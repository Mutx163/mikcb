import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/home_page_background.dart';

/// 回归钉（第二十三轮，首页背景预缓存漏掉 dart:ui 要求的那次 `dispose`）：
///
/// `precacheHomePageBackdropImage`（home_page_background.dart:96-129）就是框架
/// `precacheImage`（`flutter/lib/src/widgets/image.dart:130-142`）的手写副本，
/// 但少了框架在帧末做的那一句 `image?.dispose()`：监听回调里只做了
/// `completer.complete()` 与 `stream.removeListener(listener)`。
///
/// 这不是"风格问题"：`ImageStreamCompleter` 每次投递给监听方的都是
/// `_currentImage!.clone()`（`flutter/lib/src/widgets/image_stream.dart:539`），
/// 而 dart:ui 的契约写在 `sky_engine/lib/ui/painting.dart:2016-2025` ——
/// "Once all outstanding handles have been disposed, the underlying image will
/// be disposed as well"，即**每个 clone 句柄都必须自己 dispose**。漏掉的那一句
/// 使每次预缓存都留下一个永不释放的解码位图句柄：`ImageCache` 的清理与
/// `evictHomePageImageCache` 都放不掉这张像素（引用计数还挂着）。
///
/// 同一份契约在本仓是被明确认识到的：`preblurred_wallpaper_glass.dart:150-160`
/// 与 `home_startup_visual_primer.dart:95-96` 的注释都在讲"克隆句柄即刻释放"，
/// 所以这里是漏写而不是刻意。
///
/// 可达性：`precacheHomePageBackdropImage` 有四个调用点 ——
/// `home_startup_visual_primer.dart:93`（启动预热）、`timetable_provider.dart:806`
/// （启动）、`timetable_provider.dart:3872` 与 `settings_appearance_editor.dart:461`
/// （每次换壁纸）。release 包同样执行（这条链没有 `kReleaseMode` 门）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<File> writeWallpaper(Directory dir, String name) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = Colors.teal,
    );
    final image = await recorder.endRecording().toImage(64, 64);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file;
  }

  /// 自己占一个句柄挂在同一个 provider 上：`debugGetOpenHandleStackTraces()`
  /// 报的是**同一张底层位图**上所有未释放句柄（painting.dart:2099-2106 走的是
  /// `_image._handles`），所以这样能数到别人漏放的那一个。
  Future<ImageInfo> holdAHandle(ImageProvider provider) {
    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(ImageConfiguration.empty);
    stream.addListener(
      ImageStreamListener((info, _) {
        if (!completer.isCompleted) {
          completer.complete(info);
        }
      }),
    );
    return completer.future;
  }

  test('预缓存首页背景后，解码句柄数回到预缓存之前的水平', () async {
    final dir = await Directory.systemTemp.createTemp('mikcb-precache-leak-');
    addTearDown(() => dir.delete(recursive: true));
    final file = await writeWallpaper(dir, 'wallpaper.png');
    final settings = TimetableSettings.defaults().copyWith(
      homePageWallpaperPath: file.path,
    );

    final provider = homePageBackdropProvider(settings);
    expect(provider, isNotNull, reason: '壁纸文件存在时应给出可用 provider');
    final held = await holdAHandle(provider!);
    final before = held.image.debugGetOpenHandleStackTraces()!.length;

    await precacheHomePageBackdropImage(settings);
    // 释放发生在监听回调内（与原先 `removeListener` 同一时序），不需要等帧；
    // 这里过一次微任务只是让 ImageCache 的投递彻底落定。
    await Future<void>.delayed(Duration.zero);

    final after = held.image.debugGetOpenHandleStackTraces()!.length;
    expect(
      after,
      before,
      reason: '每调用一次预缓存就多留一个永不释放的解码句柄（$before -> $after）',
    );

    held.image.dispose();
  });

  test('反复换壁纸不会让上一张图的句柄越积越多', () async {
    final dir = await Directory.systemTemp.createTemp('mikcb-precache-two-');
    addTearDown(() => dir.delete(recursive: true));
    final first = await writeWallpaper(dir, 'first.png');
    final second = await writeWallpaper(dir, 'second.png');

    final firstSettings = TimetableSettings.defaults().copyWith(
      homePageWallpaperPath: first.path,
    );
    final firstProvider = homePageBackdropProvider(firstSettings)!;
    final heldFirst = await holdAHandle(firstProvider);
    final before = heldFirst.image.debugGetOpenHandleStackTraces()!.length;

    // 三次预缓存同一张 + 一次切到另一张：第一张图上的句柄不该增长。
    await precacheHomePageBackdropImage(firstSettings);
    await precacheHomePageBackdropImage(firstSettings);
    await precacheHomePageBackdropImage(firstSettings);
    await precacheHomePageBackdropImage(
      firstSettings.copyWith(homePageWallpaperPath: second.path),
    );
    await Future<void>.delayed(Duration.zero);

    final after = heldFirst.image.debugGetOpenHandleStackTraces()!.length;
    expect(after, before, reason: '重复预缓存把同一张位图的句柄留住了：$before -> $after');

    heldFirst.image.dispose();
  });
}
