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
    expect(canAppendSection(dayEndingAt('21:30')), isTrue);
    // 2026-10-08 审核改判：末节结束 23:59 原先断言 isTrue（"照常可以追加"），
    // 那与实现矛盾 —— `_buildNextSection` 是「+10 开始 / +45 结束」，需要的是
    // **55 分钟余量**，而不是「当天还没用完」。于是 23:06~23:59 这一段守卫放行、
    // 实际造出 23:16-00:01 这种**结束早于开始**的畸形节次（`_minutesToTime` 用
    // `%1440` 回绕），整张作息从此存不下。这条断言当时守的不是「可以追加」，
    // 是把 bug 背书成了期望 —— 守卫一收窄它就红，看起来像回归。
    // 现在钉的是守卫的真实语义：**够不够再放一整节**。
    expect(canAppendSection(dayEndingAt('23:59')), isFalse);
    expect(canAppendSection(dayEndingAt('23:30')), isFalse);
    expect(canAppendSection(dayEndingAt('23:06')), isFalse);
    expect(canAppendSection(dayEndingAt('22:00')), isTrue, reason: '还剩 2 小时余量');
    expect(canAppendSection(dayEndingAt('23:05')), isTrue, reason: '正好剩 55 分钟');
  });

  test('守卫的判据与 _buildNextSection 的实际跨度同源（跨不过午夜就置灰）', () {
    // 独立复算一遍：守卫说能追加的那些末节，推算出来的下一节确实不跨天；
    // 守卫说不能的那些，推算出来确实跨天。两条边都要钉，否则改一边另一边
    // 不会红 —— 而这正是同一个提交里导入侧与界面侧分叉的原因。
    SectionTime span(String start, String end) =>
        SectionTime(startTime: start, endTime: end);

    int minutesOf(String hhmm) {
      final parts = hhmm.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    // 与 _buildNextSection 同款：start = lastEnd + 10，end = start + 45。
    final candidates = <String>['21:30', '22:00', '23:05', '23:06', '23:30', '23:59'];
    for (final end in candidates) {
      final sections = [
        span('08:00', '08:45'),
        span('09:00', '09:45'),
        span('19:00', end),
      ];
      final start = minutesOf(end) + 10;
      final finish = start + 45;
      final crossesMidnight = finish > 24 * 60;
      expect(
        canAppendSection(sections),
        isNot(crossesMidnight),
        reason: '末节 $end → 下一节 $start~$finish，'
            '跨午夜=$crossesMidnight，守卫必须与它一致',
      );
    }
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
