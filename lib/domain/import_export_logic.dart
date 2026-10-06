// foundation 例外说明：本文件需 @visibleForTesting 等基础注解，不涉及任何
// UI 框架；领域层纯度守卫（test/architecture/dependency_guards_test.dart）
// 只禁 widgets/material/cupertino。
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../utils/clock_time.dart';

class ImportedCourseSyncResult {
  final List<Course> mergedCourses;
  final int addedCount;
  final int updatedCount;

  const ImportedCourseSyncResult({
    required this.mergedCourses,
    required this.addedCount,
    required this.updatedCount,
  });
}

/// Pure import/export helpers extracted from [TimetableProvider].
class ImportExportLogic {
  ImportExportLogic._();

  /// Hard cap for semester week count expansion during import.
  static const int maxAllowedSemesterWeekCount = 30;

  /// 一天的分钟数；`24:00` == 1440 == 当天结束（与 `ClockTime` 的 `allowEndOfDay` 同口径）。
  static const int minutesPerDay = 24 * 60;

  static int previewImportedCourseRequiredSectionCount({
    required List<Course> importedCourses,
    required int currentSectionCount,
  }) {
    if (importedCourses.isEmpty) {
      return currentSectionCount;
    }

    return importedCourses
        .map((course) => course.endSection)
        .reduce((left, right) => left > right ? left : right);
  }

  static int maxCourseWeek(
    List<Course> courses, {
    required int fallbackWeekCount,
  }) {
    if (courses.isEmpty) {
      return fallbackWeekCount.clamp(1, maxAllowedSemesterWeekCount);
    }

    final raw = courses
        .map((course) => course.normalizedCustomWeeks?.last ?? course.endWeek)
        .reduce((left, right) => left > right ? left : right);
    return raw.clamp(1, maxAllowedSemesterWeekCount);
  }

  static List<SectionTime> buildExpandedSections(
    List<SectionTime> sections,
    int requiredSectionCount,
  ) {
    final expanded = sections.isEmpty
        ? List<SectionTime>.from(TimetableSettings.defaults().sections)
        : List<SectionTime>.from(sections);

    final defaultDuration = _inferSectionDurationMinutes(expanded);
    final defaultBreak = _inferBreakDurationMinutes(expanded);
    while (expanded.length < requiredSectionCount) {
      // 锚点必须是**能解析**的结束时间：`_parseClockToMinutes` 对畸形串返回 -1
      // （SectionTime.fromJson 只要求非空串），照 -1 当锚点就会补出
      // 「-1 + 课间 10 = 00:09」这种凌晨节次，而导入侧会按这份表
      // 烤第 3、4 节课的钟点（import_export_service.dart:171）。
      final lastEndMinutes = _lastParseableEndMinutes(expanded);
      if (lastEndMinutes == null) {
        // 一条都解析不出来时停止补节：没有可靠锚点，继续下去只能凭空编时间。
        // 剩下的节数不足由导入侧的校验与提示处理。
        break;
      }
      final nextStartMinutes = lastEndMinutes + defaultBreak;
      final nextEndMinutes = nextStartMinutes + defaultDuration;
      if (nextEndMinutes > minutesPerDay) {
        // 补不下去就停：`_formatClockMinutes` 用 `% 1440` 归一，
        // 继续补会造出"第 6 节 23:45-00:25"这种绕回凌晨的节次，
        // 而它排在已有节次之前（分钟数更小），导入侧烤出来的钟点整段错位。
        // 节数不够由导入侧的校验与提示处理（与 lastEndMinutes == null 同一处置）。
        break;
      }
      expanded.add(
        SectionTime(
          startTime: _formatClockMinutes(nextStartMinutes),
          endTime: _formatClockMinutes(nextEndMinutes),
        ),
      );
    }
    return expanded;
  }

  static int _inferSectionDurationMinutes(List<SectionTime> sections) {
    for (var index = sections.length - 1; index >= 0; index--) {
      final start = _parseClockToMinutes(sections[index].startTime);
      final end = _parseClockToMinutes(sections[index].endTime);
      final duration = end - start;
      if (duration > 0) {
        return duration;
      }
    }
    return 45;
  }

  static int _inferBreakDurationMinutes(List<SectionTime> sections) {
    if (sections.length < 2) {
      return 10;
    }

    for (var index = sections.length - 1; index > 0; index--) {
      final previousEnd = _parseClockToMinutes(sections[index - 1].endTime);
      final currentStart = _parseClockToMinutes(sections[index].startTime);
      final gap = currentStart - previousEnd;
      if (gap > 0) {
        return gap;
      }
    }
    return 10;
  }

  /// 从后往前取第一条能解析的结束时间（分钟）。全都不合法时返回 null。
  static int? _lastParseableEndMinutes(List<SectionTime> sections) {
    for (var index = sections.length - 1; index >= 0; index--) {
      final minutes = _parseClockToMinutes(sections[index].endTime);
      if (minutes >= 0) {
        return minutes;
      }
    }
    return null;
  }

  static int _parseClockToMinutes(String value) {
    // 与 lib/utils/clock_time.dart 同一份实现（这里原先自己抄了一遍 `hour > 23`，
    // 于是把本仓合法的"当天结束" `24:00` 判成非法）：`allowEndOfDay` 只额外放行
    // 恰好 `24:00`（记为 1440），`24:30`/`25:00`/`08:75` 仍一律拒绝 ——
    // 它们会被 `DateTime` 静默归一到别的日子，补出来的节次看着正常却排错时间。
    return ClockTime.tryParse(value, allowEndOfDay: true)?.totalMinutes ?? -1;
  }

  static String _formatClockMinutes(int minutes) {
    final normalized = minutes % minutesPerDay;
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

@visibleForTesting
String buildImportedCourseDedupKey(Course course) {
  final weeks = [...course.activeWeeks]..sort();
  return [
    course.name.trim().toLowerCase(),
    course.teacher.trim().toLowerCase(),
    course.location.trim().toLowerCase(),
    course.dayOfWeek.toString(),
    course.startSection.toString(),
    course.endSection.toString(),
    weeks.join(','),
  ].join('|');
}

List<Course> dedupeImportedCourses(
  List<Course> importedCourses, {
  List<Course> existingCourses = const [],
}) {
  final keys = existingCourses.map(buildImportedCourseDedupKey).toSet();
  final result = <Course>[];
  for (final course in importedCourses) {
    final key = buildImportedCourseDedupKey(course);
    if (keys.add(key)) {
      result.add(course);
    }
  }
  return result;
}

@visibleForTesting
Course mergeImportedCourseWithExisting(
  Course existing,
  Course imported, {
  bool preserveLocalColors = true,
}) {
  return imported.copyWith(
    id: existing.id,
    name: imported.name.trim().isEmpty ? existing.name : imported.name,
    teacher: imported.teacher.trim().isEmpty
        ? existing.teacher
        : imported.teacher,
    location: imported.location.trim().isEmpty
        ? existing.location
        : imported.location,
    shortName: existing.shortName,
    color: preserveLocalColors ? existing.color : imported.color,
    textColor: preserveLocalColors ? existing.textColor : imported.textColor,
    courseNature: existing.courseNature,
    description: existing.description,
    note: existing.note,
    sessionNotes: existing.sessionNotes,
    timeSchemeIdOverride: existing.timeSchemeIdOverride,
    // 停课周是用户在编辑课程页加的本地标注（运动会 / 周测），而 ICS / AI /
    // 教务解析器都不产出它 —— 只有表格导入的「停课周」列会填值。本函数以
    // imported 为基底 copyWith，不显式兜回就会把本地停课周静默清空，那周的课
    // 连同课前提醒、超级岛一起复活。导入真带得动停课周时仍以导入为准。
    suspendedWeeks: (imported.suspendedWeeks?.isNotEmpty ?? false)
        ? imported.suspendedWeeks
        : existing.suspendedWeeks,
  );
}

@visibleForTesting
Course preserveImportedCourseLocalSharedFields(
  Course existing,
  Course imported, {
  bool preserveLocalColors = true,
}) {
  return imported.copyWith(
    name: imported.name.trim().isEmpty ? existing.name : imported.name,
    teacher: imported.teacher.trim().isEmpty
        ? existing.teacher
        : imported.teacher,
    location: imported.location.trim().isEmpty
        ? existing.location
        : imported.location,
    shortName: existing.shortName,
    color: preserveLocalColors ? existing.color : imported.color,
    textColor: preserveLocalColors ? existing.textColor : imported.textColor,
    courseNature: existing.courseNature,
    description: existing.description,
    // 与 mergeImportedCourseWithExisting 同口径：覆盖导入（按名复用本地字段）
    // 同样要留住备注、每周作业、自定义钟点与停课周。漏 timeSchemeIdOverride
    // 会让课程钟点回落到全局作息模板，用户按错误的时间去教室。
    note: existing.note,
    sessionNotes: existing.sessionNotes,
    timeSchemeIdOverride: existing.timeSchemeIdOverride,
    suspendedWeeks: (imported.suspendedWeeks?.isNotEmpty ?? false)
        ? imported.suspendedWeeks
        : existing.suspendedWeeks,
  );
}

@visibleForTesting
Course mergeImportedSharedFieldsIntoExistingSchedule(
  Course existing,
  Course imported, {
  bool preserveLocalColors = true,
}) {
  return existing.copyWith(
    name: imported.name.trim().isEmpty ? existing.name : imported.name,
    teacher: imported.teacher.trim().isEmpty
        ? existing.teacher
        : imported.teacher,
    location: imported.location.trim().isEmpty
        ? existing.location
        : imported.location,
    shortName: existing.shortName,
    color: preserveLocalColors ? existing.color : imported.color,
    textColor: preserveLocalColors ? existing.textColor : imported.textColor,
    courseNature: existing.courseNature,
    description: existing.description,
    note: existing.note,
    sessionNotes: existing.sessionNotes,
    timeSchemeIdOverride: existing.timeSchemeIdOverride,
  );
}

List<Course> replaceImportedCoursesPreservingLocalFields({
  required List<Course> existingCourses,
  required List<Course> importedCourses,
  bool preserveLocalColors = true,
}) {
  final dedupedImported = dedupeImportedCourses(importedCourses);
  final existingSharedCoursesByName = <String, Course>{};
  for (final existing in existingCourses) {
    existingSharedCoursesByName.putIfAbsent(
      _buildSharedCourseNameKey(existing.name),
      () => existing,
    );
  }

  final matchedExistingIds = <String>{};
  final replacedCourses = <Course>[];

  for (final imported in dedupedImported) {
    var rebuilt = imported;
    final sharedExisting =
        existingSharedCoursesByName[_buildSharedCourseNameKey(imported.name)];
    if (sharedExisting != null) {
      rebuilt = preserveImportedCourseLocalSharedFields(
        sharedExisting,
        rebuilt,
        preserveLocalColors: preserveLocalColors,
      );
    }

    final groupedMatchIndices = _findGroupedImportedCourseMatchIndices(
      existingCourses,
      imported,
      matchedExistingIds,
    );
    if (groupedMatchIndices.isNotEmpty) {
      final existing = existingCourses[groupedMatchIndices.first];
      matchedExistingIds.addAll(
        groupedMatchIndices.map((index) => existingCourses[index].id),
      );
      rebuilt = mergeImportedCourseWithExisting(
        existing,
        rebuilt,
        preserveLocalColors: preserveLocalColors,
      );
      replacedCourses.add(rebuilt);
      continue;
    }

    var matchedIndex = _findExactImportedCourseMatchIndex(
      existingCourses,
      imported,
      matchedExistingIds,
    );
    matchedIndex = matchedIndex != -1
        ? matchedIndex
        : _findSoftImportedCourseMatchIndex(
            existingCourses,
            imported,
            matchedExistingIds,
          );

    if (matchedIndex != -1) {
      final existing = existingCourses[matchedIndex];
      matchedExistingIds.add(existing.id);
      rebuilt = mergeImportedCourseWithExisting(
        existing,
        rebuilt,
        preserveLocalColors: preserveLocalColors,
      );
    }

    replacedCourses.add(rebuilt);
  }

  return replacedCourses;
}

ImportedCourseSyncResult syncImportedCourses({
  required List<Course> existingCourses,
  required List<Course> importedCourses,
  bool preserveLocalColors = true,
}) {
  final dedupedImported = dedupeImportedCourses(importedCourses);
  final merged = List<Course>.from(existingCourses);
  final matchedExistingIds = <String>{};
  var addedCount = 0;
  var updatedCount = 0;

  for (final imported in dedupedImported) {
    final groupedMatchIndices = _findGroupedImportedCourseMatchIndices(
      merged,
      imported,
      matchedExistingIds,
    );
    if (groupedMatchIndices.isNotEmpty) {
      for (final index in groupedMatchIndices) {
        final existing = merged[index];
        matchedExistingIds.add(existing.id);
        merged[index] = mergeImportedSharedFieldsIntoExistingSchedule(
          existing,
          imported,
          preserveLocalColors: preserveLocalColors,
        );
        updatedCount += 1;
      }
      continue;
    }

    var matchedIndex = _findExactImportedCourseMatchIndex(
      merged,
      imported,
      matchedExistingIds,
    );
    matchedIndex = matchedIndex != -1
        ? matchedIndex
        : _findSoftImportedCourseMatchIndex(
            merged,
            imported,
            matchedExistingIds,
          );

    if (matchedIndex != -1) {
      final existing = merged[matchedIndex];
      matchedExistingIds.add(existing.id);
      merged[matchedIndex] = mergeImportedCourseWithExisting(
        existing,
        imported,
        preserveLocalColors: preserveLocalColors,
      );
      updatedCount += 1;
    } else {
      merged.add(imported);
      addedCount += 1;
    }
  }

  return ImportedCourseSyncResult(
    mergedCourses: merged,
    addedCount: addedCount,
    updatedCount: updatedCount,
  );
}

bool courseListsEqual(List<Course> left, List<Course> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index].toJsonString() != right[index].toJsonString()) {
      return false;
    }
  }
  return true;
}

String _buildSharedCourseNameKey(String name) => name.trim().toLowerCase();

int _findExactImportedCourseMatchIndex(
  List<Course> existingCourses,
  Course imported,
  Set<String> matchedExistingIds,
) {
  final importedKey = _buildImportedCourseExactMatchKey(imported);
  for (var index = 0; index < existingCourses.length; index++) {
    final existing = existingCourses[index];
    if (matchedExistingIds.contains(existing.id)) {
      continue;
    }
    if (_buildImportedCourseExactMatchKey(existing) == importedKey) {
      return index;
    }
  }
  return -1;
}

int _findSoftImportedCourseMatchIndex(
  List<Course> existingCourses,
  Course imported,
  Set<String> matchedExistingIds,
) {
  var bestIndex = -1;
  var bestScore = 0.0;
  for (var index = 0; index < existingCourses.length; index++) {
    final existing = existingCourses[index];
    if (matchedExistingIds.contains(existing.id)) {
      continue;
    }
    if (existing.name.trim().toLowerCase() !=
        imported.name.trim().toLowerCase()) {
      continue;
    }
    // Require same weekday so multi-slot same-name courses are not merged.
    if (existing.dayOfWeek != imported.dayOfWeek) {
      continue;
    }
    if (existing.sectionCount != imported.sectionCount) {
      continue;
    }
    final overlapScore = _weekOverlapScore(
      existing.activeWeeks,
      imported.activeWeeks,
    );
    if (overlapScore < 0.5) {
      continue;
    }
    final teacherBonus =
        existing.teacher.trim().isNotEmpty &&
            imported.teacher.trim().isNotEmpty &&
            existing.teacher.trim().toLowerCase() ==
                imported.teacher.trim().toLowerCase()
        ? 0.2
        : 0.0;
    final locationBonus =
        existing.location.trim().isNotEmpty &&
            imported.location.trim().isNotEmpty &&
            existing.location.trim().toLowerCase() ==
                imported.location.trim().toLowerCase()
        ? 0.1
        : 0.0;
    final score = overlapScore + teacherBonus + locationBonus;
    if (score > bestScore) {
      bestScore = score;
      bestIndex = index;
    }
  }
  return bestIndex;
}

String _buildImportedCourseExactMatchKey(Course course) {
  final weeks = [...course.activeWeeks]..sort();
  return [
    course.name.trim().toLowerCase(),
    course.dayOfWeek.toString(),
    course.startSection.toString(),
    course.endSection.toString(),
    weeks.join(','),
  ].join('|');
}

List<int> _findGroupedImportedCourseMatchIndices(
  List<Course> existingCourses,
  Course imported,
  Set<String> matchedExistingIds,
) {
  final importedWeeks = {...imported.activeWeeks}
    ..removeWhere((week) => week < 1);
  if (importedWeeks.isEmpty) {
    return const <int>[];
  }
  final indices = <int>[];
  final coveredWeeks = <int>{};
  for (var index = 0; index < existingCourses.length; index++) {
    final existing = existingCourses[index];
    if (matchedExistingIds.contains(existing.id)) {
      continue;
    }
    if (!_hasSameStructuralKey(existing, imported)) {
      continue;
    }
    final existingWeeks = {...existing.activeWeeks}
      ..removeWhere((week) => week < 1);
    if (existingWeeks.isEmpty) {
      continue;
    }
    if (!importedWeeks.containsAll(existingWeeks)) {
      continue;
    }
    indices.add(index);
    coveredWeeks.addAll(existingWeeks);
  }
  if (indices.length <= 1) {
    return const <int>[];
  }
  if (coveredWeeks.length != importedWeeks.length ||
      !coveredWeeks.containsAll(importedWeeks)) {
    return const <int>[];
  }
  return indices;
}

bool _hasSameStructuralKey(Course left, Course right) {
  return left.name.trim().toLowerCase() == right.name.trim().toLowerCase() &&
      left.dayOfWeek == right.dayOfWeek &&
      left.startSection == right.startSection &&
      left.endSection == right.endSection;
}

double _weekOverlapScore(List<int> left, List<int> right) {
  if (left.isEmpty || right.isEmpty) {
    return 0;
  }
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  final intersection = leftSet.intersection(rightSet).length;
  final base = leftSet.length > rightSet.length
      ? leftSet.length
      : rightSet.length;
  return base == 0 ? 0 : intersection / base;
}
