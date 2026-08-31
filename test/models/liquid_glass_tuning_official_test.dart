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
}
