import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/wallpaper_position_picker_sheet.dart';

void main() {
  group('wallpaperOverflowDragExtent', () {
    test('横向溢出：宽图在窄视口下水平溢出', () {
      final overflow = wallpaperOverflowDragExtent(
        viewportSize: const Size(300, 600),
        imageSize: const Size(1200, 600),
        horizontal: true,
      );
      // cover 缩放到高 600，宽 1200 → 水平溢出 900。
      expect(overflow, closeTo(900, 0.001));
    });

    test('纵向溢出：长图在矮视口下垂直溢出', () {
      final overflow = wallpaperOverflowDragExtent(
        viewportSize: const Size(300, 600),
        imageSize: const Size(300, 1800),
        horizontal: false,
      );
      // cover 缩放到宽 300，高 1800 → 垂直溢出 1200。
      expect(overflow, closeTo(1200, 0.001));
    });

    test('不溢出时返回 0（竖图在方形视口下垂直不溢出）', () {
      final overflow = wallpaperOverflowDragExtent(
        viewportSize: const Size(300, 600),
        imageSize: const Size(300, 450),
        horizontal: false,
      );
      expect(overflow, 0);
    });
  });

  group('wallpaperAlignAfterDrag', () {
    test('正方向拖动增加对齐值', () {
      final next = wallpaperAlignAfterDrag(
        previousAlign: 0,
        dragDelta: 100,
        overflowExtent: 1000,
      );
      expect(next, closeTo(0.2, 0.001));
    });

    test('负方向拖动减少对齐值', () {
      final next = wallpaperAlignAfterDrag(
        previousAlign: 0,
        dragDelta: -50,
        overflowExtent: 1000,
      );
      expect(next, closeTo(-0.1, 0.001));
    });

    test('不溢出时恒为 0', () {
      final next = wallpaperAlignAfterDrag(
        previousAlign: 0.5,
        dragDelta: 100,
        overflowExtent: 0,
      );
      expect(next, 0);
    });

    test('超出范围时钳制到 [-1, 1]', () {
      final over = wallpaperAlignAfterDrag(
        previousAlign: 0.9,
        dragDelta: 500,
        overflowExtent: 100,
      );
      expect(over, 1);
      final under = wallpaperAlignAfterDrag(
        previousAlign: -0.9,
        dragDelta: -500,
        overflowExtent: 100,
      );
      expect(under, -1);
    });
  });
}
