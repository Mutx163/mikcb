import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import 'miuix_number_picker_sheet.dart';

/// 弹出学期周数选择 sheet，使用 [showMiuixNumberPickerSheet] 滚轮。
///
/// 确认返回选中周数；取消 / 点遮罩返回 `null`。
Future<int?> showSemesterWeekCountPickerSheet(
  BuildContext context, {
  required int currentValue,
  int minValue = 1,
  int maxValue = 30,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showMiuixNumberPickerSheet(
    context,
    title: l10n.selectSemesterWeekCountTitle,
    currentValue: currentValue,
    minValue: minValue,
    maxValue: maxValue,
    label: l10n.semesterWeekCountAction,
  );
}
