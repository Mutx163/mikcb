import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart'
    show
        MiuixGlassAnchor,
        MiuixGlassPopupAnchor,
        MiuixGlassSecondaryPopup,
        MiuixGlassTransformPopup;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurface, UndimmedBackdropCapture;
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

    testWidgets('首次展开首帧：卡宽与面板同宽（紧约束），全程布局尺寸不变', (
      tester,
    ) async {
      // 首次展开的子卡构建期面板渲染对象尚未 layout（重挂当帧
      // hasSize=false），宽度曾回退松约束 200..364——真机液态路径下首帧
      // 卡身被拉到上界附近，顶缘折射带横贯大半屏幕（用户描述「闪现横条
      // 到左边，左边剩余空隙与二级右侧空隙一样」）；再展开时宽度已缓存
      // 故不闪。回归锁：面板宽度在弹窗打开当帧预热缓存后，首帧卡宽与外
      // 层盒宽必须都等于面板宽。
      //
      // 外层动画不再用揭示裁剪（裁剪会收缩实时背景的采样范围，见
      // hyperos_list_popup.dart 的注释），改成 Transform.scale：缩放只影响
      // 绘制、不改布局，所以这里锁的是「玻璃面布局尺寸全程不变」——
      // 一旦有谁把动画改成逐帧改玻璃尺寸，就会逐帧重采样，这条会红。
      await pumpPopup(tester, items: items, appearance: liquidAppearance);

      await tester.tap(find.text('视图父项'));
      await tester.pump(); // 展开首帧（构建 + 布局 + 绘制）

      final glass = tester.renderObject<RenderBox>(
        find.byType(HyperosSelectPopupGlass).last,
      );
      final boxFinder = find
          .ancestor(
            of: find.byType(HyperosSelectPopupGlass).last,
            matching: find.byWidgetPredicate((w) => w is Transform),
          )
          .first;
      final box = tester.renderObject<RenderBox>(boxFinder);
      expect(box.size.width, closeTo(glass.size.width, 0.5));

      await tester.pump(const Duration(milliseconds: 60)); // 动画中段
      // 外层盒全程与玻璃面同尺寸（玻璃不溢出不重采样）。
      expect(tester.renderObject<RenderBox>(boxFinder).size, glass.size);

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

    testWidgets('弹窗与顶栏/玻璃坞同一个玻璃表面组件', (tester) async {
      // 回归锁：弹窗液态面走 [LiquidGlassSurface]（全 app 唯一的玻璃表面
      // 组件），与顶栏带、玻璃坞、课程卡片同一条路。曾经它有两条歧路：
      // ①传 backgroundKey 走抓拍纹理通道——玻璃里是一张静态照片（ticker
      // 只在几何变化时重拍、稳定后停摆），展开时照片跟着卡片走；②按表面
      // 单独分档——于是同一个材质出现「顶栏一种观感、弹窗另一种观感」。
      // 两条路与它们依赖的第三方包都已删除。
      await pumpPopup(
        tester,
        items: items,
        appearance: liquidAppearance,
      );

      await tester.tap(find.text('视图父项'));
      await tester.pumpAndSettle();

      // 主面板 + 子卡都走同一个表面组件。
      expect(find.byType(LiquidGlassSurface), findsNWidgets(2));
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
      // 量玻璃面本身（展开结束后 scale 已到 1，与布局矩形一致）。
      final cardRect = tester.getRect(
        find.byType(HyperosSelectPopupGlass).last,
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
      // 下面两行是"垫高"用的占位：二级面板（标题行 + 3 个子项）比一级高，
      // 一级必须更高才会露出「二级之外的一级区域」—— 那条交互要靠它们才能测。
      HomeMenuEntry(
        id: 'fillerStats',
        title: (l10n) => '占位甲',
        icon: Icons.bar_chart_rounded,
        category: HomeMenuEntryCategory.preferences,
        open: (_) async {},
      ),
      HomeMenuEntry(
        id: 'fillerFocus',
        title: (l10n) => '占位乙',
        icon: Icons.timer_outlined,
        category: HomeMenuEntryCategory.preferences,
        open: (_) async {},
      ),
      HomeMenuEntry(
        id: 'fillerMisc',
        title: (l10n) => '占位丙',
        icon: Icons.auto_awesome_outlined,
        category: HomeMenuEntryCategory.preferences,
        open: (_) async {},
      ),
      HomeMenuEntry(
        id: 'fillerAbout',
        title: (l10n) => '占位丁',
        icon: Icons.info_outline_rounded,
        category: HomeMenuEntryCategory.preferences,
        open: (_) async {},
      ),
    ];

    /// 上游契约是「常驻挂载 + 切 show」；这里用 [ValueNotifier] 驱动 show，并收集
    /// 被点条目 id 与菜单关闭次数 —— 返回键 / 遮罩那两条用例要观测「关没关」。
    Future<
      ({List<String> selected, ValueNotifier<bool> show, List<int> dismisses})
    >
    pumpMenu(WidgetTester tester) async {
      final selected = <String>[];
      final dismisses = <int>[];
      final show = ValueNotifier<bool>(true);
      final anchor = MiuixGlassPopupAnchor();
      addTearDown(anchor.dispose);
      addTearDown(show.dispose);
      await tester.pumpWidget(
        TestApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (context, visible, _) => HomeTopMenuPopup(
              show: visible,
              anchor: anchor,
              anchorContent: const Icon(Icons.more_vert_rounded),
              entries: entries,
              hasAvailableUpdate: false,
              onDismissRequest: () {
                dismisses.add(1);
                show.value = false;
              },
              onSelected: selected.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (selected: selected, show: show, dismisses: dismisses);
    }

    /// 一级面板当前的让位缩放。缩放写在 render object 的 paint transform 里
    /// （树上没有 Transform widget，抄不了列表弹层那套 `byWidgetPredicate`），
    /// 所以从内容子树的全局变换矩阵读：settle 后 contentScale = 1，storage[0]
    /// 就是 `1 - 0.05 * 让位进度`。
    double panelScale(WidgetTester tester) => tester
        .renderObject<RenderBox>(find.text('课表设置'))
        .getTransformTo(null)
        .storage[0];

    /// 面板**轮廓**（卡片本身）的绘制矩形 —— 与 [panelScale] 读的是同一棵子树
    /// 的两个不同层：让位只缩内容时，内容那边是 0.95、轮廓这边原地不动。
    ///
    /// 注入面是 [HyperosSelectPopupGlass]，一级 / 二级靠 `useAncestorGroupCapture`
    /// 区分（只有二级会进祖先共享捕获组）。
    Finder panelSurface({required bool secondary}) => find.byWidgetPredicate(
      (w) =>
          w is HyperosSelectPopupGlass && w.useAncestorGroupCapture == secondary,
    );

    testWidgets('「添加」行挂二级列表，其余行没有二级', (tester) async {
      await pumpMenu(tester);

      expect(find.text('添加'), findsOneWidget);
      expect(find.text('课表设置'), findsOneWidget);
      // 收起态：二级子项都不在树上；箭头朝右；一级面板不缩放。
      expect(find.text('添加课程'), findsNothing);
      expect(find.text('添加日程'), findsNothing);
      expect(find.text('添加考试'), findsNothing);
      for (final arrow in tester.widgetList<AnimatedRotation>(
        find.byType(AnimatedRotation),
      )) {
        expect(arrow.turns, 0);
      }
      expect(panelScale(tester), closeTo(1, 2e-3));

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      expect(find.text('添加课程'), findsOneWidget);
      expect(find.text('添加日程'), findsOneWidget);
      expect(find.text('添加考试'), findsOneWidget);
      // 一级面板不因二级展开而消失。
      expect(find.text('课表设置'), findsOneWidget);
      // 标题行 = 一级那一行在二级面板顶部的原位重复（同款条目），两份同时可见。
      expect(find.text('添加'), findsNWidgets(2));
      // 展开态两处箭头都朝上（-90° = -0.25 圈）：一级那一行 + 标题行。
      final arrows = tester
          .widgetList<AnimatedRotation>(find.byType(AnimatedRotation))
          .toList();
      expect(arrows, hasLength(2));
      for (final arrow in arrows) {
        expect(arrow.turns, closeTo(-0.25, 1e-4));
      }
      // 一级面板让位缩小 5%（绕锚点角 → 读起来是"原地缩小"）。
      expect(panelScale(tester), closeTo(0.95, 2e-3));
    });

    testWidgets('两块面板同处一个共享捕获组，垫底滤镜排在一级面板之前', (tester) async {
      // 二级面板的注入面是 `useAncestorGroupCapture: true`（液态面 `grouped`）——
      // 它全部的意义就是「**别采一级面板的玻璃输出**，改采组里缓存的那份页面」。
      // 而 `grouped` 只是「去祖先 BackdropGroup 取共享捕获点」：**组里没有别的
      // 滤镜时它什么也取不到**，引擎于是退回「按绘制顺序采自己下面那一层」，
      // 二级卡片里就会重影出一级卡片 —— 用户 2026-09-20 读到的「同时显示了收缩
      // 和未收缩的两个一级卡片，缩放后的显示在上面」。
      //
      // 首页菜单从上游 OS4 弹层迁过来时漏了这一层（本仓其余弹层：列表弹窗 /
      // 选择弹窗 / 底部弹窗 / 设置页预览各有一份同构结构）。测试环境没有 shader
      // 后端、玻璃走降级面，这条锁的是**结构契约**：
      // ①两块面板都有 BackdropGroup 祖先；②组内第一个滤镜是垫底捕获。
      await pumpMenu(tester);

      final group = find.byType(BackdropGroup);
      expect(group, findsOneWidget, reason: '弹层必须自带共享捕获组');
      expect(
        find.ancestor(
          of: find.byType(MiuixGlassTransformPopup),
          matching: group,
        ),
        findsOneWidget,
        reason: '一级面板必须进共享捕获组',
      );

      // 垫底只在二级会挂出来时才插（那层是全屏 pass，没二级不白付）。
      expect(find.byType(UndimmedBackdropCapture), findsNothing);

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      expect(find.byType(UndimmedBackdropCapture), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(MiuixGlassSecondaryPopup),
          matching: group,
        ),
        findsOneWidget,
        reason: '二级面板必须与一级同组：它的 grouped 采样靠这个组才生效',
      );
      // 组内**首个**滤镜决定共享捕获点落在哪：排在面板之后就成了「采面板自己」，
      // 与没有组一样。所以位置（不是存在与否）才是这条的关键。
      final stack = tester.widget<Stack>(
        find
            .descendant(of: group, matching: find.byType(Stack))
            .first,
      );
      final captureIndex = stack.children.indexWhere(
        (w) => w is Positioned && w.child is UndimmedBackdropCapture,
      );
      final primaryIndex = stack.children.indexWhere(
        (w) => w is MiuixGlassTransformPopup,
      );
      expect(captureIndex, isNonNegative, reason: '垫底必须在组内 Stack 里');
      expect(
        primaryIndex,
        greaterThan(captureIndex),
        reason: '垫底必须排在**一级面板之前**，否则捕获点是面板自己',
      );
    });

    testWidgets('让位：只有一级缩，二级不缩；被点那一行在屏幕上原地不动', (tester) async {
      // 用户口径（2026-09-21）：「二级弹出时被点的那一行不缩放、不变，只向下展开；
      // 二级卡片不缩；只有一级卡片向右缩一点」—— 就是已发布预发布版 v2.1.2.3 的
      // 观感。本仓一度给二级补过整族让位参数、让两块卡绕同一点一起缩（把左边缘
      // 那条 10px 的缝归零，见 archived/bug-fix/2026-09-20-home-menu-both-panels-
      // share-stack-pivot.md），用户否掉：二级跟着缩会让它的行文字一起小 5%，而
      // **被点那一行的「复印件」正是二级的标题行** —— 二级一缩，读起来就成了
      // 「被点的按钮在缩放、在挪」。
      //
      // 所以这里量四件事：①一级整张卡缩；②二级卡一点都不缩（宽度、位置保持）；
      // ③两块卡的左边缘因此错开 5% 板宽 —— 这条缝用户明确选择接受，不是回归；
      // ④被点那一行在屏幕上不动（一级那份缩进二级卡背后，二级的标题行顶在原位）。
      await pumpMenu(tester);

      final outlineClosed = tester.getRect(panelSurface(secondary: false));
      final rowClosed = tester.getRect(find.text('添加'));

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // ①一级内容与轮廓都缩 5%（只缩内容那条路被用户否掉过）。
      expect(panelScale(tester), closeTo(0.95, 2e-3));
      final outline = tester.getRect(panelSurface(secondary: false));
      expect(outline.right, closeTo(outlineClosed.right, .5));
      expect(outline.top, closeTo(outlineClosed.top, .5));
      expect(
        outline.left - outlineClosed.left,
        closeTo(outlineClosed.width * .05, .5),
        reason: '卡片轮廓必须跟着缩（只缩内容是用户否掉过的路）',
      );
      expect(
        outlineClosed.bottom - outline.bottom,
        closeTo(outlineClosed.height * .05, .5),
      );

      // ②二级卡一片都不缩：宽度与位置与收起态的一级卡完全一致。
      // 实测：二级卡宽 200.00（收起态一级卡量到 199.96 —— 出场弹簧收敛在 1 之前
      // 的那点残差，差 0.04px）。
      final secondary = tester.getRect(panelSurface(secondary: true));
      expect(
        secondary.width,
        closeTo(outlineClosed.width, .5),
        reason: '二级不参与让位：它一格都不缩，行文字保持原字号',
      );
      expect(secondary.right, closeTo(outlineClosed.right, .5));
      expect(secondary.left, closeTo(outlineClosed.left, .5));

      // ③接缝：一级缩了、二级没缩，两块卡的左边缘就差 5% 板宽。
      // 实测 -9.96px（= 5% × 200 板宽 = 10px，减去上面那 0.04px 残差）。这条是
      // 本次口径的**已知代价**（用户拍板接受），别当成待修的缺陷。
      expect(
        secondary.left - outline.left,
        closeTo(-outlineClosed.width * .05, .5),
        reason: '二级不缩 → 左边缘错开 10px，用户已选择接受这条缝',
      );

      // ④被点那一行在屏幕上没动：二级的标题行（浮在上面、可见的那份）与它收起
      // 态时的矩形重合（实测 x 差 0.004px、y 差 0.002px，都来自入场弹簧收敛在 1
      // 之前那点残差）；一级那份缩过、往右收进二级卡背后，不再是可见的那份。
      final titleRow = tester.getRect(find.text('添加').last);
      expect(titleRow.left, closeTo(rowClosed.left, 1));
      expect(titleRow.top, closeTo(rowClosed.top, 1));
      expect(
        tester.getRect(find.text('添加').first).left,
        greaterThan(rowClosed.left + 5),
        reason: '一级那份是缩过、被二级卡盖住的那份',
      );
    });

    testWidgets('点二级标题行只收起二级、不关菜单，一级缩放复原', (tester) async {
      final menu = await pumpMenu(tester);

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(panelScale(tester), closeTo(0.95, 2e-3));

      // 标题行是两份「添加」里的最后一份（一级那一行在前）。
      await tester.tap(find.text('添加').last);
      await tester.pumpAndSettle();

      expect(find.text('添加课程'), findsNothing);
      expect(find.text('添加'), findsOneWidget);
      expect(find.text('课表设置'), findsOneWidget);
      expect(menu.dismisses, isEmpty, reason: '点标题行只收二级，不关整个菜单');
      expect(panelScale(tester), closeTo(1, 2e-3));
    });

    testWidgets('点「添加考试」子项回传宿主分发 id', (tester) async {
      final menu = await pumpMenu(tester);

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加考试'));
      await tester.pumpAndSettle();

      expect(menu.selected, [kAddCourseSubmenuExamId]);
    });

    testWidgets('返回键：先收二级，再按才关菜单', (tester) async {
      final menu = await pumpMenu(tester);

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('添加课程'), findsNothing);
      expect(find.text('课表设置'), findsOneWidget);
      expect(menu.dismisses, isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(menu.dismisses, isNotEmpty);
      expect(find.text('课表设置'), findsNothing);
    });

    testWidgets('二级展开时：点一级面板只收二级，点两个面板之外才关整窗', (tester) async {
      final menu = await pumpMenu(tester);

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(find.text('添加课程'), findsOneWidget);

      // 一级面板比二级高：最下面那行（占位丁）在二级面板下方、仍然可见可点。
      final outsideSecondary = tester.getCenter(find.text('占位丁'));
      final secondaryBottom = tester
          .getRect(find.byType(MiuixGlassSecondaryPopup))
          .bottom;
      expect(
        outsideSecondary.dy,
        greaterThan(secondaryBottom),
        reason: '落点必须在二级面板之外，否则这条用例测不到分区逻辑',
      );

      await tester.tapAt(outsideSecondary);
      await tester.pumpAndSettle();

      expect(find.text('添加课程'), findsNothing, reason: '二级应收起');
      expect(
        menu.dismisses,
        isEmpty,
        reason: '点一级面板（二级之外）只收二级，不该关整窗',
      );
      expect(find.text('占位丁'), findsOneWidget, reason: '一级菜单仍在');

      // 再展开一次，点两个面板之外 → 这时才关整窗。
      await tester.tap(find.text('添加').first);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(30, 520));
      await tester.pumpAndSettle();

      expect(menu.dismisses, isNotEmpty, reason: '面板外才关整窗');
      expect(find.text('占位丁'), findsNothing);
    });

    testWidgets('二级展开时一级面板是压暗（暗罩），不是上游亮色默认的白罩', (tester) async {
      await pumpMenu(tester);

      final mask = tester
          .widget<MiuixGlassTransformPopup>(
            find.byType(MiuixGlassTransformPopup),
          )
          .maskColor;
      expect(mask, isNotNull);
      expect(
        mask!.computeLuminance(),
        lessThan(0.2),
        reason: '上游默认亮色主题用白罩（alpha .4），二级展开时一级会反而变亮',
      );
    });

    testWidgets('点面板外遮罩整个菜单关闭（不是只收二级）', (tester) async {
      final menu = await pumpMenu(tester);

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // 面板居屏幕中部（锚点未绑定，宽 200），左下角远端必在遮罩上。
      await tester.tapAt(const Offset(30, 520));
      await tester.pumpAndSettle();

      expect(menu.dismisses, isNotEmpty);
      expect(find.text('课表设置'), findsNothing);
    });

    testWidgets('收起动画期间点击穿透到页面（关掉后立刻再点不会丢）', (tester) async {
      var pageTaps = 0;
      final show = ValueNotifier<bool>(true);
      final anchor = MiuixGlassPopupAnchor();
      addTearDown(show.dispose);
      addTearDown(anchor.dispose);
      await tester.pumpWidget(
        TestApp(
          home: Stack(
            children: [
              // 页面本体（弹层开着时被遮罩盖住）：整屏点击区，用来观测
              // "这一下有没有穿透下来"。
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => pageTaps++,
                child: const SizedBox.expand(),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: show,
                builder: (context, visible, _) => HomeTopMenuPopup(
                  show: visible,
                  anchor: anchor,
                  anchorContent: const Icon(Icons.more_vert_rounded),
                  entries: entries,
                  hasAvailableUpdate: false,
                  onDismissRequest: () => show.value = false,
                  onSelected: (_) {},
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点空白关掉：这一下属于遮罩，页面不该收到。
      await tester.tapAt(const Offset(30, 520));
      await tester.pump();
      expect(show.value, isFalse, reason: '遮罩点击应先请求关闭');
      expect(pageTaps, 0, reason: '这一下仍属于遮罩，不该穿透');

      // 收起动画跑完前再点同一位置：必须穿透到页面。旧实现在这段窗口里遮罩
      // 还在最上层且 opaque，会把这一下吃掉（去重后什么也不做）—— 用户读到的
      // 就是"关掉后立刻再点没反应、等一会儿才灵"。
      await tester.tapAt(const Offset(30, 520));
      await tester.pump();
      expect(pageTaps, 1, reason: '收起期点击必须穿透，不能吞掉重开那一下');

      await tester.pumpAndSettle();
    });

    testWidgets('开合首帧：注入面的圆角必须是「锚点短边一半」（面板从正圆长出来）', (
      tester,
    ) async {
      // 形变动效的几何由上游算好（圆角每帧从「按钮短边一半」lerp 到面板圆角），
      // 注入面必须直接用这个值。若首帧拿到的是面板圆角（或 0），面板会以方角
      // 出现 —— 真机读起来就是"点击放大的那一刻，圆圈外面露出正方形的白边"。
      final controller = HyperosGlassBackdropController();
      addTearDown(controller.dispose);
      final anchor = MiuixGlassPopupAnchor();
      addTearDown(anchor.dispose);
      final show = ValueNotifier<bool>(false);
      addTearDown(show.dispose);

      await tester.pumpWidget(
        TestApp(
          home: HyperosGlassBackdropHost(
            controller: controller,
            child: Stack(
              children: [
                // 真实触发控件：40×40（上游图标按钮的最小边长）。
                MiuixGlassAnchor(
                  anchor: anchor,
                  child: const SizedBox(
                    key: ValueKey('home-more-button'),
                    width: 40,
                    height: 40,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: show,
                  builder: (context, visible, _) => HomeTopMenuPopup(
                    show: visible,
                    anchor: anchor,
                    anchorContent: const Icon(Icons.more_vert_rounded),
                    entries: entries,
                    hasAvailableUpdate: false,
                    onDismissRequest: () => show.value = false,
                    onSelected: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      show.value = true;
      // 第 1 帧：OverlayPortal 才把覆盖层挂上；第 2 帧才是面板的第一帧
      // （此时进度 ≈ 0，面板应当还是一个正圆）。
      await tester.pump();
      await tester.pump();
      final openingRadius = tester
          .widget<HyperosSelectPopupGlass>(
            find.descendant(
              of: find.byType(MiuixGlassTransformPopup),
              matching: find.byType(HyperosSelectPopupGlass),
            ),
          )
          .cornerRadius;
      expect(
        openingRadius,
        closeTo(20, 0.01),
        reason: '40×40 锚点 ⇒ 首帧圆角应为 20（正圆），不是面板圆角',
      );

      // 注：只探测首帧 —— 这一条就是"方块 vs 圆圈"的判据。展开后的材料会随
      // 全局档位在柔光 / 液态 / 高斯分支间分派，不再在这里断言。
      await tester.pumpAndSettle(); // 让形变动画跑完，避免留下未完成的计时器
    });

    testWidgets('首页菜单不再请求整层快照（注入面只读采样区）', (tester) async {
      final controller = HyperosGlassBackdropController();
      addTearDown(controller.dispose);
      final show = ValueNotifier<bool>(false);
      final anchor = MiuixGlassPopupAnchor();
      addTearDown(show.dispose);
      addTearDown(anchor.dispose);
      await tester.pumpWidget(
        TestApp(
          home: HyperosGlassBackdropHost(
            controller: controller,
            child: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (context, visible, _) => HomeTopMenuPopup(
                show: visible,
                anchor: anchor,
                anchorContent: const Icon(Icons.more_vert_rounded),
                entries: entries,
                hasAvailableUpdate: false,
                onDismissRequest: () => show.value = false,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      show.value = true; // 打开菜单 → _syncCaptureHold → holdRecording
      await tester.pumpAndSettle();

      // 采样区继续录（玻璃始终有背景），但**整层图从不录**：首页菜单两块面板
      // 都走注入面，没人读它 —— 而 `acquire()` 那条路会在开合动画期间每帧录
      // 一张全屏（按 dpr ≈ 6.7MB/帧），是这段动画最大的一笔每帧开销。
      expect(
        controller.plainBackdrop.snapshot,
        isNull,
        reason: '注入面弹层不该产生整层快照',
      );
      expect(
        controller.capturing,
        isTrue,
        reason: '菜单展开期间必须仍然持有录帧（采样区要刷新）',
      );
    });

    testWidgets('二级面板浮在一级玻璃之上：注入面必须垫底（一级不垫）', (tester) async {
      await pumpMenu(tester);

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // 一级面板站在页面上：直接采样自己背后的画面。
      expect(
        tester
            .widget<HyperosSelectPopupGlass>(
              find.descendant(
                of: find.byType(MiuixGlassTransformPopup),
                matching: find.byType(HyperosSelectPopupGlass),
              ),
            )
            .useAncestorGroupCapture,
        isFalse,
      );

      // 二级面板浮在一级玻璃之上：不垫「共享组捕获的磨砂底」的话，液态档会
      // 按绘制顺序直接采样到一级面板的玻璃输出 —— 玻璃叠玻璃再折射一遍，
      // 读感浑浊（口径见 os4_glass_popup_surface.dart 与列表弹窗的二级子卡）。
      expect(
        tester
            .widget<HyperosSelectPopupGlass>(
              find.descendant(
                of: find.byType(MiuixGlassSecondaryPopup),
                matching: find.byType(HyperosSelectPopupGlass),
              ),
            )
            .useAncestorGroupCapture,
        isTrue,
        reason: '二级面板必须走带垫底的注入面',
      );
    });
  });
}
