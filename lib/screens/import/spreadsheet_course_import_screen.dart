// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 表格文件课表导入
// 解析 Excel / CSV 表格并写入课表。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import '../../l10n/service_message_localizer.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/course.dart';
import '../../providers/timetable_provider.dart';
import '../../services/import_time_scheme_restore_point.dart';
import '../../services/spreadsheet_import_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/import_file_reader.dart';
import '../../utils/import_result_message.dart';
import '../../widgets/app_dialogs.dart';
import 'import_shared.dart';

class SpreadsheetCourseImportScreen extends StatefulWidget {
  final String? initialFilePath;
  final String? initialFileName;

  const SpreadsheetCourseImportScreen({
    super.key,
    this.initialFilePath,
    this.initialFileName,
  });

  @override
  State<SpreadsheetCourseImportScreen> createState() =>
      _SpreadsheetCourseImportScreenState();
}

class _SpreadsheetCourseImportScreenState
    extends State<SpreadsheetCourseImportScreen> {
  final SpreadsheetImportService _spreadsheetImportService =
      SpreadsheetImportService();

  bool _isImporting = false;
  bool _isSharingTemplate = false;

  @override
  void initState() {
    super.initState();
    final filePath = widget.initialFilePath;
    if (filePath != null && filePath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _importFromExternalFile(filePath, widget.initialFileName ?? 'import');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.spreadsheetImportTitle),
      // Standard list path so the large title collapses with scroll (see the
      // ICS import screen above).
      child: Column(
        children: [
          Expanded(
            child: HyperosListView(
              children: [
                    ImportGuidePanel(
                      scenarioIntro: l10n.spreadsheetScenarioIntro,
                      step1Subtitle: l10n.spreadsheetStep1Subtitle,
                      step2Subtitle: l10n.spreadsheetStep2Subtitle,
                      step3Subtitle: l10n.spreadsheetStep3Subtitle,
                      supportedFilesSuffix:
                          l10n.spreadsheetSupportedFilesSuffix,
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HyperosButton(
                      label: l10n.downloadSpreadsheetTemplateAction,
                      variant: HyperosButtonVariant.secondary,
                      expand: true,
                      loading: _isSharingTemplate,
                      onPressed: _isSharingTemplate ? null : _shareTemplate,
                    ),
                    const SizedBox(height: 10),
                    HyperosButton(
                      label: _isImporting
                          ? '${l10n.spreadsheetImportTitle}...'
                          : l10n.chooseSpreadsheetFileAction,
                      expand: true,
                      loading: _isImporting,
                      onPressed: _isImporting ? null : _importSpreadsheetFile,
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _shareTemplate() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSharingTemplate = true;
    });
    try {
      final data = await rootBundle.load(
        'assets/templates/mikcb_course_import_template.csv',
      );
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/mikcb_course_import_template.csv');
      await file.writeAsBytes(data.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: l10n.downloadSpreadsheetTemplateAction,
        ),
      );
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          message: l10n.importFileReadFailed,
          kind: AppToastKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharingTemplate = false;
        });
      }
    }
  }

  Future<void> _importFromExternalFile(String filePath, String fileName) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isImporting = true;
    });
    try {
      // 走和「自己选文件」同一个带上限的读取。这条路是**外部应用把文件递进来**
      // （main.dart 的 share intent → SpreadsheetCourseImportScreen(initialFilePath)），
      // 完全不受用户自觉约束——体积上限的全部意义就是防这种输入把内存撑爆，
      // Android 上 OOM 直接杀进程，下面的 catch 救不回来。
      final Uint8List bytes;
      try {
        bytes = await readImportFileBytes(
          filePath,
          maxBytes: SpreadsheetImportService.maxFileBytes,
        );
      } on ImportFileTooLarge {
        if (mounted) {
          showAppToast(
            context,
            message: l10n.importFileTooLarge(
              formatByteBudget(SpreadsheetImportService.maxFileBytes),
            ),
            kind: AppToastKind.error,
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
      await _executeSpreadsheetImport(bytes, fileName);
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          message: l10n.importFileReadFailed,
          kind: AppToastKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _importSpreadsheetFile() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isImporting = true;
    });
    try {
      // Ask for the path rather than the bytes. Reading the file eagerly would
      // pull all of it into memory before we get any chance to measure it, which
      // is exactly the case the size cap below exists to prevent.
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        if (mounted) {
          showAppToast(
            context,
            message: l10n.importFileReadFailed,
            kind: AppToastKind.error,
          );
        }
        return;
      }

      final Uint8List bytes;
      try {
        bytes = await readImportFileBytes(
          path,
          maxBytes: SpreadsheetImportService.maxFileBytes,
        );
      } on ImportFileTooLarge {
        if (mounted) {
          showAppToast(
            context,
            message: l10n.importFileTooLarge(
              formatByteBudget(SpreadsheetImportService.maxFileBytes),
            ),
            kind: AppToastKind.error,
          );
        }
        return;
      }
      await _executeSpreadsheetImport(bytes, file.name);
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _executeSpreadsheetImport(
    List<int> bytes,
    String fileName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();

    late final SpreadsheetImportResult parsedResult;
    try {
      parsedResult = _spreadsheetImportService.parseBytes(
        bytes,
        fileName: fileName,
        settings: provider.settings,
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        message: localizeServiceMessage(l10n, error.message),
        kind: AppToastKind.error,
      );
      return;
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        message: l10n.importFileReadFailed,
        kind: AppToastKind.error,
      );
      return;
    }

    if (parsedResult.courses.isEmpty) {
      if (mounted) {
        showAppToast(
          context,
          message: l10n.importNoCoursesRecognized,
          kind: AppToastKind.warning,
        );
      }
      return;
    }

    if (parsedResult.warnings.isNotEmpty) {
      final shouldContinue = await _showSpreadsheetWarnings(
        context,
        warnings: parsedResult.warnings,
      );
      if (shouldContinue != true || !mounted) return;
    }

    final replaceExisting = provider.courses.isEmpty
        ? true
        : await askImportReplaceExisting(
            context,
            title: l10n.importReplaceExistingTitle,
            content: l10n.importReplaceExistingMessage(
              l10n.spreadsheetImportTitle,
            ),
          );
    if (replaceExisting == null || !mounted) return;

    await _completeParsedCourseImport(
      context: context,
      provider: provider,
      courses: parsedResult.courses,
      replaceExisting: replaceExisting,
      source: 'spreadsheet',
      semesterStart: provider.settings.semesterStartDate,
      warningCount: parsedResult.warnings.length,
    );
  }
}

Future<bool?> _showSpreadsheetWarnings(
  BuildContext context, {
  required List<String> warnings,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showAppConfirmDialogWithBody(
    context,
    title: l10n.spreadsheetImportWarningsTitle,
    confirmLabel: l10n.spreadsheetImportWarningsContinue,
    body: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.spreadsheetImportWarningsMessage),
            const SizedBox(height: 12),
            ...warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${localizeServiceWarning(l10n, warning)}'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


Future<void> _completeParsedCourseImport({
  required BuildContext context,
  required TimetableProvider provider,
  required List<Course> courses,
  required bool replaceExisting,
  required String source,
  DateTime? semesterStart,
  int warningCount = 0,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final requiredSectionCount = provider
      .previewImportedCourseRequiredSectionCount(
        courses,
        replaceExisting: replaceExisting,
      );
  if (!context.mounted) return;
  // 同 ICS / AI 导入：「自动补齐节次」会先扩表并落盘，而下面每条中止路径
  // （用户取消、未挂载、写盘抛错）原先都不回滚 —— 作息被永久换掉。
  // 恢复点与教务导入那条路共用同一份实现（有 3 条单测）。
  final restorePoint = ImportTimeSchemeRestorePoint.capture(provider);
  var coursesImported = false;
  try {
    final capacityReady = await ensureImportSectionCapacity(
      context,
      requiredSectionCount: requiredSectionCount,
      provider: provider,
    );
    if (!capacityReady || !context.mounted) return;

    final coursesToImport = await coursesWithOptionalRandomColors(courses);
    if (!context.mounted) return;

    final importedCount = await provider.importParsedCourses(
      coursesToImport,
      replaceExisting: replaceExisting,
      semesterStart: semesterStart,
      source: source,
      preserveLocalColors: await shouldPreserveLocalColorsOnImport(
        replaceExisting: replaceExisting,
      ),
    );
    // 课程已经落库：这套作息就是它们的依据，之后任何失败都不再回滚作息。
    coursesImported = true;
    if (!context.mounted) return;

    showAppToast(
      context,
      message: buildImportResultMessage(
        l10n: l10n,
        importedCount: importedCount,
        replaceExisting: replaceExisting,
        warningCount: warningCount,
      ),
      kind: importedCount > 0 ? AppToastKind.success : AppToastKind.info,
    );
    if (importedCount > 0) {
      Navigator.of(context).pop(true);
    }
  } finally {
    if (!coursesImported) {
      await restorePoint.restore();
    }
  }
}


