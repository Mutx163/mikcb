import 'dart:convert';

/// Repetition frequencies supported by a [ScheduleItem].
///
/// All schedule dates are local calendar dates. Time-zone offsets in input
/// [DateTime] values are reduced to their year/month/day components before
/// matching or serializing them.
enum ScheduleRecurrence {
  none,
  daily,
  weekly;

  String get value => switch (this) {
    ScheduleRecurrence.none => 'none',
    ScheduleRecurrence.daily => 'daily',
    ScheduleRecurrence.weekly => 'weekly',
  };

  static ScheduleRecurrence fromValue(Object? raw) {
    if (raw is ScheduleRecurrence) {
      return raw;
    }
    final value = raw?.toString().trim().toLowerCase();
    return switch (value) {
      'daily' || 'day' => ScheduleRecurrence.daily,
      'weekly' || 'week' => ScheduleRecurrence.weekly,
      _ => ScheduleRecurrence.none,
    };
  }
}

// Aliases keep the contract readable for callers that use "repeat" wording.
typedef ScheduleRepeat = ScheduleRecurrence;
typedef ScheduleRepeatFrequency = ScheduleRecurrence;
typedef ScheduleRepeatRule = ScheduleRecurrence;

/// One occurrence of a schedule item on a concrete local calendar date.
///
/// [item] is the persisted source item. For a recurring item, [date] is the
/// actual occurrence date and [occurrenceDate] is the same date. A one-time
/// override keeps its original series date in [occurrenceDate], even when the
/// override was moved to another date.
class ScheduleItemInstance {
  final ScheduleItem item;
  final DateTime date;
  final DateTime occurrenceDate;

  ScheduleItemInstance({
    required this.item,
    required DateTime date,
    DateTime? occurrenceDate,
  }) : date = ScheduleItem.dateOnly(date),
       occurrenceDate = ScheduleItem.dateOnly(occurrenceDate ?? date);

  ScheduleItem get scheduleItem => item;
  ScheduleItem get sourceItem => item;
  String get title => item.title;
  String? get location => item.location;
  String? get note => item.note;
  String get startTime => item.startTime;
  String get endTime => item.endTime;
  String get color => item.color;
  DateTime get startDate => item.isRecurring ? date : item.startDate;
  DateTime get endDate => item.isRecurring ? date : item.endDate;
  String get sourceItemId => item.seriesId ?? item.id;
  String get sourceId => sourceItemId;
  String get id => occurrenceId;

  /// Stable key for this series occurrence.
  String get occurrenceId {
    if (item.isRecurring || item.seriesId != null) {
      return ScheduleItem.buildOccurrenceId(sourceItemId, occurrenceDate);
    }
    return item.id;
  }

  String get instanceId => occurrenceId;
  bool get isSeriesOverride => item.seriesId != null;

  /// A display copy whose dates describe this occurrence, when applicable.
  /// The persisted source item remains available through [item].
  ScheduleItem get materializedItem {
    if (!item.isRecurring) {
      return item;
    }
    return item.copyWith(startDate: date, endDate: date);
  }

  ScheduleItem get effectiveItem => materializedItem;
}

typedef ScheduleItemOccurrence = ScheduleItemInstance;

class ScheduleItem {
  static const Object _unset = Object();

  final String id;
  final String title;
  final String? location;
  final String? note;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ScheduleRecurrence recurrence;
  final List<DateTime> exceptionDates;
  final int? reminderMinutesBefore;
  final bool enabled;

  /// Non-null only for a persisted one-time override belonging to a series.
  final String? seriesId;

  /// The original date in the parent series represented by an override.
  final DateTime? occurrenceDate;

  ScheduleItem({
    required this.id,
    required this.title,
    this.location,
    this.note,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    required this.startTime,
    required this.endTime,
    this.color = '#5B9CF6',
    required this.createdAt,
    required this.updatedAt,
    Object? recurrence = ScheduleRecurrence.none,
    Object? repeat = _unset,
    Object? repeatRule = _unset,
    Object? recurrenceRule = _unset,
    Iterable<DateTime>? exceptionDates,
    Iterable<DateTime>? exceptions,
    Iterable<DateTime>? excludedDates,
    this.seriesId,
    DateTime? occurrenceDate,
    int? reminderMinutesBefore,
    this.enabled = true,
  }) : startDate = _normalizeDate(startDate ?? date ?? DateTime.now()),
       endDate = _resolveNormalizedEndDate(
         startDate: startDate ?? date ?? DateTime.now(),
         endDate: endDate,
       ),
       reminderMinutesBefore = _parseReminderMinutes(reminderMinutesBefore),
       recurrence = ScheduleRecurrence.fromValue(
         !identical(recurrenceRule, _unset)
             ? recurrenceRule
             : !identical(repeatRule, _unset)
             ? repeatRule
             : identical(repeat, _unset)
             ? recurrence
             : repeat,
       ),
       exceptionDates = _normalizeDateList(
         exceptionDates ?? exceptions ?? excludedDates ?? const <DateTime>[],
       ),
       occurrenceDate = occurrenceDate == null
           ? null
           : _normalizeDate(occurrenceDate);

  DateTime get date => startDate;

  ScheduleRecurrence get repeat => recurrence;
  ScheduleRecurrence get repeatRule => recurrence;
  ScheduleRecurrence get recurrenceRule => recurrence;
  List<DateTime> get exceptions => exceptionDates;
  List<DateTime> get excludedDates => exceptionDates;
  bool get isRecurring => recurrence != ScheduleRecurrence.none;
  bool get hasRecurrence => isRecurring;
  bool get isSeriesOverride => seriesId != null;
  String get seriesRootId => seriesId ?? id;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'note': note,
      // Keep all three date keys for older profile/backup payloads.
      'date': _normalizeDate(startDate).toIso8601String(),
      'startDate': _normalizeDate(startDate).toIso8601String(),
      'endDate': _normalizeDate(endDate).toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'recurrence': recurrence.value,
      'exceptionDates': exceptionDates.map(formatCalendarDate).toList(),
      'seriesId': seriesId,
      'occurrenceDate': occurrenceDate == null
          ? null
          : formatCalendarDate(occurrenceDate!),
      'reminderMinutesBefore': reminderMinutesBefore,
      'enabled': enabled,
    };
  }

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final legacyDate = _tryParseDate(json['date']);
    final parsedStartDate = _tryParseDate(json['startDate']);
    final parsedEndDate = _tryParseDate(json['endDate']);
    final rawExceptions =
        json['exceptionDates'] ?? json['exceptions'] ?? json['excludedDates'];
    final rawSeriesId = json['seriesId']?.toString();
    final parsedOccurrenceDate = _tryParseDate(json['occurrenceDate']);
    final rawReminder =
        json['reminderMinutesBefore'] ??
        json['reminderMinutes'] ??
        json['reminder'];

    return ScheduleItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      location: json['location'] as String?,
      note: json['note'] as String?,
      startDate: _normalizeDate(parsedStartDate ?? legacyDate ?? now),
      endDate: _normalizeDate(
        parsedEndDate ?? parsedStartDate ?? legacyDate ?? now,
      ),
      startTime: json['startTime'] as String? ?? '08:00',
      endTime: json['endTime'] as String? ?? '09:00',
      color: json['color'] as String? ?? '#5B9CF6',
      createdAt: _tryParseDate(json['createdAt']) ?? now,
      updatedAt: _tryParseDate(json['updatedAt']) ?? now,
      recurrence:
          json['recurrence'] ??
          json['recurrenceRule'] ??
          json['repeatRule'] ??
          json['repeat'] ??
          json['repeatFrequency'],
      exceptionDates: _parseDateList(rawExceptions),
      seriesId: rawSeriesId == null || rawSeriesId.trim().isEmpty
          ? null
          : rawSeriesId,
      occurrenceDate: parsedOccurrenceDate,
      reminderMinutesBefore: _parseReminderMinutes(rawReminder),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ScheduleItem.fromJsonString(String jsonString) {
    return ScheduleItem.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  ScheduleItem copyWith({
    String? id,
    String? title,
    Object? location = _unset,
    Object? note = _unset,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? recurrence = _unset,
    Object? repeat = _unset,
    Object? repeatRule = _unset,
    Object? recurrenceRule = _unset,
    Object? exceptionDates = _unset,
    Object? exceptions = _unset,
    Object? excludedDates = _unset,
    Object? seriesId = _unset,
    Object? occurrenceDate = _unset,
    Object? reminderMinutesBefore = _unset,
    bool? enabled,
  }) {
    final resolvedStartDate = startDate ?? date ?? this.startDate;
    final resolvedRecurrence = identical(recurrence, _unset)
        ? (identical(recurrenceRule, _unset)
              ? (identical(repeatRule, _unset)
                    ? (identical(repeat, _unset) ? this.recurrence : repeat)
                    : repeatRule)
              : recurrenceRule)
        : recurrence;
    final resolvedExceptionDates = identical(exceptionDates, _unset)
        ? (identical(exceptions, _unset)
              ? (identical(excludedDates, _unset)
                    ? this.exceptionDates
                    : excludedDates)
              : exceptions)
        : exceptionDates;
    return ScheduleItem(
      id: id ?? this.id,
      title: title ?? this.title,
      location: identical(location, _unset)
          ? this.location
          : location as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      startDate: resolvedStartDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recurrence: resolvedRecurrence,
      exceptionDates: _dateIterableFrom(resolvedExceptionDates),
      seriesId: identical(seriesId, _unset)
          ? this.seriesId
          : seriesId as String?,
      occurrenceDate: identical(occurrenceDate, _unset)
          ? this.occurrenceDate
          : occurrenceDate as DateTime?,
      reminderMinutesBefore: identical(reminderMinutesBefore, _unset)
          ? this.reminderMinutesBefore
          : _parseReminderMinutes(reminderMinutesBefore),
      enabled: enabled ?? this.enabled,
    );
  }

  /// Whether this item has an occurrence on [value].
  bool occursOn(DateTime value) {
    final normalizedValue = _normalizeDate(value);
    if (normalizedValue.isBefore(startDate) ||
        normalizedValue.isAfter(endDate)) {
      return false;
    }
    if (_containsDate(exceptionDates, normalizedValue)) {
      return false;
    }
    if (isSeriesOverride || recurrence == ScheduleRecurrence.none) {
      return true;
    }
    return switch (recurrence) {
      ScheduleRecurrence.daily => true,
      ScheduleRecurrence.weekly => normalizedValue.weekday == startDate.weekday,
      ScheduleRecurrence.none => true,
    };
  }

  /// Backward-compatible name for the original date-range query.
  bool coversDate(DateTime value) => occursOn(value);

  /// Expands this item into concrete local calendar instances in an inclusive
  /// date range. A range with an end before its start returns no instances.
  List<ScheduleItemInstance> expandInstances({
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final normalizedFrom = _normalizeDate(fromDate);
    final normalizedTo = _normalizeDate(toDate);
    if (normalizedTo.isBefore(normalizedFrom)) {
      return const <ScheduleItemInstance>[];
    }

    final first = normalizedFrom.isAfter(startDate)
        ? normalizedFrom
        : startDate;
    final last = normalizedTo.isBefore(endDate) ? normalizedTo : endDate;
    if (last.isBefore(first)) {
      return const <ScheduleItemInstance>[];
    }

    final instances = <ScheduleItemInstance>[];
    var current = first;
    while (!current.isAfter(last)) {
      if (occursOn(current)) {
        instances.add(
          ScheduleItemInstance(
            item: this,
            date: current,
            occurrenceDate: isSeriesOverride
                ? occurrenceDate ?? current
                : current,
          ),
        );
      }
      current = _nextDate(current);
    }
    return List.unmodifiable(instances);
  }

  List<ScheduleItemInstance> instancesBetween(
    DateTime fromDate,
    DateTime toDate,
  ) {
    return expandInstances(fromDate: fromDate, toDate: toDate);
  }

  List<DateTime> occurrenceDates({
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return expandInstances(
      fromDate: fromDate,
      toDate: toDate,
    ).map((instance) => instance.date).toList(growable: false);
  }

  List<DateTime> expandDates({
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return occurrenceDates(fromDate: fromDate, toDate: toDate);
  }

  String occurrenceIdFor(DateTime date) {
    if (isRecurring || seriesId != null) {
      return buildOccurrenceId(
        seriesRootId,
        seriesId != null ? occurrenceDate ?? date : date,
      );
    }
    return id;
  }

  String instanceIdFor(DateTime date) => occurrenceIdFor(date);

  static String buildOccurrenceId(String seriesId, DateTime date) {
    return '$seriesId@${formatCalendarDate(date)}';
  }

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String formatCalendarDate(DateTime value) {
    final normalized = dateOnly(value);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime _normalizeDate(DateTime value) => dateOnly(value);

  static DateTime _resolveNormalizedEndDate({
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final normalizedStart = _normalizeDate(startDate);
    final normalizedEnd = _normalizeDate(endDate ?? startDate);
    if (normalizedEnd.isBefore(normalizedStart)) {
      return normalizedStart;
    }
    return normalizedEnd;
  }

  static List<DateTime> _normalizeDateList(Iterable<DateTime> dates) {
    final unique = <String, DateTime>{};
    for (final date in dates) {
      final normalized = _normalizeDate(date);
      unique[formatCalendarDate(normalized)] = normalized;
    }
    final result = unique.values.toList()..sort();
    return List.unmodifiable(result);
  }

  static List<DateTime> _parseDateList(Object? raw) {
    if (raw is! Iterable) {
      return const <DateTime>[];
    }
    final parsed = <DateTime>[];
    for (final value in raw) {
      final date = _tryParseDate(value);
      if (date != null) {
        parsed.add(date);
      }
    }
    return parsed;
  }

  static Iterable<DateTime>? _dateIterableFrom(Object? raw) {
    if (raw is! Iterable) {
      return null;
    }
    return raw.whereType<DateTime>();
  }

  static DateTime? _tryParseDate(Object? raw) {
    if (raw is DateTime) {
      return raw;
    }
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw.toString());
  }

  static bool _containsDate(Iterable<DateTime> dates, DateTime value) {
    return dates.any(
      (date) =>
          date.year == value.year &&
          date.month == value.month &&
          date.day == value.day,
    );
  }

  static int? _parseReminderMinutes(Object? raw) {
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    return value != null && value > 0 ? value : null;
  }

  static DateTime _nextDate(DateTime value) {
    // Constructing the next local date avoids DST 23/25-hour add() drift.
    return DateTime(value.year, value.month, value.day + 1);
  }
}
