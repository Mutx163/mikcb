import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
import '../models/course.dart';
import '../models/course_task.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../widgets/miuix_date_picker_sheet.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({
    super.key,
    this.task,
    this.initialCourse,
    this.initialWeek,
  });

  final CourseTask? task;
  final Course? initialCourse;
  final int? initialWeek;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  static const _noneCourseValue = '__none__';

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String? _courseId;
  int? _sourceWeek;
  DateTime? _dueDate;
  bool _hasDueDate = false;
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final initialCourse = widget.initialCourse;
    final initialWeek = widget.initialWeek;
    final l10n = AppLocalizations.of(context);
    _titleController.text = task?.title.isNotEmpty == true
        ? task!.title
        : (initialCourse?.sessionNoteForWeek(initialWeek ?? 0)?.trimmedText ??
              (initialCourse != null
                  ? l10n?.taskHomeworkDefaultTitle ?? 'Homework'
                  : ''));
    _noteController.text = task?.note ?? '';
    _courseId = task?.courseId ?? initialCourse?.id;
    _sourceWeek = task?.sourceWeek ?? initialWeek;
    _dueDate = task?.dueDate;
    if (_dueDate == null && initialCourse != null && initialWeek != null) {
      _dueDate = context.read<TimetableProvider>().dateForCourseOccurrence(
        initialCourse,
        initialWeek,
      );
    }
    _hasDueDate = _dueDate != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final course = _courseForId(context.read<TimetableProvider>());

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      resizeToAvoidBottomInset: true,
      title: Text(_isEditing ? l10n.editTask : l10n.addTask),
      suffixes: [
        if (_isEditing)
          FHeaderAction(
            icon: const Icon(Icons.delete_outline_rounded),
            semanticsLabel: l10n.taskDelete,
            onPress: _confirmDelete,
          ),
        FHeaderAction(
          icon: const Icon(Icons.check_rounded),
          semanticsLabel: l10n.saveTask,
          onPress: _save,
        ),
      ],
      child: Form(
        key: _formKey,
        child: HyperosListView(
          padding: const EdgeInsets.all(12),
          children: [
            HyperosControlCard(
              title: l10n.taskListTitle,
              child: HyperosControlCardInset(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormField<String>(
                      initialValue: _titleController.text,
                      validator: (value) =>
                          (value ?? _titleController.text).trim().isEmpty
                          ? l10n.taskTitleRequired
                          : null,
                      builder: (field) => HyperosTextField(
                        controller: _titleController,
                        label: l10n.taskTitleLabel,
                        hint: l10n.taskTitleHint,
                        helper: field.errorText,
                        textInputAction: TextInputAction.next,
                        onChanged: field.didChange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    HyperosTextField(
                      controller: _noteController,
                      label: l10n.taskNoteLabel,
                      hint: l10n.taskNoteHint,
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            HyperosListGroup(
              children: [
                HyperosChoiceTile(
                  prefix: const Icon(Icons.menu_book_outlined, size: 20),
                  title: course?.name ?? l10n.taskNoCourse,
                  subtitle: Text(l10n.taskCourseLabel),
                  trailing: const HyperosChevron(),
                  onTap: _pickCourse,
                ),
                HyperosSwitchTile(
                  icon: Icons.event_outlined,
                  title: _hasDueDate
                      ? DateFormat.yMMMd(l10n.localeName).format(_dueDate!)
                      : l10n.taskNoDueDate,
                  subtitle: l10n.taskDueDateLabel,
                  value: _hasDueDate,
                  onChanged: (value) {
                    setState(() {
                      _hasDueDate = value;
                      _dueDate ??= CourseTask.dateOnly(DateTime.now());
                      if (!value) {
                        _dueDate = null;
                      }
                    });
                  },
                ),
                if (_hasDueDate)
                  HyperosChoiceTile(
                    prefix: const Icon(Icons.calendar_today_outlined, size: 20),
                    title: DateFormat.yMMMMd(l10n.localeName).format(_dueDate!),
                    subtitle: Text(l10n.taskDueDateLabel),
                    trailing: const HyperosChevron(),
                    onTap: _pickDueDate,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Course? _courseForId(TimetableProvider provider) {
    final id = _courseId;
    return id == null ? null : provider.getCourseById(id);
  }

  Future<void> _pickCourse() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final courses = <Course>[...provider.courses]
      ..sort((a, b) => a.name.compareTo(b.name));
    final values = [_noneCourseValue, ...courses.map((course) => course.id)];
    final selected = await showHyperosSheet<String>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: l10n.taskCourseFilter,
        child: HyperosChoiceGroup(
          children: [
            for (var index = 0; index < values.length; index++)
              HyperosChoiceTile(
                title: values[index] == _noneCourseValue
                    ? l10n.taskNoCourse
                    : provider.getCourseById(values[index])?.name ??
                          l10n.taskNoCourse,
                selected: values[index] == (_courseId ?? _noneCourseValue),
                variant: HyperosChoiceVariant.dialog,
                showDivider: index < values.length - 1,
                onTap: () => Navigator.pop(sheetContext, values[index]),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _courseId = selected == _noneCourseValue ? null : selected;
      if (_courseId == null) {
        _sourceWeek = null;
      }
    });
  }

  Future<void> _pickDueDate() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showMiuixDatePickerSheet(
      context,
      title: l10n.taskDueDateLabel,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _dueDate = CourseTask.dateOnly(selected);
      _hasDueDate = true;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    final provider = context.read<TimetableProvider>();
    final now = DateTime.now();
    final task =
        (widget.task ??
                CourseTask(
                  id: const Uuid().v4(),
                  title: _titleController.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                ))
            .copyWith(
              title: _titleController.text.trim(),
              courseId: _courseId,
              sourceWeek: _courseId == null ? null : _sourceWeek,
              dueDate: _hasDueDate ? _dueDate : null,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              updatedAt: now,
            );
    try {
      if (_isEditing) {
        await provider.updateTask(task);
      } else {
        await provider.addTask(task);
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      showAppToast(
        context,
        message: error is ArgumentError
            ? (error.message?.toString() ?? l10n.taskTitleRequired)
            : l10n.taskTitleRequired,
        kind: AppToastKind.warning,
      );
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.taskDelete,
      message: l10n.taskDeleteConfirm,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await context.read<TimetableProvider>().deleteTask(widget.task!.id);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
