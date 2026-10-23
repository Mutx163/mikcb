import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/timetable/timetable_anchored_day_overlay.dart';

/// 日视图转场壳的**面板契约**（2026-10-23 重写）。
///
/// ## 这一版在测什么，为什么改掉了上一版
///
/// 上一版测的是「摘要卡从面板上被拉出来时，裁剪高度按 `revealBottom × progress`
/// 缩」。2026-10-23 摘要卡改成**自己飞的一张卡**（起点 = 星期栏当日格）之后，
/// 「露出比例」这个机制已经不存在了 —— 那份测试的前提整条作废，留着会变成
/// 「测一个不存在的机制」。
///
/// 现在真正要钉的契约是三件事，每一件都对应一个真实的坑：
///
/// 1. **面板全程不绘制**。转场中面板必须留在树上（否则量不到飞行终点），
///    但**一个像素都不能画** —— 画了就会与飞行卡叠成同一门课两份。
///    这里曾经在「摘要卡终点还没量到时」退回旧几何，等于首帧重影。
/// 2. **面板仍按整层高布局**。裁剪窗口高度为 0，但 `OverflowBox` 必须让它按
///    整层高排 —— 否则议程列表会按 0 高度重排，落定那一帧内容跳一下。
/// 3. **落定后真面板接管整层**（铺满、可滚）。
void main() {
  const layerHeight = 740.0;
  const layerWidth = 390.0;
  const panelKey = ValueKey('overlay-panel');

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required double animationValue,
  }) async {
    // 测试默认画布 800×600 装不下 740 高的层：显式放大，否则量到的是被父级
    // 压缩后的高度，结论就变成在测父约束。
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
                // 不给 summaryFlight：这一份只测「没有摘要卡飞行时面板也不许画」。
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 转场中包住面板的那个裁剪窗口高度（没有裁剪层时返回 -1）。
  double panelWindowHeight(WidgetTester tester) {
    final clip = find.byType(ClipRect);
    if (clip.evaluate().isEmpty) {
      return -1;
    }
    return tester.getRect(clip.first).height;
  }

  testWidgets('转场中：面板窗口高度恒为 0（一个像素都不画）', (tester) async {
    for (final t in [0.1, 0.3, 0.5, 0.8, 0.95]) {
      await pumpOverlay(tester, animationValue: t);
      final height = panelWindowHeight(tester);
      expect(
        height,
        closeTo(0, 0.01),
        reason:
            't=$t 时面板窗口高 $height。转场中面板若露出来，就会与飞行卡叠成'
            '同一门课两份（用户口径「动画和卡片不是一对一」）。这里曾经在'
            '「摘要卡终点还没量到」时退回旧几何，等于首帧重影。',
      );
    }
  });

  testWidgets('转场中：面板仍按整层高布局（只把窗口压到 0，不重排）', (tester) async {
    await pumpOverlay(tester, animationValue: 0.5);
    final panel = tester.getRect(find.byKey(panelKey));
    expect(
      panel.height,
      closeTo(layerHeight, 0.5),
      reason:
          '面板高度被压成 ${panel.height} —— `OverflowBox` 失效了，议程列表会'
          '按 0 高度重排，落定那一帧内容跳一下。',
    );
  });

  testWidgets('落定后：真面板接管整层，没有残留裁剪层', (tester) async {
    await pumpOverlay(tester, animationValue: 1);
    expect(
      find.byType(ClipRect),
      findsNothing,
      reason: 'settled 之后不该还有裁剪层（否则面板永远只露一条）',
    );
    final panel = tester.getRect(find.byKey(panelKey));
    expect(panel.height, closeTo(layerHeight, 0.5));
    expect(panel.width, closeTo(layerWidth, 0.5));
  });
}
