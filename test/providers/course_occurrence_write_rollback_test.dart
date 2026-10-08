import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 回归钉（2026-10-08 审核第 6 轮）：删「某门课的某一周」落盘失败要整体退回。
///
/// `_deleteCourseOccurrenceImpl` 原先是「改内存 → 裸 await 落盘 → notify」，
/// 没有快照也没有 catch。`delCourseOccurrence` 这一步连带改掉两样**不是用户
/// 要删的东西**：
///   ① 课程自身的周次范围与 `sessionNotes`（去掉那一周的记录）；
///   ② `_syncHomeworkTasksWithCourses()` 按新周次重算出来的**作业**。
/// 作业是「那门课某周的作业标记」，用户点的是「删这一周」，作业不该跟着消失。
///
/// 落盘失败后的后果：课程和作业都停在「那周已经删掉」，而盘上还是原样；随后
/// 任意一次成功写入（切周、加课、30 秒一次的 `syncTemporalContext` 心跳）会把
/// 这份从未落库的改动永久坐实 —— 用户视角是「我只想删第 3 周，结果整门课的
/// 作业都变了，而且重启也回不来」。
///
/// 判据与本仓其它批一致（见 `course_group_repository.dart` 开头）：内存里被改掉
/// 的不是用户刚亲口确认的那一条，就要退。形状同
/// `course_write_rollback_test.dart`（删课程连带摘考试/作业）与
/// `task_write_rollback_test.dart`（删作业顺手改掉那门课的周记录）。
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

  /// 一门上三周的课，第 2 周带作业标记。
  Course threeWeekCourse() => Course(
    id: 'c1',
    name: '高等数学',
    teacher: '王老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    startWeek: 1,
    endWeek: 3,
    sessionNotes: const {
      2: CourseSessionNote(text: '第 2 周布置了习题集', hasHomework: true),
    },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = _FailingStorage();
    provider = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(threeWeekCourse());
  });

  tearDown(() {
    provider.dispose();
  });

  test('删单周课落盘失败时，那门课的周次与作业都不能被改掉', () async {
    // addCourse 会跑 `_syncHomeworkTasksWithCourses()`，由第 2 周的
    // `hasHomework` 标记生成一条作业 —— 正是被连带重算的那一条。
    expect(provider.tasks, hasLength(1));
    expect(provider.courses.single.sessionNoteForWeek(2)?.hasHomework, isTrue);

    storage.profilesFailures = 6;

    await expectLater(
      provider.deleteCourseOccurrence(courseId: 'c1', sourceWeek: 2),
      throwsStateError,
    );

    expect(
      provider.courses.single.activeWeeks,
      containsAll(<int>[1, 2, 3]),
      reason: '周次没删成功：落盘失败要整体退回',
    );
    expect(
      provider.courses.single.sessionNoteForWeek(2)?.hasHomework,
      isTrue,
      reason: '作业标记不是用户要删的东西',
    );
    expect(
      provider.tasks,
      hasLength(1),
      reason: '作业被顺手重算掉了：重算结果不是用户确认的那一条',
    );
    expect(
      provider.profiles.first.courses.single.activeWeeks,
      containsAll(<int>[1, 2, 3]),
      reason: '并进 _profiles 的那份也要退，否则下一次写入坐实「第 2 周被删了」',
    );
  });

  test('落盘成功的删单周课照常只摘那一周', () async {
    await provider.deleteCourseOccurrence(courseId: 'c1', sourceWeek: 2);

    final course = provider.courses.single;
    expect(course.activeWeeks, isNot(contains(2)));
    expect(course.activeWeeks, containsAll(<int>[1, 3]));
    expect(course.sessionNoteForWeek(2), isNull);
    expect(
      provider.tasks,
      isEmpty,
      reason: '删掉那一周的标记后，重算不再生成那条作业',
    );
  });

  test('删掉最后一周时整门课连同作业一起没', () async {
    // 这是这条路径上最重的一个形态：课程整条被摘掉。
    await provider.deleteCourseOccurrence(courseId: 'c1', sourceWeek: 3);
    expect(provider.courses, hasLength(1));
    expect(provider.courses.single.activeWeeks, isNot(contains(3)));
  });
}
