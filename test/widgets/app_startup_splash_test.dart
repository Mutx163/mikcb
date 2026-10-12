import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/app_startup_splash.dart';

void main() {
  test('最短展示时长：快启动按差值滞留，慢启动立即换入', () {
    expect(splashHoldRemaining(Duration.zero), kMinSplashDuration);
    expect(
      splashHoldRemaining(const Duration(milliseconds: 100)),
      const Duration(milliseconds: 300),
    );
    expect(splashHoldRemaining(kMinSplashDuration), Duration.zero);
    expect(splashHoldRemaining(const Duration(seconds: 5)), Duration.zero);
  });

  testWidgets('浅色底：2114 同款图标 + 常规字重黑字', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: const AppStartupSplash(),
      ),
    );

    expect(find.text('轻屿课表'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage,
      ),
      findsOneWidget,
    );

    final text = tester.widget<Text>(find.text('轻屿课表'));
    // 品牌字口径：常规字重勿加粗、黑墨（用户明确要求）。
    expect(text.style!.fontWeight, FontWeight.w400);
    expect(text.style!.color, Colors.black);
  });

  testWidgets('深色底：白字（原生夜间启动井 #121212 同色）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const AppStartupSplash(),
      ),
    );

    final text = tester.widget<Text>(find.text('轻屿课表'));
    expect(text.style!.color, Colors.white);
  });

  testWidgets('入场动效：品牌字从下方淡入到位', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: const AppStartupSplash(),
      ),
    );

    // 首帧 = 动画起点：整组下移 12px、完全透明。
    final startOffset = tester.getTopLeft(find.text('轻屿课表'));
    expect(
      tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('轻屿课表'),
              matching: find.byType(Opacity),
            )
            .first,
      ).opacity,
      0,
    );

    // 走完整段时长：位移归零、完全不透明。
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    final endOffset = tester.getTopLeft(find.text('轻屿课表'));
    expect(
      tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('轻屿课表'),
              matching: find.byType(Opacity),
            )
            .first,
      ).opacity,
      1,
    );
    // 上移的正是那 12px。
    expect(endOffset.dy, startOffset.dy - 12);
  });
}
