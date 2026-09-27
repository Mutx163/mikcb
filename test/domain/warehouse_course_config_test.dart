import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_course_import_logic.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  group('saveCourseConfig 落地到 TimetableSettings', () {
    // copyWith 对 null 取「保持原值」。若这点不成立，脚本没下发开学日期的
    // 每次导入都会把用户手填的开学日期清掉 —— 必须钉住。
    test('脚本两项都下发 → 两者都写入', () {
      final base = TimetableSettings.defaults();
      final next = base.copyWith(
        semesterWeekCount: 20,
        semesterStartDate: warehouseSemesterStartDate('2026-09-07'),
      );
      expect(next.semesterWeekCount, 20);
      expect(next.semesterStartDate, DateTime(2026, 9, 7));
    });

    test('脚本只下发总周数 → 开学日期保持原值，不被清空', () {
      final base = TimetableSettings.defaults().copyWith(
        semesterStartDate: DateTime(2026, 3, 2),
        semesterWeekCount: 16,
      );
      final next = base.copyWith(semesterWeekCount: 20);
      expect(next.semesterStartDate, DateTime(2026, 3, 2));
      expect(next.semesterWeekCount, 20);
    });

    test('脚本只下发开学日期 → 总周数保持原值', () {
      final base = TimetableSettings.defaults().copyWith(
        semesterWeekCount: 18,
      );
      final next = base.copyWith(
        semesterStartDate: warehouseSemesterStartDate('2026-09-07'),
      );
      expect(next.semesterWeekCount, 18);
      expect(next.semesterStartDate, DateTime(2026, 9, 7));
    });

    test('脚本日期非法 → 传 null，保持原值而不是写入今天', () {
      final base = TimetableSettings.defaults().copyWith(
        semesterStartDate: DateTime(2026, 3, 2),
      );
      final next = base.copyWith(
        semesterStartDate: warehouseSemesterStartDate('garbage'),
      );
      expect(next.semesterStartDate, DateTime(2026, 3, 2));
    });

    test('总周数为 0 或负数视为未下发，不写入', () {
      final base = TimetableSettings.defaults().copyWith(
        semesterWeekCount: 16,
      );
      final hasWeekCount = (0 as num?)?.toInt();
      final next = base.copyWith(
        semesterWeekCount: (hasWeekCount != null && hasWeekCount > 0)
            ? hasWeekCount
            : null,
      );
      expect(next.semesterWeekCount, 16);
    });

    test('开学日期持久化后能原样读回（周次计算的输入）', () {
      final base = TimetableSettings.defaults();
      final withDate = base.copyWith(
        semesterStartDate: warehouseSemesterStartDate('2026-09-07T00:00:00Z'),
      );
      final restored = TimetableSettings.fromJson(withDate.toJson());
      expect(
        restored.semesterStartDate,
        DateTime(2026, 9, 7),
      );
    });
  });
}
