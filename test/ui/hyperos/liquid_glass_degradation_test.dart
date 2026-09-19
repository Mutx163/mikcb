import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/ui/hyperos/frosted/liquid_glass_degradation.dart';
import 'package:university_timetable/ui/hyperos/hyperos_sheet.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';

import '../../helpers_test_app.dart';

void main() {
  group('LiquidGlassDegradation.shouldDegradeFor', () {
    const base = MediaQueryData();

    test('false by default (no accessibility flags)', () {
      expect(LiquidGlassDegradation.shouldDegradeFor(base), isFalse);
    });

    test('false under accessibleNavigation (MIUI screenshot false positive)', () {
      // MIUI/HyperOS 截图悬浮窗会打开系统 touch exploration，引擎误报
      // accessibleNavigation=true（flutter/flutter#128409），玻璃不随该信号
      // 降级，否则截图预览悬浮窗存在期间全部玻璃回落实体。
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(accessibleNavigation: true),
        ),
        isFalse,
      );
    });

    test('true under disableAnimations (system "remove animations")', () {
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(disableAnimations: true),
        ),
        isTrue,
      );
    });

    test('true under highContrast', () {
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(highContrast: true),
        ),
        isTrue,
      );
    });

    test('true when any flag is set among several', () {
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(accessibleNavigation: false, highContrast: true),
        ),
        isTrue,
      );
    });

    test('false again once all flags clear', () {
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(highContrast: true).copyWith(highContrast: false),
        ),
        isFalse,
      );
    });
  });

  group('platform-view gate is reactive via LiquidGlassDegradationScope', () {
    testWidgets('begin degrades and end restores glass on the next frame', (
      tester,
    ) async {
      // Reset the global gate so this test is order-independent within the file.
      LiquidGlassDegradation.platformViewUnsafeDepthNotifier.value = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassDegradationScope(
            notifier: LiquidGlassDegradation.platformViewUnsafeDepthNotifier,
            child: const _DegradationProbe(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('glass'), findsOneWidget);

      LiquidGlassDegradation.beginPlatformViewUnsafeSurface();
      await tester.pump();
      expect(find.text('degraded'), findsOneWidget);

      LiquidGlassDegradation.endPlatformViewUnsafeSurface();
      await tester.pump();
      expect(find.text('glass'), findsOneWidget);
    });
  });

  group('liquid glass surfaces downgrade under system degradation', () {
    const liquidAppearance = FrostedAppearance(
      sheetBlurSigma: 15,
      sheetTintAlpha: 0.7,
      sheetBarrierAlpha: 0.2,
      glassMode: FrostedGlassMode.liquidGlass,
    );

    // Sanity: without any accessibility flag the liquid-glass sheet still
    // spawns its glass surface, so the downgrade assertions below are
    // meaningful (they fail because of degradation, not by accident).
    testWidgets('liquid sheet builds LiquidGlassSurface by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestApp(
          home: FrostedAppearanceScope(
            appearance: liquidAppearance,
            child: HyperosSheetFrame(
              child: SizedBox(width: 120, height: 120),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
    });

    Widget degradedSheet({required bool highContrast}) {
      return TestApp(
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(highContrast: highContrast),
              child: const FrostedAppearanceScope(
                appearance: liquidAppearance,
                child: HyperosSheetFrame(
                  child: SizedBox(width: 120, height: 120),
                ),
              ),
            );
          },
        ),
      );
    }

    testWidgets('liquid sheet downgrades to solid under high contrast', (
      tester,
    ) async {
      await tester.pumpWidget(degradedSheet(highContrast: true));
      await tester.pump();
      // 降级不再靠「不建液态玻璃面」来表达（弹层锁标准档后那个 widget 恒在），
      // 而是**换成实底材质**：0-模糊那条分支画 Material，浅色实底不再透出背景。
      // 判据改成看得见的那一半：非降级时那层磨砂底不见了。
      expect(find.byType(FrostedHeaderBackground), findsNothing);
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('liquid sheet is restored when high contrast clears', (
      tester,
    ) async {
      await tester.pumpWidget(degradedSheet(highContrast: true));
      await tester.pump();
      expect(
        LiquidGlassDegradation.shouldDegrade(
          tester.element(find.byType(HyperosSheetFrame).first),
        ),
        isTrue,
      );
      await tester.pumpWidget(degradedSheet(highContrast: false));
      await tester.pump();
      expect(
        LiquidGlassDegradation.shouldDegrade(
          tester.element(find.byType(HyperosSheetFrame).first),
        ),
        isFalse,
      );
      // 玻璃面自始至终都在（弹层锁标准档），变的是它**有没有降级**。具体画成玻璃
      // 还是实底在 VM 里分辨不出来（没有 shader 后端、平台模糊也不支持，两条都会
      // 落到实底），所以这里钉的是降级判定本身的翻转；材质渲染由真机验收。
      expect(find.byType(LiquidGlassSurface), findsOneWidget);
    });
  });
}

class _DegradationProbe extends StatelessWidget {
  const _DegradationProbe();

  @override
  Widget build(BuildContext context) {
    final degraded = LiquidGlassDegradation.shouldDegrade(context);
    return Text(degraded ? 'degraded' : 'glass');
  }
}
