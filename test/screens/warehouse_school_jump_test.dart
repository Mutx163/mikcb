import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 跳转落点：目标组的顶边必须落在**顶栏实际画到的高度**上，而不是顶栏的
/// 展开高度。
///
/// 背景：本页顶栏是可折叠大标题栏，它的高度只在「展开且静止」时量一次
/// （`HyperosPageCollaborators.requestOverlayHeaderMeasure` 在
/// `collapsibleBarSettled` 为 false 时直接 return），所以页面拿到的
/// `contentTopInset` 永远是展开高度。跳转会让列表滚起来、大标题随之折叠，
/// 顶栏只画到折叠高度 —— 用展开高度对齐，中间空出的那一截就会露出上一组的行
/// （2026-10-07 用户实机发现）。
void main() {
  group('可折叠大标题的折叠高度换算', () {
    testWidgets('折叠高度恒小于展开高度，且跟随系统字号', (tester) async {
      Future<double> read(double textScale) async {
        late double result;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Builder(
                builder: (context) {
                  result =
                      HyperosBlurredHeader.collapsibleLargeTitleCollapsedHeight(
                        context,
                      );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        return result;
      }

      final base = await read(1);
      // 就是大标题那一行的高度：title1(32) × height 1.2 = 38.4。折叠量必须
      // **恰好**是这个数——多减会让落点偏高、把目标组的字母切掉上半截
      // （2026-10-07 实机），少减会让上一组露在顶栏下沿之下。
      expect(base, closeTo(38.4, 0.01));
      // 字号放大时折叠量必须跟着放大，否则换算出来仍会露出上一组。
      expect(await read(1.5), closeTo(57.6, 0.01));
    });

    testWidgets('collapsedContentTopInset 扣掉折叠量且不为负', (tester) async {
      late double collapsed;
      late double expanded;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expanded = 400;
              collapsed = HyperosBlurredHeader.collapsedContentTopInset(
                context,
                expandedTopInset: expanded,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(collapsed, lessThan(expanded));
      expect(collapsed, greaterThan(0));
      // 顶栏没量到（0）时不能算出负数。
      late double fromZero;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              fromZero = HyperosBlurredHeader.collapsedContentTopInset(
                context,
                expandedTopInset: 0,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(fromZero, 0);
    });
  });

  group('jumpTo(alignment) 把目标 item 顶边放在哪', () {
    testWidgets('落在视口比例处，上一 item 因此完全在其上方', (tester) async {
      const viewportHeight = 800.0;
      const headerInset = 200.0;
      const itemHeight = 100.0;

      final controller = ItemScrollController();
      final positions = ItemPositionsListener.create();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: viewportHeight,
              child: ScrollablePositionedList.builder(
                itemCount: 30,
                itemScrollController: controller,
                itemPositionsListener: positions,
                padding: const EdgeInsets.only(top: headerInset),
                itemBuilder: (context, index) =>
                    SizedBox(height: itemHeight, child: Text('item $index')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.jumpTo(index: 10, alignment: headerInset / viewportHeight);
      await tester.pumpAndSettle();

      double topOf(int index) =>
          positions.itemPositions.value
              .firstWhere((p) => p.index == index)
              .itemLeadingEdge *
          viewportHeight;
      double bottomOf(int index) =>
          positions.itemPositions.value
              .firstWhere((p) => p.index == index)
              .itemTrailingEdge *
          viewportHeight;

      // 目标组的顶边精确落在 alignment 指定处。
      expect(topOf(10), closeTo(headerInset, 0.5));
      // 紧邻的上一项**底边**也在 headerInset —— 也就是说上一组整行都落在
      // [0, headerInset] 这段里。只要顶栏盖满这一段，它就看不见；
      // 一旦对齐用的是顶栏的展开高度（大于实际折叠高度），它就会露出来。
      expect(bottomOf(9), closeTo(headerInset, 0.5));
      expect(topOf(9), lessThan(topOf(10)));
      expect(itemHeight, greaterThan(0));
    });
  });
}
