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
  });

  final Widget icon;
  final String semanticsLabel;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    // Pass the caller's widget through untouched: rebuilding `Icon(iconData)`
    // dropped the Icon's explicit color/size (e.g. the couple-mode pink heart
    // and the wallpaper chrome foreground on the home header).
    // MiuixIconButton has no tooltip parameter; wrap in Tooltip so desktop/web
    // hover still shows the label, matching the former IconButton.tooltip.
    return Tooltip(
      message: semanticsLabel,
      child: Semantics(
        label: semanticsLabel,
        button: true,
        child: MiuixIconButton(onPressed: onPress, child: icon),
      ),
    );
  }
}

/// 首页顶栏「更多」「爱心」的**常驻玻璃球** —— 画在采样宿主之外的那一份。
///
/// ⚠️ **必须放在 [HyperosLayerBackdropCapture] 子树之外**（首页即
/// `HyperosGlassBackdropHost` 的 Stack 兄弟层，配合
/// [CompositedTransformTarget] 跟随真实按钮），**不能放回按钮原位**。
/// 页内玻璃的采样快照录自捕获节点的图层：球若长在捕获子树里，它自己的输出
/// 会被烘进下一次采样 —— 打开菜单时按钮被上游隐藏、快照是干净的，关闭后
/// 按钮重新绘制随即触发重采样，球就"变一次材质"并稳定在烘过自己一层的
/// 样子（2026-09-14 真机现象）。弹窗的球没有这个问题，正因为弹层在宿主之外。
///
/// 为什么用 [HyperosSelectPopupGlass]：与首页菜单弹窗的注入面
/// （`os4_glass_popup_surface.dart`）**同一个组件、同一份档位分派**，
/// 打开/关闭菜单时那颗球逐像素同源。
///
/// 真实按钮保持原位当**透明点击区**（图标也画到这颗球上），[IgnorePointer]
/// 保证球不挡点击；菜单打开期间调用方置 `visible: false` 让位给弹窗自己的
/// 形变球 —— 与真实按钮被上游 `contentHidden` 隐藏的窗口完全一致。
class FHeaderActionBall extends StatelessWidget {
  const FHeaderActionBall({
    super.key,
    required this.link,
    required this.icon,
    this.visible = true,
  });

  /// 跟随的锚点：包在真实按钮（透明点击区）外面的 [CompositedTransformTarget]。
  final LayerLink link;

  /// 球上的图标（含「更多」的更新红点）。
  final Widget icon;

  /// 菜单打开期间置 false，让位给弹窗自己的形变球。
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    // 半径取「最小边长 / 2」＝正圆，与弹窗形变的「锚点短边 / 2」同口径
    // （锚点就是这颗按钮的矩形），两边必须同值。
    const radius = MiuixIconButtonDefaults.minWidth / 2;
    return CompositedTransformFollower(
      link: link,
      // ⚠️ 必须 false。leader（真实按钮）不在树上时，follower 会退化成画在
      // **自己的布局位置** —— 也就是这层 Stack 的左上角，屏幕上就是"左上角
      // 冒出一颗爱心/菜单球"。首页切到内嵌页（任务清单等）时首页内容整块被
      // 替换，两个 leader 都不在树上，就是这个现象（2026-09-14 真机反馈）。
      // 置 false 后没有 leader 就不画，任何导致 leader 缺席的路径都被堵住。
      showWhenUnlinked: false,
      child: IgnorePointer(
        child: HyperosSelectPopupGlass(
          cornerRadius: radius,
          child: SizedBox(
            width: MiuixIconButtonDefaults.minWidth,
            height: MiuixIconButtonDefaults.minHeight,
            child: Center(child: icon),
          ),
        ),
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
