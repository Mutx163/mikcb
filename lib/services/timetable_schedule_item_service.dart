import 'dart:async';

import '../domain/clock_order.dart';
import '../models/schedule_item.dart';
import '../models/timetable_profile.dart';
import 'timetable_core_state_port.dart';

/// 日程（安排事项）族需要的最小宿主面：内存里的日程与课表列表，
/// 以及初始化、落盘、通知、埋点、提醒同步这几个钩子。
///
/// `TimetableProvider` 的成员都是现成的（getter 已有、私有钩子各包一层），
/// 服务不 import provider，可用假端口单测。
abstract interface class TimetableScheduleItemPort implements TimetableCoreStatePort {
  List<ScheduleItem> get scheduleItems;
  set scheduleItems(List<ScheduleItem> value);
  set profiles(List<TimetableProfile> value);
  /// 把当前设置与活动课表落盘；失败时抛错，由本服务回滚。
  Future<void> persistActiveProfileState();
  void logEvent(String name, Map<String, Object> parameters);

  /// 日程改动会影响考试提醒的派生列表，写完后要重新同步原生提醒。
  Future<void> syncExamReminders();
}

/// 日程（安排事项）族的读写实现 —— **只有这一份定义**。
///
/// 2026-10-20 从分片 `providers/timetable/schedule_item_repository.dart`（136 行）
/// 与 `TimetableProvider` 里的整族方法（增删改 + 单次覆盖 + 查询 + 归一/查找
/// helper，约 364 行）合并而来（F1）。宿主只留一行委托与写盘门，
/// 服务的每个入口假定**已经站在写盘门内**（门在宿主，`_runMutation`）。
///
/// 排序与归一保持在服务里，全仓只有这一份：钟点一律按分钟数比
/// （`domain/clock_order.dart` 的正源）。`ScheduleItem.fromJson`
/// （models/schedule_item.dart:226）原样收下外来存档里的 `9:00`，而 [normalize]
/// 只 trim 文本、归一日期，**不碰钟点**，所以字典序（'10:00' < '9:00'）会把同一天的
/// 两条日程排反。钉它的用例是 `test/domain/clock_order_sort_sites_test.dart`
/// （含"重开存档后仍然有序"那条，证明外来钟点确实能进库并参与排序）。
///
/// 落盘失败回滚的判据：**内存里被改掉的，是不是用户刚刚亲口确认的那一条**。
///
/// - [update] 改一个"系列根"时，按系列的语义会把这个系列的**所有单次覆盖行**
///   一起摘掉。覆盖行是用户此前一次次单独确认出来的记录，落盘失败时它们已经在内存里
///   没了、盘上还全在，而下一次任意成功写入会把"整系列只剩改过的那条"坐实 ——
///   用户视角是"那次编辑明明报了失败，重复日程里我单独改过的几次却自己消失了"。
/// - [delete] 按 `seriesId ?? id` 连根带覆盖整系列摘除，同一个形状。
///
/// 同族的 [add]（加的就是用户刚填的那条）与 [updateOccurrence] /
/// [deleteOccurrence]（改根 + 改一次覆盖，但都属于"编辑这一次"这同一个用户意图，
/// 落盘的幻影内容与意图一致）都**不回滚**，与 `addCourse` 同一口径。
/// 回归钉：`test/providers/schedule_item_write_rollback_test.dart`、
/// `test/services/schedule_item_data_flow_test.dart`。
class TimetableScheduleItemService {
  const TimetableScheduleItemService._();

  /// 日程列表的**存量顺序**（写入口与读盘装配都会经过它）。
  static List<ScheduleItem> sort(List<ScheduleItem> source) {
    source.sort((left, right) {
      final dateCompare = left.startDate.compareTo(right.startDate);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final startCompare = compareClockText(left.startTime, right.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      final endCompare = compareClockText(left.endTime, right.endTime);
      if (endCompare != 0) {
        return endCompare;
      }
      return left.id.compareTo(right.id);
    });
    return source;
  }

  /// 落盘前的归一：trim 文本、把空串当没有、把日期压到"日"并把结束日钳到不早于开始日。
  static ScheduleItem normalize(ScheduleItem item) {
    final normalizedStartDate = DateTime(
      item.startDate.year,
      item.startDate.month,
      item.startDate.day,
    );
    final normalizedEndDate = DateTime(
      item.endDate.year,
      item.endDate.month,
      item.endDate.day,
    );
    return item.copyWith(
      title: item.title.trim(),
      location: item.location?.trim().isEmpty == true
          ? null
          : item.location?.trim(),
      note: item.note?.trim().isEmpty == true ? null : item.note?.trim(),
      startDate: normalizedStartDate,
      endDate: normalizedEndDate.isBefore(normalizedStartDate)
          ? normalizedStartDate
          : normalizedEndDate,
    );
  }

  static ScheduleItem? find(TimetableScheduleItemPort port, String itemId) {
    for (final item in port.scheduleItems) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  static ScheduleItem? seriesRoot(
    TimetableScheduleItemPort port,
    ScheduleItem? target,
  ) {
    if (target == null) {
      return null;
    }
    final rootId = target.seriesId ?? target.id;
    return find(port, rootId);
  }

  static ScheduleItemInstance? findInstanceById(
    TimetableScheduleItemPort port,
    String occurrenceId,
  ) {
    for (final item in port.scheduleItems) {
      if (item.id != occurrenceId) {
        continue;
      }
      if (item.seriesId != null) {
        final date = item.occurrenceDate ?? item.startDate;
        return ScheduleItemInstance(
          item: item,
          date: item.startDate,
          occurrenceDate: date,
        );
      }
      if (!item.isRecurring) {
        return ScheduleItemInstance(item: item, date: item.startDate);
      }
    }

    final separatorIndex = occurrenceId.lastIndexOf('@');
    if (separatorIndex <= 0 || separatorIndex == occurrenceId.length - 1) {
      return null;
    }
    final sourceId = occurrenceId.substring(0, separatorIndex);
    final date = DateTime.tryParse(occurrenceId.substring(separatorIndex + 1));
    final source = date == null ? null : find(port, sourceId);
    if (source == null || date == null) {
      return null;
    }
    return ScheduleItemInstance(item: source, date: date);
  }

  static Future<void> add(
    TimetableScheduleItemPort port,
    ScheduleItem item,
  ) async {
    await port.initialize();
    final normalizedItem = normalize(item);
    port.scheduleItems = sort(<ScheduleItem>[
      ...port.scheduleItems,
      normalizedItem,
    ]);
    await port.persistActiveProfileState();
    port.notifyStateChanged();
    port.logEvent('schedule_item_created', {
      'has_location': normalizedItem.location?.isNotEmpty == true ? 1 : 0,
      'has_note': normalizedItem.note?.isNotEmpty == true ? 1 : 0,
    });
    unawaited(port.syncExamReminders());
  }

  static Future<void> update(
    TimetableScheduleItemPort port,
    ScheduleItem item,
  ) async {
    await port.initialize();
    final index = port.scheduleItems.indexWhere(
      (existing) => existing.id == item.id,
    );
    if (index == -1) {
      return;
    }

    final normalizedItem = normalize(item);
    final nextItems = List<ScheduleItem>.from(port.scheduleItems);
    final existing = nextItems[index];
    if (existing.seriesId == null) {
      // Updating a root item means "all occurrences". Single-occurrence
      // overrides are intentionally discarded by this series operation.
      nextItems.removeWhere((candidate) => candidate.seriesId == existing.id);
    }
    final nextIndex = nextItems.indexWhere(
      (candidate) => candidate.id == existing.id,
    );
    if (nextIndex == -1) {
      return;
    }
    nextItems[nextIndex] = normalizedItem;
    final snapshotItems = List<ScheduleItem>.from(port.scheduleItems);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    port.scheduleItems = sort(nextItems);
    try {
      await port.persistActiveProfileState();
    } catch (_) {
      // 被系列语义连带摘掉的覆盖行也要一起退回来。
      port.scheduleItems = snapshotItems;
      port.profiles = snapshotProfiles;
      rethrow;
    }
    port.notifyStateChanged();
    port.logEvent('schedule_item_updated', {
      'has_location': normalizedItem.location?.isNotEmpty == true ? 1 : 0,
      'has_note': normalizedItem.note?.isNotEmpty == true ? 1 : 0,
    });
    unawaited(port.syncExamReminders());
  }

  static Future<void> delete(
    TimetableScheduleItemPort port,
    String itemId,
  ) async {
    await port.initialize();
    final target = find(port, itemId);
    if (target == null) {
      return;
    }
    final seriesId = target.seriesId ?? target.id;
    final previousCount = port.scheduleItems.length;
    final nextItems = port.scheduleItems
        .where((item) => item.id != seriesId && item.seriesId != seriesId)
        .toList(growable: false);
    if (nextItems.length == previousCount) {
      return;
    }

    final snapshotItems = List<ScheduleItem>.from(port.scheduleItems);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    port.scheduleItems = nextItems;
    try {
      await port.persistActiveProfileState();
    } catch (_) {
      port.scheduleItems = snapshotItems;
      port.profiles = snapshotProfiles;
      rethrow;
    }
    port.notifyStateChanged();
    port.logEvent('schedule_item_deleted', {
      'remaining_schedule_item_count': port.scheduleItems.length,
    });
    unawaited(port.syncExamReminders());
  }

  /// Deletes one occurrence while leaving the rest of its series intact.
  static Future<void> deleteOccurrence(
    TimetableScheduleItemPort port,
    String itemId,
    DateTime occurrenceDate,
  ) async {
    await port.initialize();
    final target = find(port, itemId);
    final root = seriesRoot(port, target);
    if (root == null) {
      return;
    }

    final requestedDate =
        target?.seriesId != null && target?.occurrenceDate != null
        ? target!.occurrenceDate!
        : ScheduleItem.dateOnly(occurrenceDate);
    final hasOverride = port.scheduleItems.any(
      (item) => _isOverrideForOccurrence(item, root.id, requestedDate),
    );
    if (!root.occursOn(requestedDate) && !hasOverride) {
      return;
    }

    // A date-only one-off has no remaining occurrences after this operation,
    // so removing its persisted row matches whole-item deletion semantics.
    if (root.seriesId == null &&
        root.recurrence == ScheduleRecurrence.none &&
        _isSameDate(root.startDate, root.endDate) &&
        _isSameDate(root.startDate, requestedDate)) {
      await delete(port, root.id);
      return;
    }

    final updatedRoot = root.copyWith(
      exceptionDates: _normalizedExceptionDates(
        root.exceptionDates,
        requestedDate,
      ),
      updatedAt: DateTime.now(),
    );
    final nextItems = <ScheduleItem>[];
    for (final item in port.scheduleItems) {
      if (item.id == root.id) {
        nextItems.add(updatedRoot);
      } else if (_isOverrideForOccurrence(item, root.id, requestedDate)) {
        continue;
      } else {
        nextItems.add(item);
      }
    }
    port.scheduleItems = sort(nextItems);
    await port.persistActiveProfileState();
    port.notifyStateChanged();
    port.logEvent('schedule_item_occurrence_deleted', {
      'schedule_item_id': root.id,
      'occurrence_date': ScheduleItem.formatCalendarDate(requestedDate),
    });
    unawaited(port.syncExamReminders());
  }

  /// Edits one occurrence by replacing it with a persisted one-time override.
  /// The base series stores the original date as an exception, so the base
  /// occurrence cannot reappear alongside the override.
  ///
  /// Existing editors use `root.startDate` as an unchanged-date sentinel. Set
  /// [dateWasExplicitlyEdited] when the user intentionally moves an occurrence
  /// to that same date, so the move remains distinguishable from that legacy
  /// sentinel.
  static Future<void> updateOccurrence(
    TimetableScheduleItemPort port,
    String itemId,
    DateTime occurrenceDate,
    ScheduleItem updatedItem, {
    bool dateWasExplicitlyEdited = false,
  }) async {
    await port.initialize();
    final target = find(port, itemId);
    final root = seriesRoot(port, target);
    if (root == null) {
      return;
    }

    final requestedDate =
        target?.seriesId != null && target?.occurrenceDate != null
        ? target!.occurrenceDate!
        : ScheduleItem.dateOnly(occurrenceDate);
    final existingOverride = port.scheduleItems.any(
      (item) => _isOverrideForOccurrence(item, root.id, requestedDate),
    );
    if (!root.occursOn(requestedDate) && !existingOverride) {
      return;
    }

    // Editing the only occurrence of a one-off can update the original row,
    // retaining its established id and avoiding an unnecessary override.
    if (root.seriesId == null &&
        root.recurrence == ScheduleRecurrence.none &&
        _isSameDate(root.startDate, root.endDate) &&
        _isSameDate(root.startDate, requestedDate)) {
      await update(port, updatedItem.copyWith(id: root.id));
      return;
    }

    final effectiveDate = _resolveOccurrenceEditDate(
      root: root,
      occurrenceDate: requestedDate,
      updatedItem: updatedItem,
      dateWasExplicitlyEdited: dateWasExplicitlyEdited,
    );
    final overrideId = ScheduleItem.buildOccurrenceId(root.id, requestedDate);
    final override = normalize(
      updatedItem.copyWith(
        id: overrideId,
        startDate: effectiveDate,
        endDate: effectiveDate,
        recurrence: ScheduleRecurrence.none,
        exceptionDates: const <DateTime>[],
        seriesId: root.id,
        occurrenceDate: requestedDate,
      ),
    );
    final updatedRoot = root.copyWith(
      exceptionDates: _normalizedExceptionDates(
        root.exceptionDates,
        requestedDate,
      ),
      updatedAt: DateTime.now(),
    );
    final nextItems = <ScheduleItem>[];
    for (final item in port.scheduleItems) {
      if (item.id == root.id) {
        nextItems.add(updatedRoot);
      } else if (_isOverrideForOccurrence(item, root.id, requestedDate)) {
        continue;
      } else {
        nextItems.add(item);
      }
    }
    nextItems.add(override);
    port.scheduleItems = sort(nextItems);
    await port.persistActiveProfileState();
    port.notifyStateChanged();
    port.logEvent('schedule_item_occurrence_updated', {
      'schedule_item_id': root.id,
      'occurrence_date': ScheduleItem.formatCalendarDate(requestedDate),
    });
    unawaited(port.syncExamReminders());
  }

  /// Convenience API for callers holding the stable occurrence id.
  static Future<void> deleteInstance(
    TimetableScheduleItemPort port,
    String occurrenceId,
  ) async {
    await port.initialize();
    final instance = findInstanceById(port, occurrenceId);
    if (instance == null) {
      return;
    }
    await deleteOccurrence(port, instance.sourceItemId, instance.occurrenceDate);
  }

  /// Convenience API for callers holding the stable occurrence id.
  static Future<void> updateInstance(
    TimetableScheduleItemPort port,
    String occurrenceId,
    ScheduleItem updatedItem, {
    bool dateWasExplicitlyEdited = false,
  }) async {
    await port.initialize();
    final instance = findInstanceById(port, occurrenceId);
    if (instance == null) {
      return;
    }
    await updateOccurrence(
      port,
      instance.sourceItemId,
      instance.occurrenceDate,
      updatedItem,
      dateWasExplicitlyEdited: dateWasExplicitlyEdited,
    );
  }

  static bool _isOverrideForOccurrence(
    ScheduleItem item,
    String seriesId,
    DateTime occurrenceDate,
  ) {
    if (item.seriesId != seriesId) {
      return false;
    }
    final candidateDate = item.occurrenceDate ?? item.startDate;
    return _isSameDate(candidateDate, occurrenceDate);
  }

  static DateTime _resolveOccurrenceEditDate({
    required ScheduleItem root,
    required DateTime occurrenceDate,
    required ScheduleItem updatedItem,
    required bool dateWasExplicitlyEdited,
  }) {
    final requestedDate = ScheduleItem.dateOnly(updatedItem.startDate);
    // A copy of the series item usually carries the series start date. Treat
    // that unchanged value as "keep this occurrence's date" unless the caller
    // explicitly reports that the date field was edited.
    if (!dateWasExplicitlyEdited &&
        _isSameDate(requestedDate, root.startDate)) {
      return ScheduleItem.dateOnly(occurrenceDate);
    }
    return requestedDate;
  }

  static List<DateTime> _normalizedExceptionDates(
    List<DateTime> existing,
    DateTime candidate,
  ) {
    final normalizedCandidate = ScheduleItem.dateOnly(candidate);
    final merged = <String, DateTime>{};
    for (final date in existing) {
      final normalized = ScheduleItem.dateOnly(date);
      merged[ScheduleItem.formatCalendarDate(normalized)] = normalized;
    }
    merged[ScheduleItem.formatCalendarDate(normalizedCandidate)] =
        normalizedCandidate;
    final result = merged.values.toList()..sort((a, b) => a.compareTo(b));
    return result;
  }

  static bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
