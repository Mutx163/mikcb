import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/frame_perf_probe.dart';

/// 探针的判据是「读日志的人能不能一眼分辨是哪条线程超时」，所以这里断言的是
/// **汇总行的内容**：帧数、最差 build / raster、线程判定、标记偏移。
///
/// 60Hz 下预算 16.7ms、阈值 20.8ms（预算 ×1.25 容差）——用例里的数字按这个口径取。
void main() {
  group('FramePerfProbe 卡顿段汇总', () {
    late List<String> lines;

    setUp(() {
      lines = <String>[];
      FramePerfProbe.debugInstall(emit: lines.add);
    });

    test('连续超预算帧结算成一条汇总，并判为 UI 线程超时', () {
      FramePerfProbe.debugIngest(buildUs: 28000, rasterUs: 4000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 33000, rasterUs: 5000, nowUs: 16000);
      FramePerfProbe.debugIngest(buildUs: 31000, rasterUs: 4000, nowUs: 32000);
      // 第一帧回到预算内 → 结算上面这一段。
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 48000);

      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line, contains('frames=3'));
      expect(line, contains('verdict=ui-bound'));
      expect(line, contains('worstBuildMs=33.0'));
      expect(line, contains('worstRasterMs=5.0'));
      expect(line, contains('worstTotalMs=38.0'));
      expect(line, contains('framesTotal=4'));
      expect(line, contains('jankyTotal=3'));
    });

    test('渲染线程超时会判为 raster-bound', () {
      FramePerfProbe.debugIngest(buildUs: 6000, rasterUs: 34000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 6000, rasterUs: 31000, nowUs: 16000);
      FramePerfProbe.debugIngest(buildUs: 6000, rasterUs: 4000, nowUs: 32000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('verdict=raster-bound'));
    });

    test('两条线程都超时判为 both', () {
      FramePerfProbe.debugIngest(buildUs: 25000, rasterUs: 22000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 24000, rasterUs: 23000, nowUs: 16000);
      FramePerfProbe.debugIngest(buildUs: 6000, rasterUs: 4000, nowUs: 32000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('verdict=both'));
    });

    test('预算内的帧不产出任何日志', () {
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 7000, rasterUs: 3000, nowUs: 16000);
      FramePerfProbe.debugIngest(buildUs: 9000, rasterUs: 5000, nowUs: 32000);

      expect(lines, isEmpty);
    });

    test('单帧的轻微超预算不报（正常抖动）', () {
      FramePerfProbe.debugIngest(buildUs: 18000, rasterUs: 4000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 16000);

      expect(lines, isEmpty);
    });

    test('单帧超两倍阈值会报（已经掉了一整帧）', () {
      FramePerfProbe.debugIngest(buildUs: 45000, rasterUs: 6000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 16000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('frames=1'));
    });

    test('卡顿段附近的标记会带上，并标出相对偏移', () {
      // 按下按钮（标记）到动画起帧之间隔了 100ms。
      FramePerfProbe.debugMark('select:open', 0);
      FramePerfProbe.debugIngest(buildUs: 30000, rasterUs: 5000, nowUs: 100000);
      FramePerfProbe.debugIngest(buildUs: 30000, rasterUs: 5000, nowUs: 116000);
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 132000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('marks=[select:open@-100ms]'));
    });

    test('回看窗（500ms）之外的旧标记不进汇总', () {
      FramePerfProbe.debugMark('select:press', 0);
      FramePerfProbe.debugIngest(buildUs: 30000, rasterUs: 5000, nowUs: 900000);
      FramePerfProbe.debugIngest(buildUs: 30000, rasterUs: 5000, nowUs: 916000);
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 932000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('marks=[]'));
    });

    test('长时间持续卡顿按上限分段结算，不会一直不出日志', () {
      // 180 帧上限：第 180 帧强制结算一次，后面继续累计。
      for (var i = 0; i < 180; i++) {
        FramePerfProbe.debugIngest(
          buildUs: 30000,
          rasterUs: 5000,
          nowUs: i * 16000,
        );
      }

      expect(lines, hasLength(1));
      expect(lines.single, contains('frames=180'));
    });
  });
}
