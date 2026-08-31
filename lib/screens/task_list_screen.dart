import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/course.dart';
import '../models/course_task.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import 'add_course_screen.dart';
import 'add_task_screen.dart';

enum _TaskDateFilter { all, today, week }

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  static const _allCourseValue = '__all__';
  static const _noneCourseValue = '__none__';

  _TaskDateFilter _dateFilter = _TaskDateFilter.all;
  String? _courseFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final visibleTasks = _visibleTasks(provider);

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.taskListTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.add_rounded),
          semanticsLabel: l10n.addTask,
          onPress: _openNewTask,
        ),
      ],
      child: HyperosListView(
        padding: const EdgeInsets.all(12),
        children: [
          HyperosSegmentedControl(
            tabs: [
              l10n.taskAllFilter,
              l10n.taskTodayFilter,
              l10n.taskWeekFilter,
            ],
            selectedIndex: _dateFilter.index,
            onChanged: (index) {
              setState(() {
                _dateFilter = _TaskDateFilter.values[index];
              });
            },
          ),
          const SizedBox(height: 10),
          _buildCourseFilter(context, provider),
          const SizedBox(height: 16),
          if (visibleTasks.isEmpty)
            HyperosEmptyState(
              title: _emptyTitle(l10n, provider.tasks.isEmpty),
              icon: Icons.task_alt_outlined,
              action: HyperosButton(
                label: l10n.addTask,
                onPressed: _openNewTask,
              ),
            )
          else
            ..._buildTaskSections(context, provider, visibleTasks),
        ],
      ),
    );
  }

  List<CourseTask> _visibleTasks(TimetableProvider provider) {
    final today = CourseTask.dateOnly(DateTime.now());
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final selectedCourseIds = _courseGroupForFilter(
      provider,
    )?.courses.map((course) => course.id).toSet();
    final tasks = provider.tasks.where((task) {
      final courseFilter = _courseFilter;
      if (courseFilter == _noneCourseValue && task.courseId != null) {
        return false;
      }
      if (selectedCourseIds != null &&
          !selectedCourseIds.contains(task.courseId)) {
        return false;
      }
      return switch (_dateFilter) {
        _TaskDateFilter.all => true,
        _TaskDateFilter.today => task.isDueOn(today),
        _TaskDateFilter.week => task.isDueBetween(weekStart, weekEnd),
      };
    }).toList();
    tasks.sort(CourseTask.compareByDueDate);
    return tasks;
  }

  String _emptyTitle(AppLocalizations l10n, bool noTasksAtAll) {
    if (noTasksAtAll) {
      return l10n.taskNoTasks;
    }
    if (_courseFilter != null) {
      return l10n.taskNoTasksForCourse;
    }
    return switch (_dateFilter) {
      _TaskDateFilter.all => l10n.taskNoTasks,
      _TaskDateFilter.today => l10n.taskNoTasksForToday,
      _TaskDateFilter.week => l10n.taskNoTasksForWeek,
    };
  }

  Widget _buildCourseFilter(BuildContext context, TimetableProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final courseGroup = _courseGroupForFilter(provider);
    final title = _courseFilter == _noneCourseValue
        ? l10n.taskNoCourse
        : courseGroup?.name ?? l10n.taskAllCourses;
    return HyperosListGroup(
      children: [
        HyperosChoiceTile(
          prefix: const Icon(Icons.menu_book_outlined, size: 20),
          title: title,
          subtitle: Text(l10n.taskCourseFilter),
          trailing: const HyperosChevron(),
          onTap: _pickCourseFilter,
        ),
      ],
    );
  }

  List<Widget> _buildTaskSections(
    BuildContext context,
    TimetableProvider provider,
    List<CourseTask> tasks,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final overdue = tasks.where((task) => task.isOverdue()).toList();
    final completed = tasks.where((task) => task.isCompleted).toList();
    final active = tasks
        .where((task) => !task.isCompleted && !task.isOverdue())
        .toList();
    final sections = <Widget>[];

    void addSection(String title, List<CourseTask> sectionTasks) {
      if (sectionTasks.isEmpty) {
        return;
      }
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 16));
      }
      sections.add(HyperosSectionLabel(text: title));
      sections.add(
        HyperosListGroup(
          children: [
            for (final task in sectionTasks)
              _TaskRow(
                task: task,
                course: provider.getCourseForTask(task),
                onEdit: () => _editTask(task),
                onToggle: () => provider.toggleTaskCompleted(task.id),
                onDelete: () => _confirmDelete(task),
                onViewCourse: provider.getCourseForTask(task) == null
                    ? null
                    : () => _viewCourse(task),
              ),
          ],
        ),
      );
    }

    addSection(l10n.taskOverdueSection, overdue);
    addSection(l10n.taskListTitle, active);
    addSection(l10n.taskCompletedSection, completed);
    return sections;
  }

  Future<void> _pickCourseFilter() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    // A timetable stores one Course object per schedule occurrence. Group by
    // the shared course name here so one subject appears once in the picker.
    final courseGroups = <CourseGroup>[...provider.courseGroups]
      ..sort((a, b) => a.name.compareTo(b.name));
    final values = [
      _allCourseValue,
      _noneCourseValue,
      ...courseGroups.map((group) => group.name),
    ];
    final selected = await showHyperosSheet<String>(
      context: context,
      enableDrag: false,
      builder: (sheetContext) => HyperosSheet(
        title: l10n.taskCourseFilter,
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
                    title: switch (values[index]) {
                      _allCourseValue => l10n.taskAllCourses,
                      _noneCourseValue => l10n.taskNoCourse,
                      _ => values[index],
                    },
                    selected:
                        values[index] == (_courseFilter ?? _allCourseValue),
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
      _courseFilter = selected == _allCourseValue ? null : selected;
    });
  }

  CourseGroup? _courseGroupForFilter(TimetableProvider provider) {
    final filter = _courseFilter;
    if (filter == null || filter == _noneCourseValue) {
      return null;
    }
    for (final group in provider.courseGroups) {
      if (group.name == filter) {
        return group;
      }
    }
    return null;
  }

  Future<void> _openNewTask() async {
    await Navigator.of(
      context,
    ).push<bool>(HyperosPageRoute<bool>(builder: (_) => const AddTaskScreen()));
  }

  Future<void> _editTask(CourseTask task) async {
    await Navigator.of(context).push<bool>(
      HyperosPageRoute<bool>(builder: (_) => AddTaskScreen(task: task)),
    );
  }

  Future<void> _viewCourse(CourseTask task) async {
    final course = context.read<TimetableProvider>().getCourseForTask(task);
    if (course == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      HyperosPageRoute<void>(
        builder: (_) =>
            AddCourseScreen(course: course, initialWeek: task.sourceWeek),
      ),
    );
  }

  Future<void> _confirmDelete(CourseTask task) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.taskDelete,
      message: l10n.taskDeleteConfirm,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (confirmed == true && mounted) {
      await context.read<TimetableProvider>().deleteTask(task.id);
    }
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.course,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onViewCourse,
  });

  final CourseTask task;
  final Course? course;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onViewCourse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final title = task.title.trim().isEmpty
        ? l10n.taskHomeworkDefaultTitle
        : task.title.trim();
    final detailParts = <String>[];
    if (course != null) {
      detailParts.add(course!.name);
      if (task.sourceWeek != null) {
        detailParts.add(l10n.weekLabel(task.sourceWeek!));
      }
    }
    detailParts.add(
      task.dueDate == null
          ? l10n.taskNoDueDate
          : DateFormat.MMMd(l10n.localeName).format(task.dueDate!),
    );
    final titleStyle = HyperosTypography.listTitle(context).copyWith(
      color: task.isOverdue() ? colors.destructive : colors.foreground,
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
    );
    final detailStyle = HyperosTypography.listDetail(context).copyWith(
      color: task.isOverdue() ? colors.destructive : colors.mutedForeground,
    );

    return HyperosPressableRow(
      onTap: onEdit,
      onLongPress: onDelete,
      backgroundColor: HyperosColors.card(context),
      highlightColor: HyperosColors.rowHighlight(context),
      child: hyperosListRowShell(
        padding: hyperosRowPadding(context),
        minHeight: HyperosTokens.listRowTwoLineMinHeight,
        child: Row(
          children: [
            _TaskCheckbox(value: task.isCompleted, onChanged: onToggle),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: titleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detailParts.join(' · '),
                    style: detailStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.note?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.note!,
                      style: HyperosTypography.listDetail(
                        context,
                      ).copyWith(color: colors.mutedForeground),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (onViewCourse != null)
              IconButton(
                tooltip: l10n.taskViewCourse,
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: onViewCourse,
              ),
          ],
        ),
      ),
    );
  }
}

/// 任务行左侧的完成勾选钮：未完成为描边圆环，完成为实心蓝底白勾。
/// MiuixCheckbox 的未选中态是一枚实心灰圆，放在任务行首位只像一个
/// 无意义的灰点，这里换成更符合待办语义的环形勾选。
class _TaskCheckbox extends StatelessWidget {
  const _TaskCheckbox({required this.value, required this.onChanged});

  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged();
      },
      child: Padding(
        // 扩大点击热区到约 30dp。
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? colors.primary : Colors.transparent,
            border: Border.all(
              color: value
                  ? colors.primary
                  : colors.mutedForeground.withValues(alpha: 0.45),
              width: 2,
            ),
          ),
          child: value
              ? Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: colors.primaryForeground,
                )
              : null,
        ),
      ),
    );
  }
}
