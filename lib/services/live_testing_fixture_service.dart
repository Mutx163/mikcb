import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';

/// Debug-only helpers for installing and driving live-update test timetables.
///
/// Install flow:
/// 1. Ensure the shared 24-section hourly scheme [timeSchemeName]
/// 2. **Apply it as the active time scheme** so left-rail times match courses
/// 3. Install one fixture course per section (section-indexed, not free-form clock)
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

  /// 1-based section number → stable fixture id (`live_test_01` …).
  static String fixtureIdForSection(int sectionNumber) {
    final normalized = sectionNumber < 1 ? 1 : sectionNumber;
    return '$courseIdPrefix${normalized.toString().padLeft(2, '0')}';
  }

  static String formatClock(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  /// 24 sections: 第1节=00:00–01:00 … 第24节=23:00–23:59.
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

  static bool _sectionsMatch(List<SectionTime> left, List<SectionTime> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index].startTime != right[index].startTime ||
          left[index].endTime != right[index].endTime) {
        return false;
      }
    }
    return true;
  }

  /// Creates or updates the 24-hour test scheme (does not apply it).
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
      final needsUpdate =
          existing.sections.length != sections.length ||
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
      return provider.timeSchemes.firstWhere(
        (scheme) => scheme.id == existing!.id,
      );
    }

    return provider.createTimeScheme(
      name: timeSchemeName,
      sections: sections,
      applyToActiveProfile: false,
    );
  }

  static int? _clockMinutes(String clock) {
    final parts = clock.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return hour * 60 + minute;
  }

  /// Section (1-based) that [time] falls in, or the next upcoming section,
  /// or the last section when the day is already past all sections.
  static int sectionNumberForTime(DateTime time, List<SectionTime> sections) {
    if (sections.isEmpty) {
      return 1;
    }
    final minutes = time.hour * 60 + time.minute;
    for (var index = 0; index < sections.length; index++) {
      final startMinutes = _clockMinutes(sections[index].startTime) ?? 0;
      final endMinutes =
          _clockMinutes(sections[index].endTime) ?? (startMinutes + 1);
      if (minutes < startMinutes) {
        return index + 1;
      }
      if (minutes < endMinutes) {
        return index + 1;
      }
    }
    return sections.length;
  }

  /// Section after [sectionNumberForTime], wrapping to 1 after the last.
  static int nextSectionNumberForTime(
    DateTime time,
    List<SectionTime> sections,
  ) {
    if (sections.isEmpty) {
      return 1;
    }
    final current = sectionNumberForTime(time, sections);
    return current >= sections.length ? 1 : current + 1;
  }

  static List<Course> buildSectionGrid({
    required DateTime now,
    required int semesterWeekCount,
    required List<SectionTime> sections,
  }) {
    final dayOfWeek = now.weekday;
    return List<Course>.generate(
      sections.length,
      (index) => buildSlotTemplate(
        sectionNumber: index + 1,
        section: sections[index],
        dayOfWeek: dayOfWeek,
        semesterWeekCount: semesterWeekCount,
        totalSections: sections.length,
      ),
    );
  }

  static Course buildSlotTemplate({
    required int sectionNumber,
    required SectionTime section,
    required int dayOfWeek,
    required int semesterWeekCount,
    int totalSections = 1,
  }) {
    final normalizedSection = sectionNumber < 1 ? 1 : sectionNumber;
    final color = colorForSection(normalizedSection, totalSections);
    final padded = normalizedSection.toString().padLeft(2, '0');
    return Course(
      id: fixtureIdForSection(normalizedSection),
      name: '测试 第$normalizedSection节',
      shortName: '测$padded',
      teacher: '测试教师',
      location: '测试教室 $padded',
      dayOfWeek: dayOfWeek,
      startSection: normalizedSection,
      endSection: normalizedSection,
      startTime: section.startTime,
      endTime: section.endTime,
      color: color,
      startWeek: 1,
      endWeek: semesterWeekCount,
      note: '超级岛快捷测试课（可安全删除）',
    );
  }

  /// Shifts only the clock fields for live-island lead testing.
  /// Section indices stay on the template so the week grid placement is stable.
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

  static String colorForSection(int sectionNumber, int totalSections) {
    final safeTotal = totalSections < 1 ? 1 : totalSections;
    final hueStep = 360.0 / safeTotal;
    final hue = ((sectionNumber - 1).clamp(0, safeTotal - 1) * hueStep) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.58, 0.48).toColor();
    String channel(double value) =>
        (value * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}';
  }

  static Course? findFixtureForSection(
    TimetableProvider provider,
    int sectionNumber,
  ) {
    final id = fixtureIdForSection(sectionNumber);
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

  /// Ensures the 24-hour scheme, **applies it as active**, then installs one
  /// fixture course per section for today.
  static Future<int> installSectionGrid(TimetableProvider provider) async {
    await provider.initialize();
    await removeAllFixtureCourses(provider);

    final scheme = await ensureHourlyTimeScheme(provider);
    // Without this, courses use the 24-section scheme data but the week grid
    // still renders the previous scheme — the original mismatch.
    final applyError = await provider.applyTimeScheme(scheme.id);
    if (applyError != null) {
      throw StateError(applyError);
    }

    final settings = provider.settings;
    final sections = List<SectionTime>.from(scheme.sections);
    if (sections.isEmpty) {
      throw StateError('测试时间方案没有节次，无法安装测试课表');
    }

    final grid = buildSectionGrid(
      now: DateTime.now(),
      semesterWeekCount: settings.semesterWeekCount,
      sections: sections,
    );
    return provider.importParsedCourses(
      grid,
      replaceExisting: false,
      source: 'live_testing_fixture',
    );
  }

  static Future<Course> upsertTimedFixtureCourse({
    required TimetableProvider provider,
    required int sectionNumber,
    required DateTime now,
    required Duration lead,
    String? note,
  }) async {
    await provider.initialize();
    final settings = provider.settings;
    final sections = settings.sections;
    if (sections.isEmpty) {
      throw StateError('当前课表没有节次时间，无法写入测试课');
    }
    final clampedSection = sectionNumber.clamp(1, sections.length);
    final section = sections[clampedSection - 1];
    final template =
        findFixtureForSection(provider, clampedSection) ??
        buildSlotTemplate(
          sectionNumber: clampedSection,
          section: section,
          dayOfWeek: now.weekday,
          semesterWeekCount: settings.semesterWeekCount,
          totalSections: sections.length,
        );
    final timedCourse = buildTimedTestCourse(
      template: template,
      now: now,
      lead: lead,
      note: note,
    );
    if (findFixtureForSection(provider, clampedSection) == null) {
      await provider.addCourse(timedCourse);
      return timedCourse;
    }
    await provider.updateCourse(timedCourse);
    return timedCourse;
  }
}
