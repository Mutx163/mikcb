import 'dart:convert';

enum CourseNature {
  required,
  elective,
}

extension CourseNatureX on CourseNature {
  String get value => switch (this) {
        CourseNature.required => 'required',
        CourseNature.elective => 'elective',
      };

  String get label => switch (this) {
        CourseNature.required => '必修',
        CourseNature.elective => '选修',
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
    this.courseNature = CourseNature.required,
    this.description,
    this.note,
    this.timeSchemeIdOverride,
  });

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
      'courseNature': courseNature.value,
      'description': description,
      'note': note,
      'timeSchemeIdOverride': timeSchemeIdOverride,
    };
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['shortName'] as String?,
      teacher: json['teacher'] as String,
      location: json['location'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      startSection: json['startSection'] as int,
      endSection: json['endSection'] as int,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      color: json['color'] as String? ?? '#2196F3',
      startWeek: json['startWeek'] as int? ?? 1,
      endWeek: json['endWeek'] as int? ?? 16,
      isOddWeek: json['isOddWeek'] as bool? ?? false,
      isEvenWeek: json['isEvenWeek'] as bool? ?? false,
      customWeeks: (json['customWeeks'] as List<dynamic>?)
          ?.map((item) => item as int)
          .toList(),
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
    CourseNature? courseNature,
    Object? description = _unset,
    Object? note = _unset,
    Object? timeSchemeIdOverride = _unset,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName:
          identical(shortName, _unset) ? this.shortName : shortName as String?,
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

  List<int> get activeWeeks {
    final custom = normalizedCustomWeeks;
    if (custom != null) {
      return custom;
    }

    final weeks = <int>[];
    for (var week = startWeek; week <= endWeek; week++) {
      if (isOddWeek && week.isEven) {
        continue;
      }
      if (isEvenWeek && week.isOdd) {
        continue;
      }
      weeks.add(week);
    }
    return weeks;
  }

  String get weekDescription {
    final custom = normalizedCustomWeeks;
    if (custom != null) {
      return '第${_formatWeekList(custom)}周';
    }

    final mode = isOddWeek
        ? ' 单周'
        : isEvenWeek
            ? ' 双周'
            : '';
    return '第$startWeek-$endWeek周$mode';
  }

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

  String _formatWeekList(List<int> weeks) {
    final ranges = <String>[];
    var rangeStart = weeks.first;
    var previous = weeks.first;

    for (var index = 1; index < weeks.length; index++) {
      final current = weeks[index];
      if (current == previous + 1) {
        previous = current;
        continue;
      }
      ranges.add(
        rangeStart == previous ? '$rangeStart' : '$rangeStart-$previous',
      );
      rangeStart = current;
      previous = current;
    }

    ranges.add(
      rangeStart == previous ? '$rangeStart' : '$rangeStart-$previous',
    );
    return ranges.join('、');
  }
}
