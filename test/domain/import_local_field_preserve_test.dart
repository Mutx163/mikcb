import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/import_export_logic.dart';
import 'package:university_timetable/models/course.dart';

/// 回归钉（2026-10-02 审查第 6 轮，导入合并的本地字段保留）：
///
/// 「更新课表」逐条走 `mergeImportedCourseWithExisting`，它以 `imported` 为基底
/// copyWith，把 shortName/color/courseNature/description/note/sessionNotes/
/// timeSchemeIdOverride 都从 existing 保住了，唯独漏了 `suspendedWeeks`。
/// 而 ICS / AI / 教务解析器都不产出停课周（只有表格导入的「停课周」列会解析，
/// `spreadsheet_import_service.dart:534`），所以导入侧该字段恒为 null ——
/// 用户在编辑课程页设的停课周（运动会、周测）被下一次更新导入静默清空，
/// 那周的课重新出现在课表上，课前提醒与超级岛跟着复活。
///
/// 同文件另一条路径 `mergeImportedSharedFieldsIntoExistingSchedule` 以
/// `existing` 为基底，停课周天然保住；「按名复用本地字段」的
/// `preserveImportedCourseLocalSharedFields`（覆盖导入用）又反过来漏了
/// note / sessionNotes / timeSchemeIdOverride。同一件事三处三种口径，
/// 用户看到的是「同一次导入里，改过节次的课备注还在，没改的反而没了」。
void main() {
  Course course(
    String id, {
    String name = '高等数学',
    int dayOfWeek = 1,
    int startSection = 1,
    int endSection = 2,
    List<int>? suspendedWeeks,
    String? note,
    Map<int, CourseSessionNote>? sessionNotes,
    String? timeSchemeIdOverride,
  }) => Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: '08:00',
    endTime: '09:40',
    suspendedWeeks: suspendedWeeks,
    note: note,
    sessionNotes: sessionNotes,
    timeSchemeIdOverride: timeSchemeIdOverride,
  );

  group('更新课表（syncImportedCourses）保留本地停课周', () {
    test('导入不含停课周时，本地停课周不被抹掉', () {
      final existing = course('c1', suspendedWeeks: [5, 9]);
      final imported = course('imported-1');

      final merged = mergeImportedCourseWithExisting(existing, imported);

      // 修复前：基底是 imported，suspendedWeeks 落成 null。
      expect(merged.suspendedWeeks, [5, 9]);
      expect(merged.isSuspendedInWeek(5), isTrue);
    });

    test('导入自带停课周时以导入为准（表格导入的停课周列要生效）', () {
      final existing = course('c1', suspendedWeeks: [5]);
      final imported = course('imported-1', suspendedWeeks: [7, 11]);

      final merged = mergeImportedCourseWithExisting(existing, imported);

      expect(merged.suspendedWeeks, [7, 11]);
    });

    test('整条 syncImportedCourses 链路同样保住停课周', () {
      final existing = course('c1', suspendedWeeks: [5]);
      final result = syncImportedCourses(
        existingCourses: [existing],
        importedCourses: [course('imported-1')],
      );

      expect(result.mergedCourses, hasLength(1));
      expect(result.mergedCourses.single.id, 'c1');
      expect(result.mergedCourses.single.suspendedWeeks, [5]);
    });
  });

  group('覆盖课表（按名复用本地字段）保留备注与自定义时间', () {
    test('note / sessionNotes / timeSchemeIdOverride 都从本地继承', () {
      final existing = course(
        'c1',
        note: '这周要交论文',
        sessionNotes: const {
          3: CourseSessionNote(text: '第 3 周作业：习题 12', hasHomework: true),
        },
        timeSchemeIdOverride: 'scheme-night',
      );
      final imported = course('imported-1', dayOfWeek: 3, startSection: 5);

      final merged = preserveImportedCourseLocalSharedFields(
        existing,
        imported,
      );

      expect(merged.note, '这周要交论文');
      expect(merged.sessionNotes, existing.sessionNotes);
      expect(merged.timeSchemeIdOverride, 'scheme-night');
    });

    test('本地停课周在覆盖导入里也不丢', () {
      final existing = course('c1', suspendedWeeks: [6]);
      final imported = course('imported-1');

      final merged = preserveImportedCourseLocalSharedFields(
        existing,
        imported,
      );

      expect(merged.suspendedWeeks, [6]);
    });
  });
}
