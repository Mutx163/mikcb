import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/ui/hyperos/hyperos_blurred_header.dart';
import 'package:university_timetable/ui/hyperos/hyperos_page.dart';
import 'package:university_timetable/ui/hyperos/inspire/inspire_header_blur.dart';

/// 折叠顶栏的模糊层是常驻挂载的（见 `HyperosFrostedHeaderShell`），而
/// `inspire` 档衬底会在底边渐隐到全透明——两者叠加会留出一条「透明窗口」：
/// 内容还没真正压到带底、`contentUnderHeader` 仍为 false 时，常驻模糊已经
/// 把即将进入带内的内容糊进这条窗口，衬底随后才整条切进来，读起来就是
/// 「内容快插到标题栏时顿一下」。
///
/// 这组用例锁住像素契约：**无内容压在带下时衬底必须整条不透明**。
/// 只取衬底那一层：`InspireHeaderBlur` 的 Stack 里模糊层最底、衬底居中。
Finder tintLayerFinder() {
  return find.descendant(
    of: find.byType(InspireHeaderBlur),
    matching: find.byWidgetPredicate(
      (w) => w is ColoredBox || w is DecoratedBox,
    ),
  );
}

Color? resolveTintBottomColor(Widget widget) {
  if (widget is ColoredBox) {
    return widget.color;
  }
  final decoration = (widget as DecoratedBox).decoration;
  if (decoration is! BoxDecoration) {
    return null;
  }
  final gradient = decoration.gradient;
  if (gradient is! LinearGradient) {
    return null;
  }
  return gradient.colors.last;
}

void main() {
  testWidgets('inspire 档：opaqueAtRest 时衬底铺满整条带，底边不渐隐', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InspireHeaderBlur(
            tint: Color(0xFFFFFFFF),
            opaqueAtRest: true,
            child: SizedBox(height: 100, width: 400),
          ),
        ),
      ),
    );

    final layers = tintLayerFinder().evaluate().toList();
    expect(layers, isNotEmpty, reason: '衬底层应当存在');
    final bottom = resolveTintBottomColor(layers.first.widget);
    expect(bottom, isNotNull);
    expect(
      bottom!.a,
      1.0,
      reason: '无内容压带时衬底底边必须不透明，否则常驻模糊会从这里漏出来',
    );
    expect(bottom, const Color(0xFFFFFFFF));
  });

  testWidgets('inspire 档：内容压带后衬底恢复底边渐隐', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InspireHeaderBlur(
            tint: Color(0xFFFFFFFF),
            child: SizedBox(height: 100, width: 400),
          ),
        ),
      ),
    );

    final layers = tintLayerFinder().evaluate().toList();
    final bottom = resolveTintBottomColor(layers.first.widget);
    expect(bottom, isNotNull);
    expect(
      bottom!.a,
      0.0,
      reason: '压带后底边必须渐隐到全透明，衔接处才没有可见切边',
    );
  });

  testWidgets('gaussian 档不受影响：始终整条均匀衬底', (tester) async {
    for (final opaqueAtRest in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspireHeaderBlur(
              tint: const Color(0xFFFFFFFF),
              style: HeaderBlurStyle.gaussian,
              opaqueAtRest: opaqueAtRest,
              child: const SizedBox(height: 100, width: 400),
            ),
          ),
        ),
      );
      final layers = tintLayerFinder().evaluate().toList();
      final bottom = resolveTintBottomColor(layers.first.widget);
      expect(bottom, const Color(0xFFFFFFFF));
    }
  });

  testWidgets('子页顶栏外壳：无内容压带时衬底不透明，压带后才渐隐', (tester) async {
    Widget build({required bool under}) {
      return MaterialApp(
        home: HyperosHeaderUnderContentScope(
          contentUnderHeader: under,
          child: const HyperosBlurredHeaderScope(
            contentTopInset: 100,
            headerBackgroundColor: Color(0xFFFFFFFF),
            child: HyperosFrostedHeaderShell(
              tint: Color(0xFFFFFFFF),
              opaqueAtRest: true,
              child: SizedBox(height: 100),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(under: false));
    var layers = tintLayerFinder().evaluate().toList();
    expect(
      resolveTintBottomColor(layers.first.widget)!.a,
      1.0,
      reason: '无内容压带：衬底整条不透明，常驻模糊不得从底边漏出',
    );

    await tester.pumpWidget(build(under: true));
    layers = tintLayerFinder().evaluate().toList();
    expect(
      resolveTintBottomColor(layers.first.widget)!.a,
      1.0,
      reason: '压带后由外层 tint 决定观感，衬底层保持不透明即可',
    );
  });

  _endToEnd();
}

/// 端到端：整条「内容快插到标题栏」的行程里，衬底都必须是不透明的；
/// 翻转点之后才允许出现底边渐隐。
void _endToEnd() {
  testWidgets('折叠顶栏：内容接近标题栏的整段行程里衬底不透明', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: HyperosSubpage(
          title: const Text('Appearance settings'),
          child: HyperosListView(
            children: List.generate(
              30,
              (i) => SizedBox(height: 72, child: Center(child: Text('row $i'))),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pos = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Scrollable).first),
    );
    await tester.pump();

    var sawOpaqueBeforeFlip = false;
    var sawGradientAfterFlip = false;
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));

      final under = tester
          .widget<HyperosHeaderUnderContentScope>(
            find.byType(HyperosHeaderUnderContentScope),
          )
          .contentUnderHeader;
      final layers = tintLayerFinder().evaluate().toList();
      if (layers.isEmpty) {
        continue;
      }
      final bottom = resolveTintBottomColor(layers.first.widget);
      if (bottom == null) {
        continue;
      }
      if (!under) {
        expect(
          bottom.a,
          1.0,
          reason: 'px=${pos.pixels} 内容未压带，衬底底边必须不透明',
        );
        sawOpaqueBeforeFlip = true;
      } else {
        sawGradientAfterFlip = true;
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(sawOpaqueBeforeFlip, isTrue, reason: '应当经过展开→收缩的行程');
    expect(sawGradientAfterFlip, isTrue, reason: '应当经过翻转点之后的行程');
  });
}
