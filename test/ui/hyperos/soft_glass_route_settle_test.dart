import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_surface.dart';

/// 柔光玻璃带 × 路由转场 settle 回归：
///
/// HyperosPageRoute 滑入期间页面被转场 shell（不透明底 + 圆角 saveLayer）
/// 包住，引擎的 backdrop 采样不稳定，彼时建出的滤镜对象被
/// _RenderSoftGlassBackdrop 缓存；settle 后几何/sigma/tuning 均未变，
/// 缓存命中复用坏滤镜 → 外观页预览顶栏停在透明，直到任意一次调参
/// 改动才重建。修复 = 路由动画 completed/dismissed 时清一次缓存。
///
/// 测试用 Fade 转场隔离变量：几何全程不变，动画期每次 paint 都缓存
/// 命中；settle 后 debugFilterBuilds +1 只能来自缓存被主动清空。
void main() {
  final hostFinder = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_SoftGlassBackdropHost',
  );

  Widget band() => const FrostedAppearanceScope(
    appearance: FrostedAppearance(
      sheetBlurSigma: 15,
      sheetTintAlpha: 0.70,
      sheetBarrierAlpha: 0.20,
      glassMode: FrostedGlassMode.softGlass,
    ),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 56,
          child: SoftGlassSurface(child: SizedBox.expand()),
        ),
      ),
    ),
  );

  testWidgets('路由转场 settle 后滤镜缓存被清空重建一次', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            pageBuilder: (_, _, _) => band(),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
    // t=0 时透明度为 0，RenderAnimatedOpacity 直接跳过子树绘制；路由页面
    // 也要到下一帧才挂载，先补一帧空 pump。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(hostFinder, findsOneWidget);
    final buildsMid =
        (tester.renderObject(hostFinder) as dynamic).debugFilterBuilds as int;
    expect(buildsMid, 1, reason: '几何不变 → 动画中只应建过一次滤镜');
    // 动画走完：completed → 状态监听清缓存 → 下一帧重建。
    await tester.pumpAndSettle();
    final buildsSettled =
        (tester.renderObject(hostFinder) as dynamic).debugFilterBuilds as int;
    expect(buildsSettled, buildsMid + 1);
  });

  testWidgets('无转场的静止页面不再额外重建（监听不误伤）', (tester) async {
    await tester.pumpWidget(MaterialApp(home: band()));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      (tester.renderObject(hostFinder) as dynamic).debugFilterBuilds,
      1,
      reason: '首个路由动画本就 completed，不应触发额外失效',
    );
  });
}
