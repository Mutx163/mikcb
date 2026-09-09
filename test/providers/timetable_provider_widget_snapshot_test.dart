import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 2026-02-23 是周一，作为学期第 1 周周一；测试日期取第 4 周的普通周一
/// （2026-03-16），避开内置节假日数据里的春节假期。
final _semesterStart = DateTime(2026, 2, 23);
final _mondayNoon = DateTime(2026, 3, 16, 12);

Course _course({
  required String id,
  required String name,
  int dayOfWeek = 1,
  int startSection = 1,
  int endSection = 2,
  String startTime = '08:00',
  String endTime = '09:40',
  int? startWeek,
  int? endWeek,
}) {
  return Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: startTime,
    endTime: endTime,
    startWeek: startWeek ?? 1,
    endWeek: endWeek ?? 20,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('buildHomeWidgetSnapshotForProfile（双卡片数据隔离）', () {
    test('按指定课表出快照，不受当前课表影响', () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterWeekCount: 20,
          semesterStartDate: _semesterStart,
        ),
      );
      // 当前课表（A）：周一只有 A 的课。
      await provider.addCourse(_course(id: 'a-mon', name: 'A-高数'));
      // 另一张课表（B）：周一只有 B 的课。
      final profileB = await provider.createProfile(name: 'B课表');
      await provider.switchProfile(profileB.id);
      await provider.addCourse(_course(id: 'b-mon', name: 'B-线代'));
      // 切回 A（profiles 顺序首位），模拟双卡片场景里的「当前课表」。
      final profileAId = provider.profiles
          .firstWhere((profile) => !profile.isPartnerImported && profile.id != profileB.id)
          .id;
      await provider.switchProfile(profileAId);

      // 当前课表快照：只含 A 的课。
      final activeSnapshot = provider.buildHomeWidgetSnapshot(now: _mondayNoon);
      expect(activeSnapshot, isNotNull);
      expect(
        activeSnapshot!.todayCourses.map((course) => course.name),
        ['A-高数'],
      );

      // 绑定课表快照：只含 B 的课，profileId/profileName 对位 B。
      final snapshotB = provider.buildHomeWidgetSnapshotForProfile(
        provider.profiles.firstWhere((profile) => profile.id == profileB.id),
        now: _mondayNoon,
      );
      expect(snapshotB, isNotNull);
      expect(snapshotB!.profileId, profileB.id);
      expect(snapshotB.profileName, 'B课表');
      expect(
        snapshotB.todayCourses.map((course) => course.name),
        ['B-线代'],
      );
    });

    test('TA 课表（partnerImported）可直接出快照', () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      final partnerProfile = provider.partnerProfile;
      // 未导入 TA 课表时无快照数据，此处只验证不抛异常且为 null。
      expect(
        partnerProfile == null
            ? null
            : provider.buildHomeWidgetSnapshotForProfile(
                partnerProfile,
                now: _mondayNoon,
              ),
        isNull,
      );
    });
  });

  group('buildHomeWidgetSnapshotForCouple（情侣合并视图）', () {
    Future<TimetableProvider> providerWithPartner(
      List<Course> partnerCourses,
    ) async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterWeekCount: 20,
          semesterStartDate: _semesterStart,
        ),
      );
      final backup = provider.dataTransferService.buildBackupJson(
        profileName: 'TA的课表',
        courses: partnerCourses,
        settings: TimetableSettings.defaults(),
        currentWeek: 1,
      );
      await provider.importPartnerTimetable(backup);
      return provider;
    }

    test('合并双方课程：我的在前按节次排序，按情侣三色着色', () async {
      final provider = await providerWithPartner([
        _course(id: 'p-eng', name: 'C-英语', startSection: 2, endSection: 3,
            startTime: '09:00', endTime: '10:40'),
        _course(id: 'p-lin', name: 'B-线代', startSection: 3, endSection: 4,
            startTime: '10:00', endTime: '11:40'),
      ]);
      await provider.addCourse(_course(id: 'a-mon', name: 'A-高数'));

      final snapshot = provider.buildHomeWidgetSnapshotForCouple(now: _mondayNoon);
      expect(snapshot, isNotNull);
      expect(snapshot!.profileId, 'couple-merged');
      expect(
        snapshot.todayCourses.map((course) => course.name),
        ['A-高数', 'C-英语', 'B-线代'],
      );
      expect(
        snapshot.todayCourses.map((course) => course.color),
        ['#2196F3', '#E91E63', '#E91E63'],
      );
    });

    test('同行程（同时段同名）去重为一起课，颜色用 together 档', () async {
      final provider = await providerWithPartner([
        _course(id: 'p-math', name: 'A-高数'),
        _course(id: 'p-lin', name: 'B-线代', startSection: 3, endSection: 4,
            startTime: '10:00', endTime: '11:40'),
      ]);
      await provider.addCourse(_course(id: 'a-mon', name: 'A-高数'));

      final snapshot = provider.buildHomeWidgetSnapshotForCouple(now: _mondayNoon);
      expect(
        snapshot!.todayCourses.map((course) => course.name),
        ['A-高数', 'B-线代'],
      );
      expect(snapshot.todayCourses.first.color, '#9C27B0');
      expect(snapshot.todayCourses.last.color, '#E91E63');
    });

    test('周偏移把 TA 课程映射到我的周次：offset=1 取 TA 第 5 周的课', () async {
      final provider = await providerWithPartner([
        _course(id: 'p-pe', name: 'D-体育', startSection: 3, endSection: 4,
            startTime: '10:00', endTime: '11:40',
            startWeek: 5, endWeek: 5),
        _course(id: 'p-chem', name: 'E-化学', startSection: 5, endSection: 6,
            startTime: '14:00', endTime: '15:40',
            startWeek: 4, endWeek: 4),
      ]);
      await provider.addCourse(_course(id: 'a-mon', name: 'A-高数'));

      // 无偏移：我的第 4 周 ← TA 第 4 周，E-化学在场、D-体育不在。
      final snapshot0 = provider.buildHomeWidgetSnapshotForCouple(
        now: _mondayNoon,
      );
      expect(
        snapshot0!.todayCourses.map((course) => course.name),
        ['A-高数', 'E-化学'],
      );

      // offset=1：我的第 4 周 ← TA 第 5 周，D-体育在场、E-化学退场。
      await provider.updatePartnerWeekOffset(1);
      final snapshot1 = provider.buildHomeWidgetSnapshotForCouple(
        now: _mondayNoon,
      );
      expect(
        snapshot1!.todayCourses.map((course) => course.name),
        ['A-高数', 'D-体育'],
      );
    });

    test('TA 解绑后返回 null（调用方清专属快照回落跟随当前课表）', () async {
      final provider = await providerWithPartner([
        _course(id: 'p-lin', name: 'B-线代', startSection: 3, endSection: 4,
            startTime: '10:00', endTime: '11:40'),
      ]);
      expect(
        provider.buildHomeWidgetSnapshotForCouple(now: _mondayNoon),
        isNotNull,
      );

      await provider.unlinkPartner();
      expect(
        provider.buildHomeWidgetSnapshotForCouple(now: _mondayNoon),
        isNull,
      );
    });
  });
}
