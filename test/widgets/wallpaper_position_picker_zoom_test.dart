// 壁纸位置编辑页的**双指缩放**与「重置」（用户 2026-09-20 要：那页能放大照片，
// 并且有一个重置缩放 / 取景的按钮）。
//
// 本组用例只测手势与取景数值，不测像素：缩放作用在预览那层 `Transform.scale`
// 上（与首页壁纸同一套几何），往上找它就能读出当前倍率。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/wallpaper_position_picker_sheet.dart';

import '../helpers_test_app.dart';

/// 1x1 transparent PNG —— 一张真实可解码的最小图片。
///
/// 必须给**真实存在且能解码**的图：文件缺失时页面只画占位图标（既没有预览、
/// 也没有缩放手势），测不到任何东西。
const _tinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
];

void main() {
  /// 建一张临时壁纸；FakeAsync 区内不能直接 await 真实文件 IO，走 runAsync。
  Future<String> writeTempWallpaper(WidgetTester tester) async {
    late Directory dir;
    late File file;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('wallpaper_zoom_test');
      file = File('${dir.path}/wallpaper_ok.png');
      await file.writeAsBytes(_tinyPng);
    });
    addTearDown(() {
      return tester.runAsync(() async {
        if (dir.existsSync()) {
          await dir.delete(recursive: true);
        }
      });
    });
    return file.path;
  }

  /// 预览那层的实际倍率：往上找最近的 `Transform`（就是包裹预览 `Image` 的那层）。
  double previewScale(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byType(Image),
            matching: find.byType(Transform),
          )
          .first,
    );
    return transform.transform.getMaxScaleOnAxis();
  }

  /// 双指捏合到 [factor] 倍（两指初始相距 200，拉到 200 × factor）。
  Future<void> pinch(WidgetTester tester, double factor) async {
    const center = Offset(200, 300);
    const halfSpan = 100.0;
    final left = await tester.startGesture(
      center - const Offset(halfSpan, 0),
    );
    final right = await tester.startGesture(
      center + const Offset(halfSpan, 0),
    );
    await left.moveTo(center - Offset(halfSpan * factor, 0));
    await right.moveTo(center + Offset(halfSpan * factor, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pump();
  }

  /// 把页面挂上去，并把「尺寸解析 / 解码」这条真实异步链放行完。
  Future<void> pumpPicker(
    WidgetTester tester,
    String imagePath, {
    double initialScale = 1,
  }) async {
    await tester.pumpWidget(
      TestApp(
        home: WallpaperPositionPickerPage(
          imagePath: imagePath,
          initialAlignX: 0,
          initialAlignY: 0,
          initialScale: initialScale,
        ),
      ),
    );
    // 尺寸解析链跨真实 / 伪异步边界：轮询放行并逐帧推进（同
    // wallpaper_position_picker_missing_file_test.dart 的做法）。
    for (var i = 0; i < 12 && find.byType(Image).evaluate().isEmpty; i++) {
      await tester.runAsync(() {
        return Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    expect(find.byType(Image), findsOneWidget, reason: '预览要真的挂上');
  }

  testWidgets('双指放大改变预览倍率，「重置」回到 1', (tester) async {
    final path = await writeTempWallpaper(tester);
    await pumpPicker(tester, path);

    expect(previewScale(tester), closeTo(1, 1e-6), reason: '默认就是刚好铺满');

    await pinch(tester, 2);
    expect(previewScale(tester), closeTo(2, 0.05), reason: '捏合 2 倍要真的放大');

    // 「重置」= 位置与缩放一起归位。
    await tester.tap(find.text('重置'));
    await tester.pump();
    expect(previewScale(tester), closeTo(1, 1e-6));
  });

  testWidgets('缩放有上限：捏过头也不会超过口径上限', (tester) async {
    final path = await writeTempWallpaper(tester);
    await pumpPicker(tester, path);

    await pinch(tester, 20);
    expect(
      previewScale(tester),
      closeTo(kWallpaperMaxScale, 1e-6),
      reason: '上限之后只是糊，钳住免得用户把图放飞到糊成一片',
    );

    await tester.tap(find.text('重置'));
    await tester.pump();
    expect(previewScale(tester), closeTo(1, 1e-6));
  });

  testWidgets('进入时沿用已保存的倍率；「完成」把它带回调用方', (tester) async {
    final path = await writeTempWallpaper(tester);
    WallpaperPositionPickerResult? result;
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await pushWallpaperPositionPickerPage(
                  context,
                  imagePath: path,
                  initialAlignX: 0,
                  initialAlignY: 0,
                  initialScale: 2.5,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    // 不用 pumpAndSettle：位置页转场期间玻璃在自激重绘，settle 不下来。
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(WallpaperPositionPickerPage), findsOneWidget);
    expect(previewScale(tester), closeTo(2.5, 1e-6), reason: '进来就是上次那档');

    await tester.tap(find.text('完成'));
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.confirmed, isTrue);
    expect(result!.scale, closeTo(2.5, 1e-6), reason: '缩放是取景的一部分，要落盘');
  });
}
