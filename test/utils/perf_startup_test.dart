// 启动分段探针（`lib/utils/perf_startup.dart`）的行为契约。
//
// 「点开到首页出来」这段在旧探针里只有一个总时长，看不出钱花在
// 哪一段（存储初始化 / 首帧 / 首页换入）。这里把它切成有序阶段，
// 每段给出「距上一步」与「距起点」两个数。纯函数、时钟注入，
// 于是每段耗时都由喂进去的时间戳人工推出，不依赖真机。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/perf_startup.dart';

void main() {
  group('阶段累计', () {
    test('第一个 mark 锚定起点，耗时为 0', () {
      final r = PerfStartup();
      r.mark('mainEnter', 1000000); // 绝对时刻，不是从 0 开始也当基准
      expect(r.elapsedUs('mainEnter'), 0);
      expect(r.sincePreviousUs('mainEnter'), 0);
    });

    test('后续 mark 距起点 = 与第一个 mark 的差', () {
      final r = PerfStartup();
      r.mark('a', 100);
      r.mark('b', 350);
      expect(r.elapsedUs('b'), 250);
    });

    test('sincePrevious 是相邻两段的间隔（不是距起点）', () {
      final r = PerfStartup();
      r.mark('a', 100); // 基准
      r.mark('b', 300); // +200
      r.mark('c', 450); // +150
      expect(r.sincePreviousUs('b'), 200);
      expect(r.sincePreviousUs('c'), 150);
      expect(r.elapsedUs('c'), 350);
    });

    test('同名阶段重复 mark 只记第一次（回前台会重跑启动路径）', () {
      final r = PerfStartup();
      r.mark('a', 100);
      r.mark('a', 9999); // 不该覆盖
      expect(r.elapsedUs('a'), 0);
      expect(r.phases.map((p) => p.label), <String>['a']);
    });

    test('未知 label 查询给 null，不抛', () {
      final r = PerfStartup();
      r.mark('a', 100);
      expect(r.elapsedUs('nope'), isNull);
      expect(r.sincePreviousUs('nope'), isNull);
    });

    test('时间倒流（时钟被系统校时回拨）→ 该段间隔夹到 0，不出负数', () {
      final r = PerfStartup();
      r.mark('a', 500);
      r.mark('b', 300); // 比 a 还早
      expect(r.sincePreviousUs('b'), 0);
      // elapsed 用累计基准，倒流段不缩短总时长（负数会污染总账）。
      expect(r.elapsedUs('b'), 0);
    });
  });

  group('导出', () {
    test('formatTextReport 按阶段顺序出行，带两段耗时', () {
      final r = PerfStartup();
      r.mark('processStart', 0);
      r.mark('mainEnter', 50000); // +50ms
      r.mark('firstFrame', 150000); // +100ms, 距起点 150ms
      final text = r.formatTextReport();
      expect(text, contains('phase=mainEnter'));
      expect(text, contains('stepMs=50.0'));
      expect(text, contains('totalMs=150.0'));
      expect(text.indexOf('phase=mainEnter'), lessThan(text.indexOf('phase=firstFrame')));
    });

    test('toJson 每段一条、字段稳定', () {
      final r = PerfStartup();
      r.mark('a', 0);
      r.mark('b', 1000);
      final json = r.toJson();
      expect(json.length, 2);
      expect(json[1]['phase'], 'b');
      expect(json[1]['stepMs'], '1.0');
      expect(json[1]['totalMs'], '1.0');
    });

    test('没有任何 mark 时报告可判读，不抛', () {
      final r = PerfStartup();
      expect(r.formatTextReport(), contains('no startup'));
      expect(r.toJson(), isEmpty);
    });

    test('总时长 = 最后一个阶段的 elapsed', () {
      final r = PerfStartup();
      r.mark('a', 0);
      r.mark('b', 1000);
      r.mark('c', 2500);
      expect(r.totalUs, 2500);
    });
  });
}
