import 'package:uuid/uuid.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
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

  @override
  Future<Course> createCourse(Course draft) async {
    await _provider.addCourse(draft);
    return _provider.courses.firstWhere((course) => course.id == draft.id);
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
    if (trimmedOriginal != null && trimmedOriginal.isNotEmpty) {
      await _provider.updateCourseGroup(trimmedOriginal, slots);
    } else {
      await _provider.addCourseGroup(slots);
    }
    return slots;
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
    if (incoming.isFullBackup ||
        (incoming.scope == TransferScope.allData &&
            incoming.profiles.isNotEmpty)) {
      throw const FormatException('use_profile_backup_not_full');
    }
    final current = _transferService.buildCurrentPackage(
      provider: _provider,
      channel: TransferChannel.lan,
    );
    return LanTransferPreview(
      incoming: incoming,
      mergeDiff: _transferService.preview(
        current: current,
        incoming: incoming,
        mode: TransferApplyMode.merge,
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
    if (incoming.isFullBackup ||
        (incoming.scope == TransferScope.allData &&
            incoming.profiles.isNotEmpty)) {
      throw const FormatException('use_profile_backup_not_full');
    }
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
    if (incoming.isFullBackup ||
        (incoming.scope == TransferScope.allData &&
            incoming.profiles.isNotEmpty)) {
      throw const FormatException('use_profile_backup_not_full');
    }
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
    if (incoming.isFullBackup ||
        (incoming.scope == TransferScope.allData &&
            incoming.profiles.isNotEmpty)) {
      throw const FormatException('use_profile_backup_not_full');
    }
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
    final startTime =
        json['startTime'] as String? ?? safeSections[startIndex].startTime;
    final endTime =
        json['endTime'] as String? ?? safeSections[endIndex].endTime;
    final normalizedWeeks = Course.normalizeWeeks(
      startWeek: (json['startWeek'] as num?)?.toInt() ?? 1,
      endWeek: (json['endWeek'] as num?)?.toInt() ?? semesterWeekCount,
      maxWeek: semesterWeekCount < 1 ? 1 : semesterWeekCount,
    );

    return Course(
      id: existingId ?? (json['id'] as String?) ?? const Uuid().v4(),
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
      color: normalizeLanCourseColor(json['color']),
      startWeek: normalizedWeeks.startWeek,
      endWeek: normalizedWeeks.endWeek,
      isOddWeek: json['isOddWeek'] as bool? ?? false,
      isEvenWeek: json['isEvenWeek'] as bool? ?? false,
      customWeeks: (json['customWeeks'] as List<dynamic>?)
          ?.map((item) => (item as num).toInt())
          .toList(),
      suspendedWeeks: (json['suspendedWeeks'] as List<dynamic>?)
          ?.map((item) => (item as num).toInt())
          .toList(),
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
