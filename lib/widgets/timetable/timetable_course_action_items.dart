import '../../domain/couple_timetable_logic.dart';
import '../../domain/day_course_display_logic.dart';
import '../../models/course.dart';
import '../../providers/timetable_provider.dart';
import '../course_action_sheet.dart';

/// 课程操作弹层要预览的条目：本人课 + 冲突课 + 情侣 / TA 关联课。
///
/// 2026-10-19 从 `timetable_screen.dart` 的 `_buildCourseActionPreviewItems` 及其
/// 三个查询 helper 搬出。纯函数：只读 provider，不碰 State、不弹 UI。
///
/// [coupleOverlayActive] 由调用方算好传进来 —— 它是「情侣覆盖层开关 && 已绑定
/// TA」再叠加预览模式门控的产物，属于宿主状态，不由本文件重复判断。
List<CourseActionPreviewItem> buildTimetableCourseActionPreviewItems(
  TimetableProvider provider,
  Course course,
  int week, {
  DayCourseDisplayItem? displayItem,
  required bool coupleOverlayActive,
}) {
  final isPartner = displayItem?.isPartnerCourse ?? false;
  final partnerWeekOffset = provider.partnerWeekOffset;
  var coupleKind = displayItem?.coupleKind;
  if (coupleKind == null &&
      !isPartner &&
      coupleOverlayActive &&
      _findTogetherPartnerCourse(
            provider,
            course,
            week,
            partnerWeekOffset: partnerWeekOffset,
          ) !=
          null) {
    coupleKind = CoupleCourseKind.together;
  }
  if (coupleKind == null &&
      isPartner &&
      coupleOverlayActive &&
      provider.courses.any(
        (mine) => CoupleTimetableLogic.isTogetherClass(
          mine,
          course,
          week: week,
          partnerWeekOffset: partnerWeekOffset,
        ),
      )) {
    coupleKind = CoupleCourseKind.together;
  }
  if (coupleKind == null && isPartner && coupleOverlayActive) {
    coupleKind = CoupleCourseKind.partner;
  }
  final items = <CourseActionPreviewItem>[
    CourseActionPreviewItem(
      course: course,
      isPartnerCourse: isPartner,
      coupleKind: coupleKind,
    ),
  ];

  if (!isPartner) {
    for (final conflict in _conflictsForCourseInWeek(provider, course, week)) {
      if (items.any((item) => item.course.id == conflict.id)) {
        continue;
      }
      items.add(CourseActionPreviewItem(course: conflict, isConflict: true));
    }
  }

  if (!coupleOverlayActive) {
    return items;
  }

  if (coupleKind == CoupleCourseKind.together) {
    final partner = _findTogetherPartnerCourse(
      provider,
      course,
      week,
      partnerWeekOffset: partnerWeekOffset,
    );
    if (partner != null && !items.any((item) => item.course.id == partner.id)) {
      items.add(
        CourseActionPreviewItem(
          course: partner,
          isPartnerCourse: true,
          coupleKind: CoupleCourseKind.together,
        ),
      );
    }
    return items;
  }

  if (isPartner) {
    for (final mine in provider.courses) {
      if (CoupleTimetableLogic.isTogetherClass(
            mine,
            course,
            week: week,
            partnerWeekOffset: partnerWeekOffset,
          ) &&
          !items.any((item) => item.course.id == mine.id)) {
        items.add(
          CourseActionPreviewItem(
            course: mine,
            coupleKind: CoupleCourseKind.together,
          ),
        );
        break;
      }
    }
    return items;
  }

  for (final partner in _overlappingPartnerCourses(
    provider,
    course,
    week,
    partnerWeekOffset: partnerWeekOffset,
  )) {
    if (items.any((item) => item.course.id == partner.id)) {
      continue;
    }
    items.add(
      CourseActionPreviewItem(
        course: partner,
        isPartnerCourse: true,
        coupleKind: CoupleCourseKind.partner,
      ),
    );
  }
  return items;
}

Course? _findTogetherPartnerCourse(
  TimetableProvider provider,
  Course mine,
  int week, {
  required int partnerWeekOffset,
}) {
  for (final partner in provider.partnerCourses) {
    if (CoupleTimetableLogic.isTogetherClass(
      mine,
      partner,
      week: week,
      partnerWeekOffset: partnerWeekOffset,
    )) {
      return partner;
    }
  }
  return null;
}

List<Course> _overlappingPartnerCourses(
  TimetableProvider provider,
  Course mine,
  int week, {
  required int partnerWeekOffset,
}) {
  return provider.partnerCourses
      .where(
        (partner) =>
            CoupleTimetableLogic.coursesOverlapForCoupleView(
              mine,
              partner,
              myWeek: week,
              partnerWeekOffset: partnerWeekOffset,
            ) &&
            !CoupleTimetableLogic.isTogetherClass(
              mine,
              partner,
              week: week,
              partnerWeekOffset: partnerWeekOffset,
            ),
      )
      .toList();
}

List<Course> _conflictsForCourseInWeek(
  TimetableProvider provider,
  Course course,
  int week,
) {
  final conflictMap = provider.courseConflictMapForWeek(week);
  final seenIds = <String>{};
  final conflicts = <Course>[];
  for (final conflict in conflictMap[course.id] ?? const <Course>[]) {
    if (conflict.id == course.id || !seenIds.add(conflict.id)) {
      continue;
    }
    conflicts.add(conflict);
  }
  conflicts.sort((left, right) {
    final dayCompare = left.dayOfWeek.compareTo(right.dayOfWeek);
    if (dayCompare != 0) {
      return dayCompare;
    }
    final startCompare = left.startSection.compareTo(right.startSection);
    if (startCompare != 0) {
      return startCompare;
    }
    return left.id.compareTo(right.id);
  });
  return conflicts;
}
