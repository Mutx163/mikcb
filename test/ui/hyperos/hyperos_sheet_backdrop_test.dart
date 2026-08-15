import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';

/// 弹窗玻璃「未压暗背景」链路：showHyperosSheet 打开前捕获屏幕，
/// 玻璃之下垫 UndimmedBackdropLayer（采样亮的页面而非 modal dim）。
void main() {
  Future<void> pumpHost(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: liquidGlassAppRootBoundaryKey,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: FrostedAppearanceScope(
            appearance: const FrostedAppearance(
              sheetBlurSigma: 24,
              sheetTintAlpha: 0.32,
              sheetBarrierAlpha: 0.2,
              glassMode: FrostedGlassMode.liquidGlass,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('showHyperosSheet: 玻璃下垫未压暗背景层，无异常', (tester) async {
    await pumpHost(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showHyperosSheet<void>(
                context: context,
                builder: (_) => const HyperosSheet(
                  title: '测试弹窗',
                  child: Text('弹窗内容'),
                ),
              ),
              child: const Text('打开弹窗'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('打开弹窗'));
    // async：先捕获未压暗屏幕，再 push route
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: '打开弹窗不应有异常');
    expect(find.text('弹窗内容'), findsOneWidget, reason: '弹窗内容应显示');
    expect(
      find.byType(UndimmedBackdropLayer),
      findsWidgets,
      reason: '液态玻璃弹窗应带未压暗背景垫层',
    );

    // 关闭弹窗
    await tester.tapAt(const Offset(200, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: '关闭弹窗不应有异常');
  });

  testWidgets('showHyperosSelectPopup: 弹窗玻璃带未压暗垫层', (tester) async {
    await pumpHost(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showHyperosSelectPopup<String>(
                context: context,
                anchorRect: const Rect.fromLTWH(300, 200, 100, 40),
                items: const {'选项A': 'a', '选项B': 'b'},
                currentValue: 'a',
              ),
              child: const Text('打开选择'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('打开选择'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: '打开选择弹窗不应有异常');
    expect(find.text('选项A'), findsOneWidget, reason: '选项应显示');
    expect(
      find.byType(UndimmedBackdropLayer),
      findsWidgets,
      reason: '选择弹窗玻璃应带未压暗背景垫层',
    );
  });
}
