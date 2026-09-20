// 首页顶栏材质与子页顶栏风格的消费侧接线回归测试。
//
// 口径（2026-09-20 收口：首页顶栏材质只有「液态玻璃 / 实体」两档，与外观编辑器里
// 那两个选项逐字一致）：
// - 存量 progressive / gaussian / soft 在设置层就归到液态
//   （`TimetableSettings.sanitizeHomeBandGlassMaterial`），渲染侧再兜一层
//   「非 solid 即液态」——本文件钉的就是这一层：四个取值必须渲染出**同一棵树**，
//   不允许任何一档再分叉出"自己的磨砂样式"（用户 2026-09-20 报的「顶栏没有玻璃
//   效果」= 界面显示液态、实际渲染渐进磨砂）；
// - 实体 → 不透明纯色条；
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
    testWidgets('非实体一律走液态玻璃：存量档与 liquid 渲染逐字段相同', (tester) async {
      // 界面只有「液态玻璃 / 实体」两项，渲染侧按「非 solid 即液态」兜底。
      // 这条钉的是**四个取值不许分叉**：谁再给 progressive / gaussian / soft 接
      // 一条自己的磨砂分支，这里的 blurStyle / tint 对比就会红。
      //
      // VM liveBlurSupported=false ⇒ 液态玻璃按降级口径回落到衬底（半透明水洗、
      // 不渲染磨砂模糊）。真实玻璃面由液态玻璃自己的 widget 测试覆盖，这里只钉
      // 「分派到哪一支」。
      FrostedHeaderBackground? liquid;
      for (final material in ['liquid', 'progressive', 'gaussian', 'soft']) {
        await _pumpFill(tester, material);
        final bg = tester.widget<FrostedHeaderBackground>(
          find.byType(FrostedHeaderBackground),
        );
        expect(bg.blurEnabled, isFalse, reason: material);
        if (liquid == null) {
          liquid = bg;
          continue;
        }
        expect(bg.blurStyle, liquid.blurStyle, reason: material);
        expect(bg.blurSigma, liquid.blurSigma, reason: material);
        expect(bg.tint, liquid.tint, reason: material);
      }

      // 降级态是**均匀的半透明水洗**（`ColoredBox` + alpha < 1），不是实体档那条
      // 不透明实心条，也不是会切出横向硬边的渐变衬底。
      final wash = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(HomePageChromeGlassFill),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(wash.color.a, lessThan(1.0));
      expect(wash.color, liquid!.tint);
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

    test('只有实体档不吃外溢：存量档与液态同口径（上边必须推出可见区）', () {
      // 外溢判据必须与渲染分支同源。曾按字面 `material == 'liquid'` 判：存量
      // progressive 会渲染液态玻璃却拿到 (0, 0) 外溢 —— 上边不再推出可见区，
      // 真机那条发丝线立刻回来。
      const band = 22.0;
      const rim = 3.0;
      for (final material in ['liquid', 'progressive', 'gaussian', 'soft']) {
        final overhang = homePageChromeGlassVerticalOverhang(
          material: material,
          refractionBand: band,
          rimWidth: rim,
        );
        expect(overhang.top, greaterThanOrEqualTo(band), reason: material);
        expect(overhang.bottom, 0.0, reason: material);
      }
      final solid = homePageChromeGlassVerticalOverhang(
        material: 'solid',
        refractionBand: band,
        rimWidth: rim,
      );
      expect(solid.top, 0.0);
      expect(solid.bottom, 0.0);
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
