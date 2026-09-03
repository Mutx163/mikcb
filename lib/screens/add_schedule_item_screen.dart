import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/schedule_item.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../utils/app_toast.dart';
import '../utils/course_color_palette.dart';
import '../utils/hex_color.dart';
import '../widgets/course_palette_sheet.dart';
import '../widgets/miuix_date_picker_sheet.dart';
import '../widgets/miuix_time_picker_sheet.dart';
import '../ui/hyperos/hyperos.dart';

class AddScheduleItemScreen extends StatefulWidget {
  final ScheduleItem? scheduleItem;
  final DateTime? initialDate;
  final DateTime? occurrenceDate;

  const AddScheduleItemScreen({
    super.key,
    this.scheduleItem,
    this.initialDate,
    this.occurrenceDate,
  });

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

  static const List<String> _colors = kCourseColorQuickPickHexes;

  late DateTime _selectedStartDate;
  late DateTime _selectedEndDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String _selectedColor = _colors.first;
  ScheduleRecurrence _recurrence = ScheduleRecurrence.none;
  int? _reminderMinutesBefore;
  bool _enabled = true;
  bool _notificationPermission = true;
  bool _didResolveSeriesRoot = false;
  bool _dateWasExplicitlyEdited = false;

  bool get _isEditing => widget.scheduleItem != null;
  bool get _isOccurrenceEditing {
    final item = widget.scheduleItem;
    return widget.occurrenceDate != null &&
        (item?.isRecurring == true || item?.seriesId != null);
  }

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
      _recurrence = scheduleItem.recurrence;
      _reminderMinutesBefore = scheduleItem.reminderMinutesBefore;
      _enabled = scheduleItem.enabled;
      if (_reminderMinutesBefore != null) {
        unawaited(_refreshNotificationPermission());
      }
    } else {
      final initialDate = widget.initialDate ?? DateTime.now();
      final now = DateTime.now();
      final defaultEnd = now.add(const Duration(hours: 1));
      final normalizedInitialDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      );
      _selectedStartDate = DateTime(
        normalizedInitialDate.year,
        normalizedInitialDate.month,
        normalizedInitialDate.day,
      );
      // Keep an add action opened for a future day valid by default. Using
      // `now + 1h` for the end date made that day appear to have an inverted
      // range until the user fixed it manually.
      _selectedEndDate = normalizedInitialDate;
      _startTime = TimeOfDay(hour: now.hour, minute: now.minute);
      _endTime = TimeOfDay(hour: defaultEnd.hour, minute: defaultEnd.minute);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveSeriesRoot || widget.scheduleItem?.seriesId == null) {
      return;
    }
    _didResolveSeriesRoot = true;
    final root = context.read<TimetableProvider>().getScheduleItemSeriesRoot(
      widget.scheduleItem!.id,
    );
    if (root == null) {
      return;
    }
    // An override carries the occurrence's content but the root owns the
    // series range and recurrence rule shown when the user chooses "all".
    _selectedStartDate = root.startDate;
    _selectedEndDate = root.endDate;
    _recurrence = root.recurrence;
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
      resizeToAvoidBottomInset: true,
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
            _buildScheduleEnabledSection(l10n),
            const SizedBox(height: _sectionSpacing),
            HyperosControlCard(
              title: l10n.scheduleInfoSectionTitle,
              child: HyperosControlCardInset(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _withSpacing([
                    FormField<String>(
                      initialValue: _titleController.text,
                      validator: (value) {
                        final title = (value ?? _titleController.text).trim();
                        if (title.isEmpty) {
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
                    if (_buildScheduleRangeHint()
                        case final Widget scheduleRangeHint)
                      scheduleRangeHint,
                    _buildColorSection(l10n),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: _sectionSpacing),
            _buildRepeatSection(l10n),
            const SizedBox(height: _sectionSpacing),
            _buildReminderSection(l10n),
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
        HyperosPickerField(
          value: dateValue,
          icon: dateIcon,
          onTap: onDatePress,
          showChevron: false,
        ),
        const SizedBox(height: _fieldSpacing),
        HyperosPickerField(
          value: timeValue,
          icon: timeIcon,
          onTap: onTimePress,
          showChevron: false,
        ),
      ],
    );
  }

  /// 重复与跨日才有需要说明的事（切片展示/重复规则）；同日常规日程
  /// 「结束须晚于开始」是常识且保存时有 toast 校验兜底，不渲染提示条。
  Widget? _buildScheduleRangeHint() {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    if (_recurrence != ScheduleRecurrence.none) {
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
            Icon(Icons.repeat_rounded, size: 18, color: theme.colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _recurrence == ScheduleRecurrence.weekly
                    ? l10n.scheduleRepeatWeeklyHint
                    : l10n.scheduleRepeatEndDateHint,
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
    final isCrossDay = _selectedEndDate.isAfter(_selectedStartDate);
    if (!isCrossDay) {
      return null;
    }
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
          Icon(Icons.nights_stay_rounded, size: 18, color: theme.colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.scheduleCrossDayHint,
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

  /// 启用日程开关独立成卡，置于「日程信息」上方。
  Widget _buildScheduleEnabledSection(AppLocalizations l10n) {
    return HyperosListGroup(
      children: [
        HyperosSwitchTile(
          title: l10n.scheduleEnabledTitle,
          subtitle: _enabled ? null : l10n.scheduleDisabledSubtitle,
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
        ),
      ],
    );
  }

  Widget _buildRepeatSection(AppLocalizations l10n) {
    final options = <(ScheduleRecurrence, String)>[
      (ScheduleRecurrence.none, l10n.scheduleRepeatNone),
      (ScheduleRecurrence.daily, l10n.scheduleRepeatDaily),
      (ScheduleRecurrence.weekly, l10n.scheduleRepeatWeekly),
    ];
    return HyperosControlCard(
      title: l10n.scheduleRepeatSectionTitle,
      child: HyperosControlCardInset(
        child: Column(
          children: [
            for (var index = 0; index < options.length; index++)
              HyperosChoiceTile(
                prefix: const Icon(Icons.repeat_rounded, size: 20),
                title: options[index].$2,
                selected: _recurrence == options[index].$1,
                variant: HyperosChoiceVariant.dialog,
                showDivider: index < options.length - 1,
                onTap: () {
                  setState(() {
                    _recurrence = options[index].$1;
                    if (_recurrence != ScheduleRecurrence.none &&
                        _selectedEndDate.isBefore(_selectedStartDate)) {
                      _selectedEndDate = _selectedStartDate;
                    }
                  });
                },
              ),
            if (_recurrence != ScheduleRecurrence.none) ...[
              const SizedBox(height: _fieldSpacing),
              HyperosChoiceTile(
                prefix: const Icon(Icons.event_outlined, size: 20),
                title: DateFormat.yMMMMd(
                  l10n.localeName,
                ).format(_selectedEndDate),
                subtitle: Text(l10n.scheduleRepeatEndDateLabel),
                trailing: const HyperosChevron(),
                onTap: () => _pickDate(isStart: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSection(AppLocalizations l10n) {
    const reminderOptions = <int?>[null, 5, 10, 15, 30, 60];
    return HyperosControlCard(
      title: l10n.scheduleReminderSectionTitle,
      child: HyperosControlCardInset(
        child: Column(
          children: [
            for (var index = 0; index < reminderOptions.length; index++)
              HyperosChoiceTile(
                prefix: const Icon(Icons.notifications_none_rounded, size: 20),
                title: reminderOptions[index] == null
                    ? l10n.scheduleReminderOff
                    : l10n.scheduleReminderMinutes(reminderOptions[index]!),
                selected: _reminderMinutesBefore == reminderOptions[index],
                variant: HyperosChoiceVariant.dialog,
                showDivider: index < reminderOptions.length - 1,
                onTap: () {
                  setState(() {
                    _reminderMinutesBefore = reminderOptions[index];
                  });
                  if (reminderOptions[index] != null) {
                    unawaited(_refreshNotificationPermission());
                  }
                },
              ),
            if (_reminderMinutesBefore != null && !_notificationPermission) ...[
              const SizedBox(height: _fieldSpacing),
              HyperosActionTile(
                icon: Icons.notifications_off_outlined,
                title: l10n.scheduleReminderPermissionAction,
                onTap: _requestNotificationPermission,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.scheduleReminderPermissionMissing,
                  style: context.theme.typography.body.xs.copyWith(
                    color: context.theme.colors.mutedForeground,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _refreshNotificationPermission() async {
    final granted = await MiuiLiveActivitiesService()
        .checkNotificationPermission();
    if (!mounted) {
      return;
    }
    setState(() => _notificationPermission = granted);
  }

  Future<void> _requestNotificationPermission() async {
    final service = MiuiLiveActivitiesService();
    var granted = await service.requestNotificationPermission();
    if (!granted) {
      await service.openNotificationSettings();
    }
    granted = await service.checkNotificationPermission();
    if (!mounted) {
      return;
    }
    setState(() => _notificationPermission = granted);
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
    final l10n = AppLocalizations.of(context)!;
    const swatchSize = 32.0;
    const swatchSpacing = 8.0;
    final selectionBorder = theme.colors.foreground;
    // 快捷行只放一族一色的精简色，全量 100+ 色走调色盘 sheet；
    // 当前选中色不在快捷行（预设浅深阶或自定义色）时，行首补一个选中态色块。
    final showCurrentChip = !_colors.contains(_selectedColor);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (showCurrentChip) ...[
            _buildPaletteSwatch(
              colorHex: _selectedColor,
              swatchSize: swatchSize,
              isSelected: true,
              selectionBorder: selectionBorder,
              onTap: _showFullColorPalette,
            ),
            const SizedBox(width: swatchSpacing),
          ],
          for (final colorHex in _colors) ...[
            _buildPaletteSwatch(
              colorHex: colorHex,
              swatchSize: swatchSize,
              isSelected: _selectedColor == colorHex,
              selectionBorder: selectionBorder,
              onTap: () => setState(() => _selectedColor = colorHex),
            ),
            const SizedBox(width: swatchSpacing),
          ],
          _buildPaletteSwatch(
            colorHex: null,
            swatchSize: swatchSize,
            isSelected: false,
            selectionBorder: selectionBorder,
            onTap: _showFullColorPalette,
            icon: Icon(
              Icons.palette_outlined,
              size: 16,
              color: theme.colors.mutedForeground,
            ),
            tooltip: l10n.customPaletteAction,
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteSwatch({
    required String? colorHex,
    required double swatchSize,
    required bool isSelected,
    required Color selectionBorder,
    required VoidCallback onTap,
    Widget? icon,
    String? tooltip,
  }) {
    final theme = context.theme;
    final swatch = GestureDetector(
      onTap: onTap,
      child: Container(
        width: swatchSize,
        height: swatchSize,
        decoration: BoxDecoration(
          // 占位井用浅灰；colors.secondary 是深色 M3 强调色（兼容垫片），
          // 浅色表单里会像一颗黑块。
          color: colorHex == null
              ? HyperosColors.secondaryVariant(context)
              : _colorFromHex(colorHex),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? selectionBorder : theme.colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: icon == null && isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Center(child: icon),
      ),
    );
    if (tooltip == null) {
      return swatch;
    }
    return Tooltip(message: tooltip, child: swatch);
  }

  Future<void> _showFullColorPalette() async {
    final result = await showCoursePaletteSheet(
      context,
      initialColorHex: _selectedColor,
      previewText: _titleController.text.trim(),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedColor = result;
    });
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
    final picked = await showMiuixDatePickerSheet(
      context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      if (isStart) {
        _selectedStartDate = normalized;
        if (_isOccurrenceEditing) {
          _dateWasExplicitlyEdited = true;
        }
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
    final l10n = AppLocalizations.of(context)!;
    final current = isStart ? _startTime : _endTime;
    final picked = await showMiuixTimePickerSheet(
      context,
      initialTime: current,
      title: isStart ? l10n.selectStartTimeTitle : l10n.selectEndTimeTitle,
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

    final existing = widget.scheduleItem;
    final provider = context.read<TimetableProvider>();
    bool? applyToAll;
    if (_isOccurrenceEditing) {
      applyToAll = await _chooseOccurrenceScope(deleting: false);
      if (applyToAll == null) {
        return;
      }
    }

    final seriesRoot = existing == null
        ? null
        : provider.getScheduleItemSeriesRoot(existing.id);
    final updateSeries =
        existing == null || !_isOccurrenceEditing || applyToAll!;
    final baseItem = updateSeries ? (seriesRoot ?? existing) : existing;
    final now = DateTime.now();
    final item = ScheduleItem(
      id: baseItem?.id ?? const Uuid().v4(),
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
      createdAt: baseItem?.createdAt ?? now,
      updatedAt: now,
      recurrence: updateSeries ? _recurrence : ScheduleRecurrence.none,
      exceptionDates: updateSeries && _recurrence != ScheduleRecurrence.none
          ? (seriesRoot?.exceptionDates ?? const <DateTime>[])
          : const <DateTime>[],
      seriesId: updateSeries ? null : existing.seriesId,
      occurrenceDate: updateSeries ? null : existing.occurrenceDate,
      reminderMinutesBefore: _reminderMinutesBefore,
      enabled: _enabled,
    );

    if (existing == null) {
      await provider.addScheduleItem(item);
    } else if (_isOccurrenceEditing && applyToAll != true) {
      await provider.updateScheduleItemOccurrence(
        existing.id,
        widget.occurrenceDate!,
        item,
        dateWasExplicitlyEdited: _dateWasExplicitlyEdited,
      );
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

  Future<bool?> _chooseOccurrenceScope({required bool deleting}) {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    return showHyperosDialog<bool>(
      context: context,
      title: deleting
          ? l10n.scheduleDeleteScopeTitle
          : l10n.scheduleEditScopeTitle,
      message: deleting ? null : l10n.scheduleOccurrenceEditHint,
      actions: [
        HyperosDialogAction(
          label: deleting
              ? l10n.scheduleDeleteScopeThis
              : l10n.scheduleEditScopeThis,
          onPressed: () => navigator.pop(false),
        ),
        HyperosDialogAction(
          label: deleting
              ? l10n.scheduleDeleteScopeAll
              : l10n.scheduleEditScopeAll,
          isPrimary: true,
          onPressed: () => navigator.pop(true),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final scheduleItem = widget.scheduleItem;
    if (scheduleItem == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    if (_isOccurrenceEditing) {
      final applyToAll = await _chooseOccurrenceScope(deleting: true);
      if (applyToAll == null) {
        return;
      }
      if (applyToAll) {
        await provider.deleteScheduleItemSeries(scheduleItem.id);
      } else {
        await provider.deleteScheduleItemOccurrence(
          scheduleItem.id,
          widget.occurrenceDate!,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      showAppToast(
        context,
        message: l10n.scheduleDeletedHint,
        kind: AppToastKind.success,
      );
      return;
    }

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
