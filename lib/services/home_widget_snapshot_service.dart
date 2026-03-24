import '../models/course.dart';
import '../models/timetable_settings.dart';

enum HomeWidgetSnapshotState {
  noCourse,
  upcoming,
  ongoing,
  completed,
}

extension HomeWidgetSnapshotStateX on HomeWidgetSnapshotState {
  String get value => switch (this) {
        HomeWidgetSnapshotState.noCourse => 'no_course',
        HomeWidgetSnapshotState.upcoming => 'upcoming',
        HomeWidgetSnapshotState.ongoing => 'ongoing',
        HomeWidgetSnapshotState.completed => 'completed',
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
  final List<HomeWidgetCourseSummary> todayCourses;
  final HomeWidgetCourseSummary? highlightedCourse;
  final HomeWidgetCourseSummary? nextCourse;

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
    required this.todayCourses,
    this.highlightedCourse,
    this.nextCourse,
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
      'todayCourses': todayCourses.map((course) => course.toJson()).toList(),
      'highlightedCourse': highlightedCourse?.toJson(),
      'nextCourse': nextCourse?.toJson(),
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
  }) {
    final summaries = todayCourses
        .map(HomeWidgetCourseSummary.fromCourse)
        .toList(growable: false);

    final currentCourse = _findCurrentCourse(todayCourses, now);
    final upcomingCourse = _findNextCourse(todayCourses, now);

    final state =
        switch ((todayCourses.isEmpty, currentCourse, upcomingCourse)) {
      (true, _, _) => HomeWidgetSnapshotState.noCourse,
      (false, Course _, _) => HomeWidgetSnapshotState.ongoing,
      (false, null, Course _) => HomeWidgetSnapshotState.upcoming,
      (false, null, null) => HomeWidgetSnapshotState.completed,
    };

    return HomeWidgetSnapshot(
      profileId: profileId,
      profileName: profileName,
      currentWeek: currentWeek,
      dayOfWeek: now.weekday,
      generatedAtMillis: now.millisecondsSinceEpoch,
      state: state,
      backgroundStyle: settings.widgetBackgroundStyle,
      showLocation: settings.widgetShowLocation,
      showCountdown: settings.widgetShowCountdown,
      todayCourses: summaries,
      highlightedCourse: currentCourse == null
          ? (upcomingCourse == null
              ? null
              : HomeWidgetCourseSummary.fromCourse(upcomingCourse))
          : HomeWidgetCourseSummary.fromCourse(currentCourse),
      nextCourse: upcomingCourse == null
          ? null
          : HomeWidgetCourseSummary.fromCourse(upcomingCourse),
    );
  }

  List<int> buildRefreshTriggers({
    required List<Course> todayCourses,
    required DateTime now,
  }) {
    final triggers = <int>{};
    for (final course in todayCourses) {
      final start = _buildCourseDateTime(now, course.startTime);
      final end = _buildCourseDateTime(now, course.endTime);
      if (start != null && start.isAfter(now)) {
        triggers.add(start.millisecondsSinceEpoch);
      }
      if (end != null && end.isAfter(now)) {
        triggers.add(end.millisecondsSinceEpoch + 1000);
      }
    }
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    if (nextMidnight.isAfter(now)) {
      triggers.add(nextMidnight.millisecondsSinceEpoch + 1000);
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
      if (!now.isBefore(start) && !now.isAfter(end)) {
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
