// 页面性能账本（`lib/utils/perf_page_ledger.dart`）的行为契约。
//
// 这套账本是「每页帧率 + 能耗排行」报表的唯一数据来源，所以它必须能在
// 不接真机、不起 Flutter 引擎的前提下被逐条判定：所有数字都由下面的
// 喂帧序列**人工推出来**，不是从实现里抄的。
//
// 三条口径值得单独钉（都是上一代探针在真机踩过的）：
// 1. 预算必须被**实测 vsync** 收紧。照显示上报的 60Hz 算，会把 120Hz 面板的
//    整段卡顿读成「全绿」（`.agents/notes/implemented/process/2026-09-16-frame-perf-probe.md`）。
// 2. `fps` 的分子是**间隔数**（帧数 - 1）：n 帧只覆盖 n-1 个间隔，用帧数会把
//    60Hz 的稳定喂帧读成 72fps。
// 3. 页面跨度只算「本页自己有帧的时间」：被别的页面占走的、静止无帧的墙上
//    时间都不记在它头上，否则「停在某页不动」会伪装成「这页很慢」。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/perf_page_ledger.dart';

/// 可控单调时钟：喂帧时由用例显式推进，绝不用真实时间（否则断言会漂）。
class _FakeClock {
  int us = 0;

  int read() => us;

  void advance(int deltaUs) => us += deltaUs;
}

/// 可控成本读数：CPU 微秒 = 墙上时间 × 倍率，于是「页内 CPU 毫秒」可手算。
class _FakeCost {
  _FakeCost(this._clock, {this.cpuFactorPerUs = 2});

  final _FakeClock _clock;
  final double cpuFactorPerUs;

  /// 起点值不承载判据（用例断言的是段内**增量**），所以不做构造参数。
  int rssKb = 100000;

  CostReading read() => CostReading(
    cpuMicros: (_clock.us * cpuFactorPerUs).round(),
    rssKb: rssKb,
  );
}

/// 默认关掉「短访问合并」，让每个用例只测自己那件事；
/// 合并行为由专门的两条用例带 [PerfPageLedger.minDwellUs] 显式覆盖。
PerfPageLedger _ledger(
  _FakeClock clock,
  _FakeCost cost, {
  double refreshRateHz = 60,
  int minDwellUs = 0,
}) {
  return PerfPageLedger(
    nowUs: clock.read,
    readCost: cost.read,
    refreshRateHz: () => refreshRateHz,
    minDwellUs: minDwellUs,
  );
}

/// 在当前时刻记一帧，然后把时钟推进 [gapUs]（模拟稳定帧节奏）。
void _feed(
  PerfPageLedger ledger,
  _FakeClock clock, {
  required int buildUs,
  required int rasterUs,
  int gapUs = 16667,
  int? vsyncUs,
}) {
  ledger.ingest(buildUs: buildUs, rasterUs: rasterUs, vsyncUs: vsyncUs);
  clock.advance(gapUs);
}

void main() {
  group('页面归属', () {
    test('未切过页的帧记进 boot 页：启动成本不该无处可去', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));

      _feed(ledger, clock, buildUs: 5000, rasterUs: 3000);
      _feed(ledger, clock, buildUs: 5000, rasterUs: 3000);

      final rows = ledger.samplesByName();
      expect(rows.keys.toList(), <String>[PerfPageLedger.bootPage]);
      expect(rows[PerfPageLedger.bootPage]!.frames, 2);
    });

    test('切页后的帧计入新页，两页各算各的账', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));

      // A 页：2 帧，每帧合计 10ms（阈值 20833us 以内，不卡）。
      ledger.beginPage('A');
      _feed(ledger, clock, buildUs: 6000, rasterUs: 4000);
      _feed(ledger, clock, buildUs: 6000, rasterUs: 4000);

      // B 页：3 帧，每帧合计 30ms（超阈值，全卡）。
      ledger.beginPage('B');
      _feed(ledger, clock, buildUs: 20000, rasterUs: 10000);
      _feed(ledger, clock, buildUs: 20000, rasterUs: 10000);
      _feed(ledger, clock, buildUs: 20000, rasterUs: 10000);

      final rows = ledger.samplesByName();
      expect(rows['A']!.frames, 2);
      expect(rows['A']!.jankyFrames, 0);
      expect(rows['B']!.frames, 3);
      expect(rows['B']!.jankyFrames, 3);
    });

    test('同一页多次进出合并累计；跨度只算各段自己的帧区间，不含别页占走的时间',
        () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));

      ledger.beginPage('A'); // t=0
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000); // 帧@0
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000); // 帧@10000

      ledger.beginPage('B'); // t=20000
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000); // 帧@20000

      ledger.beginPage('A'); // t=30000（第二次进 A）
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000); // 帧@30000

      final rows = ledger.samplesByName();
      final a = rows['A']!;
      expect(a.frames, 3);
      // 第一段帧区间 0→10000 = 10000us；第二段单帧无区间 = 0us。
      // 20000→30000 那 10ms 是 B 占的，不算 A 的。
      expect(a.spanUs, 10000);
      expect(rows['B']!.spanUs, 0);
    });

    test('驻留不足 minDwellUs 的片段并进前一页：误触一下不该在排行里占一行', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock), minDwellUs: 150000);

      ledger.beginPage('home'); // t=0
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 20000);
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 20000);
      // t=40000 离开 home：home 段 2 帧。

      ledger.beginPage('accidental'); // 误触
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 100000);
      // 该段 1 帧，t=140000 离开，驻留 100000us < 150000us → 并进 home。

      ledger.beginPage('settings');
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 20000);
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 20000);

      final rows = ledger.samplesByName();
      expect(rows.containsKey('accidental'), isFalse);
      expect(rows['home']!.frames, 3);
      expect(rows['settings']!.frames, 2);
    });

    test('没有「真的上过屏的前一页」可并时，短访问保留自己的账', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock), minDwellUs: 150000);

      // boot 段一帧都没有 → 没有证据可承接，flash 不该把账塞进一个空行。
      ledger.beginPage('flash'); // t=0
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 50000);
      ledger.beginPage('stay'); // 驻留 50000us < 150000us
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 500000);

      final rows = ledger.samplesByName();
      expect(rows['flash']!.frames, 1);
      expect(rows['stay']!.frames, 1);
      expect(rows.containsKey(PerfPageLedger.bootPage), isFalse);
    });

    test('默认最小驻留就是 150ms（报表碎行防护是产品口径，不是用例临时值）', () {
      final clock = _FakeClock();
      final ledger = PerfPageLedger(
        nowUs: clock.read,
        readCost: _FakeCost(clock).read,
        refreshRateHz: () => 60,
      );
      expect(ledger.minDwellUs, 150000);
    });

    test('重复 begin 同一页是空操作：滚动/回前台不该被当成换页', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000);
      ledger.beginPage('P'); // 同页重入
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000);

      final row = ledger.samplesByName()['P']!;
      expect(row.frames, 2);
      expect(row.firstFrameLatencyUs, 0);
    });

    test('未闭合的匿名段可以回溯改名，已落的帧跟着走', () {
      // 存在的理由：匿名路由在 didPush 那一刻还不知道自己是谁，只能先挂
      // 一个占位 id；等首帧建完才认得出页面类型。那几帧的账本来就是
      // 「进这一页」的账（首帧重正是我们要抓的），所以必须整段改名，
      // 而不是让占位行吃掉最贵的一段。
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('route:pending');
      _feed(ledger, clock, buildUs: 40000, rasterUs: 1000, gapUs: 10000);
      _feed(ledger, clock, buildUs: 40000, rasterUs: 1000, gapUs: 10000);

      final renamed = ledger.retargetOpenSegment('MonthViewScreen');
      expect(renamed, isTrue);

      final rows = ledger.samplesByName();
      expect(rows.containsKey('route:pending'), isFalse);
      final row = rows['MonthViewScreen']!;
      expect(row.frames, 2);
      expect(row.jankyFrames, 2); // 改名不能把已判的卡帧洗白
    });

    test('回溯改名对已闭合的段无效（返回 false，不改历史账）', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('A');
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000);
      ledger.beginPage('B'); // A 段已闭合
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000);

      expect(ledger.retargetOpenSegment('C'), isTrue); // B 还在开着
      final rows = ledger.samplesByName();
      expect(rows.containsKey('A'), isTrue); // 历史行名不动
      expect(rows['C']!.frames, 1);
      // 再改一次：当前段就是 C，改成别的也应当允许（同段未闭合）。
      expect(ledger.retargetOpenSegment('D'), isTrue);
      expect(ledger.samplesByName()['D']!.frames, 1);
      expect(ledger.samplesByName().containsKey('C'), isFalse);
    });

    test('段内没有任何帧时改名照样成立', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('route:pending');
      expect(ledger.retargetOpenSegment('Home'), isTrue);
      clock.advance(10000);
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000);
      expect(ledger.samplesByName()['Home']!.frames, 1);
    });
  });

  group('卡顿判定与预算', () {
    test('60Hz 下阈值 = 16667×1.25 = 20833us：18ms 不算卡、25ms 算卡', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');

      _feed(ledger, clock, buildUs: 17000, rasterUs: 1000); // 18000 ≤ 20833
      _feed(ledger, clock, buildUs: 24000, rasterUs: 1000); // 25000 > 20833

      final row = ledger.samplesByName()['P']!;
      expect(row.frames, 2);
      expect(row.jankyFrames, 1);
    });

    test('实测 vsync 把预算收紧到 120Hz 后，同一条帧的判定必须翻红', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');

      // 采到 8333us 的真实节奏（120Hz）：vsync 是引擎时间轴的绝对时刻。
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, vsyncUs: 1000000);
      _feed(
        ledger,
        clock,
        buildUs: 1000,
        rasterUs: 1000,
        vsyncUs: 1008333,
      );
      expect(ledger.budgetUs, 8333);

      // 11ms 的一帧：60Hz 口径不卡（阈值 20833），收紧后卡（阈值 10416）。
      _feed(ledger, clock, buildUs: 11000, rasterUs: 0, vsyncUs: 1016666);
      expect(ledger.samplesByName()['P']!.jankyFrames, 1);
    });

    test('不可信的 vsync 间隔（<4ms 或 >40ms）不参与预算收紧', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');

      // 同批投递：间隔 2000us 是噪声，不是面板节奏。
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, vsyncUs: 1000000);
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, vsyncUs: 1002000);
      // 长空闲后的第一帧：50000us 也不是节奏。
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, vsyncUs: 1052000);

      expect(ledger.budgetUs, 16667);
    });

    test('worst / avg 分别算 build 与 raster，均值按帧数摊', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');

      _feed(ledger, clock, buildUs: 4000, rasterUs: 9000);
      _feed(ledger, clock, buildUs: 8000, rasterUs: 1000);

      final row = ledger.samplesByName()['P']!;
      expect(row.worstBuildUs, 8000);
      expect(row.worstRasterUs, 9000);
      expect(row.avgBuildUs, 6000); // (4000+8000)/2
      expect(row.avgRasterUs, 5000); // (9000+1000)/2
    });

    test('verdict 按最差 build / raster 的 1.3 倍单边判定', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));

      ledger.beginPage('ui');
      _feed(ledger, clock, buildUs: 20000, rasterUs: 2000);
      expect(ledger.samplesByName()['ui']!.verdict, 'ui-bound');

      ledger.beginPage('raster');
      _feed(ledger, clock, buildUs: 2000, rasterUs: 20000);
      expect(ledger.samplesByName()['raster']!.verdict, 'raster-bound');

      ledger.beginPage('both');
      _feed(ledger, clock, buildUs: 9000, rasterUs: 8000);
      expect(ledger.samplesByName()['both']!.verdict, 'both');
    });

    test('只有 build 超、raster 为 0 也照样判得出来（不能要求两栏都有值）', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 30000, rasterUs: 0);
      expect(ledger.samplesByName()['P']!.verdict, 'ui-bound');
    });
  });

  group('帧率与延迟', () {
    test('60Hz 稳定喂帧，fps 必须读出约 60（分子是间隔数）', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');
      for (var i = 0; i < 6; i++) {
        _feed(ledger, clock, buildUs: 5000, rasterUs: 5000);
      }
      // 帧记于 0,16667,…,83335 → 跨度 83335us、6 帧、5 个间隔 → 59.99fps。
      final row = ledger.samplesByName()['P']!;
      expect(row.spanUs, 83335);
      expect(row.fps, closeTo(60.0, 0.5));
    });

    test('单帧页面跨度为 0 时 fps 给 null，不报出天文数字', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 5000, rasterUs: 5000);
      expect(ledger.samplesByName()['P']!.fps, isNull);
    });

    test('firstFrameLatencyUs = 切页时刻 → 该页第一帧到达时刻', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P'); // t=0
      clock.advance(12000); // 切页后 12ms 才出第一帧
      _feed(ledger, clock, buildUs: 5000, rasterUs: 5000);
      expect(ledger.samplesByName()['P']!.firstFrameLatencyUs, 12000);
    });

    test('切页后的等待时间不稀释页面 fps（那是 firstFrameMs 的账，不是跨度的账）',
        () {
      // 咬合探针补的用例：把跨度起点从「第一帧」改成「切页时刻」时，原来
      // 28 条全绿——等待被算进跨度这件事没有任何东西在守。
      // 这条口径的意义：「进这一页等得久」与「这一页动画掉帧」是两种病、
      // 两种修法，必须落在两个字段里；混进跨度就会把慢首帧伪装成低帧率。
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P'); // t=0
      clock.advance(200000); // 首帧迟迟不来：等了 200ms
      _feed(ledger, clock, buildUs: 5000, rasterUs: 5000); // 帧@200000
      _feed(ledger, clock, buildUs: 5000, rasterUs: 5000); // 帧@216667

      final row = ledger.samplesByName()['P']!;
      expect(row.firstFrameLatencyUs, 200000); // 等待由这一栏表达
      expect(row.spanUs, 16667); // 跨度只算帧间：216667 - 200000
      expect(row.fps, closeTo(60.0, 0.5)); // 不被 200ms 稀释成 ~5fps
    });

    test('切页后一帧都没出的页面不出现在排行里（没画出来 ≠ 画得很快）', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P'); // t=0
      clock.advance(9000);
      ledger.beginPage('Q'); // t=9000，P 一帧没出
      clock.advance(9000);
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000); // 帧@18000

      final rows = ledger.samplesByName();
      expect(rows.containsKey('P'), isFalse);
      expect(rows.containsKey(PerfPageLedger.bootPage), isFalse);
      expect(rows['Q']!.firstFrameLatencyUs, 9000);
    });
  });

  group('能耗代理', () {
    test('页内 CPU 微秒 = 离开该页时的读数差（倍率 3、跨度 100ms → 300000us）',
        () {
      final clock = _FakeClock();
      // 倍率刻意取非默认的 3：这条用例的主角就是「读数差怎么折算」，
      // 用默认值写等于把判据藏进辅助类里。
      final ledger = _ledger(clock, _FakeCost(clock, cpuFactorPerUs: 3));

      ledger.beginPage('P'); // t=0，CPU 读数 0
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 100000);
      ledger.beginPage('Q'); // t=100000，读数 300000

      expect(ledger.samplesByName()['P']!.cpuMicros, 300000);
    });

    test('RSS 记段内增量，同一页多段取最大增量', () {
      final clock = _FakeClock();
      final cost = _FakeCost(clock);
      final ledger = _ledger(clock, cost);

      ledger.beginPage('P'); // rssStart=100000
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 50000);
      cost.rssKb = 100300;
      ledger.beginPage('Q'); // P 段增量 +300

      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 50000);
      cost.rssKb = 100400;
      ledger.beginPage('P'); // Q 段增量 +100；第二段 P 起点 100400

      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 50000);
      cost.rssKb = 100900; // P 第二段增量 +500

      final rows = ledger.samplesByName();
      expect(rows['P']!.rssDeltaKb, 500); // max(300, 500)
      expect(rows['Q']!.rssDeltaKb, 100);
    });

    test('成本读数不可用时给 null 而不是 0（0 会被读成「这页不耗电」）', () {
      final clock = _FakeClock();
      final ledger = PerfPageLedger(
        nowUs: clock.read,
        readCost: () => const CostReading(cpuMicros: null, rssKb: null),
        refreshRateHz: () => 60,
      );
      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 50000);
      ledger.beginPage('Q');

      final row = ledger.samplesByName()['P']!;
      expect(row.cpuMicros, isNull);
      expect(row.rssDeltaKb, isNull);
    });

    test('sealSegment 把当前段落账：退到后台的静止时间不记成「这页很慢」', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000);
      clock.advance(600000); // 退后台 600s，一帧没出
      ledger.sealSegment();

      // 段末没有帧 → 跨度仍是本页自己的 0（单帧）；600s 不进账。
      expect(ledger.samplesByName()['P']!.spanUs, 0);
    });
  });

  group('排行与快照', () {
    test('rankedBy 按掉帧数降序：最差页在最前', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));

      ledger.beginPage('smooth');
      for (var i = 0; i < 4; i++) {
        _feed(ledger, clock, buildUs: 2000, rasterUs: 2000);
      }
      ledger.beginPage('janky');
      for (var i = 0; i < 4; i++) {
        _feed(ledger, clock, buildUs: 30000, rasterUs: 30000);
      }

      final ranked = ledger.rankedBy();
      expect(ranked.map((r) => r.pageId).toList(), <String>['janky', 'smooth']);
      expect(ranked.first.jankyFrames, 4);
    });

    test('rankedBy 返回不可变列表：外部改不动账本', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000);

      final ranked = ledger.rankedBy();
      expect(() => ranked.add(ranked.first), throwsUnsupportedError);
    });

    test('查快照不推进账本：报表页刷新不该改变读数', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000, gapUs: 10000);

      final before = ledger.samplesByName()['P']!;
      ledger.samplesByName();
      final after = ledger.samplesByName()['P']!;
      expect(after.frames, before.frames);
      expect(after.spanUs, before.spanUs);
    });

    test('reset 后账本清空，预算重新按上报刷新率起算', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 30000, rasterUs: 30000, vsyncUs: 1000000);
      _feed(ledger, clock, buildUs: 30000, rasterUs: 30000, vsyncUs: 1008333);
      expect(ledger.budgetUs, 8333);

      ledger.reset();
      expect(ledger.rankedBy(), isEmpty);
      expect(ledger.budgetUs, 16667);
    });

    test('totalFrames 跨页累计（含未闭合段），空闲时不涨——门面无新帧不写盘靠它', () {
      // 这条判据防的是：常驻诊断件每 5 秒无条件写一次盘，等于给用户手机
      // 加了个周期性 I/O 任务；测功耗的工具自己费电是最讽刺的失效方式。
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      expect(ledger.totalFrames, 0);

      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000);
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000);
      expect(ledger.totalFrames, 2);

      // 未闭合段的那一帧也要算进来：查报表时它还挂在 open 段里。
      ledger.beginPage('Q');
      _feed(ledger, clock, buildUs: 1000, rasterUs: 1000);
      expect(ledger.totalFrames, 3);

      // 查快照不推进计数（否则报表页一刷新就"看起来有新数据"）。
      ledger.samplesByName();
      expect(ledger.totalFrames, 3);

      ledger.reset();
      expect(ledger.totalFrames, 0);
    });
  });

  group('导出', () {
    test('toJsonFor 每页一行、字段名稳定（报表页与差分脚本共用同一份口径）', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('P');
      _feed(ledger, clock, buildUs: 2000, rasterUs: 1000);
      _feed(ledger, clock, buildUs: 2000, rasterUs: 1000);
      ledger.beginPage('Q'); // 收尾 P 段，让 cpu / rss 落账

      final json = ledger.toJsonFor('P')!;
      expect(json['page'], 'P');
      expect(json['frames'], 2);
      expect(json['janky'], 0);
      expect(json['budgetMs'], '16.7');
      expect(
        json.keys,
        containsAll(<String>[
          'spanMs',
          'fps',
          'firstFrameMs',
          'worstBuildMs',
          'worstRasterMs',
          'avgBuildMs',
          'avgRasterMs',
          'cpuMs',
          'rssDeltaKb',
          'verdict',
        ]),
      );
    });

    test('文本报告最差在前，并自带预算与实测节奏（读日志的人不必翻代码）', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      ledger.beginPage('smooth');
      _feed(ledger, clock, buildUs: 2000, rasterUs: 1000);
      ledger.beginPage('janky');
      _feed(ledger, clock, buildUs: 40000, rasterUs: 1000);
      ledger.beginPage('tail'); // 收尾 janky 段

      final text = ledger.formatTextReport();
      expect(text, contains('page=janky'));
      expect(text, contains('page=smooth'));
      expect(text.indexOf('page=janky'), lessThan(text.indexOf('page=smooth')));
      expect(text, contains('budgetMs=16.7'));
      expect(text, contains('verdict=ui-bound'));
      expect(text, isNot(contains('page=tail'))); // 一帧没出的页不占行
    });

    test('一帧都没过时报告给出可判读的空表说明，而不是空字符串', () {
      final clock = _FakeClock();
      final ledger = _ledger(clock, _FakeCost(clock));
      expect(ledger.formatTextReport(), contains('no page'));
    });
  });
}
