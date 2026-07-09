import '../models/timetable_settings.dart';
import 'hyperos/frosted/frosted_appearance.dart';

/// Maps app [TimetableSettings] into HyperOS [FrostedAppearance].
extension TimetableSettingsFrostedAppearance on TimetableSettings {
  FrostedAppearance get frostedAppearance => FrostedAppearance(
    sheetBlurSigma: frostedSheetBlurSigma,
    sheetTintAlpha: frostedSheetTintAlpha,
    sheetBarrierAlpha: frostedSheetBarrierAlpha,
    blurEnabled: frostedBlurEnabled,
  );
}
