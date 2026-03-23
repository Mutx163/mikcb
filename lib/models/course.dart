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
  final CourseNature courseNature; // 课程性质
  final String? description; // 课程简介（同名课程共享）
  final String? note; // 备注/备忘录

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
    this.courseNature = CourseNature.required,
    this.description,
    this.note,
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
      'courseNature': courseNature.value,
      'description': description,
      'note': note,
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
      courseNature: CourseNatureX.fromValue(json['courseNature'] as String?),
      description: json['description'] as String? ?? json['note'] as String?,
      note: json['note'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Course.fromJsonString(String jsonString) {
    return Course.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  Course copyWith({
    String? id,
    String? name,
    String? shortName,
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
    CourseNature? courseNature,
    String? description,
    String? note,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
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
      courseNature: courseNature ?? this.courseNature,
      description: description ?? this.description,
      note: note ?? this.note,
    );
  }

  int get sectionCount => endSection - startSection + 1;

  bool isInWeek(int week) {
    if (week < startWeek || week > endWeek) return false;
    if (isOddWeek && week % 2 == 0) return false;
    if (isEvenWeek && week % 2 != 0) return false;
    return true;
  }
}
