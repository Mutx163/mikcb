import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/miuix_fling_number_picker.dart';

/// 回归：滚轮猛甩必须带惯性滚过多格（flutter_miuix 1.0.9 上游缺陷是
/// 松手直接弹簧吸附到相邻一格，见 ChuxinNeko/flutter_miuix#2）。
void main() {
  Widget app(
    ValueChanged<int> onChanged, {
    required int value,
    int min = 1,
    int max = 30,
    MiuixFlingNumberPickerController? controller,
  }) {
    return MiuixTheme(
      data: MiuixThemeData.light(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 225,
              width: 200,
              child: MiuixFlingNumberPicker(
                controller: controller,
                value: value,
                min: min,
                max: max,
                onValueChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('猛甩后惯性滚动多格再落定', (tester) async {
    var value = 1;
    await tester.pumpWidget(app((v) => value = v, value: value));

    // 快速上甩：位移仅约 2 格（90px），但初速度很大——旧实现只会走 2 格，
    // 惯性衰减实现应滚出显著更远。
    await tester.fling(
      find.byType(MiuixFlingNumberPicker),
      const Offset(0, -90),
      3000,
    );
    await tester.pumpAndSettle();

    expect(
      value,
      greaterThanOrEqualTo(5),
      reason: '初速度 3000px/s 的甩动必须带惯性滚过多格，实际落在 $value',
    );
    expect(value, lessThanOrEqualTo(30), reason: '非循环模式不得越界');
  });

  testWidgets('快速甩动后立即确认提交最终落点', (tester) async {
    var value = 8;
    final controller = MiuixFlingNumberPickerController();
    await tester.pumpWidget(
      app(
        (v) => value = v,
        value: value,
        max: 13,
        controller: controller,
      ),
    );

    await tester.fling(
      find.byType(MiuixFlingNumberPicker),
      const Offset(0, -90),
      3000,
    );
    // Let the drag-end callback install its projected landing point, but do
    // not wait for the decay/spring animation to finish.
    await tester.pump();

    final confirmedValue = controller.settle();
    expect(confirmedValue, 13);
    expect(value, 13, reason: '确认不应依赖惯性动画完成后的回调');

    await tester.pumpAndSettle();
    expect(value, 13);
  });

  testWidgets('轻推一格正常吸附', (tester) async {
    var value = 10;
    await tester.pumpWidget(app((v) => value = v, value: value));

    // 慢速拖一格高度：应恰好走 1 格。
    await tester.timedDrag(
      find.byType(MiuixFlingNumberPicker),
      const Offset(0, -45),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(value, 11, reason: '慢速拖一格高度应恰好前进 1 格');
  });

  testWidgets('向下猛甩钳在下边界', (tester) async {
    var value = 3;
    await tester.pumpWidget(app((v) => value = v, value: value));

    await tester.fling(
      find.byType(MiuixFlingNumberPicker),
      const Offset(0, 200),
      4000,
    );
    await tester.pumpAndSettle();

    expect(value, 1, reason: '非循环模式下向下猛甩应停在最小值');
  });
}
