import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 课程组的整组写操作在落盘失败时必须退回（2026-10-05 审查）。
///
/// 本仓的写入纪律是「先抓旧值 → await 落库 → catch 里回滚并 rethrow」，已经逐族收口：
/// 主题族 `_applySavedThemes`、地点分组族 `_commitLocationGroupChange`、作息族
/// `_timetableCreateTimeScheme` / `_timetableApplyTimeScheme`、`deleteProfile`、
/// 日期规则族（本轮上一批）。这条纪律的判据是「内存里被改掉的东西**是不是用户刚刚
/// 亲口确认的那一条**」：
///
/// - 单条 `addCourse` 失败时不回滚是可以辩护的 —— 内存里那条就是用户填的内容，
///   表单自己已经弹了「保存失败」，把整张表单清空才是更糟的体验；
/// - 但 `deleteCourseGroup` / `updateCourseGroup` 会连带改**别的记录**：删除整组时
///   一并摘掉这组课的考试与作业（`_exams.removeWhere` / `_tasks.removeWhere`），
///   而用户点的是"删课程"，不是"删我的考试"。这两处当时都没有 try/catch，
///   `_persistActiveProfileState()` 开头还会 `_mergeActiveProfileIntoProfilesList()`
///   把课程/考试/作业并进 `_profiles`，于是抛错之后内存里连 profile 镜像都是删过的
///   状态，而下一次任意成功写入（加课、切周、心跳）会把「整组没了 + 考试没了 +
///   作业没了」坐实到盘上 —— 用户视角是"删除失败的那门课，连同我记在它下面的期中考试，
///   过几天一起消失了"。
class _FailingStorage extends StorageService {
  _FailingStorage() : super.forTesting();

  int profilesFailures = 0;

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) {
    if (profilesFailures > 0) {
      profilesFailures--;
      return Future<void>.error(StateError('test_profiles_write_failed'));
    }
    return super.saveProfiles(profiles);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FailingStorage storage;
  late TimetableProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = _FailingStorage();
    provider = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
  });

  tearDown(() {
    provider.dispose();
  });

  Course lesson(String id, int day) => Course(
    id: id,
    name: '高等数学',
    teacher: '王老师',
    location: 'A101',
    dayOfWeek: day,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  /// 一组两次的课 + 记在第一课次上的作业与考试。
  Future<void> seedGroup() async {
    await provider.addCourse(lesson('g1', 1));
    await provider.addCourse(lesson('g2', 3));
    await provider.addTask(
      CourseTask(
        id: 't1',
        title: '第一章作业',
        courseId: 'g1',
        dueDate: DateTime.now().add(const Duration(days: 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await provider.addExam(
      Exam(
        id: 'e1',
        courseId: 'g1',
        name: '高等数学期中',
        dateTime: DateTime.now().add(const Duration(days: 20)),
        startTime: '09:00',
        endTime: '11:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  group('课程组写操作的落盘失败回滚', () {
    test('deleteCourseGroup 写盘失败后整组课程与它的考试作业都要还在', () async {
      await seedGroup();
      expect(provider.courses, hasLength(2));
      expect(provider.tasks.map((task) => task.id), contains('t1'));
      expect(provider.exams.map((exam) => exam.id), contains('e1'));

      storage.profilesFailures = 1;
      await expectLater(
        provider.deleteCourseGroup('高等数学'),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.courses.map((course) => course.id),
        containsAll(<String>['g1', 'g2']),
        reason: '删除没落成功就不该在内存里生效',
      );
      expect(
        provider.exams.map((exam) => exam.id),
        contains('e1'),
        reason: '用户点的是删课程，考试是被连带删的，失败后必须回来',
      );
      expect(
        provider.tasks.map((task) => task.id),
        contains('t1'),
        reason: '作业同理',
      );

      // 幻影只有被下一次成功写入坐实才算真的丢数据。
      await provider.addCourse(lesson('other', 5));
      final diskProfile = (await storage.getProfiles()).firstWhere(
        (profile) => profile.id == provider.activeProfile!.id,
      );
      expect(
        diskProfile.courses.map((course) => course.id),
        containsAll(<String>['g1', 'g2']),
      );
      expect(diskProfile.exams.map((exam) => exam.id), contains('e1'));
      expect(diskProfile.tasks.map((task) => task.id), contains('t1'));
    });

    test('updateCourseGroup 写盘失败后原组与被剪掉的作业都要回来', () async {
      await seedGroup();

      storage.profilesFailures = 1;
      // 换一批 id 等于「旧课次整组摘掉 + 新课次加上」，顺带触发孤儿作业剪除。
      await expectLater(
        provider.updateCourseGroup('高等数学', [
          lesson('g1n', 2),
          lesson('g2n', 4),
        ]),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.courses.map((course) => course.id),
        containsAll(<String>['g1', 'g2']),
      );
      expect(
        provider.courses.map((course) => course.id),
        isNot(contains('g1n')),
      );
      expect(
        provider.tasks.map((task) => task.id),
        contains('t1'),
        reason: '孤儿作业剪除跟着整组替换一起失败，必须一起退回',
      );

      await provider.addCourse(lesson('other', 6));
      final diskProfile = (await storage.getProfiles()).firstWhere(
        (profile) => profile.id == provider.activeProfile!.id,
      );
      expect(
        diskProfile.courses.map((course) => course.id),
        containsAll(<String>['g1', 'g2']),
      );
      expect(diskProfile.tasks.map((task) => task.id), contains('t1'));
    });

    test('对照：写盘成功时整组删除确实把课程与考试作业一起摘掉', () async {
      await seedGroup();

      await provider.deleteCourseGroup('高等数学');

      expect(provider.courses, isEmpty);
      expect(provider.exams, isEmpty);
      expect(
        provider.tasks.where((task) => task.id == 't1'),
        isEmpty,
        reason: '回滚不能把正常路径也变成"什么都没删"',
      );
      final diskProfile = (await storage.getProfiles()).firstWhere(
        (profile) => profile.id == provider.activeProfile!.id,
      );
      expect(diskProfile.courses, isEmpty);
      expect(diskProfile.exams, isEmpty);
    });
  });
}
