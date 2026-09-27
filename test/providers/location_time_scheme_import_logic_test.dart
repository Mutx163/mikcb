import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/location_time_match_logic.dart';
import 'package:university_timetable/domain/location_time_scheme_import_logic.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/time_scheme.dart';

Map<String, Object?> _sections(List<List<String>> raw) => {
  'sections': [
    for (final pair in raw) {'startTime': pair[0], 'endTime': pair[1]},
  ],
};

void main() {
  group('LocationTimeSchemeImportLogic.parse', () {
    test('parses default plus two building groups', () {
      final spec = LocationTimeSchemeImportLogic.parse({
        'default': {
          'name': '永川校区·其他教学楼',
          ..._sections([
            ['08:20', '09:05'],
            ['09:15', '10:00'],
          ]),
        },
        'groups': [
          {
            'name': '永川校区·A主/主教学楼',
            'keywords': [
              {'pattern': 'A主', 'mode': 'prefix'},
            ],
            ..._sections([
              ['08:20', '09:05'],
              ['10:30', '11:15'],
            ]),
          },
        ],
      });

      expect(spec.defaultName, '永川校区·其他教学楼');
      expect(spec.defaultSections.length, 2);
      expect(spec.groups, hasLength(1));
      expect(spec.groups.single.name, '永川校区·A主/主教学楼');
      expect(spec.groups.single.keywords.single.pattern, 'A主');
      expect(
        spec.groups.single.keywords.single.mode,
        LocationKeywordMatchMode.prefix,
      );
      expect(spec.groups.single.sections[1].startTime, '10:30');
    });

    test('defaults unknown keyword mode to prefix', () {
      final spec = LocationTimeSchemeImportLogic.parse({
        'default': {'name': 'd', ..._sections([['08:00', '08:45']])},
        'groups': [
          {
            'name': 'g',
            'keywords': [
              {'pattern': 'A1', 'mode': 'nonsense'},
            ],
            ..._sections([['08:00', '08:45']]),
          },
        ],
      });
      expect(
        spec.groups.single.keywords.single.mode,
        LocationKeywordMatchMode.prefix,
      );
    });

    test('ignores the positional number field on sections', () {
      final spec = LocationTimeSchemeImportLogic.parse({
        'default': {
          'name': 'd',
          'sections': [
            {'number': 1, 'startTime': '08:20', 'endTime': '09:05'},
            {'number': 2, 'startTime': '09:15', 'endTime': '10:00'},
          ],
        },
      });
      expect(spec.defaultSections.map((s) => s.startTime), [
        '08:20',
        '09:15',
      ]);
    });

    test('skips groups without keywords or without sections', () {
      final spec = LocationTimeSchemeImportLogic.parse({
        'default': {'name': 'd', ..._sections([['08:00', '08:45']])},
        'groups': [
          {
            'name': 'no-keywords',
            'keywords': const [],
            ..._sections([['08:00', '08:45']]),
          },
          {
            'name': 'blank-keyword',
            'keywords': [
              {'pattern': '  '},
            ],
            ..._sections([['08:00', '08:45']]),
          },
          {
            'name': 'no-sections',
            'keywords': [
              {'pattern': 'A主'},
            ],
            'sections': const [],
          },
        ],
      });
      expect(spec.groups, isEmpty);
    });

    test('first duplicate group name wins', () {
      final spec = LocationTimeSchemeImportLogic.parse({
        'default': {'name': 'd', ..._sections([['08:00', '08:45']])},
        'groups': [
          {
            'name': 'dup',
            'keywords': [
              {'pattern': 'first'},
            ],
            ..._sections([['08:00', '08:45']]),
          },
          {
            'name': 'dup',
            'keywords': [
              {'pattern': 'second'},
            ],
            ..._sections([['09:00', '09:45']]),
          },
        ],
      });
      expect(spec.groups, hasLength(1));
      expect(spec.groups.single.keywords.single.pattern, 'first');
    });

    test('drops individual malformed entries but keeps the rest', () {
      final spec = LocationTimeSchemeImportLogic.parse({
        'default': {
          'name': 'd',
          'sections': [
            {'startTime': '08:20'}, // missing endTime
            {'endTime': '09:05'}, // missing startTime
            'not-a-map',
            {'startTime': '09:15', 'endTime': '10:00'},
          ],
        },
        'groups': 'not-a-list',
      });
      expect(spec.defaultSections, hasLength(1));
      expect(spec.defaultSections.single.startTime, '09:15');
      expect(spec.groups, isEmpty);
    });

    test('rejects payloads the host cannot use', () {
      expect(
        () => LocationTimeSchemeImportLogic.parse('nope'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'invalid_location_time_schemes_format',
          ),
        ),
      );
      expect(
        () => LocationTimeSchemeImportLogic.parse({'groups': []}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'location_time_schemes_default_required',
          ),
        ),
      );
      expect(
        () => LocationTimeSchemeImportLogic.parse({
          'default': {'name': '  ', ..._sections([['08:00', '08:45']])},
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'location_time_schemes_default_name_required',
          ),
        ),
      );
      expect(
        () => LocationTimeSchemeImportLogic.parse({
          'default': {'name': 'd', 'sections': []},
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'location_time_schemes_default_empty',
          ),
        ),
      );
    });

    test('round-trips through the real JSON the bridge receives', () {
      // Mirrors what course_import_screen.dart hands to the parser.
      const payload = '{"default":{"name":"永川校区·其他教学楼",'
          '"sections":[{"startTime":"08:20","endTime":"09:05"}]},'
          '"groups":[{"name":"永川校区·A主/主教学楼",'
          '"keywords":[{"pattern":"A主","mode":"prefix"}],'
          '"sections":[{"startTime":"08:20","endTime":"09:05"}]}]}';
      final spec = LocationTimeSchemeImportLogic.parse(
        jsonDecode(payload) as Object,
      );
      expect(spec.defaultName, '永川校区·其他教学楼');
      expect(spec.groups.single.name, '永川校区·A主/主教学楼');
    });
  });

  group('imported groups actually route by classroom', () {
    test('A主 classrooms take the main-building scheme', () {
      // The whole point of the extension: a course in A主215 must not fall back
      // to the default scheme.
      final spec = LocationTimeSchemeImportLogic.parse({
        'default': {
          'name': '永川校区·其他教学楼',
          ..._sections([
            ['08:20', '09:05'],
            ['10:20', '11:05'],
          ]),
        },
        'groups': [
          {
            'name': '永川校区·A主/主教学楼',
            'keywords': [
              {'pattern': 'A主', 'mode': 'prefix'},
            ],
            ..._sections([
              ['08:20', '09:05'],
              ['10:30', '11:15'],
            ]),
          },
        ],
      });

      // Simulate the host: bind each group name to its scheme id, then resolve.
      final groups = [
        for (var i = 0; i < spec.groups.length; i++)
          LocationTimeGroup(
            id: 'g$i',
            name: spec.groups[i].name,
            timeSchemeId: 'scheme-$i',
            priority: i,
            keywords: spec.groups[i].keywords,
          ),
      ];
      final schemes = <String, TimeScheme>{
        'default': TimeScheme(
          id: 'default',
          name: spec.defaultName,
          sections: spec.defaultSections,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        'scheme-0': TimeScheme(
          id: 'scheme-0',
          name: spec.groups[0].name,
          sections: spec.groups[0].sections,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      };

      String startFor(String classroom) {
        final match = LocationTimeMatchLogic.match(classroom, groups);
        final scheme = match == null
            ? schemes['default']
            : schemes[match.timeSchemeId];
        return scheme!.sections[1].startTime;
      }

      expect(startFor('A主215'), '10:30');
      expect(startFor('A主403'), '10:30');
      expect(startFor('A综204'), '10:20');
      expect(startFor('A6303'), '10:20');
      expect(startFor('A实415'), '10:20');
    });
  });
}
