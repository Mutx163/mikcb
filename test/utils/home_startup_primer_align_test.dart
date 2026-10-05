import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/utils/home_startup_visual_primer.dart';

/// 回归钉（第二十三轮，启动预热的亮度带没有按用户取景采样）：
///
/// `HomeStartupVisualPrimer.prime`（home_startup_visual_primer.dart:87-90）调
/// `sampleHomePageBackdropLuminanceBands(settings, viewportSize: …)` 时
/// **不传 `alignX` / `alignY`**，于是预热拿到的是「居中取景」那条带的亮度；
/// 而同一个函数（home_page_background.dart:936-951）的注释写明它的三个调用点
/// 「本来就该按**当前取景**采样，多一个参数只会有人漏传」—— 正因为这个道理，
/// `scale` 才改成不发参数、直接读 settings。偏偏 `align` 这一对**就是被漏传了**。
///
/// 消费方是首页自己：`_seedWallpaperLuminanceFromStartupPrimer`
/// （timetable_screen.dart:2273-2289）把这份种子直接写成
/// `_wallpaperTopLuminance` / `_wallpaperWeekdayLuminance` /
/// `_wallpaperBodyLuminance`（顶栏与状态栏图标的墨色极性），而本页的精确采样
/// 用的是 `_wallpaperLuminanceKey`（:2358-2366，键里含 alignX/alignY），注释里
/// 的理由正是「so a cover crop change cannot keep using a sample from an
/// **off-screen part of the image**」。也就是说种子值可以来自一张**根本不在这屏上**的带，
/// 首帧按它定极性，精确采样落地后再硬翻一次 —— 恰好是预热声称要消掉的那一下
/// （取景页 `wallpaper_position_picker_sheet.dart:286-291` 承认这个近似，因为它有
/// 渐变纠正；首页 chrome 没有）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 左右对半的壁纸：左白右黑。cover 进 4:3 视口时横向有裁切量，
  /// 于是 alignX 贴前缘（-1）读到的是白侧、贴后缘（+1）是黑侧。
  Future<File> writeSplitWallpaper(Directory dir, String name) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 100),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      const Rect.fromLTWH(100, 0, 100, 100),
      Paint()..color = Colors.black,
    );
    final image = await recorder.endRecording().toImage(200, 100);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file;
  }

  TimetableSettings settingsFor(String path, double alignX) =>
      TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: path,
        homePageWallpaperAlignX: alignX,
      );

  /// 与 `_viewportSize()` 同源：物理尺寸 / devicePixelRatio。
  Size testViewport() {
    final view = ui.PlatformDispatcher.instance.views.first;
    return view.physicalSize / view.devicePixelRatio;
  }

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mikcb-primer-align-');
  });
  tearDown(() async {
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  test('预热亮度带跟随 alignX，而不是永远按居中采样', () async {
    final left = await writeSplitWallpaper(dir, 'left.png');
    final right = await writeSplitWallpaper(dir, 'right.png');

    await HomeStartupVisualPrimer.prime(settingsFor(left.path, -1));
    final seededLeft = HomeStartupVisualPrimer.seededBandsFor(left.path);
    await HomeStartupVisualPrimer.prime(settingsFor(right.path, 1));
    final seededRight = HomeStartupVisualPrimer.seededBandsFor(right.path);

    expect(seededLeft, isNotNull);
    expect(seededRight, isNotNull);
    // 修复前：两处都不传 align，得到的是同一张「居中裁切」的带 → 完全相等。
    expect(
      seededLeft!.top,
      isNot(seededRight!.top),
      reason: '同一张左白右黑的壁纸，贴左缘与贴右缘不可能读到同一条带',
    );
    expect(seededLeft.top, greaterThan(0.5), reason: '贴左缘应读到白侧');
    expect(seededRight.top, lessThan(0.5), reason: '贴右缘应读到黑侧');
  });

  test('预热的种子与首页精确采样同源同值', () async {
    final file = await writeSplitWallpaper(dir, 'same.png');
    final settings = settingsFor(file.path, 1);

    await HomeStartupVisualPrimer.prime(settings);
    final seeded = HomeStartupVisualPrimer.seededBandsFor(file.path);
    expect(seeded, isNotNull);

    final precise = await sampleHomePageBackdropLuminanceBands(
      settings,
      viewportSize: testViewport(),
      alignX: settings.homePageWallpaperAlignX,
      alignY: settings.homePageWallpaperAlignY,
    );
    expect(precise, isNotNull);

    expect(seeded!.top, precise!.top, reason: '种子必须是本页取景下的那条带');
    expect(seeded.weekday, precise.weekday);
    expect(seeded.body, precise.body);
  });
}
