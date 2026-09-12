import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
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
      expect(
        settings.chromaticAberration,
        barGlassDefaults.chromaticAberration,
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
      expect(tokensSettings.refractiveIndex, barGlassDefaults.refractiveIndex);
      expect(tokensSettings.saturation, barGlassDefaults.saturation);
      expect(
        tokensSettings.chromaticAberration,
        barGlassDefaults.chromaticAberration,
      );
      expect(tokensSettings.lightAngle, closeTo(barGlassDefaults.lightAngle, 1e-9));
    });
  });

  /// 「液态玻璃 → 厚度」滑杆在 standard 渲染档下的可见性回归。
  ///
  /// 背景：全 app 跑 GlassQuality.standard 后，包内 lightweight_glass.frag 的
  /// 折射位移只在 PATH A（有背景纹理）里执行，而本项目从未安装
  /// LiquidGlassScope，恒走 PATH B——thickness 在那里只剩不可辨的边缘 rim，
  /// 滑杆 0..40 拉满观感不变。修法是把厚度折算成 PATH B 真正生效的
  /// edgeAbsorption / fresnelStrength。下面把这条链钉住。
  group('thickness drives visible optics in the standard tier', () {
    double absorptionFor(double thickness) => LiquidGlassTuning(
      thickness: thickness,
    ).toSheetSettings(brightness: Brightness.light).edgeAbsorption;
    double fresnelFor(double thickness) => LiquidGlassTuning(
      thickness: thickness,
    ).toSheetSettings(brightness: Brightness.light).fresnelStrength;

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
      expect(sheet.edgeAbsorption, greaterThan(0));
    });
  });
}
