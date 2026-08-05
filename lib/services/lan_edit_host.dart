import '../models/course.dart';
import '../models/timetable_settings.dart';
import 'spreadsheet_import_service.dart';
import 'transfer_diff_service.dart';
import 'transfer_package.dart';
import 'unified_transfer_service.dart';

/// Data and mutation surface used by the LAN edit HTTP API.
abstract class LanEditHost {
  Future<void> ensureInitialized();

  String? get activeProfileId;

  String? get activeProfileName;

  /// Switchable timetable profiles (excludes partner-imported).
  ///
  /// Each map includes: `id`, `name`, `courseCount`, `currentWeek`, `isActive`.
  List<Map<String, dynamic>> listProfilesSummary();

  /// Switches the active profile. Throws [ArgumentError] when the id is
  /// missing or not switchable (e.g. partner-imported).
  Future<void> switchProfile(String profileId);

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

/// Optional migration capability implemented by the real provider host.
/// Keeping it separate preserves lightweight LAN test hosts and legacy
/// adapters that only implement course editing.
abstract interface class LanTransferHost {
  LanTransferPreview? previewTransferJson(String content);

  Future<TransferApplyResult> applyTransferJson(
    String content, {
    required TransferApplyMode mode,
  });
}

class LanTransferPreview {
  final TransferPackage incoming;
  final TransferDiff mergeDiff;
  final TransferDiff overwriteDiff;

  const LanTransferPreview({
    required this.incoming,
    required this.mergeDiff,
    required this.overwriteDiff,
  });

  /// Backwards-compatible shorthand for callers that only render one summary.
  TransferDiff get diff => overwriteDiff;

  Map<String, dynamic> toJson() => {
    'transferId': incoming.packageId,
    'channel': incoming.channel.value,
    'scope': incoming.scope.value,
    'mergeDiff': mergeDiff.toJson(),
    'overwriteDiff': overwriteDiff.toJson(),
    'diff': overwriteDiff.toJson(),
  };
}
