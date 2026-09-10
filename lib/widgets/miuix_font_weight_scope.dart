import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import '../ui/app_fonts.dart';
import '../utils/theme_seed_accent.dart';

/// 读取 Android 系统字体粗细增量（`Configuration.fontWeightAdjustment`）。
///
/// Android 12+ 返回该增量；低版本、未定义或非 Android 返回 null，交由调用方
/// 回退到 [MediaQueryData.boldText]。
abstract final class SystemFontWeightService {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/system_ui',
  );

  static Future<int?> readAdjustment() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<int>('getFontWeightAdjustment');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// 让子树内的 flutter_miuix 组件字重跟随系统字体粗细，并叠加用户全局字重。
///
/// 此 scope 读取原生增量（Android 12+），失败时回退到
/// [MediaQueryData.boldText]，据此为子树提供一个"已按角色分级平移字重"的
/// [MiuixTheme]，并屏蔽 Flutter 框架对 [Text] 的统一加粗，避免盖掉分级结果。
/// 用户在外观设置中指定的全局字重会作为相对 w400 的偏移，与系统增量相加。
/// 同时通过 [AppFontScope] 把「用户字重 / 系统增量 / 字体族」下发给硬编码
/// HyperOS 文本样式（大标题、HyperosTypography），避免它们反向扣减或漏接。
/// 配色与亮度在没有显式 Miuix 主题时跟随外层 Material 主题，避免深色模式
/// 回退到 flutter_miuix 的浅色默认值。
class MiuixFontWeightScope extends StatefulWidget {
  const MiuixFontWeightScope({
    required this.child,
    this.userFontWeight,
    this.fontSpec,
    super.key,
  });

  final Widget child;

  /// 用户全局字重（100–900）。null / [kAppFontWeightDefault] 表示不叠加。
  final int? userFontWeight;

  /// 用户选定的字体族；缺省为系统默认。
  final AppFontSpec? fontSpec;

  @override
  State<MiuixFontWeightScope> createState() => _MiuixFontWeightScopeState();
}

class _MiuixFontWeightScopeState extends State<MiuixFontWeightScope>
    with WidgetsBindingObserver {
  int? _adjustment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 系统字体粗细变化会触发配置变更（metrics）或无障碍特性变更，两者都重读。
  @override
  void didChangeMetrics() => _refresh();

  @override
  void didChangeAccessibilityFeatures() => _refresh();

  Future<void> _refresh() async {
    final value = await SystemFontWeightService.readAdjustment();
    if (!mounted || value == _adjustment) {
      return;
    }
    setState(() => _adjustment = value);
  }

  @override
  Widget build(BuildContext context) {
    final systemDelta =
        _adjustment ??
        (MediaQuery.boldTextOf(context) ? kMiuixBoldTextFontWeightDelta : 0);
    final userWeight = widget.userFontWeight ?? kAppFontWeightDefault;
    final userDelta = userWeight == kAppFontWeightDefault
        ? 0
        : userWeight - kAppFontWeightDefault;
    final delta = userDelta + systemDelta;

    // App root normally has no explicit MiuixTheme. In that case, the
    // package fallback is light-only, so use the Material brightness instead.
    // Explicit nested Miuix themes (for example the Miuix showcase) keep
    // their own palette.
    final existing = MiuixTheme.maybeOf(context);
    final baseTheme =
        existing ?? MiuixThemeData.of(Theme.of(context).brightness);
    // 主题色接入：根部 Miuix 色板强调色跟随 seed（MiuixSwitch 开启色、
    // Miuix 日期/时间/数字/颜色选择器高亮等包内组件全部受益）。嵌套的
    // 显式 Miuix 主题（showcase 演示）保持自带色板不被覆盖；seed 缺失或
    // 不可读时维持包默认色。回落墨水由 onAccentInk 按实际强调色亮度取黑白。
    final seededColors = existing == null
        ? _seededMiuixColors(baseTheme.colors, context)
        : null;
    final data = MiuixThemeData(
      colors: seededColors ?? baseTheme.colors,
      brightness: baseTheme.brightness,
      textStyles: applyFontWeightDelta(defaultTextStyles(), delta),
      fontWeightAdjustment: delta,
    );

    // delta != 0 时屏蔽框架的"统一加粗到 w700"，让分级字重成为唯一权威。
    Widget child = widget.child;
    if (delta != 0) {
      final mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery != null && mediaQuery.boldText) {
        child = MediaQuery(
          data: mediaQuery.copyWith(boldText: false),
          child: child,
        );
      }
    }

    // 把「用户字重 / 系统增量 / 字体族」下发给硬编码 HyperOS 文本。
    // 旧实现只把合并后的 delta 塞进 MiuixTheme.fontWeightAdjustment，
    // 大标题却用 `400 - fontWeightAdjustment` 反向补偿，用户调粗时大标题
    // 反而变细（接反）。AppFontScope 把两者拆开，resolveWeight 才能
    // 用户非默认时绝对覆盖、默认时只减系统增量。
    child = AppFontScope(
      userFontWeight: userWeight,
      systemFontWeightDelta: systemDelta,
      fontSpec: widget.fontSpec ?? const AppFontSpec(),
      child: child,
    );

    return MiuixTheme(data: data, child: child);
  }
}

/// 用主题 seed 覆盖包默认色板中的强调色。
///
/// 只动 primary/onPrimary（Miuix 组件的选中态、开关**开启**色、选择器
/// 高亮都由 primary 派生）与 disabled 家族（**被屏蔽**开关的轨道、禁用
/// 按钮/滑杆底色 = 强调色的浅色状态，见 [resolveThemeSeedDisabled]：开启
/// 侧走 disabledPrimary、关闭侧走 disabledSecondary，因此绿/黄主题下被
/// 屏蔽开关的关闭态轨道是浅绿/浅黄而非中性灰）；
/// **不动启用态的 secondary**——仍可操作的开关其关闭轨道保持中性规范色，
/// 避免「正常关着也是主题色」。surface/文本墨水等中性角色也保持 HyperOS
/// 规范色不变。seed 经 [resolveThemeSeedAccent] 解析（缺失/不可读返回
/// null → 保持包默认）。
MiuixColors? _seededMiuixColors(MiuixColors base, BuildContext context) {
  final accent = resolveThemeSeedAccent(
    ThemeSeedScope.maybeOf(context)?.seedHex,
    Theme.of(context).brightness,
  );
  if (accent == null) {
    return null;
  }
  final brightness = Theme.of(context).brightness;
  final ink = onAccentInk(accent);
  // 被屏蔽（disabled）态跟随主题色：对应颜色的浅色状态，否则选了绿主题
  // 「被屏蔽的开关」仍显示包默认浅蓝 #C2D9FF（开侧）/ 中性灰（关侧）。
  final disabled = resolveThemeSeedDisabled(accent, brightness);
  final disabledInk = resolveThemeSeedDisabledInk(accent, brightness);
  // 只动 primary/onPrimary 与 disabled 家族（含关闭侧的 disabledSecondary）；
  // 启用态 secondary 保持包默认（可操作开关的关闭轨道）。
  return base.copy(
    primary: accent,
    onPrimary: ink,
    disabledPrimary: disabled,
    disabledOnPrimary: disabledInk,
    disabledSecondary: disabled,
    disabledOnSecondary: disabledInk,
    disabledPrimaryButton: disabled,
    disabledOnPrimaryButton: disabledInk,
    disabledPrimarySlider: disabled,
  );
}
