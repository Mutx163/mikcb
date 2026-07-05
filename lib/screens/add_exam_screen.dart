import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/exam.dart';
import '../models/timetable_settings.dart';
import 'package:intl/intl.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../widgets/course_template_picker_sheet.dart';
import '../widgets/settings_section_widgets.dart';

class AddExamScreen extends StatefulWidget {
  final Exam? exam;

  const AddExamScreen({super.key, this.exam});

  @override
  State<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends State<AddExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _seatController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCourseId;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  ExamReminderPreset _reminderPreset = ExamReminderPreset.day1AndHour1;
  List<int> _customReminderMinutes = [1440, 60];
  bool _hasSelectedDate = false;

  bool get _isEditing => widget.exam != null;

  @override
  void initState() {
    super.initState();
    final exam = widget.exam;
    if (exam != null) {
      _selectedCourseId = exam.courseId;
      _nameController.text = exam.name;
      _selectedDate = exam.dateTime;
      _hasSelectedDate = true;
      _startTime = _parseTime(exam.startTime);
      _endTime = _parseTime(exam.endTime);
      _locationController.text = exam.location ?? '';
      _seatController.text = exam.seatNumber ?? '';
      _noteController.text = exam.note ?? '';
      _reminderPreset = exam.reminderPreset;
      _customReminderMinutes = List<int>.from(exam.customReminderMinutes);
    } else {
      _selectedDate = DateTime.now().add(const Duration(days: 7));
      _startTime = const TimeOfDay(hour: 8, minute: 30);
      _endTime = const TimeOfDay(hour: 10, minute: 30);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _seatController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final courseGroups = provider.courseGroups;

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(_isEditing ? l10n.editExam : l10n.addExam),
        suffixes: [
          if (_isEditing)
            FHeaderAction(
              icon: const Icon(Icons.delete_outline_rounded),
              semanticsLabel: l10n.deleteExam,
              onPress: () => _confirmDelete(l10n),
            ),
          FHeaderAction(
            icon: const Icon(Icons.check_rounded),
            semanticsLabel: l10n.saveExam,
            onPress: _saveExam,
          ),
        ],
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SettingsSectionCard(
                plainTitle: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.linkCourse,
                      style: context.theme.typography.body.sm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCourseLinkTile(courseGroups, l10n, provider),
                    if (_selectedCourseId == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          l10n.linkCourseRequired,
                          style: context.theme.typography.body.xs.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SettingsSectionCard(
                plainTitle: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _withSpacing([
                    _buildNameField(l10n),
                    _buildDatePicker(l10n),
                    _buildTimePickers(l10n),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              SettingsSectionCard(
                plainTitle: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _withSpacing([
                    _buildLocationField(l10n, provider),
                    _buildSeatField(l10n),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              SettingsSectionCard(
                plainTitle: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _withSpacing([
                    _buildReminderDropdown(l10n),
                    _buildNoteField(l10n),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        spaced.add(const SizedBox(height: 12));
      }
      spaced.add(children[index]);
    }
    return spaced;
  }

  Widget _buildPickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onPress,
    bool isPlaceholder = false,
  }) {
    final theme = context.theme;
    return FTile(
      prefix: Icon(icon),
      title: Text(label),
      details: Text(
        value,
        style: theme.typography.body.sm.copyWith(
          fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
          color: isPlaceholder ? theme.colors.mutedForeground : null,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      suffix: Icon(
        Icons.chevron_right_rounded,
        color: theme.colors.mutedForeground,
      ),
      onPress: onPress,
    );
  }

  Widget _buildCourseLinkTile(
    List<CourseGroup> courseGroups,
    AppLocalizations l10n,
    TimetableProvider provider,
  ) {
    final selected = _selectedCourseId != null
        ? provider.getCourseById(_selectedCourseId!)
        : null;
    final courseColor = selected != null
        ? parseHexColorOrFallback(
            selected.color,
            fallback: Theme.of(context).colorScheme.primary,
          )
        : null;

    return FTile(
      prefix: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (courseColor ?? context.theme.colors.muted).withValues(
            alpha: courseColor == null ? 1 : 0.14,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: courseColor != null
            ? Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: courseColor,
                  shape: BoxShape.circle,
                ),
              )
            : Icon(
                Icons.link_rounded,
                size: 18,
                color: context.theme.colors.mutedForeground,
              ),
      ),
      title: Text(l10n.linkCourse),
      details: Text(
        selected != null
            ? '${selected.name} · ${selected.teacher}'
            : (courseGroups.isEmpty ? '暂无课程，请先添加课程' : l10n.linkCourse),
        style: context.theme.typography.body.sm.copyWith(
          fontWeight: selected != null ? FontWeight.w600 : FontWeight.normal,
          color: selected != null
              ? courseColor
              : context.theme.colors.mutedForeground,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      suffix: Icon(
        Icons.chevron_right_rounded,
        color: context.theme.colors.mutedForeground,
      ),
      onPress: courseGroups.isEmpty
          ? null
          : () => _showCourseSheet(courseGroups, l10n),
    );
  }

  Future<void> _showCourseSheet(
    List<CourseGroup> courseGroups,
    AppLocalizations l10n,
  ) async {
    final course = await showCourseTemplatePickerSheet(
      context,
      title: l10n.linkCourse,
      courseGroups: courseGroups,
      selectedCourseId: _selectedCourseId,
    );
    if (course != null && mounted) {
      setState(() {
        _selectedCourseId = course.id;
        if (_nameController.text.isEmpty) {
          _nameController.text = l10n.examDefaultName;
        }
      });
    }
  }

  Widget _buildNameField(AppLocalizations l10n) {
    return FTextFormField(
      control: FTextFieldControl.managed(controller: _nameController),
      label: Text(l10n.examNameLabel),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.examNameRequired;
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker(AppLocalizations l10n) {
    final provider = context.read<TimetableProvider>();
    final semesterStart = provider.semesterStartDate;
    final settings = provider.settings;

    // 计算当前选中日期是第几周
    String weekInfo = '';
    if (_hasSelectedDate && semesterStart != null) {
      final weekIndex = provider.getWeekIndex(_selectedDate, semesterStart);
      if (weekIndex != null &&
          weekIndex >= 1 &&
          weekIndex <= settings.semesterWeekCount) {
        final dayNames = [
          l10n.weekdayMon,
          l10n.weekdayTue,
          l10n.weekdayWed,
          l10n.weekdayThu,
          l10n.weekdayFri,
          l10n.weekdaySat,
          l10n.weekdaySun,
        ];
        final dayOfWeek = _selectedDate.weekday; // 1=Monday, 7=Sunday
        weekInfo = ' ${l10n.weekLabel(weekIndex)} ${dayNames[dayOfWeek - 1]}';
      }
    }

    final displayText = _hasSelectedDate
        ? '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}$weekInfo'
        : l10n.examDateHint;

    return _buildPickerTile(
      label: l10n.examDateLabel,
      value: displayText,
      icon: semesterStart != null
          ? Icons.view_week_rounded
          : Icons.calendar_today_outlined,
      isPlaceholder: !_hasSelectedDate,
      onPress: () => _pickDate(context),
    );
  }

  Widget _buildTimePickers(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final startTile = _buildPickerTile(
          label: l10n.examStartTimeLabel,
          value: _formatTimeOfDay(_startTime),
          icon: Icons.schedule_rounded,
          onPress: () => _pickTime(isStart: true),
        );
        final endTile = _buildPickerTile(
          label: l10n.examEndTimeLabel,
          value: _formatTimeOfDay(_endTime),
          icon: Icons.schedule_outlined,
          onPress: () => _pickTime(isStart: false),
        );
        if (constraints.maxWidth < 420) {
          return Column(
            children: [startTile, const SizedBox(height: 12), endTile],
          );
        }
        return Row(
          children: [
            Expanded(child: startTile),
            const SizedBox(width: 12),
            Expanded(child: endTile),
          ],
        );
      },
    );
  }

  Widget _buildLocationField(
    AppLocalizations l10n,
    TimetableProvider provider,
  ) {
    String? hint;
    if (_selectedCourseId != null) {
      final course = provider.getCourseById(_selectedCourseId!);
      if (course != null) {
        hint = '${l10n.sameAsClassroom}: ${course.location}';
      }
    }
    return FTextFormField(
      control: FTextFieldControl.managed(controller: _locationController),
      label: Text(l10n.examLocationLabel),
      hint: hint ?? l10n.examLocationHint,
    );
  }

  Widget _buildSeatField(AppLocalizations l10n) {
    return FTextFormField(
      control: FTextFieldControl.managed(controller: _seatController),
      label: Text(l10n.examSeatLabel),
    );
  }

  Widget _buildReminderDropdown(AppLocalizations l10n) {
    return FSelect<ExamReminderPreset>(
      label: Text(l10n.examReminderLabel),
      hint: l10n.examReminderLabel,
      items: {
        for (final preset in ExamReminderPreset.values) preset.label: preset,
      },
      control: FSelectControl.lifted(
        value: _reminderPreset,
        onChange: (value) {
          if (value == null) return;
          setState(() {
            _reminderPreset = value;
          });
        },
      ),
    );
  }

  Widget _buildNoteField(AppLocalizations l10n) {
    return FTextFormField.multiline(
      control: FTextFieldControl.managed(controller: _noteController),
      label: Text(l10n.examNoteLabel),
      minLines: 3,
      maxLines: 5,
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final semesterStart = provider.semesterStartDate;
    final settings = provider.settings;

    if (semesterStart == null) {
      // 没有设置开学日期，回退到标准日历选择器
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      );
      if (picked != null) {
        setState(() {
          _selectedDate = picked;
          _hasSelectedDate = true;
        });
      }
      return;
    }

    // 有开学日期，显示周次选择器
    final picked = await _showWeekPicker(
      context,
      semesterStart,
      settings,
      provider: provider,
      currentDate: _selectedDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _hasSelectedDate = true;
      });
    }
  }

  Future<DateTime?> _showWeekPicker(
    BuildContext context,
    DateTime semesterStart,
    TimetableSettings settings, {
    required TimetableProvider provider,
    DateTime? currentDate,
  }) async {
    final totalWeeks = settings.semesterWeekCount;
    // 基于已选日期（或今天）计算初始周次
    final anchor = currentDate ?? DateTime.now();
    final anchorWeekIndex = provider.getWeekIndex(anchor, semesterStart);
    final initialWeek =
        (anchorWeekIndex != null &&
            anchorWeekIndex >= 1 &&
            anchorWeekIndex <= totalWeeks)
        ? anchorWeekIndex
        : 1;

    int selectedWeek = initialWeek;
    // 已选日期有值时默认选中对应星期，否则不选中
    int? selectedDayOfWeek = _hasSelectedDate ? currentDate?.weekday : null;

    // 滚动控制器，初始偏移指向已选周次
    final initialOffset = ((initialWeek - 1) * 56.0 - 100.0).clamp(
      0.0,
      double.infinity,
    );
    final scrollController = ScrollController(
      initialScrollOffset: initialOffset,
    );

    // 计算某周某天的实际日期
    const weekStartDay = 1; // 1=Monday
    DateTime getDateForWeekAndDay(int week, int dayOfWeek) {
      // 学期开始日期所在周的起始日
      final startWeekday = semesterStart.weekday;
      final daysToSubtract = (startWeekday - weekStartDay + 7) % 7;
      final alignedStart = semesterStart.subtract(
        Duration(days: daysToSubtract),
      );
      // 目标日期 = 对齐后的起始日 + (周数-1)*7 + (星期几 - weekStartDay)
      final dayOffset = (dayOfWeek - weekStartDay + 7) % 7;
      return alignedStart.add(Duration(days: (week - 1) * 7 + dayOffset));
    }

    final result = await showFSheet<DateTime>(
      context: context,
      side: FLayout.btt,
      useSafeArea: true,
      draggable: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final l10n = AppLocalizations.of(ctx)!;
            final colors = ctx.theme.colors;
            final typo = ctx.theme.typography;
            final colorScheme = Theme.of(ctx).colorScheme;
            final dayNames = [
              l10n.weekdayMon,
              l10n.weekdayTue,
              l10n.weekdayWed,
              l10n.weekdayThu,
              l10n.weekdayFri,
              l10n.weekdaySat,
              l10n.weekdaySun,
            ];
            final selectedDay = selectedDayOfWeek;
            final selectedDateLabel = selectedDay != null
                ? DateFormat.Md().format(
                    getDateForWeekAndDay(selectedWeek, selectedDay),
                  )
                : l10n.weekLabel(selectedWeek);

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.view_week_rounded,
                              color: colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.examDateWeekPickerTitle,
                                  style: typo.body.sm.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  selectedDateLabel,
                                  style: typo.body.xs.copyWith(
                                    color: colors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            tooltip: MaterialLocalizations.of(
                              ctx,
                            ).closeButtonTooltip,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FButton(
                        variant: FButtonVariant.secondary,
                        onPress: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: getDateForWeekAndDay(
                              selectedWeek,
                              selectedDayOfWeek ?? DateTime.now().weekday,
                            ),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                          );
                          if (picked != null && ctx.mounted) {
                            Navigator.pop(ctx, picked);
                          }
                        },
                        prefix: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        child: Text(l10n.weekPickerCalendarTooltip),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(7, (index) {
                          final dayOfWeek = index + 1;
                          final isSelected = dayOfWeek == selectedDayOfWeek;
                          final date = getDateForWeekAndDay(
                            selectedWeek,
                            dayOfWeek,
                          );
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: index == 0 ? 0 : 4,
                              ),
                              child: FButton(
                                variant: isSelected
                                    ? FButtonVariant.secondary
                                    : FButtonVariant.outline,
                                onPress: () {
                                  Navigator.pop(
                                    ctx,
                                    getDateForWeekAndDay(
                                      selectedWeek,
                                      dayOfWeek,
                                    ),
                                  );
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dayNames[index],
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat.Md().format(date),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(ctx).height * 0.42,
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: FTileGroup(
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (var week = 1; week <= totalWeeks; week++)
                                FTile(
                                  prefix: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          (week == selectedWeek
                                                  ? colorScheme.primary
                                                  : _isCurrentWeek(
                                                      week,
                                                      semesterStart,
                                                      provider,
                                                    )
                                                  ? colorScheme.secondary
                                                  : colorScheme
                                                        .surfaceContainerHighest)
                                              .withValues(
                                                alpha: week == selectedWeek
                                                    ? 1
                                                    : 0.18,
                                              ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$week',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: week == selectedWeek
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurface,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    selectedDayOfWeek != null
                                        ? '${DateFormat.Md().format(getDateForWeekAndDay(week, selectedDayOfWeek))} ${dayNames[selectedDayOfWeek - 1]}'
                                        : l10n.weekLabel(week),
                                  ),
                                  details:
                                      _isCurrentWeek(
                                        week,
                                        semesterStart,
                                        provider,
                                      )
                                      ? Text(l10n.thisWeekLabel)
                                      : Text(l10n.weekLabel(week)),
                                  suffix: week == selectedWeek
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: colorScheme.primary,
                                          size: 20,
                                        )
                                      : null,
                                  onPress: () {
                                    final day = selectedDayOfWeek;
                                    if (day != null) {
                                      Navigator.pop(
                                        ctx,
                                        getDateForWeekAndDay(week, day),
                                      );
                                    } else {
                                      setModalState(() {
                                        selectedWeek = week;
                                      });
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    scrollController.dispose();
    return result;
  }

  bool _isCurrentWeek(
    int week,
    DateTime semesterStart,
    TimetableProvider provider,
  ) {
    final now = DateTime.now();
    final currentWeekIndex = provider.getWeekIndex(now, semesterStart);
    return currentWeekIndex == week;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _confirmDelete(AppLocalizations l10n) async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.deleteExam),
        body: Text(l10n.deleteExamConfirm(widget.exam!.name)),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<TimetableProvider>().deleteExam(widget.exam!.id);
      Navigator.pop(context);
    }
  }

  void _saveExam() {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasSelectedDate) {
      final l10n = AppLocalizations.of(context)!;
      showAppToast(
        context,
        message: l10n.examDateRequired,
        kind: AppToastKind.warning,
      );
      return;
    }

    final provider = context.read<TimetableProvider>();
    final now = DateTime.now();
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    final exam = Exam(
      id: widget.exam?.id ?? const Uuid().v4(),
      courseId: _selectedCourseId!,
      name: _nameController.text.trim(),
      dateTime: dateTime,
      startTime: _formatTimeOfDay(_startTime),
      endTime: _formatTimeOfDay(_endTime),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      seatNumber: _seatController.text.trim().isEmpty
          ? null
          : _seatController.text.trim(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      reminderPreset: _reminderPreset,
      customReminderMinutes: _customReminderMinutes,
      createdAt: widget.exam?.createdAt ?? now,
      updatedAt: now,
    );

    if (_isEditing) {
      provider.updateExam(exam);
    } else {
      provider.addExam(exam);
    }

    Navigator.pop(context);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }
}
