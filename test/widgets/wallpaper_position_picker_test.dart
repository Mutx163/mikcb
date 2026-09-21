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

    test('放大后按「倍数 × 封面尺寸 − 视口」算，不是「基础溢出 × 倍数」', () {
      // 300×600 视口 + 1200×600 横图：cover 后 1200×600，基础溢出 900。
      // 放大 2 倍 → 2400 − 300 = 2100，而不是 900 × 2 = 1800（后者分母偏小 ⇒ 拖动偏快）。
      expect(
        wallpaperOverflowDragExtent(
          viewportSize: const Size(300, 600),
          imageSize: const Size(1200, 600),
          horizontal: true,
          scale: 2,
        ),
        closeTo(2100, 0.001),
      );
      // 竖轴同理：cover 后 300×1800，基础溢出 1200 → 2 倍时 3600 − 600 = 3000。
      expect(
        wallpaperOverflowDragExtent(
          viewportSize: const Size(300, 600),
          imageSize: const Size(300, 1800),
          horizontal: false,
          scale: 2,
        ),
        closeTo(3000, 0.001),
      );
      // 不传倍数（= 1，也就是加缩放之前的调用形状）与加缩放之前逐值一致。
      expect(
        wallpaperOverflowDragExtent(
          viewportSize: const Size(300, 600),
          imageSize: const Size(1200, 600),
          horizontal: true,
        ),
        closeTo(900, 0.001),
      );
    });
  });

  group('wallpaperAlignAfterDrag', () {
    test('正方向拖动减少对齐值（壁纸跟随手指右移）', () {
      final next = wallpaperAlignAfterDrag(
        previousAlign: 0,
        dragDelta: 100,
        overflowExtent: 1000,
      );
      expect(next, closeTo(-0.2, 0.001));
    });

    test('负方向拖动增加对齐值（壁纸跟随手指左移）', () {
      final next = wallpaperAlignAfterDrag(
        previousAlign: 0,
        dragDelta: -50,
        overflowExtent: 1000,
      );
      expect(next, closeTo(0.1, 0.001));
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
      // 正方向大拖动 → align 大幅减小 → 钳制到 -1
      final over = wallpaperAlignAfterDrag(
        previousAlign: 0.9,
        dragDelta: 500,
        overflowExtent: 100,
      );
      expect(over, -1);
      // 负方向大拖动 → align 大幅增加 → 钳制到 1
      final under = wallpaperAlignAfterDrag(
        previousAlign: -0.9,
        dragDelta: -500,
        overflowExtent: 100,
      );
      expect(under, 1);
    });
  });

  group('放大后的拖动映射：内容与手指 1:1', () {
    /// 复算首页那层 `Transform.scale(scale, alignment: 对齐点)` 的屏幕落点。
    ///
    /// 图片上比例为 `u` 的那一点落在屏幕 `x = alignFrac × (V − s×S) + s×u×S`
    /// （`V` = 视口宽、`S` = cover 后的图片宽、`alignFrac = (align+1)/2`）。
    /// 推导与 `homePageBackdropImageWidget` 的注释同一套：`cover` 先按对齐值把
    /// 图片在局部坐标里摆好，再绕同一个点整体放大 `s`。
    double screenX({
      required double align,
      required double u,
      required double viewportWidth,
      required double coverWidth,
      required double scale,
    }) {
      final alignFrac = (align + 1) / 2;
      return alignFrac * (viewportWidth - scale * coverWidth) +
          scale * u * coverWidth;
    }

    test('手指按住的那一点，拖动后仍在手指下（1 倍与放大后都一样）', () {
      // 真机口径（2026-09-21）：「缩放壁纸后，拖动壁纸的灵敏度过快，拖一点就飞了」。
      // 成因是拖动映射的分母用了「基础溢出 × 倍数」，比真实溢出小 ⇒ 对齐值变化过快。
      // 这条用例不比对具体数值，而是直接钉住**手感承诺**：手指下的内容跟着手指走。
      const viewportWidth = 300.0;
      const coverWidth = 1200.0; // 1200×600 的图铺进 300×600 视口后的 cover 宽度
      const fingerX = 150.0; // 手指在屏幕正中
      const dragDelta = 40.0;
      // 居中取景 + 手指居中 ⇒ 手指下那一点无论倍数多少都是图片正中（u = 0.5）。
      const u = 0.5;

      for (final scale in const [1.0, 2.0, 4.0]) {
        final nextAlign = wallpaperAlignAfterDrag(
          previousAlign: 0,
          dragDelta: dragDelta,
          overflowExtent: wallpaperOverflowDragExtent(
            viewportSize: const Size(viewportWidth, 600),
            imageSize: const Size(1200, 600),
            horizontal: true,
            scale: scale,
          ),
        );
        expect(
          screenX(
            align: nextAlign,
            u: u,
            viewportWidth: viewportWidth,
            coverWidth: coverWidth,
            scale: scale,
          ),
          closeTo(fingerX + dragDelta, 0.001),
          reason: '倍数 $scale 下手指移动 $dragDelta，内容必须也走 $dragDelta',
        );
      }
    });
  });
}
