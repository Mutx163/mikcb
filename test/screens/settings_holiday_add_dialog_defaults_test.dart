import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「添加自定义假日」必须带日期初值（第 33 轮）。
///
/// `settings_holiday.dart:566` 原先写成 `onPressed: _showCustomHolidayDialog` ——
/// 一个"全部参数都是可选具名参数"的方法 tear-off 完全符合 `VoidCallback`，
/// 于是 `initialStart` / `initialEnd` 都是 null；弹窗里的日期初值走
/// `initialStart ?? existing?.date`，而新增路径 `existing == null` → 两边都 null。
/// 用户只填名字点"保存"，撞上 `if (startDate == null || endDate == null) return;`
/// （:111-116）—— 静默返回：不关弹层、不提示，紧邻的名字为空分支反而是有 toast 的。
/// 看起来就是"按钮坏了"。
///
/// 这里用文本棘钉住接线：新增入口必须显式给出初值，
/// 因为整页 `testWidgets` + `showHyperosSheet` 在本仓 FakeAsync 下不稳（同 §五十四 的结论）。
void main() {
  test('新增自定义假日的按钮必须预填日期，不得退回方法 tear-off', () {
    final source = File(
      'lib/screens/settings/settings_holiday.dart',
    ).readAsStringSync();

    expect(
      RegExp(r'onPressed:\s*_showCustomHolidayDialog\s*,').hasMatch(source),
      isFalse,
      reason: '裸 tear-off 会把两个日期初值都传成 null，点保存就静默不动',
    );
    expect(
      RegExp(
        r'_showCustomHolidayDialog\(\s*initialStart:\s*DateTime\.now\(\),\s*'
        r'initialEnd:\s*DateTime\.now\(\),',
      ).hasMatch(source),
      isTrue,
      reason: '新增入口要显式预填今天（编辑入口另走 existing.date）',
    );
  });
}
