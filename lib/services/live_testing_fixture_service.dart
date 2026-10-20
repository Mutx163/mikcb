import 'dart:math';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';

/// 测试课表夹具需要的宿主窄面（端口由消费方定义）。
///
/// 本文件在 services 层，不反向 import `providers/timetable_provider.dart`：
/// 夹具安装/清理只需要「初始化 / 作息读写 / 课程读写 / 按解析导入」十一个
/// 成员。宿主适配器 `LiveFixtureProviderAccess` 见
/// `lib/providers/live_testing_fixture_access.dart`，由调用点注入。
abstract class LiveTestingFixtureHost {
  Future<void> initialize();

  List<TimeScheme> get timeSchemes;

  Future<String?> updateTimeScheme({
    required String schemeId,
    required String name,
    required List<SectionTime> sections,
  });

  Future<TimeScheme> createTimeScheme({
    required String name,
    List<SectionTime>? sections,
  });

  List<Course> get courses;

  Future<void> deleteCourse(String courseId);

  Future<String?> applyTimeScheme(String schemeId);

  TimetableSettings get settings;

  Future<int> importParsedCourses(
    List<Course> importedCourses, {
    required bool replaceExisting,
    required String source,
  });

  Future<void> addCourse(Course course);

  Future<void> updateCourse(Course course);
}

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

  static const String presetCourseIdA = '${courseIdPrefix}preset_a';
  static const String presetCourseIdB = '${courseIdPrefix}preset_b';
  static const Duration defaultPresetLead = Duration(minutes: 1);
  static const Duration defaultPresetCourseDuration = Duration(minutes: 3);
  static const Duration defaultPresetGap = Duration(minutes: 1);

  // 预设课 A 的展示字段。「速览」空课表兜底（live_testing_trigger.dart 的
  // resolveLivePreviewTestCourse catch 分支）与 buildPresetCourses 必须用同一份，
  // 否则两边文案会各自漂移——那门课的名字会直接显示在超级岛与设置页预览上。
  static const String presetCourseAName = '自检预设课 A';
  static const String presetCourseAShortName = '自检A';
  static const String presetCourseATeacher = '自检教师';
  static const String presetCourseALocation = '自检教室 A';

  /// 预设课 A 的离线兜底副本（不依赖时间计算）。
  ///
  /// buildPresetCourses 在临近午夜时会抛「无法生成不跨日预设测试课」；
  /// 速览入口必须仍能起岛，故这里给一份固定 08:00-09:40 的同名副本。
  static Course buildPresetCourseAFallback() => Course(
    id: presetCourseIdA,
    name: presetCourseAName,
    shortName: presetCourseAShortName,
    teacher: presetCourseATeacher,
    location: presetCourseALocation,
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  static bool isFixtureCourse(Course course) =>
      course.id.startsWith(courseIdPrefix);

  static bool isPresetCourse(Course course) =>
      course.id.startsWith('${courseIdPrefix}preset_');

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
    LiveTestingFixtureHost host,
  ) async {
    await host.initialize();
    final sections = buildHourlySections();
    TimeScheme? existing;
    for (final scheme in host.timeSchemes) {
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
        final error = await host.updateTimeScheme(
          schemeId: existing.id,
          name: timeSchemeName,
          sections: sections,
        );
        if (error != null) {
          throw StateError(error);
        }
      }
      return host.timeSchemes.firstWhere(
        (scheme) => scheme.id == existing!.id,
      );
    }

    return host.createTimeScheme(
      name: timeSchemeName,
      sections: sections,
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
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be positive');
    }
    final start = now.add(lead);
    final end = start.add(duration);
    // Course clocks are date-less and the timetable does not support
    // overnight lessons. Near midnight, a normal lead+duration pair can
    // otherwise become e.g. 23:59 -> 00:02, which is rejected by the live
    // selector as an invalid course. Refuse that fixture instead of writing
    // an impossible clock range.
    if (start.year != end.year ||
        start.month != end.month ||
        start.day != end.day) {
      throw StateError('当前时间距离午夜太近，无法生成不跨日测试课，请在午夜后重试');
    }
    return template.copyWith(
      dayOfWeek: start.weekday,
      startTime: formatClock(start),
      endTime: formatClock(end),
      note: note ?? template.note,
    );
  }

  /// 自检预设课：真实课表无课可测（如刚安装还没有课）时的兜底测试数据。
  ///
  /// 与正式课同规则：同一天、同周次跨度、走同一条选课/快照/原生校验管线；
  /// 但只注入超级岛管线的内存覆盖层，绝不写入真实课表。时间用自由时钟
  /// （与 [_isLiveTestingFixture] 的旁路约定一致），第一门从现在起 [lead]
  /// 分钟后上课，第二门在 [gap] 后接棒，让岛的「下节课」位也有内容。
  static List<Course> buildPresetCourses({
    required DateTime now,
    required int targetWeek,
    required int semesterWeekCount,
    Duration lead = defaultPresetLead,
    Duration duration = defaultPresetCourseDuration,
    Duration gap = defaultPresetGap,
  }) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be positive');
    }
    if (gap < Duration.zero) {
      throw ArgumentError.value(gap, 'gap', 'must not be negative');
    }
    final firstStart = now.add(lead);
    final firstEnd = firstStart.add(duration);
    final secondStart = firstEnd.add(gap);
    final secondEnd = secondStart.add(duration);
    // 与 buildTimedTestCourse 相同的不跨日约束：课表不支持隔夜课。
    for (final time in [firstStart, firstEnd, secondStart, secondEnd]) {
      if (time.year != now.year ||
          time.month != now.month ||
          time.day != now.day) {
        throw StateError('当前时间距离午夜太近，无法生成不跨日预设测试课，请在午夜后重试');
      }
    }
    // 覆盖选课路径实际使用的日历周：学期未开始是第 0 周，学期结束后会超过
    // semesterWeekCount，两种情况都要让周次规则照常放行。
    final startWeek = targetWeek < 1 ? targetWeek : 1;
    final endWeek = [targetWeek, semesterWeekCount, 1].reduce(max);
    return [
      Course(
        id: presetCourseIdA,
        name: presetCourseAName,
        shortName: presetCourseAShortName,
        teacher: presetCourseATeacher,
        location: presetCourseALocation,
        dayOfWeek: now.weekday,
        startSection: 1,
        endSection: 1,
        startTime: formatClock(firstStart),
        endTime: formatClock(firstEnd),
        color: colorForSection(11, 24),
        startWeek: startWeek,
        endWeek: endWeek,
        note: '自检预设课程（仅超级岛测试用，不写入课表）',
      ),
      Course(
        id: presetCourseIdB,
        name: '自检预设课 B',
        shortName: '自检B',
        teacher: '自检教师',
        location: '自检教室 B',
        dayOfWeek: now.weekday,
        startSection: 2,
        endSection: 2,
        startTime: formatClock(secondStart),
        endTime: formatClock(secondEnd),
        color: colorForSection(17, 24),
        startWeek: startWeek,
        endWeek: endWeek,
        note: '自检预设课程（仅超级岛测试用，不写入课表）',
      ),
    ];
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
    LiveTestingFixtureHost host,
    int sectionNumber,
  ) {
    final id = fixtureIdForSection(sectionNumber);
    for (final course in host.courses) {
      if (course.id == id) {
        return course;
      }
    }
    return null;
  }

  static Future<int> removeAllFixtureCourses(
    LiveTestingFixtureHost host,
  ) async {
    await host.initialize();
    final fixtureIds = host.courses
        .where(isFixtureCourse)
        .map((course) => course.id)
        .toList(growable: false);
    for (final id in fixtureIds) {
      await host.deleteCourse(id);
    }
    return fixtureIds.length;
  }

  /// Ensures the 24-hour scheme, **applies it as active**, then installs one
  /// fixture course per section for today.
  static Future<int> installSectionGrid(LiveTestingFixtureHost host) async {
    await host.initialize();
    await removeAllFixtureCourses(host);

    final scheme = await ensureHourlyTimeScheme(host);
    // Without this, courses use the 24-section scheme data but the week grid
    // still renders the previous scheme — the original mismatch.
    final applyError = await host.applyTimeScheme(scheme.id);
    if (applyError != null) {
      throw StateError(applyError);
    }

    final settings = host.settings;
    final sections = List<SectionTime>.from(scheme.sections);
    if (sections.isEmpty) {
      throw StateError('测试时间方案没有节次，无法安装测试课表');
    }

    final grid = buildSectionGrid(
      now: DateTime.now(),
      semesterWeekCount: settings.semesterWeekCount,
      sections: sections,
    );
    return host.importParsedCourses(
      grid,
      replaceExisting: false,
      source: 'live_testing_fixture',
    );
  }

  static Future<Course> upsertTimedFixtureCourse({
    required LiveTestingFixtureHost host,
    required int sectionNumber,
    required DateTime now,
    required Duration lead,
    String? note,
  }) async {
    await host.initialize();
    final settings = host.settings;
    final sections = settings.sections;
    if (sections.isEmpty) {
      throw StateError('当前课表没有节次时间，无法写入测试课');
    }
    final clampedSection = sectionNumber.clamp(1, sections.length);
    final section = sections[clampedSection - 1];
    final template =
        findFixtureForSection(host, clampedSection) ??
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
    if (findFixtureForSection(host, clampedSection) == null) {
      await host.addCourse(timedCourse);
      return timedCourse;
    }
    await host.updateCourse(timedCourse);
    return timedCourse;
  }
}
