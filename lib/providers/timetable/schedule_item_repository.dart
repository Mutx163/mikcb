part of '../timetable_provider.dart';

/// 日程列表的**存量顺序**（写入口与读盘装配都会经过它）。
///
/// 从 `TimetableProvider` 挪进本 part 文件有两个理由：一是行数棘轮要求那个
/// 上帝类只减不增（见 `test/architecture/dependency_guards_test.dart`）；
/// 二是这条排序规则本来就和下面两个写入口是同一族。
///
/// `compareClockText` 的 import 挂在父文件上：part 文件里不允许写任何指令
/// （`The part-of directive must be the only directive in a part`），
/// 库级导入只能由父文件提供。
///
/// 钟点一律按分钟数比（`domain/clock_order.dart` 的正源）：
/// `ScheduleItem.fromJson`（models/schedule_item.dart:226）原样收下外来存档里的
/// `9:00`，而 `_normalizeScheduleItem` 只 trim 文本、归一日期，**不碰钟点**，
/// 所以字典序（'10:00' < '9:00'）会把同一天的两条日程排反。钉它的用例是
/// `test/domain/clock_order_sort_sites_test.dart`（含"重开存档后仍然有序"那条，
/// 证明外来钟点确实能进库并参与排序）。
List<ScheduleItem> _sortScheduleItems(List<ScheduleItem> source) {
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

/// 安排事项（日程）族里"一次动多行"的两个写入口。
///
/// 判据与本族其它批一致（见 `course_group_repository.dart` 开头）：**内存里被改掉的
/// 是不是用户刚刚亲口确认的那一条**。
///
/// - `updateScheduleItem` 改一个"系列根"时，按系列的语义会把这个系列的**所有单次覆盖行**
///   一起摘掉（原来只有 :2976 那行注释说明这是刻意的）。覆盖行是用户此前一次次单独确认
///   出来的记录，落盘失败时它们已经在内存里没了、盘上还全在，而下一次任意成功写入会把
///   "整系列只剩改过的那条"坐实 —— 用户视角是"那次编辑明明报了失败，重复日程里我单独
///   改过的几次却自己消失了"。
/// - `deleteScheduleItem` 按 `seriesId ?? id` 连根带覆盖整系列摘除，同一个形状。
///
/// 同族的 `addScheduleItem`（加的就是用户刚填的那条）与 `updateScheduleItemOccurrence` /
/// `deleteScheduleItemOccurrence`（改根 + 改一次覆盖，但都属于"编辑这一次"这同一个用户
/// 意图，落盘的幻影内容与意图一致）都**不回滚**，与 `addCourse` 同一口径。
Future<void> _timetableUpdateScheduleItem(
  TimetableProvider host,
  ScheduleItem item,
) async {
  await host.initialize();
  final index = host._scheduleItems.indexWhere(
    (existing) => existing.id == item.id,
  );
  if (index == -1) {
    return;
  }

  final normalizedItem = host._normalizeScheduleItem(item);
  final nextItems = List<ScheduleItem>.from(host._scheduleItems);
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
  final snapshotItems = List<ScheduleItem>.from(host._scheduleItems);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  host._scheduleItems = _sortScheduleItems(nextItems);
  try {
    await host._persistActiveProfileState();
  } catch (_) {
    // 被系列语义连带摘掉的覆盖行也要一起退回来。
    host._scheduleItems = snapshotItems;
    host._profiles = snapshotProfiles;
    rethrow;
  }
  host._notifyStateChanged();
  host._analytics.logEventLater(
    name: 'schedule_item_updated',
    parameters: {
      'has_location': normalizedItem.location?.isNotEmpty == true ? 1 : 0,
      'has_note': normalizedItem.note?.isNotEmpty == true ? 1 : 0,
    },
  );
  unawaited(host._syncExamReminders());
}

Future<void> _timetableDeleteScheduleItem(
  TimetableProvider host,
  String itemId,
) async {
  await host.initialize();
  final target = host._findScheduleItem(itemId);
  if (target == null) {
    return;
  }
  final seriesId = target.seriesId ?? target.id;
  final previousCount = host._scheduleItems.length;
  final nextItems = host._scheduleItems
      .where((item) => item.id != seriesId && item.seriesId != seriesId)
      .toList(growable: false);
  if (nextItems.length == previousCount) {
    return;
  }

  final snapshotItems = List<ScheduleItem>.from(host._scheduleItems);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  host._scheduleItems = nextItems;
  try {
    await host._persistActiveProfileState();
  } catch (_) {
    host._scheduleItems = snapshotItems;
    host._profiles = snapshotProfiles;
    rethrow;
  }
  host._notifyStateChanged();
  host._analytics.logEventLater(
    name: 'schedule_item_deleted',
    parameters: {'remaining_schedule_item_count': host._scheduleItems.length},
  );
  unawaited(host._syncExamReminders());
}
