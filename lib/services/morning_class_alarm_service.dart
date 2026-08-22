import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/timetable_settings.dart' show SectionTime;

/// One alarm payload destined for the system Clock app via ACTION_SET_ALARM.
///
/// The Android public contract only supports "hour + minute + weekly repeat
/// bitmask"; there is no way to express "only on this exact date". A plan
/// with empty [repeatDays] therefore means a one-shot alarm, while a non-empty
/// list repeats every week on those weekdays until the user deletes it.
@immutable
class MorningClassAlarmPlan {
  const MorningClassAlarmPlan({
    required this.hour,
    required this.minute,
    required this.label,
    required this.repeatDays,
    required this.skipUi,
    required this.isOneShot,
  });

  /// Alarm ring hour (0-23).
  final int hour;

  /// Alarm ring minute (0-59).
  final int minute;

  /// Label written into the clock app (EXTRA_MESSAGE).
  final String label;

  /// Weekly repeat weekday list in EXTRA_DAYS Calendar constants;
  /// empty for one-shot alarms.
  final List<int> repeatDays;

  /// Whether to request skipping the clock app confirmation page.
  final bool skipUi;

  /// True when this plan fires exactly once (no EXTRA_DAYS is sent).
  final bool isOneShot;
}

/// Result of a single SET_ALARM dispatch.
@immutable
class MorningClassAlarmResult {
  const MorningClassAlarmResult({
    required this.launched,
    required this.skipUiApplied,
    this.error,
  });

  final bool launched;
  final bool skipUiApplied;
  final String? error;
}

/// One input row describing "this weekday has a first section at HH:mm".
@immutable
class MorningClassDayFirstSection {
  const MorningClassDayFirstSection({
    required this.dayOfWeek,
    required this.startTime,
  });

  /// 1 = Monday ... 7 = Sunday (matches Course.dayOfWeek).
  final int dayOfWeek;

  /// Section start clock time, e.g. '08:00'.
  final String startTime;
}

/// Adds alarms to the system Clock app through the public
/// android.provider.AlarmClock contract. This app never owns the alarm
/// afterwards: there is no public API to read, edit or delete clock entries,
/// so all management beyond creation is delegated to the clock app itself.
class MorningClassAlarmService {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/system_alarm',
  );

  /// Dispatches one SET_ALARM intent. Returns [MorningClassAlarmResult]
  /// instead of throwing: platform failures degrade to a launched=false
  /// result the UI can surface as a toast.
  static Future<MorningClassAlarmResult> addAlarm(
    MorningClassAlarmPlan plan,
  ) async {
    try {
      final args = <String, Object?>{
        'hour': plan.hour,
        'minute': plan.minute,
        'label': plan.label,
        'skipUi': plan.skipUi,
        'days': plan.isOneShot ? null : plan.repeatDays,
      };
      final raw = await _channel.invokeMethod<Object?>('setAlarm', args);
      final map = raw != null
          ? Map<String, Object?>.from(raw as Map)
          : const <String, Object?>{};
      return MorningClassAlarmResult(
        launched: map['launched'] == true,
        skipUiApplied: map['skipUi'] == true,
      );
    } on PlatformException catch (error) {
      return MorningClassAlarmResult(
        launched: false,
        skipUiApplied: false,
        error: error.message ?? error.code,
      );
    } on MissingPluginException {
      return const MorningClassAlarmResult(
        launched: false,
        skipUiApplied: false,
        error: 'unsupported_platform',
      );
    }
  }

  /// Opens the system clock alarm list via ACTION_SHOW_ALARMS.
  static Future<bool> openSystemAlarms() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('showAlarms');
      if (raw is bool) {
        return raw;
      }
      return raw != null;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Pure helpers shared by the settings screen and unit tests.
abstract final class MorningClassAlarmLogic {
  /// Parses "HH:mm" into minutes since midnight; null when malformed.
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

  /// Earliest section start across the scheme in minutes since midnight.
  static int? firstSectionStartMinutes(List<SectionTime> sections) {
    var best = -1;
    for (final section in sections) {
      final minutes = parseClockMinutes(section.startTime);
      if (minutes == null) {
        continue;
      }
      if (best < 0 || minutes < best) {
        best = minutes;
      }
    }
    return best < 0 ? null : best;
  }

  /// Formats minutes-since-midnight back to "HH:mm" (clamped into one day).
  static String formatClock(int minutes) {
    var normalized = minutes % 1440;
    if (normalized < 0) {
      normalized += 1440;
    }
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Maps ISO weekday (1=Mon .. 7=Sun) to the EXTRA_DAYS Calendar constant
  /// used by the system clock contract (SUNDAY=1 ... SATURDAY=7).
  static int weekdayBit(int dayOfWeek) => switch (dayOfWeek) {
        1 => 2, // Calendar.MONDAY
        2 => 4, // Calendar.TUESDAY
        3 => 8, // Calendar.WEDNESDAY
        4 => 16, // Calendar.THURSDAY
        5 => 32, // Calendar.FRIDAY
        6 => 64, // Calendar.SATURDAY
        7 => 1, // Calendar.SUNDAY
        _ => 0,
      };

  /// Clamps user-configurable lead time into [0, 120] minutes.
  static int clampLeadMinutes(int minutes) {
    if (minutes < 0) {
      return 0;
    }
    if (minutes > 120) {
      return 120;
    }
    return minutes;
  }

  /// Builds the one-shot plan for one concrete class session.
  ///
  /// Returns null when the resolved ring time is already in the past: the
  /// clock app would reject or silently create an overdue alarm.
  static MorningClassAlarmPlan? buildSingleShotPlan({
    required String courseStartTime,
    required String label,
    required DateTime now,
    int leadMinutes = 30,
    bool skipUi = false,
  }) {
    final startMinutes = parseClockMinutes(courseStartTime);
    if (startMinutes == null) {
      return null;
    }
    final nowMinutes = now.hour * 60 + now.minute;
    if (nowMinutes >= startMinutes) {
      return null;
    }
    final lead = clampLeadMinutes(leadMinutes);
    final ring = startMinutes - lead;
    return MorningClassAlarmPlan(
      hour: ring ~/ 60,
      minute: ring % 60,
      label: label,
      repeatDays: const [],
      skipUi: skipUi,
      isOneShot: true,
    );
  }

  /// Builds the recurring weekly plan covering every remaining teaching day.
  ///
  /// [days] must already be filtered to weekdays whose next occurrence is
  /// today or later. The ring time derives from the earliest first-section
  /// start minus [leadMinutes]; negative results wrap below midnight and the
  /// alarm simply fires late in the previous evening on those days.
  static MorningClassAlarmPlan? buildWeeklyPlan({
    required List<MorningClassDayFirstSection> days,
    required String label,
    int leadMinutes = 30,
    bool skipUi = false,
  }) {
    if (days.isEmpty) {
      return null;
    }
    var earliestStart = -1;
    for (final day in days) {
      final minutes = parseClockMinutes(day.startTime);
      if (minutes == null) {
        continue;
      }
      if (earliestStart < 0 || minutes < earliestStart) {
        earliestStart = minutes;
      }
    }
    if (earliestStart < 0) {
      return null;
    }
    final bits = <int>{
      for (final day in days)
        if (parseClockMinutes(day.startTime) != null)
          weekdayBit(day.dayOfWeek),
    }..remove(0);
    if (bits.isEmpty) {
      return null;
    }
    final lead = clampLeadMinutes(leadMinutes);
    final ring = earliestStart - lead;
    // Wrap below midnight keeps the repeat mask aligned with class days.
    final normalizedRing = (ring % 1440 + 1440) % 1440;
    return MorningClassAlarmPlan(
      hour: normalizedRing ~/ 60,
      minute: normalizedRing % 60,
      label: label,
      repeatDays: bits.toList()..sort(),
      skipUi: skipUi,
      isOneShot: false,
    );
  }
}
