import 'dart:convert';

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
        Course.fromJson,
        onDropped: () {},
      ),
      tasks: _parseListLenient(
        json['tasks'],
        CourseTask.fromJson,
        onDropped: () {},
      ),
      scheduleItems: _parseListLenient(
        json['scheduleItems'],
        ScheduleItem.fromJson,
        onDropped: () {},
      ),
      exams: _parseListLenient(json['exams'], Exam.fromJson, onDropped: () {}),
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
      // 整份设置被回落成默认值同样是「条目级」损失：留档原始那份，避免清洗结果
      // 写回后用户真实的学期起始日/节次表/主题永久消失且无从找回。
      TimetableProfile.quarantineDroppedItem(
        stats?.quarantinedItems,
        rawSettings,
      );
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
        Course.fromJson,
        onDropped: () => stats?.droppedCourses += 1,
        quarantineSink: stats?.quarantinedItems,
      ),
      tasks: _parseListLenient<CourseTask>(
        json['tasks'],
        CourseTask.fromJson,
        onDropped: () => stats?.droppedTasks += 1,
        quarantineSink: stats?.quarantinedItems,
      ),
      scheduleItems: _parseListLenient<ScheduleItem>(
        json['scheduleItems'],
        ScheduleItem.fromJson,
        onDropped: () => stats?.droppedScheduleItems += 1,
        quarantineSink: stats?.quarantinedItems,
      ),
      exams: _parseListLenient<Exam>(
        json['exams'],
        Exam.fromJson,
        onDropped: () => stats?.droppedExams += 1,
        quarantineSink: stats?.quarantinedItems,
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
        TimetableProfile.quarantineDroppedItem(stats.quarantinedItems, item);
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
        TimetableProfile.quarantineDroppedItem(stats.quarantinedItems, item);
      }
    }
    return TimetableProfilesParseResult(profiles: profiles, stats: stats);
  }

  static List<T> _parseListLenient<T>(
    Object? rawList,
    T Function(Map<String, dynamic> map) parse, {
    required void Function() onDropped,
    List<String>? quarantineSink,
  }) {
    if (rawList is! List) {
      return const [];
    }
    final parsed = <T>[];
    for (final item in rawList) {
      if (item is! Map) {
        onDropped();
        quarantineDroppedItem(quarantineSink, item);
        continue;
      }
      try {
        parsed.add(parse(Map<String, dynamic>.from(item)));
      } catch (_) {
        onDropped();
        // 存档原始字节：丢弃本身可能只是「当前版本的解析器读不懂」，用户数据
        // 不该因此永久消失。没有留档的话，这条记录就再也找不回来了。
        quarantineDroppedItem(quarantineSink, item);
      }
    }
    return parsed;
  }

  /// 把被丢弃的原始条目编码进 [sink]，上限 [maxQuarantinedItems] 条、
  /// 单条 [maxQuarantinedItemChars] 字符，避免畸形数据把留档本身撑爆。
  static void quarantineDroppedItem(List<String>? sink, Object? item) {
    if (sink == null || sink.length >= maxQuarantinedItems) {
      return;
    }
    String encoded;
    try {
      encoded = jsonEncode(item);
    } catch (_) {
      encoded = '"${item.toString()}"';
    }
    if (encoded.length > maxQuarantinedItemChars) {
      encoded = '${encoded.substring(0, maxQuarantinedItemChars)}…(截断)';
    }
    sink.add(encoded);
  }

  /// 留档容量上限（条数 / 单条字符数）。
  static const int maxQuarantinedItems = 50;
  static const int maxQuarantinedItemChars = 4096;

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

  /// 被丢弃条目的原始 JSON（有容量上限，见 [TimetableProfile.maxQuarantinedItems]）。
  /// 供存储层留档，避免「解析器一时读不懂」直接变成永久删除。
  final List<String> quarantinedItems = <String>[];

  /// 是否只是**条目级**损坏（某门课/某个考试读坏了，或整份设置被回落成默认值），
  /// 而不是整条课表记录坏掉。存储层据此决定要不要把清洗结果写回磁盘：
  /// 条目级丢弃写回即毁数据（原字节被清洗后的版本覆盖，且此后无人再能恢复），
  /// 而整条记录不可用时把它留在盘上每次启动都会重新踩。
  bool get hasItemLevelDrops =>
      droppedCourses > 0 ||
      droppedTasks > 0 ||
      droppedScheduleItems > 0 ||
      droppedExams > 0 ||
      droppedSettings > 0;

  bool get hasProfileLevelDrops => droppedProfiles > 0;

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

  /// 只有条目级损坏（没有整条记录坏掉）—— 存储层此时不应把清洗结果写回磁盘。
  bool get hasItemLevelOnlyDrops =>
      stats.hasItemLevelDrops && !stats.hasProfileLevelDrops;

  List<String> get quarantinedItems => stats.quarantinedItems;
}
