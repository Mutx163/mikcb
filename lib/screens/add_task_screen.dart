import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/day_task_band_logic.dart';
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

  /// 这个页面该不该在打开时弹出键盘、把光标放进标题框。
  ///
  /// 这个页面同时承担三个场景，只有第一个该抢焦点：
  ///
  /// 1. **纯新建**（清单页「+」/ 首页菜单「添加任务」）：用户唯一的动作就是
  ///    打字，替他把这一步省掉。
  /// 2. **从课程加作业**（课程面板「作业」行）：课程、周次、到期日、备注原文
  ///    全都预填好了，用户的动作是「看一眼、确认或改」。此时弹键盘会吃掉
  ///    半个屏幕——实测 360×640 屏 + 300dp 键盘时，「来源课程 / 截止日期 /
  ///    已完成」三行**全部被遮住**，用户连下面有什么都不知道就得先收键盘。
  /// 3. **编辑已有作业**：最常见的改动是勾完成、挪日期，未必是改标题。
  ///
  /// 判据用「有没有预填内容」而不是「是不是编辑」：从课程进入时 `task` 为
  /// null（走新建），但内容已经预填，同样不该抢焦点。
  ///
  /// 判据本体在 `TaskFormDefaults.shouldAutofocusTitle`（纯 Dart 可单测）：
  /// 这个判断错了，用户每次进表单都会被键盘挡住半屏，而只有渲染层测试才抓得到，
  /// 太晚。这里只做参数适配。
  @visibleForTesting
  static bool shouldAutofocusTitle({
    CourseTask? task,
    Course? initialCourse,
    int? initialWeek,
  }) => TaskFormDefaults.shouldAutofocusTitle(
    isEditing: task != null,
    hasInitialCourse: initialCourse != null,
    hasInitialWeek: initialWeek != null,
  );

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  static const _noneCourseValue = '__none__';

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _noteFocusNode = FocusNode();
  String? _courseId;
  int? _sourceWeek;
  DateTime? _dueDate;
  bool _hasDueDate = false;
  bool _isCompleted = false;
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  /// 打开就弹键盘、光标落在标题框——**只在「纯新建」时成立**。
  ///
  /// 这个页面同时承担三个场景，只有第一个该抢焦点：
  ///
  /// 1. **纯新建**（清单页「+」/ 首页菜单「添加任务」）：用户唯一动作就是打字，
  ///    替他把这一步省掉。
  /// 2. **从课程加作业**（课程面板「作业」行）：课程、周次、到期日、备注原文
  ///    全都预填好了，用户的动作是「看一眼、确认或改」。此时弹键盘会直接吃掉
  ///    半个屏幕——实测 360×640 屏 + 300dp 键盘时，「来源课程 / 截止日期 /
  ///    已完成」三行**全部被遮住**，用户连下面有什么都不知道就得先收键盘。
  /// 3. **编辑已有作业**：最常见的改动是勾完成、挪日期，未必是改标题。
  ///
  /// 判据用「有没有预填内容」而不是「是不是编辑」：从课程进入时 `task` 为
  /// null（走新建），但内容已经预填，同样不该抢焦点。
  bool get _shouldAutofocusTitle => AddTaskScreen.shouldAutofocusTitle(
    task: widget.task,
    initialCourse: widget.initialCourse,
    initialWeek: widget.initialWeek,
  );

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
    _isCompleted = task?.isCompleted ?? false;
    final courseDate =
        initialCourse != null && initialWeek != null
        ? context.read<TimetableProvider>().dateForCourseOccurrence(
            initialCourse,
            initialWeek,
          )
        : null;
    // 默认到期日的规则见 `TaskFormDefaults.initialDueDate`：新建默认今天
    // （无日期的作业在日视图与「今日」里都看不见），从课程进入用那节课的日期，
    // 编辑态沿用原值。
    _dueDate = TaskFormDefaults.initialDueDate(
      editingDueDate: task?.dueDate,
      courseOccurrenceDate: courseDate,
      isEditing: _isEditing,
      today: DateTime.now(),
    );
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
    _titleFocusNode.dispose();
    _noteFocusNode.dispose();
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
                        focusNode: _titleFocusNode,
                        autofocus: _shouldAutofocusTitle,
                        label: l10n.taskTitleLabel,
                        hint: l10n.taskTitleHint,
                        helper: field.errorText,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _noteFocusNode.requestFocus(),
                        onChanged: field.didChange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    HyperosTextField(
                      controller: _noteController,
                      focusNode: _noteFocusNode,
                      label: l10n.taskNoteLabel,
                      hint: l10n.taskNoteHint,
                      minLines: 1,
                      maxLines: 4,
                      // 备注是表单里最后一个输入框：回车直接保存，不再把焦点
                      // 推到某个开关上（开关不可输入，停在那里什么也不会发生）。
                      // 原先两处都是 `next`，打完标题按回车只是把光标挪到备注，
                      // 再按一次就彻底没反应了。
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
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
                  // 不设截止日期的作业不会出现在日视图待办带、也不会进清单页
                  // 的「今日」档（`CourseTask` 没有「创建日当到期日」这条语义）。
                  // 而新建时这个开关**默认是关的**，用户很容易存完就再也找不到
                  // ——所以关着的时候把后果直接写在这行下面。
                  subtitle: _hasDueDate ? null : l10n.taskDueDateHint,
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
                HyperosSwitchTile(
                  title: l10n.taskCompletedSection,
                  value: _isCompleted,
                  onChanged: (value) {
                    setState(() => _isCompleted = value);
                  },
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
              isCompleted: _isCompleted,
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
      // 分三种说清楚，原先是「一律 taskTitleRequired」：
      // 磁盘写不进去（saveFailed）也会被说成「请输入任务标题」，用户明明填了
      // 标题却被告知没填，怎么改都过不去。`_validateTask` 只抛两种
      // ArgumentError（`task_title_required` / `task_course_not_found`，
      // 见 `timetable_course_service.dart`），按 message 区分即可。
      // 「关联课程不存在」复用既有 `serviceMsgLinkedCourseNotFound`，
      // 不为一句话新增六个 ARB 键。
      final message = switch (error) {
        ArgumentError(:final message)
            when message == 'task_course_not_found' =>
          l10n.serviceMsgLinkedCourseNotFound,
        ArgumentError() => l10n.taskTitleRequired,
        _ => l10n.saveFailed,
      };
      showAppToast(
        context,
        message: message,
        kind: error is ArgumentError
            ? AppToastKind.warning
            : AppToastKind.error,
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
    try {
      await context.read<TimetableProvider>().deleteTask(widget.task!.id);
    } catch (_) {
      // deleteTask 现在会在落盘失败时回滚内存并 rethrow（course_repository.dart 的
      // _timetableDeleteTask）。原先 await 完就无条件 pop(true)：
      // 作业一条没删，弹层却报「已删除」，重启后它又回来。
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
