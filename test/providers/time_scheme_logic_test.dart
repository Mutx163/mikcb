import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable/time_scheme_logic.dart';

Course _course({
  required String id,
  String? timeSchemeIdOverride,
  int endSection = 4,
  int dayOfWeek = 1,
}) {
  return Course(
    id: id,
    name: 'Course $id',
    teacher: 'T',
    location: 'L',
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: endSection,
    startTime: '08:00',
    endTime: '09:40',
    startWeek: 1,
    endWeek: 16,
    color: '#FF0000',
    timeSchemeIdOverride: timeSchemeIdOverride,
  );
}

TimeScheme _scheme(String id, {String name = 'Scheme'}) {
  final now = DateTime(2026, 1, 1);
  return TimeScheme(
    id: id,
    name: name,
    sections: TimetableSettings.defaults().sections,
    createdAt: now,
    updatedAt: now,
  );
}

TimetableProfile _profile({
  required String id,
  required String name,
  required String activeSchemeId,
  List<Course> courses = const [],
}) {
  final now = DateTime(2026, 1, 1);
  return TimetableProfile(
    id: id,
    name: name,
    courses: courses,
    settings: TimetableSettings.defaults().copyWith(
      activeTimeSchemeId: activeSchemeId,
    ),
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
}

void main() {
  group('TimeSchemeLogic.getSchemeById', () {
    test('returns null for unknown id', () {
      expect(TimeSchemeLogic.getSchemeById([_scheme('a')], 'missing'), isNull);
    });

    test('returns matching scheme', () {
      final scheme = _scheme('a');
      expect(TimeSchemeLogic.getSchemeById([scheme], 'a'), scheme);
    });
  });

  group('TimeSchemeLogic.resolveCourseTimeScheme', () {
    test('prefers course override over profile scheme', () {
      final defaultScheme = _scheme('default');
      final overrideScheme = _scheme('override');
      final settings = TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: defaultScheme.id,
      );
      final course = _course(id: '1', timeSchemeIdOverride: overrideScheme.id);

      expect(
        TimeSchemeLogic.resolveCourseTimeScheme(
          [defaultScheme, overrideScheme],
          settings,
          course,
        ),
        overrideScheme,
      );
    });

    test('falls back to profile active scheme', () {
      final scheme = _scheme('active');
      final settings = TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: scheme.id,
      );
      final course = _course(id: '1');

      expect(
        TimeSchemeLogic.resolveCourseTimeScheme([scheme], settings, course),
        scheme,
      );
    });
  });

  group('TimeSchemeLogic.getCourseUsages', () {
    test('collects profile-level and override usages', () {
      final schemeA = _scheme('a', name: 'A');
      final schemeB = _scheme('b', name: 'B');
      final profiles = [
        _profile(
          id: 'p1',
          name: 'Main',
          activeSchemeId: schemeA.id,
          courses: [
            _course(id: 'c1', endSection: 2),
            _course(id: 'c2', timeSchemeIdOverride: schemeB.id, endSection: 6),
          ],
        ),
        _profile(
          id: 'p2',
          name: 'Other',
          activeSchemeId: schemeB.id,
          courses: [_course(id: 'c3', endSection: 4)],
        ),
      ];

      final usagesA = TimeSchemeLogic.getCourseUsages(profiles, schemeA.id);
      expect(usagesA, hasLength(1));
      expect(usagesA.first.profileName, 'Main');
      expect(usagesA.first.usesOverride, isFalse);

      final usagesB = TimeSchemeLogic.getCourseUsages(profiles, schemeB.id);
      expect(usagesB, hasLength(2));
      expect(usagesB.any((u) => u.usesOverride), isTrue);
    });
  });

  group('TimeSchemeLogic.maxUsedSection', () {
    test('returns highest endSection among usages', () {
      final scheme = _scheme('a');
      final profiles = [
        _profile(
          id: 'p1',
          name: 'Main',
          activeSchemeId: scheme.id,
          courses: [
            _course(id: 'c1', endSection: 2),
            _course(id: 'c2', endSection: 8),
          ],
        ),
      ];

      expect(TimeSchemeLogic.maxUsedSection(profiles, scheme.id), 8);
    });

    test('returns 0 when scheme is unused', () {
      expect(TimeSchemeLogic.maxUsedSection([], 'missing'), 0);
    });
  });

  group('TimeSchemeLogic.validateCourseTimeSchemeOverride', () {
    test('rejects sections outside scheme capacity', () {
      final shortSections = TimetableSettings.defaults().sections.sublist(0, 4);
      final scheme = TimeScheme(
        id: 'a',
        name: 'Short',
        sections: shortSections,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final settings = TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: scheme.id,
      );

      expect(
        TimeSchemeLogic.validateCourseTimeSchemeOverride(
          schemes: [scheme],
          settings: settings,
          timeSchemeId: scheme.id,
          startSection: 1,
          endSection: 5,
        ),
        contains('time_scheme_sections_insufficient'),
      );
    });
  });

  group('TimeSchemeLogic.isSchemeInUse', () {
    test('detects active profile and override references', () {
      final scheme = _scheme('in-use');
      final other = _scheme('free');
      final profiles = [
        _profile(id: 'p1', name: 'Main', activeSchemeId: scheme.id),
        _profile(
          id: 'p2',
          name: 'Alt',
          activeSchemeId: other.id,
          courses: [_course(id: 'c1', timeSchemeIdOverride: scheme.id)],
        ),
      ];

      expect(TimeSchemeLogic.isSchemeInUse(profiles, scheme.id), isTrue);
      expect(TimeSchemeLogic.isSchemeInUse(profiles, other.id), isTrue);
      expect(TimeSchemeLogic.isSchemeInUse(profiles, 'unused'), isFalse);
    });
  });
}
