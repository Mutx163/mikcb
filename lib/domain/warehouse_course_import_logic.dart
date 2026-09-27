import 'package:university_timetable/domain/import_export_logic.dart';
import 'package:university_timetable/models/course.dart';

/// Pure parser for 教务适配脚本下发的课程数组（`saveImportedCourses` 的入参）。
///
/// Why this exists: the warehouse protocol lets an adapter attach a real clock
/// range to a course via `isCustomTime` / `customStartTime` / `customEndTime`.
/// Such records frequently carry **no** `startSection` / `endSection` at all —
/// 早读、实验连堂等不对应编号节次的时段就是这种形状。The previous inline parser
/// required both section fields and silently dropped anything missing them, so
/// those courses simply never appeared on the timetable.
///
/// Extracted as a pure function so this behaviour is directly testable; the
/// widget used to own it inline.
class WarehouseCourseImportLogic {
  const WarehouseCourseImportLogic._();

  /// Normalizes an adapter-supplied `HH:mm` clock value, or null when unusable.
  ///
  /// Tolerates `H:mm`, surrounding whitespace and a trailing `:ss` from
  /// adapters that serialize a `DateTime`; rejects out-of-range values so a
  /// malformed clock can never be persisted.
  static String? normalizeClock(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  /// Parses [rawCourses] into [Course]s, skipping unusable records.
  ///
  /// [idFactory] keeps this pure w.r.t. identity so callers control ids.
  /// [unknownTeacher] / [unknownLocation] supply the placeholders the widget
  /// would otherwise pull from localisation.
  static List<Course> parse(
    List<dynamic> rawCourses, {
    required String Function() idFactory,
    required String unknownTeacher,
    required String unknownLocation,
    int maxWeek = ImportExportLogic.maxAllowedSemesterWeekCount,
  }) {
    final courses = <Course>[];
    for (final item in rawCourses) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
      final name = (map['name'] as String? ?? '').trim();
      final teacher = (map['teacher'] as String? ?? '').trim();
      final location =
          (map['position'] as String? ?? map['location'] as String? ?? '')
              .trim();
      final day = (map['day'] as num?)?.toInt();
      final startSection = (map['startSection'] as num?)?.toInt();
      final endSection = (map['endSection'] as num?)?.toInt();
      final weeks =
          (map['weeks'] as List<dynamic>?)
              ?.map((item) => (item as num).toInt())
              .where((item) => item > 0 && item <= maxWeek)
              .toSet()
              .toList()
            ?..sort();

      final customStart = normalizeClock(map['customStartTime']);
      final customEnd = normalizeClock(map['customEndTime']);
      // `isCustomTime` absent → infer from the presence of a usable clock pair,
      // so adapters that only send the times still work.
      final hasCustomTime =
          ((map['isCustomTime'] as bool?) ??
                  (customStart != null && customEnd != null)) &&
          customStart != null &&
          customEnd != null;

      // No section but a real clock range (早读 etc.): seat it in section 1 so
      // the record survives; the pinned clock drives display and alarms.
      final effectiveStartSection = startSection ?? (hasCustomTime ? 1 : null);
      final effectiveEndSection = endSection ?? effectiveStartSection;

      if (name.isEmpty ||
          day == null ||
          effectiveStartSection == null ||
          effectiveEndSection == null ||
          weeks == null ||
          weeks.isEmpty) {
        continue;
      }
      final sections = Course.normalizeSections(
        startSection: effectiveStartSection,
        endSection: effectiveEndSection,
      );
      courses.add(
        Course(
          id: idFactory(),
          name: name,
          teacher: teacher.isEmpty ? unknownTeacher : teacher,
          location: location.isEmpty ? unknownLocation : location,
          dayOfWeek: Course.normalizeDayOfWeek(day),
          startSection: sections.startSection,
          endSection: sections.endSection,
          startWeek: weeks.first,
          endWeek: weeks.last,
          startTime: hasCustomTime ? customStart : '',
          endTime: hasCustomTime ? customEnd : '',
          hasCustomTime: hasCustomTime,
          customWeeks: weeks,
        ),
      );
    }
    return courses;
  }
}
