import '../models/course.dart';

/// Data and mutation surface used by the LAN edit HTTP API.
abstract class LanEditHost {
  Future<void> ensureInitialized();

  String? get activeProfileName;

  int get currentWeek;

  int get semesterWeekCount;

  List<Course> get courses;

  Course? findCourse(String id);

  Future<Course> createCourse(Course draft);

  Future<void> updateCourse(Course course);

  Future<void> deleteCourse(String courseId);

  /// Atomically replaces a course group's schedule entries, or creates a new group.
  Future<List<Course>> replaceCourseGroup({
    required String? originalName,
    required List<Course> slots,
  });

  String buildProfileBackupJson();

  Future<void> importProfileBackupJson(String content);

  Map<String, dynamic> buildMetaJson();
}
