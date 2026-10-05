import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/clock_order.dart';

/// 回归钉（2026-10-05 审查第 17 轮）：时间要按钟表分钟数排，不按字符串序。
///
/// `Course.fromJson` / `ScheduleItem.fromJson` 是 `json['startTime'] as String`
/// 原样收下的，外来备份 / 局域网传输包里的 `"9:00"`（没补零）会直接进库；
/// 而排序用的是 `String.compareTo`，于是 `"10:00" < "9:00"` —— 课程顺序整个错位。
void main() {
  group('compareClockText', () {
    test('9:00 排在 10:00 之前，不受没补零的字典序影响', () {
      expect(compareClockText('9:00', '10:00'), lessThan(0));
      expect(compareClockText('10:00', '9:00'), greaterThan(0));
      // 旧口径（String.compareTo）在这里判反：'10:00' < '9:00'，
      // 于是 9 点的课被排到 10 点之后 —— 这条用例钉住的就是这个错位。
      expect('10:00'.compareTo('9:00') < 0, isTrue);
    });

    test('同一时刻的补零与非补零形式视为相等', () {
      expect(compareClockText('08:30', '8:30'), 0);
      expect(compareClockText('8:05', '08:05'), 0);
      expect(compareClockText(' 9:00 ', '09:00'), 0);
    });

    test('分钟数决定顺序，跨小时与小时内都一致', () {
      expect(compareClockText('09:50', '10:00'), lessThan(0));
      expect(compareClockText('09:10', '09:05'), greaterThan(0));
      expect(compareClockText('00:00', '23:59'), lessThan(0));
    });

    test('24:00 排在 23:59 之后、00:00 之前是有序的（末节课口径）', () {
      expect(compareClockText('23:59', '24:00'), lessThan(0));
      // 与作息表同一口径：24:00 表示"当天结束"，是合法可比的值。
      expect(compareClockText('24:00', '24:00'), 0);
    });

    test('解析不出来的值排在能解析的值之后，且互比时退回字典序', () {
      expect(compareClockText('08:00', '上午8点'), lessThan(0));
      expect(compareClockText('上午8点', '08:00'), greaterThan(0));
      expect(compareClockText('坏值A', '坏值B'), lessThan(0));
      // 关键是不许抛：一条坏数据不能把整份列表的排序打断。
      expect(() => compareClockText('', '08:00'), returnsNormally);
      expect(compareClockText('', '08:00'), greaterThan(0));
    });

    test('用它排序能把混合格式的课表按真实先后排好', () {
      final times = ['10:00', '9:00', '08:30', '8:45', '14:00']
        ..sort(compareClockText);
      expect(
        times,
        ['08:30', '8:45', '9:00', '10:00', '14:00'],
      );
    });
  });
}
