import 'dart:convert';

enum CourseTaskSource {
  manual,
  homeworkMark;

  String get value => switch (this) {
    CourseTaskSource.manual => 'manual',
    CourseTaskSource.homeworkMark => 'homework_mark',
  };

  static CourseTaskSource fromValue(String? value) {
    return CourseTaskSource.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CourseTaskSource.manual,
    );
  }
}

/// A profile-scoped actionable item, optionally linked to a course occurrence.
class CourseTask {
  static const Object _unset = Object();

  final String id;
  final String title;
  final String? courseId;
  final int? sourceWeek;
  final DateTime? dueDate;
  final String? note;
  final bool isCompleted;
  final CourseTaskSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  CourseTask({
    required this.id,
    required this.title,
    this.courseId,
    this.sourceWeek,
    DateTime? dueDate,
    this.note,
    this.isCompleted = false,
    this.source = CourseTaskSource.manual,
    required this.createdAt,
    required this.updatedAt,
  }) : dueDate = dueDate == null ? null : dateOnly(dueDate);

  bool get hasDueDate => dueDate != null;

  bool isDueOn(DateTime date) {
    final due = dueDate;
    return due != null && dateOnly(due) == dateOnly(date);
  }

  bool isDueBetween(DateTime start, DateTime end) {
    final due = dueDate;
    if (due == null) {
      return false;
    }
    final normalizedDue = dateOnly(due);
    return !normalizedDue.isBefore(dateOnly(start)) &&
        !normalizedDue.isAfter(dateOnly(end));
  }

  bool isOverdue({DateTime? now}) {
    final due = dueDate;
    return !isCompleted &&
        due != null &&
        dateOnly(due).isBefore(dateOnly(now ?? DateTime.now()));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'courseId': courseId,
      'sourceWeek': sourceWeek,
      'dueDate': dueDate?.toIso8601String(),
      'note': note,
      'isCompleted': isCompleted,
      'source': source.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CourseTask.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final rawSourceWeek = json['sourceWeek'];
    return CourseTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      courseId: json['courseId'] as String?,
      sourceWeek: rawSourceWeek is num
          ? rawSourceWeek.toInt()
          : int.tryParse(rawSourceWeek?.toString() ?? ''),
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
      note: json['note'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      source: CourseTaskSource.fromValue(json['source'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory CourseTask.fromJsonString(String jsonString) {
    return CourseTask.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  CourseTask copyWith({
    String? id,
    String? title,
    Object? courseId = _unset,
    Object? sourceWeek = _unset,
    Object? dueDate = _unset,
    Object? note = _unset,
    bool? isCompleted,
    CourseTaskSource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CourseTask(
      id: id ?? this.id,
      title: title ?? this.title,
      courseId: identical(courseId, _unset)
          ? this.courseId
          : courseId as String?,
      sourceWeek: identical(sourceWeek, _unset)
          ? this.sourceWeek
          : sourceWeek as int?,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      note: identical(note, _unset) ? this.note : note as String?,
      isCompleted: isCompleted ?? this.isCompleted,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static int compareByDueDate(CourseTask left, CourseTask right) {
    final leftDue = left.dueDate;
    final rightDue = right.dueDate;
    if (leftDue == null && rightDue != null) {
      return 1;
    }
    if (leftDue != null && rightDue == null) {
      return -1;
    }
    if (leftDue != null && rightDue != null) {
      final dueCompare = dateOnly(leftDue).compareTo(dateOnly(rightDue));
      if (dueCompare != 0) {
        return dueCompare;
      }
    }
    final completionCompare = (left.isCompleted ? 1 : 0).compareTo(
      right.isCompleted ? 1 : 0,
    );
    if (completionCompare != 0) {
      return completionCompare;
    }
    final titleCompare = left.title.compareTo(right.title);
    if (titleCompare != 0) {
      return titleCompare;
    }
    return left.id.compareTo(right.id);
  }
}
