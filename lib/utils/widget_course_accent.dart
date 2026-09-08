import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 桌面小组件「课程色贯穿」的档位。
///
/// 用户观感分歧很大：有人要课程色贯穿、有人只要一根色条、有人完全不想要。
/// 因此做成一个三档总开关，而不是多个独立开关——语义一次说清，关闭即完全
/// 回到未加色时的经典样式。
enum WidgetCourseAccentMode {
  /// 关闭：色条与课程色文字全不渲染，回到加色之前的经典配色。
  off,

  /// 只加色条：课程名/状态胶囊文字仍用原来的中性色，只在课程名前加一根
  /// 课程色竖条。
  bar,

  /// 色条 + 文字：色条之外，课程名与状态胶囊文字也换成课程色的可读变体。
  barAndText,
}

/// 档位的语义开关：渲染侧只问「要不要条」「要不要字」，不散落判断枚举值。
extension WidgetCourseAccentModeX on WidgetCourseAccentMode {
  String get value => switch (this) {
    WidgetCourseAccentMode.off => 'off',
    WidgetCourseAccentMode.bar => 'bar',
    WidgetCourseAccentMode.barAndText => 'bar_and_text',
  };

  /// 旧快照/旧档案里只有布尔开关，按「开启 = 条+字」兼容。
  static WidgetCourseAccentMode fromValue(String? value) {
    return WidgetCourseAccentMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => WidgetCourseAccentMode.barAndText,
    );
  }

  bool get showsBar => this != WidgetCourseAccentMode.off;
  bool get showsText => this == WidgetCourseAccentMode.barAndText;
}

/// 小组件课程色贯穿的可读性钳制：把任意课程色压/提到一个相对亮度带里。
///
/// ## 为什么钳「相对亮度 Y」而不是 HSL 的 L
///
/// WCAG 对比度算的是相对亮度 `Y = 0.2126R' + 0.7152G' + 0.0722B'`，绿色通道
/// 占 71.5%、蓝色只占 7.2%。同一个 HSL 的 L 在不同色相下实际亮度能差三倍
/// 以上：L=0.55 的黄绿接近白、同 L 的蓝紫接近黑。所以「把 L 压到某值」在
/// 冷色区等于没做、在暖色区又压过头，色条会一半隐形一半发灰。
///
/// 这里统一在 **Y** 上钳制，再用二分法反解出对应的 L（Y 对 L 单调），色相
/// 与饱和度全程不动——「数据结构A 是绿色」这件事不会被算法改没，只是被压
/// 到可读。
///
/// ## 为什么钳制是单向的
///
/// 钳制只会把颜色**推离卡片底色**，绝不往回拉：
/// - 浅色卡（浅色模式）：只压暗（Y 超过上限才动），深色系原样保留；
/// - 深色卡（深色模式）：只提亮（Y 低于下限才动），亮色系原样保留。
///
/// 双向钳制（把带外的颜色一律拉回带内）会把浅卡上的深色课程**提亮**——
/// 那正好朝底色靠，对比度反而更低（实测 #334155 被提亮后对 #F8FAFC 只有
/// 5.4:1，而原色是 10.4:1）。
class WidgetCourseAccent {
  const WidgetCourseAccent._();

  /// 浅底（纯色/玻璃 + 浅色模式）色条的相对亮度上限：实测 104 色最低对比
  /// 3.17:1（WCAG 非文本达标线 3:1）。
  static const double lightBarMaxY = 0.24;

  /// 浅底文字带上限：实测对状态胶囊底（#E0EAFF / #EEF2F7）最低 5.79:1，优于
  /// 现状固定灰字 #64748B 的 3.94:1。
  static const double lightTextMaxY = 0.10;

  /// 深底（纯色/玻璃 + 深色模式）色条亮度下限：对夜间卡底最低 4.85:1。
  static const double darkBarMinY = 0.35;

  /// 深底文字亮度下限：对夜间状态胶囊底最低 5.14:1。
  static const double darkTextMinY = 0.55;

  /// 渐变底（日夜同底的深青→蓝）色条亮度下限：对渐变两端最低 3.40:1。
  /// 渐变风格下文字保持白色，不走这里（见 [accentTextArgb]）。
  static const double gradientBarMinY = 0.62;

  /// 色条：返回可直接交给 RemoteViews 的 ARGB int（不透明）。
  ///
  /// [colorHex] 非法时返回 null，渲染侧应按「无课程色」处理（不画条），
  /// 而不是画一根灰条。
  static int? accentBarArgb(
    String? colorHex, {
    required String backgroundStyle,
    required bool darkMode,
  }) => _resolve(
    colorHex,
    backgroundStyle: backgroundStyle,
    darkMode: darkMode,
    isText: false,
  );

  /// 课程名 / 状态胶囊文字：返回 ARGB int。
  ///
  /// 渐变底例外——主标题原本统一白字（5.17~5.56:1），换成课程色最坏只有
  /// 3.27:1，为「贯穿」把主标题对比度砍半不划算，故渐变底恒返回 null。
  static int? accentTextArgb(
    String? colorHex, {
    required String backgroundStyle,
    required bool darkMode,
  }) => _resolve(
    colorHex,
    backgroundStyle: backgroundStyle,
    darkMode: darkMode,
    isText: true,
  );

  static int? _resolve(
    String? colorHex, {
    required String backgroundStyle,
    required bool darkMode,
    required bool isText,
  }) {
    if (backgroundStyle == 'gradient') {
      // 渐变深底：文字不上课程色（保白字），色条走提亮钳制。
      if (isText) return null;
      return _clamp(colorHex, minY: gradientBarMinY, maxY: null);
    }
    if (darkMode) {
      return _clamp(
        colorHex,
        minY: isText ? darkTextMinY : darkBarMinY,
        maxY: null,
      );
    }
    return _clamp(
      colorHex,
      minY: null,
      maxY: isText ? lightTextMaxY : lightBarMaxY,
    );
  }

  /// 单向钳制：[maxY] 非空时只压暗，[minY] 非空时只提亮，色相/饱和度不变。
  static int? _clamp(
    String? colorHex, {
    required double? minY,
    required double? maxY,
  }) {
    final color = _parseHex(colorHex);
    if (color == null) return null;
    final hsl = HSLColor.fromColor(color);
    final y = _relativeLuminance(color);
    if (maxY != null && y > maxY) {
      return _argbOf(
        hsl.hue,
        hsl.saturation,
        _solveLForLuminance(hsl.hue, hsl.saturation, maxY),
      );
    }
    if (minY != null && y < minY) {
      return _argbOf(
        hsl.hue,
        hsl.saturation,
        _solveLForLuminance(hsl.hue, hsl.saturation, minY),
      );
    }
    return _argbOf(hsl.hue, hsl.saturation, hsl.lightness);
  }

  /// WCAG 相对亮度（与 Color.computeLuminance 同一公式）。
  static double _relativeLuminance(Color color) {
    double channel(double value) {
      if (value <= 0.03928) return value / 12.92;
      return math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// 二分反解：给定色相/饱和度，求相对亮度为 [targetY] 时的 L。
  /// Y 对 L 单调递增，50 次二分收敛到 1e-15 以内。
  static double _solveLForLuminance(
    double hue,
    double saturation,
    double targetY,
  ) {
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 50; i++) {
      final mid = (low + high) / 2;
      if (_luminanceOfHsl(hue, saturation, mid) < targetY) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  static double _luminanceOfHsl(
    double hue,
    double saturation,
    double lightness,
  ) {
    final rgb = _rgbOfHsl(hue, saturation, lightness);
    return _relativeLuminance(Color.fromARGB(255, rgb.$1, rgb.$2, rgb.$3));
  }

  /// HSL → RGB（0-255）。与 HSLColor.toColor 同一算法，独立实现只为单测能
  /// 脱离引擎校验色相漂移。
  static (int, int, int) _rgbOfHsl(
    double hue,
    double saturation,
    double lightness,
  ) {
    final h = (((hue % 360) + 360) % 360) / 360;
    final s = saturation.clamp(0.0, 1.0);
    final l = lightness.clamp(0.0, 1.0);
    if (s <= 0) {
      final v = (l * 255).round().clamp(0, 255);
      return (v, v, v);
    }
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    double channel(double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    int toChannel(double value) => (value * 255).round().clamp(0, 255).toInt();
    return (
      toChannel(channel(h + 1 / 3)),
      toChannel(channel(h)),
      toChannel(channel(h - 1 / 3)),
    );
  }

  static int _argbOf(double hue, double saturation, double lightness) {
    final rgb = _rgbOfHsl(hue, saturation, lightness);
    return 0xFF000000 | (rgb.$1 << 16) | (rgb.$2 << 8) | rgb.$3;
  }

  static Color? _parseHex(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final hex = raw.startsWith('#') ? raw.substring(1) : raw;
    if (hex.length != 6) return null;
    final parsed = int.tryParse('FF$hex', radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }
}

/// 档位 → 快照 / Kotlin 侧下发的字符串。
String widgetCourseAccentModeValue(WidgetCourseAccentMode mode) => mode.value;
