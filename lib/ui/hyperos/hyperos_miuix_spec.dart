import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design constants transcribed from [Miuix](https://github.com/compose-miuix-ui/miuix)
/// (Compose Multiplatform, Apache-2.0). Canonical reference for mikcb HyperOS — not a
/// runtime dependency. We hand-port Miuix because there is no official Flutter package.
///
/// Source files (main branch, v0.9+):
/// - `miuix-ui/.../theme/Colors.kt` — `lightColorScheme()` / `darkColorScheme()`
/// - `miuix-ui/.../theme/TextStyles.kt` — `defaultTextStyles()`
/// - `miuix-ui/.../basic/*.kt` — component `*Defaults`
/// - `miuix-preference/.../preference/ArrowPreference.kt`
/// - `miuix-ui/.../layout/DialogContentLayout.kt` — `DialogDefaults`
abstract final class HyperosMiuixSpec {
  // ---------------------------------------------------------------------------
  // Backward-compatible top-level aliases (prefer nested *Spec classes in new code)
  // ---------------------------------------------------------------------------

  static const primary = HyperosMiuixLightColors.primary;
  static const surface = HyperosMiuixLightColors.surface;
  static const surfaceContainer = HyperosMiuixLightColors.surfaceContainer;
  static const onSurface = HyperosMiuixLightColors.onSurface;
  static const onSurfaceSummary =
      HyperosMiuixLightColors.onSurfaceVariantSummary;
  static const onSurfaceActions =
      HyperosMiuixLightColors.onSurfaceVariantActions;
  static const surfaceContainerHigh =
      HyperosMiuixLightColors.surfaceContainerHigh;
  static const dividerLine = HyperosMiuixLightColors.dividerLine;
  static const secondaryTrack = HyperosMiuixLightColors.secondary;
  static const disabledOnSurface = HyperosMiuixLightColors.disabledOnSurface;
  static const error = HyperosMiuixLightColors.error;
  static const windowDimming = HyperosMiuixLightColors.windowDimming;

  static const body1Size = HyperosMiuixTypography.body1;
  static const body2Size = HyperosMiuixTypography.body2;
  static const footnote1Size = HyperosMiuixTypography.footnote1;
  static const title3Size = HyperosMiuixTypography.title3;

  static const pagePadding = HyperosMiuixBasicComponent.insideMarginHorizontal;
  static const cardGroupGap = HyperosMiuixCard.groupGap;
  static const cardCornerRadius = HyperosMiuixCard.cornerRadius;
  static const listRowPadding =
      HyperosMiuixBasicComponent.insideMarginHorizontal;
  static const startActionGap = HyperosMiuixBasicComponent.startEndSpacer;
  static const endActionGap = HyperosMiuixArrowPreference.endPadding;
  static const chevronWidth = HyperosMiuixArrowPreference.width;
  static const chevronHeight = HyperosMiuixArrowPreference.height;

  static const switchWidth = HyperosMiuixSwitch.width;
  static const switchHeight = HyperosMiuixSwitch.height;
  static const switchThumbSize = HyperosMiuixSwitch.thumbSize;
  static const switchThumbOnInset = HyperosMiuixSwitch.thumbOnInset;
  static const switchThumbOffInset = HyperosMiuixSwitch.thumbOffInset;

  static const appBarIconPadding = HyperosMiuixTopAppBar.actionIconPadding;

  // ---------------------------------------------------------------------------
  // mikcb measured overrides — HyperOS 系统「设置」首页（Miuix 通用值之上）
  // ---------------------------------------------------------------------------

  static const settingsBackground = Color(0xFFF2F2F2);
  static const settingsPrimaryText = Color(0xFF333333);
  static const settingsSecondaryText = Color(0xFF999999);
  static const settingsPressed = Color(0xFFE0E0E0);
  static const settingsGroupRadius = 24.0;

  /// Category caption above settings groups (e.g. 权限管控 / 云账号) — light, small.
  static const settingsSectionLabelSize = HyperosMiuixTypography.footnote1;
  static const settingsSectionLabelColor =
      HyperosMiuixLightColors.onSurfaceVariantActions;

  /// Align category captions with text inside [HyperosListGroup] rows.
  static const settingsSectionLabelInset = 16.0;
  static const settingsSectionGap = 12.0;
  static const listPadding = EdgeInsets.fromLTRB(16, 4, 16, 24);
  static const preferenceTitleSize = 17.0;
  static const settingsRowPadding = EdgeInsets.fromLTRB(16, 13, 16, 13);
  static const settingsRowMinHeight = 56.0;

  /// Title + subtitle rows (SwitchPreference / two-line nav).
  static const settingsRowTwoLineMinHeight = 72.0;
  static const settingsIconGap = 12.0;
  static const settingsChevronWidth = 7.0;
  static const settingsChevronHeight = 11.0;
  static const settingsChevronStrokeWidth = 1.15;

  /// Alias kept for callers using the old name.
  static const settingsListPadding = listPadding;
}

// =============================================================================
// Colors.kt — lightColorScheme()
// =============================================================================

abstract final class HyperosMiuixLightColors {
  static const primary = Color(0xFF3482FF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryVariant = Color(0xFF3482FF);
  static const onPrimaryVariant = Color(0xFFAECDFF);
  static const error = Color(0xFFE94634);
  static const onError = Color(0xFFFFFFFF);
  static const success = Color(0xFF0E8043);
  static const errorContainer = Color(0xFFFDF6F4);
  static const onErrorContainer = Color(0xFF410002);
  static const disabledPrimary = Color(0xFFC2D9FF);
  static const disabledOnPrimary = Color(0xFFF3F8FF);
  static const disabledPrimaryButton = Color(0xFFC2D9FF);
  static const disabledOnPrimaryButton = Color(0xFFFFFFFF);
  static const disabledPrimarySlider = Color(0xFFB8CFF5);
  static const primaryContainer = Color(0xFF5D9BFF);
  static const onPrimaryContainer = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFE6E6E6);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryVariant = Color(0xFFF0F0F0);
  static const onSecondaryVariant = Color(0xFF303030);
  static const disabledSecondary = Color(0xFFF0F0F0);
  static const disabledOnSecondary = Color(0xFFFCFCFC);
  static const disabledSecondaryVariant = Color(0xFFF2F2F2);
  static const disabledOnSecondaryVariant = Color(0xFFB2B2B2);
  static const secondaryContainer = Color(0xFFF0F0F0);
  static const onSecondaryContainer = Color(0xFFA9A9A9);
  static const secondaryContainerVariant = Color(0xFFF0F0F0);
  static const onSecondaryContainerVariant = Color(0xFFA8A8A8);
  static const tertiaryContainer = Color(0xFFEAF2FF);
  static const onTertiaryContainer = Color(0xFF3482FF);
  static const tertiaryContainerVariant = Color(0xFFEAF2FF);
  static const background = Color(0xFFFFFFFF);
  static const onBackground = Color(0xFF000000);
  static const onBackgroundVariant = Color(0xFF8C93B0);
  static const surface = Color(0xFFF7F7F7);
  static const onSurface = Color(0xFF000000);
  static const surfaceVariant = Color(0xFFFFFFFF);
  static const onSurfaceSecondary = Color(0xCC000000);
  static const onSurfaceVariantSummary = Color(0x99000000);
  static const onSurfaceVariantActions = Color(0x66000000);
  static const disabledOnSurface = Color(0xFFB2B2B2);
  static const surfaceContainer = Color(0xFFFFFFFF);
  static const onSurfaceContainer = Color(0xFF000000);
  static const onSurfaceContainerVariant = Color(0xFF959595);
  static const surfaceContainerHigh = Color(0xFFE8E8E8);
  static const onSurfaceContainerHigh = Color(0xFFA2A2A2);
  static const surfaceContainerHighest = Color(0xFFE8E8E8);
  static const onSurfaceContainerHighest = Color(0xFF000000);
  static const outline = Color(0xFFD9D9D9);
  static const dividerLine = Color(0xFFE0E0E0);
  static const windowDimming = Color(0x4D000000); // Black @ 30%
  static const sliderKeyPoint = Color(0x4DA3B3CD);
  static const sliderKeyPointForeground = Color(0xFF6EB5FF);
  static const sliderBackground = Color(0x0F000000);
}

// =============================================================================
// Colors.kt — darkColorScheme()
// =============================================================================

abstract final class HyperosMiuixDarkColors {
  static const primary = Color(0xFF277AF7);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryVariant = Color(0xFF0073DD);
  static const onPrimaryVariant = Color(0xFF99C7F1);
  static const error = Color(0xFFF12522);
  static const onError = Color(0xFFFFFFFF);
  static const success = Color(0xFF3FD684);
  static const errorContainer = Color(0xFF2E0603);
  static const onErrorContainer = Color(0xFFFFDAD6);
  static const disabledPrimary = Color(0xFF253E64);
  static const disabledOnPrimary = Color(0xFF677993);
  static const disabledPrimaryButton = Color(0xFF253E64);
  static const disabledOnPrimaryButton = Color(0xFF677893);
  static const disabledPrimarySlider = Color(0xFF44587C);
  static const primaryContainer = Color(0xFF338FE4);
  static const onPrimaryContainer = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF505050);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryVariant = Color(0xFF434343);
  static const onSecondaryVariant = Color(0xFFD9D9D9);
  static const disabledSecondary = Color(0xFF3F3F3F);
  static const disabledOnSecondary = Color(0xFF797979);
  static const disabledSecondaryVariant = Color(0xFF404040);
  static const disabledOnSecondaryVariant = Color(0xFF707170);
  static const secondaryContainer = Color(0xFF434343);
  static const onSecondaryContainer = Color(0xFF7C7C7C);
  static const secondaryContainerVariant = Color(0xFF4F4F4F);
  static const onSecondaryContainerVariant = Color(0xFF959595);
  static const tertiaryContainer = Color(0xFF2B3B54);
  static const onTertiaryContainer = Color(0xFF4788FF);
  static const tertiaryContainerVariant = Color(0xFF505050);
  static const background = Color(0xFF242424);
  static const onBackground = Color(0xE6FFFFFF);
  static const onBackgroundVariant = Color(0xFF787E96);
  static const surface = Color(0xFF000000);
  static const onSurface = Color(0xFFF2F2F2);
  static const surfaceVariant = Color(0xFF242424);
  static const onSurfaceSecondary = Color(0xCCFFFFFF);
  static const onSurfaceVariantSummary = Color(0x80FFFFFF);
  static const onSurfaceVariantActions = Color(0x66FFFFFF);
  static const disabledOnSurface = Color(0xFF666666);
  static const surfaceContainer = Color(0xFF242424);
  static const onSurfaceContainer = Color(0xE6FFFFFF);
  static const onSurfaceContainerVariant = Color(0xFF737373);
  static const surfaceContainerHigh = Color(0xFF242424);
  static const onSurfaceContainerHigh = Color(0xFF666666);
  static const surfaceContainerHighest = Color(0xFF2D2D2D);
  static const onSurfaceContainerHighest = Color(0xFFE9E9E9);
  static const outline = Color(0xFF404040);
  static const dividerLine = Color(0xFF393939);
  static const windowDimming = Color(0x99000000); // Black @ 60%
  static const sliderKeyPoint = Color(0x4D7A8AA6);
  static const sliderKeyPointForeground = Color(0xFF5DAAFF);
  static const sliderBackground = Color(0x26FFFFFF);
}

// =============================================================================
// TextStyles.kt — defaultTextStyles()
// =============================================================================

abstract final class HyperosMiuixTypography {
  static const main = 17.0;
  static const paragraph = 17.0;
  static const paragraphLineHeightEm = 1.2;
  static const body1 = 16.0;
  static const body2 = 14.0;
  static const button = 17.0;
  static const footnote1 = 13.0;
  static const footnote2 = 11.0;
  static const headline1 = 17.0;
  static const headline2 = 16.0;
  static const subtitle = 14.0;
  static const title1 = 32.0;
  static const title2 = 24.0;
  static const title3 = 20.0;
  static const title4 = 18.0;
}

// =============================================================================
// Component.kt — BasicComponentDefaults
// =============================================================================

abstract final class HyperosMiuixBasicComponent {
  static const insideMarginHorizontal = 16.0;
  static const insideMarginVertical = 16.0;
  static const insideMargin = EdgeInsets.all(16);

  /// Floating select sheet gap above the screen bottom (excludes safe area).
  /// Slightly tighter than 2× [insideMarginHorizontal] (32) for visual balance.
  static const selectSheetBottomMargin = 24.0;

  static const minHeight = 56.0;
  static const startEndSpacer = 8.0;
  static const bottomActionGap = 8.0;
  static const endMaxWidthFraction = 0.6;
}

// =============================================================================
// ArrowPreference.kt — ArrowPreferenceDefaults
// =============================================================================

abstract final class HyperosMiuixArrowPreference {
  static const width = 10.0;
  static const height = 16.0;
  static const endPadding = 8.0;
}

// =============================================================================
// Switch.kt — dimensions & animation
// =============================================================================

abstract final class HyperosMiuixSwitch {
  static const width = 49.0;
  static const height = 28.0;
  static const thumbSize = 20.0;
  static const thumbOnInset = 25.0;
  static const thumbOffInset = 4.0;
  static const thumbPressedScale = 1.127;
  static const dragMaxOffset = 21.0;
  static const dragToggleThreshold = 10.5; // dragMaxOffset / 2

  /// spring(dampingRatio = 0.7, stiffness = 987)
  static const thumbOffsetDamping = 0.7;
  static const thumbOffsetStiffness = 987.0;

  /// spring(dampingRatio = 0.6, stiffness = 987)
  static const thumbScaleDamping = 0.6;
  static const thumbScaleStiffness = 987.0;

  /// spring(dampingRatio = 0.99, stiffness = 438.6)
  static const trackColorDamping = 0.99;
  static const trackColorStiffness = 438.6;
}

// =============================================================================
// Button.kt — ButtonDefaults
// =============================================================================

abstract final class HyperosMiuixButton {
  static const minWidth = 58.0;
  static const minHeight = 40.0;
  static const cornerRadius = 16.0;
  static const insideMarginHorizontal = 16.0;
  static const insideMarginVertical = 13.0;
  static const insideMargin = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 13,
  );
}

// =============================================================================
// Card.kt — CardDefaults
// =============================================================================

abstract final class HyperosMiuixCard {
  static const cornerRadius = 16.0;
  static const insideMargin = EdgeInsets.zero;
  static const groupGap = 16.0;
}

// =============================================================================
// Slider.kt — SliderDefaults
// =============================================================================

abstract final class HyperosMiuixSlider {
  static const minHeight = 28.0;
  static const thumbRadius = 10.0;
  static const keyPointRadius = 3.855;
  static const thumbPressedScale = 1.127;
  static const thumbKnobRadiusFactor = 0.72;
  static const thumbHitRadiusExtraFactor = 0.5;

  /// spring(dampingRatio = 0.6, stiffness = 987)
  static const thumbScaleDamping = 0.6;
  static const thumbScaleStiffness = 987.0;

  /// spring(dampingRatio = 0.9, stiffness = 1755)
  static const valueChangeDamping = 0.9;
  static const valueChangeStiffness = 1755.0;
}

// =============================================================================
// TextField.kt — TextFieldDefaults
// =============================================================================

abstract final class HyperosMiuixTextField {
  static const cornerRadius = 16.0;
  static const insideMarginHorizontal = 16.0;
  static const insideMarginVertical = 16.0;
  static const insideMargin = EdgeInsets.all(16);
  static const borderWidth = 2.0;
  static const labelFontSizeFloating = 10.0;
  static const labelFontSizeNormal = 17.0;
}

// =============================================================================
// TopAppBar.kt — TopAppBarDefaults
// =============================================================================

abstract final class HyperosMiuixTopAppBar {
  static const titlePadding = 26.0;
  static const navigationIconPadding = 16.0;
  static const actionIconPadding = 16.0;
  static const collapsedHeight = 52.0;
  static const smallCenterHeight = 50.0;
  static const largeTitleBottomPadding = 4.0;
  static const subtitleBottomPadding = 8.0;

  /// App-side addition (not from upstream Kotlin): extra breathing room
  /// between the expanded large title and the first content row. Upstream
  /// rests content at largeTitleBottomPadding + list top padding (8dp
  /// visible); design review wanted double that, so the page shell inset
  /// and the frost threshold both add this on top.
  static const largeTitleContentGap = 8.0;
}

// =============================================================================
// Frosted nested subpage header (HyperosSubpage / HyperosOverlayNestedHeader)
// =============================================================================

abstract final class HyperosMiuixNestedHeader {
  /// Centered title on blurred settings subpages (e.g. 课表设置).
  static const titleSize = 20.0;

  /// [FHeaderAction.back] glyph size on nested frosted headers.
  static const backIconSize = 24.0;
}

// =============================================================================
// SearchBar.kt — SearchBarDefaults
// =============================================================================

abstract final class HyperosMiuixSearchBar {
  static const insideMarginHorizontal = 12.0;
  static const insideMarginVertical = 0.0;
  static const inputFieldMinHeight = 45.0;
  static const inputFieldFontSize = 17.0;
  static const leadingIconStartPadding = 16.0;
  static const leadingIconEndPadding = 8.0;
  static const trailingIconStartPadding = 8.0;
  static const trailingIconEndPadding = 16.0;
  static const collapseFocusDelayMs = 100;
}

// =============================================================================
// Snackbar.kt — SnackbarDefaults
// =============================================================================

/// System HyperOS status toast (content-tight frosted rounded rect).
///
/// Calibrated against HyperOS system toast (e.g. settings "扩展功能已开启"):
/// - Milky frosted shell; **black regular** label (not primary blue / not medium).
/// - Insets are measured in **glyph units** of [messageFontSize]:
///   - horizontal: **2 字** each side
///   - vertical: **1 字** above and **1 字** below the label
///   → single-line outer height ≈ 3 字高（约 14+14+14 = 42dp，含行高略高）
/// - Sits higher than Material SnackBar (clear of home indicator / bottom chrome).
/// - Width = text + insets only (never stretch toward screen edges).
abstract final class HyperosMiuixSnackbar {
  /// System toast label size — all inset math is relative to this glyph unit.
  static const messageFontSize = 14.0;

  /// Soft round — close to system toast; not a full stadium of half-height.
  static const cornerRadius = 16.0;

  /// Left/right inset = **2 字** width each side.
  static const insideMarginHorizontal = messageFontSize * 2; // 28

  /// Top/bottom inset = **1 字** height each side (not a tight 8dp pad).
  static const insideMarginVertical = messageFontSize; // 14
  static const insideMargin = insideMarginHorizontal;

  /// Keep long toasts away from screen edges.
  static const outerPaddingHorizontal = 40.0;
  static const outerPaddingTop = 8.0;

  /// Distance above the home-indicator / safe-area bottom.
  /// System status toast sits mid-lower, not glued to the gesture bar.
  static const hostBottomPadding = 88.0;

  /// Soft max only for wrapping; short text must stay content-width.
  static const maxWidthFraction = 0.78;

  /// Regular weight — system toast is not medium/semibold.
  static const messageFontWeight = FontWeight.w400;

  /// Near-black on milky glass (system toast; independent of app theme blue).
  static const messageColor = Color(0xFF000000);

  /// Tight line box so outer height is driven by padding, not extra leading.
  static const messageLineHeight = 1.0;
  static const iconSize = 16.0;
  static const iconGap = 8.0;

  /// Stronger blur than sheets — system toast reads as dense frosted glass.
  /// Prefer [HyperosBlurredHeader.blurSigmaOf] at runtime (外观与配色).
  @Deprecated('Use HyperosBlurredHeader.blurSigmaOf(context)')
  static const blurSigma = 28.0;
  static const tintAlphaWithBlur = 0.62;
  static const tintAlphaOpaque = 0.94;

  static const actionCornerRadius = 50.0;
  static const actionInsideMarginHorizontal = 12.0;
  static const actionMinWidth = 26.0;
  static const actionMinHeight = 26.0;
  static const actionFontSize = 14.0;
  static const actionStartPadding = 12.0;
  static const dismissIconSize = 20.0;
  static const dismissStartPadding = 8.0;

  static const shadowRadius = 12.0;
  static const shadowAlpha = 0.06;
  static const shadowYOffset = 2.0;

  static const enterMs = 220;
  static const exitMs = 180;
  static const enterScale = 0.96;
  static const durationShortMs = 2000;
  static const durationLongMs = 10000;
}

// =============================================================================
// NavigationBar.kt — NavigationBarDefaults / FloatingNavigationBarDefaults
// =============================================================================

abstract final class HyperosMiuixNavigationBar {
  static const itemHeight = 64.0;
  static const iconSize = 26.0;
  static const labelFontSize = 12.0;
  static const iconTopPadding = 8.0;
  static const bottomPadding = 8.0;
  static const selectedPressedAlpha = 0.5;
  static const unselectedPressedAlpha = 0.6;
  static const unselectedAlpha = 0.4;
  static const iosBottomInset = 20.0;
  static const captionBarAnimMs = 300;
}

abstract final class HyperosMiuixFloatingNavigationBar {
  static const horizontalOutsidePadding = 36.0;
  static const shadowElevation = 1.0;
  static const horizontalPadding = 12.0;
  static const itemSpacing = 12.0;
  static const iconSize = 28.0;
  static const iconPadding = 10.0;
  static const minBarHeight = 52.0;
  static const bottomPaddingAndroid = 26.0;
  static const bottomPaddingDefault = 36.0;
  static const dividerWidth = 0.75;
  static const shadowRadius = 10.0;
  static const shadowAlpha = 0.2;
  static const selectedPressedAlpha = 0.5;
  static const unselectedPressedAlpha = 0.6;
  static const unselectedAlpha = 0.4;
}

// =============================================================================
// DialogContentLayout.kt — DialogDefaults
// =============================================================================

abstract final class HyperosMiuixDialog {
  static const maxWidth = 420.0;
  static const outsideMarginHorizontal = 12.0;
  static const outsideMarginVertical = 12.0;
  static const insideMarginHorizontal = 24.0;
  static const insideMarginVertical = 24.0;
  static const titleBottomPadding = 12.0;
  static const summaryBottomPadding = 12.0;
  static const largeScreenMinHeight = 480.0;
  static const largeScreenMinWidth = 840.0;
  static const largeScreenMaxHeightFraction = 2 / 3;
  static const largeScreenEnterScaleFrom = 0.8;
  static const dimEnterMs = 300;
  static const dimExitMs = 250;
  static const contentExitMs = 260;
  static const backGestureResetMs = 150;
  static const backProgressScaleDelta = 0.2;
  static const minBottomCornerRadius = 32.0;
}

// =============================================================================
// Sheet / dialog content insets (app-wide floating panel padding)
// =============================================================================

/// Content padding inside a floating **sheet** card (pickers, forms, menus).
///
/// Horizontal and vertical are both 16 — matches [HyperosMiuixBasicComponent]
/// and the default [HyperosSheet] / [HyperosSheetFrame] padding.
///
/// Do **not** invent a third horizontal value (12 / 20 / 10) on sheet shells;
/// use this token (or omit `padding` to take the default).
abstract final class HyperosSheetContentInsets {
  static const double horizontal = 16;
  static const double vertical = 16;

  /// Default sheet body padding: 16 on all sides.
  static const EdgeInsets content = EdgeInsets.all(horizontal);
}

/// Content padding inside a floating **dialog** card (confirm / alert).
///
/// Horizontal and vertical are both 24 — matches [HyperosMiuixDialog]
/// `insideMargin*` from Miuix `DialogDefaults`.
abstract final class HyperosDialogContentInsets {
  static const double horizontal = HyperosMiuixDialog.insideMarginHorizontal;
  static const double vertical = HyperosMiuixDialog.insideMarginVertical;

  /// Default dialog body padding: 24 on all sides.
  static const EdgeInsets content = EdgeInsets.all(horizontal);
}

// =============================================================================
// TabRow.kt — TabRowDefaults
// =============================================================================

abstract final class HyperosMiuixTabRow {
  static const height = 42.0;
  static const contourHeight = 45.0;
  static const cornerRadius = 12.0;
  static const contourCornerRadius = 8.0;
  static const minWidth = 76.0;
  static const contourMinWidth = 62.0;
  static const maxWidth = 98.0;
  static const contourMaxWidth = 84.0;
  static const itemSpacing = 9.0;
  static const contourItemSpacing = 5.0;
  static const contourPadding = 5.0;
  static const itemHorizontalPadding = 12.0;
  static const unselectedBorderWidth = 1.0;
  static const indicatorAnimMs = 200;
}

// =============================================================================
// Dropdown.kt — DropdownDefaults (ArrowUpDown + popup padding)
// =============================================================================

abstract final class HyperosMiuixDropdown {
  static const arrowWidth = 8.0;
  static const arrowHeight = 16.0;

  /// Vertical gap between ^ and v strokes (~half body2 character).
  static const arrowChevronGap = HyperosMiuixTypography.body2 / 2;

  static const checkIconSize = 20.0;
  static const insideHorizontalPadding = 20.0;
  static const dialogHorizontalPadding = 28.0;
  static const firstLastVerticalPadding = 20.0;
  static const middleVerticalPadding = 12.0;
  static const maxItemTextWidth = 216.0;

  /// Extra popup width extending left (~4 list-title characters).
  ///
  /// Anchored select popup is right-aligned; this grows the max/min width so
  /// the left edge moves further left without shifting the right edge.
  static const popupExtraLeadingWidth =
      HyperosMiuixSpec.preferenceTitleSize * 4;

  /// 弹层圆角（MiuiX 下拉弹窗规范）。
  ///
  /// 这是**形状**规范，实底 / 液态 / 柔光三种材质共用，不随材质变化——
  /// 改这里会让所有材质的弹层一起变形。材质只管雾面、底色、透镜，不管形状。
  static const popupCornerRadius = 20.0;
  static const popupElevation = 6.0;
  static const popupVerticalGap = 2.0;

  /// Gap between trailing value text and [HyperosUpDownChevron] (~half body2).
  static const valueEndPadding = arrowChevronGap;
}

// =============================================================================
// Checkbox.kt — CheckboxDefaults (size)
// =============================================================================

abstract final class HyperosMiuixCheckbox {
  static const size = 26.0;
  static const viewportSize = 23.0;
  static const strokeWidthFactor = 0.09;
  static const colorAnimMs = 300;
  static const checkAnimMs = 200;
  static const sinkAmount = 0.85;
  static const sinkDamping = 0.99;
  static const sinkStiffness = 986.96;
}

// =============================================================================
// IconButton.kt — IconButtonDefaults
// =============================================================================

abstract final class HyperosMiuixIconButton {
  static const minWidth = 40.0;
  static const minHeight = 40.0;
  static const cornerRadius = 40.0;
}

// =============================================================================
// NumberPicker.kt — NumberPickerDefaults
// =============================================================================

abstract final class HyperosMiuixNumberPicker {
  static const itemHeight = 45.0;
  static const defaultVisibleItemCount = 5;
  static const minVisibleItemCount = 3;
  static const selectedScaleMin = 0.8;
  static const snapDamping = 1.0;
  static const snapStiffness = 400.0;
  static const frictionMultiplier = 2.0;
}

// =============================================================================
// Divider.kt — DividerDefaults
// =============================================================================

abstract final class HyperosMiuixDivider {
  static const thickness = 0.75;
}

// =============================================================================
// FloatingToolbar.kt — FloatingToolbarDefaults
// =============================================================================

abstract final class HyperosMiuixFloatingToolbar {
  static const cornerRadius = 50.0;
  static const outsidePaddingHorizontal = 12.0;
  static const outsidePaddingVertical = 8.0;
  static const defaultShadowElevation = 4.0;
  static const shadowRadius = 10.0;
  static const shadowAlpha = 0.1;
  static const dividerWidth = 0.75;
}

// =============================================================================
// SettingsTransitionHelper.java — AOSP Settings shared-axis X transition
// =============================================================================

abstract final class HyperosMiuixNavigation {
  /// AOSP「设置」基准时长：当年按「上一个默认值在 1.5× 用户速度下」反推
  /// （450ms ÷ 1.5 = 300ms）。
  ///
  /// 2026-10-16 起**不再是页面转场的实际基准**——转场改用官方 miuix-nav 口径的
  /// [programmaticDurationMs]（500ms）。这里保留 300ms 是因为它仍是另一套参照系：
  /// 启动画面 [kSplashEntranceMs] 用它同族的量级，且回退旧转场时要用回它。
  static const transitionDurationMs = 300;

  /// [SettingsTransitionHelper.FADE_THROUGH_THRESHOLD]
  static const fadeThroughThreshold = 0.22;

  /// Fraction of screen width the outgoing page slides left.
  static const exitSlideFraction = 0.25;

  /// Android [R.interpolator.fast_out_extra_slow_in]
  static const transitionCurve = Cubic(0.05, 0, 0.133333, 1);

  /// Fallback when [RoundedCorner] is unavailable (typical Xiaomi display).
  static const pageCornerRadiusFallback = 28.0;

  // ---------------------------------------------------------------------------
  // miuix-nav — `NavTransitions.MiuixDefault` + `NavDisplayEffects.Default`
  // （官方 Compose Multiplatform 的导航运行时；见 docs/zh_CN/guide/miuix-nav.md）
  // ---------------------------------------------------------------------------

  /// [NavDriverSpec.PROGRAMMATIC_DURATION_MILLIS]：程序化 push / pop 的整步时长。
  ///
  /// 官方原文：与既定导航手感一致（约 500ms）的一档，且「曲线无论距离都在这个
  /// 时间里走完」——多步连推也扫在同一窗口内。**当前页面转场的实际基准。**
  static const programmaticDurationMs = 500;

  /// [NavTransitions.MiuixDefault]：被覆盖页向 leading 方向视差的屏宽比例。
  /// 与 [exitSlideFraction] 同值（25%），这里单列是为了让「官方几何」自成一组。
  ///
  /// **2026-10-17 起取 0（关掉视差），与官方 0.25 有意偏离** —— 这是「圆角底下
  /// 一直在闪」的最后一块拼图，机理与全过程见
  /// `.agents/notes/implemented/architecture/2026-10-17-nav-corner-notch-flicker.md`。
  ///
  /// 一句话：前缘圆角是被上层页面挖出的**一个 28dp 的小窗口**，它的框跟着上层页
  /// 以整屏速度扫过屏幕（这条曲线极前端就走完，峰值近 1900dp/s）。被覆盖页自己
  /// 同时按 25% 屏宽在退 —— 于是**在窗口这个参照系里，洞里的内容以 0.75 倍屏速
  /// 反向流动**。大面积的旧页这样退没人看得出（读作「旧页让开」），但透过那个
  /// 几十 dp 的洞看就成了「洞里有一卷胶片在倒着跑」：内容越密（列表、卡片、文字、
  /// 分隔线）每帧换的内容越不一样，越明显 —— 正好解释用户的
  /// 「天气页、小组件页这些内容比较多的情况，或者在圆角底下在闪烁，很明显」。
  ///
  /// 取 0 后：旧页在屏幕坐标里**完全不动**，洞口再扫过它时只是「上层页面的形状
  /// 从静止背景上划过去」—— 洞里的像素与它左边的同一帧、同一个位置、同一条压暗
  /// 公式，全局只有上层页面这一个运动参照，读作干净的「盖上去 + 背景变暗」。
  ///
  /// 代价（已知且有意的）：旧页不再「让开 25%」，官方那点轻微后退感没了。想找回
  /// 后退感只能回到一个有反流的视差（任何 <0.9 的取值，窗口里的相对流速都还是
  /// 几百 dp/s），也就是把这个闪烁一起找回来 —— 所以这里是二选一，不是调参。
  /// 视差补底（[HyperosNavigation.parallaxBleedWidth]）保持恒挂不动：红线要求
  /// 转场子树形状恒定，且它在视差为 0 时本来就不可能被露出来。
  static const coveredParallaxFraction = 0.0;

  /// [NavTransitions.MiuixDefault]：被覆盖页的透明度衰减上限（1 - 0.1 × 覆盖度）。
  static const coveredAlphaFalloff = 0.1;

  /// [NavDisplayEffects.Default.dimAmount]：最顶层之下全屏压暗遮罩的最大 alpha。
  ///
  /// 2026-10-17 第三轮曾把它改成「平方根提前起势」（`scrimRampExponent = 0.5`），
  /// 理由写在 [HyperosNavigation.scrimAlphaFor] 的注释里；当晚用户第四轮反馈
  /// 「跟底色都没有任何关系，就是新页面的圆角」把那条机理否掉，改动已撤回
  ///（[HyperosNavigation.scrimAlphaFor] 回到这条线性口径）。机理与撤回经过见
  /// `.agents/notes/implemented/bug-fix/2026-10-17-nav-corner-notch-flicker.md`。
  static const dimAmount = 0.5;

  /// 前缘两角圆角裁切（官方 `NavDisplayEffects` 那条「跟设备屏幕圆角」的口径）。
  ///
  /// 官方默认：`enableCornerClip = true` + `cornerClipMode = Leading`（只裁**与屏幕
  /// 边缘相接的前缘角**，LTR = 左两角），`cornerClipRadius` 默认 `0.dp` 不裁，
  /// 跟屏幕圆角要显式传 `rememberNavSystemCornerRadius()`。mikcb 要 MIUI 那种
  /// 「页面带圆角滑进来」的观感，所以按后者取值（半径见 [pageCornerRadiusFallback]
  /// 与设备读数）。
  ///
  /// 切口里**不补任何颜色**（露出来的就是被覆盖页自己的像素）── 这是试错两轮后的
  /// 结论，后人别再加回去：
  /// * 深色定值（页面底色压暗 0.6，想当「角阴影」）：真机读成「一个黑色的方角」，
  ///   页面那条弧边淹没在暗色里 = 圆角像没了。用户原话「闪烁的区域显示黑色不透明的
  ///   闪烁，反复出现圆角消失圆角」。
  /// * 页面底色本身、画在压暗遮罩之下（想与背景逐帧同色）：**颜色仍然对不上**
  ///   —— 旁边不是页面背景，而是被覆盖页的**内容**（卡片、文字、分隔线，且随视差
  ///   平移在变）。用户原话「圆角底下那加的阴影，和页面左边的阴影，颜色为什么不是
  ///   完全一致的，看起来很明显」。
  ///
  /// 根因是结构性的：切口就在被覆盖页那一层里挖出来的洞，**旁边是什么颜色取决于
  /// 当时划到哪个内容**，任何一块与位置无关的定值都必然在某一刻对不上。唯一能保证
  /// 「逐帧同色」的做法就是什么都不画 —— 洞后面的像素本来就是同一层、同一条压暗
  /// 公式，与旁边天然一致。
  static const clipLeadingCornersWhileMoving = true;

  /// 圆角在「接近停稳」那一段里连续收掉的带宽（按缓动后的进度算）。
  ///
  /// 官方是二值开关（`-1 < d < 0` 才裁，停稳即不裁）：在真机上撤裁切发生在屏幕
  /// 圆角被面板遮住的区域，所以看不出。我们实测看得很清楚 —— 切口里露的是旧页，
  /// 页面一停稳这块**一帧之内**换成新页背景，对比很强，读作「圆角闪现」。故把半径
  /// 在末段按 [HyperosNavigation.transitionCornerRadiusFactor] 连续收到 0。
  ///
  /// **单位含义（选值的主要依据）**：带宽是**缓动后进度**，而上层页面离落点的距离
  /// 正是 `(1 - 进度) × 屏宽` —— 所以「带宽」同时就是**起步时页面离落点还剩多少屏宽**。
  ///
  /// 取值 `0.004`：400dp 屏上约 **1.6px**（320dp 屏 1.3px、480dp 屏 1.9px）才起步。
  /// 换句话说，肉眼看它**已经贴边**之后才收，符合用户口径「应该在贴边以后再变」。
  ///
  /// 反面教材（2026-10-16 真机）：这版之前取的是 `0.03`（12px）。看着像小数目，
  /// 实则错得远 —— 这条曲线极前端就走完（实测 `t=0.9` 时已完成 99.84%），
  /// 「离落点 3% 屏宽」提早到**整场 62% 的时刻**（≈310ms）就发生，于是半径在页面
  /// 还差 12px 没贴边时就一路缩了 190ms。用户原话：「圆角在还没有完全贴边的时候，
  /// 圆角角度就开始变化，让我都看出来了，很丑，应该在贴边以后再变」。
  /// 改到 `0.004` 后，收束只占最后约 85ms（`t≈0.83 → 1`），页面此时已在 1.6px 内。
  ///
  /// 设 0 退回官方那套二值行为（只在端点收掉），留作对照旋钮。
  static const cornerClipSettleBand = 0.004;

  /// 末段「释放」带宽：与 [cornerClipSettleBand] **同值**（有意固定为同一段）。
  ///
  /// 语义：被覆盖页的压暗（[dimAmount]）与透明度衰减（[coveredAlphaFalloff]）
  /// 在这一段里连续放掉，回到「未被覆盖」的原色。
  ///
  /// 为什么必须跟圆角收束同一段（2026-10-17 真机：掉帧治好后残留的
  /// 「圆角底部还是在闪烁成无圆角的状态」）：
  /// * 切口是上层页面挖出的洞，洞在贴边那一段收掉时**正好落在屏幕圆角那一小块
  ///   里**，露的是被覆盖页的像素。压暗还在时（0.5 × 黑），这一块是**深色**的，
  ///   收口就等于「一块深色月牙缩没」——形状变化被高对比放大成「闪成无圆角」。
  /// * 放掉压暗后，洞里就是被覆盖页的原色。同一套页面的底色本就一致（如设置页
  ///   都是 `settingsBackground`），收口时边界两侧几乎同色，形状收掉看不出来。
  /// * 早放不行：页面还差 12px 没贴边时被覆盖页就变亮，看得出（用户 2026-10-16
  ///   否过「圆角在没贴边时就开始变」）。晚放也不行：月牙已经缩没了才发现变亮，
  ///   等于换个位置闪。所以只能同段。
  ///
  /// 这不是「补色」（补色被真机否过三轮）：全程没有往切口里画任何东西，
  /// 只是把「页面全被盖住后本来就看不见」的那层压暗提前一小段撤掉。
  /// 官方口径的 0.1 / 0.5 数值一分没改，改的只是它们在末段的包络。
  static const coveredReleaseBand = cornerClipSettleBand;

  /// 形变类转场（首页卡片形变、日视图锚点展开）的圆角收束带宽（按缓动后进度）。
  ///
  /// 语义与 [cornerClipSettleBand] 相同（带宽 = 起步收束时「离贴边还剩多少」的
  /// 比例），但形变类转场的边缘内缩不是 `(1 - 进度) × 屏宽`，而是「缩放 + 位移」
  /// 两条叠加，得分开推：
  ///
  /// 卡片形变（`_OpenOnlyContainerPageRoute`：scale 0.84→1 + 源按钮→落点位移）：
  /// 前缘两角的内缩 ≈ `0.08 × (1 - 进度) × 屏宽`（400dp 屏上满值 32dp）**加上**
  /// 位移残差 `(1 - 进度) × 源按钮离屏心距离`（首页快捷入口按钮离屏心 ≤ ~250dp）。
  /// 带宽取 `0.01`：起收时横向内缩 ≈ 0.3px、位移残差 ≈ 2.5px，已经在「贴边」里。
  /// 收束占最后 ~112ms（420ms 场）—— `easeInOutCubicEmphasized` 尾段极慢
  /// （实测 t=0.73 时才走完 99%），所以这条带宽不是「一帧跳变」。
  ///
  /// 反面教材（2026-10-17 真机）：改前是 `BorderRadius.lerp(22, 0, 进度)` 线性收，
  /// 进度 0.5 时半径只剩 11dp、0.8 时只剩 4.4dp，而页面还差十分之一屏宽没贴边。
  /// 用户原话：「页面还没有完全贴边，没有完全打开的时候，圆角就已经消失变成直角了，
  /// 时机比其他页面早多了」。
  static const morphCornerSettleBand = 0.01;

  /// 锚点展开（日视图从锚点长成整屏）的圆角收束带宽：与 [morphCornerSettleBand]
  /// 分开取，因为几何不同 —— 这条转场的面板底边内缩正好是 `(1 - 进度) × 屏高`
  /// （`heightFactor = 进度`）。取 `0.002`：850dp 屏上起收时底边还差 1.7px，
  /// 与滑动转场的 1.6px 同口径；同样落在 `easeInOutCubicEmphasized` 的慢尾里
  /// （360ms 场约占最后 ~47ms），不是一帧跳变。
  ///
  /// 改前同样是线性收（`28 × (1 - 进度)`）：进度 0.6 时半径只剩 11dp、0.8 时
  /// 5.6dp，而面板还差整屏高 20% 才落到底 —— 与 [morphCornerSettleBand] 那位
  /// 是同一句用户反馈。
  static const anchorExpandCornerSettleBand = 0.002;

  /// 页面转场的「首帧门槛」开关。
  ///
  /// 背景账（2026-10-16 真机 `[first-frame]` 探针，两轮日志）：push 动画的第一帧
  /// 同时是「新页整棵树的首次构建 + 布局 + 首次绘制」，重页面上这一帧要
  /// 200~500ms（设置首页 366ms、课程卡 204ms、外观 80ms，通用 55ms）。转场动画
  /// 跟着冻死在起点，恢复时进度按真实流逝时间直接跳到中段 —— 用户读作
  /// 「滑动到一半闪一下/瞬移」。
  ///
  /// 开启后，push 动画在新页**第一帧画完之前锁在 0**（见
  /// [_HyperosFirstFrameGateSimulation]），画完后从下一帧起跑完整
  /// [programmaticDurationMs]。构建成本一分没省（省不掉），但挪到「动画开始
  /// 之前」：感知上是「点下去 → 半拍停顿 → 顺滑滑入」，而非「滑到一半冻住」。
  static const firstFrameGateEnabled = true;

  /// 滑动转场的「重页快照滑入」开关（2026-10-17）。
  ///
  /// 背景账：首帧门槛治好了「起步冻住」，但**转场中段**的重绘帧还开着 ——
  /// 新页异步内容到位 / 列表填充 / 预览卡出图时，被缓存的页面像素作废，
  /// 每一帧都要真画整页。重页面上这些帧 50~80ms，掉帧的观感是「页面在半路
  /// 停住 → 下一帧跳到位 + 圆角收平」，用户读作「还没贴边就变直角」（真机
  /// 2026-10-17：桌面小组件页、数据备份与迁移页 —— 全 App 单帧最贵的两页）。
  ///
  /// 开启后，转场中页面以**一张快照**（自己首次出画那帧的拷贝）参与滑动，
  /// 中段再贵的重绘也只更新被冻结的真页、不动快照 —— 每帧的动画成本恒定
  /// 且便宜（合成一层图片 + 位移），跟页面轻重无关。落定瞬间摘掉快照、
  /// 换回真页：从快照出画到摘除之间真页攒下的所有重绘在这一帧一起显形。
  ///
  /// 代价与豁免见 [_MiuixNavSnapshotGate] 的说明。两页已知拍不进快照的
  /// 平台视图路由（WebView 登录页）在各自推入点显式关闭。
  static const snapshotTransitionEnabled = true;

  /// 快照「预热」点（按**缓动后**进度）：真页在快照之下先画一遍、把栅格缓存
  /// 建好，让退休换层退化成纯合成操作。
  ///
  /// 背景账（2026-10-18 真机第二轮反馈）：第七轮把退休点放在收束带起点后，
  /// 换层那一帧成了**真页的第一次整机绘制** —— 重页面上 50~80ms，正好卡在
  /// 圆角收平的 85ms 里，收平被压成一步蹦变（用户：「圆角闪现消失」）。其他
  /// 页面无缝，是因为它们的收平发生在已经缓存好的活像素上（帧帧 ~8ms）。
  ///
  /// 修法是**两段式退休**：先在 0.99（页面离终点 ~4dp、视觉速度已近零）把
  /// 真页放回屏上画一帧 —— 此刻它藏在快照底下（快照仍在上层、盖住全部像素），
  /// 重活落在「画面几乎不动」的时刻 = 不可见；到收束带起点（1 -
  /// [cornerClipSettleBand]）再撤快照 —— 换层只是「去掉一张图」的合成操作，
  /// 便宜。之后圆角收平在**已预热**的活像素上逐帧连续播放，与其他页面同一条
  /// 时间线。预热帧会把快照期间攒下的内容显形 —— 它发生在收平开始之前，
  /// 读作「内容就位」，不读作闪。
  ///
  /// 取 0.99 的几何：这条曲线尾段极缓（t=0.9 已 99.88%），0.99 之后页面残余
  /// 位移 < 0.5dp，预热帧就算掉一两帧也读不出「页面在动」。
  static const snapshotWarmupProgress = 0.99;
}

/// miuix-nav `NavProgrammaticEasing`：把欠阻尼弹簧的阶跃响应烘焙成 [Curve]，
/// 配固定时长的 tween 播放（[HyperosMiuixNavigation.programmaticDurationMs]）。
///
/// 官方注释口径：中段轻快（约 20% 时长处已走完 48%），尾段很长很缓；曲线在
/// `0..1` 内单调（首次越过 1 落在播放窗口之外），`transform(1) ≈ 0.99933`，
/// 官方靠 tween 最后一帧把这点残差收掉。Flutter 的 [CurvedAnimation] 不会替
/// 我们收尾：那 0.067% 的残留位移在 400dp 宽的页面上是 0.27px —— 正好是
/// 「停稳后右边缘露出一条缝」那类瑕疵，所以这里把末值归一化到整 1。
class HyperosMiuixNavProgrammaticCurve extends Curve {
  const HyperosMiuixNavProgrammaticCurve();

  /// 官方 `NavSettleEasing` 的 response（振荡周期，单位 = 播放时长）。
  static const response = 0.8;

  /// 官方 `NavSettleEasing` 的 damping（阻尼比；< 1 即欠阻尼）。
  static const damping = 0.95;

  static final _BakedSpringStep _step = _BakedSpringStep(
    response: response,
    damping: damping,
  );

  @override
  double transformInternal(double t) => _step.normalized(t);

  @override
  String toString() => 'HyperosMiuixNavProgrammaticCurve(response: $response, '
      'damping: $damping)';
}

/// `NavSettleEasing` 那条闭式解，在这里预先算好系数并归一化末值。
///
/// 公式（官方同款）：`x(t) = e^(r·t)·(-cos(w·t) + c2·sin(w·t)) + 1`，
/// 其中 `ω = 2π/response`、`k = ω²`、`c = damping·4π/response`、
/// `w = √(4k - c²)/2`、`r = -c/2`、`c2 = r/w`。
class _BakedSpringStep {
  _BakedSpringStep({required double response, required double damping}) {
    final omega = 2 * math.pi / response;
    final stiffness = omega * omega;
    final friction = damping * 4 * math.pi / response;
    _w = math.sqrt(4 * stiffness - friction * friction) / 2;
    _r = -friction / 2;
    _c2 = _r / _w;
    _end = raw(1);
  }

  late final double _w;
  late final double _r;
  late final double _c2;
  /// 原始公式在 t = 1 处的取值（≈0.99933），用来把整条曲线归一化到整 1。
  late final double _end;

  double raw(double t) =>
      math.exp(_r * t) * (-math.cos(_w * t) + _c2 * math.sin(_w * t)) + 1;

  double normalized(double t) => (raw(t) / _end).clamp(0.0, 1.0);
}

// =============================================================================
// SpringUtils.kt — shared spring / overscroll math
// =============================================================================

abstract final class HyperosMiuixAnim {
  static const maxFrameDeltaSeconds = 0.016;
  static const minFrameDeltaSeconds = 0.001;
  static const highVelocityThreshold = 5000.0;
  static const criticalDampingRatio = 1.0;
  static const standardSpringPeriod = 0.4;
  static const slowerSpringPeriodHighVelocity = 0.55;

  /// Max rubber-band blank gap at top/bottom, as a fraction of viewport height.
  static const maxOverscrollFraction = 0.5;

  /// Pixels of overscroll that follow the finger 1:1 before resistance ramps up.
  static const overscrollDragFreeZonePx = 16.0;

  /// Resistance curve exponent after the free zone (higher = faster falloff).
  static const overscrollDragFalloffExponent = 3.4;

  /// Minimum finger-to-content transfer ratio near the overscroll cap.
  static const overscrollDragMinTransfer = 0.05;
}
