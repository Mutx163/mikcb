import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/location_time_group.dart';
import '../models/schedule_date_rule.dart';
import '../models/schedule_item.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import 'transfer_package.dart';

class AppDataBackup {
  final String? profileName;
  final List<Course> courses;
  final List<CourseTask> tasks;
  final List<ScheduleItem> scheduleItems;
  final List<Exam> exams;
  final List<TimeScheme> timeSchemes;
  final List<ScheduleDateRule> scheduleDateRules;
  final List<LocationTimeGroup> locationTimeGroups;
  final TimetableSettings settings;
  final int currentWeek;
  final DateTime exportedAt;
  final String? packageId;
  final TransferScope? scope;
  final TransferChannel channel;

  const AppDataBackup({
    this.profileName,
    required this.courses,
    this.tasks = const [],
    this.scheduleItems = const [],
    this.exams = const [],
    this.timeSchemes = const [],
    this.scheduleDateRules = const [],
    this.locationTimeGroups = const [],
    required this.settings,
    required this.currentWeek,
    required this.exportedAt,
    this.packageId,
    this.scope,
    this.channel = TransferChannel.file,
  });
}

class FullAppDataBackup {
  final List<TimetableProfile> profiles;
  final String? activeProfileId;
  final List<TimeScheme> timeSchemes;
  final List<ScheduleDateRule> scheduleDateRules;
  final List<LocationTimeGroup> locationTimeGroups;
  final DateTime exportedAt;
  final String? packageId;
  final TransferChannel channel;

  const FullAppDataBackup({
    required this.profiles,
    required this.activeProfileId,
    required this.timeSchemes,
    this.scheduleDateRules = const [],
    this.locationTimeGroups = const [],
    required this.exportedAt,
    this.packageId,
    this.channel = TransferChannel.file,
  });
}

class DataTransferService {
  static List<T> _parseOptionalList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (raw is! List) return <T>[];
    final result = <T>[];
    for (final item in raw) {
      try {
        if (item is! Map) {
          continue;
        }
        result.add(parse(Map<String, dynamic>.from(item)));
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// 「原始非空、解析全空」守卫，同款见 :293 的完整备份路径。
  ///
  /// `.mikcb` 的 `schemaVersion` 不匹配就直接拒收（:180），所以进到这里的文件
  /// 一定是**本机同版本**写出来的：条目解析不出来只可能是文件被截断/手改/损坏。
  /// 单课表导入路径把 `backup.courses` **整份替换**进课表
  /// （import_export_service.dart:358），于是一份「课程全解析失败」的文件会被
  /// 当成一份合法的**空课表**：用户原课表被清空、写盘、界面报「导入成功」。
  /// 允许逐条跳过（部分损坏仍能救回能读的部分），但不允许整列表清零。
  static List<T> _parseListWithTotalLossGuard<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    final items = _parseOptionalList<T>(raw, parse);
    if (raw is List && raw.isNotEmpty && items.isEmpty) {
      throw const FormatException('unrecognized_mikcb_data_file');
    }
    return items;
  }

  static const int schemaVersion = TransferPackage.schemaVersion;
  static const String fileExtension = 'mikcb';

  String buildBackupJson({
    String? profileName,
    required List<Course> courses,
    List<CourseTask> tasks = const [],
    List<ScheduleItem> scheduleItems = const [],
    List<Exam> exams = const [],
    List<TimeScheme> timeSchemes = const [],
    List<ScheduleDateRule> scheduleDateRules = const [],
    List<LocationTimeGroup> locationTimeGroups = const [],
    required TimetableSettings settings,
    required int currentWeek,
    TransferScope scope = TransferScope.currentTimetable,
    TransferChannel channel = TransferChannel.file,
    String? packageId,
  }) {
    return buildTransferPackage(
      packageId: packageId,
      scope: scope,
      channel: channel,
      profileName: profileName,
      courses: courses,
      tasks: tasks,
      scheduleItems: scheduleItems,
      exams: exams,
      settings: settings,
      currentWeek: currentWeek,
      timeSchemes: timeSchemes,
      scheduleDateRules: scheduleDateRules,
      locationTimeGroups: locationTimeGroups,
    ).encode();
  }

  TransferPackage buildTransferPackage({
    String? packageId,
    required TransferScope scope,
    TransferChannel channel = TransferChannel.file,
    String? profileName,
    List<Course> courses = const [],
    List<CourseTask> tasks = const [],
    List<ScheduleItem> scheduleItems = const [],
    List<Exam> exams = const [],
    TimetableSettings? settings,
    int? currentWeek,
    List<TimeScheme> timeSchemes = const [],
    List<ScheduleDateRule> scheduleDateRules = const [],
    List<LocationTimeGroup> locationTimeGroups = const [],
    List<TimetableProfile> profiles = const [],
    String? activeProfileId,
    bool isFullBackup = false,
    DateTime? exportedAt,
  }) {
    return TransferPackage(
      packageId: packageId ?? TransferPackage.newPackageId(now: exportedAt),
      scope: scope,
      channel: channel,
      profileName: profileName,
      courses: courses,
      tasks: tasks,
      scheduleItems: scheduleItems,
      exams: exams,
      settings: settings,
      currentWeek: currentWeek,
      timeSchemes: timeSchemes,
      scheduleDateRules: scheduleDateRules,
      locationTimeGroups: locationTimeGroups,
      profiles: profiles,
      activeProfileId: activeProfileId,
      isFullBackup: isFullBackup,
      exportedAt: exportedAt,
    );
  }

  String buildTransferPackageJson({required TransferPackage package}) =>
      package.encode();

  TransferPackage parseTransferPackageJson(String content) {
    return TransferPackage.decode(content);
  }

  AppDataBackup parseBackupJson(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final app = json['app'] as String?;
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;

    if (app != 'mikcb' || version != schemaVersion) {
      throw const FormatException('unrecognized_mikcb_data_file');
    }

    final rawCourses = _parseListWithTotalLossGuard(
      json['courses'],
      Course.fromJson,
    );
    final rawTasks = _parseListWithTotalLossGuard(
      json['tasks'],
      CourseTask.fromJson,
    );
    final rawScheduleItems = _parseListWithTotalLossGuard(
      json['scheduleItems'],
      ScheduleItem.fromJson,
    );
    final rawSettings = json['settings'];
    if (rawSettings is! Map) {
      throw const FormatException('missing_settings_data');
    }
    final settings = TimetableSettings.fromJson(
      Map<String, dynamic>.from(rawSettings),
    );

    return AppDataBackup(
      profileName: (json['profileName'] as String?)?.trim().isEmpty == true
          ? null
          : json['profileName'] as String?,
      courses: rawCourses,
      tasks: rawTasks,
      scheduleItems: rawScheduleItems,
      exams: _parseListWithTotalLossGuard(json['exams'], Exam.fromJson),
      timeSchemes: _parseListWithTotalLossGuard(
        json['timeSchemes'],
        TimeScheme.fromJson,
      ),
      scheduleDateRules: _parseListWithTotalLossGuard(
        json['scheduleDateRules'],
        ScheduleDateRule.fromJson,
      ),
      locationTimeGroups: _parseListWithTotalLossGuard(
        json['locationTimeGroups'],
        LocationTimeGroup.fromJson,
      ),
      settings: settings,
      currentWeek: clampCurrentWeekToSettings(
        ((json['currentWeek'] as num?)?.toInt() ?? 1).clamp(1, 30),
        settings,
      ),
      exportedAt:
          DateTime.tryParse((json['exportedAt'] as String?) ?? '') ??
          DateTime.now(),
      packageId: json['packageId'] as String?,
      scope: json['packageType'] == TransferPackage.packageType
          ? TransferScope.fromValue(json['scope'])
          : null,
      channel: TransferChannelX.fromValue(json['channel']),
    );
  }

  bool isFullBackupJson(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    return json['backupType'] == 'full' ||
        (json['packageType'] == TransferPackage.packageType &&
            json['scope'] == TransferScope.allData.value &&
            json['profiles'] is List);
  }

  String buildFullBackupJson({
    required List<TimetableProfile> profiles,
    required String? activeProfileId,
    required List<TimeScheme> timeSchemes,
    List<ScheduleDateRule> scheduleDateRules = const [],
    List<LocationTimeGroup> locationTimeGroups = const [],
    TransferChannel channel = TransferChannel.file,
    String? packageId,
  }) {
    return buildTransferPackage(
      packageId: packageId,
      scope: TransferScope.allData,
      channel: channel,
      profiles: profiles,
      activeProfileId: activeProfileId,
      timeSchemes: timeSchemes,
      scheduleDateRules: scheduleDateRules,
      locationTimeGroups: locationTimeGroups,
      isFullBackup: true,
    ).encode();
  }

  FullAppDataBackup parseFullBackupJson(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final app = json['app'] as String?;
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    final backupType = json['backupType'] as String?;

    if (app != 'mikcb' || version != schemaVersion || backupType != 'full') {
      throw const FormatException('unrecognized_mikcb_full_backup');
    }

    final rawProfiles = json['profiles'];
    final rawTimeSchemes = json['timeSchemes'];
    if (rawProfiles is! List || rawTimeSchemes is! List) {
      throw const FormatException('missing_full_backup_data');
    }
    final profiles = _parseOptionalList(rawProfiles, TimetableProfile.fromJson);
    final timeSchemes = _parseOptionalList(rawTimeSchemes, TimeScheme.fromJson);
    if ((rawProfiles.isNotEmpty && profiles.isEmpty) ||
        (rawTimeSchemes.isNotEmpty && timeSchemes.isEmpty) ||
        // 容器级条目不许"静默变少"：一档课表 = 它的课 + 考试 + 作业，一条作息 = 整张
        // 节次表。上面那条守卫只挡"全丢光"，而 `_parseOptionalList` 是逐条
        // `catch (_) { continue; }`，`TimetableProfile.fromJson`
        // （`timetable_profile.dart:92` 硬转 `json['id'] as String`）或
        // `TimeScheme.fromJson` 里任何一处畸形都会让**一整档**被丢掉而其余照常被读到。
        // 下游 `import_export_service.dart:515-520` 是 `host._profiles = backup.profiles`
        // 整表替换并落盘、`importFullAppDataBackup` 返回 null（成功），撤销同源
        // （`unified_transfer_service.dart:894`）—— 用户视角是"导入成功后某一整份课表
        // 自己消失了"，下一次云同步还会把这份残缺刷给另一台设备。
        // 与本文件 :92-110 对 `.mikcb` 单课表立下的口径一致：允许条目级逐条跳过
        // （课程/任务/考试，`data_transfer_service_test.dart:104-126` 把它钉成了设计），
        // 但容器不许被静默丢弃 —— 宁可整份拒收，让用户拿到一份完整的文件重试或换一份。
        rawProfiles.length != profiles.length ||
        rawTimeSchemes.length != timeSchemes.length) {
      throw const FormatException('missing_full_backup_data');
    }

    return FullAppDataBackup(
      profiles: profiles,
      activeProfileId: json['activeProfileId'] as String?,
      timeSchemes: timeSchemes,
      // 日期规则与地点分组**刻意留在条目级 salvage 语义**里（逐条跳过、坏一条救其余），
      // 与课程/任务/考试同档；`data_transfer_full_backup_loss_guard_test.dart:68-100`
      // 把它钉成了设计（"守卫不误伤逐条跳过"）。2026-10-08 审查曾按"容器不许变少"
      // 报过它，实为设计选择而非缺陷，故此处维持原样、不改判据。
      scheduleDateRules: _parseListWithTotalLossGuard(
        json['scheduleDateRules'],
        ScheduleDateRule.fromJson,
      ),
      locationTimeGroups: _parseListWithTotalLossGuard(
        json['locationTimeGroups'],
        LocationTimeGroup.fromJson,
      ),
      exportedAt:
          DateTime.tryParse((json['exportedAt'] as String?) ?? '') ??
          DateTime.now(),
      packageId: json['packageId'] as String?,
      channel: TransferChannelX.fromValue(json['channel']),
    );
  }

  Future<void> exportAndShare({
    String? profileName,
    required List<Course> courses,
    List<CourseTask> tasks = const [],
    List<ScheduleItem> scheduleItems = const [],
    List<Exam> exams = const [],
    List<TimeScheme> timeSchemes = const [],
    List<ScheduleDateRule> scheduleDateRules = const [],
    List<LocationTimeGroup> locationTimeGroups = const [],
    required TimetableSettings settings,
    required int currentWeek,
    required String shareText,
    required String shareSubject,
    TransferScope scope = TransferScope.currentTimetable,
    TransferChannel channel = TransferChannel.file,
    String? packageId,
  }) async {
    final now = DateTime.now();
    final filename =
        'mikcb-backup-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.$fileExtension';
    final bytes = Uint8List.fromList(
      utf8.encode(
        buildBackupJson(
          profileName: profileName,
          courses: courses,
          tasks: tasks,
          scheduleItems: scheduleItems,
          exams: exams,
          timeSchemes: timeSchemes,
          scheduleDateRules: scheduleDateRules,
          locationTimeGroups: locationTimeGroups,
          settings: settings,
          currentWeek: currentWeek,
          scope: scope,
          channel: channel,
          packageId: packageId,
        ),
      ),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/json', name: filename),
        ],
        text: shareText,
        subject: shareSubject,
      ),
    );
  }

  Future<void> exportFullBackupAndShare({
    required List<TimetableProfile> profiles,
    required String? activeProfileId,
    required List<TimeScheme> timeSchemes,
    required String shareText,
    required String shareSubject,
    List<ScheduleDateRule> scheduleDateRules = const [],
    List<LocationTimeGroup> locationTimeGroups = const [],
    TransferChannel channel = TransferChannel.file,
    String? packageId,
  }) async {
    final now = DateTime.now();
    final filename =
        'mikcb-full-backup-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.$fileExtension';
    final bytes = Uint8List.fromList(
      utf8.encode(
        buildFullBackupJson(
          profiles: profiles,
          activeProfileId: activeProfileId,
          timeSchemes: timeSchemes,
          scheduleDateRules: scheduleDateRules,
          locationTimeGroups: locationTimeGroups,
          channel: channel,
          packageId: packageId,
        ),
      ),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/json', name: filename),
        ],
        text: shareText,
        subject: shareSubject,
      ),
    );
  }
}
