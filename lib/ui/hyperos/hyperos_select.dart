import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:flutter/services.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_controls.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_sheet.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';
import 'liquid/hyperos_liquid_glass_surface.dart';

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
      : HyperosTokens.chevronRowPadding(isFirst: true, isLast: true);

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
}) {
  final entries = items.entries.toList(growable: false);
  if (entries.isEmpty || anchorRect == null) {
    return Future.value();
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    // No route-level transition: the popup runs its own spring + alpha
    // animation internally. A route FadeTransition would wrap the glass in an
    // Opacity layer that degrades the LiquidGlass shader (black flash).
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _HyperosSelectPopupBody<T>(
        anchorRect: anchorRect,
        entries: entries,
        currentValue: currentValue,
        itemTitleStyleBuilder: itemTitleStyleBuilder,
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
  });

  final Rect anchorRect;
  final List<MapEntry<String, T>> entries;
  final T? currentValue;
  final TextStyle? Function(T value)? itemTitleStyleBuilder;

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
    value: 0,
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
                  alignment: Alignment(1.0, localOriginY * 2 - 1),
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
/// - **liquidGlass**: [HyperosLiquidGlassSurface] with nestedTile role.
/// - **frosted / gaussian**: [BackdropFilter] blur + tint scrim.
/// - **translucent**: lighter blur + minimal tint.
/// - **blur disabled**: solid [HyperosColors.surfaceContainer].
class HyperosSelectPopupGlass extends StatelessWidget {
  const HyperosSelectPopupGlass({
    super.key,
    required this.cornerRadius,
    required this.child,
  });

  final double cornerRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final appearance = FrostedAppearanceScope.of(context);
    final borderRadius = BorderRadius.circular(cornerRadius);
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);

    // Blur disabled → solid opaque surface.
    if (!useBlur) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: HyperosColors.surfaceContainer(context),
          borderRadius: borderRadius,
          boxShadow: _kPopupShadow,
        ),
        child: ClipRRect(borderRadius: borderRadius, child: child),
      );
    }

    // Liquid glass mode.
    if (appearance.glassMode == FrostedGlassMode.liquidGlass) {
      return HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.nestedTile,
        borderRadius: cornerRadius,
        contentLegibilityFill: false,
        // Sample the backdrop captured at the popup's ancestor BackdropGroup
        // (undimmed page) so the modal scrim never muddies the refraction.
        useAncestorBackdropGroup: true,
        // FakeGlass underlay paints immediately so the first frames are not
        // black while the real Impeller shader warms up.
        instantUnderlay: true,
        child: child,
      );
    }

    // Frosted / gaussian / translucent: BackdropFilter + tint.
    final sigma = switch (appearance.glassMode) {
      FrostedGlassMode.gaussian => appearance.sheetBlurSigma,
      FrostedGlassMode.translucent => (appearance.sheetBlurSigma * 0.4).clamp(
        4.0,
        30.0,
      ),
      _ => appearance.sheetBlurSigma,
    };
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

  static const _kPopupShadow = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset.zero,
    ),
  ];
}

/// Opens a HyperOS dialog-style bottom sheet for longer single-choice lists.
Future<T?> showHyperosSelectSheet<T>({
  required BuildContext context,
  required String title,
  required Map<String, T> items,
  required T? currentValue,
  String? description,
  required String cancelLabel,
  TextStyle? Function(T value)? itemTitleStyleBuilder,
}) {
  final entries = items.entries.toList(growable: false);
  final resolvedCancelLabel = cancelLabel;

  return showHyperosSheet<T>(
    context: context,
    builder: (sheetContext) {
      final maxListHeight = MediaQuery.sizeOf(sheetContext).height * 0.55;

      return HyperosSheetFrame(
        chrome: HyperosSheetChrome.floating,
        frosted: true,
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
                variant: HyperosChoiceVariant.dialog,
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
    this.variant = HyperosChoiceVariant.dialog,
  });

  final List<MapEntry<String, T>> entries;
  final T? currentValue;
  final ValueChanged<T> onSelected;
  final TextStyle? Function(T value)? itemTitleStyleBuilder;
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

  @override
  State<HyperosSelectTile<T>> createState() => _HyperosSelectTileState<T>();
}

class _HyperosSelectTileState<T> extends State<HyperosSelectTile<T>> {
  final _anchorKey = GlobalKey();
  bool _menuOpen = false;

  Future<void> _openSelector(BuildContext context) async {
    if (_menuOpen || !widget.enabled || widget.onChanged == null) {
      return;
    }

    final anchorRect = hyperosSelectPopupAnchorRect(context, _anchorKey);
    final useSheet =
        widget.useSheetForPopup ||
        widget.items.length > widget.sheetItemThreshold ||
        anchorRect == null;

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
        );
      } else {
        selected = await showHyperosSelectPopup<T>(
          context: context,
          anchorRect: anchorRect,
          items: widget.items,
          currentValue: widget.value,
          itemTitleStyleBuilder: widget.itemTitleStyleBuilder,
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
        crossAxisAlignment: CrossAxisAlignment.center,
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

    return HyperosPressableRow(
      onTap: effectiveEnabled ? () => _openSelector(context) : null,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      forceHighlighted: _menuOpen,
      child: row,
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
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(1970),
      lastDate: lastDate ?? DateTime(2100),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: HyperosColors.primary(ctx),
              brightness: Theme.of(ctx).brightness,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
