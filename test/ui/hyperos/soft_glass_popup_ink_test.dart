import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/stable_frosted_surface.dart';

/// 弹窗面板的墨色必须与**面板极性**同源，而不是照抄调用方给的壁纸墨色。
///
/// 回归背景（2026-09-19 之前的形态）：首页右上角锚定菜单的墨色由「壁纸亮度」
/// 决定（深壁纸 → 白墨），面板底色却由别的判据决定，两者不同源时白墨会直接打在
/// 乳白面板上、黑墨打在深灰面板上，两个方向都不可读。
///
/// 口径变化：弹窗家族自 2026-09-19 起**锁成液态玻璃标准档**（
/// `LiquidGlassRole.pinnedChrome`），不再有「柔光玻璃面板」这一支；剩下能让面板
/// 变成不透底的两类仍是同一件事 —— 强制实底（WebView 场景）与设备级技术门禁
/// （测试环境没有 shader 后端，玻璃面退化成磨砂兜底）。两类都不透出壁纸，
/// 所以壁纸感知墨色一律不采纳，回落到与面板同源的主题墨。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const softAppearance = FrostedAppearance(
    sheetBlurSigma: 15,
    sheetTintAlpha: 0.7,
    sheetBarrierAlpha: 0.2,
    glassMode: FrostedGlassMode.softGlass,
  );

  /// 主题明暗必须由 [theme] 显式给出：`HyperosColors` 与面板底色都读
  /// `Theme.of(context).brightness`。
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

  testWidgets('亮色主题：壁纸白墨不得直接打上去', (tester) async {
    await pumpPopup(
      tester,
      theme: ThemeData.light(),
      foregroundColor: const Color(0xFFFFFFFF),
    );

    // 前置事实：本机没有 shader 后端 → 玻璃面退化成磨砂兜底（不透出壁纸）。
    expect(find.byType(StableFrostedSurface), findsOneWidget);
    // 磨砂兜底是乳白罩面 → 墨色必须是深色。
    expect(rowInk(tester).computeLuminance(), lessThan(0.5));
  });

  testWidgets('暗色主题：壁纸深墨不得直接打上去', (tester) async {
    await pumpPopup(
      tester,
      theme: ThemeData.dark(),
      foregroundColor: const Color(0xFF1A1A1A),
    );

    expect(find.byType(StableFrostedSurface), findsOneWidget);
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

    expect(find.byType(StableFrostedSurface), findsNothing);
    expect(rowInk(tester).computeLuminance(), lessThan(0.5));
  });
}
