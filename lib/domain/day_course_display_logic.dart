import '../models/course.dart';
import '../models/timetable_settings.dart';
import 'couple_timetable_logic.dart';

/// 日视图课卡展示条目。
///
/// 主屏（[TimetableScreen]）与外观编辑的周预览共用这一份：
/// 预览是主屏的子集（不填 [coupleKind] / [isCurrentCourse]），颜色、
/// 透明度、顶栏文案的口径必须只在这里定一次，避免两边走散。
class DayCourseDisplayItem {
  const DayCourseDisplayItem({
    required this.course,
    this.isCurrentWeekCourse = false,
    this.isConflicting = false,
    this.opacity = 1,
    this.isCurrentCourse = false,
    this.coupleKind,
    this.isPartnerCourse = false,
  });

  final Course course;
  final bool isCurrentWeekCourse;
  final bool isConflicting;
  final bool isCurrentCourse;
  final double opacity;
  final CoupleCourseKind? coupleKind;
  final bool isPartnerCourse;
}

/// 非本周课的统一透明度（灰卡压淡）。
const double kNonCurrentWeekCourseOpacity = 0.62;

/// 非本周课的统一灰（与时间轴墨色同族的板岩灰）。
const String kNonCurrentWeekCourseColorHex = '#94A3B8';

/// 课卡展示用的文案包（domain 不引 l10n，由界面侧注入）。
class DayCourseDisplayLabels {
  const DayCourseDisplayLabels({
    required this.nonCurrentWeek,
    required this.conflict,
    required this.coupleTogether,
    required this.couplePartner,
    required this.ongoingCourse,
  });

  final String nonCurrentWeek;
  final String conflict;
  final String coupleTogether;
  final String couplePartner;
  final String ongoingCourse;
}

/// 课卡展示透明度：非本周固定压淡；本周冲突课跟用户设定；其余不透明。
double courseDisplayOpacity({
  required bool isCurrentWeekCourse,
  required bool isConflicting,
  required double conflictOpacity,
}) {
  if (!isCurrentWeekCourse) {
    return kNonCurrentWeekCourseOpacity;
  }
  return isConflicting ? conflictOpacity : 1;
}

/// 把某天的课程列表收成展示条目：滤掉被本周课压住的非本周课，再排序。
///
/// 排序口径（与历史行为一致）：开始节次 → 本周课排在后 → 结束节次 → id。
/// 当前进行中的课（[currentCourseIds]）只是打标，不参与排序。
List<DayCourseDisplayItem> buildDayCourseDisplayItems({
  required List<Course> courses,
  required int week,
  required TimetableSettings settings,
  required Map<String, List<Course>> conflictMap,
  Set<String> currentCourseIds = const <String>{},
}) {
  return courses
      .where((course) {
        final isCurrentWeekCourse = course.isInWeek(week);
        if (isCurrentWeekCourse) {
          return true;
        }
        if (hasCurrentWeekOverlap(courses, course, week)) {
          return false;
        }
        return isPreferredNonCurrentCourse(courses, course, week);
      })
      .map((course) {
        final isCurrentWeekCourse = course.isInWeek(week);
        final isConflicting = conflictMap.containsKey(course.id);
        return DayCourseDisplayItem(
          course: course,
          isCurrentWeekCourse: isCurrentWeekCourse,
          isConflicting: isConflicting,
          isCurrentCourse: currentCourseIds.contains(course.id),
          opacity: courseDisplayOpacity(
            isCurrentWeekCourse: isCurrentWeekCourse,
            isConflicting: isConflicting,
            conflictOpacity: settings.timetableConflictCourseOpacity,
          ),
        );
      })
      .toList()
    ..sort(compareDayCourseDisplayItems);
}

/// 展示条目的稳定排序（开始节次 → 本周课靠后 → 结束节次 → id）。
int compareDayCourseDisplayItems(DayCourseDisplayItem left, DayCourseDisplayItem right) {
  final startCompare = left.course.startSection.compareTo(right.course.startSection);
  if (startCompare != 0) {
    return startCompare;
  }
  final leftCurrent = left.isCurrentWeekCourse;
  final rightCurrent = right.isCurrentWeekCourse;
  if (leftCurrent != rightCurrent) {
    return leftCurrent ? 1 : -1;
  }
  final endCompare = left.course.endSection.compareTo(right.course.endSection);
  if (endCompare != 0) {
    return endCompare;
  }
  return left.course.id.compareTo(right.course.id);
}

/// 覆盖色：合堂课走合堂色板；非本周统一灰；本周课跟「统一卡片色」开关。
///
/// [coupleColorForKind] 由主屏注入（读 Provider）；预览没有合堂，不传即可。
String? resolveDisplayCourseColor(
  DayCourseDisplayItem item, {
  required TimetableSettings settings,
  String? Function(CoupleCourseKind kind)? coupleColorForKind,
}) {
  final kind = item.coupleKind;
  if (kind != null) {
    if (coupleColorForKind != null) {
      return coupleColorForKind(kind);
    }
  }
  if (!item.isCurrentWeekCourse) {
    return kNonCurrentWeekCourseColorHex;
  }
  return settings.timetableUseUnifiedCardColor
      ? settings.timetableUnifiedCardColor
      : null;
}

/// 紧凑课卡左上角那行短文案（合堂 > 非本周 > 冲突）。
String? resolveCompactOverlineText(
  DayCourseDisplayItem item, {
  required DayCourseDisplayLabels labels,
  required bool showConflictBadge,
}) {
  if (item.coupleKind == CoupleCourseKind.together) {
    return labels.coupleTogether;
  }
  if (item.coupleKind == CoupleCourseKind.partner) {
    return labels.couplePartner;
  }
  if (!item.isCurrentWeekCourse) {
    return labels.nonCurrentWeek;
  }
  if (item.isConflicting && showConflictBadge) {
    return labels.conflict;
  }
  return null;
}

/// 紧凑课卡右上角角标：合堂 + 正在上课 + 冲突，按需拼成「 · 」串。
///
/// 预览不填合堂/进行中时自动退化成「只标冲突」，与历史行为一致。
String? resolveCompactBadgeText(
  DayCourseDisplayItem item, {
  required DayCourseDisplayLabels labels,
  required bool showConflictBadge,
}) {
  final parts = <String>[];
  if (item.coupleKind == CoupleCourseKind.together) {
    parts.add(labels.coupleTogether);
  }
  if (item.isCurrentCourse) {
    parts.add(labels.ongoingCourse);
  }
  if (item.isConflicting && showConflictBadge) {
    parts.add(labels.conflict);
  }
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' · ');
}

/// 某天的课程列表（含「非本周」开关与已结课过滤）。
///
/// 已结课（在当前周及以后没有任何上课周）的课程不再以「非本周」显示。
List<Course> getCoursesForDay(
  List<Course> allCourses,
  int week,
  int dayOfWeek,
  TimetableSettings settings,
) {
  return allCourses.where((course) {
    if (course.dayOfWeek != dayOfWeek) {
      return false;
    }
    final isCurrent = course.isInWeek(week);
    if (isCurrent) {
      return true;
    }
    return settings.timetableShowNonCurrentWeekCourses &&
        course.hasActiveWeekOnOrAfter(week);
  }).toList()
    ..sort((a, b) {
      final startCompare = a.startSection.compareTo(b.startSection);
      if (startCompare != 0) return startCompare;
      final aCurrent = a.isInWeek(week);
      final bCurrent = b.isInWeek(week);
      if (aCurrent != bCurrent) {
        return aCurrent ? 1 : -1;
      }
      final endCompare = a.endSection.compareTo(b.endSection);
      if (endCompare != 0) return endCompare;
      return a.id.compareTo(b.id);
    });
}

/// 是否有本周课与 [target] 节次重叠（有则压掉非本周的 [target]）。
bool hasCurrentWeekOverlap(List<Course> courses, Course target, int week) {
  return courses.any(
    (course) =>
        course.id != target.id &&
        course.isInWeek(week) &&
        !(course.endSection < target.startSection ||
            target.endSection < course.startSection),
  );
}

/// 重叠的非本周课里只留「离上课周最近」的那张（同距再比起止周与 id）。
bool isPreferredNonCurrentCourse(
  List<Course> courses,
  Course target,
  int week,
) {
  final overlappingNonCurrentCourses =
      courses
          .where(
            (course) =>
                !course.isInWeek(week) &&
                !(course.endSection < target.startSection ||
                    target.endSection < course.startSection),
          )
          .toList()
        ..sort((left, right) {
          final leftDistance = distanceToNearestActiveWeek(left, week);
          final rightDistance = distanceToNearestActiveWeek(right, week);
          if (leftDistance != rightDistance) {
            return leftDistance.compareTo(rightDistance);
          }
          final startCompare = left.startWeek.compareTo(right.startWeek);
          if (startCompare != 0) {
            return startCompare;
          }
          final endCompare = left.endWeek.compareTo(right.endWeek);
          if (endCompare != 0) {
            return endCompare;
          }
          return left.id.compareTo(right.id);
        });

  return overlappingNonCurrentCourses.isNotEmpty &&
      overlappingNonCurrentCourses.first.id == target.id;
}

/// 从 [week] 出发到最近上课周的周距；60 周内找不到记 999。
int distanceToNearestActiveWeek(Course course, int week) {
  for (var offset = 0; offset <= 60; offset++) {
    final previousWeek = week - offset;
    if (previousWeek >= 1 && course.isInWeek(previousWeek)) {
      return offset;
    }
    final nextWeek = week + offset;
    if (offset > 0 && course.isInWeek(nextWeek)) {
      return offset;
    }
  }
  return 999;
}
