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
