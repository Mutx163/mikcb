import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/wallpaper_position_picker_sheet.dart';

import '../helpers_test_app.dart';

/// 1x1 transparent PNG —— 一张真实可解码的最小图片。
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
  // 回归背景：设置里残留的壁纸绝对路径指向的文件可能已丢失（重装后备份
  // 只恢复 JSON、跨设备同步等）。此前进入位置编辑页会在 initState 里
  // File.readAsBytes 抛 PathNotFoundException，直接弹全局异常。
  testWidgets('壁纸文件不存在：显示占位图标而不是抛 PathNotFoundException', (
    tester,
  ) async {
    final missingPath =
        '${Directory.systemTemp.path}/'
        'wallpaper_missing_${DateTime.now().microsecondsSinceEpoch}.jpg';
    expect(File(missingPath).existsSync(), isFalse);

    await tester.pumpWidget(
      TestApp(
        home: WallpaperPositionPickerPage(
          imagePath: missingPath,
          initialAlignX: 0,
          initialAlignY: 0,
        ),
      ),
    );
    // 给真实文件 IO 放行，让 _resolveImageSize 走完「不存在」分支。
    var failed = false;
    for (var i = 0; i < 20 && !failed; i++) {
      await tester.runAsync(() {
        return Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      failed = find
          .byIcon(Icons.broken_image_outlined)
          .evaluate()
          .isNotEmpty;
    }

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('壁纸文件存在：解析出尺寸并渲染预览', (tester) async {
    // FakeAsync 区内不能直接 await 真实文件 IO，必须走 runAsync。
    late Directory dir;
    late File file;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('wallpaper_picker_test');
      file = File('${dir.path}/wallpaper_ok.png');
      await file.writeAsBytes(_tinyPng);
    });
    addTearDown(() {
      return tester.runAsync(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
    });

    await tester.pumpWidget(
      TestApp(
        home: WallpaperPositionPickerPage(
          imagePath: file.path,
          initialAlignX: 0,
          initialAlignY: 0,
        ),
      ),
    );
    await tester.runAsync(() {
      return Future<void>.delayed(const Duration(milliseconds: 150));
    });
    // 尺寸解析链（exists -> read -> ImageDescriptor）跨真实/伪异步边界，
    // 轮询放行并逐帧推进，直到预览出现。
    var resolved = false;
    for (var i = 0; i < 20 && !resolved; i++) {
      await tester.runAsync(() {
        return Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      resolved = find.byType(Image).evaluate().isNotEmpty;
    }

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });
}
