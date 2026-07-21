import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/providers/timetable/schedule_date_rule_logic.dart';

void main() {
  group('ScheduleDateRuleLogic', () {
    test('parseIsoDate rejects invalid calendar days', () {
      expect(ScheduleDateRuleLogic.parseIsoDate('2026-02-31'), isNull);
      expect(ScheduleDateRuleLogic.parseIsoDate('2026-13-01'), isNull);
      expect(ScheduleDateRuleLogic.parseIsoDate('bad'), isNull);
      expect(
        ScheduleDateRuleLogic.parseIsoDate('2026-07-21'),
        DateTime(2026, 7, 21),
      );
    });

    test('match returns rule for inclusive date range', () {
      final rule = ScheduleDateRule(
        id: 'summer',
        name: '夏令时',
        timeSchemeId: 'scheme-summer',
        startDate: '2026-05-01',
        endDate: '2026-09-30',
      );

      expect(
        ScheduleDateRuleLogic.match(DateTime(2026, 5, 1), [rule])?.id,
        'summer',
      );
      expect(
        ScheduleDateRuleLogic.match(DateTime(2026, 9, 30), [rule])?.id,
        'summer',
      );
      expect(
        ScheduleDateRuleLogic.match(DateTime(2026, 4, 30), [rule]),
        isNull,
      );
    });

    test('validateRules rejects overlap and over cap', () {
      final first = ScheduleDateRule(
        id: 'a',
        name: 'A',
        timeSchemeId: 's1',
        startDate: '2026-05-01',
        endDate: '2026-08-31',
      );
      final second = ScheduleDateRule(
        id: 'b',
        name: 'B',
        timeSchemeId: 's2',
        startDate: '2026-08-01',
        endDate: '2026-10-01',
      );
      final third = ScheduleDateRule(
        id: 'c',
        name: 'C',
        timeSchemeId: 's3',
        startDate: '2026-11-01',
        endDate: '2026-12-01',
      );

      expect(
        ScheduleDateRuleLogic.validateRules([first, second]),
        'schedule_date_rule_overlap',
      );
      expect(
        ScheduleDateRuleLogic.validateRules([first, third, second]),
        'schedule_date_rule_max_exceeded',
      );
    });

    test('disabled rules are ignored by match', () {
      final rule = ScheduleDateRule(
        id: 'summer',
        name: '夏令时',
        timeSchemeId: 'scheme-summer',
        startDate: '2026-05-01',
        endDate: '2026-09-30',
        enabled: false,
      );
      expect(ScheduleDateRuleLogic.match(DateTime(2026, 6, 1), [rule]), isNull);
    });
  });
}
