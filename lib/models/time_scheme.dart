import 'dart:convert';

import 'timetable_settings.dart';

class TimeScheme {
  final String id;
  final String name;
  final List<SectionTime> sections;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TimeScheme({
    required this.id,
    required this.name,
    required this.sections,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sections': sections.map((section) => section.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TimeScheme.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    return TimeScheme(
      id: json['id'] as String,
      name: json['name'] as String? ?? '未命名时间模板',
      sections: rawSections
          .map((item) =>
              SectionTime.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory TimeScheme.fromJsonString(String jsonString) {
    return TimeScheme.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  TimeScheme copyWith({
    String? id,
    String? name,
    List<SectionTime>? sections,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimeScheme(
      id: id ?? this.id,
      name: name ?? this.name,
      sections: sections ?? this.sections,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get sectionCount => sections.length;
}

class BreakOverrideRule {
  final int afterSection;
  final int breakDurationMinutes;

  const BreakOverrideRule({
    required this.afterSection,
    required this.breakDurationMinutes,
  });
}

List<SectionTime> buildQuickSectionTimes({
  required int morningCount,
  required int afternoonCount,
  required int eveningCount,
  required String? morningStartTime,
  required String? afternoonStartTime,
  required String? eveningStartTime,
  required int classDurationMinutes,
  required int breakDurationMinutes,
  List<BreakOverrideRule> breakOverrideRules = const [],
}) {
  final sections = <SectionTime>[];
  var sectionNumber = 1;
  final overrides = {
    for (final rule in breakOverrideRules) rule.afterSection: rule.breakDurationMinutes,
  };

  void appendPeriod({
    required int count,
    required String? startTime,
  }) {
    if (count <= 0) {
      return;
    }
    if (startTime == null || startTime.isEmpty) {
      throw const FormatException('请为有节次的时段设置第一节开始时间');
    }

    var currentStartMinutes = _clockMinutes(startTime);
    for (var index = 0; index < count; index++) {
      final currentEndMinutes = currentStartMinutes + classDurationMinutes;
      sections.add(
        SectionTime(
          startTime: _minutesToClock(currentStartMinutes),
          endTime: _minutesToClock(currentEndMinutes),
        ),
      );
      final breakMinutes =
          overrides[sectionNumber] ?? breakDurationMinutes;
      currentStartMinutes = currentEndMinutes + breakMinutes;
      sectionNumber += 1;
    }
  }

  if (classDurationMinutes <= 0) {
    throw const FormatException('上课时长必须大于 0');
  }
  if (breakDurationMinutes < 0) {
    throw const FormatException('课间时长不能小于 0');
  }

  appendPeriod(count: morningCount, startTime: morningStartTime);
  appendPeriod(count: afternoonCount, startTime: afternoonStartTime);
  appendPeriod(count: eveningCount, startTime: eveningStartTime);

  if (sections.isEmpty) {
    throw const FormatException('至少需要设置一个时段的节次数');
  }

  return sections;
}

int _clockMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    throw const FormatException('时间格式不正确');
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    throw const FormatException('时间格式不正确');
  }
  return hour * 60 + minute;
}

String _minutesToClock(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
