import '../models/course.dart';

class IcsImportResult {
  final List<Course> courses;
  final DateTime semesterStart;

  const IcsImportResult({
    required this.courses,
    required this.semesterStart,
  });
}

class IcsImportService {
  IcsImportResult parseWakeUpSchedule(String content) {
    final events = _parseEvents(content);
    if (events.isEmpty) {
      return IcsImportResult(
        courses: const [],
        semesterStart: DateTime.now(),
      );
    }

    final startDates = events
        .map((event) => _parseLocalDateTime(event['DTSTART']))
        .whereType<DateTime>()
        .toList()
      ..sort();

    final semesterStart = _startOfWeek(startDates.first);
    final rawCourses = <Course>[];

    for (final event in events) {
      final course =
          _buildCourseFromEvent(event, semesterStart, rawCourses.length);
      if (course != null) {
        rawCourses.add(course);
      }
    }

    final courses = _mergeAlternatingWeekCourses(rawCourses);

    return IcsImportResult(
      courses: courses,
      semesterStart: semesterStart,
    );
  }

  List<Map<String, String>> _parseEvents(String content) {
    final unfoldedLines = _unfoldLines(content);
    final events = <Map<String, String>>[];
    Map<String, String>? currentEvent;
    var inAlarm = false;

    for (final rawLine in unfoldedLines) {
      final line = rawLine.trim();
      if (line == 'BEGIN:VEVENT') {
        currentEvent = <String, String>{};
        inAlarm = false;
        continue;
      }
      if (line == 'END:VEVENT') {
        if (currentEvent != null) {
          events.add(currentEvent);
        }
        currentEvent = null;
        inAlarm = false;
        continue;
      }
      if (currentEvent == null) {
        continue;
      }
      if (line == 'BEGIN:VALARM') {
        inAlarm = true;
        continue;
      }
      if (line == 'END:VALARM') {
        inAlarm = false;
        continue;
      }
      if (inAlarm || !line.contains(':')) {
        continue;
      }

      final separatorIndex = line.indexOf(':');
      final rawKey = line.substring(0, separatorIndex);
      final key = rawKey.split(';').first;
      final value = line.substring(separatorIndex + 1);

      currentEvent.putIfAbsent(key, () => value);
    }

    return events;
  }

  List<String> _unfoldLines(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    final unfolded = <String>[];

    for (final line in lines) {
      if ((line.startsWith(' ') || line.startsWith('\t')) && unfolded.isNotEmpty) {
        unfolded[unfolded.length - 1] += line.substring(1);
      } else {
        unfolded.add(line);
      }
    }

    return unfolded;
  }

  Course? _buildCourseFromEvent(
    Map<String, String> event,
    DateTime semesterStart,
    int index,
  ) {
    final summary = event['SUMMARY'];
    final description = event['DESCRIPTION'];
    final startDateTime = _parseLocalDateTime(event['DTSTART']);
    final endDateTime = _parseLocalDateTime(event['DTEND']);
    if (summary == null || description == null || startDateTime == null || endDateTime == null) {
      return null;
    }

    final descriptionLines = description
        .replaceAll(r'\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (descriptionLines.isEmpty) {
      return null;
    }

    final sectionMatch = RegExp(r'第\s*(\d+)\s*-\s*(\d+)\s*节').firstMatch(descriptionLines.first);
    if (sectionMatch == null) {
      return null;
    }

    final startSection = int.parse(sectionMatch.group(1)!);
    final endSection = int.parse(sectionMatch.group(2)!);
    final hasStructuredLocation = descriptionLines.length >= 2;
    final rawLocation = hasStructuredLocation
        ? descriptionLines[1]
        : (event['LOCATION'] ?? '');
    final teacher = descriptionLines.length >= 3
        ? descriptionLines[2]
        : _extractTeacherFromCombinedLocation(event['LOCATION'] ?? '');
    final endWeek = _parseEndWeek(
          event['RRULE'],
          semesterStart,
          startDateTime,
        ) ??
        _weekIndex(startDateTime, semesterStart);

    return Course(
      id: 'ics-${startDateTime.millisecondsSinceEpoch}-$index',
      name: _cleanSummary(summary),
      teacher: teacher,
      location: hasStructuredLocation
          ? rawLocation.trim()
          : _extractLocationFromCombinedField(rawLocation),
      dayOfWeek: startDateTime.weekday,
      startSection: startSection,
      endSection: endSection,
      startTime: _formatTime(startDateTime),
      endTime: _formatTime(endDateTime),
      startWeek: _weekIndex(startDateTime, semesterStart),
      endWeek: endWeek,
    );
  }

  String _cleanSummary(String summary) {
    return summary.replaceFirst(RegExp(r'\[\d+\]\[[^\]]+\]$'), '').trim();
  }

  List<Course> _mergeAlternatingWeekCourses(List<Course> courses) {
    final grouped = <String, List<Course>>{};
    for (final course in courses) {
      grouped.putIfAbsent(_courseMergeKey(course), () => []).add(course);
    }

    final mergedCourses = <Course>[];
    for (final entry in grouped.entries) {
      final mergedFlags = <String>{};
      final group = List<Course>.from(entry.value)
        ..sort((left, right) {
          final weekCompare = left.startWeek.compareTo(right.startWeek);
          if (weekCompare != 0) {
            return weekCompare;
          }
          return left.id.compareTo(right.id);
        });

      for (var i = 0; i < group.length; i++) {
        final current = group[i];
        if (mergedFlags.contains(current.id)) {
          continue;
        }

        final run = <Course>[current];
        for (var j = i + 1; j < group.length; j++) {
          final candidate = group[j];
          if (mergedFlags.contains(candidate.id)) {
            continue;
          }
          final previous = run.last;
          if (!_isSingleWeekCourse(previous) || !_isSingleWeekCourse(candidate)) {
            break;
          }
          if (candidate.startWeek - previous.startWeek != 2) {
            break;
          }
          if ((candidate.startWeek % 2) != (current.startWeek % 2)) {
            break;
          }
          run.add(candidate);
        }

        if (run.length >= 2 && run.every(_isSingleWeekCourse)) {
          mergedFlags.addAll(run.map((course) => course.id));
          mergedCourses.add(
            current.copyWith(
              startWeek: run.first.startWeek,
              endWeek: run.last.endWeek,
              isOddWeek: run.first.startWeek.isOdd,
              isEvenWeek: run.first.startWeek.isEven,
            ),
          );
          continue;
        }

        mergedFlags.add(current.id);
        mergedCourses.add(current);
      }
    }

    mergedCourses.sort((left, right) {
      final dayCompare = left.dayOfWeek.compareTo(right.dayOfWeek);
      if (dayCompare != 0) {
        return dayCompare;
      }
      final sectionCompare = left.startSection.compareTo(right.startSection);
      if (sectionCompare != 0) {
        return sectionCompare;
      }
      return left.startWeek.compareTo(right.startWeek);
    });
    return mergedCourses;
  }

  String _courseMergeKey(Course course) {
    return [
      course.name,
      course.teacher,
      course.location,
      course.dayOfWeek,
      course.startSection,
      course.endSection,
      course.startTime,
      course.endTime,
      course.shortName ?? '',
      course.note ?? '',
    ].join('|');
  }

  bool _isSingleWeekCourse(Course course) =>
      course.startWeek == course.endWeek &&
      !course.isOddWeek &&
      !course.isEvenWeek;

  String _extractLocationFromCombinedField(String location) {
    final parts = location.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) {
      return location.trim();
    }
    return parts.sublist(0, parts.length - 1).join(' ');
  }

  String _extractTeacherFromCombinedLocation(String location) {
    final parts = location.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '';
    }
    return parts.last;
  }

  DateTime? _parseLocalDateTime(String? value) {
    if (value == null) return null;
    final match = RegExp(r'(\d{8})T(\d{4,6})').firstMatch(value);
    if (match == null) return null;

    final date = match.group(1)!;
    final time = match.group(2)!;
    final year = int.parse(date.substring(0, 4));
    final month = int.parse(date.substring(4, 6));
    final day = int.parse(date.substring(6, 8));
    final hour = int.parse(time.substring(0, 2));
    final minute = int.parse(time.substring(2, 4));
    final second = time.length >= 6 ? int.parse(time.substring(4, 6)) : 0;

    return DateTime(year, month, day, hour, minute, second);
  }

  int? _parseEndWeek(
    String? rrule,
    DateTime semesterStart,
    DateTime startDateTime,
  ) {
    if (rrule == null) return null;
    final untilDateTime = _parseUntilDateTime(rrule);
    if (untilDateTime == null) return null;

    final intervalWeeks = _parseWeeklyInterval(rrule);
    final repeatDuration =
        Duration(days: 7 * (intervalWeeks <= 0 ? 1 : intervalWeeks));
    final difference = untilDateTime.difference(startDateTime);
    if (difference.isNegative) {
      return _weekIndex(startDateTime, semesterStart);
    }

    final occurrenceOffset =
        difference.inMicroseconds ~/ repeatDuration.inMicroseconds;
    final lastOccurrence = startDateTime.add(
      Duration(days: repeatDuration.inDays * occurrenceOffset),
    );
    return _weekIndex(lastOccurrence, semesterStart);
  }

  DateTime? _parseUntilDateTime(String rrule) {
    final dateTimeMatch =
        RegExp(r'UNTIL=(\d{8})T(\d{6})(Z)?').firstMatch(rrule);
    if (dateTimeMatch != null) {
      final date = dateTimeMatch.group(1)!;
      final time = dateTimeMatch.group(2)!;
      final isUtc = dateTimeMatch.group(3) == 'Z';
      final year = int.parse(date.substring(0, 4));
      final month = int.parse(date.substring(4, 6));
      final day = int.parse(date.substring(6, 8));
      final hour = int.parse(time.substring(0, 2));
      final minute = int.parse(time.substring(2, 4));
      final second = int.parse(time.substring(4, 6));

      return isUtc
          ? DateTime.utc(year, month, day, hour, minute, second).toLocal()
          : DateTime(year, month, day, hour, minute, second);
    }

    final dateMatch = RegExp(r'UNTIL=(\d{8})').firstMatch(rrule);
    if (dateMatch == null) return null;

    final date = dateMatch.group(1)!;
    return DateTime(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(4, 6)),
      int.parse(date.substring(6, 8)),
    );
  }

  int _parseWeeklyInterval(String rrule) {
    final match = RegExp(r'INTERVAL=(\d+)').firstMatch(rrule);
    return match == null ? 1 : int.tryParse(match.group(1)!) ?? 1;
  }

  DateTime _startOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  int _weekIndex(DateTime date, DateTime semesterStart) {
    final days = _startOfWeek(date).difference(_startOfWeek(semesterStart)).inDays;
    return days ~/ 7 + 1;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
