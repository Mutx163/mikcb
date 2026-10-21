import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/import_export_logic.dart';
import 'package:university_timetable/models/course.dart';

/// 导入合并时「导入侧课程 id → 本地 id」的映射（2026-10-21 立）。
///
/// 背景：`syncImportedCourses` 软匹配到已有课次后，留下的是**本地** id
/// （`mergeImportedCourseWithExisting` 里 `id: existing.id`），导入侧那个 id
/// 被丢弃。而随同一份包过来的作业仍指着导入侧 id，于是
/// `UnifiedTransferService._merge` 抛 `task_course_missing`、整次导入作废。
///
/// 这份映射就是为了让作业跟着改写过去。期望值人手推：一门同名课 → 只留本地 id。
Course _course({
  required String id,
  required String name,
  String teacher = '张老师',
  String location = 'A101',
  int dayOfWeek = 2,
  int startSection = 1,
  int endSection = 2,
}) {
  return Course(
    id: id,
    name: name,
    teacher: teacher,
    location: location,
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: '08:00',
    endTime: '09:40',
  );
}

void main() {
  group('导入 id → 本地 id 映射', () {
    test('同名课软匹配：映射指向本地 id（导入侧 id 不保留）', () {
      final result = syncImportedCourses(
        existingCourses: <Course>[_course(id: 'local-1', name: '数学')],
        importedCourses: <Course>[_course(id: 'remote-1', name: '数学')],
      );

      expect(result.mergedCourses.map((c) => c.id), <String>['local-1']);
      expect(result.importedIdToLocalId['remote-1'], 'local-1');
    });

    test('全新课程：恒等映射（id 就是导入侧那个）', () {
      final result = syncImportedCourses(
        existingCourses: <Course>[],
        importedCourses: <Course>[_course(id: 'remote-9', name: '物理')],
      );

      expect(result.mergedCourses.map((c) => c.id), <String>['remote-9']);
      expect(result.importedIdToLocalId['remote-9'], 'remote-9');
    });

    test('多门课各归各的：每一条都能解到合并后真实存在的课程', () {
      final result = syncImportedCourses(
        existingCourses: <Course>[
          _course(id: 'local-math', name: '数学'),
          _course(id: 'local-phy', name: '物理', dayOfWeek: 3),
        ],
        importedCourses: <Course>[
          _course(id: 'in-math', name: '数学'),
          _course(id: 'in-phy', name: '物理', dayOfWeek: 3),
          _course(id: 'in-chem', name: '化学', dayOfWeek: 4),
        ],
      );

      final finalIds = result.mergedCourses.map((c) => c.id).toSet();

      // 每一条导入课程的 id 都必须映射到一个确实留下的 id。
      for (final entry in result.importedIdToLocalId.entries) {
        expect(
          finalIds,
          contains(entry.value),
          reason: '导入课程 ${entry.key} 映射到了不存在的 ${entry.value}',
        );
      }
      expect(result.importedIdToLocalId['in-math'], 'local-math');
      expect(result.importedIdToLocalId['in-phy'], 'local-phy');
      expect(result.importedIdToLocalId['in-chem'], 'in-chem');
    });

    test('导入包内部重复的同名课：被去重的那条也指向幸存者', () {
      final result = syncImportedCourses(
        existingCourses: <Course>[],
        importedCourses: <Course>[
          _course(id: 'dup-a', name: '数学'),
          _course(id: 'dup-b', name: '数学'), // 除 id 外完全相同
        ],
      );

      expect(result.mergedCourses, hasLength(1));
      final survivor = result.mergedCourses.single.id;
      expect(result.importedIdToLocalId['dup-a'], survivor);
      expect(
        result.importedIdToLocalId['dup-b'],
        survivor,
        reason: '作业若指向被去重的那条，也必须落到幸存者上，不能悬空',
      );
    });

    test('一条都不匹配，且导入为空：映射为空表，不抛异常', () {
      final result = syncImportedCourses(
        existingCourses: <Course>[_course(id: 'local-1', name: '数学')],
        importedCourses: <Course>[],
      );

      expect(result.importedIdToLocalId, isEmpty);
      expect(result.addedCount, 0);
      expect(result.updatedCount, 0);
    });

    test('不传 map 的旧调用方仍能拿到空表（构造参数有默认值）', () {
      const result = ImportedCourseSyncResult(
        mergedCourses: <Course>[],
        addedCount: 0,
        updatedCount: 0,
      );

      expect(result.importedIdToLocalId, isEmpty);
    });
  });
}
