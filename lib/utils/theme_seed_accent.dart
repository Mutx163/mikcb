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
/// 回落仅在深色模式的近黑 seed（中性灰/锌灰/石板灰，luminance < 0.08）
/// 发生：黑与深色底几乎同色、等于主题色没显示，回落墨色兜底；浅色模式
/// 所见即所得，与八宫格 `resolveHomeGridMenuAccent` 同口径。

/// 解析 seed hex 为强调色；缺失或非法时返回 null，由调用方回落。
///
/// 所见即所得：只要 seed 合法就原样返回——用户选亮黄主题就要看到
/// 亮黄，不做「浅色可读性」回落（此前浅色模式亮度 > 0.60 会回落墨色，
/// 导致选了黄色主题 UI 却是黑的，不符合「设置什么就是什么」）。唯一
/// 例外是深色模式近黑 seed（中性灰/锌灰/石板灰 luminance < 0.08）：
/// 黑与深色底几乎同色、等于主题色没显示，此时回落 null 让墨色兜底
/// 可读；同色在浅色模式原样返回（黑墨白字天然可读）。
Color? resolveThemeSeedAccent(String? seedHex, Brightness brightness) {
  final seed = tryParseHexColor(seedHex);
  if (seed == null) {
    return null;
  }
  if (brightness == Brightness.dark &&
      seed.computeLuminance() < 0.08) {
    return null;
  }
  return seed;
}

/// 按强调色实际亮度选择其上的墨水（黑/白）。
///
/// seed 接入后 onPrimary 不再是固定白：亮黄等高亮度 seed 上必须用黑墨。
Color onAccentInk(Color accent) {
  return accent.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// 表面强调色（按钮底色、选中井等「承载面」）的解析口径。
///
/// 与 [resolveThemeSeedAccent] 相反，这里所见即所得：浅色模式下亮黄等
/// 高亮度 seed 也保留原色——承载面有 [onAccentInk] 自动黑白墨水兜底文字
/// 对比，不必像前景强调色那样回落墨色（否则选亮黄主题按钮却变黑）。
/// 深色模式下近黑 seed（中性灰/锌灰/石板灰）会向白提亮到可辨识的强调面，
/// 避免按钮融进暗底。缺失/非法 hex 返回 null，由调用方回落固定蓝。
Color? resolveThemeSeedSurface(String? seedHex, Brightness brightness) {
  final seed = tryParseHexColor(seedHex);
  if (seed == null) {
    return null;
  }
  final isDark = brightness == Brightness.dark;
  if (isDark && seed.computeLuminance() < 0.08) {
    return Color.lerp(seed, Colors.white, 0.45);
  }
  return seed;
}

/// 禁用/被屏蔽状态的底色：对应颜色的**浅色状态**。
///
/// Miuix/HyperOS 包默认的 disabled 家族是固定浅蓝（浅色 #C2D9FF / 深色
/// #253E64）：用户选了绿/黄主题后，被屏蔽开关的开启侧轨道、禁用按钮与
/// 滑杆底色仍显示蓝色。本规则由主题强调色派生「浅色状态」：浅色模式向白
/// 混 0.7，深色模式向暗底 #242424 混 0.7——与包默认对默认蓝自身的派生
/// 比例一致（#3482FF→#C2D9FF、#277AF7→#253E64 均 ≈ lerp(目标, 0.7)），
/// 蓝色 seed ≈ 包默认，其他 seed 得到对应颜色的浅色。[accent] 为 null
/// （无 seed/不可读）返回 null，调用方回落包默认。
Color? resolveThemeSeedDisabled(Color? accent, Brightness brightness) {
  if (accent == null) {
    return null;
  }
  return Color.lerp(
    accent,
    brightness == Brightness.dark ? const Color(0xFF242424) : Colors.white,
    0.7,
  );
}

/// 禁用底色上的墨水（被屏蔽开关的 thumb、禁用按钮文字）：
///
/// 浅色模式用近白 thumb（浅色浅底 + 白 thumb 即 MiUI 观感，与主题色相
/// 无关）；深色模式把 accent 向暗底混 0.35——比 0.7 的禁用底更亮，保证
/// 被屏蔽 thumb/文字压在禁用底上仍可见。[accent] 为 null 返回 null，
/// 调用方保持包默认。
Color? resolveThemeSeedDisabledInk(Color? accent, Brightness brightness) {
  if (accent == null) {
    return null;
  }
  return brightness == Brightness.dark
      ? Color.lerp(accent, const Color(0xFF242424), 0.35)
      : const Color(0xFFFCFCFC);
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
