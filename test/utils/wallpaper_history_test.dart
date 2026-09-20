import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/wallpaper_history.dart';
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

    test('被挤出的遗留内置壁纸条目没有文件可删', () {
      // 内置壁纸功能已移除，但老数据里的 `builtin:` 键仍会随历史迁移；
      // 它们没有磁盘文件，被挤出时不得进待删清单。
      var history = <WallpaperHistoryEntry>[
        const WallpaperHistoryEntry(key: 'builtin:og'),
      ];
      for (var i = 0; i < kMaxWallpaperHistoryEntries - 1; i++) {
        history = pushWallpaperHistory(history: history, key: '/img/$i.png').history;
      }

      final result = pushWallpaperHistory(history: history, key: '/img/new.png');

      expect(result.history.length, kMaxWallpaperHistoryEntries);
      expect(
        result.history.any((entry) => entry.key == 'builtin:og'),
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

    test('同一批里被重新加回的条目不得列入待删（会删掉正在使用的壁纸）', () {
      // 回归：历史已满，当前壁纸不在历史里，用户点「最近使用」里最旧那条。
      // 调用方按顺序传 [被换下的, 新选中的]：第一条把最旧的挤出并列入待删，
      // 第二条又把它补回队首——若照单删除，就会删掉**刚被设为当前壁纸**的
      // 那个文件（settings.homePageWallpaperPath 正指向它）。
      var history = <WallpaperHistoryEntry>[];
      for (var i = 0; i < kMaxWallpaperHistoryEntries; i++) {
        history = pushWallpaperHistory(
          history: history,
          key: '/img/$i.png',
        ).history;
      }
      final oldest = history.last;
      expect(oldest.key, '/img/0.png');

      final result = rememberWallpaperHistoryBatch(
        history: history,
        entries: [
          const WallpaperHistoryEntry(key: '/img/previous.png'),
          WallpaperHistoryEntry(key: oldest.key),
        ],
      );

      expect(
        result.history.map((entry) => entry.key),
        contains(oldest.key),
        reason: '它已被第二条重新加回历史',
      );
      expect(
        result.evictedPaths,
        isNot(contains(oldest.key)),
        reason: '仍在历史里、且正被 settings 引用的文件绝不能列入待删',
      );
      // 其余确已离开历史的仍要删（第二条只挤掉了 /img/1）。
      expect(result.evictedPaths, ['/img/1.png']);
    });
  });

  group('availableWallpaperHistory', () {
    test('剔除文件已丢失的条目与遗留的内置壁纸键', () {
      final existing = createTempWallpaper('a.png');
      final history = [
        WallpaperHistoryEntry(key: existing),
        const WallpaperHistoryEntry(key: '/definitely/missing.png'),
        const WallpaperHistoryEntry(key: 'builtin:og'),
        const WallpaperHistoryEntry(key: 'builtin:nope'),
      ];

      final available = availableWallpaperHistory(history);

      expect(available.map((entry) => entry.key), [existing]);
    });
  });

  group('settingsWithWallpaperHistoryEntry', () {
    test('图片条目恢复路径与当时的对齐', () {
      final path = createTempWallpaper('b.png');
      final settings = TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: '/tmp/legacy.png',
        homePageWallpaperAlignX: 0.8,
      );

      final next = settingsWithWallpaperHistoryEntry(
        settings,
        WallpaperHistoryEntry(key: path, alignX: 0.3, alignY: -0.7),
      );

      expect(next, isNotNull);
      expect(next!.homePageWallpaperPath, path);
      expect(next.homePageWallpaperAlignX, 0.3);
      expect(next.homePageWallpaperAlignY, -0.7);
    });

    test('缩放是取景的一部分，切回时一起还原', () {
      final path = createTempWallpaper('zoom.png');
      final next = settingsWithWallpaperHistoryEntry(
        TimetableSettings.defaults().copyWith(homePageWallpaperScale: 3),
        WallpaperHistoryEntry(key: path, scale: 1.6),
      );

      expect(next, isNotNull);
      expect(next!.homePageWallpaperScale, 1.6);
    });
  });

  group('WallpaperHistoryEntry 序列化', () {
    test('缩放会写进 JSON；存量数据没有这个键时读作 1', () {
      final json = const WallpaperHistoryEntry(
        key: '/tmp/a.png',
        alignX: 0.5,
        scale: 2.5,
      ).toJson();
      expect(json['scale'], 2.5);
      expect(WallpaperHistoryEntry.fromJson(json)!.scale, 2.5);

      // 存量存档（加缩放之前）没有 scale：缺省 1，观感与当时一致。
      final legacy = WallpaperHistoryEntry.fromJson(<String, Object?>{
        'key': '/tmp/a.png',
        'alignX': 0.5,
      });
      expect(legacy, isNotNull);
      expect(legacy!.scale, 1);
      // 坏值不许冒泡（会让整份设置被重置），一律回退默认。
      expect(
        WallpaperHistoryEntry.fromJson(<String, Object?>{
          'key': '/tmp/a.png',
          'scale': 'big',
        })!.scale,
        1,
      );
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
    test('空路径与遗留内置壁纸键安全跳过', () async {
      await deleteEvictedWallpaperFiles(['', 'builtin:ember_teal']);
    });
  });

  group('deletableWallpaperPaths', () {
    test('跳过空串与遗留内置壁纸键', () {
      expect(
        deletableWallpaperPaths([
          '',
          'builtin:ember_teal',
          '/img/keep.png',
        ]),
        ['/img/keep.png'],
      );
    });

    test('跳过"还有人在用"的路径（全局历史下别的课表的当前壁纸）', () {
      // 回归（2026-09-15 历史改成全局）：壁纸仍每个课表各自一张，某张图被全局
      // 历史淘汰 ≠ 没人用 —— 别的课表可能正拿它当壁纸，删了对方首页就缺图。
      expect(
        deletableWallpaperPaths(
          ['/img/evicted.png', '/img/other-profile.png'],
          inUsePaths: {'/img/other-profile.png'},
        ),
        ['/img/evicted.png'],
      );
    });
  });

  group('mergeWallpaperHistories', () {
    test('同 key 去重取 usedAt 更新者，并按最新在前排序', () {
      final merged = mergeWallpaperHistories([
        const [
          WallpaperHistoryEntry(key: '/old.png', alignX: 0.1, usedAt: 10),
          WallpaperHistoryEntry(key: '/shared.png', alignX: 0.2, usedAt: 20),
        ],
        const [
          WallpaperHistoryEntry(key: '/shared.png', alignX: 0.8, usedAt: 30),
          WallpaperHistoryEntry(key: '/new.png', usedAt: 40),
        ],
      ]);

      expect(merged.map((entry) => entry.key), [
        '/new.png',
        '/shared.png',
        '/old.png',
      ]);
      expect(merged[1].alignX, 0.8, reason: '同 key 取较新的那次对齐');
    });

    test('两条都缺 usedAt（老数据）时取后看到的那条，入参由旧到新', () {
      final merged = mergeWallpaperHistories([
        const [WallpaperHistoryEntry(key: '/a.png', alignX: 0.1)],
        const [WallpaperHistoryEntry(key: '/a.png', alignX: 0.9)],
      ]);

      expect(merged.length, 1);
      expect(merged.single.alignX, 0.9);
    });

    test('缺 usedAt 的老数据排在带 usedAt 的后面（保持各自阵营内的顺序）', () {
      final merged = mergeWallpaperHistories([
        const [
          WallpaperHistoryEntry(key: '/legacy-b.png'),
          WallpaperHistoryEntry(key: '/legacy-a.png'),
        ],
        const [WallpaperHistoryEntry(key: '/fresh.png', usedAt: 5)],
      ]);

      expect(merged.map((entry) => entry.key), [
        '/fresh.png',
        '/legacy-a.png',
        '/legacy-b.png',
      ]);
    });

    test('并集后仍按上限截断', () {
      final merged = mergeWallpaperHistories([
        [
          for (var i = 0; i < kMaxWallpaperHistoryEntries; i++)
            WallpaperHistoryEntry(key: '/a/$i.png', usedAt: i),
        ],
        [
          for (var i = 0; i < kMaxWallpaperHistoryEntries; i++)
            WallpaperHistoryEntry(key: '/b/$i.png', usedAt: 100 + i),
        ],
      ]);

      expect(merged.length, kMaxWallpaperHistoryEntries);
      expect(merged.first.key, '/b/${kMaxWallpaperHistoryEntries - 1}.png');
    });
  });
}
