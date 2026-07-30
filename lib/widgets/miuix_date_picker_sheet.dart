import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../ui/hyperos/hyperos.dart';
import 'miuix_fling_number_picker.dart';

/// 弹出 HyperOS 底部 sheet，内嵌 [MiuixDatePicker] 月历。
///
/// 返回用户确认的日期；取消 / 点遮罩返回 `null`。
/// 用于替换 Material [showDatePicker]，保持与设置页一致的毛玻璃弹层。
Future<DateTime?> showMiuixDatePickerSheet(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
  MiuixWeekStart weekStart = MiuixWeekStart.monday,
}) {
  final resolvedFirstDate = firstDate ?? DateTime(2020);
  final resolvedLastDate = lastDate ?? DateTime(2035, 12, 31);
  final clampedInitial = _clampDateOnly(
    initialDate,
    resolvedFirstDate,
    resolvedLastDate,
  );

  return showHyperosSheet<DateTime>(
    context: context,
    builder: (sheetContext) => _MiuixDatePickerSheetBody(
      title: title,
      initialDate: clampedInitial,
      firstDate: resolvedFirstDate,
      lastDate: resolvedLastDate,
      weekStart: weekStart,
    ),
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _clampDateOnly(DateTime value, DateTime earliest, DateTime latest) {
  final date = _dateOnly(value);
  final lo = _dateOnly(earliest);
  final hi = _dateOnly(latest);
  if (date.isBefore(lo)) {
    return lo;
  }
  if (date.isAfter(hi)) {
    return hi;
  }
  return date;
}

class _MiuixDatePickerSheetBody extends StatefulWidget {
  const _MiuixDatePickerSheetBody({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.weekStart,
    this.title,
  });

  final String? title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final MiuixWeekStart weekStart;

  @override
  State<_MiuixDatePickerSheetBody> createState() =>
      _MiuixDatePickerSheetBodyState();
}

class _MiuixDatePickerSheetBodyState extends State<_MiuixDatePickerSheetBody> {
  late DateTime _selectedDate;
  bool _showYearMonthDialog = false;
  late int _wheelYear;
  late int _wheelMonth;
  late int _wheelDay;

  /// 与 [MiuixDatePicker] 重建同步：滚轮改日期后用新 key 强制月历跳到目标月。
  int _calendarRevision = 0;

  static const int _wheelMinYear = 2020;
  static const int _wheelMaxYear = 2035;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _syncWheelFromSelected();
  }

  void _syncWheelFromSelected() {
    _wheelYear = _selectedDate.year;
    _wheelMonth = _selectedDate.month;
    _wheelDay = _selectedDate.day;
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  void _openYearMonthDialog() {
    setState(() {
      _syncWheelFromSelected();
      _showYearMonthDialog = true;
    });
  }

  void _confirmYearMonthDialog() {
    final maxDay = _daysInMonth(_wheelYear, _wheelMonth);
    final day = _wheelDay.clamp(1, maxDay);
    final nextDate = _clampDateOnly(
      DateTime(_wheelYear, _wheelMonth, day),
      widget.firstDate,
      widget.lastDate,
    );
    setState(() {
      _selectedDate = nextDate;
      _showYearMonthDialog = false;
      _calendarRevision += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sheetTitle = widget.title ?? l10n.semesterStartDateLabel;
    final miuixColors = MiuixTheme.of(context).colors;

    // 日历贴在毛玻璃 sheet 上时去掉内置 surfaceContainer 底，避免双层卡片。
    final defaultColors = MiuixDatePickerColors.defaultColors(context);
    final calendarColors = MiuixDatePickerColors(
      backgroundColor: Colors.transparent,
      headerColor: defaultColors.headerColor,
      weekdayColor: defaultColors.weekdayColor,
      weekendWeekdayColor: defaultColors.weekendWeekdayColor,
      dayColor: defaultColors.dayColor,
      weekendDayColor: defaultColors.weekendDayColor,
      outOfMonthDayColor: defaultColors.outOfMonthDayColor,
      selectedDayColor: defaultColors.selectedDayColor,
      selectedDayTextColor: defaultColors.selectedDayTextColor,
      todayBorderColor: defaultColors.todayBorderColor,
      disabledDayColor: defaultColors.disabledDayColor,
      navigationIconColor: defaultColors.navigationIconColor,
    );

    return Stack(
      children: [
        HyperosSheet(
          title: sheetTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MiuixDatePicker(
                key: ValueKey<String>(
                  'miuix-date-$_calendarRevision-'
                  '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}',
                ),
                initialDate: _selectedDate,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                weekStart: widget.weekStart,
                colors: calendarColors,
                onDateChanged: (date) {
                  setState(() => _selectedDate = date);
                },
                onHeaderTap: _openYearMonthDialog,
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
                      onPressed: () => Navigator.of(context).pop(_selectedDate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_showYearMonthDialog)
          _YearMonthWheelDialog(
            year: _wheelYear,
            month: _wheelMonth,
            day: _wheelDay,
            minYear: _wheelMinYear,
            maxYear: _wheelMaxYear,
            onYearChanged: (year) {
              setState(() {
                _wheelYear = year;
                final maxDay = _daysInMonth(_wheelYear, _wheelMonth);
                if (_wheelDay > maxDay) {
                  _wheelDay = maxDay;
                }
              });
            },
            onMonthChanged: (month) {
              setState(() {
                _wheelMonth = month;
                final maxDay = _daysInMonth(_wheelYear, _wheelMonth);
                if (_wheelDay > maxDay) {
                  _wheelDay = maxDay;
                }
              });
            },
            onDayChanged: (day) => setState(() => _wheelDay = day),
            onCancel: () => setState(() => _showYearMonthDialog = false),
            onConfirm: _confirmYearMonthDialog,
            surfaceColor: miuixColors.surface,
            title: l10n.semesterStartDateLabel,
            cancelLabel: l10n.cancelAction,
            confirmLabel: l10n.confirmAction,
          ),
      ],
    );
  }
}

/// 点月历标题时叠在 sheet 上的年/月/日滚轮。
///
/// 不用再套一层 modal，避免双 sheet 手势冲突；半透明遮罩 + 卡片即可。
class _YearMonthWheelDialog extends StatelessWidget {
  const _YearMonthWheelDialog({
    required this.year,
    required this.month,
    required this.day,
    required this.minYear,
    required this.maxYear,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onDayChanged,
    required this.onCancel,
    required this.onConfirm,
    required this.surfaceColor,
    required this.title,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final int year;
  final int month;
  final int day;
  final int minYear;
  final int maxYear;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onDayChanged;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Color surfaceColor;
  final String title;
  final String cancelLabel;
  final String confirmLabel;

  int get _maxDay => DateTime(year, month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    final textStyles = MiuixTheme.of(context).textStyles;
    // 三列均分时 title1 会把「2026年」截成省略号，改用 title3。
    final pickerStyle = textStyles.title3.copyWith(fontWeight: FontWeight.w400);

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCancel,
              child: const ColoredBox(color: Color(0x66000000)),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Material(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(HyperosTokens.cardRadius),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: HyperosTypography.sheetTitle(context),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: Row(
                            children: [
                              Expanded(
                                child: MiuixFlingNumberPicker(
                                  value: year,
                                  min: minYear,
                                  max: maxYear,
                                  textStyle: pickerStyle,
                                  label: (value) => '$value年',
                                  onValueChanged: onYearChanged,
                                ),
                              ),
                              Expanded(
                                child: MiuixFlingNumberPicker(
                                  value: month,
                                  min: 1,
                                  max: 12,
                                  wrapAround: true,
                                  textStyle: pickerStyle,
                                  label: (value) => '$value月',
                                  onValueChanged: onMonthChanged,
                                ),
                              ),
                              Expanded(
                                child: MiuixFlingNumberPicker(
                                  value: day.clamp(1, _maxDay),
                                  min: 1,
                                  max: _maxDay,
                                  wrapAround: true,
                                  textStyle: pickerStyle,
                                  label: (value) => '$value日',
                                  onValueChanged: onDayChanged,
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
                                label: cancelLabel,
                                variant: HyperosButtonVariant.secondary,
                                expand: true,
                                fitLabel: true,
                                onPressed: onCancel,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: HyperosButton(
                                label: confirmLabel,
                                variant: HyperosButtonVariant.primary,
                                expand: true,
                                fitLabel: true,
                                onPressed: onConfirm,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
