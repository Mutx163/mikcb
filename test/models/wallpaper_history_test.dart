import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
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
      final entry = WallpaperHistoryEntry.fromJson({'key': '/data/a.png'});

      expect(entry, isNotNull);
      expect(entry!.key, '/data/a.png');
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

    test('数字字段类型错误时不得抛错（不得放大成整份设置丢失）', () {
      // 回归：此前用 `raw['alignX'] as num?`，遇到字符串会抛 TypeError。这条
      // 异常会一路冒到 TimetableSettings.fromJson（该处无 try/catch），被
      // TimetableProfile.fromJsonLenient 捕获后**把整份课表设置重置为默认**——
      // 单个坏值放大成整份设置丢失，与「脏条目逐条丢弃」的承诺直接矛盾。
      // 现改为 `is num` 判断：非法类型当缺失处理，回退默认值。
      final entry = WallpaperHistoryEntry.fromJson(<String, Object?>{
        'key': '/a.png',
        'alignX': '0.5',
        'alignY': 'oops',
        'usedAt': 'ten',
      });
      expect(entry, isNotNull);
      expect(entry!.alignX, 0);
      expect(entry.alignY, 0);
      expect(entry.usedAt, 0);

      // 同一份脏 JSON 走**完整设置**解析路径也不许抛，且好条目要保住。
      final settings = TimetableSettings.fromJson(<String, dynamic>{
        'wallpaperHistory': <Object?>[
          <String, Object?>{'key': '/a.png', 'alignX': '0.5', 'usedAt': 'ten'},
          <String, Object?>{'key': '/b.png', 'alignX': 0.5, 'usedAt': 7},
        ],
      });
      expect(settings.wallpaperHistory.map((e) => e.key), ['/a.png', '/b.png']);
      expect(settings.wallpaperHistory.last.alignX, 0.5);
      expect(settings.wallpaperHistory.last.usedAt, 7);
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
