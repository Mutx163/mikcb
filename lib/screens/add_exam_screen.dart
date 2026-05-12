import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../models/timetable_settings.dart';
import 'package:intl/intl.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';

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

  bool get _isEditing => widget.exam != null;

  @override
  void initState() {
    super.initState();
    final exam = widget.exam;
    if (exam != null) {
      _selectedCourseId = exam.courseId;
      _nameController.text = exam.name;
      _selectedDate = exam.dateTime;
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
    final courses = provider.courses;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editExam : l10n.addExam),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.deleteExam,
              onPressed: () => _confirmDelete(l10n),
            ),
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: l10n.saveExam,
            onPressed: _saveExam,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _buildCourseDropdown(courses, l10n),
            const SizedBox(height: 16),
            _buildNameField(l10n),
            const SizedBox(height: 16),
            _buildDatePicker(l10n),
            const SizedBox(height: 16),
            _buildTimePickers(l10n),
            const SizedBox(height: 16),
            _buildLocationField(l10n, provider),
            const SizedBox(height: 16),
            _buildSeatField(l10n),
            const SizedBox(height: 16),
            _buildReminderDropdown(l10n),
            const SizedBox(height: 16),
            _buildNoteField(l10n),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saveExam,
              child: Text(l10n.saveExam),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseDropdown(List<Course> courses, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = courses.where((c) => c.id == _selectedCourseId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.linkCourse,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _buildCourseTrigger(selected, courses, colorScheme, l10n),
        if (_selectedCourseId == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.linkCourseRequired,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildCourseTrigger(
    Course? selected,
    List<Course> courses,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final selectedColor = selected != null
        ? parseHexColorOrFallback(selected.color, fallback: colorScheme.primary)
        : colorScheme.primary;

    return Material(
      color: selected != null
          ? selectedColor.withValues(alpha: 0.08)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showCourseSheet(courses, colorScheme, l10n),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: selected != null
              ? BoxDecoration(
                  border: Border.all(
                    color: selectedColor.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(14),
                )
              : null,
          child: Row(
            children: [
              if (selected != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${selected.name}  ·  ${selected.teacher}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selectedColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                Icon(Icons.link_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    courses.isEmpty ? '暂无课程，请先添加课程' : l10n.linkCourse,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              Icon(Icons.unfold_more_rounded, size: 20, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseSheet(List<Course> courses, ColorScheme colorScheme, AppLocalizations l10n) {
    if (courses.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      l10n.linkCourse,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: courses.length,
                  itemBuilder: (_, i) {
                    final course = courses[i];
                    final isSelected = course.id == _selectedCourseId;
                    final courseColor = parseHexColorOrFallback(
                      course.color,
                      fallback: colorScheme.primary,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: isSelected
                            ? courseColor.withValues(alpha: 0.10)
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              _selectedCourseId = course.id;
                              if (_nameController.text.isEmpty) {
                                _nameController.text = l10n.examDefaultName;
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: isSelected
                                ? BoxDecoration(
                                    border: Border.all(
                                      color: courseColor.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  )
                                : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: courseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        course.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isSelected ? courseColor : colorScheme.onSurface,
                                        ),
                                      ),
                                      if (course.teacher.isNotEmpty)
                                        Text(
                                          course.teacher,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, size: 20, color: courseColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNameField(AppLocalizations l10n) {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: l10n.examNameLabel,
        border: const OutlineInputBorder(),
      ),
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
    if (semesterStart != null) {
      final weekIndex = _getWeekIndex(_selectedDate, semesterStart, 1); // 1=Monday
      if (weekIndex != null && weekIndex >= 1 && weekIndex <= settings.semesterWeekCount) {
        final dayNames = [l10n.weekdayMon, l10n.weekdayTue, l10n.weekdayWed, l10n.weekdayThu, l10n.weekdayFri, l10n.weekdaySat, l10n.weekdaySun];
        final dayOfWeek = _selectedDate.weekday; // 1=Monday, 7=Sunday
        weekInfo = ' ${l10n.weekLabel(weekIndex)} ${dayNames[dayOfWeek - 1]}';
      }
    }

    return InkWell(
      onTap: () => _pickDate(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.examDateLabel,
          border: const OutlineInputBorder(),
          suffixIcon: semesterStart != null
              ? const Icon(Icons.view_week_rounded)
              : const Icon(Icons.calendar_today),
        ),
        child: Text(
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}$weekInfo',
        ),
      ),
    );
  }

  int? _getWeekIndex(DateTime date, DateTime semesterStart, int firstDayOfWeek) {
    // 将学期开始日期对齐到本周的起始日
    final startWeekday = semesterStart.weekday; // 1=Mon, 7=Sun
    final daysToSubtract = (startWeekday - firstDayOfWeek + 7) % 7;
    final alignedStart = semesterStart.subtract(Duration(days: daysToSubtract));

    // 将目标日期对齐到同一起始日
    final targetWeekday = date.weekday;
    final daysToSubtractTarget = (targetWeekday - firstDayOfWeek + 7) % 7;
    final alignedTarget = date.subtract(Duration(days: daysToSubtractTarget));

    final diffDays = alignedTarget.difference(alignedStart).inDays;
    if (diffDays < 0) return null;
    return (diffDays ~/ 7) + 1;
  }

  Widget _buildTimePickers(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pickTime(isStart: true),
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.examStartTimeLabel,
                border: const OutlineInputBorder(),
              ),
              child: Text(_formatTimeOfDay(_startTime)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => _pickTime(isStart: false),
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.examEndTimeLabel,
                border: const OutlineInputBorder(),
              ),
              child: Text(_formatTimeOfDay(_endTime)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField(AppLocalizations l10n, TimetableProvider provider) {
    String? hint;
    if (_selectedCourseId != null) {
      final course = provider.getCourseForExam(
        Exam(
          id: '',
          courseId: _selectedCourseId!,
          name: '',
          dateTime: DateTime.now(),
          startTime: '',
          endTime: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (course != null) {
        hint = '${l10n.sameAsClassroom}: ${course.location}';
      }
    }
    return TextFormField(
      controller: _locationController,
      decoration: InputDecoration(
        labelText: l10n.examLocationLabel,
        hintText: hint ?? l10n.examLocationHint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSeatField(AppLocalizations l10n) {
    return TextFormField(
      controller: _seatController,
      decoration: InputDecoration(
        labelText: l10n.examSeatLabel,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildReminderDropdown(AppLocalizations l10n) {
    return DropdownButtonFormField<ExamReminderPreset>(
      initialValue: _reminderPreset,
      decoration: InputDecoration(
        labelText: l10n.examReminderLabel,
        border: const OutlineInputBorder(),
      ),
      items: ExamReminderPreset.values.map((preset) {
        return DropdownMenuItem(
          value: preset,
          child: Text(preset.label),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _reminderPreset = value;
          });
        }
      },
    );
  }

  Widget _buildNoteField(AppLocalizations l10n) {
    return TextFormField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: l10n.examNoteLabel,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
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
        setState(() => _selectedDate = picked);
      }
      return;
    }

    // 有开学日期，显示周次选择器
    final picked = await _showWeekPicker(context, semesterStart, settings);
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<DateTime?> _showWeekPicker(
    BuildContext context,
    DateTime semesterStart,
    TimetableSettings settings,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final totalWeeks = settings.semesterWeekCount;
    const firstDayOfWeek = 1; // 1=Mon, 7=Sun

    // 计算当前周次（基于今天）
    final now = DateTime.now();
    final nowWeekIndex = _getWeekIndex(now, semesterStart, firstDayOfWeek);
    final initialWeek = (nowWeekIndex != null && nowWeekIndex >= 1 && nowWeekIndex <= totalWeeks)
        ? nowWeekIndex
        : 1;

    int selectedWeek = initialWeek;
    int? selectedDayOfWeek; // 默认不选中星期

    // 滚动控制器，用于默认滚动到当前周
    final scrollController = ScrollController();
    bool hasScrolledToCurrentWeek = false;

    // 计算某周某天的实际日期
    const weekStartDay = 1; // 1=Monday
    DateTime getDateForWeekAndDay(int week, int dayOfWeek) {
      // 学期开始日期所在周的起始日
      final startWeekday = semesterStart.weekday;
      final daysToSubtract = (startWeekday - weekStartDay + 7) % 7;
      final alignedStart = semesterStart.subtract(Duration(days: daysToSubtract));
      // 目标日期 = 对齐后的起始日 + (周数-1)*7 + (星期几 - weekStartDay)
      final dayOffset = (dayOfWeek - weekStartDay + 7) % 7;
      return alignedStart.add(Duration(days: (week - 1) * 7 + dayOffset));
    }

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final l10n = AppLocalizations.of(ctx)!;
            final dayNames = [l10n.weekdayMon, l10n.weekdayTue, l10n.weekdayWed, l10n.weekdayThu, l10n.weekdayFri, l10n.weekdaySat, l10n.weekdaySun];

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖拽指示条
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 标题
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.view_week_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.examDateWeekPickerTitle,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        // Close button
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        // 切换到标准日历选择器
                        IconButton(
                          icon: const Icon(Icons.calendar_today, size: 20),
                          tooltip: l10n.weekPickerCalendarTooltip,
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: getDateForWeekAndDay(selectedWeek, selectedDayOfWeek ?? DateTime.now().weekday),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (picked != null && ctx.mounted) {
                              Navigator.pop(ctx, picked);
                            }
                          },
                        ),
                        // 显示当前选中的实际日期
                        Text(
                          selectedDayOfWeek != null
                              ? DateFormat.Md().format(getDateForWeekAndDay(selectedWeek, selectedDayOfWeek!))
                              : l10n.weekLabel(selectedWeek),
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 星期几选择
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: List.generate(7, (index) {
                        final dayOfWeek = index + 1; // 1=Mon, 7=Sun
                        final isSelected = dayOfWeek == selectedDayOfWeek;
                        final date = getDateForWeekAndDay(selectedWeek, dayOfWeek);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Material(
                              color: isSelected
                                  ? colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setModalState(() {
                                    selectedDayOfWeek = dayOfWeek;
                                  });
                                  // 选完星期后自动确定
                                  Navigator.pop(
                                    ctx,
                                    getDateForWeekAndDay(selectedWeek, dayOfWeek),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                    children: [
                                      Text(
                                        dayNames[index],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat.Md().format(date),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                        ),
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
                  ),
                  // 周次列表
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                    ),
                    child: ListView.builder(
                      controller: scrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: totalWeeks,
                      itemBuilder: (_, index) {
                        final week = index + 1;
                        final isSelected = week == selectedWeek;
                        final date = getDateForWeekAndDay(week, selectedDayOfWeek ?? 1);
                        final isCurrentWeek = _isCurrentWeek(week, semesterStart, weekStartDay);

                        // 滚动到当前周
                        if (!hasScrolledToCurrentWeek && isCurrentWeek) {
                          hasScrolledToCurrentWeek = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (scrollController.hasClients) {
                              final targetOffset = (index * 56.0 - 100.0).clamp(0.0, scrollController.position.maxScrollExtent);
                              scrollController.jumpTo(targetOffset);
                            }
                          });
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                : isCurrentWeek
                                    ? colorScheme.secondaryContainer.withValues(alpha: 0.3)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                if (selectedDayOfWeek != null) {
                                  Navigator.pop(
                                    ctx,
                                    getDateForWeekAndDay(week, selectedDayOfWeek!),
                                  );
                                } else {
                                  setModalState(() {
                                    selectedWeek = week;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    // 周次标签
                                    Container(
                                      width: 52,
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : isCurrentWeek
                                                ? colorScheme.secondary.withValues(alpha: 0.2)
                                                : colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          l10n.weekLabel(week),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? colorScheme.onPrimary
                                                : isCurrentWeek
                                                    ? colorScheme.secondary
                                                    : colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 日期信息
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedDayOfWeek != null
                                                ? '${DateFormat.Md().format(date)} ${dayNames[selectedDayOfWeek! - 1]}'
                                                : l10n.weekLabel(week),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              color: isSelected
                                                  ? colorScheme.onPrimaryContainer
                                                  : colorScheme.onSurface,
                                            ),
                                          ),
                                          if (isCurrentWeek)
                                            Text(
                                              l10n.thisWeekLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.secondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 20,
                                        color: colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

  bool _isCurrentWeek(int week, DateTime semesterStart, int firstDayOfWeek) {
    final now = DateTime.now();
    final currentWeekIndex = _getWeekIndex(now, semesterStart, firstDayOfWeek);
    return currentWeekIndex == week;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteExam),
        content: Text(l10n.deleteExamConfirm(widget.exam!.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
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