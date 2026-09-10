import 'package:flutter/material.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'frosted/liquid_glass_degradation.dart';
import 'hyperos_widgets.dart';
import 'liquid/hyperos_liquid_glass_surface.dart';

/// Extra height painted below an edge-flush glass sheet's bottom edge so the
/// liquid-glass specular fringe along the straight bottom side lands outside
/// the panel's clip and is cut — otherwise that fringe shows as a 1px
/// hairline seam where the panel meets the screen bottom (same failure as the
/// top edge, see `homePageChromeGlassTopEdgeOverdraw`).
const hyperosEdgeSheetBottomOverdraw = 4.0;

/// Marks descendants as sitting on a frosted (blur + milky tint) panel.
///
/// Used by [HyperosButton] secondary fill so cancel / neutral actions stay
/// readable against glass instead of blending into white-on-white.
class HyperosFrostedPanelScope extends InheritedWidget {
  const HyperosFrostedPanelScope({required super.child, super.key});

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<HyperosFrostedPanelScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(covariant HyperosFrostedPanelScope oldWidget) {
    return false;
  }
}

/// Visual chrome for [HyperosSheetFrame] / [HyperosSheet].
enum HyperosSheetChrome {
  /// Floating card: left/right/bottom outer gap + full rounded corners.
  /// Matches [HyperosDialog] (settings / form sheets).
  floating,

  /// Edge-flush panel: full width, top corners only, sits on screen bottom.
  /// Preferred for home timetable menus and action sheets.
  edge,
}

/// 本框的液态玻璃材质受「液态玻璃作用范围」哪一档开关控制。
enum HyperosSheetLiquidGlassGroup {
  /// 底部弹窗与对话框（showHyperosSheet / HyperosDialog 系，默认开）。
  sheetDialog,

  /// 对话式全屏选择面板——预设主题、字体等长列表选择弹窗（默认关：
  /// 大面积折射在长列表上偏炫且更费电，默认保持经典磨砂）。
  selectSheet,
}

/// Provides default [HyperosSheetChrome] for nested [HyperosSheetFrame]s.
class HyperosSheetChromeScope extends InheritedWidget {
  const HyperosSheetChromeScope({
    required this.chrome,
    required super.child,
    super.key,
  });

  final HyperosSheetChrome chrome;

  static HyperosSheetChrome? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosSheetChromeScope>()
        ?.chrome;
  }

  static HyperosSheetChrome of(BuildContext context) {
    return maybeOf(context) ?? HyperosSheetChrome.floating;
  }

  @override
  bool updateShouldNotify(covariant HyperosSheetChromeScope oldWidget) {
    return chrome != oldWidget.chrome;
  }
}

/// HyperOS bottom sheet panel shell.
///
/// Defaults to the shared modal glass material using the same tuning as the
/// top chrome. Defaults to [HyperosSheetChrome.floating] unless an ancestor
/// [HyperosSheetChromeScope] or [chrome] overrides it.
class HyperosSheetFrame extends StatelessWidget {
  const HyperosSheetFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.maxHeight,
    this.frosted = true,
    this.chrome,
    this.liquidGlassRole = HyperosLiquidGlassRole.modal,
    this.liquidGlassContentLegibilityFill = false,
    this.liquidGlassGroup = HyperosSheetLiquidGlassGroup.sheetDialog,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxHeight;

  /// When true (default), milky frosted glass + live blur when enabled in
  /// settings. Sigma / tint / master switch come from [FrostedAppearanceScope].
  final bool frosted;

  /// When null, uses [HyperosSheetChromeScope] or [HyperosSheetChrome.floating].
  final HyperosSheetChrome? chrome;

  /// Material role used when [frosted] resolves to liquid glass.
  ///
  /// All modal shells default to [HyperosLiquidGlassRole.modal] so dialogs,
  /// action sheets, and pickers share one clear material. Override this only
  /// for a deliberately different embedded surface.
  final HyperosLiquidGlassRole liquidGlassRole;

  /// Whether liquid-glass content receives the extra opaque legibility fill.
  ///
  /// Defaults to false so every sheet/dialog uses the same clear material as
  /// the home chrome band (9de96b8 / A 方案通透统一). Set true explicitly
  /// only for a deliberately milky panel.
  final bool liquidGlassContentLegibilityFill;

  /// 「液态玻璃作用范围」开关档位：本框液态材质跟随弹窗对话框（默认）
  /// 还是对话式全屏选择面板（预设主题等长列表选择弹窗）。
  final HyperosSheetLiquidGlassGroup liquidGlassGroup;

  /// 本框当前是否允许使用液态玻璃材质（全局模式 × 家族开关）。
  bool _liquidGlassAllowed(FrostedAppearance appearance) =>
      switch (liquidGlassGroup) {
        HyperosSheetLiquidGlassGroup.sheetDialog =>
          appearance.liquidGlassSheetDialogEnabled,
        HyperosSheetLiquidGlassGroup.selectSheet =>
          appearance.liquidGlassSelectSheetEnabled,
      };

  @override
  Widget build(BuildContext context) {
    final resolvedChrome = chrome ?? HyperosSheetChromeScope.of(context);
    final panel = switch (resolvedChrome) {
      HyperosSheetChrome.floating => _buildFloatingPanel(context),
      HyperosSheetChrome.edge => _buildEdgePanel(context),
    };

    if (maxHeight == null) {
      return panel;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: panel,
    );
  }

  Widget _buildFloatingPanel(BuildContext context) {
    const outerInset = HyperosMiuixDialog.outsideMarginHorizontal;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final borderRadius = BorderRadius.circular(HyperosTokens.cardRadius);
    final content = Padding(padding: padding, child: child);

    final panel = frosted
        ? _buildFrostedSurface(
            context: context,
            borderRadius: borderRadius,
            content: content,
          )
        : Material(
            color: HyperosColors.surfaceContainer(context),
            shape: HyperosTheme.cardShape(),
            clipBehavior: Clip.antiAlias,
            child: content,
          );

    // BoxShadow creates a dark ring around the panel — visible on all sides,
    // moves with the panel (no tracking), and matches the panel's rounded
    // corners naturally.  The shadow sits BEHIND the frosted glass, so
    // BackdropFilter inside the glass samples the bright page content, not
    // the shadow.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        outerInset,
        0,
        outerInset,
        outerInset + bottomSafeInset,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              // 与 anchored popup 气泡同级：轻投影，不再形成明显暗环。
              color: Color(0x24000000),
              blurRadius: 20,
            ),
          ],
        ),
        child: panel,
      ),
    );
  }

  Widget _buildEdgePanel(BuildContext context) {
    const borderRadius = BorderRadius.vertical(
      top: Radius.circular(HyperosTokens.cardRadius),
    );
    final content = SafeArea(
      top: false,
      child: Padding(padding: padding, child: child),
    );

    if (frosted) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: double.infinity,
          child: HyperosFrostedPanelScope(
            child: Stack(
              children: [
                // Paint the glass a few pixels below the visible panel so the
                // liquid-glass specular fringe on its straight bottom edge
                // lands outside the ClipRRect and is clipped — otherwise it
                // shows as a 1px hairline seam where the edge sheet meets the
                // screen bottom (see hyperosEdgeSheetBottomOverdraw).
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: -hyperosEdgeSheetBottomOverdraw,
                  child: _buildFrostedBackground(
                    context: context,
                    borderRadius: borderRadius,
                  ),
                ),
                // The real content is the non-positioned sizing child: a
                // Stack containing only Positioned children sizes itself to
                // constraints.biggest, which used to blow the edge sheet up
                // to full screen with the content pinned to the top and blank
                // glass below.
                content,
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: HyperosColors.scaffoldBackground(context),
        borderRadius: borderRadius,
      ),
      child: content,
    );
  }

  /// Glass / tint / solid background layer for a frosted panel.
  ///
  /// Painted separately from the content so callers can overdraw the glass
  /// past the panel's clip edge (see [_buildEdgePanel]) while the layout
  /// stays driven by the real content.
  Widget _buildFrostedBackground({
    required BuildContext context,
    required BorderRadius borderRadius,
  }) {
    final appearance = FrostedAppearanceScope.of(context);

    // Liquid glass mode: real-time refraction shader panel. Checked before
    // the gaussian blur gate because liquid glass carries its own blur —
    // gating it on backdropBlurEnabled (liveBlurSupported && blurEnabled)
    // would make the frame a solid gray slab on desktop/web while the nested
    // tiles keep rendering liquid glass.
    // 「液态玻璃作用范围」对应家族开关关闭时，整框回退磨砂/实底材质。
    if (appearance.glassMode == FrostedGlassMode.liquidGlass &&
        _liquidGlassAllowed(appearance) &&
        !LiquidGlassDegradation.shouldDegrade(context)) {
      return HyperosLiquidGlassSurface(
        role: liquidGlassRole,
        borderRadius: borderRadius.topLeft.x,
        instantUnderlay: true,
        useAncestorBackdropGroup: true,
        contentLegibilityFill: liquidGlassContentLegibilityFill,
        child: const SizedBox.expand(),
      );
    }

    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);

    // Blur off → solid opaque panel (no translucent scrim over the page).
    if (!useBlur) {
      return Material(
        color: HyperosColors.surfaceContainer(context),
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: const SizedBox.expand(),
      );
    }

    // Frosted / gaussian / translucent: BackdropFilter + tint.
    final tint = HyperosBlurredHeader.sheetTintColor(context, withBlur: true);

    return ClipRRect(
      borderRadius: borderRadius,
      child: FrostedHeaderBackground(
        blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
        tint: tint,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildFrostedSurface({
    required BuildContext context,
    required BorderRadius borderRadius,
    required Widget content,
  }) {
    final appearance = FrostedAppearanceScope.of(context);

    // Liquid glass mode: real-time refraction shader panel. Checked before
    // the gaussian blur gate because liquid glass carries its own blur —
    // gating it on backdropBlurEnabled (liveBlurSupported && blurEnabled)
    // would make the frame a solid gray slab on desktop/web while nested
    // tiles keep rendering liquid glass.
    // 「液态玻璃作用范围」对应家族开关关闭时，整框回退磨砂/实底材质。
    if (appearance.glassMode == FrostedGlassMode.liquidGlass &&
        _liquidGlassAllowed(appearance) &&
        !LiquidGlassDegradation.shouldDegrade(context)) {
      return HyperosFrostedPanelScope(
        child: HyperosLiquidGlassSurface(
          role: liquidGlassRole,
          borderRadius: borderRadius.topLeft.x,
          instantUnderlay: true,
          useAncestorBackdropGroup: true,
          contentLegibilityFill: liquidGlassContentLegibilityFill,
          child: content,
        ),
      );
    }

    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);

    // Blur off → solid opaque panel (no translucent scrim over the page).
    if (!useBlur) {
      return HyperosFrostedPanelScope(
        child: Material(
          color: HyperosColors.surfaceContainer(context),
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      );
    }

    // Frosted / gaussian / translucent: BackdropFilter + tint.
    final tint = HyperosBlurredHeader.sheetTintColor(context, withBlur: true);

    return HyperosFrostedPanelScope(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: FrostedHeaderBackground(
          blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
          tint: tint,
          child: content,
        ),
      ),
    );
  }
}

/// Bottom sheet body with optional title (uses [HyperosSheetFrame] chrome).
class HyperosSheet extends StatelessWidget {
  const HyperosSheet({
    super.key,
    this.title,
    required this.child,
    this.description,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.frosted = true,
    this.chrome,
  });

  final String? title;
  final Widget child;
  final String? description;
  final EdgeInsetsGeometry padding;
  final bool frosted;
  final HyperosSheetChrome? chrome;

  @override
  Widget build(BuildContext context) {
    return HyperosSheetFrame(
      frosted: frosted,
      padding: padding,
      chrome: chrome,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: HyperosTypography.sheetTitle(context)),
            const SizedBox(height: 16),
          ],
          child,
          if (description != null) ...[
            const SizedBox(height: 12),
            HyperosSectionDescription(text: description!),
          ],
        ],
      ),
    );
  }
}

/// Bottom velocity threshold to dismiss (pixels/second).
const double _kDismissVelocity = 600;

/// Bottom distance threshold to dismiss (fraction of sheet height).
const double _kDismissFraction = 0.3;

/// A wrapper that adds vertical drag-to-dismiss for the sheet content.
///
/// Wraps the sheet content (not the full-screen Align) so that the
/// [LayoutBuilder] measures the actual sheet height, enabling the
/// distance-based dismiss threshold.
///
/// Dragging only translates the panel — the sheet never fades out. An
/// `Opacity` layer here would degrade frosted [BackdropFilter] / liquid glass
/// shaders (the same reason [_SheetSlideUp] avoids animated Opacity), showing
/// as transparency flicker while the panel is dragged down.
class _DragDismissableSheet extends StatefulWidget {
  const _DragDismissableSheet({required this.child});

  final Widget child;

  @override
  State<_DragDismissableSheet> createState() => _DragDismissableSheetState();
}

class _DragDismissableSheetState extends State<_DragDismissableSheet>
    with SingleTickerProviderStateMixin {
  /// Pixel offset the sheet has been dragged down (0 = at rest).
  ///
  /// A [ValueNotifier] instead of `setState`: dragging would otherwise rebuild
  /// the whole frosted / liquid glass subtree on every pointer move. The
  /// notifier only rebuilds the [Transform.translate] layer while the sheet
  /// subtree stays mounted untouched (same pattern as [HyperosPage]).
  final _dragOffset = ValueNotifier<double>(0);
  double _sheetHeight = 0;

  late AnimationController _resetController;
  late final CurvedAnimation _resetCurve;
  Animation<double> _resetAnimation = const AlwaysStoppedAnimation<double>(0);

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(vsync: this);
    _resetCurve = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutCubic,
    );
    _resetAnimation = Tween<double>(begin: 0, end: 0).animate(_resetCurve)
      ..addListener(_onResetTick);
  }

  @override
  void dispose() {
    _resetAnimation.removeListener(_onResetTick);
    _resetCurve.dispose();
    _resetController.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  void _onResetTick() {
    _dragOffset.value = _resetAnimation.value;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final dy = details.primaryDelta ?? 0;
    if (dy > 0 || _dragOffset.value > 0) {
      _dragOffset.value = (_dragOffset.value + dy).clamp(0.0, double.infinity);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    // Dismiss if velocity or distance exceeds threshold.
    if (velocity > _kDismissVelocity ||
        (_sheetHeight > 0 &&
            _dragOffset.value > _sheetHeight * _kDismissFraction)) {
      Navigator.of(context).pop();
      return;
    }

    // Animate back to origin.
    if (_dragOffset.value > 0) {
      final startOffset = _dragOffset.value;
      _resetController.stop();
      _resetAnimation.removeListener(_onResetTick);
      _resetAnimation = Tween<double>(
        begin: startOffset,
        end: 0,
      ).animate(_resetCurve)..addListener(_onResetTick);
      final durationMs =
          (250 * (startOffset / (_sheetHeight > 0 ? _sheetHeight : 300))).clamp(
            100,
            350,
          );
      _resetController
        ..duration = Duration(milliseconds: durationMs.toInt())
        ..forward(from: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _sheetHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.5;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: ValueListenableBuilder<double>(
            valueListenable: _dragOffset,
            // Kept outside the builder so the sheet subtree (frosted glass /
            // liquid glass shaders) never rebuilds while dragging.
            child: widget.child,
            builder: (context, dragOffset, child) {
              return Transform.translate(
                offset: Offset(0, dragOffset),
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}

/// Internal slide-up animation for sheet entrance. Uses a simple spring on
/// initial build — no route-level transition needed, so frosted glass never
/// sits inside an animated Opacity layer (which breaks LiquidGlass shaders).
class _SheetSlideUp extends StatefulWidget {
  const _SheetSlideUp({required this.child});

  final Widget child;

  @override
  State<_SheetSlideUp> createState() => _SheetSlideUpState();
}

class _SheetSlideUpState extends State<_SheetSlideUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slide, child: widget.child);
  }
}

/// Shows a HyperOS-styled modal bottom sheet (replaces Forui `showFSheet`).
///
/// Content should use [HyperosSheetFrame] / [HyperosSheet] / [HyperosDialog].
/// Default chrome is [HyperosSheetChrome.floating] unless [chrome] or a
/// [HyperosSheetChromeScope] says otherwise.
///
/// When [padForKeyboard] is true (default), the sheet is lifted by
/// [MediaQuery.viewInsets] so it sits above the IME. Set it to false when the
/// sheet body manages keyboard avoidance itself (e.g. scroll-to-field).
Future<T?> showHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool padForKeyboard = true,
  Color? barrierColor,
  HyperosSheetChrome chrome = HyperosSheetChrome.floating,
}) async {
  final appearance = FrostedAppearanceScope.of(context);
  final dimColor =
      barrierColor ?? HyperosBlurredHeader.modalBarrierColor(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // The dim is painted inside the page below the glass so the modal can
    // cache an undimmed backdrop before any scrim is composited.
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    useRootNavigator: useRootNavigator,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final keyboardInset = padForKeyboard
          ? MediaQuery.viewInsetsOf(dialogContext).bottom
          : 0.0;
      final sheetContent = FrostedAppearanceScope(
        appearance: appearance,
        child: HyperosSheetChromeScope(
          chrome: chrome,
          child: builder(dialogContext),
        ),
      );

      // Wrap drag-to-dismiss around the sheet content (not the full-screen
      // Align) so LayoutBuilder measures the actual sheet height.
      final sheet = enableDrag
          ? _DragDismissableSheet(child: sheetContent)
          : sheetContent;

      return BackdropGroup(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 原 UndimmedBackdropCapture 垫层已移除：本树内没有任何
            // BackdropFilter.grouped 成员加入该外层组，垫层每次开弹窗
            // 白做一次全屏近零模糊采样（premium 玻璃走包内自有隔离组）。
            if (isDismissible)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).maybePop(),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(child: ColoredBox(color: dimColor)),
            ),
            Positioned.fill(
              child: _SheetSlideUp(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: keyboardInset),
                    child: sheet,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Home timetable sheets: edge-flush chrome + lighter barrier.
/// Nested [HyperosSheetFrame]s default to frosted glass.
Future<T?> showHomeHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool padForKeyboard = true,
  Color? barrierColor,
  HyperosSheetChrome chrome = HyperosSheetChrome.edge,
}) {
  return showHyperosSheet<T>(
    context: context,
    builder: builder,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    padForKeyboard: padForKeyboard,
    chrome: chrome,
    barrierColor:
        barrierColor ?? HyperosBlurredHeader.modalBarrierColor(context),
  );
}
