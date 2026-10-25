// A/B 差分表（`tool/perf_diff.dart`）的行为契约。
//
// 这是「这个版本到底比上一版慢在哪」的最终判据产出物：读两份快照 JSON
// （base = v2.1.4.1、head = 当前），按页面 id 配对，逐栏算增减并给出结论。
//
// 期望值全部**人工推出来**（喂进构造的 rows，手算百分比），不是从实现抄的。
//
// 三条判据口径值得单独钉，因为它们决定了结论会不会骗人：
// 1. **样本下限**：一页只跑了 3 帧时，janky 从 0 变 1 就是 33% 恶化，但那
//    是噪音。帧数不足下限的页面标 `lowSample`，不进「恶化」名单。
// 2. **只在两侧都存在的页上比 fps**：head 新增的页没有基线，比不出增减；
//    base 独有的页被删了也不该算成"变快了"。
// 3. **能耗代理按相对增幅判**：CPU 毫秒的绝对值受机型/后台任务影响，
//    两版本同机跑才有意义，所以看增幅百分比而不是绝对毫秒。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

// 差分逻辑住在 tool/（它是给脚本用的 CLI，不是 App 运行期代码），测试按仓内
// 既有先例用相对路径直接引它 —— `test/architecture/copy_style_guard_test.dart`
// 就是这么引 `tool/copy_style_rules.dart` 的。
import '../../tool/perf_diff.dart';

Map<String, Object?> page(
  String id, {
  required int frames,
  required int janky,
  String? fps,
  String? cpuMs,
  String? firstFrameMs,
  String? worstBuildMs,
  String? worstRasterMs,
  String verdict = 'both',
}) {
  return <String, Object?>{
    'page': id,
    'frames': frames,
    'janky': janky,
    'fps': fps,
    'cpuMs': cpuMs,
    'firstFrameMs': firstFrameMs,
    'worstBuildMs': worstBuildMs,
    'worstRasterMs': worstRasterMs,
    'verdict': verdict,
  };
}

Map<String, Object?> snapshot(List<Map<String, Object?>> pages, {String version = 'x'}) {
  var frames = 0;
  var janky = 0;
  for (final p in pages) {
    // 辅助函数自己不能硬转：本文件有一条用例刻意喂 String/null 字段，
    // 这里一 `as int` 就先于被测代码崩掉，报错会被误读成"实现会抛"。
    final f = p['frames'];
    final j = p['janky'];
    if (f is int) {
      frames += f;
    }
    if (j is int) {
      janky += j;
    }
  }
  return <String, Object?>{
    'schema': 1,
    'appVersion': version,
    'probe': <String, Object?>{'budgetMs': '8.3', 'nominalMs': '16.7'},
    'totals': <String, Object?>{
      'pages': pages.length,
      'frames': frames,
      'janky': janky,
    },
    'pages': pages,
  };
}

void main() {
  group('页面配对', () {
    test('两侧同名页面配对成一行差分', () {
      final diff = diffSnapshots(
        base: snapshot(<Map<String, Object?>>[
          page('home:week', frames: 100, janky: 10, fps: '58.0', cpuMs: '500.0'),
        ]),
        head: snapshot(<Map<String, Object?>>[
          page('home:week', frames: 100, janky: 30, fps: '45.0', cpuMs: '900.0'),
        ]),
      );
      expect(diff.rows.length, 1);
      final row = diff.rows.single;
      expect(row.pageId, 'home:week');
      expect(row.baseJankyPct, 10.0); // 10/100
      expect(row.headJankyPct, 30.0); // 30/100
      expect(row.jankyPctDelta, 20.0);
      expect(row.fpsDelta, -13.0); // 45 - 58
    });

    test('head 独有的页面标 added，不参与增减计算', () {
      final diff = diffSnapshots(
        base: snapshot(<Map<String, Object?>>[
          page('home:week', frames: 100, janky: 5),
        ]),
        head: snapshot(<Map<String, Object?>>[
          page('home:week', frames: 100, janky: 5),
          page('statisticsSession', frames: 80, janky: 20),
        ]),
      );
      expect(diff.added.map((r) => r.pageId), <String>['statisticsSession']);
      expect(diff.removed, isEmpty);
      // added 行没有基线，delta 必须是 null（不是 0 —— 0 会被读成「没变化」）。
      expect(diff.added.single.jankyPctDelta, isNull);
      expect(diff.regressed, isEmpty);
    });

    test('单侧页的所有读数都落在自己那一侧（新增页不能假装基线有帧率）', () {
      // 存在的理由：差分表是给人左右对读的。把 ADDED 页的 fps/cpu 填进
      // base 栏，读表的人会得出「这一页在旧版本是 45fps」的结论 —— 而旧
      // 版本里这页根本不存在（是这次新加的统计页）。frames 已经按侧分栏，
      // 其余字段必须同口径，否则一列对得上、另一列对不上更难查。
      final diff = diffSnapshots(
        base: snapshot([page('home:week', frames: 100, janky: 5)]),
        head: snapshot([
          page('home:week', frames: 100, janky: 5),
          page('statisticsSession', frames: 80, janky: 20, fps: '45.0', cpuMs: '900.0'),
        ]),
      );
      final added = diff.added.single;
      expect(added.headFrames, 80);
      expect(added.baseFrames, isNull);
      expect(added.headFps, 45.0);
      expect(added.baseFps, isNull);
      expect(added.headCpuMs, 900.0);
      expect(added.baseCpuMs, isNull);

      // REMOVED 反之：读数属于 base 侧。
      final gone = diffSnapshots(
        base: snapshot([page('oldPage', frames: 60, janky: 3, fps: '50.0', cpuMs: '100.0')]),
        head: snapshot([page('other', frames: 10, janky: 0)]),
      ).removed.single;
      expect(gone.baseFrames, 60);
      expect(gone.headFrames, isNull);
      expect(gone.baseFps, 50.0);
      expect(gone.headFps, isNull);
      expect(gone.baseCpuMs, 100.0);
      expect(gone.headCpuMs, isNull);
    });

    test('base 独有的页面标 removed，不算成「变快了」', () {
      final diff = diffSnapshots(
        base: snapshot(<Map<String, Object?>>[
          page('oldPage', frames: 100, janky: 50),
          page('shared', frames: 100, janky: 10),
        ]),
        head: snapshot(<Map<String, Object?>>[
          page('shared', frames: 100, janky: 10),
        ]),
      );
      expect(diff.removed.map((r) => r.pageId), <String>['oldPage']);
      expect(diff.regressed, isEmpty);
    });
  });

  group('样本下限与判据', () {
    test('帧数低于下限的页面标 lowSample 且不进恶化名单', () {
      // 手推：base 5 帧 0 卡、head 5 帧 3 卡 = 60% 恶化，但 5 帧是噪音。
      final diff = diffSnapshots(
        base: snapshot(<Map<String, Object?>>[
          page('tiny', frames: 5, janky: 0),
        ]),
        head: snapshot(<Map<String, Object?>>[
          page('tiny', frames: 5, janky: 3),
        ]),
        options: const DiffOptions(minFrames: 10),
      );
      expect(diff.rows.single.lowSample, isTrue);
      expect(diff.regressed, isEmpty);
      // 但读数仍在表里（要看得到，只是不当结论）。
      expect(diff.rows.single.jankyPctDelta, 60.0);
    });

    test('达到下限的恶化页进 regressed 名单', () {
      final diff = diffSnapshots(
        base: snapshot(<Map<String, Object?>>[
          page('monthView', frames: 200, janky: 10, cpuMs: '100.0'),
        ]),
        head: snapshot(<Map<String, Object?>>[
          page('monthView', frames: 200, janky: 60, cpuMs: '300.0'),
        ]),
      );
      expect(diff.regressed.map((r) => r.pageId), <String>['monthView']);
      // CPU 增幅手推：(300-100)/100 = +200%
      expect(diff.rows.single.cpuGrowthPct, 200.0);
    });

    test('恶化判据是「两个信号之一超阈值」：janky 百分点 或 CPU 增幅', () {
      // 只 janky 涨 3pp（阈值 5pp）→ 不算恶化。
      final onlySmall = diffSnapshots(
        base: snapshot([page('p', frames: 200, janky: 10, cpuMs: '100.0')]),
        head: snapshot([page('p', frames: 200, janky: 16, cpuMs: '105.0')]),
      );
      expect(onlySmall.regressed, isEmpty);
      expect(onlySmall.rows.single.jankyPctDelta, 3.0);

      // janky 涨 6pp（超 5pp）→ 恶化。
      final overThreshold = diffSnapshots(
        base: snapshot([page('p', frames: 200, janky: 10, cpuMs: '100.0')]),
        head: snapshot([page('p', frames: 200, janky: 22, cpuMs: '105.0')]),
      );
      expect(overThreshold.regressed.length, 1);

      // janky 没涨但 CPU 涨 60%（超 25%）→ 也算恶化（帧率没掉但更费电）。
      final energyOnly = diffSnapshots(
        base: snapshot([page('p', frames: 200, janky: 10, cpuMs: '100.0')]),
        head: snapshot([page('p', frames: 200, janky: 10, cpuMs: '160.0')]),
      );
      expect(energyOnly.regressed.length, 1);
      // 两侧都没喂 fps 读数时是 null 而不是 0：0 会被读成「量过、没变化」，
      // 与「这一栏没量到」是两件事（与 cpuGrowthPct 同口径）。
      expect(energyOnly.rows.single.fpsDelta, isNull);
    });

    test('一侧缺 cpuMs 读数时不算能耗增幅（不能把「没量到」当成 0）', () {
      final diff = diffSnapshots(
        // base 不传 cpuMs（默认即 null）= 这一侧没量到。
        base: snapshot([page('p', frames: 200, janky: 10)]),
        head: snapshot([page('p', frames: 200, janky: 10, cpuMs: '500.0')]),
      );
      expect(diff.rows.single.cpuGrowthPct, isNull);
      expect(diff.regressed, isEmpty);
    });
  });

  group('整轮汇总', () {
    test('totals 行给出跨页总量增减', () {
      final diff = diffSnapshots(
        base: snapshot([
          page('a', frames: 100, janky: 10),
          page('b', frames: 100, janky: 10),
        ]),
        head: snapshot([
          page('a', frames: 100, janky: 30),
          page('b', frames: 100, janky: 20),
        ]),
      );
      // 总帧 200，base 卡 20（10%）、head 卡 50（25%）→ +15pp
      expect(diff.summary.baseJankyPct, 10.0);
      expect(diff.summary.headJankyPct, 25.0);
      expect(diff.summary.jankyPctDelta, 15.0);
      expect(diff.summary.baseFrames, 200);
    });

    test('两侧版本不同要写进结论（同版本比 = 白跑一轮）', () {
      final diff = diffSnapshots(
        base: snapshot([page('a', frames: 100, janky: 1)], version: '2.1.4.1+140'),
        head: snapshot([page('a', frames: 100, janky: 1)], version: '2.1.4.2+141'),
      );
      expect(diff.baseVersion, '2.1.4.1+140');
      expect(diff.headVersion, '2.1.4.2+141');
      expect(diff.sameBuild, isFalse);
    });

    test('判据块两侧不一致时给出口径警告（预算不同 = 帧率增减不可比）', () {
      // 一次跑 60Hz 空闲档、一次 120Hz 交互档，`janky` 的门槛就不同，
      // 差出来的「恶化」可能只是阈值变了 —— 必须把这件事顶到结论前面。
      // 两个版本号分开给：默认值两边相同会顺带触发「同版本」警告，
      // 那条与本用例要验的「判据不一致」无关，会把 .single 断言挤掉。
      final base = snapshot([page('a', frames: 100, janky: 10)], version: 'b1');
      final head = snapshot([page('a', frames: 100, janky: 40)], version: 'h1');
      (base['probe'] as Map<String, Object?>)['budgetMs'] = '16.7';
      (head['probe'] as Map<String, Object?>)['budgetMs'] = '8.3';
      final diff = diffSnapshots(base: base, head: head);
      expect(diff.comparabilityWarnings, isNotEmpty);
      expect(diff.comparabilityWarnings.single, contains('budget'));
    });
  });

  group('导出', () {
    test('文本表按恶化幅度降序，最差在最前', () {
      final diff = diffSnapshots(
        base: snapshot(
          [
            page('mild', frames: 200, janky: 10),
            page('bad', frames: 200, janky: 10),
          ],
          version: '2.1.4.1+140',
        ),
        head: snapshot(
          [
            page('mild', frames: 200, janky: 20), // +5pp
            page('bad', frames: 200, janky: 80), // +35pp
          ],
          version: '2.1.4.2+141',
        ),
      );
      final text = formatDiffTable(diff);
      expect(text.indexOf('page=bad'), lessThan(text.indexOf('page=mild')));
      expect(text, contains('REGRESSED'));
      expect(text, contains('base=2.1.4'));
    });

    test('CSV 一行一页、表头固定（差分表要能进表格软件二次筛）', () {
      final diff = diffSnapshots(
        base: snapshot([page('a', frames: 100, janky: 10, cpuMs: '50.0')]),
        head: snapshot([page('a', frames: 100, janky: 30, cpuMs: '80.0')]),
      );
      final csv = formatDiffCsv(diff);
      final lines = const LineSplitter().convert(csv);
      expect(lines.first, 'page,base_frames,head_frames,base_janky_pct,'
          'head_janky_pct,janky_pct_delta,base_fps,head_fps,fps_delta,'
          'base_cpu_ms,head_cpu_ms,cpu_growth_pct,low_sample,status');
      expect(lines.length, 2);
      expect(lines[1], startsWith('a,100,100,10.0,30.0,20.0,'));
      expect(lines[1], contains('REGRESSED'));
    });

    test('页面名含逗号时 CSV 要加引号，否则整列错位', () {
      final diff = diffSnapshots(
        base: snapshot([page('a,b', frames: 100, janky: 10)]),
        head: snapshot([page('a,b', frames: 100, janky: 10)]),
      );
      final line = const LineSplitter().convert(formatDiffCsv(diff))[1];
      expect(line, startsWith('"a,b"'));
    });
  });

  group('输入健壮性', () {
    test('快照缺 pages 键 → 空表而不是崩', () {
      final diff = diffSnapshots(
        base: <String, Object?>{'schema': 1},
        head: snapshot([page('a', frames: 10, janky: 1)]),
      );
      expect(diff.rows, isEmpty);
      expect(diff.added.map((r) => r.pageId), <String>['a']);
    });

    test('数字字段是字符串或缺失时按 null 处理，不抛', () {
      final diff = diffSnapshots(
        base: snapshot([
          <String, Object?>{'page': 'a', 'frames': '100', 'janky': null},
        ]),
        head: snapshot([page('a', frames: 100, janky: 10)]),
      );
      // base 的 frames 读不出来 → 这一页进不了对比（而不是拿 0 去算 100% 恶化）。
      expect(diff.rows.single.skippedReason, isNotNull);
      expect(diff.regressed, isEmpty);
    });
  });
}
