import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/domain/time_scheme_logic.dart';

Course _course({
  required String id,
  String? timeSchemeIdOverride,
  int endSection = 4,
  int dayOfWeek = 1,
  String location = 'L',
}) {
  return Course(
    id: id,
    name: 'Course $id',
    teacher: 'T',
    location: location,
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: endSection,
    startTime: '08:00',
    endTime: '09:40',
    color: '#FF0000',
    timeSchemeIdOverride: timeSchemeIdOverride,
  );
}

TimeScheme _scheme(String id, {String name = 'Scheme'}) {
  final now = DateTime(2026);
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
  final now = DateTime(2026);
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

    test('uses location match when no override', () {
      final defaultScheme = _scheme('default');
      final otherScheme = _scheme('other');
      final settings = TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: defaultScheme.id,
      );
      final course = Course(
        id: '1',
        name: 'Course',
        teacher: 'T',
        location: 'A1062',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        color: '#FF0000',
      );
      final groups = [
        LocationTimeGroup(
          id: 'g1',
          name: '其他教学楼',
          timeSchemeId: otherScheme.id,
          keywords: const [
            LocationKeyword(
              pattern: 'A1',
            ),
          ],
        ),
      ];

      expect(
        TimeSchemeLogic.resolveCourseTimeScheme(
          [defaultScheme, otherScheme],
          settings,
          course,
          locationTimeGroups: groups,
        ),
        otherScheme,
      );
    });

    test('manual override still beats location match', () {
      final defaultScheme = _scheme('default');
      final otherScheme = _scheme('other');
      final overrideScheme = _scheme('override');
      final settings = TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: defaultScheme.id,
      );
      final course = _course(
        id: '1',
        timeSchemeIdOverride: overrideScheme.id,
      ).copyWith(location: 'A1062');
      final groups = [
        LocationTimeGroup(
          id: 'g1',
          name: '其他教学楼',
          timeSchemeId: otherScheme.id,
          keywords: const [
            LocationKeyword(
              pattern: 'A1',
            ),
          ],
        ),
      ];

      expect(
        TimeSchemeLogic.resolveCourseTimeScheme(
          [defaultScheme, otherScheme, overrideScheme],
          settings,
          course,
          locationTimeGroups: groups,
        ),
        overrideScheme,
      );
    });

    test('date rules do not soft-overlay resolve (bulk apply is separate)', () {
      final defaultScheme = _scheme('default');
      final summerScheme = _scheme('summer');
      final settings = TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: defaultScheme.id,
      );
      final course = _course(id: '1');
      final rules = [
        ScheduleDateRule(
          id: 'r1',
          name: '夏令时',
          timeSchemeId: summerScheme.id,
          startDate: '2026-05-01',
          endDate: '2026-09-30',
        ),
      ];

      expect(
        TimeSchemeLogic.resolveCourseTimeScheme(
          [defaultScheme, summerScheme],
          settings,
          course,
          scheduleDateRules: rules,
          onDate: DateTime(2026, 7),
        ),
        defaultScheme,
      );
    });

    test('resolve always uses profile default when no override/location', () {
      final defaultScheme = _scheme('default');
      final summerScheme = _scheme('summer');
      final settings = TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: defaultScheme.id,
      );
      final course = _course(id: '1');
      final rules = [
        ScheduleDateRule(
          id: 'r1',
          name: '夏令时',
          timeSchemeId: summerScheme.id,
          startDate: '2026-05-01',
          endDate: '2026-09-30',
        ),
      ];

      expect(
        TimeSchemeLogic.resolveCourseTimeScheme(
          [defaultScheme, summerScheme],
          settings,
          course,
          scheduleDateRules: rules,
        ),
        defaultScheme,
      );
    });

    test('location match beats date rule', () {
      final defaultScheme = _scheme('default');
      final summerScheme = _scheme('summer');
      final buildingScheme = _scheme('building');
      final settings = TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: defaultScheme.id,
      );
      final course = _course(id: '1').copyWith(location: 'A1062');
      final groups = [
        LocationTimeGroup(
          id: 'g1',
          name: '其他教学楼',
          timeSchemeId: buildingScheme.id,
          keywords: const [
            LocationKeyword(
              pattern: 'A1',
            ),
          ],
        ),
      ];
      final rules = [
        ScheduleDateRule(
          id: 'r1',
          name: '夏令时',
          timeSchemeId: summerScheme.id,
          startDate: '2026-05-01',
          endDate: '2026-09-30',
        ),
      ];

      expect(
        TimeSchemeLogic.resolveCourseTimeScheme(
          [defaultScheme, summerScheme, buildingScheme],
          settings,
          course,
          locationTimeGroups: groups,
          scheduleDateRules: rules,
          onDate: DateTime(2026, 7),
        ),
        buildingScheme,
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
          courses: [_course(id: 'c3')],
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
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
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

    test('reports no blockers for a scheme nothing references', () {
      final scheme = _scheme('free');
      final profiles = [
        _profile(
          id: 'p1',
          name: 'Main',
          activeSchemeId: 'other',
          courses: [_course(id: 'c1')],
        ),
      ];

      final blockers = TimeSchemeLogic.collectDeleteBlockers(profiles, scheme.id);

      expect(blockers.isEmpty, isTrue);
      expect(TimeSchemeLogic.isSchemeInUse(profiles, scheme.id), isFalse);
    });

    test('names the blocking profiles and counts override courses', () {
      final scheme = _scheme('in-use');
      final profiles = [
        _profile(id: 'p1', name: 'Main', activeSchemeId: scheme.id),
        _profile(
          id: 'p2',
          name: 'Alt',
          activeSchemeId: 'other',
          courses: [
            _course(id: 'c1', timeSchemeIdOverride: scheme.id),
            _course(id: 'c2', timeSchemeIdOverride: scheme.id),
          ],
        ),
      ];

      final blockers = TimeSchemeLogic.collectDeleteBlockers(profiles, scheme.id);

      expect(blockers.profileNames, ['Main']);
      expect(blockers.overrideCourseCount, 2);
      expect(blockers.locationCourseCount, 0);
      expect(blockers.isNotEmpty, isTrue);
    });

    // The management page used to gate the delete row on profiles and courses
    // only, so a scheme held by one of these two looked deletable and the
    // provider then refused after the confirm dialog had already been accepted.
    test('reports location group and date rule references', () {
      final scheme = _scheme('in-use');
      final profiles = [
        _profile(id: 'p1', name: 'Main', activeSchemeId: 'other'),
      ];

      final blockers = TimeSchemeLogic.collectDeleteBlockers(
        profiles,
        scheme.id,
        schemes: [scheme],
        locationTimeGroups: [
          LocationTimeGroup(
            id: 'g1',
            name: '实验楼',
            timeSchemeId: scheme.id,
          ),
        ],
        scheduleDateRules: [
          ScheduleDateRule(
            id: 'r1',
            name: '期末周',
            timeSchemeId: scheme.id,
            startDate: '2026-01-05',
            endDate: '2026-01-18',
          ),
        ],
      );

      expect(blockers.locationGroupNames, ['实验楼']);
      expect(blockers.dateRuleNames, ['期末周']);
      expect(blockers.isNotEmpty, isTrue);
    });

    test('counts courses routed to the scheme by a location group', () {
      final scheme = _scheme('lab');
      final profiles = [
        _profile(
          id: 'p1',
          name: 'Main',
          activeSchemeId: 'other',
          courses: [
            _course(id: 'c1', location: '实验楼 101'),
            _course(id: 'c2', location: '实验楼 202'),
            _course(id: 'c3', location: '主教学楼 301'),
          ],
        ),
      ];

      final blockers = TimeSchemeLogic.collectDeleteBlockers(
        profiles,
        scheme.id,
        schemes: [scheme],
        locationTimeGroups: [
          LocationTimeGroup(
            id: 'g1',
            name: '实验楼',
            timeSchemeId: scheme.id,
            keywords: const [LocationKeyword(pattern: '实验楼')],
          ),
        ],
      );

      expect(blockers.locationCourseCount, 2);
      expect(blockers.overrideCourseCount, 0);
      expect(blockers.isNotEmpty, isTrue);
    });
  });
}
