// 弹窗面板内 `HyperosAdaptiveCard` 的填充色分派（与 `HyperosFrostedSurface`
// 共用同一个出口 `HyperosBlurredHeader.nestedLiquidTileTintColor`）。
//
// 为什么单独钉：那张卡片是**另一个组件、另一条渲染路径**（`Material` 的 color，
// 不是 `ColoredBox`）。两条路径共用一个函数不等于共用一次修复 —— 只钉住
// `HyperosFrostedSurface` 的话，哪天有人给卡片这条路径私开一个判据，测试照样全绿。
//
// 「背后平色底 → 弃白色水洗」的成因与算术见
// `hyperos_frosted_surface_nested_test.dart` 顶部与
// `lib/ui/hyperos/frosted/flat_backdrop_scope.dart`。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/flat_backdrop_scope.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/hyperos_sheet.dart';
import 'package:university_timetable/ui/hyperos/widgets/adaptive_card.dart';

Widget _harness({required bool flatBackdrop, bool inPanel = true}) {
  const appearance = FrostedAppearance(
    sheetBlurSigma: 18,
    sheetTintAlpha: 0.5,
    sheetBarrierAlpha: 0.4,
  );
  const card = HyperosAdaptiveCard(child: Text('card'));
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: FrostedAppearanceScope(
      appearance: appearance,
      child: HyperosFlatBackdropScope(
        isFlat: flatBackdrop,
        child: inPanel
            ? const HyperosFrostedPanelScope(child: Center(child: card))
            : const Center(child: card),
      ),
    ),
  );
}

/// 卡片自己那块 `Material` 的填充色（`MaterialApp` 里另有 Material，必须限定在
/// 卡片子树内取，否则会抓到 App 自己的那层）。
Color _cardFill(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(HyperosAdaptiveCard),
            matching: find.byType(Material),
          )
          .first,
    )
    .color!;

void main() {
  testWidgets('面板内 + 有壁纸：走玻璃白色水洗（白 28%）', (tester) async {
    await tester.pumpWidget(_harness(flatBackdrop: false));
    await tester.pump();

    expect(_cardFill(tester), Colors.white.withValues(alpha: 0.28));
  });

  testWidgets('面板内 + 背后平色底：改中性水洗（黑 5%）', (tester) async {
    await tester.pumpWidget(_harness(flatBackdrop: true));
    await tester.pump();

    expect(_cardFill(tester), Colors.black.withValues(alpha: 0.05));
  });

  testWidgets('面板外：不受平色底判据影响，仍是实体卡片色', (tester) async {
    // 设置页的卡片不站在玻璃面板上，一直是不透明 `HyperosColors.card`
    // （浅色 #FFFFFF，压在 #F2F2F2 页面底上）—— 本次修的是「面板内白叠白」，
    // 面板外本来就读得出来，不能顺手一起改掉。
    final withBackdrop = _harness(flatBackdrop: false, inPanel: false);
    final flatBackdrop = _harness(flatBackdrop: true, inPanel: false);

    await tester.pumpWidget(withBackdrop);
    await tester.pump();
    final normal = _cardFill(tester);

    await tester.pumpWidget(flatBackdrop);
    await tester.pump();

    expect(_cardFill(tester), normal);
    expect(normal.a, 1.0, reason: '面板外的卡片必须仍是不透明实体色');
  });
}
