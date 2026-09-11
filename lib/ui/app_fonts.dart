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
  ///
  /// 适合「层级靠字号/颜色表达」的文本（HyperosTypography 全站都是 w400，
  /// 覆盖不会丢层级）。层级本身靠字重表达的文本（课程卡片标题粗、详情常规）
  /// 必须改用 [resolveShiftedWeight]，否则会被压成同一档。
  int resolveWeight(int designWeight) {
    if (userFontWeight != kAppFontWeightDefault) {
      return userFontWeight.clamp(kAppFontWeightMin, kAppFontWeightMax);
    }
    return (designWeight - systemFontWeightDelta).clamp(
      kAppFontWeightMin,
      kAppFontWeightMax,
    );
  }

  /// 把设计稿字重按用户字重**整体平移**，保留角色之间的层级差。
  ///
  /// 课卡这类文本的层级就是字重本身（标题 w700 / 详情 w400），绝对覆盖会让
  /// 标题与详情变成同一档、卡片失去主次。这里改为平移：
  ///
  /// - 用户设了非默认字重：每个角色都加上 `用户字重 - w400`，w700 标题与
  ///   w400 详情同步变粗/变细，差值保留。
  /// - 用户未改：只做系统粗体增量补偿，与 [resolveWeight] 同口径。
  ///
  /// 平移结果同样钳制在 w100–w900：用户滑到极值（如 w900）时角色差值会
  /// 因上下限收敛，这是有意的（不能超出字体可用的字重范围）。
  int resolveShiftedWeight(int designWeight) {
    if (userFontWeight != kAppFontWeightDefault) {
      return (designWeight + userFontWeight - kAppFontWeightDefault).clamp(
        kAppFontWeightMin,
        kAppFontWeightMax,
      );
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
