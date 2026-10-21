import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/wallpaper_luminance_profile.dart';
import 'package:university_timetable/widgets/timetable/day_view/day_view_ink_style.dart';

/// 日视图判色的**接线**契约：`dayAgendaAutoInk` 必须使用调用方传进来的真实
/// 染色比例，而不是自己回落到出厂常数。
///
/// 为什么单独一条：纯函数 `cardSurfaceInk` 的测试无论传什么 washAlpha 都成立，
/// 所以「widget 层有没有把真实值传下去」它抓不到。2026-10-21 实测（浅色主题 +
/// 水墨夜景壁纸）卡面有效染色只有 ~3%，出厂常数是 42%~70%，两者在同一张壁纸上
/// 会给出**相反**的黑白结论 —— 传不传这个参数，真机结果完全不同。
///
/// ⚠️ 本文件必须**造一个真实存在的壁纸文件**：`hasHomePageBackdrop` 会检查
/// 文件存在，不存在时玻璃档被降级成实体卡（恒白字），整份用例就变成永远绿的
/// 摆设。这条坑第一次写这个测试时踩过。
///
/// 咬合探针：把 `dayAgendaAutoInk` 里的 `washAlpha ?? _default...` 改成
/// 无条件 `_default...`（忽略调用方），本文件必须变红。
void main() {
  late Directory tempDir;
  late String wallpaperPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mikcb_ink_wiring_');
    final file = File('${tempDir.path}/wallpaper.png');
    // 内容无所谓：判色只读 settings 里的路径是否存在，不解码这张图。
    file.writeAsBytesSync(const <int>[0x89, 0x50, 0x4E, 0x47]);
    wallpaperPath = file.path;
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // ignored
    }
  });

  // 玻璃档 + 有壁纸：只有这段才走「卡面 × 染色 + 壁纸」的合成判据。
  TimetableSettings glassSettings() {
    return TimetableSettings.defaults().copyWith(
      courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
      homePageWallpaperPath: wallpaperPath,
    );
  }

  DayViewInkEnvironment envWith(double wallpaperLuminance) {
    return DayViewInkEnvironment(
      backdropBlurOn: true,
      wallpaperBodyLuminance: wallpaperLuminance,
      wallpaperTopLuminance: wallpaperLuminance,
    );
  }

  group('前置：确实进了玻璃档（否则整份用例是摆设）', () {
    test('有壁纸文件 + 玻璃档 → 卡面不是实体档', () {
      final settings = glassSettings();
      expect(settings.homePageWallpaperPath, wallpaperPath);
      // 用"实体卡恒白字"这条已知行为反证：如果不是实体档，传黑色底也会被判色。
      final asGlass = dayAgendaAutoInk(
        const Color(0xFF000000),
        settings: settings,
        env: envWith(0.9),
        washAlpha: 0.42,
      );
      expect(
        asGlass,
        isNot(Colors.white),
        reason: '黑底 × 42% 压亮壁纸 → 应当是黑字；若返回白字，'
            '说明被降级成实体档了，后面的用例都不作数',
      );
    });
  });

  group('dayAgendaAutoInk 必须使用调用方给的真实染色比例', () {
    test('实测染色 3% + 近黑壁纸 → 白字', () {
      final ink = dayAgendaAutoInk(
        const Color(0xFFFFFFFF), // 浅色主题的主题卡面
        settings: glassSettings(),
        env: envWith(0.05),
        washAlpha: 0.03, // 真机反推出来的有效染色
      );
      expect(ink, Colors.white, reason: '3% 染色时卡面很暗，必须是白字');
    });

    test('同一场景若忽略调用方、用出厂常数 42% → 黑字（结论相反，证明参数在用）', () {
      final withDefault = dayAgendaAutoInk(
        const Color(0xFFFFFFFF),
        settings: glassSettings(),
        env: envWith(0.05),
      );
      // 42% 染色时卡面 = 1.0×0.42 + 0.05×0.58 = 0.449 → 黑字更优。
      expect(
        withDefault,
        isNot(Colors.white),
        reason: '出厂常数会判成黑字；若这里也是白字，说明 washAlpha 参数'
            '根本没被使用（接线断了）',
      );
      final real = dayAgendaAutoInk(
        const Color(0xFFFFFFFF),
        settings: glassSettings(),
        env: envWith(0.05),
        washAlpha: 0.03,
      );
      expect(real, isNot(withDefault), reason: '传与不传必须给出不同结论');
    });
  });

  group('不是玻璃档时不跟壁纸走', () {
    test('实体卡恒为白字', () {
      final settings = TimetableSettings.defaults().copyWith(
        courseCardSurfaceStyle: CourseCardSurfaceStyle.solid,
        homePageWallpaperPath: wallpaperPath,
      );
      final ink = dayAgendaAutoInk(
        const Color(0xFF90CAF9),
        settings: settings,
        env: const DayViewInkEnvironment(backdropBlurOn: false),
        washAlpha: 1,
      );
      expect(ink, Colors.white, reason: '实体卡是课程色实底，白字是既有口径');
    });
  });

  group('局部亮度优先于整屏带', () {
    test('有逐行剖面 + 卡片矩形时，用它那一格而不是 body 带', () {
      // body 带故意给很亮的 0.9（整屏平均），而卡片所在的底部是近黑 0.02。
      // 若实现忽略局部剖面，就会按 0.9 判成黑字（错）；正确应给白字。
      final profile = WallpaperLuminanceProfile(
        rowLuminances: List<double>.generate(100, (i) => i < 60 ? 0.9 : 0.02),
      );
      final env = DayViewInkEnvironment(
        backdropBlurOn: true,
        wallpaperBodyLuminance: 0.9,
        wallpaperTopLuminance: 0.9,
        profile: profile,
        screenHeight: 1000,
      );
      final ink = dayAgendaAutoInk(
        const Color(0xFFFFFFFF),
        settings: glassSettings(),
        env: env,
        cardRect: const Rect.fromLTWH(0, 800, 400, 150), // 屏高 80%~95%
        washAlpha: 0.03,
      );
      expect(ink, Colors.white, reason: '卡片在近黑区域，必须按局部亮度判');
    });

    test('没有剖面时回落到整屏带（同一张卡会判成黑字）', () {
      const env = DayViewInkEnvironment(
        backdropBlurOn: true,
        wallpaperBodyLuminance: 0.9,
        wallpaperTopLuminance: 0.9,
      );
      final ink = dayAgendaAutoInk(
        const Color(0xFFFFFFFF),
        settings: glassSettings(),
        env: env,
        cardRect: const Rect.fromLTWH(0, 800, 400, 150),
        washAlpha: 0.03,
      );
      expect(
        ink,
        isNot(Colors.white),
        reason: '没有剖面就只能按整屏 0.9 判 —— 这正说明剖面在起作用',
      );
    });
  });
}
