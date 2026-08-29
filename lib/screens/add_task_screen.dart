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

  /// initState 里不允许访问 InheritedWidget（Localizations），标题里
  /// 需要 l10n 兜底文案的部分延后到首个 didChangeDependencies 一次性初始化。
  bool _didInitTitle = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitTitle) {
      return;
    }
    _didInitTitle = true;
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
                  title: course?.name ?? l10n.taskNoCourse,
                  subtitle: Text(l10n.taskCourseLabel),
                  trailing: const HyperosChevron(),
                  onTap: _pickCourse,
                ),
                HyperosSwitchTile(
                  title: l10n.taskDueDateLabel,
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
                    title: DateFormat.yMMMMd(l10n.localeName).format(_dueDate!),
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
    // 课表里同一门课的每个时段都是独立的 Course 对象，这里按课程名分组，
    // 让绑定弹窗里一门课只出现一次（与任务清单页的课程筛选弹窗一致）。
    final courseGroups = <CourseGroup>[...provider.courseGroups]
      ..sort((a, b) => a.name.compareTo(b.name));
    final boundCourse = _courseId == null
        ? null
        : provider.getCourseById(_courseId!);
    final values = [
      _noneCourseValue,
      ...courseGroups.map((group) => group.name),
    ];
    final selected = await showHyperosSheet<String>(
      context: context,
      enableDrag: false,
      builder: (sheetContext) => HyperosSheet(
        title: l10n.taskCourseLabel,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.64,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: HyperosChoiceGroup(
              children: [
                for (var index = 0; index < values.length; index++)
                  HyperosChoiceTile(
                    title: values[index] == _noneCourseValue
                        ? l10n.taskNoCourse
                        : values[index],
                    selected: values[index] == _noneCourseValue
                        ? boundCourse == null
                        : boundCourse?.name == values[index],
                    variant: HyperosChoiceVariant.dialog,
                    showDivider: index < values.length - 1,
                    onTap: () => Navigator.pop(sheetContext, values[index]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      if (selected == _noneCourseValue) {
        _courseId = null;
        _sourceWeek = null;
        return;
      }
      if (boundCourse?.name == selected) {
        // 重新选择已绑定课程所在分组时，保留原来的具体课时绑定。
        return;
      }
      final group = courseGroups
          .where((group) => group.name == selected)
          .firstOrNull;
      if (group != null) {
        _courseId = group.courses.first.id;
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
