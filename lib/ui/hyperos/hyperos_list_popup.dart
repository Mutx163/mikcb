import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
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
  });

  final String label;
  final T value;
  final bool destructive;
  final bool enabled;
}

/// Miuix spring spec (matches select popup / ListPopup defaults).
final _listPopupSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 362.5,
  ratio: 0.82,
);

/// Shows a Miuix-styled anchored list popup with spring animation + glass.
///
/// No-ops when [position] is null (anchor not mounted, see
/// [hyperosPopupPositionBelow]).
Future<T?> showHyperosListPopup<T>({
  required BuildContext context,
  required RelativeRect? position,
  required List<HyperosPopupMenuItem<T>> items,
}) {
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
      return _HyperosListPopupBody<T>(position: position, items: items);
    },
  );
}

class _HyperosListPopupBody<T> extends StatefulWidget {
  const _HyperosListPopupBody({required this.position, required this.items});

  final RelativeRect position;
  final List<HyperosPopupMenuItem<T>> items;

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

    // Estimate popup height for layout.
    final estimatedHeight =
        widget.items.length * HyperosMiuixBasicComponent.minHeight;
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
    final maxHeight = available < estimatedHeight ? available : estimatedHeight;

    final localOriginY = showBelow ? 0.0 : 1.0;
    // Left-aligned if anchor is on the left half, right-aligned otherwise.
    final isRightAligned = anchorRight > screen.width / 2;
    final originX = isRightAligned ? 1.0 : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim 以渐变 alpha 淡入（复用 _alpha AnimationController, 200ms fastOutSlowIn）
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: AnimatedBuilder(
            animation: _alpha,
            builder: (context, _) => ColoredBox(
              color: HyperosBlurredHeader.modalBarrierColor(
                context,
              ).withValues(alpha: _alpha.value.clamp(0.0, 1.0)),
            ),
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
                  clipper: _ListPopupRevealClipper(
                    progress: fraction,
                    showBelow: showBelow,
                    cornerRadius: cornerRadius,
                  ),
                  child: _ListPopupGlass(
                    cornerRadius: cornerRadius,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: 160,
                        maxWidth: (screen.width - margin * 2).clamp(
                          160.0,
                          288.0,
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
                                  isFirst: i == 0,
                                  isLast: i == widget.items.length - 1,
                                  onTap: widget.items[i].enabled
                                      ? () => Navigator.of(
                                          context,
                                        ).pop(widget.items[i].value)
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
    );
  }
}

/// Individual row in the list popup.
class _ListPopupTile extends StatelessWidget {
  const _ListPopupTile({
    required this.item,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  final HyperosPopupMenuItem<dynamic> item;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? HyperosColors.error(context)
        : (item.enabled
              ? HyperosColors.onSurface(context)
              : HyperosColors.disabledOnSurface(context));
    final verticalPadding = (isFirst || isLast)
        ? HyperosMiuixDropdown.firstLastVerticalPadding
        : HyperosMiuixDropdown.middleVerticalPadding;

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: Colors.transparent,
      highlightColor: HyperosColors.rowHighlight(context),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: HyperosMiuixDropdown.insideHorizontalPadding,
          end: HyperosMiuixDropdown.insideHorizontalPadding,
          top: isFirst ? verticalPadding : verticalPadding * 0.5,
          bottom: isLast ? verticalPadding : verticalPadding * 0.5,
        ),
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
    );
  }
}

/// Reveal clipper for list popup (same logic as select popup).
class _ListPopupRevealClipper extends CustomClipper<Path> {
  const _ListPopupRevealClipper({
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
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, visibleHeight),
        Radius.circular(r),
      ),
    );
  }

  @override
  bool shouldReclip(_ListPopupRevealClipper oldClipper) {
    return oldClipper.progress != progress ||
        oldClipper.showBelow != showBelow ||
        oldClipper.cornerRadius != cornerRadius;
  }
}

/// Glass background for the list popup (liquid glass / blur / solid).
class _ListPopupGlass extends StatelessWidget {
  const _ListPopupGlass({required this.cornerRadius, required this.child});

  final double cornerRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final appearance = FrostedAppearanceScope.of(context);
    final borderRadius = BorderRadius.circular(cornerRadius);
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);

    if (!useBlur) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: HyperosColors.surfaceContainer(context),
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 20,
              offset: Offset.zero,
            ),
          ],
        ),
        child: ClipRRect(borderRadius: borderRadius, child: child),
      );
    }

    if (appearance.glassMode == FrostedGlassMode.liquidGlass) {
      return HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.nestedTile,
        borderRadius: cornerRadius,
        contentLegibilityFill: false,
        instantUnderlay: true,
        child: child,
      );
    }

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
            child: BackdropFilter(
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
