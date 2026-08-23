import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
