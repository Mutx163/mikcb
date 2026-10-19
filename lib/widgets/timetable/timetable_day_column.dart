import 'package:flutter/material.dart';

import '../../domain/day_course_display_logic.dart';
import '../../models/class_reminder.dart';
import '../../models/course.dart';
import '../../models/timetable_settings.dart';
import '../../providers/timetable_provider.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/course_color_palette.dart';
import '../../utils/home_page_background.dart';
import '../../widgets/course_card.dart';
import '../../widgets/course_weather_display.dart';

/// 周网格的日列（2026-10-19 从课表页 State 搬出）。
///
/// 只做布局与卡片参数拼装；空白标记、课程操作、颜色/天气/圆角等状态相关逻辑
/// 全部经 [TimetableDayColumnCallbacks] 注入，组件本身不引用 State。
class TimetableDayColumn extends StatelessWidget {
  final int week;
  final int dayOfWeek;
  final List<DayCourseDisplayItem> displayItems;
  final TimetableSettings settings;
  final bool showConflictBadge;
  final double sectionHeight;
  final double cardInset;
  final TimetableProvider provider;
  final int dayIndex;
  final int dayCount;
  final Set<(int, int)> occupiedSections;
  final TimetableDayColumnCallbacks callbacks;

  const TimetableDayColumn({
    super.key,
    required this.week,
    required this.dayOfWeek,
    required this.displayItems,
    required this.settings,
    required this.showConflictBadge,
    required this.sectionHeight,
    required this.cardInset,
    required this.provider,
    required this.dayIndex,
    required this.dayCount,
    required this.occupiedSections,
    required this.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    final courseCards = <Widget>[];
    final gridLines = <Widget>[];

    final date = callbacks.dateForWeekDay(settings, week, dayOfWeek);
    final isDayHoliday = date != null && provider.isHoliday(date);

    // 虚线框：整列**只挂一个固定槽位**的 Positioned（top/height 随标记状态
    // 变），不与某个节次格绑定。原因：向上拉长会改标记起始节次，若把框挂在
    // "起始格"那个 Positioned 里，每次改起始格就等于把整棵标记子树挪到另一个
    // 父节点——旧 Element 被卸载，它手里那个正在拖拽的手势识别器随 dispose
    // 注销掉路由，纵拖当场断箭（现象：向上只能拉一格，向下改的是末节次、框不
    // 挪窝所以能一直拉）。固定槽位后无论首尾怎么变，标记始终是同一个 Element。
    // 放在 courseCards 之前＝框永远在课程卡下面。
    final markerSpan = callbacks.markerSpanAt(week, dayOfWeek);
    final markerStart = callbacks.markerSection();
    gridLines.add(
      Positioned(
        key: const ValueKey('empty-slot-add-marker-slot'),
        top: markerSpan > 0 && markerStart != null
            ? (markerStart - 1) * sectionHeight
            : 0,
        left: 0,
        right: 0,
        height: markerSpan > 0 ? sectionHeight * markerSpan : 0,
        child: callbacks.buildEmptySlotCell(
          week,
          dayOfWeek,
          markerStart ?? 1,
          sectionHeight,
          cardInset,
          settings,
          span: markerSpan,
          occupiedSections: occupiedSections,
        ),
      ),
    );

    for (
      var sectionIndex = 0;
      sectionIndex < settings.sectionCount;
      sectionIndex++
    ) {
      final section = sectionIndex + 1;
      final startingCourses = callbacks.startingAt(displayItems, section);

      for (final item in startingCourses) {
        courseCards.add(
          Positioned(
            top: sectionIndex * sectionHeight,
            left: 0,
            right: 0,
            height: item.course.sectionCount * sectionHeight,
            // Do not wrap CourseCard in Opacity: BackdropFilter / FakeGlass
            // cannot sample behind an opacity layer (blur becomes pure clear).
            child: CourseCard(
              course: item.course,
              overrideColorHex: callbacks.resolveColor(
                item,
                settings: settings,
              ),
              compactOverlineText: callbacks.overline(item, showConflictBadge),
              topRightBadgeText: callbacks.badge(item, showConflictBadge),
              // 日课表：这节课（课程×真实日期）已设单节课提醒时，在备注角标旁
              // 亮铃铛；情侣对方的只读课不显示。
              hasReminder:
                  date != null &&
                  !item.isPartnerCourse &&
                  provider.classReminderFor(
                        item.course.id,
                        ClassReminderEntry.formatDate(date),
                      ) !=
                      null,
              showHomeworkIndicator:
                  !item.isPartnerCourse && item.course.hasHomeworkInWeek(week),
              isHighlighted: item.isCurrentCourse,
              isHoliday: isDayHoliday,
              isSuspended: item.course.isSuspendedInWeek(week),
              isCompact: true,
              showName: settings.courseCardShowName,
              showTeacher: settings.courseCardShowTeacher,
              showLocation: settings.courseCardShowLocation,
              showTime: settings.courseCardShowTime,
              showTimeLabels: settings.courseCardShowTimeLabels,
              showWeeks: settings.courseCardShowWeeks,
              showDescription: settings.courseCardShowDescription,
              weather: callbacks.weather(item, date),
              verticalAlign: settings.courseCardVerticalAlign,
              horizontalAlign: settings.courseCardHorizontalAlign,
              onTap: () {
                callbacks.clearMarker();
                callbacks.showActions(item.course, week, displayItem: item);
              },
              compactTitleFontSize: settings.courseCardFontSize,
              compactSubtitleFontSize: (settings.courseCardFontSize - 1).clamp(
                7.0,
                14.0,
              ),
              compactVerticalPadding: sectionHeight < 64 ? 4 : 6,
              compactOuterInset: cardInset,
              // 无壁纸或模糊管线不可用（全局实体/系统降级）时统一实体卡
              // （高斯没有可采样背景）；有壁纸且管线可用才按设置。
              surfaceStyle: effectiveCourseCardSurfaceStyle(
                settings,
                gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
                  context,
                ),
              ),
              // wallpaperLuminance 供玻璃档自动黑白判定；实体卡忽略。
              wallpaperLuminance:
                  callbacks.wallpaperBodyLuminance() ??
                  callbacks.wallpaperTopLuminance(),
              // Dim conflict / non-current via fill alphas, keep frost working.
              surfaceOpacity: item.opacity,
              titleColorHex: resolveCourseCardTitleColorHex(
                courseTextColorHex: item.course.textColor,
                settingsTitleColorLight: settings.courseCardTitleColorLight,
                settingsTitleColorDark: settings.courseCardTitleColorDark,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
              detailColorHex: resolveCourseCardDetailColorHex(
                courseTextColorHex: item.course.textColor,
                settingsDetailColorLight: settings.courseCardDetailColorLight,
                settingsDetailColorDark: settings.courseCardDetailColorDark,
                settingsTitleColorLight: settings.courseCardTitleColorLight,
                settingsTitleColorDark: settings.courseCardTitleColorDark,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
        );
      }
    }

    return Container(
      height: settings.sectionCount * sectionHeight,
      decoration: BoxDecoration(
        borderRadius: callbacks.border(dayIndex, dayCount),
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [...gridLines, ...courseCards],
      ),
    );
  }
}

class TimetableDayColumnCallbacks {
  final DateTime? Function(TimetableSettings settings, int week, int dayOfWeek)
  dateForWeekDay;
  final int Function(int week, int dayOfWeek) markerSpanAt;
  final int? Function() markerSection;
  final Widget Function(
    int week,
    int dayOfWeek,
    int section,
    double sectionHeight,
    double cardInset,
    TimetableSettings settings, {
    required int span,
    required Set<(int, int)> occupiedSections,
  })
  buildEmptySlotCell;
  final List<DayCourseDisplayItem> Function(
    List<DayCourseDisplayItem> items,
    int section,
  )
  startingAt;
  final String? Function(
    DayCourseDisplayItem item, {
    required TimetableSettings settings,
  })
  resolveColor;
  final String? Function(DayCourseDisplayItem item, bool showConflictBadge)
  overline;
  final String? Function(DayCourseDisplayItem item, bool showConflictBadge)
  badge;
  final CourseWeatherDisplay? Function(
    DayCourseDisplayItem item,
    DateTime? date,
  )
  weather;
  final VoidCallback clearMarker;
  final void Function(
    Course course,
    int week, {
    DayCourseDisplayItem? displayItem,
  })
  showActions;
  final BorderRadius Function(int dayIndex, int dayCount) border;
  final double? Function() wallpaperBodyLuminance;
  final double? Function() wallpaperTopLuminance;

  const TimetableDayColumnCallbacks({
    required this.dateForWeekDay,
    required this.markerSpanAt,
    required this.markerSection,
    required this.buildEmptySlotCell,
    required this.startingAt,
    required this.resolveColor,
    required this.overline,
    required this.badge,
    required this.weather,
    required this.clearMarker,
    required this.showActions,
    required this.border,
    required this.wallpaperBodyLuminance,
    required this.wallpaperTopLuminance,
  });
}


/// 分组日列的圆角：首日左侧、末日右侧，中间直角。
BorderRadius groupedDayColumnBorderRadius(
  int dayIndex,
  int dayCount, {
  double radius = 12,
}) {
  if (dayCount <= 1) {
    return BorderRadius.circular(radius);
  }
  return BorderRadius.only(
    topLeft: dayIndex == 0 ? Radius.circular(radius) : Radius.zero,
    bottomLeft: dayIndex == 0 ? Radius.circular(radius) : Radius.zero,
    topRight: dayIndex == dayCount - 1
        ? Radius.circular(radius)
        : Radius.zero,
    bottomRight: dayIndex == dayCount - 1
        ? Radius.circular(radius)
        : Radius.zero,
  );
}
