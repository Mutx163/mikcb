import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';

void main() {
  group('ScheduleDateRule', () {
    test('round-trips through toJson/fromJson', () {
      const original = ScheduleDateRule(
        id: 'rule-1',
        name: '  暑假作息  ',
        timeSchemeId: 'scheme-summer',
        startDate: '2026-07-01',
        endDate: '2026-08-31',
        enabled: false,
      );

      final restored = ScheduleDateRule.fromJson(original.toJson());

      expect(restored.id, 'rule-1');
      // fromJson trims name and date strings.
      expect(restored.name, '暑假作息');
      expect(restored.timeSchemeId, 'scheme-summer');
      expect(restored.startDate, '2026-07-01');
      expect(restored.endDate, '2026-08-31');
      expect(restored.enabled, isFalse);
    });

    test('fromJson fills defaults for missing fields', () {
      final restored = ScheduleDateRule.fromJson(const {
        'id': null,
        'name': null,
        'timeSchemeId': null,
        'startDate': ' 2026-01-01 ',
        'endDate': ' 2026-01-07 ',
      });

      expect(restored.id, '');
      expect(restored.name, '');
      expect(restored.timeSchemeId, '');
      expect(restored.enabled, isTrue);
      expect(restored.startDate, '2026-01-01');
      expect(restored.endDate, '2026-01-07');
    });

    test('json string helpers round-trip', () {
      const original = ScheduleDateRule(
        id: 'rule-2',
        name: '考试周',
        timeSchemeId: 'scheme-exam',
        startDate: '2026-06-10',
        endDate: '2026-06-20',
      );

      final restored = ScheduleDateRule.fromJsonString(original.toJsonString());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.timeSchemeId, original.timeSchemeId);
    });

    test('copyWith overrides selected fields only', () {
      const original = ScheduleDateRule(
        id: 'rule-3',
        name: '原名称',
        timeSchemeId: 'scheme-a',
        startDate: '2026-02-01',
        endDate: '2026-02-28',
      );

      final updated = original.copyWith(
        name: '新名称',
        enabled: false,
        endDate: '2026-03-01',
      );

      expect(updated.id, original.id);
      expect(updated.name, '新名称');
      expect(updated.timeSchemeId, original.timeSchemeId);
      expect(updated.startDate, original.startDate);
      expect(updated.endDate, '2026-03-01');
      expect(updated.enabled, isFalse);
    });
  });
}
