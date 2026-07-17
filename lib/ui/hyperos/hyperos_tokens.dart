import 'package:flutter/material.dart';

import 'hyperos_layout_tuning.dart';
import 'hyperos_miuix_spec.dart';

/// Design tokens for mikcb HyperOS / MIUI-style surfaces.
///
/// Layout sizes/gaps are the primary public API. Color fields below are
/// **light-mode measured constants** for [HyperosColors] only — UI code must
/// resolve colors via [HyperosColors], never paint with these directly.
abstract final class HyperosTokens {
  // --- Light-only color constants (consume via HyperosColors only) ---

  /// Light scaffold gray. Prefer [HyperosColors.scaffoldBackground].
  static const background = HyperosMiuixSpec.settingsBackground;

  /// Light card surface. Prefer [HyperosColors.card].
  static const card = HyperosMiuixSpec.surfaceContainer;

  /// Light primary text. Prefer [HyperosColors.primaryText].
  static const primaryText = HyperosMiuixSpec.settingsPrimaryText;

  /// Light secondary text. Prefer [HyperosColors.secondaryText].
  static const secondaryText = HyperosMiuixSpec.settingsSecondaryText;

  /// Light tertiary action icon. Prefer [HyperosColors.actionIcon].
  static const actionIcon = HyperosMiuixSpec.onSurfaceActions;

  /// Light row press fill. Prefer [HyperosColors.rowHighlight].
  static const pressed = HyperosMiuixSpec.settingsPressed;

  /// Light divider. Prefer [HyperosColors.dividerLine].
  static const divider = HyperosMiuixSpec.dividerLine;

  /// Light accent alias. Prefer [HyperosColors.primary].
  static const accent = HyperosMiuixSpec.primary;

  /// Light error alias. Prefer [HyperosColors.error].
  static const error = HyperosMiuixSpec.error;

  static HyperosLayoutTuning get _t => HyperosLayoutTuning.current;

  static double get cardRadius => _t.cardRadius;

  /// Corner radius for compact controls (buttons, text fields, nested pickers).
  ///
  /// Miuix pairs this with a real min height ([controlMinHeight] /
  /// TextField padding) so the side walls stay flat. Never put [cardRadius]
  /// (settings group 24) on a short surface — when radius ≥ height/2 the top
  /// and bottom arcs merge into a capsule and look unlike other HyperOS chrome.
  ///
  /// Prefer [HyperosRadius.surfaceRadiusForHeight] / [HyperosAdaptiveCard] when
  /// the surface height is not fixed.
  static const controlRadius = HyperosMiuixButton.cornerRadius;

  /// Minimum height for compact bordered controls using [controlRadius].
  static const controlMinHeight = HyperosMiuixButton.minHeight;

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

  /// Vertical gap between a list/card title and its multi-line caption.
  static const titleCaptionGap = 3.0;

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
