import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/background/bokeh_lava_gradient.dart';
import 'package:university_timetable/ui/background/builtin_wallpaper.dart';

/// 内置壁纸动画的驱动契约。
///
/// 这组用例锁的不是「画得好不好看」，而是**出帧方式**：光斑动画必须由
/// [Timer.periodic] 按目标帧率驱动，两帧之间不得保留任何已排程的帧。
///
/// 历史回归：早先用 [Ticker]（每帧回调 + 累积式节流）驱动，节流只压住了
/// 「重绘次数」，压不住「每 vsync 都请求一帧」——首页静置时设备仍以屏幕
/// 刷新率持续出帧，壁纸下方每块柔光玻璃都要重做 backdrop 采样 + 模糊 + 折射，
/// 实测 SurfaceFlinger 单核 44%、机身 5 分钟升到 44℃。
Widget _host(Widget child) => MaterialApp(home: Center(child: child));

void main() {
  setUp(() {
    BokehLavaGradient.debugDisableAnimationForced = false;
    BokehLavaGradient.debugTickCount = 0;
  });

  group('出帧方式', () {
    testWidgets('两帧之间不保留已排程的帧（Ticker → Timer 的核心回归点）', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const _FrameWith(BokehLavaGradient(wallpaper: BuiltInWallpaper.og))),
      );
      await tester.pump();
      // Ticker 驱动时这里恒为 true：回调结束会立刻 re-schedule 下一帧。
      expect(tester.binding.hasScheduledFrame, isFalse);

      // 推进一个节拍（默认 15fps ≈ 66.7ms），帧被请求、然后再次安静下来。
      await tester.pump(const Duration(milliseconds: 70));
      expect(BokehLavaGradient.debugTickCount, greaterThanOrEqualTo(1));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('节拍跟 targetFps 走，不会退化成逐帧', (tester) async {
      await tester.pumpWidget(
        _host(
          const _FrameWith(
            BokehLavaGradient(wallpaper: BuiltInWallpaper.og),
          ),
        ),
      );
      await tester.pump();
      BokehLavaGradient.debugTickCount = 0;
      // 假时钟下 1 秒恰好走 1 秒的节拍：15fps → 14~15 次（首拍在 +66.7ms）。
      await tester.pump(const Duration(seconds: 1));
      expect(BokehLavaGradient.debugTickCount, inInclusiveRange(13, 15));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('animate:false 不起计时器', (tester) async {
      await tester.pumpWidget(
        _host(
          const _FrameWith(
            BokehLavaGradient(wallpaper: BuiltInWallpaper.og, animate: false),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(BokehLavaGradient.debugTickCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('TickerMode 关闭（被别的路由覆盖）时停表', (tester) async {
      await tester.pumpWidget(
        _host(
          const TickerMode(
            enabled: false,
            child: _FrameWith(BokehLavaGradient(wallpaper: BuiltInWallpaper.og)),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(BokehLavaGradient.debugTickCount, 0);

      // 重新可见后必须自己接上（TickerMode 依赖变化会触发 didChangeDependencies）。
      await tester.pumpWidget(
        _host(const _FrameWith(BokehLavaGradient(wallpaper: BuiltInWallpaper.og))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(BokehLavaGradient.debugTickCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('退到后台停表，回前台接上', (tester) async {
      await tester.pumpWidget(
        _host(const _FrameWith(BokehLavaGradient(wallpaper: BuiltInWallpaper.og))),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      BokehLavaGradient.debugTickCount = 0;
      await tester.pump(const Duration(seconds: 1));
      expect(BokehLavaGradient.debugTickCount, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));
      expect(BokehLavaGradient.debugTickCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('dispose 后不再推进', (tester) async {
      await tester.pumpWidget(
        _host(const _FrameWith(BokehLavaGradient(wallpaper: BuiltInWallpaper.og))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox());
      final afterDispose = BokehLavaGradient.debugTickCount;
      await tester.pump(const Duration(seconds: 2));
      expect(BokehLavaGradient.debugTickCount, afterDispose);
    });
  });

  group('BokehLavaGradient 冒烟', () {
    testWidgets('连续多帧驱动不抛异常', (tester) async {
      await tester.pumpWidget(
        _host(const _FrameWith(BokehLavaGradient(wallpaper: BuiltInWallpaper.og))),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(BokehLavaGradient), findsOneWidget);

      // 换壁纸重建 blob 场，不应抛异常。
      await tester.pumpWidget(
        _host(
          const _FrameWith(BokehLavaGradient(wallpaper: BuiltInWallpaper.lavaDark)),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('改 targetFps 后按新节拍跑（重建计时器）', (tester) async {
      await tester.pumpWidget(
        _host(
          const _FrameWith(
            BokehLavaGradient(wallpaper: BuiltInWallpaper.og, targetFps: 5),
          ),
        ),
      );
      await tester.pump();
      BokehLavaGradient.debugTickCount = 0;
      await tester.pump(const Duration(seconds: 1));
      final slow = BokehLavaGradient.debugTickCount;
      expect(slow, inInclusiveRange(4, 5));

      await tester.pumpWidget(
        _host(
          const _FrameWith(
            BokehLavaGradient(wallpaper: BuiltInWallpaper.og, targetFps: 20),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      BokehLavaGradient.debugTickCount = 0;
      await tester.pump(const Duration(seconds: 1));
      expect(BokehLavaGradient.debugTickCount, greaterThan(slow));
      expect(BokehLavaGradient.debugTickCount, inInclusiveRange(18, 20));

      await tester.pumpWidget(const SizedBox());
    });
  });
}

/// 固定尺寸的宿主盒子；单独提出来只为让上面的用例保持一行可读。
class _FrameWith extends StatelessWidget {
  const _FrameWith(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 360, height: 800, child: child);
  }
}
