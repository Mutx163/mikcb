import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/day_view_expand_motion.dart';

/// 日视图开合转场的**配速与手感口径**（2026-10-23）。
///
/// 用户三次反馈里最后一条是「动画速度，要调快一倍」，再往后是「点了没反应」
/// 那种迟滞。这两件事都由「前 N 毫秒走了多少行程」决定，所以这里直接把曲线
/// 取出来量化，而不是靠肉眼看。
///
/// 这些断言是**人推出来的期望值**（不是从实现里抄的）：
/// - 严格对称：展开到一半点关闭（可达路径）不能跳；
/// - 起步跟手：60fps 下第一帧（16.7ms）就要有可感知的位移；
/// - 中段不过冲：全程单调。
void main() {
  // 60fps 一帧 = 16.67ms。
  const frame = 1000 / 60;

  group('曲线：严格对称（中途反向不跳）', () {
    test('f(1-x) == 1-f(x) 全程成立', () {
      var maxError = 0.0;
      for (var i = 0; i <= 200; i++) {
        final x = i / 200;
        final forward = DayViewExpandMotion.curve.transform(x);
        final mirrored = 1 - DayViewExpandMotion.curve.transform(1 - x);
        final error = (forward - mirrored).abs();
        if (error > maxError) {
          maxError = error;
        }
      }
      expect(
        maxError,
        lessThan(1e-6),
        reason:
            '曲线不对称（最大偏差 $maxError）：展开到一半点关闭时宽度会跳一下',
      );
    });
  });

  group('配速：第一帧就要看得出在动', () {
    test('16.7ms（第一帧）行程 ≥ 1.5%', () {
      final duration = DayViewExpandMotion.baseMilliseconds.toDouble();
      final progress = DayViewExpandMotion.curve.transform(frame / duration);
      expect(
        progress,
        greaterThanOrEqualTo(0.015),
        reason:
            '第一帧只走 ${(progress * 100).toStringAsFixed(2)}%，读作「点了没反应」',
      );
    });

    test('33ms（两帧）行程 ≥ 6%（旧 easeInOut 只有 5%）', () {
      final duration = DayViewExpandMotion.baseMilliseconds.toDouble();
      final progress = DayViewExpandMotion.curve.transform(2 * frame / duration);
      expect(
        progress,
        greaterThanOrEqualTo(0.06),
        reason: '两帧只走 ${(progress * 100).toStringAsFixed(2)}%，起步仍然太软',
      );
    });

    test('半程附近仍是 45%~55%（中段不抢跑、不拖沓）', () {
      final mid = DayViewExpandMotion.curve.transform(0.5);
      expect(mid, inInclusiveRange(0.45, 0.55));
    });
  });

  group('单调：全程不回退', () {
    test('取值随 progress 单调不减', () {
      var previous = -1.0;
      for (var i = 0; i <= 500; i++) {
        final value = DayViewExpandMotion.curve.transform(i / 500);
        expect(
          value,
          greaterThanOrEqualTo(previous),
          reason: 'progress=${i / 500} 时曲线回退了：$previous → $value',
        );
        previous = value;
      }
    });
  });

  group('时长：仍在既有测试的取样窗口内', () {
    test('baseMilliseconds 远低于 500ms 的 pump 取样上限', () {
      // `timetable_day_view_test.dart` 有大量 `pump() + pump(500ms)` 取样。
      // 超过 500ms 会让一批断言在动画中途取样 —— 那是硬顶，不是审美。
      expect(DayViewExpandMotion.baseMilliseconds, lessThan(500));
      expect(
        DayViewExpandMotion.baseMilliseconds,
        greaterThanOrEqualTo(150),
        reason: '低于 150ms 就读不出「卡片在长大」这个过程了',
      );
    });
  });

  group('减少动态效果：真的不动，而不是「更快」', () {
    testWidgets('disableAnimations 时 expand 直接落定、collapse 直接归零', (
      tester,
    ) async {
      late AnimationController controller;
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              controller = AnimationController(vsync: const TestVSync());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(SizedBox));
      expect(DayViewExpandMotion.reduceMotion(context), isTrue);

      controller.value = 0;
      await DayViewExpandMotion.expand(context, controller);
      expect(
        controller.value,
        1,
        reason: '开启减少动效时必须直接落定 —— 「更快的动画」对这类用户仍然不适',
      );

      await DayViewExpandMotion.collapse(context, controller);
      expect(controller.value, 0);
    });

    testWidgets('未开启时走正常动画（不会被误判成减少动效）', (tester) async {
      late AnimationController controller;
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              controller = AnimationController(vsync: const TestVSync());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(SizedBox));
      expect(DayViewExpandMotion.reduceMotion(context), isFalse);
    });
  });
}
