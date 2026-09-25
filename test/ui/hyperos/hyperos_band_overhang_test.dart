import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';

import '../../helpers_test_app.dart';

/// 子页顶栏玻璃带的下沿外推（`InspireHeaderBlur.bottomOverhang`）是**画在顶栏
/// 盒子之外**的，布局高度不变。版面上留给「顶栏底边 → 第一行内容」的空白只有
/// [HyperosMiuixTopAppBar.largeTitleContentGap]（大标题页 8px + 列表顶距 4px），
/// 按满 20 画就越过正文顶边距：不透明衬底把静止时第一行的上半截盖掉 ——
/// 2026-09-25 用户报「桌面小组件页的小标题『快速添加到桌面』只显示下半部分」。
///
/// 两条要同时守住（2026-09-25 用户口径「空隙太大」把只保后者的一条否掉了）：
/// 1. **带下沿不许越过正文顶边距** —— 第一行不被盖。
/// 2. **正文不许下移** —— 外推按版面空白封顶，不靠让位解决。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => HyperosBlurredHeader.bandOverhangsOverride = true);
  tearDown(() => HyperosBlurredHeader.bandOverhangsOverride = null);

  Widget subpage({
    bool collapsibleLargeTitle = true,
    bool withExtension = false,
  }) => HyperosSubpage(
    onBack: () {},
    title: const Text('页面标题'),
    collapsibleLargeTitle: collapsibleLargeTitle,
    headerExtension: withExtension
        ? const HyperosBlurredHeaderExtension(child: SizedBox(height: 40))
        : null,
    child: const HyperosListView(
      children: [
        HyperosSectionLabel(text: '小标题文字'),
        HyperosListGroup(children: [SizedBox(height: 60)]),
      ],
    ),
  );

  Future<({double overhang, double headerBottom, double firstRowTop})> pump(
    WidgetTester tester,
    Widget page,
  ) async {
    await tester.pumpWidget(TestApp(home: page));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return (
      overhang: tester
          .widget<HyperosFrostedHeaderShell>(
            find.byType(HyperosFrostedHeaderShell),
          )
          .bottomOverhang,
      headerBottom: tester.getRect(find.byType(HyperosFrostedHeaderShell)).bottom,
      firstRowTop: tester.getRect(find.byType(HyperosSectionLabel).first).top,
    );
  }

  void expectClearsBand(
    WidgetTester tester, {
    required double overhang,
    required double headerBottom,
    required double firstRowTop,
  }) {
    expect(
      firstRowTop,
      greaterThanOrEqualTo(headerBottom + overhang),
      reason: '第一行顶边 $firstRowTop 必须落在玻璃带下沿 '
          '${headerBottom + overhang} 之下，否则静止时被不透明衬底盖掉上半截',
    );
  }

  testWidgets('大标题折叠页：下沿按版面空白封顶，且不越过正文顶边距', (
    tester,
  ) async {
    final m = await pump(tester, subpage());

    expectClearsBand(
      tester,
      overhang: m.overhang,
      headerBottom: m.headerBottom,
      firstRowTop: m.firstRowTop,
    );
    expect(
      m.overhang,
      HyperosMiuixTopAppBar.largeTitleContentGap,
      reason: '能画的只有标题块与正文之间那点设计间距',
    );
    expect(m.overhang, lessThan(HyperosBlurredHeader.subpageBandBottomOverhang));
  });

  testWidgets('无大标题页：正文紧贴顶栏，不外推', (tester) async {
    // 这一页型原先只留 4px 列表顶距，20px 外推直接盖掉整行小标题（实测 94%）。
    final m = await pump(tester, subpage(collapsibleLargeTitle: false));
    expect(m.overhang, 0);
    expectClearsBand(
      tester,
      overhang: m.overhang,
      headerBottom: m.headerBottom,
      firstRowTop: m.firstRowTop,
    );
  });

  testWidgets('顶栏带工具条页：正文顶边距就是顶栏实测高度，不外推', (
    tester,
  ) async {
    final m = await pump(tester, subpage(withExtension: true));
    expect(m.overhang, 0);
    expectClearsBand(
      tester,
      overhang: m.overhang,
      headerBottom: m.headerBottom,
      firstRowTop: m.firstRowTop,
    );
  });

  testWidgets('正文顶边距不受外推影响（不靠下移内容解决）', (tester) async {
    HyperosBlurredHeader.bandOverhangsOverride = true;
    final on = await pump(tester, subpage());
    HyperosBlurredHeader.bandOverhangsOverride = false;
    final off = await pump(tester, subpage());

    expect(
      on.firstRowTop,
      off.firstRowTop,
      reason: '带画不画都不许挪正文 —— 挪了就等于所有页面凭空多一截空隙',
    );
  });

  testWidgets('大标题折叠页：字体放大后仍不越过正文顶边距', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(
      () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
    );
    final m = await pump(tester, subpage());
    expectClearsBand(
      tester,
      overhang: m.overhang,
      headerBottom: m.headerBottom,
      firstRowTop: m.firstRowTop,
    );
  });

  testWidgets('深色模式 / 关模糊：带不画，下沿也不画', (tester) async {
    // 深色顶栏规范走纯不透明深色、不做模糊（[HyperosBlurredHeaderShell]），
    // 页面壳的判据与外壳的 `useBlur` 同源，于是都不外推。override 只顶「平台
    // 支持」那一项，这里清掉它走真实判据。
    HyperosBlurredHeader.bandOverhangsOverride = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: subpage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      tester
          .widget<HyperosFrostedHeaderShell>(
            find.byType(HyperosFrostedHeaderShell),
          )
          .bottomOverhang,
      0,
    );
  });
}
