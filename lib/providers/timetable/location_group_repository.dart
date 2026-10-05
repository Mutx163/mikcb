part of '../timetable_provider.dart';

/// 地点时间分组的四个写入口同样收进 `_mutationGate`：`_resyncAllProfilesWith
/// LocationRules` 会按「自己读到的分组」重算**每个课表**的 courses 并全量覆写
/// profiles 键，还会用那份结果反向覆盖 `_courses`/`_settings`。中途让出时门内写者
/// （updateCourse 等）刚落的盘会被这份旧口径重算结果盖掉。
///
/// 地点分组写入的收口：任一步 await 失败就把四份内存状态整体退回，并尽力把旧
/// 分组列表重新落盘（补偿），最后 rethrow。
///
/// 形状同 `_applySavedThemes`（主题族）与 `_timetableUpdateTimeScheme`（作息）。
/// 分组写成功但 `_resyncAllProfilesWithLocationRules` 失败时也必须退：否则盘上是
/// 新分组、课表钟点还是旧口径，下一次任意成功写入会把这份不一致永久坐实。
///
/// 第 27 轮从父文件移入本分片（行数棘轮的既定做法：规则放回它该在的分片，不抬基线），
/// 同时把第四个写入口 `replaceLocationTimeGroups` 也接进来 —— 它原先是唯一一个
/// 「改内存 → 裸 await 落盘 → 重算」的，传输层应用 / 教务导入 / 云快照恢复都走它。
Future<void> _commitLocationGroupChange(
  TimetableProvider host,
  List<LocationTimeGroup> previousGroups,
  Future<void> Function() write,
) async {
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  final snapshotSettings = host._settings;
  final snapshotCourses = List<Course>.from(host._courses);
  try {
    await write();
  } catch (_) {
    host._locationTimeGroups = previousGroups;
    host._profiles = snapshotProfiles;
    host._settings = snapshotSettings;
    host._courses = snapshotCourses;
    try {
      await host._persistLocationTimeGroups();
    } catch (_) {
      // 补偿失败不遮住原始错误：与 updateTimetableSettings 的旧路径同处理。
    }
    rethrow;
  }
}
