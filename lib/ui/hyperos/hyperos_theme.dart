import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_tokens.dart';

/// Resolves HyperOS palette values for light / dark and Forui themes.
abstract final class HyperosColors {
  static Brightness _brightness(BuildContext context) =>
      Theme.of(context).brightness;

  static FColors _colors(BuildContext context) => context.theme.colors;

  static Color scaffoldBackground(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? _colors(context).background
        : HyperosTokens.background;
  }

  static Color card(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? _colors(context).card
        : HyperosTokens.card;
  }

  static Color primaryText(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? _colors(context).foreground
        : HyperosTokens.primaryText;
  }

  static Color secondaryText(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? _colors(context).mutedForeground
        : HyperosTokens.secondaryText;
  }

  /// Miuix `onSurfaceVariantActions` — chevrons and tertiary actions.
  static Color actionIcon(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? _colors(context).mutedForeground
        : HyperosTokens.actionIcon;
  }

  static Color rowHighlight(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? _colors(context).secondary
        : HyperosTokens.pressed;
  }

  /// Miuix preference category caption (e.g. 预设主题 / 权限管控).
  static Color sectionLabel(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurfaceVariantActions
        : HyperosTokens.sectionLabelColor;
  }

  // --- PR3: 新增语义颜色 ---

  /// Primary accent color (buttons, active indicators).
  static Color primary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;
  }

  /// Surface container for sheets, popups, toolbars.
  static Color surfaceContainer(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainer
        : HyperosMiuixLightColors.surfaceContainer;
  }

  /// Highest surface container for elevated elements.
  static Color surfaceContainerHighest(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainerHighest
        : HyperosMiuixLightColors.surfaceContainerHighest;
  }

  /// Error / destructive color.
  static Color error(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.error
        : HyperosMiuixLightColors.error;
  }

  /// On-error color (text/icon on error background).
  static Color onError(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onError
        : HyperosMiuixLightColors.onError;
  }

  /// Outline / divider color.
  static Color outline(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.outline
        : HyperosMiuixLightColors.outline;
  }

  /// Divider line color.
  static Color dividerLine(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.dividerLine
        : HyperosMiuixLightColors.dividerLine;
  }

  /// Slider background color.
  static Color sliderBackground(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.sliderBackground
        : HyperosMiuixLightColors.sliderBackground;
  }

  /// On-surface color (text on surface).
  static Color onSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurface
        : HyperosMiuixLightColors.onSurface;
  }

  /// Window dimming color for modal barriers.
  static Color windowDimming(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.windowDimming
        : HyperosMiuixLightColors.windowDimming;
  }

  // --- State / surface role colors (Miuix light/dark) ---

  static Color secondary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.secondary
        : HyperosMiuixLightColors.secondary;
  }

  static Color onPrimary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onPrimary
        : HyperosMiuixLightColors.onPrimary;
  }

  static Color onSecondary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSecondary
        : HyperosMiuixLightColors.onSecondary;
  }

  static Color secondaryContainer(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.secondaryContainer
        : HyperosMiuixLightColors.secondaryContainer;
  }

  static Color secondaryVariant(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.secondaryVariant
        : HyperosMiuixLightColors.secondaryVariant;
  }

  static Color onBackground(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onBackground
        : HyperosMiuixLightColors.onBackground;
  }

  static Color onSurfaceVariantSummary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurfaceVariantSummary
        : HyperosMiuixLightColors.onSurfaceVariantSummary;
  }

  static Color onSurfaceVariantActions(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurfaceVariantActions
        : HyperosMiuixLightColors.onSurfaceVariantActions;
  }

  static Color surface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surface
        : HyperosMiuixLightColors.surface;
  }

  static Color surfaceContainerHigh(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainerHigh
        : HyperosMiuixLightColors.surfaceContainerHigh;
  }

  /// Elevated panel background for snackbar / floating toolbar / tooltip.
  ///
  /// Asymmetric by design: dark uses [surfaceContainerHighest], light uses
  /// [surfaceContainer] (or onSurface for inverse tooltips — see
  /// [inverseSurface]).
  static Color elevatedSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainerHighest
        : HyperosMiuixLightColors.surfaceContainer;
  }

  /// Inverse surface for tooltips / snackbars that sit on dark text in light mode.
  ///
  /// Dark: [surfaceContainerHighest]; light: [onSurface] (dark panel).
  static Color inverseSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainerHighest
        : HyperosMiuixLightColors.onSurface;
  }

  /// Text/icon color on [inverseSurface].
  static Color onInverseSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurface
        : HyperosMiuixLightColors.onPrimary;
  }

  // --- Disabled role colors ---

  static Color disabledPrimary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledPrimary
        : HyperosMiuixLightColors.disabledPrimary;
  }

  static Color disabledSecondary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledSecondary
        : HyperosMiuixLightColors.disabledSecondary;
  }

  static Color disabledOnPrimary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnPrimary
        : HyperosMiuixLightColors.disabledOnPrimary;
  }

  static Color disabledOnSecondary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnSecondary
        : HyperosMiuixLightColors.disabledOnSecondary;
  }

  static Color disabledPrimaryButton(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledPrimaryButton
        : HyperosMiuixLightColors.disabledPrimaryButton;
  }

  static Color disabledOnPrimaryButton(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnPrimaryButton
        : HyperosMiuixLightColors.disabledOnPrimaryButton;
  }

  static Color disabledPrimarySlider(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledPrimarySlider
        : HyperosMiuixLightColors.disabledPrimarySlider;
  }

  static Color disabledOnSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnSurface
        : HyperosMiuixLightColors.disabledOnSurface;
  }

  static Color onSecondaryVariant(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSecondaryVariant
        : HyperosMiuixLightColors.onSecondaryVariant;
  }

  static Color disabledSecondaryVariant(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledSecondaryVariant
        : HyperosMiuixLightColors.disabledSecondaryVariant;
  }

  static Color disabledOnSecondaryVariant(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnSecondaryVariant
        : HyperosMiuixLightColors.disabledOnSecondaryVariant;
  }

  /// Status bar icons/background aligned to a solid page or header color.
  static SystemUiOverlayStyle systemOverlayForBackground(Color background) {
    final light = background.computeLuminance() > 0.5;
    return SystemUiOverlayStyle(
      statusBarColor: background,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
    );
  }
}

abstract final class HyperosTypography {
  /// Canonical settings title — list rows, card headers, page/sheet/dialog titles.
  static TextStyle title(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.titleSize,
      fontWeight: FontWeight.w400,
      color: HyperosColors.primaryText(context),
      height: 1.25,
    );
  }

  static TextStyle listTitle(BuildContext context) => title(context);

  /// Preference row helper / trailing summary — same ink as [title] (not muted).
  static TextStyle listDetail(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.listDetailSize,
      fontWeight: FontWeight.w400,
      color: HyperosColors.primaryText(context),
    );
  }

  /// Miuix preference category caption above list groups (e.g. 预设主题).
  static TextStyle sectionLabel(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.sectionLabelSize,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: HyperosColors.sectionLabel(context),
    );
  }

  /// Footnote under list groups — same ink as [title] for readability.
  static TextStyle sectionDescription(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.sectionDescriptionSize,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: HyperosColors.primaryText(context),
    );
  }

  /// Large title on bottom sheets (e.g. memory-extension picker).
  static TextStyle sheetTitle(BuildContext context) =>
      title(context).copyWith(height: 1.2);

  /// Summary card primary line.
  static TextStyle summaryTitle(BuildContext context) => title(context);

  /// Summary card secondary line — same ink as [title].
  static TextStyle summarySubtitle(BuildContext context) {
    return TextStyle(
      fontSize: HyperosMiuixTypography.footnote1,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: HyperosColors.primaryText(context),
    );
  }
}

abstract final class HyperosTheme {
  /// Pressed overlay for list rows — Material 3 ignores [InkWell.highlightColor].
  static WidgetStateProperty<Color?> rowPressOverlay(Color pressed) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return pressed;
      }
      return null;
    });
  }

  static BorderRadius get cardBorderRadius =>
      BorderRadius.circular(HyperosTokens.cardRadius);

  /// Squircle card used by settings list groups (HyperOS measured 24dp).
  static ShapeBorder cardShape() {
    return RoundedSuperellipseBorder(
      borderRadius: cardBorderRadius,
      side: BorderSide.none,
    );
  }

  /// Stadium outline for single-line account / status strips.
  static ShapeBorder stripShape() {
    return const StadiumBorder(side: BorderSide.none);
  }

  static FCardStyleDelta cardStyle(
    BuildContext context, {
    required Color cardColor,
  }) {
    return FCardStyleDelta.delta(
      decoration: DecorationDelta.shapeDelta(
        color: cardColor,
        shape: cardShape(),
      ),
    );
  }

  /// Header content style for pages that wrap [FHeader] in
  /// [HyperosBlurredHeaderShell] (blur + tint live on the shell).
  static FHeaderStyleDelta nestedHeaderStyle(BuildContext context) {
    final appFont = DefaultTextStyle.of(context).style;
    return FHeaderStyleDelta.delta(
      decoration: DecorationDelta.boxDelta(color: Colors.transparent),
      backgroundFilter: null,
      titleTextStyle: TextStyleDelta.delta(
        fontSize: HyperosTokens.nestedHeaderTitleSize,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: HyperosColors.primaryText(context),
        fontFamily: appFont.fontFamily,
        fontFamilyFallback: appFont.fontFamilyFallback,
      ),
      padding: EdgeInsetsGeometryDelta.value(
        const EdgeInsets.fromLTRB(4, 0, 4, 4),
      ),
      constraints: const BoxConstraints(minHeight: 44),
      actionStyle: FHeaderActionStyleDelta.delta(
        iconStyle: FVariantsDelta.delta([
          FVariantOperation.all(
            IconThemeDataDelta.delta(
              size: HyperosTokens.nestedHeaderBackIconSize,
            ),
          ),
        ]),
      ),
    );
  }
}
