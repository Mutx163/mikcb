import 'package:flutter/material.dart';

import '../../../domain/day_task_band_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/course.dart';
import '../../../models/course_task.dart';
import '../../../models/timetable_settings.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../ui/hyperos/hyperos_motion.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/hex_color.dart';
import '../../../utils/home_page_background.dart';
import '../../course_surface.dart';
import '../../home_menu_route_catalog.dart';
import '../../home_top_menu.dart' show pushHomeMenuPage;
import '../../open_container.dart';
import '../../task_checkbox.dart';
import 'day_view_agenda_surface.dart';
import 'day_view_ink_style.dart';

/// 日视图议程列表顶部的**待办带**：今天要交 / 欠着的 / 已经交了的作业。
///
/// ## 为什么是独立一条带，不进时间线
///
/// 作业只有截止日期、没有时刻（`CourseTask.dueDate` 构造时归一成 `dateOnly`）。
/// 塞进时间线要么编一个假钟点——污染「X 开始 · Y 结束」摘要与
/// `compareClockText` 排序；要么恒沉底，视觉上与「独立一条带」等价，却要多改
/// 三处类型判别（`TimetableDayAgendaItem` 的 `id` 兜底、排序类型权重、
/// 摘要卡首末条目）。
///
/// 主流日历一律如此：Google Tasks 的 deadline 出现在 All day 区、Apple 提醒
/// 事项进全天区、TickTick 是全天任务条、Todoist 是「全天」版块、
/// FullCalendar 有 `allDaySlot`、Flutter 的 `calendar_view` 直接把两类数据
/// 拆成两个 API。没有任何一家把只有日期的条目按某个默认时刻插进时间线。
///
/// ## 为什么长得不像课程卡
///
/// 作业没有时刻、没有地点、可以勾选，它和「一节要上的课」是两种东西。带内用
/// 复选框 + 中性底 + 来源课程色小圆点，不复用课程卡的色块语言。反例有实测：
/// Google Calendar 把截止日与生日放同一行、同一套样式，被用户记为「错过重要
/// 截止，因为屏幕上没有任何东西让它看起来更紧急」。
///
/// 材质仍与日视图其余内容卡同源（[DayViewAgendaSurface] → `CourseSurface`），
/// 墨色判据同走 [dayAgendaAutoInk]——玻璃档与实底档不能在这里漂移。
class DayViewTaskBand extends StatelessWidget {
  /// 按目标日期分好档的数据（组装在 `DayTaskBandLogic.resolve`）。
  final DayTaskBandData data;

  final TimetableSettings settings;
  final DayViewInkEnvironment inkEnvironment;

  /// 这张卡在屏幕上的实际矩形（由 `MeasuredScreenRect` 量出，首帧为 null）。
  ///
  /// 判字色只用它背后那一小块壁纸的亮度：用整屏平均会让坐在近黑区域的卡拿到
  /// 给亮背景准备的黑字（2026-10-21 真机）。
  final Rect? cardRect;

  /// 卡片圆角；正源是 `_TimetableScreenState._dayViewCardRadius`。
  final double radius;

  /// 关联课程解析（只在有关联时调用一次，取课名与颜色）。
  final Course? Function(CourseTask task) courseResolver;

  /// 勾选 / 取消勾选一条作业。
  ///
  /// **必须返回 Future 并由 UI await**：`toggleTaskCompleted` 在
  /// `test/architecture/delete_write_failure_guard_test.dart` 的 rethrowing
  /// 名单里，落盘失败会回滚并 rethrow；不接住就是「勾了没反应、异常落进
  /// zone」。现成正确写法见 `task_list_screen.dart` 的 `_toggleTask`。
  ///
  /// 类型写 `Future<void> Function` 而不是 `VoidCallback`，就是为了让调用方
  /// 在类型层面被迫处理这个 Future，而不是 fire-and-forget。
  final Future<void> Function(CourseTask task) onToggleCompleted;

  /// 展开某条作业的编辑页（走 `TimetableFormPages.taskForm`）。
  final Widget Function(CourseTask task) taskFormBuilder;

  const DayViewTaskBand({
    super.key,
    required this.data,
    required this.settings,
    required this.inkEnvironment,
    required this.radius,
    required this.courseResolver,
    required this.onToggleCompleted,
    required this.taskFormBuilder,
    this.cardRect,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    // 中性底而不是课程色：作业不属于任何一门课的颜色，它就是一天里的一件待办。
    final surfaceColor = HyperosColors.card(context);
    final ink = dayAgendaAutoInk(
      surfaceColor,
      settings: settings,
      env: inkEnvironment,
      cardRect: cardRect,
      // 真实染色比例（与 CourseSurface 渲染同源），不拿出厂常数顶替。
      washAlpha: CourseSurface.washAlpha(
        context,
        effectiveCourseCardSurfaceStyle(
          settings,
          gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(context),
        ),
      ),
    );
    final mutedInk = ink.withValues(alpha: 0.62);
    const overdueColor = HyperosColors.destructive;
    final l10n = AppLocalizations.of(context)!;

    final rows = <Widget>[];
    void addGap() {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 8));
      }
    }

    if (data.overdue.isNotEmpty) {
      addGap();
      rows.add(
        _BandSectionLabel(
          text: l10n.taskOverdueSection,
          color: overdueColor,
        ),
      );
      for (final row in data.overdue) {
        rows.add(const SizedBox(height: 6));
        rows.add(
          _TaskRow(
            row: row,
            ink: ink,
            mutedInk: mutedInk,
            course: courseResolver(row.task),
            onToggle: () => onToggleCompleted(row.task),
            taskFormBuilder: taskFormBuilder,
            radius: radius,
            settings: settings,
          ),
        );
      }
      if (data.hiddenOverdueCount > 0) {
        rows.add(const SizedBox(height: 6));
        rows.add(
          _MoreOverdueAction(
            text: l10n.dayTaskBandOverdueMore(data.hiddenOverdueCount),
            ink: mutedInk,
            onTap: () =>
                pushHomeMenuPage(context, homePage('taskListPage')),
          ),
        );
      }
    }

    if (data.today.isNotEmpty) {
      addGap();
      for (var i = 0; i < data.today.length; i++) {
        if (i > 0) {
          rows.add(const SizedBox(height: 6));
        }
        final row = data.today[i];
        rows.add(
          _TaskRow(
            row: row,
            ink: ink,
            mutedInk: mutedInk,
            course: courseResolver(row.task),
            onToggle: () => onToggleCompleted(row.task),
            taskFormBuilder: taskFormBuilder,
            radius: radius,
            settings: settings,
          ),
        );
      }
    }

    if (data.completed.isNotEmpty) {
      addGap();
      rows.add(
        _BandSectionLabel(
          text: l10n.taskCompletedSection,
          color: mutedInk,
        ),
      );
      for (final row in data.completed) {
        rows.add(const SizedBox(height: 6));
        rows.add(
          _TaskRow(
            row: row,
            ink: ink,
            mutedInk: mutedInk,
            course: courseResolver(row.task),
            onToggle: () => onToggleCompleted(row.task),
            taskFormBuilder: taskFormBuilder,
            radius: radius,
            settings: settings,
          ),
        );
      }
    }

    return DayViewAgendaSurface(
      settings: settings,
      radius: radius,
      color: surfaceColor,
      gradient: LinearGradient(colors: [surfaceColor, surfaceColor]),
      border: Border.all(color: ink.withValues(alpha: 0.12)),
      shadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ),
    );
  }
}

/// 勾选 / 取消勾选一条作业，并把落盘失败讲给用户听。
///
/// 	oggleTaskCompleted 在 	est/architecture/delete_write_failure_guard_test
/// 的 rethrowing 名单里：落盘失败会回滚内存并 rethrow。不接住的话勾选框一边
/// 弹回去、一边把异常丢进 zone，用户看到的是「点了没反应」——这正是守卫文件
/// 头注释记的那个坑。所以统一收在这里，不让每个调用点各写一份。
///
/// 返回 Future 而不是 void：调用方（onToggleCompleted）的类型要求如此，
/// 避免有人把它写成 fire-and-forget。
Future<void> toggleTaskFromBand(
  BuildContext context,
  Future<void> Function(String taskId) toggle,
  String taskId,
) async {
  try {
    await toggle(taskId);
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.saveFailed,
      kind: AppToastKind.error,
    );
  }
}
/// 带内的小节标题（「已逾期」/「已完成」）。
///
/// 不复用 `DayAgendaStatusBadge`：那是胶囊徽标，这里是分组标题，两者在
/// 卡片里的层级不同（徽标标状态，标题分段落）。
class _BandSectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _BandSectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    );
  }
}

/// 逾期折叠后的「还有 N 项」。
class _MoreOverdueAction extends StatelessWidget {
  final String text;
  final Color ink;
  final VoidCallback? onTap;

  const _MoreOverdueAction({
    required this.text,
    required this.ink,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 15, color: ink),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 带内的一行作业：复选框 + 标题 + 课名/逾期徽标。
///
/// 点行展开编辑页（`OpenContainer`，与三张议程卡同一套转场）；点复选框走
/// 勾选回调，两个热区互不重叠——复选框在左侧、外面包着 `GestureDetector` 的
/// 命中区域，行其余部分交给 `InkWell`。
class _TaskRow extends StatelessWidget {
  final DayTaskBandRow row;
  final Color ink;
  final Color mutedInk;
  final Course? course;
  final VoidCallback onToggle;
  final Widget Function(CourseTask task) taskFormBuilder;
  final double radius;
  final TimetableSettings settings;

  const _TaskRow({
    required this.row,
    required this.ink,
    required this.mutedInk,
    required this.course,
    required this.onToggle,
    required this.taskFormBuilder,
    required this.radius,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final task = row.task;
    final isCompleted = row.kind == DayTaskBandKind.completed;
    final isOverdue = row.kind == DayTaskBandKind.overdue;
    final title = DayTaskBandLogic.needsDefaultTitle(task)
        ? l10n.taskHomeworkDefaultTitle
        : task.title.trim();
    final titleColor = isCompleted
        ? mutedInk
        : (isOverdue ? HyperosColors.destructive : ink);
    final courseName = course?.name ?? '';

    return OpenContainer<void>(
      key: ValueKey('day-view-task-card-${task.id}'),
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: 360.scaledMs,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      openBuilder: (context, _) => taskFormBuilder(task),
      closedBuilder: (context, openContainer) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
              child: Row(
                children: [
                  // 复选框是 opaque 的 GestureDetector、比外层 InkWell 更深，
                  // 手势竞技场里它先赢，点勾不会连带展开编辑页。
                  TaskCheckbox(
                    value: isCompleted,
                    size: 20,
                    onChanged: onToggle,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: mutedInk,
                          ),
                        ),
                        if (courseName.isNotEmpty || isOverdue) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (courseName.isNotEmpty) ...[
                                _CourseDot(
                                  color: parseHexColorOrFallback(
                                    course?.color,
                                    fallback: HyperosColors.primary(context),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    courseName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mutedInk,
                                    ),
                                  ),
                                ),
                              ],
                              if (courseName.isNotEmpty && isOverdue)
                                const SizedBox(width: 8),
                              if (isOverdue)
                                Text(
                                  l10n.dayTaskBandOverdueBadge(
                                    row.overdueDays,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: HyperosColors.destructive,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: mutedInk.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 来源课程的小圆点：作业不属于自己的颜色，用一个点标记它从哪门课来。
class _CourseDot extends StatelessWidget {
  final Color color;

  const _CourseDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
