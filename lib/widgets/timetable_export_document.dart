import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../domain/week_calculator.dart';
import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';
import 'statistics/statistics_export_brand_footer.dart';
import 'timetable_week_preview.dart';

/// 课表分享图。**只进离屏捕获宿主**，不参与屏幕上的正常布局。
///
/// 与统计导出文档同一套约定：顶层 `Column(mainAxisSize: min)`，不滚动、
/// 不 `Expanded`/`Spacer` —— 离屏捕获靠固有高度量出完整尺寸，塞进滚动组件
/// 就只能量到一屏。
///
/// 两种形态：
/// * [dayOfWeek] 为 null：整周网格，复用屏内的 `TimetableWeekPreview`。
/// * [dayOfWeek] 非空：那一天的课程按时间顺序排成列表。
///
/// 日视图**不是**把屏幕上那个日视图页面原样搬过来。屏内日视图是
/// `_TimetableScreenState` 的私有实现（摘要卡、进度条、玻璃、情侣面板等
/// 一堆交互件），且主体是可滚动列表，既不可复用也量不出完整高度。分享图
/// 要的是「干净」——把那些交互件剥掉、把当天的课按时间排清楚，比像素级复刻
/// 屏内页面更合用。
class TimetableExportDocument extends StatelessWidget {
  const TimetableExportDocument({
    super.key,
    required this.provider,
    required this.settings,
    required this.week,
    this.dayOfWeek,
  });

  final TimetableProvider provider;
  final TimetableSettings settings;
  final int week;

  /// null = 周视图；1..7 = 日视图（周一到周日）。
  final int? dayOfWeek;

  /// 周几栏高度，与 `TimetableWeekPreview._headerHeight` 一致。
  /// 给周预览算 `heightBudget` 时必须减掉它，否则会溢出 40dp。
  static const double _weekdayHeaderHeight = 40;

  /// 导出图的节高上下限。
  ///
  /// 不直接用用户的 `sectionHeight`：那个值是「让整周塞进一屏」调出来的
  /// 屏内参数，直接搬进一张可随意缩放的图片，要么密到看不清、要么空得发虚。
  static const double _minSectionHeight = 56;
  static const double _maxSectionHeight = 110;

  static const double _surfaceRadius = 16;
  static const double _surfacePadding = 10;

  static const Color _surfaceColor = Colors.white;

  /// 导出专用设置：纯白底 + 清掉壁纸。
  ///
  /// 这两项都不是「顺眼一点」的微调，各自保一件事：
  /// * **清壁纸**让 `hasHomePageBackdrop` 为 false，课程卡自动落到实底。
  ///   离屏宿主是 opacity 层，采不到背后的内容，实时玻璃在这里只会塌成
  ///   一层裸 tint（参见 `CourseSurface` 与 `course_grid_surface_host.dart`
  ///   里「不要用 Opacity 包玻璃」的说明）。
  /// * 顺带**掐掉异步亮度采样**那条通路（`_TimetableWeekPreviewState`
  ///   只在有壁纸时采样）。否则采样可能在「量高」与「光栅化」之间落地并
  ///   `setState`，同一份数据导出的图就不确定了。
  ///
  /// 底色统一成纯白是为了和网格外面那张白卡无缝：默认的
  /// `timetablePageBackgroundColor` 是近白 `#F8FAFC`，两种近白拼在一起会
  /// 显出一道色差边。
  TimetableSettings get _exportSettings => settings.copyWith(
    timetablePageBackgroundColor: '#FFFFFF',
    clearHomePageBackgroundImagePath: true,
    clearHomePageWallpaperPath: true,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final targetDay = dayOfWeek;
    final subtitle = targetDay == null ? null : _dateLabel(context, targetDay);

    return ColoredBox(
      color: HyperosColors.scaffoldBackground(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 品牌条与统计导出共用（它本来就只依赖 app 名与官网地址）。
            StatisticsExportBrandBar.header(),
            const SizedBox(height: 10),
            Text(
              _title(l10n),
              style: HyperosTypography.sheetTitle(context),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: HyperosTypography.listDetail(
                  context,
                ).copyWith(color: HyperosColors.secondaryText(context)),
              ),
            ],
            const SizedBox(height: 12),
            if (targetDay == null)
              _buildWeekSurface()
            else
              _buildDaySurface(context, targetDay),
            const SizedBox(height: 12),
            StatisticsExportBrandBar.footer(),
          ],
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    final targetDay = dayOfWeek;
    if (targetDay == null) {
      return l10n.timetableShareExportWeekTitle(week);
    }
    return l10n.timetableShareExportDayTitle(week, _weekdayLabel(l10n, targetDay));
  }

  /// 周视图：白卡里塞整周网格。
  ///
  /// `heightBudget` 必须显式给死：不传的话 `TimetableWeekPreview` 会拿
  /// `MediaQuery` 里的屏幕高度反推节高（`_resolveHomeSectionHeight`），
  /// 离屏宿主给的是一屏高的 MediaQuery，导出的就是一屏版式而不是完整长图。
  Widget _buildWeekSurface() {
    final exportSettings = _exportSettings;
    final sectionCount = exportSettings.sectionCount;
    final sectionHeight = settings.sectionHeight.clamp(
      _minSectionHeight,
      _maxSectionHeight,
    );
    return _surfaceShell(
      child: TimetableWeekPreview(
        provider: provider,
        settings: exportSettings,
        week: week,
        maxVisibleSections: sectionCount,
        // App 顶栏与壁纸都不画：分享图要的是课表本身，不是「一张截图」。
        // includeAppHeader 的默认值就是 false，故不显式传。
        applyHomePageBackdrop: false,
        showFloatingBackToCurrentWeek: false,
        heightBudget: _weekdayHeaderHeight + sectionHeight * sectionCount,
      ),
    );
  }

  /// 日视图：当天课程按开始时间排成列表（`getCoursesForDay` 已按节次排好）。
  Widget _buildDaySurface(BuildContext context, int targetDay) {
    final courses = provider.getCoursesForDay(targetDay, week: week);
    if (courses.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return _surfaceShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              l10n.timetableShareExportEmptyDay,
              style: HyperosTypography.listDetail(
                context,
              ).copyWith(color: HyperosColors.secondaryText(context)),
            ),
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var index = 0; index < courses.length; index++) {
      if (index > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            color: HyperosColors.dividerLine(context).withValues(alpha: 0.7),
          ),
        );
      }
      rows.add(_buildCourseRow(context, courses[index]));
    }

    return _surfaceShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ),
    );
  }

  Widget _buildCourseRow(BuildContext context, Course course) {
    final accent = parseHexColorOrFallback(
      course.color,
      fallback: HyperosColors.primary(context),
    );
    final sectionLabel = course.startSection == course.endSection
        ? '${course.startSection}'
        : '${course.startSection}-${course.endSection}';
    final details = [
      if (course.teacher.trim().isNotEmpty) course.teacher.trim(),
      if (course.location.trim().isNotEmpty) course.location.trim(),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '${course.startTime}-${course.endTime}',
                      style: HyperosTypography.listDetail(context).copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sectionLabel,
                      style: HyperosTypography.listDetail(context).copyWith(
                        color: HyperosColors.secondaryText(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  course.name,
                  style: HyperosTypography.listTitle(context).copyWith(
                    color: HyperosColors.primaryText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: HyperosTypography.listDetail(context).copyWith(
                      color: HyperosColors.secondaryText(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceShell({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(_surfaceRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_surfaceRadius),
        child: Padding(
          padding: const EdgeInsets.all(_surfacePadding),
          child: child,
        ),
      ),
    );
  }

  /// 「第 N 周 · 周三」用的周几标签。
  String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
    final labels = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
    final index = dayOfWeek - 1;
    if (index < 0 || index >= labels.length) {
      return '';
    }
    return labels[index];
  }

  /// 「10月8日」这类日期；学期开始日期没配时返回 null（标题只显示周次）。
  String? _dateLabel(BuildContext context, int dayOfWeek) {
    final semesterStart = settings.semesterStartDate;
    if (semesterStart == null) {
      return null;
    }
    final date = WeekCalculator.startOfWeek(
      semesterStart,
    ).add(Duration(days: (week - 1) * 7 + dayOfWeek - 1));
    final localeName = Localizations.localeOf(context).toString();
    return DateFormat.MMMd(localeName).format(date);
  }
}
