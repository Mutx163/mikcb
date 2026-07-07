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
import '../ui/hyperos/hyperos.dart';

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

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
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
      child: Form(
        key: _formKey,
        child: HyperosListView(
          children: [
            HyperosControlCard(
              edgeToEdge: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCourseLinkTile(courseGroups, l10n, provider),
                  if (_selectedCourseId == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        HyperosControlCardScope.defaultHorizontalPadding,
                        6,
                        HyperosControlCardScope.defaultHorizontalPadding,
                        HyperosControlCardScope.defaultBodyBottomInset,
                      ),
                      child: Text(
                        l10n.linkCourseRequired,
                        style: HyperosTypography.listDetail(
                          context,
                        ).copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
            const HyperosSectionGap(),
            HyperosControlCard(
              edgeToEdge: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HyperosControlCardScope.defaultHorizontalPadding,
                      HyperosControlCardScope.defaultHorizontalPadding,
                      HyperosControlCardScope.defaultHorizontalPadding,
                      0,
                    ),
                    child: _buildNameField(l10n),
                  ),
                  _buildDateTimePickerRows(l10n),
                ],
              ),
            ),
            const HyperosSectionGap(),
            HyperosControlCard(
              edgeToEdge: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  HyperosControlCardScope.defaultHorizontalPadding,
                  HyperosControlCardScope.defaultHorizontalPadding,
                  HyperosControlCardScope.defaultHorizontalPadding,
                  HyperosControlCardScope.defaultBodyBottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _withSpacing([
                    _buildLocationField(l10n, provider),
                    _buildSeatField(l10n),
                  ]),
                ),
              ),
            ),
            const HyperosSectionGap(),
            HyperosControlCard(
              edgeToEdge: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildReminderDropdown(l10n),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HyperosControlCardScope.defaultHorizontalPadding,
                      0,
                      HyperosControlCardScope.defaultHorizontalPadding,
                      HyperosControlCardScope.defaultBodyBottomInset,
                    ),
                    child: _buildNoteField(l10n),
                  ),
                ],
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
    return HyperosListTile(
      icon: icon,
      title: label,
      details: isPlaceholder ? null : value,
      onTap: onPress,
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

    final detailsText = selected != null
        ? '${selected.name} · ${selected.teacher}'
        : (courseGroups.isEmpty
              ? l10n.noCoursesInCurrentProfile
              : l10n.linkCourse);

    return HyperosChoiceTile(
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
      title: l10n.linkCourse,
      subtitle: Text(detailsText, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: courseGroups.isEmpty
          ? null
          : Icon(
              Icons.chevron_right_rounded,
              color: context.theme.colors.mutedForeground,
            ),
      onTap: courseGroups.isEmpty
          ? null
          : () => _showCourseSheet(courseGroups, l10n),
    );
  }

  Future<void> _showCourseSheet(
    List<CourseGroup> courseGroups,
    AppLocalizations l10n,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final course = await showCourseTemplatePickerSheet(
      context,
      title: l10n.linkCourse,
      courseGroups: courseGroups,
      selectedCourseId: _selectedCourseId,
    );
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
    });
    if (course != null) {
      setState(() {
        _selectedCourseId = course.id;
        if (_nameController.text.isEmpty) {
          _nameController.text = l10n.examDefaultName;
        }
      });
    }
  }

  Widget _buildNameField(AppLocalizations l10n) {
    return FormField<String>(
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.examNameRequired;
        }
        return null;
      },
      builder: (field) {
        return HyperosTextField(
          controller: _nameController,
          label: l10n.examNameLabel,
          helper: field.errorText,
          onChanged: field.didChange,
        );
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

  Widget _buildDateTimePickerRows(AppLocalizations l10n) {
    final dateTile = _buildDatePicker(l10n);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HyperosListTileScope(
                isFirst: true,
                isLast: false,
                child: dateTile,
              ),
              HyperosListTileScope(
                isFirst: false,
                isLast: false,
                child: startTile,
              ),
              HyperosListTileScope(
                isFirst: false,
                isLast: true,
                child: endTile,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HyperosListTileScope(
              isFirst: true,
              isLast: false,
              child: dateTile,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: HyperosListTileScope(
                    isFirst: false,
                    isLast: true,
                    child: startTile,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HyperosListTileScope(
                    isFirst: false,
                    isLast: true,
                    child: endTile,
                  ),
                ),
              ],
            ),
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
    return HyperosTextField(
      controller: _locationController,
      label: l10n.examLocationLabel,
      hint: hint ?? l10n.examLocationHint,
    );
  }

  Widget _buildSeatField(AppLocalizations l10n) {
    return HyperosTextField(
      controller: _seatController,
      label: l10n.examSeatLabel,
    );
  }

  Widget _buildReminderDropdown(AppLocalizations l10n) {
    return HyperosSelectTile<ExamReminderPreset>(
      label: l10n.examReminderLabel,
      items: {
        for (final preset in ExamReminderPreset.values) preset.label: preset,
      },
      value: _reminderPreset,
      onChanged: (value) => setState(() => _reminderPreset = value),
    );
  }

  Widget _buildNoteField(AppLocalizations l10n) {
    return HyperosTextField(
      controller: _noteController,
      label: l10n.examNoteLabel,
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

    final result = await showHyperosSheet<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final l10n = AppLocalizations.of(ctx)!;
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

            return HyperosSheet(
              title: l10n.examDateWeekPickerTitle,
              description: selectedDateLabel,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HyperosButton(
                    label: l10n.weekPickerCalendarTooltip,
                    variant: HyperosButtonVariant.secondary,
                    expand: true,
                    onPressed: () async {
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
                          padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
                          child: Material(
                            color: isSelected
                                ? Theme.of(ctx).colorScheme.secondaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(
                                  ctx,
                                  getDateForWeekAndDay(selectedWeek, dayOfWeek),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
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
                      child: HyperosChoiceGroup(
                        children: [
                          for (var week = 1; week <= totalWeeks; week++)
                            HyperosChoiceTile(
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
                              title: selectedDayOfWeek != null
                                  ? '${DateFormat.Md().format(getDateForWeekAndDay(week, selectedDayOfWeek))} ${dayNames[selectedDayOfWeek - 1]}'
                                  : l10n.weekLabel(week),
                              subtitle: Text(
                                _isCurrentWeek(week, semesterStart, provider)
                                    ? l10n.thisWeekLabel
                                    : l10n.weekLabel(week),
                              ),
                              selected: week == selectedWeek,
                              highlightSelectedText: true,
                              onTap: () {
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
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteExam,
      message: l10n.deleteExamConfirm(widget.exam!.name),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
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
