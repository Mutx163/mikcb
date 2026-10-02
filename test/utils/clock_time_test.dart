import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/clock_time.dart';

/// 回归钉（CODE_REVIEW 2026-10-02）：`SectionTime.fromJson` 只要求"非空字符串"，
/// `"08.30"`、`"8"`、`"上午8点"` 都能进库；而作息管理页与快速生成抽屉的时间解析是
/// 裸 `int.parse(parts[0])`，一遇到这些值就抛 FormatException/RangeError，被 async
/// 吞掉后表现为「点某一节的时间没反应」。ClockTime.tryParse 是统一口径。
void main() {
  group('ClockTime.tryParse', () {
    test('接受规范的 HH:MM 与宽松空白', () {
      final parsed = ClockTime.tryParse(' 08:05 ');
      expect(parsed, isNotNull);
      expect(parsed!.hour, 8);
      expect(parsed.minute, 5);
      expect(parsed.totalMinutes, 485);
      expect(parsed.formatted, '08:05');
    });

    test('拒绝会打爆裸 int.parse 的形态而不是抛错', () {
      for (final bad in [
        '',
        '   ',
        '08.30',
        '8',
        '上午8点',
        '08:05:00',
        '08:',
        ':05',
        'ab:cd',
      ]) {
        expect(ClockTime.tryParse(bad), isNull, reason: 'input=[$bad]');
      }
      expect(ClockTime.tryParse(null), isNull);
    });

    test('拒绝越界的时分', () {
      expect(ClockTime.tryParse('24:00'), isNull);
      expect(ClockTime.tryParse('23:60'), isNull);
      expect(ClockTime.tryParse('-1:00'), isNull);
      expect(ClockTime.tryParse('23:59'), isNotNull);
      expect(ClockTime.tryParse('0:0'), isNotNull);
    });
  });
}
