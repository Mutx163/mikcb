import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/app_startup_splash.dart';

void main() {
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
}
