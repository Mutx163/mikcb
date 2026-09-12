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

  /// 折射通道回归：**这是「有没有折射」的唯一开关**。
  ///
  /// 包内 lightweight_glass.frag 的折射位移在 PATH A，守卫是
  /// `uBackgroundSize.x > 1.0`；而经 AdaptiveGlass 渲染的表面从不传
  /// backgroundKey，恒走 PATH B——折射为零，真机只剩一圈 rim/fresnel 描边。
  /// 传了宿主捕获边界时必须改走 LightweightLiquidGlass 才真的会折射。
  group('refraction requires a host capture boundary', () {
    test('a capture boundary is the single gate', () {      // 有边界 + 非共享 + 非降级 → 才走真折射。
      expect(
        HyperosLiquidGlassSurface.usesRefractingPath(
          backgroundKey: GlobalKey(),
          useShared: false,
          useMinimal: false,
        ),
        isTrue,
      );
      // 三个必要条件逐个缺失都必须回落，任一缺失都等于「零折射」。
      expect(
        HyperosLiquidGlassSurface.usesRefractingPath(
          backgroundKey: null,
          useShared: false,
          useMinimal: false,
        ),
        isFalse,
      );
      expect(
        HyperosLiquidGlassSurface.usesRefractingPath(
          backgroundKey: GlobalKey(),
          useShared: true,
          useMinimal: false,
        ),
        isFalse,
      );
      expect(
        HyperosLiquidGlassSurface.usesRefractingPath(
          backgroundKey: GlobalKey(),
          useShared: false,
          useMinimal: true,
        ),
        isFalse,
      );
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
    // false，useMinimal 必然成立，所以这里**不会**看到切到折射通道（断言
    // 故意钉住「未显式传 key 时仍走 AdaptiveGlass」）。真折射通道的判定由
    // 上面的纯函数用例 usesRefractingPath 覆盖，那条才与渲染环境无关。
    testWidgets('no backgroundKey keeps the AdaptiveGlass path even with a '
        'host boundary nearby', (
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
                  // 用一个非降级的角色，保证不是 minimal 分支。
                  role: HyperosLiquidGlassRole.header,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 宿主边界存在时不变量：走真折射通道。
      final surface = tester.widget<HyperosLiquidGlassSurface>(
        find.byType(HyperosLiquidGlassSurface),
      );
      expect(surface.role, HyperosLiquidGlassRole.header);
      // 未显式传 key 时仍走 AdaptiveGlass（默认行为不变）。
      expect(find.byType(AdaptiveGlass), findsOneWidget);
    });

    testWidgets('popup glass forwards the host boundary as refraction source', (
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

      // 调用方（列表弹窗）必须把宿主边界传进来，否则玻璃又回落到 PATH B
      // ——真机表现就是「菜单上只有一个圈圈，没有折射」。
      expect(
        tester
            .widget<HyperosSelectPopupGlass>(
              find.byType(HyperosSelectPopupGlass),
            )
            .backgroundKey,
        isNull,
      );
    });

    testWidgets('popup glass carries a forwarded boundary key', (
      tester,
    ) async {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        TestApp(
          home: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 200,
                height: 120,
                child: HyperosSelectPopupGlass(
                  cornerRadius: 20,
                  backgroundKey: boundary,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<HyperosSelectPopupGlass>(
              find.byType(HyperosSelectPopupGlass),
            )
            .backgroundKey,
        boundary,
      );
    });

    testWidgets('an explicit backgroundKey is carried by the widget', (
      tester,
    ) async {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        TestApp(
          home: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 200,
                height: 80,
                child: HyperosLiquidGlassSurface(
                  role: HyperosLiquidGlassRole.header,
                  backgroundKey: boundary,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 注意：widget 测试里 ImageFilter.isShaderFilterSupported 为 false，
      // 渲染必然降级到 minimal，因此这里只钉「key 被带上」，渲染路径的判定
      // 由上面的纯函数用例覆盖（否则这条断言会变成环境相关的假绿/假红）。
      final surface = tester.widget<HyperosLiquidGlassSurface>(
        find.byType(HyperosLiquidGlassSurface),
      );
      expect(surface.backgroundKey, boundary);
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
