import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';

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
    this.plainTitle = false,
    this.strip = false,
    this.edgeToEdge = false,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final bool plainTitle;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final expandedWidth =
            constraints.maxWidth + HyperosMiuixSlider.thumbRadius * 2;
        return SizedBox(
          height: HyperosMiuixSlider.minHeight,
          width: constraints.maxWidth,
          child: Transform.translate(
            offset: const Offset(-HyperosMiuixSlider.thumbRadius, 0),
            child: SizedBox(
              width: expandedWidth,
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
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: HyperosMiuixSlider.thumbRadius,
                    disabledThumbRadius: HyperosMiuixSlider.thumbRadius,
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
            ),
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final labelStyle = HyperosTypography.listDetail(context);
    final titleStyle = HyperosTypography.listTitle(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HyperosControlCardScope.defaultHorizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(child: Text(title!, style: titleStyle)),
                if (valueLabel != null) Text(valueLabel!, style: labelStyle),
              ],
            ),
            const SizedBox(height: 8),
          ] else if (valueLabel != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Text(valueLabel!, style: labelStyle),
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
  });

  final String label;
  final VoidCallback? onPressed;
  final HyperosButtonVariant variant;
  final bool loading;
  final bool expand;

  /// Tighter padding and scaled label for grid / chip-like layouts.
  final bool dense;

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
        : dense
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
