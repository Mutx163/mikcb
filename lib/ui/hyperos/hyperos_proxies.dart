import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_popup_glass.dart' show HyperosGlassEdge, HyperosSelectPopupGlass;
import 'hyperos_theme.dart';


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

/// 首页顶栏「更多」按钮的**可见内容**：三个点图标 + 可选更新红点。
///
/// 常驻玻璃球（[FHeaderActionBall]）与弹窗形变起点（`anchorContent`）**必须
/// 共用同一份** —— 任何差异都会在开合交接的那一瞬被看见（红点晚一步出现、
/// 或整颗球跟着重绘一次）。
///
/// ⚠️ 自带固定 [size]×[size] 基准框 + 外层 [Center]，**不要**把 `Stack` 直接
/// 暴露出去：弹窗形变起点那份副本是按 `BoxConstraints.tight(锚点矩形)`（40×40）
/// 布局的，`Stack` 被撑成 40×40 后默认对齐会把图标推到**左上角**、`Positioned`
/// 到 Stack 右上角的红点落到**右上角** —— 收起动画里就是"三个点和红点跑到圈圈
/// 的左上/右上，过一会（交接给常驻球）才归位"（2026-09-14 真机反馈）。
/// 固定基准框之后，紧 / 松两种约束下图标与红点的相对位置完全一致。
class HomeMoreActionIcon extends StatelessWidget {
  const HomeMoreActionIcon({
    super.key,
    required this.ink,
    required this.dotBorderColor,
    required this.showUpdateDot,
  });

  /// 图标墨色（见首页 `_chromeActionBallInk`）。
  final Color ink;

  /// 更新红点那圈"挖坑"描边色（顶栏带色 / 无带时的主题底色）。
  final Color dotBorderColor;

  final bool showUpdateDot;

  /// 基准边长，与 `Icon` 默认尺寸一致。
  static const double size = 24;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Center(child: Icon(Icons.more_vert_rounded, color: ink)),
          ),
          if (showUpdateDot)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  // 更新红点与危险语义统一色
                  color: HyperosColors.destructive,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotBorderColor, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    ),
  );
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

  /// 描边（压在玻璃**之上**）+ 外阴影（垫在玻璃**之下**）。
  ///
  /// 上游同款组件 `MiuixGlassIconButton` 的可见性靠三样东西保底：材质自身、
  /// **描边**、**外阴影** —— 后两样与背景无关，任何底色上都读得出轮廓。本仓
  /// 这颗球走 [HyperosSelectPopupGlass]，而默认的「高斯磨砂」分支既没描边也
  /// 没阴影：纯色背景上模糊一个纯色仍是同一个纯色，圆就整颗融进页面
  /// （真机反馈：没设壁纸时右上角小球在浅色和深色下都几乎看不见）。
  ///
  /// ⚠️ 两层的**数值必须与弹层侧同源**（[HyperosGlassEdge]，弹层侧由
  /// [HyperosSelectPopupGlass.surfaceEdge] 打开）：菜单收起时这颗球是弹窗先画
  /// 一颗、再交接给常驻球的，两侧不一致就会在交接瞬间现形 —— 真机反馈「阴影在
  /// 弹窗收回后一秒突然出现」就是这么来的。同理，这里**不要**再给自己垫洗色之类
  /// 弹层侧没有的层：交接面多一层，跳变就换一种形式回来。
  ///
  /// 描边必须叠在最上层而不是画在玻璃下面：降级实底那条分支的球是不透明的，
  /// 画在下面会被整块盖掉。
  Widget _buildVisibleBall(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 与弹层侧同源（见 [HyperosGlassEdge]）。
              boxShadow: [HyperosGlassEdge.shadow],
            ),
          ),
        ),
        HyperosSelectPopupGlass(
          cornerRadius: MiuixIconButtonDefaults.minWidth / 2,
          child: SizedBox(
            width: MiuixIconButtonDefaults.minWidth,
            height: MiuixIconButtonDefaults.minHeight,
            child: Center(child: icon),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 与弹层侧同源的轮廓线（见 [HyperosGlassEdge]）：只勾边界，
                // 不抢图标。
                border: Border.all(
                  color: HyperosGlassEdge.ringColor(context),
                  width: HyperosGlassEdge.ringWidth,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: link,
      // ⚠️ 必须 false。leader（真实按钮）不在树上时，follower 会退化成画在
      // **自己的布局位置** —— 也就是这层 Stack 的左上角，屏幕上就是"左上角
      // 冒出一颗爱心/菜单球"。首页切到内嵌页（任务清单等）时首页内容整块被
      // 替换，两个 leader 都不在树上，就是这个现象（2026-09-14 真机反馈）。
      // 置 false 后没有 leader 就不画，任何导致 leader 缺席的路径都被堵住。
      showWhenUnlinked: false,
      child: IgnorePointer(
        // ⚠️ 菜单打开期间**不要**把这颗球从树上摘掉（早先这里是
        // `if (!visible) return SizedBox.shrink();`）：摘掉会连带销毁它内部的
        // 玻璃面状态与采样区登记。关闭菜单重新挂载时，采样区里还没有快照，
        // `MiuixGlass` 会先走兜底实底画一帧平涂，等录帧落地才变回玻璃 ——
        // 读起来就是"关掉菜单时右上角圆按钮闪一下"（2026-09-14 真机反馈）。
        //
        // 改成「留着、但不画」：`maintainSize` 让它继续参与布局，采样区矩形
        // 保持有效、录帧不中断（快照一直是新鲜的），重新出现时第一帧就是玻璃。
        // `maintainState` 保住玻璃面自己的状态，`IgnorePointer` 让点击穿透到
        // 下面的真实按钮。
        child: Visibility(
          visible: visible,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          // ⚠️ 明暗切换必须让球**换一棵子树**（Key 里带 brightness）：玻璃面的
          // 底图是"背后那条窄带"的快照，快照不跟着主题变，切回浅色时球会一直
          // 停在深色那张底图上（真机反馈：切深色再切浅色，球还是黑的）。整块换
          // 掉等于强制重新登记采样区、重新录帧；`maintainState` 仍保住显隐状态，
          // 与"不摘掉球"那条口径不冲突（球一直在，只是换了个身份重新登记）。
          child: KeyedSubtree(
            key: ValueKey<Brightness>(Theme.of(context).brightness),
            child: _buildVisibleBall(context),
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
