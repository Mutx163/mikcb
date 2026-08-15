import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';

void main() {
  group('LiquidGlassTuning standard preset vs official defaults', () {
    test('standard preset matches LiquidGlassSettings() field by field', () {
      final settings = LiquidGlassTuning.defaults.toSheetSettings(
        brightness: Brightness.light,
      );
      final official = LiquidGlassSettings();

      expect(settings.thickness, official.thickness);
      expect(settings.blur, official.blur);
      expect(settings.glassColor, official.glassColor);
      expect(settings.lightIntensity, official.lightIntensity);
      expect(settings.ambientStrength, official.ambientStrength);
      expect(settings.refractiveIndex, official.refractiveIndex);
      expect(settings.saturation, official.saturation);
      expect(settings.chromaticAberration, official.chromaticAberration);
      expect(settings.visibility, official.visibility);
      expect(settings.lightAngle, closeTo(official.lightAngle, 1e-9));
    });
  });
}
