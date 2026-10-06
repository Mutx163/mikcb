// 弹窗面板实体回退时嵌套 tile 着色的同步回归测试。
//
// 回归背景（2026-09-12）：面板走 solid 分支回退**纯白实体卡片**时，嵌套 tile
// 若仍走玻璃面板的白色水洗（白 28% / 白 22–72%），叠白底整个隐形——课程弹窗
// 「只剩字、小框框没了」。修复后实体面板内的 tile 改走中性水洗。
//
// 触发条件变化（2026-09-19）：原先靠「作用范围 → 弹窗」开关关掉来触发实体
// 回退，那批开关已整体删除（弹窗家族锁标准档）。现在**只剩系统降级**能把它
// 摘成实体（[LiquidGlassDegradation.shouldDegradeFor]：减动效 / 高对比），
// 所以这里用 MediaQuery 打开这两个信号来复现同一条分支。
//
// 测试环境（VM）liveBlurSupported=false，withBlur:true 的白色水洗分支无法
// 在此复现（那需要真实模糊能力）；这里钉住的是**分支选择契约**：面板是玻璃 =
// 玻璃水洗分支，面板被降级成实体 = 中性水洗分支。
//
// 第二次回归（2026-09-29，用户口径「这弹窗上的框框什么的，都是和弹窗颜色一样，
// 看不出来框框」）：「面板读作不透明浅色卡片」还有第二种成因 —— **背后没壁纸**。
// 着色器后端是好的、玻璃照画，只是采到一片近白，白色水洗照样隐形。同一个中性
// 水洗出口，这批用例用 [HyperosFlatBackdropScope] 复现同一条分支。
//
// 第三次变化（2026-09-30，高斯模糊全局档退场）：本文件原来还有一个 `mode` 参数
// 用来切「液态 / 基础高斯」两条分支，并各配一组用例。液态成为唯一玻璃材质后
// 判据只剩系统降级与平色底两条，那两组用例与那个参数一并删除。
// 顺带修掉一批早就过时的用例名（它们写的是「柔光玻璃」，2026-09-22 就退了）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/flat_backdrop_scope.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/ui/hyperos/hyperos_sheet.dart';

Widget _harness({
  bool degraded = false,
  bool flatBackdrop = false,
  Brightness brightness = Brightness.light,
}) {
  Widget app = MaterialApp(
    theme: brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true),
    home: FrostedAppearanceScope(
      appearance: const FrostedAppearance(
        sheetBlurSigma: 18,
        sheetTintAlpha: 0.5,
        sheetBarrierAlpha: 0.4,
      ),
      // 挂在 MaterialApp 之下即可：本文件只验分派，读到值就够了。真实挂位在
      // main.dart 的 MaterialApp.builder（弹窗在根 Overlay 里，页面级挂不到）。
      child: HyperosFlatBackdropScope(
        isFlat: flatBackdrop,
        child: HyperosFrostedPanelScope(
          child: Center(
            child: HyperosFrostedSurface(
              borderRadius: BorderRadius.circular(12),
              child: const Text('tile'),
            ),
          ),
        ),
      ),
    ),
  );
  if (degraded) {
    app = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: app,
    );
  }
  return app;
}

/// 液态面板分支画的是纯 `ColoredBox`（无自带模糊）。
ColoredBox _liquidTile(WidgetTester tester) => tester.widget<ColoredBox>(
  find.descendant(
    of: find.byType(HyperosFrostedSurface),
    matching: find.byType(ColoredBox),
  ),
);

/// 非液态分支画的是 `FrostedHeaderBackground`。
FrostedHeaderBackground _frostedTile(WidgetTester tester) =>
    tester.widget<FrostedHeaderBackground>(
      find.descendant(
        of: find.byType(HyperosFrostedSurface),
        matching: find.byType(FrostedHeaderBackground),
      ),
    );

void main() {
  testWidgets('液态面板：嵌套 tile 走玻璃水洗', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    // 玻璃面板内：父面板自带模糊，tile 只上一层白色水洗（浅色主题 28%）。
    // 背后有壁纸时玻璃采到的是有颜色的内容，白色压上去读得出「更亮的一块」。
    expect(_liquidTile(tester).color, Colors.white.withValues(alpha: 0.28));
  });

  testWidgets('液态面板 + 系统降级：嵌套 tile 弃白色水洗改中性水洗', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(degraded: true));
    await tester.pump();

    // 面板已回退纯白实体：白色水洗会白底白框隐形，必须走 withBlur:false
    // 的中性水洗（浅色主题 = 黑 5%）。
    expect(_frostedTile(tester).tint, Colors.black.withValues(alpha: 0.05));
  });

  // ── 第二次回归：背后没壁纸（2026-09-29）────────────────────────────────
  //
  // 面板仍是液态玻璃、着色器后端正常，只是**背后没有可采样的内容**：面板出图
  // 与近白页面底色几乎一致，白色水洗叠上去只差 1~2 个色阶 → 行卡片隐形。
  // 这不是「面板退化成实底」，所以系统降级闸门抓不到它，得单开一条。

  testWidgets('液态面板 + 背后平色底：嵌套 tile 弃白色水洗改中性水洗', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(flatBackdrop: true));
    await tester.pump();

    // 关键：此时面板**没有**被降级（仍是 ColoredBox 那条液态分支），
    // 若判据只认 LiquidGlassDegradation，这里会读到白 0.28 —— 正是症状本身。
    final tile = _liquidTile(tester);
    expect(tile.color, isNot(Colors.white.withValues(alpha: 0.28)));
    expect(tile.color, Colors.black.withValues(alpha: 0.05));
  });

  testWidgets('暗色 + 背后平色底：改中性水洗（白 10%，不是白 12% 那条水洗）', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(flatBackdrop: true, brightness: Brightness.dark),
    );
    await tester.pump();

    // 暗色的中性水洗是白 10%，玻璃水洗是白 12% —— 两个值只差 0.02，断言必须
    // 写死具体值而不是「不等于玻璃水洗」，否则这条用例什么也钉不住。
    expect(_liquidTile(tester).color, Colors.white.withValues(alpha: 0.10));
  });

  testWidgets('暗色 + 有壁纸：仍走玻璃水洗（白 12%）', (tester) async {
    await tester.pumpWidget(_harness(brightness: Brightness.dark));
    await tester.pump();

    expect(_liquidTile(tester).color, Colors.white.withValues(alpha: 0.12));
  });

  testWidgets('有壁纸（isFlat:false）：逐像素保持既有白色水洗', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    // 这是本次改动的**回归底线**：有壁纸时一个像素都不能动。
    expect(_liquidTile(tester).color, Colors.white.withValues(alpha: 0.28));
  });

  testWidgets('作用域缺席：按「背后有东西可采」处理，不改既有观感', (tester) async {
    // 独立组件 / 未挂作用域的测试与预览：缺席即 false（见类注释的默认值理由）。
    // 这棵树**故意不挂** [HyperosFlatBackdropScope] —— 挂了就测不到「缺席」这条。
    await tester.pumpWidget(
      MaterialApp(
        home: FrostedAppearanceScope(
          appearance: const FrostedAppearance(
            sheetBlurSigma: 18,
            sheetTintAlpha: 0.5,
            sheetBarrierAlpha: 0.4,
          ),
          child: HyperosFrostedPanelScope(
            child: Center(
              child: HyperosFrostedSurface(
                borderRadius: BorderRadius.circular(12),
                child: const Text('tile'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_liquidTile(tester).color, Colors.white.withValues(alpha: 0.28));
  });
}
