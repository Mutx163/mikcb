import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/day_task_band_logic.dart';
import '../l10n/app_localizations.dart';
import '../models/course.dart';
import '../models/course_task.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../widgets/task_checkbox.dart';
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
          // 无截止日期的作业不归属任何一天，在「今日」「本周」里必然被筛掉。
          // 不提示的话，用户在编辑页把日期一关，那条作业就像凭空消失了
          // （只剩「全部」能看，而那不是默认档）。
          if (_undatedHiddenCount(provider) > 0) _buildUndatedHint(l10n),
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
        // 口径收在 `DayTaskBandLogic.isRelevantToday`：清单页与日视图待办带
        // 对「今日」的定义必须一致，否则同一天在两处显示不同的作业。
        _TaskDateFilter.today => DayTaskBandLogic.isRelevantToday(task, today),
        _TaskDateFilter.week => task.isDueBetween(weekStart, weekEnd),
      };
    }).toList();
    tasks.sort(CourseTask.compareByDueDate);
    return tasks;
  }

  /// 当前筛选下**被挡在外面**的无截止日期作业条数。
  ///
  /// 无 `dueDate` 的作业不归属任何一天（`DayTaskBandLogic` 的取数口径，理由
  /// 是把它归到「今天」会让同一条在一年里重复出现 300 多次）。这本身是对的，
  /// 但那意味着用户在编辑页把截止日期一关，这条作业就从日视图待办带、
  /// 「今日」「本周」三处**同时消失**，只剩「全部」一个档能看到——而「全部」
  /// 不是默认档，于是表现为「我找不到这条作业了」（2026-10-21 用户实测报告）。
  ///
  /// 这里把它数出来，在列表底部给一条可点的提示，让「消失」变成「挪到别处了」。
  int _undatedHiddenCount(TimetableProvider provider) {
    if (_dateFilter == _TaskDateFilter.all) {
      return 0;
    }
    final selectedCourseIds = _courseGroupForFilter(
      provider,
    )?.courses.map((course) => course.id).toSet();
    return provider.tasks.where((task) {
      if (task.dueDate != null || task.isCompleted) {
        return false;
      }
      final courseFilter = _courseFilter;
      if (courseFilter == _noneCourseValue && task.courseId != null) {
        return false;
      }
      if (selectedCourseIds != null &&
          !selectedCourseIds.contains(task.courseId)) {
        return false;
      }
      return true;
    }).length;
  }

  /// 「还有 N 条没设截止日期」的可点提示。
  ///
  /// 点它就切到「全部」——那是唯一能看到这些作业的档。这不是把一个作业塞进
  /// 某一天（那会让它在一年里重复出现 300 多次），只是把「它去哪了」讲清楚。
  Widget _buildUndatedHint(AppLocalizations l10n) {
    final count = _undatedHiddenCount(context.read<TimetableProvider>());
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: HyperosListGroup(
        children: [
          HyperosNavTile(
            icon: Icons.event_busy_outlined,
            title: l10n.taskUndatedHint(count),
            subtitle: l10n.taskUndatedHintSubtitle,
            onTap: () {
              setState(() => _dateFilter = _TaskDateFilter.all);
            },
          ),
        ],
      ),
    );
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

  /// 勾选 / 取消勾选。落盘失败要说出来：勾选框会自己弹回去，用户不点第二下
  /// 就以为没生效，而异常落进 zone 什么也看不见。
  Future<void> _toggleTask(TimetableProvider provider, CourseTask task) async {
    try {
      await provider.toggleTaskCompleted(task.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
    }
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
                // `toggleTaskCompleted` 落盘失败会回滚并 rethrow，而
                // `onToggle` 是 VoidCallback、返回的 Future 没人接 —— 勾选框
                // 弹回去、用户零提示，异常落进 zone。
                onToggle: () => _toggleTask(provider, task),
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
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await context.read<TimetableProvider>().deleteTask(task.id);
    } catch (_) {
      // 落盘失败已回滚内存（见 _timetableDeleteTask），这里必须报出来：原先 await
      // 没有 catch，抛出的错误变成未处理异步异常，列表也原地不动。
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.saveFailed,
        kind: AppToastKind.error,
      );
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
            TaskCheckbox(value: task.isCompleted, onChanged: onToggle),
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
