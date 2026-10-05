import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 「清空当前课表」落盘失败时必须整体退回（2026-10-05 审查）。
///
/// `_clearActiveProfileCoursesImpl`（timetable_provider.dart:3821-3839）是本族**影响面最大**
/// 的写入口：`_courses = []` 把整份课表清空，再 `_tasks.removeWhere((task) => task.courseId != null)`
/// 顺手摘掉所有挂在课程上的作业，然后 `await _persistActiveProfileState()` —— 没有 try/catch。
/// 抛错之后：
/// - 内存：课表空、作业空、`_profiles` 里的镜像也被 `_mergeActiveProfileIntoProfilesList()`
///   改成空的（该方法开头就合并）；
/// - 盘上：还是满的；
/// - 调用方 `timetable_profiles_screen.dart:204-216` 没有任何 try/catch，异常直接飞出
///   async 处理函数 —— 成功提示「已清空 X」不会出现，**失败提示也没有**，用户看到的只是
///   "点了没反应"；
/// - 而下一次任意成功写入（加课、切周、30 秒一次的 `syncTemporalContext` 心跳）会把
///   「整份课表没了 + 全部课程作业没了」永久坐实到盘上。
///
/// 也就是说：一次没落成功的"清空"会延迟成真，而且用户从来没第二次确认过它。
class _FailingStorage extends StorageService {
  _FailingStorage() : super.forTesting();

  int profilesFailures = 0;
  int profilesWrites = 0;

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) {
    profilesWrites++;
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
    name: '大学英语$id',
    teacher: '李老师',
    location: 'B201',
    dayOfWeek: day,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  CourseTask task(String id, {String? courseId}) => CourseTask(
    id: id,
    title: '任务$id',
    courseId: courseId,
    dueDate: DateTime.now().add(const Duration(days: 2)),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Future<void> seed() async {
    await provider.addCourse(lesson('c1', 1));
    await provider.addCourse(lesson('c2', 3));
    await provider.addTask(task('linked', courseId: 'c1'));
    await provider.addTask(task('free'));
  }

  group('清空课表的落盘失败回滚', () {
    test('落盘失败后整份课表与挂在课程上的作业都要还在', () async {
      await seed();
      expect(provider.courses, hasLength(2));

      storage.profilesFailures = 1;
      await expectLater(
        provider.clearActiveProfileCourses(),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.courses.map((course) => course.id),
        containsAll(<String>['c1', 'c2']),
        reason: '清空没落成功就不该在内存里生效：调用方什么提示都没给',
      );
      expect(
        provider.tasks.map((item) => item.id),
        contains('linked'),
        reason: '挂在课程上的作业是被连带清掉的，用户没确认过它',
      );
      expect(provider.tasks.map((item) => item.id), contains('free'));

      // 幻影只有被下一次成功写入坐实才算真的丢数据。
      await provider.addTask(task('later'));
      final disk = (await storage.getProfiles()).firstWhere(
        (profile) => profile.id == provider.activeProfile!.id,
      );
      expect(
        disk.courses.map((course) => course.id),
        containsAll(<String>['c1', 'c2']),
      );
      expect(disk.tasks.map((item) => item.id), contains('linked'));
    });

    test('对照：落盘成功时清空课程与课程作业，但保留不挂课程的作业', () async {
      await seed();

      final cleared = await provider.clearActiveProfileCourses();

      expect(cleared, isTrue);
      expect(provider.courses, isEmpty);
      expect(
        provider.tasks.map((item) => item.id),
        isNot(contains('linked')),
      );
      expect(provider.tasks.map((item) => item.id), contains('free'));
      final disk = (await storage.getProfiles()).firstWhere(
        (profile) => profile.id == provider.activeProfile!.id,
      );
      expect(disk.courses, isEmpty);
    });

    test('课表本来就是空时返回 false，且什么都不动', () async {
      final idsBefore = provider.tasks.map((item) => item.id).toList();

      expect(await provider.clearActiveProfileCourses(), isFalse);
      // 这里不断言"一次写盘都没发生"：本类有 30 秒一次的 temporal 心跳与小组件快照
      // 之类后台写，测到的写次数不是这条用例的判据。守卫要看的是"没动手"。
      expect(provider.courses, isEmpty);
      expect(provider.tasks.map((item) => item.id).toList(), idsBefore);
    });
  });
}
