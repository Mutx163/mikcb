import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/domain/schedule_date_rule_logic.dart';

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
      const rule = ScheduleDateRule(
        id: 'summer',
        name: '夏令时',
        timeSchemeId: 'scheme-summer',
        startDate: '2026-05-01',
        endDate: '2026-09-30',
      );

      expect(
        ScheduleDateRuleLogic.match(DateTime(2026, 5), [rule])?.id,
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

    test('enabled single-day rule matches that day', () {
      const rule = ScheduleDateRule(
        id: 'single-day',
        name: '临时作息',
        timeSchemeId: 'scheme-special',
        startDate: '2026-07-23',
        endDate: '2026-07-23',
      );

      final matched = ScheduleDateRuleLogic.match(DateTime(2026, 7, 23), [
        rule,
      ]);

      expect(matched?.id, rule.id);
      expect(matched?.enabled, isTrue);
    });

    test('validateRules rejects overlap and over cap', () {
      const first = ScheduleDateRule(
        id: 'a',
        name: 'A',
        timeSchemeId: 's1',
        startDate: '2026-05-01',
        endDate: '2026-08-31',
      );
      const second = ScheduleDateRule(
        id: 'b',
        name: 'B',
        timeSchemeId: 's2',
        startDate: '2026-08-01',
        endDate: '2026-10-01',
      );
      const third = ScheduleDateRule(
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
      const rule = ScheduleDateRule(
        id: 'summer',
        name: '夏令时',
        timeSchemeId: 'scheme-summer',
        startDate: '2026-05-01',
        endDate: '2026-09-30',
        enabled: false,
      );
      expect(ScheduleDateRuleLogic.match(DateTime(2026, 6), [rule]), isNull);
    });

    test('shouldBulkApply only when signature differs', () {
      const rule = ScheduleDateRule(
        id: 'summer',
        name: '夏令时',
        timeSchemeId: 'scheme-summer',
        startDate: '2026-05-01',
        endDate: '2026-09-30',
      );
      final signature = ScheduleDateRuleLogic.appliedSignature(rule);

      expect(
        ScheduleDateRuleLogic.shouldBulkApply(
          matchedRule: rule,
          lastAppliedSignature: null,
        ),
        isTrue,
      );
      expect(
        ScheduleDateRuleLogic.shouldBulkApply(
          matchedRule: rule,
          lastAppliedSignature: signature,
        ),
        isFalse,
      );
      expect(
        ScheduleDateRuleLogic.shouldBulkApply(
          matchedRule: null,
          lastAppliedSignature: signature,
        ),
        isFalse,
      );

      final winter = rule.copyWith(
        id: 'winter',
        name: '冬令时',
        timeSchemeId: 'scheme-winter',
        startDate: '2026-10-01',
        endDate: '2027-04-30',
      );
      expect(
        ScheduleDateRuleLogic.shouldBulkApply(
          matchedRule: winter,
          lastAppliedSignature: signature,
        ),
        isTrue,
      );
    });

    group('ScheduleDateRuleApplyResult outcomes', () {
      test('notDue is neither didApply nor failedWhileDue', () {
        const result = ScheduleDateRuleApplyResult(
          outcome: ScheduleDateRuleApplyOutcome.notDue,
        );
        expect(result.didApply, isFalse);
        expect(result.failedWhileDue, isFalse);
      });

      test('applied sets didApply only', () {
        const result = ScheduleDateRuleApplyResult(
          outcome: ScheduleDateRuleApplyOutcome.applied,
        );
        expect(result.didApply, isTrue);
        expect(result.failedWhileDue, isFalse);
      });

      test('schemeMissing is failedWhileDue', () {
        const result = ScheduleDateRuleApplyResult(
          outcome: ScheduleDateRuleApplyOutcome.schemeMissing,
        );
        expect(result.didApply, isFalse);
        expect(result.failedWhileDue, isTrue);
      });

      test('sectionOverflow is failedWhileDue and keeps section stats', () {
        const result = ScheduleDateRuleApplyResult(
          outcome: ScheduleDateRuleApplyOutcome.sectionOverflow,
          requiredMaxSection: 10,
          schemeSectionCount: 8,
        );
        expect(result.didApply, isFalse);
        expect(result.failedWhileDue, isTrue);
        expect(result.requiredMaxSection, 10);
        expect(result.schemeSectionCount, 8);
      });
    });
  });
}
