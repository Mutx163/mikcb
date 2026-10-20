import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/empty_slot_marker_controller.dart';
import '../../models/timetable_settings.dart';
import '../../utils/home_page_background.dart';
import 'timetable_empty_slot.dart';

/// 周网格里「长按空白格添加课程」的虚线标记格与网格级手势层
/// （2026-10-20 从 `TimetableScreen` State 搬出）。
///
/// 标记位置/缩放基准在 [EmptySlotMarkerController]；本文件只做命中换算、
/// 墨色与手势派发。

/// 单个节次的虚线加号标记；[span] 为 0 时返回无尺寸盒子。
class TimetableEmptySlotCell extends StatelessWidget {
  final EmptySlotMarkerController controller;
  final int week;
  final int dayOfWeek;
  final int startSection;
  final double sectionHeight;
  final double cardInset;
  final TimetableSettings settings;
  final int span;
  final Set<(int, int)> occupiedSections;
  final double? wallpaperLuminance;
  final VoidCallback onOpenAddCourse;

  const TimetableEmptySlotCell({
    super.key,
    required this.controller,
    required this.week,
    required this.dayOfWeek,
    required this.startSection,
    required this.sectionHeight,
    required this.cardInset,
    required this.settings,
    required this.span,
    required this.occupiedSections,
    required this.wallpaperLuminance,
    required this.onOpenAddCourse,
  });

  @override
  Widget build(BuildContext context) {
    if (!settings.longPressEmptySlotToAddCourseEnabled || span <= 0) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 虚线框墨色与时间轴数字同一套规则（用户自定义色 + 壁纸明暗自动黑白
    // 反转），避免硬编码白/黑在壁纸或深浅色反差下看不见。
    final markerInk = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.timeAxisFontColorDark
          : settings.timeAxisFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultTimeAxisFontColorDark
          : TimetableSettings.defaultTimeAxisFontColorLight,
      themeFallback: isDark ? Colors.white : Colors.grey.shade800,
      hasBackdrop: hasHomePageBackdrop(settings),
      wallpaperLuminance: wallpaperLuminance,
    );
    return TimetableEmptySlotAddMarker(
      sectionHeight: sectionHeight,
      span: span,
      inset: cardInset + 2,
      ink: markerInk,
      onTap: onOpenAddCourse,
      onResizeStart: controller.startResize,
      onResizeUpdate: (deltaDy) => controller.resize(
        deltaDy: deltaDy,
        sectionHeight: sectionHeight,
        dayOfWeek: dayOfWeek,
        sectionCount: settings.sectionCount,
        occupiedSections: occupiedSections,
        enableHaptics: settings.enableHaptics,
        onHaptic: HapticFeedback.selectionClick,
      ),
      onResizeEnd: controller.endResize,
    );
  }
}

/// 包住整块日列 Row 的手势层：长按出现虚线标记，拖动跟手换格，点空白清标记。
class TimetableEmptySlotGestureArea extends StatelessWidget {
  final EmptySlotMarkerController controller;
  final TimetableSettings settings;
  final int week;
  final double sectionHeight;
  final double dayWidth;
  final List<int> visibleDays;
  final Set<(int, int)> occupiedSections;
  final bool overlayVisible;
  final Widget child;

  const TimetableEmptySlotGestureArea({
    super.key,
    required this.controller,
    required this.settings,
    required this.week,
    required this.sectionHeight,
    required this.dayWidth,
    required this.visibleDays,
    required this.occupiedSections,
    required this.overlayVisible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!settings.longPressEmptySlotToAddCourseEnabled || overlayVisible) {
      return child;
    }

    /// 指针局部坐标（相对本手势层 = 日列网格）→ 所在空白格（星期几,
    /// 节次）；越界或格子有课返回 null。
    (int, int)? cellAt(Offset localPosition) {
      if (localPosition.dx < 0 || localPosition.dy < 0) {
        return null;
      }
      final dayIndex = (localPosition.dx / dayWidth).floor().clamp(
        0,
        visibleDays.length - 1,
      );
      final sectionIndex = (localPosition.dy / sectionHeight).floor().clamp(
        0,
        settings.sectionCount - 1,
      );
      final dayOfWeek = visibleDays[dayIndex];
      final section = sectionIndex + 1;
      if (occupiedSections.contains((dayOfWeek, section))) {
        return null;
      }
      return (dayOfWeek, section);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        final cell = cellAt(details.localPosition);
        if (cell == null) {
          return;
        }
        if (settings.enableHaptics) HapticFeedback.mediumImpact();
        controller.show(week, cell.$1, cell.$2);
      },
      onLongPressMoveUpdate: (details) {
        final cell = cellAt(details.localPosition);
        if (cell == null) {
          return;
        }
        if (cell.$1 == controller.week && cell.$2 == controller.section) {
          return;
        }
        if (settings.enableHaptics) HapticFeedback.selectionClick();
        controller.show(week, cell.$1, cell.$2);
      },
      onTap: controller.clear,
      child: child,
    );
  }
}
