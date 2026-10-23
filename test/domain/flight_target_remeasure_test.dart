import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/timetable/flight_target_cache.dart';
import 'package:university_timetable/widgets/timetable/measure_flight_target.dart';

/// 飞行终点「换代之后真的会重测位置」（2026-10-23 审核补）。
///
/// ## 抓的是两个叠在一起的真 bug
///
/// 1. `MeasureFlightTarget` 在「尺寸没变 + 代数没变」时**直接早退**（位置漂移
///    不触发重测 —— 这是为了别在滚动时每帧重建首页，是有意为之）。
/// 2. 但 `FlightTransitionGlue` 原来只在 `AnimationStatus.forward` 时 bump 代数，
///    **`reverse` 不 bump**。而 `performLayout` 又只在自己需要重排时才被调用：
///    父级位置变了、约束没变的场合，Flutter 会跳过这次 layout。
///
/// 两件事叠起来的后果：用户在日视图**滚动过议程列表**（终点位置早变了）再关闭，
/// 缓存里还是打开那一刻的旧矩形 → 卡片朝一个空位置飞。而且因为代数没变 + 没重排，
/// 连「下一帧自己好起来」的机会都没有。
///
/// 实测（修前）：位置从 top=100 移到 top=40、revision 加一，仍然上报旧值 100。
void main() {
  testWidgets('位置变了 + 代数加一 ⇒ 必须重新上报新位置', (tester) async {
    final reported = <Rect>[];
    var offset = 100.0;
    var revision = 0;

    await tester.binding.setSurfaceSize(const Size(300, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget build() => Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned(
            top: offset,
            left: 10,
            child: MeasureFlightTarget(
              revision: revision,
              onMeasured: reported.add,
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump();
    expect(reported, hasLength(1));
    expect(reported.single.top, 100);

    // 模拟滚动：位置变了、尺寸没变、代数没变。
    // 这一帧**不该**重测（否则滚动时每帧都会重建首页）。
    offset = 40.0;
    await tester.pumpWidget(build());
    await tester.pump();
    expect(
      reported,
      hasLength(1),
      reason: '代数没变、尺寸没变时不该重测 —— 那是"滚动时每帧重建首页"的防线',
    );

    // 转场开始（forward 或 reverse）：代数加一 ⇒ 必须重测到新位置。
    revision = 1;
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();

    expect(
      reported.length,
      greaterThanOrEqualTo(2),
      reason:
          '代数加一后必须重新上报。没重测说明 `didUpdateWidget` 只把 `_reported` '
          '置回 false、却没让渲染对象真的重排（`performLayout` 被跳过）。'
          '后果：日视图滚动过再关闭时，卡片飞向上一次的位置。',
    );
    expect(
      reported.last.top,
      closeTo(40, 0.01),
      reason: '重测到的应该是**新**位置（top=40），而不是缓存的旧值 100。'
          '实测到 ${reported.last.top}。',
    );
  });

  test('缓存换代后旧终点作废', () {
    final cache = FlightTargetCache();
    cache.bump();
    cache.record('c1', const Rect.fromLTWH(10, 100, 364, 120));
    expect(cache['c1'], isNotNull);

    // 关闭转场也开新代数（`FlightTransitionGlue` 对 forward 与 reverse 都 bump）。
    cache.bump();
    expect(
      cache['c1'],
      isNull,
      reason: '换代后旧终点必须作废，否则卡片会飞向上一轮的位置',
    );
  });
}
