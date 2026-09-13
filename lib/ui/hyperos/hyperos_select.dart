import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_miuix/miuix.dart';

import 'package:flutter/services.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_controls.dart';
import 'hyperos_glass_backdrop_host.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_sheet.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';
import 'os4_glass_backdrop.dart';
import '../../widgets/miuix_date_picker_sheet.dart';
import 'frosted/liquid_glass_degradation.dart';
import 'liquid/hyperos_liquid_glass_surface.dart';
import 'soft_glass/soft_glass_surface.dart';

/// Row padding for [HyperosSelectTile] (and similar chevron rows).
///
/// Correct first/last insets require one of:
/// - [HyperosListGroup] → [HyperosListTileScope]
/// - [HyperosControlCardRows] inside [HyperosControlCard] → [HyperosControlCardRowScope]
///
/// A bare [Column] of select tiles under [HyperosControlCard] has no row scope;
/// each tile then defaults to first+last (and absorbs [bodyBottomInset]), which
/// is only valid for a **single** full-bleed child.
///
/// [bodyBottomBleed] is **not** folded into [padding]: baking the card's
/// bottom inset into content padding makes the label look top-heavy. Apply it
/// as empty space *below* a symmetrically padded [hyperosListRowShell] so the
/// press highlight still reaches the card edge.
({double minHeight, EdgeInsets padding, double bodyBottomBleed})
hyperosSelectRowLayout(BuildContext context, {bool twoLine = false}) {
  final listScope = HyperosListTileScope.maybeOf(context);
  final cardRowScope = HyperosControlCardRowScope.maybeOf(context);
  final cardScope = HyperosControlCardScope.maybeOf(context);

  // Prefer shared edge flags; lone select under a ControlCard is last so it
  // can absorb [bodyBottomInset] via [bodyBottomBleed].
  final edges = hyperosRowEdgeFlags(context);
  final isFirst = edges.isFirst;
  final isLast = listScope?.isLast ?? cardRowScope?.isLast ?? cardScope != null;

  final padding =
      (listScope != null || cardRowScope != null || cardScope != null)
      ? HyperosTokens.chevronRowPadding(isFirst: isFirst, isLast: isLast)
      : HyperosTokens.chevronRowPadding();

  final bodyBottomBleed = (cardScope != null && isLast)
      ? cardScope.bodyBottomInset
      : 0.0;

  final baseMinHeight = twoLine
      ? HyperosTokens.listRowTwoLineMinHeight
      : HyperosTokens.listRowMinHeight;

  return (
    minHeight: baseMinHeight,
    padding: padding,
    bodyBottomBleed: bodyBottomBleed,
  );
}

/// Global rect of [anchorKey]'s render box (for anchored select popups).
///
/// Returns null when the anchor is not mounted / laid out yet; callers should
/// fall back to a sheet or skip opening instead of crashing.
Rect? hyperosSelectPopupAnchorRect(BuildContext context, GlobalKey anchorKey) {
  final renderObject = anchorKey.currentContext?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  final topLeft = renderObject.localToGlobal(Offset.zero);
  return topLeft & renderObject.size;
}

/// Opens an anchored HyperOS dropdown popup (Miuix `OverlayDropdownPopup`).
///
/// Best for short option lists triggered from a settings row. The popup is
/// right-aligned to [anchorRect] and appears just below the row.
///
/// When [itemTitleStyleBuilder] is provided, each option's title is rendered
/// with the style it returns (merged over the default list-title style). This
/// is used by the appearance font picker to preview each option's own typeface.
///
/// Selected options keep the same gray press fill as outer [HyperosSelectTile]
/// rows for a short commit window so the highlight can paint before the route
/// is popped.
const _hyperosSelectPopupCommitDelay = Duration(milliseconds: 100);

Future<void> _hyperosSelectCommitPopupValue<T>(
  BuildContext context,
  T value,
) async {
  await Future<void>.delayed(_hyperosSelectPopupCommitDelay);
  if (!context.mounted) {
    return;
  }
  Navigator.of(context).pop(value);
}

Future<T?> showHyperosSelectPopup<T>({
  required BuildContext context,
  required Rect? anchorRect,
  required Map<String, T> items,
  required T? currentValue,
  TextStyle? Function(T value)? itemTitleStyleBuilder,
  Widget? Function(T value)? itemPrefixBuilder,
}) async {
  final appearance = FrostedAppearanceScope.of(context);
  final entries = items.entries.toList(growable: false);
  if (entries.isEmpty || anchorRect == null) {
    return Future.value();
  }

  return showGeneralDialog<T>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    // No route-level transition: the popup runs its own spring + alpha
    // animation internally. A route FadeTransition would wrap the glass in an
    // Opacity layer that degrades the LiquidGlass shader (black flash).
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FrostedAppearanceScope(
        appearance: appearance,
        child: _HyperosSelectPopupBody<T>(
          anchorRect: anchorRect,
          entries: entries,
          currentValue: currentValue,
          itemTitleStyleBuilder: itemTitleStyleBuilder,
          itemPrefixBuilder: itemPrefixBuilder,
        ),
      );
    },
  );
}

class _HyperosSelectPopupBody<T> extends StatefulWidget {
  const _HyperosSelectPopupBody({
    required this.anchorRect,
    required this.entries,
    required this.currentValue,
    required this.itemTitleStyleBuilder,
    this.itemPrefixBuilder,
  });

  final Rect anchorRect;
  final List<MapEntry<String, T>> entries;
  final T? currentValue;
  final TextStyle? Function(T value)? itemTitleStyleBuilder;
  final Widget? Function(T value)? itemPrefixBuilder;

  @override
  State<_HyperosSelectPopupBody<T>> createState() =>
      _HyperosSelectPopupBodyState<T>();
}

/// Miuix spring spec for popup fraction (scale + reveal) animation.
/// Matches `MiuixListPopupDefaults.fractionAnimationSpec`.
final _popupSpringDesc = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 362.5,
  ratio: 0.82,
);

class _HyperosSelectPopupBodyState<T> extends State<_HyperosSelectPopupBody<T>>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _itemKeys = <int, GlobalKey>{};

  /// Spring-driven fraction (0→1) for scale + reveal clip.
  late final AnimationController _fraction = AnimationController.unbounded(
    vsync: this,
  );

  /// Tween-driven alpha for content fade-in.
  late final AnimationController _alpha = AnimationController(
    vsync: this,
    value: 0,
  );

  /// Visual selection while the popup is open. Starts as [currentValue] and
  /// moves to the tapped option immediately so blue title + checkmark update
  /// together with the press fill before the route is popped.
  late T? _displayedValue = widget.currentValue;
  bool _isCommitting = false;

  int? get _selectedIndex {
    for (var i = 0; i < widget.entries.length; i++) {
      if (widget.entries[i].value == _displayedValue) return i;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Enter animation: spring fraction + tween alpha (miuix ListPopup spec).
    _fraction.animateWith(
      SpringSimulation(
        _popupSpringDesc,
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
    _scrollController.dispose();
    _fraction.dispose();
    _alpha.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    final index = _selectedIndex;
    if (index == null || !_scrollController.hasClients) return;
    final key = _itemKeys[index];
    final context = key?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  void _onOptionTapped(T value) {
    if (_isCommitting) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _isCommitting = true;
      _displayedValue = value;
    });
    unawaited(_hyperosSelectCommitPopupValue(context, value));
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    const margin = 12.0;
    final safeTop = MediaQuery.paddingOf(context).top + margin;
    final safeBottom =
        screen.height - MediaQuery.paddingOf(context).bottom - margin;
    final estimatedHeight = hyperosSelectPopupEstimatedHeight(
      widget.entries.length,
    );
    final layout = hyperosSelectPopupLayout(
      anchorRect: widget.anchorRect,
      estimatedPopupHeight: estimatedHeight,
      screenHeight: screen.height,
      safeTop: safeTop,
      safeBottom: safeBottom,
    );

    // Right edge of popup aligns with anchor row (HyperOS anchored dropdown).
    final anchorRight = widget.anchorRect.right.clamp(
      margin,
      screen.width - margin,
    );

    // Determine popup position relative to anchor for transform origin.
    final showBelow = layout.top >= widget.anchorRect.bottom;
    // Right-aligned popup: transform origin at top-right (or bottom-right).
    final localOriginY = showBelow ? 0.0 : 1.0;

    final popupChild = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 132 + HyperosMiuixDropdown.popupExtraLeadingWidth,
        maxWidth: (screen.width - margin * 2).clamp(
          132.0 + HyperosMiuixDropdown.popupExtraLeadingWidth,
          HyperosMiuixDropdown.maxItemTextWidth +
              HyperosMiuixDropdown.popupExtraLeadingWidth +
              HyperosMiuixDropdown.insideHorizontalPadding * 2 +
              HyperosMiuixDropdown.checkIconSize +
              28,
        ),
        maxHeight: layout.maxHeight,
      ),
      child: HyperosSelectPopupGlass(
        cornerRadius: HyperosMiuixDropdown.popupCornerRadius,
        child: HyperosSurfaceRadiusScope(
          radius: HyperosMiuixDropdown.popupCornerRadius,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.entries.length; i++)
                    Builder(
                      builder: (tileContext) {
                        _itemKeys[i] = GlobalKey();
                        final entry = widget.entries[i];
                        final isSelected = entry.value == _displayedValue;
                        return KeyedSubtree(
                          key: _itemKeys[i],
                          child: HyperosListTileScope(
                            isFirst: i == 0,
                            isLast: i == widget.entries.length - 1,
                            child: HyperosChoiceTile(
                              title: entry.key,
                              selected: isSelected,
                              highlightSelectedText: true,
                              variant: HyperosChoiceVariant.popup,
                              isFirstInPopup: i == 0,
                              isLastInPopup: i == widget.entries.length - 1,
                              titleStyle: widget.itemTitleStyleBuilder?.call(
                                entry.value,
                              ),
                              prefix: widget.itemPrefixBuilder?.call(
                                entry.value,
                              ),
                              forceHighlighted: _isCommitting && isSelected,
                              onTap: _isCommitting
                                  ? () {}
                                  : () => _onOptionTapped(entry.value),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // BackdropGroup boundary: grouped filters in the popup glass sample the
    // backdrop captured HERE (the undimmed page). The dim ColoredBox below is
    // inside the group, so it darkens the screen without ever entering the
    // glass's blur/refraction input — no geometric hole-punching needed.
    return BackdropGroup(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: UndimmedBackdropCapture()),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
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
            top: layout.top,
            right: screen.width - anchorRight,
            child: AnimatedBuilder(
              animation: _fraction,
              builder: (context, _) {
                final fraction = _fraction.value.clamp(0.0, 1.0);
                final scale = 0.15 + 0.85 * fraction;
                // No Opacity here: an Opacity layer (opacity < 1) isolates the
                // popup into an offscreen layer, so the glass BackdropFilter /
                // liquid shader samples an empty backdrop and renders fully
                // transparent until the fade ends (then snaps to blur). Scale +
                // clip reveal carry the entrance while the glass stays live.
                return Transform.scale(
                  scale: scale,
                  alignment: Alignment(1, localOriginY * 2 - 1),
                  child: ClipPath(
                    clipper: SelectPopupRevealClipper(
                      progress: fraction,
                      showBelow: showBelow,
                      cornerRadius: HyperosMiuixDropdown.popupCornerRadius,
                    ),
                    child: popupChild,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelected();
    });
  }
}

/// Squircle-ish reveal clipper for select popup enter animation.
///
/// Mirrors `MiuixListPopupContent._PopupRevealClipper`: progressively reveals
/// the popup from the anchor-facing edge (top when below, bottom when above).
class SelectPopupRevealClipper extends CustomClipper<Path> {
  const SelectPopupRevealClipper({
    required this.progress,
    required this.showBelow,
    required this.cornerRadius,
  });

  final double progress;
  final bool showBelow;
  final double cornerRadius;

  @override
  Path getClip(Size size) {
    final value = progress.clamp(0.0, 1.0);
    if (value <= 0 || size.isEmpty) return Path();
    final visibleHeight = size.height * value;
    final top = showBelow ? 0.0 : size.height - visibleHeight;
    final r = cornerRadius
        .clamp(0.0, visibleHeight / 2)
        .clamp(0.0, size.width / 2);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, size.width, visibleHeight),
          Radius.circular(r),
        ),
      );
    return path;
  }

  @override
  bool shouldReclip(SelectPopupRevealClipper oldClipper) {
    return oldClipper.progress != progress ||
        oldClipper.showBelow != showBelow ||
        oldClipper.cornerRadius != cornerRadius;
  }
}

/// Glass background for the select popup.
///
/// Renders the appropriate surface based on [FrostedGlassMode]:
/// - **liquidGlass**: [HyperosLiquidGlassSurface] with the shared modal role.
/// - **frosted / gaussian**: [BackdropFilter] blur + tint scrim.
/// - **translucent**: lighter blur + minimal tint.
/// - **blur disabled**: solid [HyperosColors.surfaceContainer].
class HyperosSelectPopupGlass extends StatelessWidget {
  const HyperosSelectPopupGlass({
    super.key,
    required this.cornerRadius,
    required this.child,
    this.useAncestorGroupCapture = false,
    this.thicknessFactor,
  });

  final double cornerRadius;
  final Widget child;

  /// 折射厚度缩放（0..1）：液态面按完整厚度的该比例渲染。二级子卡揭示
  /// 期间传揭示进度——厚度从近零生长到满值，顶缘折射对上方面板文字的
  /// 镜像随揭示减弱直至压暗接管，消除「字体反射」闪动。null/1 = 完整
  /// 厚度。
  final double? thicknessFactor;

  /// 浮在同一块玻璃面之上的弹层（如列表弹窗的二级子卡）置 true。
  ///
  /// 液态玻璃面按绘制顺序采样它下面的合成结果——二级子卡排在主面板
  /// 之后，直接采样就会包含主面板玻璃的输出，玻璃叠玻璃再折射一遍，
  /// 读感浑浊。置真后先铺一层**共享组捕获的磨砂底**（弹窗遮罩下的页面，
  /// 与主面板玻璃同源、由合成器逐帧刷新）把下方玻璃挡在外面，液态玻璃
  /// 再贴着这层底折射。
  ///
  /// 历史教训：这里一度垫的是宿主页面的**整页同步快照**（ui.Image），
  /// 结果展开时是一张静态照片跟着卡片走（用户口径：「就好携带一个有
  /// 背景的卡片出来了，而不是玻璃出来了」）。premium 档改为实时读底面
  /// 后，垫底必须是 live 的合成器捕获，不能再垫任何快照。
  final bool useAncestorGroupCapture;

  /// 当前外观下弹窗是否走柔光玻璃面（Hyper-PiliPlus SoftGlass 风格）。
  ///
  /// 与 [liquidSurfaceActive] 同口径：柔光与液态同为高级材质，受**同一组**
  /// 「作用范围」开关约束。关闭时落入 [solidSurfaceActive]的实底分支
  /// （不降级为高斯）。此前该判定只看全局档位，全局柔光时
  /// 六个作用范围开关全部失效（历史 bug）。
  static bool softSurfaceActive(BuildContext context) {
    final appearance = FrostedAppearanceScope.of(context);
    return appearance.glassMode == FrostedGlassMode.softGlass &&
        appearance.liquidGlassPopupEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
  }

  /// 当前外观下弹窗是否走液态玻璃面（与 [build] 分支同一口径，供调用方
  /// 判断是否需要准备共享组捕获垫层）。
  static bool liquidSurfaceActive(BuildContext context) {
    final appearance = FrostedAppearanceScope.of(context);
    return appearance.glassMode == FrostedGlassMode.liquidGlass &&
        appearance.liquidGlassPopupEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
  }

  /// 当前外观下弹窗是否走不透明实底面（[HyperosSolidPopupSurface]）。
  ///
  /// 判定与 [build] 的材质分支同序：调用方强制实底（WebView 场景）→
  /// 实底；液态玻璃激活 → 液态面（自带模糊，不受 blur 总开关约束）；
  /// 否则 blur 总开关关闭、系统降级、或「液态玻璃作用范围」关闭本家族
  /// → 实底。调用方（如列表弹窗的墨色选择）据此把「为透明玻璃准备的
  /// 壁纸感知墨色」重置为主题墨——实底不再透出壁纸，浅色实底上的白墨
  /// 不可读。
  static bool solidSurfaceActive(
    BuildContext context, {
    bool opaqueSurface = false,
  }) {
    if (opaqueSurface) {
      return true;
    }
    if (liquidSurfaceActive(context) || softSurfaceActive(context)) {
      return false;
    }
    if (LiquidGlassDegradation.familyFallsBackToSolid(
      context,
      advancedFamilyEnabled:
          FrostedAppearanceScope.of(context).liquidGlassPopupEnabled,
    )) {
      return true;
    }
    return !HyperosBlurredHeader.backdropBlurEnabled(context);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(cornerRadius);
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final appearance = FrostedAppearanceScope.of(context);

    // Soft glass (global): milky frost panel for anchored popups.
    if (softSurfaceActive(context)) {
      return HyperosFrostedPanelScope(
        child: SoftGlassSurface(
          borderRadius: borderRadius,
          blurEnabled: useBlur,
          // 不传 recipe：全 app 柔光玻璃共用 [SoftGlassSurface] 的唯一配方
          // （顶栏 / 底栏 / 弹窗 / 面板同参）。曾经这里单独挂 dialog 配方、
          // 顶栏挂 floatingNavigation 配方——同一个材质两种雾度，用户口径
          // 「是柔光玻璃就全部显示一样」。
          enableShadows: false,
          child: child,
        ),
      );
    }

    // Liquid glass owns its own blur/refraction and must not be gated by the
    // platform BackdropFilter capability. Otherwise anchored popups become
    // solid surfaces on desktop while sheets and headers keep their glass.
    // 「液态玻璃作用范围 → 下拉选择弹窗」关闭时回退磨砂/实底材质。
    final useLiquidGlass = liquidSurfaceActive(context);

    if (useLiquidGlass) {
      // 与顶栏带 / 玻璃坞 / 卡片完全同一个组件、同一个档位常量
      // （[MikcbLiquidGlassTokens.defaultQuality]）。任何表面都不得再传自己的
      // 档位或捕获源——那正是「同一个材质几种观感」的成因。
      final surface = HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.modal,
        borderRadius: cornerRadius,
        thicknessFactor: thicknessFactor,
        child: child,
      );
      if (!useAncestorGroupCapture) {
        return surface;
      }
      // 磨砂底：共享组捕获（遮罩下的页面，合成器逐帧刷新）+ 常规磨砂
      // 参数，把主面板玻璃的输出挡在液态玻璃的采样输入之外。ClipRRect
      // 只圆底垫的角；液态玻璃面保持不裁，浅色模式的外阴影才能画到卡外。
      final sigma = HyperosBlurredHeader.blurSigmaOf(context);
      final tint = HyperosBlurredHeader.sheetTintColor(context, withBlur: true);
      return Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter.grouped(
                filter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.clamp,
                ),
                child: ColoredBox(color: tint),
              ),
            ),
          ),
          surface,
        ],
      );
    }

    // Blur disabled, 或「液态玻璃作用范围 → 下拉选择弹窗」关闭
    // → solid opaque surface.
    //
    // 家族关闭时不再降级为磨砂：磨砂走实时 BackdropFilter，入场动画
    // （弹簧缩放 + 揭示裁切）期间采不到稳定背景，面板会整段渲染为透明，
    // 动画结束才「啪」地出现——读起来就是弹窗没有动画。实体卡片不依赖
    // 背景采样，动画全程正常。
    if (!useBlur ||
        LiquidGlassDegradation.familyFallsBackToSolid(
          context,
          advancedFamilyEnabled: appearance.liquidGlassPopupEnabled,
        )) {
      return HyperosSolidPopupSurface(cornerRadius: cornerRadius, child: child);
    }

    // Frosted / gaussian / translucent: use the same sigma and tint as every
    // HyperosSheetFrame. The selected glass mode changes the shared modal
    // material, not the visual identity of one popup versus another.
    final sigma = HyperosBlurredHeader.blurSigmaOf(context);
    final tint = HyperosBlurredHeader.sheetTintColor(context, withBlur: true);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            // Grouped: samples the ancestor BackdropGroup's capture (undimmed
            // page), so the sibling modal scrim stays out of the blur input.
            child: BackdropFilter.grouped(
              filter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.clamp,
              ),
              child: ColoredBox(color: tint),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Solid opaque popup surface — the shared fallback when backdrop blur is
/// unavailable or unsafe. Over an Android platform view (WebView) the
/// BackdropFilter / liquid-glass capture reads the platform view as black,
/// so popups anchored above one must use this instead of sampled glass.
class HyperosSolidPopupSurface extends StatelessWidget {
  const HyperosSolidPopupSurface({
    super.key,
    required this.cornerRadius,
    required this.child,
  });

  final double cornerRadius;
  final Widget child;

  static const _kPopupShadow = [
    BoxShadow(color: Color(0x24000000), blurRadius: 20),
  ];

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(cornerRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HyperosColors.surfaceContainer(context),
        borderRadius: borderRadius,
        boxShadow: _kPopupShadow,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}

/// 选择弹窗（**常驻挂载 + 切 `show`**，上游 OS4 弹层的契约）。
///
/// 上游源码注释写明了这条契约：
/// > 保持组件挂载并切换 show，让退出动画完成后自动清除弹层和返回记录。
///
/// 所以它**不能**塞进 `showGeneralDialog` 路由里用（上一版这么做，导致
/// 弹层内部关闭记账与路由栈错位：点条目会 pop 掉宿主页、点空白也关不掉）。
/// 正确形态与 [HomeTopMenuPopup] 一致：宿主页持有 `show`，弹层常驻在自己的
/// 页面树里，位置由 [anchorRect] 给出，结果只经 [onSelected] 回调回落 ——
/// 弹层**不自己 pop 任何路由**。
///
/// 玻璃需要宿主页提供采样源：优先取所在页面 [HyperosGlassBackdropScope]
/// 下发的页级 backdrop（`_HyperosBlurredPage` 已自动挂好，弹层展开期间才录帧），
/// 页面级宿主之外的调用点再退回全局 [os4GlassBackdrop]；都没有时上游降级为
/// 材质底色 + 轮廓，不会报错。上游要求捕获子树不含玻璃自身，因此弹层必须留在
/// 捕获**之外** —— 弹层经 OverlayPortal 画到 rootOverlay，天然满足。
class HyperosSelectPopup<T> extends StatelessWidget {
  const HyperosSelectPopup({
    super.key,
    required this.show,
    required this.anchorRect,
    required this.items,
    required this.currentValue,
    required this.onSelected,
    required this.onDismiss,
    this.itemPrefixBuilder,
    this.backdrop,
  });

  /// 是否展开。
  final bool show;

  /// 锚定矩形（按下触发控件时用 `hyperosSelectPopupAnchorRect` 取）。
  final Rect anchorRect;

  final Map<String, T> items;
  final T? currentValue;

  /// 选中回调：宿主在此应用结果并自行把 [show] 置回 false。
  final ValueChanged<T> onSelected;

  /// 点空白 / 系统返回等关闭请求：宿主把 [show] 置回 false。
  final VoidCallback onDismiss;

  final Widget? Function(T value)? itemPrefixBuilder;

  /// 采样源覆盖（默认按所在页面自动解析，见类文档）。
  final MiuixLayerBackdrop? backdrop;

  @override
  Widget build(BuildContext context) {
    return MiuixGlassDropdownPopup(
      show: show,
      anchorBounds: anchorRect,
      backdrop:
          backdrop ??
          HyperosGlassBackdropScope.maybeOf(context)?.backdrop ??
          os4GlassBackdrop,
      sizing: _os4SelectSizing,
      onDismissRequest: onDismiss,
      // 上游 `MiuixGlassPopupItem` 的 Row 是 `mainAxisSize.max`，会直接撑满
      // `sizing.maxWidth`：只给 min/max 而不夹内容，弹层宽度恒等于 maxWidth
      // （短标签的「卡片外观」也会变成 372 宽）。这里用 [IntrinsicWidth] 把内容
      // 夹到「最宽一条的自然宽度」，再由 sizing 收敛到 [200, 372] —— 与旧实现
      // （`ConstrainedBox(minWidth: 132 + popupExtraLeadingWidth)` + 内容自适应）
      // 同宽度。
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in items.entries)
              MiuixGlassPopupItem(
                text: entry.key,
                selected: entry.value == currentValue,
                icon: itemPrefixBuilder?.call(entry.value),
                onPressed: () => onSelected(entry.value),
              ),
          ],
        ),
      ),
    );
  }
}

/// 选择弹层的尺寸约束：复刻旧实现那套公式（`HyperosMiuixDropdown`）。
///
/// 选择器标签比首页菜单长（"按添加时间排序"这类），所以上限保留旧公式的 372；
/// 上游布局会再用屏幕边界做一次 `min` 收敛
///（`popup_layout.dart`：`maxWidth = min(sizing.maxWidth, bounds.width)`），
/// 因此这里不必自己夹屏幕宽。下界不写：上游默认 `minWidth = 200`，与旧公式
/// `132 + popupExtraLeadingWidth` 恰好相同。
const _os4SelectSizing = MiuixGlassPopupSizing(
  maxWidth:
      HyperosMiuixDropdown.maxItemTextWidth +
      HyperosMiuixDropdown.popupExtraLeadingWidth +
      HyperosMiuixDropdown.insideHorizontalPadding * 2 +
      HyperosMiuixDropdown.checkIconSize +
      28,
);

/// Opens a HyperOS dialog-style bottom sheet for longer single-choice lists.
Future<T?> showHyperosSelectSheet<T>({
  required BuildContext context,
  required String title,
  required Map<String, T> items,
  required T? currentValue,
  String? description,
  required String cancelLabel,
  TextStyle? Function(T value)? itemTitleStyleBuilder,
  Widget? Function(T value)? itemPrefixBuilder,
}) {
  final entries = items.entries.toList(growable: false);
  final resolvedCancelLabel = cancelLabel;

  return showHyperosSheet<T>(
    context: context,
    builder: (sheetContext) {
      final maxListHeight = MediaQuery.sizeOf(sheetContext).height * 0.55;

      return HyperosSheetFrame(
        chrome: HyperosSheetChrome.floating,
        // 对话式选择面板走「液态玻璃作用范围 → 全屏选择面板」开关
        //（默认关）：预设主题/字体等长列表弹窗默认保持磨砂材质。
        liquidGlassGroup: HyperosSheetLiquidGlassGroup.selectSheet,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: HyperosTypography.sheetTitle(sheetContext),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.start,
                    style: HyperosTypography.sectionDescription(sheetContext),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: _AutoScrollChoiceList<T>(
                entries: entries,
                currentValue: currentValue,
                itemTitleStyleBuilder: itemTitleStyleBuilder,
                itemPrefixBuilder: itemPrefixBuilder,
                onSelected: (value) => Navigator.of(sheetContext).pop(value),
              ),
            ),
            const SizedBox(height: 12),
            HyperosButton(
              label: resolvedCancelLabel,
              expand: true,
              variant: HyperosButtonVariant.secondary,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      );
    },
  );
}

/// Scrollable choice list that auto-scrolls to the currently selected item
/// when first built. Used by both the anchored popup and the bottom sheet.
class _AutoScrollChoiceList<T> extends StatefulWidget {
  const _AutoScrollChoiceList({
    required this.entries,
    required this.currentValue,
    required this.onSelected,
    this.itemTitleStyleBuilder,
    this.itemPrefixBuilder,
    this.variant = HyperosChoiceVariant.dialog,
  });

  final List<MapEntry<String, T>> entries;
  final T? currentValue;
  final ValueChanged<T> onSelected;
  final TextStyle? Function(T value)? itemTitleStyleBuilder;
  final Widget? Function(T value)? itemPrefixBuilder;
  final HyperosChoiceVariant variant;

  @override
  State<_AutoScrollChoiceList<T>> createState() =>
      _AutoScrollChoiceListState<T>();
}

class _AutoScrollChoiceListState<T> extends State<_AutoScrollChoiceList<T>> {
  final _scrollController = ScrollController();
  final _itemKeys = <int, GlobalKey>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    for (var i = 0; i < widget.entries.length; i++) {
      if (widget.entries[i].value != widget.currentValue) continue;
      final key = _itemKeys[i];
      final context = key?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.entries.length; i++) ...[
            Builder(
              builder: (_) {
                _itemKeys[i] = GlobalKey();
                return KeyedSubtree(
                  key: _itemKeys[i],
                  child: HyperosChoiceTile(
                    title: widget.entries[i].key,
                    selected: widget.entries[i].value == widget.currentValue,
                    highlightSelectedText: true,
                    variant: widget.variant,
                    titleStyle: widget.itemTitleStyleBuilder?.call(
                      widget.entries[i].value,
                    ),
                    prefix: widget.itemPrefixBuilder?.call(
                      widget.entries[i].value,
                    ),
                    onTap: () => widget.onSelected(widget.entries[i].value),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

String? hyperosSelectLabelFor<T>(Map<String, T> items, T? value) {
  if (value == null) {
    return null;
  }
  for (final entry in items.entries) {
    if (entry.value == value) {
      return entry.key;
    }
  }
  return null;
}

double hyperosSelectPopupEstimatedHeight(int itemCount) {
  if (itemCount <= 0) {
    return 0;
  }
  var height = 0.0;
  for (var i = 0; i < itemCount; i++) {
    // Match [_popupChoiceRowPadding] / content-sized HyperosChoiceTile popup
    // rows (v2.0.4): first row top and last row bottom use firstLast; all other
    // edges use middle. Content height is the list-title line box
    // (preferenceTitleSize × 1.25), not settings-row min height.
    final topPadding = i == 0
        ? HyperosMiuixDropdown.firstLastVerticalPadding
        : HyperosMiuixDropdown.middleVerticalPadding;
    final bottomPadding = i == itemCount - 1
        ? HyperosMiuixDropdown.firstLastVerticalPadding
        : HyperosMiuixDropdown.middleVerticalPadding;
    height +=
        topPadding +
        bottomPadding +
        HyperosMiuixSpec.preferenceTitleSize * 1.25;
  }
  return height;
}

({double top, double maxHeight}) hyperosSelectPopupLayout({
  required Rect anchorRect,
  required double estimatedPopupHeight,
  required double screenHeight,
  required double safeTop,
  required double safeBottom,
  double verticalGap = HyperosMiuixDropdown.popupVerticalGap,
}) {
  final belowTop = anchorRect.bottom + verticalGap;
  final aboveTop = anchorRect.top - verticalGap - estimatedPopupHeight;
  final spaceBelow = safeBottom - belowTop;
  final spaceAbove = anchorRect.top - verticalGap - safeTop;

  double top;
  if (spaceBelow >= estimatedPopupHeight || spaceBelow >= spaceAbove) {
    top = belowTop;
  } else if (spaceAbove >= estimatedPopupHeight) {
    top = aboveTop;
  } else if (spaceAbove > spaceBelow) {
    top = safeTop;
  } else {
    top = belowTop;
  }

  top = top.clamp(safeTop, safeBottom);
  // Never claim more height than the space actually available — forcing a
  // minimum here would push the popup past the safe area on tiny leftovers.
  final available = (safeBottom - top).clamp(0.0, double.infinity);
  final maxHeight = available < estimatedPopupHeight
      ? available
      : estimatedPopupHeight;

  return (top: top, maxHeight: maxHeight);
}

/// Pressable select row: label + current value + up/down arrow.
class HyperosSelectTile<T> extends StatefulWidget {
  const HyperosSelectTile({
    super.key,
    required this.label,
    this.subtitle,
    required this.items,
    required this.value,
    required this.onChanged,
    this.sheetTitle,
    this.sheetDescription,
    this.useSheetForPopup = false,
    this.sheetItemThreshold = 6,
    this.enabled = true,
    this.itemTitleStyleBuilder,
    this.itemPrefixBuilder,
  });

  final String label;
  final String? subtitle;
  final Map<String, T> items;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? sheetTitle;
  final String? sheetDescription;

  /// When true, always use dialog-style bottom sheet instead of anchored popup.
  final bool useSheetForPopup;

  /// Item count above which the bottom sheet is preferred over anchored popup.
  final int sheetItemThreshold;
  final bool enabled;

  /// Per-option title style override. Lets callers render each option in its
  /// own font (e.g. the font picker previews the actual typeface per entry).
  final TextStyle? Function(T value)? itemTitleStyleBuilder;
  final Widget? Function(T value)? itemPrefixBuilder;

  @override
  State<HyperosSelectTile<T>> createState() => _HyperosSelectTileState<T>();
}

class _HyperosSelectTileState<T> extends State<HyperosSelectTile<T>> {
  final _anchorKey = GlobalKey();
  bool _menuOpen = false;

  /// OS4 玻璃弹层：**常驻挂载 + 切 `show`**（上游契约），锚点矩形在展开时定格。
  bool _os4Open = false;
  Rect? _os4AnchorRect;

  /// 已 acquire 的页级采样源宿主。弹层展开期间持有；手指按下即预热，抬手后
  /// 若并未展开则立刻归还，避免页级捕获空转。
  HyperosGlassBackdropScope? _heldCapture;

  /// 本行是否走 OS4 玻璃弹层。三类调用点继续走旧弹层：
  /// - 选项多到要用底部 sheet（`showHyperosSelectSheet`）；
  /// - 逐项自定义字号（字体预览）—— 上游 `MiuixGlassPopupItem` 不支持覆盖文字样式；
  /// - 所在页面没有页级采样源宿主（如单测里的裸 `HyperosSelectTile`）。
  HyperosGlassBackdropScope? _os4ScopeFor(BuildContext context) {
    if (widget.useSheetForPopup ||
        widget.items.length > widget.sheetItemThreshold ||
        widget.itemTitleStyleBuilder != null) {
      return null;
    }
    return HyperosGlassBackdropScope.maybeOf(context);
  }

  void _holdCapture(HyperosGlassBackdropScope scope) {
    if (identical(_heldCapture, scope)) return;
    _heldCapture?.release();
    _heldCapture = scope;
    scope.acquire();
  }

  void _dropCapture() {
    _heldCapture?.release();
    _heldCapture = null;
  }

  /// 手指按下就开启页级捕获：图层快照在帧末录制，早一拍预热可保证弹层首帧
  /// 已经采得到背景（否则展开的第一帧只有材质底色）。
  void _prewarmCapture(BuildContext context) {
    if (_menuOpen || !widget.enabled || widget.onChanged == null) return;
    final scope = _os4ScopeFor(context);
    if (scope != null) {
      _holdCapture(scope);
    }
  }

  /// 抬手/取消：没真展开就归还预热。
  void _settleCapture() {
    if (!_os4Open) {
      _dropCapture();
    }
  }

  void _closeOs4() {
    if (!_os4Open) return;
    setState(() {
      _os4Open = false;
      _menuOpen = false;
    });
    _dropCapture();
  }

  void _onOs4Selected(T value) {
    final changed = value != widget.value;
    _closeOs4();
    if (changed) {
      widget.onChanged?.call(value);
    }
  }

  @override
  void dispose() {
    _dropCapture();
    super.dispose();
  }

  Future<void> _openSelector(BuildContext context) async {
    if (_menuOpen || !widget.enabled || widget.onChanged == null) {
      return;
    }

    final anchorRect = hyperosSelectPopupAnchorRect(context, _anchorKey);
    final useSheet =
        widget.useSheetForPopup ||
        widget.items.length > widget.sheetItemThreshold ||
        anchorRect == null;
    final os4Scope = useSheet ? null : _os4ScopeFor(context);

    if (os4Scope != null) {
      _holdCapture(os4Scope);
      setState(() {
        _menuOpen = true;
        _os4Open = true;
        _os4AnchorRect = anchorRect;
      });
      return;
    }

    _dropCapture();
    setState(() => _menuOpen = true);

    T? selected;
    try {
      if (useSheet) {
        selected = await showHyperosSelectSheet<T>(
          context: context,
          title: widget.sheetTitle ?? widget.label,
          description: widget.sheetDescription,
          items: widget.items,
          currentValue: widget.value,
          cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
          itemTitleStyleBuilder: widget.itemTitleStyleBuilder,
          itemPrefixBuilder: widget.itemPrefixBuilder,
        );
      } else {
        selected = await showHyperosSelectPopup<T>(
          context: context,
          anchorRect: anchorRect,
          items: widget.items,
          currentValue: widget.value,
          itemTitleStyleBuilder: widget.itemTitleStyleBuilder,
          itemPrefixBuilder: widget.itemPrefixBuilder,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _menuOpen = false);
      }
    }

    if (!mounted || selected == null || selected == widget.value) {
      return;
    }
    widget.onChanged!(selected);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = widget.enabled && widget.onChanged != null;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final primaryText = HyperosColors.primaryText(context);
    final valueLabel = hyperosSelectLabelFor(widget.items, widget.value);
    final valueColor = effectiveEnabled
        ? HyperosColors.onSurfaceVariantActions(context)
        : HyperosColors.disabledOnSurface(context);
    final secondaryText = HyperosColors.secondaryText(context);
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: effectiveEnabled
          ? secondaryText
          : secondaryText.withValues(alpha: 0.45),
    );

    final rowLayout = hyperosSelectRowLayout(
      context,
      twoLine: widget.subtitle != null,
    );

    Widget row = hyperosListRowShell(
      key: _anchorKey,
      padding: rowLayout.padding,
      minHeight: rowLayout.minHeight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: HyperosTypography.listTitle(context).copyWith(
                    color: effectiveEnabled
                        ? primaryText
                        : primaryText.withValues(alpha: 0.45),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: HyperosTokens.titleCaptionGap),
                  Text(widget.subtitle!, style: subtitleStyle, softWrap: true),
                ],
              ],
            ),
          ),
          if (valueLabel != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                right: HyperosMiuixDropdown.valueEndPadding,
              ),
              child: Text(
                valueLabel,
                style: HyperosTypography.listDetail(context).copyWith(
                  fontSize: HyperosMiuixTypography.body2,
                  color: valueColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.end,
              ),
            ),
          ],
          Opacity(
            opacity: effectiveEnabled ? 1 : 0.45,
            child: const HyperosUpDownChevron(),
          ),
        ],
      ),
    );

    if (rowLayout.bodyBottomBleed > 0) {
      row = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row,
          SizedBox(height: rowLayout.bodyBottomBleed),
        ],
      );
    }

    final pressable = HyperosPressableRow(
      onTap: effectiveEnabled ? () => _openSelector(context) : null,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      forceHighlighted: _menuOpen,
      child: row,
    );

    final os4Scope = _os4ScopeFor(context);
    if (os4Scope == null) {
      // 没有页级采样源（或本行本就走 sheet / 需要逐项字号）：保持原样，连弹层
      // 都不挂载。
      return pressable;
    }

    // OS4 弹层经 OverlayPortal 画到 rootOverlay，自身零尺寸，所以与行同层放
    // Stack 不会改变行本身的布局（Stack 只把约束放松给非定位子节点，行内部
    // 的 Row 仍按 mainAxisSize.max 撑满）。
    return Stack(
      children: [
        Listener(
          onPointerDown: (_) => _prewarmCapture(context),
          onPointerUp: (_) => _settleCapture(),
          onPointerCancel: (_) => _settleCapture(),
          child: pressable,
        ),
        HyperosSelectPopup<T>(
          show: _os4Open,
          anchorRect: _os4AnchorRect ?? Rect.zero,
          items: widget.items,
          currentValue: widget.value,
          onSelected: _onOs4Selected,
          onDismiss: _closeOs4,
          itemPrefixBuilder: widget.itemPrefixBuilder,
        ),
      ],
    );
  }
}

/// Date picker row — label + formatted date + chevron (Miuix date preference pattern).
class HyperosDateTile extends StatelessWidget {
  const HyperosDateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.formatter,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;
  final String Function(DateTime date)? formatter;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  String _format(DateTime date) {
    if (formatter != null) return formatter!(date);
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate(BuildContext context) async {
    if (!enabled || onChanged == null) return;

    final initial = value ?? DateTime.now();
    final picked = await showMiuixDatePickerSheet(
      context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(1970),
      lastDate: lastDate ?? DateTime(2100),
      title: label,
    );
    if (picked != null) {
      onChanged!(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HyperosNavTile(
      title: label,
      details: value != null ? _format(value!) : null,
      enabled: enabled && onChanged != null,
      holdHighlightThroughTransition: false,
      onTap: () => _pickDate(context),
    );
  }
}
