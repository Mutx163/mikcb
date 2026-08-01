import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/widgets/frosted_sheet_settings_preview.dart';

void main() {
  group('FrostedSheetSettingsPreview.previewSafeTuning', () {
    test('clamps thickness/blur at the dense preset (artifact-free ceiling)', () {
      final safe = FrostedSheetSettingsPreview.previewSafeTuning(
        const LiquidGlassTuning(thickness: 40, blur: 24),
      )!;
      expect(safe.thickness, LiquidGlassTuning.presetDense.thickness);
      expect(safe.blur, LiquidGlassTuning.presetDense.blur);
    });

    test('passes values at or below the ceiling through unchanged', () {
      const tuning = LiquidGlassTuning(thickness: 16, blur: 7);
      final safe = FrostedSheetSettingsPreview.previewSafeTuning(tuning)!;
      expect(safe.thickness, 16);
      expect(safe.blur, 7);
    });

    test('keeps the dense preset itself intact', () {
      final safe = FrostedSheetSettingsPreview.previewSafeTuning(
        LiquidGlassTuning.presetDense,
      )!;
      expect(safe, LiquidGlassTuning.presetDense);
    });

    test('clamps from a mid-range tuning only up to the ceiling', () {
      final safe = FrostedSheetSettingsPreview.previewSafeTuning(
        const LiquidGlassTuning(thickness: 32, blur: 18),
      )!;
      expect(safe.thickness, LiquidGlassTuning.presetDense.thickness);
      expect(safe.blur, LiquidGlassTuning.presetDense.blur);
    });

    test('does not touch the other knobs', () {
      final safe = FrostedSheetSettingsPreview.previewSafeTuning(
        const LiquidGlassTuning(
          thickness: 40,
          blur: 24,
          tintAlpha: 0.5,
          lightIntensity: 1.8,
          ambientStrength: 0.6,
          saturation: 2.0,
          refractiveIndex: 1.4,
        ),
      )!;
      expect(safe.tintAlpha, 0.5);
      expect(safe.lightIntensity, 1.8);
      expect(safe.ambientStrength, 0.6);
      expect(safe.saturation, 2.0);
      expect(safe.refractiveIndex, 1.4);
    });

    test('null tuning stays null', () {
      expect(FrostedSheetSettingsPreview.previewSafeTuning(null), isNull);
    });
  });
}
