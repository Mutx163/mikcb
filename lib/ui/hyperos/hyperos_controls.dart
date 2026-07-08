import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_text_field.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';

/// Marks descendants inside [HyperosControlCard].
///
/// The card body is edge-to-edge; interactive rows apply [HyperosTokens.rowPaddingUniform]
/// themselves. Non-row blocks should wrap in [HyperosControlCardInset].
class HyperosControlCardScope extends InheritedWidget {
  const HyperosControlCardScope({
    super.key,
    required this.hasHeader,
    required this.bodyBottomInset,
    required this.cornerRadius,
    required super.child,
  });

  static const defaultHorizontalPadding = 16.0;

  /// Extra bottom inset absorbed by the last full-bleed row (replaces outer card
  /// padding so press highlight can reach the card's rounded bottom edge).
  static const defaultBodyBottomInset = 12.0;

  /// Whether [HyperosControlCard] rendered a title/subtitle block above [child].
  final bool hasHeader;
  final double bodyBottomInset;
  final double cornerRadius;

  static HyperosControlCardScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosControlCardScope>();
  }

  @override
  bool updateShouldNotify(HyperosControlCardScope oldWidget) {
    return hasHeader != oldWidget.hasHeader ||
        bodyBottomInset != oldWidget.bodyBottomInset ||
        cornerRadius != oldWidget.cornerRadius;
  }
}

/// Positions a full-bleed row inside [HyperosControlCard] (first/last padding).
class HyperosControlCardRowScope extends InheritedWidget {
  const HyperosControlCardRowScope({
    super.key,
    required this.isFirst,
    required this.isLast,
    required super.child,
  });

  final bool isFirst;
  final bool isLast;

  static HyperosControlCardRowScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosControlCardRowScope>();
  }

  @override
  bool updateShouldNotify(HyperosControlCardRowScope oldWidget) {
    return isFirst != oldWidget.isFirst || isLast != oldWidget.isLast;
  }
}

/// Stacks multiple full-bleed rows inside one [HyperosControlCard].
class HyperosControlCardRows extends StatelessWidget {
  const HyperosControlCardRows({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          HyperosControlCardRowScope(
            isFirst: i == 0,
            isLast: i == children.length - 1,
            child: children[i],
          ),
      ],
    );
  }
}

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
      child: Material(
        color: HyperosColors.card(context),
        shape: useStrip ? HyperosTheme.stripShape() : HyperosTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: HyperosControlCardScope(
          hasHeader: hasHeader,
          bodyBottomInset: useStrip
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
                                const SizedBox(height: 2),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;
    final inactive = isDark
        ? HyperosMiuixDarkColors.sliderBackground
        : const Color(0xFFF2F2F2);
    final disabledActive = isDark
        ? HyperosMiuixDarkColors.disabledPrimarySlider
        : HyperosMiuixLightColors.disabledPrimarySlider;
    final thumb = isDark
        ? HyperosMiuixDarkColors.onPrimary
        : HyperosMiuixLightColors.onPrimary;
    final disabledThumb = isDark
        ? HyperosMiuixDarkColors.disabledOnPrimary
        : HyperosMiuixLightColors.disabledOnPrimary;

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
          value: value.clamp(lo, hi),
          min: lo,
          max: hi,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

EdgeInsets _hyperosSliderTilePadding(BuildContext context) {
  final cardRowScope = HyperosControlCardRowScope.maybeOf(context);
  final cardScope = HyperosControlCardScope.maybeOf(context);

  // Mirrors [hyperosSelectRowLayout]: when no explicit row scope exists but the
  // tile sits inside a [HyperosControlCard], treat it as the card's last block.
  final isLast = cardRowScope?.isLast ?? cardScope != null;

  var bottom = 0.0;
  if (cardScope != null && isLast) {
    bottom = cardScope.bodyBottomInset;
  }

  return EdgeInsets.fromLTRB(
    HyperosControlCardScope.defaultHorizontalPadding,
    0,
    HyperosControlCardScope.defaultHorizontalPadding,
    bottom,
  );
}

String _hyperosSliderInputText(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toString();
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
  return trimmed.length - dot - 1;
}

double _hyperosNormalizeSliderValue(
  double rawValue, {
  required double min,
  required double max,
  required int? divisions,
}) {
  final clamped = rawValue.clamp(min, max);
  if (divisions == null || divisions <= 0 || max <= min) {
    return clamped;
  }

  final step = (max - min) / divisions;
  final snapped = (((clamped - min) / step).round() * step) + min;
  final precision = _hyperosSliderPrecision(min, max, divisions);
  return double.parse(snapped.toStringAsFixed(precision));
}

Future<double?> showHyperosSliderValueDialog({
  required BuildContext context,
  required String title,
  required double value,
  required double min,
  required double max,
  required int? divisions,
  String? helper,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final dimming = isDark
      ? HyperosMiuixDarkColors.windowDimming
      : HyperosMiuixLightColors.windowDimming;

  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: dimming,
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
    this.helper,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
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
    _controller = TextEditingController(
      text: _hyperosSliderInputText(widget.value),
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
      setState(() => _errorText = widget.helper ?? '${widget.min} - ${widget.max}');
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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? HyperosMiuixDarkColors.surfaceContainer
        : HyperosMiuixLightColors.surfaceContainer;
    final borderColor = isDark
        ? HyperosMiuixDarkColors.outline
        : HyperosMiuixLightColors.outline;

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
                  helper: _errorText ?? widget.helper ?? '${widget.min} - ${widget.max}',
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: HyperosButton(
                        label: l10n.cancelAction,
                        variant: HyperosButtonVariant.secondary,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HyperosButton(
                        label: l10n.confirmAction,
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
    final result = await showHyperosSliderValueDialog(
      context: context,
      title: dialogTitle ?? title ?? valueLabel ?? 'Slider',
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      helper: dialogHelper,
    );
    if (result == null || result == value) {
      return;
    }
    onChanged!(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = HyperosTypography.listDetail(context).copyWith(
      color: enabled
          ? (isDark
                ? HyperosMiuixDarkColors.onSurfaceVariantActions
                : HyperosMiuixLightColors.onSurfaceVariantActions)
          : (isDark
                ? HyperosMiuixDarkColors.disabledOnSurface
                : HyperosMiuixLightColors.disabledOnSurface),
    );
    final titleStyle = HyperosTypography.listTitle(context);
    final rowEnabled = tapToEdit && enabled && onChanged != null;
    final displayValue = valueLabel ?? _hyperosSliderInputText(value);
    final row = Row(
      children: [
        if (title != null) Expanded(child: Text(title!, style: titleStyle)),
        if (displayValue.isNotEmpty) ...[
          Text(displayValue, style: labelStyle),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null && !loading;

    final (bg, fg, disabledBg, disabledFg) = switch (variant) {
      HyperosButtonVariant.primary => (
        isDark
            ? HyperosMiuixDarkColors.primary
            : HyperosMiuixLightColors.primary,
        isDark
            ? HyperosMiuixDarkColors.onPrimary
            : HyperosMiuixLightColors.onPrimary,
        isDark
            ? HyperosMiuixDarkColors.disabledPrimaryButton
            : HyperosMiuixLightColors.disabledPrimaryButton,
        isDark
            ? HyperosMiuixDarkColors.disabledOnPrimaryButton
            : HyperosMiuixLightColors.disabledOnPrimaryButton,
      ),
      HyperosButtonVariant.secondary => (
        isDark
            ? HyperosMiuixDarkColors.secondaryVariant
            : HyperosMiuixLightColors.secondaryVariant,
        isDark
            ? HyperosMiuixDarkColors.onSecondaryVariant
            : HyperosMiuixLightColors.onSecondaryVariant,
        isDark
            ? HyperosMiuixDarkColors.disabledSecondaryVariant
            : HyperosMiuixLightColors.disabledSecondaryVariant,
        isDark
            ? HyperosMiuixDarkColors.disabledOnSecondaryVariant
            : HyperosMiuixLightColors.disabledOnSecondaryVariant,
      ),
      HyperosButtonVariant.destructive => (
        isDark ? HyperosMiuixDarkColors.error : HyperosMiuixLightColors.error,
        isDark
            ? HyperosMiuixDarkColors.onError
            : HyperosMiuixLightColors.onError,
        isDark
            ? HyperosMiuixDarkColors.disabledSecondaryVariant
            : HyperosMiuixLightColors.disabledSecondaryVariant,
        isDark
            ? HyperosMiuixDarkColors.disabledOnSecondaryVariant
            : HyperosMiuixLightColors.disabledOnSecondaryVariant,
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

    final button = Material(
      color: enabled ? bg : disabledBg,
      borderRadius: BorderRadius.circular(HyperosMiuixButton.cornerRadius),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;
    final fg = enabled
        ? (isDark
              ? HyperosMiuixDarkColors.onSecondaryVariant
              : HyperosMiuixLightColors.onSecondaryVariant)
        : (isDark
              ? HyperosMiuixDarkColors.disabledOnSecondaryVariant
              : HyperosMiuixLightColors.disabledOnSecondaryVariant);
    final outline = isDark
        ? HyperosMiuixDarkColors.outline
        : HyperosMiuixLightColors.outline;
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
