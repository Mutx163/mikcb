import 'dart:convert';

import '../l10n/app_localizations.dart';
import '../l10n/course_week_localizations.dart';

enum CourseNature { required, elective }

extension CourseNatureX on CourseNature {
  String get value => switch (this) {
    CourseNature.required => 'required',
    CourseNature.elective => 'elective',
  };

  static CourseNature fromValue(String? value) {
    return CourseNature.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CourseNature.required,
    );
  }
}

/// Per-occurrence (single week) note for a course schedule entry.
class CourseSessionNote {
  static const Object _unset = Object();

  final String text;
  final bool hasHomework;

  const CourseSessionNote({this.text = '', this.hasHomework = false});

  bool get isEmpty => text.trim().isEmpty && !hasHomework;

  bool get isNotEmpty => !isEmpty;

  String get trimmedText => text.trim();

  CourseSessionNote? get normalizedOrNull {
    final trimmed = trimmedText;
    if (trimmed.isEmpty && !hasHomework) {
      return null;
    }
    return CourseSessionNote(text: trimmed, hasHomework: hasHomework);
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'hasHomework': hasHomework};
  }

  factory CourseSessionNote.fromJson(Map<String, dynamic> json) {
    return CourseSessionNote(
      text: (json['text'] as String?) ?? '',
      hasHomework: json['hasHomework'] as bool? ?? false,
    );
  }

  CourseSessionNote copyWith({Object? text = _unset, bool? hasHomework}) {
    return CourseSessionNote(
      text: identical(text, _unset) ? this.text : text as String,
      hasHomework: hasHomework ?? this.hasHomework,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CourseSessionNote &&
        other.text == text &&
        other.hasHomework == hasHomework;
  }

  @override
  int get hashCode => Object.hash(text, hasHomework);
}

class Course {
  static const Object _unset = Object();

  final String id;
  final String name;
  final String? shortName;
  final String teacher;
  final String location;
  final int dayOfWeek; // 1-7, Monday-Sunday
  final int startSection; // 开始节次
  final int endSection; // 结束节次
  final String startTime; // 格式: HH:mm
  final String endTime; // 格式: HH:mm
  final String color; // 课程颜色
  final int startWeek; // 开始周次
  final int endWeek; // 结束周次
  final bool isOddWeek; // 是否单周
  final bool isEvenWeek; // 是否双周
  final List<int>? customWeeks; // 自定义周次
  final List<int>? suspendedWeeks; // 停课周次
  final CourseNature courseNature; // 课程性质
  final String? description; // 课程简介（同名课程共享）
  /// Legacy per-entry free text. Prefer [description] for shared course intro;
  /// kept for import/back-compat. UI should not write new values here.
  final String? note;

  /// Per-week session notes keyed by teaching week (1-based).
  final Map<int, CourseSessionNote>? sessionNotes;
  final String? timeSchemeIdOverride; // 课程级时间模板覆盖

  Course({
    required this.id,
    required this.name,
    this.shortName,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.startTime,
    required this.endTime,
    this.color = '#2196F3',
    this.startWeek = 1,
    this.endWeek = 16,
    this.isOddWeek = false,
    this.isEvenWeek = false,
    this.customWeeks,
    this.suspendedWeeks,
    this.courseNature = CourseNature.required,
    this.description,
    this.note,
    this.sessionNotes,
    this.timeSchemeIdOverride,
  });

  /// Clamps [dayOfWeek] to Monday–Sunday (1–7).
  static int normalizeDayOfWeek(int dayOfWeek) {
    if (dayOfWeek < 1) {
      return 1;
    }
    if (dayOfWeek > 7) {
      return 7;
    }
    return dayOfWeek;
  }

  /// Clamps section indexes so both stay in range and end >= start.
  static ({int startSection, int endSection}) normalizeSections({
    required int startSection,
    required int endSection,
    int maxSection = 24,
  }) {
    final safeMaxSection = maxSection < 1 ? 1 : maxSection;
    final normalizedStart = startSection.clamp(1, safeMaxSection);
    final normalizedEnd = endSection.clamp(normalizedStart, safeMaxSection);
    return (startSection: normalizedStart, endSection: normalizedEnd);
  }

  /// Clamps week range so both stay in range and end >= start.
  static ({int startWeek, int endWeek}) normalizeWeeks({
    required int startWeek,
    required int endWeek,
    int maxWeek = 30,
  }) {
    final safeMaxWeek = maxWeek < 1 ? 1 : maxWeek;
    final normalizedStart = startWeek.clamp(1, safeMaxWeek);
    final normalizedEnd = endWeek.clamp(normalizedStart, safeMaxWeek);
    return (startWeek: normalizedStart, endWeek: normalizedEnd);
  }

  Map<String, dynamic> toJson() {
    final normalizedSessionNotes = normalizedSessionNotesMap;
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'teacher': teacher,
      'location': location,
      'dayOfWeek': dayOfWeek,
      'startSection': startSection,
      'endSection': endSection,
      'startTime': startTime,
      'endTime': endTime,
      'color': color,
      'startWeek': startWeek,
      'endWeek': endWeek,
      'isOddWeek': isOddWeek,
      'isEvenWeek': isEvenWeek,
      'customWeeks': customWeeks,
      'suspendedWeeks': suspendedWeeks,
      'courseNature': courseNature.value,
      'description': description,
      'note': note,
      if (normalizedSessionNotes != null)
        'sessionNotes': {
          for (final entry in normalizedSessionNotes.entries)
            entry.key.toString(): entry.value.toJson(),
        },
      'timeSchemeIdOverride': timeSchemeIdOverride,
    };
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    int readInt(String key, {int? fallback}) {
      final raw = json[key];
      if (raw is num) {
        return raw.toInt();
      }
      if (raw is String) {
        return int.tryParse(raw) ?? fallback ?? 0;
      }
      if (fallback != null) {
        return fallback;
      }
      throw FormatException('Course.$key must be a number');
    }

    List<int>? readIntList(String key) {
      final raw = json[key];
      if (raw is! List) {
        return null;
      }
      return raw.map((item) {
        if (item is num) {
          return item.toInt();
        }
        if (item is String) {
          return int.tryParse(item) ?? 0;
        }
        return 0;
      }).toList();
    }

    final sections = normalizeSections(
      startSection: readInt('startSection', fallback: 1),
      endSection: readInt('endSection', fallback: 1),
    );
    final weeks = normalizeWeeks(
      startWeek: readInt('startWeek', fallback: 1),
      endWeek: readInt('endWeek', fallback: 16),
    );

    return Course(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['shortName'] as String?,
      teacher: json['teacher'] as String,
      location: json['location'] as String,
      dayOfWeek: normalizeDayOfWeek(readInt('dayOfWeek', fallback: 1)),
      startSection: sections.startSection,
      endSection: sections.endSection,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      color: json['color'] as String? ?? '#2196F3',
      startWeek: weeks.startWeek,
      endWeek: weeks.endWeek,
      isOddWeek: json['isOddWeek'] as bool? ?? false,
      isEvenWeek: json['isEvenWeek'] as bool? ?? false,
      customWeeks: readIntList('customWeeks'),
      suspendedWeeks: readIntList('suspendedWeeks'),
      courseNature: CourseNatureX.fromValue(json['courseNature'] as String?),
      description: json['description'] as String? ?? json['note'] as String?,
      note: json['note'] as String?,
      sessionNotes: parseSessionNotes(json['sessionNotes']),
      timeSchemeIdOverride: json['timeSchemeIdOverride'] as String?,
    );
  }

  /// Parses persisted session-note maps (week key as string or int).
  static Map<int, CourseSessionNote>? parseSessionNotes(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final parsed = <int, CourseSessionNote>{};
    raw.forEach((key, value) {
      final week = switch (key) {
        final int number => number,
        final String text => int.tryParse(text),
        _ => null,
      };
      if (week == null || week < 1) {
        return;
      }
      if (value is! Map) {
        return;
      }
      final note = CourseSessionNote.fromJson(
        Map<String, dynamic>.from(value),
      ).normalizedOrNull;
      if (note != null) {
        parsed[week] = note;
      }
    });
    if (parsed.isEmpty) {
      return null;
    }
    return Map<int, CourseSessionNote>.unmodifiable(parsed);
  }

  static Map<int, CourseSessionNote>? normalizeSessionNotes(
    Map<int, CourseSessionNote>? source,
  ) {
    if (source == null || source.isEmpty) {
      return null;
    }
    final normalized = <int, CourseSessionNote>{};
    for (final entry in source.entries) {
      if (entry.key < 1) {
        continue;
      }
      final note = entry.value.normalizedOrNull;
      if (note != null) {
        normalized[entry.key] = note;
      }
    }
    if (normalized.isEmpty) {
      return null;
    }
    return Map<int, CourseSessionNote>.unmodifiable(normalized);
  }

  String toJsonString() => jsonEncode(toJson());

  factory Course.fromJsonString(String jsonString) {
    return Course.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  Course copyWith({
    String? id,
    String? name,
    Object? shortName = _unset,
    String? teacher,
    String? location,
    int? dayOfWeek,
    int? startSection,
    int? endSection,
    String? startTime,
    String? endTime,
    String? color,
    int? startWeek,
    int? endWeek,
    bool? isOddWeek,
    bool? isEvenWeek,
    Object? customWeeks = _unset,
    Object? suspendedWeeks = _unset,
    CourseNature? courseNature,
    Object? description = _unset,
    Object? note = _unset,
    Object? sessionNotes = _unset,
    Object? timeSchemeIdOverride = _unset,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: identical(shortName, _unset)
          ? this.shortName
          : shortName as String?,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      isOddWeek: isOddWeek ?? this.isOddWeek,
      isEvenWeek: isEvenWeek ?? this.isEvenWeek,
      customWeeks: identical(customWeeks, _unset)
          ? this.customWeeks
          : (customWeeks as List<int>?),
      suspendedWeeks: identical(suspendedWeeks, _unset)
          ? this.suspendedWeeks
          : (suspendedWeeks as List<int>?),
      courseNature: courseNature ?? this.courseNature,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      sessionNotes: identical(sessionNotes, _unset)
          ? this.sessionNotes
          : normalizeSessionNotes(sessionNotes as Map<int, CourseSessionNote>?),
      timeSchemeIdOverride: identical(timeSchemeIdOverride, _unset)
          ? this.timeSchemeIdOverride
          : timeSchemeIdOverride as String?,
    );
  }

  int get sectionCount => endSection - startSection + 1;

  Map<int, CourseSessionNote>? get normalizedSessionNotesMap =>
      normalizeSessionNotes(sessionNotes);

  CourseSessionNote? sessionNoteForWeek(int week) =>
      normalizedSessionNotesMap?[week];

  bool hasHomeworkInWeek(int week) =>
      sessionNoteForWeek(week)?.hasHomework == true;

  bool hasSessionNoteInWeek(int week) => sessionNoteForWeek(week) != null;

  bool get hasAnyHomework =>
      normalizedSessionNotesMap?.values.any((note) => note.hasHomework) ??
      false;

  /// Returns a new session-note map with [week] upserted or removed.
  Map<int, CourseSessionNote>? withSessionNote(
    int week,
    CourseSessionNote? note,
  ) {
    final next = <int, CourseSessionNote>{...?normalizedSessionNotesMap};
    final normalized = note?.normalizedOrNull;
    if (normalized == null) {
      next.remove(week);
    } else {
      next[week] = normalized;
    }
    return normalizeSessionNotes(next);
  }

  /// Removes the session note for [week] (e.g. delete this occurrence).
  Map<int, CourseSessionNote>? withoutSessionNote(int week) =>
      withSessionNote(week, null);

  /// Moves a session note from [fromWeek] to [toWeek] (reschedule).
  Map<int, CourseSessionNote>? relocatingSessionNote({
    required int fromWeek,
    required int toWeek,
  }) {
    if (fromWeek == toWeek) {
      return normalizedSessionNotesMap;
    }
    final source = sessionNoteForWeek(fromWeek);
    final next = <int, CourseSessionNote>{...?normalizedSessionNotesMap};
    next.remove(fromWeek);
    if (source != null) {
      next[toWeek] = source;
    }
    return normalizeSessionNotes(next);
  }

  /// Session notes kept on the leftover multi-week course after moving one week.
  Map<int, CourseSessionNote>? sessionNotesExcludingWeek(int week) =>
      withoutSessionNote(week);

  /// Session notes for a single-week course created by reschedule/split.
  Map<int, CourseSessionNote>? sessionNotesForSingleWeek({
    required int sourceWeek,
    required int targetWeek,
  }) {
    final source = sessionNoteForWeek(sourceWeek);
    if (source == null) {
      return null;
    }
    return normalizeSessionNotes({targetWeek: source});
  }

  List<int>? get normalizedCustomWeeks {
    final source = customWeeks;
    if (source == null || source.isEmpty) {
      return null;
    }
    final normalized = source.toSet().toList()..sort();
    return normalized;
  }

  bool get hasCustomWeeks => normalizedCustomWeeks != null;

  List<int>? get normalizedSuspendedWeeks {
    final source = suspendedWeeks;
    if (source == null || source.isEmpty) {
      return null;
    }
    final normalized = source.toSet().toList()..sort();
    return normalized;
  }

  bool isSuspendedInWeek(int week) => suspendedWeeks?.contains(week) ?? false;

  List<int> get activeWeeks {
    final custom = normalizedCustomWeeks;
    final weeks = <int>[];
    if (custom != null) {
      weeks.addAll(custom);
    } else {
      for (var week = startWeek; week <= endWeek; week++) {
        if (isOddWeek && week.isEven) {
          continue;
        }
        if (isEvenWeek && week.isOdd) {
          continue;
        }
        weeks.add(week);
      }
    }
    final suspended = normalizedSuspendedWeeks;
    if (suspended == null || suspended.isEmpty) {
      return weeks;
    }
    return weeks.where((week) => !suspended.contains(week)).toList();
  }

  String weekDescription(AppLocalizations l10n) =>
      courseWeekDescription(l10n, this);

  String? suspensionDescription(AppLocalizations l10n) =>
      courseSuspensionDescription(l10n, this);

  bool isInWeek(int week) {
    final custom = normalizedCustomWeeks;
    if (custom != null) {
      return custom.contains(week);
    }
    if (week < startWeek || week > endWeek) return false;
    if (isOddWeek && week % 2 == 0) return false;
    if (isEvenWeek && week % 2 != 0) return false;
    return true;
  }

  /// 是否在指定周次有效（排除停课）
  bool isActiveInWeek(int week) {
    if (suspendedWeeks?.contains(week) == true) return false;
    return isInWeek(week);
  }
}
