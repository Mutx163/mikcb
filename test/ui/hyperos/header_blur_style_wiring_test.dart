// 顶栏模糊风格两档字段的消费侧接线回归测试。
//
// 回归背景（2026-09-12）：7f301074 把顶栏模糊风格拆成首页
// （headerBlurStyle）与子页（subpageHeaderBlurStyle）两档独立设置。模型层
// 口径由 test/models/header_blur_style_test.dart 钉住；这里钉住**消费侧
// 接线**：子页顶栏外壳（HyperosFrostedHeaderShell）必须读子页档，首页玻璃
// 带（HomePageChromeGlassFill）必须读首页档——两者接反、或任一侧改回单一
// 全局字段时，本文件必须失败。
//
// 同日追加：柔光玻璃带的风格接线——渐进档 = inspire 可变模糊 + 柔光雾面
// 层叠组合；高斯档 = 原生 SoftGlassSurface（均匀雾）。液态档不接风格。
//
// 测试环境（VM）liveBlurSupported=false：只断言 widget 字段与类型组合，
// 不涉及真实模糊渲染。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/ui/hyperos/inspire/inspire_header_blur.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_surface.dart';
import 'package:university_timetable/models/soft_glass_tuning.dart';
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

void main() {  testWidgets('子页顶栏外壳读 subpageHeaderBlurStyleOf', (tester) async {
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

  group('柔光玻璃带跟随顶栏风格', () {
    // 柔光分支在 HomePageChromeGlassFill 里受 useBlur 门（VM 恒 false，
    // 走磨砂兜底），所以直接泵分派 widget 本体。
    Future<void> pumpBand(
      WidgetTester tester,
      HeaderBlurStyle style, {
      bool blurEnabled = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const FrostedAppearanceScope(
            appearance: FrostedAppearance(
              sheetBlurSigma: 15,
              sheetTintAlpha: 0.7,
              sheetBarrierAlpha: 0.2,
            ),
            child: SizedBox.expand(),
          ),
          builder: (_, child) => FrostedAppearanceScope(
            appearance: const FrostedAppearance(
              sheetBlurSigma: 15,
              sheetTintAlpha: 0.7,
              sheetBarrierAlpha: 0.2,
              glassMode: FrostedGlassMode.softGlass,
            ),
            child: Scaffold(
              body: SoftGlassHomeBand(
                blurStyle: style,
                blurEnabled: blurEnabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('渐进档：可变模糊 + 渐进雾面，内层不再叠模糊与雾', (tester) async {
      await pumpBand(tester, HeaderBlurStyle.inspire);

      // 组合契约（2026-09-12 首页「还是均匀柔光」回归）：
      // - 雾面底色交给 InspireHeaderBlur 的渐进衬底（顶边全雾、底边全清），
      //   颜色 = 柔光浮空导航配方的雾面色；
      // - SoftGlassSurface 只出边缘高光——它若再出内部均匀高斯，双层模糊
      //   会把可变衰减抹平（底边被均匀 σ 重糊）；若再叠均匀雾面，底边的
      //   「清」也被盖回去，两者都会退化回均匀柔光。
      final context = tester.element(find.byType(InspireHeaderBlur));
      final expectedFog = SoftGlassTokens.tint(
        context,
        blurEnabled: true,
        tintAlphaMultiplier:
            SoftGlassRecipe.floatingNavigation.tintAlphaMultiplier *
            SoftGlassTuning.defaults.tintAlphaMultiplier,
      );
      final inspire = tester.widget<InspireHeaderBlur>(
        find.byType(InspireHeaderBlur),
      );
      expect(inspire.style, HeaderBlurStyle.inspire);
      expect(inspire.tint, expectedFog);
      expect(inspire.tint, isNot(Colors.transparent));
      // σ 取柔光浮空导航配方（× 用户倍率），不是磨砂 sheetBlurSigma。
      expect(
        inspire.blurSigma,
        SoftGlassRecipe.floatingNavigation.blurSigmaWithMultiplier(
          SoftGlassTuning.defaults.blurRadiusMultiplier,
        ),
      );
      final soft = tester.widget<SoftGlassSurface>(
        find.byType(SoftGlassSurface),
      );
      // 内层禁止任何模糊与雾面（防双层模糊回归）。
      expect(soft.blurEnabled, isFalse);
      expect(soft.tint, Colors.transparent);
    });

    testWidgets('高斯档：原生 SoftGlassSurface，无可变模糊层', (tester) async {
      await pumpBand(tester, HeaderBlurStyle.gaussian);
      await tester.pump();

      expect(find.byType(InspireHeaderBlur), findsNothing);
      expect(find.byType(SoftGlassSurface), findsOneWidget);
    });

    testWidgets('模糊总开关关：两档都不画模糊层，字段如实下传', (tester) async {
      await pumpBand(tester, HeaderBlurStyle.inspire, blurEnabled: false);
      await tester.pump();

      expect(
        tester.widget<InspireHeaderBlur>(find.byType(InspireHeaderBlur))
            .blurEnabled,
        isFalse,
      );
      expect(
        tester.widget<SoftGlassSurface>(find.byType(SoftGlassSurface))
            .blurEnabled,
        isFalse,
      );
    });

    testWidgets('液态档不经柔光带（HomePageChromeGlassFill 分支隔离）', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance(
              sheetBlurSigma: 15,
              sheetTintAlpha: 0.7,
              sheetBarrierAlpha: 0.2,
              glassMode: FrostedGlassMode.liquidGlass,
            ),
            child: HomePageChromeGlassFill(),
          ),
        ),
      );
      await tester.pump();

      // VM 下液态面不可达（useBlur 门回退磨砂），但无论走哪个分支都不该
      // 出现柔光面——风格只可能经由 SoftGlassHomeBand 接入。
      expect(find.byType(SoftGlassSurface), findsNothing);
    });
  });
}
