import 'dart:convert';
import 'dart:typed_data';

import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/location_time_group.dart';
import '../models/schedule_date_rule.dart';
import '../models/schedule_item.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';

/// The user-visible boundary of a transfer. Transport implementations must
/// carry this value instead of inferring scope from the payload contents.
enum TransferScope {
  currentTimetable,
  selectedCourses,
  allData,
  weekTimetable,
  selectedCourse,
  timeTemplate;

  String get value => switch (this) {
    TransferScope.currentTimetable => 'current_timetable',
    TransferScope.selectedCourses => 'selected_courses',
    TransferScope.allData => 'all_data',
    TransferScope.weekTimetable => 'week_timetable',
    TransferScope.selectedCourse => 'selected_course',
    TransferScope.timeTemplate => 'time_template',
  };

  static TransferScope fromValue(Object? raw) {
    final value = raw?.toString().trim();
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => throw const FormatException('transfer_scope_invalid'),
    );
  }
}

/// Identifies the path that produced or consumed a package. It is metadata,
/// not an authorization boundary; all paths still require the same preview.
enum TransferChannel { file, qr, lan, cloud }

extension TransferChannelX on TransferChannel {
  String get value => name;

  static TransferChannel fromValue(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    return TransferChannel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TransferChannel.file,
    );
  }
}

enum TransferApplyMode { merge, overwrite }

enum TransferEntityKind {
  courses,
  exams,
  timeRules,
  locations,
  tasks,
  scheduleItems,
  timeSchemes,
  settings;

  String get value => switch (this) {
    TransferEntityKind.courses => 'courses',
    TransferEntityKind.exams => 'exams',
    TransferEntityKind.timeRules => 'time_rules',
    TransferEntityKind.locations => 'locations',
    TransferEntityKind.tasks => 'tasks',
    TransferEntityKind.scheduleItems => 'schedule_items',
    TransferEntityKind.timeSchemes => 'time_schemes',
    TransferEntityKind.settings => 'settings',
  };
}

/// Versioned, transport-neutral payload shared by file, QR, LAN and cloud.
///
/// Lists are intentionally kept typed at the boundary. A transport adapter
/// should never decode individual model maps on its own.
class TransferPackage {
  static const String appId = 'mikcb';
  static const String packageType = 'transfer';
  static const int schemaVersion = 1;

  final String packageId;
  final TransferScope scope;
  final TransferChannel channel;
  final String? profileName;
  final List<Course> courses;
  final List<CourseTask> tasks;
  final List<ScheduleItem> scheduleItems;
  final List<Exam> exams;
  final TimetableSettings? settings;
  final int? currentWeek;
  final List<TimeScheme> timeSchemes;
  final List<ScheduleDateRule> scheduleDateRules;
  final List<LocationTimeGroup> locationTimeGroups;
  final List<TimetableProfile> profiles;
  final String? activeProfileId;
  final bool isFullBackup;
  final DateTime exportedAt;

  TransferPackage({
    required this.packageId,
    required this.scope,
    this.channel = TransferChannel.file,
    this.profileName,
    this.courses = const [],
    this.tasks = const [],
    this.scheduleItems = const [],
    this.exams = const [],
    this.settings,
    this.currentWeek,
    this.timeSchemes = const [],
    this.scheduleDateRules = const [],
    this.locationTimeGroups = const [],
    this.profiles = const [],
    this.activeProfileId,
    this.isFullBackup = false,
    DateTime? exportedAt,
  }) : exportedAt = exportedAt ?? DateTime.now() {
    _requireUniqueIds('course', courses.map((item) => item.id));
    _requireUniqueIds('task', tasks.map((item) => item.id));
    _requireUniqueIds('schedule_item', scheduleItems.map((item) => item.id));
    _requireUniqueIds('exam', exams.map((item) => item.id));
    _requireUniqueIds('time_scheme', timeSchemes.map((item) => item.id));
    _requireUniqueIds('time_rule', scheduleDateRules.map((item) => item.id));
    _requireUniqueIds(
      'location_group',
      locationTimeGroups.map((item) => item.id),
    );
    _requireUniqueIds('profile', profiles.map((item) => item.id));
    if (packageId.trim().isEmpty) {
      throw const FormatException('transfer_package_id_required');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'app': appId,
      'packageType': packageType,
      'schemaVersion': schemaVersion,
      'packageId': packageId,
      'scope': scope.value,
      'channel': channel.value,
      if (isFullBackup) 'backupType': 'full',
      'exportedAt': exportedAt.toIso8601String(),
      if (profileName != null) 'profileName': profileName,
      if (currentWeek != null) 'currentWeek': currentWeek,
      if (activeProfileId != null) 'activeProfileId': activeProfileId,
      if (settings != null) 'settings': settings!.toJson(),
      'courses': courses.map((item) => item.toJson()).toList(),
      'tasks': tasks.map((item) => item.toJson()).toList(),
      'scheduleItems': scheduleItems.map((item) => item.toJson()).toList(),
      'exams': exams.map((item) => item.toJson()).toList(),
      'timeSchemes': timeSchemes.map((item) => item.toJson()).toList(),
      'scheduleDateRules': scheduleDateRules
          .map((item) => item.toJson())
          .toList(),
      'locationTimeGroups': locationTimeGroups
          .map((item) => item.toJson())
          .toList(),
      'profiles': profiles.map((item) => item.toJson()).toList(),
    };
  }

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  Uint8List encodeBytes() => Uint8List.fromList(utf8.encode(encode()));

  static TransferPackage decode(String content) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on Object {
      throw const FormatException('transfer_package_json_invalid');
    }
    if (decoded is! Map) {
      throw const FormatException('transfer_package_root_invalid');
    }
    return fromJson(Map<String, dynamic>.from(decoded));
  }

  static TransferPackage decodeBytes(Uint8List bytes) {
    try {
      return decode(utf8.decode(bytes));
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('transfer_package_utf8_invalid');
    }
  }

  static TransferPackage fromJson(Map<String, dynamic> json) {
    if (json['app'] != appId || json['packageType'] != packageType) {
      throw const FormatException('transfer_package_type_invalid');
    }
    final version = (json['schemaVersion'] as num?)?.toInt();
    if (version != schemaVersion) {
      throw const FormatException('transfer_package_schema_unsupported');
    }

    final packageId = json['packageId']?.toString().trim() ?? '';
    if (packageId.isEmpty) {
      throw const FormatException('transfer_package_id_required');
    }
    final settingsRaw = json['settings'];
    final settings = settingsRaw is Map
        ? TimetableSettings.fromJson(Map<String, dynamic>.from(settingsRaw))
        : null;

    return TransferPackage(
      packageId: packageId,
      scope: TransferScope.fromValue(json['scope']),
      channel: TransferChannelX.fromValue(json['channel']),
      profileName: _nullableString(json['profileName']),
      currentWeek: (json['currentWeek'] as num?)?.toInt(),
      activeProfileId: _nullableString(json['activeProfileId']),
      settings: settings,
      courses: _parseList<Course>(json['courses'], Course.fromJson, 'course'),
      tasks: _parseList<CourseTask>(json['tasks'], CourseTask.fromJson, 'task'),
      scheduleItems: _parseList<ScheduleItem>(
        json['scheduleItems'],
        ScheduleItem.fromJson,
        'schedule_item',
      ),
      exams: _parseList<Exam>(json['exams'], Exam.fromJson, 'exam'),
      timeSchemes: _parseList<TimeScheme>(
        json['timeSchemes'],
        TimeScheme.fromJson,
        'time_scheme',
      ),
      scheduleDateRules: _parseList<ScheduleDateRule>(
        json['scheduleDateRules'],
        ScheduleDateRule.fromJson,
        'time_rule',
      ),
      locationTimeGroups: _parseList<LocationTimeGroup>(
        json['locationTimeGroups'],
        LocationTimeGroup.fromJson,
        'location_group',
      ),
      profiles: _parseList<TimetableProfile>(
        json['profiles'],
        TimetableProfile.fromJson,
        'profile',
      ),
      isFullBackup: json['backupType'] == 'full',
      exportedAt:
          DateTime.tryParse(json['exportedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  TransferPackage copyWith({
    String? packageId,
    TransferScope? scope,
    TransferChannel? channel,
    String? profileName,
    List<Course>? courses,
    List<CourseTask>? tasks,
    List<ScheduleItem>? scheduleItems,
    List<Exam>? exams,
    TimetableSettings? settings,
    int? currentWeek,
    List<TimeScheme>? timeSchemes,
    List<ScheduleDateRule>? scheduleDateRules,
    List<LocationTimeGroup>? locationTimeGroups,
    List<TimetableProfile>? profiles,
    String? activeProfileId,
    bool? isFullBackup,
    DateTime? exportedAt,
  }) {
    return TransferPackage(
      packageId: packageId ?? this.packageId,
      scope: scope ?? this.scope,
      channel: channel ?? this.channel,
      profileName: profileName ?? this.profileName,
      courses: courses ?? this.courses,
      tasks: tasks ?? this.tasks,
      scheduleItems: scheduleItems ?? this.scheduleItems,
      exams: exams ?? this.exams,
      settings: settings ?? this.settings,
      currentWeek: currentWeek ?? this.currentWeek,
      timeSchemes: timeSchemes ?? this.timeSchemes,
      scheduleDateRules: scheduleDateRules ?? this.scheduleDateRules,
      locationTimeGroups: locationTimeGroups ?? this.locationTimeGroups,
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      isFullBackup: isFullBackup ?? this.isFullBackup,
      exportedAt: exportedAt ?? this.exportedAt,
    );
  }

  static String newPackageId({DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
    return 'transfer-$timestamp';
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static List<T> _parseList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
    String kind,
  ) {
    if (raw == null) {
      return const [];
    }
    if (raw is! List) {
      throw FormatException('transfer_${kind}_list_invalid');
    }
    final parsed = <T>[];
    for (final item in raw) {
      if (item is! Map) {
        throw FormatException('transfer_${kind}_invalid');
      }
      try {
        parsed.add(parse(Map<String, dynamic>.from(item)));
      } on FormatException {
        rethrow;
      } on Object {
        throw FormatException('transfer_${kind}_invalid');
      }
    }
    _requireUniqueIds(kind, parsed.map(_idOf));
    return parsed;
  }

  static String _idOf<T>(T value) {
    return switch (value) {
      final Course item => item.id,
      final CourseTask item => item.id,
      final ScheduleItem item => item.id,
      final Exam item => item.id,
      final TimeScheme item => item.id,
      final ScheduleDateRule item => item.id,
      final LocationTimeGroup item => item.id,
      final TimetableProfile item => item.id,
      _ => throw const FormatException('transfer_entity_id_missing'),
    };
  }

  static void _requireUniqueIds(String kind, Iterable<String> ids) {
    final seen = <String>{};
    for (final rawId in ids) {
      final id = rawId.trim();
      if (id.isEmpty || !seen.add(id)) {
        throw FormatException('transfer_${kind}_id_invalid');
      }
    }
  }
}
