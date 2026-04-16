import 'dart:convert';

class ScheduleItem {
  static const Object _unset = Object();

  final String id;
  final String title;
  final String? location;
  final String? note;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduleItem({
    required this.id,
    required this.title,
    this.location,
    this.note,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    required this.startTime,
    required this.endTime,
    this.color = '#5B9CF6',
    required this.createdAt,
    required this.updatedAt,
  })  : startDate = _normalizeDate(startDate ?? date ?? DateTime.now()),
        endDate = _resolveNormalizedEndDate(
          startDate: startDate ?? date ?? DateTime.now(),
          endDate: endDate,
        );

  DateTime get date => startDate;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'note': note,
      'date': _normalizeDate(startDate).toIso8601String(),
      'startDate': _normalizeDate(startDate).toIso8601String(),
      'endDate': _normalizeDate(endDate).toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final legacyDate = DateTime.tryParse(json['date'] as String? ?? '');
    final parsedStartDate =
        DateTime.tryParse(json['startDate'] as String? ?? '');
    final parsedEndDate = DateTime.tryParse(json['endDate'] as String? ?? '');

    return ScheduleItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      location: json['location'] as String?,
      note: json['note'] as String?,
      startDate: _normalizeDate(parsedStartDate ?? legacyDate ?? now),
      endDate: _normalizeDate(
        parsedEndDate ?? parsedStartDate ?? legacyDate ?? now,
      ),
      startTime: json['startTime'] as String? ?? '08:00',
      endTime: json['endTime'] as String? ?? '09:00',
      color: json['color'] as String? ?? '#5B9CF6',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ScheduleItem.fromJsonString(String jsonString) {
    return ScheduleItem.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  ScheduleItem copyWith({
    String? id,
    String? title,
    Object? location = _unset,
    Object? note = _unset,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final resolvedStartDate = startDate ?? date ?? this.startDate;
    return ScheduleItem(
      id: id ?? this.id,
      title: title ?? this.title,
      location:
          identical(location, _unset) ? this.location : location as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      startDate: resolvedStartDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool coversDate(DateTime value) {
    final normalizedValue = _normalizeDate(value);
    return !normalizedValue.isBefore(startDate) &&
        !normalizedValue.isAfter(endDate);
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _resolveNormalizedEndDate({
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final normalizedStart = _normalizeDate(startDate);
    final normalizedEnd = _normalizeDate(endDate ?? startDate);
    if (normalizedEnd.isBefore(normalizedStart)) {
      return normalizedStart;
    }
    return normalizedEnd;
  }
}
