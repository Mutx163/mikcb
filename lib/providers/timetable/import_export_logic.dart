import 'package:flutter/foundation.dart';
import '../../models/course.dart';
import '../../models/timetable_settings.dart';

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
      return fallbackWeekCount;
    }

    return courses
        .map((course) => course.normalizedCustomWeeks?.last ?? course.endWeek)
        .reduce((left, right) => left > right ? left : right);
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
      final last = expanded.last;
      final lastEndMinutes = _parseClockToMinutes(last.endTime);
      final nextStartMinutes = lastEndMinutes + defaultBreak;
      final nextEndMinutes = nextStartMinutes + defaultDuration;
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

  static int _parseClockToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return -1;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return -1;
    }
    return hour * 60 + minute;
  }

  static String _formatClockMinutes(int minutes) {
    final normalized = minutes % (24 * 60);
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
Course mergeImportedCourseWithExisting(Course existing, Course imported) {
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
    color: existing.color,
    courseNature: existing.courseNature,
    description: existing.description,
    note: existing.note,
    timeSchemeIdOverride: existing.timeSchemeIdOverride,
  );
}

@visibleForTesting
Course preserveImportedCourseLocalSharedFields(
  Course existing,
  Course imported,
) {
  return imported.copyWith(
    name: imported.name.trim().isEmpty ? existing.name : imported.name,
    teacher: imported.teacher.trim().isEmpty
        ? existing.teacher
        : imported.teacher,
    location: imported.location.trim().isEmpty
        ? existing.location
        : imported.location,
    shortName: existing.shortName,
    color: existing.color,
    courseNature: existing.courseNature,
    description: existing.description,
  );
}

@visibleForTesting
Course mergeImportedSharedFieldsIntoExistingSchedule(
  Course existing,
  Course imported,
) {
  return existing.copyWith(
    name: imported.name.trim().isEmpty ? existing.name : imported.name,
    teacher: imported.teacher.trim().isEmpty
        ? existing.teacher
        : imported.teacher,
    location: imported.location.trim().isEmpty
        ? existing.location
        : imported.location,
    shortName: existing.shortName,
    color: existing.color,
    courseNature: existing.courseNature,
    description: existing.description,
    note: existing.note,
    timeSchemeIdOverride: existing.timeSchemeIdOverride,
  );
}

List<Course> replaceImportedCoursesPreservingLocalFields({
  required List<Course> existingCourses,
  required List<Course> importedCourses,
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
      rebuilt = mergeImportedCourseWithExisting(existing, rebuilt);
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
      rebuilt = mergeImportedCourseWithExisting(existing, rebuilt);
    }

    replacedCourses.add(rebuilt);
  }

  return replacedCourses;
}

@visibleForTesting
ImportedCourseSyncResult syncImportedCourses({
  required List<Course> existingCourses,
  required List<Course> importedCourses,
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
