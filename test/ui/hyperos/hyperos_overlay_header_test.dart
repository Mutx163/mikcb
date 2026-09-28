import 'package:flutter/material.dart';
// 只取要断言的那个渲染对象（别整包进来把 material 的同名符号搞歧义）。
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_icon_button.dart';
import 'package:university_timetable/ui/hyperos/hyperos_overlay_header.dart';
import 'package:university_timetable/ui/hyperos/hyperos_proxies.dart';

import '../../helpers_test_app.dart';

void main() {
  testWidgets('overlay header suffix action receives taps through title layer', (
    WidgetTester tester,
  ) async {
    var savePressed = false;

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: HyperosOverlayNestedHeader(
            title: const Text('添加课程'),
            prefixes: [
              HyperosIconButton(icon: Icons.arrow_back, onPressed: () {}),
            ],
            suffixes: [
              FHeaderAction(
                icon: const Icon(Icons.check_rounded),
                semanticsLabel: '保存',
                onPress: () => savePressed = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(savePressed, isTrue);
  });

  group('长标题不压图标', () {
    // 教务导入网页页的标题（学校名 + 适配器名）就是这个量级：14 个汉字
    // ≈ 237dp，而右边常年 4 个动作图标占 160dp，360dp 宽的机器上两者
    // 必然打架（2026-09-28 真机反馈：标题盖掉 3 个图标）。
    const longTitle = '重庆城市科技学院强智通适配';

    Widget header({required String title, int suffixCount = 4}) {
      return TestApp(
        home: Scaffold(
          body: HyperosOverlayNestedHeader(
            title: Text(title),
            prefixes: [
              HyperosIconButton(icon: Icons.arrow_back, onPressed: () {}),
            ],
            suffixes: List.generate(
              suffixCount,
              (index) => FHeaderAction(
                icon: Icon(Icons.circle, key: ValueKey('suffix$index')),
                semanticsLabel: '动作$index',
                onPress: () {},
              ),
            ),
          ),
        ),
      );
    }

    Rect rectOf(WidgetTester tester, Finder finder) {
      final box = tester.renderObject<RenderBox>(finder);
      return box.localToGlobal(Offset.zero) & box.size;
    }

    void expectNoOverlapWithSuffixes(WidgetTester tester, String title) {
      final titleRect = rectOf(tester, find.text(title));
      for (final icon in find.byType(FHeaderAction).evaluate()) {
        final iconRect = rectOf(tester, find.byElementPredicate((e) => e == icon));
        expect(
          titleRect.overlaps(iconRect),
          isFalse,
          reason:
              '标题（${titleRect.width.toStringAsFixed(1)}dp）不能压到动作图标'
              '（${iconRect.toString()}）上',
        );
      }
    }

    testWidgets('首帧（还没量到图标宽度）就不重叠', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(header(title: longTitle));
      // 只 pump 一帧：此刻左右两组宽度还是「个数 × 名义槽宽」的兜底值。
      expectNoOverlapWithSuffixes(tester, longTitle);
    });

    testWidgets('量到真实宽度后仍不重叠，且放不下就走省略号', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(header(title: longTitle));
      await tester.pumpAndSettle();
      expectNoOverlapWithSuffixes(tester, longTitle);

      final titleRect = rectOf(tester, find.text(longTitle));
      // 360 − 返回键 40 − 4×40 图标 − 两端各 10 留白 = 132（首帧用名义 44/个
      // 算出来的更窄，settle 后是真实值）。
      expect(titleRect.width, lessThanOrEqualTo(140.5));
      // 放不下就该出省略号，而不是把字顶到图标上。
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(longTitle),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
    });

    testWidgets('短标题仍按整条栏居中（不因夹宽而偏移）', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(header(title: '设置', suffixCount: 1));
      await tester.pumpAndSettle();

      final titleRect = rectOf(tester, find.text('设置'));
      // 1 个返回键 + 1 个动作图标，两侧等宽 → 居中就是整条栏居中。
      expect(titleRect.center.dx, closeTo(180, 1));
    });

    testWidgets('两侧不等宽时长标题让位给图标，仍不压上去', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(header(title: longTitle, suffixCount: 1));
      await tester.pumpAndSettle();
      expectNoOverlapWithSuffixes(tester, longTitle);
    });
  });
}
