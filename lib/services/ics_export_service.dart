import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/schedule_item.dart';
import '../models/timetable_profile.dart';

/// The kinds of timetable data that can be emitted as calendar events.
enum IcsExportEventKind {
  course,
  exam,
  scheduleItem;

  String get value => switch (this) {
    IcsExportEventKind.course => 'course',
    IcsExportEventKind.exam => 'exam',
    IcsExportEventKind.scheduleItem => 'schedule',
  };

  static const Set<IcsExportEventKind> all = <IcsExportEventKind>{
    IcsExportEventKind.course,
    IcsExportEventKind.exam,
    IcsExportEventKind.scheduleItem,
  };
}

/// Compatibility aliases for callers that use "type" or "kind" wording.
typedef IcsExportEventType = IcsExportEventKind;
typedef IcsExportKind = IcsExportEventKind;

/// Immutable input for one ICS export operation.
class IcsExportRequest {
  final TimetableProfile profile;
  final DateTime fromDate;
  final DateTime toDate;
  final Set<IcsExportEventKind> eventKinds;
  final DateTime? generatedAt;

  IcsExportRequest({
    required this.profile,
    required DateTime fromDate,
    required DateTime toDate,
    Iterable<IcsExportEventKind>? eventKinds,
    Iterable<IcsExportEventKind>? eventTypes,
    Iterable<IcsExportEventKind>? types,
    this.generatedAt,
  }) : fromDate = _dateOnly(fromDate),
       toDate = _dateOnly(toDate),
       eventKinds = Set.unmodifiable(
         eventKinds ?? eventTypes ?? types ?? IcsExportEventKind.all,
       );

  Set<IcsExportEventKind> get eventTypes => eventKinds;

  DateTime get startDate => fromDate;

  DateTime get endDate => toDate;

  bool get hasValidDateRange => !toDate.isBefore(fromDate);
}

/// The pure output of [IcsExportService].
class IcsExportResult {
  final String content;
  final int eventCount;
  final String fileName;
  final DateTime generatedAt;

  const IcsExportResult({
    required this.content,
    required this.eventCount,
    required this.fileName,
    required this.generatedAt,
  });

  String get icsContent => content;

  String get calendar => content;

  String get text => content;

  String get filename => fileName;

  int get count => eventCount;

  bool get hasEvents => eventCount > 0;
}

/// Serializes profile data into a deterministic, single-occurrence ICS file.
///
/// This class deliberately has no provider, UI, file-system, or sharing
/// dependency. The optional clock is only used when a request does not supply
/// [IcsExportRequest.generatedAt], which keeps callers and tests in control of
/// generated metadata when required.
class IcsExportService {
  IcsExportService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Generates a calendar for [request]. The input range is inclusive.
  IcsExportResult generate(IcsExportRequest request) {
    final generatedAt = (request.generatedAt ?? _clock()).toUtc();
    final events = <_IcsEvent>[];

    if (request.hasValidDateRange) {
      if (request.eventKinds.contains(IcsExportEventKind.course)) {
        events.addAll(_courseEvents(request));
      }
      if (request.eventKinds.contains(IcsExportEventKind.exam)) {
        events.addAll(_examEvents(request));
      }
      if (request.eventKinds.contains(IcsExportEventKind.scheduleItem)) {
        events.addAll(_scheduleEvents(request));
      }
    }

    final uniqueEvents = <String, _IcsEvent>{};
    for (final event in events) {
      uniqueEvents[event.uid] = event;
    }
    final sortedEvents = uniqueEvents.values.toList()..sort(_compareEvents);

    return IcsExportResult(
      content: _serializeCalendar(
        profile: request.profile,
        fromDate: request.fromDate,
        toDate: request.toDate,
        generatedAt: generatedAt,
        events: sortedEvents,
      ),
      eventCount: sortedEvents.length,
      fileName: buildFileName(
        profileName: request.profile.name,
        fromDate: request.fromDate,
        toDate: request.toDate,
      ),
      generatedAt: generatedAt,
    );
  }

  /// Builds a request from named values for thin UI adapters.
  IcsExportResult build({
    required TimetableProfile profile,
    required DateTime fromDate,
    required DateTime toDate,
    Iterable<IcsExportEventKind>? eventKinds,
    Iterable<IcsExportEventKind>? eventTypes,
    Iterable<IcsExportEventKind>? types,
    DateTime? generatedAt,
  }) {
    return generate(
      IcsExportRequest(
        profile: profile,
        fromDate: fromDate,
        toDate: toDate,
        eventKinds: eventKinds,
        eventTypes: eventTypes,
        types: types,
        generatedAt: generatedAt,
      ),
    );
  }

  /// Alias for callers that prefer serializer terminology.
  IcsExportResult serialize(IcsExportRequest request) => generate(request);

  /// Creates a stable, filesystem-safe name without profile IDs or metadata.
  static String buildFileName({
    required String profileName,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final safeProfile = _sanitizeFileNameSegment(profileName);
    final from = _formatCompactCalendarDate(_dateOnly(fromDate));
    final to = _formatCompactCalendarDate(_dateOnly(toDate));
    return '$safeProfile-$from-$to.ics';
  }

  List<_IcsEvent> _courseEvents(IcsExportRequest request) {
    final semesterStart = request.profile.settings.semesterStartDate;
    if (semesterStart == null) {
      return const <_IcsEvent>[];
    }

    final firstMonday = _mondayOf(_dateOnly(semesterStart));
    final events = <_IcsEvent>[];
    for (final course in request.profile.courses) {
      final dayOfWeek = course.dayOfWeek.clamp(1, 7);
      for (final week in course.activeWeeks) {
        if (week < 1) {
          continue;
        }
        final occurrenceDate = _addDays(
          firstMonday,
          ((week - 1) * 7) + dayOfWeek - 1,
        );
        if (!_isInRange(occurrenceDate, request.fromDate, request.toDate)) {
          continue;
        }

        final sessionNote = course.sessionNoteForWeek(week);
        final descriptionParts = <String>[
          if (course.teacher.trim().isNotEmpty) 'Teacher: ${course.teacher}',
          'Sections: ${course.startSection}-${course.endSection}',
          if (course.description?.trim().isNotEmpty == true)
            course.description!.trim(),
          if (course.note?.trim().isNotEmpty == true) course.note!.trim(),
          if (sessionNote?.text.trim().isNotEmpty == true)
            sessionNote!.text.trim(),
          if (sessionNote?.hasHomework == true) 'Homework: yes',
        ];
        final event = _buildTimedEvent(
          profile: request.profile,
          kind: IcsExportEventKind.course,
          sourceId: course.id,
          occurrenceDate: occurrenceDate,
          startTime: course.startTime,
          endTime: course.endTime,
          summary: course.name,
          location: course.location,
          description: _joinDistinct(descriptionParts),
        );
        if (event != null) {
          events.add(event);
        }
      }
    }
    return events;
  }

  List<_IcsEvent> _examEvents(IcsExportRequest request) {
    final events = <_IcsEvent>[];
    for (final exam in request.profile.exams) {
      final occurrenceDate = _dateOnly(exam.dateTime);
      if (!_isInRange(occurrenceDate, request.fromDate, request.toDate)) {
        continue;
      }

      final descriptionParts = <String>[
        if (exam.note?.trim().isNotEmpty == true) exam.note!.trim(),
        if (exam.seatNumber?.trim().isNotEmpty == true)
          'Seat: ${exam.seatNumber}',
      ];
      final event = _buildTimedEvent(
        profile: request.profile,
        kind: IcsExportEventKind.exam,
        sourceId: exam.id,
        occurrenceDate: occurrenceDate,
        startTime: exam.startTime,
        endTime: exam.endTime,
        summary: exam.name,
        location: exam.location,
        description: _joinDistinct(descriptionParts),
      );
      if (event != null) {
        events.add(event);
      }
    }
    return events;
  }

  List<_IcsEvent> _scheduleEvents(IcsExportRequest request) {
    final occurrences = <String, _ScheduleOccurrence>{};
    for (final item in request.profile.scheduleItems) {
      if (item.isRecurring) {
        for (final instance in item.expandInstances(
          fromDate: request.fromDate,
          toDate: request.toDate,
        )) {
          final key =
              '${instance.sourceItemId}|${_formatCalendarDate(instance.occurrenceDate)}';
          final existing = occurrences[key];
          if (existing == null || instance.isSeriesOverride) {
            occurrences[key] = _ScheduleOccurrence(
              item: instance.item,
              eventDate: instance.date,
              endDate: instance.date,
              occurrenceDate: instance.occurrenceDate,
            );
          }
        }
        continue;
      }

      if (!_dateRangesOverlap(
        item.startDate,
        item.endDate,
        request.fromDate,
        request.toDate,
      )) {
        continue;
      }
      final occurrenceDate = item.occurrenceDate ?? item.startDate;
      final key = '${item.seriesRootId}|${_formatCalendarDate(occurrenceDate)}';
      final existing = occurrences[key];
      if (existing == null || item.isSeriesOverride) {
        occurrences[key] = _ScheduleOccurrence(
          item: item,
          eventDate: item.startDate,
          endDate: item.endDate,
          occurrenceDate: occurrenceDate,
        );
      }
    }

    final events = <_IcsEvent>[];
    for (final occurrence in occurrences.values) {
      final item = occurrence.item;
      final event = _buildTimedEvent(
        profile: request.profile,
        kind: IcsExportEventKind.scheduleItem,
        sourceId: item.seriesRootId,
        occurrenceDate: occurrence.occurrenceDate,
        eventDate: occurrence.eventDate,
        endDate: occurrence.endDate,
        startTime: item.startTime,
        endTime: item.endTime,
        summary: item.title,
        location: item.location,
        description: item.note,
      );
      if (event != null) {
        events.add(event);
      }
    }
    return events;
  }

  _IcsEvent? _buildTimedEvent({
    required TimetableProfile profile,
    required IcsExportEventKind kind,
    required String sourceId,
    required DateTime occurrenceDate,
    DateTime? eventDate,
    DateTime? endDate,
    required String startTime,
    required String endTime,
    required String summary,
    String? location,
    String? description,
  }) {
    final startParts = _parseTime(startTime);
    final endParts = _parseTime(endTime);
    if (startParts == null || endParts == null) {
      return null;
    }

    final startDate = _dateOnly(eventDate ?? occurrenceDate);
    final start = _dateTimeAt(startDate, startParts);
    final resolvedEndDate = _dateOnly(endDate ?? startDate);
    var end = _dateTimeAt(resolvedEndDate, endParts);
    if (!end.isAfter(start)) {
      end = _addDays(end, 1);
    }

    final uidMaterial = [
      profile.id,
      kind.value,
      sourceId,
      _formatCalendarDate(_dateOnly(occurrenceDate)),
      _formatClock(start),
      _formatClock(end),
    ].join('|');
    final digest = sha256.convert(utf8.encode(uidMaterial)).toString();

    return _IcsEvent(
      uid: '$digest@qingyu-timetable.local',
      kind: kind,
      start: start,
      end: end,
      summary: summary,
      location: location,
      description: description,
    );
  }

  String _serializeCalendar({
    required TimetableProfile profile,
    required DateTime fromDate,
    required DateTime toDate,
    required DateTime generatedAt,
    required List<_IcsEvent> events,
  }) {
    final from = _formatCalendarDate(fromDate);
    final to = _formatCalendarDate(toDate);
    final calendarName = '${profile.name.trim()} $from - $to'.trim();
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'PRODID:-//Mutx163//Qingyu Timetable//EN',
      'VERSION:2.0',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-TIMEZONE:UTC',
      'X-MIKCB-SOURCE:Qingyu Timetable',
      'X-MIKCB-GENERATED-AT:${_formatUtcDateTime(generatedAt)}',
      'X-MIKCB-DATE-RANGE:$from/$to',
      'X-WR-CALNAME:${_escapeText(calendarName)}',
    ];

    for (final event in events) {
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:${event.uid}',
        'DTSTAMP:${_formatUtcDateTime(generatedAt)}',
        'DTSTART:${_formatUtcDateTime(event.start)}',
        'DTEND:${_formatUtcDateTime(event.end)}',
        'SUMMARY:${_escapeText(event.summary)}',
        if (_hasText(event.location))
          'LOCATION:${_escapeText(event.location!.trim())}',
        if (_hasText(event.description))
          'DESCRIPTION:${_escapeText(event.description!.trim())}',
        'X-MIKCB-EVENT-TYPE:${event.kind.value}',
        'END:VEVENT',
      ]);
    }
    lines.add('END:VCALENDAR');

    final foldedLines = <String>[];
    for (final line in lines) {
      foldedLines.addAll(_foldLine(line));
    }
    return '${foldedLines.join('\r\n')}\r\n';
  }

  static int _compareEvents(_IcsEvent left, _IcsEvent right) {
    final startCompare = left.start.compareTo(right.start);
    if (startCompare != 0) {
      return startCompare;
    }
    final endCompare = left.end.compareTo(right.end);
    if (endCompare != 0) {
      return endCompare;
    }
    final kindCompare = left.kind.value.compareTo(right.kind.value);
    if (kindCompare != 0) {
      return kindCompare;
    }
    return left.uid.compareTo(right.uid);
  }
}

class _IcsEvent {
  final String uid;
  final IcsExportEventKind kind;
  final DateTime start;
  final DateTime end;
  final String summary;
  final String? location;
  final String? description;

  const _IcsEvent({
    required this.uid,
    required this.kind,
    required this.start,
    required this.end,
    required this.summary,
    this.location,
    this.description,
  });
}

class _ScheduleOccurrence {
  final ScheduleItem item;
  final DateTime eventDate;
  final DateTime endDate;
  final DateTime occurrenceDate;

  const _ScheduleOccurrence({
    required this.item,
    required this.eventDate,
    required this.endDate,
    required this.occurrenceDate,
  });
}

class _TimeOfDay {
  final int hour;
  final int minute;
  final int second;

  const _TimeOfDay(this.hour, this.minute, this.second);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _mondayOf(DateTime date) =>
    _addDays(date, -(date.weekday - DateTime.monday));

DateTime _addDays(DateTime date, int days) => DateTime(
  date.year,
  date.month,
  date.day + days,
  date.hour,
  date.minute,
  date.second,
);

DateTime _dateTimeAt(DateTime date, _TimeOfDay time) => DateTime(
  date.year,
  date.month,
  date.day,
  time.hour,
  time.minute,
  time.second,
);

bool _isInRange(DateTime date, DateTime from, DateTime to) {
  final normalized = _dateOnly(date);
  return !normalized.isBefore(from) && !normalized.isAfter(to);
}

bool _dateRangesOverlap(
  DateTime start,
  DateTime end,
  DateTime from,
  DateTime to,
) {
  final normalizedStart = _dateOnly(start);
  final normalizedEnd = _dateOnly(end);
  return !normalizedEnd.isBefore(from) && !normalizedStart.isAfter(to);
}

_TimeOfDay? _parseTime(String raw) {
  final match = RegExp(
    r'^\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*$',
  ).firstMatch(raw);
  if (match == null) {
    return null;
  }
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  final second = int.tryParse(match.group(3) ?? '0');
  if (hour == null || minute == null || second == null) {
    return null;
  }
  if (hour > 23 || minute > 59 || second > 59) {
    return null;
  }
  return _TimeOfDay(hour, minute, second);
}

String _formatCalendarDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _formatCompactCalendarDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}

String _formatClock(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';
}

String _formatUtcDateTime(DateTime date) {
  final utc = date.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}'
      '${utc.month.toString().padLeft(2, '0')}'
      '${utc.day.toString().padLeft(2, '0')}'
      'T${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}Z';
}

String _escapeText(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', '\\n');
}

List<String> _foldLine(String line) {
  if (line.isEmpty) {
    return const <String>[''];
  }

  final folded = <String>[];
  final buffer = StringBuffer();
  var byteLength = 0;
  var maxBytes = 75;
  for (final rune in line.runes) {
    final character = String.fromCharCode(rune);
    final characterBytes = utf8.encode(character).length;
    if (byteLength > 0 && byteLength + characterBytes > maxBytes) {
      folded.add(buffer.toString());
      buffer.clear();
      byteLength = 0;
      maxBytes = 74;
    }
    buffer.write(character);
    byteLength += characterBytes;
  }
  folded.add(buffer.toString());

  for (var index = 1; index < folded.length; index++) {
    folded[index] = ' ${folded[index]}';
  }
  return folded;
}

bool _hasText(String? value) => value?.trim().isNotEmpty == true;

String _joinDistinct(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isNotEmpty && seen.add(normalized)) {
      result.add(normalized);
    }
  }
  return result.join('\n');
}

String _sanitizeFileNameSegment(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), '_');
  final buffer = StringBuffer();
  for (final rune in normalized.runes) {
    final isControl = rune < 0x20;
    final isUnsafe = '<>:"/\\|?*'.runes.contains(rune);
    buffer.write(isControl || isUnsafe ? '_' : String.fromCharCode(rune));
  }
  var safe = buffer.toString().replaceAll(RegExp(r'_+'), '_');
  safe = safe.replaceFirst(RegExp(r'^[ ._]+'), '');
  safe = safe.replaceFirst(RegExp(r'[ ._]+$'), '');
  if (safe.isEmpty) {
    return 'timetable';
  }
  final runes = safe.runes.toList(growable: false);
  if (runes.length > 80) {
    safe = String.fromCharCodes(runes.take(80));
  }
  return safe;
}
