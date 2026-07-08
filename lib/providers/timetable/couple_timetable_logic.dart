import '../../models/course.dart';
import '../../models/timetable_settings.dart';

/// Semantic category for a course in couple overlay view.
enum CoupleCourseKind {
  mine,
  partner,
  together,
}

/// A minute-based time interval [startMinutes, endMinutes] within a day.
class MinuteInterval {
  final int startMinutes;
  final int endMinutes;

  const MinuteInterval({
    required this.startMinutes,
    required this.endMinutes,
  });

  int get durationMinutes => endMinutes - startMinutes;
}

class CoupleTimetableLogic {
  static const String mineColorHexDefault = '#2196F3';
  static const String partnerColorHexDefault = '#E91E63';
  static const String togetherColorHexDefault = '#9C27B0';
  static const String freeSlotColorHex = '#4CAF50';
  static const int minWeekOffset = -15;
  static const int maxWeekOffset = 15;

  static int clampWeekOffset(int offset) {
    if (offset < minWeekOffset) {
      return minWeekOffset;
    }
    if (offset > maxWeekOffset) {
      return maxWeekOffset;
    }
    return offset;
  }

  static int partnerWeekForMyWeek(int myWeek, int weekOffset) {
    return myWeek + clampWeekOffset(weekOffset);
  }

  static bool coursesOverlapForCoupleView(
    Course mine,
    Course partner, {
    required int myWeek,
    int partnerWeekOffset = 0,
  }) {
    if (mine.dayOfWeek != partner.dayOfWeek) {
      return false;
    }
    if (mine.endSection < partner.startSection ||
        partner.endSection < mine.startSection) {
      return false;
    }
    final partnerWeek = partnerWeekForMyWeek(myWeek, partnerWeekOffset);
    return mine.isInWeek(myWeek) && partner.isInWeek(partnerWeek);
  }

  static bool coursesOverlapInWeek(Course left, Course right, {int? week}) {
    if (left.dayOfWeek != right.dayOfWeek) {
      return false;
    }
    if (left.endSection < right.startSection ||
        right.endSection < left.startSection) {
      return false;
    }

    final overlapStartWeek = left.startWeek > right.startWeek
        ? left.startWeek
        : right.startWeek;
    final overlapEndWeek = left.endWeek < right.endWeek
        ? left.endWeek
        : right.endWeek;
    if (overlapStartWeek > overlapEndWeek) {
      return false;
    }

    if (week != null) {
      if (week < overlapStartWeek || week > overlapEndWeek) {
        return false;
      }
      return left.isInWeek(week) && right.isInWeek(week);
    }

    for (var w = overlapStartWeek; w <= overlapEndWeek; w++) {
      if (left.isInWeek(w) && right.isInWeek(w)) {
        return true;
      }
    }
    return false;
  }

  static bool isTogetherClass(
    Course mine,
    Course partner, {
    required int week,
    int partnerWeekOffset = 0,
  }) {
    if (!coursesOverlapForCoupleView(
      mine,
      partner,
      myWeek: week,
      partnerWeekOffset: partnerWeekOffset,
    )) {
      return false;
    }
    return mine.name.trim().toLowerCase() ==
        partner.name.trim().toLowerCase();
  }

  static CoupleCourseKind classifyMineCourse(
    Course course,
    List<Course> partnerCourses, {
    required int week,
    int partnerWeekOffset = 0,
  }) {
    for (final partner in partnerCourses) {
      if (isTogetherClass(
        course,
        partner,
        week: week,
        partnerWeekOffset: partnerWeekOffset,
      )) {
        return CoupleCourseKind.together;
      }
    }
    return CoupleCourseKind.mine;
  }

  static CoupleCourseKind classifyPartnerCourse(
    Course course,
    List<Course> myCourses, {
    required int week,
    int partnerWeekOffset = 0,
  }) {
    for (final mine in myCourses) {
      if (isTogetherClass(
        mine,
        course,
        week: week,
        partnerWeekOffset: partnerWeekOffset,
      )) {
        return CoupleCourseKind.together;
      }
    }
    return CoupleCourseKind.partner;
  }

  static String colorHexForKind(
    CoupleCourseKind kind, {
    String? mineColorHex,
    String? partnerColorHex,
    String? togetherColorHex,
  }) {
    return switch (kind) {
      CoupleCourseKind.mine => mineColorHex ?? mineColorHexDefault,
      CoupleCourseKind.partner => partnerColorHex ?? partnerColorHexDefault,
      CoupleCourseKind.together => togetherColorHex ?? togetherColorHexDefault,
    };
  }

  static const String mineColorHex = mineColorHexDefault;
  static const String partnerColorHex = partnerColorHexDefault;
  static const String togetherColorHex = togetherColorHexDefault;

  static List<Course> coursesForDay(
    List<Course> courses,
    int dayOfWeek,
    int week,
  ) {
    return courses
        .where(
          (course) =>
              course.dayOfWeek == dayOfWeek && course.isInWeek(week),
        )
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  static List<MinuteInterval> busyIntervalsForDay(
    List<Course> courses,
    int dayOfWeek,
    int week,
    List<SectionTime> sections,
  ) {
    final dayCourses = coursesForDay(courses, dayOfWeek, week);
    final intervals = <MinuteInterval>[];
    for (final course in dayCourses) {
      final start = _sectionStartMinutes(sections, course.startSection);
      final end = _sectionEndMinutes(sections, course.endSection);
      if (start == null || end == null || end <= start) {
        continue;
      }
      intervals.add(MinuteInterval(startMinutes: start, endMinutes: end));
    }
    return mergeMinuteIntervals(intervals);
  }

  static List<MinuteInterval> freeIntervalsForDay(
    List<Course> courses,
    int dayOfWeek,
    int week,
    List<SectionTime> sections,
  ) {
    if (sections.isEmpty) {
      return const [];
    }
    final dayStart = _clockToMinutes(sections.first.startTime);
    final dayEnd = _clockToMinutes(sections.last.endTime);
    if (dayEnd <= dayStart) {
      return const [];
    }
    final busy = busyIntervalsForDay(courses, dayOfWeek, week, sections);
    return invertMinuteIntervals(
      busy,
      rangeStart: dayStart,
      rangeEnd: dayEnd,
    );
  }

  static List<MinuteInterval> sharedFreeIntervalsForDay({
    required List<Course> myCourses,
    required List<Course> partnerCourses,
    required int dayOfWeek,
    required int week,
    required List<SectionTime> sections,
  }) {
    final myFree = freeIntervalsForDay(myCourses, dayOfWeek, week, sections);
    final partnerFree = freeIntervalsForDay(
      partnerCourses,
      dayOfWeek,
      week,
      sections,
    );
    return intersectSortedMinuteIntervals(myFree, partnerFree);
  }

  static List<MinuteInterval> mergeMinuteIntervals(
    List<MinuteInterval> intervals,
  ) {
    if (intervals.isEmpty) {
      return const [];
    }
    final sorted = List<MinuteInterval>.from(intervals)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final merged = <MinuteInterval>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      final last = merged.last;
      if (current.startMinutes <= last.endMinutes) {
        merged[merged.length - 1] = MinuteInterval(
          startMinutes: last.startMinutes,
          endMinutes: current.endMinutes > last.endMinutes
              ? current.endMinutes
              : last.endMinutes,
        );
      } else {
        merged.add(current);
      }
    }
    return merged;
  }

  static List<MinuteInterval> invertMinuteIntervals(
    List<MinuteInterval> busy, {
    required int rangeStart,
    required int rangeEnd,
  }) {
    if (rangeEnd <= rangeStart) {
      return const [];
    }
    if (busy.isEmpty) {
      return [MinuteInterval(startMinutes: rangeStart, endMinutes: rangeEnd)];
    }

    final free = <MinuteInterval>[];
    var cursor = rangeStart;
    for (final interval in busy) {
      if (interval.startMinutes > cursor) {
        free.add(
          MinuteInterval(
            startMinutes: cursor,
            endMinutes: interval.startMinutes,
          ),
        );
      }
      if (interval.endMinutes > cursor) {
        cursor = interval.endMinutes;
      }
    }
    if (cursor < rangeEnd) {
      free.add(MinuteInterval(startMinutes: cursor, endMinutes: rangeEnd));
    }
    return free;
  }

  static List<MinuteInterval> intersectSortedMinuteIntervals(
    List<MinuteInterval> left,
    List<MinuteInterval> right,
  ) {
    final result = <MinuteInterval>[];
    var i = 0;
    var j = 0;
    while (i < left.length && j < right.length) {
      final start = left[i].startMinutes > right[j].startMinutes
          ? left[i].startMinutes
          : right[j].startMinutes;
      final end = left[i].endMinutes < right[j].endMinutes
          ? left[i].endMinutes
          : right[j].endMinutes;
      if (start < end) {
        result.add(MinuteInterval(startMinutes: start, endMinutes: end));
      }
      if (left[i].endMinutes < right[j].endMinutes) {
        i++;
      } else {
        j++;
      }
    }
    return result;
  }

  static bool isSectionInFreeSlot(
    int section,
    List<MinuteInterval> freeIntervals,
    List<SectionTime> sections,
  ) {
    final start = _sectionStartMinutes(sections, section);
    final end = _sectionEndMinutes(sections, section);
    if (start == null || end == null) {
      return false;
    }
    for (final interval in freeIntervals) {
      if (start >= interval.startMinutes && end <= interval.endMinutes) {
        return true;
      }
    }
    return false;
  }

  static String formatMinuteInterval(MinuteInterval interval) {
    return '${_minutesToClock(interval.startMinutes)}-${_minutesToClock(interval.endMinutes)}';
  }

  static int? _sectionStartMinutes(List<SectionTime> sections, int section) {
    final index = section - 1;
    if (index < 0 || index >= sections.length) {
      return null;
    }
    return _clockToMinutes(sections[index].startTime);
  }

  static int? _sectionEndMinutes(List<SectionTime> sections, int section) {
    final index = section - 1;
    if (index < 0 || index >= sections.length) {
      return null;
    }
    return _clockToMinutes(sections[index].endTime);
  }

  static int _clockToMinutes(String clock) {
    final parts = clock.split(':');
    if (parts.length != 2) {
      return 0;
    }
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  static String _minutesToClock(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
