import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart' show MiuixGlassPopupAnchor;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show AdaptiveGlass, LightweightLiquidGlass;
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart'
    show HyperosLiquidGlassSurface, UndimmedBackdropCapture;
import 'package:university_timetable/widgets/home_top_menu.dart';
import 'package:university_timetable/widgets/home_top_menu_popup.dart';

import '../../helpers_test_app.dart';

/// 与 hyperos_list_popup.dart 的 _panelReplayShrink 同值：测试里直接
/// 复算回放终值（源文件里是私有常量）。
const _panelReplayShrinkForTest = 0.05;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 高斯磨砂定值外观：测试环境无真实玻璃采样，固定参数保证确定性。
  const gaussianAppearance = FrostedAppearance(
    sheetBlurSigma: 15,
    sheetTintAlpha: 0.7,
    sheetBarrierAlpha: 0.2,
    glassMode: FrostedGlassMode.gaussian,
  );

  // 液态玻璃外观：用于验证共享组捕获垫层随液态子卡一起挂载（测试机
  // 无 shader，液态面自动走包内轻量回退，不影响树结构断言）。
  const liquidAppearance = FrostedAppearance(
    sheetBlurSigma: 15,
    sheetTintAlpha: 0.7,
    sheetBarrierAlpha: 0.2,
    glassMode: FrostedGlassMode.liquidGlass,
  );

  group('hyperos list popup submenu', () {
    const items = [
      HyperosPopupMenuItem(label: '普通项', value: 'a'),
      HyperosPopupMenuItem(
        label: '视图父项',
        value: 'parent',
        children: [
          HyperosPopupMenuItem(label: '子项一', value: 'child:1'),
          HyperosPopupMenuItem(label: '子项二', value: 'child:2'),
        ],
      ),
      HyperosPopupMenuItem(label: '尾项', value: 'c'),
    ];

    // 打开弹窗并收集它的回传 Future。注意：返回的是「装 Future 的列表」
    // 而非 Future 本身——async 函数 return Future 会被 Dart 自动 flatten
    // （内部隐式 await），而弹窗 result 只有关闭时才完成，测试体没关弹窗
    // 就会永久挂起。
    Future<List<Future<String?>?>> pumpPopup(
      WidgetTester tester, {
      required List<HyperosPopupMenuItem<String>> items,
      FrostedAppearance appearance = gaussianAppearance,
    }) async {
      final opened = <Future<String?>?>[];
      final host = FrostedAppearanceScope(
        appearance: appearance,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              opened.add(
                showHyperosListPopup<String>(
                  context: context,
                  position: const RelativeRect.fromLTRB(200, 80, 24, 200),
                  items: items,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.pumpWidget(TestApp(home: host));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('收起态只显示父行与右向箭头，子行不可见', (tester) async {
      await pumpPopup(tester, items: items);

      expect(find.text('视图父项'), findsOneWidget);
      expect(find.text('子项一'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0,
      );
    });

    testWidgets('点父行浮出二级列表（父行在卡内原位重复），再点收起且弹窗不关', (tester) async {
      await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      // 浮层卡里父行原样重复 + 两个子行都可见。
      expect(find.text('视图父项'), findsNWidgets(2));
      expect(find.text('子项一'), findsOneWidget);
      expect(find.text('子项二'), findsOneWidget);
      // 展开态箭头翻转为朝上（-90°），主面板行与卡内行同步。
      for (final rotation in tester.widgetList<AnimatedRotation>(
        find.byType(AnimatedRotation),
      )) {
        expect(rotation.turns, closeTo(-0.25, 0.0001));
      }

      // 主面板父行与卡内父行同位（卡片锚定在父行原位），点哪个都收起。
      await tester.tap(find.text('视图父项').first);
      await tester.pumpAndSettle();

      expect(find.text('子项一'), findsNothing);
      // 弹窗仍开着（父行点按是展开开关，不回传不关闭）。
      expect(find.text('普通项'), findsOneWidget);
    });

    testWidgets('点子行立即回传子项 value 关闭弹窗', (tester) async {
      final opened = await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('子项二'));
      await tester.pump();
      expect(await opened.single, 'child:2');
      expect(find.text('普通项'), findsNothing);
    });

    testWidgets('展开态点主面板暗区只收起子列表，弹窗不关', (tester) async {
      await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();
      expect(find.text('子项一'), findsOneWidget);

      // 「普通项」行在父行上方、被暗层覆盖：点它=收起。
      await tester.tap(find.text('普通项'));
      await tester.pumpAndSettle();

      expect(find.text('子项一'), findsNothing);
      expect(find.text('普通项'), findsOneWidget);
    });

    testWidgets('展开态按返回键先收子列表，再按才关弹窗', (tester) async {
      await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('子项一'), findsNothing);
      expect(find.text('普通项'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('普通项'), findsNothing);
    });

    testWidgets('展开态点面板外遮罩整窗关闭', (tester) async {
      await pumpPopup(tester, items: items);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      // 面板右对齐（x≈412..776、y≈80..248），左下角远端必在遮罩上。
      await tester.tapAt(const Offset(30, 520));
      await tester.pumpAndSettle();

      expect(find.text('普通项'), findsNothing);
      expect(find.text('视图父项'), findsNothing);
    });

    testWidgets('首次展开首帧：卡宽与面板同宽（紧约束），揭示窗盒同宽', (
      tester,
    ) async {
      // 首次展开的子卡构建期面板渲染对象尚未 layout（重挂当帧
      // hasSize=false），宽度曾回退松约束 200..364——真机液态路径下首帧
      // 卡身被拉到上界附近，顶缘揭示带横贯大半屏幕（用户描述「闪现横条
      // 到左边，左边剩余空隙与二级右侧空隙一样」）；再展开时宽度已缓存
      // 故不闪。回归锁：面板宽度在弹窗打开当帧预热缓存后，首帧卡宽与
      // 揭示窗盒宽都必须等于面板宽。
      await pumpPopup(tester, items: items, appearance: liquidAppearance);

      await tester.tap(find.text('视图父项'));
      await tester.pump(); // 展开首帧（构建 + 市局 + 绘制）

      final glass = tester.renderObject<RenderBox>(
        find.byType(HyperosSelectPopupGlass).last,
      );
      final windowFinder = find.ancestor(
        of: find.byType(HyperosSelectPopupGlass).last,
        matching: find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is SelectPopupRevealClipper,
        ),
      ).first;
      final window = tester.renderObject<RenderBox>(windowFinder);
      expect(window.size.width, closeTo(glass.size.width, 0.5));

      await tester.pump(const Duration(milliseconds: 60)); // 动画中段
      // 揭示窗盒子全程与玻璃面同宽同高（玻璃不溢出不重采样）。
      expect(
        tester.renderObject<RenderBox>(windowFinder).size,
        glass.size,
      );

      await tester.pumpAndSettle();
      final settled = tester.renderObject<RenderBox>(
        find.byType(HyperosSelectPopupGlass).last,
      );
      expect(settled.size.height, glass.size.height);
    });

    testWidgets('有二级子项的弹窗挂共享组捕获垫层，子卡取遮罩下页面', (
      tester,
    ) async {
      // 液态外观下子卡走「共享组磨砂底 + premium 液态面」路径，垫层随
      // 弹窗挂载（高斯/实底环境无 grouped 消费者，不插，见
      // liquid_glass_consistency_test 的无冗余垫层断言）。垫底必须是
      // **实时合成器捕获**：曾经那种「整页同步快照」垫底会让子卡变成
      // 一张跟着卡片走的静态照片。
      await pumpPopup(
        tester,
        items: items,
        appearance: liquidAppearance,
      );

      expect(find.byType(UndimmedBackdropCapture), findsOneWidget);
      expect(find.text('普通项'), findsOneWidget);

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      // Stack 里主面板在前、浮层卡在后：.last 是子卡，必须取共享组垫底。
      final glasses = tester
          .widgetList<HyperosSelectPopupGlass>(
            find.byType(HyperosSelectPopupGlass),
          )
          .toList();
      expect(glasses.length, 2);
      expect(glasses.first.useAncestorGroupCapture, isFalse);
      expect(glasses.last.useAncestorGroupCapture, isTrue);
    });

    testWidgets('弹窗与顶栏/玻璃坞同一条渲染路径（无抓拍纹理、无快照垫底）', (
      tester,
    ) async {
      // 回归锁：弹窗液态面走 AdaptiveGlass（premium 实时读底面），与顶栏带、
      // 玻璃坞、卡片同一个组件同一条路。曾经它有两条歧路：①传 backgroundKey
      // 走抓拍纹理通道——玻璃里是一张静态照片（ticker 只在几何变化时重拍、
      // 稳定后停摆），展开时照片跟着卡片走；②单独开 premium 档——于是同一个
      // 材质出现「顶栏一种观感、弹窗另一种观感」。两条都已删除。
      await pumpPopup(
        tester,
        items: items,
        appearance: liquidAppearance,
      );

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      // 主面板 + 子卡都走同一条路。
      expect(find.byType(HyperosLiquidGlassSurface), findsNWidgets(2));
      expect(find.byType(AdaptiveGlass), findsNWidgets(2));
      // 抓拍纹理通道入口（LightweightLiquidGlass）已从组件上删除。
      expect(find.byType(LightweightLiquidGlass), findsNothing);
    });

    testWidgets('无二级子项的弹窗不挂捕获垫层', (tester) async {
      await pumpPopup(
        tester,
        items: const [
          HyperosPopupMenuItem(label: '普通项', value: 'a'),
          HyperosPopupMenuItem(label: '尾项', value: 'c'),
        ],
        appearance: liquidAppearance,
      );

      expect(find.byType(UndimmedBackdropCapture), findsNothing);
    });

    testWidgets('二级展开时主面板沿锚点角水平回放缩小，收起复原', (tester) async {
      await pumpPopup(tester, items: items);

      final panelScaleFinder = find.byWidgetPredicate(
        (w) => w is Transform && w.child is KeyedSubtree,
      );
      // 收起态主面板满尺寸（弹出弹簧已 settle；弹簧容差内有浮点尾数）。
      double panelScale() => tester
          .widget<Transform>(panelScaleFinder)
          .transform
          .storage[0];
      expect(panelScale(), closeTo(1.0, 0.0001));

      await tester.tap(find.text('视图父项'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60)); // 动画中段
      final midScale = panelScale();
      expect(midScale, lessThan(1.0));
      expect(midScale, greaterThan(0.9));

      await tester.pumpAndSettle();
      // 展开态面板停在回放后的尺寸（让位给子卡，直到收起才复原）。
      expect(panelScale(), closeTo(1 - _panelReplayShrinkForTest, 0.001));

      // 再点父行收起后复原（回放随 _expand 逆放）。
      await tester.tap(find.text('视图父项').first);
      await tester.pumpAndSettle();
      expect(panelScale(), closeTo(1.0, 0.0001));
    });

    testWidgets('长菜单滚动后展开：卡内父行与面板父行同位', (tester) async {
      // 展开会重挂面板玻璃（_expandSession），滚动位置曾随之静默丢回 0，
      // 浮层卡按「展开瞬间应停的位置」锚定——重挂后两处父行各说各话。
      // 回归锁：展开后卡内父行副本必须与面板父行逐像素同位。
      tester.view.physicalSize = const Size(1260, 1200); // 420×400 逻辑
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final longItems = <HyperosPopupMenuItem<String>>[
        const HyperosPopupMenuItem(label: '首项', value: 'first'),
        const HyperosPopupMenuItem(
          label: '视图父项',
          value: 'parent',
          children: [
            HyperosPopupMenuItem(label: '子项一', value: 'child:1'),
            HyperosPopupMenuItem(label: '子项二', value: 'child:2'),
          ],
        ),
        for (var i = 0; i < 12; i++)
          HyperosPopupMenuItem(label: '填充项$i', value: 'fill:$i'),
      ];

      await pumpPopup(tester, items: longItems);

      // 面板可滚动（14 行 ≈ 784 高 > 视口 308）：下滚 60 让父行贴视口上部。
      await tester.drag(find.text('首项'), const Offset(0, -60));
      await tester.pumpAndSettle();

      // 展开前记录父行位置与滚动偏移。浮层卡接管的是父行「展开瞬间的
      // 原位」——展开后面板向锚点角回放缩放 0.95、父行视觉后退属于让位
      // 设计，缩放后的面板行不能当基准。滚动偏移必须跨重挂保留。
      final rowBefore = tester.getRect(find.text('视图父项').first);
      double scrollOffset() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first)
              .position.pixels;
      final offsetBefore = scrollOffset();

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      expect(scrollOffset(), closeTo(offsetBefore, 0.5));
      // Stack 里主面板在前、浮层卡在后：.last 是卡内父行副本。
      final cardRow = tester.getRect(find.text('视图父项').last);
      expect(cardRow.left, closeTo(rowBefore.left, 0.5));
      expect(cardRow.top, closeTo(rowBefore.top, 0.5));
    });

    testWidgets('卡高超过安全区时收缩卡高，不溢出屏底', (tester) async {
      // _submenuCardTopGlobal 的 max(safeTop, maxTop) 在「卡高 > 可用高」
      // 时把卡推回 safeTop，底部照旧溢出。回归锁：卡必须整体落在安全区
      // 内（超高时收缩自身高度，子项改为卡内滚动）。
      tester.view.physicalSize = const Size(1260, 1080); // 420×360 逻辑
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final tallItems = <HyperosPopupMenuItem<String>>[
        HyperosPopupMenuItem(
          label: '视图父项',
          value: 'parent',
          children: [
            for (var i = 0; i < 6; i++)
              HyperosPopupMenuItem(label: '子项$i', value: 'child:$i'),
          ],
        ),
      ];

      await pumpPopup(tester, items: tallItems);
      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      // 未收缩卡高 = 7 行 × 56 + 分隔块 ≈ 400.75，安全区只有 336。
      final cardRect = tester.getRect(
        find
            .ancestor(
              of: find.text('子项0'),
              matching: find.byWidgetPredicate(
                (w) => w is ClipPath && w.clipper is SelectPopupRevealClipper,
              ),
            )
            .first,
      );
      const safeTop = 12.0;
      const safeBottom = 360.0 - 12.0;
      expect(cardRect.top, greaterThanOrEqualTo(safeTop - 0.1));
      expect(cardRect.bottom, lessThanOrEqualTo(safeBottom + 0.1));
      expect(cardRect.height, lessThanOrEqualTo(safeBottom - safeTop + 0.1));
    });
  });

  group('home top menu add-course submenu wiring', () {
    // 2026-09-13：首页菜单的列表形态迁到上游 OS4 玻璃弹层后，旧的
    // `showHomeTopMenuSheet`（自研列表弹层）已删除。本组改为驱动现役实现
    // `HomeTopMenuPopup`，保住「『添加』行 → 二级面板 → 回传子项 id」这条
    // 唯一的覆盖 —— 此前它只测在已删除的实现上，属「测试护空」。
    final entries = [
      HomeMenuEntry(
        id: 'addCourse',
        title: (l10n) => l10n.homeMenuAddCourseTitle,
        icon: Icons.add_circle_outline_rounded,
        category: HomeMenuEntryCategory.features,
        open: (_) async {},
      ),
      HomeMenuEntry(
        id: 'settings',
        title: (l10n) => l10n.homeMenuSettingsTitle,
        icon: Icons.tune_rounded,
        category: HomeMenuEntryCategory.preferences,
        open: (_) async {},
      ),
    ];

    /// 上游契约是「常驻挂载 + 切 show」，所以这里直接以 show: true 挂载；
    /// 返回被点条目的 id 收集器。
    Future<List<String>> pumpMenu(WidgetTester tester) async {
      final selected = <String>[];
      final anchor = MiuixGlassPopupAnchor();
      addTearDown(anchor.dispose);
      await tester.pumpWidget(
        TestApp(
          home: HomeTopMenuPopup(
            show: true,
            anchor: anchor,
            anchorContent: const Icon(Icons.more_vert_rounded),
            entries: entries,
            hasAvailableUpdate: false,
            onDismissRequest: () {},
            onSelected: selected.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return selected;
    }

    testWidgets('「添加」行挂二级列表，其余行没有二级', (tester) async {
      await pumpMenu(tester);

      expect(find.text('添加'), findsOneWidget);
      expect(find.text('课表设置'), findsOneWidget);
      // 收起态：二级子项都不在树上。
      expect(find.text('添加课程'), findsNothing);
      expect(find.text('添加日程'), findsNothing);
      expect(find.text('添加考试'), findsNothing);

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      expect(find.text('添加课程'), findsOneWidget);
      expect(find.text('添加日程'), findsOneWidget);
      expect(find.text('添加考试'), findsOneWidget);
      // 一级面板不因二级展开而消失。
      expect(find.text('课表设置'), findsOneWidget);
    });

    testWidgets('点「添加考试」子项回传宿主分发 id', (tester) async {
      final selected = await pumpMenu(tester);

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加考试'));
      await tester.pumpAndSettle();

      expect(selected, [kAddCourseSubmenuExamId]);
    });
  });
}
