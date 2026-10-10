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

  setUp(() {
    HyperosBlurredHeader.bandOverhangsOverride = true;
    // 不顶这一项的话，widget test 跑在宿主平台（Windows）上，`liveBlurSupported`
    // 恒 false，玻璃带**根本没画**那截外推 —— 测试就只在验算术，不验绘制路径。
    HyperosBlurredHeader.liveBlurSupportedOverride = true;
  });
  tearDown(() {
    HyperosBlurredHeader.bandOverhangsOverride = null;
    HyperosBlurredHeader.liveBlurSupportedOverride = null;
  });

  Widget subpage({
    bool collapsibleLargeTitle = true,
    bool withExtension = false,
    double bodyHeight = 60,
    Key? key,
  }) => HyperosSubpage(
    key: key,
    onBack: () {},
    title: const Text('页面标题'),
    collapsibleLargeTitle: collapsibleLargeTitle,
    headerExtension: withExtension
        ? const HyperosBlurredHeaderExtension(child: SizedBox(height: 40))
        : null,
    child: HyperosListView(
      children: [
        const HyperosSectionLabel(text: '小标题文字'),
        HyperosListGroup(children: [SizedBox(height: bodyHeight)]),
      ],
    ),
  );

  Future<({double overhang, double painted, double headerBottom, double firstRowTop})>
  pump(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(TestApp(home: page));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return (
      overhang: tester
          .widget<HyperosFrostedHeaderShell>(
            find.byType(HyperosFrostedHeaderShell),
          )
          .bottomOverhang,
      // 真·画出去的那一截：HyperosFrostedHeaderShell 自己按 useBlur 门控后
      // 交给 InspireHeaderBlur 的值。
      painted: tester
          .widget<FrostedHeaderBackground>(find.byType(FrostedHeaderBackground))
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
    expect(
      m.painted,
      m.overhang,
      reason: '页面壳算出的值必须真的被画出去（门控之后仍然是同一个数）',
    );
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

  testWidgets('外推不改变「字滑到带下 → 变磨砂」这个窗口的宽度', (tester) async {
    // 「内容先滑到不透明带下、越过阈值再切磨砂」是 2026-07-31 起就有的设计
    // （见 `_collapsibleFrostThreshold` 与 `opaqueAtRest`），那个窗口本来就
    // 存在、且有意的（无顿挫）。外推要保证的是**只把这条曲线整体前移**、
    // 不把窗口撑宽 —— 撑宽就等于在带子底下多藏一段字。
    //
    // 2026-09-26 审核曾报"窗口从 4px 变 12px"，实测两条都错：外推 8 与外推 0
    // 的窗口**都是 36px**（外推只是让接触点与磨砂点一起前移 8px）。这条测试
    // 就是钉住那个事实，防止以后有人把窗口改宽。
    Future<({double contact, double frost})> measure(
      WidgetTester tester, {
      required bool bandPaints,
    }) async {
      HyperosBlurredHeader.bandOverhangsOverride = bandPaints;
      // 每次量一遍都要一棵**全新**的树：同 runtimeType 会复用 State，滚动位置与
      // 磨砂状态会从上一次量测里带过来，把两次读数搅在一起（实测会假报 8px 差异）。
      await pump(tester, subpage(bodyHeight: 300, key: ValueKey(bandPaints)));
      final oh = tester
          .widget<HyperosFrostedHeaderShell>(
            find.byType(HyperosFrostedHeaderShell),
          )
          .bottomOverhang;
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(HyperosListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      double? contact;
      double? frost;
      for (final p in [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0, 40.0, 48.0, 56.0, 64.0, 80.0]) {
        position.jumpTo(p);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final bandBottom =
            tester.getRect(find.byType(HyperosFrostedHeaderShell)).bottom + oh;
        final rowTop = tester.getRect(find.byType(HyperosSectionLabel).first).top;
        final frosted = tester
            .widgetList<HyperosHeaderUnderContentScope>(
              find.byType(HyperosHeaderUnderContentScope),
            )
            .first
            .contentUnderHeader;
        contact ??= rowTop < bandBottom ? p : null;
        frost ??= frosted ? p : null;
      }
      expect(contact, isNotNull);
      expect(frost, isNotNull);
      return (contact: contact!, frost: frost!);
    }

    final withBand = await measure(tester, bandPaints: true);
    final withoutBand = await measure(tester, bandPaints: false);

    expect(
      withBand.frost - withBand.contact,
      closeTo(withoutBand.frost - withoutBand.contact, 0.01),
      reason:
          '外推 $withBand 与不外推 $withoutBand 的「不透明窗口」必须一样宽，'
          '否则就有一段字被多藏在不透明带子底下',
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

  testWidgets('深色模式与浅色同构：带与下沿外推都画（2026-10-10 拆深色门禁）', (tester) async {
    // 旧规范「深色顶栏 = 纯不透明、不做玻璃」的门禁 2026-10-10 拆除：用户口径
    // 2026-09-27「暗色模式渐变模糊也要显示」，当时只修了取色（_frostedScrimColor
    // 亮 veil）、门禁漏了，深色下模糊层不挂、衬底换成页面底色又渐隐到透明，
    // 整条带读成透明片。现在深色必须与浅色画出同一条带。
    HyperosBlurredHeader.bandOverhangsOverride = true;
    double shellOverhang() => tester
        .widget<HyperosFrostedHeaderShell>(find.byType(HyperosFrostedHeaderShell))
        .bottomOverhang;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.light,
        home: subpage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final lightOverhang = shellOverhang();

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

    expect(lightOverhang, HyperosMiuixTopAppBar.largeTitleContentGap);
    expect(
      shellOverhang(),
      lightOverhang,
      reason: '深色不再被门禁挡：玻璃带与下沿外推必须与浅色一致',
    );
  });

  testWidgets('平台不支持：带不画，下沿也不画（真实判据，不顶 override）', (tester) async {
    // 宿主是 Windows：清掉 override 后 `liveBlurSupported` 恒 false，
    // 深浅色都不画带 —— 平台门禁是深浅色共用的最后一道。
    HyperosBlurredHeader.bandOverhangsOverride = null;
    HyperosBlurredHeader.liveBlurSupportedOverride = null;
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
