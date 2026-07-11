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
  final String? note; // 备注/备忘录
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
      timeSchemeIdOverride: json['timeSchemeIdOverride'] as String?,
    );
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
      timeSchemeIdOverride: identical(timeSchemeIdOverride, _unset)
          ? this.timeSchemeIdOverride
          : timeSchemeIdOverride as String?,
    );
  }

  int get sectionCount => endSection - startSection + 1;

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
