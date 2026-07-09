import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';

/// Live-tunable HyperOS list layout values (debug / hand-off to baked tokens).
class HyperosLayoutTuning {
  const HyperosLayoutTuning({
    required this.cardRadius,
    required this.iconBadgeSize,
    required this.iconGlyphSize,
    required this.paddingLeft,
    required this.paddingRight,
    required this.paddingTopFirst,
    required this.paddingBottomLast,
    required this.paddingInnerVertical,
    required this.chevronWidth,
    required this.chevronHeight,
    required this.chevronStrokeWidth,
    required this.listTitleSize,
    required this.titleChevronGap,
  });

  final double cardRadius;
  final double iconBadgeSize;
  final double iconGlyphSize;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTopFirst;
  final double paddingBottomLast;
  final double paddingInnerVertical;
  final double chevronWidth;
  final double chevronHeight;
  final double chevronStrokeWidth;
  final double listTitleSize;
  final double titleChevronGap;

  double get iconBadgeRadius => iconBadgeSize * 7 / 26;

  static const defaults = HyperosLayoutTuning(
    cardRadius: HyperosMiuixSpec.settingsGroupRadius,
    iconBadgeSize: 26,
    iconGlyphSize: 14,
    paddingLeft: 16,
    paddingRight: 16,
    paddingTopFirst: 13,
    paddingBottomLast: 13,
    paddingInnerVertical: 13,
    chevronWidth: HyperosMiuixSpec.settingsChevronWidth,
    chevronHeight: HyperosMiuixSpec.settingsChevronHeight,
    chevronStrokeWidth: HyperosMiuixSpec.settingsChevronStrokeWidth,
    listTitleSize: HyperosMiuixSpec.preferenceTitleSize,
    titleChevronGap: 4,
  );

  HyperosLayoutTuning copyWith({
    double? cardRadius,
    double? iconBadgeSize,
    double? iconGlyphSize,
    double? paddingLeft,
    double? paddingRight,
    double? paddingTopFirst,
    double? paddingBottomLast,
    double? paddingInnerVertical,
    double? chevronWidth,
    double? chevronHeight,
    double? chevronStrokeWidth,
    double? listTitleSize,
    double? titleChevronGap,
  }) {
    return HyperosLayoutTuning(
      cardRadius: cardRadius ?? this.cardRadius,
      iconBadgeSize: iconBadgeSize ?? this.iconBadgeSize,
      iconGlyphSize: iconGlyphSize ?? this.iconGlyphSize,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingRight: paddingRight ?? this.paddingRight,
      paddingTopFirst: paddingTopFirst ?? this.paddingTopFirst,
      paddingBottomLast: paddingBottomLast ?? this.paddingBottomLast,
      paddingInnerVertical: paddingInnerVertical ?? this.paddingInnerVertical,
      chevronWidth: chevronWidth ?? this.chevronWidth,
      chevronHeight: chevronHeight ?? this.chevronHeight,
      chevronStrokeWidth: chevronStrokeWidth ?? this.chevronStrokeWidth,
      listTitleSize: listTitleSize ?? this.listTitleSize,
      titleChevronGap: titleChevronGap ?? this.titleChevronGap,
    );
  }

  Map<String, num> toJson() => {
    'cardRadius': cardRadius,
    'iconBadgeSize': iconBadgeSize,
    'iconGlyphSize': iconGlyphSize,
    'paddingLeft': paddingLeft,
    'paddingRight': paddingRight,
    'paddingTopFirst': paddingTopFirst,
    'paddingBottomLast': paddingBottomLast,
    'paddingInnerVertical': paddingInnerVertical,
    'chevronWidth': chevronWidth,
    'chevronHeight': chevronHeight,
    'chevronStrokeWidth': chevronStrokeWidth,
    'listTitleSize': listTitleSize,
    'titleChevronGap': titleChevronGap,
  };
}

/// In-memory tuning state; notifies listeners so tuned screens update live.
class HyperosLayoutTuningController extends ChangeNotifier {
  HyperosLayoutTuningController._();

  static final HyperosLayoutTuningController instance =
      HyperosLayoutTuningController._();

  HyperosLayoutTuning values = HyperosLayoutTuning.defaults;

  void apply(HyperosLayoutTuning next) {
    values = next;
    notifyListeners();
  }

  void reset() {
    values = HyperosLayoutTuning.defaults;
    notifyListeners();
  }

  void patch(HyperosLayoutTuning Function(HyperosLayoutTuning current) patch) {
    apply(patch(values));
  }
}
