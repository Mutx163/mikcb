import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/wallpaper_history.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/miui_live_activities_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/wallpaper_history_service.dart';

/// 壁纸「最近使用」历史改成**全局**（设备级、所有课表共用）之后的两条迁移行为：
/// 首次载入把各 profile 各自的历史并成一条；用户清空之后不许被残留副本复活。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // StorageService 的 profiles 键是私有的，这里按同一个字面量播种。
  const String profilesKey = 'timetable_profiles';

  Map<String, Object?> profileJson({
    required String id,
    required String name,
    required List<WallpaperHistoryEntry> history,
    required int currentWeek,
  }) => TimetableProfile(
    id: id,
    name: name,
    courses: const [],
    settings: TimetableSettings.defaults().copyWith(wallpaperHistory: history),
    currentWeek: currentWeek,
    createdAt: DateTime(2026, 9),
    lastUsedAt: DateTime(2026, 9),
  ).toJson();

  Future<void> bootProvider() async {
    final provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      liveActivitiesService: TestMiuiLiveActivitiesService(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    // 迁移是 unawaited 的后台动作，等它跑完。
    await pumpEventQueue();
  }

  void seedTwoProfiles() {
    SharedPreferences.setMockInitialValues({
      profilesKey: jsonEncode([
        profileJson(
          id: 'a',
          name: '课表A',
          currentWeek: 3,
          history: const [WallpaperHistoryEntry(key: '/a/old.png', usedAt: 100)],
        ),
        profileJson(
          id: 'b',
          name: '课表B',
          currentWeek: 1,
          history: const [
            WallpaperHistoryEntry(key: '/b/new.png', usedAt: 300),
            WallpaperHistoryEntry(key: '/a/old.png', alignX: 0.5, usedAt: 200),
          ],
        ),
      ]),
    });
    WallpaperHistoryService.notifier.value = const [];
  }

  test('首次载入把各 profile 的历史并成一条全局历史', () async {
    seedTwoProfiles();

    await bootProvider();

    final global = await WallpaperHistoryService.load();
    expect(global.map((entry) => entry.key), ['/b/new.png', '/a/old.png']);
    expect(global.last.alignX, 0.5, reason: '同 key 取较新的那次对齐');
    expect(await WallpaperHistoryService.isMigrated(), isTrue);
  });

  test('迁移只做一次：清空历史之后不会被 profile 里的残留副本复活', () async {
    seedTwoProfiles();

    await bootProvider();
    expect((await WallpaperHistoryService.load()).length, 2);

    // 用户清空「最近使用」。
    await WallpaperHistoryService.save(const []);

    // 同一份 prefs 再起一个 provider：标记已置位，旧条目不许被重新并回来。
    await bootProvider();
    expect(await WallpaperHistoryService.load(), isEmpty);
  });
}
