import '../models/schedule_item.dart';

/// 日程项实例展开领域服务（纯 Dart，无 Flutter / IO 依赖）。
///
/// 解耦阶段 1 自 `TimetableProvider` 收口：单条展开交给模型层
/// [ScheduleItem.expandInstances]，此处负责跨条目的去重与排序组装。
class ScheduleItemExpander {
  ScheduleItemExpander._();

  /// 展开单日实例：按显示日去重（例外覆盖胜出）并排序。
  static List<ScheduleItemInstance> instancesForDate(
    List<ScheduleItem> items,
    DateTime date,
  ) {
    final normalizedDate = ScheduleItem.dateOnly(date);
    return instancesForRange(items, normalizedDate, normalizedDate);
  }

  /// 展开闭区间 [fromDate, toDate] 内的全部实例并去重排序。
  static List<ScheduleItemInstance> instancesForRange(
    List<ScheduleItem> items,
    DateTime fromDate,
    DateTime toDate,
  ) {
    final instancesByDisplayDate = <String, ScheduleItemInstance>{};
    for (final item in items) {
      for (final instance in item.expandInstances(
        fromDate: fromDate,
        toDate: toDate,
      )) {
        putByDisplayDate(instancesByDisplayDate, instance);
      }
    }
    return sort(instancesByDisplayDate.values.toList());
  }

  /// 按显示日去重：key = `sourceItemId@yyyy-MM-dd`。
  ///
  /// 稳定的 occurrence id 仍指向系列原始日期（供持久化），但同一系列
  /// 被移动（例外覆盖）后，覆盖实例在同一天显示时优先于原系列实例。
  static void putByDisplayDate(
    Map<String, ScheduleItemInstance> instancesByDisplayDate,
    ScheduleItemInstance instance,
  ) {
    final key =
        '${instance.sourceItemId}@${ScheduleItem.formatCalendarDate(instance.date)}';
    final existing = instancesByDisplayDate[key];
    if (existing == null ||
        (instance.isSeriesOverride && !existing.isSeriesOverride)) {
      instancesByDisplayDate[key] = instance;
    }
  }

  /// 多键排序：日期 → 系列开始日 → 开始时间 → 结束时间 → occurrenceId；
  /// 返回不可变列表。
  static List<ScheduleItemInstance> sort(
    List<ScheduleItemInstance> source,
  ) {
    source.sort((left, right) {
      final dateCompare = left.date.compareTo(right.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final sourceDateCompare = left.item.startDate.compareTo(
        right.item.startDate,
      );
      if (sourceDateCompare != 0) {
        return sourceDateCompare;
      }
      final startCompare = left.item.startTime.compareTo(right.item.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      final endCompare = left.item.endTime.compareTo(right.item.endTime);
      if (endCompare != 0) {
        return endCompare;
      }
      return left.occurrenceId.compareTo(right.occurrenceId);
    });
    return List.unmodifiable(source);
  }
}
