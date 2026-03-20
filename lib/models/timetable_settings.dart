import 'dart:convert';

class SectionTime {
  final String startTime;
  final String endTime;

  const SectionTime({
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory SectionTime.fromJson(Map<String, dynamic> json) {
    return SectionTime(
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
    );
  }

  SectionTime copyWith({
    String? startTime,
    String? endTime,
  }) {
    return SectionTime(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  String get displayText => '$startTime-$endTime';
}

class TimetableSettings {
  final List<SectionTime> sections;
  final double sectionHeight;
  final double compactFontSize;
  final DateTime? semesterStartDate;

  const TimetableSettings({
    required this.sections,
    this.sectionHeight = 68,
    this.compactFontSize = 9,
    this.semesterStartDate,
  });

  factory TimetableSettings.defaults() {
    return const TimetableSettings(
      sections: [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        SectionTime(startTime: '08:55', endTime: '09:40'),
        SectionTime(startTime: '10:00', endTime: '10:45'),
        SectionTime(startTime: '10:55', endTime: '11:40'),
        SectionTime(startTime: '14:00', endTime: '14:45'),
        SectionTime(startTime: '14:55', endTime: '15:40'),
        SectionTime(startTime: '16:00', endTime: '16:45'),
        SectionTime(startTime: '16:55', endTime: '17:40'),
        SectionTime(startTime: '19:00', endTime: '19:45'),
        SectionTime(startTime: '19:55', endTime: '20:40'),
      ],
      sectionHeight: 68,
      compactFontSize: 9,
      semesterStartDate: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sections': sections.map((section) => section.toJson()).toList(),
      'sectionHeight': sectionHeight,
      'compactFontSize': compactFontSize,
      'semesterStartDate': semesterStartDate?.millisecondsSinceEpoch,
    };
  }

  factory TimetableSettings.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    if (rawSections.isEmpty) {
      return TimetableSettings.defaults();
    }

    return TimetableSettings(
      sections: rawSections
          .map((item) => SectionTime.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      sectionHeight: (json['sectionHeight'] as num?)?.toDouble() ?? 68,
      compactFontSize: (json['compactFontSize'] as num?)?.toDouble() ?? 9,
      semesterStartDate: (json['semesterStartDate'] as num?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['semesterStartDate'] as num).toInt(),
            )
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory TimetableSettings.fromJsonString(String jsonString) {
    return TimetableSettings.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  TimetableSettings copyWith({
    List<SectionTime>? sections,
    double? sectionHeight,
    double? compactFontSize,
    DateTime? semesterStartDate,
  }) {
    return TimetableSettings(
      sections: sections ?? this.sections,
      sectionHeight: sectionHeight ?? this.sectionHeight,
      compactFontSize: compactFontSize ?? this.compactFontSize,
      semesterStartDate: semesterStartDate ?? this.semesterStartDate,
    );
  }

  int get sectionCount => sections.length;

  SectionTime sectionAt(int section) => sections[section - 1];
}
