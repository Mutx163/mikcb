import 'package:uuid/uuid.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import 'lan_edit_host.dart';

const _presetCourseColors = [
  '#2196F3',
  '#4CAF50',
  '#FF9800',
  '#E91E63',
  '#9C27B0',
  '#00BCD4',
  '#FF5722',
  '#795548',
  '#607D8B',
];

/// Bridges [TimetableProvider] to [LanEditHost] for LAN HTTP handlers.
class LanEditProviderHost implements LanEditHost {
  final TimetableProvider _provider;

  LanEditProviderHost(this._provider);

  @override
  Future<void> ensureInitialized() => _provider.initialize();

  @override
  String? get activeProfileName => _provider.activeProfile?.name;

  @override
  int get currentWeek => _provider.currentWeek;

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
  Future<List<Course>> replaceCourseGroup({
    required String? originalName,
    required List<Course> slots,
  }) async {
    if (slots.isEmpty) {
      throw ArgumentError('至少需要保留一个上课时间段');
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
    return _provider.dataTransferService.buildBackupJson(
      profileName: _provider.activeProfile?.name,
      courses: _provider.courses,
      exams: _provider.exams,
      settings: _provider.settings,
      currentWeek: _provider.currentWeek,
    );
  }

  @override
  Future<void> importProfileBackupJson(String content) async {
    final error = await _provider.importAppDataBackup(content);
    if (error != null) {
      throw FormatException(error);
    }
  }

  @override
  Map<String, dynamic> buildMetaJson() {
    final settings = _provider.settings;
    return {
      'profileName': activeProfileName,
      'currentWeek': currentWeek,
      'semesterWeekCount': settings.semesterWeekCount,
      'sectionCount': settings.sectionCount,
      'sections': settings.sections.map((section) => section.toJson()).toList(),
      'presetColors': _presetCourseColors,
      'weekdayLabels': const [
        '周一',
        '周二',
        '周三',
        '周四',
        '周五',
        '周六',
        '周日',
      ],
    };
  }

  /// Builds a [Course] from API JSON, filling required defaults.
  static Course courseFromApiJson(
    Map<String, dynamic> json, {
    required List<SectionTime> sections,
    required int semesterWeekCount,
    String? existingId,
  }) {
    final startSection = (json['startSection'] as num?)?.toInt() ?? 1;
    final endSection = (json['endSection'] as num?)?.toInt() ?? startSection;
    final safeSections = sections.isEmpty
        ? TimetableSettings.defaults().sections
        : sections;
    final startIndex =
        (startSection - 1).clamp(0, safeSections.length - 1);
    final endIndex = (endSection - 1).clamp(0, safeSections.length - 1);
    final startTime = json['startTime'] as String? ??
        safeSections[startIndex].startTime;
    final endTime =
        json['endTime'] as String? ?? safeSections[endIndex].endTime;

    return Course(
      id: existingId ?? (json['id'] as String?) ?? const Uuid().v4(),
      name: (json['name'] as String?)?.trim() ?? '',
      shortName: json['shortName'] as String?,
      teacher: (json['teacher'] as String?)?.trim() ?? '',
      location: (json['location'] as String?)?.trim() ?? '',
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
      color: json['color'] as String? ?? '#2196F3',
      startWeek: (json['startWeek'] as num?)?.toInt() ?? 1,
      endWeek: (json['endWeek'] as num?)?.toInt() ?? semesterWeekCount,
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
