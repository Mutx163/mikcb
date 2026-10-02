import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/course_import_screen.dart';

/// 教务页 → WebView 脚本 → `postMessage` 的节次表解析（回归钉，2026-10-02）。
///
/// 节次在本仓是**按位置下标**使用的（`Course.startSection` 直接索引这张表），所以
/// 「丢掉一条坏记录」= 它之后每一节都指向相邻后一节的时间。读取侧已经用
/// `SectionTime.parseListAligned` 补位修过，这个外部写入入口当时漏了：payload 里
/// 第 3 节为空时，旧解析返回 3 节的表，第 4 节的时间就变成了「第 3 节」，用户会
/// 按错的时间去教室，而界面完全正常。
void main() {
  List<SectionTime>? decode(String payload) =>
      decodeAlignedImportedSections(jsonDecode(payload));

  test('blank middle entry keeps every later section in place', () {
    final sections = decode(
      '[{"startTime":"08:00","endTime":"08:45"},'
      '{"startTime":"09:00","endTime":"09:45"},'
      '{"startTime":"","endTime":""},'
      '{"startTime":"10:00","endTime":"10:45"}]',
    );

    expect(sections, hasLength(4));
    expect(sections![2].startTime, isEmpty);
    expect(sections[3].startTime, '10:00');
    expect(sections[3].endTime, '10:45');
  });

  test('non-map entries are holes, not removals', () {
    final sections = decode('["oops",{"startTime":"08:00","endTime":"08:45"}]');

    expect(sections, hasLength(2));
    expect(sections![0].startTime, isEmpty);
    expect(sections[0].endTime, isEmpty);
    expect(sections[1].startTime, '08:00');
  });

  test('numeric clock fields are holes rather than stringified junk', () {
    // 旧实现用 `toString()` 把 830 变成 "830" 塞进表里，validateSectionTimes
    // 之后会把它算成 0 分 → 整节时间错误。
    final sections = decode(
      '[{"startTime":830,"endTime":915},{"startTime":"09:00","endTime":"09:45"}]',
    );

    expect(sections, hasLength(2));
    expect(sections![0].startTime, isEmpty);
    expect(sections[1].startTime, '09:00');
  });

  test('nothing usable → null (caller shows the localized tip)', () {
    expect(decode('[]'), isNull);
    expect(decode('{"startTime":"08:00"}'), isNull);
    expect(
      decode('[{"startTime":"","endTime":""},{"startTime":830,"endTime":915}]'),
      isNull,
      reason: '每一条都是空位时没有任何可用节次',
    );
  });

  // `SectionTime.fromJson` 只要求「是非空字符串」，所以 "x" 这种垃圾时间会留在
  // 表里 —— 这是有意的：位置保住了，而 validateSectionTimes 会在创建/更新作息时
  // 明确报出是第几节（`section_end_must_after_start|sectionNumber=2`）。
  test('garbage clock text stays in place for the validator to name', () {
    final sections = decode(
      '[{"startTime":"08:00","endTime":"08:45"},{"startTime":"x","endTime":"y"}]',
    );

    expect(sections, hasLength(2));
    expect(sections![1].startTime, 'x');
  });
}
