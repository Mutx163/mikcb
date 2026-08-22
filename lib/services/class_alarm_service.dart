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
class ClassAlarmPlan {
  const ClassAlarmPlan({
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

  /// Returns a copy with the given fields replaced; label/skipUi default to
  /// the original values so callers can fill them in at dispatch time.
  ClassAlarmPlan copyWith({String? label, bool? skipUi}) => ClassAlarmPlan(
        hour: hour,
        minute: minute,
        label: label ?? this.label,
        repeatDays: repeatDays,
        skipUi: skipUi ?? this.skipUi,
        isOneShot: isOneShot,
      );
}

/// One weekly-repeat alarm bucket: weekdays whose first class shares the same
/// ring time (e.g. Mon/Wed morning group vs Fri afternoon group).
@immutable
class ClassAlarmWeeklyGroup {
  const ClassAlarmWeeklyGroup({
    required this.dayOfWeeks,
    required this.plan,
  });

  /// ISO weekdays (1=Mon .. 7=Sun) covered by this group, ascending.
  final List<int> dayOfWeeks;

  /// The weekly repeating plan shared by [dayOfWeeks].
  final ClassAlarmPlan plan;
}

/// Result of a single SET_ALARM dispatch.
@immutable
class ClassAlarmResult {
  const ClassAlarmResult({
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
class ClassAlarmDayFirstSection {
  const ClassAlarmDayFirstSection({
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
class ClassAlarmService {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/system_alarm',
  );

  /// Dispatches one SET_ALARM intent. Returns [ClassAlarmResult]
  /// instead of throwing: platform failures degrade to a launched=false
  /// result the UI can surface as a toast.
  static Future<ClassAlarmResult> addAlarm(ClassAlarmPlan plan) async {
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
      return ClassAlarmResult(
        launched: map['launched'] == true,
        skipUiApplied: map['skipUi'] == true,
      );
    } on PlatformException catch (error) {
      return ClassAlarmResult(
        launched: false,
        skipUiApplied: false,
        error: error.message ?? error.code,
      );
    } on MissingPluginException {
      return const ClassAlarmResult(
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

/// Aggregation output: merged weekly groups plus weekdays whose first-class
/// time varies inside the selected range (those cannot be represented by one
/// honest weekly-repeat alarm and are reported back to the caller).
@immutable
class ClassAlarmGrouping {
  const ClassAlarmGrouping({required this.groups, required this.variableDays});

  /// One alarm bucket per distinct ring time, ordered by ring time.
  final List<ClassAlarmWeeklyGroup> groups;

  /// ISO weekdays whose first-class start differs between weeks.
  final List<int> variableDays;
}

/// Pure helpers shared by the settings screen and unit tests.
abstract final class ClassAlarmLogic {
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
  static ClassAlarmPlan? buildSingleShotPlan({
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
    return ClassAlarmPlan(
      hour: ring ~/ 60,
      minute: ring % 60,
      label: label,
      repeatDays: const [],
      skipUi: skipUi,
      isOneShot: true,
    );
  }

  /// Buckets weekdays by their own first-class ring time and emits one
  /// weekly-repeating plan per bucket.
  ///
  /// Days whose first class happens in the morning and days whose first class
  /// is in the afternoon produce separate alarms instead of one early alarm
  /// wrongly firing every day. Input rows whose time cannot be parsed are
  /// skipped; buckets are ordered by ring time ascending. Negative ring times
  /// (huge lead before midnight) wrap below midnight so the repeat mask stays
  /// aligned with class days.
  static List<ClassAlarmWeeklyGroup> buildWeeklyGroups({
    required List<ClassAlarmDayFirstSection> days,
    required String label,
    int leadMinutes = 30,
    bool skipUi = false,
  }) {
    final buckets = <int, List<int>>{};
    for (final day in days) {
      final start = parseClockMinutes(day.startTime);
      final bit = weekdayBit(day.dayOfWeek);
      if (start == null || bit == 0) {
        continue;
      }
      final ring =
          ((start - clampLeadMinutes(leadMinutes)) % 1440 + 1440) % 1440;
      buckets.putIfAbsent(ring, () => []).add(day.dayOfWeek);
    }
    final groups = <ClassAlarmWeeklyGroup>[];
    for (final ring in buckets.keys.toList()..sort()) {
      final weekDays = buckets[ring]!.toList()..sort();
      groups.add(
        ClassAlarmWeeklyGroup(
          dayOfWeeks: weekDays,
          plan: ClassAlarmPlan(
            hour: ring ~/ 60,
            minute: ring % 60,
            label: label,
            repeatDays: [
              for (final day in weekDays) weekdayBit(day),
            ]..sort(),
            skipUi: skipUi,
            isOneShot: false,
          ),
        ),
      );
    }
    return groups;
  }

  /// Builds one weekly plan for a single course series ("arm this course").
  ///
  /// The alarm repeats on the course weekday at its own start time minus the
  /// lead; null when [startTime] cannot be parsed.
  static ClassAlarmPlan? buildCourseWeeklyPlan({
    required int dayOfWeek,
    required String startTime,
    required String label,
    int leadMinutes = 30,
    bool skipUi = false,
  }) {
    final start = parseClockMinutes(startTime);
    final bit = weekdayBit(dayOfWeek);
    if (start == null || bit == 0) {
      return null;
    }
    final ring =
        ((start - clampLeadMinutes(leadMinutes)) % 1440 + 1440) % 1440;
    return ClassAlarmPlan(
      hour: ring ~/ 60,
      minute: ring % 60,
      label: label,
      repeatDays: [bit],
      skipUi: skipUi,
      isOneShot: false,
    );
  }

  /// Merges concrete first-class occurrences (one row per week/day; a weekday
  /// may appear in many weeks) into the smallest set of honest weekly-repeating
  /// alarms.
  ///
  /// A weekday whose first-class start varies inside the selected range cannot
  /// map onto one weekly alarm; it is reported via [ClassAlarmGrouping.variableDays]
  /// instead of being silently approximated. Duplicate rows collapse first, so
  /// feeding every week of the semester is cheap and idempotent.
  static ClassAlarmGrouping groupFromOccurrences({
    required List<ClassAlarmDayFirstSection> rows,
    required int leadMinutes,
  }) {
    // Collapse duplicates and detect per-weekday time stability.
    final timesByDay = <int, Set<int>>{};
    for (final row in rows) {
      final start = parseClockMinutes(row.startTime);
      if (start == null || row.dayOfWeek < 1 || row.dayOfWeek > 7) {
        continue;
      }
      timesByDay.putIfAbsent(row.dayOfWeek, () => <int>{}).add(start);
    }
    final variableDays = <int>[
      for (final entry in timesByDay.entries)
        if (entry.value.length > 1) entry.key,
    ]..sort();

    // Bucket stable weekdays by their shared ring time.
    final buckets = <int, List<int>>{};
    for (final entry in timesByDay.entries) {
      if (entry.value.length != 1) {
        continue;
      }
      final ring =
          ((entry.value.first - clampLeadMinutes(leadMinutes)) % 1440 + 1440) %
              1440;
      buckets.putIfAbsent(ring, () => []).add(entry.key);
    }
    final groups = <ClassAlarmWeeklyGroup>[];
    for (final ring in buckets.keys.toList()..sort()) {
      final weekDays = buckets[ring]!.toList()..sort();
      groups.add(
        ClassAlarmWeeklyGroup(
          dayOfWeeks: weekDays,
          plan: ClassAlarmPlan(
            // Label is filled by the caller per user preference; keep pure.
            label: '',
            hour: ring ~/ 60,
            minute: ring % 60,
            repeatDays: [
              for (final day in weekDays) weekdayBit(day),
            ]..sort(),
            skipUi: false,
            isOneShot: false,
          ),
        ),
      );
    }
    return ClassAlarmGrouping(groups: groups, variableDays: variableDays);
  }
}
