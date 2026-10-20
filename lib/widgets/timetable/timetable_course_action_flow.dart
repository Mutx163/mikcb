import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../domain/day_course_display_logic.dart';
import '../../models/course.dart';
import '../../providers/timetable_provider.dart';
import '../course_action_sheet.dart';
import 'timetable_course_action_items.dart';
import 'timetable_course_sheet_actions.dart';

/// 课程操作弹层的装配（2026-10-20 从 `timetable_screen.dart` 的
/// `_showCourseActions` 搬出）。
///
/// 只负责「取预览条目 → 打开弹层 → 把三条后续流程接上」；改动课程本体的四处
/// 动作（编辑 / 加作业 / 单节课提醒 / 后续 sheet）由调用方注入 —— 它们要推
/// 屏幕，属于宿主页的导航职责，本文件不 import `screens/`。
///
/// 行为口径与原 State 方法逐项一致：
/// * 预览条目用 [buildTimetableCourseActionPreviewItems]，情侣覆盖层状态由调用方
///   算好传进来（原 `_isCoupleOverlayActive(provider)`）；
/// * 调课 / 删除 / 停课复用既有的 `timetable_course_sheet_actions.dart`；
/// * 单节课提醒只在 Android 原生精确闹钟可用的平台出现，判据与原实现相同。
Future<void> showTimetableCourseActions(
  BuildContext context, {
  required TimetableProvider provider,
  required Course course,
  required int week,
  DayCourseDisplayItem? displayItem,
  required bool coupleOverlayActive,
  required List<String> Function(BuildContext context) weekdayLabels,
  required CourseActionHandler onEdit,
  required CourseActionHandler onAddTask,
  required CourseAlarmHandler onSetAlarm,
}) async {
  final previewItems = buildTimetableCourseActionPreviewItems(
    provider,
    course,
    week,
    displayItem: displayItem,
    coupleOverlayActive: coupleOverlayActive,
  );
  await showCourseActionSheet(
    context,
    previewItems: previewItems,
    week: week,
    onEdit: onEdit,
    onReschedule: (target) => showTimetableCourseRescheduleSheet(
      context,
      course: target,
      sourceWeek: week,
      weekdayLabels: weekdayLabels,
    ),
    onDelete: (target) => showTimetableCourseDeleteOptions(
      context,
      course: target,
      week: week,
      weekdayLabels: weekdayLabels,
    ),
    onSuspend: (target) =>
        showTimetableCourseSuspendSheet(context, course: target, week: week),
    onAddTask: onAddTask,
    // 单节课提醒依赖原生精确闹钟调度，其他平台不显示入口。
    onSetAlarm: (!kIsWeb && Platform.isAndroid) ? onSetAlarm : null,
  );
}
