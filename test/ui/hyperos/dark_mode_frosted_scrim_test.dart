// 暗色模式下的磨砂衬底必须是**亮 veil**，不能是暗 veil。
//
// 用户口径 2026-09-27（两条都指同一个根因）：
//   · 「暗色模式，进入设置页面渐变模糊也是显示的透明效果」—— 子页顶栏那条带；
//   · 弹窗顶部那条带同样读成透明。
//
// 机制：暗 veil 压在暗背景上一点对比都没有，模糊没有可糊的东西，整条带就是一块透明片。
// 本仓同族接口（首页区域 / 菜单井 / 嵌套面）早就按「暗色用亮 veil」实现，只有共享的那
// 一份写成了暗 veil，而子页顶栏 / 弹窗面板 / 菜单全都经过它 —— 于是一起中招。
//
// 这里钉的是**机制**而不是像素值：暗色档必须是白色基（r=g=b=1）且不透明度落在「看得见」
// 的区间内。数值以后要调随便调，但这三件事不能再变回暗 veil。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/ui/hyperos/hyperos_blurred_header.dart';
import 'package:university_timetable/ui/hyperos/hyperos_sheet_blur_top.dart';

const _appearance = FrostedAppearance(
  sheetBlurSigma: 15,
  sheetTintAlpha: 0.7,
  sheetBarrierAlpha: 0.2,
);

/// 白基判据：三个通道必须相等且为满值（暗 veil 是页面底色，通道不相等）。
bool _isWhiteBased(Color c) => c.r == 1.0 && c.g == 1.0 && c.b == 1.0;

Future<void> _pumpHeader(WidgetTester tester, Brightness brightness) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const FrostedAppearanceScope(
        appearance: _appearance,
        child: HyperosFrostedHeaderShell(child: SizedBox(height: 56)),
      ),
    ),
  );
  // 必须 settle：`MaterialApp` 的 `Theme` 是 `AnimatedTheme`，换亮度有 200ms 过渡。
  // 只 pump 一帧读到的是**上一轮**的亮度（第一版就是这么写成「两种亮度结果一样」的，
  // 一度以为是产品代码错了）。
  await tester.pumpAndSettle();
}

void main() {
  // 真机判据里的 `liveBlurSupported` 读 `dart:io` 的 `Platform.isAndroid/isIOS`，
  // widget test 跑在宿主（Windows）恒为 false —— 不打开这个开关，「模糊开着」那条分支
  // 在测试里根本走不到。
  setUp(() => HyperosBlurredHeader.liveBlurSupportedOverride = true);
  tearDown(() => HyperosBlurredHeader.liveBlurSupportedOverride = null);

  testWidgets('共享磨砂衬底：暗色也必须是白基亮 veil（不是暗 veil）', (tester) async {
    for (final brightness in Brightness.values) {
      await _pumpHeader(tester, brightness);

      final tint = HyperosBlurredHeader.tintColor(
        tester.element(find.byType(HyperosFrostedHeaderShell)),
        withBlur: true,
      );

      expect(
        _isWhiteBased(tint),
        isTrue,
        reason: '$brightness 下的磨砂衬底必须是白基：暗 veil 压在暗背景上没有对比，'
            '模糊读不出来，整条带就是一块透明片（2026-09-27）',
      );
      if (brightness == Brightness.dark) {
        expect(
          tint.a,
          inInclusiveRange(0.16, 0.30),
          reason: '暗色档要留可读下限：落在任何低值上都会读成透明',
        );
      }
    }
  });

  testWidgets('弹窗顶部模糊带：衬底不能是全透明，且与设置页顶栏同一份材料', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const FrostedAppearanceScope(
            appearance: _appearance,
            child: Scaffold(
              body: SizedBox(
                height: 200,
                width: 300,
                child: HyperosSheetBlurTop(
                  headerHeight: 40,
                  header: SizedBox(height: 40),
                  body: SizedBox(height: 160),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bg = tester.widget<FrostedHeaderBackground>(
        find.byType(FrostedHeaderBackground),
      );

      expect(
        bg.tint.a,
        greaterThan(0),
        reason: '$brightness 下带子都必须有衬底：带子覆盖的那一段一行内容都没有，'
            '只有模糊就等于糊了一片均匀玻璃（读成没糊 / 一块透明片），渐隐区也会与下面'
            '第一行内容硬切出一条线（2026-09-27 三条投诉的同一个根因）',
      );
      expect(
        bg.tint,
        HyperosBlurredHeader.sheetTintColor(
          tester.element(find.byType(FrostedHeaderBackground)),
          withBlur: true,
        ),
        reason: '带子必须与设置页顶栏用**同一份**磨砂衬底（用户要的就是设置页那份观感）',
      );
    }
  });
}
