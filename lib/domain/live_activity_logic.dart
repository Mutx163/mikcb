import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../utils/clock_time.dart';

/// Stable label key for the "most recent class ended" break milestone.
///
/// Android resolves these identifiers against `R.string.milestone_*` (see
/// `localizeLiveMilestoneLabel`). They have to stay keys rather than display
/// text: the offline scheduler builds the same milestones straight from
/// resources, so a hard-coded Chinese label here would make the island switch
/// language depending on who started it.
const String milestoneRecentEndLabelKey = 'milestone_recent_end';

/// Stable label key for the "next class starts" break milestone.
const String milestoneNextStartLabelKey = 'milestone_next_start';

class LiveActivityCourseSelection {
  final Course currentCourse;
  final Course? nextCourse;
  final LiveActivityStage stage;

  const LiveActivityCourseSelection({
    required this.currentCourse,
    required this.nextCourse,
    required this.stage,
  });
}

enum LiveActivityStage {
  beforeClass,
  duringClassStatusBar,
  duringClass,
  beforeEnd,
}

/// Pure live-activity helpers extracted from [TimetableProvider].
class LiveActivityLogic {
  LiveActivityLogic._();

  /// `"HH:MM"` → 相对当天 00:00 的分钟数。
  ///
  /// 收口到 [ClockTime.tryParse]：原来这里只做 `parts.length != 2` + tryParse，
  /// **不查范围**，于是 `25:00` 会被 [buildCourseDateTime] 里的 `DateTime(y,m,d,25,0)`
  /// 静默归一成**次日 01:00** —— 超级岛/自动响点的日期挪了一天，界面无异常。
  /// 同仓 `ClassReminderService.parseClockMinutes`（:25-27）与
  /// `SystemAlarmLogic.parseClockMinutes`（:90）都有范围守卫，只有这条链漏了。
  static int? parseClockMinutes(String value) =>
      ClockTime.tryParse(value, allowEndOfDay: true)?.totalMinutes;

  static DateTime? buildCourseDateTime(DateTime date, String courseTime) {
    final parsed = ClockTime.tryParse(courseTime, allowEndOfDay: true);
    if (parsed == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute);
  }

  static String resolveRealTime(
    Course course,
    bool isStart,
    List<SectionTime>? sections,
  ) {
    final sectionIndex =
        (isStart ? course.startSection : course.endSection) - 1;
    if (sections != null &&
        sectionIndex >= 0 &&
        sectionIndex < sections.length) {
      return isStart
          ? sections[sectionIndex].startTime
          : sections[sectionIndex].endTime;
    }
    return isStart ? course.startTime : course.endTime;
  }

  static List<Map<String, dynamic>> buildLiveProgressMilestones(
    Course course,
    List<SectionTime>? sections, {
    int? startAtMillis,
    int? endAtMillis,
  }) {
    if (course.sectionCount < 2 || sections == null) {
      return const [];
    }

    final firstSectionIndex = course.startSection - 1;
    final lastSectionIndex = course.endSection - 1;
    if (firstSectionIndex < 0 || lastSectionIndex >= sections.length) {
      return const [];
    }

    final resolvedStartAtMillis = startAtMillis;
    final resolvedEndAtMillis = endAtMillis;
    if (resolvedStartAtMillis == null ||
        resolvedEndAtMillis == null ||
        resolvedEndAtMillis <= resolvedStartAtMillis) {
      return const [];
    }

    final sectionStartMinutes = parseClockMinutes(
      sections[firstSectionIndex].startTime,
    );
    final sectionEndMinutes = parseClockMinutes(
      sections[lastSectionIndex].endTime,
    );
    if (sectionStartMinutes == null ||
        sectionEndMinutes == null ||
        sectionEndMinutes <= sectionStartMinutes) {
      return const [];
    }

    final referenceTotalMinutes = sectionEndMinutes - sectionStartMinutes;
    final totalDurationMillis = resolvedEndAtMillis - resolvedStartAtMillis;
    final milestones = <Map<String, dynamic>>[];

    for (
      var sectionIndex = firstSectionIndex;
      sectionIndex < lastSectionIndex;
      sectionIndex++
    ) {
      final currentSection = sections[sectionIndex];
      final nextSection = sections[sectionIndex + 1];
      final currentEndMinutes = parseClockMinutes(currentSection.endTime);
      final nextStartMinutes = parseClockMinutes(nextSection.startTime);
      if (currentEndMinutes == null ||
          nextStartMinutes == null ||
          nextStartMinutes <= currentEndMinutes) {
        continue;
      }

      final breakStartOffsetMillis =
          (((currentEndMinutes - sectionStartMinutes) / referenceTotalMinutes) *
                  totalDurationMillis)
              .round()
              .clamp(1, totalDurationMillis - 1);
      final breakEndOffsetMillis =
          (((nextStartMinutes - sectionStartMinutes) / referenceTotalMinutes) *
                  totalDurationMillis)
              .round()
              .clamp(1, totalDurationMillis - 1);

      milestones.add({
        'offsetMillis': breakStartOffsetMillis,
        'label': milestoneRecentEndLabelKey,
        'timeText': currentSection.endTime,
      });
      milestones.add({
        'offsetMillis': breakEndOffsetMillis,
        'label': milestoneNextStartLabelKey,
        'timeText': nextSection.startTime,
      });
    }

    milestones.sort(
      (left, right) =>
          (left['offsetMillis'] as int).compareTo(right['offsetMillis'] as int),
    );
    return milestones;
  }

  static List<int> buildLiveProgressBreakOffsetsMillis(
    Course course,
    List<SectionTime>? sections, {
    int? startAtMillis,
    int? endAtMillis,
  }) {
    return buildLiveProgressMilestones(
      course,
      sections,
      startAtMillis: startAtMillis,
      endAtMillis: endAtMillis,
    ).map((milestone) => milestone['offsetMillis'] as int).toList();
  }

  static String buildStageTransitionKey(LiveActivityCourseSelection selection) {
    final liveCourse = selection.currentCourse;
    return '${liveCourse.id}:${selection.stage.name}:${liveCourse.name}:'
        '${liveCourse.startSection}:${liveCourse.endSection}:'
        '${liveCourse.location}:${liveCourse.teacher}';
  }

  static bool canDisplayStage(
    LiveActivityStage stage,
    TimetableSettings settings,
  ) {
    switch (stage) {
      case LiveActivityStage.beforeClass:
        return settings.liveEnableBeforeClass;
      case LiveActivityStage.duringClassStatusBar:
        return settings.liveEnableDuringClass &&
            settings.liveShowDuringClassNotification;
      case LiveActivityStage.duringClass:
        return settings.liveEnableDuringClass &&
            (settings.livePromoteDuringClass ||
                settings.liveShowDuringClassNotification);
      case LiveActivityStage.beforeEnd:
        return settings.liveEnableBeforeEnd;
    }
  }

  static LiveActivityStage? preferredTestStage(TimetableSettings settings) {
    if (canDisplayStage(LiveActivityStage.beforeClass, settings)) {
      return LiveActivityStage.beforeClass;
    }
    if (canDisplayStage(LiveActivityStage.duringClass, settings)) {
      return LiveActivityStage.duringClass;
    }
    if (canDisplayStage(LiveActivityStage.beforeEnd, settings)) {
      return LiveActivityStage.beforeEnd;
    }
    return null;
  }

  static DateTime resolveEndReminderStart(
    DateTime startTime,
    DateTime endTime,
    Duration endReminderWindow,
  ) {
    final endReminderStart = endTime.subtract(endReminderWindow);
    return endReminderStart.isBefore(startTime) ? startTime : endReminderStart;
  }

  static LiveActivityStage? resolveLiveActivityStage({
    required DateTime currentTime,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime aheadTime,
    required TimetableSettings settings,
    required Duration endReminderWindow,
  }) {
    if (currentTime.isBefore(aheadTime) || !currentTime.isBefore(endTime)) {
      return null;
    }

    if (currentTime.isBefore(startTime)) {
      return canDisplayStage(LiveActivityStage.beforeClass, settings)
          ? LiveActivityStage.beforeClass
          : null;
    }

    final startMinutes = settings.liveClassReminderStartMinutes;
    final reminderStartTime = startMinutes == 0
        ? startTime
        : endTime.subtract(Duration(minutes: startMinutes));

    if (currentTime.isBefore(reminderStartTime)) {
      if (startMinutes > 0 &&
          canDisplayStage(LiveActivityStage.duringClassStatusBar, settings)) {
        return LiveActivityStage.duringClassStatusBar;
      }
      return null;
    }

    if (startMinutes > 0) {
      if (canDisplayStage(LiveActivityStage.beforeEnd, settings)) {
        return LiveActivityStage.beforeEnd;
      }
      return canDisplayStage(LiveActivityStage.duringClass, settings)
          ? LiveActivityStage.duringClass
          : null;
    }

    final endReminderStart = resolveEndReminderStart(
      startTime,
      endTime,
      endReminderWindow,
    );
    if (!currentTime.isBefore(endReminderStart)) {
      if (canDisplayStage(LiveActivityStage.beforeEnd, settings)) {
        return LiveActivityStage.beforeEnd;
      }
      if (canDisplayStage(LiveActivityStage.duringClass, settings)) {
        return LiveActivityStage.duringClass;
      }
      return null;
    }

    return canDisplayStage(LiveActivityStage.duringClass, settings)
        ? LiveActivityStage.duringClass
        : null;
  }
}
