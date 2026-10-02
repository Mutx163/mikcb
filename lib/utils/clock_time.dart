/// `"HH:MM"` 时钟串的容错解析。
///
/// 为什么要单独收口：全仓同类解析几乎都带 `parts.length != 2` + `int.tryParse`
/// 守卫（例如 `lib/domain/live_activity_logic.dart:39-50`、
/// `lib/screens/timetable_screen.dart:6648-6657`），唯独作息管理页与「快速生成
/// 作息」抽屉是裸 `int.parse(parts[0])`。而 `SectionTime.fromJson`
/// （`lib/models/timetable_settings.dart:975-983`）只要求"非空字符串"，
/// `"08.30"`、`"8"`、`"上午8点"` 都能进库 —— 于是这些值一到 UI 就抛
/// FormatException/RangeError，被 async 吞掉后表现为「点某一节的时间没反应」，
/// 用户既改不动也不知道为什么。
class ClockTime {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// 解析失败（缺列、非数字、越界）返回 null，由调用方决定兜底值。
  static ClockTime? tryParse(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final parts = text.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return ClockTime(hour, minute);
  }

  /// 相对当天 00:00 的分钟数，供排序与跨度比较使用。
  int get totalMinutes => hour * 60 + minute;

  /// 规范化文本形态 `HH:MM`。
  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
