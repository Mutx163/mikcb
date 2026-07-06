import '../logging/app_debug_log.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:convert';
import 'dart:io';

import 'package:azlistview/azlistview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../models/warehouse_macro_models.dart';
import '../models/warehouse_repository_models.dart';
import '../providers/timetable_provider.dart';
import '../services/ai_course_import_service.dart';
import '../services/ics_import_service.dart';
import '../services/import_week_alignment_service.dart';
import '../services/spreadsheet_import_service.dart';
import '../services/warehouse_import_preferences_service.dart';
import '../services/warehouse_macro_service.dart';
import '../services/warehouse_repository_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/warehouse_macro_recorder.dart';
import '../widgets/warehouse_macro_replayer.dart';
import '../widgets/warehouse_playback_overlay.dart';
import 'feedback_screen.dart';

enum _WarehouseImportMenuAction { feedback, customDebug }

bool shouldPromptRememberedLoginAutofill({
  required bool hasPasswordField,
  required WarehouseRememberedLogin? rememberedLogin,
  required WarehouseRememberedLogin candidate,
  required bool hasPromptedAutofill,
  required bool isPromptShowing,
}) {
  return hasPasswordField &&
      rememberedLogin != null &&
      rememberedLogin.password.isNotEmpty &&
      candidate.password.isEmpty &&
      !hasPromptedAutofill &&
      !isPromptShowing;
}

Widget _buildImportMethodChoiceTile({
  required ThemeData theme,
  required ColorScheme colorScheme,
  required IconData icon,
  required String title,
  required String subtitle,
  required String footer,
  required VoidCallback onTap,
}) {
  return HyperosChoiceTile(
    prefix: Icon(icon),
    title: title,
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subtitle),
        const SizedBox(height: 4),
        Text(
          footer,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
    onTap: onTap,
  );
}

Widget _buildWarehouseAdapterListItem({
  required BuildContext context,
  required WarehouseAdapterEntry adapter,
  required bool hasMacro,
  required Future<void> Function()? onImport,
  required Future<void> Function()? onRecord,
  required Future<void> Function() onInfo,
  required Future<void> Function()? onQuickImport,
  required String importButtonLabel,
  required String recordButtonLabel,
}) {
  final scope = HyperosListTileScope.maybeOf(context);
  return Padding(
    padding: HyperosTokens.rowPadding(
      isFirst: scope?.isFirst ?? true,
      isLast: scope?.isLast ?? true,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ImportIconBadge(icon: Icons.extension_outlined),
        const SizedBox(width: HyperosTokens.rowContentGap),
        Expanded(
          child: _WarehouseAdapterTileBody(
            adapter: adapter,
            hasMacro: hasMacro,
            onImport: onImport,
            onRecord: onRecord,
            onInfo: onInfo,
            onQuickImport: onQuickImport,
            importButtonLabel: importButtonLabel,
            recordButtonLabel: recordButtonLabel,
          ),
        ),
      ],
    ),
  );
}

class CourseImportScreen extends StatelessWidget {
  const CourseImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.courseImportTitle),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ImportSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.chooseImportMethodTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.chooseImportMethodSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              HyperosChoiceGroup(
                children: [
                  _buildImportMethodChoiceTile(
                    theme: theme,
                    colorScheme: colorScheme,
                    icon: Icons.event_note_rounded,
                    title: l10n.importMethodIcsTitle,
                    subtitle: l10n.importMethodIcsSubtitle,
                    footer: l10n.importMethodIcsFooter,
                    onTap: () => _openImportPage<bool>(
                      context,
                      builder: (_) => const IcsCourseImportScreen(),
                    ),
                  ),
                  _buildImportMethodChoiceTile(
                    theme: theme,
                    colorScheme: colorScheme,
                    icon: Icons.auto_awesome_rounded,
                    title: l10n.importMethodAiTitle,
                    subtitle: l10n.importMethodAiSubtitle,
                    footer: l10n.importMethodAiFooter,
                    onTap: () => _openImportPage<bool>(
                      context,
                      builder: (_) => const AiImageCourseImportScreen(),
                    ),
                  ),
                  _buildImportMethodChoiceTile(
                    theme: theme,
                    colorScheme: colorScheme,
                    icon: Icons.school_outlined,
                    title: l10n.importMethodWarehouseTitle,
                    subtitle: l10n.importMethodWarehouseSubtitle,
                    footer: l10n.importMethodWarehouseFooter,
                    onTap: () => _openImportPage<bool>(
                      context,
                      builder: (_) => const WarehouseCourseImportScreen(),
                    ),
                  ),
                  _buildImportMethodChoiceTile(
                    theme: theme,
                    colorScheme: colorScheme,
                    icon: Icons.table_chart_outlined,
                    title: l10n.importMethodSpreadsheetTitle,
                    subtitle: l10n.importMethodSpreadsheetSubtitle,
                    footer: l10n.importMethodSpreadsheetFooter,
                    onTap: () => _openImportPage<bool>(
                      context,
                      builder: (_) => const SpreadsheetCourseImportScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openImportPage<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) async {
    final imported = await Navigator.of(context).push<T>(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/courses/import/detail'),
        builder: builder,
      ),
    );
    if (context.mounted && imported == true) {
      Navigator.of(context).pop(true);
    }
  }
}

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
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ImportGuidePanel(
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
        ),
      ),
    );
  }

  Future<void> _importIcsFile() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isImporting = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['ics'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        if (mounted) {
          showAppToast(
            context,
            message: l10n.importFileReadFailed,
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
    final replaceExisting = provider.courses.isEmpty
        ? true
        : await _askReplaceExisting(
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

    final semesterConfig = await _pickImportSemesterConfig(
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
    final capacityReady = await _ensureSectionCapacity(
      context,
      requiredSectionCount: requiredSectionCount,
      provider: provider,
    );
    if (!capacityReady || !mounted) return;

    final importedCount = await provider.importParsedCourses(
      alignedCourses,
      replaceExisting: replaceExisting,
      semesterStart: semesterConfig.semesterStartDate,
      source: 'ics',
    );
    if (!mounted) return;
    showAppToast(
      context,
      message: importedCount > 0
          ? (replaceExisting
                ? l10n.importOverwriteCount(importedCount)
                : l10n.importUpdatedCount(importedCount))
          : l10n.importNoCourseChanges,
      kind: importedCount > 0 ? AppToastKind.success : AppToastKind.info,
    );
    if (importedCount > 0) Navigator.of(context).pop(true);
  }
}

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
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ImportGuidePanel(
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
        ),
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
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: l10n.downloadSpreadsheetTemplateAction);
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
    setState(() {
      _isImporting = true;
    });
    try {
      final bytes = await File(filePath).readAsBytes();
      if (!mounted) {
        return;
      }
      await _executeSpreadsheetImport(bytes, fileName);
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          message: AppLocalizations.of(context)!.importFileReadFailed,
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          showAppToast(
            context,
            message: l10n.importFileReadFailed,
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
        message: error.message.contains('未识别')
            ? l10n.spreadsheetFormatUnrecognized
            : error.message,
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
        : await _askReplaceExisting(
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
                child: Text('• $warning'),
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
  final capacityReady = await _ensureSectionCapacity(
    context,
    requiredSectionCount: requiredSectionCount,
    provider: provider,
  );
  if (!capacityReady || !context.mounted) return;

  final importedCount = await provider.importParsedCourses(
    courses,
    replaceExisting: replaceExisting,
    semesterStart: semesterStart,
    source: source,
  );
  if (!context.mounted) return;

  final warningSuffix = warningCount == 0
      ? ''
      : l10n.aiWarningExtraSuffix(warningCount);
  showAppToast(
    context,
    message: importedCount > 0
        ? (replaceExisting
              ? l10n.importOverwriteCount(importedCount) + warningSuffix
              : l10n.importUpdatedCount(importedCount) + warningSuffix)
        : l10n.importNoCourseChanges,
    kind: importedCount > 0 ? AppToastKind.success : AppToastKind.info,
  );
  if (importedCount > 0) {
    Navigator.of(context).pop(true);
  }
}

class AiImageCourseImportScreen extends StatefulWidget {
  const AiImageCourseImportScreen({super.key});

  @override
  State<AiImageCourseImportScreen> createState() =>
      _AiImageCourseImportScreenState();
}

class _AiImageCourseImportScreenState extends State<AiImageCourseImportScreen> {
  final TextEditingController _aiController = TextEditingController();
  final FocusNode _aiFocusNode = FocusNode();
  final AiCourseImportService _aiImportService = AiCourseImportService();
  final ImportWeekAlignmentService _weekAlignmentService =
      const ImportWeekAlignmentService();

  AiCourseImportParseResult? _aiParsedResult;
  String? _aiParseError;
  bool _isImporting = false;

  @override
  void dispose() {
    _aiFocusNode.dispose();
    _aiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.aiImportTitle),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: HyperosBlurredBodyInset(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dense = constraints.maxHeight < 760;
                  final ultraDense = constraints.maxHeight < 520;
                  final double sectionGap;
                  final double outerPadding;
                  if (ultraDense) {
                    sectionGap = 4.0;
                    outerPadding = 10.0;
                  } else if (dense) {
                    sectionGap = 8.0;
                    outerPadding = 12.0;
                  } else {
                    sectionGap = 12.0;
                    outerPadding = 16.0;
                  }
                  final previewSummary = _aiParsedResult == null
                      ? null
                      : l10n.aiPreviewSummary(
                          _aiParsedResult!.courses.length,
                          _aiParsedResult!.requiredSectionCount,
                          _aiParsedResult!.warnings.isEmpty
                              ? ''
                              : l10n.aiWarningCountSuffix(
                                  _aiParsedResult!.warnings.length,
                                ),
                        );

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      outerPadding,
                      12,
                      outerPadding,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ImportSectionCard(
                          padding: EdgeInsets.all(
                            ultraDense
                                ? 10
                                : dense
                                ? 14
                                : 16,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ultraDense
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.aiWorkflowCompactTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            l10n.aiWorkflowCompactSubtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.aiWorkflowTitle,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          SizedBox(height: dense ? 4 : 6),
                                          Text(
                                            l10n.aiWorkflowSubtitle,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  height: 1.35,
                                                ),
                                          ),
                                        ],
                                      ),
                              ),
                              SizedBox(width: ultraDense ? 8 : 12),
                              if (ultraDense)
                                HyperosButton(
                                  label: l10n.aiPromptShortAction,
                                  variant: HyperosButtonVariant.secondary,
                                  onPressed: _showPromptSheet,
                                )
                              else
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: dense ? 30 : 34,
                                  color: colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        if (ultraDense)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              l10n.aiExpertModeSuggestion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _CompactHintChip(
                                icon: Icons.smart_toy_outlined,
                                label: l10n.aiHintExpertMode,
                              ),
                              _CompactHintChip(
                                icon: Icons.photo_library_outlined,
                                label: l10n.aiHintSendScreenshot,
                              ),
                              _CompactHintChip(
                                icon: Icons.content_copy_rounded,
                                label: l10n.aiHintCopyJsonBack,
                              ),
                              _CompactHintChip(
                                icon: Icons.event_available_rounded,
                                label: l10n.aiHintPickSemesterAfterImport,
                              ),
                            ],
                          ),
                        SizedBox(height: sectionGap),
                        if (ultraDense)
                          Row(
                            children: [
                              Expanded(
                                child: _CompactActionButton(
                                  icon: Icons.copy_all_rounded,
                                  label: l10n.copyAddress,
                                  onPressed: _copyAiPrompt,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _CompactActionButton(
                                  icon: Icons.article_outlined,
                                  label: l10n.aiPromptShortAction,
                                  onPressed: _showPromptSheet,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _CompactActionButton(
                                  icon: Icons.content_paste_rounded,
                                  label: l10n.pasteAction,
                                  onPressed: _pasteFromClipboard,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _CompactActionButton(
                                  icon: Icons.clear_rounded,
                                  label: l10n.clearAction,
                                  onPressed: _clearInput,
                                ),
                              ),
                            ],
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              HyperosButton(
                                label: l10n.copyAddress,
                                variant: HyperosButtonVariant.secondary,
                                onPressed: _copyAiPrompt,
                              ),
                              HyperosButton(
                                label: l10n.aiPromptShortAction,
                                variant: HyperosButtonVariant.secondary,
                                onPressed: _showPromptSheet,
                              ),
                              HyperosButton(
                                label: l10n.pasteAction,
                                variant: HyperosButtonVariant.secondary,
                                onPressed: _pasteFromClipboard,
                              ),
                              HyperosButton(
                                label: l10n.clearAction,
                                variant: HyperosButtonVariant.secondary,
                                onPressed: _clearInput,
                              ),
                            ],
                          ),
                        SizedBox(height: sectionGap),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ultraDense
                                    ? l10n.jsonLabelShort
                                    : l10n.aiPasteJsonTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_aiParsedResult != null)
                              _CompactStatusChip(
                                label: l10n.aiCourseCountChip(
                                  _aiParsedResult!.courses.length,
                                ),
                              ),
                            if (_aiParseError != null)
                              _CompactStatusChip(
                                label: l10n.aiParseFailedChip,
                                isError: true,
                              ),
                          ],
                        ),
                        SizedBox(
                          height: ultraDense
                              ? 4
                              : dense
                              ? 6
                              : 8,
                        ),
                        Expanded(
                          child: _ImportSectionCard(
                            padding: EdgeInsets.zero,
                            child: TextField(
                              key: const ValueKey('ai_import_json_input'),
                              controller: _aiController,
                              focusNode: _aiFocusNode,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              onChanged: (_) {
                                if (_aiParsedResult != null ||
                                    _aiParseError != null) {
                                  setState(() {
                                    _aiParsedResult = null;
                                    _aiParseError = null;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(
                                  ultraDense ? 10 : 14,
                                ),
                                hintText: ultraDense
                                    ? l10n.aiPasteJsonHintShort
                                    : l10n.aiPasteJsonHintLong,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        if (_aiParseError != null)
                          _CompactNoticeCard(
                            icon: Icons.error_outline_rounded,
                            message: _aiParseError!,
                            isError: true,
                            actionLabel: l10n.detailAction,
                            onAction: () => _showMessageSheet(
                              title: l10n.aiParseErrorTitle,
                              content: _aiParseError!,
                            ),
                          )
                        else if (_aiParsedResult != null)
                          _CompactNoticeCard(
                            icon: Icons.check_circle_outline_rounded,
                            message: previewSummary!,
                            actionLabel: l10n.viewDetailsAction,
                            onAction: () => _showPreviewSheet(_aiParsedResult!),
                          )
                        else if (!ultraDense)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              l10n.aiWorkflowFooter,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        SizedBox(height: sectionGap),
                        Row(
                          children: [
                            Expanded(
                              child: HyperosButton(
                                label: l10n.previewAction,
                                variant: HyperosButtonVariant.secondary,
                                expand: true,
                                onPressed: _previewAiResult,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: HyperosButton(
                                label: _isImporting
                                    ? '${l10n.importReplaceExistingTitle}...'
                                    : l10n.confirmImportAction,
                                expand: true,
                                loading: _isImporting,
                                onPressed: _isImporting
                                    ? null
                                    : _importAiResult,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyAiPrompt() async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(
      const ClipboardData(text: AiCourseImportService.prompt),
    );
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.promptCopiedHint,
      kind: AppToastKind.success,
    );
  }

  Future<void> _pasteFromClipboard() async {
    final l10n = AppLocalizations.of(context)!;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.clipboardNoText,
        kind: AppToastKind.warning,
      );
      return;
    }
    _aiController.text = text;
    if (!mounted) {
      return;
    }
    setState(() {
      _aiParsedResult = null;
      _aiParseError = null;
    });
  }

  void _clearInput() {
    _aiController.clear();
    setState(() {
      _aiParsedResult = null;
      _aiParseError = null;
    });
  }

  void _showPromptSheet() {
    final l10n = AppLocalizations.of(context)!;
    showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        return HyperosSheetFrame(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.aiPromptSheetTitle,
                style: HyperosTypography.sheetTitle(sheetContext),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.aiPromptSheetSubtitle,
                style: HyperosTypography.sectionDescription(sheetContext),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      AiCourseImportService.prompt.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPreviewSheet(AiCourseImportParseResult result) {
    final l10n = AppLocalizations.of(context)!;
    showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) {
        return HyperosSheetFrame(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.aiPreviewTitle,
                style: HyperosTypography.sheetTitle(sheetContext),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _AiPreviewCard(result: result),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessageSheet({required String title, required String content}) {
    showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) {
        return HyperosSheetFrame(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HyperosTypography.sheetTitle(sheetContext)),
              const SizedBox(height: 12),
              Expanded(child: SingleChildScrollView(child: Text(content))),
            ],
          ),
        );
      },
    );
  }

  void _previewAiResult() {
    final result = _parseAiResult(showError: true);
    if (result != null) {
      _showPreviewSheet(result);
    }
  }

  AiCourseImportParseResult? _parseAiResult({required bool showError}) {
    final l10n = AppLocalizations.of(context)!;
    final content = _aiController.text.trim();
    if (content.isEmpty) {
      final message = l10n.aiPasteJsonFirst;
      if (mounted) {
        setState(() {
          _aiParsedResult = null;
          _aiParseError = message;
        });
        if (showError) {
          showAppToast(context, message: message);
        }
      }
      return null;
    }

    try {
      final result = _aiImportService.parse(
        content,
        settings: context.read<TimetableProvider>().settings,
      );
      if (mounted) {
        setState(() {
          _aiParsedResult = result;
          _aiParseError = null;
        });
      }
      return result;
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _aiParsedResult = null;
          _aiParseError = error.message;
        });
        if (showError) {
          showAppToast(
            context,
            message: error.message,
            kind: AppToastKind.error,
          );
        }
      }
      return null;
    } catch (_) {
      final message = l10n.aiParseFailedIncompleteJson;
      if (mounted) {
        setState(() {
          _aiParsedResult = null;
          _aiParseError = message;
        });
        if (showError) {
          showAppToast(context, message: message);
        }
      }
      return null;
    }
  }

  Future<void> _importAiResult() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isImporting = true;
    });
    try {
      final result = _parseAiResult(showError: true);
      if (result == null || !mounted) {
        return;
      }

      final provider = context.read<TimetableProvider>();
      final replaceExisting = provider.courses.isEmpty
          ? true
          : await _askReplaceExisting(
              context,
              title: l10n.importAiResultTitle,
              content: l10n.importAiReplaceMessage,
            );
      if (replaceExisting == null || !mounted) {
        return;
      }

      final semesterConfig = await _pickImportSemesterConfig(
        context,
        initialSemesterStartDate:
            provider.settings.semesterStartDate ??
            _weekAlignmentService.startOfWeek(DateTime.now()),
        initialFirstCourseWeek: 1,
        title: l10n.importConfirmSemesterMappingTitle,
        subtitle: l10n.importConfirmSemesterMappingSubtitleAi,
      );
      if (semesterConfig == null || !mounted) {
        return;
      }

      final alignedCourses = _weekAlignmentService.shiftCoursesToSemesterWeeks(
        result.courses,
        firstCourseWeek: semesterConfig.firstCourseWeek,
      );
      final requiredSectionCount = provider
          .previewImportedCourseRequiredSectionCount(
            alignedCourses,
            replaceExisting: replaceExisting,
          );
      if (!mounted) {
        return;
      }
      final capacityReady = await _ensureSectionCapacity(
        context,
        requiredSectionCount: requiredSectionCount,
        provider: provider,
      );
      if (!capacityReady || !mounted) {
        return;
      }

      final importedCount = await provider.importParsedCourses(
        alignedCourses,
        replaceExisting: replaceExisting,
        semesterStart: semesterConfig.semesterStartDate,
        source: 'ai',
      );
      if (!mounted) {
        return;
      }

      final warningSuffix = result.warnings.isEmpty
          ? ''
          : l10n.aiWarningExtraSuffix(result.warnings.length);
      showAppToast(
        context,
        message: importedCount > 0
            ? (replaceExisting
                  ? l10n.importOverwriteCount(importedCount) + warningSuffix
                  : l10n.importUpdatedCount(importedCount) + warningSuffix)
            : l10n.importNoCourseChanges,
        kind: importedCount > 0 ? AppToastKind.success : AppToastKind.info,
      );
      if (importedCount > 0) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
}

class WarehouseCourseImportScreen extends StatefulWidget {
  const WarehouseCourseImportScreen({super.key});

  @override
  State<WarehouseCourseImportScreen> createState() =>
      _WarehouseCourseImportScreenState();
}

class _WarehouseCourseImportScreenState
    extends State<WarehouseCourseImportScreen> {
  static final WarehouseRepositorySource _defaultSource =
      WarehouseRepositorySource.fromGitHubUrl(
        'https://github.com/Mutx163/qingyu_warehouse',
      );

  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  final WarehouseMacroService _macroService = WarehouseMacroService();
  final TextEditingController _searchController = TextEditingController();
  late Future<WarehouseRootIndex> _rootIndexFuture;
  List<String> _recentSchoolIds = const [];
  String _searchQuery = '';
  WarehouseFetchOptions _currentFetchOptions() {
    final settings = context.read<TimetableProvider>().settings;
    return WarehouseFetchOptions.fromSettings(settings);
  }

  @override
  void initState() {
    super.initState();
    _rootIndexFuture = _repositoryService.fetchRootIndex(
      _defaultSource,
      options: _currentFetchOptions(),
    );
    _loadRecentSchoolIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSchoolIds() async {
    final ids = await _preferencesService.getRecentSchoolIds();
    if (!mounted) return;
    setState(() {
      _recentSchoolIds = ids;
    });
  }

  Future<void> _handleMoreAction(_WarehouseImportMenuAction action) async {
    switch (action) {
      case _WarehouseImportMenuAction.feedback:
        await _openMissingSchoolFeedbackGuide();
        break;
      case _WarehouseImportMenuAction.customDebug:
        await _openCustomDebugRecords();
        break;
    }
  }

  Future<void> _handleQuickImport() async {
    final allEntries = await _macroService.getAllMacroEntries();
    if (!mounted) return;
    if (allEntries.isEmpty) {
      _showLightTip(context, '暂无已保存的快捷导入记录');
      return;
    }
    // 加载完整的宏记录（含学校名、适配器名）
    final records = <WarehouseMacroRecord>[];
    for (final entry in allEntries) {
      final record = await _macroService.getMacro(
        entry.schoolId,
        entry.adapterId,
      );
      if (record != null) records.add(record);
    }
    if (!mounted) return;
    if (records.isEmpty) {
      _showLightTip(context, '暂无已保存的快捷导入记录');
      return;
    }
    if (records.length == 1) {
      await _startQuickImport(records.first);
      return;
    }
    // 多个宏录制，弹窗选择
    final l10n = AppLocalizations.of(context)!;
    final chosen = await showHyperosDialog<WarehouseMacroRecord>(
      context: context,
      title: '选择快捷导入',
      body: HyperosChoiceGroup(
        children: [
          for (final record in records)
            HyperosChoiceTile(
              title: record.schoolName,
              subtitle: Text(
                '${record.adapterName} · ${record.steps.length} 步',
              ),
              trailing: const Icon(Icons.flash_on_rounded, size: 20),
              onTap: () => Navigator.pop(context, record),
            ),
        ],
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
    if (chosen != null && mounted) {
      await _startQuickImport(chosen);
    }
  }

  Future<void> _startQuickImport(WarehouseMacroRecord macro) async {
    final customUrl = await _preferencesService.getCustomImportUrl(
      macro.adapterId,
    );
    final initialUrl = resolveWarehouseImportUrl(
      customImportUrl: customUrl,
      defaultUrl: macro.importUrl,
    );
    if (!mounted || initialUrl == null) {
      if (mounted) {
        _showLightTip(context, '未找到有效的教务登录地址');
      }
      return;
    }

    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/quick-import-top',
        ),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: '快捷导入 - ${macro.schoolName}',
          initialUrl: initialUrl,
          source: _defaultSource,
          school: WarehouseSchoolEntry(
            id: macro.schoolId,
            name: macro.schoolName,
            initial: macro.schoolName.isNotEmpty ? macro.schoolName[0] : '#',
            resourceFolder: macro.schoolResourceFolder.isNotEmpty
                ? macro.schoolResourceFolder
                : macro.schoolId,
          ),
          adapter: WarehouseAdapterEntry(
            adapterId: macro.adapterId,
            adapterName: macro.adapterName,
            category: 'macro',
            assetJsPath: macro.adapterAssetJsPath.isNotEmpty
                ? macro.adapterAssetJsPath
                : 'macro/${macro.adapterId}.js',
            importUrl: macro.importUrl,
            maintainer: 'macro',
            description: '快捷导入 ${macro.schoolName} ${macro.adapterName}',
          ),
          fetchOptions: _currentFetchOptions(),
          macroRecord: macro,
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _showLightTip(BuildContext context, String message) {
    showAppLightTip(context, message: message);
  }

  Future<void> _openMissingSchoolFeedbackGuide() async {
    final l10n = AppLocalizations.of(context)!;
    final shouldOpen = await showHyperosSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return HyperosSheet(
          title: l10n.warehouseMissingSchoolTitle,
          description: l10n.warehouseMissingSchoolSubtitle,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              HyperosButton(
                label: l10n.laterAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: () => Navigator.pop(sheetContext, false),
              ),
              HyperosButton(
                label: l10n.goFeedbackAction,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        );
      },
    );
    if (shouldOpen == true && mounted) {
      await Navigator.of(context).push(
        HyperosPageRoute(
          settings: const RouteSettings(name: '/feedback'),
          builder: (_) => const FeedbackScreen(),
        ),
      );
    }
  }

  Future<void> _openCustomDebugRecords() async {
    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/custom-debug',
        ),
        builder: (_) => const WarehouseCustomDebugRecordsScreen(),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.importMethodWarehouseTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.flash_on_rounded),
          semanticsLabel: '快捷导入',
          onPress: _handleQuickImport,
        ),
        PopupMenuButton<_WarehouseImportMenuAction>(
          tooltip: l10n.moreActionsTooltip,
          onSelected: _handleMoreAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _WarehouseImportMenuAction.feedback,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.campaign_outlined),
                title: Text(l10n.warehouseFeedbackMissingSchoolTitle),
              ),
            ),
            PopupMenuItem(
              value: _WarehouseImportMenuAction.customDebug,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.terminal_rounded),
                title: Text(l10n.warehouseCustomDebugTitle),
              ),
            ),
          ],
        ),
      ],
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: FutureBuilder<WarehouseRootIndex>(
            future: _rootIndexFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ImportSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.warehouseRootLoadFailedTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          HyperosButton(
                            label: l10n.reloadAction,
                            variant: HyperosButtonVariant.secondary,
                            onPressed: () {
                              setState(() {
                                _rootIndexFuture = _repositoryService
                                    .fetchRootIndex(
                                      _defaultSource,
                                      options: _currentFetchOptions(),
                                    );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final allSchools = [...?snapshot.data?.schools]
                ..sort((left, right) {
                  // 通用教务/工具类学校置顶
                  final leftIsGeneric = left.name.contains('通用');
                  final rightIsGeneric = right.name.contains('通用');
                  if (leftIsGeneric != rightIsGeneric) {
                    return leftIsGeneric ? -1 : 1;
                  }
                  final initialCompare = left.initial.compareTo(right.initial);
                  if (initialCompare != 0) return initialCompare;
                  return left.name.compareTo(right.name);
                });
              final filteredSchools = _filterSchools(allSchools, _searchQuery);
              final beans = _schoolsToBeans(filteredSchools, _recentSchoolIds);
              final indexTags = beans
                  .map((bean) => bean.getSuspensionTag())
                  .toSet()
                  .toList(growable: false);
              final isSearching = _searchQuery.trim().isNotEmpty;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.searchSchoolHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.clearSearchTooltip,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: context.theme.colors.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: beans.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 36,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isSearching
                                        ? l10n.noMatchingSchools
                                        : l10n.noAvailableSchools,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  if (isSearching) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.searchSchoolSuggestion,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : AzListView(
                            data: beans,
                            itemCount: beans.length,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            indexBarData: isSearching ? const [] : indexTags,
                            indexBarOptions: IndexBarOptions(
                              needRebuild: true,
                              hapticFeedback: true,
                              textStyle:
                                  theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ) ??
                                  const TextStyle(fontSize: 11),
                              selectTextStyle:
                                  theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ) ??
                                  const TextStyle(fontSize: 11),
                              selectItemDecoration: BoxDecoration(
                                color: context.theme.colors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              indexHintDecoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              indexHintTextStyle:
                                  theme.textTheme.headlineMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ) ??
                                  const TextStyle(fontSize: 28),
                            ),
                            indexHintBuilder: (context, tag) => Container(
                              width: 72,
                              height: 72,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                tag,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            itemBuilder: (context, index) {
                              final bean = beans[index];
                              final school = bean.school;
                              return HyperosChoiceTile(
                                prefix: _ImportInitialBadge(
                                  label: school.initial,
                                ),
                                title: school.name,
                                subtitle: Text(
                                  bean.isRecent
                                      ? '最近 · 资源目录：${school.resourceFolder}'
                                      : '资源目录：${school.resourceFolder}',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                ),
                                onTap: () async {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  final imported = await Navigator.of(context)
                                      .push<bool>(
                                        HyperosPageRoute(
                                          settings: RouteSettings(
                                            name:
                                                '/courses/import/warehouse/${school.id}',
                                          ),
                                          builder: (_) =>
                                              WarehouseSchoolAdaptersScreen(
                                                source: _defaultSource,
                                                school: school,
                                                fetchOptions:
                                                    _currentFetchOptions(),
                                              ),
                                        ),
                                      );
                                  if (imported == true && context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<WarehouseSchoolEntry> _filterSchools(
    List<WarehouseSchoolEntry> schools,
    String query,
  ) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return schools;
    }
    return schools
        .where((school) {
          return school.name.toLowerCase().contains(keyword) ||
              school.id.toLowerCase().contains(keyword) ||
              school.initial.toLowerCase().contains(keyword) ||
              school.resourceFolder.toLowerCase().contains(keyword);
        })
        .toList(growable: false);
  }
}

class WarehouseCustomDebugRecordsScreen extends StatefulWidget {
  const WarehouseCustomDebugRecordsScreen({super.key});

  @override
  State<WarehouseCustomDebugRecordsScreen> createState() =>
      _WarehouseCustomDebugRecordsScreenState();
}

class _WarehouseCustomDebugRecordsScreenState
    extends State<WarehouseCustomDebugRecordsScreen> {
  static const WarehouseRepositorySource _customSource =
      WarehouseRepositorySource(owner: 'Mutx163', repo: 'qingyu_warehouse');

  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  List<WarehouseCustomDebugRecord> _records = const [];
  bool _isLoading = true;

  WarehouseFetchOptions _currentFetchOptions() {
    final settings = context.read<TimetableProvider>().settings;
    return WarehouseFetchOptions.fromSettings(settings);
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await _preferencesService.getCustomDebugRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _openEditor([WarehouseCustomDebugRecord? record]) async {
    final saved = await Navigator.of(context).push<WarehouseCustomDebugRecord>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/custom-debug/edit',
        ),
        builder: (_) => WarehouseCustomDebugEditScreen(initialRecord: record),
      ),
    );
    if (saved == null || !mounted) {
      return;
    }
    await _loadRecords();
  }

  Future<void> _deleteRecord(WarehouseCustomDebugRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.deleteDebugRecordTitle,
      message: l10n.deleteDebugRecordMessage(record.name),
      confirmLabel: l10n.deleteAction,
    );
    if (confirmed != true) {
      return;
    }
    await _preferencesService.deleteCustomDebugRecord(record.id);
    if (!mounted) {
      return;
    }
    await _loadRecords();
    if (!mounted) {
      return;
    }
    _showLightTip(context, l10n.deletedDebugRecord(record.name));
  }

  Future<void> _openDebug(WarehouseCustomDebugRecord record) async {
    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/custom-debug/run',
        ),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: record.name,
          initialUrl: record.importUrl,
          source: _customSource,
          school: const WarehouseSchoolEntry(
            id: 'custom-debug',
            name: 'custom-debug',
            initial: '#',
            resourceFolder: 'custom-debug',
          ),
          adapter: WarehouseAdapterEntry(
            adapterId: 'custom-debug-${record.id}',
            adapterName: record.name,
            category: 'custom_debug',
            assetJsPath: 'custom/${record.id}.js',
            importUrl: record.importUrl,
            maintainer: 'custom-debug',
            description: '',
          ),
          fetchOptions: _currentFetchOptions(),
          debugScriptOverride: record.script,
          debugScriptName: '${record.name}.js',
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.warehouseCustomDebugTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.add_rounded),
          semanticsLabel: l10n.addDebugRecordTooltip,
          onPress: () => _openEditor(),
        ),
      ],
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ImportSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.customDebugIntroTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.customDebugIntroSubtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          HyperosButton(
                            label: l10n.addDebugRecordAction,
                            onPressed: () => _openEditor(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_records.isEmpty)
                      _ImportSectionCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 36,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.noSavedDebugRecords,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.noSavedDebugRecordsHint,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._records.map(
                        (record) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ImportSectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        record.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      _formatDebugRecordDateTime(
                                        record.updatedAt,
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  record.importUrl,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.debugScriptLength(record.script.length),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    HyperosButton(
                                      label: l10n.startDebugAction,
                                      onPressed: () => _openDebug(record),
                                    ),
                                    HyperosButton(
                                      label: l10n.editAction,
                                      variant: HyperosButtonVariant.secondary,
                                      onPressed: () => _openEditor(record),
                                    ),
                                    HyperosButton(
                                      label: l10n.deleteAction,
                                      variant: HyperosButtonVariant.destructive,
                                      onPressed: () => _deleteRecord(record),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class WarehouseCustomDebugEditScreen extends StatefulWidget {
  final WarehouseCustomDebugRecord? initialRecord;

  const WarehouseCustomDebugEditScreen({super.key, this.initialRecord});

  @override
  State<WarehouseCustomDebugEditScreen> createState() =>
      _WarehouseCustomDebugEditScreenState();
}

class _WarehouseCustomDebugEditScreenState
    extends State<WarehouseCustomDebugEditScreen> {
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _scriptController;
  bool _isSaving = false;

  bool get _isEditing => widget.initialRecord != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialRecord?.name ?? '',
    );
    _urlController = TextEditingController(
      text: widget.initialRecord?.importUrl ?? '',
    );
    _scriptController = TextEditingController(
      text: widget.initialRecord?.script ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _pickScriptFromFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['js', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }
      final file = result.files.single;
      List<int>? bytes = file.bytes;
      if (bytes == null && (file.path ?? '').isNotEmpty) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          _showLightTip(context, l10n.scriptFileReadFailed);
        }
        return;
      }
      _scriptController.text = utf8.decode(bytes, allowMalformed: true).trim();
      if (!mounted) {
        return;
      }
      _showLightTip(context, l10n.scriptFileImported(file.name));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showLightTip(context, l10n.scriptFileImportFailed('$error'));
    }
  }

  Future<void> _saveRecord() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final importUrl = _urlController.text.trim();
    final script = _scriptController.text.trim();

    if (name.isEmpty) {
      _showLightTip(context, l10n.debugRecordNameRequired);
      return;
    }
    final uri = Uri.tryParse(importUrl);
    if (importUrl.isEmpty || uri == null || uri.host.isEmpty) {
      _showLightTip(context, l10n.invalidImportUrl);
      return;
    }
    if (script.isEmpty) {
      _showLightTip(context, l10n.debugScriptRequired);
      return;
    }

    final now = DateTime.now();
    final record =
        (widget.initialRecord ??
                WarehouseCustomDebugRecord(
                  id: const Uuid().v4(),
                  name: name,
                  importUrl: importUrl,
                  script: script,
                  createdAt: now,
                  updatedAt: now,
                ))
            .copyWith(
              name: name,
              importUrl: importUrl,
              script: script,
              updatedAt: now,
            );

    setState(() {
      _isSaving = true;
    });
    await _preferencesService.saveCustomDebugRecord(record);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(
        _isEditing ? l10n.editDebugRecordTitle : l10n.addDebugRecordTitle,
      ),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.check_rounded),
          semanticsLabel: l10n.saveAction,
          onPress: _isSaving ? null : _saveRecord,
        ),
      ],
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ImportSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.debugRecordFormula,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.debugRecordFormulaSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.debugRecordNameLabel,
                  hintText: l10n.debugRecordNameHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.importUrlLabel,
                  hintText: 'https://...',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.debugScriptLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  HyperosButton(
                    label: l10n.importFromFileAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _pickScriptFromFile,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _scriptController,
                minLines: 14,
                maxLines: 24,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  hintText: l10n.debugScriptHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              HyperosButton(
                label: _isSaving
                    ? l10n.savingAction
                    : l10n.saveDebugRecordAction,
                loading: _isSaving,
                onPressed: _isSaving ? null : _saveRecord,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDebugRecordDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_formatDate(local)} $hour:$minute';
}

class WarehouseSchoolAdaptersScreen extends StatefulWidget {
  final WarehouseRepositorySource source;
  final WarehouseSchoolEntry school;
  final WarehouseFetchOptions fetchOptions;

  const WarehouseSchoolAdaptersScreen({
    super.key,
    required this.source,
    required this.school,
    required this.fetchOptions,
  });

  @override
  State<WarehouseSchoolAdaptersScreen> createState() =>
      _WarehouseSchoolAdaptersScreenState();
}

class _WarehouseSchoolAdaptersScreenState
    extends State<WarehouseSchoolAdaptersScreen> {
  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  final WarehouseMacroService _macroService = WarehouseMacroService();
  late Future<WarehouseAdaptersIndex> _adaptersFuture;
  final Map<String, bool> _macroCache = {};
  String? _macroCacheAdapterSignature;
  bool _macroCacheCheckInFlight = false;

  @override
  void initState() {
    super.initState();
    _adaptersFuture = _repositoryService.fetchAdaptersIndex(
      widget.source,
      widget.school,
      options: widget.fetchOptions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(widget.school.name),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: FutureBuilder<WarehouseAdaptersIndex>(
            future: _adaptersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${snapshot.error}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final adapters =
                  snapshot.data?.adapters ?? const <WarehouseAdapterEntry>[];
              // 检查每个适配器是否有宏录制
              _scheduleMacroCacheCheck(adapters);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  HyperosListGroup(
                    children: [
                      for (final adapter in adapters)
                        _buildWarehouseAdapterListItem(
                          context: context,
                          adapter: adapter,
                          hasMacro: _macroCache[adapter.adapterId] ?? false,
                          importButtonLabel: adapter.importUrl.isEmpty
                              ? '填写网址后导入'
                              : '网页登录导入',
                          recordButtonLabel: adapter.importUrl.isEmpty
                              ? '填写网址后录制'
                              : '录制导入',
                          onImport: () => _openAdapterImport(adapter),
                          onRecord: () =>
                              _openAdapterImport(adapter, autoRecord: true),
                          onInfo: () async {
                            final imported = await Navigator.of(context).push<bool>(
                              HyperosPageRoute(
                                settings: RouteSettings(
                                  name:
                                      '/courses/import/warehouse/${widget.school.id}/${adapter.adapterId}',
                                ),
                                builder: (_) => WarehouseAdapterDetailScreen(
                                  source: widget.source,
                                  school: widget.school,
                                  adapter: adapter,
                                  fetchOptions: widget.fetchOptions,
                                ),
                              ),
                            );
                            if (imported == true && context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                          onQuickImport: () => _openQuickImport(adapter),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openAdapterImport(
    WarehouseAdapterEntry adapter, {
    bool autoRecord = false,
  }) async {
    final initialUrl = await _resolveAdapterImportUrl(adapter);
    if (initialUrl == null || !mounted) {
      return;
    }
    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/courses/import/warehouse/login'),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: adapter.adapterName,
          initialUrl: initialUrl,
          source: widget.source,
          school: widget.school,
          adapter: adapter,
          fetchOptions: widget.fetchOptions,
          autoRecord: autoRecord,
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
    // 从导入/录制页面返回后刷新单适配器的宏缓存
    if (mounted) {
      await _refreshMacroCacheForAdapter(adapter.adapterId);
    }
  }

  Future<String?> _resolveAdapterImportUrl(
    WarehouseAdapterEntry adapter,
  ) async {
    final custom = await _preferencesService.getCustomImportUrl(
      adapter.adapterId,
    );
    final effectiveUrl = resolveWarehouseImportUrl(
      customImportUrl: custom,
      defaultUrl: adapter.importUrl,
    );
    if (effectiveUrl != null) {
      return effectiveUrl;
    }
    if (!mounted) {
      return null;
    }
    final manualUrl = await _promptWarehouseImportUrl(
      context,
      schoolName: widget.school.name,
      adapterName: adapter.adapterName,
    );
    if (manualUrl == null) {
      return null;
    }
    await _preferencesService.setCustomImportUrl(adapter.adapterId, manualUrl);
    if (mounted) {
      _showLightTip(context, AppLocalizations.of(context)!.savedImportUrlHint);
    }
    return manualUrl;
  }

  // ============ 宏录制快捷导入 ============

  void _scheduleMacroCacheCheck(List<WarehouseAdapterEntry> adapters) {
    final signature = _macroCacheSignatureForAdapters(adapters);
    final hasAllValues = adapters.every(
      (adapter) => _macroCache.containsKey(adapter.adapterId),
    );
    if (_macroCacheCheckInFlight ||
        (_macroCacheAdapterSignature == signature && hasAllValues)) {
      return;
    }
    _macroCacheCheckInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _checkMacrosForAdapters(adapters, signature);
    });
  }

  String _macroCacheSignatureForAdapters(List<WarehouseAdapterEntry> adapters) {
    return '${widget.school.id}|${adapters.map((a) => a.adapterId).join('|')}';
  }

  Future<void> _checkMacrosForAdapters(
    List<WarehouseAdapterEntry> adapters,
    String signature,
  ) async {
    final nextCache = <String, bool>{};
    try {
      for (final adapter in adapters) {
        final has = await _macroService.hasMacro(
          widget.school.id,
          adapter.adapterId,
        );
        if (!mounted) return;
        nextCache[adapter.adapterId] = has;
      }
    } catch (_) {
      if (mounted) {
        _macroCacheCheckInFlight = false;
      }
      return;
    }
    if (!mounted) return;

    final changed =
        _macroCacheAdapterSignature != signature ||
        _macroCache.length != nextCache.length ||
        nextCache.entries.any((entry) => _macroCache[entry.key] != entry.value);
    if (!changed) {
      _macroCacheAdapterSignature = signature;
      _macroCacheCheckInFlight = false;
      return;
    }

    setState(() {
      _macroCache
        ..clear()
        ..addAll(nextCache);
      _macroCacheAdapterSignature = signature;
      _macroCacheCheckInFlight = false;
    });
  }

  Future<void> _refreshMacroCacheForAdapter(String adapterId) async {
    final has = await _macroService.hasMacro(widget.school.id, adapterId);
    if (!mounted) return;
    if (_macroCache[adapterId] != has) {
      setState(() {
        _macroCache[adapterId] = has;
      });
    }
  }

  Future<void> _openQuickImport(WarehouseAdapterEntry adapter) async {
    final initialUrl = await _resolveAdapterImportUrl(adapter);
    if (!mounted || initialUrl == null) return;

    final macro = await _macroService.getMacro(
      widget.school.id,
      adapter.adapterId,
    );
    if (!mounted) return;
    if (macro == null) {
      _showLightTip(context, '未找到录制记录，请先完成一次录制');
      return;
    }

    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/quick-import',
        ),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: '快捷导入 - ${adapter.adapterName}',
          initialUrl: initialUrl,
          source: widget.source,
          school: widget.school,
          adapter: adapter,
          fetchOptions: widget.fetchOptions,
          macroRecord: macro,
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
    if (mounted) {
      await _refreshMacroCacheForAdapter(adapter.adapterId);
    }
  }
}

class WarehouseAdapterDetailScreen extends StatefulWidget {
  final WarehouseRepositorySource source;
  final WarehouseSchoolEntry school;
  final WarehouseAdapterEntry adapter;
  final WarehouseFetchOptions fetchOptions;

  const WarehouseAdapterDetailScreen({
    super.key,
    required this.source,
    required this.school,
    required this.adapter,
    required this.fetchOptions,
  });

  @override
  State<WarehouseAdapterDetailScreen> createState() =>
      _WarehouseAdapterDetailScreenState();
}

class _WarehouseAdapterDetailScreenState
    extends State<WarehouseAdapterDetailScreen> {
  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  late Future<String> _scriptFuture;
  String? _customImportUrl;

  @override
  void initState() {
    super.initState();
    _scriptFuture = _repositoryService.fetchAdapterScript(
      widget.source,
      school: widget.school,
      adapter: widget.adapter,
      options: widget.fetchOptions,
    );
    _loadCustomImportUrl();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final adapter = widget.adapter;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(adapter.adapterName),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _WarehouseIntroCard(
                title: adapter.adapterName,
                subtitle: adapter.description.isEmpty
                    ? l10n.adapterIntroSubtitle
                    : '',
                chips: [
                  '${l10n.schoolLabel}：${widget.school.name}',
                  '${l10n.categoryLabel}：${adapter.category}',
                  '${l10n.maintainerLabel}：${adapter.maintainer}',
                ],
                markdown: adapter.description.isEmpty
                    ? null
                    : adapter.description,
              ),
              const SizedBox(height: 16),
              _ImportSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adapterInfoTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailLine(label: 'adapter_id', value: adapter.adapterId),
                    _DetailLine(
                      label: l10n.scriptPathLabel,
                      value: adapter.assetJsPath,
                    ),
                    _DetailLine(
                      label: l10n.loginEntryLabel,
                      value: _effectiveImportUrl.isEmpty
                          ? l10n.unsetConfigLabel
                          : _effectiveImportUrl,
                    ),
                    if ((_customImportUrl ?? '').isNotEmpty)
                      _DetailLine(
                        label: l10n.homeWidgetDescriptionTitle,
                        value: l10n.adapterOverrideImportUrlHint,
                      ),
                    _DetailLine(
                      label: l10n.repositoryLabel,
                      value: widget.source.repositoryUrl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<String>(
                future: _scriptFuture,
                builder: (context, snapshot) {
                  final readable =
                      snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasError &&
                      (snapshot.data?.trim().isNotEmpty ?? false);
                  return _ImportSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.scriptStatusTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const LinearProgressIndicator(minHeight: 3)
                        else if (readable)
                          Text(
                            l10n.scriptLoadedLength(snapshot.data!.length),
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          Text(
                            snapshot.hasError
                                ? '${snapshot.error}'
                                : l10n.scriptEmpty,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              HyperosButton(
                label: _effectiveImportUrl.isEmpty
                    ? l10n.fillUrlThenImport
                    : l10n.openLoginInAppAction,
                expand: true,
                onPressed: () => _openInAppLogin(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  HyperosButton(
                    label: l10n.openInSystemBrowserAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _effectiveImportUrl.isEmpty
                        ? null
                        : () => _openImportUrl(_effectiveImportUrl),
                  ),
                  HyperosButton(
                    label: l10n.copyLoginAddressAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _effectiveImportUrl.isEmpty
                        ? null
                        : () => _copyText(
                            _effectiveImportUrl,
                            successMessage: l10n.copiedImportLoginUrl,
                          ),
                  ),
                  HyperosButton(
                    label: l10n.copyScriptAddressAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: () => _copyText(
                      widget.source
                          .buildRawFileUri(
                            'resources/${widget.school.resourceFolder}/${adapter.assetJsPath}',
                          )
                          .toString(),
                      successMessage: l10n.copiedScriptRawUrl,
                    ),
                  ),
                  HyperosButton(
                    label: (_customImportUrl ?? '').isEmpty
                        ? l10n.customLoginAddressAction
                        : l10n.editCustomLoginAddressAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _editCustomImportUrl,
                  ),
                  if ((_customImportUrl ?? '').isNotEmpty)
                    HyperosButton(
                      label: adapter.importUrl.isEmpty
                          ? l10n.clearCustomLoginAddressAction
                          : l10n.restoreRepositoryAddressAction,
                      variant: HyperosButtonVariant.secondary,
                      onPressed: _clearCustomImportUrl,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _effectiveImportUrl => (_customImportUrl ?? '').trim().isNotEmpty
      ? _customImportUrl!.trim()
      : widget.adapter.importUrl;

  Future<void> _loadCustomImportUrl() async {
    final custom = await _preferencesService.getCustomImportUrl(
      widget.adapter.adapterId,
    );
    if (!mounted) return;
    setState(() {
      _customImportUrl = custom;
    });
  }

  Future<void> _openImportUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      _showLightTip(
        context,
        AppLocalizations.of(context)!.invalidLoginEntryUrl,
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openInAppLogin() async {
    var targetUrl = _effectiveImportUrl.trim();
    if (targetUrl.isEmpty) {
      final manualUrl = await _promptWarehouseImportUrl(
        context,
        schoolName: widget.school.name,
        adapterName: widget.adapter.adapterName,
      );
      if (manualUrl == null) {
        return;
      }
      await _preferencesService.setCustomImportUrl(
        widget.adapter.adapterId,
        manualUrl,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _customImportUrl = manualUrl;
      });
      _showLightTip(context, AppLocalizations.of(context)!.savedImportUrlHint);
      targetUrl = manualUrl;
    }
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      _showLightTip(
        context,
        AppLocalizations.of(context)!.invalidLoginEntryUrl,
      );
      return;
    }
    await Navigator.of(context)
        .push(
          HyperosPageRoute(
            settings: const RouteSettings(
              name: '/courses/import/warehouse/login',
            ),
            builder: (_) => WarehouseAdapterWebLoginScreen(
              title: widget.adapter.adapterName,
              initialUrl: targetUrl,
              source: widget.source,
              school: widget.school,
              adapter: widget.adapter,
              fetchOptions: widget.fetchOptions,
            ),
          ),
        )
        .then((imported) {
          if (imported == true && mounted) {
            Navigator.of(context).pop(true);
          }
        });
  }

  Future<void> _editCustomImportUrl() async {
    final result = await _promptWarehouseImportUrl(
      context,
      schoolName: widget.school.name,
      adapterName: widget.adapter.adapterName,
      initialValue: _effectiveImportUrl,
    );
    if (result == null) return;
    await _preferencesService.setCustomImportUrl(
      widget.adapter.adapterId,
      result,
    );
    if (!mounted) return;
    setState(() {
      _customImportUrl = result;
    });
    _showLightTip(
      context,
      AppLocalizations.of(context)!.savedCustomLoginAddress,
    );
  }

  Future<void> _clearCustomImportUrl() async {
    await _preferencesService.clearCustomImportUrl(widget.adapter.adapterId);
    if (!mounted) return;
    setState(() {
      _customImportUrl = null;
    });
    _showLightTip(
      context,
      widget.adapter.importUrl.isEmpty
          ? AppLocalizations.of(context)!.clearedCustomLoginAddress
          : AppLocalizations.of(context)!.restoredRepositoryImportUrl,
    );
  }

  Future<void> _copyText(String value, {required String successMessage}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    _showLightTip(context, successMessage);
  }
}

class WarehouseAdapterWebLoginScreen extends StatefulWidget {
  final String title;
  final String initialUrl;
  final WarehouseRepositorySource source;
  final WarehouseSchoolEntry school;
  final WarehouseAdapterEntry adapter;
  final WarehouseFetchOptions fetchOptions;
  final String? debugScriptOverride;
  final String? debugScriptName;
  final WarehouseMacroRecord? macroRecord;
  final bool autoRecord;

  const WarehouseAdapterWebLoginScreen({
    super.key,
    required this.title,
    required this.initialUrl,
    required this.source,
    required this.school,
    required this.adapter,
    required this.fetchOptions,
    this.debugScriptOverride,
    this.debugScriptName,
    this.macroRecord,
    this.autoRecord = false,
  });

  @override
  State<WarehouseAdapterWebLoginScreen> createState() =>
      _WarehouseAdapterWebLoginScreenState();
}

class _WarehouseAdapterWebLoginScreenState
    extends State<WarehouseAdapterWebLoginScreen> {
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  static const String _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; 25060RK16C) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  final ImportWeekAlignmentService _weekAlignmentService =
      const ImportWeekAlignmentService();
  late final WebViewController _controller;
  late final TextEditingController _addressController;
  final FocusNode _addressFocusNode = FocusNode();
  int _loadingProgress = 0;
  String? _currentUrl;
  bool _isExecutingImport = false;
  Timer? _importTimeoutTimer;
  static const _importTimeout = Duration(seconds: 30);
  String? _lastScriptStatus;
  List<SectionTime>? _pendingImportedSections;
  String? _pendingImportedSectionsSignature;
  String? _appliedImportedSectionsSignature;
  Future<void>? _pendingImportedSectionsApplyFuture;
  WarehouseRememberedLogin? _rememberedLogin;
  WarehouseRememberedLogin? _latestLoginCandidate;
  bool _hasPromptedAutofill = false;
  bool _hasPromptedSave = false;
  bool _isPromptShowing = false;
  bool _useDesktopMode = true;

  // --- 宏录制相关 ---
  final WarehouseMacroService _macroService = WarehouseMacroService();
  MacroRecordingState _macroRecordingState = MacroRecordingState.idle;
  List<Map<String, dynamic>> _macroRawEvents = [];
  final Map<String, dynamic> _macroDialogResponses = {};

  /// 根据弹窗类型和内容生成匹配 key，用于录制时关联操作和回放时自动响应
  String _dialogResponseKey(String type, Map<String, dynamic> message) =>
      warehouseDialogResponseKey(type, message);

  // --- 宏回放相关 ---
  PlaybackUiState _playbackState = PlaybackUiState.hidden;
  ReplayProgress _playbackProgress = const ReplayProgress(
    currentStepIndex: 0,
    totalSteps: 0,
    currentStep: MacroStep(type: MacroStepType.delay, waitMs: 0),
    status: ReplayStepStatus.pending,
  );
  WarehouseMacroReplayer? _replayer;

  bool get _isUsingLocalDebugScript =>
      (widget.debugScriptOverride ?? '').trim().isNotEmpty;

  void _debugImportLog(String message) {
    if (!kDebugMode) return;
    appDebugLog(
      'WarehouseImportDebug',
      'macro=$_isMacroReplay '
          'playback=$_playbackState '
          'executing=$_isExecutingImport '
          'recording=$_macroRecordingState '
          'status="${_lastScriptStatus ?? ''}" '
          '$message',
    );
  }

  String _bridgeMessageSummary(Map<String, dynamic> message) {
    final type = message['type'];
    final keys = message.keys.join(',');
    final payload = message['payload'];
    final payloadLength = payload is String ? payload.length : null;
    final errorMessage = message['message'];
    return 'type=$type keys=[$keys] payloadLength=$payloadLength message=$errorMessage';
  }

  @override
  void initState() {
    super.initState();
    _useDesktopMode = widget.macroRecord?.useDesktopMode ?? true;
    _currentUrl = widget.initialUrl;
    _addressController = TextEditingController(text: widget.initialUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setUserAgent(_useDesktopMode ? _desktopUserAgent : _mobileUserAgent)
      ..addJavaScriptChannel(
        'QingyuBridge',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentUrl = url;
              _hasPromptedAutofill = false;
              if (!_addressFocusNode.hasFocus) {
                _addressController.text = url;
              }
            });
          },
          onPageFinished: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentUrl = url;
              _loadingProgress = 100;
              if (!_addressFocusNode.hasFocus) {
                _addressController.text = url;
              }
            });
            // 先注入录制 JS（如果在录制中），再探测登录状态——这样填充事件也能被录制到
            if (_macroRecordingState == MacroRecordingState.recording) {
              _injectMacroRecorderJs();
            }
            _requestLoginStateProbe();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
    _loadRememberedLogin();

    // 如果是自动录制模式，延迟一帧后自动开始录制
    if (widget.autoRecord && widget.macroRecord == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMacroRecording();
      });
    }

    // 如果是回放模式，延迟一帧后自动开始
    if (widget.macroRecord != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startPlayback(widget.macroRecord!);
      });
    }
  }

  @override
  void dispose() {
    _replayer?.cancel();
    _replayContinueCompleter?.complete(false);
    _replayContinueCompleter = null;
    _importTimeoutTimer?.cancel();
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _resetPendingImportedArtifacts() {
    _pendingImportedSections = null;
    _pendingImportedSectionsSignature = null;
    _appliedImportedSectionsSignature = null;
    _pendingImportedSectionsApplyFuture = null;
  }

  String _buildSectionSignature(List<SectionTime> sections) => sections
      .map((section) => '${section.startTime}-${section.endTime}')
      .join('|');

  List<SectionTime> _decodeImportedSections(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! List) {
      throw FormatException(
        AppLocalizations.of(context)!.invalidSectionTimeFormat,
      );
    }
    final sections = decoded
        .whereType<Map>()
        .map(
          (item) => SectionTime(
            startTime: item['startTime']?.toString() ?? '',
            endTime: item['endTime']?.toString() ?? '',
          ),
        )
        .where((item) => item.startTime.isNotEmpty && item.endTime.isNotEmpty)
        .toList(growable: false);
    if (sections.isEmpty) {
      throw FormatException(AppLocalizations.of(context)!.noSectionTimesToSave);
    }
    return sections;
  }

  Future<void> _waitForCompanionImportSections() async {
    if (_pendingImportedSections != null) {
      return;
    }
    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_pendingImportedSections != null) {
        return;
      }
    }
  }

  Future<void> _applyImportedSections(List<SectionTime> sections) async {
    final provider = context.read<TimetableProvider>();
    final schemeName = AppLocalizations.of(
      context,
    )!.warehouseImportedTimeSchemeName(widget.school.name);
    TimeScheme? existingScheme;
    for (final scheme in provider.timeSchemes) {
      if (scheme.name == schemeName) {
        existingScheme = scheme;
        break;
      }
    }
    if (existingScheme == null) {
      final created = await provider.createTimeScheme(
        name: schemeName,
        sections: sections,
        applyToActiveProfile: true,
      );
      await provider.applyTimeScheme(created.id);
      return;
    }
    final result = await provider.updateTimeScheme(
      schemeId: existingScheme.id,
      name: existingScheme.name,
      sections: sections,
    );
    if (result != null) {
      throw FormatException(result);
    }
    await provider.applyTimeScheme(existingScheme.id);
  }

  Future<void> _applyPendingImportedSectionsIfNeeded() async {
    final sections = _pendingImportedSections;
    final signature = _pendingImportedSectionsSignature;
    if (sections == null || sections.isEmpty) {
      return;
    }
    if (signature != null && signature == _appliedImportedSectionsSignature) {
      return;
    }
    final inFlight = _pendingImportedSectionsApplyFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _applyImportedSections(sections);
    _pendingImportedSectionsApplyFuture = future;
    try {
      await future;
      _appliedImportedSectionsSignature = signature;
    } finally {
      if (identical(_pendingImportedSectionsApplyFuture, future)) {
        _pendingImportedSectionsApplyFuture = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveDebugScriptName =
        (widget.debugScriptName?.trim().isNotEmpty ?? false)
        ? widget.debugScriptName!.trim()
        : l10n.unnamedScript;
    final currentStatus =
        _lastScriptStatus ??
        (_isUsingLocalDebugScript
            ? l10n.localDebugModeScriptStatus(effectiveDebugScriptName)
            : null);
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(widget.title),
      suffixes: [
        FHeaderAction(
          icon: _macroRecordingState == MacroRecordingState.recording
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  ),
                )
              : const Icon(Icons.fiber_manual_record_rounded),
          semanticsLabel: _macroRecordingState == MacroRecordingState.recording
              ? '停止录制'
              : '录制操作',
          onPress: _isExecutingImport ? null : _toggleMacroRecording,
        ),
        if (widget.macroRecord == null)
          FHeaderAction(
            icon: Icon(
              _useDesktopMode
                  ? Icons.smartphone_rounded
                  : Icons.desktop_windows_rounded,
            ),
            semanticsLabel: _useDesktopMode
                ? l10n.switchToMobileWebTooltip
                : l10n.switchToDesktopWebTooltip,
            onPress: _toggleWebPageMode,
          ),
        FHeaderAction(
          icon: const Icon(Icons.refresh_rounded),
          semanticsLabel: l10n.reloadAction,
          onPress: _controller.reload,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) async {
            switch (value) {
              case 'execute':
                _executeImportScript();
                break;
              case 'remember':
                _rememberCurrentLogin();
                break;
              case 'fill':
                _autofillRememberedLogin();
                break;
              case 'clear':
                _clearRememberedLogin();
                break;
              case 'copy':
                final url = _currentUrl ?? widget.initialUrl;
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  showAppToast(
                    context,
                    message: l10n.copiedCurrentAddress,
                    kind: AppToastKind.success,
                  );
                }
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'execute',
              child: ListTile(
                leading: _isExecutingImport
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                title: Text(l10n.executeImportScriptAction),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                enabled: !_isExecutingImport,
              ),
            ),
            PopupMenuItem(
              value: 'remember',
              child: ListTile(
                leading: const Icon(Icons.save_outlined),
                title: Text(l10n.rememberCurrentInputTooltip),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            PopupMenuItem(
              value: 'fill',
              child: ListTile(
                leading: const Icon(Icons.password_rounded),
                title: Text(l10n.fillRememberedTooltip),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                enabled: _rememberedLogin != null,
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(l10n.clearRememberedTooltip),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                enabled: _rememberedLogin != null,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'copy',
              child: ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(l10n.copyCurrentAddressTooltip),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ],
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosBlurredBodyInset(
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    color: context.theme.colors.muted,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 模式标识 + 提示文字（紧凑单行）
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.theme.colors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _useDesktopMode ? '🖥️' : '📱',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _isUsingLocalDebugScript
                                    ? l10n.warehouseLoginHintLocalDebug
                                    : l10n.warehouseLoginHintImport,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isUsingLocalDebugScript)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  effectiveDebugScriptName,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onTertiaryContainer,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // URL 地址栏
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _addressController,
                                focusNode: _addressFocusNode,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.go,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: l10n.webAddressHint,
                                  prefixIcon: const Icon(
                                    Icons.language_rounded,
                                    size: 18,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onSubmitted: (_) => _loadAddressBarUrl(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            HyperosButton(
                              label: l10n.goAction,
                              onPressed: _loadAddressBarUrl,
                            ),
                          ],
                        ),
                        // 状态/提示行
                        if ((currentStatus ?? '').isNotEmpty ||
                            _rememberedLogin != null ||
                            (_macroRecordingState ==
                                MacroRecordingState.recording) ||
                            (_macroRecordingState ==
                                    MacroRecordingState.stopped &&
                                _lastScriptStatus != null))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _lastScriptStatus ??
                                  currentStatus ??
                                  (_rememberedLogin != null
                                      ? l10n.rememberedAccountLabel(
                                          _rememberedLogin!.username,
                                        )
                                      : ''),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_loadingProgress < 100)
                    LinearProgressIndicator(value: _loadingProgress / 100),
                  Expanded(child: WebViewWidget(controller: _controller)),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: HyperosButton(
                        label: _isExecutingImport
                            ? l10n.importingAction
                            : (_isUsingLocalDebugScript
                                  ? l10n.executeLocalDebugScriptAction
                                  : l10n.executeImportScriptAction),
                        expand: true,
                        loading: _isExecutingImport,
                        onPressed: _isExecutingImport
                            ? null
                            : _executeImportScript,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: PlaybackOverlay(
                  progress: _playbackProgress,
                  state: _playbackState,
                  schoolName: widget.school.name,
                  adapterName: widget.adapter.adapterName,
                  onCancel: _cancelPlayback,
                  onRetry: _retryPlayback,
                  onDismiss: _dismissPlaybackResult,
                  onContinueAfterPause: _resumePlaybackAfterPause,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadAddressBarUrl() async {
    final text = _addressController.text.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      if (!mounted) return;
      _showLightTip(context, AppLocalizations.of(context)!.invalidWebAddress);
      return;
    }
    _addressFocusNode.unfocus();
    setState(() {
      _currentUrl = uri.toString();
      _loadingProgress = 0;
    });
    await _controller.loadRequest(uri);
  }

  Future<void> _toggleWebPageMode() async {
    final nextDesktopMode = !_useDesktopMode;
    setState(() {
      _useDesktopMode = nextDesktopMode;
      _loadingProgress = 0;
    });
    await _controller.setUserAgent(
      nextDesktopMode ? _desktopUserAgent : _mobileUserAgent,
    );
    final target = Uri.tryParse(_currentUrl ?? widget.initialUrl);
    if (target != null) {
      await _controller.loadRequest(target);
    }
  }

  Future<void> _installLoginWatcher() async {
    try {
      await _controller.runJavaScript('''
(() => {
  const collect = () => {
    const textInputs = Array.from(document.querySelectorAll('input')).filter((input) => {
      const type = (input.type || 'text').toLowerCase();
      return ['text','email','tel','number'].includes(type) && !input.disabled;
    });
    const passwordInput = Array.from(document.querySelectorAll('input[type="password"]')).find((input) => !input.disabled);
    QingyuBridge.postMessage(JSON.stringify({
      type: 'loginState',
      username: textInputs[0] ? String(textInputs[0].value || '') : '',
      password: passwordInput ? String(passwordInput.value || '') : '',
      hasPasswordField: !!passwordInput
    }));
  };
  window.__qingyuCollectLoginState = collect;
  if (!window.__qingyuLoginWatcherInstalled) {
    window.__qingyuLoginWatcherInstalled = true;
    document.addEventListener('input', (event) => {
      if (event.target && event.target.tagName === 'INPUT') collect();
    }, true);
    document.addEventListener('change', (event) => {
      if (event.target && event.target.tagName === 'INPUT') collect();
    }, true);
    document.addEventListener('click', (event) => {
      const target = event.target;
      if (!(target instanceof HTMLElement)) return;
      const text = (target.innerText || target.textContent || target.value || '').trim().toLowerCase();
      if (/登录|login|sign in|signin|进入教务|提交/.test(text)) {
        collect();
        QingyuBridge.postMessage(JSON.stringify({ type: 'loginAttempt' }));
      }
    }, true);
    document.addEventListener('submit', () => {
      collect();
      QingyuBridge.postMessage(JSON.stringify({ type: 'loginAttempt' }));
    }, true);
    let loginProbeTimer = null;
    const scheduleCollect = () => {
      window.clearTimeout(loginProbeTimer);
      loginProbeTimer = window.setTimeout(collect, 120);
    };
    const observer = new MutationObserver(scheduleCollect);
    observer.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['type', 'disabled', 'style', 'class']
    });
  }
  collect();
  window.setTimeout(collect, 0);
  window.setTimeout(collect, 300);
  window.setTimeout(collect, 1000);
  window.setTimeout(collect, 2000);
})();
''');
    } catch (_) {}
  }

  Future<void> _requestLoginStateProbe() async {
    await _installLoginWatcher();
    try {
      await _controller.runJavaScript('window.__qingyuCollectLoginState?.();');
    } catch (_) {}
  }

  void _startImportTimeout() {
    _debugImportLog('start import timeout duration=$_importTimeout');
    _importTimeoutTimer?.cancel();
    _importTimeoutTimer = Timer(_importTimeout, () {
      _debugImportLog(
        'import timeout fired mounted=$mounted shouldRun=${mounted && _isExecutingImport}',
      );
      if (!mounted || !_isExecutingImport) return;
      final waitingForMacroCourses =
          _isMacroReplay && _playbackState == PlaybackUiState.executingImport;
      final message = waitingForMacroCourses
          ? '导入脚本未返回课程数据'
          : AppLocalizations.of(context)!.executeFailedWithError('timeout');
      _debugImportLog(
        'timeout -> mark import failed waitingForMacroCourses=$waitingForMacroCourses message="$message"',
      );
      setState(() {
        _isExecutingImport = false;
        _lastScriptStatus = waitingForMacroCourses
            ? message
            : AppLocalizations.of(context)!.scriptInjectionFailed;
      });
      _showMacroReplayImportError(message);
      _showLightTip(context, message);
    });
  }

  void _cancelImportTimeout() {
    _debugImportLog(
      'cancel import timeout hadTimer=${_importTimeoutTimer != null}',
    );
    _importTimeoutTimer?.cancel();
    _importTimeoutTimer = null;
  }

  bool get _isMacroReplay => widget.macroRecord != null;

  void _showMacroReplayImportError(String message) {
    if (kDebugMode) {
      _debugImportLog(
        'show macro replay error message="$message"\n${StackTrace.current}',
      );
    }
    if (!_isMacroReplay || !mounted) return;
    setState(() {
      _playbackProgress = ReplayProgress(
        currentStepIndex: _playbackProgress.currentStepIndex,
        totalSteps: _playbackProgress.totalSteps == 0
            ? 1
            : _playbackProgress.totalSteps,
        currentStep: MacroStep.executeScript,
        status: ReplayStepStatus.failed,
        errorMessage: message,
      );
      _playbackState = PlaybackUiState.error;
    });
  }

  Future<void> _markMacroImportCompleted({
    required bool countSuccessfulImport,
  }) async {
    _debugImportLog(
      'mark macro import completed countSuccessfulImport=$countSuccessfulImport',
    );
    if (!_isMacroReplay) return;
    if (countSuccessfulImport) {
      final existing = await _macroService.getMacro(
        widget.school.id,
        widget.adapter.adapterId,
      );
      if (existing != null) {
        await _macroService.saveMacro(
          existing.copyWith(
            successfulImportCount: existing.successfulImportCount + 1,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _playbackState = PlaybackUiState.finished;
    });
  }

  Future<void> _executeImportScript() async {
    final l10n = AppLocalizations.of(context)!;
    _debugImportLog('execute import script start');
    _resetPendingImportedArtifacts();
    setState(() {
      _isExecutingImport = true;
      _lastScriptStatus = _isUsingLocalDebugScript
          ? l10n.injectingLocalDebugScript
          : l10n.injectingAdapterScript;
    });
    try {
      final script = _isUsingLocalDebugScript
          ? widget.debugScriptOverride!.trim()
          : await _repositoryService.fetchAdapterScript(
              widget.source,
              school: widget.school,
              adapter: widget.adapter,
              options: widget.fetchOptions,
            );
      final wrappedScript =
          '''
(() => {
  window.__qingyuResolvers = window.__qingyuResolvers || {};
  window.AndroidBridge = {
    showToast: (msg) => QingyuBridge.postMessage(JSON.stringify({type: 'toast', message: String(msg ?? '')})),
    notifyTaskCompletion: () => QingyuBridge.postMessage(JSON.stringify({type: 'complete'}))
  };
  window.AndroidBridgePromise = {
    showAlert: async (title, message, confirmText) => {
      const requestId = 'confirm_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'confirm',
          requestId,
          title: String(title ?? ''),
          message: String(message ?? ''),
          confirmText: String(confirmText ?? '${l10n.confirmImportAction}')
        }));
      });
    },
    showPrompt: async (title, message, defaultValue, validatorName) => {
      const requestId = 'prompt_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'prompt',
          requestId,
          title: String(title ?? ''),
          message: String(message ?? ''),
          defaultValue: String(defaultValue ?? ''),
          validatorName: String(validatorName ?? '')
        }));
      });
    },
    showSingleSelection: async (title, optionsJson, selectedIndex, dialogId) => {
      const requestId = 'single_selection_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'singleSelection',
          requestId,
          title: String(title ?? ''),
          optionsJson: String(optionsJson ?? '[]'),
          selectedIndex: Number(selectedIndex ?? 0),
          dialogId: dialogId ? String(dialogId) : undefined
        }));
      });
    },
    saveCourseConfig: async (json) => {
      const requestId = 'course_config_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'saveCourseConfig',
          requestId,
          payload: String(json ?? '{}')
        }));
      });
    },
    savePresetTimeSlots: async (json) => {
      const requestId = 'preset_time_slots_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'savePresetTimeSlots',
          requestId,
          payload: String(json ?? '[]')
        }));
      });
    },
    saveImportedCourses: async (json) => {
      QingyuBridge.postMessage(JSON.stringify({type: 'courses', payload: String(json ?? '[]')}));
      return true;
    }
  };
  try {
    $script
  } catch (error) {
    QingyuBridge.postMessage(JSON.stringify({type: 'error', message: String(error)}));
  }
})();
''';
      _debugImportLog('run import script scriptLength=${script.length}');
      await _controller.runJavaScript(wrappedScript);
      if (!mounted) {
        _debugImportLog('run import script finished after dispose');
        return;
      }
      _debugImportLog('run import script injected');
      setState(() {
        _lastScriptStatus = _isUsingLocalDebugScript
            ? AppLocalizations.of(context)!.localDebugScriptInjected
            : AppLocalizations.of(context)!.scriptInjected;
      });
      _startImportTimeout();
    } catch (error) {
      _debugImportLog('execute import script caught error=$error');
      if (!mounted) {
        return;
      }
      _cancelImportTimeout();
      final message = AppLocalizations.of(
        context,
      )!.executeFailedWithError('$error');
      setState(() {
        _isExecutingImport = false;
        _lastScriptStatus = AppLocalizations.of(context)!.scriptInjectionFailed;
      });
      _showMacroReplayImportError(message);
      _showLightTip(context, message);
    }
  }

  Future<void> _handleBridgeMessage(String rawMessage) async {
    Map<String, dynamic>? message;
    try {
      message = jsonDecode(rawMessage) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    _debugImportLog('bridge ${_bridgeMessageSummary(message)}');
    final type = message['type'] as String? ?? '';
    switch (type) {
      case 'macro:event':
        _handleMacroEvent(message);
        break;
      case 'loginState':
        await _handleLoginStateMessage(message);
        break;
      case 'loginAttempt':
        await _handleLoginAttempt();
        break;
      case 'toast':
        if (!mounted) return;
        _showLightTip(context, (message['message'] as String?) ?? '');
        break;
      case 'confirm':
        await _showScriptConfirmDialog(message);
        break;
      case 'prompt':
        await _showScriptPromptDialog(message);
        break;
      case 'singleSelection':
        await _showScriptSingleSelectionDialog(message);
        break;
      case 'saveCourseConfig':
        await _handleSaveCourseConfig(message);
        break;
      case 'savePresetTimeSlots':
        await _handleSavePresetTimeSlots(message);
        break;
      case 'error':
        if (!mounted) return;
        final errorMessage = (message['message'] as String?) ?? '脚本执行失败';
        _debugImportLog('bridge error -> mark failed message="$errorMessage"');
        _cancelImportTimeout();
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = '脚本执行失败';
        });
        _showMacroReplayImportError(errorMessage);
        _showLightTip(context, errorMessage);
        break;
      case 'courses':
        final payload = (message['payload'] as String?) ?? '[]';
        _debugImportLog(
          'bridge courses -> handle payloadLength=${payload.length}',
        );
        await _handleImportedCoursesJson(payload);
        break;
      case 'complete':
        if (!mounted) return;
        final status = AppLocalizations.of(context)!.importFlowFinished;
        _debugImportLog('bridge complete entered');
        if (_isMacroReplay) {
          if (_playbackState == PlaybackUiState.executingImport) {
            _debugImportLog(
              'bridge complete ignored for macro replay while waiting for courses',
            );
            setState(() {
              _lastScriptStatus = status;
            });
            break;
          }
          if (_playbackState == PlaybackUiState.finished) {
            _debugImportLog(
              'bridge complete ignored because macro replay already finished',
            );
            break;
          }
        }
        _debugImportLog('bridge complete -> finish non-macro import flow');
        _cancelImportTimeout();
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = status;
        });
        break;
    }
  }

  Future<void> _showScriptConfirmDialog(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    // 回放模式：使用录制的响应或自动确认
    final macroRecord = widget.macroRecord;
    if (macroRecord != null) {
      final key = _dialogResponseKey('confirm', message);
      final recorded = macroRecord.dialogResponses[key];
      await _resolveJavaScriptRequest(requestId, recorded == true);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: (message['title'] as String?)?.trim().isNotEmpty == true
          ? (message['title'] as String)
          : l10n.confirmImportAction,
      message: (message['message'] as String?) ?? l10n.defaultContinuePrompt,
      confirmLabel:
          (message['confirmText'] as String?) ?? l10n.confirmImportAction,
    );
    // 录制模式：记住用户的选择
    if (_macroRecordingState == MacroRecordingState.recording) {
      final key = _dialogResponseKey('confirm', message);
      _macroDialogResponses[key] = confirmed == true;
    }
    await _resolveJavaScriptRequest(requestId, confirmed == true);
  }

  Future<void> _showScriptPromptDialog(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    // 回放模式：使用录制的响应或默认值
    final macroRecord = widget.macroRecord;
    if (macroRecord != null) {
      final key = _dialogResponseKey('prompt', message);
      final recorded = macroRecord.dialogResponses[key];
      await _resolveJavaScriptRequest(
        requestId,
        '${recorded ?? (message['defaultValue'] as String? ?? '')}',
      );
      return;
    }
    final validatorName = (message['validatorName'] as String?) ?? '';
    final controller = TextEditingController(
      text: (message['defaultValue'] as String?) ?? '',
    );
    final l10n = AppLocalizations.of(context)!;
    final result = await showAppTextInputDialog(
      context,
      title: (message['title'] as String?) ?? l10n.inputRequiredTitle,
      confirmLabel: l10n.saveAction,
      readValue: () => controller.text,
      validate: (text) {
        if (validatorName == 'validateYearInput' &&
            !RegExp(r'^[0-9]{4}$').hasMatch(text)) {
          _showLightTip(context, l10n.pleaseEnterFourDigitYear);
          return false;
        }
        return true;
      },
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((message['message'] as String?) ?? ''),
          const SizedBox(height: 12),
          HyperosTextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
    // 录制模式：记住用户输入
    if (_macroRecordingState == MacroRecordingState.recording) {
      final key = _dialogResponseKey('prompt', message);
      if (result != null) _macroDialogResponses[key] = result;
    }
    await _resolveJavaScriptRequest(requestId, result);
  }

  Future<void> _showScriptSingleSelectionDialog(
    Map<String, dynamic> message,
  ) async {
    final requestId = (message['requestId'] as String?) ?? '';
    final macroRecord = widget.macroRecord;
    if (macroRecord != null) {
      final key = _dialogResponseKey('singleSelection', message);
      final recorded = macroRecord.dialogResponses[key];
      if (recorded != null) {
        await _resolveJavaScriptRequest(requestId, '$recorded');
        return;
      }
    }
    final optionsRaw = (message['optionsJson'] as String?) ?? '[]';
    final selectedIndex = (message['selectedIndex'] as num?)?.toInt() ?? 0;
    List<String> options = const [];
    try {
      final decoded = jsonDecode(optionsRaw);
      if (decoded is List) {
        options = decoded
            .map((item) => item.toString())
            .toList(growable: false);
      }
    } catch (_) {}
    var currentSelection = selectedIndex.clamp(
      0,
      options.isEmpty ? 0 : options.length - 1,
    );
    final l10n = AppLocalizations.of(context)!;
    final result = await showAppSingleChoiceDialog(
      context,
      title: (message['title'] as String?) ?? l10n.pleaseChooseTitle,
      options: options,
      initialIndex: currentSelection,
      confirmLabel: l10n.saveAction,
    );
    // 录制模式：记住用户的选择
    if (_macroRecordingState == MacroRecordingState.recording &&
        result != null &&
        options.isNotEmpty) {
      final key = _dialogResponseKey('singleSelection', message);
      if (result >= 0 && result < options.length) {
        _macroDialogResponses[key] = options[result];
      }
    }
    await _resolveJavaScriptRequest(requestId, result);
  }

  Future<void> _handleSaveCourseConfig(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    try {
      final decoded = jsonDecode((message['payload'] as String?) ?? '{}');
      if (decoded is! Map) {
        throw FormatException(
          AppLocalizations.of(context)!.invalidCourseConfigFormat,
        );
      }
      final provider = context.read<TimetableProvider>();
      final semesterTotalWeeks = (decoded['semesterTotalWeeks'] as num?)
          ?.toInt();
      if (semesterTotalWeeks != null && semesterTotalWeeks > 0) {
        final result = await provider.updateTimetableSettings(
          provider.settings.copyWith(semesterWeekCount: semesterTotalWeeks),
        );
        if (result != null) {
          throw FormatException(result);
        }
      }
      await _resolveJavaScriptRequest(requestId, true);
    } catch (error) {
      if (!mounted) return;
      _showLightTip(
        context,
        AppLocalizations.of(context)!.saveCourseConfigFailedWithError('$error'),
      );
      await _resolveJavaScriptRequest(requestId, false);
    }
  }

  Future<void> _handleSavePresetTimeSlots(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    try {
      final sections = _decodeImportedSections(
        (message['payload'] as String?) ?? '[]',
      );
      _pendingImportedSections = sections;
      _pendingImportedSectionsSignature = _buildSectionSignature(sections);
      await _applyPendingImportedSectionsIfNeeded();
      await _resolveJavaScriptRequest(requestId, true);
    } catch (error) {
      if (!mounted) return;
      _showLightTip(
        context,
        AppLocalizations.of(context)!.saveSectionTimesFailedWithError('$error'),
      );
      await _resolveJavaScriptRequest(requestId, false);
    }
  }

  Future<void> _resolveJavaScriptRequest(
    String requestId,
    Object? value,
  ) async {
    final encoded = jsonEncode(value);
    await _controller.runJavaScript(
      "window.__qingyuResolvers = window.__qingyuResolvers || {}; "
      "window.__qingyuResolvers['$requestId']?.($encoded); "
      "delete window.__qingyuResolvers['$requestId'];",
    );
  }

  Future<void> _handleImportedCoursesJson(String payload) async {
    _debugImportLog('handle courses start payloadLength=${payload.length}');
    try {
      final decoded = jsonDecode(payload);
      _debugImportLog('courses decoded type=${decoded.runtimeType}');
      if (decoded is! List) {
        throw FormatException(
          AppLocalizations.of(context)!.invalidCourseDataFormat,
        );
      }
      final parsedCourses = _parseWarehouseCourses(decoded);
      _debugImportLog('courses parsed count=${parsedCourses.length}');
      if (parsedCourses.isEmpty) {
        throw FormatException(
          AppLocalizations.of(context)!.noImportableCoursesFromScript,
        );
      }

      final provider = context.read<TimetableProvider>();
      // 回放/录制模式：使用录制的替换/合并选择
      bool? recordedReplaceExisting;
      _ImportSemesterConfig? recordedSemesterConfig;
      final recording = _macroRecordingState == MacroRecordingState.recording;
      final replaying = widget.macroRecord != null;

      if (replaying) {
        final r = widget.macroRecord!.dialogResponses['replaceExisting'];
        if (r is bool) recordedReplaceExisting = r;
        final s = widget.macroRecord!.dialogResponses['semesterConfig'];
        if (s is Map) {
          final startDate = DateTime.tryParse(s['startDate'] as String? ?? '');
          final week = s['firstCourseWeek'] as int?;
          if (startDate != null && week != null) {
            recordedSemesterConfig = _ImportSemesterConfig(
              semesterStartDate: startDate,
              firstCourseWeek: week,
            );
          }
        }
      }

      final replaceExisting = provider.courses.isEmpty
          ? true
          : recordedReplaceExisting ??
                await _askReplaceExisting(
                  context,
                  title: AppLocalizations.of(context)!.courseImportTitle,
                  content: AppLocalizations.of(
                    context,
                  )!.importCourseCountPrompt(parsedCourses.length),
                );
      if (replaceExisting == null || !mounted) {
        _debugImportLog(
          'courses import aborted at replaceExisting mounted=$mounted value=$replaceExisting',
        );
        _cancelImportTimeout();
        if (!mounted) return;
        final status = AppLocalizations.of(context)!.importCancelledStatus;
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = status;
        });
        _showMacroReplayImportError(status);
        return;
      }
      if (recording) {
        _macroDialogResponses['replaceExisting'] = replaceExisting;
      }

      final semesterConfig =
          recordedSemesterConfig ??
          await _pickImportSemesterConfig(
            context,
            initialSemesterStartDate:
                provider.settings.semesterStartDate ?? DateTime.now(),
            initialFirstCourseWeek: 1,
            title: AppLocalizations.of(
              context,
            )!.importConfirmSemesterMappingTitle,
            subtitle: AppLocalizations.of(
              context,
            )!.importConfirmSemesterMappingSubtitleWarehouse,
          );
      if (semesterConfig == null || !mounted) {
        _debugImportLog(
          'courses import aborted at semesterConfig mounted=$mounted hasConfig=${semesterConfig != null}',
        );
        _cancelImportTimeout();
        if (!mounted) return;
        final status = AppLocalizations.of(context)!.importCancelledStatus;
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = status;
        });
        _showMacroReplayImportError(status);
        return;
      }
      if (recording) {
        _macroDialogResponses['semesterConfig'] = {
          'startDate': semesterConfig.semesterStartDate.toIso8601String(),
          'firstCourseWeek': semesterConfig.firstCourseWeek,
        };
      }

      final alignedCourses = _weekAlignmentService.shiftCoursesToSemesterWeeks(
        parsedCourses,
        firstCourseWeek: semesterConfig.firstCourseWeek,
      );
      await _waitForCompanionImportSections();
      if (!mounted) {
        return;
      }
      try {
        await _applyPendingImportedSectionsIfNeeded();
      } catch (error) {
        if (mounted) {
          _showLightTip(
            context,
            AppLocalizations.of(
              context,
            )!.applyReturnedTimeSchemeFailed('$error'),
          );
        }
      }
      final requiredSectionCount = provider
          .previewImportedCourseRequiredSectionCount(
            alignedCourses,
            replaceExisting: replaceExisting,
          );
      if (!mounted) {
        return;
      }
      final capacityReady = await _ensureSectionCapacity(
        context,
        requiredSectionCount: requiredSectionCount,
        provider: provider,
      );
      if (!capacityReady || !mounted) {
        _debugImportLog(
          'courses import aborted at capacity mounted=$mounted capacityReady=$capacityReady requiredSectionCount=$requiredSectionCount',
        );
        _cancelImportTimeout();
        if (!mounted) return;
        final status = AppLocalizations.of(context)!.importInterruptedStatus;
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = status;
        });
        _showMacroReplayImportError(status);
        return;
      }

      _debugImportLog(
        'importParsedCourses start alignedCount=${alignedCourses.length} replaceExisting=$replaceExisting semesterStart=${semesterConfig.semesterStartDate.toIso8601String()}',
      );
      final importedCount = await provider.importParsedCourses(
        alignedCourses,
        replaceExisting: replaceExisting,
        semesterStart: semesterConfig.semesterStartDate,
        source: 'warehouse',
      );
      _debugImportLog('importParsedCourses done importedCount=$importedCount');
      if (!mounted) {
        return;
      }
      await _preferencesService.addRecentSchool(widget.school.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastScriptStatus = importedCount > 0
            ? AppLocalizations.of(context)!.importUpdatedCount(importedCount)
            : AppLocalizations.of(context)!.importNoCourseChanges;
      });
      final navigator = Navigator.of(context);
      _showLightTip(
        context,
        importedCount > 0
            ? AppLocalizations.of(context)!.importUpdatedCount(importedCount)
            : AppLocalizations.of(context)!.importNoCourseChanges,
      );
      _cancelImportTimeout();
      _debugImportLog('courses import success path -> set executing false');
      setState(() {
        _isExecutingImport = false;
      });
      if (importedCount > 0) {
        _debugImportLog(
          'courses import positive result recording=$recording replaying=$replaying',
        );
        // 导入成功，如果正在录制宏则自动结束录制并保存
        if (_macroRecordingState == MacroRecordingState.recording) {
          await _completeMacroAndPop();
        } else if (replaying) {
          await _markMacroImportCompleted(countSuccessfulImport: true);
        } else {
          navigator.pop(true);
        }
      } else if (replaying) {
        _debugImportLog(
          'courses import no changes but replaying -> mark completed without count',
        );
        await _markMacroImportCompleted(countSuccessfulImport: false);
      }
    } catch (error) {
      if (kDebugMode) {
        _debugImportLog(
          'handle courses caught error=$error\n${StackTrace.current}',
        );
      }
      if (!mounted) return;
      _cancelImportTimeout();
      final message = AppLocalizations.of(
        context,
      )!.importFailedWithError('$error');
      setState(() {
        _isExecutingImport = false;
        _lastScriptStatus = AppLocalizations.of(context)!.importFailedStatus;
      });
      _showMacroReplayImportError(message);
      _showLightTip(context, message);
    }
  }

  List<Course> _parseWarehouseCourses(List<dynamic> rawCourses) {
    final courses = <Course>[];
    for (final item in rawCourses) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
      final name = (map['name'] as String? ?? '').trim();
      final teacher = (map['teacher'] as String? ?? '').trim();
      final location =
          (map['position'] as String? ?? map['location'] as String? ?? '')
              .trim();
      final day = (map['day'] as num?)?.toInt();
      final startSection = (map['startSection'] as num?)?.toInt();
      final endSection = (map['endSection'] as num?)?.toInt();
      final weeks =
          (map['weeks'] as List<dynamic>?)
              ?.map((item) => (item as num).toInt())
              .where((item) => item > 0)
              .toSet()
              .toList()
            ?..sort();
      if (name.isEmpty ||
          day == null ||
          startSection == null ||
          endSection == null ||
          weeks == null ||
          weeks.isEmpty) {
        continue;
      }
      courses.add(
        Course(
          id: const Uuid().v4(),
          name: name,
          teacher: teacher.isEmpty
              ? AppLocalizations.of(context)!.unknownTeacher
              : teacher,
          location: location.isEmpty
              ? AppLocalizations.of(context)!.unknownLocation
              : location,
          dayOfWeek: day,
          startSection: startSection,
          endSection: endSection,
          startTime: '',
          endTime: '',
          customWeeks: weeks,
        ),
      );
    }
    return courses;
  }

  Future<void> _handleLoginStateMessage(Map<String, dynamic> message) async {
    final hasPasswordField = message['hasPasswordField'] == true;
    final candidate = WarehouseRememberedLogin(
      username: (message['username'] as String? ?? '').trim(),
      password: (message['password'] as String? ?? '').trim(),
    );
    _latestLoginCandidate = candidate;

    if (shouldPromptRememberedLoginAutofill(
      hasPasswordField: hasPasswordField,
      rememberedLogin: _rememberedLogin,
      candidate: candidate,
      hasPromptedAutofill: _hasPromptedAutofill,
      isPromptShowing: _isPromptShowing,
    )) {
      _hasPromptedAutofill = true;
      // 回放模式：直接填充，不弹对话框
      if (widget.macroRecord != null) {
        await _autofillRememberedLogin();
        return;
      }
      _isPromptShowing = true;
      final l10n = AppLocalizations.of(context)!;
      final shouldAutofill = await showAppConfirmDialog(
        context,
        title: l10n.autofillLoginTitle,
        message: l10n.autofillLoginMessage(_rememberedLogin!.username),
        cancelLabel: l10n.notNowAction,
        confirmLabel: l10n.autofillAction,
      );
      _isPromptShowing = false;
      if (shouldAutofill == true) {
        await _autofillRememberedLogin();
      }
      return;
    }
  }

  Future<void> _handleLoginAttempt() async {
    final candidate = _latestLoginCandidate;
    if (candidate == null ||
        _rememberedLogin != null ||
        _hasPromptedSave ||
        _isPromptShowing ||
        candidate.username.isEmpty ||
        candidate.password.isEmpty) {
      return;
    }
    _hasPromptedSave = true;
    // 回放模式：跳过保存密码对话框
    if (widget.macroRecord != null) {
      return;
    }
    _isPromptShowing = true;
    final l10n = AppLocalizations.of(context)!;
    final shouldSave = await showAppConfirmDialog(
      context,
      title: l10n.rememberPasswordTitle,
      message: l10n.rememberPasswordMessage(candidate.username),
      cancelLabel: l10n.dontRememberAction,
      confirmLabel: l10n.rememberAndAutofillAction,
    );
    _isPromptShowing = false;
    if (shouldSave == true) {
      await _preferencesService.setRememberedLogin(
        widget.adapter.adapterId,
        candidate,
      );
      if (!mounted) return;
      setState(() {
        _rememberedLogin = candidate;
        _lastScriptStatus = AppLocalizations.of(
          context,
        )!.savedRememberedLoginStatus;
      });
    }
  }

  Future<void> _loadRememberedLogin() async {
    final login = await _preferencesService.getRememberedLogin(
      widget.adapter.adapterId,
    );
    if (!mounted) return;
    setState(() {
      _rememberedLogin = login;
    });
    await _autofillRememberedLoginIfNeeded();
  }

  Future<void> _autofillRememberedLoginIfNeeded() async {
    if (_rememberedLogin == null || _hasPromptedAutofill || _isPromptShowing) {
      return;
    }
    await _requestLoginStateProbe();
  }

  Future<void> _autofillRememberedLogin() async {
    final login = _rememberedLogin;
    if (login == null) return;
    final js =
        '''
(() => {
  const textInputs = Array.from(document.querySelectorAll('input')).filter((input) => {
    const type = (input.type || 'text').toLowerCase();
    return ['text','email','tel','number'].includes(type) && !input.disabled;
  });
  const passwordInput = Array.from(document.querySelectorAll('input[type="password"]')).find((input) => !input.disabled);
  if (textInputs[0]) {
    textInputs[0].focus();
    textInputs[0].value = ${jsonEncode(login.username)};
    textInputs[0].dispatchEvent(new Event('input', { bubbles: true }));
    textInputs[0].dispatchEvent(new Event('change', { bubbles: true }));
  }
  if (passwordInput) {
    passwordInput.focus();
    passwordInput.value = ${jsonEncode(login.password)};
    passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
    passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
  }
})();
''';
    await _controller.runJavaScript(js);
    if (!mounted) return;
    setState(() {
      _lastScriptStatus = AppLocalizations.of(
        context,
      )!.autofilledRememberedLoginStatus;
    });
  }

  Future<void> _rememberCurrentLogin() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final raw = await _controller.runJavaScriptReturningResult('''
(() => {
  const textInputs = Array.from(document.querySelectorAll('input')).filter((input) => {
    const type = (input.type || 'text').toLowerCase();
    return ['text','email','tel','number'].includes(type) && !input.disabled;
  });
  const passwordInput = Array.from(document.querySelectorAll('input[type="password"]')).find((input) => !input.disabled);
  return JSON.stringify({
    username: textInputs[0] ? String(textInputs[0].value || '') : '',
    password: passwordInput ? String(passwordInput.value || '') : ''
  });
})();
''');
      if (!mounted) return;
      final normalized = _normalizeJavaScriptResult(raw);
      final decoded = jsonDecode(normalized);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(l10n.noRecognizedLoginInputs);
      }
      final login = WarehouseRememberedLogin.fromJson(decoded);
      if (login.username.isEmpty && login.password.isEmpty) {
        _showLightTip(context, l10n.noUsernameOrPasswordRecognized);
        return;
      }
      await _preferencesService.setRememberedLogin(
        widget.adapter.adapterId,
        login,
      );
      if (!mounted) return;
      setState(() {
        _rememberedLogin = login;
        _lastScriptStatus = l10n.rememberedCurrentLoginStatus;
      });
      _showLightTip(context, l10n.rememberedCurrentLoginSuccess);
    } catch (error) {
      if (!mounted) return;
      _showLightTip(context, l10n.rememberLoginFailedWithError('$error'));
    }
  }

  Future<void> _clearRememberedLogin() async {
    await _preferencesService.clearRememberedLogin(widget.adapter.adapterId);
    if (!mounted) return;
    setState(() {
      _rememberedLogin = null;
      _lastScriptStatus = AppLocalizations.of(
        context,
      )!.clearedRememberedLoginStatus;
    });
    _showLightTip(
      context,
      AppLocalizations.of(context)!.clearedRememberedLoginSuccess,
    );
  }

  // ============ 宏录制方法 ============

  Future<void> _injectMacroRecorderJs() async {
    try {
      await _controller.runJavaScript(MacroRecorderJs.injectScript);
    } catch (_) {}
  }

  void _handleMacroEvent(Map<String, dynamic> message) {
    if (_macroRecordingState != MacroRecordingState.recording) return;
    try {
      final payloadRaw = message['payload'] as String?;
      if (payloadRaw == null || payloadRaw.isEmpty) return;
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map) return;
      setState(() {
        _macroRawEvents.add(Map<String, dynamic>.from(decoded));
      });
    } catch (_) {}
  }

  Future<void> _toggleMacroRecording() async {
    if (_macroRecordingState == MacroRecordingState.recording) {
      await _stopMacroRecording();
    } else {
      _startMacroRecording();
    }
  }

  void _startMacroRecording() {
    setState(() {
      _macroRecordingState = MacroRecordingState.recording;
      _macroRawEvents = [];
      _lastScriptStatus = '录制中…点击停止完成录制';
    });
    // 在当前页面注入录制 JS
    _injectMacroRecorderJs();
    _showLightTip(context, '录制已开始，请按正常流程操作教务网站');
  }

  /// 导入成功时自动完成录制并返回
  Future<void> _completeMacroAndPop() async {
    // 从 JS 获取剩余事件
    try {
      final result = await _controller.runJavaScriptReturningResult(
        MacroRecorderJs.dumpScript,
      );
      final normalized = _normalizeJavaScriptResult(result);
      if (normalized.isNotEmpty && normalized != '[]') {
        final decoded = jsonDecode(normalized);
        if (decoded is List) {
          _macroRawEvents.addAll(
            decoded.map((e) => Map<String, dynamic>.from(e)),
          );
        }
      }
    } catch (_) {}

    final capturedEvents = List<Map<String, dynamic>>.from(_macroRawEvents);
    final steps = MacroRecordingConverter.convert(capturedEvents);

    if (steps.isNotEmpty && mounted) {
      final now = DateTime.now();
      final record = WarehouseMacroRecord(
        schoolId: widget.school.id,
        adapterId: widget.adapter.adapterId,
        schoolName: widget.school.name,
        adapterName: widget.adapter.adapterName,
        importUrl: widget.initialUrl,
        schoolResourceFolder: widget.school.resourceFolder,
        adapterAssetJsPath: widget.adapter.assetJsPath,
        steps: steps,
        dialogResponses: Map<String, dynamic>.from(_macroDialogResponses),
        createdAt: now,
        updatedAt: now,
        successfulImportCount: 1,
        useDesktopMode: _useDesktopMode,
      );
      await _macroService.saveMacro(record);
    }

    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _stopMacroRecording() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _macroRecordingState = MacroRecordingState.stopped;
    });

    // 尝试从页面获取剩余的录制事件
    try {
      final result = await _controller.runJavaScriptReturningResult(
        MacroRecorderJs.dumpScript,
      );
      final normalized = _normalizeJavaScriptResult(result);
      if (normalized.isNotEmpty && normalized != '[]') {
        final decoded = jsonDecode(normalized);
        if (decoded is List) {
          setState(() {
            _macroRawEvents.addAll(
              decoded.map((e) => Map<String, dynamic>.from(e)),
            );
          });
        }
      }
    } catch (_) {}

    // 转换为 MacroStep 列表
    final capturedEvents = List<Map<String, dynamic>>.from(_macroRawEvents);
    final steps = MacroRecordingConverter.convert(capturedEvents);
    if (!mounted) return;

    if (steps.isEmpty) {
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
        _lastScriptStatus = '未录制到任何操作';
      });
      _showLightTip(context, '未录制到任何操作');
      return;
    }

    // 询问用户是否要保存
    final shouldSave = await showAppConfirmDialog(
      context,
      title: '保存录制',
      message: '录制了 ${steps.length} 个操作步骤。是否保存为快捷导入？',
      confirmLabel: l10n.saveAction,
    );

    if (shouldSave != true || !mounted) {
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
        _lastScriptStatus = null;
      });
      return;
    }

    // 保存宏录制
    final now = DateTime.now();
    final record = WarehouseMacroRecord(
      schoolId: widget.school.id,
      adapterId: widget.adapter.adapterId,
      schoolName: widget.school.name,
      adapterName: widget.adapter.adapterName,
      importUrl: widget.initialUrl,
      schoolResourceFolder: widget.school.resourceFolder,
      adapterAssetJsPath: widget.adapter.assetJsPath,
      steps: steps,
      dialogResponses: Map<String, dynamic>.from(_macroDialogResponses),
      createdAt: now,
      updatedAt: now,
      successfulImportCount: 0,
      useDesktopMode: _useDesktopMode,
    );

    await _macroService.saveMacro(record);
    if (!mounted) return;

    setState(() {
      _macroRecordingState = MacroRecordingState.idle;
      _macroRawEvents = [];
      _lastScriptStatus = '录制已保存（${steps.length} 步）';
    });
    // 保存后自动返回适配器列表，用户即可看到快捷导入按钮
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ============ 宏回放方法 ============

  Future<void> _startPlayback(WarehouseMacroRecord macro) async {
    _debugImportLog(
      'start playback macro steps=${macro.steps.length} adapter=${macro.adapterId}',
    );
    setState(() {
      _playbackState = PlaybackUiState.playing;
      _playbackProgress = ReplayProgress(
        currentStepIndex: 0,
        totalSteps: 0,
        currentStep: const MacroStep(type: MacroStepType.delay, waitMs: 0),
        status: ReplayStepStatus.pending,
      );
      _isExecutingImport = false;
    });

    final replayer = WarehouseMacroReplayer(
      controller: _controller,
      callbacks: ReplayCallbacks(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _playbackProgress = progress;
          });
        },
        onPauseForManualInput: (step, reason) async {
          if (!mounted) return false;
          if (shouldUseRememberedPasswordForManualStep(step, reason)) {
            final remembered =
                _rememberedLogin ??
                await _preferencesService.getRememberedLogin(
                  widget.adapter.adapterId,
                );
            if (!mounted) return false;
            if (remembered != null && remembered.password.isNotEmpty) {
              if (_rememberedLogin == null) {
                setState(() {
                  _rememberedLogin = remembered;
                });
              }
              await _autofillRememberedLogin();
              await Future.delayed(const Duration(milliseconds: 300));
              if (!mounted) return false;
              setState(() {
                _playbackState = PlaybackUiState.playing;
              });
              return true;
            }
          }
          setState(() {
            _playbackState = PlaybackUiState.pausedForInput;
          });
          // 使用 Completer 等待用户点击继续
          final completer = Completer<bool>();
          _replayContinueCompleter = completer;
          return completer.future;
        },
        onShowTip: (message) {
          if (!mounted) return;
          _showLightTip(context, message);
        },
        onComplete: (success, errorMessage) async {
          _debugImportLog(
            'playback onComplete success=$success errorMessage=$errorMessage mounted=$mounted',
          );
          if (!mounted) return;
          if (success) {
            _debugImportLog('playback success -> executing import');
            setState(() {
              _playbackState = PlaybackUiState.executingImport;
            });
            await _autoExecuteImportAfterPlayback();
          } else {
            if (!mounted) return;
            _debugImportLog('playback failed -> playback error');
            setState(() {
              _playbackState = PlaybackUiState.error;
            });
          }
        },
      ),
    );
    _replayer = replayer;
    await replayer.execute(macro);
  }

  Completer<bool>? _replayContinueCompleter;

  void _resumePlaybackAfterPause() {
    if (_replayContinueCompleter == null) return;
    _replayContinueCompleter!.complete(true);
    _replayContinueCompleter = null;
    if (mounted) {
      setState(() {
        _playbackState = PlaybackUiState.playing;
      });
    }
  }

  void _cancelPlayback() {
    _replayer?.cancel();
    _replayContinueCompleter?.complete(false);
    _replayContinueCompleter = null;
    if (mounted) {
      setState(() {
        _playbackState = PlaybackUiState.hidden;
      });
    }
  }

  Future<void> _dismissPlaybackResult() async {
    if (_playbackState == PlaybackUiState.finished) {
      // 成功：返回到上一页
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      // 失败：隐藏覆盖层，让用户手动操作
      if (mounted) {
        setState(() {
          _playbackState = PlaybackUiState.hidden;
        });
      }
    }
  }

  Future<void> _retryPlayback() async {
    final macro =
        widget.macroRecord ??
        await _macroService.getMacro(
          widget.school.id,
          widget.adapter.adapterId,
        );
    if (macro == null || !mounted) return;
    // 重新加载初始 URL
    final uri = Uri.tryParse(widget.initialUrl);
    if (uri != null) {
      await _controller.loadRequest(uri);
    }
    if (!mounted) return;
    _startPlayback(macro);
  }

  /// 回放导航完成后，自动执行导入脚本
  Future<void> _autoExecuteImportAfterPlayback() async {
    // 给页面一点稳定时间
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    // 自动执行导入脚本
    await _executeImportScript();
  }
}

class _ImportInitialBadge extends StatelessWidget {
  final String label;

  const _ImportInitialBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final text = label.trim().isEmpty ? '#' : label.trim();
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: typo.body.sm.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ImportIconBadge extends StatelessWidget {
  final IconData icon;

  const _ImportIconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: colors.primary),
    );
  }
}

class _ImportSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ImportSectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return HyperosCard(padding: padding, child: child);
  }
}

class _ImportGuidePanel extends StatelessWidget {
  final String scenarioIntro;
  final String step1Subtitle;
  final String step2Subtitle;
  final String step3Subtitle;
  final String supportedFilesSuffix;
  final String? supportedFilesExtra;

  const _ImportGuidePanel({
    required this.scenarioIntro,
    required this.step1Subtitle,
    required this.step2Subtitle,
    required this.step3Subtitle,
    required this.supportedFilesSuffix,
    this.supportedFilesExtra,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ImportSectionCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.applicableScenarioTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(scenarioIntro),
              const SizedBox(height: 14),
              _GuideLine(title: l10n.stepLabel('1'), subtitle: step1Subtitle),
              const SizedBox(height: 10),
              _GuideLine(title: l10n.stepLabel('2'), subtitle: step2Subtitle),
              const SizedBox(height: 10),
              _GuideLine(title: l10n.stepLabel('3'), subtitle: step3Subtitle),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ImportSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.supportedFilesTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(supportedFilesSuffix),
              if (supportedFilesExtra != null) ...[
                const SizedBox(height: 4),
                Text(supportedFilesExtra!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WarehouseIntroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> chips;
  final String? markdown;

  const _WarehouseIntroCard({
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.markdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _ImportSectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if ((markdown ?? '').trim().isNotEmpty) ...[
            if (subtitle.isNotEmpty) const SizedBox(height: 8),
            MarkdownBody(
              data: markdown!,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map((item) => HyperosTag(label: item))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _WarehouseAdapterTileBody extends StatelessWidget {
  final WarehouseAdapterEntry adapter;
  final bool hasMacro;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onRecord;
  final Future<void> Function() onInfo;
  final Future<void> Function()? onQuickImport;
  final String importButtonLabel;
  final String recordButtonLabel;

  const _WarehouseAdapterTileBody({
    required this.adapter,
    required this.hasMacro,
    required this.onImport,
    required this.onRecord,
    required this.onInfo,
    required this.onQuickImport,
    required this.importButtonLabel,
    required this.recordButtonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          adapter.adapterName,
          style: typo.body.lg.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '类别：${adapter.category} · 维护者：${adapter.maintainer}',
          style: typo.body.sm.copyWith(color: colors.mutedForeground),
        ),
        if (adapter.description.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          MarkdownBody(
            data: adapter.description,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(
                color: colors.mutedForeground,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: HyperosButton(
                label: importButtonLabel,
                expand: true,
                onPressed: onImport,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HyperosButton(
                label: recordButtonLabel,
                variant: HyperosButtonVariant.secondary,
                expand: true,
                onPressed: onRecord,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: HyperosButton(
            label: '查看详情',
            variant: HyperosButtonVariant.secondary,
            onPressed: onInfo,
          ),
        ),
        if (hasMacro) ...[
          const SizedBox(height: 10),
          HyperosButton(
            label: '⚡ 快捷导入',
            expand: true,
            onPressed: onQuickImport,
          ),
        ],
      ],
    );
  }
}

class _WarehouseSchoolBean extends ISuspensionBean {
  final WarehouseSchoolEntry school;
  final String tag;
  final bool isRecent;

  _WarehouseSchoolBean({
    required this.school,
    required this.tag,
    required this.isRecent,
  });

  @override
  String getSuspensionTag() => tag;
}

List<_WarehouseSchoolBean> _schoolsToBeans(
  List<WarehouseSchoolEntry> schools,
  List<String> recentSchoolIds,
) {
  final recentOrdered = recentSchoolIds
      .map((id) => schools.where((school) => school.id == id).firstOrNull)
      .whereType<WarehouseSchoolEntry>()
      .toList(growable: false);
  final remaining = schools
      .where((school) => !recentSchoolIds.contains(school.id))
      .toList(growable: false);
  final beans = <_WarehouseSchoolBean>[
    ...recentOrdered.map(
      (school) =>
          _WarehouseSchoolBean(school: school, tag: '★', isRecent: true),
    ),
    ...remaining.map(
      (school) => _WarehouseSchoolBean(
        school: school,
        tag: school.initial.trim().isEmpty
            ? '#'
            : school.initial.trim().toUpperCase(),
        isRecent: false,
      ),
    ),
  ];
  SuspensionUtil.setShowSuspensionStatus(beans);
  return beans;
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ImportSemesterConfig {
  final DateTime semesterStartDate;
  final int firstCourseWeek;

  const _ImportSemesterConfig({
    required this.semesterStartDate,
    required this.firstCourseWeek,
  });
}

class _GuideLine extends StatelessWidget {
  final String title;
  final String subtitle;

  const _GuideLine({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.theme.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            title.replaceAll('步骤 ', ''),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactHintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CompactHintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.theme.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.mutedForeground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactStatusChip extends StatelessWidget {
  final String label;
  final bool isError;

  const _CompactStatusChip({required this.label, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.theme.colors;
    final backgroundColor = isError
        ? colors.error.withValues(alpha: 0.12)
        : colors.primary.withValues(alpha: 0.12);
    final foregroundColor = isError ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactNoticeCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const _CompactNoticeCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isError
        ? colorScheme.errorContainer.withValues(alpha: 0.92)
        : colorScheme.surfaceContainerHigh;
    final foregroundColor = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: foregroundColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foregroundColor,
                height: 1.35,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            HyperosButton(
              label: actionLabel!,
              variant: HyperosButtonVariant.secondary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _AiPreviewCard extends StatelessWidget {
  final AiCourseImportParseResult result;

  const _AiPreviewCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aiPreviewTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.aiPreviewCourseCount(result.courses.length)),
          Text(l10n.aiPreviewMaxSection(result.requiredSectionCount)),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.aiPreviewWarningsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...result.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $warning'),
              ),
            ),
          ],
          if (result.courses.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.aiPreviewCoursesTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...result.courses.take(6).map(_buildCoursePreviewLine),
            if (result.courses.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.aiPreviewRemainingCourses(result.courses.length - 6),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoursePreviewLine(Course course) {
    final weeks = course.customWeeks ?? const [];
    final weekText = weeks.isEmpty
        ? '未提供周次'
        : weeks.length <= 6
        ? weeks.join('、')
        : '${weeks.first}-${weeks.last}（共 ${weeks.length} 周）';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '周${_weekdayLabel(course.dayOfWeek)} 第${course.startSection}-${course.endSection}节  ${course.name}  ${course.location.isEmpty ? "未填写地点" : course.location}  周次：$weekText',
      ),
    );
  }
}

Future<_ImportSemesterConfig?> _pickImportSemesterConfig(
  BuildContext context, {
  required DateTime initialSemesterStartDate,
  required int initialFirstCourseWeek,
  required String title,
  required String subtitle,
  DateTime? inferredFirstCourseDate,
}) {
  final alignmentService = const ImportWeekAlignmentService();
  return showHyperosSheet<_ImportSemesterConfig>(
    context: context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final colorScheme = theme.colorScheme;
      var selectedSemesterStartDate = initialSemesterStartDate;
      var selectedFirstCourseWeek = initialFirstCourseWeek < 1
          ? 1
          : initialFirstCourseWeek > 20
          ? 20
          : initialFirstCourseWeek;
      var autoTrackWeekMapping = inferredFirstCourseDate != null;

      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickStartDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedSemesterStartDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked == null || !context.mounted) {
              return;
            }
            setModalState(() {
              selectedSemesterStartDate = picked;
              if (autoTrackWeekMapping && inferredFirstCourseDate != null) {
                selectedFirstCourseWeek = alignmentService.inferFirstCourseWeek(
                  semesterStartDate: selectedSemesterStartDate,
                  firstCourseDate: inferredFirstCourseDate,
                );
              }
            });
          }

          final shiftedWeeks = selectedFirstCourseWeek - 1;
          return HyperosSheetFrame(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HyperosTypography.sheetTitle(context)),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: HyperosTypography.sectionDescription(context),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('开学日期'),
                    subtitle: Text(
                      '${_formatDate(selectedSemesterStartDate)} · 按这一天所在周作为校历第 1 周',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: pickStartDate,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedFirstCourseWeek,
                    decoration: const InputDecoration(
                      labelText: '课表第 1 周对应校历第几周',
                      border: OutlineInputBorder(),
                      helperText: '如果学校第一周没课，就选第 2 周；前两周都没课就选第 3 周。',
                    ),
                    items: List.generate(20, (index) => index + 1)
                        .map(
                          (week) => DropdownMenuItem<int>(
                            value: week,
                            child: Text('校历第 $week 周'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setModalState(() {
                        selectedFirstCourseWeek = value;
                        autoTrackWeekMapping = false;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      shiftedWeeks <= 0
                          ? '导入后会直接把课表第 1 周当作校历第 1 周。'
                          : '导入后会把所有课程周次整体顺延 $shiftedWeeks 周，让课表第 1 周落在校历第 $selectedFirstCourseWeek 周。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: HyperosButton(
                          label: '取消',
                          variant: HyperosButtonVariant.secondary,
                          expand: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HyperosButton(
                          label: '继续导入',
                          expand: true,
                          onPressed: () => Navigator.pop(
                            context,
                            _ImportSemesterConfig(
                              semesterStartDate: selectedSemesterStartDate,
                              firstCourseWeek: selectedFirstCourseWeek,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<bool?> _askReplaceExisting(
  BuildContext context, {
  required String title,
  required String content,
}) {
  return showAppTripleActionDialog(
    context,
    title: title,
    message: '$content\n\n建议日常更新课表时优先使用“更新课表（保留本地信息）”。',
    cancelLabel: '取消',
    secondaryLabel: '更新课表（推荐）',
    primaryLabel: '覆盖导入',
  );
}

Future<bool> _ensureSectionCapacity(
  BuildContext context, {
  required int requiredSectionCount,
  required TimetableProvider provider,
}) async {
  if (requiredSectionCount <= provider.settings.sectionCount) {
    return true;
  }

  final shouldContinue = await showAppConfirmDialog(
    context,
    title: '时间模板节次不足',
    message:
        '当前课表时间模板只有 ${provider.settings.sectionCount} 节，但导入数据需要到第 $requiredSectionCount 节。是否自动补齐后继续导入？',
    confirmLabel: '自动补齐并导入',
  );

  if (shouldContinue != true || !context.mounted) {
    return false;
  }

  final ensureMessage = await provider.ensureSectionCapacityForImport(
    requiredSectionCount,
  );
  if (ensureMessage != null) {
    if (context.mounted) {
      showAppLightTip(context, message: ensureMessage);
    }
    return false;
  }
  return true;
}

String _weekdayLabel(int dayOfWeek) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  if (dayOfWeek < 1 || dayOfWeek > 7) {
    return dayOfWeek.toString();
  }
  return labels[dayOfWeek - 1];
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _normalizeJavaScriptResult(Object? raw) {
  if (raw == null) {
    return '';
  }
  final text = raw.toString();
  try {
    final decoded = jsonDecode(text);
    if (decoded is String) {
      return decoded;
    }
  } catch (_) {}
  return text;
}

Future<String?> _promptWarehouseImportUrl(
  BuildContext context, {
  required String schoolName,
  required String adapterName,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showAppTextInputDialog(
    context,
    title: '输入教务网址',
    cancelLabel: '取消',
    confirmLabel: '保存并继续',
    readValue: () => controller.text,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('“$schoolName / $adapterName” 没有默认登录地址，请先输入学校教务系统网址。'),
        const SizedBox(height: 12),
        HyperosTextField(
          controller: controller,
          label: '教务网址',
          hint: 'http(s)://...',
          autofocus: true,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        Text(
          '保存后下次会直接使用，也可以在适配器信息页里修改。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
  if (result == null || result.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(result.trim());
  if (uri == null || uri.host.isEmpty) {
    if (!context.mounted) {
      return null;
    }
    _showLightTip(context, '登录地址格式不正确');
    return null;
  }
  return result.trim();
}

void _showLightTip(BuildContext context, String message) {
  showAppLightTip(context, message: message);
}
