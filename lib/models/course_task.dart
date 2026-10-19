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

  /// 2026-10-19 补：与 `Course.fromJson` / `Exam.fromJson` 同款口径。
  /// CourseTask 随 `TimetableProfile.fromJson` 消费云同步 / 备份 / 局域网三路
  /// 外部数据，原先 `id: json['id'] as String` 等六处裸强制转换，任一字段类型
  /// 不对就抛 TypeError：备份路径被 `_parseListWithTotalLossGuard` 计入丢弃，
  /// profile 路径被 `_parseListLenient` 按条目丢弃——数字型 title / 字符串型
  /// sourceWeek 都能让整条任务凭空消失。
  /// ⚠️ 与 Course 相同分两类：`id` 是身份字段，**缺失或空白仍要抛**
  /// FormatException，好让「坏条目留档、不写回」的自愈机制接住
  /// （`timetable_profile.dart` 的 quarantine 范式）；其余字段类型不对但有值
  /// → toString 收下，确实没有 → 默认值。序列化输出不受影响：合法输入的
  /// 解析结果与原先逐字段相同。
  factory CourseTask.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    String readRequiredId() {
      final raw = json['id'];
      if (raw == null) {
        throw const FormatException('CourseTask.id is missing');
      }
      final value = raw is String ? raw : raw.toString();
      if (value.trim().isEmpty) {
        throw const FormatException('CourseTask.id is blank');
      }
      return value;
    }

    String? readStringOrNull(String key) {
      final raw = json[key];
      if (raw == null) {
        return null;
      }
      return raw is String ? raw : raw.toString();
    }

    final rawSourceWeek = json['sourceWeek'];
    return CourseTask(
      id: readRequiredId(),
      title: readStringOrNull('title') ?? '',
      courseId: readStringOrNull('courseId'),
      sourceWeek: rawSourceWeek is num
          ? rawSourceWeek.toInt()
          : int.tryParse(rawSourceWeek?.toString() ?? ''),
      dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? ''),
      note: readStringOrNull('note'),
      // 类型不对没有合理真值（"true" 不是 Dart 的 true），按缺省 false 收下，
      // 不让一个标记字段把整条任务丢掉。
      isCompleted: json['isCompleted'] is bool
          ? json['isCompleted'] as bool
          : false,
      source: CourseTaskSource.fromValue(
        json['source'] is String ? json['source'] as String : null,
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
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
