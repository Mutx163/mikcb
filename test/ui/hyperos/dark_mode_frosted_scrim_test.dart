// 暗色模式下的磨砂衬底：**中性灰、比页面底亮一档**——既不是白纱，也不是页面底色。
//
// 用户口径变过两次，两次都要守住，别把其中一条当成另一条的回归：
//
//   2026-09-27「暗色模式，进入设置页面渐变模糊也是显示的透明效果」——
//     当时的暗色档是「页面底色 + 低不透明度」（暗 veil）：暗膜压在暗底上一点对比
//     都没有，模糊没有可糊的东西，整条带读成透明片。修法是把暗色档换成**白纱**。
//
//   2026-10-21「设置页面顶部的渐变模糊，还是浅色的模糊效果，能不能有一个深色的
//     模糊效果」—— 白纱把透明片治好了，但深色下顶栏从此是一层发白的雾。
//
// 所以**判据不是「必须白」**：原版钉的是 `r==g==b==1`，它把第二条口径直接判成了回归。
// 现在的判据是机理层面的三条，两条口径都能同时满足：
//
//   1. 中性色（r==g==b）—— 歪成任何色相都不是「灰玻璃」，是染色的雾；
//   2. 叠在页面底色上之后，比页面底色`亮一档`——这是 9-27 那条的真正诉求
//      （「看得见这层材料」），从「白一档」改成了「灰一档」；
//   3. 不透明度落在 [0.34, 0.58]——下限防透明片，上限防灰板糊死模糊。
//
// 数值以后要调随便调，但这三条不能再破。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/ui/hyperos/hyperos_blurred_header.dart';
import 'package:university_timetable/ui/hyperos/hyperos_sheet_blur_top.dart';
// 判据要拿页面底色做比较（「比页面底亮一档」），页面底色只从这里取。
import 'package:university_timetable/ui/hyperos/hyperos_theme.dart';

const _appearance = FrostedAppearance(
  sheetBlurSigma: 15,
  sheetTintAlpha: 0.7,
  sheetBarrierAlpha: 0.2,
);

/// 中性色判据：三通道相等（灰）。纯白/纯黑也满足，所以还要配对比度那条一起看。
bool _isNeutral(Color c) => c.r == c.g && c.g == c.b;

/// 把不透明度为 [alpha] 的前景 [fg] 叠在 [bg] 上，返回合成色。
Color _composite(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

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

  testWidgets('共享磨砂衬底：暗色是中性灰、比页面底亮一档（既非白纱也非页面底色）', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await _pumpHeader(tester, brightness);

      final context = tester.element(
        find.byType(HyperosFrostedHeaderShell),
      );
      final tint = HyperosBlurredHeader.tintColor(context, withBlur: true);

      expect(
        _isNeutral(tint),
        isTrue,
        reason: '$brightness 下的磨砂衬底必须是中性色（r==g==b）：'
            '歪成任何色相读起来都不是灰玻璃，而是染了色的雾',
      );

      if (brightness == Brightness.dark) {
        // 底色钉具名常量，不钉「差不多是灰」：这一档的取值是产品决定
        // （中性灰、与液态玻璃深色配方的目标底色同源），不是随手挑的灰。
        expect(
          tint.r,
          closeTo(HyperosBlurredHeader.darkVeilBase.r, 0.001),
          reason: '暗色衬底的底色必须取 [HyperosBlurredHeader.darkVeilBase]：'
              '与液态玻璃深色配方同源，改色要改那个常量而不是各处写 0x 字面量',
        );
        // ⚠️ 中性色一条**分不开灰与白**（纯白也满足 r==g==b）——反向探针实测：
        // 把实现改回 `Colors.white` 后只判中性色的用例仍然全绿，等于摆设。
        // 所以「明显暗于纯白」必须单独判，那是 2026-10-21 投诉的白雾本身。
        expect(
          tint.r,
          lessThanOrEqualTo(0.55),
          reason: '暗色衬底的底色必须明显暗于纯白：白色亮纱就是本次（2026-10-21）'
              '被投诉的「浅色模糊」本身，只有中性灰才是深色玻璃',
        );
        expect(
          tint.a,
          inInclusiveRange(
            HyperosBlurredHeader.darkVeilMinAlpha,
            HyperosBlurredHeader.darkVeilMaxAlpha,
          ),
          reason: '暗色档的不透明度要同时守住两条：下限防「透明片」（2026-09-27）、'
              '上限防「灰板糊死模糊」',
        );

        // 9-27 那条口径的真正诉求：这条带要**看得见**。当年靠「换白纱」实现，
        // 现在靠「灰底 + 更高不透明度」实现，两版都必须比页面底亮。
        final page = HyperosColors.scaffoldBackground(context);
        final laid = _composite(tint, page);
        expect(
          laid.computeLuminance(),
          greaterThan(page.computeLuminance()),
          reason: '暗色衬底叠在页面底上之后必须比页面底亮：'
              '与页面同色就是 2026-09-27 被打回的「一块透明片」',
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
