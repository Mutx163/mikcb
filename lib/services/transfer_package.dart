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

  static const Map<String, String> _requiredListKinds = {
    'courses': 'course',
    'tasks': 'task',
    'scheduleItems': 'schedule_item',
    'exams': 'exam',
    'timeSchemes': 'time_scheme',
    'scheduleDateRules': 'time_rule',
    'locationTimeGroups': 'location_group',
    'profiles': 'profile',
  };

  static const Map<String, List<String>> _requiredEntityFields = {
    'course': [
      'id',
      'name',
      'teacher',
      'location',
      'dayOfWeek',
      'startSection',
      'endSection',
      'startTime',
      'endTime',
    ],
    'task': ['id', 'title', 'createdAt', 'updatedAt'],
    'schedule_item': [
      'id',
      'title',
      'startDate',
      'endDate',
      'startTime',
      'endTime',
      'createdAt',
      'updatedAt',
      'recurrence',
      'exceptionDates',
      'enabled',
    ],
    'exam': [
      'id',
      'courseId',
      'name',
      'dateTime',
      'startTime',
      'endTime',
      'createdAt',
      'updatedAt',
    ],
    'time_scheme': ['id', 'name', 'sections', 'createdAt', 'updatedAt'],
    'time_rule': [
      'id',
      'name',
      'timeSchemeId',
      'enabled',
      'startDate',
      'endDate',
    ],
    'location_group': [
      'id',
      'name',
      'timeSchemeId',
      'enabled',
      'priority',
      'keywords',
    ],
    'profile': [
      'id',
      'name',
      'courses',
      'tasks',
      'scheduleItems',
      'exams',
      'settings',
      'currentWeek',
      'createdAt',
      'lastUsedAt',
    ],
  };

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
    required String packageId,
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
  }) : packageId = packageId.trim(),
       exportedAt = exportedAt ?? DateTime.now() {
    _requireUniqueIdsAcross(
      'course',
      courses.map((item) => item.id),
      profiles.map((profile) => profile.courses.map((item) => item.id)),
    );
    _requireUniqueIdsAcross(
      'task',
      tasks.map((item) => item.id),
      profiles.map((profile) => profile.tasks.map((item) => item.id)),
    );
    _requireUniqueIdsAcross(
      'schedule_item',
      scheduleItems.map((item) => item.id),
      profiles.map(
        (profile) => profile.scheduleItems.map((item) => item.id),
      ),
    );
    _requireUniqueIdsAcross(
      'exam',
      exams.map((item) => item.id),
      profiles.map((profile) => profile.exams.map((item) => item.id)),
    );
    _requireUniqueIds('profile', profiles.map((item) => item.id));
    _requireUniqueIds('time_scheme', timeSchemes.map((item) => item.id));
    _requireUniqueIds('time_rule', scheduleDateRules.map((item) => item.id));
    _requireUniqueIds(
      'location_group',
      locationTimeGroups.map((item) => item.id),
    );
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
    late final String content;
    try {
      content = utf8.decode(bytes);
    } on Object {
      throw const FormatException('transfer_package_utf8_invalid');
    }
    return decode(content);
  }

  static TransferPackage fromJson(Map<String, dynamic> json) {
    if (json['app'] != appId || json['packageType'] != packageType) {
      throw const FormatException('transfer_package_type_invalid');
    }
    final version = json['schemaVersion'];
    if (version != schemaVersion) {
      throw const FormatException('transfer_package_schema_unsupported');
    }

    for (final entry in _requiredListKinds.entries) {
      if (!json.containsKey(entry.key) || json[entry.key] == null) {
        throw FormatException('transfer_${entry.value}_list_required');
      }
    }

    final packageId = _requiredString(json, 'packageId', 'package_id');
    final scope = TransferScope.fromValue(
      _requiredString(json, 'scope', 'scope'),
    );
    final channel = _parseChannel(json['channel']);
    final exportedAt = _parseExportedAt(json['exportedAt']);
    final profileName = _optionalString(json, 'profileName');
    final activeProfileId = _optionalString(json, 'activeProfileId');
    final currentWeek = _optionalInt(json, 'currentWeek');
    final backupType = json['backupType'];
    if (backupType != null && backupType != 'full') {
      throw const FormatException('transfer_backup_type_invalid');
    }

    final settingsRaw = json['settings'];
    TimetableSettings? settings;
    if (settingsRaw != null) {
      if (settingsRaw is! Map) {
        throw const FormatException('transfer_settings_invalid');
      }
      try {
        settings = TimetableSettings.fromJson(
          Map<String, dynamic>.from(settingsRaw),
        );
      } on Object {
        throw const FormatException('transfer_settings_invalid');
      }
    }

    final courses = _parseList<Course>(
      json['courses'],
      Course.fromJson,
      'course',
    );
    final tasks = _parseList<CourseTask>(
      json['tasks'],
      CourseTask.fromJson,
      'task',
    );
    final scheduleItems = _parseList<ScheduleItem>(
      json['scheduleItems'],
      ScheduleItem.fromJson,
      'schedule_item',
    );
    final exams = _parseList<Exam>(json['exams'], Exam.fromJson, 'exam');
    final timeSchemes = _parseList<TimeScheme>(
      json['timeSchemes'],
      TimeScheme.fromJson,
      'time_scheme',
    );
    final scheduleDateRules = _parseList<ScheduleDateRule>(
      json['scheduleDateRules'],
      ScheduleDateRule.fromJson,
      'time_rule',
    );
    final locationTimeGroups = _parseList<LocationTimeGroup>(
      json['locationTimeGroups'],
      LocationTimeGroup.fromJson,
      'location_group',
    );
    final profiles = _parseList<TimetableProfile>(
      json['profiles'],
      TimetableProfile.fromJson,
      'profile',
    );
    final profileScoped = profiles.isNotEmpty;
    if (settings == null &&
        scope != TransferScope.timeTemplate &&
        !profileScoped) {
      throw const FormatException('transfer_settings_required');
    }
    if (currentWeek == null &&
        scope != TransferScope.timeTemplate &&
        !profileScoped) {
      throw const FormatException('transfer_current_week_required');
    }

    return TransferPackage(
      packageId: packageId,
      scope: scope,
      channel: channel,
      profileName: profileName,
      currentWeek: currentWeek,
      activeProfileId: activeProfileId,
      settings: settings,
      courses: courses,
      tasks: tasks,
      scheduleItems: scheduleItems,
      exams: exams,
      timeSchemes: timeSchemes,
      scheduleDateRules: scheduleDateRules,
      locationTimeGroups: locationTimeGroups,
      profiles: profiles,
      isFullBackup: backupType == 'full',
      exportedAt: exportedAt,
    );
  }

  /// Performs non-throwing package validation for import previews and tests.
  static TransferPackageValidation validateJson(String content) {
    try {
      final package = decode(content);
      return package.validate();
    } on FormatException catch (error) {
      return TransferPackageValidation(errors: [error.message]);
    } on Object {
      return const TransferPackageValidation(
        errors: ['transfer_package_invalid'],
      );
    }
  }

  /// Returns structural diagnostics that do not require a local comparison.
  TransferPackageValidation validate() {
    final hasPayload = profiles.isNotEmpty ||
        courses.isNotEmpty ||
        tasks.isNotEmpty ||
        scheduleItems.isNotEmpty ||
        exams.isNotEmpty ||
        timeSchemes.isNotEmpty ||
        scheduleDateRules.isNotEmpty ||
        locationTimeGroups.isNotEmpty ||
        settings != null;
    final errors = <String>[];
    final warnings = <String>[];
    if (!hasPayload) {
      errors.add('transfer_package_empty');
    }
    if (isFullBackup && scope == TransferScope.allData && profiles.isEmpty) {
      errors.add('transfer_full_profiles_required');
    }
    if (scope == TransferScope.timeTemplate && timeSchemes.isEmpty) {
      errors.add('transfer_time_template_empty');
    }
    if (activeProfileId != null &&
        profiles.isNotEmpty &&
        !profiles.any((profile) => profile.id == activeProfileId)) {
      warnings.add('active_profile_missing:$activeProfileId');
    }
    return TransferPackageValidation(errors: errors, warnings: warnings);
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

  static String _requiredString(
    Map<String, dynamic> json,
    String key,
    String codeKey,
  ) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('transfer_${codeKey}_required');
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key) || json[key] == null) {
      return null;
    }
    final value = json[key];
    if (value is! String) {
      throw FormatException('transfer_${key}_invalid');
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key) || json[key] == null) {
      return null;
    }
    final value = json[key];
    if (value is! num || value.toInt() != value) {
      throw FormatException('transfer_${key}_invalid');
    }
    return value.toInt();
  }

  static DateTime _parseExportedAt(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('transfer_exported_at_required');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw const FormatException('transfer_exported_at_invalid');
    }
    return parsed;
  }

  static TransferChannel _parseChannel(Object? raw) {
    if (raw is! String) {
      throw const FormatException('transfer_channel_required');
    }
    final value = raw.trim().toLowerCase();
    for (final channel in TransferChannel.values) {
      if (channel.value == value) {
        return channel;
      }
    }
    throw const FormatException('transfer_channel_invalid');
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
    for (var index = 0; index < raw.length; index++) {
      final item = raw[index];
      if (item is! Map) {
        throw FormatException('transfer_${kind}_invalid');
      }
      try {
        final map = Map<String, dynamic>.from(item);
        _validateEntityMap(kind, map);
        parsed.add(parse(map));
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
      if (id.isEmpty) {
        throw FormatException('transfer_${kind}_id_required');
      }
      if (!seen.add(id)) {
        throw FormatException('transfer_${kind}_id_duplicate');
      }
    }
  }

  static void _requireUniqueIdsAcross(
    String kind,
    Iterable<String> topLevelIds,
    Iterable<Iterable<String>> nestedIds,
  ) {
    final seen = <String>{};

    void addAll(Iterable<String> ids) {
      for (final rawId in ids) {
        final id = rawId.trim();
        if (id.isEmpty) {
          throw FormatException('transfer_${kind}_id_required');
        }
        if (!seen.add(id)) {
          throw FormatException('transfer_${kind}_id_duplicate');
        }
      }
    }

    addAll(topLevelIds);
    for (final ids in nestedIds) {
      addAll(ids);
    }
  }

  static void _validateEntityMap(String kind, Map<String, dynamic> json) {
    final fields = _requiredEntityFields[kind];
    if (fields == null) {
      return;
    }
    for (final field in fields) {
      if (!json.containsKey(field) || json[field] == null) {
        throw FormatException('transfer_${kind}_${field}_required');
      }
    }
    if (kind == 'profile') {
      _validateProfileNestedMaps(json);
    }
  }

  static void _validateProfileNestedMaps(Map<String, dynamic> json) {
    const nestedKinds = {
      'courses': 'course',
      'tasks': 'task',
      'scheduleItems': 'schedule_item',
      'exams': 'exam',
    };
    for (final entry in nestedKinds.entries) {
      final rawItems = json[entry.key];
      if (rawItems is! List) {
        throw FormatException('transfer_profile_${entry.key}_list_invalid');
      }
      for (final item in rawItems) {
        if (item is! Map) {
          throw FormatException('transfer_${entry.value}_invalid');
        }
        _validateEntityMap(entry.value, Map<String, dynamic>.from(item));
      }
    }
  }
}

/// Structural validation result for a decoded package.
class TransferPackageValidation {
  final List<String> errors;
  final List<String> warnings;

  const TransferPackageValidation({
    this.errors = const [],
    this.warnings = const [],
  });

  bool get isValid => errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}
