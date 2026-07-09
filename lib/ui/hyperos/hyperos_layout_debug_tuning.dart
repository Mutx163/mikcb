import '../debug/debug_tuning.dart';
import 'hyperos_layout_tuning.dart';

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
    write: (value) => controller.patch((v) => write(v, value)),
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
