import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/screens/add_exam_screen.dart';
import 'package:university_timetable/services/storage_service.dart';

import '../helpers_test_app.dart';

/// 回归：添加考试页键盘未收起时点「考试日期」，周次选择弹层被
/// viewInsets 挤压后整列溢出（黑匣子记录 RenderFlex overflowed 106px）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('键盘弹起时打开考试日期周次弹层不溢出', (tester) async {
    // 412x800 逻辑分辨率 + 底部 320 逻辑像素的模拟输入法。
    tester.view.physicalSize = const Size(412, 800);
    // dpr 显式钉 1.0：默认 3.0 会把 412x800 物理像素缩成 137 逻辑宽。
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    final provider = await createInitializedTestProvider(tester);
    final now = DateTime.now();
    await runRealAsync(tester, () async {
      await provider.updateSettings(
        provider.settings.copyWith(
          semesterStartDate: DateTime(now.year, now.month),
          semesterWeekCount: 18,
        ),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: AddExamScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('考试日期'));
    await tester.pumpAndSettle();

    // 弹层确实打开（周次网格 + 顶部日历入口），且首帧起无溢出异常。
    expect(find.text('使用日历选择'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
