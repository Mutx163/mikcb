import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/course_week_localizations.dart';
import '../../l10n/service_message_localizer.dart';
import '../../models/course.dart';
import '../../providers/timetable_provider.dart';
import '../../utils/app_toast.dart';
import '../course_followup_sheets.dart';

/// 课程操作弹层派生的「删除 / 停课 / 调课」三条后续流程。
///
/// 2026-10-19 从 `timetable_screen.dart` 搬出（原 `_showDeleteCourseOptions`、
/// `_showSuspendSheet`、`_confirmDeleteCourse`、`_confirmDeleteOccurrence`、
/// `_showRescheduleSheet`）。这些流程只依赖「当前页 context + provider + 星期
/// 标签」，不再需要 State 的其它成员：
///
/// * provider 一律从 [BuildContext] 现读（与搬迁前同一条 `context.read`）；
/// * [weekdayLabels] 由调用方注入，避免第二份 l10n 星期映射；
/// * 异步之后一律用 `context.mounted`（原 `State.mounted` 的等价判断）。
///
/// 落盘失败的口径原样保留：删除 / 停课 / 调课失败都会回滚并 rethrow，不接就是
/// 「点了没反应 + 未处理异步错误」，所以每一步都 toast 出来。
Future<void> showTimetableCourseDeleteOptions(
  BuildContext context, {
  required Course course,
  required int week,
  required List<String> Function(BuildContext context) weekdayLabels,
}) async {
  final canDeleteOccurrence = course.isInWeek(week);
  final selected = await showCourseDeleteModeSheet(
    context,
    canDeleteOccurrence: canDeleteOccurrence,
    week: week,
  );

  if (!context.mounted || selected == null) {
    return;
  }

  switch (selected) {
    case CourseDeleteMode.course:
      await _confirmDeleteCourse(context, course, weekdayLabels);
    case CourseDeleteMode.occurrence:
      await _confirmDeleteOccurrence(context, course, week, weekdayLabels);
  }
}

/// 「停课 / 复课」弹层：本周停课，或整门课停 / 复。
Future<void> showTimetableCourseSuspendSheet(
  BuildContext context, {
  required Course course,
  required int week,
}) async {
  final provider = context.read<TimetableProvider>();
  final isSuspended = course.isSuspendedInWeek(week);
  final hasAnySuspended = course.suspendedWeeks?.isNotEmpty ?? false;

  final selected = await showCourseSuspendModeSheet(
    context,
    isSuspendedThisWeek: isSuspended,
    hasAnySuspended: hasAnySuspended,
  );

  if (!context.mounted || selected == null) {
    return;
  }

  // 停课/复课一族落盘失败会**回滚并 rethrow**（`_toggleCourseSuspensionImpl` 的
  // 快照 + catch + rethrow，注释里写明「不退的话心跳会把这次停课坐实」）。
  // 不接就是零提示 + 未处理异步错误，而这几条正是"课自己变灰、再也回不来"。
  final l10nSuspend = AppLocalizations.of(context);
  try {
    switch (selected) {
      case CourseSuspendMode.thisWeek:
        await provider.toggleCourseSuspension(course.id, week);
      case CourseSuspendMode.allWeeks:
        if (hasAnySuspended) {
          await provider.unsuspendAllWeeks(course.id);
        } else {
          await provider.suspendAllWeeks(course.id);
        }
    }
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10nSuspend?.saveFailed ?? '',
      kind: AppToastKind.error,
    );
    return;
  }
}

/// 「调课」弹层：把某周的一次课挪到别的周 / 星期 / 节次。
Future<void> showTimetableCourseRescheduleSheet(
  BuildContext context, {
  required Course course,
  required int sourceWeek,
  required List<String> Function(BuildContext context) weekdayLabels,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final provider = context.read<TimetableProvider>();
  final settings = provider.settings;
  final weekDays = weekdayLabels(context);
  final scheme = provider.resolveCourseTimeScheme(course);
  // 必须用课程解析后的节次表：`_applyCourseCustomTime` 会把自定义钟点钉回它
  // 自己那两节，闹钟、课表卡、进度里程碑读的都是这份结果（见
  // TimetableProvider.resolvedSectionsForCourse 的注释）。这里原先直接取模板
  // `scheme.sections`，于是钉过钟点的课（例如教务导入把早读 07:00-07:40 钉在
  // 第 1 节）在本弹层显示成模板的 08:00-08:45 —— 用户照弹层上的时间行动就会错，
  // 而同一个 App 里卡片与闹钟都显示 07:00。
  final sectionTimes =
      provider.resolvedSectionsForCourse(course) ??
      scheme?.sections ??
      settings.sections;

  final draft = await showCourseRescheduleSheet(
    context,
    course: course,
    sourceWeek: sourceWeek,
    settings: settings,
    weekDays: weekDays,
    sectionTimes: sectionTimes,
    locationSuggestions: provider.uniqueLocations,
  );

  if (draft == null) {
    return;
  }

  try {
    final changed = await provider.rescheduleCourseOccurrence(
      courseId: course.id,
      sourceWeek: sourceWeek,
      targetWeek: draft.targetWeek,
      targetDayOfWeek: draft.targetDayOfWeek,
      targetStartSection: draft.targetStartSection,
      targetEndSection: draft.targetEndSection,
      targetLocation: draft.targetLocation,
    );
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: changed
          ? l10n.rescheduledToMessage(
              draft.targetWeek,
              _weekdayLabel(weekDays, draft.targetDayOfWeek),
              draft.targetStartSection,
              draft.targetEndSection,
            )
          : l10n.noChangesDetected,
      kind: changed ? AppToastKind.success : AppToastKind.info,
    );
  } on ArgumentError catch (error) {
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: error.message != null
          ? localizeServiceMessage(l10n, error.message!.toString())
          : AppLocalizations.of(context)!.rescheduleFailed,
      kind: AppToastKind.error,
    );
  } catch (_) {
    // ⚠️ 落盘失败抛的是 StateError（storage_service.dart 的
    // `throw StateError('storage_write_failed:…')`），不是 ArgumentError ——
    // 上面的 on 子句接不到它（同款注释见 `deleteCourseOccurrence` 的处理函数，
    // 那条已经吃过一次亏）。落不进盘就必须让用户看见，否则点了没反应、
    // 下一次成功写入还把内存里的挪动坐实。
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.rescheduleFailed,
      kind: AppToastKind.error,
    );
  }
}

Future<void> _confirmDeleteCourse(
  BuildContext context,
  Course course,
  List<String> Function(BuildContext context) weekdayLabels,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDeleteCourseConfirmDialog(
    context,
    title: l10n.deleteScheduleTitle,
    message: l10n.deleteScheduleConfirmMessage(
      course.name,
      l10n.courseWeekdaySectionSummary(
        course.weekDescription(l10n),
        _weekdayLabel(weekdayLabels(context), course.dayOfWeek),
        course.startSection,
        course.endSection,
      ),
    ),
  );

  if (!confirmed || !context.mounted) {
    return;
  }

  // 与 `add_course_screen` 的同名入口同因：provider 删除失败会回滚并 rethrow，
  // 不接就是「点了删除、零提示、未处理异步错误」。
  try {
    await context.read<TimetableProvider>().deleteCourse(course.id);
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.deleteFailed,
      kind: AppToastKind.error,
    );
    return;
  }
  if (!context.mounted) {
    return;
  }
  showAppToast(
    context,
    message: AppLocalizations.of(context)!.deletedCourseMessage(course.name),
    kind: AppToastKind.success,
  );
}

Future<void> _confirmDeleteOccurrence(
  BuildContext context,
  Course course,
  int sourceWeek,
  List<String> Function(BuildContext context) weekdayLabels,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDeleteOccurrenceConfirmDialog(
    context,
    title: l10n.deleteLessonTitle,
    message: l10n.deleteOccurrenceConfirmMessage(
      course.name,
      sourceWeek,
      l10n.weekdaySectionTimeSummary(
        _weekdayLabel(weekdayLabels(context), course.dayOfWeek),
        course.startSection,
        course.endSection,
        course.startTime,
        course.endTime,
      ),
    ),
  );

  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final changed = await context
        .read<TimetableProvider>()
        .deleteCourseOccurrence(courseId: course.id, sourceWeek: sourceWeek);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: changed
          ? l10n.occurrenceDeletedMessage(sourceWeek)
          : l10n.noChangesDetected,
      kind: changed ? AppToastKind.success : AppToastKind.info,
    );
  } on ArgumentError catch (error) {
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: error.message != null
          ? localizeServiceMessage(l10n, error.message!.toString())
          : AppLocalizations.of(context)!.deleteFailed,
      kind: AppToastKind.error,
    );
  } catch (_) {
    // ⚠️ 落盘失败抛的是 StateError（storage_service.dart 的
    // `throw StateError('storage_write_failed:…')`），**不是** ArgumentError，
    // 所以上面那个 on 子句根本接不到 —— 异常落进 zone 成为未处理异步错误，
    // 而 `deleteCourseOccurrence` 失败时**不回滚**（内存里那一次已经被摘掉），
    // 下一次任意成功写入就把"这周没上过课"坐实。用户零提示。
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.deleteFailed,
      kind: AppToastKind.error,
    );
  }
}

/// 单日星期标签；越界退化成数字（与搬迁前 `_weekdayLabel` 同口径）。
String _weekdayLabel(List<String> labels, int dayOfWeek) {
  if (dayOfWeek < 1 || dayOfWeek > labels.length) {
    return dayOfWeek.toString();
  }
  return labels[dayOfWeek - 1];
}
