import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/schedule_item.dart';
import '../providers/timetable_provider.dart';

class AddScheduleItemScreen extends StatefulWidget {
  final ScheduleItem? scheduleItem;
  final DateTime? initialDate;

  const AddScheduleItemScreen({
    super.key,
    this.scheduleItem,
    this.initialDate,
  });

  @override
  State<AddScheduleItemScreen> createState() => _AddScheduleItemScreenState();
}

class _AddScheduleItemScreenState extends State<AddScheduleItemScreen> {
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
      _startTime = _parseTime(scheduleItem.startTime) ??
          const TimeOfDay(hour: 8, minute: 0);
      _endTime = _parseTime(scheduleItem.endTime) ??
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.editScheduleTitle : l10n.addScheduleTitle,
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: l10n.deleteAction,
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          TextButton(
            onPressed: _save,
            child: Text(
              l10n.saveAction,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionCard(
              title: l10n.scheduleInfoSectionTitle,
              subtitle: l10n.scheduleInfoSectionSubtitle,
              children: [
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: _buildFieldDecoration(
                    label: l10n.scheduleTitleLabel,
                    hint: l10n.scheduleTitleHint,
                    prefixIcon: const Icon(Icons.event_note_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.scheduleTitleRequired;
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _locationController,
                  textInputAction: TextInputAction.next,
                  decoration: _buildFieldDecoration(
                    label: l10n.scheduleLocationLabel,
                    hint: l10n.scheduleLocationHint,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                TextFormField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _buildFieldDecoration(
                    label: l10n.scheduleNoteLabel,
                    hint: l10n.scheduleNoteHint,
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: l10n.scheduleTimeSectionTitle,
              subtitle: l10n.scheduleTimeSectionSubtitle,
              children: [
                _buildResponsiveFieldPair(
                  leading: _buildPickerField(
                    label: l10n.scheduleStartDateLabel,
                    value: _formatDateLabel(context, _selectedStartDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _pickDate(isStart: true),
                  ),
                  trailing: _buildPickerField(
                    label: l10n.scheduleStartTimeLabel,
                    value: _formatTimeLabel(context, _startTime),
                    icon: Icons.schedule_rounded,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(height: 16),
                _buildResponsiveFieldPair(
                  leading: _buildPickerField(
                    label: l10n.scheduleEndDateLabel,
                    value: _formatDateLabel(context, _selectedEndDate),
                    icon: Icons.date_range_rounded,
                    onTap: () => _pickDate(isStart: false),
                  ),
                  trailing: _buildPickerField(
                    label: l10n.scheduleEndTimeLabel,
                    value: _formatTimeLabel(context, _endTime),
                    icon: Icons.schedule_outlined,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
                const SizedBox(height: 12),
                _buildScheduleRangeHint(),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: l10n.scheduleAppearanceSectionTitle,
              subtitle: l10n.scheduleAppearanceSectionSubtitle,
              children: [
                _buildColorPalette(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ..._withSpacing(children),
          ],
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        spaced.add(const SizedBox(height: 16));
      }
      spaced.add(children[index]);
    }
    return spaced;
  }

  InputDecoration _buildFieldDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      border: const OutlineInputBorder(),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildPickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InputDecorator(
          isFocused: false,
          isHovering: false,
          decoration: _buildFieldDecoration(
            label: label,
            prefixIcon: Icon(icon),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
          ),
          child: Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveFieldPair({
    required Widget leading,
    required Widget trailing,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              leading,
              const SizedBox(height: 16),
              trailing,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: leading),
            const SizedBox(width: 16),
            Expanded(child: trailing),
          ],
        );
      },
    );
  }

  Widget _buildScheduleRangeHint() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isCrossDay = _selectedEndDate.isAfter(_selectedStartDate);
    final text =
        isCrossDay ? l10n.scheduleCrossDayHint : l10n.scheduleSingleDayHint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCrossDay ? Icons.nights_stay_rounded : Icons.today_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPalette() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colors.map((colorHex) {
        final isSelected = colorHex == _selectedColor;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = colorHex),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _colorFromHex(colorHex),
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.black, width: 3)
                  : null,
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
          ),
        );
      }).toList(),
    );
  }

  String _formatDateLabel(BuildContext context, DateTime value) {
    return MaterialLocalizations.of(context).formatMediumDate(value);
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
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scheduleTimeRangeInvalid)),
      );
      return;
    }
    if (_selectedEndDate.isBefore(_selectedStartDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scheduleDateRangeInvalid)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? l10n.scheduleSavedHint : l10n.scheduleUpdatedHint,
        ),
      ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteScheduleTitle),
        content: Text(l10n.deleteScheduleMessage(scheduleItem.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await provider.deleteScheduleItem(scheduleItem.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.scheduleDeletedHint)),
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
    final normalized = value.replaceFirst('#', '');
    return Color(int.parse('FF$normalized', radix: 16));
  }
}

