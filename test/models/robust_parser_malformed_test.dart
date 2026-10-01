import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/services/holiday_service.dart';
import 'package:http/http.dart' as http;

// Focused robustness tests for B2/B3/D2/D3/D5/D7/D8.
// Each group verifies: one malformed entry is skipped, valid records preserved,
// grouping/precedence and required IDs respected, no silent ID invention.

void main() {
  group('D3 HolidayEntry/HolidayData robust parsing', () {
    test('HolidayEntry.fromJson rejects missing date', () {
      expect(
        () => HolidayEntry.fromJson({'name': 'test', 'type': 'vacation'}),
        throwsA(isA<FormatException>()),
      );
    });
    test('HolidayEntry.fromJson rejects bad date string', () {
      expect(
        () => HolidayEntry.fromJson({
          'date': 'not-a-date',
          'name': 'x',
          'type': 'vacation',
        }),
        throwsA(isA<FormatException>()),
      );
    });
    test('HolidayEntry.fromJson rejects missing name', () {
      expect(
        () => HolidayEntry.fromJson({'date': '2026-10-01', 'type': 'vacation'}),
        throwsA(isA<FormatException>()),
      );
    });
    test('HolidayData.fromJson skips malformed entry, keeps valid', () {
      final data = HolidayData.fromJson({
        'year': 2026,
        'version': 1,
        'entries': [
          {
            'date': '2026-10-01',
            'name': '国庆',
            'type': 'vacation',
            'groupId': 'holiday-2026-0',
          },
          {'date': 'bad-date', 'name': 'bad', 'type': 'vacation'},
          {'name': 'missing-date', 'type': 'vacation'},
          {
            'date': '2026-10-02',
            'name': '国庆',
            'type': 'vacation',
            'groupId': 'holiday-2026-0',
          },
          'not-a-map',
        ],
      });
      expect(data.entries.length, 2);
      expect(data.holidayDateKeysForSnapshot(), ['2026-10-01', '2026-10-02']);
    });
    test(
      'HolidayData preserves year string coercion and skips invalid year',
      () {
        expect(
          HolidayData.fromJson({'year': '2026', 'entries': []}).year,
          2026,
        );
        expect(
          () => HolidayData.fromJson({'year': 'bad', 'entries': []}),
          throwsA(isA<FormatException>()),
        );
      },
    );
    test('HolidayData grouping/precedence: custom overrides makeup', () {
      final data = HolidayData.fromJson({
        'year': 2026,
        'entries': [
          {
            'date': '2026-10-01',
            'name': '国庆',
            'type': 'vacation',
            'groupId': 'holiday-2026-0',
          },
          {
            'date': '2026-10-01',
            'name': '学校补班',
            'type': 'adjusted_workday',
            'groupId': 'custom-makeup-1',
          },
          {'date': 'bad', 'name': '', 'type': 'vacation'},
        ],
      });
      // custom makeup on same date as vacation => isHoliday false due to adjustedWorkday precedence
      expect(data.entries.length, 2);
      expect(data.isHoliday(DateTime(2026, 10)), isFalse);
      expect(data.adjustedWorkdayDateKeysForSnapshot(), ['2026-10-01']);
    });
  });

  group('B2 holiday_service remote converters skip malformed', () {
    test('convertApiEntries skips bad date/daytype and keeps valid', () {
      final svc = HolidayService(client: http.Client());
      final entries = svc.convertApiEntriesForTest([
        {'date': '2026-10-01', 'daytype': 1, 'rest': 1},
        {'date': 'not-a-date', 'daytype': 1},
        {'daytype': 1, 'rest': 1}, // missing date
        {'date': '2026-10-02', 'daytype': 1, 'rest': 1},
        {'date': '2026-10-10', 'daytype': 3, 'rest': 0},
        {'date': '2026-10-10', 'daytype': 'bad'}, // bad daytype
        'not-a-map',
      ], 2026);
      // 2 vacations + 1 makeup; grouping preserved
      expect(entries.where((e) => e.type == HolidayType.vacation).length, 2);
      expect(
        entries.where((e) => e.type == HolidayType.adjustedWorkday).length,
        1,
      );
      svc.dispose();
    });
  });

  group('D5 TimeScheme robust parsing', () {
    test(
      'heals malformed SectionTime in place; keeps valid and required id',
      () {
        final scheme = TimeScheme.fromJson({
          'id': 'scheme-1',
          'name': 'test',
          'sections': [
            {'startTime': '08:00', 'endTime': '08:45'},
            {'startTime': '', 'endTime': '09:40'}, // bad
            {'startTime': '10:00', 'endTime': '10:45'},
            'bad',
            {'startTime': '11:00'}, // missing end
          ],
          'createdAt': '2026-01-01T00:00:00.000',
          'updatedAt': '2026-01-01T00:00:00.000',
        });
        // 节次表按位置被消费（Course.startSection 是下标），所以坏条目必须补位
        // 而不是删除：这里原本会把 10:00 那节从第 3 节塌成第 2 节，于是第 3 节
        // 起所有课程都指向后一节的时间，而界面看不出任何异常。
        expect(scheme.sections.length, 5);
        expect(scheme.sections.map((s) => s.displayText), [
          '08:00-08:45',
          '-',
          '10:00-10:45',
          '-',
          '-',
        ]);
        expect(scheme.id, 'scheme-1');
      },
    );
    test('TimeScheme rejects missing id (no silent invention)', () {
      expect(
        () => TimeScheme.fromJson({'name': 'x', 'sections': []}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TimeScheme.fromJson({'id': '', 'sections': []}),
        throwsA(isA<FormatException>()),
      );
    });

    test('wrong sections container defaults to an empty list', () {
      final scheme = TimeScheme.fromJson({'id': 'scheme-map', 'sections': {}});
      expect(scheme.sections, isEmpty);
    });
  });

  group('D7 SectionTime/SavedTheme/TimetableSettings robust parsing', () {
    test('SectionTime rejects missing fields', () {
      expect(
        () => SectionTime.fromJson({'startTime': '08:00'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SectionTime.fromJson({'endTime': '08:45'}),
        throwsA(isA<FormatException>()),
      );
    });
    test('SavedTheme rejects missing id/name/createdAt', () {
      expect(
        () => SavedTheme.fromJson({
          'name': 'n',
          'themeData': {},
          'createdAt': '2026-01-01T00:00:00.000',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SavedTheme.fromJson({
          'id': 'a',
          'themeData': {},
          'createdAt': '2026-01-01T00:00:00.000',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SavedTheme.fromJson({
          'id': 'a',
          'name': 'n',
          'themeData': {},
          'createdAt': 'bad',
        }),
        throwsA(isA<FormatException>()),
      );
    });
    test(
      'TimetableSettings heals malformed sections in place, skips bad themes',
      () {
        final s = TimetableSettings.fromJson({
          'sections': [
            {'startTime': '08:00', 'endTime': '08:45'},
            {'startTime': '', 'endTime': ''}, // bad
            123,
          ],
          'semesterWeekCount': 24,
          'themeSeedColor': '#FF0000',
          'savedThemes': [
            {
              'id': 't1',
              'name': 'good',
              'themeData': {'v': 2, 'seed': '#00FF00'},
              'createdAt': '2026-01-01T00:00:00.000',
            },
            {'id': '', 'name': 'bad', 'themeData': {}, 'createdAt': 'bad'},
            'not-a-map',
          ],
        });

        // 节次表是位置表：坏条目必须按位补，不能删掉让后面的节次前移，
        // 否则 Course.startSection 会从这一节起全部指向错误的时间。
        final defaultSections = TimetableSettings.defaults().sections;
        expect(s.sections.length, 3);
        expect(s.sections[0].startTime, '08:00');
        expect(s.sections[0].endTime, '08:45');
        expect(s.sections[1].startTime, defaultSections[1].startTime);
        expect(s.sections[2].startTime, defaultSections[2].startTime);

        // 主题列表不是位置表，仍按「跳过坏条目」处理。
        expect(s.semesterWeekCount, 24);
        expect(s.themeSeedColor, '#FF0000');
        expect(s.savedThemes.length, 1);
        expect(s.savedThemes.first.id, 't1');
      },
    );
    test('wrong optional list containers default safely', () {
      final settings = TimetableSettings.fromJson({'sections': 'not-a-list'});
      expect(settings.sections, isNotEmpty);
    });

    test(
      'bad nested glass tuning drops only that field, not whole settings',
      () {
        // 回归钉（CODE_REVIEW 2026-10-01 A6）：这三处曾是
        // `json[key] as Map<String, dynamic>` 硬转且外层没有 try，一个类型不对的
        // 嵌套值会冒到 TimetableProfile.fromJsonLenient 的 catch，把整份设置换成
        // defaults（学期起始日、节次表、主题、超级岛开关一起清零），再经
        // AppGlobalSettingsService.syncFrom 扩散成设备级全局键。
        final s = TimetableSettings.fromJson({
          'liquidGlassTuning': 'not-a-map',
          'liquidGlassTuningDark': [1, 2, 3],
          'courseCardGlassTuning': 7,
          'semesterWeekCount': 22,
          'themeSeedColor': '#123456',
          'sections': [
            {'startTime': '08:00', 'endTime': '08:45'},
            {'startTime': '08:55', 'endTime': '09:40'},
          ],
        });

        expect(s.liquidGlassTuning, isNull);
        expect(s.liquidGlassTuningDark, isNull);
        expect(s.courseCardGlassTuning, isNull);
        // 其余字段必须原样保留，而不是被 defaults 覆盖。
        expect(s.semesterWeekCount, 22);
        expect(s.themeSeedColor, '#123456');
        expect(s.sections.length, 2);
        expect(s.sections[1].startTime, '08:55');
      },
    );

    test(
      'TimetableSettings falls back to defaults when all sections malformed',
      () {
        final s = TimetableSettings.fromJson({
          'sections': [
            {'startTime': '', 'endTime': ''},
          ],
        });
        expect(s.sections.length, TimetableSettings.defaults().sections.length);
      },
    );
  });

  group('D8 WarehouseMacro robust parsing', () {
    test('WarehouseMacroRecord skips malformed steps, keeps valid', () {
      final rec = WarehouseMacroRecord.fromJson({
        'schoolId': 'a',
        'adapterId': 'b',
        'schoolName': 's',
        'adapterName': 'ad',
        'importUrl': 'https://example.com',
        'schoolResourceFolder': 'f',
        'adapterAssetJsPath': 'x.js',
        'steps': [
          {'type': 'navigate', 'value': 'https://example.com'},
          'bad-step',
          {'type': 'click', 'selector': '#a'},
          123,
        ],
        'dialogResponses': {'k': 'v'},
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      });
      expect(rec.steps.length, 2);
      expect(
        rec.steps.map((e) => e.type),
        containsAll([MacroStepType.navigate, MacroStepType.click]),
      );
    });
    test('WarehouseMacroRecord steps container tolerates non-list', () {
      final rec = WarehouseMacroRecord.fromJson({
        'schoolId': '',
        'adapterId': '',
        'schoolName': '',
        'adapterName': '',
        'importUrl': '',
        'schoolResourceFolder': '',
        'adapterAssetJsPath': '',
        'steps': 7,
        'dialogResponses': {},
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      });
      expect(rec.steps, isEmpty);
    });

    test('WarehouseMacroRecord dialogResponses tolerates non-map', () {
      final rec = WarehouseMacroRecord.fromJson({
        'schoolId': '',
        'adapterId': '',
        'schoolName': '',
        'adapterName': '',
        'importUrl': '',
        'schoolResourceFolder': '',
        'adapterAssetJsPath': '',
        'steps': [],
        'dialogResponses': 'not-a-map',
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      });
      expect(rec.dialogResponses, isEmpty);
      expect(rec.steps, isEmpty);
    });
  });
}
