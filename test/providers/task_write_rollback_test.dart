import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 回归钉（第 28 轮，删作业的落盘失败回滚）。
///
/// `deleteTask`（原 timetable_provider.dart:2600-2632）是「改内存 → 裸
/// `await _persistActiveProfileState()` → notify」，没有 try/catch。它的越界处在
/// :2607-2623：当这条作业是「某门课某周的作业标记」（`source == homeworkMark` 且带
/// `courseId`/`sourceWeek`）时，它会顺手把**另一条记录** —— 那门课 `sessionNotes`
/// 里的 `hasHomework` —— 改成 false，然后才落盘。
///
/// 判据来自 `course_group_repository.dart:15` 与 `schedule_item_repository.dart:52`
/// 写明的边界：只有「内存里被改掉的不是用户刚亲口确认的那一条」才需要回滚。
/// 用户点的是「删这条作业」，那门课的周记录不是他要改的东西 —— 与第 20 轮
/// `deleteCourse` 连带摘掉考试/作业同形（`course_write_rollback_test.dart` 钉的就是
/// 这条），而 `deleteCourse` 早就有 `course_repository.dart` 里的快照回滚。
///
/// 落盘失败后的后果：课表里那门课的作业标记停在「已取消」，作业本身还在，
/// 而 `_persistActiveProfileState` 第一步的 `_mergeActiveProfileIntoProfilesList`
/// 已经把改过的课程并进了 `_profiles` —— 下一次任意成功写入把「那门课从来没作业」坐实。
class _FailingStorage extends StorageService {
  _FailingStorage() : super.forTesting();

  /// 一次保存里 `saveProfiles` 会被调用不止一次（`_persistActiveProfileStateToDisk`
  /// 那份 + `setActiveProfileId` 内部的重写），失败次数要给足才能命中真正那次。
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

  Course homeworkCourse() => Course(
    id: 'c1',
    name: '高等数学',
    teacher: '王老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    sessionNotes: const {
      3: CourseSessionNote(text: '第 3 周布置了习题集', hasHomework: true),
    },
  );

  CourseTask manualTask(String id) => CourseTask(
    id: id,
    title: '自己记的作业$id',
    createdAt: DateTime(2026, 10),
    updatedAt: DateTime(2026, 10),
  );

  late String homeworkMarkTaskId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = _FailingStorage();
    provider = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(homeworkCourse());
    // `addCourse` 会跑 `_syncHomeworkTasksWithCourses()`（:2466），
    // 由那门课第 3 周的 `hasHomework` 标记自动生成一条作业 —— 直接用这条，
    // 它才是 `deleteTask` 里 :2607-2623 那个「顺手改回去」分支会命中的形状。
    homeworkMarkTaskId = provider.tasks.single.id;
    expect(provider.tasks.single.source, CourseTaskSource.homeworkMark);
  });

  tearDown(() {
    provider.dispose();
  });

  test('删作业落盘失败时，那条作业的课表记录不能被顺手改掉', () async {
    expect(provider.tasks, hasLength(1));
    expect(provider.courses.single.sessionNoteForWeek(3)?.hasHomework, isTrue);
    storage.profilesFailures = 6;

    await expectLater(
      provider.deleteTask(homeworkMarkTaskId),
      throwsStateError,
    );

    expect(
      provider.tasks.map((task) => task.id),
      [homeworkMarkTaskId],
      reason: '作业没删掉：落盘失败要退回',
    );
    expect(
      provider.courses.single.sessionNoteForWeek(3)?.hasHomework,
      isTrue,
      reason: '修复前这里是 false：用户没点过的那门课记录被改掉并留在内存里',
    );
    expect(
      provider.profiles.first.courses.single.sessionNoteForWeek(3)?.hasHomework,
      isTrue,
      reason: '并进 _profiles 的那份也要退，否则下一次写入坐实「这门课从来没作业」',
    );
  });

  test('落盘成功的删除照常摘掉作业并取消作业标记', () async {
    await provider.deleteTask(homeworkMarkTaskId);

    expect(provider.tasks, isEmpty);
    expect(provider.courses.single.sessionNoteForWeek(3)?.hasHomework, isFalse);
  });

  test('手写的普通作业删除不碰课表记录', () async {
    await provider.addTask(manualTask('t2'));

    await provider.deleteTask('t2');

    expect(provider.tasks.map((task) => task.id), [homeworkMarkTaskId]);
    expect(provider.courses.single.sessionNoteForWeek(3)?.hasHomework, isTrue);
  });
}
