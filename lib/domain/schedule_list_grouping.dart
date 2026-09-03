import '../models/schedule_item.dart';

/// 日程列表页的一行数据：系列根条目 + 解析后的时间状态。
///
/// [nextDate] 是自参考日（含当天）起下一次发生的日期（仅日成分）；
/// 已过期为 null。跨天进行中的单次日程取其开始日（过去值），
/// 排序时自然置顶，展示层据此渲染「进行中」标签。
class ScheduleListEntry {
  final ScheduleItem item;
  final DateTime? nextDate;

  /// 单次日程已开始且今天仍处于 [startDate, endDate] 区间内。
  final bool ongoing;

  const ScheduleListEntry({
    required this.item,
    required this.nextDate,
    this.ongoing = false,
  });

  bool get isExpired => nextDate == null;
}

/// 日程列表页的三组行：即将到来 / 已过期 / 已暂停。
class ScheduleListGroups {
  final List<ScheduleListEntry> upcoming;
  final List<ScheduleListEntry> past;
  final List<ScheduleListEntry> paused;

  const ScheduleListGroups({
    required this.upcoming,
    required this.past,
    required this.paused,
  });

  bool get isEmpty => upcoming.isEmpty && past.isEmpty && paused.isEmpty;
}

/// 日程列表页分组领域服务（纯 Dart，无 Flutter / IO 依赖）。
///
/// 与 [ScheduleItemExpander] 同源的收口思路：持久化列表里混着系列
/// 单次覆盖（seriesId 非空），它们不是独立条目，列表只收系列根；
/// 时间状态交给 [ScheduleItem.occursOn] 判定，这里只做跨条目的
/// 分组与排序组装。
abstract final class ScheduleListGrouper {
  /// 按 启用/暂停 与 下次发生日是否不早于今天 分成三组并排序。
  static ScheduleListGroups group(List<ScheduleItem> items, DateTime now) {
    final today = ScheduleItem.dateOnly(now);
    final upcoming = <ScheduleListEntry>[];
    final past = <ScheduleListEntry>[];
    final paused = <ScheduleListEntry>[];
    for (final item in items) {
      // 单次覆盖是重复日程的实例级数据，编辑/删除入口在日视图卡片与
      // 表单里；列表混入会出现同标题双行。
      if (item.seriesId != null) {
        continue;
      }
      final entry = _resolveEntry(item, today);
      if (!item.enabled) {
        paused.add(entry);
      } else if (entry.isExpired) {
        past.add(entry);
      } else {
        upcoming.add(entry);
      }
    }
    return ScheduleListGroups(
      upcoming: _sortUpcoming(upcoming),
      past: _sortPast(past),
      paused: _sortPaused(paused),
    );
  }

  static ScheduleListEntry _resolveEntry(ScheduleItem item, DateTime today) {
    final start = ScheduleItem.dateOnly(item.startDate);
    final end = ScheduleItem.dateOnly(item.endDate);
    if (item.isRecurring) {
      // 重复日程：自 max(startDate, today) 起找第一个 occursOn 命中日。
      // 循环由 endDate 兜底，异常日列表在 occursOn 内判定。
      var cursor = start.isAfter(today) ? start : today;
      while (!cursor.isAfter(end)) {
        if (item.occursOn(cursor)) {
          return ScheduleListEntry(item: item, nextDate: cursor);
        }
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }
      return ScheduleListEntry(item: item, nextDate: null);
    }
    if (!start.isBefore(today)) {
      return ScheduleListEntry(item: item, nextDate: start);
    }
    if (!today.isAfter(end)) {
      // 跨天进行中的单次日程：开始日早于今天但区间仍覆盖今天。
      return ScheduleListEntry(item: item, nextDate: start, ongoing: true);
    }
    return ScheduleListEntry(item: item, nextDate: null);
  }

  /// 即将到来：下次发生日 → 开始时间 → 结束时间 → id。
  static List<ScheduleListEntry> _sortUpcoming(List<ScheduleListEntry> entries) {
    entries.sort((left, right) {
      final dateCompare = left.nextDate!.compareTo(right.nextDate!);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final startCompare = left.item.startTime.compareTo(right.item.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      final endCompare = left.item.endTime.compareTo(right.item.endTime);
      if (endCompare != 0) {
        return endCompare;
      }
      return left.item.id.compareTo(right.item.id);
    });
    return List.unmodifiable(entries);
  }

  /// 已过期：结束日期新的在前，同日按开始时间倒序，id 兜底。
  static List<ScheduleListEntry> _sortPast(List<ScheduleListEntry> entries) {
    entries.sort((left, right) {
      final endCompare = ScheduleItem.dateOnly(
        right.item.endDate,
      ).compareTo(ScheduleItem.dateOnly(left.item.endDate));
      if (endCompare != 0) {
        return endCompare;
      }
      final startCompare = right.item.startTime.compareTo(left.item.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      return left.item.id.compareTo(right.item.id);
    });
    return List.unmodifiable(entries);
  }

  /// 已暂停：按时间性下次发生日（无则退回开始日）新的在前，id 兜底。
  static List<ScheduleListEntry> _sortPaused(List<ScheduleListEntry> entries) {
    entries.sort((left, right) {
      final leftKey = left.nextDate ?? ScheduleItem.dateOnly(left.item.startDate);
      final rightKey = right.nextDate ??
          ScheduleItem.dateOnly(right.item.startDate);
      final keyCompare = rightKey.compareTo(leftKey);
      if (keyCompare != 0) {
        return keyCompare;
      }
      return left.item.id.compareTo(right.item.id);
    });
    return List.unmodifiable(entries);
  }
}
