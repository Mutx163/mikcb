import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 柔光玻璃面板上的墨色必须与**面板极性**同源。
///
/// 回归背景：首页右上角锚定菜单的墨色由「壁纸亮度」决定（深壁纸 → 白墨），
/// 但柔光玻璃弹窗面板的极性只看 app 主题明暗（亮色主题 → 乳白 252@67.5%
/// 罩面，暗色主题 → 深灰 31@67.5% 罩面，见 `SoftGlassTokens.tint`）。
/// 两者判据不同源：深壁纸 + 亮色主题下白墨直接打在乳白面板上、浅壁纸 +
/// 暗色主题下黑墨直接打在深灰面板上——两个方向都不可读。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const softAppearance = FrostedAppearance(
    sheetBlurSigma: 15,
    sheetTintAlpha: 0.7,
    sheetBarrierAlpha: 0.2,
    glassMode: FrostedGlassMode.softGlass,
  );

  /// 主题明暗必须由 [theme] 显式给出：`HyperosColors` 与
  /// `SoftGlassTokens.tint` 都读 `Theme.of(context).brightness`。
  Future<void> pumpPopup(
    WidgetTester tester, {
    required ThemeData theme,
    FrostedAppearance appearance = softAppearance,
    Color? foregroundColor,
    bool opaqueSurface = false,
  }) async {
    final host = FrostedAppearanceScope(
      appearance: appearance,
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            unawaited(
              showHyperosListPopup<String>(
                context: context,
                position: const RelativeRect.fromLTRB(200, 80, 24, 200),
                foregroundColor: foregroundColor,
                opaqueSurface: opaqueSurface,
                items: const [HyperosPopupMenuItem(label: '普通项', value: 'a')],
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: child ?? const SizedBox.shrink(),
        ),
        home: host,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Color rowInk(WidgetTester tester) =>
      tester.widget<Text>(find.text('普通项')).style!.color!;

  testWidgets('亮色主题（乳白面板）：壁纸白墨不得直接打上去', (tester) async {
    await pumpPopup(
      tester,
      theme: ThemeData.light(),
      foregroundColor: const Color(0xFFFFFFFF),
    );

    // 前置事实：面板确实走柔光玻璃面。
    expect(find.byType(SoftGlassSurface), findsOneWidget);
    // 乳白罩面 → 墨色必须是深色。
    expect(rowInk(tester).computeLuminance(), lessThan(0.5));
  });

  testWidgets('暗色主题（深灰面板）：壁纸深墨不得直接打上去', (tester) async {
    await pumpPopup(
      tester,
      theme: ThemeData.dark(),
      foregroundColor: const Color(0xFF1A1A1A),
    );

    expect(find.byType(SoftGlassSurface), findsOneWidget);
    // 深灰罩面 → 墨色必须是浅色。
    expect(rowInk(tester).computeLuminance(), greaterThan(0.5));
  });

  testWidgets('强制实底面（WebView 场景）同样不吃壁纸墨色', (tester) async {
    await pumpPopup(
      tester,
      theme: ThemeData.light(),
      foregroundColor: const Color(0xFFFFFFFF),
      opaqueSurface: true,
    );

    expect(find.byType(SoftGlassSurface), findsNothing);
    expect(rowInk(tester).computeLuminance(), lessThan(0.5));
  });
}
