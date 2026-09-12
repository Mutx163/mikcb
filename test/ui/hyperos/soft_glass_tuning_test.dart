import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/soft_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_surface.dart';

/// 柔光玻璃调参（SoftGlassTuning）渲染冒烟：
/// 倍率作用在配方底色 alpha 上，测试环境无折射 shader（回退纯高斯），
/// 因此只验证底色合成与构建不炸；折射 uniform 走模型测试的常量守卫。
void main() {
  /// 底栏配方（floatingNavigation）最终底色 = 0.75 × 0.90 × tint 倍率。
  double fillAlpha(WidgetTester tester) {
    final boxes = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(SoftGlassSurface),
        matching: find.byType(DecoratedBox),
      ),
    );
    for (final box in boxes) {
      final decoration = box.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        return decoration.color!.a;
      }
    }
    fail('SoftGlassSurface 子树里没找到带底色的 DecoratedBox');
  }

  Future<void> pumpSurface(
    WidgetTester tester, {
    SoftGlassTuning? scopeTuning,
    SoftGlassTuning? override,
    bool blurEnabled = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FrostedAppearanceScope(
          appearance: FrostedAppearance(
            sheetBlurSigma: 15,
            sheetTintAlpha: 0.70,
            sheetBarrierAlpha: 0.20,
            glassMode: FrostedGlassMode.softGlass,
            softGlassTuning: scopeTuning ?? SoftGlassTuning.defaults,
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 56,
                child: SoftGlassSurface(
                  blurEnabled: blurEnabled,
                  tuning: override,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('默认调参 = 接入前的底色（0.75 × 0.90）', (tester) async {
    await pumpSurface(tester);
    expect(fillAlpha(tester), closeTo(0.675, 1e-6));
  });

  testWidgets('底色倍率整体缩放配方 alpha', (tester) async {
    await pumpSurface(
      tester,
      scopeTuning: const SoftGlassTuning(tintAlphaMultiplier: 0.5),
    );
    expect(fillAlpha(tester), closeTo(0.675 * 0.5, 1e-6));
  });

  testWidgets('显式 tuning 覆盖优先于 scope', (tester) async {
    await pumpSurface(
      tester,
      scopeTuning: const SoftGlassTuning(tintAlphaMultiplier: 0.5),
      // 1.2 × 0.675 = 0.81，不触 alpha 上限 clamp。
      override: const SoftGlassTuning(tintAlphaMultiplier: 1.2),
    );
    expect(fillAlpha(tester), closeTo(0.675 * 1.2, 1e-6));
  });

  testWidgets('模糊关闭时落 0.90 实底，不受底色倍率影响', (tester) async {
    await pumpSurface(
      tester,
      scopeTuning: const SoftGlassTuning(tintAlphaMultiplier: 0.1),
      blurEnabled: false,
    );
    expect(fillAlpha(tester), closeTo(SoftGlassTokens.tintAlphaNoBlur, 1e-6));
  });

  testWidgets('雾面/折射拉满也不炸（sigma 与 shader 参数越界由链路夹紧）', (tester) async {
    await pumpSurface(
      tester,
      scopeTuning: SoftGlassTuning.defaults.copyWith(
        blurRadiusMultiplier: SoftGlassTuning.maxBlurRadiusMultiplier,
        refraction: SoftGlassTuning.maxRefraction,
        chromaticAberration: SoftGlassTuning.maxChromaticAberration,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
