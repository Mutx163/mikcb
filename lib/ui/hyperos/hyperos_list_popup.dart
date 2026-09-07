import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_select.dart';
import 'hyperos_theme.dart';
import 'hyperos_widgets.dart';
import 'liquid/hyperos_liquid_glass_surface.dart'
    show UndimmedBackdropCapture;

/// 宿主页面根级的页面捕获作用域：给锚定弹窗的二级子卡提供「弹窗背后
/// 页面」的同步截图来源（RenderRepaintBoundary.toImageSync）。
///
/// 液态玻璃面的自有采样捕获点在它自己的绘制位置——浮在主面板玻璃上面
/// 的子卡会把主面板玻璃的输出再采样一遍（玻璃叠玻璃，读感浑浊）。把
/// 整页预捕获成 [ui.Image] 直接喂给子卡玻璃的 shader（LiquidGlass 的
/// captureImage 通道），子卡取到的就是背后的首页内容本身，与一级弹窗
/// 同源。挂在页面根部的捕获边界同时承担整页重绘隔离，代价可忽略。
class PopupPageCaptureScope extends StatefulWidget {
  const PopupPageCaptureScope({super.key, required this.child});

  final Widget child;

  @override
  State<PopupPageCaptureScope> createState() => _PopupPageCaptureScopeState();
}

class _PopupPageCaptureScopeState extends State<PopupPageCaptureScope> {
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return PopupPageCaptureData(
      boundaryKey: _boundaryKey,
      child: RepaintBoundary(key: _boundaryKey, child: widget.child),
    );
  }
}

/// [PopupPageCaptureScope] 发布的数据。
class PopupPageCaptureData extends InheritedWidget {
  const PopupPageCaptureData({
    super.key,
    required this.boundaryKey,
    required super.child,
  });

  /// 宿主页面捕获边界的 key（[RepaintBoundary] 根）。
  final GlobalKey boundaryKey;

  /// 解析宿主页面的捕获边界；宿主未挂作用域时返回 null（二级子卡退回
  /// 共享组磨砂底采样）。
  static PopupPageCaptureData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PopupPageCaptureData>();

  @override
  bool updateShouldNotify(PopupPageCaptureData oldWidget) =>
      boundaryKey != oldWidget.boundaryKey;
}

/// Single item in [showHyperosListPopup].
class HyperosPopupMenuItem<T> {
  const HyperosPopupMenuItem({
    required this.label,
    required this.value,
    this.destructive = false,
    this.enabled = true,
    this.icon,
    this.iconColor,
    this.trailing,
    this.gapBefore = false,
    this.children = const [],
  });

  final String label;
  final T value;
  final bool destructive;
  final bool enabled;

  /// Optional leading icon, rendered at 20dp (Miuix check-icon size).
  final IconData? icon;

  /// Optional tint for [icon]; defaults to the label color.
  final Color? iconColor;

  /// Optional trailing widget (e.g. a dot badge) rendered at the row end.
  final Widget? trailing;

  /// Adds an 8dp gap above this row to group menu items (Miuix gap grouping).
  final bool gapBefore;

  /// 二级子列表（HyperOS 相册「视图」式）：非空时该行变成展开开关——
  /// 收起态尾部显示右向箭头，点按后在同一弹窗上方浮出独立的亮面子卡
  /// （父行 + 分隔线 + 子行），同时主面板压暗、其下行被浮层盖住；再点
  /// 一次（或点暗区/按返回键）收起。子行仍回传各自的 value。展开开关
  /// 行点按不再回传自身 value。
  final List<HyperosPopupMenuItem<T>> children;
}

/// Miuix spring spec (matches select popup / ListPopup defaults).
final _listPopupSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 362.5,
  ratio: 0.82,
);

/// Vertical gap before rows with [HyperosPopupMenuItem.gapBefore].
const _listPopupGroupGap = 8.0;

/// Exit animation length: rows fade + shrink back before the route pops.
/// Matches MiuixListPopupDefaults.alphaExitAnimationSpec.
const _listPopupExitDuration = Duration(milliseconds: 150);

/// Submenu reveal/collapse duration (HyperOS gallery menu pace).
const _submenuRevealDuration = Duration(milliseconds: 200);

/// 二级子卡展开时主面板沿锚点角等比回放的幅度（缩到 1-0.05）。弹出时
/// 面板从锚点角向左展开，展开子卡时向锚点角等比缩回一点，读作「面板
/// 让位退后、子卡浮前」，与系统相册的层级退让同语感。
const _panelReplayShrink = 0.05;

/// 展开动画的起跳值（0..1）。刻意不从 0 起跳：每次展开都会重挂面板
/// 玻璃（[_expandSession]），配合第一帧就带一点缩放，玻璃面的首次
/// 绘制直接落在缩放中——liquid_glass 包只有在「先无缩放绘制过、再遇
/// 双轴缩放」时才冻结几何矩阵（快照为 null 时不冻结），等比回放才能
/// 全程按 live 变换计算 uniform。对子卡揭示的影响仅是第一帧多出约 3%
/// 高度，肉眼不可辨。
const _submenuRevealFrom = 0.12;

/// Air above/below the hairline separating the submenu parent row from its
/// children (Miuix divider sits in whitespace, not flush against rows).
const _submenuDividerVerticalPadding = 4.0;

/// Height of the parent→children divider block (padding + hairline).
const double _submenuDividerBlock =
    _submenuDividerVerticalPadding * 2 + HyperosMiuixDivider.thickness;

/// Shows a Miuix-styled anchored list popup with spring animation + glass.
///
/// No-ops when [position] is null (anchor not mounted, see
/// [hyperosPopupPositionBelow]).
Future<T?> showHyperosListPopup<T>({
  required BuildContext context,
  required RelativeRect? position,
  required List<HyperosPopupMenuItem<T>> items,
  Color? foregroundColor,

  /// Use a solid opaque surface instead of sampled glass. Glass popups read
  /// as black when hovering an Android platform view (WebView), because the
  /// backdrop capture cannot include the platform view's texture.
  bool opaqueSurface = false,
}) async {
  final appearance = FrostedAppearanceScope.of(context);
  if (position == null || items.isEmpty) {
    return Future.value();
  }

  // 二级子卡的页面捕获来源：宿主页面根部的捕获边界。宿主未挂
  // [PopupPageCaptureScope] 时为 null，子卡退回共享组磨砂底采样。
  final pageBoundaryKey = PopupPageCaptureData.maybeOf(context)?.boundaryKey;

  return showGeneralDialog<T>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FrostedAppearanceScope(
        appearance: appearance,
        child: _HyperosListPopupBody<T>(
          position: position,
          items: items,
          foregroundColor: foregroundColor,
          opaqueSurface: opaqueSurface,
          pageBoundaryKey: pageBoundaryKey,
        ),
      );
    },
  );
}

class _HyperosListPopupBody<T> extends StatefulWidget {
  const _HyperosListPopupBody({
    required this.position,
    required this.items,
    this.foregroundColor,
    this.opaqueSurface = false,
    this.pageBoundaryKey,
  });

  final RelativeRect position;
  final List<HyperosPopupMenuItem<T>> items;

  /// Overrides the row label/icon color (e.g. wallpaper-aware chrome ink on
  /// the home screen); falls back to [HyperosColors.onSurface].
  final Color? foregroundColor;

  /// Solid surface instead of sampled glass (see [showHyperosListPopup]).
  final bool opaqueSurface;

  /// 宿主页面捕获边界（[PopupPageCaptureScope]）；null 表示宿主未提供，
  /// 液态子卡退回共享组磨砂底采样。
  final GlobalKey? pageBoundaryKey;

  @override
  State<_HyperosListPopupBody<T>> createState() =>
      _HyperosListPopupBodyState<T>();
}

class _HyperosListPopupBodyState<T> extends State<_HyperosListPopupBody<T>>
    with TickerProviderStateMixin {
  late final AnimationController _fraction = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _alpha = AnimationController(
    vsync: this,
    value: 0,
  );

  /// 二级子列表的展开/收起动画（高度揭示 + 主面板压暗共用一条曲线）。
  late final AnimationController _expand = AnimationController(
    vsync: this,
    duration: _submenuRevealDuration,
    value: 0,
  );

  /// 当前展开的父行下标；null = 收起。收起动画期间立即置 null（箭头、
  /// 点击豁免即时切换），卡片本体由 [_lastSubmenuIndex] 留在树上随
  /// [_expand] 逆放缩到 0。
  int? _expandedIndex;

  /// 最近一次展开的父行下标：收起动画期间浮层卡仍需知道自己的定位行。
  int? _lastSubmenuIndex;

  /// 主面板滚动位置：展开态按它修正子卡浮层的锚定行位置（长菜单小屏
  /// 情况下父行可能被滚过视口顶部）。
  final ScrollController _panelScroll = ScrollController();

  /// 主面板玻璃面（Transform 内）的定位键：浮层卡按它的实测宽度做
  /// min=max 宽度约束，保证两卡严格同宽。
  final GlobalKey _panelKey = GlobalKey();

  /// Guards re-entrant dismissal (tap outside + back key racing the exit).
  bool _dismissing = false;

  /// 面板玻璃的展开会话键：每次展开自增并重挂玻璃面。liquid_glass 包在
  /// 「已无缩放绘制过、再遇双轴缩放」时会冻结几何矩阵（matteTransform
  /// 返回旧快照），live 采样的 shader uniform 拿未缩放矩形导致边缘错位
  /// （实测等比回放时圆角错位亮带）。重挂让玻璃面首帧直接画在缩放中，
  /// 冻结快照保持 null，等比回放全程按 live 变换计算。副作用：面板
  /// 滚动位置重置——展开态本就禁用滚动，且常见菜单不溢出，可忽略。
  int _expandSession = 0;

  /// 菜单里是否挂了二级子列表。有才需要在遮罩后插共享组捕获垫层
  /// （二级子卡的玻璃按共享组采样，见 [HyperosSelectPopupGlass]
  /// 的 [HyperosSelectPopupGlass.useAncestorGroupCapture]）；无子列表
  /// 的菜单没有 grouped 消费者，不插，保持零多余全屏 pass。
  late final bool _hasSubmenu = widget.items.any(
    (item) => item.children.isNotEmpty,
  );

  /// 宿主页面的整页快照（不透明，含页面自身内容）+ 它的全局逻辑原点
  /// 与逻辑尺寸。页面在模态弹窗期间静止，弹窗打开时捕一份复用到关闭
  /// （见 [_warmPageCapture]，勿推迟到首次展开当帧）。快照作为子卡
  /// 玻璃面下的不透明垫底（见 _PopupPageSnapshotUnderlay）：玻璃面是
  /// 标准组件 live 采样垫底输出，模糊/折射/材质全走与一级相同的链路，
  /// 垫底只负责挡住主面板玻璃、对齐取样源亮度。
  ui.Image? _pageCapture;
  Offset _pageCaptureOrigin = Offset.zero;
  Size _pageCaptureSize = Size.zero;

  /// 弹窗打开当帧预热整页捕获（挂在 didChangeDependencies）。必须与
  /// 二级展开首帧错开：toImageSync 会在栅格线程同步栅格化整页边界，
  /// 而首次展开当帧恰好是子卡玻璃面（快照垫底 + 双 BackdropFilter
  /// 链）第一次在揭示窗口下合成——整页栅格化与揭示首帧的背景捕获在
  /// 栅格线程上争抢，实测真机表现为子卡顶缘一条横贯卡宽的亮带，随
  /// 揭示动画结束才消失，且仅每次弹窗会话的首次展开出现（快照已缓存
  /// 的再展开无此现象）。弹窗期间页面静止，打开时捕获与展开时捕获
  /// 内容完全一致，提前预热即可把这次栅格化从揭示帧挪走。捕获失败
  /// （宿主未挂作用域、边界未布局、toImageSync 异常等）保持 null，
  /// 子卡退回共享组磨砂底，且展开时仍会再试一次（[_ensurePageCapture]）。
  void _warmPageCapture() {
    if (_pageCapture != null) return;
    if (!_hasSubmenu) return;
    if (!HyperosSelectPopupGlass.liquidSurfaceActive(context)) return;
    _ensurePageCapture();
  }

  /// 确保宿主页面整页快照可用（幂等）。常规路径由 [_warmPageCapture]
  /// 在弹窗打开时调用；此处仅作展开时的兜底重试。
  void _ensurePageCapture() {
    if (_pageCapture != null) return;
    final key = widget.pageBoundaryKey;
    if (key == null) return;
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.hasSize ||
        boundary.size.isEmpty) {
      return;
    }
    try {
      _pageCapture = boundary.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      _pageCaptureOrigin = boundary.localToGlobal(Offset.zero);
      _pageCaptureSize = boundary.size;
    } catch (_) {
      _pageCapture = null;
    }
  }

  /// Plays the exit animation (fade + shrink, [MiuixListPopupDefaults]
  /// alphaExit spec) and only then pops the route with [result].
  ///
  /// Every dismissal path (scrim tap, row tap, system back) funnels through
  /// here so the popup never flashes away.
  Future<void> _dismiss([T? result]) async {
    if (_dismissing) return;
    _dismissing = true;
    final navigator = Navigator.of(context);
    _alpha.animateBack(
      0,
      duration: _listPopupExitDuration,
      curve: Curves.fastOutSlowIn,
    );
    _fraction.animateWith(
      SpringSimulation(
        _listPopupSpring,
        1,
        0,
        0,
        tolerance: const Tolerance(distance: 0.0001, velocity: 0.0001),
      ),
    );
    await Future<void>.delayed(_listPopupExitDuration);
    if (mounted) {
      navigator.pop(result);
    }
  }

  @override
  void initState() {
    super.initState();
    _fraction.animateWith(
      SpringSimulation(
        _listPopupSpring,
        0,
        1,
        0,
        tolerance: const Tolerance(distance: 0.0001, velocity: 0.0001),
      ),
    );
    _alpha.animateTo(
      1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 弹窗一打开就预热整页捕获（有二级子项且液态面激活时）：把
    // toImageSync 的整页栅格化从首次展开当帧挪走，见 _warmPageCapture。
    _warmPageCapture();
  }

  @override
  void dispose() {
    _fraction.dispose();
    _alpha.dispose();
    _expand.dispose();
    _panelScroll.dispose();
    _pageCapture?.dispose();
    _pageCapture = null;
    super.dispose();
  }

  /// HyperOS 相册「视图」式二级列表：点父行展开/收起（浮层卡 + 主面板
  /// 压暗 + 主面板沿锚点角等比回放一小段弹出动画），不回传父行 value。
  void _toggleSubmenu(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
        _expand.reverse();
      } else {
        _expandedIndex = index;
        _lastSubmenuIndex = index;
        // 液态子卡需要页面捕获图；磨砂/实底分支走共享组/实底，不采。
        // 常规已在弹窗打开时预热（_warmPageCapture），这里只兜底重试，
        // 避免整页栅格化落在揭示首帧（真机亮带问题，见预热方法注释）。
        if (HyperosSelectPopupGlass.liquidSurfaceActive(context)) {
          _ensurePageCapture();
        }
        // 重挂面板玻璃 + 起跳过 0：见 _expandSession 与 _submenuRevealFrom。
        _expandSession++;
        _expand.forward(from: _submenuRevealFrom);
      }
    });
  }

  /// 父行在主面板内容里的纵向偏移（行高 + 分组间隔都是定值，可纯算术
  /// 求出，无需布局后再测量）。
  double _rowTopInPanel(int index) {
    var top = 0.0;
    for (var i = 0; i < index && i < widget.items.length; i++) {
      top +=
          HyperosMiuixBasicComponent.minHeight +
          (widget.items[i].gapBefore ? _listPopupGroupGap : 0);
    }
    return top;
  }

  /// 收起态内容总高（与 build 里的 estimatedHeight 同一口径，抽出复用）。
  double get _panelEstimatedHeight => widget.items.fold<double>(
    0,
    (height, item) =>
        height +
        HyperosMiuixBasicComponent.minHeight +
        (item.gapBefore ? _listPopupGroupGap : 0),
  );

  /// 子菜单浮层卡内容高度：父行 + 分隔线块 + 子行（卡内一律不带分组
  /// 间隔，父→子的分隔由卡自身绘制）。
  double _submenuCardHeight(HyperosPopupMenuItem<dynamic> item) =>
      HyperosMiuixBasicComponent.minHeight * (1 + item.children.length) +
      _submenuDividerBlock;

  /// 浮层卡的全局纵向位置：面板顶 + 父行面板内偏移 − 面板已滚过的量，
  /// 屏幕安全区越界时上收（极小屏 + 父行贴近菜单末尾时卡片退成指向式
  /// 气泡，优先保证子项全部可见可点）。卡片在全屏 Stack 定位（命中测试
  /// 不受主面板边界截断）。
  double _submenuCardTopGlobal({
    required double top,
    required double safeTop,
    required double safeBottom,
  }) {
    final index = _lastSubmenuIndex!;
    final item = widget.items[index];
    // 重挂过渡帧（[_expandSession] 自增当帧）旧滚动位置尚未 detach、
    // 新视图已挂上，positions 可能短暂为 2——新视图从 0 起，取 0 与
    // 重挂后的视觉位置一致；稳定态单 position 正常读。
    final scrollOffset = _panelScroll.positions.length == 1
        ? _panelScroll.offset
        : 0.0;
    final raw = top + _rowTopInPanel(index) - scrollOffset;
    final maxTop = safeBottom - _submenuCardHeight(item);
    if (raw > maxTop) {
      return math.max(safeTop, maxTop);
    }
    return math.max(safeTop, raw);
  }

  /// 主面板实测宽度 → 浮层卡宽度约束（min=max 严格同宽）。宽度按帧
  /// 缓存：展开会重挂面板玻璃（[_expandSession]），重挂当帧的构建期
  /// 新渲染对象尚未 layout（hasSize=false），此时沿用上次实测宽度，
  /// 避免构建期断言与卡宽跳变；未挂载时兜底 200..364。
  double? _panelMeasuredWidth;

  /// 页面快照垫底的全局对齐原点 = 卡片真实左上角。右对齐时 [cardLeft]
  /// 是「卡片右缘」（Positioned 只给 right），必须减去卡宽才是左上角；
  /// 卡宽与卡身 ConstrainedBox 同源（[_panelMeasuredWidth]，未实测帧
  /// 用最小宽 200 兜底——仅重挂首帧，垫底暗底模糊，一帧偏差不可辨）。
  /// 错一个卡宽会让垫底几乎完全盖不住主面板玻璃（玻璃叠玻璃浑浊复发）。
  Offset _submenuCardUnderlayOrigin({
    required double cardLeft,
    required bool isRightAligned,
    required double top,
    required double safeTop,
    required double safeBottom,
  }) {
    final width = _panelMeasuredWidth ?? 200.0;
    return Offset(
      isRightAligned ? cardLeft - width : cardLeft,
      _submenuCardTopGlobal(
        top: top,
        safeTop: safeTop,
        safeBottom: safeBottom,
      ),
    );
  }

  BoxConstraints _submenuCardWidthConstraints() {
    final renderBox = _panelKey.currentContext?.findRenderObject();
    if (renderBox is RenderBox && renderBox.hasSize) {
      _panelMeasuredWidth = renderBox.size.width;
    }
    final width = _panelMeasuredWidth;
    if (width == null || width <= 0) {
      return const BoxConstraints(minWidth: 200, maxWidth: 364);
    }
    return BoxConstraints(minWidth: width, maxWidth: width);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    const margin = 12.0;
    const cornerRadius = HyperosMiuixDropdown.popupCornerRadius;

    // Resolve anchor position from RelativeRect.
    final anchorLeft = widget.position.left;
    final anchorTop = widget.position.top;
    final anchorRight = screen.width - widget.position.right;
    final anchorBottom = screen.height - widget.position.bottom;
    final showBelow = anchorTop <= screen.height - anchorBottom;

    // Estimate popup height for layout: rows plus Miuix group gaps, so
    // [maxHeight] never ends up a few pixels shorter than the real content
    // (which would make the popup scrollable even though everything fits).
    // 与浮层卡定位共用同一口径（_panelEstimatedHeight）。
    final estimatedHeight = _panelEstimatedHeight;
    final safeTop = MediaQuery.paddingOf(context).top + margin;
    final safeBottom =
        screen.height - MediaQuery.paddingOf(context).bottom - margin;

    double top;
    if (showBelow && anchorTop + estimatedHeight <= safeBottom) {
      top = anchorTop;
    } else if (anchorBottom - estimatedHeight >= safeTop) {
      top = anchorBottom - estimatedHeight;
    } else {
      top = anchorTop;
    }
    top = top.clamp(safeTop, safeBottom);
    final available = (safeBottom - top).clamp(0.0, double.infinity);
    // When the estimated content fits, leave the popup unconstrained so the
    // scroll view never offers a stray drag even if real content measures a
    // few pixels taller than the estimate. Only cap height (and enable
    // scrolling) when the content would actually overflow the screen.
    final maxHeight = available < estimatedHeight ? available : double.infinity;

    final localOriginY = showBelow ? 0.0 : 1.0;
    // Left-aligned if anchor is on the left half, right-aligned otherwise.
    final isRightAligned = anchorRight > screen.width / 2;
    final originX = isRightAligned ? 1.0 : 0.0;
    // 二级子卡的定位基点（与子卡 Positioned 的 left/right 约束同一口
    // 径）。注意语义：右对齐时 Positioned 只给 right，这是「卡片右缘」，
    // 不是左缘——快照垫底对齐见 _submenuCardUnderlayOrigin。
    final cardLeft = isRightAligned
        ? screen.width -
            (screen.width - anchorRight).clamp(margin, screen.width - margin)
        : anchorLeft.clamp(margin, screen.width - margin);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // 返回键先收起二级子列表（对齐系统相册），再按一次才关弹窗。
          final expanded = _expandedIndex;
          if (expanded != null) {
            _toggleSubmenu(expanded);
          } else {
            _dismiss();
          }
        }
      },
      child: BackdropGroup(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 共享组捕获垫层（遮罩之后、主面板之前）：组内首个 grouped
            // 过滤器的捕获点决定采样内容——二级子卡的玻璃由此采到
            // 「遮罩下的页面」（与主面板玻璃同源），而不是把主面板玻璃
            // 的输出再采样一遍。仅当有二级子项且采样面可用时才付这层
            // 全屏 pass（其余情况树内没有 grouped 消费者）。
            if (_hasSubmenu &&
                (HyperosBlurredHeader.backdropBlurEnabled(context) ||
                    HyperosSelectPopupGlass.liquidSurfaceActive(context)))
              const Positioned.fill(child: UndimmedBackdropCapture()),
            // Dim 以渐变 alpha 淡入（复用 _alpha AnimationController, 200ms fastOutSlowIn）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: AnimatedBuilder(
                animation: _alpha,
                builder: (context, _) {
                  final base = HyperosBlurredHeader.modalBarrierColor(context);
                  return ColoredBox(
                    color: base.withValues(
                      alpha: base.a * _alpha.value.clamp(0.0, 1.0),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: top,
              left: isRightAligned
                  ? null
                  : anchorLeft.clamp(margin, screen.width - margin),
              right: isRightAligned
                  ? (screen.width - anchorRight).clamp(
                      margin,
                      screen.width - margin,
                    )
                  : null,
              child: AnimatedBuilder(
                // 展开态主面板要跟着 _expand 回放缩放，与子卡揭示同步。
                animation: Listenable.merge([_fraction, _expand]),
                builder: (context, _) {
                  final fraction = _fraction.value.clamp(0.0, 1.0);
                  // 弹出动画（锚点角 0.15→1 弹簧）× 展开回放：子卡展开
                  // 时面板沿锚点角等比缩回一点，收起时随 _expand 逆放回
                  // 1。锚点对齐沿用弹出动画的角。等比回放的几何正确性由
                  // _expandSession 重挂 + _submenuRevealFrom 起跳保证。
                  final replay =
                      1 -
                      _panelReplayShrink *
                          Curves.fastOutSlowIn.transform(_expand.value);
                  final scale = (0.15 + 0.85 * fraction) * replay;
                  final Widget panelChild = ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 200,
                      maxWidth: (screen.width - margin * 2).clamp(200.0, 364.0),
                      maxHeight: maxHeight,
                    ),
                    child: SingleChildScrollView(
                      controller: _panelScroll,
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < widget.items.length; i++)
                              _ListPopupTile(
                                item: widget.items[i],
                                foregroundColor: widget.foregroundColor,
                                expanded: _expandedIndex == i,
                                // Selecting an item pops the popup immediately
                                // so the destination page can start its
                                // transition right away; the exit animation
                                // would otherwise delay navigation by 150ms.
                                // (Scrim taps and the back key still play the
                                // fade-out.) 有子列表的行改为展开开关，不回传。
                                onTap: !widget.items[i].enabled
                                    ? null
                                    : widget.items[i].children.isNotEmpty
                                    ? () => _toggleSubmenu(i)
                                    : () => Navigator.of(
                                        context,
                                      ).pop(widget.items[i].value),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                  // 展开态：主面板整面压暗（对齐系统相册的「父卡退后」），
                  // 暗层吸收点按=收起子列表；面板行不再可点（滚动也随之
                  // 停用，保证浮层卡与锚定行的算术对位不被滚动打破）。
                  final Widget dimmedPanelChild = Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IgnorePointer(
                        ignoring: _expandedIndex != null,
                        child: panelChild,
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: _expandedIndex == null,
                          child: GestureDetector(
                            onTap: _expandedIndex != null
                                ? () => _toggleSubmenu(_expandedIndex!)
                                : null,
                            child: AnimatedBuilder(
                              animation: _expand,
                              builder: (context, _) {
                                final t = Curves.fastOutSlowIn.transform(
                                  _expand.value,
                                );
                                if (t == 0) {
                                  return const SizedBox.shrink();
                                }
                                final base =
                                    HyperosBlurredHeader.modalBarrierColor(
                                      context,
                                    );
                                return ColoredBox(
                                  color: base.withValues(alpha: base.a * t),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                  return Transform.scale(
                    scale: scale,
                    alignment: Alignment(originX * 2 - 1, localOriginY * 2 - 1),
                    // No reveal clip around the glass: clipping the backdrop
                    // surface every spring frame resamples the group capture
                    // and reads as whole-page flicker on open/close. The
                    // Miuix scale + alpha motion stays, without the clip.
                    // 实色回退（opaqueSurface）：悬在 WebView 平台视图上方时，
                    // 玻璃的背景采集读不到平台视图内容，会渲染成黑色面板。
                    child: KeyedSubtree(
                      key: _panelKey,
                      child: KeyedSubtree(
                        // 展开会话键（见 _expandSession）：每次展开重挂
                        // 玻璃面，首帧即画在缩放中，包内冻结快照保持空。
                        key: ValueKey<int>(_expandSession),
                        child: widget.opaqueSurface
                            ? HyperosSolidPopupSurface(
                                cornerRadius: cornerRadius,
                                child: dimmedPanelChild,
                              )
                            : HyperosSelectPopupGlass(
                                cornerRadius: cornerRadius,
                                child: dimmedPanelChild,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 二级子列表浮层卡：独立亮面玻璃，锚定父行原位（父行在卡内
            // 原样重复，视觉上不动，其下方行被亮卡盖住，对齐系统相册展开
            // 「视图」的形态）。与主面板平级放在全屏 Stack：命中测试不被
            // 面板/Transform 边界截断；宽度用 _panelKey 读主面板实测尺寸
            // 做 min=max 约束，两卡严格同宽；关窗时不随主面板弹簧缩放，
            // 只走 _alpha 淡出（展开只会发生在弹簧结束后）。玻璃按
            // useAncestorGroupCapture 同源采样：液态激活时优先折射宿主
            // 页面捕获图（背后首页本身），无捕获图退回共享组磨砂底；
            // 都不再把主面板玻璃的输出采一遍。揭示窗口裁在玻璃面外侧
            // （玻璃面布局全程不变）。
            if (_lastSubmenuIndex != null)
              Positioned(
                top: _submenuCardTopGlobal(
                  top: top,
                  safeTop: safeTop,
                  safeBottom: safeBottom,
                ),
                left: isRightAligned
                    ? null
                    : anchorLeft.clamp(margin, screen.width - margin),
                right: isRightAligned
                    ? (screen.width - anchorRight).clamp(
                        margin,
                        screen.width - margin,
                      )
                    : null,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_expand, _alpha]),
                  builder: (context, _) {
                    final t = Curves.fastOutSlowIn.transform(_expand.value);
                    if (t == 0) {
                      return const SizedBox.shrink();
                    }
                    final item = widget.items[_lastSubmenuIndex!];
                    final cardHeight = _submenuCardHeight(item);
                    // 玻璃面按完整内容尺寸稳定布局，揭示窗口裁在玻璃面
                    // 外侧（见下方 ClipRect）。旧实现把揭示放在玻璃内侧
                    // （Align heightFactor 包着玻璃），玻璃面布局高度逐帧
                    // 从 0 长到全高：头几帧高度小于 2×圆角时超椭圆形状退
                    // 化、玻璃逐帧重采样，顶边会闪一下；现在第一帧起就是
                    // 完整圆角形状（从圆角开始显示），动画只动裁剪窗口。
                    Widget card = ConstrainedBox(
                      constraints: _submenuCardWidthConstraints(),
                      child: SizedBox(
                        height: cardHeight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ListPopupTile(
                              item: item,
                              foregroundColor: widget.foregroundColor,
                              expanded: true,
                              // 卡内不带分组间隔：顶边就是面板里
                              // 的原行位。
                              includeGroupGap: false,
                              onTap: () =>
                                  _toggleSubmenu(_lastSubmenuIndex!),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: HyperosMiuixDropdown
                                    .insideHorizontalPadding,
                                vertical: _submenuDividerVerticalPadding,
                              ),
                              child: Container(
                                height: HyperosMiuixDivider.thickness,
                                color: (widget.foregroundColor ??
                                        HyperosColors.onSurface(context))
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                            for (final child in item.children)
                              _ListPopupTile(
                                item: child,
                                foregroundColor: widget.foregroundColor,
                                includeGroupGap: false,
                                onTap: child.enabled
                                    ? () =>
                                        Navigator.of(context).pop(child.value)
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    );
                    card = widget.opaqueSurface
                        ? HyperosSolidPopupSurface(
                            cornerRadius: cornerRadius,
                            child: card,
                          )
                        : HyperosSelectPopupGlass(
                            cornerRadius: cornerRadius,
                            // 同源采样：不透明整页快照垫底挡住主面板玻璃，
                            // 玻璃面是标准组件（与一级同链路的 live 采样），
                            // 透出的就是背后首页本身。
                            useAncestorGroupCapture: true,
                            pageCapture: _pageCapture == null
                                ? null
                                : PopupPageCapture(
                                    image: _pageCapture!,
                                    origin: _pageCaptureOrigin,
                                    size: _pageCaptureSize,
                                    scrimColor:
                                        HyperosBlurredHeader.modalBarrierColor(
                                          context,
                                        ),
                                  ),
                            // 卡片全局原点：快照垫底按它对齐「卡片在页
                            // 面坐标系中的位置」（仅在展开分支求值，
                            // _lastSubmenuIndex 必非空）。右对齐时必须从
                            // 右缘减卡宽，见 _submenuCardUnderlayOrigin。
                            pageAlignedOrigin: _submenuCardUnderlayOrigin(
                              cardLeft: cardLeft,
                              isRightAligned: isRightAligned,
                              top: top,
                              safeTop: safeTop,
                              safeBottom: safeBottom,
                            ),
                            child: card,
                          );
                    // 高度因子揭示（玻璃面外侧）：裁剪窗口从父行顶边向下
                    // 生长，父行位置全程不动；底缘圆角在窗口到达卡底时
                    // 露出，t=1 时窗口即完整卡。
                    card = ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: t,
                        child: card,
                      ),
                    );
                    if (_alpha.value < 1) {
                      card = Opacity(opacity: _alpha.value, child: card);
                    }
                    return card;
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Individual row in the list popup.
class _ListPopupTile extends StatelessWidget {
  const _ListPopupTile({
    required this.item,
    this.foregroundColor,
    this.onTap,
    this.expanded = false,
    this.includeGroupGap = true,
  });

  final HyperosPopupMenuItem<dynamic> item;
  final Color? foregroundColor;
  final VoidCallback? onTap;

  /// 二级子列表父行的展开态（箭头朝上）；仅 [HyperosPopupMenuItem.children]
  /// 非空时渲染箭头，收起态箭头朝右。
  final bool expanded;

  /// 是否渲染 [HyperosPopupMenuItem.gapBefore] 的分组间隔。子菜单浮层卡
  /// 内一律为 false：卡顶边就是面板里的原行位，父→子的分隔由卡自身绘制。
  final bool includeGroupGap;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? HyperosColors.error(context)
        : (item.enabled
              ? (foregroundColor ?? HyperosColors.onSurface(context))
              : HyperosColors.disabledOnSurface(context));

    // Popup surfaces are translucent glass (or a solid container fallback);
    // the settings-row pressed gray (opaque E0E0E0) would read as a solid
    // block through the glass, so use the same translucent wash family as
    // nested tile tints.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final row = HyperosPressableRow(
      onTap: onTap,
      backgroundColor: Colors.transparent,
      highlightColor: highlightColor,
      child: SizedBox(
        height: HyperosMiuixBasicComponent.minHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: HyperosMiuixDropdown.insideHorizontalPadding,
            end: HyperosMiuixDropdown.insideHorizontalPadding,
          ),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: HyperosMiuixDropdown.checkIconSize,
                  color: item.iconColor ?? color,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: HyperosMiuixTypography.body1,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.children.isNotEmpty) ...[
                const SizedBox(width: 12),
                // 「视图」式展开开关：收起 ▸ / 展开 ▴，弱于正文的次级墨色。
                AnimatedRotation(
                  turns: expanded ? -0.25 : 0,
                  duration: _submenuRevealDuration,
                  curve: Curves.fastOutSlowIn,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: HyperosMiuixDropdown.checkIconSize,
                    color: color.withValues(alpha: 0.45),
                  ),
                ),
              ] else if (item.trailing != null) ...[
                const SizedBox(width: 12),
                item.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
    return includeGroupGap && item.gapBefore
        ? Padding(padding: const EdgeInsets.only(top: 8), child: row)
        : row;
  }
}

/// Anchor helper — positions popup below [anchorKey]'s render box.
///
/// Returns null when the anchor is not mounted / laid out yet; pass the result
/// straight to [showHyperosListPopup], which no-ops on null.
RelativeRect? hyperosPopupPositionBelow(
  BuildContext context,
  GlobalKey anchorKey, {
  double verticalGap = 4,
}) {
  final renderObject = anchorKey.currentContext?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final size = renderObject.size;
  final screen = MediaQuery.sizeOf(context);

  return RelativeRect.fromLTRB(
    topLeft.dx,
    topLeft.dy + size.height + verticalGap,
    screen.width - topLeft.dx - size.width,
    screen.height - topLeft.dy - size.height - verticalGap,
  );
}
