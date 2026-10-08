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

  /// 归一自定义提醒偏移：丢掉非正数与非数值条目，重复值只留一份（保持先来后到的顺序）。
  ///
  /// 与写侧同口径：`add_exam_screen.dart:561` 拒 `totalMinutes <= 0`，
  /// :575 挡重复偏移；调度侧 `exam_reminder_service.dart:345` 也 `<= 0 continue`。
  /// 原先 `Exam.fromJson` 是裸 `(item as num).toInt()`：
  /// - 类型不对（云端 / 备份 / 局域网写来的 `"x"`）直接抛 TypeError；
  /// - 0 与负数则原样留在列表里，而考试卡的偏移标签用
  ///   `(minutes % 1440) ~/ 60`（`exam_list_screen.dart:232`）算分量，Dart 的 `%`
  ///   恒非负，`-30` 被渲染成「23 小时 + 30 分钟」—— 用户看到"会提前提醒"，
  ///   实际一条通知都不会排。
  static List<int> normalizeReminderOffsets(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final seen = <int>{};
    for (final item in raw) {
      if (item is! num) {
        continue;
      }
      final minutes = item.toInt();
      if (minutes <= 0) {
        continue;
      }
      seen.add(minutes);
    }
    if (seen.isEmpty) {
      return const [];
    }
    return List<int>.unmodifiable(seen.toList(growable: false));
  }

  /// Normalizes free-form time text into `HH:mm`, or returns [fallback].
  static String normalizeTimeOfDay(String? raw, {String fallback = '08:30'}) {
    final value = (raw ?? '').trim();
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(value);
    if (match == null) {
      return fallback;
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return fallback;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static (int hour, int minute) parseTimeOfDayParts(
    String raw, {
    int fallbackHour = 0,
    int fallbackMinute = 0,
  }) {
    final normalized = normalizeTimeOfDay(
      raw,
      fallback:
          '${fallbackHour.toString().padLeft(2, '0')}:${fallbackMinute.toString().padLeft(2, '0')}',
    );
    final parts = normalized.split(':');
    return (
      int.tryParse(parts[0]) ?? fallbackHour,
      int.tryParse(parts[1]) ?? fallbackMinute,
    );
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    // 2026-10-08：与 `Course.fromJson` / `TimetableProfile.fromJson` 同款口径。
    // 考试来自备份恢复与云同步（外部数据），原先十处 `as String` 裸转换，
    // 任一字段类型不对就抛 TypeError，而恢复路径会把「解析结果为空」
    // 当成整份文件全损 → 一条坏考试让整份备份恢复不出来。
    //
    // ⚠️ 同 `Course`：**必填字段缺失要抛**，好让「坏条目留档、不写回」那条
    // 自愈机制接住（`storage_service_profiles_integrity_test.dart:104`）；
    // 只有「类型不对但有值」（`name: 123` 这类导入器手滑）才收下。
    String readRequired(String key) {
      final raw = json[key];
      if (raw == null) {
        throw FormatException('Exam.$key is missing');
      }
      return raw is String ? raw : raw.toString();
    }

    String readStr(String key, {String fallback = ''}) {
      final raw = json[key];
      if (raw is String) {
        return raw;
      }
      return raw == null ? fallback : raw.toString();
    }

    String? readStrOrNull(String key) {
      final raw = json[key];
      if (raw == null) {
        return null;
      }
      return raw is String ? raw : raw.toString();
    }

    return Exam(
      id: readRequired('id'),
      courseId: readRequired('courseId'),
      name: readStr('name'),
      dateTime: DateTime.tryParse(readStr('dateTime')) ?? now,
      startTime: normalizeTimeOfDay(readStrOrNull('startTime')),
      endTime: normalizeTimeOfDay(
        readStrOrNull('endTime'),
        fallback: '10:30',
      ),
      location: readStrOrNull('location'),
      seatNumber: readStrOrNull('seatNumber'),
      note: readStrOrNull('note'),
      reminderPreset: ExamReminderPresetX.fromValue(
        readStrOrNull('reminderPreset'),
      ),
      customReminderMinutes: normalizeReminderOffsets(
        json['customReminderMinutes'],
      ),
      createdAt: DateTime.tryParse(readStr('createdAt')) ?? now,
      updatedAt: DateTime.tryParse(readStr('updatedAt')) ?? now,
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

  /// Local wall-clock start of the exam (`dateTime` date + [startTime]).
  DateTime get examStartDateTime {
    final startParts = parseTimeOfDayParts(startTime);
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      startParts.$1,
      startParts.$2,
    );
  }

  /// Stable chronological ordering for exams, including same-day times.
  static int compareByStart(Exam left, Exam right) {
    final startCompare = left.examStartDateTime.compareTo(
      right.examStartDateTime,
    );
    if (startCompare != 0) {
      return startCompare;
    }
    final leftEnd = _dateTimeWithTime(left.dateTime, left.endTime);
    final rightEnd = _dateTimeWithTime(right.dateTime, right.endTime);
    final endCompare = leftEnd.compareTo(rightEnd);
    if (endCompare != 0) {
      return endCompare;
    }
    return left.id.compareTo(right.id);
  }

  static DateTime _dateTimeWithTime(DateTime date, String rawTime) {
    final parts = parseTimeOfDayParts(
      rawTime,
      fallbackHour: 23,
      fallbackMinute: 59,
    );
    return DateTime(date.year, date.month, date.day, parts.$1, parts.$2);
  }

  /// 考试是否已过期
  bool get isExpired {
    final now = DateTime.now();
    final endParts = parseTimeOfDayParts(
      endTime,
      fallbackHour: 23,
      fallbackMinute: 59,
    );
    final examEnd = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      endParts.$1,
      endParts.$2,
    );
    return now.isAfter(examEnd);
  }

  /// 距离考试还有多少天
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return DateTime.utc(
      examDate.year,
      examDate.month,
      examDate.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  }
}
