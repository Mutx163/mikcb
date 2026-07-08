import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';

/// Debug-only helpers for installing and driving live-update test timetables.
///
/// All fixture courses use [courseIdPrefix] so they can be removed without
/// touching user-created courses.
class LiveTestingFixtureService {
  LiveTestingFixtureService._();

  static const String courseIdPrefix = 'live_test_';
  static const String timeSchemeName = '超级岛测试24时段';
  static const Duration defaultCourseDuration = Duration(minutes: 3);
  static const List<int> supportedLeadMinutes = [1, 3, 5, 8];

  static bool isFixtureCourse(Course course) =>
      course.id.startsWith(courseIdPrefix);

  static String fixtureIdForHour(int hour) =>
      '$courseIdPrefix${hour.clamp(0, 23).toString().padLeft(2, '0')}';

  static int hourSlotFor(DateTime time) => time.hour.clamp(0, 23);

  static int nextHourSlotFor(DateTime time) => (time.hour + 1) % 24;

  static String formatClock(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  static List<SectionTime> buildHourlySections() {
    return List<SectionTime>.generate(24, (hour) {
      final endHour = hour == 23 ? 23 : hour + 1;
      final endMinute = hour == 23 ? 59 : 0;
      return SectionTime(
        startTime: '${hour.toString().padLeft(2, '0')}:00',
        endTime:
            '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}',
      );
    });
  }

  static Future<TimeScheme> ensureHourlyTimeScheme(
    TimetableProvider provider,
  ) async {
    await provider.initialize();
    final sections = buildHourlySections();
    TimeScheme? existing;
    for (final scheme in provider.timeSchemes) {
      if (scheme.name == timeSchemeName) {
        existing = scheme;
        break;
      }
    }

    if (existing != null) {
      final needsUpdate = existing.sections.length != sections.length ||
          !_sectionsMatch(existing.sections, sections);
      if (needsUpdate) {
        final error = await provider.updateTimeScheme(
          schemeId: existing.id,
          name: timeSchemeName,
          sections: sections,
        );
        if (error != null) {
          throw StateError(error);
        }
      }
      return provider.timeSchemes.firstWhere((scheme) => scheme.id == existing!.id);
    }

    return provider.createTimeScheme(
      name: timeSchemeName,
      sections: sections,
    );
  }

  static bool _sectionsMatch(
    List<SectionTime> left,
    List<SectionTime> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i].startTime != right[i].startTime ||
          left[i].endTime != right[i].endTime) {
        return false;
      }
    }
    return true;
  }

  static List<Course> buildTwentyFourHourGrid({
    required DateTime now,
    required int semesterWeekCount,
    required String timeSchemeId,
  }) {
    final dayOfWeek = now.weekday;
    final sections = buildHourlySections();
    return List<Course>.generate(
      24,
      (hour) => buildSlotTemplate(
        hour: hour,
        dayOfWeek: dayOfWeek,
        semesterWeekCount: semesterWeekCount,
        timeSchemeId: timeSchemeId,
        section: sections[hour],
      ),
    );
  }

  static Course buildSlotTemplate({
    required int hour,
    required int dayOfWeek,
    required int semesterWeekCount,
    required String timeSchemeId,
    SectionTime? section,
  }) {
    final normalizedHour = hour.clamp(0, 23);
    final resolvedSection = section ?? buildHourlySections()[normalizedHour];
    final sectionIndex = normalizedHour + 1;
    final color = colorForHour(normalizedHour);
    return Course(
      id: fixtureIdForHour(normalizedHour),
      name: '测试 ${resolvedSection.startTime}',
      shortName: '测${normalizedHour.toString().padLeft(2, '0')}',
      teacher: '测试教师',
      location: '测试教室 ${normalizedHour.toString().padLeft(2, '0')}',
      dayOfWeek: dayOfWeek,
      startSection: sectionIndex,
      endSection: sectionIndex,
      startTime: resolvedSection.startTime,
      endTime: resolvedSection.endTime,
      color: color,
      startWeek: 1,
      endWeek: semesterWeekCount,
      timeSchemeIdOverride: timeSchemeId,
      note: '超级岛快捷测试课（可安全删除）',
    );
  }

  static Course buildTimedTestCourse({
    required Course template,
    required DateTime now,
    required Duration lead,
    Duration duration = defaultCourseDuration,
    String? note,
  }) {
    final start = now.add(lead);
    final end = start.add(duration);
    return template.copyWith(
      dayOfWeek: now.weekday,
      startTime: formatClock(start),
      endTime: formatClock(end),
      note: note ?? template.note,
    );
  }

  static String colorForHour(int hour) {
    final hue = (hour.clamp(0, 23) * 15) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.58, 0.48).toColor();
    String channel(double value) =>
        (value * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}';
  }

  static Course? findFixtureForHour(TimetableProvider provider, int hour) {
    final id = fixtureIdForHour(hour);
    for (final course in provider.courses) {
      if (course.id == id) {
        return course;
      }
    }
    return null;
  }

  static Future<int> removeAllFixtureCourses(TimetableProvider provider) async {
    await provider.initialize();
    final fixtureIds = provider.courses
        .where(isFixtureCourse)
        .map((course) => course.id)
        .toList(growable: false);
    for (final id in fixtureIds) {
      await provider.deleteCourse(id);
    }
    return fixtureIds.length;
  }

  static Future<int> installTwentyFourHourGrid(TimetableProvider provider) async {
    await provider.initialize();
    await removeAllFixtureCourses(provider);
    final scheme = await ensureHourlyTimeScheme(provider);
    final settings = provider.settings;
    final grid = buildTwentyFourHourGrid(
      now: DateTime.now(),
      semesterWeekCount: settings.semesterWeekCount,
      timeSchemeId: scheme.id,
    );
    return provider.importParsedCourses(
      grid,
      replaceExisting: false,
      source: 'live_testing_fixture',
    );
  }

  static Future<Course> upsertTimedFixtureCourse({
    required TimetableProvider provider,
    required int hour,
    required DateTime now,
    required Duration lead,
    String? note,
  }) async {
    await provider.initialize();
    final settings = provider.settings;
    final scheme = await ensureHourlyTimeScheme(provider);
    final template = findFixtureForHour(provider, hour) ??
        buildSlotTemplate(
          hour: hour,
          dayOfWeek: now.weekday,
          semesterWeekCount: settings.semesterWeekCount,
          timeSchemeId: scheme.id,
        );
    final timedCourse = buildTimedTestCourse(
      template: template,
      now: now,
      lead: lead,
      note: note,
    );
    if (findFixtureForHour(provider, hour) == null) {
      await provider.addCourse(timedCourse);
      return timedCourse;
    }
    await provider.updateCourse(timedCourse);
    return timedCourse;
  }
}
