import 'package:flutter/widgets.dart';

import '../models/timetable_settings.dart';

/// Resolved font family for [AppFontMode], including CJK fallbacks.
class AppFontSpec {
  const AppFontSpec({this.fontFamily, this.fontFamilyFallback = const []});

  final String? fontFamily;
  final List<String> fontFamilyFallback;

  TextStyle applyTo(TextStyle style) {
    final fontFamily = this.fontFamily;
    if (fontFamily == null || fontFamily.isEmpty) {
      return style;
    }
    return style.copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }
}

/// Merges the active app font from [DefaultTextStyle] into [style].
TextStyle applyAppFontStyle(BuildContext context, TextStyle style) {
  final appFont = DefaultTextStyle.of(context).style;
  return style.copyWith(
    fontFamily: appFont.fontFamily,
    fontFamilyFallback: appFont.fontFamilyFallback,
  );
}

extension AppFontModeFontSpec on AppFontMode {
  AppFontSpec get fontSpec => switch (this) {
    AppFontMode.system => const AppFontSpec(),
    AppFontMode.sansSerif => const AppFontSpec(fontFamily: 'sans-serif'),
    AppFontMode.miSans => const AppFontSpec(
      fontFamily: 'MiSans',
      fontFamilyFallback: ['MiSans Latin', 'sans-serif'],
    ),
    AppFontMode.harmonyOS => const AppFontSpec(
      fontFamily: 'HarmonyOS Sans SC',
      fontFamilyFallback: ['HarmonyOS Sans', 'sans-serif'],
    ),
    AppFontMode.oppoSans => const AppFontSpec(
      fontFamily: 'OPlus Sans SC 3.5',
      fontFamilyFallback: ['OPlusSans SC', 'OPPOSans', 'sans-serif'],
    ),
    AppFontMode.pingFang => const AppFontSpec(
      fontFamily: 'PingFang SC',
      fontFamilyFallback: ['PingFangSC-Regular', 'sans-serif'],
    ),
    AppFontMode.notoSans => const AppFontSpec(
      fontFamily: 'Noto Sans CJK SC',
      fontFamilyFallback: ['Noto Sans SC', 'sans-serif'],
    ),
    AppFontMode.serif => const AppFontSpec(fontFamily: 'serif'),
    AppFontMode.songti => const AppFontSpec(
      fontFamily: 'Songti SC',
      fontFamilyFallback: ['STSong', 'Noto Serif CJK SC', 'serif'],
    ),
    AppFontMode.monospace => const AppFontSpec(fontFamily: 'monospace'),
  };
}
