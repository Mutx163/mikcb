import 'package:uuid/uuid.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/clock_time.dart';
import '../utils/course_color_palette.dart';
import 'lan_edit_host.dart';
import 'spreadsheet_import_service.dart';
import 'transfer_package.dart';
import 'unified_transfer_service.dart';
import 'week_expression_parser.dart';

/// Bridges [TimetableProvider] to [LanEditHost] for LAN HTTP handlers.
class LanEditProviderHost implements LanEditHost, LanTransferHost {
  final TimetableProvider _provider;
  final UnifiedTransferService _transferService = UnifiedTransferService();

  LanEditProviderHost(this._provider);

  static const String defaultLanCourseColor = '#2196F3';
  static final RegExp _lanCourseColorPattern = RegExp(r'^#?([0-9a-fA-F]{6})$');

  /// Restricts LAN-provided course colors to the hex format used by the app.
  ///
  /// LAN data is eventually rendered by the browser, so accepting arbitrary
  /// CSS values here would turn a presentation field into an HTML sink. A
  /// safe default also repairs legacy values when a course is edited.
  static String normalizeLanCourseColor(Object? rawColor) {
    if (rawColor is! String) {
      return defaultLanCourseColor;
    }
    final trimmedColor = rawColor.trim();
    final match = _lanCourseColorPattern.firstMatch(trimmedColor);
    if (match == null) {
      return defaultLanCourseColor;
    }
    return '#${match.group(1)!.toUpperCase()}';
  }

  /// 客户端自带的 id：只在是**非空字符串**时才采用。
  /// 空白 id 造出的行无法被 `/api/v1/courses/{id}` 寻址（路由段正则
  /// `([^/]+)` 匹配不到空串），非字符串 id 则会让整条请求 500。
  static String? _suppliedCourseId(Object? rawId) {
    if (rawId is! String) {
      return null;
    }
    final trimmed = rawId.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 客户端送来的钟点必须是可解析的 `H:MM`，否则回落模板值。
  ///
  /// 表单清空时间、或送来 `25:00` 这类越界值时不能直接落库：`Course.startTime`
  /// 全仓按 `HH:MM` 解析（原生侧同样），而越界串会被
  /// `DateTime(y,m,d,hour,minute)` 静默归一到别的日子。规范化用
  /// [ClockTime.formatted]，于是 `8:00` 与模板的 `08:00` 能正确判等。
  static String _usableClockText(Object? rawTime, String fallback) {
    final parsed = ClockTime.tryParse(
      rawTime is String ? rawTime : null,
      allowEndOfDay: true,
    );
    return parsed?.formatted ?? fallback;
  }

  /// Removes unsafe colors from both top-level and profile-scoped transfers.
  static TransferPackage normalizeTransferCourseColors(
    TransferPackage package,
  ) {
    Course normalizeCourse(Course course) {
      return course.copyWith(color: normalizeLanCourseColor(course.color));
    }

    return package.copyWith(
      courses: package.courses.map(normalizeCourse).toList(growable: false),
      profiles: package.profiles
          .map(
            (profile) => profile.copyWith(
              courses: profile.courses
                  .map(normalizeCourse)
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> ensureInitialized() => _provider.initialize();

  @override
  String? get activeProfileId => _provider.activeProfile?.id;

  @override
  String? get activeProfileName => _provider.activeProfile?.name;

  @override
  List<Map<String, dynamic>> listProfilesSummary() {
    final activeId = _provider.activeProfile?.id;
    return _provider.profiles
        .where((profile) => !profile.isPartnerImported)
        .map(
          (profile) => <String, dynamic>{
            'id': profile.id,
            'name': profile.name,
            'courseCount': profile.courses.length,
            'currentWeek': profile.currentWeek,
            'isActive': profile.id == activeId,
          },
        )
        .toList(growable: false);
  }

  @override
  Future<void> switchProfile(String profileId) async {
    final trimmedId = profileId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('profile_id_required');
    }
    final exists = _provider.profiles.any(
      (profile) => profile.id == trimmedId && !profile.isPartnerImported,
    );
    if (!exists) {
      throw ArgumentError('profile_not_found');
    }
    await _provider.switchProfile(trimmedId);
    if (_provider.activeProfile?.id != trimmedId) {
      throw ArgumentError('profile_switch_failed');
    }
  }

  @override
  int get currentWeek => _provider.currentWeek;

  @override
  TimetableSettings get timetableSettings => _provider.settings;

  @override
  int get semesterWeekCount => _provider.settings.semesterWeekCount;

  @override
  List<Course> get courses => _provider.courses;

  @override
  Course? findCourse(String id) {
    for (final course in _provider.courses) {
      if (course.id == id) {
        return course;
      }
    }
    return null;
  }

  /// 局域网客户端可以自带课程 id（网页端用 `crypto.randomUUID()` 预生成，
  /// 好在一次批量编辑里按 id 引用同一门课）。但 id 是本机的行标识，
  /// 让外部值直接落地有两个可观察后果：`addCourse` 不查重复，于是同一 id
  /// 出现两行，而 `deleteCourse` 用 `removeWhere` —— 删一次掉两行、
  /// 批量删除的计数却只加 1；空 id 更糟，`/api/v1/courses/([^/]+)` 永远
  /// 寻址不到它，PATCH 只会命中第一条同 id 的课。
  /// 这里保留"客户端可指定新 id"的能力，只拒绝撞车与空值（400）。
  void _rejectIdConflict(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('course_id_required');
    }
    if (findCourse(trimmed) != null) {
      throw ArgumentError('course_id_conflict');
    }
  }

  @override
  Future<Course> createCourse(Course draft) async {
    _rejectIdConflict(draft.id);
    await _provider.addCourse(draft);
    return _provider.courses.firstWhere(
      (course) => course.id == draft.id,
      orElse: () => draft,
    );
  }

  @override
  Future<void> updateCourse(Course course) async {
    await _provider.updateCourse(course);
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    await _provider.deleteCourse(courseId);
  }

  @override
  Future<int> deleteCoursesBatch(List<String> courseIds) async {
    var removed = 0;
    for (final id in courseIds) {
      if (findCourse(id) == null) {
        continue;
      }
      await _provider.deleteCourse(id);
      removed += 1;
    }
    return removed;
  }

  @override
  Future<List<Course>> replaceCourseGroup({
    required String? originalName,
    required List<Course> slots,
  }) async {
    if (slots.isEmpty) {
      throw ArgumentError('at_least_one_schedule_slot');
    }
    final trimmedOriginal = originalName?.trim();
    if (trimmedOriginal == null || trimmedOriginal.isEmpty) {
      // 新建分组：整组都是插入，id 撞车同样会造出重复行。
      for (final slot in slots) {
        _rejectIdConflict(slot.id);
      }
      await _provider.addCourseGroup(slots);
    } else {
      await _provider.updateCourseGroup(trimmedOriginal, slots);
    }
    return slots;
  }

  /// 局域网会话只绑定一个课表档（`_ensureWriteProfileTarget` 逐请求校验），
  /// 所以整设备作用域的包在这里永远不该出现。
  ///
  /// 原先只拦 `profiles 非空` 的 all_data：把手里的 `/api/v1/profile/active`
  /// 包改个 `scope` 并把 `profiles` 留空就能绕过，而
  /// `UnifiedTransferService._replaceRulesAndLocations` 判的是
  /// `incoming.scope == TransferScope.allData`（不看数组是否为空），
  /// 于是一次 200 applied 的覆盖导入把**全设备**的地点分组与日期规则清空，
  /// 连带 `resync: true` 改写了这台机器上其他课表档的上课钟点 ——
  /// 那些档在 `listProfilesSummary` 里是隐藏的，配对端根本看不见。
  /// 全量备份（`backupType: 'full'`）与带档的 all_data 一起拒，
  /// 让用户改用「导入课表档」而不是整设备覆盖。
  void _rejectWholeDeviceWrite(TransferPackage incoming) {
    if (incoming.isFullBackup || incoming.scope == TransferScope.allData) {
      throw const FormatException('use_profile_backup_not_full');
    }
  }

  @override
  String buildProfileBackupJson() {
    return _transferService
        .buildCurrentPackage(provider: _provider, channel: TransferChannel.lan)
        .encode();
  }

  @override
  LanTransferPreview? previewTransferJson(String content) {
    final incoming = normalizeTransferCourseColors(
      _transferService.parseCompatible(content, channel: TransferChannel.lan),
    );
    _rejectWholeDeviceWrite(incoming);
    final current = _transferService.buildCurrentPackage(
      provider: _provider,
      channel: TransferChannel.lan,
    );
    return LanTransferPreview(
      incoming: incoming,
      mergeDiff: _transferService.preview(
        current: current,
        incoming: incoming,
      ),
      overwriteDiff: _transferService.preview(
        current: current,
        incoming: incoming,
        mode: TransferApplyMode.overwrite,
      ),
    );
  }

  @override
  Future<TransferApplyResult> applyTransferJson(
    String content, {
    required TransferApplyMode mode,
  }) async {
    final incoming = normalizeTransferCourseColors(
      _transferService.parseCompatible(content, channel: TransferChannel.lan),
    );
    _rejectWholeDeviceWrite(incoming);
    return _transferService.applyToProvider(
      provider: _provider,
      incoming: incoming,
      mode: mode,
    );
  }

  @override
  Future<void> importProfileBackupJson(String content) async {
    final incoming = normalizeTransferCourseColors(
      _transferService.parseCompatible(content, channel: TransferChannel.lan),
    );
    _rejectWholeDeviceWrite(incoming);
    final result = await _transferService.applyToProvider(
      provider: _provider,
      incoming: incoming,
      mode: TransferApplyMode.overwrite,
    );
    if (!result.applied) {
      throw FormatException(result.error ?? 'transfer_import_failed');
    }
  }

  @override
  Future<int> importMergeBackupJson(String content) async {
    final incoming = normalizeTransferCourseColors(
      _transferService.parseCompatible(content, channel: TransferChannel.lan),
    );
    _rejectWholeDeviceWrite(incoming);
    final result = await _transferService.applyToProvider(
      provider: _provider,
      incoming: incoming,
      mode: TransferApplyMode.merge,
    );
    if (!result.applied) {
      throw FormatException(result.error ?? 'transfer_import_failed');
    }
    final courseDiff = result.preview.forKind(TransferEntityKind.courses);
    return courseDiff.addedCount + courseDiff.updatedCount;
  }

  @override
  Future<int> importSpreadsheetCourses(
    SpreadsheetImportResult result, {
    required bool replaceExisting,
  }) {
    return _provider.importParsedCourses(
      result.courses,
      replaceExisting: replaceExisting,
      source: 'spreadsheet',
    );
  }

  @override
  Future<void> setCurrentWeek(int week) => _provider.setCurrentWeek(week);

  @override
  Map<String, dynamic> buildMetaJson() {
    final settings = _provider.settings;
    return {
      'profileId': activeProfileId,
      'profileName': activeProfileName,
      'currentWeek': currentWeek,
      'semesterWeekCount': settings.semesterWeekCount,
      'sectionCount': settings.sectionCount,
      'sections': settings.sections.map((section) => section.toJson()).toList(),
      'presetColors': kPresetCourseColorHexes,
      'weekdayLabels': const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
      'profiles': listProfilesSummary(),
    };
  }

  /// Applies [weekExpression] / [suspendedWeekExpression] on a slot JSON map.
  static void applyWeekExpressionFields(
    Map<String, dynamic> slotMap, {
    required String courseName,
    required int semesterWeekCount,
    List<String>? warnings,
  }) {
    final weekExpression =
        slotMap.remove('weekExpression')?.toString().trim() ?? '';
    if (weekExpression.isNotEmpty) {
      final weeks = WeekExpressionParser.parse(
        weekExpression,
        itemName: courseName,
        semesterWeekCount: semesterWeekCount,
        warnings: warnings,
      );
      slotMap['customWeeks'] = weeks;
      if (weeks.isNotEmpty) {
        slotMap['startWeek'] = weeks.first;
        slotMap['endWeek'] = weeks.last;
      }
      slotMap['isOddWeek'] = false;
      slotMap['isEvenWeek'] = false;
    }
    final suspendedExpression =
        slotMap.remove('suspendedWeekExpression')?.toString().trim() ?? '';
    if (suspendedExpression.isNotEmpty) {
      slotMap['suspendedWeeks'] = WeekExpressionParser.parse(
        suspendedExpression,
        itemName: '$courseName 停课周',
        semesterWeekCount: semesterWeekCount,
        warnings: warnings,
      );
    }
  }

  /// Builds a [Course] from API JSON, filling required defaults.
  static Course courseFromApiJson(
    Map<String, dynamic> json, {
    required List<SectionTime> sections,
    required int semesterWeekCount,
    String? existingId,
  }) {
    final safeSections = sections.isEmpty
        ? TimetableSettings.defaults().sections
        : sections;
    final normalizedSections = Course.normalizeSections(
      startSection: (json['startSection'] as num?)?.toInt() ?? 1,
      endSection:
          (json['endSection'] as num?)?.toInt() ??
          ((json['startSection'] as num?)?.toInt() ?? 1),
      maxSection: safeSections.length,
    );
    final startIndex = normalizedSections.startSection - 1;
    final endIndex = normalizedSections.endSection - 1;
    final templateStartTime = safeSections[startIndex].startTime;
    final templateEndTime = safeSections[endIndex].endTime;
    final startTime = _usableClockText(json['startTime'], templateStartTime);
    final endTime = _usableClockText(json['endTime'], templateEndTime);
    // hasCustomTime 决定 provider 会不会按作息模板重写钟点
    // （TimeSchemeLogic：`if (course.hasCustomTime) return course` 原样保留）。
    // 这里原先根本不读它，于是 PATCH 只改地点时：existing.toJson() 带着
    // hasCustomTime=true 进来却被丢掉 → 造出的对象是 false →
    // `_syncCourseWithEffectiveTimeScheme` 把这门课的时间重写回模板，
    // 而 HTTP 响应回显的还是请求里那份自定义时间 —— 手机与浏览器从此
    // 各显示一个时间。缺字段的老客户端按"送来的时间与模板是否一致"推导，
    // 保证响应即落库。
    final hasCustomTime =
        json['hasCustomTime'] as bool? ??
        (startTime != templateStartTime || endTime != templateEndTime);
    final normalizedWeeks = Course.normalizeWeeks(
      startWeek: (json['startWeek'] as num?)?.toInt() ?? 1,
      endWeek: (json['endWeek'] as num?)?.toInt() ?? semesterWeekCount,
      maxWeek: semesterWeekCount < 1 ? 1 : semesterWeekCount,
    );
    // 与 Course.fromJson 同口径的写侧归一：越界项丢弃、去重、升序、超量整表作废。
    // 裸列表进构造函数时消费侧（isInWeek / activeWeeks）会钳到 1..30，
    // 于是 [999] 变成"这门课哪周都不在"——界面上消失却仍计入统计与伴侣同步。
    final customWeeks = Course.normalizeWeekList(
      (json['customWeeks'] as List<dynamic>?)
          ?.map((item) => (item as num).toInt())
          .toList(),
    );
    final suspendedWeeks = Course.normalizeWeekList(
      (json['suspendedWeeks'] as List<dynamic>?)
          ?.map((item) => (item as num).toInt())
          .toList(),
    );

    return Course(
      id: existingId ?? _suppliedCourseId(json['id']) ?? const Uuid().v4(),
      name: (json['name'] as String?)?.trim() ?? '',
      shortName: json['shortName'] as String?,
      teacher: (json['teacher'] as String?)?.trim() ?? '',
      location: (json['location'] as String?)?.trim() ?? '',
      dayOfWeek: Course.normalizeDayOfWeek(
        (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      ),
      startSection: normalizedSections.startSection,
      endSection: normalizedSections.endSection,
      startTime: startTime,
      endTime: endTime,
      hasCustomTime: hasCustomTime,
      color: normalizeLanCourseColor(json['color']),
      startWeek: normalizedWeeks.startWeek,
      endWeek: normalizedWeeks.endWeek,
      isOddWeek: json['isOddWeek'] as bool? ?? false,
      isEvenWeek: json['isEvenWeek'] as bool? ?? false,
      customWeeks: customWeeks,
      suspendedWeeks: suspendedWeeks,
      note: json['note'] as String?,
      description: json['description'] as String? ?? json['note'] as String?,
      courseNature: CourseNatureX.fromValue(json['courseNature'] as String?),
      timeSchemeIdOverride: json['timeSchemeIdOverride'] as String?,
    );
  }

  static Course mergeCoursePatch(
    Course existing,
    Map<String, dynamic> patch, {
    required List<SectionTime> sections,
    required int semesterWeekCount,
  }) {
    final merged = Map<String, dynamic>.from(existing.toJson());
    for (final entry in patch.entries) {
      merged[entry.key] = entry.value;
    }
    return courseFromApiJson(
      merged,
      sections: sections,
      semesterWeekCount: semesterWeekCount,
      existingId: existing.id,
    );
  }

  List<SectionTime> get sections => _provider.settings.sections;

  int get semesterWeekCountValue => _provider.settings.semesterWeekCount;
}
