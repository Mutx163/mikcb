import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/time_scheme_management_screen.dart';

/// 回归钉（第 30 轮，末节是 `24:00` 时「添加一节」造出一节 00:10 的幽灵课）。
///
/// `_buildNextSection`（time_scheme_management_screen.dart:1591-1598）用
/// `_parseTimeOfDay(last.endTime)` 推算下一节，而这个解析器不带 `allowEndOfDay`，
/// 于是末节 `24:00`（本仓认可的当天结束，快速生成作息就会写成这样）被兜底成 `00:00`，
/// 追加出来的是 **00:10-00:55** 一节；节次必须递增，这张作息此后保存不了
/// （`validateSectionTimes` 会拒），用户看到的是「我明明只点了一下添加，整个作息改不动了」。
///
/// 原先按钮的禁用条件只有 `_sections.length >= 20`（:1147），完全没有"今天还有没有余地"
/// 这一维。修法是把判断收进 `canAppendSection`，按钮与 `_addSection` 都走它，
/// 没余地时置灰（与"已满 20 节"同一条既有语义）。
void main() {
  SectionTime span(String start, String end) =>
      SectionTime(startTime: start, endTime: end);

  List<SectionTime> dayEndingAt(String endTime) => [
    span('08:00', '08:45'),
    span('09:00', '09:45'),
    span('19:00', endTime),
  ];

  test('末节到当天结束（24:00）时不许再追加', () {
    expect(canAppendSection(dayEndingAt('24:00')), isFalse);
  });

  test('末节还在当天之内时照常可以追加', () {
    expect(canAppendSection(dayEndingAt('23:59')), isTrue);
    expect(canAppendSection(dayEndingAt('21:30')), isTrue);
  });

  test('数量上限仍然生效', () {
    final twenty = List<SectionTime>.generate(
      20,
      (index) => span('08:00', '08:45'),
    );
    expect(canAppendSection(twenty), isFalse);
    expect(canAppendSection(twenty.take(19).toList()), isTrue);
  });

  test('畸形存量值不猜语义：不许追加，否则造出的正是同一节幽灵课', () {
    // 2026-10-08 改判（原断言是 isTrue，"照旧允许追加，交给保存时的校验处理"）。
    // 那个理由与实现矛盾：`_buildNextSection` 用的就是同一个不带 `allowEndOfDay`
    // 的解析器，畸形串照样被兜底成 00:00 → 追加出 00:10-00:55 一节，
    // 与「末节 24:00」那条是**一模一样的幽灵课**；而这张作息本来就已经因为那处
    // 畸形存不下（`validateSectionTimes` 抛 invalid_time_format）。
    // 原来这条断言守的不是「不猜语义」，是把坏行为钉成了期望。
    expect(canAppendSection(dayEndingAt('25:00')), isFalse);
    expect(canAppendSection(dayEndingAt('')), isFalse);
    expect(canAppendSection(dayEndingAt('上午8点')), isFalse);
  });

  test('上限可配（快速生成用的 30 节口径不会与这里分叉）', () {
    final twenty = List<SectionTime>.generate(
      20,
      (index) => span('08:00', '08:45'),
    );
    expect(canAppendSection(twenty, maxSections: 21), isTrue);
  });

  test('按钮与入口都必须走这一份判断', () {
    final source = File('lib/screens/time_scheme_management_screen.dart')
        .readAsStringSync();
    expect(source, contains('canAppendSection(_sections) ? _addSection : null'));
    expect(source, contains('if (!canAppendSection(_sections)) {'));
    expect(
      source.contains('_sections.length >= 20 ? null : _addSection'),
      isFalse,
      reason: '留下一份只数数量的副本，24:00 那条就又会漏掉',
    );
  });
}
