// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// ICS 文件课表导入
// 解析 .ics 日历文件并写入课表。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import '../../l10n/service_message_localizer.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/timetable_provider.dart';
import '../../services/ics_import_service.dart';
import '../../services/import_time_scheme_restore_point.dart';
import '../../services/import_week_alignment_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/import_file_reader.dart';
import '../../utils/import_result_message.dart';
import 'import_shared.dart';

class IcsCourseImportScreen extends StatefulWidget {
  final String? initialIcsContent;
  const IcsCourseImportScreen({super.key, this.initialIcsContent});

  @override
  State<IcsCourseImportScreen> createState() => _IcsCourseImportScreenState();
}

class _IcsCourseImportScreenState extends State<IcsCourseImportScreen> {
  final IcsImportService _icsImportService = IcsImportService();
  final ImportWeekAlignmentService _weekAlignmentService =
      const ImportWeekAlignmentService();

  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialIcsContent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _importFromExternalIcs(widget.initialIcsContent!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.icsImportTitle),
      // Standard list path (header inset inside the scrollable + notification
      // bubbling) so the large title collapses; the old BodyInset +
      // includeHeaderInset:false combo swallowed vertical scroll notifications
      // and froze the large title.
      child: Column(
        children: [
          Expanded(
            child: HyperosListView(
              children: [
                    ImportGuidePanel(
                      scenarioIntro: l10n.icsScenarioIntro,
                      step1Subtitle: l10n.icsStep1Subtitle,
                      step2Subtitle: l10n.icsStep2Subtitle,
                      step3Subtitle: l10n.icsStep3Subtitle,
                      supportedFilesSuffix: l10n.supportedFilesSuffix,
                      supportedFilesExtra: l10n.supportedFilesImageHint,
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: HyperosButton(
                  label: _isImporting
                      ? '${l10n.icsImportTitle}...'
                      : l10n.chooseIcsFileAction,
                  expand: true,
                  loading: _isImporting,
                  onPressed: _isImporting ? null : _importIcsFile,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _importIcsFile() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isImporting = true;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['ics'],
        // withData: true would already have the whole file in memory, and on
        // Android an OOM kills the process instead of raising something
        // catchable — so the ceiling has to be enforced before the read
        // (the picker only returns bytes on demand; nothing is pre-loaded).
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
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
          maxBytes: IcsImportService.maxFileBytes,
        );
      } on ImportFileTooLarge {
        if (mounted) {
          showAppToast(
            context,
            message: l10n.importFileTooLarge(
              formatByteBudget(IcsImportService.maxFileBytes),
            ),
            kind: AppToastKind.error,
          );
        }
        return;
      }

      await _executeIcsImport(
        utf8.decode(bytes, allowMalformed: true),
        result.files.single.name,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _importFromExternalIcs(String icsContent) async {
    setState(() {
      _isImporting = true;
    });
    try {
      await _executeIcsImport(
        icsContent,
        AppLocalizations.of(context)!.icsImportTitle,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  /// ICS 导入核心流程：解析 → 替换选择 → 学期对齐 → 容量检查 → 导入
  Future<void> _executeIcsImport(String icsContent, String importLabel) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    try {
      await _executeIcsImportCore(icsContent, importLabel, provider, l10n);
    } on FormatException catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        message: error.message.isNotEmpty
            ? localizeServiceMessage(l10n, error.message)
            : l10n.importNoCoursesRecognized,
        kind: AppToastKind.error,
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        message: l10n.importNoCoursesRecognized,
        kind: AppToastKind.error,
      );
    }
  }

  Future<void> _executeIcsImportCore(
    String icsContent,
    String importLabel,
    TimetableProvider provider,
    AppLocalizations l10n,
  ) async {
    final replaceExisting = provider.courses.isEmpty
        ? true
        : await askImportReplaceExisting(
            context,
            title: l10n.importReplaceExistingTitle,
            content: l10n.importReplaceExistingMessage(importLabel),
          );
    if (replaceExisting == null || !mounted) return;

    final parsedResult = _icsImportService.parseWakeUpSchedule(icsContent);
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

    final semesterConfig = await pickImportSemesterConfig(
      context,
      initialSemesterStartDate:
          provider.settings.semesterStartDate ?? parsedResult.semesterStart,
      initialFirstCourseWeek: _weekAlignmentService.inferFirstCourseWeek(
        semesterStartDate:
            provider.settings.semesterStartDate ?? parsedResult.semesterStart,
        firstCourseDate: parsedResult.semesterStart,
      ),
      inferredFirstCourseDate: parsedResult.semesterStart,
      title: l10n.importConfirmSemesterMappingTitle,
      subtitle: l10n.importConfirmSemesterMappingSubtitleIcs,
    );
    if (semesterConfig == null || !mounted) return;

    final alignedCourses = _weekAlignmentService.shiftCoursesToSemesterWeeks(
      parsedResult.courses,
      firstCourseWeek: semesterConfig.firstCourseWeek,
    );
    final requiredSectionCount = provider
        .previewImportedCourseRequiredSectionCount(
          alignedCourses,
          replaceExisting: replaceExisting,
        );
    if (!mounted) return;
    // 「要不要自动补齐节次」会**先扩表并落盘**，而下面每条中止路径（用户取消、
    // 未挂载、写盘抛错）原先都不回滚 —— 用户什么都没干，作息却被永久换掉，
    // 还多出一条叫「（导入补齐）」的模板。恢复点与教务导入那条路共用同一份实现
    // （`services/import_time_scheme_restore_point.dart`，有 3 条单测）。
    final restorePoint = ImportTimeSchemeRestorePoint.capture(provider);
    var coursesImported = false;
    try {
      final capacityReady = await ensureImportSectionCapacity(
        context,
        requiredSectionCount: requiredSectionCount,
        provider: provider,
      );
      if (!capacityReady || !mounted) return;

      final coursesToImport = await coursesWithOptionalRandomColors(
        alignedCourses,
      );
      if (!mounted) return;
      final importedCount = await provider.importParsedCourses(
        coursesToImport,
        replaceExisting: replaceExisting,
        semesterStart: semesterConfig.semesterStartDate,
        source: 'ics',
        preserveLocalColors: await shouldPreserveLocalColorsOnImport(
          replaceExisting: replaceExisting,
        ),
      );
      // 课程已经落库：这套作息就是它们的依据，之后任何失败都不再回滚作息。
      coursesImported = true;
      if (!mounted) return;
      showAppToast(
        context,
        message: buildImportResultMessage(
          l10n: l10n,
          importedCount: importedCount,
          replaceExisting: replaceExisting,
        ),
        kind: importedCount > 0 ? AppToastKind.success : AppToastKind.info,
      );
      if (importedCount > 0) Navigator.of(context).pop(true);
    } finally {
      if (!coursesImported) {
        await restorePoint.restore();
      }
    }
  }
}

