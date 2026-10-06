// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 导入流程共享 UI 与通用策略
// ICS / 表格 / AI 图片 / 仓库四条导入链路的公共小组件与公共约定函数。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import '../../l10n/service_message_localizer.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/miuix_date_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import '../../models/course.dart';
import 'package:provider/provider.dart';
import '../../providers/timetable_provider.dart';
import '../../services/import_random_color_preferences.dart';
import '../../services/import_week_alignment_service.dart';
import '../../services/warehouse_repository_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/course_color_palette.dart';
import '../../utils/import_random_course_colors.dart';
import '../../widgets/app_dialogs.dart';

Future<List<Course>> coursesWithOptionalRandomColors(
  List<Course> courses,
) async {
  if (!await ImportRandomColorPreferences.isEnabled()) {
    return courses;
  }
  final assignMatchingTextColor =
      await ImportRandomColorPreferences.isTextColorEnabled();
  final groupId = await ImportRandomColorPreferences.getGroupId();
  return applyRandomImportCourseColors(
    courses,
    palette: courseColorGroupPalette(groupId),
    assignMatchingTextColor: assignMatchingTextColor,
  );
}

/// 颜色更新只在覆盖导入时生效：覆盖 + 随机色开启才让导入色盖掉本地色。
/// 更新/下拉快捷导入一律保留本地颜色——随机色此时只落到本地没有的新课上。
bool shouldOverrideLocalColorsOnImport({
  required bool replaceExisting,
  required bool randomColorsEnabled,
}) {
  return replaceExisting && randomColorsEnabled;
}

/// Whether the import should keep the color of courses that match existing
/// local rows. Overwrite + random colors re-colors the whole timetable; any
/// update path never touches existing colors.
Future<bool> shouldPreserveLocalColorsOnImport({
  required bool replaceExisting,
}) async {
  return !shouldOverrideLocalColorsOnImport(
    replaceExisting: replaceExisting,
    randomColorsEnabled: await ImportRandomColorPreferences.isEnabled(),
  );
}

Widget importListTitle(BuildContext context, String text) {
  return Text(text, style: HyperosTypography.listTitle(context));
}

Widget importCardHeading(BuildContext context, String text) {
  return Text(text, style: HyperosTypography.title(context));
}

Widget importListDetail(BuildContext context, String text) {
  return Text(text, style: HyperosTypography.listDetail(context));
}

Widget importLoadingCenter({double size = 32}) {
  return Center(child: HyperosCircularProgress(size: size));
}

class ImportInitialBadge extends StatelessWidget {
  final String label;

  const ImportInitialBadge({super.key, required this.label});

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

class ImportIconBadge extends StatelessWidget {
  final IconData icon;

  const ImportIconBadge({super.key, required this.icon});

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

class ImportSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ImportSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return HyperosCard(padding: padding, child: child);
  }
}

class ImportGuidePanel extends StatelessWidget {
  final String scenarioIntro;
  final String step1Subtitle;
  final String step2Subtitle;
  final String step3Subtitle;
  final String supportedFilesSuffix;
  final String? supportedFilesExtra;

  const ImportGuidePanel({
    super.key,
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
                ImportGuideLine(title: l10n.stepLabel('1'), subtitle: step1Subtitle),
                const SizedBox(height: 10),
                ImportGuideLine(title: l10n.stepLabel('2'), subtitle: step2Subtitle),
                const SizedBox(height: 10),
                ImportGuideLine(title: l10n.stepLabel('3'), subtitle: step3Subtitle),
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
                importListDetail(context, supportedFilesSuffix),
                if (supportedFilesExtra != null) ...[
                  const SizedBox(height: 4),
                  importListDetail(context, supportedFilesExtra!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ImportDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const ImportDetailLine({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          importListDetail(context, label),
          const SizedBox(height: 2),
          Text(value, style: HyperosTypography.listTitle(context)),
        ],
      ),
    );
  }
}

class ImportSemesterConfig {
  final DateTime semesterStartDate;
  final int firstCourseWeek;

  const ImportSemesterConfig({
    required this.semesterStartDate,
    required this.firstCourseWeek,
  });
}

class ImportGuideLine extends StatelessWidget {
  final String title;
  final String subtitle;

  const ImportGuideLine({super.key, required this.title, required this.subtitle});

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
              importListTitle(context, title),
              const SizedBox(height: 2),
              importListDetail(context, subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

Future<ImportSemesterConfig?> pickImportSemesterConfig(
  BuildContext context, {
  required DateTime initialSemesterStartDate,
  required int initialFirstCourseWeek,
  required String title,
  required String subtitle,
  DateTime? inferredFirstCourseDate,
}) {
  const alignmentService = ImportWeekAlignmentService();
  return showHyperosSheet<ImportSemesterConfig>(
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
                            '${importFormatDate(selectedSemesterStartDate)} · ${l10n.importSemesterStartDateSubtitle}',
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
                            ImportSemesterConfig(
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


Future<bool?> askImportReplaceExisting(
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


Future<bool> ensureImportSectionCapacity(
  BuildContext context, {
  required int requiredSectionCount,
  required TimetableProvider provider,
  bool autoConfirm = false,
  VoidCallback? onWriteStart,
  bool Function()? isCancelled,
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
  if (isCancelled?.call() ?? false) {
    return false;
  }

  onWriteStart?.call();
  final ensureMessage = await provider.ensureSectionCapacityForImport(
    requiredSectionCount,
  );
  if (ensureMessage != null) {
    if (context.mounted) {
      showAppLightTip(
        context,
        message: localizeServiceMessage(
          AppLocalizations.of(context)!,
          ensureMessage,
        ),
      );
    }
    return false;
  }
  return true;
}


String importWeekdayLabel(AppLocalizations l10n, int dayOfWeek) {
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

String importFormatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Future<String?> promptImportWarehouseUrl(
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
    showImportLightTip(context, l10n.courseImportPortalUrlInvalid);
    return null;
  }
  return result.trim();
}

void showImportLightTip(BuildContext context, String message) {
  showAppLightTip(context, message: message);
}

/// 仓库抓取选项的当前值：从课表设置里派生，仓库侧三条调用点共用同一份读法。
///
/// 2026-10-06 拆分时原本是三个文件里逐字重复的 `_currentFetchOptions()`
/// （仓库主流程 / 调试记录 / 首页下拉快捷导入），这里收成一处。
/// 收拢的另一个作用：这三个文件原本各自 import `TimetableProvider` 就只为这四行，
/// 合并后它们不再直接依赖那个巨型 Provider（见
/// `test/architecture/dependency_guards_test.dart` 的扇入棘轮）。
WarehouseFetchOptions currentWarehouseFetchOptions(BuildContext context) {
  return WarehouseFetchOptions.fromSettings(
    context.read<TimetableProvider>().settings,
  );
}