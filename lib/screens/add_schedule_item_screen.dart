import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/schedule_item.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../ui/hyperos/hyperos.dart';

class AddScheduleItemScreen extends StatefulWidget {
  final ScheduleItem? scheduleItem;
  final DateTime? initialDate;

  const AddScheduleItemScreen({super.key, this.scheduleItem, this.initialDate});

  @override
  State<AddScheduleItemScreen> createState() => _AddScheduleItemScreenState();
}

class _AddScheduleItemScreenState extends State<AddScheduleItemScreen> {
  static const double _pagePadding = 12;
  static const double _sectionSpacing = 10;
  static const double _fieldSpacing = 8;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();

  static const List<String> _colors = <String>[
    '#2196F3',
    '#4CAF50',
    '#FF9800',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#FF5722',
    '#795548',
    '#607D8B',
  ];

  late DateTime _selectedStartDate;
  late DateTime _selectedEndDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String _selectedColor = _colors.first;

  bool get _isEditing => widget.scheduleItem != null;

  @override
  void initState() {
    super.initState();
    final scheduleItem = widget.scheduleItem;
    if (scheduleItem != null) {
      _titleController.text = scheduleItem.title;
      _locationController.text = scheduleItem.location ?? '';
      _noteController.text = scheduleItem.note ?? '';
      _selectedStartDate = DateTime(
        scheduleItem.startDate.year,
        scheduleItem.startDate.month,
        scheduleItem.startDate.day,
      );
      _selectedEndDate = DateTime(
        scheduleItem.endDate.year,
        scheduleItem.endDate.month,
        scheduleItem.endDate.day,
      );
      _startTime =
          _parseTime(scheduleItem.startTime) ??
          const TimeOfDay(hour: 8, minute: 0);
      _endTime =
          _parseTime(scheduleItem.endTime) ??
          const TimeOfDay(hour: 9, minute: 0);
      _selectedColor = scheduleItem.color;
    } else {
      final initialDate = widget.initialDate ?? DateTime.now();
      final now = DateTime.now();
      final defaultEnd = now.add(const Duration(hours: 1));
      _selectedStartDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      );
      _selectedEndDate = DateTime(
        defaultEnd.year,
        defaultEnd.month,
        defaultEnd.day,
      );
      _startTime = TimeOfDay(hour: now.hour, minute: now.minute);
      _endTime = TimeOfDay(hour: defaultEnd.hour, minute: defaultEnd.minute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(_isEditing ? l10n.editScheduleTitle : l10n.addScheduleTitle),
      suffixes: [
        if (_isEditing)
          FHeaderAction(
            icon: const Icon(Icons.delete_outline_rounded),
            semanticsLabel: l10n.deleteAction,
            onPress: _confirmDelete,
          ),
        FHeaderAction(
          icon: const Icon(Icons.check_rounded),
          semanticsLabel: l10n.saveAction,
          onPress: _save,
        ),
      ],
      child: Form(
        key: _formKey,
        child: HyperosListView(
          padding: const EdgeInsets.all(_pagePadding),
          children: [
            HyperosControlCard(
              title: l10n.scheduleInfoSectionTitle,
              child: HyperosControlCardInset(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _withSpacing([
                    FormField<String>(
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.scheduleTitleRequired;
                        }
                        return null;
                      },
                      builder: (field) {
                        return HyperosTextField(
                          controller: _titleController,
                          label: l10n.scheduleTitleLabel,
                          hint: l10n.scheduleTitleHint,
                          helper: field.errorText,
                          textInputAction: TextInputAction.next,
                          onChanged: field.didChange,
                        );
                      },
                    ),
                    HyperosTextField(
                      controller: _locationController,
                      label: l10n.scheduleLocationLabel,
                      hint: l10n.scheduleLocationHint,
                      textInputAction: TextInputAction.next,
                    ),
                    HyperosTextField(
                      controller: _noteController,
                      label: l10n.scheduleNoteLabel,
                      hint: l10n.scheduleNoteHint,
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: _sectionSpacing),
            HyperosControlCard(
              title: l10n.scheduleTimeSectionTitle,
              child: HyperosControlCardInset(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _withSpacing([
                    _buildStartEndTimeLayout(l10n),
                    _buildScheduleRangeHint(),
                    _buildColorSection(l10n),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        spaced.add(const SizedBox(height: _fieldSpacing));
      }
      spaced.add(children[index]);
    }
    return spaced;
  }

  Widget _buildStartEndTimeLayout(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildEndpointColumn(
            groupLabel: l10n.scheduleStartGroupLabel,
            dateValue: _formatCompactDateLabel(context, _selectedStartDate),
            timeValue: _formatTimeLabel(context, _startTime),
            dateIcon: Icons.calendar_today_outlined,
            timeIcon: Icons.schedule_rounded,
            onDatePress: () => _pickDate(isStart: true),
            onTimePress: () => _pickTime(isStart: true),
          ),
        ),
        const SizedBox(width: _fieldSpacing),
        Expanded(
          child: _buildEndpointColumn(
            groupLabel: l10n.scheduleEndGroupLabel,
            dateValue: _formatCompactDateLabel(context, _selectedEndDate),
            timeValue: _formatTimeLabel(context, _endTime),
            dateIcon: Icons.date_range_rounded,
            timeIcon: Icons.schedule_outlined,
            onDatePress: () => _pickDate(isStart: false),
            onTimePress: () => _pickTime(isStart: false),
          ),
        ),
      ],
    );
  }

  Widget _buildEndpointColumn({
    required String groupLabel,
    required String dateValue,
    required String timeValue,
    required IconData dateIcon,
    required IconData timeIcon,
    required VoidCallback onDatePress,
    required VoidCallback onTimePress,
  }) {
    final theme = context.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          groupLabel,
          style: theme.typography.body.sm.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _buildCompactPickerTile(
          value: dateValue,
          icon: dateIcon,
          onPress: onDatePress,
        ),
        const SizedBox(height: _fieldSpacing),
        _buildCompactPickerTile(
          value: timeValue,
          icon: timeIcon,
          onPress: onTimePress,
        ),
      ],
    );
  }

  Widget _buildCompactPickerTile({
    required String value,
    required IconData icon,
    required VoidCallback onPress,
  }) {
    return HyperosChoiceTile(
      prefix: Icon(icon, size: 18),
      title: value,
      onTap: onPress,
    );
  }

  Widget _buildScheduleRangeHint() {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final isCrossDay = _selectedEndDate.isAfter(_selectedStartDate);
    final text = isCrossDay
        ? l10n.scheduleCrossDayHint
        : l10n.scheduleSingleDayHint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCrossDay ? Icons.nights_stay_rounded : Icons.today_rounded,
            size: 18,
            color: theme.colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSection(AppLocalizations l10n) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.scheduleAppearanceSectionTitle,
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _buildColorPalette(),
      ],
    );
  }

  Widget _buildColorPalette() {
    final theme = context.theme;
    const swatchSize = 32.0;
    const swatchSpacing = 8.0;
    final selectionBorder = theme.colors.foreground;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final colorHex in _colors) ...[
            GestureDetector(
              onTap: () => setState(() => _selectedColor = colorHex),
              child: Container(
                width: swatchSize,
                height: swatchSize,
                decoration: BoxDecoration(
                  color: _colorFromHex(colorHex),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedColor == colorHex
                        ? selectionBorder
                        : theme.colors.border,
                    width: _selectedColor == colorHex ? 2 : 1,
                  ),
                ),
                child: _selectedColor == colorHex
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: swatchSpacing),
          ],
        ],
      ),
    );
  }

  String _formatCompactDateLabel(BuildContext context, DateTime value) {
    final locale = Localizations.localeOf(context).toString();
    if (value.year == DateTime.now().year) {
      return DateFormat.Md(locale).format(value);
    }
    return DateFormat.yMd(locale).format(value);
  }

  String _formatTimeLabel(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _selectedStartDate : _selectedEndDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      if (isStart) {
        _selectedStartDate = normalized;
        if (_selectedEndDate.isBefore(_selectedStartDate)) {
          _selectedEndDate = _selectedStartDate;
        }
      } else {
        _selectedEndDate = normalized;
        if (_selectedEndDate.isBefore(_selectedStartDate)) {
          _selectedStartDate = _selectedEndDate;
        }
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final sameDay = _isSameDate(_selectedStartDate, _selectedEndDate);
    if (sameDay && _asMinutes(_endTime) <= _asMinutes(_startTime)) {
      showAppToast(
        context,
        message: l10n.scheduleTimeRangeInvalid,
        kind: AppToastKind.warning,
      );
      return;
    }
    if (_selectedEndDate.isBefore(_selectedStartDate)) {
      showAppToast(
        context,
        message: l10n.scheduleDateRangeInvalid,
        kind: AppToastKind.warning,
      );
      return;
    }

    final now = DateTime.now();
    final existing = widget.scheduleItem;
    final item = ScheduleItem(
      id: existing?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      color: _selectedColor,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final provider = context.read<TimetableProvider>();
    if (existing == null) {
      await provider.addScheduleItem(item);
    } else {
      await provider.updateScheduleItem(item);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
    showAppToast(
      context,
      message: existing == null
          ? l10n.scheduleSavedHint
          : l10n.scheduleUpdatedHint,
      kind: AppToastKind.success,
    );
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _confirmDelete() async {
    final scheduleItem = widget.scheduleItem;
    if (scheduleItem == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteScheduleTitle,
      message: l10n.deleteScheduleMessage(scheduleItem.title),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );

    if (confirmed != true) {
      return;
    }

    await provider.deleteScheduleItem(scheduleItem.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
    showAppToast(
      context,
      message: l10n.scheduleDeletedHint,
      kind: AppToastKind.success,
    );
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _asMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Color _colorFromHex(String value) {
    return parseHexColorOrFallback(value, fallback: const Color(0xFF2196F3));
  }
}
