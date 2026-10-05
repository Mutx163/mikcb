import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 回归钉（第 28 轮，导入族最后一个没带回滚快照的写入口）。
///
/// `importParsedCourses`（`_timetableImportParsedCourses`，
/// lib/providers/timetable/import_export_service.dart:245-343）是 ICS 唤醒导入、
/// 表格导入、AI 导入、教务导入共用的那一条（`course_import_screen.dart:5825`）。
/// 它的形状是「整份换内存 → 裸 await 落盘」：
/// - `host._scheduleItems = []`（:274，覆盖式导入把上一套课表的日程条目**整份清零**）；
/// - `host._courses = …`（:299）、`host._settings = copyWith(semesterStartDate /
///   semesterWeekCount)`（:313-319）、`host._currentWeek/_currentDateWeek`（:320-325）；
/// - 然后才 `await host._persistActiveProfileState(notifySync: false)`（:326），**外面没有 try/catch**。
///
/// 同文件另外两条导入路径都已经收口过：`_timetableImportAppDataBackup`（:359 抓
/// `_FullBackupRestoreSnapshot`）与 `_timetableImportFullAppDataBackup`（:519），
/// 注释写的理由就是「先换内存、后写盘……用户退出 App 再进来，课表凭空消失」。
/// 落盘一失败（磁盘满、`commit()` 返回 false → `StateError('storage_write_failed')`），
/// 界面报「导入失败」，但内存里是新课表 + 日程被清空；而
/// `_persistActiveProfileState` 第一步的 `_mergeActiveProfileIntoProfilesList`
/// 已经把这些并进了 `_profiles`，下一次任意成功写入（切周、加课）就把
/// 「日程被永久删除」落盘 —— 用户重启看到的既不是旧课表也不是新课表，是半成品。
class _FailingStorage extends StorageService {
  _FailingStorage() : super.forTesting();

  /// 一次保存里 `saveProfiles` 会被调用不止一次（`_persistActiveProfileStateToDisk`
  /// 那份 + `setActiveProfileId` 内部对 profiles 的重写），失败次数要给足才能命中，
  /// 否则第一次失败会被后面那次成功写吸收（第 27 轮踩过）。
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

  Course lesson(String id) => Course(
    id: id,
    name: '课程$id',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  ScheduleItem agenda(String id) => ScheduleItem(
    id: id,
    title: '周会$id',
    location: '三教',
    startTime: '14:00',
    endTime: '15:00',
    date: DateTime(2026, 10, 12),
    createdAt: DateTime(2026, 10),
    updatedAt: DateTime(2026, 10),
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
    await provider.addCourse(lesson('old'));
    await provider.addScheduleItem(agenda('s1'));
    await provider.addScheduleItem(agenda('s2'));
  });

  tearDown(() {
    provider.dispose();
  });

  test('覆盖导入落盘失败时，旧课表与整份日程都要退回', () async {
    final coursesBefore = provider.courses.map((course) => course.id).toList();
    expect(provider.scheduleItems, hasLength(2));
    storage.profilesFailures = 6;

    await expectLater(
      provider.importParsedCourses(
        [lesson('new')],
        replaceExisting: true,
        source: 'csv',
      ),
      throwsStateError,
    );

    expect(
      provider.scheduleItems.map((item) => item.id).toList(),
        ['s1', 's2'],
      reason: '修复前这里是空表：`_scheduleItems = []` 从没落库的那次导入里留下',
    );
    expect(
      provider.courses.map((course) => course.id).toList(),
      coursesBefore,
      reason: '内存不能停在没落库的新课表上',
    );
    expect(
      provider.profiles.first.scheduleItems,
      hasLength(2),
      reason: '合并进 _profiles 的那份也必须一起退，否则下一次写入坐实「日程没了」',
    );
  });

  test('落盘成功的覆盖导入照常替换', () async {
    final imported = await provider.importParsedCourses(
      [lesson('new'), lesson('new2')],
      replaceExisting: true,
      source: 'csv',
    );

    expect(imported, 2);
    expect(provider.courses.map((course) => course.id), ['new', 'new2']);
    expect(provider.scheduleItems, isEmpty);
  });
}
