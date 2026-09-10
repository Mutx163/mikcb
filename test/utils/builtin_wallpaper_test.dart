import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/background/builtin_wallpaper.dart';
import 'package:university_timetable/utils/home_page_background.dart';

void main() {
  group('BuiltInWallpaper 主键', () {
    test('value 与枚举一一对应且可回读', () {
      for (final item in BuiltInWallpaper.values) {
        expect(BuiltInWallpaper.fromValue(item.value), item);
      }
    });

    test('未知 / 空值返回 null', () {
      expect(BuiltInWallpaper.fromValue(null), isNull);
      expect(BuiltInWallpaper.fromValue(''), isNull);
      expect(BuiltInWallpaper.fromValue('nope'), isNull);
    });
  });

  group('homePageBackdropKey', () {
    test('无背景返回 null', () {
      expect(homePageBackdropKey(const TimetableSettings(sections: [])), isNull);
    });

    test('内置壁纸返回 builtin: 前缀键', () {
      final settings = const TimetableSettings(
        sections: [],
      ).copyWith(homePageBuiltInWallpaper: BuiltInWallpaper.lavaDark.value);
      expect(homePageBackdropKey(settings), 'builtin:lava_dark');
    });

    test('图片文件缺失时回退到内置壁纸', () {
      final settings = const TimetableSettings(sections: []).copyWith(
        homePageBuiltInWallpaper: BuiltInWallpaper.lavaDark.value,
        homePageWallpaperPath: '/definitely/missing/x.png',
      );
      expect(homePageBackdropKey(settings), 'builtin:lava_dark');
    });

    test('图片存在时优先于内置壁纸', () async {
      final dir = await Directory.systemTemp.createTemp('builtin_wp');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/wall.png');
      await file.writeAsBytes(const [0, 0, 0, 0]);
      final settings = const TimetableSettings(sections: []).copyWith(
        homePageBuiltInWallpaper: BuiltInWallpaper.lavaDark.value,
        homePageWallpaperPath: file.path,
      );
      expect(homePageBackdropKey(settings), file.path);
    });
  });

  group('hasHomePageBackdrop', () {
    test('内置壁纸参与背景判定（无磁盘文件）', () {
      final settings = const TimetableSettings(
        sections: [],
      ).copyWith(homePageBuiltInWallpaper: BuiltInWallpaper.emberTeal.value);
      expect(hasHomePageBackdropImage(settings), isFalse);
      expect(hasHomePageBackdrop(settings), isTrue);
      expect(homePageBackdropProvider(settings), isA<BuiltInWallpaperImage>());
    });

    test('未选择时既无图片也无内置背景', () {
      const settings = TimetableSettings(sections: []);
      expect(hasHomePageBackdrop(settings), isFalse);
      expect(homePageBackdropProvider(settings), isNull);
    });
  });

  group('内置壁纸预设参数', () {
    test('完整移植原包 7 个预设（含历史主键）', () {
      expect(BuiltInWallpaper.values, hasLength(7));
      // 历史用户数据里的三个 key 必须继续可回读。
      expect(BuiltInWallpaper.fromValue('lava_dark'), BuiltInWallpaper.lavaDark);
      expect(BuiltInWallpaper.fromValue('lava_light'), BuiltInWallpaper.lavaLight);
      expect(
        BuiltInWallpaper.fromValue('ember_teal'),
        BuiltInWallpaper.emberTeal,
      );
    });

    test('深色预设极性为 dark、浅色预设为 light', () {
      const dark = {
        BuiltInWallpaper.og,
        BuiltInWallpaper.dark1,
        BuiltInWallpaper.lavaDark,
        BuiltInWallpaper.emberTeal,
      };
      const light = {
        BuiltInWallpaper.lavaLight,
        BuiltInWallpaper.light2,
        BuiltInWallpaper.light3,
      };
      for (final item in dark) {
        expect(
          builtInWallpaperSpec(item).brightness,
          Brightness.dark,
          reason: '${item.value} 应为深色',
        );
      }
      for (final item in light) {
        expect(
          builtInWallpaperSpec(item).brightness,
          Brightness.light,
          reason: '${item.value} 应为浅色',
        );
      }
    });

    test('每个预设都有非空调色板与合法不透明度', () {
      for (final item in BuiltInWallpaper.values) {
        final spec = builtInWallpaperSpec(item);
        expect(spec.colors, isNotEmpty);
        expect(spec.opacity, inInclusiveRange(0.0, 1.0));
        expect(spec.blobCount, greaterThan(0));
        expect(spec.minBlobRadius, lessThanOrEqualTo(spec.maxBlobRadius));
        expect(spec.speed, greaterThan(0));
      }
    });
  });

  group('渲染与亮度采样', () {
    testWidgets('渲染出的位图尺寸符合约定', (tester) async {
      final image = await tester.runAsync(
        () => renderBuiltInWallpaperImage(
          BuiltInWallpaper.lavaDark,
          width: 64,
          height: 128,
        ),
      );
      expect(image!.width, 64);
      expect(image.height, 128);
      image.dispose();
    });

    testWidgets('同一预设两次渲染像素一致（可播种、无随机漂移）', (tester) async {
      Future<List<int>> pixels() async {
        final image = await renderBuiltInWallpaperImage(
          BuiltInWallpaper.emberTeal,
          width: 32,
          height: 32,
        );
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List().toList();
      }

      final a = await tester.runAsync(pixels);
      final b = await tester.runAsync(pixels);
      expect(a, b);
    });

    testWidgets('顶部亮度采样返回 0-1 之间的值', (tester) async {
      // 小尺寸渲染：全尺寸 720×1600 高斯模糊在测试环境会拖到超时。
      final dark = (await tester.runAsync(
        () => sampleBuiltInWallpaperTopLuminance(
          BuiltInWallpaper.lavaDark,
          width: 64,
          height: 96,
        ),
      ))!;
      expect(dark, inInclusiveRange(0.0, 1.0));

      final light = (await tester.runAsync(
        () => sampleBuiltInWallpaperTopLuminance(
          BuiltInWallpaper.lavaLight,
          width: 64,
          height: 96,
        ),
      ))!;
      // 浅色预设应当比近黑底的深色预设更亮，保证自动墨色极性正确。
      expect(light, greaterThan(dark));
    });

    testWidgets('背景亮度带入口支持内置壁纸', (tester) async {
      final settings = const TimetableSettings(
        sections: [],
      ).copyWith(homePageBuiltInWallpaper: BuiltInWallpaper.lavaLight.value);
      final bands = await tester.runAsync(
        () => sampleHomePageBackdropLuminanceBands(settings),
      );
      expect(bands, isNotNull);
      expect(bands!.top, inInclusiveRange(0.0, 1.0));
      expect(bands.weekday, inInclusiveRange(0.0, 1.0));
      expect(bands.body, inInclusiveRange(0.0, 1.0));
    });

    testWidgets('无背景时亮度带为 null', (tester) async {
      const settings = TimetableSettings(sections: []);
      expect(await sampleHomePageBackdropLuminanceBands(settings), isNull);
    });
  });

  group('设置持久化', () {
    test('内置壁纸随设置序列化并可回读', () {
      final settings = const TimetableSettings(
        sections: [],
      ).copyWith(homePageBuiltInWallpaper: BuiltInWallpaper.lavaLight.value);
      final restored = TimetableSettings.fromJson(settings.toJson());
      expect(restored.homePageBuiltInWallpaper, 'lava_light');
      expect(resolveBuiltInWallpaper(restored), BuiltInWallpaper.lavaLight);
    });

    test('clear 标志可清空内置壁纸', () {
      final settings = const TimetableSettings(
        sections: [],
      ).copyWith(homePageBuiltInWallpaper: BuiltInWallpaper.lavaDark.value);
      final cleared = settings.copyWith(clearHomePageBuiltInWallpaper: true);
      expect(cleared.homePageBuiltInWallpaper, isNull);
    });

    test('旧数据缺 key 时为 null（无迁移）', () {
      final json = const TimetableSettings(sections: []).toJson()
        ..remove('homePageBuiltInWallpaper');
      expect(
        TimetableSettings.fromJson(json).homePageBuiltInWallpaper,
        isNull,
      );
    });
  });
}
