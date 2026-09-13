import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_tokens.dart';

import '../../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('liquid glass settings are unified', () {
    for (final brightness in Brightness.values) {
      test('sheet/nested/course use the same settings for $brightness', () {
        final sheet = MikcbLiquidGlassTokens.sheetSettingsFor(brightness);
        final nested = MikcbLiquidGlassTokens.nestedTileSettingsFor(brightness);
        final course = MikcbLiquidGlassTokens.courseCardSettingsFor(brightness);

        expect(nested, sheet);
        expect(course, sheet);
      });
    }

    test('tuning role methods do not scale sheet settings', () {
      const tuning = LiquidGlassTuning(thickness: 18, blur: 8, tintAlpha: 0.25);
      const brightness = Brightness.light;
      final sheet = tuning.toSheetSettings(brightness: brightness);

      expect(tuning.toNestedTileSettings(brightness: brightness), sheet);
      expect(tuning.toCourseCardSettings(brightness: brightness), sheet);
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

      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
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

      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
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

      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
      expect(find.text('Option A'), findsOneWidget);
    });
  });

  /// 液态玻璃只有一条渲染路径：AdaptiveGlass + premium（实时读底面）。
  ///
  /// 回归锁：曾经这里有一条「抓拍纹理真折射通道」——有宿主捕获边界时绕开
  /// AdaptiveGlass 直连 LightweightLiquidGlass 传 backgroundKey，让 standard
  /// 档也能折射。那条路有两个致命后果：①玻璃里是一张静态照片（ticker 只在
  /// 几何变化时重拍、稳定后停摆）；②只有部分表面走它，于是同一个材质出现
  /// 「顶栏一种观感、弹窗另一种观感」。两者都已删除，用一个常量钉住。
  group('liquid glass has exactly one render path', () {
    test('the material has a single quality constant', () {
      // 一个材质一个档：任何调用点都不得再传自己的档位。
      expect(MikcbLiquidGlassTokens.defaultQuality, GlassQuality.premium);
    });

    testWidgets('no backgroundKey keeps the AdaptiveGlass path', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 80,
              child: HyperosLiquidGlassSurface(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdaptiveGlass), findsOneWidget);
      expect(find.byType(LightweightLiquidGlass), findsNothing);
    });

    // 名字写实：widget 测试环境里 ImageFilter.isShaderFilterSupported 恒为
    // false，useMinimal 必然成立，所以真机上那条 premium 实时通道在测试里
    // 只会渲染 minimal——但**渲染路径**仍然是同一条 AdaptiveGlass，绝不再
    // 因为「旁边有没有宿主捕获边界」而分流。
    testWidgets('a nearby host boundary never diverts the render path', (
      tester,
    ) async {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        TestApp(
          home: Center(
            child: RepaintBoundary(
              key: boundary,
              child: const SizedBox(
                width: 200,
                height: 80,
                child: HyperosLiquidGlassSurface(
                  role: HyperosLiquidGlassRole.header,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdaptiveGlass), findsOneWidget);
      // 抓拍纹理通道的入口（LightweightLiquidGlass + backgroundKey）已从
      // 组件上删除，任何宿主边界都分流不了渲染路径。
      expect(find.byType(LightweightLiquidGlass), findsNothing);
    });

    testWidgets('popup glass renders through the same AdaptiveGlass path', (
      tester,
    ) async {
      // 弹窗与顶栏带、玻璃坞、卡片同一条路（同一组件、同一档位常量），
      // 不再有「弹窗 premium / 顶栏 standard」这种按表面分档的观感分叉。
      await tester.pumpWidget(
        const TestApp(
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance(
              sheetBlurSigma: 15,
              sheetTintAlpha: 0.7,
              sheetBarrierAlpha: 0.2,
              glassMode: FrostedGlassMode.liquidGlass,
            ),
            child: Center(
              child: SizedBox(
                width: 200,
                height: 120,
                child: HyperosSelectPopupGlass(
                  cornerRadius: 20,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdaptiveGlass), findsOneWidget);
      expect(find.byType(LightweightLiquidGlass), findsNothing);
    });
  });

  group('modal liquid glass sampling', () {
    test('all modal roles resolve identical liquid settings', () {
      for (final brightness in Brightness.values) {
        final header = HyperosLiquidGlassSurface.settingsForRole(
          role: HyperosLiquidGlassRole.header,
          brightness: brightness,
        );
        final modal = HyperosLiquidGlassSurface.settingsForRole(
          role: HyperosLiquidGlassRole.modal,
          brightness: brightness,
        );

        expect(modal, header);
      }
    });

    testWidgets('showHyperosSheet mounts no redundant undimmed capture', (
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
      // 树内没有 BackdropFilter.grouped 成员加入外层组，挂
      // UndimmedBackdropCapture 只会白做一次全屏近零模糊采样。
      expect(find.byType(UndimmedBackdropCapture), findsNothing);
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
      // 同 showHyperosSheet：树内无 grouped 过滤器，垫层无消费者。
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
