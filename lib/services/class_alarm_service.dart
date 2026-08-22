import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One alarm payload destined for the system Clock app via ACTION_SET_ALARM.
///
/// The Android public contract only supports "hour + minute + weekly repeat";
/// there is no way to express "only on this exact date", so every plan created
/// here repeats weekly on [repeatDays] until the user deletes it in the clock
/// app.
@immutable
class ClassAlarmPlan {
  const ClassAlarmPlan({
    required this.hour,
    required this.minute,
    required this.label,
    required this.repeatDays,
    required this.skipUi,
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

  /// Returns a copy with the given fields replaced; label/skipUi default to
  /// the original values so callers can fill them in at dispatch time.
  ClassAlarmPlan copyWith({String? label, bool? skipUi}) => ClassAlarmPlan(
        hour: hour,
        minute: minute,
        label: label ?? this.label,
        repeatDays: repeatDays,
        skipUi: skipUi ?? this.skipUi,
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
  const ClassAlarmResult({required this.launched, this.error});

  final bool launched;
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
        'days': plan.repeatDays,
      };
      final raw = await _channel.invokeMethod<Object?>('setAlarm', args);
      final map = raw != null
          ? Map<String, Object?>.from(raw as Map)
          : const <String, Object?>{};
      return ClassAlarmResult(launched: map['launched'] == true);
    } on PlatformException catch (error) {
      return ClassAlarmResult(
        launched: false,
        error: error.message ?? error.code,
      );
    } on MissingPluginException {
      return const ClassAlarmResult(
        launched: false,
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

  /// Maps ISO weekday (1=Mon .. 7=Sun) to the java.util.Calendar day-of-week
  /// constant required by the EXTRA_DAYS contract (SUNDAY=1 ... SATURDAY=7).
  /// Returns 0 for out-of-range input; callers treat 0 as "skip this day".
  static int calendarWeekday(int dayOfWeek) => const {
        1: 2, // Calendar.MONDAY
        2: 3, // Calendar.TUESDAY
        3: 4, // Calendar.WEDNESDAY
        4: 5, // Calendar.THURSDAY
        5: 6, // Calendar.FRIDAY
        6: 7, // Calendar.SATURDAY
        7: 1, // Calendar.SUNDAY
      }[dayOfWeek] ?? 0;

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

  /// Builds one weekly plan for a single course series ("arm this course").
  ///
  /// The alarm repeats on the course weekday at its own start time minus the
  /// lead. When the ring time wraps below midnight (huge lead before a
  /// first-section class right after 00:00) both the hour/minute and the
  /// repeat weekday shift to the previous calendar day, so the alarm fires
  /// shortly BEFORE the class instead of nearly 24 hours after it.
  static ClassAlarmPlan? buildCourseWeeklyPlan({
    required int dayOfWeek,
    required String startTime,
    required String label,
    int leadMinutes = 30,
    bool skipUi = false,
  }) {
    final start = parseClockMinutes(startTime);
    if (start == null || calendarWeekday(dayOfWeek) == 0) {
      return null;
    }
    final rawRing = start - clampLeadMinutes(leadMinutes);
    final ring = ((rawRing % 1440) + 1440) % 1440;
    final ringDay =
        rawRing < 0 ? (dayOfWeek == 1 ? 7 : dayOfWeek - 1) : dayOfWeek;
    return ClassAlarmPlan(
      hour: ring ~/ 60,
      minute: ring % 60,
      label: label,
      repeatDays: [calendarWeekday(ringDay)],
      skipUi: skipUi,
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
  ///
  /// Ring times that wrap below midnight (lead larger than a first-section
  /// start right after 00:00) shift both the clock time and the repeat weekday
  /// to the previous calendar day: e.g. Monday 00:20 with a 30-minute lead
  /// becomes Sunday 23:50, which is when the phone must actually ring.
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

    // Bucket stable weekdays by their shared ring time. Days are keyed by the
    // RING day, not the class day: a ring time wrapped below midnight belongs
    // to the previous weekday.
    final lead = clampLeadMinutes(leadMinutes);
    final buckets = <int, List<int>>{};
    for (final entry in timesByDay.entries) {
      if (entry.value.length != 1) {
        continue;
      }
      final rawRing = entry.value.first - lead;
      final ring = ((rawRing % 1440) + 1440) % 1440;
      final ringDay =
          rawRing < 0 ? (entry.key == 1 ? 7 : entry.key - 1) : entry.key;
      buckets.putIfAbsent(ring, () => []).add(ringDay);
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
              for (final day in weekDays) calendarWeekday(day),
            ]..sort(),
            skipUi: false,
          ),
        ),
      );
    }
    return ClassAlarmGrouping(groups: groups, variableDays: variableDays);
  }
}
