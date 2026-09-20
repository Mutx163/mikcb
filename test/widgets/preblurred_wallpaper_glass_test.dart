import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/preblurred_wallpaper_glass.dart';

void main() {
  // Portrait screen with a wallpaper that is relatively taller than the screen,
  // so cover-fit crops horizontally.
  const screen = Size(400, 800);
  const image = Size(400, 1000);

  group('preblurredWallpaperSourceRect', () {
    test('cover-fit crops the wallpaper and maps a box to image pixels', () {
      // scale = max(400/400, 800/1000) = 1.0 → dest is 400x1000 centered
      // vertically, i.e. top = (800 - 1000) / 2 = -100.
      final rect = preblurredWallpaperSourceRect(
        imageSize: image,
        screenSize: screen,
        boxSize: const Size(100, 50),
        globalOffset: const Offset(40, 200),
        wallpaperOriginX: 0,
      );

      expect(rect.left, closeTo(40, 0.001));
      expect(rect.top, closeTo(300, 0.001));
      expect(rect.width, closeTo(100, 0.001));
      expect(rect.height, closeTo(50, 0.001));
    });

    test('a wider-than-screen wallpaper is scaled, not stretched', () {
      // image 800x800, screen 400x800 → scale = max(0.5, 1.0) = 1.0.
      // dest = 800x800, left = (400 - 800) / 2 = -200.
      final rect = preblurredWallpaperSourceRect(
        imageSize: const Size(800, 800),
        screenSize: screen,
        boxSize: const Size(80, 80),
        globalOffset: const Offset(0, 0),
        wallpaperOriginX: 0,
      );

      expect(rect.left, closeTo(200, 0.001));
      expect(rect.top, closeTo(0, 0.001));
      expect(rect.width, closeTo(80, 0.001));
      expect(rect.height, closeTo(80, 0.001));
    });

    test(
      'pager-following wallpaper keeps the sample constant while sliding',
      () {
        // A card sitting 40px into its page must sample the same wallpaper slice
        // no matter how far that page has slid, because the wallpaper instance
        // slides with it. Card global x and page origin move together.
        const cardOffsetInPage = 40.0;
        Rect sampleAt(double pageOrigin) {
          return preblurredWallpaperSourceRect(
            imageSize: image,
            screenSize: screen,
            boxSize: const Size(100, 50),
            globalOffset: Offset(pageOrigin + cardOffsetInPage, 200),
            wallpaperOriginX: pageOrigin,
          );
        }

        final settled = sampleAt(0);
        expect(sampleAt(-120), settled);
        expect(sampleAt(-399.5), settled);
        expect(sampleAt(160), settled);
      },
    );

    test('screen-fixed wallpaper re-samples as the card slides', () {
      Rect sampleAt(double cardX) {
        return preblurredWallpaperSourceRect(
          imageSize: image,
          screenSize: screen,
          boxSize: const Size(100, 50),
          globalOffset: Offset(cardX, 200),
          wallpaperOriginX: 0,
        );
      }

      expect(sampleAt(40).left, closeTo(40, 0.001));
      expect(sampleAt(120).left, closeTo(120, 0.001));
    });

    test('near-full-width cards keep parallax past the first few pixels', () {
      // Day-view agenda cards are almost screen-wide. The old clamp on source
      // left would pin after ~14px of drag and freeze frost onto the card.
      const cardWidth = 372.0;
      Rect sampleAt(double cardX) {
        return preblurredWallpaperSourceRect(
          imageSize: image,
          screenSize: screen,
          boxSize: const Size(cardWidth, 80),
          globalOffset: Offset(cardX, 200),
          wallpaperOriginX: 0,
        );
      }

      expect(sampleAt(14).left, closeTo(14, 0.001));
      expect(sampleAt(80).left, closeTo(80, 0.001));
      expect(sampleAt(200).left, closeTo(200, 0.001));
      // Source may leave the bitmap; the paint path clips via the card.
      expect(sampleAt(-40).left, closeTo(-40, 0.001));
    });

    test('cover dest rect is screen-aligned and independent of the card', () {
      final dest = preblurredWallpaperCoverDestRect(
        imageSize: image,
        screenSize: screen,
        wallpaperOriginX: 0,
      );
      // scale = 1 → dest 400x1000 centered vertically (top = -100).
      expect(dest.left, closeTo(0, 0.001));
      expect(dest.top, closeTo(-100, 0.001));
      expect(dest.width, closeTo(400, 0.001));
      expect(dest.height, closeTo(1000, 0.001));
    });

    test('zoom 绕对齐点放大落点（与首页 Transform.scale 同几何）', () {
      Rect destAt(double alignY, double zoom) =>
          preblurredWallpaperCoverDestRect(
            imageSize: image,
            screenSize: screen,
            wallpaperOriginX: 0,
            alignY: alignY,
            zoom: zoom,
          );

      // 基准（zoom = 1）：400x1000、纵向溢出 200（top = -100）。
      // 居中放大 2 倍 ⇒ 400x2000、溢出 1200、top = -600（中心那一点不动）。
      expect(destAt(0, 2).height, closeTo(2000, 0.001));
      expect(destAt(0, 2).top, closeTo(-600, 0.001));
      expect(destAt(0, 2).width, closeTo(800, 0.001));
      // 两个端点仍然贴着对应的边（-1 前缘 / +1 后缘），放大不改这件事。
      expect(destAt(-1, 2).top, closeTo(0, 0.001));
      final bottom = destAt(1, 2);
      expect(bottom.top + bottom.height, closeTo(800, 0.001));
      // 越界倍数钳到口径上限（渲染侧与编辑页共用同一份上下限）。
      expect(destAt(0, 99).height, closeTo(1000 * kWallpaperMaxScale, 0.001));
      // zoom < 1 一律当 1：再小就露出底色。
      expect(destAt(0, 0.5).height, closeTo(1000, 0.001));
    });

    test('cover 对齐值与屏幕上真壁纸同源：-1 贴前缘 / +1 贴后缘', () {
      // 竖长的壁纸只在纵向溢出（scale = 1 → 溢出 200）：alignY 决定这 200px
      // 怎么分。默认 0（居中）时 top = -100，与上一条用例同一读数。
      Rect destAt(double alignY) => preblurredWallpaperCoverDestRect(
        imageSize: image,
        screenSize: screen,
        wallpaperOriginX: 0,
        alignY: alignY,
      );
      expect(destAt(0).top, closeTo(-100, 0.001));
      expect(destAt(-1).top, closeTo(0, 0.001));
      expect(destAt(1).top, closeTo(-200, 0.001));

      // 横向溢出的情形走同一套公式（800x800 铺 400x800 → 横向溢出 400）。
      Rect wideAt(double alignX) => preblurredWallpaperCoverDestRect(
        imageSize: const Size(800, 800),
        screenSize: screen,
        wallpaperOriginX: 0,
        alignX: alignX,
      );
      expect(wideAt(0).left, closeTo(-200, 0.001));
      expect(wideAt(-1).left, closeTo(0, 0.001));
      expect(wideAt(1).left, closeTo(-400, 0.001));
    });

    test('预模糊位图的可见窗口与亮度采样那份推导一致', () {
      // 同一件事（「cover + 对齐值在屏幕上露出哪一段」）本仓有两处实现：这份位图
      // 的 dest 矩形，与 homePageWallpaperVisibleSourceRect（顶部亮度采样用它）。
      // 两处漂移的后果是「卡里的背景」与「背景本身的取景」对不上，所以钉住关系：
      // 源图里第 left 这个比例点必须落在屏幕 x = 0 上。
      for (final alignX in const [-1.0, -0.5, 0.0, 0.5, 1.0]) {
        for (final alignY in const [-1.0, 0.0, 1.0]) {
          const imageSize = Size(1200, 1600);
          final visible = homePageWallpaperVisibleSourceRect(
            viewportSize: screen,
            imageSize: imageSize,
            alignX: alignX,
            alignY: alignY,
          );
          final dest = preblurredWallpaperCoverDestRect(
            imageSize: imageSize,
            screenSize: screen,
            wallpaperOriginX: 0,
            alignX: alignX,
            alignY: alignY,
          );
          expect(
            dest.left + visible.left * dest.width,
            closeTo(0, 0.001),
            reason: 'alignX=$alignX 时露出的左边界没落在屏幕左边',
          );
          expect(
            dest.top + visible.top * dest.height,
            closeTo(0, 0.001),
            reason: 'alignY=$alignY 时露出的上边界没落在屏幕上边',
          );
        }
      }
    });

    test('unclamped source can leave the bitmap (clip handles edges)', () {
      final beyondEnd = preblurredWallpaperSourceRect(
        imageSize: image,
        screenSize: screen,
        boxSize: const Size(100, 50),
        globalOffset: const Offset(10000, 10000),
        wallpaperOriginX: 0,
      );
      expect(beyondEnd.left, closeTo(10000, 0.001));
      expect(beyondEnd.top, closeTo(10100, 0.001));

      final beforeStart = preblurredWallpaperSourceRect(
        imageSize: image,
        screenSize: screen,
        boxSize: const Size(100, 50),
        globalOffset: const Offset(-10000, -10000),
        wallpaperOriginX: 0,
      );
      expect(beforeStart.left, closeTo(-10000, 0.001));
      expect(beforeStart.top, closeTo(-9900, 0.001));
    });

    test('a box larger than the bitmap maps without clamping width', () {
      final rect = preblurredWallpaperSourceRect(
        imageSize: const Size(50, 50),
        screenSize: screen,
        boxSize: const Size(4000, 4000),
        globalOffset: Offset.zero,
        wallpaperOriginX: 0,
      );
      // scale = max(400/50, 800/50) = 16 → src = 4000/16 = 250 (larger than
      // the 50px image; paint uses cover dest + clip instead).
      expect(rect.width, closeTo(250, 0.001));
      expect(rect.height, closeTo(250, 0.001));
    });

    test('degenerate inputs produce no sample', () {
      expect(
        preblurredWallpaperSourceRect(
          imageSize: Size.zero,
          screenSize: screen,
          boxSize: const Size(10, 10),
          globalOffset: Offset.zero,
          wallpaperOriginX: 0,
        ),
        Rect.zero,
      );
      expect(
        preblurredWallpaperSourceRect(
          imageSize: image,
          screenSize: Size.zero,
          boxSize: const Size(10, 10),
          globalOffset: Offset.zero,
          wallpaperOriginX: 0,
        ),
        Rect.zero,
      );
      expect(
        preblurredWallpaperSourceRect(
          imageSize: image,
          screenSize: screen,
          boxSize: Size.zero,
          globalOffset: Offset.zero,
          wallpaperOriginX: 0,
        ),
        Rect.zero,
      );
    });
  });

  group('PreblurredWallpaperPage', () {
    testWidgets('exposes its page index to descendants', (tester) async {
      int? seen;
      await tester.pumpWidget(
        PreblurredWallpaperPage(
          pageIndex: 7,
          child: Builder(
            builder: (context) {
              seen = PreblurredWallpaperPage.maybeIndexOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, 7);
    });

    testWidgets('is absent outside a page', (tester) async {
      int? seen = -1;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = PreblurredWallpaperPage.maybeIndexOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, isNull);
    });
  });

  group('PreblurredWallpaperAlignedFill', () {
    testWidgets('paints nothing and takes up its slot without a wallpaper', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 120,
              height: 60,
              child: PreblurredWallpaperAlignedFill(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(PreblurredWallpaperAlignedFill)),
        const Size(120, 60),
      );
    });

    testWidgets('does not absorb taps meant for the card underneath', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(
                width: 120,
                height: 60,
                child: PreblurredWallpaperAlignedFill(),
              ),
            ),
          ),
        ),
      );

      // warnIfMissed: the fill deliberately does not hit test, so the tap is
      // expected to fall through to the GestureDetector behind it.
      await tester.tap(
        find.byType(PreblurredWallpaperAlignedFill),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('PreblurredWallpaperCache', () {
    late Directory tempDir;
    late String wallpaperPath;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = await Directory.systemTemp.createTemp('preblur_cache_test');
      // 4x4 纯色位图编码为 PNG 落盘，让 FileImage 走真实解码路径。
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 4, 4),
        ui.Paint()..color = const Color(0xFF3366AA),
      );
      final picture = recorder.endRecording();
      final image = picture.toImageSync(4, 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      wallpaperPath =
          '${tempDir.path}${Platform.pathSeparator}wallpaper.png';
      File(wallpaperPath).writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    tearDownAll(() {
      PreblurredWallpaperCache.instance.evict();
      tempDir.deleteSync(recursive: true);
    });

    test(
      'concurrent callers each receive an independently disposable handle',
      () async {
        final cache = PreblurredWallpaperCache.instance;
        cache.evict();

        // 相同请求并发发起：两个调用方会加入同一个 in-flight build。
        final futureA = cache.obtain(
          path: wallpaperPath,
          logicalSigma: 12,
          devicePixelRatio: 2,
        );
        final futureB = cache.obtain(
          path: wallpaperPath,
          logicalSigma: 12,
          devicePixelRatio: 2,
        );
        final a = await futureA;
        final b = await futureB;

        expect(a, isNotNull);
        expect(b, isNotNull);
        expect(
          identical(a, b),
          isFalse,
          reason: '共享 Future 只广播一个实例；每个调用方必须持有自己的 clone，'
              '否则一方的 dispose 会抽掉另一方正在绘制的纹理',
        );

        // 回归点：一方按自身所有权释放后，另一方的位图必须仍然可用，
        // 否则绘制时命中 drawImageRect 的 assert(!image.debugDisposed)。
        a!.dispose();
        expect(b!.debugDisposed, isFalse);

        // 构建完成后的重复请求走缓存快路径，同样必须拿到独立 clone。
        final c = await cache.obtain(
          path: wallpaperPath,
          logicalSigma: 12,
          devicePixelRatio: 2,
        );
        expect(c, isNotNull);
        expect(identical(c, a) || identical(c, b), isFalse);
        expect(c!.debugDisposed, isFalse);
        c.dispose();
        expect(b.debugDisposed, isFalse);
      },
    );
  });
}
