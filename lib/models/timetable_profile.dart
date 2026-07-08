import 'course.dart';
import 'exam.dart';
import 'schedule_item.dart';
import 'timetable_settings.dart';

enum TimetableProfileKind {
  normal,
  partnerImported;

  String get value => switch (this) {
    TimetableProfileKind.normal => 'normal',
    TimetableProfileKind.partnerImported => 'partnerImported',
  };

  static TimetableProfileKind fromValue(String? value) {
    return TimetableProfileKind.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TimetableProfileKind.normal,
    );
  }
}

int clampCurrentWeekToSettings(int week, TimetableSettings settings) {
  final maxWeek = settings.semesterWeekCount < 1
      ? 1
      : settings.semesterWeekCount;
  if (week < 1) {
    return 1;
  }
  if (week > maxWeek) {
    return maxWeek;
  }
  return week;
}

class TimetableProfile {
  final String id;
  final String name;
  final List<Course> courses;
  final List<ScheduleItem> scheduleItems;
  final List<Exam> exams;
  final TimetableSettings settings;
  final int currentWeek;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final TimetableProfileKind profileKind;

  const TimetableProfile({
    required this.id,
    required this.name,
    required this.courses,
    this.scheduleItems = const [],
    this.exams = const [],
    required this.settings,
    required this.currentWeek,
    required this.createdAt,
    required this.lastUsedAt,
    this.profileKind = TimetableProfileKind.normal,
  });

  bool get isPartnerImported =>
      profileKind == TimetableProfileKind.partnerImported;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'courses': courses.map((course) => course.toJson()).toList(),
      'scheduleItems': scheduleItems.map((item) => item.toJson()).toList(),
      'exams': exams.map((exam) => exam.toJson()).toList(),
      'settings': settings.toJson(),
      'currentWeek': currentWeek,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
      'profileKind': profileKind.value,
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
          .map(
            (item) => Course.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      scheduleItems: (json['scheduleItems'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                ScheduleItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      exams: (json['exams'] as List<dynamic>? ?? const [])
          .map((item) => Exam.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      settings: settings,
      currentWeek: clampCurrentWeekToSettings(
        ((json['currentWeek'] as num?)?.toInt() ?? 1).clamp(1, 30),
        settings,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastUsedAt:
          DateTime.tryParse(json['lastUsedAt'] as String? ?? '') ??
          DateTime.now(),
      profileKind: TimetableProfileKind.fromValue(json['profileKind'] as String?),
    );
  }

  TimetableProfile copyWith({
    String? id,
    String? name,
    List<Course>? courses,
    List<ScheduleItem>? scheduleItems,
    List<Exam>? exams,
    TimetableSettings? settings,
    int? currentWeek,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    TimetableProfileKind? profileKind,
  }) {
    return TimetableProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      courses: courses ?? this.courses,
      scheduleItems: scheduleItems ?? this.scheduleItems,
      exams: exams ?? this.exams,
      settings: settings ?? this.settings,
      currentWeek: currentWeek ?? this.currentWeek,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      profileKind: profileKind ?? this.profileKind,
    );
  }
}
