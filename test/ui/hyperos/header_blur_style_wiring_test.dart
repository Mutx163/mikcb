// 顶栏模糊风格两档字段的消费侧接线回归测试。
//
// 回归背景（2026-09-12）：7f301074 把顶栏模糊风格拆成首页
// （headerBlurStyle）与子页（subpageHeaderBlurStyle）两档独立设置。模型层
// 口径由 test/models/header_blur_style_test.dart 钉住；这里钉住**消费侧
// 接线**：子页顶栏外壳（HyperosFrostedHeaderShell）必须读子页档，首页玻璃
// 带（HomePageChromeGlassFill）必须读首页档——两者接反、或任一侧改回单一
// 全局字段时，本文件必须失败。
//
// 测试环境（VM）liveBlurSupported=false：只断言 FrostedHeaderBackground 收
// 到的 blurStyle（widget 字段），不涉及真实模糊渲染。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';

const _appearance = FrostedAppearance(
  sheetBlurSigma: 15,
  sheetTintAlpha: 0.7,
  sheetBarrierAlpha: 0.2,
  // 两档故意取不同值：读到对方档位即接线错误。
  headerBlurStyle: HeaderBlurStyle.gaussian,
  // ignore: avoid_redundant_argument_values -- inspire 恰为默认档，显式写出以保持「两档互异」的接线判定。
  subpageHeaderBlurStyle: HeaderBlurStyle.inspire,
);

void main() {
  testWidgets('子页顶栏外壳读 subpageHeaderBlurStyleOf', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FrostedAppearanceScope(
          appearance: _appearance,
          child: HyperosFrostedHeaderShell(child: SizedBox(height: 56)),
        ),
      ),
    );
    await tester.pump();

    final bg = tester.widget<FrostedHeaderBackground>(
      find.byType(FrostedHeaderBackground),
    );
    expect(bg.blurStyle, HeaderBlurStyle.inspire);
  });

  testWidgets('首页玻璃带读 headerBlurStyleOf', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FrostedAppearanceScope(
          appearance: _appearance,
          child: HomePageChromeGlassFill(),
        ),
      ),
    );
    await tester.pump();

    final bg = tester.widget<FrostedHeaderBackground>(
      find.byType(FrostedHeaderBackground),
    );
    expect(bg.blurStyle, HeaderBlurStyle.gaussian);
  });
}
