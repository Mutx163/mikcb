import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/course.dart';
import '../models/exam.dart';
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
                                _nameController.text = '期末考试';
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
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.examDateLabel,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        ),
      ),
    );
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
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