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

  /// 锁内读-改-写：PATCH 这类"先读基线、再把整份记录覆盖回去"的入口必须用它。
  ///
  /// HTTP 侧从 `findCourse` 到写入之间至少有两个真实 await（读请求体，最长 20 秒
  /// 预算；以及课表目标检查）。在那段窗口里本机（手机编辑页、导入、云同步）改了
  /// 同一门课，就会被"过期基线 + 整份覆盖"静默抹掉，而 HTTP 还回 200 并把请求体
  /// 原样回显 —— 网页显示"已保存"，手机上那次改动凭空消失。
  /// 回调只负责**算出新值**，读基线与写入都由宿主在同一次持锁里完成；
  /// 返回 null 表示这条记录已经不在了（回调不会执行）。
  Future<Course?> mutateCourse(
    String courseId,
    Future<Course> Function(Course existing) mutate,
  );

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
