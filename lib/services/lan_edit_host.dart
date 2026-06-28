import '../models/course.dart';
import '../models/timetable_settings.dart';
import 'spreadsheet_import_service.dart';

/// Data and mutation surface used by the LAN edit HTTP API.
abstract class LanEditHost {
  Future<void> ensureInitialized();

  String? get activeProfileName;

  int get currentWeek;

  TimetableSettings get timetableSettings;

  int get semesterWeekCount;

  List<Course> get courses;

  Course? findCourse(String id);

  Future<Course> createCourse(Course draft);

  Future<void> updateCourse(Course course);

  Future<void> deleteCourse(String courseId);

  /// Deletes multiple courses by id; returns number removed.
  Future<int> deleteCoursesBatch(List<String> courseIds);

  /// Atomically replaces a course group's schedule entries, or creates a new group.
  Future<List<Course>> replaceCourseGroup({
    required String? originalName,
    required List<Course> slots,
  });

  String buildProfileBackupJson();

  Future<void> importProfileBackupJson(String content);

  /// Merges courses from a backup JSON into the active profile (non-destructive).
  Future<int> importMergeBackupJson(String content);

  /// Imports parsed spreadsheet rows into the active profile.
  Future<int> importSpreadsheetCourses(
    SpreadsheetImportResult result, {
    required bool replaceExisting,
  });

  Future<void> setCurrentWeek(int week);

  Map<String, dynamic> buildMetaJson();
}
