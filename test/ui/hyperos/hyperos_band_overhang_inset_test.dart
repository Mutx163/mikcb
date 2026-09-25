import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';

import '../../helpers_test_app.dart';

/// 子页顶栏玻璃带下沿会画到顶栏盒子之外
/// ([HyperosBlurredHeader.subpageBandBottomOverhang]，2026-09-23 用户口径
/// 「模糊边界再往下超过标题底部一个字高」)。那一截不参与布局，于是静止时的
/// 第一行正好落在带下：不透明衬底把字盖掉上半截 —— 2026-09-25 用户报
/// 「桌面小组件页的小标题『快速添加到桌面』只显示下半部分」，课表管理页同症状。
///
/// 不变式：**正文第一行的顶边必须在带下沿之下**，且这条让位与带画不画同源
/// （深色模式 / 关模糊时不留无谓空白）。
///
/// 三种页型都要守住：大标题折叠页、无大标题页、顶栏带工具条页。
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

  Future<({double inset, double headerBottom, double firstRowTop})> pump(
    WidgetTester tester,
    Widget page,
  ) async {
    await tester.pumpWidget(TestApp(home: page));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final inset = tester
        .widgetList<HyperosBlurredHeaderScope>(
          find.byType(HyperosBlurredHeaderScope),
        )
        .first
        .contentTopInset;
    // 顶栏外壳 = 带真正绘制的那只盒子（外推的那一截不在其中）。
    final headerBottom = tester
        .getRect(find.byType(HyperosFrostedHeaderShell))
        .bottom;
    return (
      inset: inset,
      headerBottom: headerBottom,
      firstRowTop: tester.getRect(find.byType(HyperosSectionLabel).first).top,
    );
  }

  /// 带下沿 = 顶栏盒子底边 + 外推高度（外推不参与布局，只能这么算）。
  void expectClearsBand(
    WidgetTester tester, {
    required double headerBottom,
    required double firstRowTop,
    String? reason,
  }) {
    final bandBottom =
        headerBottom + HyperosBlurredHeader.subpageBandBottomOverhang;
    expect(
      firstRowTop,
      greaterThanOrEqualTo(bandBottom),
      reason:
          reason ??
          '第一行顶边 $firstRowTop 必须落在玻璃带下沿 $bandBottom 之下，'
              '否则静止时被不透明衬底盖掉上半截',
    );
  }

  testWidgets('大标题折叠页：正文为玻璃带外推让位', (tester) async {
    final m = await pump(tester, subpage());

    // 让位的那一截与外推同值，标题到第一行的原有间距（大标题内容间距 + 列表顶距）不变。
    expectClearsBand(tester, headerBottom: m.headerBottom, firstRowTop: m.firstRowTop);
    expect(
      m.inset - m.headerBottom,
      greaterThanOrEqualTo(HyperosBlurredHeader.subpageBandBottomOverhang),
      reason: '正文顶边距必须覆盖顶栏盒子 + 外推',
    );
  });

  testWidgets('无大标题页：正文为玻璃带外推让位', (tester) async {
    // 这一页型原先只留 4px 列表顶距，20px 外推直接盖掉整行小标题（实测 94%）。
    final m = await pump(tester, subpage(collapsibleLargeTitle: false));
    expectClearsBand(tester, headerBottom: m.headerBottom, firstRowTop: m.firstRowTop);
  });

  testWidgets('顶栏带工具条页：正文为玻璃带外推让位', (tester) async {
    final m = await pump(tester, subpage(withExtension: true));
    expectClearsBand(tester, headerBottom: m.headerBottom, firstRowTop: m.firstRowTop);
  });

  testWidgets('大标题折叠页：字体放大后仍让位（原有间距不缩）', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(
      () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
    );
    final m = await pump(tester, subpage());
    expectClearsBand(tester, headerBottom: m.headerBottom, firstRowTop: m.firstRowTop);
  });

  testWidgets('玻璃带不画时不留无谓空白', (tester) async {
    HyperosBlurredHeader.bandOverhangsOverride = false;
    final off = await pump(tester, subpage());
    HyperosBlurredHeader.bandOverhangsOverride = true;
    final on = await pump(tester, subpage());

    expect(
      on.inset - off.inset,
      HyperosBlurredHeader.subpageBandBottomOverhang,
      reason: '带画出去多少，正文就且只让出那么多',
    );
  });

  testWidgets('深色模式不画玻璃带，正文顶边距不额外下移', (tester) async {
    // 深色顶栏规范走纯不透明深色、不做模糊（[HyperosBlurredHeaderShell]），
    // 这条路径不画外推，于是不能留空白。override 只顶「平台支持」那一项，
    // 这里直接把主题换成深色，走真实判据。
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

    final inset = tester
        .widgetList<HyperosBlurredHeaderScope>(
          find.byType(HyperosBlurredHeaderScope),
        )
        .first
        .contentTopInset;
    final headerBottom = tester
        .getRect(find.byType(HyperosFrostedHeaderShell))
        .bottom;
    // 深色下带不外推，正文顶边距就是顶栏高度本身那套老算法，不含 20。
    expect(inset - headerBottom, lessThan(HyperosBlurredHeader.subpageBandBottomOverhang));
  });
}
