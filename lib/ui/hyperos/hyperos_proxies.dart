import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_popup_glass.dart' show HyperosSelectPopupGlass;

/// Temporary compatibility widget until all FHeaderAction usages are
/// migrated to HyperosIconButton.
class FHeaderAction extends StatelessWidget {
  const FHeaderAction({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    this.onPress,
    this.glassBall = false,
  });

  final Widget icon;
  final String semanticsLabel;
  final VoidCallback? onPress;

  /// 常驻玻璃圆底（首页顶栏「更多」「爱心」那颗球）。
  ///
  /// 为什么需要它：上游 `MiuixGlassTransformPopup` 的形变终点是「面板缩回锚点
  /// 矩形」——也就是按钮位置的一块玻璃，动画跑完才随 overlay 一起隐藏，读起来
  /// 就是个「点一下冒出来、过一会才消失的小球」。按钮自己常驻同一颗球，形变
  /// 才有落点，关闭时也不会留下突兀的残影。
  ///
  /// ⚠️ 球必须用 [HyperosSelectPopupGlass] 画，**不要退回 `MiuixIconButton` 的
  /// `backgroundColor`**（那是平涂色：没有模糊、没有边缘高光、没有描边，而且
  /// 颜色得按壁纸反相才读得出来）。这里与首页菜单弹窗的注入面
  /// （`os4_glass_popup_surface.dart`）用的是**同一个组件、同一份档位分派**，
  /// 所以打开/关闭菜单时那颗球不会跳。
  final bool glassBall;

  @override
  Widget build(BuildContext context) {
    // Pass the caller's widget through untouched: rebuilding `Icon(iconData)`
    // dropped the Icon's explicit color/size (e.g. the couple-mode pink heart
    // and the wallpaper chrome foreground on the home header).
    // MiuixIconButton has no tooltip parameter; wrap in Tooltip so desktop/web
    // hover still shows the label, matching the former IconButton.tooltip.
    Widget button = MiuixIconButton(onPressed: onPress, child: icon);
    if (glassBall) {
      // 圆角取「最小边长 / 2」＝正圆。弹窗形变时用的是**同一个**口径
      // （`锚点短边 / 2`，锚点就是这颗按钮的矩形），两边必须同值 ——
      // 差一点就会在打开/关闭菜单的交接瞬间看到圆角跳一下。
      const radius = MiuixIconButtonDefaults.minWidth / 2;
      button = HyperosSelectPopupGlass(cornerRadius: radius, child: button);
    }
    return Tooltip(
      message: semanticsLabel,
      child: Semantics(
        label: semanticsLabel,
        button: true,
        child: button,
      ),
    );
  }
}

// ── Temporary Forui compatibility layer ──────────────────────────────────────

/// Type aliases so files that reference FColors / FTypography still compile.
typedef FColors = ForuiCompatColors;
typedef FTypography = ForuiCompatTypography;

/// Replaces Forui's `context.theme` — returns a [ForuiCompatTheme] object
/// that exposes `.colors` and `.typography` with the same property names.
extension ForuiCompatContext on BuildContext {
  ForuiCompatTheme get theme => ForuiCompatTheme._(this);
}

/// Stand-in for Forui's `FThemeData`.  Exposes `.colors` and `.typography`
/// backed by Material [ThemeData].
class ForuiCompatTheme {
  ForuiCompatTheme._(this._context);

  final BuildContext _context;
  late final ThemeData _t = Theme.of(_context);

  ForuiCompatColors get colors => ForuiCompatColors._(_t);
  ForuiCompatTypography get typography => ForuiCompatTypography._(_t);
}

/// Stand-in for Forui's `FColors`.
class ForuiCompatColors {
  ForuiCompatColors._(this._t);

  final ThemeData _t;

  Color get foreground => _t.colorScheme.onSurface;
  Color get mutedForeground => _t.colorScheme.onSurfaceVariant;
  Color get border => _t.dividerColor;
  /// Forui 语义里 muted 是「弱化背景面板色」（mutedForeground 才是其上的
  /// 文字墨水）。对齐 app 标准弱化表面（与表单字段填充同源）：
  /// 浅色 #F0F0F0 / 深色 #434343。此前映射成 onSurface@60% 半透明黑墨水，
  /// 被当背景用的地方（日程提示条、考试关联占位井）在浅色模式下渲染成黑块。
  Color get muted => _t.brightness == Brightness.dark
      ? HyperosMiuixDarkColors.secondaryVariant
      : HyperosMiuixLightColors.secondaryVariant;
  Color get primary => _t.colorScheme.primary;
  Color get secondary => _t.colorScheme.secondary;
  Color get background => _t.colorScheme.surface;
  Color get destructive => _t.colorScheme.error;
  Color get primaryForeground => _t.colorScheme.onPrimary;
}

/// Stand-in for Forui's `FTypography`.  Returns Material [TextStyle]s that
/// approximate the Forui typography scale.
class ForuiCompatTypography {
  ForuiCompatTypography._(this._t);

  final ThemeData _t;

  ForuiCompatTypeface get body => ForuiCompatTypeface._(_t.textTheme);
  ForuiCompatTypeface get display => ForuiCompatTypeface._(_t.textTheme);
}

class ForuiCompatTypeface {
  ForuiCompatTypeface._(this._tt);

  final TextTheme _tt;

  TextStyle get xs =>
      _tt.bodySmall?.copyWith(fontSize: 12) ?? const TextStyle(fontSize: 12);
  TextStyle get xs2 =>
      _tt.bodySmall?.copyWith(fontSize: 11) ?? const TextStyle(fontSize: 11);
  TextStyle get sm =>
      _tt.bodySmall?.copyWith(fontSize: 14) ?? const TextStyle(fontSize: 14);
  TextStyle get md => _tt.bodyMedium ?? const TextStyle();
  TextStyle get lg => _tt.bodyLarge ?? const TextStyle();
  TextStyle get xl => _tt.headlineSmall ?? const TextStyle();
  TextStyle get xl2 => _tt.headlineMedium ?? const TextStyle();

  ForuiCompatTypeface copyWith({
    TextStyle? xs,
    TextStyle? xs2,
    TextStyle? sm,
    TextStyle? md,
    TextStyle? lg,
    TextStyle? xl,
    TextStyle? xl2,
  }) {
    return this;
  } // simplified — not needed for compilation
}
