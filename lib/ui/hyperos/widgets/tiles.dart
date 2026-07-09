import 'dart:async';

import 'package:flutter/material.dart';

import '../hyperos_controls.dart';
import '../hyperos_motion.dart';
import '../hyperos_miuix_spec.dart';
import '../hyperos_switch.dart';
import '../hyperos_theme.dart';
import '../hyperos_tokens.dart';
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
    if (_phase == PressPhase.pending) {
      _highlightTimer?.cancel();
      _downPosition = null;
      setState(() => _phase = PressPhase.idle);
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
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: enabled
          ? HyperosColors.secondaryText(context)
          : HyperosColors.secondaryText(context).withValues(alpha: 0.45),
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

/// Miuix-styled choice row: colored circle, title, optional subtitle, trailing
/// radio / checkmark indicator. Tapping the row selects when enabled.
class HyperosChoiceTile extends StatelessWidget {
  const HyperosChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    this.onTap,
    this.enabled = true,
    this.iconAccent,
    this.variant = HyperosChoiceVariant.radio,
    this.highlightSelectedText = false,
    this.isFirstInPopup = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? iconAccent;
  final HyperosChoiceVariant variant;
  final bool highlightSelectedText;
  final bool isFirstInPopup;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final effectiveEnabled = enabled && onTap != null;
    final primaryText = HyperosColors.primaryText(context);
    final titleStyle = HyperosTypography.listTitle(context).copyWith(
      color: effectiveEnabled
          ? primaryText
          : primaryText.withValues(alpha: 0.45),
    );
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: effectiveEnabled
          ? HyperosColors.secondaryText(context)
          : HyperosColors.secondaryText(context).withValues(alpha: 0.45),
    );

    final rowHeight = subtitle != null
        ? HyperosTokens.listRowTwoLineMinHeight
        : null;

    final row = hyperosListRowShell(
      padding: _paddingForVariant(context),
      minHeight: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          HyperosColorDot(color: iconAccent ?? HyperosIconColors.blue),
          const SizedBox(width: HyperosTokens.rowContentGap),
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
          if (selected) ...[
            const SizedBox(width: 6),
            HyperosSelectedCheckmark(
              size: variant == HyperosChoiceVariant.radio ? 20 : 22,
            ),
          ],
        ],
      ),
    );

    return HyperosPressableRow(
      onTap: effectiveEnabled ? onTap : null,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

EdgeInsets _paddingForVariant(BuildContext context) {
  final scope = HyperosListTileScope.maybeOf(context);
  final isFirst = scope?.isFirst ?? true;
  final isLast = scope?.isLast ?? true;
  return HyperosTokens.chevronRowPadding(isFirst: isFirst, isLast: isLast);
}

/// Groups [HyperosChoiceTile] rows into a white rounded card.
class HyperosChoiceGroup extends StatelessWidget {
  const HyperosChoiceGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => HyperosListGroup(children: children);
}

/// HyperOS card: white rounded card with optional title, subtitle, and child.
class HyperosCard extends StatelessWidget {
  const HyperosCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: HyperosColors.card(context),
        shape: HyperosTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            hasTitle || hasSubtitle ? 16 : 0,
            16,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTitle)
                Text(title!, style: HyperosTypography.title(context)),
              if (hasTitle && hasSubtitle) const SizedBox(height: 2),
              if (hasSubtitle)
                Text(
                  subtitle!,
                  style: HyperosTypography.sectionDescription(context),
                  softWrap: true,
                ),
              if (hasTitle || hasSubtitle) const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Summary card: white rounded card with a single summary line.
class HyperosSummaryCard extends StatelessWidget {
  const HyperosSummaryCard({super.key, required this.summary, this.onTap});

  final String summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: hyperosListRowShell(
        padding: hyperosRowPadding(context),
        child: Text(
          summary,
          style: HyperosTypography.listTitle(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Navigation row: colored icon badge, title, optional detail, chevron.
class HyperosNavTile extends StatelessWidget {
  const HyperosNavTile({
    super.key,
    this.icon,
    required this.title,
    this.onTap,
    this.details,
    this.iconAccent,
    this.enabled = true,
    this.holdHighlightThroughTransition = true,
  });

  final IconData? icon;
  final String title;
  final String? details;
  final VoidCallback? onTap;
  final Color? iconAccent;
  final bool enabled;
  final bool holdHighlightThroughTransition;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final enabled = onTap != null;
    final primaryText = HyperosColors.primaryText(context);

    final row = hyperosListRowShell(
      padding: hyperosChevronRowPadding(context),
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
      holdHighlightThroughTransition: true,
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
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dangerColor = isDark
        ? HyperosMiuixDarkColors.error
        : HyperosMiuixLightColors.error;

    final row = hyperosListRowShell(
      padding: hyperosRowPadding(context),
      child: Row(
        children: [
          HyperosIconBadge(icon: icon, accent: dangerColor),
          const SizedBox(width: HyperosTokens.rowContentGap),
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
