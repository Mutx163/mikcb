import 'package:flutter/foundation.dart';

/// 单节课提醒：用户为「某一门课在某个真实日期的某一次课」设置的本地通知提醒。
///
/// 与旧的系统时钟方案不同，这里按具体日期一次性生效——假期、单双周、调休
/// 都不会误响。条目随 TimetableSettings JSON 持久化，并经云同步/备份携带。
@immutable
class ClassReminderEntry {
  const ClassReminderEntry({
    required this.courseId,
    required this.date,
    required this.minuteOfDay,
  });

  /// 所属课程 id；课程被删除后条目在 reconcile 时被自然忽略。
  final String courseId;

  /// 上课真实日期（日期作息规则换课后实际展示的那一天），格式 yyyy-MM-dd。
  final String date;

  /// 提醒响点在该日内的分钟数（0..1439）。同日内表达，不跨午夜。
  final int minuteOfDay;

  /// 全局唯一身份，同时是原生侧取消/去重用的 fire id 前缀来源。
  String get id => 'classreminder:$courseId@$date';

  bool get isValid =>
      courseId.trim().isNotEmpty &&
      _isValidDate(date) &&
      minuteOfDay >= 0 &&
      minuteOfDay <= 1439;

  ClassReminderEntry copyWith({
    String? courseId,
    String? date,
    int? minuteOfDay,
  }) => ClassReminderEntry(
        courseId: courseId ?? this.courseId,
        date: date ?? this.date,
        minuteOfDay: minuteOfDay ?? this.minuteOfDay,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'courseId': courseId,
        'date': date,
        'minuteOfDay': minuteOfDay,
      };

  /// 非法输入返回 null 而不是抛错：设置 JSON 可能来自旧版本或手改备份。
  static ClassReminderEntry? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final courseId = raw['courseId'];
    final date = raw['date'];
    final minuteOfDay = raw['minuteOfDay'];
    if (courseId is! String || date is! String || minuteOfDay is! num) {
      return null;
    }
    final entry = ClassReminderEntry(
      courseId: courseId,
      date: date,
      minuteOfDay: minuteOfDay.toInt(),
    );
    return entry.isValid ? entry : null;
  }

  static List<ClassReminderEntry> listFromJson(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (fromJson(item) case final ClassReminderEntry entry) entry,
    ];
  }

  static bool _isValidDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      return false;
    }
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) {
      return false;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }

  @override
  bool operator ==(Object other) =>
      other is ClassReminderEntry &&
      other.courseId == courseId &&
      other.date == date &&
      other.minuteOfDay == minuteOfDay;

  @override
  int get hashCode => Object.hash(courseId, date, minuteOfDay);

  @override
  String toString() => 'ClassReminderEntry($courseId, $date, $minuteOfDay)';
}
