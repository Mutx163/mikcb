import '../models/course.dart';
import '../models/exam.dart';
import '../models/timetable_settings.dart';

enum HomeWidgetSnapshotState {
  noCourse,
  upcoming,
  ongoing,
  completed,
  holiday,
}

extension HomeWidgetSnapshotStateX on HomeWidgetSnapshotState {
  String get value => switch (this) {
        HomeWidgetSnapshotState.noCourse => 'no_course',
        HomeWidgetSnapshotState.upcoming => 'upcoming',
        HomeWidgetSnapshotState.ongoing => 'ongoing',
        HomeWidgetSnapshotState.completed => 'completed',
        HomeWidgetSnapshotState.holiday => 'holiday',
      };
}

class HomeWidgetCourseSummary {
  final String id;
  final String name;
  final String? shortName;
  final String location;
  final String startTime;
  final String endTime;
  final int startSection;
  final int endSection;
  final String color;

  const HomeWidgetCourseSummary({
    required this.id,
    required this.name,
    required this.shortName,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.startSection,
    required this.endSection,
    required this.color,
  });

  factory HomeWidgetCourseSummary.fromCourse(Course course) {
    return HomeWidgetCourseSummary(
      id: course.id,
      name: course.name,
      shortName: course.shortName,
      location: course.location,
      startTime: course.startTime,
      endTime: course.endTime,
      startSection: course.startSection,
      endSection: course.endSection,
      color: course.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'location': location,
      'startTime': startTime,
      'endTime': endTime,
      'startSection': startSection,
      'endSection': endSection,
      'color': color,
    };
  }
}

class HomeWidgetSnapshot {
  final String profileId;
  final String profileName;
  final int currentWeek;
  final int dayOfWeek;
  final int generatedAtMillis;
  final HomeWidgetSnapshotState state;
  final WidgetBackgroundStyle backgroundStyle;
  final bool showLocation;
  final bool showCountdown;
  final String countdownTextStyle;
  final bool hideCompletedCourses;
  final double heightAdjustment;
  final double cornerRadius;
  final int totalTodayCourseCount;
  final List<HomeWidgetCourseSummary> todayCourses;
  final List<HomeWidgetCourseSummary> visibleTodayCourses;
  final HomeWidgetCourseSummary? highlightedCourse;
  final HomeWidgetCourseSummary? nextCourse;
  final String? nextExamName;
  final String? nextExamDate;
  final int? nextExamDaysUntil;
  final String? nextExamLocation;
  final String? nextExamStartTime;
  final String? nextExamEndTime;
  final String? holidayName;
  final List<HomeWidgetCourseSummary> tomorrowCourses;
  final int tomorrowWeek;
  final int tomorrowDayOfWeek;

  const HomeWidgetSnapshot({
    required this.profileId,
    required this.profileName,
    required this.currentWeek,
    required this.dayOfWeek,
    required this.generatedAtMillis,
    required this.state,
    required this.backgroundStyle,
    required this.showLocation,
    required this.showCountdown,
    required this.countdownTextStyle,
    required this.hideCompletedCourses,
    required this.heightAdjustment,
    required this.cornerRadius,
    required this.totalTodayCourseCount,
    required this.todayCourses,
    required this.visibleTodayCourses,
    this.highlightedCourse,
    this.nextCourse,
    this.nextExamName,
    this.nextExamDate,
    this.nextExamDaysUntil,
    this.nextExamLocation,
    this.nextExamStartTime,
    this.nextExamEndTime,
    this.holidayName,
    this.tomorrowCourses = const [],
    this.tomorrowWeek = 0,
    this.tomorrowDayOfWeek = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'profileId': profileId,
      'profileName': profileName,
      'currentWeek': currentWeek,
      'dayOfWeek': dayOfWeek,
      'generatedAtMillis': generatedAtMillis,
      'state': state.value,
      'backgroundStyle': backgroundStyle.value,
      'showLocation': showLocation,
      'showCountdown': showCountdown,
      'countdownTextStyle': countdownTextStyle,
      'hideCompletedCourses': hideCompletedCourses,
      'heightAdjustment': heightAdjustment,
      'cornerRadius': cornerRadius,
      'totalTodayCourseCount': totalTodayCourseCount,
      'todayCourses': todayCourses.map((course) => course.toJson()).toList(),
      'visibleTodayCourses':
          visibleTodayCourses.map((course) => course.toJson()).toList(),
      'highlightedCourse': highlightedCourse?.toJson(),
      'nextCourse': nextCourse?.toJson(),
      'nextExamName': nextExamName,
      'nextExamDate': nextExamDate,
      'nextExamDaysUntil': nextExamDaysUntil,
      'nextExamLocation': nextExamLocation,
      'nextExamStartTime': nextExamStartTime,
      'nextExamEndTime': nextExamEndTime,
      'holidayName': holidayName,
      'tomorrowCourses': tomorrowCourses.map((c) => c.toJson()).toList(),
      'tomorrowWeek': tomorrowWeek,
      'tomorrowDayOfWeek': tomorrowDayOfWeek,
    };
  }
}

class HomeWidgetSnapshotService {
  const HomeWidgetSnapshotService();

  HomeWidgetSnapshot build({
    required String profileId,
    required String profileName,
    required int currentWeek,
    required TimetableSettings settings,
    required List<Course> todayCourses,
    required DateTime now,
    int countdownLeadMinutes = 20,
    String countdownTextStyle = 'smart',
    Exam? nextExam,
    bool isHoliday = false,
    String? holidayName,
    List<Course> tomorrowCourses = const [],
    int tomorrowWeek = 0,
    int tomorrowDayOfWeek = 0,
    bool showTomorrowCourses = true,
    int originalTodayCourseCount = 0,
  }) {
    // Holiday: return a dedicated snapshot without course info
    if (isHoliday) {
      return HomeWidgetSnapshot(
        profileId: profileId,
        profileName: profileName,
        currentWeek: currentWeek,
        dayOfWeek: now.weekday,
        generatedAtMillis: now.millisecondsSinceEpoch,
        state: HomeWidgetSnapshotState.holiday,
        backgroundStyle: settings.widgetBackgroundStyle,
        showLocation: settings.widgetShowLocation,
        showCountdown: false,
        countdownTextStyle: countdownTextStyle,
        hideCompletedCourses: settings.widgetHideCompletedCourses,
        heightAdjustment: settings.widgetHeightAdjustment,
        cornerRadius: settings.widgetCornerRadius,
        totalTodayCourseCount: 0,
        todayCourses: const [],
        visibleTodayCourses: const [],
        holidayName: holidayName ?? 'Holiday',
      );
    }

    final summaries = todayCourses
        .map(HomeWidgetCourseSummary.fromCourse)
        .toList(growable: false);
    final visibleCourses = settings.widgetHideCompletedCourses
        ? todayCourses.where((course) {
            final end = _buildCourseDateTime(now, course.endTime);
            return end != null && end.isAfter(now);
          }).toList(growable: false)
        : todayCourses;
    final visibleSummaries = visibleCourses
        .map(HomeWidgetCourseSummary.fromCourse)
        .toList(growable: false);

    final currentCourse = _findCurrentCourse(todayCourses, now);
    final upcomingCourse = _findNextCourse(todayCourses, now);

    final hasCoursesScheduled = !todayCourses.isEmpty || originalTodayCourseCount > 0;
    final state =
        switch ((!hasCoursesScheduled, currentCourse, upcomingCourse)) {
      (true, _, _) => HomeWidgetSnapshotState.noCourse,
      (false, Course _, _) => HomeWidgetSnapshotState.ongoing,
      (false, null, Course _) => HomeWidgetSnapshotState.upcoming,
      (false, null, null) => HomeWidgetSnapshotState.completed,
    };

    // Compute effective showCountdown based on countdownLeadMinutes.
    final bool effectiveShowCountdown;
    if (!settings.widgetShowCountdown) {
      effectiveShowCountdown = false;
    } else if (countdownLeadMinutes == 0) {
      effectiveShowCountdown = true;
    } else {
      effectiveShowCountdown = state == HomeWidgetSnapshotState.ongoing ||
          (state == HomeWidgetSnapshotState.upcoming &&
              upcomingCourse != null &&
              _isWithinLeadMinutes(now, upcomingCourse, countdownLeadMinutes));
    }

    return HomeWidgetSnapshot(
      profileId: profileId,
      profileName: profileName,
      currentWeek: currentWeek,
      dayOfWeek: now.weekday,
      generatedAtMillis: now.millisecondsSinceEpoch,
      state: state,
      backgroundStyle: settings.widgetBackgroundStyle,
      showLocation: settings.widgetShowLocation,
      showCountdown: effectiveShowCountdown,
      countdownTextStyle: countdownTextStyle,
      hideCompletedCourses: settings.widgetHideCompletedCourses,
      heightAdjustment: settings.widgetHeightAdjustment,
      cornerRadius: settings.widgetCornerRadius,
      totalTodayCourseCount: todayCourses.length,
      todayCourses: summaries,
      visibleTodayCourses: visibleSummaries,
      highlightedCourse: currentCourse == null
          ? (upcomingCourse == null
              ? null
              : HomeWidgetCourseSummary.fromCourse(upcomingCourse))
          : HomeWidgetCourseSummary.fromCourse(currentCourse),
      nextCourse: upcomingCourse == null
          ? null
          : HomeWidgetCourseSummary.fromCourse(upcomingCourse),
      nextExamName: nextExam?.name,
      nextExamDate: nextExam != null
          ? '${nextExam.dateTime.year}-${nextExam.dateTime.month.toString().padLeft(2, '0')}-${nextExam.dateTime.day.toString().padLeft(2, '0')}'
          : null,
      nextExamDaysUntil: nextExam?.daysUntil,
      nextExamLocation: nextExam?.location,
      nextExamStartTime: nextExam?.startTime,
      nextExamEndTime: nextExam?.endTime,
      tomorrowCourses: showTomorrowCourses
          ? tomorrowCourses
              .map(HomeWidgetCourseSummary.fromCourse)
              .toList(growable: false)
          : const [],
      tomorrowWeek: tomorrowWeek,
      tomorrowDayOfWeek: tomorrowDayOfWeek,
    );
  }

  List<int> buildRefreshTriggers({
    required List<Course> todayCourses,
    required DateTime now,
    bool showCountdown = false,
    String state = 'no_course',
    int countdownLeadMinutes = 20,
  }) {
    final triggers = <int>{};
    for (final course in todayCourses) {
      final start = _buildCourseDateTime(now, course.startTime);
      final end = _buildCourseDateTime(now, course.endTime);
      if (start != null && start.isAfter(now)) {
        triggers.add(start.millisecondsSinceEpoch);
        // Add trigger at countdown activation point (start - lead minutes).
        if (countdownLeadMinutes > 0) {
          final activation =
              start.subtract(Duration(minutes: countdownLeadMinutes));
          if (activation.isAfter(now)) {
            triggers.add(activation.millisecondsSinceEpoch);
          }
        }
      }
      if (end != null && end.isAfter(now)) {
        triggers.add(end.millisecondsSinceEpoch);
      }
    }
    if (showCountdown && (state == 'ongoing' || state == 'upcoming')) {
      triggers.add(now.millisecondsSinceEpoch + 60000);
    }
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    if (nextMidnight.isAfter(now)) {
      triggers.add(nextMidnight.millisecondsSinceEpoch);
    }
    final sorted = triggers.toList()..sort();
    return sorted;
  }

  Course? _findCurrentCourse(List<Course> courses, DateTime now) {
    for (final course in courses) {
      final start = _buildCourseDateTime(now, course.startTime);
      final end = _buildCourseDateTime(now, course.endTime);
      if (start == null || end == null) {
        continue;
      }
      if (!now.isBefore(start) && now.isBefore(end)) {
        return course;
      }
    }
    return null;
  }

  Course? _findNextCourse(List<Course> courses, DateTime now) {
    for (final course in courses) {
      final start = _buildCourseDateTime(now, course.startTime);
      if (start == null) {
        continue;
      }
      if (start.isAfter(now)) {
        return course;
      }
    }
    return null;
  }

  bool _isWithinLeadMinutes(
      DateTime now, Course course, int leadMinutes) {
    final start = _buildCourseDateTime(now, course.startTime);
    if (start == null) return false;
    final threshold = start.subtract(Duration(minutes: leadMinutes));
    return !now.isBefore(threshold);
  }

  DateTime? _buildCourseDateTime(DateTime now, String clock) {
    final parts = clock.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}
