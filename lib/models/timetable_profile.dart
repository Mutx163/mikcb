import 'course.dart';
import 'timetable_settings.dart';

class TimetableProfile {
  final String id;
  final String name;
  final List<Course> courses;
  final TimetableSettings settings;
  final int currentWeek;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  const TimetableProfile({
    required this.id,
    required this.name,
    required this.courses,
    required this.settings,
    required this.currentWeek,
    required this.createdAt,
    required this.lastUsedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'courses': courses.map((course) => course.toJson()).toList(),
      'settings': settings.toJson(),
      'currentWeek': currentWeek,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  factory TimetableProfile.fromJson(Map<String, dynamic> json) {
    final rawSettings = json['settings'];
    final settings = rawSettings is Map
        ? TimetableSettings.fromJson(Map<String, dynamic>.from(rawSettings))
        : TimetableSettings.defaults();

    return TimetableProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '未命名课表',
      courses: (json['courses'] as List<dynamic>? ?? const [])
          .map((item) => Course.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      settings: settings,
      currentWeek: ((json['currentWeek'] as num?)?.toInt() ?? 1).clamp(1, 30),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  TimetableProfile copyWith({
    String? id,
    String? name,
    List<Course>? courses,
    TimetableSettings? settings,
    int? currentWeek,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return TimetableProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      courses: courses ?? this.courses,
      settings: settings ?? this.settings,
      currentWeek: currentWeek ?? this.currentWeek,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}
