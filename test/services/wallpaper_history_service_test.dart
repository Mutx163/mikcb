import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/wallpaper_history.dart';
import 'package:university_timetable/services/wallpaper_history_service.dart';
import 'package:university_timetable/utils/wallpaper_history.dart';

/// 壁纸「最近使用」历史的**全局**存储。
///
/// 守两件事：真源只有 prefs 这一处（切课表不再跟着换），以及迁移/导入时的并集
/// 幂等（不会越并越多、也不会被坏数据炸掉整条历史）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WallpaperHistoryService.notifier.value = const [];
  });

  test('空存储读出空历史', () async {
    expect(await WallpaperHistoryService.load(), isEmpty);
  });

  test('保存后能读回，并同步 notifier', () async {
    await WallpaperHistoryService.save(const [
      WallpaperHistoryEntry(key: '/a.png', alignX: 0.5, usedAt: 20),
      WallpaperHistoryEntry(key: '/b.png', usedAt: 10),
    ]);

    final loaded = await WallpaperHistoryService.load();
    expect(loaded.map((entry) => entry.key), ['/a.png', '/b.png']);
    expect(loaded.first.alignX, 0.5);
    expect(WallpaperHistoryService.notifier.value, loaded);
  });

  test('保存时按上限截断', () async {
    await WallpaperHistoryService.save([
      for (var i = 0; i < kMaxWallpaperHistoryEntries + 5; i++)
        WallpaperHistoryEntry(key: '/img/$i.png', usedAt: i),
    ]);

    expect(
      (await WallpaperHistoryService.load()).length,
      kMaxWallpaperHistoryEntries,
    );
  });

  test('坏条目逐条丢弃，不牵连连好条目', () async {
    SharedPreferences.setMockInitialValues({
      WallpaperHistoryService.preferenceKey:
          '[{"key":"/ok.png","usedAt":3},{"key":123},{"alignX":1},"junk",null]',
    });

    final loaded = await WallpaperHistoryService.load();
    expect(loaded.map((entry) => entry.key), ['/ok.png']);
    expect(loaded.single.usedAt, 3);
  });

  test('整串 JSON 坏掉时当空历史，不抛给调用方', () async {
    SharedPreferences.setMockInitialValues({
      WallpaperHistoryService.preferenceKey: '{not json',
    });

    expect(await WallpaperHistoryService.load(), isEmpty);
  });

  test('mergeAndSave：同 key 取 usedAt 更新者、去重、最新在前，且幂等', () async {
    const older = [
      WallpaperHistoryEntry(key: '/a.png', alignX: 0.1, usedAt: 100),
    ];
    const newer = [
      WallpaperHistoryEntry(key: '/a.png', alignX: 0.9, usedAt: 300),
      WallpaperHistoryEntry(key: '/b.png', usedAt: 200),
    ];

    await WallpaperHistoryService.mergeAndSave([older, newer]);
    final first = await WallpaperHistoryService.load();
    expect(first.map((entry) => entry.key), ['/a.png', '/b.png']);
    expect(first.first.alignX, 0.9, reason: '同 key 应保留较新的那次对齐');

    // 再并一次同样的两份：结果必须一字不差（导入后可能反复触发）。
    await WallpaperHistoryService.mergeAndSave([older, newer]);
    expect(await WallpaperHistoryService.load(), first);
  });

  test('迁移标记默认 false，置位后为 true', () async {
    expect(await WallpaperHistoryService.isMigrated(), isFalse);
    await WallpaperHistoryService.markMigrated();
    expect(await WallpaperHistoryService.isMigrated(), isTrue);
  });
}
