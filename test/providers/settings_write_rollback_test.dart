import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 回归钉（第 27 轮，设置写入口的落盘失败回滚）。
///
/// `updateSettings`（原 timetable_provider.dart:333-342）是「批量更新设置」那条口：
/// 主题导入、`_mutateSettings` 的上课提醒开关（:3380）、天气设置
/// （`settings_weather.dart:36`）、统计设置（`statistics_settings_screen.dart:77`）、
/// 桌面星期条文字色重置（`timetable_screen.dart:2561`）、撤销主题变更（:329）、
/// 传输层写入（`unified_transfer_service.dart:697`）都走它。它原先的形状是
/// 「改内存 → await 落盘 → notify」，`previous` 只喂给了性能快照日志，
/// **落盘失败不回滚**：
///
/// - 内存停在没落库的新值上，getter 与盘上不一致；
/// - `_persistActiveProfileState` 在写盘**之前**就执行了
///   `_mergeActiveProfileIntoProfilesList`（:718-738，`settings: _settings`），
///   所以这份幻影已经进了 `_profiles`；下一次任意成功写入（加课、切周）把它落盘，
///   用户视角是「那次失败之后，某个我根本没改过的设置自己生效了」；
/// - 不 `notifyListeners()`，界面也不退回。
///
/// 同文件的 `updateTimetableSettings`（:3847-3867）与主题族共用的
/// `_applySavedThemes`（:350-360）才是本仓契约形状（回滚 + notify + rethrow），
/// 课程/日程/作息/日期规则族也都有对应的 `*_write_rollback_test.dart`。
class _FailingStorage extends StorageService {
  _FailingStorage() : super.forTesting();

  /// 一次设置保存里 `saveProfiles` 会被调用**不止一次**（`_persistActiveProfileStateToDisk`
  /// :1414 那份，加 `setActiveProfileId` 内部对 profiles 的重写），所以注入失败要给足
  /// 次数，否则第一次失败会被后面那次成功写吸收，测不到落盘真的失败。
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

  Course lesson(String id) => Course(
    id: id,
    name: '高等数学$id',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  test('updateSettings 落盘失败要把内存退回旧设置并刷新界面', () async {
    expect(provider.settings.weeklyReportEnabled, isFalse);
    var notifications = 0;
    provider.addListener(() => notifications++);
    storage.profilesFailures = 5;

    await expectLater(
      provider.updateSettings(
        provider.settings.copyWith(weeklyReportEnabled: true),
      ),
      throwsStateError,
    );

    expect(
      provider.settings.weeklyReportEnabled,
      isFalse,
      reason: '修复前这里为 true：内存留着没落库的新值（getter 与盘不一致）',
    );
    expect(
      provider.profiles.first.settings.weeklyReportEnabled,
      isFalse,
      reason: '合并进 _profiles 的那份幻影必须一起退回，否则下一次写入把它坐实',
    );
    expect(notifications, greaterThan(0), reason: '回滚后必须 notifyListeners()');
  });

  test('回滚之后下一次成功写入落的是旧设置', () async {
    storage.profilesFailures = 5;
    await expectLater(
      provider.updateSettings(
        provider.settings.copyWith(weeklyReportEnabled: true),
      ),
      throwsStateError,
    );
    storage.profilesFailures = 0;

    await provider.addCourse(lesson('c1'));

    expect(provider.profiles.first.settings.weeklyReportEnabled, isFalse);
    expect(provider.settings.weeklyReportEnabled, isFalse);
  });

  test('落盘成功时照常生效', () async {
    await provider.updateSettings(
      provider.settings.copyWith(weeklyReportEnabled: true),
    );
    expect(provider.settings.weeklyReportEnabled, isTrue);
    expect(provider.profiles.first.settings.weeklyReportEnabled, isTrue);
    expect(storage.profilesWrites, greaterThan(0));
  });

  // 主题族走的是另一个收口：`_applySavedThemes`（timetable_provider.dart，
  // saveTheme / deleteTheme / renameTheme 三处共用）。它原先只把 `_settings`
  // 退回旧值 —— 但 `_persistActiveProfileState` 的第一步就是
  // `_mergeActiveProfileIntoProfilesList`，落盘抛错时 `_profiles[active]` 里
  // 已经是那份从未落库的新主题列表。此后任何一条直接 `saveProfiles(_profiles)`
  // 的路径（切课表、加课、30 秒一次的心跳）都会把「保存失败」的主题坐实成
  // 盘上数据，用户视角是「刚报了失败，之后它自己又出现了」。
  group('主题列表的落盘失败回滚', () {
    test('saveTheme 失败：幻影主题不能留在 _profiles 里', () async {
      storage.profilesFailures = 5;

      await expectLater(
        provider.saveTheme('深色', {'seed': '#FF0000'}),
        throwsStateError,
      );

      expect(provider.settings.savedThemes, isEmpty, reason: '内存必须退回旧值');
      expect(
        provider.profiles.first.settings.savedThemes,
        isEmpty,
        reason: '修复前这里有 1 条：合并进 _profiles 的幻影没被退回',
      );
    });

    test('saveTheme 失败后，下一次成功写入落的是空主题列表', () async {
      storage.profilesFailures = 5;
      await expectLater(
        provider.saveTheme('深色', {'seed': '#FF0000'}),
        throwsStateError,
      );
      storage.profilesFailures = 0;

      await provider.addCourse(lesson('c1'));

      expect(
        provider.profiles.first.settings.savedThemes,
        isEmpty,
        reason: '这条就是用户视角的「失败之后它自己又出现了」',
      );
      expect(provider.settings.savedThemes, isEmpty);
    });

    test('deleteTheme 失败：被删的主题要回到 _profiles', () async {
      await provider.saveTheme('深色', {'seed': '#FF0000'});
      final themeId = provider.settings.savedThemes.single.id;

      storage.profilesFailures = 5;
      await expectLater(provider.deleteTheme(themeId), throwsStateError);

      expect(provider.settings.savedThemes, hasLength(1));
      expect(
        provider.profiles.first.settings.savedThemes,
        hasLength(1),
        reason: '修复前这里为 0：删除虽然「失败」了幻影却已进 _profiles，'
            '下一次写入就把它永久删掉',
      );
    });

    test('renameTheme 失败：旧名字要回到 _profiles', () async {
      await provider.saveTheme('深色', {'seed': '#FF0000'});
      final themeId = provider.settings.savedThemes.single.id;

      storage.profilesFailures = 5;
      await expectLater(provider.renameTheme(themeId, '浅色'), throwsStateError);

      expect(provider.settings.savedThemes.single.name, '深色');
      expect(
        provider.profiles.first.settings.savedThemes.single.name,
        '深色',
        reason: '修复前这里是「浅色」：改名失败了但幻影留在 _profiles 里',
      );
    });

    test('主题落盘成功时照常生效', () async {
      await provider.saveTheme('深色', {'seed': '#FF0000'});
      expect(provider.settings.savedThemes, hasLength(1));
      expect(provider.profiles.first.settings.savedThemes, hasLength(1));
      expect(storage.profilesWrites, greaterThan(0));
    });
  });
}
