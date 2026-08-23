import '../models/class_reminder.dart';
import '../models/course.dart';
import 'exam_reminder_service.dart';

/// 把「单节课提醒」条目展开成原生 AlarmManager 可调度的通知触发点。
///
/// 复用考试提醒的 reconcile 管线（同一 MethodChannel、同一快照持久化与
/// 开机重建），本类只负责纯计算：身份 id、requestCode、时间解析与过滤。
/// 原生侧对 examId 字符串完全通用，无需任何改动。
abstract final class ClassReminderService {
  /// 默认提前量：一键添加时「上课前 N 分钟」。与设置页历史默认一致。
  static const int defaultLeadMinutes = 30;

  /// 解析 "HH:mm" 为当日分钟数；格式非法或越界返回 null。
  static int? parseClockMinutes(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  /// 把当日分钟数格式化回 "HH:mm"（自动归一到一天内）。
  static String formatClock(int minutes) {
    var normalized = minutes % 1440;
    if (normalized < 0) {
      normalized += 1440;
    }
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// 条目所在真实日期的完整本地时间（即提醒响点）。
  static DateTime? occurrenceDateTime(ClassReminderEntry entry) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(entry.date);
    if (match == null) {
      return null;
    }
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day, entry.minuteOfDay ~/ 60, entry.minuteOfDay % 60);
  }

  /// 与原生取消逻辑共享的稳定 requestCode；minuteOfDay 参与哈希，
  /// 因此用户修改提醒时间后旧 PendingIntent 身份随之改变。
  static int requestCode(ClassReminderEntry entry) =>
      ExamReminderService.stableRequestCode(entry.id, entry.minuteOfDay);

  /// 展开为未来的通知触发点。课程已删除、日期非法或响点已过期的条目
  /// 直接丢弃——原生 reconcile 全量重建，不会残留旧调度。
  static List<ExamReminderFire> buildFires({
    required List<ClassReminderEntry> entries,
    required Course? Function(String courseId) resolveCourse,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final fires = <ExamReminderFire>[];
    for (final entry in entries) {
      if (!entry.isValid) {
        continue;
      }
      final course = resolveCourse(entry.courseId);
      if (course == null) {
        continue;
      }
      final fireAt = occurrenceDateTime(entry);
      if (fireAt == null || !fireAt.isAfter(referenceNow)) {
        continue;
      }
      final location = course.location.trim();
      fires.add(
        ExamReminderFire(
          examId: entry.id,
          offsetMinutes: entry.minuteOfDay,
          fireAtMillis: fireAt.millisecondsSinceEpoch,
          examStartMillis: fireAt.millisecondsSinceEpoch,
          title: course.name.trim(),
          body: location,
          requestCode: requestCode(entry),
        ),
      );
    }
    fires.sort((a, b) => a.fireAtMillis.compareTo(b.fireAtMillis));
    return fires;
  }
}
