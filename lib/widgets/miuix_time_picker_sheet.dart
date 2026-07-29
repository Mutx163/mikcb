import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../ui/hyperos/hyperos.dart';

/// 弹出 HyperOS 底部 sheet，内嵌时 / 分双列 [MiuixNumberPicker] 滚轮。
///
/// 返回用户确认的时间；取消 / 点遮罩返回 `null`。
/// 用于替换 Material [showTimePicker]，保持与 [showMiuixDatePickerSheet]
/// 一致的毛玻璃弹层与滚轮手感。时间恒为 24 小时制。
Future<TimeOfDay?> showMiuixTimePickerSheet(
  BuildContext context, {
  required TimeOfDay initialTime,
  String? title,
  bool useRootNavigator = false,
}) {
  return showHyperosSheet<TimeOfDay>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (sheetContext) =>
        _MiuixTimePickerSheetBody(title: title, initialTime: initialTime),
  );
}

class _MiuixTimePickerSheetBody extends StatefulWidget {
  const _MiuixTimePickerSheetBody({required this.initialTime, this.title});

  final String? title;
  final TimeOfDay initialTime;

  @override
  State<_MiuixTimePickerSheetBody> createState() =>
      _MiuixTimePickerSheetBodyState();
}

class _MiuixTimePickerSheetBodyState extends State<_MiuixTimePickerSheetBody> {
  late int _hour;
  late int _minute;

  /// 滚轮可见行数（奇数，至少 3）；5 行更接近系统数字选择器手感。
  static const int _visibleItemCount = 5;

  /// 约 5 × itemHeight，给滚轮足够的滑动高度。
  static const double _pickerHeight = 220;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sheetTitle = widget.title ?? l10n.selectTimeTitle;
    final textStyles = MiuixTheme.of(context).textStyles;
    // 与日期滚轮对话框一致，title3 保证两列均分时数字完整显示。
    final pickerStyle = textStyles.title3.copyWith(fontWeight: FontWeight.w400);

    return HyperosSheet(
      title: sheetTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _pickerHeight,
            child: Row(
              children: [
                Expanded(
                  child: MiuixNumberPicker(
                    value: _hour,
                    min: 0,
                    max: 23,
                    wrapAround: true,
                    visibleItemCount: _visibleItemCount,
                    textStyle: pickerStyle,
                    label: _twoDigits,
                    onValueChanged: (value) => setState(() => _hour = value),
                  ),
                ),
                Expanded(
                  child: MiuixNumberPicker(
                    value: _minute,
                    min: 0,
                    max: 59,
                    wrapAround: true,
                    visibleItemCount: _visibleItemCount,
                    textStyle: pickerStyle,
                    label: _twoDigits,
                    onValueChanged: (value) => setState(() => _minute = value),
                  ),
                ),
              ],
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
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(TimeOfDay(hour: _hour, minute: _minute)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
