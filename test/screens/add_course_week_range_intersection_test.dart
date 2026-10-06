import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/add_course_screen.dart';

/// 「按范围选周」叠上单/双周算出空集时不许保存（第 33 轮）。
///
/// 缺陷链条：`add_course_screen.dart` 原先有两份同样的过滤循环
/// （摘要用 `_buildEntryWeeksFromRange`、弹层用局部的 `buildTempWeeksFromRange`），
/// 而确定按钮无条件 `Navigator.pop(context, true)`，保存校验又只挡
/// `weekSelectionMode == custom && selectedCustomWeeks.isEmpty`。
/// 于是"开始周=结束周=第 2 周 + 勾单周"（或单双周同时勾）会算出**空集**照样保存：
/// 存进去的课对任何一周都 `isInWeek == false`，界面上报"添加成功"，
/// 从此课表上任何一周都看不见它，却仍留在数据里计入统计与伴侣同步。
void main() {
  group('weeksFromRangeSelection', () {
    test('范围只有一周而单双周与之相反时算出空集', () {
      expect(
        weeksFromRangeSelection(
          startWeek: 2,
          endWeek: 2,
          isOddWeek: true,
          isEvenWeek: false,
        ),
        isEmpty,
      );
      expect(
        weeksFromRangeSelection(
          startWeek: 1,
          endWeek: 1,
          isOddWeek: false,
          isEvenWeek: true,
        ),
        isEmpty,
      );
    });

    test('单双周同时勾也是空集', () {
      expect(
        weeksFromRangeSelection(
          startWeek: 1,
          endWeek: 8,
          isOddWeek: true,
          isEvenWeek: true,
        ),
        isEmpty,
      );
    });

    test('正常过滤仍然按周逐个判断', () {
      expect(
        weeksFromRangeSelection(
          startWeek: 1,
          endWeek: 6,
          isOddWeek: true,
          isEvenWeek: false,
        ),
        [1, 3, 5],
      );
      expect(
        weeksFromRangeSelection(
          startWeek: 2,
          endWeek: 6,
          isOddWeek: false,
          isEvenWeek: true,
        ),
        [2, 4, 6],
      );
      expect(
        weeksFromRangeSelection(
          startWeek: 1,
          endWeek: 4,
          isOddWeek: false,
          isEvenWeek: false,
        ),
        [1, 2, 3, 4],
      );
    });

    test('结束周小于开始周时不产出（也不能崩）', () {
      expect(
        weeksFromRangeSelection(
          startWeek: 5,
          endWeek: 3,
          isOddWeek: false,
          isEvenWeek: false,
        ),
        isEmpty,
      );
    });
  });

  test('接线棘：确定按钮与保存校验都要用同一份周次判据', () {
    final source = File(
      'lib/screens/add_course_screen.dart',
    ).readAsStringSync();

    // 过滤循环只许有一份（在 weeksFromRangeSelection 里）。
    final copies = RegExp(r'isOddWeek\s*&&\s*\w+\.isEven').allMatches(source);
    expect(
      copies.length,
      1,
      reason: '范围+单双周的过滤又被人抄了一份：${copies.map((m) => m.group(0)).toList()}',
    );

    expect(
      source,
      contains('onPressed: selectedWeeks.isEmpty'),
      reason: '弹层确定按钮要挡住空集',
    );
    expect(
      source,
      contains('if (_selectedWeeksFor(entry).isEmpty)'),
      reason: '保存校验要覆盖两种模式，不能只挡自定义',
    );
    expect(
      RegExp(
        'entry\\.weekSelectionMode == _WeekSelectionMode\\.custom &&\\s*'
        'entry\\.selectedCustomWeeks\\.isEmpty',
      ).hasMatch(source),
      isFalse,
      reason: '旧的"只挡自定义模式"判据不能留着',
    );
  });
}
