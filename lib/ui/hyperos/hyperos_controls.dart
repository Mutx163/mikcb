import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_radius.dart';
import 'hyperos_text_field.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';

/// Horizontal inset for non-row content inside [HyperosControlCard] (color chips,
/// button groups, accordions, helper text).
class HyperosControlCardInset extends StatelessWidget {
  const HyperosControlCardInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = HyperosControlCardScope.maybeOf(context);
    if (scope != null && !scope.hasHeader) {
      // Headerless [HyperosControlCard] already applies [HyperosControlCard.headerlessBodyPadding].
      return child;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        HyperosControlCardScope.defaultHorizontalPadding,
        scope == null ? HyperosControlCardScope.defaultHorizontalPadding : 0,
        HyperosControlCardScope.defaultHorizontalPadding,
        scope?.bodyBottomInset ??
            HyperosControlCardScope.defaultBodyBottomInset,
      ),
      child: child,
    );
  }
}

/// White card for sliders, button groups, and custom controls (Miuix Card +
/// preference section layout).
///
/// **Multi-row full-bleed content:** wrap rows in [HyperosControlCardRows].
/// Do not stack [HyperosSelectTile] / [HyperosSliderTile] with [SizedBox]
/// spacers in a plain [Column] — those tiles only get correct first/last
/// padding through [HyperosControlCardRows] or [HyperosListGroup].
///
/// **List-only blocks** (no title/subtitle): prefer [HyperosListGroup] instead.
class HyperosControlCard extends StatelessWidget {
  const HyperosControlCard({
    super.key,
    this.title,
    this.subtitle,
    this.strip = false,
    this.edgeToEdge = false,
    required this.child,
  });

  final String? title;
  final String? subtitle;

  /// When true the card body stays edge-to-edge (e.g. [HyperosSelectTile] rows).
  /// Headerless cards with only inset content default to [headerlessBodyPadding].
  /// Multi-row edge-to-edge bodies must use [HyperosControlCardRows].
  final bool edgeToEdge;

  /// Stadium outline for child-only status rows (e.g. connected account strip).
  final bool strip;
  final Widget child;

  static const headerlessBodyPadding = EdgeInsets.fromLTRB(
    HyperosControlCardScope.defaultHorizontalPadding,
    HyperosControlCardScope.defaultHorizontalPadding,
    HyperosControlCardScope.defaultHorizontalPadding,
    HyperosControlCardScope.defaultBodyBottomInset,
  );

  @override
  Widget build(BuildContext context) {
    final hasHeader =
        (title != null && title!.isNotEmpty) || (subtitle != null);
    final useStrip = strip && !hasHeader;

    Widget body = child;
    if (!hasHeader && !edgeToEdge) {
      body = Padding(padding: headerlessBodyPadding, child: child);
    }

    return SizedBox(
      width: double.infinity,
      child: HyperosAdaptiveCard(
        child: HyperosControlCardScope(
          hasHeader: hasHeader,
          // Edge-to-edge bodies already use first/last row padding (same as
          // [HyperosListGroup]). An extra bodyBottomInset under a lone select
          // row leaves a dead band and makes the label look top-heavy.
          bodyBottomInset: useStrip || edgeToEdge
              ? 0
              : HyperosControlCardScope.defaultBodyBottomInset,
          cornerRadius: HyperosTokens.cardRadius,
          child: useStrip
              ? Padding(
                  padding: HyperosTokens.rowPaddingUniform,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: HyperosTokens.listRowMinHeight,
                    ),
                    child: Align(alignment: Alignment.centerLeft, child: child),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null && title!.isNotEmpty)
                              Text(
                                title!,
                                style: HyperosTypography.title(context),
                              ),
                            if (subtitle != null) ...[
                              if (title != null && title!.isNotEmpty)
                                const SizedBox(
                                  height: HyperosTokens.titleCaptionGap,
                                ),
                              Text(
                                subtitle!,
                                style: HyperosTypography.sectionDescription(
                                  context,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (hasHeader) const SizedBox(height: 12),
                    body,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Track shape for [HyperosSlider]: HyperOS volume-style full-height capsule.
///
/// The whole track is a capsule as tall as the slider (28dp). The active fill
/// is a capsule whose rounded right end wraps the thumb; at the minimum value
/// it collapses to a circle around the thumb (the "ring" look in HyperOS
/// system settings).
class _HyperosCapsuleTrackShape extends SliderTrackShape {
  const _HyperosCapsuleTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? HyperosMiuixSlider.minHeight;
    final top = offset.dy + (parentBox.size.height - trackHeight) / 2;
    // Inset by half the track height so the thumb (and the rounded end of the
    // fill capsule around it) always stays inside the capsule.
    final width = parentBox.size.width - trackHeight;
    return Rect.fromLTWH(
      offset.dx + trackHeight / 2,
      top,
      width > 0 ? width : 0,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? HyperosMiuixSlider.minHeight;
    final radius = Radius.circular(trackHeight / 2);
    final top = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final fullRect = Rect.fromLTWH(
      offset.dx,
      top,
      parentBox.size.width,
      trackHeight,
    );

    final inactiveColor = ColorTween(
      begin: sliderTheme.disabledInactiveTrackColor,
      end: sliderTheme.inactiveTrackColor,
    ).evaluate(enableAnimation);
    final activeColor = ColorTween(
      begin: sliderTheme.disabledActiveTrackColor,
      end: sliderTheme.activeTrackColor,
    ).evaluate(enableAnimation);

    final canvas = context.canvas;
    if (inactiveColor != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(fullRect, radius),
        Paint()..color = inactiveColor,
      );
    }
    if (activeColor != null) {
      // Fill capsule extends half a track height past the thumb center, so the
      // thumb sits centered inside the rounded end of the fill.
      final fillRect = textDirection == TextDirection.rtl
          ? Rect.fromLTRB(
              thumbCenter.dx - trackHeight / 2,
              fullRect.top,
              fullRect.right,
              fullRect.bottom,
            )
          : Rect.fromLTRB(
              fullRect.left,
              fullRect.top,
              thumbCenter.dx + trackHeight / 2,
              fullRect.bottom,
            );
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, radius),
        Paint()..color = activeColor,
      );
    }
  }
}

/// HyperOS volume-style slider: 28dp capsule track with an inset white thumb.
class HyperosSlider extends StatelessWidget {
  const HyperosSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.enabled = true,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Normalize so a caller mistake (min > max) degrades instead of throwing
    // from value.clamp / Slider asserts during build.
    final lo = min <= max ? min : max;
    final hi = min <= max ? max : min;
    final active = HyperosColors.primary(context);
    final inactive = HyperosColors.sliderBackground(context);
    final disabledActive = HyperosColors.disabledPrimarySlider(context);
    final thumb = HyperosColors.onPrimary(context);
    final disabledThumb = HyperosColors.disabledOnPrimary(context);

    return SizedBox(
      height: HyperosMiuixSlider.minHeight,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: HyperosMiuixSlider.minHeight,
          activeTrackColor: enabled ? active : disabledActive,
          inactiveTrackColor: inactive,
          thumbColor: enabled ? thumb : disabledThumb,
          disabledActiveTrackColor: disabledActive,
          disabledInactiveTrackColor: inactive,
          disabledThumbColor: disabledThumb,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
          tickMarkShape: SliderTickMarkShape.noTickMark,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: HyperosMiuixSlider.thumbRadius,
            disabledThumbRadius: HyperosMiuixSlider.thumbRadius,
            elevation: 0,
            pressedElevation: 0,
          ),
          trackShape: const _HyperosCapsuleTrackShape(),
        ),
        child: Slider(
          // Keep raw clamped value for display so off-grid stored values
          // (e.g. legacy 0.72) stay consistent with parent labels until edited.
          value: value.clamp(lo, hi),
          min: lo,
          max: hi,
          divisions: divisions,
          onChanged: enabled && onChanged != null
              ? (rawValue) => onChanged!(
                  _hyperosNormalizeSliderValue(
                    rawValue,
                    min: lo,
                    max: hi,
                    divisions: divisions,
                  ),
                )
              : null,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

EdgeInsets _hyperosSliderTilePadding(BuildContext context) {
  final listScope = HyperosListTileScope.maybeOf(context);
  final cardRowScope = HyperosControlCardRowScope.maybeOf(context);
  final cardScope = HyperosControlCardScope.maybeOf(context);

  // Inside [HyperosListGroup] or [HyperosControlCardRows]: same first/last
  // row insets as switches and select tiles.
  if (listScope != null) {
    return HyperosTokens.rowPadding(
      isFirst: listScope.isFirst,
      isLast: listScope.isLast,
    );
  }
  if (cardRowScope != null) {
    var padding = HyperosTokens.rowPadding(
      isFirst: cardRowScope.isFirst,
      isLast: cardRowScope.isLast,
    );
    if (cardScope != null && cardRowScope.isLast) {
      padding = padding.copyWith(
        bottom: padding.bottom + cardScope.bodyBottomInset,
      );
    }
    return padding;
  }

  // Bare [HyperosControlCard] with a single slider (no row scope): treat as
  // the card's only full-bleed block. Multi-row cards must use
  // [HyperosControlCardRows] instead of a plain Column + SizedBox.
  if (cardScope != null) {
    return EdgeInsets.fromLTRB(
      HyperosControlCardScope.defaultHorizontalPadding,
      12,
      HyperosControlCardScope.defaultHorizontalPadding,
      cardScope.bodyBottomInset,
    );
  }

  return const EdgeInsets.fromLTRB(
    HyperosControlCardScope.defaultHorizontalPadding,
    12,
    HyperosControlCardScope.defaultHorizontalPadding,
    12,
  );
}

String _hyperosSliderInputText(
  double value, {
  double min = 0,
  double max = 1,
  int? divisions,
}) {
  final precision = _hyperosSliderPrecision(min, max, divisions);
  if (precision <= 0 || value == value.roundToDouble()) {
    return value.round().toString();
  }
  final fixed = value.toStringAsFixed(precision);
  // Drop trailing zeros so "0.70" becomes "0.7", never binary noise.
  if (!fixed.contains('.')) {
    return fixed;
  }
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

int _hyperosSliderPrecision(double min, double max, int? divisions) {
  if (divisions == null || divisions <= 0 || max <= min) {
    return 2;
  }
  final step = (max - min) / divisions;
  final stepText = step.toStringAsFixed(6);
  final dot = stepText.indexOf('.');
  if (dot < 0) {
    return 0;
  }
  final trimmed = stepText.replaceFirst(RegExp(r'0+$'), '');
  final digits = trimmed.length - dot - 1;
  // Cap so UI never shows long floating-point tails.
  return digits.clamp(0, 4);
}

double _hyperosNormalizeSliderValue(
  double rawValue, {
  required double min,
  required double max,
  required int? divisions,
}) {
  final lo = min <= max ? min : max;
  final hi = min <= max ? max : min;
  final clamped = rawValue.clamp(lo, hi);
  if (divisions == null || divisions <= 0 || hi <= lo) {
    final precision = _hyperosSliderPrecision(lo, hi, null);
    return double.parse(clamped.toStringAsFixed(precision));
  }

  final step = (hi - lo) / divisions;
  final snapped = (((clamped - lo) / step).round() * step) + lo;
  final precision = _hyperosSliderPrecision(lo, hi, divisions);
  final normalized = double.parse(snapped.toStringAsFixed(precision));
  return normalized.clamp(lo, hi);
}

Future<double?> showHyperosSliderValueDialog({
  required BuildContext context,
  required String title,
  required double value,
  required double min,
  required double max,
  required int? divisions,
  required String cancelLabel,
  required String confirmLabel,
  String? helper,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: HyperosColors.windowDimming(context),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _HyperosSliderValueSheetBody(
          title: title,
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
          helper: helper,
        ),
      );
    },
  );
}

class _HyperosSliderValueSheetBody extends StatefulWidget {
  const _HyperosSliderValueSheetBody({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.cancelLabel,
    required this.confirmLabel,
    this.helper,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String cancelLabel;
  final String confirmLabel;
  final String? helper;

  @override
  State<_HyperosSliderValueSheetBody> createState() =>
      _HyperosSliderValueSheetBodyState();
}

class _HyperosSliderValueSheetBodyState
    extends State<_HyperosSliderValueSheetBody> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final displayValue = _hyperosNormalizeSliderValue(
      widget.value,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
    );
    _controller = TextEditingController(
      text: _hyperosSliderInputText(
        displayValue,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) {
      setState(
        () => _errorText = widget.helper ?? '${widget.min} - ${widget.max}',
      );
      return;
    }
    final normalized = _hyperosNormalizeSliderValue(
      parsed,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
    );
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final background = HyperosColors.surfaceContainer(context);
    final borderColor = HyperosColors.outline(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HyperosTokens.cardRadius),
            side: BorderSide(color: borderColor.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: HyperosTypography.sheetTitle(context),
                ),
                const SizedBox(height: 16),
                HyperosTextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  helper:
                      _errorText ??
                      widget.helper ??
                      '${widget.min} - ${widget.max}',
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: HyperosButton(
                        label: widget.cancelLabel,
                        variant: HyperosButtonVariant.secondary,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HyperosButton(
                        label: widget.confirmLabel,
                        expand: true,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Title + optional value label + [HyperosSlider] (Miuix `SliderPreference`).
class HyperosSliderTile extends StatelessWidget {
  const HyperosSliderTile({
    super.key,
    this.title,
    required this.value,
    required this.onChanged,
    this.valueLabel,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.enabled = true,
    this.tapToEdit = true,
    this.dialogTitle,
    this.dialogHelper,
  });

  /// When omitted, only the slider is shown (e.g. under [HyperosControlCard] header).
  final String? title;
  final String? valueLabel;
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
  final bool tapToEdit;
  final String? dialogTitle;
  final String? dialogHelper;

  Future<void> _openValueDialog(BuildContext context) async {
    if (!enabled || onChanged == null) {
      return;
    }
    final materialL10n = MaterialLocalizations.of(context);
    final cancelLabel = materialL10n.cancelButtonLabel;
    final confirmLabel = materialL10n.okButtonLabel;
    final result = await showHyperosSliderValueDialog(
      context: context,
      title: dialogTitle ?? title ?? valueLabel ?? 'Slider',
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      helper: dialogHelper,
    );
    if (result == null || result == value) {
      return;
    }
    onChanged!(result);
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = HyperosTypography.listDetail(context).copyWith(
      color: enabled
          ? HyperosColors.onSurfaceVariantActions(context)
          : HyperosColors.disabledOnSurface(context),
    );
    final titleStyle = HyperosTypography.listTitle(context);
    final rowEnabled = tapToEdit && enabled && onChanged != null;
    // When [title] already embeds the value (common in settings cards), only
    // show a separate trailing label when [valueLabel] is provided explicitly.
    final displayValue =
        valueLabel ??
        (title == null
            ? _hyperosSliderInputText(
                value,
                min: min,
                max: max,
                divisions: divisions,
              )
            : '');
    final row = Row(
      children: [
        if (title != null)
          Expanded(
            child: Text(
              title!,
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          const Spacer(),
        if (displayValue.isNotEmpty) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: HyperosMiuixDropdown.maxItemTextWidth,
            ),
            child: Text(
              displayValue,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
          if (rowEnabled)
            Padding(
              padding: const EdgeInsets.only(
                left: HyperosMiuixDropdown.valueEndPadding,
              ),
              child: Opacity(
                opacity: enabled ? 1 : 0.45,
                child: HyperosChevron(),
              ),
            ),
        ] else if (rowEnabled)
          HyperosChevron(),
      ],
    );

    return Padding(
      padding: _hyperosSliderTilePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || valueLabel != null || rowEnabled) ...[
            if (rowEnabled)
              HyperosPressableRow(
                onTap: () => _openValueDialog(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: row,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: row,
              ),
            const SizedBox(height: 8),
          ],
          HyperosSlider(
            value: value,
            onChanged: onChanged,
            min: min,
            max: max,
            divisions: divisions,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

enum HyperosButtonVariant { primary, secondary, destructive }

/// Miuix-styled button (primary / secondary / destructive).
class HyperosButton extends StatelessWidget {
  const HyperosButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HyperosButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.dense = false,
    this.fitLabel = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final HyperosButtonVariant variant;
  final bool loading;
  final bool expand;

  /// Tighter padding and scaled label for grid / chip-like layouts.
  final bool dense;

  /// Scale label down to fit one line inside narrow buttons (e.g. side-by-side).
  final bool fitLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    final (bg, fg, disabledBg, disabledFg) = switch (variant) {
      HyperosButtonVariant.primary => (
        HyperosColors.primary(context),
        HyperosColors.onPrimary(context),
        HyperosColors.disabledPrimaryButton(context),
        HyperosColors.disabledOnPrimaryButton(context),
      ),
      HyperosButtonVariant.secondary => (
        HyperosColors.secondary(context),
        HyperosColors.onSecondaryVariant(context),
        HyperosColors.disabledSecondary(context),
        HyperosColors.disabledOnSecondaryVariant(context),
      ),
      HyperosButtonVariant.destructive => (
        HyperosColors.error(context),
        HyperosColors.onError(context),
        HyperosColors.disabledSecondaryVariant(context),
        HyperosColors.disabledOnSecondaryVariant(context),
      ),
    };

    final labelStyle = TextStyle(
      fontSize: dense
          ? HyperosMiuixTypography.footnote1
          : HyperosMiuixTypography.button,
      color: enabled ? fg : disabledFg,
      fontWeight: dense ? FontWeight.w600 : FontWeight.w400,
      height: 1.1,
    );

    final Widget labelChild = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: enabled ? fg : disabledFg,
            ),
          )
        : (dense || fitLabel)
        ? FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: labelStyle,
            ),
          )
        : Text(label, style: labelStyle);

    final minHeight = dense ? 36.0 : HyperosMiuixButton.minHeight;
    final cornerRadius = HyperosRadius.clampCornerRadius(
      HyperosMiuixButton.cornerRadius,
      minHeight,
    );

    final button = Material(
      color: enabled ? bg : disabledBg,
      borderRadius: BorderRadius.circular(cornerRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: dense ? 0 : HyperosMiuixButton.minWidth,
            minHeight: minHeight,
          ),
          child: Padding(
            padding: dense
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                : HyperosMiuixButton.insideMargin,
            child: Center(child: labelChild),
          ),
        ),
      ),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Tappable control on frosted home sheets — nested [HyperosFrostedSurface]
/// stays visible over the panel (flat [HyperosButtonVariant.secondary] does not).
class HyperosFrostedSheetButton extends StatelessWidget {
  const HyperosFrostedSheetButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.dense = false,
    this.bordered = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final bool dense;

  /// Outline for full-width bar actions; grid tiles match course detail cards.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = enabled
        ? HyperosColors.onSecondaryVariant(context)
        : HyperosColors.disabledOnSecondaryVariant(context);
    final outline = HyperosColors.outline(context);
    final radius = BorderRadius.circular(HyperosMiuixButton.cornerRadius);
    final fontSize = dense
        ? HyperosMiuixTypography.footnote1
        : HyperosMiuixTypography.button;

    final labelChild = dense
        ? FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          )
        : Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          );

    final button = HyperosFrostedSurface(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          borderRadius: radius,
          child: Ink(
            decoration: bordered
                ? BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: outline),
                  )
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: dense ? 0 : HyperosMiuixButton.minWidth,
                minHeight: dense ? 36 : HyperosMiuixButton.minHeight,
              ),
              child: Padding(
                padding: dense
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                    : HyperosMiuixButton.insideMargin,
                child: Center(child: labelChild),
              ),
            ),
          ),
        ),
      ),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
