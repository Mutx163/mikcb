import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/transfer_package.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/unified_transfer_service.dart';

/// 「本周课表」导出必须把附属数据一起收窄（回归钉，2026-10-02）。
///
/// `buildCurrentPackage` 里课程按 `isActiveInWeek(currentWeek)` 过滤，但任务与考试
/// 走的是「只要不是 selectedCourses/selectedCourse 就全带」分支，`weekTimetable`
/// 被漏在外面。于是包里有考试/任务指向**没被打包的那门课**：
/// 接收端 `_diffService.validate` 判 `exam_course_missing` 为 error，整单导入被拒 ——
/// 「分享本周课表」这个入口直接不可用；若接收端恰好有同 id 的课，还会把包外数据导进去。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TimetableProvider> booted() async {
    SharedPreferences.setMockInitialValues({});
    // 每个用例一套独立的存储：StorageService 是带内存缓存的单例，只重置
    // SharedPreferences 会让上一个用例的课程留在缓存里（表现为 id 重复、
    // 以及本周包莫名其妙含住别的用例加过的课）。
    final provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: DateTime(2026, 9, 7),
        semesterWeekCount: 16,
      ),
    );
    await provider.setCurrentWeek(2);
    return provider;
  }

  Course weekCourse({required String id, required int week, String? location}) {
    return Course(
      id: id,
      name: '课程$id',
      teacher: '张老师',
      location: location ?? 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      startWeek: week,
      endWeek: week,
    );
  }

  test('本周包里带上本周课程自身的考试与任务', () async {
    final provider = await booted();
    addTearDown(provider.dispose);

    await provider.addCourse(weekCourse(id: 'c2', week: 2));
    await provider.addExam(
      Exam(
        id: 'e2',
        courseId: 'c2',
        name: '期中考试',
        dateTime: DateTime(2026, 11, 2),
        startTime: '09:00',
        endTime: '11:00',
        location: 'A101',
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 9),
      ),
    );
    await provider.addTask(
      CourseTask(
        id: 't2',
        courseId: 'c2',
        title: '复习',
        dueDate: DateTime(2026, 10, 30),
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 9),
      ),
    );

    final pack = UnifiedTransferService().buildCurrentPackage(
      provider: provider,
      scope: TransferScope.weekTimetable,
    );

    expect(pack.courses.map((item) => item.id), ['c2']);
    expect(pack.exams.map((item) => item.id), ['e2']);
    expect(pack.tasks.map((item) => item.id), ['t2']);
  });

  test('别周课程的考试与任务不进本周包', () async {
    final provider = await booted();
    addTearDown(provider.dispose);

    // c4 只在第 4 周，当前第 2 周 → 课程被过滤掉，它的考试/任务也必须跟着消失。
    await provider.addCourse(weekCourse(id: 'c4', week: 4));
    await provider.addExam(
      Exam(
        id: 'e4',
        courseId: 'c4',
        name: '期末',
        dateTime: DateTime(2026, 12, 20),
        startTime: '14:00',
        endTime: '16:00',
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 9),
      ),
    );
    await provider.addTask(
      CourseTask(
        id: 't4',
        courseId: 'c4',
        title: '作业',
        dueDate: DateTime(2026, 10, 20),
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 9),
      ),
    );
    // 独立任务（不绑课）与日程不受影响，必须继续打包。
    await provider.addTask(
      CourseTask(
        id: 't-free',
        title: '交水电费',
        dueDate: DateTime(2026, 10, 9),
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 9),
      ),
    );

    final pack = UnifiedTransferService().buildCurrentPackage(
      provider: provider,
      scope: TransferScope.weekTimetable,
    );

    expect(pack.courses, isEmpty);
    expect(
      pack.exams,
      isEmpty,
      reason: '包里没有 c4，带 e4 会让接收端判 exam_course_missing 而整单拒收',
    );
    expect(pack.tasks.map((item) => item.id), ['t-free']);
  });

  test('整表导出仍然带全部考试与任务', () async {
    final provider = await booted();
    addTearDown(provider.dispose);

    await provider.addCourse(weekCourse(id: 'c4', week: 4));
    await provider.addExam(
      Exam(
        id: 'e4',
        courseId: 'c4',
        name: '期末',
        dateTime: DateTime(2026, 12, 20),
        startTime: '14:00',
        endTime: '16:00',
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 9),
      ),
    );

    final pack = UnifiedTransferService().buildCurrentPackage(
      provider: provider,
      scope: TransferScope.currentTimetable,
    );

    expect(pack.courses.map((item) => item.id), ['c4']);
    expect(pack.exams.map((item) => item.id), ['e4']);
  });
}
