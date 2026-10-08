// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// AI 图片识课
// 拍照或选图识别课表并写入。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import '../../l10n/service_message_localizer.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../providers/timetable_provider.dart';
import '../../services/ai_course_import_service.dart';
import '../../services/import_time_scheme_restore_point.dart';
import '../../services/import_week_alignment_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/import_result_message.dart';
import 'import_shared.dart';

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
    // 扩容（下面那次预扫，或解析之后那次容量确认）会**先扩表并落盘**：任何一条
    // 中止路径都要把作息退回去 —— 用户什么都没干，作息却被永久换成 AI 那套。
    // 与教务导入 / ICS / 表格三条路共用同一份实现（有 3 条单测）。
    ImportTimeSchemeRestorePoint? restorePoint;
    var coursesImported = false;
    setState(() {
      _isImporting = true;
    });
    try {
      // 先按 AI 结果里的最大节次把作息对齐，**再**解析。
      //
      // `parse` 遇到超出当前作息节数的课次会直接抛 `section_count_below_usage`
      // （越界是该拒的畸形输入），而「要不要自动补齐节次」那个弹窗在解析之后的
      // `ensureImportSectionCapacity` 才弹 —— 于是补救出口永远到不了，用户只会
      // 收到一句「节次数不足」，却没有任何办法把这批课导进来。
      // 预扫只看 `endSection`、读不到就跳过（返回 null），真正的校验仍由 parse 负责。
      final provider = context.read<TimetableProvider>();
      restorePoint = ImportTimeSchemeRestorePoint.capture(provider);
      final previewMaxSection = _aiImportService.maxSectionIn(_aiController.text);
      if (previewMaxSection != null &&
          previewMaxSection > provider.settings.sectionCount) {
        final preExpanded = await ensureImportSectionCapacity(
          context,
          requiredSectionCount: previewMaxSection,
          provider: provider,
        );
        if (!preExpanded || !mounted) {
          return;
        }
      }

      final result = _parseAiResult(showError: true);
      if (result == null || !mounted) {
        return;
      }

      final replaceExisting = provider.courses.isEmpty
          ? true
          : await askImportReplaceExisting(
              context,
              title: l10n.importAiResultTitle,
              content: l10n.importAiReplaceMessage,
            );
      if (replaceExisting == null || !mounted) {
        return;
      }

      final semesterConfig = await pickImportSemesterConfig(
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
      final capacityReady = await ensureImportSectionCapacity(
        context,
        requiredSectionCount: requiredSectionCount,
        provider: provider,
      );
      if (!capacityReady || !mounted) {
        return;
      }

      final coursesToImport = await coursesWithOptionalRandomColors(
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
        preserveLocalColors: await shouldPreserveLocalColorsOnImport(
          replaceExisting: replaceExisting,
        ),
      );
      // 课程已经落库：这套作息就是它们的依据，之后任何失败都不再回滚作息。
      coursesImported = true;
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
      final point = restorePoint;
      if (!coursesImported && point != null) {
        await point.restore();
      }
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
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
            importListDetail(
              context,
              l10n.aiPreviewCourseCount(result.courses.length),
            ),
            importListDetail(
              context,
              l10n.aiPreviewMaxSection(result.requiredSectionCount),
            ),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              importCardHeading(context, l10n.aiPreviewWarningsTitle),
              const SizedBox(height: 6),
              ...result.warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: importListDetail(context, '• $warning'),
                ),
              ),
            ],
            if (result.courses.isNotEmpty) ...[
              const SizedBox(height: 10),
              importCardHeading(context, l10n.aiPreviewCoursesTitle),
              const SizedBox(height: 6),
              ...result.courses
                  .take(6)
                  .map((course) => _buildCoursePreviewLine(context, course)),
              if (result.courses.length > 6)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: importListDetail(
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
    final weekText = importPreviewWeekSummary(
      weeks: weeks,
      weekListSeparator: l10n.weekListSeparator,
      weekNotProvidedLabel: l10n.courseImportWeekNotProvided,
      weeksCountLabel: l10n.availableWeeksCount,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: importListDetail(
        context,
        l10n.courseImportPreviewLine(
          importWeekdayLabel(l10n, course.dayOfWeek),
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

