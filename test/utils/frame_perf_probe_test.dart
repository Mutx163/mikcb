import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/frame_perf_probe.dart';

/// 探针的判据是「读日志的人能不能一眼分辨是哪条线程超时、这次动画跑到多少帧」，
/// 所以这里断言的是**汇总行的内容**，不是内部字段。
///
/// 时间戳口径（两组用例故意不同）：
/// - burst 组：帧间隔取 **20ms**，比 60Hz 预算（16.7ms）宽，所以「实测最小间隔」
///   不会把预算收得更紧 —— 断言里的数字就是 60Hz 预算下的结果。
/// - mark 组：帧间隔取 **8.3ms**，专门验「实测间隔把预算收紧到 120Hz 档」这条。
void main() {
  group('FramePerfProbe 卡顿段汇总（burst）', () {
    late List<String> lines;

    setUp(() {
      lines = <String>[];
      FramePerfProbe.debugInstall(emit: lines.add);
    });

    test('连续超预算帧结算成一条汇总，并判为 UI 线程超时', () {
      FramePerfProbe.debugIngest(buildUs: 28000, rasterUs: 4000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 33000, rasterUs: 5000, nowUs: 20000);
      FramePerfProbe.debugIngest(buildUs: 31000, rasterUs: 4000, nowUs: 40000);
      // 第一帧回到预算内 → 结算上面这一段。
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 60000);

      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line, contains('frames=3'));
      expect(line, contains('verdict=ui-bound'));
      expect(line, contains('worstBuildMs=33.0'));
      expect(line, contains('worstRasterMs=5.0'));
      expect(line, contains('worstTotalMs=38.0'));
      // 帧间隔 20ms 比配置预算宽，预算不该被收紧。
      expect(line, contains('budgetMs=16.7'));
      expect(line, contains('framesTotal=4'));
      expect(line, contains('jankyTotal=3'));
    });

    test('渲染线程超时会判为 raster-bound', () {
      FramePerfProbe.debugIngest(buildUs: 6000, rasterUs: 34000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 6000, rasterUs: 31000, nowUs: 20000);
      FramePerfProbe.debugIngest(buildUs: 6000, rasterUs: 4000, nowUs: 40000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('verdict=raster-bound'));
    });

    test('两条线程都超时判为 both', () {
      FramePerfProbe.debugIngest(buildUs: 25000, rasterUs: 22000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 24000, rasterUs: 23000, nowUs: 20000);
      FramePerfProbe.debugIngest(buildUs: 6000, rasterUs: 4000, nowUs: 40000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('verdict=both'));
    });

    test('预算内的帧不产出任何日志', () {
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 7000, rasterUs: 3000, nowUs: 20000);
      FramePerfProbe.debugIngest(buildUs: 9000, rasterUs: 5000, nowUs: 40000);

      expect(lines, isEmpty);
    });

    test('单帧的轻微超预算不报（正常抖动）', () {
      FramePerfProbe.debugIngest(buildUs: 18000, rasterUs: 4000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 20000);

      expect(lines, isEmpty);
    });

    test('单帧超两倍阈值会报（已经掉了一整帧）', () {
      FramePerfProbe.debugIngest(buildUs: 45000, rasterUs: 6000, nowUs: 0);
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 20000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('frames=1'));
    });

    test('卡顿段附近的标记会带上，并标出相对偏移', () {
      // 按下按钮（标记）到动画起帧之间隔了 100ms。
      FramePerfProbe.debugMark('select:open', 0);
      FramePerfProbe.debugIngest(buildUs: 30000, rasterUs: 5000, nowUs: 100000);
      FramePerfProbe.debugIngest(buildUs: 30000, rasterUs: 5000, nowUs: 120000);
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 140000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('marks=[select:open@-100ms]'));
    });

    test('回看窗（500ms）之外的旧标记不进汇总', () {
      FramePerfProbe.debugMark('select:press', 0);
      FramePerfProbe.debugIngest(buildUs: 30000, rasterUs: 5000, nowUs: 900000);
      FramePerfProbe.debugIngest(buildUs: 30000, rasterUs: 5000, nowUs: 920000);
      FramePerfProbe.debugIngest(buildUs: 8000, rasterUs: 4000, nowUs: 940000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('marks=[]'));
    });

    test('长时间持续卡顿按上限分段结算，不会一直不出日志', () {
      // 180 帧上限：第 180 帧强制结算一次。
      for (var i = 0; i < 180; i++) {
        FramePerfProbe.debugIngest(
          buildUs: 30000,
          rasterUs: 5000,
          nowUs: i * 20000,
        );
      }

      expect(lines, hasLength(1));
      expect(lines.single, contains('frames=180'));
    });
  });

  group('FramePerfProbe 交互窗口（mark）', () {
    late List<String> lines;

    setUp(() {
      lines = <String>[];
      FramePerfProbe.debugInstall(emit: lines.add);
    });

    test('标记窗口给出这次交互的读数：帧数 / 等效 fps / 实测 vsync / 超预算帧数', () {
      FramePerfProbe.debugMark('select:open', 0);
      for (var i = 1; i <= 4; i++) {
        FramePerfProbe.debugIngest(
          buildUs: 5000,
          rasterUs: 4000,
          nowUs: i * 8333,
          // 引擎给的 vsync 时刻按 8333µs 递进 → 探针认定面板是 120Hz。
          vsyncUs: i * 8333,
        );
      }
      // 下一帧已经超出窗口时长（700ms）：先结算窗口，本帧不进窗口。
      FramePerfProbe.debugIngest(buildUs: 1000, rasterUs: 1000, nowUs: 900000);

      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line, contains('mark select:open'));
      expect(line, contains('frames=4'));
      expect(line, contains('spanMs=33'));
      expect(line, contains('fps=120'));
      expect(line, contains('vsyncMs=8.3'));
      expect(line, contains('budgetMs=8.3'));
      // 每帧 9ms > 8.3ms：首帧还采不到间隔（仍按 16.7ms 判），后三帧都超。
      expect(line, contains('over=3'));
      expect(line, contains('worstBuildMs=5.0'));
      expect(line, contains('avgRasterMs=4.0'));
    });

    test('窗口到期后的第一帧只负责结算，不被算进窗口', () {
      FramePerfProbe.debugMark('select:open', 0);
      FramePerfProbe.debugIngest(buildUs: 5000, rasterUs: 4000, nowUs: 8333);
      FramePerfProbe.debugIngest(buildUs: 5000, rasterUs: 4000, nowUs: 900000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('frames=1'));
    });

    test('同一瞬间连打两条标记会合并成一个标签', () {
      // dialog:open 直接转发 sheet:open：两条标记之间一帧都没有。
      FramePerfProbe.debugMark('dialog:open', 0);
      FramePerfProbe.debugMark('sheet:open', 200);
      FramePerfProbe.debugIngest(buildUs: 5000, rasterUs: 4000, nowUs: 8333);
      FramePerfProbe.debugIngest(buildUs: 5000, rasterUs: 4000, nowUs: 900000);

      expect(lines, hasLength(1));
      expect(lines.single, contains('mark dialog:open+sheet:open'));
    });

    test('新标记到来时先结算上一个窗口', () {
      FramePerfProbe.debugMark('select:press', 0);
      FramePerfProbe.debugIngest(buildUs: 5000, rasterUs: 4000, nowUs: 8333);
      FramePerfProbe.debugMark('select:open', 16666);
      FramePerfProbe.debugIngest(buildUs: 5000, rasterUs: 4000, nowUs: 25000);
      FramePerfProbe.debugIngest(buildUs: 5000, rasterUs: 4000, nowUs: 900000);

      expect(lines, hasLength(2));
      expect(lines[0], contains('mark select:press'));
      expect(lines[0], contains('frames=1'));
      expect(lines[1], contains('mark select:open'));
      expect(lines[1], contains('frames=1'));
    });

    test('实测 8.3ms 的 vsync 间隔把预算从 60Hz 档收紧到 120Hz 档', () {
      FramePerfProbe.debugMark('homeMenu:open', 0);
      // 每帧 10ms：60Hz 预算（16.7ms）下不算超，120Hz 预算（8.3ms）下每帧都超。
      // vsync 时刻按 8333µs 递进 → 探针认定面板是 120Hz。
      // 第一帧采不到间隔（还没有上一帧），所以它仍按宽预算判 —— over=2 而不是 3。
      for (var i = 1; i <= 3; i++) {
        FramePerfProbe.debugIngest(
          buildUs: 6000,
          rasterUs: 4000,
          nowUs: i * 8333,
          vsyncUs: i * 8333,
        );
      }
      FramePerfProbe.debugIngest(
        buildUs: 1000,
        rasterUs: 1000,
        nowUs: 900000,
        vsyncUs: 900000,
      );

      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line, contains('budgetMs=8.3'));
      expect(line, contains('vsyncMs=8.3'));
      expect(line, contains('frames=3'));
      expect(line, contains('over=2'));
    });

    test('标记打了但一帧都没出时不产日志', () {
      FramePerfProbe.debugMark('select:press', 0);
      FramePerfProbe.debugIngest(buildUs: 1000, rasterUs: 1000, nowUs: 900000);

      expect(lines, isEmpty);
    });

    test('没有标记时的兜底窗口：每 2 秒给一条 steady 基线读数', () {
      FramePerfProbe.debugInstall(emit: lines.add, steadyWindows: true);
      // 120Hz 节奏跑 3 秒：前 2 秒凑满 240 帧时结算一段，余下的重新开一段。
      for (var i = 1; i <= 360; i++) {
        FramePerfProbe.debugIngest(
          buildUs: 1000,
          rasterUs: 2000,
          nowUs: i * 8333,
          vsyncUs: i * 8333,
        );
      }

      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line, startsWith('[frame-perf] steady'));
      expect(line, contains('frames=240'));
      expect(line, contains('budgetMs=8.3'));
      expect(line, contains('vsyncMs=8.3'));
    });
  });
}
