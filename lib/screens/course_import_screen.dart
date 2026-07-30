import '../l10n/service_message_localizer.dart';
import '../logging/app_debug_log.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/miuix_date_picker_sheet.dart';
import 'dart:convert';
import 'dart:io';

import 'package:azlistview/azlistview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../providers/timetable/import_export_logic.dart';
import '../services/ai_course_import_service.dart';
import '../services/ics_import_service.dart';
import '../services/import_random_color_preferences.dart';
import '../services/import_week_alignment_service.dart';
import '../services/spreadsheet_import_service.dart';
import '../services/warehouse_import_preferences_service.dart';
import '../services/warehouse_import_session_log.dart';
import '../services/warehouse_macro_service.dart';
import '../services/warehouse_repository_service.dart';
import '../utils/app_toast.dart';
import '../utils/import_random_course_colors.dart';
import '../utils/import_result_message.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/import_random_color_toggle.dart';
import '../widgets/warehouse_macro_recorder.dart';
import '../widgets/warehouse_macro_replayer.dart';
import '../widgets/warehouse_playback_overlay.dart';
import 'feedback_screen.dart';
import 'log_viewer_entry.dart';

Future<List<Course>> _coursesWithOptionalRandomColors(
  List<Course> courses,
) async {
  if (!await ImportRandomColorPreferences.isEnabled()) {
    return courses;
  }
  final assignMatchingTextColor =
      await ImportRandomColorPreferences.isTextColorEnabled();
  return applyRandomImportCourseColors(
    courses,
    assignMatchingTextColor: assignMatchingTextColor,
  );
}

/// When random colors are on, import must apply the new palette (and optional
/// text colors) even for courses that match existing local rows.
Future<bool> _shouldPreserveLocalColorsOnImport() async {
  return !(await ImportRandomColorPreferences.isEnabled());
}

enum _WarehouseImportMenuAction { feedback, customDebug, executionLog }

Future<void> openWarehouseImportExecutionLogViewer(BuildContext context) =>
    openLogViewer(context, AppLogSource.warehouseImport);

Widget _importListTitle(BuildContext context, String text) {
  return Text(text, style: HyperosTypography.listTitle(context));
}

Widget _importCardHeading(BuildContext context, String text) {
  return Text(text, style: HyperosTypography.title(context));
}

Widget _importListDetail(BuildContext context, String text) {
  return Text(text, style: HyperosTypography.listDetail(context));
}

Widget _importLoadingCenter({double size = 32}) {
  return Center(child: HyperosCircularProgress(size: size));
}

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

/// Whether ordinary web-login import should start background path recording.
///
/// Explicit "record import" always records. Automatic first-import recording
/// only runs when this school+adapter has no saved macro yet.
bool shouldAutoRecordWarehouseImport({
  required bool forceRecord,
  required bool hasExistingMacro,
}) {
  return forceRecord || !hasExistingMacro;
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
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.courseImportTitle),
      childPad: false,
      // Standard list path (header inset inside the scrollable + notification
      // bubbling) so the large title collapses with scroll; the old
      // BodyInset + includeHeaderInset:false combo swallowed vertical scroll
      // notifications and froze the large title.
      child: HyperosListView(
        children: [
          const ImportRandomColorToggle(),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.chooseImportMethodTitle),
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              HyperosNavTile(
                icon: Icons.event_note_rounded,
                iconAccent: HyperosIconColors.blue,
                title: l10n.importMethodIcsTitle,
                subtitle: l10n.importMethodIcsSubtitle,
                onTap: () => _openImportPage<bool>(
                  context,
                  builder: (_) => const IcsCourseImportScreen(),
                ),
              ),
              HyperosNavTile(
                icon: Icons.auto_awesome_rounded,
                iconAccent: HyperosIconColors.purple,
                title: l10n.importMethodAiTitle,
                subtitle: l10n.importMethodAiSubtitle,
                onTap: () => _openImportPage<bool>(
                  context,
                  builder: (_) => const AiImageCourseImportScreen(),
                ),
              ),
              HyperosNavTile(
                icon: Icons.school_outlined,
                iconAccent: HyperosIconColors.green,
                title: l10n.importMethodWarehouseTitle,
                subtitle: l10n.importMethodWarehouseSubtitle,
                onTap: () => _openImportPage<bool>(
                  context,
                  builder: (_) => const WarehouseCourseImportScreen(),
                ),
              ),
              HyperosNavTile(
                icon: Icons.table_chart_outlined,
                iconAccent: HyperosIconColors.orange,
                title: l10n.importMethodSpreadsheetTitle,
                subtitle: l10n.importMethodSpreadsheetSubtitle,
                onTap: () => _openImportPage<bool>(
                  context,
                  builder: (_) => const SpreadsheetCourseImportScreen(),
                ),
              ),
            ],
          ),
        ],
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
      // Standard list path (header inset inside the scrollable + notification
      // bubbling) so the large title collapses; the old BodyInset +
      // includeHeaderInset:false combo swallowed vertical scroll notifications
      // and froze the large title.
      child: Column(
        children: [
          Expanded(
            child: HyperosListView(
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

    final coursesToImport = await _coursesWithOptionalRandomColors(
      alignedCourses,
    );
    if (!mounted) return;
    final importedCount = await provider.importParsedCourses(
      coursesToImport,
      replaceExisting: replaceExisting,
      semesterStart: semesterConfig.semesterStartDate,
      source: 'ics',
      preserveLocalColors: await _shouldPreserveLocalColorsOnImport(),
    );
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
      // Standard list path so the large title collapses with scroll (see the
      // ICS import screen above).
      child: Column(
        children: [
          Expanded(
            child: HyperosListView(
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
      final result = await FilePicker.pickFiles(
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
  final capacityReady = await _ensureSectionCapacity(
    context,
    requiredSectionCount: requiredSectionCount,
    provider: provider,
  );
  if (!capacityReady || !context.mounted) return;

  final coursesToImport = await _coursesWithOptionalRandomColors(courses);
  if (!context.mounted) return;

  final importedCount = await provider.importParsedCourses(
    coursesToImport,
    replaceExisting: replaceExisting,
    semesterStart: semesterStart,
    source: source,
    preserveLocalColors: await _shouldPreserveLocalColorsOnImport(),
  );
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
}

List<String> _splitWorkflowArrowTitle(String title) {
  return title
      .split(RegExp(r'\s*(?:->|→)\s*'))
      .map((step) => step.trim())
      .where((step) => step.isNotEmpty)
      .toList(growable: false);
}

class _AiWorkflowGuideCard extends StatelessWidget {
  const _AiWorkflowGuideCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final steps = _splitWorkflowArrowTitle(l10n.aiWorkflowTitle);

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HyperosIconBadge(
                  icon: Icons.auto_awesome_rounded,
                  accent: HyperosIconColors.purple,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.importMethodAiTitle,
                        style: HyperosTypography.listTitle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.aiWorkflowSubtitle,
                        style: HyperosTypography.listDetail(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 16),
              _AiWorkflowStepList(steps: steps),
            ],
            const SizedBox(height: 14),
            const HyperosDivider(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: HyperosColors.primary(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.aiExpertModeSuggestion,
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AiWorkflowStepList extends StatelessWidget {
  const _AiWorkflowStepList({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final accent = HyperosColors.primary(context);

    return Column(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: HyperosTypography.listDetail(context).copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    steps[index],
                    style: HyperosTypography.listTitle(context),
                  ),
                ),
              ),
            ],
          ),
          if (index < steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 2,
                  height: 12,
                  decoration: BoxDecoration(
                    color: HyperosColors.dividerLine(context),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
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
    final previewSummary = _aiParsedResult == null
        ? null
        : l10n.aiPreviewSummary(
            _aiParsedResult!.courses.length,
            _aiParsedResult!.requiredSectionCount,
            _aiParsedResult!.warnings.isEmpty
                ? ''
                : l10n.aiWarningCountSuffix(_aiParsedResult!.warnings.length),
          );

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.aiImportTitle),
      childPad: false,
      resizeToAvoidBottomInset: true,
      // Standard list path so the large title collapses with scroll (see the
      // ICS import screen above).
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: HyperosListView(
                children: [
                      _AiWorkflowGuideCard(l10n: l10n),
                      const HyperosSectionGap(),
                      HyperosControlCard(
                        child: HyperosControlCardInset(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HyperosButton(
                                label: l10n.copyAddress,
                                expand: true,
                                onPressed: _copyAiPrompt,
                              ),
                              const SizedBox(height: 10),
                              HyperosButton(
                                label: l10n.aiPromptShortAction,
                                variant: HyperosButtonVariant.secondary,
                                expand: true,
                                onPressed: _showPromptSheet,
                              ),
                              const SizedBox(height: 10),
                              HyperosButton(
                                label: l10n.pasteAction,
                                variant: HyperosButtonVariant.secondary,
                                expand: true,
                                onPressed: _pasteFromClipboard,
                              ),
                              const SizedBox(height: 10),
                              HyperosButton(
                                label: l10n.clearAction,
                                variant: HyperosButtonVariant.secondary,
                                expand: true,
                                onPressed: _clearInput,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const HyperosSectionGap(),
                      HyperosControlCard(
                        edgeToEdge: true,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            HyperosControlCardScope.defaultHorizontalPadding,
                            HyperosControlCardScope.defaultHorizontalPadding,
                            HyperosControlCardScope.defaultHorizontalPadding,
                            HyperosControlCardScope.defaultBodyBottomInset,
                          ),
                          child: HyperosTextField(
                            key: const ValueKey('ai_import_json_input'),
                            controller: _aiController,
                            focusNode: _aiFocusNode,
                            label: l10n.aiPasteJsonTitle,
                            helper: l10n.aiPasteJsonHintLong,
                            hint: l10n.aiPasteJsonHintShort,
                            minLines: 8,
                            maxLines: 999,
                            onChanged: (_) {
                              if (_aiParsedResult != null ||
                                  _aiParseError != null) {
                                setState(() {
                                  _aiParsedResult = null;
                                  _aiParseError = null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      if (_aiParseError != null) ...[
                        const SizedBox(height: 12),
                        HyperosListGroup(
                          children: [
                            HyperosNavTile(
                              title: l10n.aiParseFailedChip,
                              subtitle: _aiParseError,
                              onTap: () => _showMessageSheet(
                                title: l10n.aiParseErrorTitle,
                                content: _aiParseError!,
                              ),
                            ),
                          ],
                        ),
                      ] else if (_aiParsedResult != null) ...[
                        const SizedBox(height: 12),
                        HyperosListGroup(
                          children: [
                            HyperosNavTile(
                              title: previewSummary!,
                              subtitle: l10n.viewDetailsAction,
                              onTap: () => _showPreviewSheet(_aiParsedResult!),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
            ),
                Material(
                  color: HyperosColors.card(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
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
                            onPressed: _isImporting ? null : _importAiResult,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
          _aiParseError = localizeServiceMessage(l10n, error.message);
        });
        if (showError) {
          showAppToast(
            context,
            message: localizeServiceMessage(l10n, error.message),
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

      final coursesToImport = await _coursesWithOptionalRandomColors(
        alignedCourses,
      );
      if (!mounted) {
        return;
      }

      final importedCount = await provider.importParsedCourses(
        coursesToImport,
        replaceExisting: replaceExisting,
        semesterStart: semesterConfig.semesterStartDate,
        source: 'ai',
        preserveLocalColors: await _shouldPreserveLocalColorsOnImport(),
      );
      if (!mounted) {
        return;
      }

      showAppToast(
        context,
        message: buildImportResultMessage(
          l10n: l10n,
          importedCount: importedCount,
          replaceExisting: replaceExisting,
          warningCount: result.warnings.length,
        ),
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

/// Runs warehouse quick import without showing the WebView login page.
///
/// Equivalent to tapping the lightning icon on the warehouse import school list,
/// but keeps the browser off-screen for home pull-to-refresh.
///
/// Hosted in an [Overlay] (not a route) so the home page stays interactive.
/// Call [onCancelAvailable] with a cancel callback while the session is active.
Future<bool> runHomePullWarehouseQuickImport(
  BuildContext context, {
  VoidCallback? onNeedsManualAction,
  void Function(VoidCallback cancel)? onCancelAvailable,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final macroService = WarehouseMacroService();
  final preferencesService = WarehouseImportPreferencesService();
  final allEntries = await macroService.getAllMacroEntries();
  if (!context.mounted) {
    return false;
  }
  if (allEntries.isEmpty) {
    showAppLightTip(context, message: l10n.noSavedQuickImportRecords);
    return false;
  }

  WarehouseMacroRecord? macro;
  for (final entry in allEntries) {
    final record = await macroService.getMacro(entry.schoolId, entry.adapterId);
    if (record != null) {
      macro = record;
      break;
    }
  }
  if (!context.mounted) {
    return false;
  }
  if (macro == null) {
    showAppLightTip(context, message: l10n.noSavedQuickImportRecords);
    return false;
  }

  final customUrl = await preferencesService.getCustomImportUrl(
    macro.adapterId,
  );
  final initialUrl = resolveWarehouseImportUrl(
    customImportUrl: customUrl,
    defaultUrl: macro.importUrl,
  );
  if (!context.mounted) {
    return false;
  }
  if (initialUrl == null) {
    showAppLightTip(context, message: l10n.noValidWarehouseLoginUrl);
    return false;
  }

  final settings = context.read<TimetableProvider>().settings;
  final fetchOptions = WarehouseFetchOptions.fromSettings(settings);
  final source = WarehouseRepositorySource.fromGitHubUrl(
    'https://github.com/Mutx163/qingyu_warehouse',
  );
  final selectedMacro = macro;
  final completer = Completer<bool>();
  var sessionFinished = false;
  OverlayEntry? overlayEntry;

  void completeSession(bool success) {
    if (sessionFinished) {
      return;
    }
    sessionFinished = true;
    overlayEntry?.remove();
    overlayEntry = null;
    if (!completer.isCompleted) {
      completer.complete(success);
    }
  }

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    showAppLightTip(context, message: l10n.quickImportUnknownError);
    return false;
  }

  overlayEntry = OverlayEntry(
    builder: (overlayContext) {
      // Keep a tiny on-screen platform view so WebView keeps running, but do
      // not intercept home-page touches.
      return IgnorePointer(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1,
            height: 1,
            child: WarehouseAdapterWebLoginScreen(
              title: l10n.quickImportTitle(selectedMacro.schoolName),
              initialUrl: initialUrl,
              source: source,
              school: WarehouseSchoolEntry(
                id: selectedMacro.schoolId,
                name: selectedMacro.schoolName,
                initial: selectedMacro.schoolName.isNotEmpty
                    ? selectedMacro.schoolName[0]
                    : '#',
                resourceFolder: selectedMacro.schoolResourceFolder.isNotEmpty
                    ? selectedMacro.schoolResourceFolder
                    : selectedMacro.schoolId,
              ),
              adapter: WarehouseAdapterEntry(
                adapterId: selectedMacro.adapterId,
                adapterName: selectedMacro.adapterName,
                category: 'macro',
                assetJsPath: selectedMacro.adapterAssetJsPath.isNotEmpty
                    ? selectedMacro.adapterAssetJsPath
                    : 'macro/${selectedMacro.adapterId}.js',
                importUrl: selectedMacro.importUrl,
                maintainer: 'macro',
                description: l10n.courseImportQuickImportDescription(
                  selectedMacro.schoolName,
                  selectedMacro.adapterName,
                ),
              ),
              fetchOptions: fetchOptions,
              macroRecord: selectedMacro,
              runInBackground: true,
              onBackgroundNeedsManualAction: onNeedsManualAction,
              onBackgroundFinished: completeSession,
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(overlayEntry!);
  onCancelAvailable?.call(() => completeSession(false));
  return completer.future;
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
  final GlobalKey _warehouseMoreMenuKey = GlobalKey();
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
      case _WarehouseImportMenuAction.executionLog:
        await openWarehouseImportExecutionLogViewer(context);
        break;
    }
  }

  Future<void> _showWarehouseMoreMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showHyperosListPopup<_WarehouseImportMenuAction>(
      context: context,
      position: hyperosPopupPositionBelow(context, _warehouseMoreMenuKey),
      items: [
        HyperosPopupMenuItem(
          label: l10n.warehouseFeedbackMissingSchoolTitle,
          value: _WarehouseImportMenuAction.feedback,
        ),
        HyperosPopupMenuItem(
          label: l10n.warehouseCustomDebugTitle,
          value: _WarehouseImportMenuAction.customDebug,
        ),
        HyperosPopupMenuItem(
          label: l10n.warehouseImportExecutionLogMenuLabel,
          value: _WarehouseImportMenuAction.executionLog,
        ),
      ],
    );
    if (action != null && mounted) {
      await _handleMoreAction(action);
    }
  }

  Future<void> _handleQuickImport() async {
    final l10n = AppLocalizations.of(context)!;
    final allEntries = await _macroService.getAllMacroEntries();
    if (!mounted) return;
    if (allEntries.isEmpty) {
      _showLightTip(context, l10n.noSavedQuickImportRecords);
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
      _showLightTip(context, l10n.noSavedQuickImportRecords);
      return;
    }
    if (records.length == 1) {
      await _startQuickImport(records.first);
      return;
    }
    // 多个宏录制，弹窗选择
    final chosen = await showHyperosDialog<WarehouseMacroRecord>(
      context: context,
      title: l10n.selectQuickImportTitle,
      body: HyperosChoiceGroup(
        children: [
          for (final record in records)
            HyperosChoiceTile(
              title: record.schoolName,
              subtitle: Text(
                l10n.quickImportMacroSteps(
                  record.adapterName,
                  record.steps.length,
                ),
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
    final l10n = AppLocalizations.of(context)!;
    final customUrl = await _preferencesService.getCustomImportUrl(
      macro.adapterId,
    );
    final initialUrl = resolveWarehouseImportUrl(
      customImportUrl: customUrl,
      defaultUrl: macro.importUrl,
    );
    if (!mounted || initialUrl == null) {
      if (mounted) {
        _showLightTip(context, l10n.noValidWarehouseLoginUrl);
      }
      return;
    }

    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/quick-import-top',
        ),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: l10n.quickImportTitle(macro.schoolName),
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
            description: AppLocalizations.of(context)!
                .courseImportQuickImportDescription(
                  macro.schoolName,
                  macro.adapterName,
                ),
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
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.importMethodWarehouseTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.flash_on_rounded),
          semanticsLabel: l10n.quickImportTooltip,
          onPress: _handleQuickImport,
        ),
        Builder(
          key: _warehouseMoreMenuKey,
          builder: (context) => FHeaderAction(
            icon: const Icon(Icons.more_vert_rounded),
            semanticsLabel: l10n.moreActionsTooltip,
            onPress: _showWarehouseMoreMenu,
          ),
        ),
      ],
      headerExtension: HyperosBlurredHeaderExtension(
        child: Row(
          children: [
            Expanded(
              child: HyperosTextField(
                controller: _searchController,
                hint: l10n.searchSchoolHint,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            if (_searchQuery.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              HyperosIconButton(
                icon: Icons.close_rounded,
                tooltip: l10n.clearSearchTooltip,
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              ),
            ],
          ],
        ),
      ),
      childPad: false,
      // Standard scroll path so the large title collapses with scroll (see the
      // ICS import screen above); centered states inset manually below.
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<WarehouseRootIndex>(
                  future: _rootIndexFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Non-scroll centered view: inset below the bar manually.
                      return HyperosBlurredBodyInset(
                        child: _importLoadingCenter(),
                      );
                    }
                    if (snapshot.hasError) {
                      return HyperosListView(
                        children: [
                          HyperosSectionLabel(
                            text: l10n.warehouseRootLoadFailedTitle,
                          ),
                          HyperosControlCard(
                            child: HyperosControlCardInset(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _importListDetail(
                                    context,
                                    localizeServiceError(l10n, snapshot.error!),
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
                        final initialCompare = left.initial.compareTo(
                          right.initial,
                        );
                        if (initialCompare != 0) return initialCompare;
                        return left.name.compareTo(right.name);
                      });
                    final filteredSchools = _filterSchools(
                      allSchools,
                      _searchQuery,
                    );
                    final beans = _schoolsToBeans(
                      filteredSchools,
                      _recentSchoolIds,
                    );
                    final sections = _schoolsToSections(beans);
                    final indexTags = sections
                        .map((section) => section.tag)
                        .toList(growable: false);
                    final isSearching = _searchQuery.trim().isNotEmpty;
                    if (sections.isEmpty) {
                      // Non-scroll centered view: inset below the bar manually.
                      return HyperosBlurredBodyInset(
                        child: Center(
                          child: HyperosEmptyState(
                            icon: Icons.search_off_rounded,
                            title: isSearching
                                ? l10n.noMatchingSchools
                                : l10n.noAvailableSchools,
                            subtitle: isSearching
                                ? l10n.searchSchoolSuggestion
                                : null,
                          ),
                        ),
                      );
                    }
                    // Header inset inside the scrollable so rows slide under
                    // the frosted bar (mirrors HyperosListView's default).
                    final headerInset = HyperosBlurredHeaderScope.insetOf(
                      context,
                    );
                    return AzListView(
                      data: sections,
                      itemCount: sections.length,
                      padding: EdgeInsets.fromLTRB(16, headerInset, 16, 16),
                      indexBarData: isSearching ? const [] : indexTags,
                      indexBarOptions: IndexBarOptions(
                        needRebuild: true,
                        hapticFeedback: true,
                        textStyle: HyperosTypography.listDetail(context)
                            .copyWith(
                              fontSize: HyperosMiuixTypography.footnote2,
                              color: HyperosColors.secondaryText(context),
                            ),
                        selectTextStyle: HyperosTypography.listDetail(context)
                            .copyWith(
                              fontSize: HyperosMiuixTypography.footnote2,
                              color: HyperosColors.primary(context),
                            ),
                        selectItemDecoration: BoxDecoration(
                          color: HyperosColors.primary(
                            context,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        indexHintDecoration: BoxDecoration(
                          color: HyperosColors.card(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        indexHintTextStyle: HyperosTypography.title(
                          context,
                        ).copyWith(color: HyperosColors.primary(context)),
                      ),
                      indexHintBuilder: (context, tag) => Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: HyperosColors.card(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: HyperosTypography.title(
                            context,
                          ).copyWith(color: HyperosColors.primary(context)),
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            HyperosChoiceGroup(
                              children: [
                                for (final bean in section.items)
                                  HyperosChoiceTile(
                                    prefix: _ImportInitialBadge(
                                      label: bean.school.initial,
                                    ),
                                    title: bean.school.name,
                                    subtitle: Text(
                                      bean.isRecent
                                          ? l10n.recentSchoolLabel
                                          : l10n.warehouseSchoolTapHint,
                                    ),
                                    trailing: const HyperosChevron(),
                                    onTap: () =>
                                        _openWarehouseSchool(bean.school),
                                  ),
                              ],
                            ),
                            if (index < sections.length - 1)
                              const HyperosSectionGap(),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _openWarehouseSchool(WarehouseSchoolEntry school) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: RouteSettings(name: '/courses/import/warehouse/${school.id}'),
        builder: (_) => WarehouseSchoolAdaptersScreen(
          source: _defaultSource,
          school: school,
          fetchOptions: _currentFetchOptions(),
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
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
      child: _isLoading
          // Non-scroll centered view: inset below the bar manually.
          ? HyperosBlurredBodyInset(child: _importLoadingCenter())
          : HyperosListView(
                  children: [
                    HyperosControlCard(
                      title: l10n.customDebugIntroTitle,
                      subtitle: l10n.customDebugIntroSubtitle,
                      child: HyperosControlCardInset(
                        child: HyperosButton(
                          label: l10n.addDebugRecordAction,
                          onPressed: () => _openEditor(),
                        ),
                      ),
                    ),
                    const HyperosSectionGap(),
                    if (_records.isEmpty)
                      _ImportSectionCard(
                        padding: const EdgeInsets.all(20),
                        child: HyperosEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: l10n.noSavedDebugRecords,
                          subtitle: l10n.noSavedDebugRecordsHint,
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
                                      child: _importListTitle(
                                        context,
                                        record.name,
                                      ),
                                    ),
                                    _importListDetail(
                                      context,
                                      _formatDebugRecordDateTime(
                                        record.updatedAt,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  record.importUrl,
                                  style: HyperosTypography.listDetail(context)
                                      .copyWith(
                                        color: HyperosColors.primary(context),
                                      ),
                                ),
                                const SizedBox(height: 6),
                                _importListDetail(
                                  context,
                                  l10n.debugScriptLength(record.script.length),
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
      final result = await FilePicker.pickFiles(
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
      // Standard list path so the large title collapses with scroll (see the
      // ICS import screen above).
      child: HyperosListView(
            children: [
              HyperosSectionLabel(text: l10n.debugRecordFormula),
              const HyperosSectionGap(),
              HyperosTextField(
                controller: _nameController,
                label: l10n.debugRecordNameLabel,
                hint: l10n.debugRecordNameHint,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              HyperosTextField(
                controller: _urlController,
                label: l10n.importUrlLabel,
                hint: 'https://...',
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _importListTitle(context, l10n.debugScriptLabel),
                  ),
                  HyperosButton(
                    label: l10n.importFromFileAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _pickScriptFromFile,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              HyperosTextField(
                controller: _scriptController,
                hint: l10n.debugScriptHint,
                minLines: 14,
                maxLines: 24,
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
  final Map<String, String?> _customImportUrlCache = {};
  String? _customImportUrlAdapterSignature;
  bool _customImportUrlCheckInFlight = false;

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
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(widget.school.name),
      childPad: false,
      // Standard scroll path so the large title collapses with scroll (see the
      // ICS import screen above); the loading state insets manually.
      child: FutureBuilder<WarehouseAdaptersIndex>(
            future: _adaptersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Non-scroll centered view: inset below the bar manually.
                return HyperosBlurredBodyInset(
                  child: _importLoadingCenter(),
                );
              }
              if (snapshot.hasError) {
                return HyperosListView(
                  children: [
                    HyperosSectionLabel(
                      text: l10n.warehouseAdaptersLoadFailedTitle,
                    ),
                    HyperosControlCard(
                      child: HyperosControlCardInset(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _importListDetail(
                              context,
                              localizeServiceError(l10n, snapshot.error!),
                            ),
                            const SizedBox(height: 12),
                            HyperosButton(
                              label: l10n.reloadAction,
                              variant: HyperosButtonVariant.secondary,
                              onPressed: _reloadAdapters,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              final adapters =
                  snapshot.data?.adapters ?? const <WarehouseAdapterEntry>[];
              // 检查每个适配器是否有宏录制
              _scheduleMacroCacheCheck(adapters);
              _scheduleCustomImportUrlCacheCheck(adapters);
              return HyperosListView(
                children: [
                  HyperosListGroup(
                    children: [
                      for (final adapter in adapters)
                        _buildWarehouseAdapterListItem(
                          context: context,
                          adapter: adapter,
                          hasMacro: _macroCache[adapter.adapterId] ?? false,
                          importButtonLabel: _adapterHasImportUrl(adapter)
                              ? l10n.webLoginImport
                              : l10n.fillUrlThenImport,
                          recordButtonLabel: _adapterHasImportUrl(adapter)
                              ? l10n.recordImportAction
                              : l10n.fillUrlThenRecord,
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
                            if (context.mounted) {
                              await _refreshCustomImportUrlCacheForAdapter(
                                adapter.adapterId,
                              );
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
    );
  }

  void _reloadAdapters() {
    setState(() {
      _adaptersFuture = _repositoryService.fetchAdaptersIndex(
        widget.source,
        widget.school,
        options: widget.fetchOptions,
      );
    });
  }

  bool _adapterHasImportUrl(WarehouseAdapterEntry adapter) {
    return resolveWarehouseImportUrl(
          customImportUrl: _customImportUrlCache[adapter.adapterId],
          defaultUrl: adapter.importUrl,
        ) !=
        null;
  }

  Future<void> _openAdapterImport(
    WarehouseAdapterEntry adapter, {
    bool autoRecord = false,
  }) async {
    final initialUrl = await _resolveAdapterImportUrl(adapter);
    if (initialUrl == null || !mounted) {
      return;
    }
    // Explicit "record import" always records. Ordinary import auto-records
    // only when this school+adapter has no saved macro yet (first import).
    final hasExistingMacro = await _macroService.hasMacro(
      widget.school.id,
      adapter.adapterId,
    );
    if (!mounted) {
      return;
    }
    final shouldRecord = shouldAutoRecordWarehouseImport(
      forceRecord: autoRecord,
      hasExistingMacro: hasExistingMacro,
    );
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
          autoRecord: shouldRecord,
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
    // 从导入/录制页面返回后刷新单适配器的宏缓存与自定义网址
    if (mounted) {
      await _refreshMacroCacheForAdapter(adapter.adapterId);
      await _refreshCustomImportUrlCacheForAdapter(adapter.adapterId);
    }
  }

  void _scheduleCustomImportUrlCacheCheck(
    List<WarehouseAdapterEntry> adapters,
  ) {
    final signature = _macroCacheSignatureForAdapters(adapters);
    final hasAllValues = adapters.every(
      (adapter) => _customImportUrlCache.containsKey(adapter.adapterId),
    );
    if (_customImportUrlCheckInFlight ||
        (_customImportUrlAdapterSignature == signature && hasAllValues)) {
      return;
    }
    _customImportUrlCheckInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _checkCustomImportUrlsForAdapters(adapters, signature);
    });
  }

  Future<void> _checkCustomImportUrlsForAdapters(
    List<WarehouseAdapterEntry> adapters,
    String signature,
  ) async {
    final nextCache = <String, String?>{};
    try {
      for (final adapter in adapters) {
        final custom = await _preferencesService.getCustomImportUrl(
          adapter.adapterId,
        );
        if (!mounted) return;
        nextCache[adapter.adapterId] = custom;
      }
    } catch (_) {
      if (mounted) {
        _customImportUrlCheckInFlight = false;
      }
      return;
    }
    if (!mounted) return;

    final changed =
        _customImportUrlAdapterSignature != signature ||
        _customImportUrlCache.length != nextCache.length ||
        nextCache.entries.any(
          (entry) => _customImportUrlCache[entry.key] != entry.value,
        );
    if (!changed) {
      _customImportUrlAdapterSignature = signature;
      _customImportUrlCheckInFlight = false;
      return;
    }

    setState(() {
      _customImportUrlCache
        ..clear()
        ..addAll(nextCache);
      _customImportUrlAdapterSignature = signature;
      _customImportUrlCheckInFlight = false;
    });
  }

  Future<void> _refreshCustomImportUrlCacheForAdapter(String adapterId) async {
    final custom = await _preferencesService.getCustomImportUrl(adapterId);
    if (!mounted) return;
    if (_customImportUrlCache[adapterId] != custom) {
      setState(() {
        _customImportUrlCache[adapterId] = custom;
      });
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
    final l10n = AppLocalizations.of(context)!;
    final initialUrl = await _resolveAdapterImportUrl(adapter);
    if (!mounted || initialUrl == null) return;

    final macro = await _macroService.getMacro(
      widget.school.id,
      adapter.adapterId,
    );
    if (!mounted) return;
    if (macro == null) {
      _showLightTip(context, l10n.noMacroRecordFound);
      return;
    }

    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/quick-import',
        ),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: l10n.quickImportTitle(adapter.adapterName),
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
  final WarehouseMacroService _macroService = WarehouseMacroService();
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
    final colorScheme = Theme.of(context).colorScheme;
    final adapter = widget.adapter;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(adapter.adapterName),
      childPad: false,
      // Standard list path so the large title collapses with scroll (see the
      // ICS import screen above).
      child: HyperosListView(
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
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.adapterInfoTitle),
              HyperosControlCard(
                child: HyperosControlCardInset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailLine(
                        label: 'adapter_id',
                        value: adapter.adapterId,
                      ),
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
              ),
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.scriptStatusTitle),
              FutureBuilder<String>(
                future: _scriptFuture,
                builder: (context, snapshot) {
                  final readable =
                      snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasError &&
                      (snapshot.data?.trim().isNotEmpty ?? false);
                  return HyperosControlCard(
                    child: HyperosControlCardInset(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const HyperosLinearProgress(minHeight: 3)
                          else if (readable)
                            _importListDetail(
                              context,
                              l10n.scriptLoadedLength(snapshot.data!.length),
                            )
                          else
                            Text(
                              snapshot.hasError
                                  ? localizeServiceError(l10n, snapshot.error!)
                                  : l10n.scriptEmpty,
                              style: HyperosTypography.listDetail(
                                context,
                              ).copyWith(color: colorScheme.error),
                            ),
                        ],
                      ),
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
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.moreActionsTooltip),
              HyperosListGroup(
                children: [
                  HyperosNavTile(
                    title: l10n.openInSystemBrowserAction,
                    enabled: _effectiveImportUrl.isNotEmpty,
                    onTap: _effectiveImportUrl.isEmpty
                        ? null
                        : () => _openImportUrl(_effectiveImportUrl),
                  ),
                  HyperosNavTile(
                    title: l10n.copyLoginAddressAction,
                    enabled: _effectiveImportUrl.isNotEmpty,
                    onTap: _effectiveImportUrl.isEmpty
                        ? null
                        : () => _copyText(
                            _effectiveImportUrl,
                            successMessage: l10n.copiedImportLoginUrl,
                          ),
                  ),
                  HyperosNavTile(
                    title: l10n.copyScriptAddressAction,
                    onTap: () => _copyText(
                      widget.source
                          .buildRawFileUri(
                            'resources/${widget.school.resourceFolder}/${adapter.assetJsPath}',
                          )
                          .toString(),
                      successMessage: l10n.copiedScriptRawUrl,
                    ),
                  ),
                  HyperosNavTile(
                    title: (_customImportUrl ?? '').isEmpty
                        ? l10n.customLoginAddressAction
                        : l10n.editCustomLoginAddressAction,
                    onTap: _editCustomImportUrl,
                  ),
                  if ((_customImportUrl ?? '').isNotEmpty)
                    HyperosNavTile(
                      title: adapter.importUrl.isEmpty
                          ? l10n.clearCustomLoginAddressAction
                          : l10n.restoreRepositoryAddressAction,
                      onTap: _clearCustomImportUrl,
                    ),
                ],
              ),
            ],
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
    final hasExistingMacro = await _macroService.hasMacro(
      widget.school.id,
      widget.adapter.adapterId,
    );
    if (!mounted) {
      return;
    }
    final shouldRecord = shouldAutoRecordWarehouseImport(
      forceRecord: false,
      hasExistingMacro: hasExistingMacro,
    );
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
              autoRecord: shouldRecord,
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

  /// When true, the WebView runs off-screen and UI chrome is hidden. Used by
  /// home pull-to-refresh quick import so the page never appears.
  final bool runInBackground;

  /// Called when background playback needs user input (captcha / password).
  final VoidCallback? onBackgroundNeedsManualAction;

  /// Called when background import finishes (success or failure).
  final ValueChanged<bool>? onBackgroundFinished;

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
    this.runInBackground = false,
    this.onBackgroundNeedsManualAction,
    this.onBackgroundFinished,
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
  final GlobalKey _webLoginMoreMenuKey = GlobalKey();
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
  bool _quickImportResultHandled = false;

  bool get _isUsingLocalDebugScript =>
      (widget.debugScriptOverride ?? '').trim().isNotEmpty;

  void _debugImportLog(String message, {String level = 'info'}) {
    final detail =
        'macro=$_isMacroReplay '
        'playback=$_playbackState '
        'executing=$_isExecutingImport '
        'recording=$_macroRecordingState '
        'status="${_lastScriptStatus ?? ''}" '
        '$message';
    WarehouseImportSessionLog.instance.append(
      message: detail,
      level: level,
      extras: {
        'schoolId': widget.school.id,
        'schoolName': widget.school.name,
        'adapterId': widget.adapter.adapterId,
        'adapterName': widget.adapter.adapterName,
        'url': _currentUrl ?? widget.initialUrl,
        'macroReplay': _isMacroReplay,
        'executingImport': _isExecutingImport,
        'playbackState': '$_playbackState',
        'recordingState': '$_macroRecordingState',
      },
    );
    if (!kDebugMode) return;
    appDebugLog('WarehouseImportDebug', detail);
  }

  String _bridgeMessageSummary(Map<String, dynamic> message) {
    final type = message['type'];
    final keys = message.keys.join(',');
    final payload = message['payload'];
    final payloadLength = payload is String ? payload.length : null;
    final errorMessage = message['message'];
    return 'type=$type keys=[$keys] payloadLength=$payloadLength message=$errorMessage';
  }

  /// Adapter scripts often toast "成功导入 N 条课程" right before the host shows
  /// the quick-import completion sheet. Match common success phrasings so we
  /// can suppress the redundant light tip during macro replay.
  bool _isScriptImportSuccessToast(String message) {
    final text = message.trim();
    if (text.isEmpty) {
      return false;
    }
    final lower = text.toLowerCase();
    return text.contains('成功导入') ||
        text.contains('导入成功') ||
        text.contains('导入完成') ||
        (text.contains('导入') && text.contains('条课程')) ||
        lower.contains('import success') ||
        lower.contains('imported') && lower.contains('course');
  }

  /// Progress toasts from adapter scripts ("正在获取课表…") are redundant with
  /// the quick-import playback overlay / completion sheet.
  bool _isScriptImportProgressToast(String message) {
    final text = message.trim();
    if (text.isEmpty) {
      return false;
    }
    return text.contains('正在通过接口') ||
        text.contains('正在获取') ||
        text.contains('正在导入') ||
        text.contains('请稍候') ||
        text.contains('请稍等');
  }

  @override
  void initState() {
    super.initState();
    _useDesktopMode = widget.macroRecord?.useDesktopMode ?? true;
    _currentUrl = widget.initialUrl;
    _addressController = TextEditingController(text: widget.initialUrl);
    WarehouseImportSessionLog.instance.append(
      message:
          'open web login school=${widget.school.name}(${widget.school.id}) '
          'adapter=${widget.adapter.adapterName}(${widget.adapter.adapterId}) '
          'url=${widget.initialUrl} macro=${widget.macroRecord != null} '
          'autoRecord=${widget.autoRecord} localDebug=$_isUsingLocalDebugScript',
      extras: {
        'schoolId': widget.school.id,
        'adapterId': widget.adapter.adapterId,
        'url': widget.initialUrl,
      },
    );
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
      ..setOnConsoleMessage((consoleMessage) {
        WarehouseImportSessionLog.instance.append(
          message:
              'console.${consoleMessage.level.name}: ${consoleMessage.message}',
          level: consoleMessage.level.name == 'error' ? 'error' : 'debug',
          extras: {
            'schoolId': widget.school.id,
            'adapterId': widget.adapter.adapterId,
            'url': _currentUrl ?? widget.initialUrl,
          },
        );
      })
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
      final applyError = await provider.applyTimeScheme(created.id);
      if (applyError != null) {
        throw FormatException(applyError);
      }
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
    final applyError = await provider.applyTimeScheme(existingScheme.id);
    if (applyError != null) {
      throw FormatException(applyError);
    }
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

  Future<void> _showWebLoginMoreMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final value = await showHyperosListPopup<String>(
      context: context,
      position: hyperosPopupPositionBelow(context, _webLoginMoreMenuKey),
      items: [
        HyperosPopupMenuItem(
          label: l10n.executeImportScriptAction,
          value: 'execute',
          enabled: !_isExecutingImport,
        ),
        HyperosPopupMenuItem(
          label: l10n.rememberCurrentInputTooltip,
          value: 'remember',
        ),
        HyperosPopupMenuItem(
          label: l10n.fillRememberedTooltip,
          value: 'fill',
          enabled: _rememberedLogin != null,
        ),
        HyperosPopupMenuItem(
          label: l10n.clearRememberedTooltip,
          value: 'clear',
          enabled: _rememberedLogin != null,
        ),
        HyperosPopupMenuItem(
          label: l10n.copyCurrentAddressTooltip,
          value: 'copy',
        ),
        HyperosPopupMenuItem(
          label: l10n.warehouseImportExecutionLogMenuLabel,
          value: 'executionLog',
        ),
      ],
    );
    if (!mounted || value == null) {
      return;
    }
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
        if (mounted) {
          showAppToast(
            context,
            message: l10n.copiedCurrentAddress,
            kind: AppToastKind.success,
          );
        }
        break;
      case 'executionLog':
        await openWarehouseImportExecutionLogViewer(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveDebugScriptName =
        (widget.debugScriptName?.trim().isNotEmpty ?? false)
        ? widget.debugScriptName!.trim()
        : l10n.unnamedScript;
    final currentStatus =
        _lastScriptStatus ??
        (_isUsingLocalDebugScript
            ? l10n.localDebugModeScriptStatus(effectiveDebugScriptName)
            : null);
    if (widget.runInBackground) {
      // Keep the platform WebView attached (size > 0) but fully off-screen so
      // JS / cookies / navigation still work without showing any UI chrome.
      return Offstage(
        offstage: true,
        child: SizedBox(
          width: 1,
          height: 1,
          child: WebViewWidget(controller: _controller),
        ),
      );
    }
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(widget.title),
      suffixes: [
        if (widget.macroRecord == null)
          FHeaderAction(
            icon: _macroRecordingState == MacroRecordingState.recording
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: HyperosCircularProgress(size: 18, strokeWidth: 2),
                  )
                : const Icon(Icons.fiber_manual_record_rounded),
            semanticsLabel:
                _macroRecordingState == MacroRecordingState.recording
                ? l10n.stopRecordingTooltip
                : l10n.startRecordingTooltip,
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
        Builder(
          key: _webLoginMoreMenuKey,
          builder: (context) => FHeaderAction(
            icon: const Icon(Icons.more_vert_rounded),
            semanticsLabel: l10n.moreActionsTooltip,
            onPress: _showWebLoginMoreMenu,
          ),
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
                    color: HyperosColors.card(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 模式标识 + 提示文字（紧凑单行）
                        Row(
                          children: [
                            HyperosTag(
                              label: _useDesktopMode ? '🖥️' : '📱',
                              backgroundColor: HyperosColors.primary(
                                context,
                              ).withValues(alpha: 0.12),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isUsingLocalDebugScript
                                    ? l10n.warehouseLoginHintLocalDebug
                                    : l10n.warehouseLoginHintImport,
                                style: HyperosTypography.listDetail(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isUsingLocalDebugScript)
                              HyperosTag(
                                label: effectiveDebugScriptName,
                                backgroundColor: HyperosColors.primary(
                                  context,
                                ).withValues(alpha: 0.12),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // URL 地址栏
                        Row(
                          children: [
                            Expanded(
                              child: HyperosTextField(
                                controller: _addressController,
                                focusNode: _addressFocusNode,
                                hint: l10n.webAddressHint,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.go,
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
                              style: HyperosTypography.listDetail(
                                context,
                              ).copyWith(color: HyperosColors.primary(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_loadingProgress < 100)
                    HyperosLinearProgress(value: _loadingProgress / 100),
                  Expanded(child: WebViewWidget(controller: _controller)),
                  if (_showImportScriptBar)
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
          ? AppLocalizations.of(context)!.courseImportScriptNoCourses
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

  bool get _showImportScriptBar =>
      !_isMacroReplay || _playbackState == PlaybackUiState.hidden;

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
    if (widget.runInBackground) {
      _debugImportLog('background import error message="$message"');
      widget.onBackgroundFinished?.call(false);
    }
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
            scriptPageUrl:
                sanitizeWarehouseScriptPageUrl(
                  _currentUrl ?? widget.initialUrl,
                ) ??
                existing.scriptPageUrl,
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _playbackState = PlaybackUiState.hidden;
      _isExecutingImport = false;
    });
    await _showQuickImportFinishedSheet();
  }

  Future<void> _showQuickImportFinishedSheet() async {
    if (!mounted || _quickImportResultHandled) {
      return;
    }
    _quickImportResultHandled = true;
    if (widget.runInBackground) {
      _debugImportLog('background quick import finished successfully');
      widget.onBackgroundFinished?.call(true);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final status = (_lastScriptStatus ?? '').trim();
    final description = [
      '${widget.school.name} · ${widget.adapter.adapterName}',
      if (status.isNotEmpty) status,
    ].join('\n');

    await showHyperosSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) {
        return HyperosSheet(
          title: l10n.quickImportFinishedTitle,
          // Put result text above the dismiss button. HyperosSheet renders
          // [child] before [description], so compose layout in [child].
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HyperosSectionDescription(text: description),
              const SizedBox(height: 16),
              HyperosButton(
                label: l10n.quickImportDismissAction,
                expand: true,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
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
      if (script.trim().isEmpty) {
        _debugImportLog('execute import script rejected: empty script');
        if (!mounted) {
          return;
        }
        final emptyScriptMessage = l10n.courseImportScriptFailed;
        _cancelImportTimeout();
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = emptyScriptMessage;
        });
        _showMacroReplayImportError(emptyScriptMessage);
        _showLightTip(context, emptyScriptMessage);
        return;
      }
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

  /// Privileged bridge ops that mutate timetable data may only run while an
  /// import script (manual or macro replay) is actively executing.
  bool get _isPrivilegedBridgeContextActive =>
      _isExecutingImport ||
      (_isMacroReplay && _playbackState == PlaybackUiState.executingImport);

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
        final toastMessage = (message['message'] as String?)?.trim() ?? '';
        if (toastMessage.isEmpty) {
          break;
        }
        // During quick-import / macro replay the host already shows a
        // completion sheet; suppress script success toasts that only report
        // "imported N courses" so users are not hit by two stacked tips.
        if (_isMacroReplay &&
            (_isScriptImportSuccessToast(toastMessage) ||
                _isScriptImportProgressToast(toastMessage))) {
          _debugImportLog(
            'bridge toast suppressed during macro replay message="$toastMessage"',
          );
          break;
        }
        _showLightTip(context, toastMessage);
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
        if (!_isPrivilegedBridgeContextActive) {
          _debugImportLog(
            'bridge saveCourseConfig ignored outside import execution',
          );
          break;
        }
        await _handleSaveCourseConfig(message);
        break;
      case 'savePresetTimeSlots':
        if (!_isPrivilegedBridgeContextActive) {
          _debugImportLog(
            'bridge savePresetTimeSlots ignored outside import execution',
          );
          break;
        }
        await _handleSavePresetTimeSlots(message);
        break;
      case 'error':
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        final errorMessage =
            (message['message'] as String?) ?? l10n.courseImportScriptFailed;
        _debugImportLog('bridge error -> mark failed message="$errorMessage"');
        _cancelImportTimeout();
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = l10n.courseImportScriptFailed;
        });
        _showMacroReplayImportError(errorMessage);
        _showLightTip(context, errorMessage);
        break;
      case 'courses':
        if (!_isPrivilegedBridgeContextActive) {
          _debugImportLog('bridge courses ignored outside import execution');
          break;
        }
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
          if (_quickImportResultHandled) {
            _debugImportLog(
              'bridge complete ignored because quick import result already shown',
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
      // Unrecorded confirms default to true so automated import scripts are
      // not cancelled just because the old macro never saw this dialog.
      final shouldConfirm = recorded == null ? true : recorded == true;
      await _resolveJavaScriptRequest(requestId, shouldConfirm);
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
    final l10n = AppLocalizations.of(context)!;
    final result = await showAppTextInputDialog(
      context,
      title: (message['title'] as String?) ?? l10n.inputRequiredTitle,
      confirmLabel: l10n.saveAction,
      initialValue: (message['defaultValue'] as String?) ?? '',
      validate: (text) {
        if (validatorName == 'validateYearInput' &&
            !RegExp(r'^[0-9]{4}$').hasMatch(text)) {
          _showLightTip(context, l10n.pleaseEnterFourDigitYear);
          return false;
        }
        return true;
      },
      bodyBuilder: (controller) => Column(
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
      if (widget.runInBackground) {
        // Prefer the script-provided selection; fall back to first option.
        final selectedIndex = (message['selectedIndex'] as num?)?.toInt() ?? 0;
        await _resolveJavaScriptRequest(requestId, selectedIndex);
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
    if (!_isSafeBridgeRequestId(requestId)) {
      _debugImportLog('reject unsafe bridge requestId');
      return;
    }
    final encodedValue = jsonEncode(value);
    final encodedRequestId = jsonEncode(requestId);
    await _controller.runJavaScript(
      "window.__qingyuResolvers = window.__qingyuResolvers || {}; "
      "window.__qingyuResolvers[$encodedRequestId]?.($encodedValue); "
      "delete window.__qingyuResolvers[$encodedRequestId];",
    );
  }

  /// Bridge request ids must be alphanumeric tokens (no quotes / script).
  bool _isSafeBridgeRequestId(String requestId) {
    if (requestId.isEmpty || requestId.length > 128) {
      return false;
    }
    for (var index = 0; index < requestId.length; index++) {
      final codeUnit = requestId.codeUnitAt(index);
      final isUpperLetter = codeUnit >= 65 && codeUnit <= 90;
      final isLowerLetter = codeUnit >= 97 && codeUnit <= 122;
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isAllowedSymbol =
          codeUnit == 95 || codeUnit == 46 || codeUnit == 45;
      if (!isUpperLetter && !isLowerLetter && !isDigit && !isAllowedSymbol) {
        return false;
      }
    }
    return true;
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
                (widget.runInBackground
                    ? false
                    : await _askReplaceExisting(
                        context,
                        title: AppLocalizations.of(context)!.courseImportTitle,
                        content: AppLocalizations.of(
                          context,
                        )!.importCourseCountPrompt(parsedCourses.length),
                      ));
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
          (widget.runInBackground
              ? _ImportSemesterConfig(
                  semesterStartDate:
                      provider.settings.semesterStartDate ?? DateTime.now(),
                  firstCourseWeek: 1,
                )
              : await _pickImportSemesterConfig(
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
                ));
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

      final coursesToImport = await _coursesWithOptionalRandomColors(
        alignedCourses,
      );
      if (!mounted) {
        return;
      }
      _debugImportLog(
        'importParsedCourses start alignedCount=${coursesToImport.length} replaceExisting=$replaceExisting semesterStart=${semesterConfig.semesterStartDate.toIso8601String()}',
      );
      final importedCount = await provider.importParsedCourses(
        coursesToImport,
        replaceExisting: replaceExisting,
        semesterStart: semesterConfig.semesterStartDate,
        source: 'warehouse',
        preserveLocalColors: await _shouldPreserveLocalColorsOnImport(),
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
      // Quick-import replay already shows a completion sheet with the same
      // status text; skip the 2s light tip to avoid a double toast.
      if (!replaying) {
        _showLightTip(
          context,
          importedCount > 0
              ? AppLocalizations.of(context)!.importUpdatedCount(importedCount)
              : AppLocalizations.of(context)!.importNoCourseChanges,
        );
      }
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
              .where(
                (item) =>
                    item > 0 &&
                    item <= ImportExportLogic.maxAllowedSemesterWeekCount,
              )
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
      final normalizedDay = Course.normalizeDayOfWeek(day);
      final normalizedSections = Course.normalizeSections(
        startSection: startSection,
        endSection: endSection,
      );
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
          dayOfWeek: normalizedDay,
          startSection: normalizedSections.startSection,
          endSection: normalizedSections.endSection,
          startWeek: weeks.first,
          endWeek: weeks.last,
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
  const setInputValue = (input, nextValue) => {
    if (!input) return false;
    // 已是目标值则不改写，避免触发页面「清空再输入」监听。
    if (String(input.value || '') === nextValue) return false;
    input.focus();
    input.value = nextValue;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  };
  if (textInputs[0]) {
    setInputValue(textInputs[0], ${jsonEncode(login.username)});
  }
  if (passwordInput) {
    setInputValue(passwordInput, ${jsonEncode(login.password)});
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
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _macroRecordingState = MacroRecordingState.recording;
      _macroRawEvents = [];
      _lastScriptStatus = l10n.courseImportRecordingStatus;
    });
    // Each recording session must start with a clean dialog map so a previous
    // stop-and-discard (or re-record on the same WebView) cannot leak answers.
    _macroDialogResponses.clear();
    // 在当前页面注入录制 JS
    _injectMacroRecorderJs();
    // First-import auto-record uses a lighter tip so users are not startled.
    _showLightTip(
      context,
      widget.autoRecord
          ? l10n.courseImportAutoRecordingStartedTip
          : l10n.courseImportRecordingStartedTip,
    );
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

    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _macroRecordingState = MacroRecordingState.stopped;
    });

    // No steps captured: finish import without offering to save a path.
    if (steps.isEmpty) {
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
      });
      _macroDialogResponses.clear();
      Navigator.of(context).pop(true);
      return;
    }

    // Ask whether to keep this first-import (or explicit-record) path.
    final shouldSave = await showAppConfirmDialog(
      context,
      title: l10n.courseImportSaveRecordingTitle,
      message: widget.autoRecord
          ? l10n.courseImportSaveAutoRecordingMessage(steps.length)
          : l10n.courseImportSaveRecordingMessage(steps.length),
      confirmLabel: l10n.saveAction,
    );

    if (!mounted) {
      return;
    }

    if (shouldSave == true) {
      final now = DateTime.now();
      final record = WarehouseMacroRecord(
        schoolId: widget.school.id,
        adapterId: widget.adapter.adapterId,
        schoolName: widget.school.name,
        adapterName: widget.adapter.adapterName,
        importUrl: widget.initialUrl,
        scriptPageUrl: sanitizeWarehouseScriptPageUrl(
          _currentUrl ?? widget.initialUrl,
        ),
        schoolResourceFolder: widget.school.resourceFolder,
        adapterAssetJsPath: widget.adapter.assetJsPath,
        steps: steps,
        dialogResponses: Map<String, dynamic>.from(_macroDialogResponses),
        createdAt: now,
        updatedAt: now,
        successfulImportCount: 1,
        useDesktopMode: _useDesktopMode,
      );
      _macroDialogResponses.clear();
      await _macroService.saveMacro(record);
      if (!mounted) {
        return;
      }
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
        _lastScriptStatus = l10n.courseImportRecordingSavedStatus(steps.length);
      });
    } else {
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
        _lastScriptStatus = null;
      });
      _macroDialogResponses.clear();
    }

    if (mounted) {
      // Import already succeeded; always return true so parent can close.
      Navigator.of(context).pop(true);
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
        _lastScriptStatus = l10n.courseImportRecordingEmptyStatus;
      });
      _macroDialogResponses.clear();
      _showLightTip(context, l10n.courseImportRecordingEmptyTip);
      return;
    }

    // 询问用户是否要保存
    final shouldSave = await showAppConfirmDialog(
      context,
      title: l10n.courseImportSaveRecordingTitle,
      message: l10n.courseImportSaveRecordingMessage(steps.length),
      confirmLabel: l10n.saveAction,
    );

    if (shouldSave != true || !mounted) {
      setState(() {
        _macroRecordingState = MacroRecordingState.idle;
        _macroRawEvents = [];
        _lastScriptStatus = null;
      });
      _macroDialogResponses.clear();
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
      scriptPageUrl: sanitizeWarehouseScriptPageUrl(
        _currentUrl ?? widget.initialUrl,
      ),
      schoolResourceFolder: widget.school.resourceFolder,
      adapterAssetJsPath: widget.adapter.assetJsPath,
      steps: steps,
      dialogResponses: Map<String, dynamic>.from(_macroDialogResponses),
      createdAt: now,
      updatedAt: now,
      successfulImportCount: 0,
      useDesktopMode: _useDesktopMode,
    );

    _macroDialogResponses.clear();
    await _macroService.saveMacro(record);
    if (!mounted) return;

    setState(() {
      _macroRecordingState = MacroRecordingState.idle;
      _macroRawEvents = [];
      _lastScriptStatus = l10n.courseImportRecordingSavedStatus(steps.length);
    });
    // 保存后自动返回适配器列表，用户即可看到快捷导入按钮
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ============ 宏回放方法 ============

  Future<void> _startPlayback(WarehouseMacroRecord macro) async {
    final acceleratedPreview = buildAcceleratedMacroSteps(
      compactMacroFillSteps(macro.steps),
      scriptPageUrl: macro.scriptPageUrl,
      importUrl: macro.importUrl,
    );
    final willAccelerate =
        acceleratedPreview.length < compactMacroFillSteps(macro.steps).length;
    _debugImportLog(
      'start playback macro steps=${macro.steps.length} '
      'acceleratedSteps=${acceleratedPreview.length} '
      'willAccelerate=$willAccelerate '
      'scriptPageUrl=${macro.scriptPageUrl ?? "(null)"} '
      'importUrl=${macro.importUrl} '
      'adapter=${macro.adapterId}',
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
      l10n: AppLocalizations.of(context)!,
      callbacks: ReplayCallbacks(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _playbackProgress = progress;
          });
        },
        onPauseForManualInput: (step, reason) async {
          if (!mounted) return false;
          if (shouldUseRememberedPasswordForManualStep(
            step,
            reason,
            AppLocalizations.of(context)!,
          )) {
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
              // 始终走 autofill：内部 setInputValue 对已有正确值会跳过改写，
              // 但不会连带跳过学号/用户名（避免密码已满、用户名为空）。
              await _autofillRememberedLogin();
              await Future.delayed(const Duration(milliseconds: 300));
              if (!mounted) return false;
              setState(() {
                _playbackState = PlaybackUiState.playing;
              });
              return true;
            }
          }
          if (widget.runInBackground) {
            _debugImportLog(
              'background playback needs manual input reason=$reason',
            );
            widget.onBackgroundNeedsManualAction?.call();
            widget.onBackgroundFinished?.call(false);
            return false;
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
            if (widget.runInBackground) {
              widget.onBackgroundFinished?.call(false);
              return;
            }
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
    if (mounted) {
      setState(() {
        _playbackState = PlaybackUiState.hidden;
      });
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
    final text = label.trim().isEmpty ? '#' : label.trim();
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: HyperosColors.primary(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: HyperosTypography.listDetail(
          context,
        ).copyWith(color: HyperosColors.primary(context)),
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
        borderRadius: BorderRadius.circular(12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HyperosControlCard(
          title: l10n.applicableScenarioTitle,
          subtitle: scenarioIntro,
          child: HyperosControlCardInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuideLine(title: l10n.stepLabel('1'), subtitle: step1Subtitle),
                const SizedBox(height: 10),
                _GuideLine(title: l10n.stepLabel('2'), subtitle: step2Subtitle),
                const SizedBox(height: 10),
                _GuideLine(title: l10n.stepLabel('3'), subtitle: step3Subtitle),
              ],
            ),
          ),
        ),
        const HyperosSectionGap(),
        HyperosControlCard(
          title: l10n.supportedFilesTitle,
          child: HyperosControlCardInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _importListDetail(context, supportedFilesSuffix),
                if (supportedFilesExtra != null) ...[
                  const SizedBox(height: 4),
                  _importListDetail(context, supportedFilesExtra!),
                ],
              ],
            ),
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
    return HyperosControlCard(
      title: title,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((markdown ?? '').trim().isNotEmpty)
              MarkdownBody(
                data: markdown!,
                styleSheet: MarkdownStyleSheet.fromTheme(
                  theme,
                ).copyWith(p: HyperosTypography.sectionDescription(context)),
              ),
            if (chips.isNotEmpty) ...[
              if ((markdown ?? '').trim().isNotEmpty)
                const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips
                    .map((item) => HyperosTag(label: item))
                    .toList(growable: false),
              ),
            ],
            if ((markdown ?? '').trim().isEmpty && chips.isEmpty)
              const SizedBox.shrink(),
          ],
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _importListTitle(context, adapter.adapterName),
        const SizedBox(height: 4),
        _importListDetail(
          context,
          '${l10n.categoryLabel}：${adapter.category} · ${l10n.maintainerLabel}：${adapter.maintainer}',
        ),
        if (adapter.description.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          MarkdownBody(
            data: adapter.description,
            styleSheet: MarkdownStyleSheet.fromTheme(
              theme,
            ).copyWith(p: HyperosTypography.sectionDescription(context)),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: HyperosButton(
                label: importButtonLabel,
                expand: true,
                fitLabel: true,
                onPressed: onImport,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HyperosButton(
                label: recordButtonLabel,
                variant: HyperosButtonVariant.secondary,
                expand: true,
                fitLabel: true,
                onPressed: onRecord,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: HyperosButton(
            label: l10n.viewDetailsAction,
            variant: HyperosButtonVariant.secondary,
            onPressed: onInfo,
          ),
        ),
        if (hasMacro) ...[
          const SizedBox(height: 10),
          HyperosButton(
            label: l10n.quickImportAction,
            expand: true,
            onPressed: onQuickImport,
          ),
        ],
      ],
    );
  }
}

class _WarehouseSchoolSection extends ISuspensionBean {
  _WarehouseSchoolSection({required this.tag, required this.items});

  final String tag;
  final List<_WarehouseSchoolBean> items;

  @override
  String getSuspensionTag() => tag;
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

List<_WarehouseSchoolSection> _schoolsToSections(
  List<_WarehouseSchoolBean> beans,
) {
  if (beans.isEmpty) {
    return const [];
  }

  final sections = <_WarehouseSchoolSection>[];
  var currentTag = beans.first.tag;
  var currentItems = <_WarehouseSchoolBean>[];

  for (final bean in beans) {
    if (bean.tag != currentTag) {
      sections.add(
        _WarehouseSchoolSection(tag: currentTag, items: currentItems),
      );
      currentTag = bean.tag;
      currentItems = [bean];
    } else {
      currentItems.add(bean);
    }
  }
  sections.add(_WarehouseSchoolSection(tag: currentTag, items: currentItems));
  SuspensionUtil.setShowSuspensionStatus(sections);
  return sections;
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _importListDetail(context, label),
          const SizedBox(height: 2),
          Text(value, style: HyperosTypography.listTitle(context)),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HyperosColors.primary(context).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            title.replaceAll('步骤 ', ''),
            style: HyperosTypography.listDetail(
              context,
            ).copyWith(color: HyperosColors.primary(context)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _importListTitle(context, title),
              const SizedBox(height: 2),
              _importListDetail(context, subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiPreviewCard extends StatelessWidget {
  final AiCourseImportParseResult result;

  const _AiPreviewCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosControlCard(
      title: l10n.aiPreviewTitle,
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _importListDetail(
              context,
              l10n.aiPreviewCourseCount(result.courses.length),
            ),
            _importListDetail(
              context,
              l10n.aiPreviewMaxSection(result.requiredSectionCount),
            ),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              _importCardHeading(context, l10n.aiPreviewWarningsTitle),
              const SizedBox(height: 6),
              ...result.warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _importListDetail(context, '• $warning'),
                ),
              ),
            ],
            if (result.courses.isNotEmpty) ...[
              const SizedBox(height: 10),
              _importCardHeading(context, l10n.aiPreviewCoursesTitle),
              const SizedBox(height: 6),
              ...result.courses
                  .take(6)
                  .map((course) => _buildCoursePreviewLine(context, course)),
              if (result.courses.length > 6)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _importListDetail(
                    context,
                    l10n.aiPreviewRemainingCourses(result.courses.length - 6),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoursePreviewLine(BuildContext context, Course course) {
    final l10n = AppLocalizations.of(context)!;
    final weeks = course.customWeeks ?? const [];
    final weekText = weeks.isEmpty
        ? l10n.courseImportWeekNotProvided
        : weeks.length <= 6
        ? weeks.join(l10n.weekListSeparator)
        : '${weeks.first}-${weeks.last}（共 ${weeks.length} 周）';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _importListDetail(
        context,
        l10n.courseImportPreviewLine(
          _weekdayLabel(l10n, course.dayOfWeek),
          course.startSection,
          course.endSection,
          course.name,
          course.location.isEmpty
              ? l10n.courseImportLocationNotFilled
              : course.location,
          weekText,
        ),
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
      final l10n = AppLocalizations.of(sheetContext)!;
      var selectedSemesterStartDate = initialSemesterStartDate;
      var selectedFirstCourseWeek = initialFirstCourseWeek < 1
          ? 1
          : initialFirstCourseWeek > 20
          ? 20
          : initialFirstCourseWeek;
      var autoTrackWeekMapping = inferredFirstCourseDate != null;
      final weekItems = {
        for (var i = 1; i <= 20; i++) l10n.calendarWeekOption(i): i,
      };

      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickStartDate() async {
            final picked = await showMiuixDatePickerSheet(
              context,
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
                  HyperosListGroup(
                    children: [
                      HyperosNavTile(
                        title: l10n.importSemesterStartDateTitle,
                        subtitle:
                            '${_formatDate(selectedSemesterStartDate)} · ${l10n.importSemesterStartDateSubtitle}',
                        onTap: pickStartDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HyperosControlCard(
                    edgeToEdge: true,
                    child: HyperosControlCardRowScope(
                      isFirst: true,
                      // Lone select row is also the card bottom edge.
                      isLast: true,
                      child: HyperosSelectTile<int>(
                        label: l10n.importFirstCourseWeekMappingLabel,
                        subtitle: l10n.importFirstCourseWeekMappingSubtitle,
                        items: weekItems,
                        value: selectedFirstCourseWeek,
                        useSheetForPopup: true,
                        onChanged: (picked) {
                          setModalState(() {
                            selectedFirstCourseWeek = picked;
                            autoTrackWeekMapping = false;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  HyperosCard(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      shiftedWeeks <= 0
                          ? l10n.importSemesterMappingNoShiftHint
                          : l10n.importSemesterMappingShiftHint(
                              shiftedWeeks,
                              selectedFirstCourseWeek,
                            ),
                      style: HyperosTypography.sectionDescription(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: HyperosButton(
                          label: l10n.cancelAction,
                          variant: HyperosButtonVariant.secondary,
                          expand: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HyperosButton(
                          label: l10n.spreadsheetImportWarningsContinue,
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
  final l10n = AppLocalizations.of(context)!;
  return showAppTripleActionDialog(
    context,
    title: title,
    message: '$content\n\n建议日常更新课表时优先使用「更新课表」：会保留本地独有课程，并合并导入文件中的课程',
    cancelLabel: l10n.cancelAction,
    secondaryLabel: l10n.courseImportUpdateRecommendedAction,
    primaryLabel: l10n.courseImportOverwriteAction,
  );
}

Future<bool> _ensureSectionCapacity(
  BuildContext context, {
  required int requiredSectionCount,
  required TimetableProvider provider,
  bool autoConfirm = false,
}) async {
  if (requiredSectionCount <= provider.settings.sectionCount) {
    return true;
  }

  final l10n = AppLocalizations.of(context)!;
  final shouldContinue = autoConfirm
      ? true
      : await showAppConfirmDialog(
          context,
          title: l10n.courseImportSectionCountInsufficientTitle,
          message: l10n.courseImportSectionCountInsufficientMessage(
            provider.settings.sectionCount,
            requiredSectionCount,
          ),
          confirmLabel: l10n.courseImportAutoFillAndImportAction,
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

String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
  return switch (dayOfWeek) {
    1 => l10n.weekdayShortMonday,
    2 => l10n.weekdayShortTuesday,
    3 => l10n.weekdayShortWednesday,
    4 => l10n.weekdayShortThursday,
    5 => l10n.weekdayShortFriday,
    6 => l10n.weekdayShortSaturday,
    7 => l10n.weekdayShortSunday,
    _ => dayOfWeek.toString(),
  };
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
  final l10n = AppLocalizations.of(context)!;
  final result = await showAppTextInputDialog(
    context,
    title: l10n.courseImportPortalUrlTitle,
    cancelLabel: l10n.cancelAction,
    confirmLabel: l10n.courseImportPortalUrlSaveContinue,
    initialValue: initialValue,
    bodyBuilder: (controller) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.courseImportPortalUrlMissingBody(schoolName, adapterName)),
        const SizedBox(height: 12),
        HyperosTextField(
          controller: controller,
          label: l10n.courseImportPortalUrlLabel,
          hint: 'http(s)://...',
          autofocus: true,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.courseImportPortalUrlHint,
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
    _showLightTip(context, l10n.courseImportPortalUrlInvalid);
    return null;
  }
  return result.trim();
}

void _showLightTip(BuildContext context, String message) {
  showAppLightTip(context, message: message);
}
