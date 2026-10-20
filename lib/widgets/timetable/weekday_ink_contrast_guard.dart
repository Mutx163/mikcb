import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/timetable_settings.dart';
import '../../providers/timetable_provider.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/hex_color.dart';
import '../../utils/home_page_background.dart';
import '../home_page_region_blur.dart';
import 'timetable_weekday_ink_contrast_dialog.dart';

/// 「自定义星期栏墨色在壁纸上快看不见了」的一次性提醒（2026-10-20 从
/// `TimetableScreen` State 搬出）。
///
/// 颜色/壁纸/主题组合已提醒过（持久化）就静默；弹窗期间用 [showing] 去重。
class WeekdayInkContrastGuard {
  String? _warnedSignature;
  bool _showing = false;

  /// 判断并（必要时）弹一次提醒；[luminance] 是星期栏背后的实际亮度带。
  void maybeWarn({
    required BuildContext context,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required double? luminance,
  }) {
    // Judge custom ink against the band actually behind the weekday bar, not
    // the status/title strip above it.
    if (luminance == null || _showing) {
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!hasHomePageBackdrop(settings)) {
      return;
    }
    // 实体档那条带是不透明实心条，星期栏压根不在壁纸上 ⇒ 这条「对比度不够」的
    // 提醒在实体档下是假的（拿壁纸亮度去判一张实底上的字），别弹。液态 / 磨砂
    // 带在模糊管线不在时同样降级为实心条，也不弹。
    if (!homePageWeekdayBarOverWallpaper(
      settings: settings,
      hasBackdrop: true,
      blurPipelineOn: HyperosBlurredHeader.backdropBlurEnabled(context),
    )) {
      return;
    }
    final configuredHex = isDark
        ? settings.weekdayBarFontColorDark
        : settings.weekdayBarFontColorLight;
    final defaultHex = isDark
        ? TimetableSettings.defaultWeekdayBarFontColorDark
        : TimetableSettings.defaultWeekdayBarFontColorLight;
    // Default ink already auto-flips with the wallpaper; only a custom pick
    // can go invisible (and trigger the temporary auto flip).
    if (homePageInkUsesBuiltInDefault(configuredHex, defaultHex)) {
      return;
    }
    final ink = tryParseHexColor(configuredHex);
    if (ink == null) {
      return;
    }
    // ~WCAG ratio against the sampled band; photos are busy, so anything
    // above 3:1 is left alone — this only catches "nearly invisible".
    if (homePageInkHasSufficientContrast(ink, luminance)) {
      return;
    }
    final signature =
        '$configuredHex|${homePageBackdropKey(settings) ?? ''}|'
        '$isDark';
    if (_warnedSignature == signature) {
      return;
    }
    _warnedSignature = signature;
    unawaited(
      _showDialog(
        context: context,
        provider: provider,
        signature: signature,
        wallpaperIsDark: luminance < 0.45,
        isDarkTheme: isDark,
        defaultHex: defaultHex,
      ),
    );
  }

  Future<void> _showDialog({
    required BuildContext context,
    required TimetableProvider provider,
    required String signature,
    required bool wallpaperIsDark,
    required bool isDarkTheme,
    required String defaultHex,
  }) async {
    const prefsKey = 'weekday_ink_contrast_warned_signature';
    final prefs = await SharedPreferences.getInstance();
    // Same colour + wallpaper + theme was already explained once (persisted):
    // the user chose to keep it, so do not nag on every launch.
    if (prefs.getString(prefsKey) == signature) {
      return;
    }
    if (!context.mounted || _showing) {
      return;
    }
    _showing = true;
    await prefs.setString(prefsKey, signature);
    if (!context.mounted) {
      _showing = false;
      return;
    }
    try {
      await showTimetableWeekdayInkContrastDialog(
        context,
        wallpaperIsDark: wallpaperIsDark,
        onResetDefault: () => resetTimetableWeekdayInkToDefault(
          context,
          provider: provider,
          isDarkTheme: isDarkTheme,
          defaultHex: defaultHex,
        ),
      );
    } finally {
      _showing = false;
    }
  }
}
