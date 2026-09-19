import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_shader.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';

import '../../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 全 app 只有一套液态玻璃观感：材质参数只能从 [LiquidGlassTuning.toStyle]
  /// 出，表面只提供自己的几何（圆角）与当前明暗。
  ///
  /// 回归锁：历史上出现过「同一个材质两种观感」——一条自带抓拍纹理的折射
  /// 通道，只有部分表面走它，于是顶栏一种观感、弹窗另一种。那条通道与它
  /// 依赖的第三方包一起删掉了，这里用两条不变量钉住：
  ///   ① 圆角只影响几何，不影响任何材质旋钮；
  ///   ② 全局只有一份表面着色器资产，且加载器是单例。
  group('liquid glass has exactly one material parameter source', () {
    test('圆角只改几何，材质旋钮与它无关', () {
      const tuning = LiquidGlassTuning(
        refraction: 11,
        refractionBand: 9,
        refractionEdgePow: 2.2,
        rimStrength: 0.26,
        rimWidth: 4,
        blurSigma: 22,
        tintAlpha: 0.4,
      );

      final small = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.light,
      );
      final large = tuning.toStyle(
        borderRadius: 28,
        brightness: Brightness.light,
      );

      expect(small.borderRadius, 12);
      expect(large.borderRadius, 28);
      // 除圆角外逐字段一致：表面拿不到自己的折射旋钮。
      expect(small.refraction, large.refraction);
      expect(small.refractionBand, large.refractionBand);
      expect(small.refractionEdgePow, large.refractionEdgePow);
      expect(small.rimStrength, large.rimStrength);
      expect(small.rimWidth, large.rimWidth);
      expect(small.blurSigma, large.blurSigma);
      expect(small.tint, large.tint);
      expect(small.rimColor, large.rimColor);
      expect(small.lightDirection, large.lightDirection);
      expect(small.refraction, tuning.refraction);
      expect(small.blurSigma, tuning.blurSigma);
    });

    test('表面着色器只有一份，且加载器是单例', () {
      final a = LiquidGlassSurfaceShader.instance;
      final b = LiquidGlassSurfaceShader.instance;
      expect(identical(a, b), isTrue, reason: '每次 new 一个加载器会各自持有一份程序');
      expect(
        a.assetKey,
        'shaders/glass_surface_refraction.frag',
        reason: '换资产键等于换材质，必须是同一个文件',
      );
    });
  });

  group('modal appearance scope is preserved across popup routes', () {
    const gaussianAppearance = FrostedAppearance(
      sheetBlurSigma: 15,
      sheetTintAlpha: 0.7,
      sheetBarrierAlpha: 0.2,
      glassMode: FrostedGlassMode.gaussian,
    );

    testWidgets('sheet keeps the caller appearance mode', (tester) async {
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: gaussianAppearance,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHyperosSheet<void>(
                  context: context,
                  builder: (_) => const HyperosSheetFrame(
                    child: SizedBox(width: 180, height: 120),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 弹窗家族自 2026-09-19 起锁成「永远液态玻璃的标准档」：调用方的非液态档
      // 不再改变它们的材质（这里跑在高斯档下，弹窗照样是液态玻璃）。
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
      expect(
        tester.widget<LiquidGlassSurface>(find.byType(LiquidGlassSurface)).role,
        LiquidGlassRole.pinnedChrome,
      );
      expect(find.byType(HyperosSheetFrame), findsOneWidget);
    });

    testWidgets('anchored list popup keeps the caller appearance mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: gaussianAppearance,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHyperosListPopup<String>(
                  context: context,
                  position: const RelativeRect.fromLTRB(24, 24, 200, 500),
                  items: const [
                    HyperosPopupMenuItem(label: 'Option A', value: 'a'),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 弹窗家族自 2026-09-19 起锁成「永远液态玻璃的标准档」：调用方的非液态档
      // 不再改变它们的材质（这里跑在高斯档下，弹窗照样是液态玻璃）。
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
      expect(
        tester.widget<LiquidGlassSurface>(find.byType(LiquidGlassSurface)).role,
        LiquidGlassRole.pinnedChrome,
      );
      expect(find.text('Option A'), findsOneWidget);
    });

    testWidgets('anchored select popup keeps the caller appearance mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: gaussianAppearance,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHyperosSelectPopup<String>(
                  context: context,
                  anchorRect: const Rect.fromLTWH(24, 24, 160, 48),
                  items: const {'Option A': 'a'},
                  currentValue: 'a',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 弹窗家族自 2026-09-19 起锁成「永远液态玻璃的标准档」：调用方的非液态档
      // 不再改变它们的材质（这里跑在高斯档下，弹窗照样是液态玻璃）。
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
      expect(
        tester.widget<LiquidGlassSurface>(find.byType(LiquidGlassSurface)).role,
        LiquidGlassRole.pinnedChrome,
      );
      expect(find.text('Option A'), findsOneWidget);
    });
  });

  group('modal liquid glass sampling', () {
    testWidgets('showHyperosSheet builds an undimmed capture group', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showHyperosSheet<void>(
                    context: context,
                    builder: (sheetContext) {
                      return const SizedBox(
                        width: 240,
                        height: 160,
                        child: Center(child: Text('sheet body')),
                      );
                    },
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropGroup), findsOneWidget);
      // 弹层玻璃走 grouped: true，采样组内首个分组滤镜处缓存的「未压暗页面」。
      // 垫层必须存在，否则玻璃会把弹窗自己的黑色蒙层一起折射进去。
      expect(find.byType(UndimmedBackdropCapture), findsOneWidget);
      expect(find.text('sheet body'), findsOneWidget);
    });

    testWidgets('showHyperosListPopup mounts no redundant undimmed capture', (
      tester,
    ) async {
      final anchorKey = GlobalKey();

      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return GestureDetector(
                key: anchorKey,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  showHyperosListPopup<String>(
                    context: context,
                    position: hyperosPopupPositionBelow(context, anchorKey),
                    items: const [
                      HyperosPopupMenuItem(label: 'Option A', value: 'a'),
                      HyperosPopupMenuItem(label: 'Option B', value: 'b'),
                    ],
                  );
                },
                child: const SizedBox(
                  width: 120,
                  height: 48,
                  child: Center(child: Text('open')),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropGroup), findsOneWidget);
      // 没有二级子项时树内没有 grouped 消费者，垫层只会白做一次全屏近零模糊采样。
      expect(find.byType(UndimmedBackdropCapture), findsNothing);
      expect(find.text('Option A'), findsOneWidget);
    });

    testWidgets('showHyperosSelectPopup builds an undimmed capture group', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showHyperosSelectPopup<String>(
                    context: context,
                    anchorRect: const Rect.fromLTWH(24, 24, 160, 48),
                    items: const {'Option A': 'a'},
                    currentValue: 'a',
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropGroup), findsOneWidget);
      expect(find.byType(UndimmedBackdropCapture), findsOneWidget);
      expect(find.text('Option A'), findsOneWidget);
    });
  });
}
