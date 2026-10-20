// 主路径 1/5：冷启动 → 首页渲染出来
//
// 这是 `integration_test/` 的**破冰文件**：在此之前整个目录不存在，
// 「东西在真机上真能用」这一层完全空白（见 AGENTS.md 的 TEST-POLICY 节）。
//
// ## 这条路径到底证明什么
//
// 它跑的是**真的 `main()`**，不是手工拼出来的 `MaterialApp`：
// `WidgetsFlutterBinding.ensureInitialized()` → `deferFirstFrame()` →
// `runApp(MyApp(...))` → `AppEntryScreen` 里的启动管线（读 prefs、初始化
// provider、预热视觉资产、等玻璃/顶栏 shader）→ `_revealHomeOnce()` 换入首页。
// 这条链上任何一环在真机上挂死，用户看到的是「停在启动画面」——本文件就是
// 那个症状的自动化探针。
//
// ## 为什么不能断言「立刻就有首页」
//
// `main()` 第一件事是 `WidgetsBinding.instance.deferFirstFrame()`
// （lib/main.dart:285）：框架照常构建帧，但先别投给引擎。首页要等
// `_revealHomeOnce()`（main.dart:749）把 `_homeRevealed` 翻成 true 才进
// widget 树；`AnimatedSwitcher` 的两个分支（`AppStartupSplash` / `home`，
// main.dart:1788）都留在树上，谁在渲染取决于那个标志。
//
// 所以断言一律用**轮询等待**（`_pumpUntil`），等的是「首页真的出现了」，
// 既不是「等固定 N 秒」，也不是「widget 树非空」。如果只 pump 几次就断言，
// 拿到的一定是启动画面——首帧放行 / provider 初始化 / 视觉预热 / shader
// 编译这三段在真机冷启动上远比组件测试的假时钟慢。
//
// 兜底时间比 6s 看门狗宽：`main()` 里有个 6 秒首帧看门狗（main.dart:288），
// 启动管线真挂死时它会强制放行 + 强制换入。那种情况**仍然算通过**——它确实
// 是用户能用的状态，只是慢了；真实的性能退化不该由这条功能路径测试判红。
//
// ## 为什么自己造 SharedPreferences 初始值（重要，涉及共享设备安全）
//
// 冷启动有两条分支（main.dart:1018 起）：
//   - 老用户快速路径：`hasAcceptedPrivacyPolicy && hasSeenUserGuide` 都为真
//     → `provider.initialize()` → `_revealHomeOnce()`；
//   - 新用户引导路径：先弹引导页，`_openGuide(...)` 会 await 用户操作。
//
// 真机**首次安装**走的是第二条，那时首页不会自己出现（等用户点完引导）。
// 测试设备多半是全新安装，所以这里显式预置那两个键，把用例固定在
// 「老用户冷启动」这条路径上——这也正是存量用户每天的走法。
//
// 另外这一手把存储换成**内存实现**（`setMockInitialValues` 会替换
// `SharedPreferencesStorePlatform.instance`）：integration test 跑在设备上
// 与 App 同包名，不这样的话会**读写这台设备上真实用户的数据**。共享设备上
// 那既危险又会互相污染。代价是「从真实磁盘读回」这一点没被覆盖——那属于
// 「改设置 → 杀进程重开 → 设置还在」那条主路径（第 4 条），不该由本条背。
//
// ## 已知局限（如实记录，不要当成已覆盖）
//
// 1. `main()` 自己装了 `FlutterError.onError`（main.dart:311），会顶掉
//    flutter_test 的异常收集器。所以**启动期间的框架异常不会自动让本用例变红**，
//    只会被 App 记进 AppLogService。本用例靠「首页到底有没有出来」判成败。
// 2. 只验首页骨架（周网格 + 星期栏），不验「有课」的情形——那要先造数据。
// 3. 首次安装的引导路径未覆盖（本用例固定走老用户快速路径）。
// 4. 换入耗时没有性能门槛（见上文看门狗那段）。
//
// ## 怎么跑
//
// 前提：`pubspec.yaml` 的 dev_dependencies 里要有 `integration_test: sdk: flutter`。
// 缺这一条，`flutter test` 会在 commands/test.dart:638 直接拒绝执行。依赖变更
// 必须在 **Windows 侧**跑 `flutter pub get` 才生效，WSL 侧禁止（见
// docs/WSL_DEVELOPMENT.md：会改写两边共用的 package_config.json）。
//
// 设备：真机或已启动的模拟器，`flutter devices` 能列出来即可。
// **未经用户明确许可，不要用本文件去控制实体设备**（AGENTS.md 的 DEVICE-CONTROL 铁律）。
//
//   flutter test integration_test/cold_start_home_test.dart -d <device-id>
//
// 本仓 android 有 dev / perf / prod 三个 flavor（android/app/build.gradle:79）：
//
//   flutter test integration_test/cold_start_home_test.dart -d <device-id> --flavor dev
//
// 读结果：
//   - 绿 = 冷启动管线在设备上跑通，首页的周网格与星期栏真的渲染出来了；
//   - 红在第一段（连 AppStartupSplash 都没出现）= 启动画面的分支结构变了；
//   - 红在第二段（TimetableScreen 没出现）= 设备上「卡在启动画面」。先看
//     logcat 里 `[boot]` 开头的日志，以及 AppLogService 里的
//     `home_reveal_watchdog` / `first_frame_watchdog` 记录。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:university_timetable/main.dart' as app;
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/app_startup_splash.dart';
import 'package:university_timetable/widgets/timetable/timetable_week_grid.dart';
import 'package:university_timetable/widgets/timetable/timetable_weekday_header.dart';

/// 首页出现的等待上限。
///
/// 为什么给得比 6s 看门狗宽：真机冷启动要跑完整个启动管线——prefs 读取、
/// provider 初始化、`HomeStartupVisualPrimer.prime()`（壁纸解码 + 高斯模糊
/// 烤图，自带 3s 预算，见 lib/utils/home_startup_visual_primer.dart:26）、
/// 玻璃与顶栏两个 shader 预热。低端机上这段真能到几秒。
/// 给宽一点，让「看门狗强制放行」这条降级路径也能判为通过（见文件头第 3 条局限）。
const Duration _homeRevealTimeout = Duration(seconds: 30);

/// 单次轮询步长。integration_test 跑在 LiveBinding 上，`pump(Duration)`
/// 会推进一帧并真的等这么久，所以这个值同时决定轮询的粒度。
///
/// 每一步都 `pump` 而不是干等 `Future.delayed`：启动管线里有一步是靠
/// `addPostFrameCallback` 触发的（预解码启动图标 → 放行首帧，main.dart:817），
/// 不推帧它就不会往前走。
const Duration _pollStep = Duration(milliseconds: 100);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // StorageService 是单例，会把 `_initFuture` / `_prefs` 缓存住。
    // 本文件目前只有一个用例，但下一个人加第二个用例时不清这里会拿到上一轮
    // 的内存状态（尤其是 provider 已初始化），症状是「第二个用例莫名通过/失败」。
    StorageService().resetForTesting();

    // 把存储换成内存实现，并预置「已接受隐私政策 + 已看过引导」两个键，
    // 使冷启动走老用户快速路径。键名与 lib/services/storage_service.dart 的
    // _acceptedPrivacyPolicyKey / _hasSeenUserGuideKey 对齐；
    // setMockInitialValues 会自动补 `flutter.` 前缀。
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accepted_privacy_policy': true,
      'has_seen_user_guide': true,
    });
  });

  testWidgets('冷启动：真的 main() 跑完，首页的周课表网格出现在屏幕上', (tester) async {
    // 直接调 App 真正的入口。这一句就包含了 deferFirstFrame + runApp +
    // AppEntryScreen 的整条启动管线。
    //
    // 不 await：main() 要等 PackageInfo 等平台通道，而我们**必须自己推帧**
    // 启动管线才会前进（见 _pollStep 的注释）。await 它等于在等一件需要靠
    // 推帧才能完成的事。
    unawaited(app.main());

    // 先确认启动画面确实先出现。这一步证明我们真的站在冷启动路径上，
    // 而不是因为某处改动把启动阶段整个跳过了（那属于要人看的回归）。
    await _pumpUntil(
      tester,
      () => find.byType(AppStartupSplash).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
      reason: '冷启动应当先渲染自绘启动画面（AppStartupSplash）',
    );

    // 核心断言一：首页换入（AppEntryScreen 把 _homeRevealed 翻成 true）。
    await _pumpUntil(
      tester,
      () => find.byType(TimetableScreen).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason:
          '冷启动 ${_homeRevealTimeout.inSeconds}s 内首页仍未换入'
          '（TimetableScreen 不在树上）。这对应设备上「永远停在启动画面」的症状：'
          '查首帧放行（_releaseFirstFrame）、_revealHomeOnce，'
          '以及 provider.initialize() / HomeStartupVisualPrimer.prime() 是否挂死',
    );

    // 核心断言二：首页骨架真的画出来了——周视图网格。
    // 断言网格而不是「widget 树非空」：课可以为空，网格必须在。
    await _pumpUntil(
      tester,
      () => find.byType(TimetableWeekGrid).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '首页已换入但周课表网格（TimetableWeekGrid）没出现：首页骨架没搭起来',
    );

    // 核心断言三：星期栏（周一到周日那一行）也在。
    // 网格 + 星期栏同时在场，才算「能读懂的课表」，而不是一个空壳页面。
    await _pumpUntil(
      tester,
      () => find.byType(TimetableWeekdayHeader).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '首页已换入但星期栏（TimetableWeekdayHeader）没出现',
    );

    // 断言四：启动画面退场了，首页真的接管。
    //
    // 这里同样不用「固定等 300ms」：换入的交叉淡入时长走
    // `HyperosMotionPlatform.scaledDuration(kHomeRevealFadeMs)`
    // （main.dart:218、1785），会跟着设备的「动画时长」设置缩放——把时长
    // 写死，在动效调慢的设备上就会假红。
    await _pumpUntil(
      tester,
      () => find.byType(AppStartupSplash).evaluate().isEmpty,
      timeout: const Duration(seconds: 15),
      reason: '首页已换入，但启动画面（AppStartupSplash）一直没退场：两棵树叠在一起了',
    );

    // 断言五：给一条人可读的实锤——网格是有面积的，不是 0 尺寸。
    // 「找到了 widget」和「它真的占了屏幕」是两件事，后者才是用户看得见的。
    final gridSize = tester.getSize(find.byType(TimetableWeekGrid).first);
    expect(
      gridSize.width,
      greaterThan(0),
      reason: '周课表网格宽度为 0，说明它被布局成了不可见尺寸',
    );
    expect(
      gridSize.height,
      greaterThan(0),
      reason: '周课表网格高度为 0，说明它被布局成了不可见尺寸',
    );
  });
}

/// 轮询 [condition] 直到为真；超过 [timeout] 仍未成立就带着 [reason] 失败。
///
/// 为什么不用 `pumpAndSettle()`：首页永远不会「静止」——星期栏选中态、
/// 玻璃表面、下拉回弹都带常驻动画或持续重绘，`pumpAndSettle` 只会等到超时。
/// 所以这里按固定步长推进，直到目标 widget 出现为止。
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  required String reason,
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (condition()) {
      return;
    }
    await tester.pump(_pollStep);
  }
  // 最后一次 pump 之后条件可能刚好成立，不复查就会把「只差一步」误报成失败。
  if (condition()) {
    return;
  }
  fail('$reason（已等待 ${stopwatch.elapsed.inMilliseconds}ms）');
}
