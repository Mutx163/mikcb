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

abstract final class HyperosMiuixSnackbar {
  static const cornerRadius = 16.0;
  static const insideMargin = 12.0;
  static const outerPaddingHorizontal = 12.0;
  static const outerPaddingTop = 8.0;
  static const hostBottomPadding = 12.0;
  static const minHeight = 48.0;
  static const actionCornerRadius = 50.0;
  static const actionInsideMarginHorizontal = 12.0;
  static const actionMinWidth = 26.0;
  static const actionMinHeight = 26.0;
  static const actionFontSize = 15.0;
  static const actionStartPadding = 12.0;
  static const dismissIconSize = 20.0;
  static const dismissStartPadding = 8.0;
  static const shadowRadius = 10.0;
  static const shadowAlpha = 0.1;
  static const durationShortMs = 4000;
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
  /// Base page transition duration. Tuned to match the previous default at 1.5×
  /// user speed (450ms ÷ 1.5 = 300ms).
  static const transitionDurationMs = 300;

  /// [SettingsTransitionHelper.FADE_THROUGH_THRESHOLD]
  static const fadeThroughThreshold = 0.22;

  /// Fraction of screen width the outgoing page slides left.
  static const exitSlideFraction = 0.25;

  /// Android [R.interpolator.fast_out_extra_slow_in]
  static const transitionCurve = Cubic(0.05, 0.0, 0.133333, 1.0);

  /// Fallback when [RoundedCorner] is unavailable (typical Xiaomi display).
  static const pageCornerRadiusFallback = 28.0;

  /// Drop shadow on the incoming page's lower-left (overhead light on a card).
  static const pageShadowOffsetX = -8.0;
  static const pageShadowOffsetY = 12.0;
  static const pageShadowBlur = 28.0;
  static const pageShadowAlpha = 0.20;
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
}
