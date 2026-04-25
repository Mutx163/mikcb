import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../providers/timetable_provider.dart';

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
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saveExam,
              child: Text(l10n.saveExam),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseDropdown(List<Course> courses, AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCourseId,
      decoration: InputDecoration(
        labelText: l10n.linkCourse,
        border: const OutlineInputBorder(),
      ),
      items: courses.map((course) {
        return DropdownMenuItem(
          value: course.id,
          child: Text(
            '${course.name} · ${course.teacher}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCourseId = value;
          if (!_isEditing && value != null) {
            final course = courses.firstWhere((c) => c.id == value);
            if (_nameController.text.isEmpty) {
              _nameController.text = '${course.name}期末考试';
            }
            if (_locationController.text.isEmpty) {
              _locationController.text = '';
            }
          }
        });
      },
      validator: (value) =>
          value == null ? l10n.linkCourseRequired : null,
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