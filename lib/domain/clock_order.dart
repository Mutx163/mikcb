import '../utils/clock_time.dart';

/// 按**钟表分钟数**比较两个时间文本，而不是按字符串字典序。
///
/// 为什么不能直接 `compareTo`：模型边界并不保证时间串一定是补零的 `HH:mm`。
/// `Course.fromJson`（`lib/models/course.dart:298`）与
/// `ScheduleItem.fromJson`（`lib/models/schedule_item.dart`）都是
/// `json['startTime'] as String` 原样收下，而外来数据确实会写没补零的形式
/// （备份 JSON、局域网传输包、别的工具导出的课表里 `"9:00"` 很常见）。
/// 字符串序下 `"10:00" < "9:00"`，于是课程列表、日视图与"即将到来"清单的
/// 顺序都会错 —— 而这条排序路径在仓库里有两处独立实现，各错各的。
///
/// 这里只在比较时归一，不改写存储值：读取时顺手补零会造成"读路径回写"，
/// 与本仓已经踩过的宏存储教训相同（残缺结果被当成脱敏永久存盘）。
///
/// 解析不出来的值排在能解析的值之后，两个都解析不出来时退回字典序，
/// 保证排序全序、稳定、且不会因为一条坏数据抛异常。
int compareClockText(String left, String right) {
  final a = ClockTime.tryParse(left, allowEndOfDay: true);
  final b = ClockTime.tryParse(right, allowEndOfDay: true);
  if (a == null && b == null) return left.compareTo(right);
  if (a == null) return 1;
  if (b == null) return -1;
  return a.totalMinutes.compareTo(b.totalMinutes);
}
