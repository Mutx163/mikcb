import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/wallpaper_history.dart';

void main() {
  group('WallpaperHistoryEntry', () {
    test('json 往返保持全部字段', () {
      const entry = WallpaperHistoryEntry(
        key: '/data/home_page_wallpaper/wallpaper_1.jpg',
        alignX: -0.5,
        alignY: 0.25,
        usedAt: 1700000000000,
      );

      expect(WallpaperHistoryEntry.fromJson(entry.toJson()), entry);
    });

    test('缺少可选字段时回到默认值', () {
      final entry = WallpaperHistoryEntry.fromJson({'key': 'builtin:og'});

      expect(entry, isNotNull);
      expect(entry!.key, 'builtin:og');
      expect(entry.alignX, 0);
      expect(entry.alignY, 0);
      expect(entry.usedAt, 0);
    });

    test('脏条目逐条丢弃而不是抛错', () {
      expect(WallpaperHistoryEntry.fromJson(null), isNull);
      expect(WallpaperHistoryEntry.fromJson('nope'), isNull);
      expect(WallpaperHistoryEntry.fromJson(<String, Object?>{}), isNull);
      expect(WallpaperHistoryEntry.fromJson({'key': 42}), isNull);
      expect(WallpaperHistoryEntry.fromJson({'key': '   '}), isNull);

      expect(
        WallpaperHistoryEntry.listFromJson([
          {'key': '/a.png'},
          null,
          'x',
          {'key': ''},
          {'key': '/b.png', 'alignX': 1, 'alignY': -1, 'usedAt': 5},
        ]),
        const [
          WallpaperHistoryEntry(key: '/a.png'),
          WallpaperHistoryEntry(key: '/b.png', alignX: 1, alignY: -1, usedAt: 5),
        ],
      );
    });

    test('listFromJson 非列表输入返回空表', () {
      expect(WallpaperHistoryEntry.listFromJson(null), isEmpty);
      expect(WallpaperHistoryEntry.listFromJson({'key': 'x'}), isEmpty);
    });

    test('copyWith 只改指定字段', () {
      const entry = WallpaperHistoryEntry(
        key: '/a.png',
        alignX: 0.25,
        alignY: 0.5,
        usedAt: 7,
      );

      final updated = entry.copyWith(alignY: -0.5);

      expect(updated.key, '/a.png');
      expect(updated.alignX, 0.25);
      expect(updated.alignY, -0.5);
      expect(updated.usedAt, 7);
    });
  });
}
