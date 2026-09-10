import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../models/timetable_settings.dart';

export '../models/timetable_settings.dart'
    show
        kAppFontWeightDefault,
        kAppFontWeightDivisions,
        kAppFontWeightMax,
        kAppFontWeightMin,
        kAppTextScaleDefault,
        kAppTextScaleDivisions,
        kAppTextScaleMax,
        kAppTextScaleMin,
        normalizeAppFontWeight,
        normalizeAppTextScale;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppFontSpec &&
          other.fontFamily == fontFamily &&
          listEquals(other.fontFamilyFallback, fontFamilyFallback));

  @override
  int get hashCode =>
      Object.hash(fontFamily, Object.hashAll(fontFamilyFallback));
}

/// 根部下发的全局字体上下文：用户字重、系统字重增量、字体族。
///
/// HyperOS 原生风格文本（`HyperosTypography` / 折叠大标题）走硬编码
/// [TextStyle]，不会自动继承 [ThemeData.textTheme] 的字重覆盖，必须经此
/// scope 显式解析，才能与设置页滑杆一致。字号缩放走根部 [MediaQuery] 的
/// `textScaler`，不需要在此重复缩放。
class AppFontScope extends InheritedWidget {
  const AppFontScope({
    super.key,
    required this.userFontWeight,
    required this.systemFontWeightDelta,
    required this.fontSpec,
    required super.child,
  });

  /// 用户设置的全局字重（100–900）。
  final int userFontWeight;

  /// 系统 `fontWeightAdjustment` / 粗体文字增量（可正可负）。
  final int systemFontWeightDelta;

  final AppFontSpec fontSpec;

  static AppFontScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppFontScope>();

  /// 把设计稿字重解析成运行时字重。
  ///
  /// - 用户设定了非默认字重：整页绝对覆盖（与 Material `TextTheme` 一致）。
  /// - 用户未改：保留设计角色层级；若系统有粗体增量，对硬编码样式做
  ///   与原先大标题相同的补偿（减去系统增量，避免被再叠一层加粗）。
  int resolveWeight(int designWeight) {
    if (userFontWeight != kAppFontWeightDefault) {
      return userFontWeight.clamp(kAppFontWeightMin, kAppFontWeightMax);
    }
    return (designWeight - systemFontWeightDelta).clamp(
      kAppFontWeightMin,
      kAppFontWeightMax,
    );
  }

  @override
  bool updateShouldNotify(AppFontScope oldWidget) =>
      userFontWeight != oldWidget.userFontWeight ||
      systemFontWeightDelta != oldWidget.systemFontWeightDelta ||
      fontSpec != oldWidget.fontSpec;
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
