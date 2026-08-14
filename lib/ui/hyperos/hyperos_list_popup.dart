import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_select.dart';
import 'hyperos_theme.dart';
import 'hyperos_widgets.dart';
import 'liquid/hyperos_liquid_glass_surface.dart';

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

/// Shows a Miuix-styled anchored list popup with spring animation + glass.
///
/// No-ops when [position] is null (anchor not mounted, see
/// [hyperosPopupPositionBelow]).
Future<T?> showHyperosListPopup<T>({
  required BuildContext context,
  required RelativeRect? position,
  required List<HyperosPopupMenuItem<T>> items,
  Color? foregroundColor,
}) {
  final appearance = FrostedAppearanceScope.of(context);
  if (position == null || items.isEmpty) {
    return Future.value();
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
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
  });

  final RelativeRect position;
  final List<HyperosPopupMenuItem<T>> items;

  /// Overrides the row label/icon color (e.g. wallpaper-aware chrome ink on
  /// the home screen); falls back to [HyperosColors.onSurface].
  final Color? foregroundColor;

  @override
  State<_HyperosListPopupBody<T>> createState() =>
      _HyperosListPopupBodyState<T>();
}

class _HyperosListPopupBodyState<T> extends State<_HyperosListPopupBody<T>>
    with TickerProviderStateMixin {
  late final AnimationController _fraction = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  late final AnimationController _alpha = AnimationController(
    vsync: this,
    value: 0,
  );

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
    super.dispose();
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
    final estimatedHeight = widget.items.fold<double>(
      0,
      (height, item) =>
          height +
          HyperosMiuixBasicComponent.minHeight +
          (item.gapBefore ? _listPopupGroupGap : 0),
    );
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
          _dismiss();
        }
      },
      child: BackdropGroup(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: UndimmedBackdropCapture()),
            // Dim 以渐变 alpha 淡入（复用 _alpha AnimationController, 200ms fastOutSlowIn）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _dismiss(),
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
                  return Transform.scale(
                    scale: scale,
                    alignment: Alignment(originX * 2 - 1, localOriginY * 2 - 1),
                    child: ClipPath(
                      clipper: SelectPopupRevealClipper(
                        progress: fraction,
                        showBelow: showBelow,
                        cornerRadius: cornerRadius,
                      ),
                      child: HyperosSelectPopupGlass(
                        cornerRadius: cornerRadius,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: 200,
                            maxWidth: (screen.width - margin * 2).clamp(
                              200.0,
                              364.0,
                            ),
                            maxHeight: maxHeight,
                          ),
                          child: SingleChildScrollView(
                            child: IntrinsicWidth(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < widget.items.length; i++)
                                    _ListPopupTile(
                                      item: widget.items[i],
                                      foregroundColor: widget.foregroundColor,
                                      onTap: widget.items[i].enabled
                                          ? () =>
                                                _dismiss(widget.items[i].value)
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
  });

  final HyperosPopupMenuItem<dynamic> item;
  final Color? foregroundColor;
  final VoidCallback? onTap;

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
          padding: EdgeInsetsDirectional.only(
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
              if (item.trailing != null) ...[
                const SizedBox(width: 12),
                item.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
    return item.gapBefore
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
