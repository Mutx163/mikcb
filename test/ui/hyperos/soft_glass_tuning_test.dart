import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/soft_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/home_top_menu_popup.dart';

import '../../helpers_test_app.dart';

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
    final glass = glassOf(tester);
    final material = glass.material!;
    final base = MiuixGlassMaterials.popupViewGlassLight;

    // 基线就是菜单用的 popupViewGlass：同半径、同颜色层。
    expect(material.blurRadius, base.blurRadius);
    expect(material.blurRadius, SoftGlassRecipe.standard.blurRadiusDp);
    // 底色倍率默认 1：三层颜色层 alpha 与上游预设**逐层**一致。
    expect(material.first.color.a, closeTo(base.first.color.a, 1e-6));
    expect(material.second!.color.a, closeTo(base.second!.color.a, 1e-6));
    expect(material.third!.color.a, closeTo(base.third!.color.a, 1e-6));

    // 描边也必须原样。`defaultEdgeHighlight` 一旦不是 1.0（历史上是 0.95），
    // 标准档的描边就会比菜单暗一档 —— 而上面那几条只验半径 / 颜色层的断言
    // **完全发现不了**，正是这个盲区让「标准档 = 菜单原样」的说法长期不成立。
    final stroke = glass.stroke!;
    final baseStroke = MiuixGlassStrokes.forTheme(false);
    expect(stroke.width, baseStroke.width);
    expect(stroke.color.a, closeTo(baseStroke.color.a, 1e-6));
    expect(stroke.primary.color.a, closeTo(baseStroke.primary.color.a, 1e-6));
    expect(stroke.secondary.color.a, closeTo(baseStroke.secondary.color.a, 1e-6));
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

  testWidgets('模糊关闭时的兜底实底取自 SoftGlassTokens.tint，不是上游默认纯白', (tester) async {
    await pumpSurface(tester, blurEnabled: false);
    final glass = glassOf(tester);
    final expected = SoftGlassTokens.tint(
      tester.element(find.byType(SoftGlassSurface)),
      blurEnabled: false,
    );
    expect(glass.fill, expected);
    // 上游 `MiuixGlass` 在没给 fill 时兜底 0xFFFFFFFF，直接沿用会在深色壁纸上
    // 糊一块纯白卡；项目约定「模糊关闭即实底」= tintAlphaNoBlur 的半透明灰。
    expect(glass.fill!.a, closeTo(SoftGlassTokens.tintAlphaNoBlur, 1e-6));
  });

  testWidgets('与菜单同档：栏与菜单 MaterialToken（shading 关）', (tester) async {
    await pumpSurface(tester);
    expect(glassOf(tester).shading, isFalse);
  });

  group('OS4 弹层也跟随柔光玻璃档位', () {
    /// 真机反馈：选了「清透」和「浓雾」，首页右上角菜单一模一样 —— 弹层当时用的是
    /// 上游固定材质，没接用户档位。这里守「同一份映射也喂给弹层」。
    Widget scope({required SoftGlassTuning tuning, required Widget child}) =>
        FrostedAppearanceScope(
          appearance: FrostedAppearance(
            sheetBlurSigma: 15,
            sheetTintAlpha: 0.70,
            sheetBarrierAlpha: 0.20,
            glassMode: FrostedGlassMode.softGlass,
            softGlassTuning: tuning,
          ),
          child: child,
        );

    Future<double> selectPopupBlur(
      WidgetTester tester,
      SoftGlassTuning tuning,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: scope(
            tuning: tuning,
            child: Stack(
              children: [
                HyperosSelectPopup<int>(
                  show: false,
                  anchorRect: Rect.zero,
                  items: const {'A': 1, 'B': 2},
                  currentValue: 1,
                  onSelected: (_) {},
                  onDismiss: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final popup = tester.widget<MiuixGlassDropdownPopup>(
        find.byType(MiuixGlassDropdownPopup),
      );
      return popup.visuals.material!.blurRadius;
    }

    testWidgets('选择弹层材质随档位变化（清透 < 标准 < 浓雾）', (tester) async {
      final clear = await selectPopupBlur(tester, SoftGlassTuning.presetClear);
      final standard = await selectPopupBlur(
        tester,
        SoftGlassTuning.defaults,
      );
      final dense = await selectPopupBlur(tester, SoftGlassTuning.presetDense);

      expect(clear, lessThan(standard));
      expect(standard, lessThan(dense));
      expect(standard, SoftGlassRecipe.standard.blurRadiusDp);
    });

    testWidgets('首页右上角菜单材质随档位变化', (tester) async {
      final anchor = MiuixGlassPopupAnchor();
      addTearDown(anchor.dispose);
      await tester.pumpWidget(
        TestApp(
          home: scope(
            tuning: SoftGlassTuning.presetDense,
            child: HomeTopMenuPopup(
              show: false,
              anchor: anchor,
              anchorContent: const Icon(Icons.more_vert_rounded),
              entries: const [],
              hasAvailableUpdate: false,
              onDismissRequest: () {},
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final popup = tester.widget<MiuixGlassTransformPopup>(
        find.byType(MiuixGlassTransformPopup),
      );
      expect(
        popup.visuals.material!.blurRadius,
        SoftGlassRecipe.standard.blurRadiusDp *
            SoftGlassTuning.presetDense.blurRadiusMultiplier,
      );
    });
  });
}
