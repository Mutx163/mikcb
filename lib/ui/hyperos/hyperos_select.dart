import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'hyperos_controls.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_page.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';

({double minHeight, EdgeInsets padding}) hyperosSelectRowLayout(
  BuildContext context, {
  bool twoLine = false,
}) {
  final listScope = HyperosListTileScope.maybeOf(context);
  final cardRowScope = HyperosControlCardRowScope.maybeOf(context);
  final cardScope = HyperosControlCardScope.maybeOf(context);

  final isFirst = listScope?.isFirst ?? cardRowScope?.isFirst ?? true;
  final isLast = listScope?.isLast ?? cardRowScope?.isLast ?? cardScope != null;

  var padding = (listScope != null || cardRowScope != null || cardScope != null)
      ? HyperosTokens.chevronRowPadding(isFirst: isFirst, isLast: isLast)
      : HyperosTokens.chevronRowPadding(isFirst: true, isLast: true);

  if (cardScope != null && isLast) {
    padding = padding.copyWith(
      bottom: padding.bottom + cardScope.bodyBottomInset,
    );
  }

  final baseMinHeight = twoLine
      ? HyperosTokens.listRowTwoLineMinHeight
      : HyperosTokens.listRowMinHeight;

  return (minHeight: baseMinHeight, padding: padding);
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
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _HyperosSelectPopupBody<T>(
        anchorRect: anchorRect,
        entries: entries,
        currentValue: currentValue,
        itemTitleStyleBuilder: itemTitleStyleBuilder,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _HyperosSelectPopupBody<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? HyperosMiuixDarkColors.surfaceContainer
        : HyperosMiuixLightColors.surfaceContainer;
    final screen = MediaQuery.sizeOf(context);
    const margin = 12.0;
    final safeTop = MediaQuery.paddingOf(context).top + margin;
    final safeBottom =
        screen.height - MediaQuery.paddingOf(context).bottom - margin;
    final estimatedHeight = hyperosSelectPopupEstimatedHeight(entries.length);
    final layout = hyperosSelectPopupLayout(
      anchorRect: anchorRect,
      estimatedPopupHeight: estimatedHeight,
      screenHeight: screen.height,
      safeTop: safeTop,
      safeBottom: safeBottom,
    );

    // Right edge of popup aligns with anchor row (HyperOS anchored dropdown).
    final anchorRight = anchorRect.right.clamp(margin, screen.width - margin);

    return Stack(
      children: [
        Positioned(
          top: layout.top,
          right: screen.width - anchorRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 132,
              maxWidth: (screen.width - margin * 2).clamp(
                132.0,
                HyperosMiuixDropdown.maxItemTextWidth +
                    HyperosMiuixDropdown.insideHorizontalPadding * 2 +
                    HyperosMiuixDropdown.checkIconSize +
                    28,
              ),
              maxHeight: layout.maxHeight,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(
                  HyperosMiuixDropdown.popupCornerRadius,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: Offset.zero,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  HyperosMiuixDropdown.popupCornerRadius,
                ),
                child: SingleChildScrollView(
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          HyperosChoiceTile(
                            title: entries[i].key,
                            selected: entries[i].value == currentValue,
                            highlightSelectedText: true,
                            variant: HyperosChoiceVariant.popup,
                            isFirstInPopup: i == 0,
                            isLastInPopup: i == entries.length - 1,
                            titleStyle: itemTitleStyleBuilder?.call(
                              entries[i].value,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop(entries[i].value);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
      // Resolve inside the builder so rotation / keyboard metrics changes
      // re-evaluate instead of using a snapshot taken when the sheet opened.
      final maxListHeight = MediaQuery.sizeOf(sheetContext).height * 0.55;
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final sheetBackground = isDark
          ? HyperosMiuixDarkColors.surfaceContainer
          : HyperosMiuixLightColors.surfaceContainer;

      // ~1 body1 char side inset; floating select sheet bottom gap (see spec).
      const horizontalInset = HyperosMiuixBasicComponent.insideMarginHorizontal;
      const bottomInsetBase =
          HyperosMiuixBasicComponent.selectSheetBottomMargin;
      final bottomInset =
          bottomInsetBase + MediaQuery.paddingOf(sheetContext).bottom;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          0,
          horizontalInset,
          bottomInset,
        ),
        child: Material(
          color: sheetBackground,
          borderRadius: BorderRadius.circular(
            HyperosMiuixDialog.minBottomCornerRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
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
                        style: HyperosTypography.sectionDescription(
                          sheetContext,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        HyperosChoiceTile(
                          title: entries[i].key,
                          selected: entries[i].value == currentValue,
                          highlightSelectedText: true,
                          variant: HyperosChoiceVariant.dialog,
                          titleStyle: itemTitleStyleBuilder?.call(
                            entries[i].value,
                          ),
                          onTap: () =>
                              Navigator.of(sheetContext).pop(entries[i].value),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HyperosButton(
                  label: resolvedCancelLabel,
                  expand: true,
                  variant: HyperosButtonVariant.secondary,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
    // Match [_popupChoiceRowPadding] / HyperosChoiceTile popup layout:
    // first row top and last row bottom use firstLast; all other edges use middle.
    final topPadding = i == 0
        ? HyperosMiuixDropdown.firstLastVerticalPadding
        : HyperosMiuixDropdown.middleVerticalPadding;
    final bottomPadding = i == itemCount - 1
        ? HyperosMiuixDropdown.firstLastVerticalPadding
        : HyperosMiuixDropdown.middleVerticalPadding;
    height +=
        topPadding + bottomPadding + HyperosMiuixSpec.settingsRowMinHeight;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final primaryText = HyperosColors.primaryText(context);
    final valueLabel = hyperosSelectLabelFor(widget.items, widget.value);
    final valueColor = effectiveEnabled
        ? (isDark
              ? HyperosMiuixDarkColors.onSurfaceVariantActions
              : HyperosMiuixLightColors.onSurfaceVariantActions)
        : (isDark
              ? HyperosMiuixDarkColors.disabledOnSurface
              : HyperosMiuixLightColors.disabledOnSurface);
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: effectiveEnabled
          ? HyperosColors.secondaryText(context)
          : HyperosColors.secondaryText(context).withValues(alpha: 0.45),
    );

    final rowLayout = hyperosSelectRowLayout(
      context,
      twoLine: widget.subtitle != null,
    );

    final row = ConstrainedBox(
      key: _anchorKey,
      constraints: BoxConstraints(minHeight: rowLayout.minHeight),
      child: Padding(
        padding: rowLayout.padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: subtitleStyle,
                      softWrap: true,
                    ),
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
      ),
    );

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
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: HyperosMiuixLightColors.primary,
              brightness: isDark ? Brightness.dark : Brightness.light,
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
