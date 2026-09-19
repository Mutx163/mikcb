import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderOpacity;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

/// Cumulative alpha applied to [finder]'s render object by ancestor
/// [RenderOpacity] layers (1.0 when nothing fades it).
double effectiveOpacityOf(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  tester.element(finder).visitAncestorElements((ancestor) {
    final renderObject = ancestor.renderObject;
    if (renderObject is RenderOpacity) {
      opacity *= renderObject.opacity;
    }
    return true;
  });
  return opacity;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showHomeHyperosSheet drag-to-dismiss（面板换成上游底部弹窗之后）', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showHomeHyperosSheet<void>(
                      context: context,
                      builder: (sheetContext) {
                        // 内容里照旧用 HyperosSheetFrame：面板由承载壳注入，
                        // 框自己让位（不画第二层玻璃）—— 这条也顺带被下面几条覆盖。
                        return const HyperosSheetFrame(
                          child: SizedBox(
                            key: ValueKey('sheet-body'),
                            width: 300,
                            height: 400,
                            child: Center(child: Text('Sheet content')),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    /// 把手中心：面板顶部那条 24dp 横条。
    ///
    /// ⚠️ 上游只给**把手**挂了拖拽手势（无标题时它下面还有 18dp 的标题行），
    /// 面板本身拖不动 —— 拿内容坐标当把手会「拖不动」，这是 2026-09-19 换组件后
    /// 行为变化最明显的一处（旧实现整面板可拖）。
    Offset handleCenter(WidgetTester tester, Finder content) {
      final topLeft = tester.getTopLeft(content);
      return Offset(topLeft.dx + 150, topLeft.dy - 30);
    }

    testWidgets('拖把手：面板整体下移，且内容始终不透明', (tester) async {
      await openSheet(tester);

      final body = find.byKey(const ValueKey('sheet-body'));
      expect(body, findsOneWidget);
      expect(effectiveOpacityOf(tester, body), 1.0);
      final topBeforeDrag = tester.getTopLeft(body).dy;

      final gesture = await tester.startGesture(handleCenter(tester, body));
      // 先来一小步越过 touch slop，让纵向拖拽识别器赢下竞技场；再拖才是位移。
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();

      // 拖拽期间面板只平移、不淡出：盖一层 Opacity 会让磨砂 / 液态玻璃闪烁
      // （这条是当初修过的回归）。
      expect(effectiveOpacityOf(tester, body), 1.0);
      expect(tester.getTopLeft(body).dy, greaterThan(topBeforeDrag));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('拖过距离阈值就收起', (tester) async {
      await openSheet(tester);

      // 慢拖：速度不过阈值，靠**距离**判定（>150dp）。
      await tester.timedDragFrom(
        handleCenter(tester, find.byKey(const ValueKey('sheet-body'))),
        const Offset(0, 300),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sheet content'), findsNothing);
    });

    testWidgets('小幅慢拖回弹、不收起', (tester) async {
      await openSheet(tester);

      final body = find.byKey(const ValueKey('sheet-body'));
      final topBeforeDrag = tester.getTopLeft(body).dy;

      await tester.timedDragFrom(
        handleCenter(tester, body),
        const Offset(0, 40),
        const Duration(milliseconds: 1000),
      );
      await tester.pumpAndSettle();

      expect(body, findsOneWidget);
      expect(tester.getTopLeft(body).dy, closeTo(topBeforeDrag, 0.5));
    });
  });

  group('showHomeHyperosSheet 贴底布局（内容贴底、不撑满全屏）', () {
    Future<void> openFrostedEdgeSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showHomeHyperosSheet<void>(
                      context: context,
                      builder: (sheetContext) {
                        return const HyperosSheetFrame(
                          child: SizedBox(
                            width: 300,
                            height: 200,
                            child: Center(child: Text('Edge sheet content')),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('frosted edge sheet hugs content instead of full screen', (
      tester,
    ) async {
      await openFrostedEdgeSheet(tester);

      final content = find.text('Edge sheet content');
      expect(content, findsOneWidget);

      // Bottom-aligned edge sheet: the 200dp content (+ padding) hugs the
      // bottom of the 600dp test screen. The old all-Positioned Stack sized
      // itself to constraints.biggest and pinned the content to the top of a
      // full-screen panel (content top ~16dp instead of ~384dp).
      expect(tester.getTopLeft(content).dy, greaterThan(300));
    });
  });

  group('HyperosAdaptiveCard on frosted panels', () {
    testWidgets('choice group card turns translucent inside a frosted sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showHomeHyperosSheet<void>(
                      context: context,
                      builder: (sheetContext) {
                        return const HyperosSheetFrame(
                          child: HyperosChoiceGroup(
                            children: [
                              HyperosChoiceTile(title: 'Profile A'),
                              HyperosChoiceTile(title: 'Profile B'),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The list card must let the liquid glass / frosted panel show through:
      // an opaque white card here defeats the whole point of the glass sheet.
      final cardMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(HyperosAdaptiveCard),
          matching: find.byType(Material),
        ),
      );
      expect(cardMaterial.color, isNotNull);
      expect(cardMaterial.color!.a, lessThan(1.0));
    });

    testWidgets('choice group card stays opaque on a plain settings page', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestApp(
          home: Scaffold(
            body: HyperosChoiceGroup(
              children: [
                HyperosChoiceTile(title: 'Profile A'),
                HyperosChoiceTile(title: 'Profile B'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(HyperosAdaptiveCard),
          matching: find.byType(Material),
        ),
      );
      expect(cardMaterial.color, isNotNull);
      expect(cardMaterial.color!.a, 1.0);
    });
  });
}
