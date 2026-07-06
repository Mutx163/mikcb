import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/android_animation_scale_service.dart';
import 'hyperos_controls.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_switch.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';

/// Solid circle used as a theme / color swatch prefix on choice rows.
class HyperosColorDot extends StatelessWidget {
  const HyperosColorDot({super.key, required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Thin right chevron used on HyperOS list rows.
class HyperosChevron extends StatelessWidget {
  const HyperosChevron({super.key});

  @override
  Widget build(BuildContext context) {
    final color = HyperosColors.actionIcon(context);
    return SizedBox(
      width: HyperosTokens.chevronWidth,
      height: HyperosTokens.chevronHeight,
      child: CustomPaint(
        painter: _HyperosChevronPainter(
          color: color,
          strokeWidth: HyperosTokens.chevronStrokeWidth,
        ),
      ),
    );
  }
}

class _HyperosChevronPainter extends CustomPainter {
  const _HyperosChevronPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HyperosChevronPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Up-down arrow for dropdown / select rows (Miuix `ArrowUpDown`, 10×16).
class HyperosUpDownChevron extends StatelessWidget {
  const HyperosUpDownChevron({super.key});

  @override
  Widget build(BuildContext context) {
    final color = HyperosColors.actionIcon(context);
    return SizedBox(
      width: HyperosMiuixDropdown.arrowWidth,
      height: HyperosMiuixDropdown.arrowHeight,
      child: CustomPaint(
        painter: _HyperosUpDownChevronPainter(
          color: color,
          strokeWidth: HyperosTokens.chevronStrokeWidth,
        ),
      ),
    );
  }
}

class _HyperosUpDownChevronPainter extends CustomPainter {
  const _HyperosUpDownChevronPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final midY = size.height / 2;
    final halfGap = HyperosMiuixDropdown.arrowChevronGap / 2;
    final chevronHalfHeight =
        (size.height - HyperosMiuixDropdown.arrowChevronGap) / 2 - strokeWidth;

    // Top chevron points up (^); bottom chevron points down (v).
    final upBaseline = midY - halfGap;
    final downBaseline = midY + halfGap;
    final up = Path()
      ..moveTo(0, upBaseline)
      ..lineTo(w / 2, upBaseline - chevronHalfHeight)
      ..lineTo(w, upBaseline);
    final down = Path()
      ..moveTo(0, downBaseline)
      ..lineTo(w / 2, downBaseline + chevronHalfHeight)
      ..lineTo(w, downBaseline);

    canvas.drawPath(up, paint);
    canvas.drawPath(down, paint);
  }

  @override
  bool shouldRepaint(covariant _HyperosUpDownChevronPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Colored rounded-square icon badge with white glyph.
class HyperosIconBadge extends StatelessWidget {
  const HyperosIconBadge({
    super.key,
    required this.icon,
    this.accent = HyperosIconColors.blue,
  });

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HyperosTokens.iconBadgeSize,
      height: HyperosTokens.iconBadgeSize,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(HyperosTokens.iconBadgeRadius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: HyperosTokens.iconGlyphSize, color: Colors.white),
    );
  }
}

class HyperosSelectedCheckmark extends StatelessWidget {
  const HyperosSelectedCheckmark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.check, size: size, color: HyperosTokens.accent);
  }
}

class HyperosInsetDivider extends StatelessWidget {
  const HyperosInsetDivider({super.key, required this.indent});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: const Divider(
        height: 0.5,
        thickness: 0.5,
        color: HyperosTokens.divider,
      ),
    );
  }
}

/// Position of a tile inside a [HyperosListGroup] (first / last row).
class HyperosListTileScope extends InheritedWidget {
  const HyperosListTileScope({
    super.key,
    required this.isFirst,
    required this.isLast,
    required super.child,
  });

  final bool isFirst;
  final bool isLast;

  static HyperosListTileScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HyperosListTileScope>();
  }

  @override
  bool updateShouldNotify(HyperosListTileScope oldWidget) {
    return isFirst != oldWidget.isFirst || isLast != oldWidget.isLast;
  }
}

EdgeInsets _hyperosRowPadding(BuildContext context) {
  final scope = HyperosListTileScope.maybeOf(context);
  return HyperosTokens.rowPadding(
    isFirst: scope?.isFirst ?? true,
    isLast: scope?.isLast ?? true,
  );
}

/// Fixed-height row shell shared by settings list tiles (56dp single-line default).
Widget _hyperosListRowShell({
  required EdgeInsetsGeometry padding,
  required Widget child,
  double? minHeight,
}) {
  final targetHeight = minHeight ?? HyperosTokens.listRowMinHeight;
  final padded = Padding(
    padding: padding,
    child: Align(alignment: Alignment.centerLeft, child: child),
  );
  // Two-line rows use min height so subtitle ellipsis survives narrow widths
  // (e.g. HyperosPageRoute shared-axis transition) without bottom overflow.
  if (minHeight != null && minHeight > HyperosTokens.listRowMinHeight) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: targetHeight),
      child: padded,
    );
  }
  return SizedBox(height: targetHeight, child: padded);
}

/// White rounded card grouping list rows.
class HyperosListGroup extends StatelessWidget {
  const HyperosListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: HyperosColors.card(context),
        shape: HyperosTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++)
              HyperosListTileScope(
                isFirst: i == 0,
                isLast: i == children.length - 1,
                child: children[i],
              ),
          ],
        ),
      ),
    );
  }
}

/// Light caption above a settings block (Miuix preference category).
class HyperosSectionLabel extends StatelessWidget {
  const HyperosSectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: HyperosTokens.sectionLabelInset,
        bottom: 8,
      ),
      child: Text(text, style: HyperosTypography.sectionLabel(context)),
    );
  }
}

/// Footnote below a [HyperosListGroup] (Miuix preference category helper).
///
/// Order: [HyperosSectionLabel] → [HyperosListGroup] → [HyperosSectionDescription].
class HyperosSectionDescription extends StatelessWidget {
  const HyperosSectionDescription({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: HyperosTokens.sectionLabelInset, top: 8),
      child: Text(
        text,
        style: HyperosTypography.sectionDescription(context),
        softWrap: true,
      ),
    );
  }
}

/// HyperOS settings block: section title, multiline remark, then a card body.
///
/// Use for select rows ([HyperosListGroup]) or control cards below the remark.
class HyperosSettingsBlock extends StatelessWidget {
  const HyperosSettingsBlock({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.gapBeforeChild = 0,
  });

  final String title;
  final String? description;
  final Widget child;
  final double gapBeforeChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosSectionLabel(text: title),
        if (description != null && description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: HyperosTokens.sectionLabelInset,
              right: HyperosTokens.sectionLabelInset,
            ),
            child: Text(
              description!,
              style: HyperosTypography.sectionDescription(context),
              softWrap: true,
            ),
          ),
        SizedBox(height: gapBeforeChild),
        child,
      ],
    );
  }
}

/// Scroll state shared by rows inside [HyperosListView].
class HyperosListScrollScope extends InheritedWidget {
  const HyperosListScrollScope({
    super.key,
    required this.isUserScrolling,
    required this.pressHighlightGeneration,
    required super.child,
  });

  final bool isUserScrolling;

  /// Bumped on [ScrollStartNotification] so rows cancel pending press highlights.
  final int pressHighlightGeneration;

  static HyperosListScrollScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HyperosListScrollScope>();
  }

  static bool isUserScrollingOf(BuildContext context) {
    return maybeOf(context)?.isUserScrolling ?? false;
  }

  static int pressHighlightGenerationOf(BuildContext context) {
    return maybeOf(context)?.pressHighlightGeneration ?? 0;
  }

  @override
  bool updateShouldNotify(HyperosListScrollScope oldWidget) {
    return isUserScrolling != oldWidget.isUserScrolling ||
        pressHighlightGeneration != oldWidget.pressHighlightGeneration;
  }
}

enum _PressPhase { idle, pending, highlighted, flash }

/// Press highlight for rows inside scrollables.
///
/// Deferred highlight avoids a gray flash when a scroll drag starts on a row.
/// When [holdHighlightThroughTransition] is true, a successful tap keeps the
/// gray state through the HyperOS page transition; otherwise highlight clears
/// as soon as the finger lifts.
class HyperosPressableRow extends StatefulWidget {
  const HyperosPressableRow({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.highlightColor,
    this.holdHighlightThroughTransition = false,
    this.forceHighlighted = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? highlightColor;
  final bool holdHighlightThroughTransition;
  final bool forceHighlighted;

  @override
  State<HyperosPressableRow> createState() => _HyperosPressableRowState();
}

class _HyperosPressableRowState extends State<HyperosPressableRow> {
  static const _highlightDelay = Duration(milliseconds: 25);
  static const _verticalCancelSlop = 2.0;

  _PressPhase _phase = _PressPhase.idle;
  Offset? _downPosition;
  Timer? _highlightTimer;
  Timer? _flashTimer;
  int _subscribedGeneration = 0;

  bool get _showHighlight =>
      widget.forceHighlighted ||
      _phase == _PressPhase.highlighted ||
      _phase == _PressPhase.flash;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final generation = HyperosListScrollScope.pressHighlightGenerationOf(
      context,
    );
    if (generation != _subscribedGeneration) {
      _subscribedGeneration = generation;
      _resetGesture(clearFlash: true);
    }
  }

  void _resetGesture({bool clearFlash = false}) {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    _downPosition = null;
    if (clearFlash) {
      _flashTimer?.cancel();
      _flashTimer = null;
    }
    if (_phase == _PressPhase.flash && !clearFlash) {
      return;
    }
    if (_phase == _PressPhase.idle && !clearFlash) {
      return;
    }
    setState(() => _phase = _PressPhase.idle);
  }

  Duration get _postTapHighlightDuration =>
      AndroidAnimationScaleService.scaledDuration(
        HyperosMiuixNavigation.transitionDurationMs,
      );

  void _holdHighlightThroughTransition() {
    _flashTimer?.cancel();
    _downPosition = null;
    setState(() => _phase = _PressPhase.flash);
    _flashTimer = Timer(_postTapHighlightDuration, () {
      if (!mounted) return;
      if (_phase == _PressPhase.flash) {
        setState(() => _phase = _PressPhase.idle);
      }
    });
  }

  void _enterPending(Offset globalPosition) {
    if (HyperosListScrollScope.isUserScrollingOf(context)) return;
    _downPosition = globalPosition;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(_highlightDelay, () {
      if (!mounted || _phase != _PressPhase.pending) return;
      setState(() => _phase = _PressPhase.highlighted);
    });
    setState(() => _phase = _PressPhase.pending);
  }

  void _handleTapDown(TapDownDetails details) {
    if (_phase == _PressPhase.flash) {
      _flashTimer?.cancel();
      _phase = _PressPhase.idle;
    }
    _enterPending(details.globalPosition);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.holdHighlightThroughTransition) {
      _resetGesture();
      return;
    }
    if (_phase == _PressPhase.pending) {
      _highlightTimer?.cancel();
      _downPosition = null;
      setState(() => _phase = _PressPhase.idle);
    }
    // Keep [highlighted] until [onTap] extends it through the page transition.
  }

  void _handleTapCancel() {
    _resetGesture();
  }

  void _handleTap() {
    widget.onTap?.call();
    if (widget.holdHighlightThroughTransition) {
      _holdHighlightThroughTransition();
    }
  }

  void _handleLongPress() {
    _highlightTimer?.cancel();
    if (_phase == _PressPhase.pending) {
      setState(() => _phase = _PressPhase.highlighted);
    }
    widget.onLongPress?.call();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_phase != _PressPhase.pending && _phase != _PressPhase.highlighted) {
      return;
    }
    final down = _downPosition;
    if (down == null) return;
    if ((event.position - down).dy.abs() > _verticalCancelSlop) {
      _resetGesture();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? HyperosColors.card(context);
    final highlight =
        widget.highlightColor ?? HyperosColors.rowHighlight(context);
    final enabled = widget.onTap != null || widget.onLongPress != null;

    if (!enabled) {
      return Material(color: bg, child: widget.child);
    }

    final cardScope = HyperosControlCardScope.maybeOf(context);
    final cardRowScope = HyperosControlCardRowScope.maybeOf(context);
    final clipHighlightBottom =
        _showHighlight && cardScope != null && (cardRowScope?.isLast ?? true);

    Widget highlighted = ColoredBox(
      color: _showHighlight ? highlight : bg,
      child: SizedBox(width: double.infinity, child: widget.child),
    );

    if (clipHighlightBottom) {
      highlighted = ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(cardScope.cornerRadius),
          bottomRight: Radius.circular(cardScope.cornerRadius),
        ),
        child: highlighted,
      );
    }

    return Material(
      color: bg,
      child: Listener(
        onPointerMove: _handlePointerMove,
        onPointerCancel: (_) => _resetGesture(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onTap != null ? _handleTap : null,
          onLongPress: widget.onLongPress != null ? _handleLongPress : null,
          child: highlighted,
        ),
      ),
    );
  }
}

Widget _hyperosTrailingDetails(BuildContext context, String details) {
  // Non-flex trailing value: only [Expanded] title may flex so chevron stays
  // pinned to the row's right edge (Miuix ArrowPreference pattern).
  return ConstrainedBox(
    constraints: const BoxConstraints(
      maxWidth: HyperosMiuixDropdown.maxItemTextWidth,
    ),
    child: Text(
      details,
      style: HyperosTypography.listDetail(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
    ),
  );
}

/// Navigation row: colored icon badge, title, optional detail, chevron.
class HyperosListTile extends StatelessWidget {
  const HyperosListTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.onLongPress,
    this.details,
    this.iconAccent,
  });

  final IconData icon;
  final String title;
  final String? details;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? iconAccent;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final enabled = onTap != null || onLongPress != null;
    final primaryText = HyperosColors.primaryText(context);

    final row = _hyperosListRowShell(
      padding: _hyperosRowPadding(context),
      child: Row(
        children: [
          HyperosIconBadge(
            icon: icon,
            accent: iconAccent ?? HyperosIconColors.blue,
          ),
          const SizedBox(width: HyperosTokens.rowContentGap),
          Expanded(
            child: Text(
              title,
              style: HyperosTypography.listTitle(context).copyWith(
                color: enabled
                    ? primaryText
                    : primaryText.withValues(alpha: 0.45),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (details != null) ...[
            const SizedBox(width: 6),
            _hyperosTrailingDetails(context, details!),
            SizedBox(width: HyperosTokens.detailChevronGap),
          ] else
            SizedBox(width: HyperosTokens.titleChevronGap),
          Opacity(opacity: enabled ? 1 : 0.45, child: const HyperosChevron()),
        ],
      ),
    );

    return HyperosPressableRow(
      onTap: onTap,
      onLongPress: onLongPress,
      holdHighlightThroughTransition: true,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

/// Toggle row aligned with Miuix `SwitchPreference` — optional icon, subtitle,
/// trailing [HyperosSwitch] (no chevron). Tapping the row toggles when enabled.
class HyperosSwitchTile extends StatelessWidget {
  const HyperosSwitchTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconAccent,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconAccent;

  void _toggle() {
    if (onChanged != null) onChanged!(!value);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final enabled = onChanged != null;
    final primaryText = HyperosColors.primaryText(context);
    final titleStyle = HyperosTypography.listTitle(context).copyWith(
      color: enabled ? primaryText : primaryText.withValues(alpha: 0.45),
    );
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: enabled
          ? HyperosColors.secondaryText(context)
          : HyperosColors.secondaryText(context).withValues(alpha: 0.45),
    );

    final rowHeight = subtitle != null
        ? HyperosTokens.listRowTwoLineMinHeight
        : null;

    final row = _hyperosListRowShell(
      padding: _hyperosRowPadding(context),
      minHeight: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            HyperosIconBadge(
              icon: icon!,
              accent: iconAccent ?? HyperosIconColors.blue,
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: subtitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: HyperosMiuixBasicComponent.startEndSpacer),
          HyperosSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );

    return HyperosPressableRow(
      onTap: enabled ? _toggle : null,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

/// Plain action row with blue outline-style icon (export / import sheets).
class HyperosActionTile extends StatelessWidget {
  const HyperosActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.showDivider = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    final row = _hyperosListRowShell(
      padding: _hyperosRowPadding(context),
      child: Row(
        children: [
          Icon(icon, size: 22, color: HyperosTokens.accent),
          const SizedBox(width: HyperosTokens.rowContentGap),
          Expanded(
            child: Text(title, style: HyperosTypography.listTitle(context)),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosPressableRow(
          onTap: onTap,
          backgroundColor: cardColor,
          highlightColor: highlightColor,
          child: row,
        ),
        if (showDivider)
          HyperosInsetDivider(indent: HyperosTokens.actionTileDividerIndent),
      ],
    );
  }
}

/// Visual variant for [HyperosChoiceTile] in different HyperOS surfaces.
enum HyperosChoiceVariant {
  /// In-card list (settings choice group).
  list,

  /// Anchored dropdown popup — blue selected text, no pill background.
  popup,

  /// Dialog / bottom sheet — light blue selected pill background.
  dialog,
}

/// Single- or multi-choice row with optional checkmark.
class HyperosChoiceTile extends StatelessWidget {
  const HyperosChoiceTile({
    super.key,
    required this.title,
    this.prefix,
    this.subtitle,
    this.trailing,
    this.selected = false,
    this.highlightSelectedText = false,
    this.variant = HyperosChoiceVariant.list,
    this.isFirstInPopup = false,
    this.isLastInPopup = false,
    this.showDivider = false,
    this.dividerIndent,
    this.onTap,
  });

  final Widget? prefix;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool selected;
  final bool highlightSelectedText;
  final HyperosChoiceVariant variant;
  final bool isFirstInPopup;
  final bool isLastInPopup;
  final bool showDivider;
  final double? dividerIndent;
  final VoidCallback? onTap;

  EdgeInsets _paddingForVariant(BuildContext context) {
    return switch (variant) {
      HyperosChoiceVariant.list => _hyperosRowPadding(context),
      HyperosChoiceVariant.popup => EdgeInsets.fromLTRB(
        HyperosMiuixDropdown.insideHorizontalPadding,
        isFirstInPopup
            ? HyperosMiuixDropdown.firstLastVerticalPadding
            : HyperosMiuixDropdown.middleVerticalPadding,
        HyperosMiuixDropdown.insideHorizontalPadding,
        isLastInPopup
            ? HyperosMiuixDropdown.firstLastVerticalPadding
            : HyperosMiuixDropdown.middleVerticalPadding,
      ),
      HyperosChoiceVariant.dialog => const EdgeInsets.symmetric(
        horizontal: HyperosMiuixDropdown.dialogHorizontalPadding,
        vertical: HyperosMiuixDropdown.middleVerticalPadding,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final primaryText = HyperosColors.primaryText(context);

    final usePopupStyle = variant == HyperosChoiceVariant.popup;
    final useDialogStyle = variant == HyperosChoiceVariant.dialog;

    final titleColor = switch ((selected, highlightSelectedText, variant)) {
      (true, true, HyperosChoiceVariant.list) => HyperosTokens.accent,
      (true, _, HyperosChoiceVariant.popup) => HyperosTokens.accent,
      (true, _, HyperosChoiceVariant.dialog) =>
        isDark
            ? HyperosMiuixDarkColors.onTertiaryContainer
            : HyperosMiuixLightColors.onTertiaryContainer,
      _ => primaryText,
    };

    final rowBackground = selected && useDialogStyle
        ? (isDark
              ? HyperosMiuixDarkColors.tertiaryContainer
              : HyperosMiuixLightColors.tertiaryContainer)
        : Colors.transparent;

    final row = Container(
      color: rowBackground,
      padding: _paddingForVariant(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (prefix != null) ...[
            prefix!,
            const SizedBox(width: HyperosTokens.rowContentGap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: (usePopupStyle || useDialogStyle)
                      ? TextStyle(
                          fontSize: HyperosMiuixTypography.body1,
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: titleColor,
                        )
                      : HyperosTypography.listTitle(
                          context,
                        ).copyWith(color: titleColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle(
                    style: HyperosTypography.listDetail(context),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (selected) ...[
            if (trailing != null) const SizedBox(width: 4),
            Icon(
              Icons.check_rounded,
              size: HyperosMiuixDropdown.checkIconSize,
              color: useDialogStyle
                  ? (isDark
                        ? HyperosMiuixDarkColors.onTertiaryContainer
                        : HyperosMiuixLightColors.onTertiaryContainer)
                  : HyperosTokens.accent,
            ),
          ],
        ],
      ),
    );

    final interactiveChild = variant == HyperosChoiceVariant.list
        ? HyperosPressableRow(
            onTap: onTap,
            backgroundColor: cardColor,
            highlightColor: highlightColor,
            child: row,
          )
        : Material(
            color: usePopupStyle
                ? (isDark
                      ? HyperosMiuixDarkColors.surfaceContainer
                      : HyperosMiuixLightColors.surfaceContainer)
                : Colors.transparent,
            child: InkWell(onTap: onTap, child: row),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        interactiveChild,
        if (showDivider)
          HyperosInsetDivider(
            indent: dividerIndent ?? HyperosTokens.listTileDividerIndent,
          ),
      ],
    );
  }
}

/// Alias for choice-picker cards.
class HyperosChoiceGroup extends StatelessWidget {
  const HyperosChoiceGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => HyperosListGroup(children: children);
}

/// Standalone white card using HyperOS corner radius (summary / info blocks).
class HyperosCard extends StatelessWidget {
  const HyperosCard({
    super.key,
    required this.child,
    this.padding,
    this.strip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// When true, use a stadium (pill) outline for single-line status rows.
  final bool strip;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? HyperosTokens.rowPaddingUniform;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: HyperosColors.card(context),
        shape: strip ? HyperosTheme.stripShape() : HyperosTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: strip
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: HyperosTokens.listRowMinHeight,
                ),
                child: Padding(padding: resolvedPadding, child: child),
              )
            : Padding(padding: resolvedPadding, child: child),
      ),
    );
  }
}

/// Top-of-page summary card: leading avatar/icon + title + optional subtitle.
///
/// Used for semester overview, account header, and similar HyperOS settings
/// blocks (Miuix preference page header pattern).
class HyperosSummaryCard extends StatelessWidget {
  const HyperosSummaryCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.backgroundColor,
    this.onTap,
  });

  static const double leadingSize = 44;
  static const double leadingRadius = 8;
  static const double contentGap = HyperosMiuixSpec.settingsIconGap;

  final Widget leading;
  final String title;
  final String? subtitle;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: contentGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HyperosTypography.summaryTitle(context)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: HyperosTypography.summarySubtitle(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Material(
      color: backgroundColor ?? HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        overlayColor: HyperosTheme.rowPressOverlay(
          HyperosColors.rowHighlight(context),
        ),
        child: Padding(
          padding: HyperosTokens.rowPaddingUniform,
          child: content,
        ),
      ),
    );
  }
}

/// Text-only navigation row (no left icon badge) — common on secondary settings pages.
class HyperosNavTile extends StatelessWidget {
  const HyperosNavTile({
    super.key,
    required this.title,
    this.onTap,
    this.onLongPress,
    this.details,
    this.subtitle,
    this.enabled = true,
    this.holdHighlightThroughTransition = true,
  });

  final String title;
  final String? subtitle;
  final String? details;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool holdHighlightThroughTransition;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final primaryText = HyperosColors.primaryText(context);
    final interactive = enabled && (onTap != null || onLongPress != null);
    final titleStyle = HyperosTypography.listTitle(context).copyWith(
      color: interactive ? primaryText : primaryText.withValues(alpha: 0.45),
    );
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: interactive
          ? HyperosColors.secondaryText(context)
          : HyperosColors.secondaryText(context).withValues(alpha: 0.45),
    );

    final rowHeight = subtitle != null
        ? HyperosTokens.listRowTwoLineMinHeight
        : null;

    final row = _hyperosListRowShell(
      padding: _hyperosRowPadding(context),
      minHeight: rowHeight,
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
                  title,
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: subtitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (details != null) ...[
            const SizedBox(width: 6),
            _hyperosTrailingDetails(context, details!),
            SizedBox(width: HyperosTokens.detailChevronGap),
          ] else
            SizedBox(width: HyperosTokens.titleChevronGap),
          Opacity(
            opacity: interactive ? 1 : 0.45,
            child: const HyperosChevron(),
          ),
        ],
      ),
    );

    return HyperosPressableRow(
      onTap: interactive ? onTap : null,
      onLongPress: interactive ? onLongPress : null,
      holdHighlightThroughTransition: holdHighlightThroughTransition,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

/// Destructive action row — red title text (logout, clear data, delete).
class HyperosDangerTile extends StatelessWidget {
  const HyperosDangerTile({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final error = isDark
        ? HyperosMiuixDarkColors.error
        : HyperosMiuixLightColors.error;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final enabled = onTap != null;

    final rowHeight = subtitle != null
        ? HyperosTokens.listRowTwoLineMinHeight
        : null;

    final row = _hyperosListRowShell(
      padding: _hyperosRowPadding(context),
      minHeight: rowHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: HyperosTypography.listTitle(
              context,
            ).copyWith(color: enabled ? error : error.withValues(alpha: 0.45)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: HyperosTypography.listDetail(context).copyWith(
                color: enabled
                    ? HyperosColors.secondaryText(context)
                    : HyperosColors.secondaryText(
                        context,
                      ).withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

/// Switch rows grouped with inset dividers between items.
class HyperosSwitchListGroup extends StatelessWidget {
  const HyperosSwitchListGroup({super.key, required this.children});

  final List<HyperosSwitchTile> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            HyperosListTileScope(
              isFirst: i == 0,
              isLast: i == children.length - 1,
              child: children[i],
            ),
            if (i < children.length - 1) const HyperosInsetDivider(indent: 16),
          ],
        ],
      ),
    );
  }
}

/// Vertical gap between grouped sections on a HyperOS page.
class HyperosSectionGap extends StatelessWidget {
  const HyperosSectionGap({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: HyperosTokens.sectionGap);
  }
}
