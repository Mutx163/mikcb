import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/home_page_background.dart';

/// Generates a [width]x[height] PNG: top [topLightFraction] rows white,
/// the rest black.
Future<File> _writeStripedWallpaper(
  Directory dir, {
  int width = 100,
  int height = 100,
  double topLightFraction = 0.0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1000000, 1000000),
    Paint()..color = Colors.black,
  );
  final lightRows = (height * topLightFraction).round();
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), lightRows.toDouble()),
    Paint()..color = Colors.white,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/wallpaper.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}

Future<File> _writeHorizontalSplitWallpaper(Directory dir) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 200, 100),
    Paint()..color = Colors.black,
  );
  canvas.drawRect(
    const Rect.fromLTWH(100, 0, 100, 100),
    Paint()..color = Colors.white,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 100);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/horizontal-split-wallpaper.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}

Future<File> _writeSolidWallpaper(Directory dir, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1000000, 1000000),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 100);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/solid-wallpaper.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mikcb_lum_');
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // ignored
    }
  });

  test('missing path / missing file return null', () async {
    expect(await sampleHomePageWallpaperLuminanceBands(null), isNull);
    expect(
      await sampleHomePageWallpaperLuminanceBands('${dir.path}/nope.png'),
      isNull,
    );
  });

  test('all-black wallpaper: all three bands read dark', () async {
    final file = await _writeStripedWallpaper(dir);
    final bands = await sampleHomePageWallpaperLuminanceBands(file.path);
    expect(bands, isNotNull);
    expect(bands!.top, 0.0);
    expect(bands.weekday, 0.0);
    expect(bands.body, 0.0);
  });

  test('all-white wallpaper: all three bands read light', () async {
    final file = await _writeStripedWallpaper(dir, topLightFraction: 1);
    final bands = await sampleHomePageWallpaperLuminanceBands(file.path);
    expect(bands, isNotNull);
    expect(bands!.top, 1.0);
    expect(bands.weekday, 1.0);
    expect(bands.body, 1.0);
  });

  test(
    'mid-tone wallpaper matches Color.computeLuminance color space',
    () async {
      final file = await _writeSolidWallpaper(dir, const Color(0xFF808080));
      final bands = await sampleHomePageWallpaperLuminanceBands(file.path);
      expect(bands, isNotNull);
      final expected = const Color(0xFF808080).computeLuminance();
      expect(bands!.top, closeTo(expected, 0.01));
      expect(bands.weekday, closeTo(expected, 0.01));
      expect(bands.body, closeTo(expected, 0.01));
    },
  );

  test('cover sampling follows horizontal crop alignment', () async {
    final file = await _writeHorizontalSplitWallpaper(dir);
    final left = await sampleHomePageWallpaperLuminanceBands(
      file.path,
      viewportSize: const Size(100, 100),
      alignX: -1,
    );
    final right = await sampleHomePageWallpaperLuminanceBands(
      file.path,
      viewportSize: const Size(100, 100),
      alignX: 1,
    );
    expect(left, isNotNull);
    expect(right, isNotNull);
    expect(left!.top, lessThan(0.01));
    expect(right!.top, greaterThan(0.99));
    expect(left.body, lessThan(0.01));
    expect(right.body, greaterThan(0.99));
  });

  test('light strip only at the very top: weekday band reads dark', () async {
    // Top 12% white, the rest black — a sky/ground photo. The status/title
    // strip (top 9%) sits on the sky, but the weekday chrome bar (7–20%)
    // already straddles into the dark ground; the two bands must differ so
    // each region gets its own ink polarity. (The 64×64 decode blends the
    // boundary rows, so assert the polarity, not exact row math.)
    final file = await _writeStripedWallpaper(dir, topLightFraction: 0.12);
    final bands = await sampleHomePageWallpaperLuminanceBands(file.path);
    expect(bands, isNotNull);
    expect(bands!.top, 1.0);
    expect(bands.weekday, lessThan(0.45));
    expect(bands.weekday, greaterThan(0.3));
    expect(bands.body, 0.0);
  });

  test('top band narrows to the status/title strip (not 22%)', () async {
    // 15% light: the old 0–22% top band would average 15/22 ≈ 0.68 (light);
    // the narrowed status/title band stays fully light, while the weekday
    // band below it reads mostly light too but from its own rows.
    final file = await _writeStripedWallpaper(dir, topLightFraction: 0.15);
    final bands = await sampleHomePageWallpaperLuminanceBands(file.path);
    expect(bands, isNotNull);
    expect(bands!.top, 1.0);
    expect(bands.weekday, greaterThan(0.45));
    expect(bands.weekday, lessThan(0.75));
  });

  test('light wallpaper uses dark status-bar icons in a light theme', () {
    final background = resolveHomePageStatusBarBackground(
      pageBackground: const Color(0xFFF8FAFC),
      statusBarShowsBackdrop: true,
      hasBackdrop: true,
      isDark: false,
      usesFrostedChrome: true,
      wallpaperTopLuminance: 1,
    );

    final style = SystemUiOverlayStyle(
      statusBarColor: background,
      statusBarIconBrightness: background.computeLuminance() > 0.5
          ? Brightness.dark
          : Brightness.light,
    );
    expect(style.statusBarIconBrightness, Brightness.dark);
  });

  test('unsampled light-theme wallpaper does not default to white icons', () {
    final background = resolveHomePageStatusBarBackground(
      pageBackground: const Color(0xFFF8FAFC),
      statusBarShowsBackdrop: true,
      hasBackdrop: true,
      isDark: false,
      usesFrostedChrome: true,
      wallpaperTopLuminance: null,
    );

    expect(background.computeLuminance(), greaterThan(0.5));
  });

  // ── 状态栏图标极性：分界点是"黑白对比度相等"那一点（2026-10-21 P0-3）──
  //
  // 旧实现用 0.5，于是 0.179~0.5 这一整段都配白图标，而白图标在那一段恰恰是
  // 差的那一档：真机截图顶部带平均 0.356 → 判白图标，在右侧亮云（局部 0.738）
  // 上实测 1.33:1，5G / 信号 / 电量整排读不出来。
  group('状态栏图标极性：黑白对比度相等点（0.179）', () {
    /// 期望值按公式自己算，不复用被测实现。
    double contrastOf(Color ink, double backgroundLuminance) {
      final hi = ink.computeLuminance() > backgroundLuminance
          ? ink.computeLuminance()
          : backgroundLuminance;
      final lo = ink.computeLuminance() > backgroundLuminance
          ? backgroundLuminance
          : ink.computeLuminance();
      return (hi + 0.05) / (lo + 0.05);
    }

    Brightness iconsFor(double luminance) {
      final background = resolveHomePageStatusBarBackground(
        pageBackground: const Color(0xFFF8FAFC),
        statusBarShowsBackdrop: true,
        hasBackdrop: true,
        isDark: false,
        usesFrostedChrome: true,
        wallpaperTopLuminance: luminance,
      );
      return background.computeLuminance() > 0.5
          ? Brightness.dark
          : Brightness.light;
    }

    test('0.356 的顶部带必须配黑图标（旧实现配白图标，实测 2.59:1）', () {
      expect(
        iconsFor(0.356),
        Brightness.dark,
        reason: '0.356 处白图标只有 2.59:1、黑图标 8.12:1 —— 必须选黑',
      );
    });

    test('每一个采样亮度下都选对比度更高的那一档', () {
      for (final luminance in <double>[
        0.05,
        0.12,
        0.18,
        0.25,
        0.36,
        0.45,
        0.55,
        0.70,
      ]) {
        final icons = iconsFor(luminance);
        final ink = icons == Brightness.dark ? Colors.black : Colors.white;
        final other = icons == Brightness.dark ? Colors.white : Colors.black;
        expect(
          contrastOf(ink, luminance),
          greaterThanOrEqualTo(contrastOf(other, luminance)),
          reason: '亮度 $luminance 下选了对比度更差的那一档图标',
        );
      }
    });

    test('分界点两侧都必须过 4.5:1（不会在两个方向都留暗区）', () {
      for (final luminance in <double>[0.17, 0.19]) {
        final icons = iconsFor(luminance);
        final ink = icons == Brightness.dark ? Colors.black : Colors.white;
        expect(
          contrastOf(ink, luminance),
          greaterThanOrEqualTo(4.5),
          reason: '黑白对比度相等点附近两者都应是 4.58:1 —— 低于 4.5 说明分界点算错了',
        );
      }
    });
  });
}
