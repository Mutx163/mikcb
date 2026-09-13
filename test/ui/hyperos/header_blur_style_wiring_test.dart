// 首页顶栏材质与子页顶栏风格的消费侧接线回归测试。
//
// 口径（2026-09-12 拍板：首页顶栏材质独立自由五档）：
// - HomePageChromeGlassFill 按材质分派：progressive → inspire 渐进衰减、
//   gaussian → 均匀高斯、solid → 实底衬底；soft/liquid 自带模糊，VM 下
//   liveBlurSupported=false 走实底回落（真机高级面由柔光/液态的既有
//   widget 测试覆盖），但无论环境如何都不得渲染出磨砂模糊样式；
// - 子页顶栏外壳（HyperosFrostedHeaderShell）读 subpageHeaderBlurStyleOf，
//   永不走高级材质；
// - inspire 高斯档必须用 UniformDistribution：包的 extent 语义是「衰减到
//   零的位置」，曾把 0.12 当底边收边传入，整条带只有顶部 12% 有模糊
//   （2026-09-12 真机「全局柔光 + 子页高斯 = 顶栏全透明」根因）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inspire_blur/inspire_blur.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/models/progressive_blur_tuning.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/ui/hyperos/inspire/inspire_header_blur.dart';
import 'package:university_timetable/ui/hyperos/hyperos_theme.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';

const _appearance = FrostedAppearance(
  sheetBlurSigma: 15,
  sheetTintAlpha: 0.7,
  sheetBarrierAlpha: 0.2,
);

FrostedAppearance _bandAppearance(String material) => FrostedAppearance(
  sheetBlurSigma: 15,
  sheetTintAlpha: 0.7,
  sheetBarrierAlpha: 0.2,
  homeBandGlassMaterial: material,
);

Future<void> _pumpFill(WidgetTester tester, String material) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FrostedAppearanceScope(
        appearance: _bandAppearance(material),
        child: const HomePageChromeGlassFill(),
      ),
    ),
  );
  await tester.pump();
}

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

  group('首页玻璃带按材质分派（HomePageChromeGlassFill）', () {
    testWidgets('渐进磨砂 → inspire 渐进衰减', (tester) async {
      await _pumpFill(tester, 'progressive');

      final bg = tester.widget<FrostedHeaderBackground>(
        find.byType(FrostedHeaderBackground),
      );
      expect(bg.blurStyle, HeaderBlurStyle.inspire);
    });

    testWidgets('高斯磨砂 → uniform 高斯档（真机语义）', (tester) async {
      await _pumpFill(tester, 'gaussian');

      final bg = tester.widget<FrostedHeaderBackground>(
        find.byType(FrostedHeaderBackground),
      );
      expect(bg.blurStyle, HeaderBlurStyle.gaussian);
    });

    testWidgets('实体 → 不透明纯色条，完全遮住壁纸', (tester) async {
      await _pumpFill(tester, 'solid');

      // 实体是显式选择：必须是不透明的页面底色实心条，而不是模糊关时的
      // 半透明淡色衬底（2026-09-12 真机「选实体是透明的」回归钉）。
      final context = tester.element(find.byType(HomePageChromeGlassFill));
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(HomePageChromeGlassFill),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, HyperosColors.scaffoldBackground(context));
      expect(box.color.a, 1.0);
    });

    testWidgets('柔光/液态在 VM 降级为实底，绝不渲染磨砂模糊样式', (tester) async {
      // VM liveBlurSupported=false：高级面按降级口径回落实底。这里钉的是
      // 「高级材质不带磨砂模糊样式」——若有人把 soft/liquid 误接进磨砂分
      // 支，blurStyle/blurEnabled 断言会失败。
      for (final material in ['soft', 'liquid']) {
        await _pumpFill(tester, material);
        final bg = tester.widget<FrostedHeaderBackground>(
          find.byType(FrostedHeaderBackground),
        );
        expect(bg.blurEnabled, isFalse, reason: material);
      }
    });
  });

  group('inspire 高斯档均匀分布（子页全透明 bug 回归钉）', () {
    test('高斯 = UniformDistribution；渐进 = 渐变衰减', () {
      final gaussian = InspireHeaderBlur.configFor(
        HeaderBlurStyle.gaussian,
        gaussianSigma: 15,
        tuning: ProgressiveBlurTuning.defaults,
      );
      final progressive = InspireHeaderBlur.configFor(
        HeaderBlurStyle.inspire,
        gaussianSigma: 15,
        tuning: ProgressiveBlurTuning.defaults,
      );
      expect(gaussian.distribution, isA<UniformDistribution>());
      expect(progressive.distribution, isNot(isA<UniformDistribution>()));
      // 高斯整带等强：sigma 如实进入配置。
      expect(gaussian.effectiveSigmaX, 15);
    });

    test('衬底渐变在带底恒为全透明（不留横向硬边）', () {
      // 回归钉：带底必须收敛到 alpha 0，否则玻璃带与下方内容的交界处会切出
      // 一条横向边。默认（0）退化成两段，与接入调参前逐像素一致。
      const top = Color(0x99FFFFFF);
      final flat = InspireHeaderBlur.tintGradient(top, 0);
      expect(flat.colors.length, 2);
      expect(flat.colors.first, top);
      expect(flat.colors.last.a, 0);

      for (final scale in [0.0, 0.18, 0.6]) {
        final gradient = InspireHeaderBlur.tintGradient(top, scale);
        expect(gradient.colors.last.a, 0, reason: 'scale=$scale 带底必须透明');
        if (scale <= 0) {
          // 默认档不加中间 stop，就是接入调参前那条两端渐变。
          expect(gradient.stops, isNull);
          continue;
        }
        // 中间 stop 才体现「下半段更压得住」，末段仍收敛到全透明。
        expect(gradient.colors[1].a, closeTo(top.a * scale, 1e-6));
        expect(gradient.stops!.last, 1);
        expect(gradient.stops![1], lessThan(1));
      }
    });

    test('渐进档吃自己的档位：sigma 与 extent 都来自 tuning', () {
      const tuning = ProgressiveBlurTuning(sigma: 24, extent: 0.6);
      final progressive = InspireHeaderBlur.configFor(
        HeaderBlurStyle.inspire,
        gaussianSigma: 15,
        tuning: tuning,
      );
      // 渐进档不再读全局高斯 sigma（15），而是档位自己的 24。
      expect(progressive.effectiveSigmaX, 24);
      // extent = 渐变里「模糊衰减到 0」所在的带宽比例：0.6 表示带宽 60%
      // 处就已收干（1.0 = 正好落在带底，即默认档）。
      double fadeEndStop(InspireBlurConfig config) {
        final dist = config.distribution as DirectionalDistribution;
        for (var i = 0; i < dist.stops.length; i++) {
          if (dist.values[i] <= 0) return dist.stops[i];
        }
        return 1;
      }

      expect(progressive.distribution, isA<DirectionalDistribution>());
      expect(fadeEndStop(progressive), closeTo(0.6, 1e-9));
      expect(
        fadeEndStop(
          InspireHeaderBlur.configFor(
            HeaderBlurStyle.inspire,
            gaussianSigma: 15,
            tuning: ProgressiveBlurTuning.defaults,
          ),
        ),
        closeTo(ProgressiveBlurTuning.defaultExtent, 1e-9),
      );
      // 高斯档不受 tuning 影响：仍是全局模糊强度。
      final gaussian = InspireHeaderBlur.configFor(
        HeaderBlurStyle.gaussian,
        gaussianSigma: 15,
        tuning: tuning,
      );
      expect(gaussian.effectiveSigmaX, 15);
    });
  });
}
