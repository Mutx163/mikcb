import 'dart:async';

import 'package:flutter/material.dart';

import '../hyperos_motion.dart';
import '../hyperos_miuix_spec.dart';
import '../hyperos_switch.dart';
import '../hyperos_theme.dart';
import '../hyperos_tokens.dart';
import 'adaptive_card.dart';
import 'indicators.dart';
import 'layout.dart';

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

  PressPhase _phase = PressPhase.idle;
  Offset? _downPosition;
  Timer? _highlightTimer;
  Timer? _flashTimer;
  int _subscribedGeneration = 0;

  bool get _showHighlight =>
      widget.forceHighlighted ||
      _phase == PressPhase.highlighted ||
      _phase == PressPhase.flash;

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
    if (_phase == PressPhase.flash && !clearFlash) {
      return;
    }
    if (_phase == PressPhase.idle && !clearFlash) {
      return;
    }
    setState(() => _phase = PressPhase.idle);
  }

  Duration get _postTapHighlightDuration => HyperosMotionScope.of(
    context,
  ).scaledDuration(HyperosMiuixNavigation.transitionDurationMs);

  void _holdHighlightThroughTransition() {
    _flashTimer?.cancel();
    _downPosition = null;
    setState(() => _phase = PressPhase.flash);
    _flashTimer = Timer(_postTapHighlightDuration, () {
      if (!mounted) return;
      if (_phase == PressPhase.flash) {
        setState(() => _phase = PressPhase.idle);
      }
    });
  }

  void _enterPending(Offset globalPosition) {
    if (HyperosListScrollScope.isUserScrollingOf(context)) return;
    _downPosition = globalPosition;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(_highlightDelay, () {
      if (!mounted || _phase != PressPhase.pending) return;
      setState(() => _phase = PressPhase.highlighted);
    });
    setState(() => _phase = PressPhase.pending);
  }

  void _handleTapDown(TapDownDetails details) {
    if (_phase == PressPhase.flash) {
      _flashTimer?.cancel();
      // setState so the flash highlight clears even when _enterPending bails
      // out early (e.g. the list is still scrolling).
      setState(() => _phase = PressPhase.idle);
    }
    _enterPending(details.globalPosition);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.holdHighlightThroughTransition) {
      _resetGesture();
      return;
    }
    // Keep press fill visible through a quick tap. [onTap] promotes this to
    // the post-tap flash so anchored popups can paint one gray frame before
    // [Navigator.pop] disposes the row.
    _downPosition = null;
    if (_phase == PressPhase.pending) {
      _highlightTimer?.cancel();
      _highlightTimer = null;
      setState(() => _phase = PressPhase.highlighted);
    }
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
    if (_phase == PressPhase.pending) {
      setState(() => _phase = PressPhase.highlighted);
    }
    widget.onLongPress?.call();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_phase != PressPhase.pending && _phase != PressPhase.highlighted) {
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
    final listScope = HyperosListTileScope.maybeOf(context);
    final isFirst =
        listScope?.isFirst ?? cardRowScope?.isFirst ?? cardScope != null;
    final isLast =
        listScope?.isLast ?? cardRowScope?.isLast ?? cardScope != null;
    final surfaceRadius = HyperosSurfaceRadiusScope.of(
      context,
      fallback: cardScope?.cornerRadius,
    );

    final clipTop = _showHighlight && isFirst;
    final clipBottom = _showHighlight && isLast;

    Widget highlighted = ColoredBox(
      color: _showHighlight ? highlight : bg,
      child: SizedBox(width: double.infinity, child: widget.child),
    );

    if (clipTop || clipBottom) {
      highlighted = ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: clipTop ? Radius.circular(surfaceRadius) : Radius.zero,
          topRight: clipTop ? Radius.circular(surfaceRadius) : Radius.zero,
          bottomLeft: clipBottom ? Radius.circular(surfaceRadius) : Radius.zero,
          bottomRight: clipBottom
              ? Radius.circular(surfaceRadius)
              : Radius.zero,
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

    final row = hyperosListRowShell(
      padding: hyperosChevronRowPadding(context),
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

/// Toggle row aligned with Miuix `SwitchPreference` - optional icon, subtitle,
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
    final secondaryText = HyperosColors.secondaryText(context);
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: enabled ? secondaryText : secondaryText.withValues(alpha: 0.45),
    );

    final rowHeight = subtitle != null
        ? HyperosTokens.listRowTwoLineMinHeight
        : null;

    final row = hyperosListRowShell(
      padding: hyperosRowPadding(context),
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
                  Text(subtitle!, style: subtitleStyle, softWrap: true),
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

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          hyperosListRowShell(
            padding: hyperosRowPadding(context),
            child: Row(
              children: [
                HyperosIconBadge(icon: icon, accent: HyperosIconColors.blue),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Expanded(
                  child: Text(
                    title,
                    style: HyperosTypography.listTitle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            HyperosInsetDivider(indent: HyperosTokens.actionTileDividerIndent),
        ],
      ),
    );
  }
}

enum HyperosChoiceVariant { radio, checkmark, dialog, popup }

/// Miuix-styled choice row: optional leading [prefix], title, optional subtitle,
/// trailing checkmark when [selected]. Tapping the row selects when enabled.
///
/// Pure single-choice lists (download channel, week mode, sort, …) should omit
/// [prefix]. Theme / color pickers pass an explicit [prefix] (e.g. color dot).
class HyperosChoiceTile extends StatelessWidget {
  const HyperosChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.onTap,
    this.enabled = true,
    this.iconAccent,
    this.variant = HyperosChoiceVariant.radio,
    this.highlightSelectedText = false,
    this.isFirstInPopup = false,
    this.isLastInPopup = false,
    this.showDivider = false,
    this.trailing,
    this.prefix,
    this.dividerIndent,
    this.titleStyle,
    this.forceHighlighted = false,
  });

  final String title;
  final Widget? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  /// Kept for API compatibility; leading accent dots must be passed via [prefix].
  final Color? iconAccent;
  final HyperosChoiceVariant variant;
  final bool highlightSelectedText;
  final bool isFirstInPopup;
  final bool isLastInPopup;
  final bool showDivider;
  final Widget? trailing;
  final Widget? prefix;
  final double? dividerIndent;

  /// Optional override merged on top of the default list-title style.
  ///
  /// Callers use this to render each option in its own font family so users
  /// can preview the typeface directly inside the select list.
  final TextStyle? titleStyle;

  /// Forces the press fill while selection chrome (blue title / check) has
  /// already moved — used by the anchored select popup commit window.
  final bool forceHighlighted;

  @override
  Widget build(BuildContext context) {
    final isPopup = variant == HyperosChoiceVariant.popup;
    final isDialog = variant == HyperosChoiceVariant.dialog;
    // Popup sits on [surfaceContainer]; keep row fill transparent so the
    // press gray matches settings-row [HyperosPressableRow] against the same
    // surface family. Dialog / list cards still use the card surface.
    final cardColor = isPopup
        ? Colors.transparent
        : HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final effectiveEnabled = enabled && onTap != null;
    final primaryText = HyperosColors.primaryText(context);
    final baseTitleStyle = HyperosTypography.listTitle(context).copyWith(
      color: effectiveEnabled
          ? (selected && highlightSelectedText
                ? HyperosColors.primary(context)
                : primaryText)
          : primaryText.withValues(alpha: 0.45),
    );
    final resolvedTitleStyle = titleStyle != null
        ? baseTitleStyle.merge(titleStyle)
        : baseTitleStyle;
    final secondaryText = HyperosColors.secondaryText(context);
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: effectiveEnabled
          ? secondaryText
          : secondaryText.withValues(alpha: 0.45),
    );

    final padding = _paddingForVariant(context);
    // Popup rows stay content-sized (padding + title line), matching v2.0.4.
    // Do not force settings-row min height — that stacks 56dp under the
    // already-large first/last vertical padding and makes options look bloated.
    final rowHeight = isPopup
        ? null
        : (subtitle != null ? HyperosTokens.listRowTwoLineMinHeight : null);

    final rowChild = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (prefix != null &&
            variant != HyperosChoiceVariant.popup &&
            variant != HyperosChoiceVariant.dialog) ...[
          prefix!,
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
                style: resolvedTitleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                DefaultTextStyle.merge(style: subtitleStyle, child: subtitle!),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        if (selected) ...[
          const SizedBox(width: 6),
          HyperosSelectedCheckmark(
            size: variant == HyperosChoiceVariant.radio ? 20 : 22,
          ),
        ],
      ],
    );

    // [hyperosListRowShell] always sizes to list-row min height when
    // [minHeight] is null — popup must wrap with padding only.
    final row = isPopup
        ? Padding(padding: padding, child: rowChild)
        : hyperosListRowShell(
            padding: padding,
            minHeight: rowHeight,
            child: rowChild,
          );

    return HyperosPressableRow(
      onTap: effectiveEnabled ? onTap : null,
      // Popup / dialog options dismiss immediately on select; keep the same
      // gray press fill as outer settings rows through the brief commit delay.
      holdHighlightThroughTransition: isPopup || isDialog,
      forceHighlighted: forceHighlighted,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          if (showDivider)
            HyperosInsetDivider(
              indent: dividerIndent ?? HyperosMiuixSpec.settingsRowPadding.left,
            ),
        ],
      ),
    );
  }

  /// Settings-list rows use [HyperosListTileScope]; popup rows use the
  /// explicit [isFirstInPopup] / [isLastInPopup] flags from the select body.
  EdgeInsets _paddingForVariant(BuildContext context) {
    if (variant == HyperosChoiceVariant.popup) {
      return _popupChoiceRowPadding(
        isFirst: isFirstInPopup,
        isLast: isLastInPopup,
      );
    }
    final scope = HyperosListTileScope.maybeOf(context);
    final isFirst = scope?.isFirst ?? true;
    final isLast = scope?.isLast ?? true;
    return HyperosTokens.chevronRowPadding(isFirst: isFirst, isLast: isLast);
  }
}

/// Vertical/horizontal insets for Miuix dropdown popup choice rows.
///
/// Edge rows use [HyperosMiuixDropdown.firstLastVerticalPadding]; middle rows
/// use [HyperosMiuixDropdown.middleVerticalPadding]. Must stay in lockstep with
/// [hyperosSelectPopupEstimatedHeight].
EdgeInsets _popupChoiceRowPadding({
  required bool isFirst,
  required bool isLast,
}) {
  return EdgeInsets.only(
    left: HyperosMiuixDropdown.insideHorizontalPadding,
    right: HyperosMiuixDropdown.insideHorizontalPadding,
    top: isFirst
        ? HyperosMiuixDropdown.firstLastVerticalPadding
        : HyperosMiuixDropdown.middleVerticalPadding,
    bottom: isLast
        ? HyperosMiuixDropdown.firstLastVerticalPadding
        : HyperosMiuixDropdown.middleVerticalPadding,
  );
}

/// Groups [HyperosChoiceTile] rows into a white rounded card.
class HyperosChoiceGroup extends StatelessWidget {
  const HyperosChoiceGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => HyperosListGroup(children: children);
}

/// Navigation row: colored icon badge, title, optional subtitle, chevron.
class HyperosNavTile extends StatelessWidget {
  const HyperosNavTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.details,
    this.iconAccent,
    this.enabled = true,
    this.holdHighlightThroughTransition = true,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? details;
  final VoidCallback? onTap;
  final Color? iconAccent;
  final bool enabled;
  final bool holdHighlightThroughTransition;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final canTap = onTap != null && enabled;
    final primaryText = HyperosColors.primaryText(context);

    final rowHeight = subtitle != null
        ? HyperosTokens.listRowTwoLineMinHeight
        : null;

    final titleStyle = HyperosTypography.listTitle(context).copyWith(
      color: canTap ? primaryText : primaryText.withValues(alpha: 0.45),
    );
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: canTap
          ? HyperosColors.secondaryText(context)
          : HyperosColors.secondaryText(context).withValues(alpha: 0.45),
    );

    final row = hyperosListRowShell(
      padding: hyperosChevronRowPadding(context),
      minHeight: rowHeight,
      child: Row(
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
                  Text(subtitle!, style: subtitleStyle, softWrap: true),
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
          Opacity(opacity: canTap ? 1 : 0.45, child: const HyperosChevron()),
        ],
      ),
    );

    return HyperosPressableRow(
      onTap: canTap ? onTap : null,
      holdHighlightThroughTransition: holdHighlightThroughTransition,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

/// Destructive action row (delete, disconnect) with red icon and text.
class HyperosDangerTile extends StatelessWidget {
  const HyperosDangerTile({
    super.key,
    this.icon,
    required this.title,
    this.onTap,
  });

  final IconData? icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final dangerColor = HyperosColors.error(context);

    final row = hyperosListRowShell(
      padding: hyperosRowPadding(context),
      child: Row(
        children: [
          if (icon != null) ...[
            HyperosIconBadge(icon: icon!, accent: dangerColor),
            const SizedBox(width: HyperosTokens.rowContentGap),
          ],
          Expanded(
            child: Text(
              title,
              style: HyperosTypography.listTitle(
                context,
              ).copyWith(color: dangerColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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

/// Groups [HyperosSwitchTile] rows into a white rounded card.
class HyperosSwitchListGroup extends StatelessWidget {
  const HyperosSwitchListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => HyperosListGroup(children: children);
}
