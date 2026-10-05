import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/holiday_resolver.dart';

/// 回归钉（2026-10-05 审查第 17 轮）：假期分组必须先排序。
///
/// `holiday_service` 的两处转换器都在原顺序上判断相邻（`_isConsecutive(current.last, date)`），
/// 而远程接口不保证升序返回。乱序时一段七天假会被切成好几组：banner 名取错组、
/// `groupId` 被分散，后面"调休上班挂到最近的一组"按 group.first/last 算距离也跟着错。
void main() {
  DateTime day(int month, int day) => DateTime(2026, month, day);

  group('groupConsecutiveHolidayDates', () {
    test('乱序输入照样合成一段连续假期', () {
      final shuffled = [
        day(10, 5),
        day(10, 1),
        day(10, 3),
        day(10, 2),
        day(10, 4),
      ];
      final groups = groupConsecutiveHolidayDates(shuffled);

      // 旧实现在这里会切出 2-3 组（10-05 之后回不去 10-01）。
      expect(groups, hasLength(1));
      expect(groups.single, [
        day(10, 1),
        day(10, 2),
        day(10, 3),
        day(10, 4),
        day(10, 5),
      ]);
    });

    test('真正的断点才分组：中间缺一天就是两段', () {
      final groups = groupConsecutiveHolidayDates([
        day(10, 1),
        day(10, 2),
        day(10, 4),
        day(10, 5),
      ]);
      expect(groups, hasLength(2));
      expect(groups[0], [day(10, 1), day(10, 2)]);
      expect(groups[1], [day(10, 4), day(10, 5)]);
    });

    test('跨年也要连成一段（元旦 2026-12-30..2027-01-02）', () {
      final groups = groupConsecutiveHolidayDates([
        DateTime(2026, 12, 30),
        DateTime(2027, 1, 2),
        DateTime(2026, 12, 31),
        DateTime(2027),
      ]);
      expect(groups, hasLength(1));
      expect(groups.first.first, DateTime(2026, 12, 30));
      expect(groups.first.last, DateTime(2027, 1, 2));
    });

    test('重复日期不产生额外分组，也不把同一天塞两次', () {
      final groups = groupConsecutiveHolidayDates([
        day(5, 1),
        day(5, 1),
        day(5, 2),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single, [day(5, 1), day(5, 2)]);
    });

    test('空输入返回空列表，单日期返回一段', () {
      expect(groupConsecutiveHolidayDates([]), isEmpty);
      expect(groupConsecutiveHolidayDates([day(3, 3)]), [
        [day(3, 3)],
      ]);
    });

    test('带时间分量的输入按日期比较（不因秒级差异断成两段）', () {
      final groups = groupConsecutiveHolidayDates([
        DateTime(2026, 10, 1, 8, 30),
        DateTime(2026, 10, 2, 3, 10),
        DateTime(2026, 10, 3, 23, 59),
      ]);
      expect(groups, hasLength(1));
    });

    test('分组结果内部升序，且各组区间互不重叠（覆盖原"最近一组"距离计算的前提）', () {
      final groups = groupConsecutiveHolidayDates([
        day(10, 8),
        day(10, 1),
        day(10, 2),
        day(10, 7),
      ]);
      expect(groups, hasLength(2));
      for (final group in groups) {
        for (var i = 1; i < group.length; i++) {
          expect(group[i].isAfter(group[i - 1]), isTrue);
        }
      }
      expect(groups[1].first.isAfter(groups[0].last), isTrue);
    });
  });
}
