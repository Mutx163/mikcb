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
/// - `tintAlphaMultiplier` → 上游颜色层不透明度，以及「无 backdrop」时的兜底实底
///   （两边必须同口径，否则同一档位在真玻璃与兜底实底上是两个浓度）；
/// - `blurEnabled: false` → 不接采样源（上游无 backdrop 时保留纯色轮廓）。
void main() {
  MiuixGlass glassOf(WidgetTester tester) =>
      tester.widget<MiuixGlass>(find.byType(MiuixGlass));

  Future<void> pumpSurface(
    WidgetTester tester, {
    SoftGlassTuning? scopeTuning,
    SoftGlassTuning? override,
    bool blurEnabled = true,
    Size size = const Size(200, 56),
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
                width: size.width,
                height: size.height,
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

  testWidgets('本屏有采样源时，等第一张快照的那一帧不画实底（不再闪假玻璃）', (tester) async {
    // 真机反馈（2026-09-15）：柔光档进 / 出壁纸位置选择页，三个悬浮按钮先冒一块
    // 奶白实底、再变真玻璃。首帧没有快照是**暂态**（宿主当帧末就录到了），这一段
    // 画实底正是那一闪的来源；有采样源时必须留透明，让衬底与文字先顶上。
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HyperosGlassBackdropScope(
          controller: controller,
          child: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 56,
                child: SoftGlassSurface(child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(glassOf(tester).fill!.a, 0);
  });

  testWidgets('真降级（本屏没有采样源）时的兜底实底也跟随底色倍率（与 standInWashColor 同口径）', (tester) async {
    // 有采样源时兜底实底只在"等第一张快照"那一帧短暂出现（现已画透明，见上一条
    // 用例）；这条守的是**不会有快照来**的那条路：模糊关闭、或本屏压根没有采样源。
    // 那时上游读 `fill` 画纯色轮廓，它也得跟着档位走 —— 漏掉倍率时清透（0.55）
    // 与浓雾（1.3）会得到同一个浓度，而 `HomePageChromeGlassFill.standInWashColor`
    // （同源注释）带了倍率，两边就此分叉，正是「一个材质两种观感」。
    const dense = SoftGlassTuning.presetDense;
    await pumpSurface(tester, scopeTuning: dense);
    final context = tester.element(find.byType(SoftGlassSurface));

    expect(
      glassOf(tester).fill,
      SoftGlassTokens.tint(
        context,
        blurEnabled: true,
        tintAlphaMultiplier: dense.tintAlphaMultiplier,
      ),
    );
    // 与清透档必须不同，否则说明倍率没进兜底实底。
    final clear = SoftGlassTokens.tint(
      context,
      blurEnabled: true,
      tintAlphaMultiplier: SoftGlassTuning.presetClear.tintAlphaMultiplier,
    );
    expect(glassOf(tester).fill!.a, greaterThan(clear.a));
  });

  group('OS4 弹层也跟随柔光玻璃档位', () {
    /// 真机反馈：选了「清透」和「浓雾」，首页右上角菜单一模一样 —— 弹层当时用的是
    /// 上游固定材质，没接用户档位。这里守「同一份映射也喂给弹层」。
    ///
    /// 断言落点已从上游 `visuals` 改成**真正出图的那块玻璃**：弹层面板现在是
    /// 项目自己的注入面（`os4_glass_popup_surface.dart` → `HyperosSelectPopupGlass`
    /// → `SoftGlassSurface` → `MiuixGlass`），档位由注入面自己按全局档位分派，
    /// 上游那 7 个 OS4 材质字段不再参与渲染（`visuals` 传了也是死参）。
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

    /// 读弹层面板的材质半径。正常只该有一块（面板本身）。
    double popupBlur(WidgetTester tester, Finder popup) =>
        tester
            .widget<MiuixGlass>(
              find.descendant(of: popup, matching: find.byType(MiuixGlass)),
            )
            .material!
            .blurRadius;

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
                  show: true,
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
      // 面板经 OverlayPortal 挂到 Overlay：只有真正展示（show: true）时
      // overlay child 才非空，断言才有落点。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return popupBlur(tester, find.byType(MiuixGlassDropdownPopup));
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
              show: true,
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
      // 同选择弹层：面板经 OverlayPortal 挂到 Overlay，只有展示时才有落点。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        popupBlur(tester, find.byType(MiuixGlassTransformPopup)),
        SoftGlassRecipe.standard.blurRadiusDp *
            SoftGlassTuning.presetDense.blurRadiusMultiplier,
      );
    });
  });

  group('小圆球的描边衰减', () {
    /// 真机反馈：柔光档 + 壁纸时，首页右上角那颗球的白边特别重。
    ///
    /// 根因在材质侧：这圈描边是**柔光档独有**的（高斯 / 液态两条分支都不传
    /// `stroke`，所以只有柔光档会白），而它的参数是按面板调的 —— 贴边 1px 的
    /// 加法白高光，叠在"浅色档本就被三层白提亮到接近纯白"的玻璃内部上，直接
    /// 钳到 1.0。球的周长/面积比是面板的十几倍，同一条高光几乎绕满一圈，于是
    /// 只剩"一圈死白边"。纯色底上白叠白等于没画，这个偏差只在**有背景**时暴露
    /// —— 正好对上"带壁纸才看得见"。
    ///
    /// 这里守住**判定**（谁算球、谁不算）与**落点**（球的 MiuixGlass 真拿到
    /// 衰减后的值，且面板没被波及）。
    final baseStroke = MiuixGlassStrokes.forTheme(false);

    double strokeAlphaOf(WidgetTester tester) =>
        glassOf(tester).stroke!.primary.color.a;

    test('只有接近正方形的小表面算球', () {
      double at(double w, double h) => softGlassBallEdgeHighlight(
        BoxConstraints.tightFor(width: w, height: h),
        SoftGlassTuning.defaultEdgeHighlight,
      );
      const scaled =
          SoftGlassTuning.defaultEdgeHighlight * softGlassBallEdgeScale;

      // 40dp 的顶栏图标球正是这一档。
      expect(at(40, 40), closeTo(scaled, 1e-9));
      // 56dp 圆钮**不在**本档（阈值 48）：它的边要不要一起收是另一个决定，
      // 调 `softGlassBallMaxSide` 即可 —— 这里钉住当前口径。
      expect(at(56, 56), SoftGlassTuning.defaultEdgeHighlight);
      // 横长的玻璃条与面板不能被误伤：底栏 54 高、本文件的测试面 200×56 都
      // 贴着阈值，靠"接近正方形"这个条件把它们挡在外面。
      expect(at(380, 54), SoftGlassTuning.defaultEdgeHighlight);
      expect(at(200, 56), SoftGlassTuning.defaultEdgeHighlight);
      expect(at(300, 240), SoftGlassTuning.defaultEdgeHighlight);
      // 约束无界（放进 Column / Row 按内容撑）时不做猜测。
      expect(
        softGlassBallEdgeHighlight(const BoxConstraints(maxWidth: 200), 1),
        1,
      );
    });

    testWidgets('40dp 的球发出衰减档描边，面板保持原样', (tester) async {
      await pumpSurface(tester, size: const Size(40, 40));
      expect(
        strokeAlphaOf(tester),
        closeTo(baseStroke.primary.color.a * softGlassBallEdgeScale, 1e-6),
      );

      await pumpSurface(tester);
      expect(
        strokeAlphaOf(tester),
        closeTo(baseStroke.primary.color.a, 1e-6),
        reason: '「标准档 = 菜单原样」对面板依然成立，衰减不能波及大面板',
      );
    });
  });
}
