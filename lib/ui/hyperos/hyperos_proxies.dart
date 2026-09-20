import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
// 只取量跟随结果要用的那一个（与 hyperos_zoom_route.dart 同口径：别整包进来
// 把 material 的一堆同名符号搞歧义）。
import 'package:flutter/rendering.dart' show RenderFollowerLayer;
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_popup_glass.dart' show HyperosGlassShadow, HyperosSelectPopupGlass;
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
///
/// ⚠️ **`showWhenUnlinked: false` 只堵得住「跟随失效」的一半**（2026-09-20）：
/// 它挡的是「没有 leader 就画在布局位置」；链路**没解析出来**的其它情形（leader
/// 在但变换算不出来 / layer 还没合成或刚被 detach）它管不到，而那些帧里这颗球
/// 对外报的坐标会退化成**布局位置 = 屏幕左上角** —— 真机读成「右上角那颗圈圈
/// 跑到左上角去了；点一下菜单才恢复」。另一半由 [_FHeaderActionBallState]
/// 自己兜住，判据与理由都在那个类上。
class FHeaderActionBall extends StatefulWidget {
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
  State<FHeaderActionBall> createState() => _FHeaderActionBallState();
}

/// 球的可见性 = 调用方给的 `visible` **且**跟随链这一帧是「知道球在哪」的。
///
/// 为什么必须自己查：**跟随链没解析出来时，这颗球对外给的坐标全是错的**，
/// 而错的那个值恰好就是屏幕左上角。两条路都会走到那儿：
///
/// 1. **绘制侧**：`FollowerLayer.addToScene` 在 `_lastTransform == null` 时画的
///    就是 `unlinkedOffset` = 本组件的**布局位置**（这颗球是 `Stack` 的左上角
///    对齐子节点 ⇒ 屏幕左上角）。`showWhenUnlinked: false` 只挡住其中「没有
///    leader」那一种；「leader 在、但变换算不出来」那一种它管不到。
/// 2. **几何侧**：`RenderFollowerLayer.getCurrentTransform()` 的契约是「没有
///    layer（还没合成过 / 刚被 detach）/ 算不出变换 ⇒ 返回单位阵」，而
///    `applyPaintTransform` 正是拿它当变换。也就是说这一帧里问「球在哪」，答案
///    是**布局位置 = 屏幕左上角** —— 谁按这个答案取几何（玻璃面算采样区矩形、
///    几何 uniform，或者任何 `localToGlobal` 取屏幕坐标的绘制）就会把圆画到
///    左上角去，而**画出来的位置还会被登记 / 缓存住**，链路恢复了也不会自己
///    回位。真机现象「只要进外观编辑页，右上角那颗圈圈就跑到左上角；点一下
///    菜单才恢复」（2026-09-20）就是这一族的读法。
///
/// ⚠️ 本地复现不出来不是反证：`_pathsToCommonAncestor` 找不到共同祖先那条
/// assert 只在 debug 生效，release 直接往下算；而上面第 1 条里「退化矩阵」
/// 那一半要靠一个**行列式为 0 的 TransformLayer**，Flutter 自己的
/// `RenderTransform.paint` 会在推层之前短路掉（"singular → paint nothing"），
/// 所以测试环境里连触发的入口都不好造。因此这里的判据**不依赖任何一条具体
/// 触发路径**，只依赖上游契约本身：拿不到 layer / 拿不到变换 ⇒ 这一帧坐标不可信
/// ⇒ 不画。
///
/// 判据用上游契约、不做任何几何假设，所以正常状态下不会误伤：链路正常时
/// `layer` 与 `getLastTransform()` 都在（变换是每帧重算的，
/// `FollowerLayer.alwaysNeedsAddToScene` 恒为 true）。链路恢复（leader 回来、
/// 重新合成）会自动把球放回去。
class _FHeaderActionBallState extends State<FHeaderActionBall> {
  /// 量跟随结果的抓手（[RenderFollowerLayer] 自己就是 follower）。
  final GlobalKey _followerKey = GlobalKey();

  /// 跟随链这一帧算不算得出来。默认 true：第一次合成之前没有结论，先按正常画。
  bool _linkResolved = true;

  /// 「跟随链断了」只留一次痕，状态不翻转不重复打。
  bool _linkLossReported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_watchLink);
  }

  /// 每帧末查一次跟随结果（变换是**上一帧合成阶段**算出来的，只能帧末读）。
  ///
  /// 稳定状态下代价只有一次取 renderObject + 一次矩阵取值，且只在结果翻转时
  /// setState（不会每帧重建球）。
  void _watchLink(Duration _) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(_watchLink);
    final renderObject = _followerKey.currentContext?.findRenderObject();
    if (renderObject is! RenderFollowerLayer) {
      return;
    }
    // 两个都要满足才算"知道球在哪"：
    // * `layer == null`（还没合成过 / 刚被 detach）—— 此时
    //   `RenderFollowerLayer.getCurrentTransform()` 回落到**单位阵**，任何按它
    //   取几何的查询（`localToGlobal` / 命中测试 / 玻璃算采样区与几何 uniform）
    //   都会把答案算成**布局位置**，而这颗球的布局位置就是屏幕左上角；
    // * `getLastTransform() == null` —— 契约里那两种情况（没接上 leader，或带
    //   退化矩阵），此时 `addToScene` 直接画在布局位置。
    // 任一不成立都不安全，一律不画（fail-safe：宁可少画一帧）。
    final layer = renderObject.layer;
    final resolved = layer != null && layer.getLastTransform() != null;
    if (resolved == _linkResolved) {
      return;
    }
    if (!resolved && !_linkLossReported) {
      _linkLossReported = true;
      _traceLinkLoss(renderObject);
    }
    setState(() => _linkResolved = resolved);
  }

  /// 跟随链断裂的留痕：debug 才打（与本仓 `[glass-state]` 那条同口径，正式包
  /// 不留诊断输出），但要对得上「哪颗球、什么时候、锚还在不在」。
  void _traceLinkLoss(RenderFollowerLayer renderObject) {
    if (kReleaseMode) {
      return;
    }
    debugPrint(
      '[glass-ball] link-lost size=${renderObject.size} '
      'leaderLinked=${widget.link.leader != null} '
      '→ 照画会落在布局位置（屏幕左上角），本帧起隐藏',
    );
  }

  /// 外阴影（垫在玻璃**之下**）。
  ///
  /// 上游同款组件 `MiuixGlassIconButton` 的可见性靠三样东西保底：材质自身、
  /// 描边、外阴影 —— 后两样与背景无关，任何底色上都读得出轮廓。本仓这颗球走
  /// [HyperosSelectPopupGlass]，而默认的「高斯磨砂」分支既没描边也没阴影：
  /// 纯色背景上模糊一个纯色仍是同一个纯色，圆就整颗融进页面（真机反馈：没设
  /// 壁纸时右上角小球在浅色和深色下都几乎看不见）。
  ///
  /// **其中「描边」已按用户要求下线**（2026-09-19）：球的边界改由玻璃材质自己
  /// 交代，组件不再在材质之外叠一层发丝线。浮影保留 —— 它同样与背景无关，也是
  /// 下面那条交接一致性的载体。
  ///
  /// ⚠️ 数值必须与弹层侧同源（[HyperosGlassShadow] 定义、弹层侧由
  /// [HyperosSelectPopupGlass.surfaceShadow] 打开）：菜单收起时这颗球是弹窗先画
  /// 一颗、再交接给常驻球的，两侧不一致就会在交接瞬间现形 —— 真机反馈「阴影在
  /// 弹窗收回后一秒突然出现」就是这么来的。同理，这里**不要**再给自己垫洗色之类
  /// 弹层侧没有的层：交接面多一层，跳变就换一种形式回来。
  Widget _buildVisibleBall() {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 与弹层侧同源（见 [HyperosGlassShadow]）。
              boxShadow: [HyperosGlassShadow.shadow],
            ),
          ),
        ),
        HyperosSelectPopupGlass(
          cornerRadius: MiuixIconButtonDefaults.minWidth / 2,
          // 这里原本要关掉上游柔光玻璃那圈「贴边加法白」高光（它在球上是零收益、
          // 纯副作用：纯色底上白叠白等于没画，有壁纸时贴边那层白一叠就顶到纯白，
          // 读成「一圈没有过渡的死白边」）。2026-09-19 起球与弹层一起锁成
          // **永远液态玻璃的标准档**，柔光分支在这里不存在了，那个开关随之删除。
          child: SizedBox(
            width: MiuixIconButtonDefaults.minWidth,
            height: MiuixIconButtonDefaults.minHeight,
            child: Center(child: widget.icon),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      key: _followerKey,
      link: widget.link,
      // ⚠️ 必须 false。leader（真实按钮）不在树上时，follower 会退化成画在
      // **自己的布局位置** —— 也就是这层 Stack 的左上角，屏幕上就是"左上角
      // 冒出一颗爱心/菜单球"。首页切到内嵌页（任务清单等）时首页内容整块被
      // 替换，两个 leader 都不在树上，就是这个现象（2026-09-14 真机反馈）。
      //
      // ⚠️ 但它只堵得住「没有 leader」这一条：**leader 在树上、变换算不出来**
      // 时（祖先链里有退化矩阵）照样画在布局位置，且该分支无视本开关（见类
      // 注释）。那一条由 [_watchLink] 兜住。
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
          // 跟随链断掉时同样走「留着、不画」：位置是错的，但玻璃面与采样区
          // 登记必须留着 —— 链路一恢复下一帧就是玻璃，不能走重新挂载那条会
          // 闪一下的路。
          visible: widget.visible && _linkResolved,
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
            child: _buildVisibleBall(),
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
