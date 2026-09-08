import 'package:flutter/material.dart';

import 'hex_color.dart';

/// 全局主题强调色（seed accent）的统一解析口径。
///
/// 用户在「外观 → 应用主题色」选择的 seed（[TimetableSettings.themeSeedColor]，
/// 预设主题与自定义色共用一个 hex）经由本文件派生全 App 强调色：
/// Hyperos 弹窗/控件（`HyperosColors.primary`）、Material colorScheme
/// （`colorScheme.primary`，含添加弹层三宫格按钮）、根部 Miuix 色板
/// （MiuixSwitch 开启色与 Miuix 选择器高亮）。
///
/// 可读性回落与八宫格 `resolveHomeGridMenuAccent` 同口径：磨砂/瓷贴上
/// 不可读的 seed（深色模式的近黑灰、浅色模式的亮黄）回落为玻璃墨色
/// （自动黑白），与课表玻璃卡「彩色墨回落自动黑白」一致。

/// 解析 seed hex 为强调色；不可读或缺失时返回 null，由调用方回落。
///
/// 阈值与 `resolveHomeGridMenuAccent` 一致：深色模式要求 luminance >= 0.08，
/// 浅色模式要求 <= 0.60。
Color? resolveThemeSeedAccent(String? seedHex, Brightness brightness) {
  final seed = tryParseHexColor(seedHex);
  if (seed == null) {
    return null;
  }
  final isDark = brightness == Brightness.dark;
  final luminance = seed.computeLuminance();
  final readable = isDark ? luminance >= 0.08 : luminance <= 0.60;
  return readable ? seed : null;
}

/// 按强调色实际亮度选择其上的墨水（黑/白）。
///
/// seed 接入后 onPrimary 不再是固定白：亮黄等高亮度 seed 上必须用黑墨。
Color onAccentInk(Color accent) {
  return accent.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// 把当前主题 seed 暴露给整棵组件树的 InheritedWidget。
///
/// 挂在 `MaterialApp.builder`（根 Navigator 之上），`HyperosColors` 等
/// 静态取色入口经 [ThemeSeedScope.maybeOf] 读取；依赖按 seedHex 变化
/// 才通知，切主题色时依赖组件精准重建，其余设置变更不波及。
class ThemeSeedScope extends InheritedWidget {
  const ThemeSeedScope({
    super.key,
    required this.seedHex,
    required super.child,
  });

  /// 当前主题 seed（`TimetableSettings.themeSeedColor`），缺失/未初始化为 null。
  final String? seedHex;

  static ThemeSeedScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeSeedScope>();
  }

  @override
  bool updateShouldNotify(ThemeSeedScope oldWidget) {
    return oldWidget.seedHex != seedHex;
  }
}
