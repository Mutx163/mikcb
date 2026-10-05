import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 安排事项（日程）族里"会波及其它行"的写入口在落盘失败时必须退回（2026-10-05 审查）。
///
/// 判据与本族其它批一致（见 `course_group_repository.dart` 开头）：**内存里被改掉的是
/// 不是用户刚刚亲口确认的那一条**。日程族有两个入口会一次动多行：
///
/// - `updateScheduleItem`（timetable_provider.dart:2960-2997）改一个"系列根"时，
///   :2976 会 `nextItems.removeWhere((candidate) => candidate.seriesId == existing.id)`
///   把这个系列的**所有单次覆盖行**一起摘掉（注释里写明是刻意的系列语义），然后
///   `await _persistActiveProfileState()`，没有 try/catch；
/// - `deleteScheduleItem`（:2999-3023）按 `seriesId ?? id` 连根带覆盖整系列摘除，
///   同样无回滚。
///
/// 落盘失败时（磁盘满、`commit()` 返回 false）内存里那些从没被用户点过"删除"的覆盖行
/// 已经没了，而下一次任意成功写入（加日程、切周、心跳）会把这份"整系列只剩改过的那条"
/// 坐实到盘上 —— 用户看到的是一次失败的编辑之后，重复日程里单独改过的那几次自己消失了。
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

  final today = DateTime.now();
  DateTime dayOffset(int days) => today.add(Duration(days: days));

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

  ScheduleItem weeklyRoot() => ScheduleItem(
    id: 'root-1',
    title: '每周组会',
    startTime: '10:00',
    endTime: '11:00',
    startDate: dayOffset(0),
    endDate: dayOffset(28),
    recurrence: ScheduleRecurrence.weekly,
    createdAt: today,
    updatedAt: today,
  );

  ScheduleItem overrideItem() => ScheduleItem(
    id: 'ov-1',
    title: '组会（这周改到下午）',
    startTime: '15:00',
    endTime: '16:00',
    date: dayOffset(7),
    startDate: dayOffset(7),
    endDate: dayOffset(7),
    seriesId: 'root-1',
    occurrenceDate: dayOffset(7),
    createdAt: today,
    updatedAt: today,
  );

  Future<void> seedSeries() async {
    await provider.addScheduleItem(weeklyRoot());
    await provider.addScheduleItem(overrideItem());
    expect(provider.scheduleItems, hasLength(2));
  }

  List<String> storedIds() => provider.scheduleItems
      .map((item) => item.id)
      .toList()
    ..sort();

  group('日程族写入口的落盘失败回滚', () {
    test('updateScheduleItem 写盘失败后被摘掉的单次覆盖行要回来', () async {
      await seedSeries();
      final idsBefore = storedIds();
      final rootTitleBefore = provider.scheduleItems
          .firstWhere((item) => item.id == 'root-1')
          .title;

      storage.profilesFailures = 1;
      await expectLater(
        provider.updateScheduleItem(
          weeklyRoot().copyWith(title: '改过的每周组会'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        storedIds(),
        idsBefore,
        reason: '覆盖行（ov-1）是被系列语义连带删的，失败后必须一起退回',
      );
      expect(
        provider.scheduleItems.firstWhere((item) => item.id == 'root-1').title,
        rootTitleBefore,
      );

      // 幻影只有被下一次成功写入坐实才算真的丢数据。
      await provider.addScheduleItem(
        overrideItem().copyWith(id: 'probe-1', seriesId: null),
      );
      final disk = (await storage.getProfiles()).firstWhere(
        (profile) => profile.id == provider.activeProfile!.id,
      );
      expect(
        disk.scheduleItems.map((item) => item.id),
        containsAll(<String>['root-1', 'ov-1']),
      );
      expect(
        disk.scheduleItems
            .firstWhere((item) => item.id == 'root-1')
            .title,
        rootTitleBefore,
      );
    });

    test('deleteScheduleItem 写盘失败后整系列（根与覆盖行）都要还在', () async {
      await seedSeries();

      storage.profilesFailures = 1;
      await expectLater(
        provider.deleteScheduleItem('ov-1'),
        throwsA(isA<StateError>()),
      );

      expect(
        storedIds(),
        <String>['ov-1', 'root-1'],
        reason: '按系列摘除是整系列删除，落盘失败就一行都不该少',
      );

      await provider.addScheduleItem(
        weeklyRoot().copyWith(id: 'probe-2', recurrence: ScheduleRecurrence.none),
      );
      final disk = (await storage.getProfiles()).firstWhere(
        (profile) => profile.id == provider.activeProfile!.id,
      );
      expect(
        disk.scheduleItems.map((item) => item.id),
        containsAll(<String>['root-1', 'ov-1']),
      );
    });

    test('对照：落盘成功时删除系列根会连覆盖行一起消失', () async {
      await seedSeries();

      await provider.deleteScheduleItem('root-1');

      expect(provider.scheduleItems, isEmpty);
      final disk = (await storage.getProfiles()).firstWhere(
        (profile) => profile.id == provider.activeProfile!.id,
      );
      expect(disk.scheduleItems, isEmpty);
    });
  });
}
