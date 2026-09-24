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
// - 子页顶栏外壳（HyperosFrostedHeaderShell）恒为渐进档 —— 2026-09-23 起该档
//   锁死（设置里不再有选项），模糊下沿比标题行多画一个字高；
// - inspire 高斯档必须用 UniformDistribution：包的 extent 语义是「衰减到
//   零的位置」，曾把 0.12 当底边收边传入，整条带只有顶部 12% 有模糊
//   （2026-09-12 真机「全局柔光 + 子页高斯 = 顶栏全透明」根因）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inspire_blur/inspire_blur.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/ui/hyperos/hyperos_blurred_header.dart';
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
  testWidgets('子页顶栏外壳锁死渐进档，并把模糊下沿撑到标题下方', (tester) async {
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

  testWidgets('模糊下沿按 bottomOverhang 往下多画，带子本身高度不变', (tester) async {
    // 用户口径 2026-09-23：「让模糊靠下一点，最底下模糊的边界再往下，超过标题
    // 底部一个字空间」。这条钉的是**只往下多画**：标题行（带子本体）的高度一点
    // 不涨，正文顶部留白因此不动，涨的只有模糊/衬底那一层的下沿。
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: InspireHeaderBlur(
              tint: Color(0x99FFFFFF),
              bottomOverhang: 20,
              child: SizedBox(height: 56),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(InspireHeaderBlur)).height, 56);
    final bandStack = tester.widget<Stack>(
      find
          .descendant(
            of: find.byType(InspireHeaderBlur),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(
      bandStack.clipBehavior,
      Clip.none,
      reason: '内层 Stack 不能把 bottomOverhang 多出的那一截裁掉',
    );
    final tintLayer = find.descendant(
      of: find.byType(InspireHeaderBlur),
      matching: find.byType(DecoratedBox),
    );
    expect(tintLayer, findsOneWidget);
    expect(
      tester.getSize(tintLayer).height,
      76,
      reason: '衬底/模糊层要比标题行多画 20（= 一个字高）',
    );
  });

  group('首页玻璃带按材质分派（HomePageChromeGlassFill）', () {
    testWidgets('液态走液态玻璃（测试环境降级为水洗），frost 走磨砂带', (tester) async {
      // 渲染侧只消费**生效值**：存量 progressive / gaussian / soft 在设置层就
      // 归到液态、'follow' 解析成 frost/liquid/solid（2026-09-23 起），永远不会
      // 以原始值进入这里 —— 所以候选只有 liquid / frost / solid 三个。
      //
      // VM liveBlurSupported=false ⇒ 液态玻璃按降级口径回落到衬底（半透明水洗、
      // 不渲染磨砂模糊）。真实玻璃面由液态玻璃自己的 widget 测试覆盖，这里只钉
      // 「分派到哪一支」。
      await _pumpFill(tester, 'liquid');
      final wash = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(HomePageChromeGlassFill),
          matching: find.byType(ColoredBox),
        ),
      );
      // 降级态是**均匀的半透明水洗**，不是实体档那条不透明实心条。
      expect(wash.color.a, lessThan(1.0));

      // 'frost'（跟随默认 + 默认档高斯）→ 磨砂带：渐进模糊链路（inspire 风格），
      // 不再被吞进液态分支 —— 它没有折射，也不吃液态调参。
      await _pumpFill(tester, 'frost');
      final bg = tester.widget<FrostedHeaderBackground>(
        find.byType(FrostedHeaderBackground),
      );
      expect(bg.blurEnabled, isFalse);
      expect(bg.blurStyle, HeaderBlurStyle.inspire);
      // 磨砂带的水洗色就是降级液态那条（同一取色口径），只是形状/风格不同。
      expect(bg.tint, wash.color);
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

    test('液态档吃外溢：frost 与实体同口径（磨砂带没有折射位移）', () {
      // 外溢判据与渲染分支同源：只有液态玻璃有折射位移，上边必须推出可见区。
      // 磨砂带（'frost'，跟随默认 + 默认档高斯）没有折射，与实体一样不吃外溢 ——
      // 谁再把 frost 误判成液态（比如按"非实体"判），这里的 overhang.top 就会红。
      const band = 22.0;
      const rim = 3.0;
      final liquid = homePageChromeGlassVerticalOverhang(
        material: 'liquid',
        refractionBand: band,
        rimWidth: rim,
      );
      expect(liquid.top, greaterThanOrEqualTo(band));
      expect(liquid.bottom, 0.0);
      for (final material in ['frost', 'solid']) {
        final overhang = homePageChromeGlassVerticalOverhang(
          material: material,
          refractionBand: band,
          rimWidth: rim,
        );
        expect(overhang.top, 0.0, reason: material);
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
      );
      final progressive = InspireHeaderBlur.configFor(
        HeaderBlurStyle.inspire,
        gaussianSigma: 15,
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

    test('渐进档用固定常量（2026-09-23：浓淡只要一个档位）', () {
      final progressive = InspireHeaderBlur.configFor(
        HeaderBlurStyle.inspire,
        gaussianSigma: 15,
      );
      // 渐进档不读全局高斯 sigma（15），用的是它自己那个写死的档。
      expect(progressive.effectiveSigmaX, InspireHeaderBlur.progressiveSigma);
      // 用户口径「让顶部再模糊一点」：15 → 22。
      expect(InspireHeaderBlur.progressiveSigma, 22);

      // extent = 渐变里「模糊衰减到 0」所在的带宽比例：1.0 = 正好落在带底。
      double fadeEndStop(InspireBlurConfig config) {
        final dist = config.distribution as DirectionalDistribution;
        for (var i = 0; i < dist.stops.length; i++) {
          if (dist.values[i] <= 0) return dist.stops[i];
        }
        return 1;
      }

      expect(progressive.distribution, isA<DirectionalDistribution>());
      expect(
        fadeEndStop(progressive),
        closeTo(InspireHeaderBlur.progressiveExtent, 1e-9),
      );
      // 边界必须落在带底（留一丝就会和下方清晰内容硬切一条横向边）。
      expect(InspireHeaderBlur.progressiveExtent, 1);

      // 高斯档不受影响：仍是全局模糊强度。
      final gaussian = InspireHeaderBlur.configFor(
        HeaderBlurStyle.gaussian,
        gaussianSigma: 15,
      );
      expect(gaussian.effectiveSigmaX, 15);
    });

    test('子页顶栏模糊下沿比标题多画 ≈ 一个字高（2026-09-23 口径）', () {
      // 用户口径：「最底下模糊的边界再往下，超过标题底部一个字空间」。
      // 一个字高按 20dp 取；这个值同时是"模糊往下的距离"与"上限"，
      // 太大就会盖住正文第一条。
      expect(HyperosBlurredHeader.subpageBandBottomOverhang, 20);
    });
  });
}
