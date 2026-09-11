import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/wallpaper_history.dart';
import 'package:university_timetable/ui/background/builtin_wallpaper.dart';
import 'package:university_timetable/utils/wallpaper_history.dart';

void main() {
  /// 建一个真实存在的临时壁纸文件：图片条目的可用性判定会摸盘。
  /// 每个用例用独立目录，避免命中按路径记忆的存在性缓存。
  String createTempWallpaper(String name) {
    final dir = Directory.systemTemp.createTempSync('mikcb-wallpaper-test');
    final file = File('${dir.path}${Platform.pathSeparator}$name')
      ..writeAsStringSync('x');
    return file.path;
  }

  group('pushWallpaperHistory', () {
    test('新条目置顶并记录使用时间', () {
      final result = pushWallpaperHistory(
        history: const [WallpaperHistoryEntry(key: '/old.png')],
        key: '/new.png',
        usedAt: 123,
      );

      expect(result.history.map((entry) => entry.key), ['/new.png', '/old.png']);
      expect(result.history.first.usedAt, 123);
      expect(result.evictedPaths, isEmpty);
    });

    test('同一 key 去重后置顶并更新对齐', () {
      final result = pushWallpaperHistory(
        history: const [
          WallpaperHistoryEntry(key: '/a.png'),
          WallpaperHistoryEntry(key: '/b.png'),
        ],
        key: '/b.png',
        alignX: 0.5,
        alignY: -0.5,
      );

      expect(result.history.map((entry) => entry.key), ['/b.png', '/a.png']);
      expect(result.history.first.alignX, 0.5);
      expect(result.history.first.alignY, -0.5);
    });

    test('空 key 原样返回，不写入历史', () {
      const history = [WallpaperHistoryEntry(key: '/a.png')];
      final result = pushWallpaperHistory(history: history, key: '   ');

      expect(result.history, history);
      expect(result.evictedPaths, isEmpty);
    });

    test('超出上限时挤出最旧条目并给出待删图片路径', () {
      var history = <WallpaperHistoryEntry>[];
      for (var i = 0; i < kMaxWallpaperHistoryEntries; i++) {
        history = pushWallpaperHistory(history: history, key: '/img/$i.png').history;
      }

      final result = pushWallpaperHistory(history: history, key: '/img/new.png');

      expect(result.history.length, kMaxWallpaperHistoryEntries);
      expect(result.history.first.key, '/img/new.png');
      expect(result.history.last.key, '/img/1.png');
      expect(result.evictedPaths, ['/img/0.png']);
    });

    test('被挤出的内置条目没有文件可删', () {
      var history = <WallpaperHistoryEntry>[
        WallpaperHistoryEntry(key: builtInWallpaperKey(BuiltInWallpaper.og)),
      ];
      for (var i = 0; i < kMaxWallpaperHistoryEntries - 1; i++) {
        history = pushWallpaperHistory(history: history, key: '/img/$i.png').history;
      }

      final result = pushWallpaperHistory(history: history, key: '/img/new.png');

      expect(result.history.length, kMaxWallpaperHistoryEntries);
      expect(
        result.history.any(
          (entry) => entry.key == builtInWallpaperKey(BuiltInWallpaper.og),
        ),
        isFalse,
      );
      expect(result.evictedPaths, isEmpty);
    });
  });

  group('rememberWallpaperHistoryBatch', () {
    test('按旧到新顺序补记，最新的留在最前', () {
      final result = rememberWallpaperHistoryBatch(
        history: const [],
        entries: const [
          WallpaperHistoryEntry(key: '/old.png', alignX: 0.2),
          WallpaperHistoryEntry(key: '/new.png', alignX: -0.2),
        ],
      );

      expect(result.history.map((entry) => entry.key), ['/new.png', '/old.png']);
      expect(result.history.last.alignX, 0.2);
    });

    test('批量挤出时累计所有待删路径', () {
      var history = <WallpaperHistoryEntry>[];
      for (var i = 0; i < kMaxWallpaperHistoryEntries; i++) {
        history = pushWallpaperHistory(history: history, key: '/img/$i.png').history;
      }

      final result = rememberWallpaperHistoryBatch(
        history: history,
        entries: const [
          WallpaperHistoryEntry(key: '/img/a.png'),
          WallpaperHistoryEntry(key: '/img/b.png'),
        ],
      );

      expect(result.history.length, kMaxWallpaperHistoryEntries);
      expect(result.evictedPaths, ['/img/0.png', '/img/1.png']);
    });
  });

  group('availableWallpaperHistory', () {
    test('剔除文件已丢失的图片条目，保留合法内置预设', () {
      final existing = createTempWallpaper('a.png');
      final history = [
        WallpaperHistoryEntry(key: existing),
        const WallpaperHistoryEntry(key: '/definitely/missing.png'),
        WallpaperHistoryEntry(key: builtInWallpaperKey(BuiltInWallpaper.og)),
        const WallpaperHistoryEntry(key: 'builtin:nope'),
      ];

      final available = availableWallpaperHistory(history);

      expect(available.map((entry) => entry.key), [
        existing,
        builtInWallpaperKey(BuiltInWallpaper.og),
      ]);
    });
  });

  group('settingsWithWallpaperHistoryEntry', () {
    test('内置条目清掉图片路径并把对齐归零', () {
      final settings = TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: '/tmp/legacy.png',
        homePageWallpaperAlignX: 0.8,
        homePageWallpaperAlignY: -0.4,
      );

      final next = settingsWithWallpaperHistoryEntry(
        settings,
        WallpaperHistoryEntry(
          key: builtInWallpaperKey(BuiltInWallpaper.lavaDark),
        ),
      );

      expect(next, isNotNull);
      expect(next!.homePageBuiltInWallpaper, BuiltInWallpaper.lavaDark.value);
      expect(next.homePageWallpaperPath, isNull);
      expect(next.homePageWallpaperAlignX, 0);
      expect(next.homePageWallpaperAlignY, 0);
    });

    test('图片条目恢复路径与当时的对齐，且保留内置回退', () {
      final path = createTempWallpaper('b.png');
      final settings = TimetableSettings.defaults().copyWith(
        homePageBuiltInWallpaper: BuiltInWallpaper.og.value,
      );

      final next = settingsWithWallpaperHistoryEntry(
        settings,
        WallpaperHistoryEntry(key: path, alignX: 0.3, alignY: -0.7),
      );

      expect(next, isNotNull);
      expect(next!.homePageWallpaperPath, path);
      expect(next.homePageWallpaperAlignX, 0.3);
      expect(next.homePageWallpaperAlignY, -0.7);
      expect(next.homePageBuiltInWallpaper, BuiltInWallpaper.og.value);
    });

    test('条目不可用时返回 null', () {
      expect(
        settingsWithWallpaperHistoryEntry(
          TimetableSettings.defaults(),
          const WallpaperHistoryEntry(key: 'builtin:nope'),
        ),
        isNull,
      );
      expect(
        settingsWithWallpaperHistoryEntry(
          TimetableSettings.defaults(),
          const WallpaperHistoryEntry(key: '/definitely/missing.png'),
        ),
        isNull,
      );
    });
  });

  group('deleteEvictedWallpaperFiles', () {
    test('空路径与内置条目安全跳过', () async {
      await deleteEvictedWallpaperFiles([
        '',
        builtInWallpaperKey(BuiltInWallpaper.emberTeal),
      ]);
    });
  });
}
