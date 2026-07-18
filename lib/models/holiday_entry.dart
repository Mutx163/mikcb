import 'dart:convert';

/// 节假日类型
enum HolidayType {
  /// 法定假期（国庆、清明等），课表灰显/隐藏
  vacation,

  /// 调休上班日（周末但需要上课）
  adjustedWorkday,

  /// 调休休息日（工作日但放假）
  adjustedRestday,
}

extension HolidayTypeX on HolidayType {
  String get value => switch (this) {
    HolidayType.vacation => 'vacation',
    HolidayType.adjustedWorkday => 'adjusted_workday',
    HolidayType.adjustedRestday => 'adjusted_restday',
  };

  static HolidayType fromValue(String? value) {
    return HolidayType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => HolidayType.vacation,
    );
  }
}

/// 单日节假日条目
class HolidayEntry {
  /// 日期（仅日期部分，时间归零）
  final DateTime date;

  /// 显示名称，如"国庆节"、"调休上班"
  final String name;

  /// 节假日类型
  final HolidayType type;

  /// 所属假期组 ID（如"national-day-2026"），用于合并显示横幅
  final String? groupId;

  const HolidayEntry({
    required this.date,
    required this.name,
    required this.type,
    this.groupId,
  });

  /// 该日期是否应该隐藏/灰显课程
  bool get shouldHideCourses =>
      type == HolidayType.vacation || type == HolidayType.adjustedRestday;

  /// 该日期是否为调休上班日（需要显示课程）
  bool get isAdjustedWorkday => type == HolidayType.adjustedWorkday;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'name': name,
    'type': type.value,
    'groupId': groupId,
  };

  factory HolidayEntry.fromJson(Map<String, dynamic> json) {
    return HolidayEntry(
      date: DateTime.parse(json['date'] as String),
      name: json['name'] as String,
      type: HolidayTypeX.fromValue(json['type'] as String?),
      groupId: json['groupId'] as String?,
    );
  }
}

/// 年度节假日数据集合
class HolidayData {
  /// 数据年份
  final int year;

  /// 数据版本（用于远程更新比对）
  final int version;

  /// 所有节假日条目
  final List<HolidayEntry> entries;

  const HolidayData({
    required this.year,
    required this.version,
    required this.entries,
  });

  /// 按日期索引查询
  HolidayEntry? entryForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    try {
      return entries.firstWhere((e) => _isSameDate(e.date, dateOnly));
    } catch (_) {
      return null;
    }
  }

  /// 某日期是否为假期（应隐藏课程）
  /// 调休上班日优先级高于假期——同一天既有假期又有调休上班时，按上班处理。
  /// 但用户手动设置的自定义假期优先级最高，覆盖调休上班日。
  bool isHoliday(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    // 自定义假期优先级最高
    if (entries.any(
      (e) =>
          _isSameDate(e.date, dateOnly) &&
          e.shouldHideCourses &&
          _isCustomEntry(e),
    )) {
      return true;
    }
    if (entries.any(
      (e) => _isSameDate(e.date, dateOnly) && e.isAdjustedWorkday,
    )) {
      return false;
    }
    return entries.any(
      (e) => _isSameDate(e.date, dateOnly) && e.shouldHideCourses,
    );
  }

  /// `yyyy-MM-dd` keys for native surfaces (island / widget schedule).
  ///
  /// Uses full [isHoliday] semantics so custom makeup workdays that cover a
  /// statutory vacation are excluded, matching Flutter timetable UI.
  List<String> holidayDateKeysForSnapshot() {
    final dateKeys = <String>{};
    for (final entry in entries) {
      final dateOnly = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      if (!isHoliday(dateOnly)) {
        continue;
      }
      dateKeys.add(_dateKey(dateOnly));
    }
    return dateKeys.toList()..sort();
  }

  /// Effective makeup/adjusted workdays for native holiday override punch-through.
  ///
  /// Mirrors [isAdjustedWorkday] (custom rest still wins over makeup).
  List<String> adjustedWorkdayDateKeysForSnapshot() {
    final dateKeys = <String>{};
    for (final entry in entries) {
      if (!entry.isAdjustedWorkday) {
        continue;
      }
      final dateOnly = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      if (!isAdjustedWorkday(dateOnly)) {
        continue;
      }
      dateKeys.add(_dateKey(dateOnly));
    }
    return dateKeys.toList()..sort();
  }

  static String _dateKey(DateTime dateOnly) =>
      '${dateOnly.year}-'
      '${dateOnly.month.toString().padLeft(2, '0')}-'
      '${dateOnly.day.toString().padLeft(2, '0')}';

  /// 某日期是否为调休上班日（排除被自定义假期覆盖的情况）
  bool isAdjustedWorkday(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    // 如果该日期有自定义假期覆盖，则不算调休上班日
    if (entries.any(
      (e) =>
          _isSameDate(e.date, dateOnly) &&
          e.shouldHideCourses &&
          _isCustomEntry(e),
    )) {
      return false;
    }
    return entries.any(
      (e) => _isSameDate(e.date, dateOnly) && e.isAdjustedWorkday,
    );
  }

  /// 获取连续假期组
  List<HolidayEntry> entriesForGroup(String groupId) {
    return entries.where((e) => e.groupId == groupId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isCustomEntry(HolidayEntry e) =>
      e.groupId != null && e.groupId!.startsWith('custom-');

  Map<String, dynamic> toJson() => {
    'year': year,
    'version': version,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory HolidayData.fromJson(Map<String, dynamic> json) {
    return HolidayData(
      year: json['year'] as int,
      version: json['version'] as int? ?? 1,
      entries: (json['entries'] as List<dynamic>? ?? const [])
          .map(
            (e) => HolidayEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  String toJsonString() => jsonEncode(toJson());
}
