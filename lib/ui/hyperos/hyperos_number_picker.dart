import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_miuix_spec.dart';

/// HyperOS / Miuix wheel number picker (Miuix `NumberPicker` dimensions).
class HyperosNumberPicker extends StatefulWidget {
  const HyperosNumberPicker({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.visibleItemCount = HyperosMiuixNumberPicker.defaultVisibleItemCount,
    this.labelBuilder,
    this.enabled = true,
  });

  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;
  final int step;
  final int visibleItemCount;
  final String Function(int value)? labelBuilder;
  final bool enabled;

  @override
  State<HyperosNumberPicker> createState() => _HyperosNumberPickerState();
}

class _HyperosNumberPickerState extends State<HyperosNumberPicker> {
  late FixedExtentScrollController _controller;
  late List<int> _values;

  @override
  void initState() {
    super.initState();
    _values = _buildValues();
    _controller = FixedExtentScrollController(
      initialItem: _indexForValue(widget.value),
    );
  }

  @override
  void didUpdateWidget(HyperosNumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.min != widget.min ||
        oldWidget.max != widget.max ||
        oldWidget.step != widget.step) {
      _values = _buildValues();
    }
    if (oldWidget.value != widget.value) {
      final index = _indexForValue(widget.value);
      if (_controller.hasClients && _controller.selectedItem != index) {
        _controller.jumpToItem(index);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<int> _buildValues() {
    if (widget.max < widget.min) return [widget.min];
    final values = <int>[];
    for (var v = widget.min; v <= widget.max; v += widget.step) {
      values.add(v);
    }
    return values;
  }

  int _indexForValue(int value) {
    final index = _values.indexOf(value);
    return index >= 0 ? index : 0;
  }

  String _labelFor(int value) =>
      widget.labelBuilder?.call(value) ?? value.toString();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;
    final summary = isDark
        ? HyperosMiuixDarkColors.onSurfaceVariantSummary
        : HyperosMiuixLightColors.onSurfaceVariantSummary;
    final divider = isDark
        ? HyperosMiuixDarkColors.dividerLine
        : HyperosMiuixLightColors.dividerLine;

    final itemHeight = HyperosMiuixNumberPicker.itemHeight;
    final height = itemHeight * widget.visibleItemCount;

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            child: Container(
              height: itemHeight,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: divider, width: 0.75),
                  bottom: BorderSide(color: divider, width: 0.75),
                ),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: itemHeight,
            physics: widget.enabled
                ? const FixedExtentScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onSelectedItemChanged: widget.enabled
                ? (index) {
                    if (index < 0 || index >= _values.length) return;
                    final next = _values[index];
                    if (next != widget.value) {
                      HapticFeedback.selectionClick();
                      widget.onChanged(next);
                    }
                  }
                : null,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: _values.length,
              builder: (context, index) {
                final v = _values[index];
                final selected = v == widget.value;
                return Center(
                  child: Text(
                    _labelFor(v),
                    style: TextStyle(
                      fontSize: selected
                          ? HyperosMiuixTypography.main
                          : HyperosMiuixTypography.body2,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? (widget.enabled ? primary : summary)
                          : (widget.enabled
                                ? summary
                                : summary.withValues(alpha: 0.5)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Picker row: title + embedded [HyperosNumberPicker] inside a card section.
class HyperosNumberPickerTile extends StatelessWidget {
  const HyperosNumberPickerTile({
    super.key,
    required this.title,
    required this.picker,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final HyperosNumberPicker picker;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = isDark
        ? HyperosMiuixDarkColors.onSurfaceVariantSummary
        : HyperosMiuixLightColors.onSurfaceVariantSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: HyperosMiuixTypography.body1,
            fontWeight: FontWeight.w500,
            color: isDark
                ? HyperosMiuixDarkColors.onSurface
                : HyperosMiuixLightColors.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: HyperosMiuixTypography.footnote1,
              color: summary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        picker,
      ],
    );
  }
}
