// 弹窗遮罩色：系统降级与否决定用哪一档黑纱。
//
// 2026-09-30 高斯模糊全局档退场之前，这里有两档材质各测一次（高斯走配置里的
// `sheetBarrierAlpha`、液态走固定的轻纱）。液态成为唯一玻璃材质后判据只剩
// 「系统有没有降级」这一条 —— 高斯那一档连同它的分支一起没了。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_blurred_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HyperosBlurredHeader.modalBarrierColor', () {
    Future<Color> barrierOf(
      WidgetTester tester, {
      double sheetBarrierAlpha = 0.20,
      bool degraded = false,
    }) async {
      late Color barrier;
      Widget app = FrostedAppearanceScope(
        appearance: FrostedAppearance(
          sheetBlurSigma: 15,
          sheetTintAlpha: 0.70,
          sheetBarrierAlpha: sheetBarrierAlpha,
        ),
        child: Builder(
          builder: (context) {
            barrier = HyperosBlurredHeader.modalBarrierColor(context);
            return const SizedBox.shrink();
          },
        ),
      );
      if (degraded) {
        app = MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: app),
        );
      } else {
        app = MaterialApp(home: app);
      }
      await tester.pumpWidget(app);
      return barrier;
    }

    testWidgets('正常态：液态玻璃用那层固定的轻纱，不吃配置值', (tester) async {
      final barrier = await barrierOf(
        tester,
        // 即便配置里的遮罩很深，液态也保持柔和。
        sheetBarrierAlpha: 0.45,
      );
      expect(
        barrier,
        Colors.black.withValues(
          alpha: HyperosBlurredHeader.liquidGlassModalBarrierAlpha,
        ),
      );
      expect(barrier.a, lessThan(0.20));
      expect(barrier.a, greaterThan(0.0));
    });

    testWidgets('系统降级：改用配置的 sheetBarrierAlpha（面板已不透明，需要层次）', (
      tester,
    ) async {
      final barrier = await barrierOf(tester, degraded: true);
      expect(barrier, Colors.black.withValues(alpha: 0.20));
    });
  });
}
