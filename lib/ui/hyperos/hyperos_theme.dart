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

  static TextStyle listDetail(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.listDetailSize,
      fontWeight: FontWeight.w400,
      color: HyperosColors.secondaryText(context),
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

  static TextStyle sectionDescription(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.sectionDescriptionSize,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: HyperosColors.secondaryText(context),
    );
  }

  /// Large title on bottom sheets (e.g. memory-extension picker).
  static TextStyle sheetTitle(BuildContext context) =>
      title(context).copyWith(height: 1.2);

  /// Summary card primary line.
  static TextStyle summaryTitle(BuildContext context) => title(context);

  /// Summary card secondary line (Miuix footnote1 + onSurfaceVariantSummary).
  static TextStyle summarySubtitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: HyperosMiuixTypography.footnote1,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: isDark
          ? HyperosMiuixDarkColors.onSurfaceVariantSummary
          : HyperosMiuixLightColors.onSurfaceVariantSummary,
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
