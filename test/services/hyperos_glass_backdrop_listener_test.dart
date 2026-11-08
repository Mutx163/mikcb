import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

/// 玻璃采样捕获节点的**监听器生命周期**回归。
///
/// 2026-11-08 从 `test/ui/hyperos/hyperos_glass_backdrop_host_test.dart` 迁出：
/// `test/ui` 属迁移期冻结区（只许保留、不许增改），而这条断言本身是行为级的
/// 内存泄漏回归，放在允许新增的 `test/services/` 才有地方长大。
/// 测试子类：hasListeners 是 ChangeNotifier 的受保护成员，
/// test/services 会被 dart analyze 扫到，只能在子类里读。
class _ProbeController extends HyperosGlassBackdropController {
  bool get probeHasListeners => hasListeners;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('捕获节点在卸载销毁时必须从 controller 解绑监听器（防止内存泄漏）', (tester) async {
    final controller = _ProbeController();
    addTearDown(controller.dispose);

    expect(controller.probeHasListeners, isFalse);

    await tester.pumpWidget(
      TestApp(
        home: HyperosLayerBackdropCapture(
          controller: controller,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    expect(controller.probeHasListeners, isTrue);

    // 卸载该捕获节点
    await tester.pumpWidget(
      const TestApp(
        home: SizedBox(width: 100, height: 100),
      ),
    );
    await tester.pump();

    expect(
      controller.probeHasListeners,
      isFalse,
      reason: '卸载后应解绑监听器，防止 RenderObject 内存泄漏',
    );
  });
}
