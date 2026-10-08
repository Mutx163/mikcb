import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 单条课程的写入口在落盘失败时的退回边界（2026-10-05 审查）。
///
/// 与 `course_group_repository.dart` 开头那条判据一致 —— **内存里被改掉的是不是用户
/// 刚刚亲口确认的那一条**：
///
/// - `deleteCourse`（原 timetable_provider.dart:2576-2591）除了摘掉这门课，还会
///   `_exams.removeWhere` / `_tasks.removeWhere` 连带摘掉记在它名下的考试与作业，
///   然后 `await _persistActiveProfileState()`，没有 try/catch。用户确认的是"删这门课"，
///   期中考试与那条作业不是他要删的东西；落盘一失败（磁盘满、`commit()` 返回 false）
///   就是内存删干净、盘上没删，而下一次任意成功写入会把它们永久坐实成"已删除"。
/// - `updateCourse`（原 :2517-2574）会把改动的共享字段**广播给同组其它课次**
///   （:2542-2554 的 `applySharedFields` 循环），还会顺带 `_syncHomeworkTasksWithCourses`；
///   落盘失败时被改的"别人的记录"停在改动后的状态，下一次成功写入把它们一起坐实。
/// - `addCourse` / `addCourseGroup` 失败时**不回滚**是刻意的：内存里那些正是用户刚填的
///   内容，表单已经报了「保存失败」，回滚等于把整张表单清空，是更糟的体验。
///   下面最后一条用例把这个边界钉住，免得后来人以为是漏了一处。
class _FailingStorage extends StorageService {
  _FailingStorage() : super.forTesting();

  int profilesFailures = 0;
  int profilesWrites = 0;

  /// 教师/地点名册的写盘失败注入（2026-10-07 新增）。
  ///
  /// 这两条不是装饰：`updateCourse` / `updateCourseGroup` 里的
  /// `_recordTeacherImpl` / `_recordLocationImpl` 各自 `await` 一次名册落盘，
  /// 而保护区原先从它们**之后**才开始（见
  /// `course_repository.dart` 函数体顶部那条注）。名册写盘失败时课程已被替换、
  /// 共享字段已广播，三份快照一份都不退。
  int teacherFailures = 0;
  int locationFailures = 0;

  @override
  Future<void> saveTeacherRecords(List<String> teachers) {
    if (teacherFailures > 0) {
      teacherFailures--;
      return Future<void>.error(StateError('test_teacher_records_failed'));
    }
    return super.saveTeacherRecords(teachers);
  }

  @override
  Future<void> saveLocationRecords(List<String> locations) {
    if (locationFailures > 0) {
      locationFailures--;
      return Future<void>.error(StateError('test_location_records_failed'));
    }
    return super.saveLocationRecords(locations);
  }

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

  Course lesson(
    String id,
    int day, {
    String name = '高等数学',
    String color = '#111111',
  }) => Course(
    id: id,
    name: name,
    teacher: '王老师',
    location: 'A101',
    dayOfWeek: day,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: color,
  );

  Future<void> seedPair() async {
    await provider.addCourse(lesson('g1', 1));
    await provider.addCourse(lesson('g2', 3));
  }

  Future<TimetableProfile> activeOnDisk() async =>
      (await storage.getProfiles()).firstWhere(
        (profile) => profile.id == provider.activeProfile!.id,
      );

  group('单条课程写入口的落盘失败回滚', () {
    test('deleteCourse 写盘失败后课程与它名下的考试作业都要还在', () async {
      await seedPair();
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

      storage.profilesFailures = 1;
      await expectLater(
        provider.deleteCourse('g1'),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.courses.map((course) => course.id),
        containsAll(<String>['g1', 'g2']),
        reason: '课程没落成功就不该在内存里被删掉',
      );
      expect(
        provider.exams.map((exam) => exam.id),
        contains('e1'),
        reason: '考试是连带删的，用户没确认过它，失败后必须回来',
      );
      expect(
        provider.tasks.map((task) => task.id),
        contains('t1'),
        reason: '作业同理',
      );
      // 另一条课不受影响，仍然在。
      expect(provider.courses.map((course) => course.id), contains('g2'));

      await provider.addCourse(lesson('other', 5));
      final disk = await activeOnDisk();
      expect(
        disk.courses.map((course) => course.id),
        containsAll(<String>['g1', 'g2']),
      );
      expect(disk.exams.map((exam) => exam.id), contains('e1'));
      expect(disk.tasks.map((task) => task.id), contains('t1'));
    });

    test('updateCourse 写盘失败后广播给同组其它课次的改动也要退回', () async {
      await seedPair();
      final before = {
        for (final course in provider.courses) course.id: course.color,
      };
      expect(before['g2'], '#111111');

      storage.profilesFailures = 1;
      await expectLater(
        provider.updateCourse(lesson('g1', 1, color: '#eeeeee')),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.courses.firstWhere((course) => course.id == 'g1').color,
        '#111111',
        reason: '用户改的那一条也要退回：内存必须与盘上同一条真相',
      );
      expect(
        provider.courses.firstWhere((course) => course.id == 'g2').color,
        '#111111',
        reason: 'g2 是被共享字段广播连带改的，失败后不能停在改过的状态',
      );

      await provider.addCourse(lesson('other', 6));
      final disk = await activeOnDisk();
      expect(
        {
          for (final course in disk.courses.where((c) => c.id != 'other'))
            course.id: course.color,
        },
        before,
      );
    });

    test('对照：updateCourse 写盘成功时共享字段确实广播到同组', () async {
      await seedPair();

      await provider.updateCourse(lesson('g1', 1, color: '#eeeeee'));

      expect(
        provider.courses.map((course) => course.color).toSet(),
        contains('#eeeeee'),
      );
      final disk = await activeOnDisk();
      expect(
        disk.courses.where((course) => course.id != 'other').map(
          (course) => course.color,
        ),
        everyElement('#eeeeee'),
        reason: '回滚不许把正常路径也变成"什么都没改"',
      );
    });

    test('addCourse 落盘失败后刻意保留用户刚填的那条（不回滚）', () async {
      // 先正常加一条：让课表进入"有激活课表、有内容"的常规状态，
      // 否则 `_persistActiveProfileState` 的分支与真实使用场景不一致。
      await provider.addCourse(lesson('seed', 1));
      final writesBefore = storage.profilesWrites;
      storage.profilesFailures = 1;
      Object? thrown;
      try {
        await provider.addCourse(lesson('added', 2));
      } catch (error) {
        thrown = error;
      }

      expect(
        storage.profilesWrites,
        greaterThan(writesBefore),
        reason: '缝隙必须真的被命中，否则这条用例什么都没测',
      );
      expect(thrown, isA<StateError>(), reason: '落盘失败要让调用方看到');
      expect(
        provider.courses.map((course) => course.id),
        contains('added'),
        reason: '这条正是用户刚填的内容，表单已经报错；回滚等于清空整张表单。'
            '这是刻意口径，见 course_group_repository.dart 开头的说明。',
      );
    });

    // 保护区起点太晚导致的三个洞（2026-10-07）。`_recordTeacherImpl` /
    // `_recordLocationImpl` 自己要落盘（`saveTeacherRecords` /
    // `saveLocationRecords`），而保护区原先从它们之后才开始：这两条 await 抛错时
    // 课程已替换、共享字段已广播给同组其它课次，三份快照一份都不退、也不 notify。
    test('updateCourse：教师名册写盘失败要把整组课次退回', () async {
      await provider.addCourse(lesson('m1', 1));
      await provider.addCourse(lesson('m2', 2));
      final before = provider.courses
          .map((course) => '${course.id}/${course.teacher}/${course.location}')
          .toList();

      storage.teacherFailures = 1;
      await expectLater(
        provider.updateCourse(
          provider.courses.firstWhere((course) => course.id == 'm1').copyWith(
            teacher: '新老师',
          ),
        ),
        throwsStateError,
      );

      expect(
        provider.courses
            .map((course) => '${course.id}/${course.teacher}/${course.location}')
            .toList(),
        before,
        reason: '修复前课程已被替换、共享字段已广播，而快照一份都没退',
      );
      expect(
        provider.profiles.first.courses
            .map((course) => '${course.id}/${course.teacher}')
            .toList(),
        before.map((entry) => entry.split('/').take(2).join('/')).toList(),
        reason: '连课表镜像一起退：幻影会被下一次写入坐实',
      );
    });

    test('updateCourse：地点名册写盘失败同样要退回', () async {
      await provider.addCourse(lesson('l1', 1));
      final before = provider.courses
          .map((course) => '${course.id}/${course.location}')
          .toList();

      storage.locationFailures = 1;
      await expectLater(
        provider.updateCourse(
          provider.courses.firstWhere((course) => course.id == 'l1').copyWith(
            location: '新楼302',
          ),
        ),
        throwsStateError,
      );

      expect(
        provider.courses
            .map((course) => '${course.id}/${course.location}')
            .toList(),
        before,
      );
    });

    test('updateCourseGroup：名册写盘失败要整组退回', () async {
      // 组更新的循环体里每条课次各 await 一次名册写盘。第一条课次的教师名
      // 「王老师」已在名册里（幂等短路，不落盘），所以改成新名字才会真的走到
      // saveTeacherRecords —— 这正是要注入失败的那一次。
      await provider.addCourseGroup([
        lesson('g1', 1),
        lesson('g2', 2),
      ]);
      final before = provider.courses
          .map((course) => '${course.id}/${course.teacher}')
          .toList();
      expect(before, hasLength(2));

      storage.teacherFailures = 1;
      await expectLater(
        provider.updateCourseGroup(
          lesson('g1', 1).name,
          [
            lesson('g1', 1).copyWith(teacher: '组新老师'),
            lesson('g2', 2),
          ],
        ),
        throwsStateError,
      );

      expect(
        provider.courses
            .map((course) => '${course.id}/${course.teacher}')
            .toList(),
        before,
        reason: '修复前这里是一套半新半旧的课次：三份快照都没退',
      );
    });
  });
}
