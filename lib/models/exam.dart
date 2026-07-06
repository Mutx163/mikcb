import 'dart:convert';

enum ExamReminderPreset {
  none, // 不提醒
  min30, // 考前 30 分钟
  hour1, // 考前 1 小时
  hour1AndMin30, // 考前 1 小时 + 30 分钟
  day1, // 考前 1 天
  day1AndHour1, // 考前 1 天 + 1 小时（默认）
  custom, // 自定义分钟数列表
}

extension ExamReminderPresetX on ExamReminderPreset {
  String get value => switch (this) {
    ExamReminderPreset.none => 'none',
    ExamReminderPreset.min30 => 'min_30',
    ExamReminderPreset.hour1 => 'hour_1',
    ExamReminderPreset.hour1AndMin30 => 'hour_1_and_min_30',
    ExamReminderPreset.day1 => 'day_1',
    ExamReminderPreset.day1AndHour1 => 'day_1_and_hour_1',
    ExamReminderPreset.custom => 'custom',
  };

  String get label => switch (this) {
    ExamReminderPreset.none => '不提醒',
    ExamReminderPreset.min30 => '考前 30 分钟',
    ExamReminderPreset.hour1 => '考前 1 小时',
    ExamReminderPreset.hour1AndMin30 => '考前 1 小时 + 30 分钟',
    ExamReminderPreset.day1 => '考前 1 天',
    ExamReminderPreset.day1AndHour1 => '考前 1 天 + 1 小时',
    ExamReminderPreset.custom => '自定义',
  };

  List<int> get reminderMinutes => switch (this) {
    ExamReminderPreset.none => const [],
    ExamReminderPreset.min30 => const [30],
    ExamReminderPreset.hour1 => const [60],
    ExamReminderPreset.hour1AndMin30 => const [60, 30],
    ExamReminderPreset.day1 => const [1440],
    ExamReminderPreset.day1AndHour1 => const [1440, 60],
    ExamReminderPreset.custom => const [], // 使用 customReminderMinutes
  };

  static ExamReminderPreset fromValue(String? value) {
    return ExamReminderPreset.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ExamReminderPreset.day1AndHour1,
    );
  }
}

class Exam {
  static const Object _unset = Object();

  final String id;
  final String courseId; // 强关联课程 ID
  final String name; // 考试名称，默认继承课程名
  final DateTime dateTime; // 考试日期
  final String startTime; // "08:30"
  final String endTime; // "10:30"
  final String? location; // 考场（可能不同于上课教室）
  final String? seatNumber; // 座位号
  final String? note; // 备注
  final ExamReminderPreset reminderPreset; // 提醒预设
  final List<int> customReminderMinutes; // 自定义提醒分钟数
  final DateTime createdAt;
  final DateTime updatedAt;

  Exam({
    required this.id,
    required this.courseId,
    required this.name,
    required this.dateTime,
    required this.startTime,
    required this.endTime,
    this.location,
    this.seatNumber,
    this.note,
    this.reminderPreset = ExamReminderPreset.day1AndHour1,
    this.customReminderMinutes = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'name': name,
      'dateTime': dateTime.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'seatNumber': seatNumber,
      'note': note,
      'reminderPreset': reminderPreset.value,
      'customReminderMinutes': customReminderMinutes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Exam(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      name: json['name'] as String? ?? '',
      dateTime: DateTime.tryParse(json['dateTime'] as String? ?? '') ?? now,
      startTime: json['startTime'] as String? ?? '08:30',
      endTime: json['endTime'] as String? ?? '10:30',
      location: json['location'] as String?,
      seatNumber: json['seatNumber'] as String?,
      note: json['note'] as String?,
      reminderPreset: ExamReminderPresetX.fromValue(
        json['reminderPreset'] as String?,
      ),
      customReminderMinutes:
          (json['customReminderMinutes'] as List<dynamic>?)
              ?.map((item) => (item as num).toInt())
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Exam.fromJsonString(String jsonString) {
    return Exam.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  Exam copyWith({
    String? id,
    String? courseId,
    String? name,
    DateTime? dateTime,
    String? startTime,
    String? endTime,
    Object? location = _unset,
    Object? seatNumber = _unset,
    Object? note = _unset,
    ExamReminderPreset? reminderPreset,
    List<int>? customReminderMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Exam(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      name: name ?? this.name,
      dateTime: dateTime ?? this.dateTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: identical(location, _unset)
          ? this.location
          : location as String?,
      seatNumber: identical(seatNumber, _unset)
          ? this.seatNumber
          : seatNumber as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      reminderPreset: reminderPreset ?? this.reminderPreset,
      customReminderMinutes:
          customReminderMinutes ?? this.customReminderMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 获取实际的提醒分钟数列表
  List<int> get effectiveReminderMinutes {
    if (reminderPreset == ExamReminderPreset.custom) {
      return customReminderMinutes;
    }
    return reminderPreset.reminderMinutes;
  }

  /// 考试是否已过期
  bool get isExpired {
    final now = DateTime.now();
    final examEnd = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      int.parse(endTime.split(':')[0]),
      int.parse(endTime.split(':')[1]),
    );
    return now.isAfter(examEnd);
  }

  /// 距离考试还有多少天
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return examDate.difference(today).inDays;
  }
}
