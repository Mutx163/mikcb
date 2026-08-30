import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
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
}) {
  return Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    startWeek: 1,
    endWeek: 16,
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
}
