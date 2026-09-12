import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/background/builtin_wallpaper.dart';
import 'package:university_timetable/utils/home_page_background.dart';

void main() {
  group('effectiveCourseCardSurfaceStyle', () {
    test('no wallpaper: gaussian falls back to solid', () {
      final settings = TimetableSettings.defaults().copyWith(
        courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
      );
      expect(
        effectiveCourseCardSurfaceStyle(settings),
        CourseCardSurfaceStyle.solid,
      );
    });

    test('no wallpaper: solid stays solid', () {
      final settings = TimetableSettings.defaults().copyWith(
        courseCardSurfaceStyle: CourseCardSurfaceStyle.solid,
      );
      expect(
        effectiveCourseCardSurfaceStyle(settings),
        CourseCardSurfaceStyle.solid,
      );
    });

    test('built-in wallpaper: user switch is respected (gaussian)', () {
      final settings = TimetableSettings.defaults().copyWith(
        homePageBuiltInWallpaper: BuiltInWallpaper.og.value,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
      );
      expect(
        effectiveCourseCardSurfaceStyle(settings),
        CourseCardSurfaceStyle.gaussian,
      );
    });

    test('built-in wallpaper: user switch is respected (solid)', () {
      final settings = TimetableSettings.defaults().copyWith(
        homePageBuiltInWallpaper: BuiltInWallpaper.og.value,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.solid,
      );
      expect(
        effectiveCourseCardSurfaceStyle(settings),
        CourseCardSurfaceStyle.solid,
      );
    });

    test(
      'wallpaper file missing: treated as no wallpaper, falls back solid',
      () {
        final settings = TimetableSettings.defaults().copyWith(
          homePageWallpaperPath: '/definitely/not/a/real/file.png',
          courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
        );
        expect(
          effectiveCourseCardSurfaceStyle(settings),
          CourseCardSurfaceStyle.solid,
        );
      },
    );

    test('wallpaper file exists: gaussian applies', () async {
      final dir = await Directory.systemTemp.createTemp('effective_style_test');
      final file = File('${dir.path}/wall.png')..writeAsBytesSync([1, 2, 3, 4]);
      addTearDown(() => dir.deleteSync(recursive: true));
      final settings = TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: file.path,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
      );
      expect(
        effectiveCourseCardSurfaceStyle(settings),
        CourseCardSurfaceStyle.gaussian,
      );
    });

    test(
      'blur pipeline unavailable: gaussian falls back to solid even with wallpaper',
      () {
        // 全局材质「实体卡片」= 模糊总开关关（或系统降级）：高斯档寄生在
        // 全局模糊管线上，管线关闭后只剩裸 tint 过壁纸（读作透明卡片），
        // 必须随管线一起回落实体卡，墨色规则同源切换。
        final settings = TimetableSettings.defaults().copyWith(
          homePageBuiltInWallpaper: BuiltInWallpaper.og.value,
          courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
        );
        expect(
          effectiveCourseCardSurfaceStyle(
            settings,
            gaussianBlurAvailable: false,
          ),
          CourseCardSurfaceStyle.solid,
        );
      },
    );

    test('blur pipeline unavailable: solid stays solid', () {
      final settings = TimetableSettings.defaults().copyWith(
        homePageBuiltInWallpaper: BuiltInWallpaper.og.value,
        courseCardSurfaceStyle: CourseCardSurfaceStyle.solid,
      );
      expect(
        effectiveCourseCardSurfaceStyle(settings, gaussianBlurAvailable: false),
        CourseCardSurfaceStyle.solid,
      );
    });
  });
}
