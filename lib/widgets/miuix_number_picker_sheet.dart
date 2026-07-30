import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../ui/hyperos/hyperos.dart';

/// 弹出通用数值选择 sheet，使用 [MiuixNumberPicker] 滚轮。
///
/// 与学期周数弹窗同款滚轮：[label] 决定每行文案（如「第 N 周」「第 N 节」）。
/// 确认返回选中值；取消 / 点遮罩返回 `null`。
Future<int?> showMiuixNumberPickerSheet(
  BuildContext context, {
  required String title,
  required int currentValue,
  required int minValue,
  required int maxValue,
  String Function(int value)? label,
}) {
  final clampedCurrent = currentValue.clamp(minValue, maxValue);
  return showHyperosSheet<int>(
    context: context,
    builder: (sheetContext) => _MiuixNumberPickerSheetBody(
      title: title,
      currentValue: clampedCurrent,
      minValue: minValue,
      maxValue: maxValue,
      label: label,
    ),
  );
}

class _MiuixNumberPickerSheetBody extends StatefulWidget {
  const _MiuixNumberPickerSheetBody({
    required this.title,
    required this.currentValue,
    required this.minValue,
    required this.maxValue,
    this.label,
  });

  final String title;
  final int currentValue;
  final int minValue;
  final int maxValue;
  final String Function(int value)? label;

  @override
  State<_MiuixNumberPickerSheetBody> createState() =>
      _MiuixNumberPickerSheetBodyState();
}

class _MiuixNumberPickerSheetBodyState
    extends State<_MiuixNumberPickerSheetBody> {
  late int _selectedValue;

  /// 滚轮可见行数（奇数，至少 3）；5 行更接近系统数字选择器手感。
  static const int _visibleItemCount = 5;

  /// 约 5 × itemHeight，给滚轮足够的滑动高度。
  static const double _pickerHeight = 220;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.currentValue;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textStyles = MiuixTheme.of(context).textStyles;

    return HyperosSheet(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _pickerHeight,
            child: MiuixNumberPicker(
              value: _selectedValue,
              min: widget.minValue,
              max: widget.maxValue,
              visibleItemCount: _visibleItemCount,
              textStyle: textStyles.title3.copyWith(
                fontWeight: FontWeight.w600,
              ),
              label: widget.label,
              onValueChanged: (value) {
                setState(() => _selectedValue = value);
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.cancelAction,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  fitLabel: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HyperosButton(
                  label: l10n.confirmAction,
                  variant: HyperosButtonVariant.primary,
                  expand: true,
                  fitLabel: true,
                  onPressed: () => Navigator.of(context).pop(_selectedValue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
