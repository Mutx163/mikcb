import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 系统时钟闹钟payload，通过 ACTION_SET_ALARM 写入。
@immutable
class SystemAlarmPlan {
  const SystemAlarmPlan({
    required this.hour,
    required this.minute,
    required this.label,
    required this.repeatDays,
    required this.skipUi,
  });

  final int hour;
  final int minute;
  final String label;
  final List<int> repeatDays;
  final bool skipUi;

  SystemAlarmPlan copyWith({String? label, bool? skipUi}) => SystemAlarmPlan(
        hour: hour,
        minute: minute,
        label: label ?? this.label,
        repeatDays: repeatDays,
        skipUi: skipUi ?? this.skipUi,
      );
}

@immutable
class SystemAlarmResult {
  const SystemAlarmResult({required this.launched, this.error});

  final bool launched;
  final String? error;
}

class SystemAlarmService {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/system_alarm',
  );

  static Future<SystemAlarmResult> addAlarm(SystemAlarmPlan plan) async {
    try {
      final args = <String, Object?>{
        'hour': plan.hour,
        'minute': plan.minute,
        'label': plan.label,
        'skipUi': plan.skipUi,
        'days': plan.repeatDays,
      };
      final raw = await _channel.invokeMethod<Object?>('setAlarm', args);
      final map = raw != null
          ? Map<String, Object?>.from(raw as Map)
          : const <String, Object?>{};
      return SystemAlarmResult(launched: map['launched'] == true);
    } on PlatformException catch (error) {
      return SystemAlarmResult(
        launched: false,
        error: error.message ?? error.code,
      );
    } on MissingPluginException {
      return const SystemAlarmResult(
        launched: false,
        error: 'unsupported_platform',
      );
    }
  }

  static Future<bool> openSystemAlarms() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('showAlarms');
      if (raw is bool) return raw;
      return raw != null;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

abstract final class SystemAlarmLogic {
  static int? parseClockMinutes(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  static String formatClock(int minutes) {
    var normalized = minutes % 1440;
    if (normalized < 0) normalized += 1440;
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// ISO 1=Mon..7=Sun -> Calendar SUNDAY=1..SATURDAY=7
  static int calendarWeekday(int dayOfWeek) => const {
        1: 2,
        2: 3,
        3: 4,
        4: 5,
        5: 6,
        6: 7,
        7: 1,
      }[dayOfWeek] ?? 0;

  /// calendarWeekday 的逆映射：Calendar SUNDAY=1..SATURDAY=7 -> ISO 1=Mon..7=Sun。
  static int isoWeekdayFromCalendar(int calendarDay) => const {
        1: 7,
        2: 1,
        3: 2,
        4: 3,
        5: 4,
        6: 5,
        7: 6,
      }[calendarDay] ?? 0;

  static int clampLeadMinutes(int minutes) {
    if (minutes < 0) return 0;
    if (minutes > 120) return 120;
    return minutes;
  }

  /// 为单门课程生成每周重复闹钟。
  /// 响点 = startTime - leadMinutes，若越过午夜则重复星期前移一天。
  static SystemAlarmPlan? buildCourseWeeklyPlan({
    required int dayOfWeek,
    required String startTime,
    required String label,
    int leadMinutes = 30,
    bool skipUi = false,
  }) {
    final start = parseClockMinutes(startTime);
    if (start == null || calendarWeekday(dayOfWeek) == 0) return null;
    final rawRing = start - clampLeadMinutes(leadMinutes);
    final ring = ((rawRing % 1440) + 1440) % 1440;
    final ringDay = rawRing < 0 ? (dayOfWeek == 1 ? 7 : dayOfWeek - 1) : dayOfWeek;
    return SystemAlarmPlan(
      hour: ring ~/ 60,
      minute: ring % 60,
      label: label,
      repeatDays: [calendarWeekday(ringDay)],
      skipUi: skipUi,
    );
  }
}
