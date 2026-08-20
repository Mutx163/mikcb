import 'course.dart';
import 'course_task.dart';
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
  final List<CourseTask> tasks;
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
    this.tasks = const [],
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
      'tasks': tasks.map((task) => task.toJson()).toList(),
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
      courses: _parseListLenient(
        json['courses'],
        (map) => Course.fromJson(map),
        onDropped: () {},
      ),
      tasks: _parseListLenient(
        json['tasks'],
        (map) => CourseTask.fromJson(map),
        onDropped: () {},
      ),
      scheduleItems: _parseListLenient(
        json['scheduleItems'],
        (map) => ScheduleItem.fromJson(map),
        onDropped: () {},
      ),
      exams: _parseListLenient(
        json['exams'],
        (map) => Exam.fromJson(map),
        onDropped: () {},
      ),
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
      profileKind: TimetableProfileKind.fromValue(
        json['profileKind'] as String?,
      ),
    );
  }

  /// Parses a profile while skipping corrupt nested entries instead of failing.
  factory TimetableProfile.fromJsonLenient(
    Map<String, dynamic> json, {
    TimetableProfileParseStats? stats,
  }) {
    final rawSettings = json['settings'];
    TimetableSettings settings;
    try {
      settings = rawSettings is Map
          ? TimetableSettings.fromJson(Map<String, dynamic>.from(rawSettings))
          : TimetableSettings.defaults();
    } catch (_) {
      settings = TimetableSettings.defaults();
      stats?.droppedSettings += 1;
    }

    final id = json['id']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('profile_id_required');
    }

    return TimetableProfile(
      id: id,
      name: json['name']?.toString() ?? '未命名课表',
      courses: _parseListLenient<Course>(
        json['courses'],
        (map) => Course.fromJson(map),
        onDropped: () => stats?.droppedCourses += 1,
      ),
      tasks: _parseListLenient<CourseTask>(
        json['tasks'],
        (map) => CourseTask.fromJson(map),
        onDropped: () => stats?.droppedTasks += 1,
      ),
      scheduleItems: _parseListLenient<ScheduleItem>(
        json['scheduleItems'],
        (map) => ScheduleItem.fromJson(map),
        onDropped: () => stats?.droppedScheduleItems += 1,
      ),
      exams: _parseListLenient<Exam>(
        json['exams'],
        (map) => Exam.fromJson(map),
        onDropped: () => stats?.droppedExams += 1,
      ),
      settings: settings,
      currentWeek: clampCurrentWeekToSettings(
        ((json['currentWeek'] as num?)?.toInt() ?? 1).clamp(1, 30),
        settings,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      lastUsedAt:
          DateTime.tryParse(json['lastUsedAt']?.toString() ?? '') ??
          DateTime.now(),
      profileKind: TimetableProfileKind.fromValue(
        json['profileKind']?.toString(),
      ),
    );
  }

  /// Parses a profiles JSON list, skipping bad profiles/items instead of wiping.
  static TimetableProfilesParseResult parseProfilesPayload(
    List<dynamic> rawProfiles,
  ) {
    final stats = TimetableProfileParseStats();
    final profiles = <TimetableProfile>[];
    for (final item in rawProfiles) {
      if (item is! Map) {
        stats.droppedProfiles += 1;
        continue;
      }
      try {
        profiles.add(
          TimetableProfile.fromJsonLenient(
            Map<String, dynamic>.from(item),
            stats: stats,
          ),
        );
      } catch (_) {
        stats.droppedProfiles += 1;
      }
    }
    return TimetableProfilesParseResult(profiles: profiles, stats: stats);
  }

  static List<T> _parseListLenient<T>(
    Object? rawList,
    T Function(Map<String, dynamic> map) parse, {
    required void Function() onDropped,
  }) {
    if (rawList is! List) {
      return const [];
    }
    final parsed = <T>[];
    for (final item in rawList) {
      if (item is! Map) {
        onDropped();
        continue;
      }
      try {
        parsed.add(parse(Map<String, dynamic>.from(item)));
      } catch (_) {
        onDropped();
      }
    }
    return parsed;
  }

  TimetableProfile copyWith({
    String? id,
    String? name,
    List<Course>? courses,
    List<CourseTask>? tasks,
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
      tasks: tasks ?? this.tasks,
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

/// Counters for lenient profile payload parsing.
class TimetableProfileParseStats {
  int droppedProfiles = 0;
  int droppedCourses = 0;
  int droppedTasks = 0;
  int droppedScheduleItems = 0;
  int droppedExams = 0;
  int droppedSettings = 0;

  bool get didDrop =>
      droppedProfiles > 0 ||
      droppedCourses > 0 ||
      droppedTasks > 0 ||
      droppedScheduleItems > 0 ||
      droppedExams > 0 ||
      droppedSettings > 0;

  int get totalDropped =>
      droppedProfiles +
      droppedCourses +
      droppedTasks +
      droppedScheduleItems +
      droppedExams +
      droppedSettings;
}

/// Result of [TimetableProfile.parseProfilesPayload].
class TimetableProfilesParseResult {
  final List<TimetableProfile> profiles;
  final TimetableProfileParseStats stats;

  const TimetableProfilesParseResult({
    required this.profiles,
    required this.stats,
  });

  bool get didDrop => stats.didDrop;
}
