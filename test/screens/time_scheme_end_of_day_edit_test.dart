import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/time_scheme_management_screen.dart';

/// 回归钉（第 29 轮，`24:00` 结束的那一节改不动开始时间）。
///
/// `_editSectionTime`（time_scheme_management_screen.dart:1186 起）强制连过
/// 「开始 → 结束」两个时间选择器，而：
/// - `showMiuixTimePickerSheet` 的小时上限是 23（`miuix_time_picker_sheet.dart:88`）；
/// - 初始值走 `_parseTimeOfDay`（:1546-1554，`ClockTime.tryParse(value)` 不带
///   `allowEndOfDay`）→ 存量 `24:00` 被兜底成 `00:00`；
/// - 折叠后 `endMinutes(0) <= startMinutes` 撞上 :1212 的「时间段不能跨天」直接 return。
///
/// 于是末节晚自习（快速生成作息就会写成 `24:00`，见
/// `test/models/time_scheme_quick_generate_midnight_test.dart:41-50`）那一行
/// **只想改开始时间也永远保存不了**，还伴随一条误导性的报错；而真去选个新结束时间，
/// `24:00` 再也选不回来。
void main() {
  test('末节 24:00：确认选择器默认的 00:00 视为「没改结束时间」', () {
    expect(
      resolveSectionEndTimeEdit(storedEndTime: '24:00', pickedEndTime: '00:00'),
      '24:00',
      reason: '修复前这里返回 00:00 → 跨天校验拒掉整次编辑',
    );
  });

  test('显式改了结束时间就照常生效', () {
    expect(
      resolveSectionEndTimeEdit(storedEndTime: '24:00', pickedEndTime: '22:30'),
      '22:30',
    );
    expect(
      resolveSectionEndTimeEdit(storedEndTime: '09:40', pickedEndTime: '10:30'),
      '10:30',
    );
  });

  test('普通节次选回 00:00 不做特殊解释（仍交给跨天校验拒掉）', () {
    expect(
      resolveSectionEndTimeEdit(storedEndTime: '09:40', pickedEndTime: '00:00'),
      '00:00',
    );
  });

  test('存量钟点畸形时不猜语义，直接用选择器给的值', () {
    expect(
      resolveSectionEndTimeEdit(storedEndTime: '25:00', pickedEndTime: '00:00'),
      '00:00',
    );
    expect(
      resolveSectionEndTimeEdit(storedEndTime: '', pickedEndTime: '08:00'),
      '08:00',
    );
  });

  test('编辑流程必须走这条折叠，不能再裸用选择器返回值', () {
    final source = File('lib/screens/time_scheme_management_screen.dart')
        .readAsStringSync();
    expect(source, contains('resolveSectionEndTimeEdit('));
    expect(
      source.contains('endTime: _formatTimeOfDay(end)'),
      isFalse,
      reason: '出现裸的 `_formatTimeOfDay(end)` 就意味着 24:00 又会被改写成 00:00',
    );
  });
}
