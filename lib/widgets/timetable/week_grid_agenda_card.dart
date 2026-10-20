import 'package:flutter/material.dart';

import '../../domain/week_grid_agenda_placement.dart';
import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../ui/hyperos/hyperos_motion.dart';
import '../../utils/hex_color.dart';
import '../course_surface.dart';
import '../open_container.dart';
import 'day_view/day_view_ink_style.dart';
import 'timetable_form_pages.dart';

/// 周网格里的「考试/日程」卡（WakeUp 式落格）。
///
/// 提案见 `.agents/notes/proposed/feature/2026-10-20-week-view-exam-agenda-display.md`：
/// 考试/日程按「钟点 → 重叠节次」映射落进对应时段（[WeekGridAgendaPlacement]），
/// 与课程卡共处一张网格。卡面材质与课程卡共用 [CourseSurface]（单一正源，
/// 玻璃/实体不漂移）；墨色与日视图议程卡同源（[dayAgendaAutoInk]：实体档恒
/// 白墨，玻璃档按「卡色 × tint 占比 + 壁纸亮度」自动黑白）。
///
/// 点击去处与日视图议程卡**同一条路**：考试 → `AddExamScreen`，日程 → 日程
/// 编辑页（单次覆盖带 occurrenceDate），都用 [OpenContainer] 的容器转场——
/// 两个视图点同一张卡去同一个地方，交互才不会「看着像两个功能」。
class TimetableWeekGridAgendaCard extends StatelessWidget {
  final WeekGridAgendaEntry entry;
  final TimetableSettings settings;
  final double sectionHeight;
  final double outerInset;
  final CourseCardSurfaceStyle surfaceStyle;
  final double? wallpaperBodyLuminance;
  final double? wallpaperTopLuminance;

  const TimetableWeekGridAgendaCard({
    super.key,
    required this.entry,
    required this.settings,
    required this.sectionHeight,
    required this.outerInset,
    required this.surfaceStyle,
    this.wallpaperBodyLuminance,
    this.wallpaperTopLuminance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isExam = entry.isExam;
    // 考试用主题错误红（与考试红点、日视图考试卡同一来源）；日程用
    // item.color 解析出的日程色，解析不了回落主题强调色（与日视图同口径）。
    final Color fill = isExam
        ? theme.colorScheme.error
        : parseHexColorOrFallback(
            entry.scheduleInstance?.color,
            fallback: theme.colorScheme.primary,
          );
    final ink = dayAgendaAutoInk(
      fill,
      settings: settings,
      env: DayViewInkEnvironment(
        backdropBlurOn: HyperosBlurredHeader.backdropBlurEnabled(context),
        wallpaperBodyLuminance: wallpaperBodyLuminance,
        wallpaperTopLuminance: wallpaperTopLuminance,
      ),
    );
    // 跨天日程的时刻已换成 00:00–23:59（整列占位），画出来是噪音：只留
    // 徽标与标题，整列的占位本身就在说「这一天都有」。
    final isCrossDay =
        entry.continuesFromPreviousDay || entry.continuesToNextDay;
    final titleFontSize = (settings.courseCardFontSize + 1).clamp(8.0, 14.0);
    final detailFontSize = settings.courseCardFontSize.clamp(7.0, 13.0);

    return OpenContainer<void>(
      key: ValueKey('week-grid-agenda-card-${entry.id}'),
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: 360.scaledMs,
      openColor: theme.scaffoldBackgroundColor,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      // 放大到整屏后必须是**直角**（2026-10-20 用户实测四角黑边）：`openShape`
      // 用默认直角、`openBuilder` 不再套同半径 ClipRRect，否则 28dp 圆角外侧
      // 谁都不画，而这条路由 opaque（下面的周网格不再绘制），透出窗口黑底。
      // 形变中段的圆角仍由转场那层 Material(Clip.antiAlias) 按形状补间完成。
      openBuilder: (context, _) {
        final exam = entry.exam;
        final instance = entry.scheduleInstance;
        if (isExam && exam != null) {
          return timetableFormPages.examForm(exam: exam);
        }
        if (instance != null) {
          return timetableFormPages.scheduleItemForm(
            scheduleItem: instance.item,
            occurrenceDate: instance.occurrenceDate,
          );
        }
        return const SizedBox.shrink();
      },
      closedBuilder: (context, openContainer) {
        return Padding(
          padding: EdgeInsets.all(outerInset),
          child: CourseSurface(
            style: surfaceStyle,
            color: fill,
            borderRadius: 8,
            solidGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [fill.withValues(alpha: 0.9), fill.withValues(alpha: 0.7)],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: openContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: sectionHeight < 64 ? 3 : 5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRect(
                          // 与紧凑课程卡同款（course_card.dart 的
                          // _buildCompactCard）：LayoutBuilder 量出格宽给
                          // SizedBox，文本在定宽下走 maxLines/ellipsis；
                          // 整块放不下时 FittedBox 整体缩小，绝不溢出。
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _AgendaBadgePill(
                                        label: isExam
                                            ? l10n.examBadgeLabel
                                            : l10n.scheduleBadgeLabel,
                                        icon: isExam
                                            ? Icons.school_outlined
                                            : Icons.event_outlined,
                                        ink: ink,
                                        fontSize: detailFontSize,
                                      ),
                                      SizedBox(height: detailFontSize * 0.3),
                                      Text(
                                        entry.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: titleFontSize,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                          height: 1.15,
                                        ),
                                      ),
                                      if (!isCrossDay &&
                                          entry.startTime.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 1,
                                          ),
                                          child: Text(
                                            '${entry.startTime} - ${entry.endTime}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: detailFontSize,
                                              color: ink.withValues(
                                                alpha: 0.88,
                                              ),
                                              height: 1.15,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 徽标小药丸（图标 + 「考试」/「日程」），样式与日视图议程卡的徽标同款：
/// 墨色洗底（[dayAgendaInkWash]）+ 圆角胶囊。窄格里字号随课程卡设置走。
class _AgendaBadgePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color ink;
  final double fontSize;

  const _AgendaBadgePill({
    required this.label,
    required this.icon,
    required this.ink,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.6, vertical: 2),
      decoration: BoxDecoration(
        color: dayAgendaInkWash(ink, lightAlpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2, color: ink),
          SizedBox(width: fontSize * 0.35),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}
