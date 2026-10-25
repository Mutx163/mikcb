// 性能探针门面（`lib/utils/perf_probe.dart`）里可纯测的两块：
// 页面 id 归一化，与整份快照的 JSON 结构。
//
// 为什么归一化值得单独钉：`RouteSettings.name` 在本仓**没有统一约定**——
// 有的地方写 `'/settings'`（带前导斜杠，深链/平台路由那条），有的写
// `'settings'`，有的根本不传（匿名路由，全靠 widget 类型兜底）。
// 两版本差分表靠「同一个页面的行名对得上」才成立，名字不归一化就会
// 把一页拆成两行、或把两页并成一行，得出「这页变慢了」的假结论。
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/perf_page_ledger.dart';
import 'package:university_timetable/utils/perf_probe.dart';
import 'package:university_timetable/utils/perf_startup.dart';

/// 给账本喂 [count] 帧（走账本的纯接口，不需要引擎）。
void _feed(PerfPageLedger ledger, int count) {
  for (var i = 0; i < count; i++) {
    ledger.ingest(buildUs: 1000, rasterUs: 1000);
  }
}

void main() {
  group('页面 id 归一化', () {
    test('前导斜杠去掉：/settings 与 settings 必须落到同一行', () {
      expect(PerfProbe.normalizePageId('/settings'), 'settings');
      expect(PerfProbe.normalizePageId('settings'), 'settings');
    });

    test('多级路径只保留最后一段：/a/b/Screen 与 Screen 是同一页', () {
      expect(PerfProbe.normalizePageId('/timetable/settings/editor'), 'editor');
    });

    test('泛型参数去掉：Foo<Bar> 与 Foo<Baz> 不该被拆成两页', () {
      expect(PerfProbe.normalizePageId('CourseOverviewScreen<Section>'),
          'CourseOverviewScreen');
    });

    test('匿名路由的兜底链：name 缺失时用 widget 类型，都没有才 unnamed', () {
      expect(PerfProbe.normalizePageId(null, widgetType: 'MonthViewScreen'),
          'MonthViewScreen');
      expect(PerfProbe.normalizePageId(null), 'unnamed');
      expect(PerfProbe.normalizePageId('', widgetType: 'X'), 'X');
      expect(PerfProbe.normalizePageId('   '), 'unnamed');
    });

    test('widget 类型带库前缀时只取类名（dart:_internal.Foo 这类）', () {
      expect(PerfProbe.normalizePageId(null, widgetType: 'material.Foo'), 'Foo');
    });

    test('名字里的空白被压成单空格：报表按空白切 token，串位会毁掉整行', () {
      expect(PerfProbe.normalizePageId('my  page\tname'), 'my page name');
      expect(
        PerfProbe.normalizePageId('page with\nnewline'),
        contains(' '),
      );
      expect(PerfProbe.normalizePageId('page with\nnewline'), isNot(contains('\n')));
    });
  });

  group('路由归属兜底链', () {
    test('命名路由优先用 name', () {
      expect(
        PerfProbe.pageIdFrom(
          routeName: '/settings',
          routeTypeString: 'HyperosPageRoute<SettingsScreen>',
          widgetType: 'TimetableSettingsScreen',
        ),
        'settings',
      );
    });

    test('匿名路由用路由的泛型参数（本仓大量 push 是匿名 + 泛型带页面类型）', () {
      expect(
        PerfProbe.pageIdFrom(
          routeTypeString: 'HyperosPageRoute<CourseOverviewScreen>',
        ),
        'CourseOverviewScreen',
      );
    });

    test('泛型参数是 void 时不算页面名（`HyperosPageRoute<void>` 到处都有）', () {
      expect(
        PerfProbe.pageIdFrom(
          routeTypeString: 'HyperosPageRoute<void>',
          widgetType: 'TaskListScreen',
        ),
        'TaskListScreen',
      );
    });

    test('泛型带前缀点号时只取类名', () {
      expect(
        PerfProbe.pageIdFrom(routeTypeString: 'material._PageRouteImpl<Foo.Bar>'),
        'Bar',
      );
    });

    test('name 是空字符串也走兜底（本仓有 settings.name: \'\' 的写法）', () {
      expect(
        PerfProbe.pageIdFrom(routeName: '', widgetType: 'X'),
        'X',
      );
    });

    test('三条都没有时用路由类型名本身，最后一档才 unnamed', () {
      expect(
        PerfProbe.pageIdFrom(routeTypeString: 'CustomTransitionPage'),
        'CustomTransitionPage',
      );
      expect(PerfProbe.pageIdFrom(), 'unnamed');
    });
  });

  group('快照结构', () {
    /// 时钟恒为 0 的假账本：本组用例只验快照结构与字段名，不验时间跨度
    /// （跨度由 perf_page_ledger_test 专门覆盖，那里用可控时钟逐帧推进）。
    PerfPageLedger ledger() {
      const t = 0;
      return PerfPageLedger(
        nowUs: () => t,
        readCost: () => const CostReading(cpuMicros: 0, rssKb: 0),
        refreshRateHz: () => 60,
      );
    }

    test('snapshotJson 带版本、启动段与页面行三块（差分脚本只认这一份结构）', () {
      final l = ledger();
      l.beginPage('home');
      l.ingest(buildUs: 5000, rasterUs: 5000);
      l.beginPage('settings');
      l.ingest(buildUs: 5000, rasterUs: 5000);

      final startup = PerfStartup()
        ..mark('mainEnter', 0)
        ..mark('firstFrame', 50000);

      final json = PerfProbe.buildSnapshotJson(
        ledger: l,
        startup: startup,
        meta: const <String, Object?>{'appVersion': '2.1.4.1'},
      );

      expect(json['schema'], PerfProbe.schemaVersion);
      expect(json['appVersion'], '2.1.4.1');
      expect(json['startup'], isA<List<Object?>>());
      expect((json['startup'] as List<Object?>).length, 2);

      final pages = json['pages'] as List<Object?>;
      expect(pages.length, 2);
      // 排行序：两页同样本数时按出现顺序，home 在前。
      expect((pages.first as Map<String, Object?>)['page'], 'home');
    });

    test('totals 汇总跨页总量，用来做「整轮」级别的两版本对比', () {
      final l = ledger();
      l.beginPage('A');
      l.ingest(buildUs: 5000, rasterUs: 5000);
      l.ingest(buildUs: 30000, rasterUs: 30000); // 卡一帧
      l.beginPage('B');
      l.ingest(buildUs: 1000, rasterUs: 1000);

      final json = PerfProbe.buildSnapshotJson(
        ledger: l,
        startup: PerfStartup(),
        meta: const <String, Object?>{},
      );
      final totals = json['totals'] as Map<String, Object?>;
      expect(totals['frames'], 3);
      expect(totals['janky'], 1);
      expect(totals['pages'], 2);
    });

    test('空账本也能出快照（启动即崩、一帧没出的极端场景要留得下文件）', () {
      final json = PerfProbe.buildSnapshotJson(
        ledger: ledger(),
        startup: PerfStartup(),
        meta: const <String, Object?>{},
      );
      expect(json['pages'], isEmpty);
      expect((json['totals'] as Map<String, Object?>)['frames'], 0);
    });

    test('快照带 probe 判据块：budgetMs / nominalMs / observedVsyncMs 三栏并排', () {
      // 报表页与差分脚本都必须知道「这一轮是按什么阈值判的红」。只给
      // budgetMs 是不够的：它会被实测 vsync 收紧，而收紧本身可能出错——
      // 2026-09-16 首轮探针就是照显示上报的 60Hz 算预算，把 120Hz 面板的
      // 整段卡顿读成「全绿」。三栏并排才看得出「上报多少 / 实收多少」。
      final l = ledger();
      l.beginPage('home');
      l.ingest(buildUs: 5000, rasterUs: 5000, vsyncUs: 1000000);
      l.ingest(buildUs: 5000, rasterUs: 5000, vsyncUs: 1008333);

      final probe = PerfProbe.buildSnapshotJson(
        ledger: l,
        startup: PerfStartup(),
        meta: const <String, Object?>{},
      )['probe'] as Map<String, Object?>;
      expect(probe['budgetMs'], '8.3'); // 收紧到 120Hz 后生效的预算
      expect(probe['nominalMs'], '16.7'); // 显示上报的预算（没被收紧）
      expect(probe['observedVsyncMs'], '8.3');
    });

    test('还没采到 vsync 样本时 observedVsyncMs 给 ?，不能是 0 或缺省', () {
      // 0 会被读成「这块屏的帧周期是 0」，而真实含义是「还没量到」。
      final probe = PerfProbe.buildSnapshotJson(
        ledger: ledger(),
        startup: PerfStartup(),
        meta: const <String, Object?>{},
      )['probe'] as Map<String, Object?>;
      expect(probe['observedVsyncMs'], '?');
      expect(probe['budgetMs'], '16.7');
    });

    test('探针未安装（ledger 为 null）时快照仍出得来，probe 块给空表', () {
      // 正式版不装探针，但报表页/导出路径仍可能被调到：结构必须完整，
      // 否则脚本读到 null 会当成解析失败而不是「这个包没数据」。
      final json = PerfProbe.buildSnapshotJson(
        ledger: null,
        startup: null,
        meta: const <String, Object?>{'appVersion': 'x'},
      );
      expect(json['pages'], isEmpty);
      expect(json['probe'], isA<Map<String, Object?>>());
      expect(json['appVersion'], 'x');
    });
  });

  group('视图 id 映射（不经过 Navigator 的页面切换）', () {
    // 「归一化成 home」那条依赖未接追踪器的状态，上一条用例接过的话结果会
    // 变成 home:day。显式从干净态起步，免得结论取决于跑序。
    setUp(PerfProbe.debugUninstall);
    test('首页三个视图各有稳定行名，且都挂在 home 前缀下', () {
      // 首页的日/周/月不是路由，观察者看不见；而它同时又是 MaterialApp 的
      // home，返回时观察者会给它 `TimetableScreen` 这个名字。两套名字若各写
      // 一半，同一页就会在差分表里被拆成两行 —— 所以视图名与路由名必须
      // 收敛到同一个前缀。
      expect(PerfProbe.viewPageId(null), 'home');
      expect(PerfProbe.viewPageId('week'), 'home:week');
      expect(PerfProbe.viewPageId('day'), 'home:day');
      expect(PerfProbe.viewPageId('month'), 'home:month');
    });

    test('课表主页面归一化成 home：路由给的 TimetableScreen 与视图名同源', () {
      expect(PerfProbe.canonicalPageId('TimetableScreen'), 'home');
      // 其它页面原样通过，不能被这张表误伤。
      expect(PerfProbe.canonicalPageId('MonthViewScreen'), 'MonthViewScreen');
      expect(PerfProbe.canonicalPageId('settings'), 'settings');
    });

    test('未知视图值落到 home（新加视图不该凭空多出一行空账）', () {
      expect(PerfProbe.viewPageId('somethingNew'), 'home');
    });

    test('已接上视图追踪后，回到首页要落到当前视图那一行', () {
      // 存在的理由：首页既是 MaterialApp 的 home（从子页 pop 回来时观察者
      // 给它 `TimetableScreen` → `home`），又经视图追踪器记成 `home:day`。
      // 两套名字各写一半，同一页在差分表里就**拆成两行**（一行"进过设置再
      // 回来"、一行"日视图"），两版本还未必按同样比例分裂 —— 那就是假增减。
      // 口径：知道当前视图时一律归到 `home:<view>`，不知道时才用父级名。
      PerfProbe.debugInstall(minDwellUs: 0);
      final source = _FakeListenable();
      PerfProbe.attachHomeViewTracker(source: source, modeName: () => 'day');

      expect(PerfProbe.canonicalPageId('TimetableScreen'), 'home:day');
      expect(PerfProbe.canonicalPageId('home'), 'home:day');
      // 其它页面不受这张表影响。
      expect(PerfProbe.canonicalPageId('settings'), 'settings');
      expect(PerfProbe.canonicalPageId('MonthViewScreen'), 'MonthViewScreen');
      PerfProbe.debugUninstall();
    });
  });

  group('三视图接线（监听持久化模式，不进热文件）', () {
    // 每条都从「未安装」起步：否则"未安装时是空操作"那条的结论取决于
    // 它前面跑过什么，是顺序耦合的假绿。
    setUp(PerfProbe.debugUninstall);
    tearDown(PerfProbe.debugUninstall);

    test('未安装时挂追踪器是空操作：不抛、也不建账本', () {
      // 正式版走的就是这条路（install 直接 return），所以这里必须安静。
      final source = _FakeListenable();
      PerfProbe.attachHomeViewTracker(
        source: source,
        modeName: () => 'day',
      );
      expect(PerfProbe.openLedger, isNull);
      expect(source.listenerCount, 0);
    });

    test('挂上时立刻记一次当前视图：探针装好时用户可能已停在日视图', () {
      // 不补这一笔，那段帧会全部记到 boot 头上（启动页背了首页的账）。
      PerfProbe.debugInstall();
      final source = _FakeListenable();
      PerfProbe.attachHomeViewTracker(
        source: source,
        modeName: () => 'day',
      );
      expect(PerfProbe.openLedger!.openPageId, 'home:day');
    });

    test('模式变化后自动换页：三个视图各成一行，帧落在各自的行上', () {
      // minDwellUs: 0 —— 本用例只验「切换有没有把账开对页」，喂帧是微秒级，
      // 留着默认的短访问合并会把 day 那段并进 week，验不到三行。
      PerfProbe.debugInstall(minDwellUs: 0);
      final source = _FakeListenable();
      var mode = 'week';
      PerfProbe.attachHomeViewTracker(source: source, modeName: () => mode);
      _feed(PerfProbe.openLedger!, 2);

      mode = 'day';
      source.notify();
      _feed(PerfProbe.openLedger!, 1);

      mode = 'month';
      source.notify();
      _feed(PerfProbe.openLedger!, 3);

      expect(source.listenerCount, 1);
      expect(PerfProbe.openLedger!.openPageId, 'home:month');
      final rows = PerfProbe.openLedger!.samplesByName();
      expect(rows['home:week']!.frames, 2);
      expect(rows['home:day']!.frames, 1);
      expect(rows['home:month']!.frames, 3);
    });

    test('读数抛异常时保持现状：探针不参与业务故障，也不猜一个新行名', () {
      PerfProbe.debugInstall();
      final source = _FakeListenable();
      PerfProbe.attachHomeViewTracker(
        source: source,
        modeName: () => throw StateError('provider 还没就绪'),
      );
      // 装不上就还是 boot，不该出现 'null' / 空名字这种脏行。
      expect(PerfProbe.openLedger!.openPageId, PerfPageLedger.bootPage);
    });

    test('同一个视图重复通知不会把账切成无数碎段', () {
      PerfProbe.debugInstall();
      final source = _FakeListenable();
      PerfProbe.attachHomeViewTracker(source: source, modeName: () => 'day');
      for (var i = 0; i < 20; i++) {
        source.notify(); // 设置里任意字段变动都会触发 listener
      }
      // beginPage 同页是空操作，所以这里仍然只有一段。
      expect(PerfProbe.openLedger!.openPageId, 'home:day');
      expect(PerfProbe.openLedger!.rankedBy().length, lessThanOrEqualTo(1));
    });
  });

  // 下面四组用例全部来自 2026-10-25 那次真机巡检的实测数据 —— 探针在真机上
  // 跑出数据之后，暴露出三个自己没测到的问题，逐条补在这里。
  group('启动打点在 install 之前不能丢（真机实测丢了两段）', () {
    setUp(PerfProbe.debugUninstall);
    tearDown(PerfProbe.debugUninstall);

    test('装之前的打点先缓冲、装的时候补记进去', () {
      // 真机读数里只有 runApp / firstFrame / homeRevealed 三段，
      // mainEnter 与 bindingReady **整段不见了**：它们在 PerfProbe.install()
      // 之前调用，而那时启动记录器还没建出来，被静默丢弃。
      // 丢的偏偏是「进程起来 → Dart 侧起点 → binding 就绪」这一段，
      // 也就是冷启动里最贵、最想知道的那一段。
      PerfProbe.debugUninstall();
      PerfProbe.startupMark('mainEnter');
      PerfProbe.startupMark('bindingReady');
      PerfProbe.debugInstall();

      final phases = (PerfProbe.snapshotJson()['startup'] as List<Object?>)
          .map((e) => (e as Map<String, Object?>)['phase'])
          .toList();
      expect(phases, <String>['mainEnter', 'bindingReady']);
    });

    test('缓冲段与装之后的打点顺序必须对（不能把补记排在后面）', () {
      PerfProbe.debugUninstall();
      PerfProbe.startupMark('mainEnter');
      PerfProbe.debugInstall();
      PerfProbe.startupMark('runApp');
      PerfProbe.startupMark('firstFrame');

      final phases = (PerfProbe.snapshotJson()['startup'] as List<Object?>)
          .map((e) => (e as Map<String, Object?>)['phase'])
          .toList();
      expect(phases, <String>['mainEnter', 'runApp', 'firstFrame']);
    });

    test('卸载会清掉缓冲，不让用例/会话之间顺序耦合', () {
      // 「正式版不缓冲」由编译期常量 `_willInstall` 保证（release 且无 define
      // 时那条分支被折叠掉），在 debug 测试里跑不到 —— 所以这里只钉**能验的**
      // 那半条：卸载必须把缓冲清干净，否则下一次安装会补记上一轮的残留阶段。
      PerfProbe.debugUninstall();
      PerfProbe.startupMark('mainEnter');
      expect(PerfProbe.pendingStartupMarkCount, 1);
      PerfProbe.debugUninstall();
      expect(PerfProbe.pendingStartupMarkCount, 0);
      expect(PerfProbe.isInstalled, isFalse);
    });

    test('重复 install 不会把缓冲补记两遍', () {
      PerfProbe.debugUninstall();
      PerfProbe.startupMark('mainEnter');
      PerfProbe.debugInstall();
      PerfProbe.debugInstall();
      final phases = (PerfProbe.snapshotJson()['startup'] as List<Object?>)
          .map((e) => (e as Map<String, Object?>)['phase'])
          .toList();
      expect(phases, <String>['mainEnter']);
    });
  });

  group('跨重启不丢巡检数据（真机实测只剩 2 页）', () {
    // 真机读数里只有 home:week 与 MaterialPageRoute 两页，而巡检清单里走了
    // 十几处、还做了 3 次冷启动 —— 因为账本在内存里、冷启动清零，而自动落盘
    // **覆盖同一个文件名**，最后一次启动把前面几次的巡检结果全盖掉了。

    test('会话文件名带时间戳，且与 live 文件名不同', () {
      final name = PerfProbe.sessionFileName(DateTime.utc(2026, 10, 25, 5, 6, 7));
      expect(name, 'perf-session-20261025T050607.json');
      expect(name, isNot(PerfProbe.liveJsonName));
    });

    test('轮转只删旧会话，绝不删 live 文件', () {
      // 不传 keep，用生产默认值：这条要钉的正是「默认口径下也不会删 live 文件」。
      final doomed = PerfProbe.sessionsToPrune(
        const <String>[
          PerfProbe.liveJsonName,
          'perf-live.txt',
          'perf-session-20261025T050607.json',
        ],
      );
      expect(doomed, isEmpty);
    });

    test('会话超出保留数时，从最旧的开始删', () {
      // 文件名用真实形状（零填充 ISO，字典序即时间序）—— 上一版这里我写了
      // 带冒号的名字，正则根本不认，测出来会是「一个都没删」的假红。
      String sessionAt(int hour) =>
          'perf-session-20261025T${hour.toString().padLeft(2, '0')}0000.json';
      final existing = <String>[
        PerfProbe.liveJsonName,
        for (var h = 1; h <= 12; h++) sessionAt(h),
      ];
      // 保留数取 5（非默认值）：这样「该删几份」是这条用例自己定的，
      // 不会因为以后调整默认保留数而悄悄变成另一条断言。
      final doomed = PerfProbe.sessionsToPrune(existing, keep: 5);
      expect(
        doomed,
        <String>[for (var h = 1; h <= 7; h++) sessionAt(h)],
      );
      expect(doomed, isNot(contains(PerfProbe.liveJsonName)));
    });

    test('不认得的文件名一律不碰（用户自己放进来的东西不该被探针删掉）', () {
      final doomed = PerfProbe.sessionsToPrune(
        const <String>[
          'perf-live.json',
          'notes.txt',
          'backup.json',
          'perf-session-20261025T050607.json',
        ],
        keep: 1,
      );
      expect(doomed, isEmpty);
    });
  });

  group('认不出页面时不许拿路由类型名收工（真机实测出现 MaterialPageRoute 行）', () {
    test('路由自身说不出页面身份时给 null，交给回溯去找真页名', () {
      // 全仓没有任何一处用 MaterialPageRoute（只有注释里说「别用」），
      // 真机却出现了一行 page=MaterialPageRoute —— 说明那条路由的 name 与
      // 泛型都给不出身份，而旧逻辑**拿路由类型名当成了「认出来了」**，
      // 于是跳过了首帧后的页面名回溯，把一页真页面记成了一个框架类名。
      expect(
        PerfProbe.routeDeclaredPageId(routeTypeString: 'MaterialPageRoute<dynamic>'),
        isNull,
      );
      expect(
        PerfProbe.routeDeclaredPageId(routeTypeString: 'HyperosPageRoute<void>'),
        isNull,
      );
    });

    test('命名路由与带页面类型的泛型仍然算认出来了', () {
      expect(
        PerfProbe.routeDeclaredPageId(routeName: '/settings'),
        'settings',
      );
      expect(
        PerfProbe.routeDeclaredPageId(
          routeTypeString: 'HyperosPageRoute<CourseOverviewScreen>',
        ),
        'CourseOverviewScreen',
      );
    });

    test('pageIdFrom 的兜底链保持不变（回溯那一侧仍需要它）', () {
      // 兜底链是「最后手段」，不是「认出页面」的判据：两件事必须分开，
      // 否则把兜底值当成识别结果，就会重演上面那个 bug。
      expect(
        PerfProbe.pageIdFrom(routeTypeString: 'MaterialPageRoute<dynamic>'),
        'MaterialPageRoute',
      );
    });
  });

  group('报表头带得上解释读数所需的环境', () {
    test('meta 给 CPU 核数、不给会误导的 deviceModel', () {
      // 真机读数 cpuMs=48980 / spanMs=39317 ≈ 1.25 个核。这个数要能解释，
      // 就必须知道机器有几个核（8 核里占 1.25 与 2 核里占 1.25 含义完全不同）。
      // 而 `Platform.localHostname` 在 Android 上恒为 "localhost"，写进报表
      // 只会让读的人以为探针认出了机型 —— 删掉，机型由采集侧配对提供。
      final meta = PerfProbe.debugMeta();
      expect(meta['cpuCount'], isA<int>());
      expect(meta.containsKey('deviceModel'), isFalse);
    });
  });
}

/// 可控的 [ChangeNotifier]：只用来数「挂了几个监听」并手动触发。
/// 真 provider 的 notify 依赖整个设置对象，测试里没必要拖进来。
class _FakeListenable extends ChangeNotifier {
  int _count = 0;

  /// 已注册的监听者数量。
  int get listenerCount => _count;

  @override
  void addListener(VoidCallback listener) {
    _count++;
    super.addListener(listener);
  }

  void notify() => notifyListeners();
}
