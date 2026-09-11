import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/background/bokeh_lava_gradient.dart';
import 'package:university_timetable/ui/background/builtin_wallpaper.dart';

/// 按刷新率 [hz] 生成 [frames] 帧 Ticker 回调，返回每次实际推进的秒数。
///
/// Ticker 给出的 `elapsed` 是整数微秒，所以这里按 `round` 取整，与真机一致。
/// [jitterUs] 模拟真机时间戳的抖动（elapsed 并不是精确的 1/hz）。
List<double> runThrottle(
  FrameThrottle throttle,
  double hz,
  int frames, {
  int jitterUs = 0,
}) {
  final out = <double>[];
  for (var i = 1; i <= frames; i++) {
    var micros = (i * 1000000 / hz).round();
    if (jitterUs != 0) {
      micros += ((i * 7919) % (jitterUs * 2 + 1)) - jitterUs;
    }
    final dt = throttle.tick(Duration(microseconds: micros));
    if (dt != null) {
      out.add(dt);
    }
  }
  return out;
}

/// 修复前的节流逻辑，仅用于锁住回归点（见最后一组用例）。
List<double> legacyThrottle(double hz, int frames, {double targetFps = 30}) {
  final out = <double>[];
  var last = Duration.zero;
  for (var i = 1; i <= frames; i++) {
    final elapsed = Duration(microseconds: (i * 1000000 / hz).round());
    final intervalUs = 1000000 / targetFps;
    final dtUs = (elapsed - last).inMicroseconds;
    if (last != Duration.zero && dtUs < intervalUs) {
      continue;
    }
    out.add(last == Duration.zero ? 1 / targetFps : dtUs / 1000000.0);
    last = elapsed;
  }
  return out;
}

void main() {
  const target = 1 / 30;

  group('FrameThrottle', () {
    for (final hz in <double>[60, 90, 120]) {
      test('${hz.toInt()}Hz 屏稳定落在 30fps 目标节拍', () {
        final dts = runThrottle(FrameThrottle(30), hz, (hz * 2).round());
        // 首个返回值是起始标称步长，之后的稳态间隔必须完全一致。
        final steady = dts.skip(1).toList();
        expect(steady, isNotEmpty);
        for (final dt in steady) {
          expect(dt, closeTo(target, 0.0005));
        }
      });
    }

    test('时间戳抖动下平均节拍仍贴近目标，不做系统性降级', () {
      // 真机 elapsed 不是精确的 1/hz。累积式判定必须吸收抖动，而不是像
      // 旧实现那样因为某一帧差几微秒就把整帧丢掉。
      final dts = runThrottle(
        FrameThrottle(30),
        60,
        120,
        jitterUs: 300,
      ).skip(1).toList();
      final mean = dts.reduce((a, b) => a + b) / dts.length;
      expect(mean, closeTo(target, 0.002));
      // 抖动会让个别帧被推迟（两帧间隔合成一个 50ms），但不得成为主流。
      final long = dts.where((d) => d > 0.04).length;
      expect(long / dts.length, lessThan(0.35));
    });

    test('真实掉帧时返回的是真实经过时间，轨迹不漂移', () {
      final throttle = FrameThrottle(30);
      expect(throttle.tick(Duration.zero), closeTo(target, 1e-9));
      // 这一帧卡了 120ms。
      final dt = throttle.tick(const Duration(milliseconds: 120));
      expect(dt, closeTo(0.12, 1e-6));
    });

    test('首帧 elapsed 为 0 时不会把标称步长走两次', () {
      final throttle = FrameThrottle(30);
      expect(throttle.tick(Duration.zero), closeTo(target, 1e-9));
      // 紧跟的一帧只过去 16ms —— 不足目标间隔，必须返回 null，而不是因为
      // 「上一帧 elapsed 也是 0」再走一次标称步长。
      expect(throttle.tick(const Duration(milliseconds: 16)), isNull);
    });

    test('reset 之后重新走起始分支，暂停时长不灌进动画', () {
      final throttle = FrameThrottle(30);
      throttle.tick(Duration.zero);
      throttle.tick(const Duration(milliseconds: 17));
      throttle.tick(const Duration(milliseconds: 34));
      throttle.reset();
      expect(throttle.tick(const Duration(seconds: 5)), closeTo(target, 1e-9));
    });

    test('90Hz 屏上 20fps 只能拿到 18fps（故取 30 而非 20）', () {
      // 90 / 20 = 4.5 不是整数分频，累积式会稳定地 5 帧推一次（≈55.6ms）。
      // 30fps 才是 60 / 90 / 120 的公约数，三个刷新率都能精确命中。
      final dts = runThrottle(FrameThrottle(20), 90, 180).skip(1).toList();
      expect(dts.first, closeTo(5 / 90, 1e-6));
      expect(dts.first, greaterThan(1 / 20));
    });
  });

  group('回归对照：修复前的节流', () {
    test('60Hz 屏会被系统性降到 20fps', () {
      final steady = legacyThrottle(60, 120).skip(1).toList();
      // 浮点阈值 33333.333 与整数 33333µs 相撞 → 每帧都判「不到间隔」，
      // 稳定产出 50ms，也就是 20fps。这正是用户报的「一顿一顿」。
      expect(steady, isNotEmpty);
      for (final dt in steady) {
        expect(dt, closeTo(0.05, 1e-9));
      }
      // 而修复后同样输入下是 33.3ms。
      final fixed = runThrottle(FrameThrottle(30), 60, 120).skip(1).toList();
      for (final dt in fixed) {
        expect(dt, closeTo(target, 0.0005));
      }
    });
  });

  group('BokehLavaGradient 冒烟', () {
    testWidgets('连续多帧驱动不抛异常', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 800,
              child: BokehLavaGradient(wallpaper: BuiltInWallpaper.og),
            ),
          ),
        ),
      );
      // Ticker 在 testWidgets 的假时钟下可正常驱动（不要混用 runAsync）。
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(BokehLavaGradient), findsOneWidget);

      // 换壁纸重建 blob 场，不应抛异常。
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 800,
              child: BokehLavaGradient(wallpaper: BuiltInWallpaper.lavaDark),
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
