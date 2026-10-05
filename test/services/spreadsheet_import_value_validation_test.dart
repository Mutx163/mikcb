import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/spreadsheet_import_service.dart';
import 'package:university_timetable/utils/clock_time.dart';
import 'package:university_timetable/utils/hex_color.dart';

/// 回归钉（第二十二轮，表格导入的「颜色」「时间」两列不做校验）：
///
/// 同一个 `_buildCourse` 里，周次（:446-497）、整数（:696）、单双周（:505）都
/// 有校验并回落，唯独这两列直接原样入库：
/// * `_normalizeColor`（:641-655）注释承诺 `#RGB`、`#RRGGBB` 或 `#AARRGGBB`，
///   正则 `^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?([0-9a-fA-F]{2})?$` 实际放行
///   **3/5/6/8 位**（5 位不在任何承诺里；8 位按分组顺序是 `#RRGGBBAA`，与注释
///   的 `#AARRGGBB` 相反）。而全仓着色一律走 `tryParseHexColor`
///   （utils/hex_color.dart:9-11 只认 6 位），`test/utils/hex_color_test.dart:32,52`
///   更把 `#12345`、`#FFF` 断言为 null。导入放行的码渲染侧一律解不出来。
/// * `_normalizeTimeOrDefault`（:633-639）只处理 `''/无/-`，其余原样返回。
///   `domain/clock_order.dart:5-9` 自述"模型边界不保证是补零 HH:mm"，
///   `test/services/statistics_time_utilization_clock_test.dart:13-15` 亲口点名
///   这条入口是真的。xlsx 侧更宽：Excel 的时间格是数值，`_cellToString`(:732-740)
///   会把它烤成 `0.3333333333333333` 或 `12月30日` 这类串。
///
/// 后果：颜色列填 `#F00` → 零警告、原样写进 `Course.color`、卡片一律默认蓝，
/// 反复重导都无效且无从查因；时间列填畸形串 → 该课被统计「时间利用」静默剔除、
/// 在「即将到来」与日视图里排到末尾，同样零警告。
void main() {
  final service = SpreadsheetImportService();
  final settings = TimetableSettings.defaults();

  Course onlyRow(String csv) {
    final result = service.parseBytes(
      utf8.encode(csv),
      fileName: 'courses.csv',
      settings: settings,
    );
    expect(result.courses, hasLength(1), reason: result.warnings.toString());
    return result.courses.single;
  }

  String csvWith(List<String> cells) =>
      '课程名,星期,开始节,结束节,上课周,开始时间,结束时间,颜色\n'
      '高等数学,1,1,2,1-16,${cells.join(',')}\n';

  group('导入放行的颜色必须渲染得出来', () {
    test('三位缩写展开成六位，卡片能显示红色而不是默认蓝', () {
      final course = onlyRow(csvWith(['08:00', '09:40', '#F00']));

      expect(tryParseHexColor(course.color), isNotNull);
      expect(course.color.toUpperCase(), '#FF0000');
    });

    test('六位颜色原样保留', () {
      final course = onlyRow(csvWith(['08:00', '09:40', '#2196F3']));

      expect(course.color, '#2196F3');
      expect(tryParseHexColor(course.color), isNotNull);
    });

    test('五位与八位这类渲染侧解不出的长度，一律回落默认色', () {
      for (final raw in ['#12345', '#2196F3FF', '2196F3FF', '#GGGGGG']) {
        final course = onlyRow(csvWith(['08:00', '09:40', raw]));

        expect(
          tryParseHexColor(course.color),
          isNotNull,
          reason: '$raw 被导入放行后必须能被 tryParseHexColor 解析',
        );
        expect(course.color, '#2196F3', reason: '$raw 不是可用颜色，应回落默认');
      }
    });

    test('不变式：导入接受的每个 hex，渲染侧都能解析且往返相等', () {
      for (final raw in [
        '',
        '无',
        '-',
        'FFF',
        '#FFF',
        '#abcdef',
        'ABCDEF',
        '#12345',
        '#RRGGBB',
        '#2196F3FF',
        '##FF0000',
        '  #F00  ',
      ]) {
        final course = onlyRow(csvWith(['08:00', '09:40', raw]));
        final parsed = tryParseHexColor(course.color);

        expect(parsed, isNotNull, reason: '导入放行了解析不出的颜色：$raw');
        expect(
          course.color,
          isNot(contains('##')),
          reason: '畸形输入不能拼出更畸形的存储值：$raw',
        );
      }
    });
  });

  group('导入放行的钟点必须读得出来', () {
    test('Excel 数值格烤成的串不能直接入库', () {
      final course = onlyRow(
        csvWith(['0.3333333333333333', '12月30日', '#2196F3']),
      );

      expect(
        ClockTime.tryParse(course.startTime, allowEndOfDay: true),
        isNotNull,
        reason: '开始时间入库后必须读得出来，否则统计与排序静默丢课',
      );
      expect(
        ClockTime.tryParse(course.endTime, allowEndOfDay: true),
        isNotNull,
      );
      // 回落的是节次对应的时间（settings.sections[0] 起、[1] 止）。
      expect(course.startTime, settings.sections[0].startTime);
      expect(course.endTime, settings.sections[1].endTime);
    });

    test('未补零的合法钟点归一成 HH:mm', () {
      final course = onlyRow(csvWith(['8:00', '9:40', '#2196F3']));

      expect(course.startTime, '08:00');
      expect(course.endTime, '09:40');
    });

    test('晚自习写 24:00 按当天结束保留', () {
      final course = onlyRow(csvWith(['22:00', '24:00', '#2196F3']));

      expect(course.startTime, '22:00');
      expect(course.endTime, '24:00');
    });

    test('不变式：导入产出的每个钟点都满足 parse→formatted 往返', () {
      for (final pair in [
        ['08:00', '09:40'],
        ['8:00', '9:40'],
        ['', ''],
        ['无', '-'],
        ['25:00', '26:00'],
        ['8:00 到 9:40', '上午'],
        ['09:60', '08:00'],
      ]) {
        final course = onlyRow(csvWith([pair[0], pair[1], '#2196F3']));

        for (final value in [course.startTime, course.endTime]) {
          final parsed = ClockTime.tryParse(value, allowEndOfDay: true);
          expect(parsed, isNotNull, reason: '入库了读不出的钟点：$value');
          expect(
            value,
            parsed!.formatted,
            reason: '入库的钟点没有归一成 HH:mm：$value',
          );
        }
      }
    });
  });
}
