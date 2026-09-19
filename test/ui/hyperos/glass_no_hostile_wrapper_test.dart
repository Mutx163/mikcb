import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

/// 弹层玻璃面**不许被套进裁剪层或半透明层**。
///
/// 为什么：这块玻璃读的是**实时合成器背景**（`BackdropFilter` +
/// `compose(着色器, 模糊)`）。裁剪层会把它连同「图边」一起缩到裁剪窗口上，而着色器
/// 恰恰是在边缘**往外**采样的 —— 窗口越小、离边越近，采到的就越接近出界；真机上
/// 读作弹窗开合时一块块发黑。半透明层同理：它把玻璃隔离进离屏层，采到的是空背景。
///
/// 真机跑出来的对照：右上角菜单只套缩放、不裁剪，从来没有黑块；内部小选择菜单套了
/// 揭示裁剪，关闭时就出黑块。所以**缩放、平移、滑动都不在禁止之列**，只有裁剪与
/// 半透明会出事。
///
/// 这条规则此前只活在注释里（`hyperos_list_popup.dart` 的
/// 「No reveal clip around the glass」、`hyperos_select.dart` 的
/// 「No Opacity here」），踩回去没人拦 —— 本文件就是那道拦截。
///
/// 断言锚在 `HyperosSelectPopupGlass` 上而不是 `LiquidGlassSurface`：测试环境没有
/// shader filter 后端，液态分支会内部回退成别的材质（树里没有 `LiquidGlassSurface`），
/// 但「外壳有没有裁剪/半透明」与走哪个材质分支无关，锚在外壳上才测得准。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const liquidAppearance = FrostedAppearance(
    sheetBlurSigma: 15,
    sheetTintAlpha: 0.7,
    sheetBarrierAlpha: 0.2,
    glassMode: FrostedGlassMode.liquidGlass,
  );

  /// 从玻璃面往上收集「会隔离或重塑实时背景」的祖先，返回可读描述。
  ///
  /// 只看**取值确实会隔离背景**的那些：不透明的 `FadeTransition`（路由默认转场，
  /// 时长 0、一直停在 1.0）不算事，`RenderAnimatedOpacity` 在 alpha=255 时压根不建
  /// 离屏层。所以这里判的是「当前值 < 1」，而不是「有没有这个 widget」。
  List<String> backgroundHostileAncestors(WidgetTester tester, Finder glass) {
    final hits = <String>[];
    tester.element(glass).visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is ClipPath) {
        hits.add('ClipPath');
      } else if (widget is ClipRect) {
        hits.add('ClipRect');
      } else if (widget is ClipRRect) {
        hits.add('ClipRRect');
      } else if (widget is Opacity && widget.opacity < 1) {
        hits.add('Opacity(${widget.opacity})');
      } else if (widget is AnimatedOpacity && widget.opacity < 1) {
        hits.add('AnimatedOpacity(${widget.opacity})');
      } else if (widget is FadeTransition && widget.opacity.value < 1) {
        hits.add('FadeTransition(${widget.opacity.value})');
      }
      return true;
    });
    return hits;
  }

  void expectNoHostileAncestor(WidgetTester tester, {required String stage}) {
    final glass = find.byType(HyperosSelectPopupGlass).last;
    expect(glass, findsOneWidget, reason: '$stage：玻璃面应该在树上');
    expect(
      backgroundHostileAncestors(tester, glass),
      isEmpty,
      reason:
          '$stage：玻璃面祖先里不该出现裁剪层或半透明层 —— 这块玻璃读实时合成器'
          '背景，裁剪会把采样范围连同图边一起缩到裁剪窗口上，而着色器是在边缘往外'
          '采的，真机上表现为发黑；半透明层则把它隔离进离屏层。缩放/平移/滑动不受限。',
    );
  }

  Future<void> pumpSelectHost(WidgetTester tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: FrostedAppearanceScope(
          appearance: liquidAppearance,
          child: Center(
            child: SizedBox(
              width: 360,
              child: HyperosSelectTile<String>(
                label: '排序',
                items: {'按名称': 'name', '按时间': 'time'},
                value: 'name',
                onChanged: _noop,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('选择弹窗：开合全程，玻璃面祖先里没有裁剪层或半透明层', (tester) async {
    await pumpSelectHost(tester);

    await tester.tap(find.text('排序'));
    await tester.pump(); // 打开：动画首帧
    expectNoHostileAncestor(tester, stage: '打开首帧');

    await tester.pump(const Duration(milliseconds: 60)); // 打开：动画中段
    expectNoHostileAncestor(tester, stage: '打开中段');

    await tester.pumpAndSettle();
    expectNoHostileAncestor(tester, stage: '打开完成');

    // 关掉，把遗留的计时器/路由收干净。
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });

  testWidgets('列表弹窗二级子卡：展开与收起全程，玻璃面祖先里没有裁剪层或半透明层', (tester) async {
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
    ];

    await tester.pumpWidget(
      TestApp(
        home: FrostedAppearanceScope(
          appearance: liquidAppearance,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                // 返回的 Future 要接住，否则弹窗 result 永不完成会被判成
                // 未处理的异步错误（同 hyperos_list_popup_submenu_test）。
                unawaited(
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
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('视图父项').first);
    await tester.pump(); // 展开：动画首帧
    expectNoHostileAncestor(tester, stage: '展开首帧');

    await tester.pump(const Duration(milliseconds: 60)); // 展开：动画中段
    expectNoHostileAncestor(tester, stage: '展开中段');

    await tester.pumpAndSettle();
    expectNoHostileAncestor(tester, stage: '展开完成');

    await tester.tap(find.text('视图父项').first);
    await tester.pump(); // 收起：动画首帧
    expectNoHostileAncestor(tester, stage: '收起首帧');

    await tester.pump(const Duration(milliseconds: 60)); // 收起：动画中段
    expectNoHostileAncestor(tester, stage: '收起中段');

    await tester.pumpAndSettle();
  });
}

void _noop(String _) {}
