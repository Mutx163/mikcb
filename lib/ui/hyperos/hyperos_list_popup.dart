import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_select.dart';
import 'hyperos_theme.dart';
import 'hyperos_widgets.dart';

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
  });

  final RelativeRect position;
  final List<HyperosPopupMenuItem<T>> items;

  /// Overrides the row label/icon color (e.g. wallpaper-aware chrome ink on
  /// the home screen); falls back to [HyperosColors.onSurface].
  final Color? foregroundColor;

  /// Solid surface instead of sampled glass (see [showHyperosListPopup]).
  final bool opaqueSurface;

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
  void dispose() {
    _fraction.dispose();
    _alpha.dispose();
    _expand.dispose();
    _panelScroll.dispose();
    super.dispose();
  }

  /// HyperOS 相册「视图」式二级列表：点父行展开/收起（浮层卡 + 主面板
  /// 压暗），不回传父行 value。
  void _toggleSubmenu(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
        _expand.reverse();
      } else {
        _expandedIndex = index;
        _lastSubmenuIndex = index;
        _expand.forward(from: 0);
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
    final scrollOffset = _panelScroll.hasClients ? _panelScroll.offset : 0.0;
    final raw = top + _rowTopInPanel(index) - scrollOffset;
    final maxTop = safeBottom - _submenuCardHeight(item);
    if (raw > maxTop) {
      return math.max(safeTop, maxTop);
    }
    return math.max(safeTop, raw);
  }

  /// 主面板实测宽度 → 浮层卡宽度约束（min=max 严格同宽）。面板已布局
  /// （展开只会在弹窗完全出现后发生）；未挂载时兜底 200..364。
  BoxConstraints _submenuCardWidthConstraints() {
    final renderBox =
        _panelKey.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width;
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
            // 原 UndimmedBackdropCapture 垫层已移除：树内无 grouped 过滤器，
            // 垫层采样无消费者，纯多余全屏 pass。
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
                animation: _fraction,
                builder: (context, _) {
                  final fraction = _fraction.value.clamp(0.0, 1.0);
                  final scale = 0.15 + 0.85 * fraction;
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
                  );
                },
              ),
            ),
            // 二级子列表浮层卡：独立亮面玻璃，锚定父行原位（父行在卡内
            // 原样重复，视觉上不动，其下方行被亮卡盖住，对齐系统相册展开
            // 「视图」的形态）。与主面板平级放在全屏 Stack：命中测试不被
            // 面板/Transform 边界截断；宽度用 _panelKey 读主面板实测尺寸
            // 做 min=max 约束，两卡严格同宽；关窗时不随主面板弹簧缩放，
            // 只走 _alpha 淡出（展开只会发生在弹簧结束后）。
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
                    Widget card = ClipRect(
                      // 高度因子揭示：卡自身始终按完整内容高度排版，仅裁出
                      // 顶部 t 段——展开时底缘向下生长（圆角随动），父行
                      // 位置全程不动。
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: t,
                        child: ConstrainedBox(
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
                                    color:
                                        (widget.foregroundColor ??
                                                HyperosColors.onSurface(
                                                  context,
                                                ))
                                            .withValues(alpha: 0.15),
                                  ),
                                ),
                                for (final child in item.children)
                                  _ListPopupTile(
                                    item: child,
                                    foregroundColor: widget.foregroundColor,
                                    includeGroupGap: false,
                                    onTap: child.enabled
                                        ? () => Navigator.of(
                                            context,
                                          ).pop(child.value)
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    if (_alpha.value < 1) {
                      card = Opacity(opacity: _alpha.value, child: card);
                    }
                    return widget.opaqueSurface
                        ? HyperosSolidPopupSurface(
                            cornerRadius: cornerRadius,
                            child: card,
                          )
                        : HyperosSelectPopupGlass(
                            cornerRadius: cornerRadius,
                            child: card,
                          );
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
