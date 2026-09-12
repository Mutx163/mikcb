import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_tokens.dart';

/// GlassTabBar 内部默认（kBottomBarGlassDefaults）——iOS 26 Apple News /
/// Safari tab bar 调校：深折射、微模糊、24% 白、135° 左上光源。
/// 项目所有玻璃表面（弹窗/顶栏/菜单）默认都对齐这一组值，保证全 app 一致。
const barGlassDefaults = LiquidGlassSettings(
  thickness: 30,
  blur: 3,
  chromaticAberration: 0.3,
  lightIntensity: 0.6,
  refractiveIndex: 1.59,
  saturation: 0.7,
  ambientStrength: 1,
  glassColor: Color(0x3DFFFFFF),
);

void main() {
  group('LiquidGlassTuning standard preset matches bar defaults', () {
    test('standard preset matches kBottomBarGlassDefaults field by field', () {
      final settings = LiquidGlassTuning.defaults.toSheetSettings(
        brightness: Brightness.light,
      );

      expect(settings.thickness, barGlassDefaults.thickness);
      expect(settings.blur, barGlassDefaults.blur);
      // 0x3D/255 = 0.2392 vs tuning tintAlpha 0.24：允许 1e-3 精度差。
      expect(
        settings.glassColor.a,
        closeTo(barGlassDefaults.glassColor.a, 1e-3),
      );
      expect(settings.lightIntensity, barGlassDefaults.lightIntensity);
      expect(settings.ambientStrength, barGlassDefaults.ambientStrength);
      // 项目默认折射率已从 1.59 收敛为 1.5（与滑杆上限 maxRefractiveIndex
      // 对齐，clamp 后无漂移），刻意不再跟随包内底栏默认的 1.59。
      expect(settings.refractiveIndex, 1.5);
      expect(settings.saturation, barGlassDefaults.saturation);
      // 项目默认色差同样从包内底栏的 0.3 收敛为滑杆上限 0.12：0.3 换算到
      // 轻量着色器是 3.5dp 级的边缘 RGB 分离，真机读作「一条彩虹描边」，
      // 且滑杆最左只能到 0.12——用户关不干净。与 refractiveIndex 同型处理。
      expect(settings.chromaticAberration, 0.12);
      expect(
        settings.chromaticAberration,
        LiquidGlassTuning.maxChromaticAberration,
      );
      expect(settings.visibility, barGlassDefaults.visibility);
      expect(settings.lightAngle, closeTo(barGlassDefaults.lightAngle, 1e-9));
      // 默认厚度 30 是「厚度 → 可见光学量」的枢轴：两个补偿量必须精确等于
      // LiquidGlassSettings 的构造默认，出厂观感与历史版本逐字段一致。
      expect(settings.edgeAbsorption, 0.0);
      expect(settings.fresnelStrength, 1.0);
    });

    test('tokens static default matches bar defaults', () {
      final tokensSettings = MikcbLiquidGlassTokens.sheetSettingsFor(
        Brightness.light,
      );
      expect(tokensSettings.thickness, barGlassDefaults.thickness);
      expect(tokensSettings.blur, barGlassDefaults.blur);
      expect(
        tokensSettings.glassColor.a,
        closeTo(barGlassDefaults.glassColor.a, 1e-3),
      );
      expect(tokensSettings.lightIntensity, barGlassDefaults.lightIntensity);
      expect(tokensSettings.ambientStrength, barGlassDefaults.ambientStrength);
      expect(tokensSettings.saturation, barGlassDefaults.saturation);
      expect(tokensSettings.lightAngle, closeTo(barGlassDefaults.lightAngle, 1e-9));
      // 与包内底栏默认的两处**有意**差异：折射率收敛到滑杆上限 1.5（1.59
      // clamp 后会漂移），色散收敛到滑杆上限 0.12（0.3 在轻量着色器里是
      // 3.5dp 级 RGB 分离，真机读作边缘彩虹描边，且滑杆关不干净）。
      // 这条兜底常量与 LiquidGlassTuning.defaults 必须同步，否则「没进过
      // 高级材质页」的用户拿不到同样的观感。
      expect(tokensSettings.refractiveIndex, 1.5);
      expect(tokensSettings.chromaticAberration, 0.12);
      expect(
        tokensSettings.chromaticAberration,
        LiquidGlassTuning.defaults.chromaticAberration,
      );
      expect(
        tokensSettings.refractiveIndex,
        LiquidGlassTuning.defaults.refractiveIndex,
      );
    });
  });

  /// 「液态玻璃 → 厚度」滑杆在 standard 渲染档下的可见性回归。
  ///
  /// 背景：全 app 跑 GlassQuality.standard 后，包内 lightweight_glass.frag 的
  /// 折射位移只在 PATH A（有背景纹理）里执行，而本项目从未安装
  /// LiquidGlassScope，恒走 PATH B——thickness 在那里只剩不可辨的边缘 rim，
  /// 滑杆 0..40 拉满观感不变。修法是把厚度折算成 PATH B 真正生效的
  /// edgeAbsorption / fresnelStrength。下面把这条链钉住。
  /// 「色差」默认值越界：滑杆上限 0.12，构造默认却是 0.3（实测真机观感 =
  /// 玻璃边缘一条彩虹描边）。0.3 × edgeInfluence × 0.006 换算成像素是
  /// 3.5dp 级的 RGB 分离，远超 iOS 26 药丸的 0.15 量级；而滑杆最左只能拖到
  /// 0.12（1.4dp）——用户想关小也关不干净。成因与 refractiveIndex 那次
  /// （1.59 → 1.5）完全同型：构造默认超出自己的滑杆上限，UI 与内存默认脱节。
  group('chromatic aberration default sits inside its own slider range', () {
    test('default never exceeds maxChromaticAberration', () {
      expect(
        LiquidGlassTuning.defaultChromaticAberration,
        lessThanOrEqualTo(LiquidGlassTuning.maxChromaticAberration),
      );
      expect(
        LiquidGlassTuning.maxChromaticAberration,
        LiquidGlassTuning.defaultChromaticAberration,
      );
    });

    test('every shipped preset also stays inside the slider range', () {
      for (final tuning in [
        LiquidGlassTuning.presetClear,
        LiquidGlassTuning.presetLight,
        LiquidGlassTuning.presetStandard,
        LiquidGlassTuning.presetDense,
      ]) {
        expect(
          tuning.chromaticAberration,
          lessThanOrEqualTo(LiquidGlassTuning.maxChromaticAberration),
        );
      }
    });
  });

  group('thickness drives visible optics in the standard tier', () {
    // 厚度补偿已从 toSheetSettings 移到表面层：PATH A（真折射）由
    // HyperosLiquidGlassSurface.withThicknessOptics 清零补偿，PATH B 由
    // withoutThicknessOptics 按生效厚度写入。此处直接钉这两个纯函数，
    // 不再经由 toSheetSettings（它现在与本补偿无关）。
    LiquidGlassSettings pathB(double thickness) =>
        HyperosLiquidGlassSurface.withoutThicknessOptics(
          const LiquidGlassSettings(),
          LiquidGlassTuning(thickness: thickness),
        );
    double absorptionFor(double thickness) =>
        pathB(thickness).edgeAbsorption;
    double fresnelFor(double thickness) => pathB(thickness).fresnelStrength;

    test('PATH A drops the compensation: no double counting', () {
      // 真折射通道下 thickness 本身就驱动折射位移（shader 里
      // edgeOffset = surfaceNormal * edgeInfluence * uThickness * 0.5），
      // 再叠 edgeAbsorption / fresnelStrength 就是双重计数。
      final pathA = HyperosLiquidGlassSurface.withThicknessOptics(
        LiquidGlassTuning(thickness: 40).toSheetSettings(
          brightness: Brightness.light,
        ),
        const LiquidGlassTuning(thickness: 40),
      );
      expect(pathA.edgeAbsorption, 0.0);
      expect(pathA.fresnelStrength, 1.0);
      // 厚度本身必须保留（折射位移靠它）。
      expect(pathA.thickness, 40);
    });

    test('toSheetSettings itself no longer bakes in the compensation', () {
      // 契约：补偿是**渲染路径**的信息，不属于模型层。若此处又出现非零值，
      // PATH A 表面就会双重计数。
      final sheet = const LiquidGlassTuning(thickness: 40).toSheetSettings(
        brightness: Brightness.light,
      );
      expect(sheet.edgeAbsorption, 0.0);
      expect(sheet.fresnelStrength, 1.0);
    });

    test('default thickness is the pivot: package defaults, zero drift', () {
      expect(LiquidGlassTuning.defaultThickness, 30);
      expect(absorptionFor(LiquidGlassTuning.defaultThickness), 0.0);
      expect(fresnelFor(LiquidGlassTuning.defaultThickness), 1.0);
    });

    test('shipped presets no longer look identical when dragged', () {
      // 四个内置预设的厚度 24/26/30/36 必须给出互不相同的可见反馈，
      // 否则「清澈 ↔ 浓密」在 standard 档下仍然只靠 tint 区分。
      final fresnels = [
        LiquidGlassTuning.presetClear,
        LiquidGlassTuning.presetLight,
        LiquidGlassTuning.presetStandard,
        LiquidGlassTuning.presetDense,
      ].map((t) => t.visibleThicknessOptics().fresnelStrength).toList();
      expect(fresnels.toSet().length, fresnels.length);
      expect(
        LiquidGlassTuning.presetDense.visibleThicknessOptics().edgeAbsorption,
        greaterThan(0),
      );
      expect(
        LiquidGlassTuning.presetClear.visibleThicknessOptics().fresnelStrength,
        lessThan(1.0),
      );
    });

    test('0 / mid / max are strictly monotonic in both channels', () {
      const thicknesses = [0.0, 10.0, 20.0, 24.0, 30.0, 32.0, 36.0, 40.0];
      var previousAbsorption = -1.0;
      var previousFresnel = -1.0;
      for (final thickness in thicknesses) {
        final optics = LiquidGlassTuning(
          thickness: thickness,
        ).visibleThicknessOptics();
        expect(optics.edgeAbsorption, greaterThanOrEqualTo(previousAbsorption));
        expect(optics.fresnelStrength, greaterThan(previousFresnel));
        // 包内对这两个量的 clamp 窗口是 absorption 0..1 / fresnel 0..4。
        expect(optics.edgeAbsorption, inInclusiveRange(0.0, 1.0));
        expect(optics.fresnelStrength, inInclusiveRange(0.0, 4.0));
        previousAbsorption = optics.edgeAbsorption;
        previousFresnel = optics.fresnelStrength;
      }
      // 两端必须是「真的不一样」：0 厚度完全无边缘，满厚度明显更沉更亮。
      const min = LiquidGlassTuning(
        thickness: LiquidGlassTuning.minThickness,
      );
      const max = LiquidGlassTuning(
        thickness: LiquidGlassTuning.maxThickness,
      );
      final minOptics = min.visibleThicknessOptics();
      final maxOptics = max.visibleThicknessOptics();
      expect(minOptics.fresnelStrength, 0.0);
      expect(
        maxOptics.edgeAbsorption,
        LiquidGlassTuning.maxThicknessEdgeAbsorption,
      );
      expect(
        maxOptics.fresnelStrength,
        closeTo(1.0 + LiquidGlassTuning.maxThicknessFresnelBoost, 1e-9),
      );
      // 滑杆两端在可见量上的落差必须足够大，才谈得上「调节有效」。
      expect(
        maxOptics.fresnelStrength - minOptics.fresnelStrength,
        greaterThan(1.0),
      );
      expect(
        maxOptics.edgeAbsorption - minOptics.edgeAbsorption,
        greaterThan(0.1),
      );
    });

    test('visibility scales effective thickness, so the two sliders agree', () {
      // 有效厚度 = thickness × visibility（与包内 effectiveThickness 同源）：
      // 可见性拉到一半，厚度观感应回落，而不是两个滑杆各说各话。
      final full = const LiquidGlassTuning(
        thickness: 40,
      ).visibleThicknessOptics();
      final half = const LiquidGlassTuning(
        thickness: 40,
        visibility: 0.5,
      ).visibleThicknessOptics();
      expect(half.fresnelStrength, lessThan(full.fresnelStrength));
      expect(half.edgeAbsorption, lessThan(full.edgeAbsorption));
    });

    test('nested tile / course card carry the same optics as sheets', () {
      const tuning = LiquidGlassTuning(thickness: 40);
      final sheet = tuning.toSheetSettings(brightness: Brightness.dark);
      expect(
        tuning.toNestedTileSettings(brightness: Brightness.dark),
        sheet,
      );
      expect(
        tuning.toCourseCardSettings(brightness: Brightness.dark),
        sheet,
      );
      // 三个角色共用同一份基础设置；厚度补偿由表面层按渲染路径追加，
      // 三者路径相同时结果也必然相同。
      expect(
        HyperosLiquidGlassSurface.withoutThicknessOptics(sheet, tuning)
            .edgeAbsorption,
        greaterThan(0),
      );
    });
  });
}