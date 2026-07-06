import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';

/// Marks descendants inside [HyperosControlCard] so full-bleed rows (e.g.
/// [HyperosSelectTile]) can extend their press highlight to the card edge.
class HyperosControlCardScope extends InheritedWidget {
  const HyperosControlCardScope({
    super.key,
    required this.horizontalPadding,
    required super.child,
  });

  static const defaultHorizontalPadding = 16.0;

  final double horizontalPadding;

  static HyperosControlCardScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosControlCardScope>();
  }

  @override
  bool updateShouldNotify(HyperosControlCardScope oldWidget) {
    return horizontalPadding != oldWidget.horizontalPadding;
  }
}

/// White card for sliders, button groups, and custom controls (Miuix Card +
/// preference section layout).
class HyperosControlCard extends StatelessWidget {
  const HyperosControlCard({
    super.key,
    this.title,
    this.subtitle,
    this.plainTitle = false,
    this.strip = false,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final bool plainTitle;

  /// Stadium outline for child-only status rows (e.g. connected account strip).
  final bool strip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasHeader =
        (title != null && title!.isNotEmpty) || (subtitle != null);
    final useStrip = strip && !hasHeader;

    return Material(
      color: HyperosColors.card(context),
      shape: useStrip ? HyperosTheme.stripShape() : HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: HyperosControlCardScope(
        horizontalPadding: useStrip
            ? HyperosMiuixSpec.settingsRowPadding.left
            : HyperosControlCardScope.defaultHorizontalPadding,
        child: Padding(
          padding: useStrip
              ? HyperosTokens.rowPaddingUniform
              : const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: useStrip
              ? ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: HyperosTokens.listRowMinHeight,
                  ),
                  child: Align(alignment: Alignment.centerLeft, child: child),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasHeader) ...[
                      if (title != null && title!.isNotEmpty)
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: HyperosMiuixTypography.body2,
                            fontWeight: plainTitle
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: HyperosColors.primaryText(context),
                          ),
                        ),
                      if (subtitle != null) ...[
                        if (title != null && title!.isNotEmpty)
                          const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: HyperosTypography.sectionDescription(context),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    child,
                  ],
                ),
        ),
      ),
    );
  }
}

/// HyperOS / Miuix-styled slider (track + thumb colors and 28dp touch height).
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;
    final inactive = isDark
        ? HyperosMiuixDarkColors.sliderBackground
        : HyperosMiuixLightColors.sliderBackground;
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
          trackHeight: 4,
          activeTrackColor: enabled ? active : disabledActive,
          inactiveTrackColor: inactive,
          thumbColor: enabled ? thumb : disabledThumb,
          disabledActiveTrackColor: disabledActive,
          disabledInactiveTrackColor: inactive,
          disabledThumbColor: disabledThumb,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 10,
            disabledThumbRadius: 10,
          ),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

/// Title + optional value label + [HyperosSlider] (Miuix `SliderPreference`).
class HyperosSliderTile extends StatelessWidget {
  const HyperosSliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.valueLabel,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.enabled = true,
  });

  final String title;
  final String? valueLabel;
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final labelStyle = HyperosTypography.listDetail(context);
    final titleStyle = HyperosTypography.listTitle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: titleStyle)),
            if (valueLabel != null) Text(valueLabel!, style: labelStyle),
          ],
        ),
        const SizedBox(height: 8),
        HyperosSlider(
          value: value,
          onChanged: onChanged,
          min: min,
          max: max,
          divisions: divisions,
          enabled: enabled,
        ),
      ],
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
  });

  final String label;
  final VoidCallback? onPressed;
  final HyperosButtonVariant variant;
  final bool loading;
  final bool expand;

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

    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: enabled ? fg : disabledFg,
            ),
          )
        : Text(
            label,
            style: TextStyle(
              fontSize: HyperosMiuixTypography.button,
              color: enabled ? fg : disabledFg,
            ),
          );

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
          constraints: const BoxConstraints(
            minWidth: HyperosMiuixButton.minWidth,
            minHeight: HyperosMiuixButton.minHeight,
          ),
          child: Padding(
            padding: HyperosMiuixButton.insideMargin,
            child: Center(child: child),
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
