import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/soft_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_surface.dart';

/// 柔光玻璃调参（[SoftGlassTuning]）→ 上游 OS4 玻璃材质的映射：
///
/// 自研折射链路删除后，[SoftGlassSurface] 内部换成 `MiuixGlass`，用户档位不再
/// 作用于自绘底色，而是作用在上游材质上：
/// - `blurRadiusMultiplier` → 材质 `blurRadius`（上游 radius 单位，与配方半径
///   `SoftGlassRecipe.blurRadiusDp` 同源）；
/// - `tintAlphaMultiplier` → 上游颜色层不透明度；
/// - `blurEnabled: false` → 不接采样源（上游无 backdrop 时保留纯色轮廓）。
void main() {
  MiuixGlass glassOf(WidgetTester tester) =>
      tester.widget<MiuixGlass>(find.byType(MiuixGlass));

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

  testWidgets('默认档位 = 上游弹层材质原样（与首页菜单 / 选择弹层同款）', (tester) async {
    await pumpSurface(tester);
    final material = glassOf(tester).material!;
    // 基线就是菜单用的 popupViewGlass：同半径、同颜色层。
    expect(
      material.blurRadius,
      MiuixGlassMaterials.popupViewGlassLight.blurRadius,
    );
    expect(material.blurRadius, SoftGlassRecipe.standard.blurRadiusDp);
    // 底色倍率默认 1：颜色层不透明度与上游预设一致。
    expect(
      material.first.color.a,
      closeTo(MiuixGlassMaterials.puredThinGlassLight.first.color.a, 1e-6),
    );
  });

  testWidgets('底色倍率整体缩放上游颜色层 alpha', (tester) async {
    await pumpSurface(
      tester,
      scopeTuning: const SoftGlassTuning(tintAlphaMultiplier: 0.5),
    );
    final material = glassOf(tester).material!;
    expect(
      material.first.color.a,
      closeTo(
        MiuixGlassMaterials.puredThinGlassLight.first.color.a * 0.5,
        1e-6,
      ),
    );
  });

  testWidgets('雾面倍率整体缩放配方半径', (tester) async {
    await pumpSurface(
      tester,
      scopeTuning: const SoftGlassTuning(blurRadiusMultiplier: 0.25),
    );
    expect(
      glassOf(tester).material!.blurRadius,
      closeTo(SoftGlassRecipe.standard.blurRadiusDp * 0.25, 1e-6),
    );
  });

  testWidgets('显式 tuning 覆盖优先于 scope', (tester) async {
    await pumpSurface(
      tester,
      scopeTuning: const SoftGlassTuning(blurRadiusMultiplier: 0.25),
      override: const SoftGlassTuning(blurRadiusMultiplier: 2),
    );
    expect(
      glassOf(tester).material!.blurRadius,
      closeTo(SoftGlassRecipe.standard.blurRadiusDp * 2, 1e-6),
    );
  });

  testWidgets('模糊关闭时不接采样源（上游走纯色轮廓兜底）', (tester) async {
    await pumpSurface(tester, blurEnabled: false);
    expect(glassOf(tester).backdrop, isNull);
  });

  testWidgets('与菜单同档：栏与菜单 MaterialToken（shading 关）', (tester) async {
    await pumpSurface(tester);
    expect(glassOf(tester).shading, isFalse);
  });
}
