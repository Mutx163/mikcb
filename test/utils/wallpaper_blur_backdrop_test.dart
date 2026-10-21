import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/preblurred_wallpaper_backdrop.dart';
import 'package:university_timetable/widgets/preblurred_wallpaper_glass.dart';

/// 壁纸高斯模糊的**接线**契约：哪一个设置值会画出哪一种控件、位图没到时画什么。
///
/// 为什么不在这里断言"糊度对不对"：`flutter test` 里 `Paint.imageFilter` 的高斯远弱
/// 于真机（`test/widgets/preblurred_wallpaper_glass_test.dart` 记着探针实测：4px 条纹
/// 在 sigma 2 下对比度只掉到 0.90），那种断言会变成永远绿的假钉子。这里钉的是
/// **分支归属**：0 档必须一个字节都不变地走原图、非 0 档必须走预糊那条路、
/// 位图在途/失败时必须仍画原图。
///
/// 真机观感（尤其 1~3 这最弱几档会不会读成"糊得脏"）只能上设备看，见
/// `.agents/notes/implemented/feature/2026-10-21-home-wallpaper-baked-blur.md` 的 Risks。
/// 纯异步版：给不带 [WidgetTester] 的普通 `test` 用（`_writeWallpaper` 要
/// `tester.runAsync`，只能在 widget 用例里调）。
Future<String> _writeWallpaperAsync({int width = 240}) async {
  final dir = await Directory.systemTemp.createTemp('wp_blur_peek');
  final file = File('${dir.path}${Platform.pathSeparator}wallpaper_peek.png');
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), 480),
    Paint()..color = const Color(0xFF3366CC),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, 480);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  await file.writeAsBytes(
    Uint8List.view(png!.buffer, png.offsetInBytes, png.lengthInBytes),
    flush: true,
  );
  return file.path;
}

Future<String> _writeWallpaper(WidgetTester tester, {int width = 240}) async {
  final dir = await tester.runAsync(
    () => Directory.systemTemp.createTemp('wp_blur_backdrop'),
  );
  addTearDown(() async {
    try {
      await dir!.delete(recursive: true);
    } catch (_) {
      // 临时目录清理失败不该让断言红。
    }
  });
  final file = File('${dir!.path}${Platform.pathSeparator}wallpaper_test.png');
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), 480),
    Paint()..color = const Color(0xFF3366CC),
  );
  final picture = recorder.endRecording();
  final image = await tester.runAsync(() => picture.toImage(width, 480));
  final png = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  picture.dispose();
  image!.dispose();
  await tester.runAsync(
    () => file.writeAsBytes(
      Uint8List.view(png!.buffer, png.offsetInBytes, png.lengthInBytes),
      flush: true,
    ),
  );
  return file.path;
}

Widget _host(Widget child) {
  // `Center` 不是装饰：widget 树的**根**收到的是测试视口的紧约束
  // （2400×1800），直接挂 `SizedBox(360×800)` 会被紧约束拉回整屏，
  // 于是"有没有尺寸"这条断言就量不到真正想量的小盒子。
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: SizedBox(width: 360, height: 800, child: child)),
  );
}

void main() {
  setUp(() {
    // 固定密度：预糊缓存的键里含 devicePixelRatio，预热与取用必须同值。
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .devicePixelRatio = 1.0;
  });
  tearDown(PreblurredWallpaperCache.instance.evict);

  testWidgets('模糊关闭（0 档）时不建预糊控件，画的是清晰原图', (tester) async {
    final path = await _writeWallpaper(tester);
    final settings = TimetableSettings.defaults().copyWith(
      homePageWallpaperPath: path,
      // 显式写成出厂值：这条用例要钉的就是"默认档零回归"。
      homePageWallpaperBlurSigma: 0,
    );

    final widget = homePageBackdropImageWidget(settings: settings);
    expect(widget, isNotNull);

    await tester.pumpWidget(_host(widget!));
    await tester.pump();

    expect(
      find.byType(PreblurredWallpaperBackdrop),
      findsNothing,
      reason: '0 档必须走原来的 Image 分支，不该白白建预糊那条路',
    );
    expect(
      find.byType(Image),
      findsOneWidget,
      reason: '0 档画的应当是清晰原图',
    );
  });

  testWidgets('模糊开启时改走预糊控件；位图未就绪期间仍画原图，不是空白', (tester) async {
    final path = await _writeWallpaper(tester);
    final settings = TimetableSettings.defaults().copyWith(
      homePageWallpaperPath: path,
      homePageWallpaperBlurSigma: 8,
    );

    final widget = homePageBackdropImageWidget(settings: settings);
    expect(
      widget,
      isA<PreblurredWallpaperBackdrop>(),
      reason: '非 0 档必须走预糊那条路',
    );

    await tester.pumpWidget(_host(widget!));
    // 冷缓存：整屏烤图（解码 → 高斯 → toImage）还没落地。
    await tester.pump();

    // 位图未就绪时画的是调用方传进来的清晰原图 —— 不是 SizedBox.shrink()。
    // 后者会在换壁纸 / 冷启动时闪一帧纯色底，正是启动预热器存在要消掉的那个现象。
    expect(
      find.descendant(
        of: find.byType(PreblurredWallpaperBackdrop),
        matching: find.byType(Image),
      ),
      findsOneWidget,
      reason: '位图在途期间必须继续显示原图（gapless 承诺），不能空白',
    );
    // 而且它得真的占满宿主，不是 0×0 的空壳。
    expect(
      tester.getSize(find.byType(PreblurredWallpaperBackdrop)),
      const Size(360, 800),
    );

    // 烤图在 fake-async 里跑不完（`_decode` 挂了一个 10s 的兜底 timeout）：
    // 推过那段时间，走到的是"超时 → 拿不到位图"这条真实失败分支，
    // 此时必须**仍然是原图**，不能变成空白、也不能一直转圈。
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(PreblurredWallpaperBackdrop),
        matching: find.byType(Image),
      ),
      findsOneWidget,
      reason: '烤图失败/超时后必须回落原图（模糊是增益功能，不许成为"壁纸没了"的新原因）',
    );
  });

  testWidgets('位图落地后换成贴图（RawImage），原图退场', (tester) async {
    final path = await _writeWallpaper(tester);
    const sigma = 8.0;
    final settings = TimetableSettings.defaults().copyWith(
      homePageWallpaperPath: path,
      homePageWallpaperBlurSigma: sigma,
    );

    // 先按**同一组参数**把位图烤好放进缓存：widget 里的解码/高斯走的是真实异步
    // I/O，在 fake-async 的 testWidgets 里跑不完，所以预热放在 runAsync 里。
    // 生产路径上这段由 `HomeStartupVisualPrimer.prime` 在首帧放行之前做完。
    final warmed = await tester.runAsync(
      () => PreblurredWallpaperCache.instance.obtain(
        path: path,
        logicalSigma: sigma,
        // 与 setUp 里设的 1.0 同值（参数是 double，写 1 也合法）。
        devicePixelRatio: 1,
      ),
    );
    expect(warmed, isNotNull);
    warmed!.dispose();

    await tester.pumpWidget(_host(homePageBackdropImageWidget(settings: settings)!));
    // 命中缓存 → Future 在微任务里落地 → 下一帧换成成品。
    await tester.pump();
    await tester.pump();

    final backdrop = find.byType(PreblurredWallpaperBackdrop);
    expect(backdrop, findsOneWidget);
    // 成品是裸 RawImage：`PreblurredWallpaperBackdrop` 底下**没有** Image 了。
    expect(
      find.descendant(of: backdrop, matching: find.byType(Image)),
      findsNothing,
      reason: '位图落地后原图必须退场，否则两层同时画',
    );
    expect(
      find.descendant(of: backdrop, matching: find.byType(RawImage)),
      findsOneWidget,
      reason: '成品是贴图，运行时不做任何滤镜',
    );
  });

  test('缓存命中时 peek 必须**同步**返回位图（这正是"第一帧不闪"的判据）', () async {
    // 2026-10-21 用户报：日/周视图切月视图时，整页会闪一下没模糊的壁纸。
    // 月视图是全新页面、壁纸控件从零开始，而 `obtain` 即使命中缓存也返回 Future
    // （`Future.value` 也要等一个微任务）—— 真实 UI 线程的第一帧在微任务之前就画了，
    // 于是先摆原图、下一帧才换。
    //
    // ⚠️ 这条**不能**写成 widget 用例：`tester.pumpWidget` 会把挂起的微任务一并跑完，
    // 所以"没有 peek 的实现"在测试里第一帧看起来也是成品（我实测确认过：去掉 peek
    // 那条 widget 断言照样绿，等于假钉子）。能区分两种实现的，只有 peek 自己的
    // **同步**语义 —— 所以这里直接钉它。
    final path = await _writeWallpaperAsync();
    const sigma = 8.0;

    // 没烤过：同步问必须立刻给 null（而不是一个待完成的 Future）。
    expect(
      PreblurredWallpaperCache.instance.peek(
        path: path,
        logicalSigma: sigma,
        devicePixelRatio: 1,
      ),
      isNull,
      reason: '冷缓存时 peek 必须同步 null，调用方据此才敢第一帧画原图',
    );

    final warmed = await PreblurredWallpaperCache.instance.obtain(
      path: path,
      logicalSigma: sigma,
      devicePixelRatio: 1,
    );
    expect(warmed, isNotNull);
    warmed!.dispose();

    // 烤好之后：同步问必须立刻给图（不需要 await 任何东西）。
    final peeked = PreblurredWallpaperCache.instance.peek(
      path: path,
      logicalSigma: sigma,
      devicePixelRatio: 1,
    );
    expect(peeked, isNotNull, reason: '缓存命中时 peek 必须同步给图');
    expect(peeked!.width, greaterThan(0));
    peeked.dispose();

    // 参数不同就不该串号（sigma 是键的一员）。
    expect(
      PreblurredWallpaperCache.instance.peek(
        path: path,
        logicalSigma: sigma + 1,
        devicePixelRatio: 1,
      ),
      isNull,
    );
  });

  testWidgets('壁纸文件不存在时整个壁纸层不存在（模糊不改变既有回退）', (tester) async {
    // 跨设备恢复 / 重装后设置还在、文件没了，是真实路径
    //（`settings_home_backdrop_flow.dart` 与 `home_page_background.dart` 都记着）。
    final settings = TimetableSettings.defaults().copyWith(
      homePageWallpaperPath: '/nonexistent/dir/wallpaper_missing.png',
      homePageWallpaperBlurSigma: 10,
    );
    expect(homePageBackdropImageWidget(settings: settings), isNull);
  });

  testWidgets('缩放与模糊的叠放次序：预糊在 Transform.scale 里面', (tester) async {
    // 模糊量是"屏幕上的像素"。若 `Transform.scale` 包在模糊外面（即模糊在外层），
    // 用户把缩放拖到 4 倍时糊度会跟着放大、与滑杆读数对不上。
    final path = await _writeWallpaper(tester);
    final settings = TimetableSettings.defaults().copyWith(
      homePageWallpaperPath: path,
      homePageWallpaperBlurSigma: 6,
      homePageWallpaperScale: 2.5,
      homePageWallpaperAlignX: -0.4,
      homePageWallpaperAlignY: 0.3,
    );

    final widget = homePageBackdropImageWidget(settings: settings);
    final scale = widget! as Transform;
    expect(
      scale.transform.getMaxScaleOnAxis(),
      closeTo(2.5, 1e-6),
      reason: '缩放数值必须原样传给外层 Transform',
    );
    expect(
      scale.child,
      isA<PreblurredWallpaperBackdrop>(),
      reason: '预糊控件必须在 Transform.scale 的里面：模糊对屏幕像素恒定',
    );
    // 对齐点也要一起传下去（取景三处同源，抄错就是卡内外壁纸错位）。
    expect(scale.alignment, const Alignment(-0.4, 0.3));
    // 预糊控件自己也要拿到同一对对齐值。
    final backdrop = scale.child! as PreblurredWallpaperBackdrop;
    expect(backdrop.alignX, closeTo(-0.4, 1e-9));
    expect(backdrop.alignY, closeTo(0.3, 1e-9));
    expect(backdrop.sigma, closeTo(6, 1e-9));
  });
}
