import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/import/warehouse/warehouse_course_import_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos_navigation.dart';

import '../helpers_test_app.dart';

/// 回归测试（2026-09-28）：进/出学校页转场时，被盖的学校列表页必须保持
/// 整屏高度、继续绘制 —— 守的就是那条「底下整页黑」的真机黑带。
///
/// 根因：页面 build 包了 `Stack[Positioned.fill(body), 常驻菜单]`，唯一非定位
/// 子级是 0 尺寸的挂载态弹层；转场时 `_HyperosParallaxBleed` 的内层 Stack 把
/// 高度放宽成 min=0，页面按 0 高子级塌成 800×0 → 整页不画 → 露出面窗黑底。
/// 修复：补底内层 `SizedBox` 加 `height: double.infinity`，还原静止时的紧约束。
///
/// ⚠️ harness 陷阱（第一版探针就是栽在这）：被盖页与盖页**必须都是
/// HyperosPageRoute**。MaterialPageRoute.canTransitionTo(HyperosPageRoute) 为
/// false，被盖页 secondaryAnimation 恒 0 —— 视差/补底整条路不触发，塌高
/// 根本不会发生，测了等于没测。下面用 topLeft.x < 0 钉住「这条路确实在跑」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    StorageService().resetForTesting();
  });

  Future<ModalRoute<void>?> pumpSchoolList(WidgetTester tester) async {
    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const TestApp(home: SizedBox(key: ValueKey('probe-home'))),
      ),
    );
    final homeCtx = tester.element(find.byKey(const ValueKey('probe-home')));
    Navigator.of(homeCtx).push<void>(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/probe/warehouse'),
        builder: (_) => const WarehouseCourseImportScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 让 initState 里那几条 Future 走一走（测试 HTTP 是桩/即时失败）。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final listCtx = tester.element(find.byType(WarehouseCourseImportScreen));
    final route = ModalRoute.of(listCtx);
    final rect = tester.getRect(find.byType(WarehouseCourseImportScreen));
    expect(rect.height, greaterThanOrEqualTo(600), reason: '静止时列表页必须整屏');
    expect(route?.secondaryAnimation?.value, 0.0, reason: '静止时 secondary 应为 0');
    return route;
  }

  Future<void> pushCover(WidgetTester tester) async {
    final listCtx = tester.element(find.byType(WarehouseCourseImportScreen));
    Navigator.of(listCtx).push<void>(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/probe/cover'),
        builder: (_) => const Scaffold(
          body: Center(child: Text('COVER', textDirection: TextDirection.ltr)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets('push 覆盖中被盖列表页保持整屏高度（不塌成 0 露黑带）', (tester) async {
    final route = await pumpSchoolList(tester);
    await pushCover(tester);

    expect(
      route?.secondaryAnimation?.status,
      AnimationStatus.forward,
      reason: 'harness 失效：secondary 没动，补底路径没跑到',
    );
    final rect = tester.getRect(find.byType(WarehouseCourseImportScreen));
    expect(rect.height, greaterThanOrEqualTo(600), reason: '转场中被盖页塌成 0 高 = 整页黑带');
    expect(rect.left, lessThan(0), reason: '视差位移应在进行中（也证明补底路径在跑）');
  });

  testWidgets('pop 回落中被盖列表页保持整屏高度', (tester) async {
    final route = await pumpSchoolList(tester);
    await pushCover(tester);

    final listCtx = tester.element(find.byType(WarehouseCourseImportScreen));
    Navigator.of(listCtx).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      route?.secondaryAnimation?.status,
      AnimationStatus.reverse,
      reason: 'harness 失效：pop 时 secondary 应在回退',
    );
    final rect = tester.getRect(find.byType(WarehouseCourseImportScreen));
    expect(rect.height, greaterThanOrEqualTo(600), reason: 'pop 中被盖页塌成 0 高 = 整页黑带');

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('COVER'), findsNothing);
    final settled = tester.getRect(find.byType(WarehouseCourseImportScreen));
    expect(settled.height, greaterThanOrEqualTo(600));
    expect(settled.left, 0, reason: '落定后视差归零');
  });
}

