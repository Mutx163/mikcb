import 'package:flutter/material.dart';

import 'hyperos_layout_tuning.dart';
import 'hyperos_miuix_spec.dart';

/// Design tokens for mikcb HyperOS / MIUI-style surfaces.
///
/// Colors follow Miuix [HyperosMiuixSpec] where applicable; layout defaults
/// follow HyperOS system Settings overrides in the same file.
abstract final class HyperosTokens {
  // --- Colors ---

  static const background = HyperosMiuixSpec.settingsBackground;
  static const card = HyperosMiuixSpec.surfaceContainer;
  static const primaryText = HyperosMiuixSpec.settingsPrimaryText;
  static const secondaryText = HyperosMiuixSpec.settingsSecondaryText;
  static const actionIcon = HyperosMiuixSpec.onSurfaceActions;
  static const pressed = HyperosMiuixSpec.settingsPressed;
  static const divider = HyperosMiuixSpec.dividerLine;
  static const accent = HyperosMiuixSpec.primary;
  static const error = HyperosMiuixSpec.error;

  static const switchOffTrack = HyperosMiuixLightColors.secondary;
  static const switchOffThumb = HyperosMiuixLightColors.onSecondary;
  static const switchDisabledOnTrack = HyperosMiuixLightColors.disabledPrimary;
  static const switchDisabledOnThumb =
      HyperosMiuixLightColors.disabledOnPrimary;
  static const switchDisabledOffTrack =
      HyperosMiuixLightColors.disabledSecondary;
  static const switchDisabledOffThumb =
      HyperosMiuixLightColors.disabledOnSecondary;

  static HyperosLayoutTuning get _t =>
      HyperosLayoutTuningController.instance.values;

  static double get cardRadius => _t.cardRadius;

  static const sectionGap = HyperosMiuixSpec.settingsSectionGap;
  static const listPadding = HyperosMiuixSpec.settingsListPadding;
  static const rowContentGap = HyperosMiuixSpec.settingsIconGap;
  static const listRowMinHeight = HyperosMiuixSpec.settingsRowMinHeight;
  static const listRowTwoLineMinHeight =
      HyperosMiuixSpec.settingsRowTwoLineMinHeight;

  static double get iconBadgeSize => _t.iconBadgeSize;
  static double get iconGlyphSize => _t.iconGlyphSize;
  static double get iconBadgeRadius => _t.iconBadgeRadius;

  static double get chevronWidth => _t.chevronWidth;
  static double get chevronHeight => _t.chevronHeight;
  static double get chevronStrokeWidth => _t.chevronStrokeWidth;

  static double get listTitleSize => _t.listTitleSize;

  /// Canonical title size for list rows, card headers, page/sheet/dialog titles.
  static double get titleSize => listTitleSize;
  static double get titleChevronGap => _t.titleChevronGap;

  static const listDetailSize = HyperosMiuixSpec.body2Size;

  /// Gap between trailing summary text and chevron (~one body2 character).
  static const detailChevronGap = listDetailSize;
  static const sectionLabelSize = HyperosMiuixSpec.settingsSectionLabelSize;
  static const sectionLabelColor = HyperosMiuixSpec.settingsSectionLabelColor;
  static const sectionLabelInset = HyperosMiuixSpec.settingsSectionLabelInset;
  static const sectionDescriptionSize = HyperosMiuixSpec.footnote1Size;

  /// Same as [titleSize]; prefer [titleSize] for new code.
  static double get headerTitleSize => titleSize;

  /// Frosted [HyperosSubpage] centered title (larger than list row titles).
  static const nestedHeaderTitleSize = HyperosMiuixNestedHeader.titleSize;

  static const nestedHeaderBackIconSize = HyperosMiuixNestedHeader.backIconSize;

  /// Row padding inside a shared [HyperosListGroup] card.
  static EdgeInsets rowPadding({bool isFirst = true, bool isLast = true}) {
    final base = HyperosMiuixSpec.settingsRowPadding;
    return EdgeInsets.only(
      left: base.left,
      right: base.right,
      top: isFirst ? _t.paddingTopFirst : base.top,
      bottom: isLast ? _t.paddingBottomLast : base.bottom,
    );
  }

  /// Row padding for trailing chevron / up-down arrow rows.
  ///
  /// Uses the same horizontal insets as [rowPadding]: chevron sits at the
  /// standard card edge inset (typically 16dp), matching label/title start on
  /// text-only rows.
  static EdgeInsets chevronRowPadding({
    bool isFirst = true,
    bool isLast = true,
  }) {
    return rowPadding(isFirst: isFirst, isLast: isLast);
  }

  static EdgeInsets get rowPaddingUniform =>
      HyperosMiuixSpec.settingsRowPadding;

  static double get listTileDividerIndent =>
      HyperosMiuixSpec.settingsRowPadding.left +
      _t.iconBadgeSize +
      rowContentGap;

  static double get actionTileDividerIndent =>
      HyperosMiuixSpec.settingsRowPadding.left + 22 + rowContentGap;
}

/// Distinct icon accent colors on HyperOS system Settings.
abstract final class HyperosIconColors {
  static const blue = Color(0xFF3482FF);
  static const green = Color(0xFF10C550);
  static const orange = Color(0xFFFF6B00);
  static const purple = Color(0xFF8B5CF6);
  static const teal = Color(0xFF14B8A6);
  static const red = Color(0xFFFA382E);
  static const yellow = Color(0xFFF5A623);
  static const indigo = Color(0xFF6366F1);
  static const cyan = Color(0xFF06B6D4);
}
