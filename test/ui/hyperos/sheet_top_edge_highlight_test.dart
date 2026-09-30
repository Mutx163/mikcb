// 面板上沿那条边线：只画上沿与两个上角、颜色线宽与玻璃同源、盖在内容之上。
//
// 用户口径 2026-09-27：「内容滑到弹窗顶部渐变模糊带里时，弹窗左上角右上角的圆角变成平铺，
// 滑回顶部/底部又恢复」（停住不动也复现 → 静态问题，不是滚动中的临时状态）。
//
// 机制与取舍写在 `HyperosSheetTopEdgeHighlight` 的类注释里；这里钉机械判据。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';
import 'package:university_timetable/ui/hyperos/miuix_bottom_sheet.dart';

const _appearance = FrostedAppearance(
  sheetBlurSigma: 15,
  sheetTintAlpha: 0.7,
  sheetBarrierAlpha: 0.2,
);

void main() {
  test('路径只覆盖「上沿 + 两个上角」，不画左右与底边', () {
    const size = Size(400, 600);
    const r = 28.0;
    // 几何测试用典型线宽（rimWidth = 1.5），路径会往内缩 strokeWidth/2。
    const strokeWidth = 1.5;
    final bounds = HyperosSheetTopEdgePainter.topEdgePath(size, r, strokeWidth).getBounds();

    // 路径往内缩了 strokeWidth/2 = 0.75，所以左/上边界在 0.75 处。
    // 通栏弹窗左右两条边贴着屏幕边，画出来是两条贴屏线的竖线；底边在屏幕外。
    // 所以这条笔只能占住最上面那一条 —— 这条判据挡住「顺手改成整圈描边」。
    expect(bounds.left, closeTo(strokeWidth / 2, 0.01));
    expect(bounds.right, closeTo(size.width - strokeWidth / 2, 0.01));
    expect(bounds.top, closeTo(strokeWidth / 2, 0.01));
    expect(
      bounds.bottom,
      closeTo(r, 0.6),
      reason: '只到圆角半径那条线为止：再往下就画到左右边了',
    );
  });

  testWidgets('颜色与线宽取自玻璃那份 rim 配方（深浅两档都对）', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const FrostedAppearanceScope(
            appearance: _appearance,
            child: HyperosSheetTopEdgeHighlight(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // `find.byType(CustomPaint)` 会连 MaterialApp 内部的一起捞进来，必须限定在
      // 边线自己的子树里。
      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(HyperosSheetTopEdgeHighlight),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter! as HyperosSheetTopEdgePainter;

      final style = LiquidGlassSurface.resolveStyleFor(
        appearance: _appearance,
        role: LiquidGlassRole.pinnedChrome,
        borderRadius: hyperosMiuixBottomSheetCornerRadius,
        brightness: brightness,
      );

      expect(
        painter.strokeWidth,
        style.rimWidth,
        reason: '$brightness：边线宽度必须与玻璃同一个值',
      );
      expect(
        painter.color.a,
        closeTo(style.rimColor.a * style.rimStrength, 0.001),
        reason: '$brightness：边线浓度必须等于玻璃 rim 的颜色 × 强度',
      );
      expect(
        painter.cornerRadius,
        hyperosMiuixBottomSheetCornerRadius,
        reason: '圆角必须与面板裁剪同一个常量（否则角上会差一线）',
      );
    }
  });

  testWidgets('边线不吃点击：面板顶部那 24 之外照常可点', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showMiuixBottomSheet<void>(
                context: context,
                builder: (sheetContext, close) => Align(
                  alignment: Alignment.topCenter,
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('面板顶部按钮'),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // 边线是 IgnorePointer 包着的：它盖在内容上面，但不能把内容的点击吃掉。
    await tester.tap(find.text('面板顶部按钮'));
    await tester.pump();
    expect(taps, 1, reason: '边线只是描边，不该吃掉内容的点击');
  });
}
