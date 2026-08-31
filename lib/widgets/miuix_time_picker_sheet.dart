import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../ui/hyperos/hyperos.dart';
import 'miuix_fling_number_picker.dart';

/// 弹出 HyperOS 底部 sheet，内嵌时 / 分双列 [MiuixFlingNumberPicker] 滚轮。
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
  final _hourPickerController = MiuixFlingNumberPickerController();
  final _minutePickerController = MiuixFlingNumberPickerController();

  /// 约 5 × itemHeight（滚轮可见 5 行，接近系统数字选择器手感）。
  static const double _pickerHeight = 220;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  void _confirm() {
    // 确认可能在滚轮惯性衰减途中按下：先同步结算投影落点，
    // 避免回传上一格的旧值（与日期/数字滚轮弹层同一模式）。
    final settledHour = _hourPickerController.settle() ?? _hour;
    final settledMinute = _minutePickerController.settle() ?? _minute;
    Navigator.of(
      context,
    ).pop(TimeOfDay(hour: settledHour, minute: settledMinute));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sheetTitle = widget.title ?? l10n.selectTimeTitle;
    final textStyles = MiuixTheme.of(context).textStyles;
    // 与日期滚轮对话框一致，title3 保证两列均分时数字完整显示。
    final pickerStyle = textStyles.title3.copyWith(fontWeight: FontWeight.w600);

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
                  child: MiuixFlingNumberPicker(
                    controller: _hourPickerController,
                    value: _hour,
                    max: 23,
                    wrapAround: true,
                    textStyle: pickerStyle,
                    label: _twoDigits,
                    onValueChanged: (value) => setState(() => _hour = value),
                  ),
                ),
                Expanded(
                  child: MiuixFlingNumberPicker(
                    controller: _minutePickerController,
                    value: _minute,
                    max: 59,
                    wrapAround: true,
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
                  expand: true,
                  fitLabel: true,
                  onPressed: _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
