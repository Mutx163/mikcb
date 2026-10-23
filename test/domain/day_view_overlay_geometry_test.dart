import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/timetable/timetable_anchored_day_overlay.dart';

/// 日视图转场壳的**几何契约**（2026-10-23）。
///
/// ## 为什么这条测试必须存在
///
/// 2026-10-21 的版本把「摘要卡从上往下拉出来」写成：
///
/// ```dart
/// ClipRect(child: Align(heightFactor: revealFactor, child: …))
/// ```
///
/// 外面套的是 `Stack(fit: StackFit.expand)`（紧约束），而
/// `RenderPositionedBox.performLayout` 做的是
/// `constraints.constrain(childSize × factor)` —— **紧约束会把它拉回满高**。
/// 裁剪等于没发生：实测层高 600 时 Align 仍是 600，于是整块日视图面板
/// （摘要卡 + 全部议程卡）在转场全程都在画，与飞行卡叠成同一门课两份。
///
/// 这是「动画和卡片不是一对一」的直接来源之一，而且**肉眼在静态测试里看不出来**
/// —— 必须按像素量。
///
/// 现在改成 `Positioned(height: 层高 × revealFactor)`。这条测试量三件事：
/// 1. 转场中途裁剪高度确实按比例缩（不是满高）；
/// 2. 面板内容仍按**整层高**布局（`OverflowBox` 的职责：不重排、只裁窗口）；
/// 3. 露出高度的上限正好是「摘要卡底边」（14 + 107），不会越露越多。
void main() {
  const layerHeight = 740.0;
  const layerWidth = 390.0;
  const panelKey = ValueKey('overlay-panel');

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required double animationValue,
  }) async {
    // 测试默认画布是 800×600，装不下 740 高的层：显式放大，否则会量到
    // 被父级压缩后的高度，结论就变成在测「父约束」而不是在测裁剪。
    await tester.binding.setSurfaceSize(const Size(layerWidth, layerHeight));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(layerWidth, layerHeight)),
          child: Center(
            child: SizedBox(
              width: layerWidth,
              height: layerHeight,
              child: TimetableAnchoredDayOverlay(
                panel: Container(key: panelKey, color: Colors.red),
                expandAnimation: AlwaysStoppedAnimation<double>(
                  animationValue,
                ),
                weekTimeColumnWidth: 40,
                visibleDayCount: 7,
                selectedDayIndex: 2,
                sectionHeight: 60,
                settings: const TimetableSettings(sections: <SectionTime>[]),
                cardInset: 2,
                // 只测几何：不要飞行卡参与（它的矩形依赖实测终点）。
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('转场中途：裁剪高度按露出比例缩，不是满高', (tester) async {
    await pumpOverlay(tester, animationValue: 0.5);

    // revealBottom = 14 + 107 = 121；progress 0.5 时露出 = 121 × 0.5 ≈ 60.5。
    final clip = tester.getRect(find.byType(ClipRect).first);
    expect(
      clip.height,
      lessThan(layerHeight * 0.5),
      reason:
          '裁剪高度 ${clip.height} 接近满高 $layerHeight —— 说明 heightFactor 又被'
          '紧约束拉回 1.0 了，整块面板都在画（飞行卡会与真卡叠成两份）',
    );
    expect(
      clip.height,
      greaterThan(0),
      reason: '中途必须有东西露出来（摘要卡正在被拉出）',
    );
  });

  testWidgets('面板内容仍按整层高布局（只裁窗口，不重排）', (tester) async {
    await pumpOverlay(tester, animationValue: 0.5);
    final panel = tester.getRect(find.byKey(panelKey));
    expect(
      panel.height,
      closeTo(layerHeight, 0.5),
      reason:
          '面板高度被压成 ${panel.height} —— `OverflowBox` 失效了，议程列表会'
          '按露出高度重排（内容跳一下）',
    );
  });

  testWidgets('露出上限 = 摘要卡底边（14 + 107），不会越露越多', (tester) async {
    // progress 到 1 之前，露出高度的上限由 `summaryRevealBottom` 决定。
    await pumpOverlay(tester, animationValue: 0.9);
    final clip = tester.getRect(find.byType(ClipRect).first);
    const summaryBottom = 14.0 + 107;
    expect(
      clip.height,
      lessThanOrEqualTo(summaryBottom + 0.5),
      reason:
          '露出 ${clip.height} 超过了摘要卡底边 $summaryBottom：下面的议程卡'
          '会连同飞行卡一起露出来（重影）',
    );
  });

  testWidgets('落定后不再裁剪：真面板接管整层', (tester) async {
    await pumpOverlay(tester, animationValue: 1);
    expect(
      find.byType(ClipRect),
      findsNothing,
      reason: ' settled 之后不该还有裁剪层（否则面板永远只露一条）',
    );
    final panel = tester.getRect(find.byKey(panelKey));
    expect(panel.height, closeTo(layerHeight, 0.5));
    expect(panel.width, closeTo(layerWidth, 0.5));
  });
}
