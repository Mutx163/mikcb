import 'package:flutter/material.dart';

import '../debug/debug_tuning.dart';
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
    paddingRight: 12,
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

  void _patch(HyperosLayoutTuning Function(HyperosLayoutTuning current) patch) {
    apply(patch(values));
  }
}

DebugTuningFieldSpec _hyperosField(
  String label, {
  required double min,
  required double max,
  required int divisions,
  required double Function(HyperosLayoutTuning v) read,
  required HyperosLayoutTuning Function(HyperosLayoutTuning v, double value)
  write,
}) {
  final controller = HyperosLayoutTuningController.instance;
  return DebugTuningFieldSpec(
    label: label,
    min: min,
    max: max,
    divisions: divisions,
    read: () => read(controller.values),
    write: (value) => controller._patch((v) => write(v, value)),
  );
}

/// Registers HyperOS list sliders into the global debug panel.
void registerHyperosLayoutDebugTuning() {
  final controller = HyperosLayoutTuningController.instance;
  DebugTuningRegistry.instance.register(
    DebugTuningSuite(
      id: 'hyperos_list',
      title: 'HyperOS 列表',
      notifier: controller,
      onReset: controller.reset,
      exportJson: () => controller.values.toJson(),
      fields: [
        _hyperosField(
          '卡片圆角',
          min: 8,
          max: 40,
          divisions: 32,
          read: (v) => v.cardRadius,
          write: (v, n) => v.copyWith(cardRadius: n),
        ),
        _hyperosField(
          '图标边长',
          min: 16,
          max: 40,
          divisions: 24,
          read: (v) => v.iconBadgeSize,
          write: (v, n) => v.copyWith(iconBadgeSize: n),
        ),
        _hyperosField(
          '图标 glyph',
          min: 10,
          max: 24,
          divisions: 14,
          read: (v) => v.iconGlyphSize,
          write: (v, n) => v.copyWith(iconGlyphSize: n),
        ),
        _hyperosField(
          '左内边距',
          min: 0,
          max: 40,
          divisions: 40,
          read: (v) => v.paddingLeft,
          write: (v, n) => v.copyWith(paddingLeft: n),
        ),
        _hyperosField(
          '右内边距',
          min: 0,
          max: 40,
          divisions: 40,
          read: (v) => v.paddingRight,
          write: (v, n) => v.copyWith(paddingRight: n),
        ),
        _hyperosField(
          '首行上',
          min: 0,
          max: 40,
          divisions: 40,
          read: (v) => v.paddingTopFirst,
          write: (v, n) => v.copyWith(paddingTopFirst: n),
        ),
        _hyperosField(
          '末行下',
          min: 0,
          max: 40,
          divisions: 40,
          read: (v) => v.paddingBottomLast,
          write: (v, n) => v.copyWith(paddingBottomLast: n),
        ),
        _hyperosField(
          '中间行',
          min: 0,
          max: 24,
          divisions: 24,
          read: (v) => v.paddingInnerVertical,
          write: (v, n) => v.copyWith(paddingInnerVertical: n),
        ),
        _hyperosField(
          '箭头宽',
          min: 2,
          max: 12,
          divisions: 10,
          read: (v) => v.chevronWidth,
          write: (v, n) => v.copyWith(chevronWidth: n),
        ),
        _hyperosField(
          '箭头高',
          min: 4,
          max: 20,
          divisions: 16,
          read: (v) => v.chevronHeight,
          write: (v, n) => v.copyWith(chevronHeight: n),
        ),
        _hyperosField(
          '箭头线宽',
          min: 0.5,
          max: 3,
          divisions: 25,
          read: (v) => v.chevronStrokeWidth,
          write: (v, n) => v.copyWith(chevronStrokeWidth: n),
        ),
        _hyperosField(
          '标题字号',
          min: 12,
          max: 22,
          divisions: 10,
          read: (v) => v.listTitleSize,
          write: (v, n) => v.copyWith(listTitleSize: n),
        ),
        _hyperosField(
          '字箭间距',
          min: 0,
          max: 24,
          divisions: 24,
          read: (v) => v.titleChevronGap,
          write: (v, n) => v.copyWith(titleChevronGap: n),
        ),
      ],
    ),
  );
}
