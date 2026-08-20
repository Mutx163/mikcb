import 'dart:convert';

import '../l10n/service_message_localizer.dart';

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
    final rawId = json['id'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('missing time scheme id');
    }
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    final sections = <SectionTime>[];
    for (final item in rawSections) {
      try {
        if (item is! Map) continue;
        sections.add(
          SectionTime.fromJson(Map<String, dynamic>.from(item as Map)),
        );
      } catch (_) {
        continue;
      }
    }
    return TimeScheme(
      id: rawId,
      name: json['name'] as String? ?? '未命名时间模板',
      sections: sections,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory TimeScheme.fromJsonString(String jsonString) {
    return TimeScheme.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
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

String? validateSectionTimes(List<SectionTime> sections) {
  if (sections.isEmpty) {
    return 'at_least_one_section_required';
  }

  var previousEndMinutes = -1;
  for (var index = 0; index < sections.length; index++) {
    final section = sections[index];
    final startMinutes = _clockMinutes(section.startTime);
    final endMinutes = _clockMinutes(section.endTime);

    if (endMinutes <= startMinutes) {
      return encodeServiceMessage(
        'section_end_must_after_start',
        {'sectionNumber': index + 1},
      );
    }

    if (previousEndMinutes >= 0 && startMinutes < previousEndMinutes) {
      return encodeServiceMessage(
        'section_start_before_previous_end',
        {'sectionNumber': index + 1},
      );
    }

    previousEndMinutes = endMinutes;
  }

  return null;
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
    for (final rule in breakOverrideRules)
      rule.afterSection: rule.breakDurationMinutes,
  };

  void appendPeriod({required int count, required String? startTime}) {
    if (count <= 0) {
      return;
    }
    if (startTime == null || startTime.isEmpty) {
      throw const FormatException('period_start_time_required');
    }

    var currentStartMinutes = _clockMinutes(startTime);
    for (var index = 0; index < count; index++) {
      final currentEndMinutes = currentStartMinutes + classDurationMinutes;
      if (currentEndMinutes > 24 * 60) {
        throw FormatException(
          encodeServiceMessage(
            'section_crosses_midnight',
            {'sectionNumber': sectionNumber},
          ),
        );
      }
      sections.add(
        SectionTime(
          startTime: _minutesToClock(currentStartMinutes),
          endTime: _minutesToClock(currentEndMinutes),
        ),
      );
      final breakMinutes = overrides[sectionNumber] ?? breakDurationMinutes;
      currentStartMinutes = currentEndMinutes + breakMinutes;
      sectionNumber += 1;
    }
  }

  if (classDurationMinutes <= 0) {
    throw const FormatException('class_duration_must_positive');
  }
  if (breakDurationMinutes < 0) {
    throw const FormatException('break_duration_must_non_negative');
  }

  appendPeriod(count: morningCount, startTime: morningStartTime);
  appendPeriod(count: afternoonCount, startTime: afternoonStartTime);
  appendPeriod(count: eveningCount, startTime: eveningStartTime);

  if (sections.isEmpty) {
    throw const FormatException('at_least_one_period_section');
  }

  final validationMessage = validateSectionTimes(sections);
  if (validationMessage != null) {
    throw FormatException(validationMessage);
  }

  return sections;
}

int _clockMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    throw const FormatException('invalid_time_format');
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    throw const FormatException('invalid_time_format');
  }
  return hour * 60 + minute;
}

String _minutesToClock(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
