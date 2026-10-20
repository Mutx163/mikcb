// 主路径 1/5（深化版）：冷启动 → **存储里已有的课真的出现在首页网格上**
//
// ## 为什么从「首页渲染出来」加深到「那门课在里面」
//
// 上一版只断言「周网格存在 + 星期栏存在」。用户的原话是「这么简单的」——
// 他说得对：首页画出来不等于**数据活着**。启动管线里「读存储 → 解析 →
// 灌进 provider → 网格布局 → 卡片绘制」这条链任何一环断掉，旧版断言照样绿，
// 用户看到的却是「我的课表空了」。
//
// 所以这一版的核心差别是：**启动之前先往磁盘写一门带唯一标记的课，
// 启动之后断言这门课的卡片真的出现在网格里。**
//
// 这同时把测试从「内存 mock」升级成「真的读设备磁盘」——见下面「存储」一节。
//
// ## 存储：真的写磁盘，但写在隔离包里
//
// 2026-10-20 出过一次事故：用 `--flavor dev` 跑测试，而 `flutter test` 跑完会
// **卸载**它装的包（`integration_test_device.dart:147` 的 `uninstallApp`，
// 默认 true，见 `commands/test.dart:301`），于是用户日常调试的 `.debug` 包
// 连同数据一起没了。细节见 README。
//
// 现在有专用 flavor `itest`（包名 `com.mutx163.qingyu.itest`，
// android/app/build.gradle:118）。`.itest` 与 prod / profile / dev 三个包完全隔离，
// 所以：
//   - 可以**放心用真实磁盘存储**（不再需要 `setMockInitialValues` 那份内存替身）；
//   - 装、跑、卸载都只影响它自己，碰不到用户任何真实数据。
//
// 这一步很关键：用内存 mock 的话，「读磁盘」这条链根本没被验证——
// 而那正是本路径要证明的东西。
//
// ## 怎么跑
//
//   flutter test integration_test/cold_start_home_test.dart \
//     -d <device-id> --flavor itest
//
// `--flavor itest` 不能省。`-d` 也不能省（不指定时 flutter_tools 自己挑设备，
// 见 commands/test.dart:621）。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:university_timetable/main.dart' as app;
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/course_card.dart';
import 'package:university_timetable/widgets/timetable/timetable_week_grid.dart';
import 'package:university_timetable/widgets/timetable/timetable_weekday_header.dart';

/// 首页出现的等待上限。真机冷启动要跑完整个启动管线（prefs 读取、provider
/// 初始化、视觉预热、两个 shader 编译），低端机上能到几秒；给宽一点，
/// 让 6s 首帧看门狗强制放行那条降级路径也能判为通过（它是可用状态，只是慢）。
const Duration _homeRevealTimeout = Duration(seconds: 30);

/// 单次轮询步长：`pump` 推进一帧并真实等待这么久。
const Duration _pollStep = Duration(milliseconds: 100);

/// 启动前写进磁盘的那门课的**唯一标记名**。
///
/// 带下划线与版本号，保证不可能与任何真实课程重名——「按名字找卡片」
/// 因此不会误命中。改这个名字等于换测试数据，没别的含义。
const String _seededCourseName = 'itest_seed_week1_course';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 这套用例往**真实磁盘**写（隔离包 .itest 的私有目录），所以每次开始前
    // 先清干净：resetForTesting 丢掉内存缓存与写链，下一句 init() 重新拿
    // SharedPreferences 实例。再显式清掉课程键，避免上一个用例的残留。
    StorageService().resetForTesting();
    await StorageService().init();
    await StorageService().saveCourses(const <Course>[]);

    // 预置「已接受隐私政策 + 已看过引导」：冷启动有两条分支
    // （main.dart:1018 起），都为真才走老用户快速路径直接换入首页；
    // 否则会弹引导页并 await 用户点击，首页永远不出现。
    await StorageService().setAcceptedPrivacyPolicy(true);
    await StorageService().setHasSeenUserGuide(true);

    // 写一门课进磁盘。这里走的是 App 自己保存时用的同一个
    // `saveCourses`（存储层的写链），不是旁路。
    await StorageService().saveCourses(<Course>[_seededCourse()]);

    // 再丢一次缓存：确保接下来 app.main() 里的 provider 是**从磁盘重新读**，
    // 而不是复用上面这次写入留在内存里的东西。这一步是把「写入」与
    // 「读取」两件事真正隔开的关键。
    StorageService().resetForTesting();
  });

  testWidgets('冷启动：磁盘里那门课真的出现在首页网格上', (tester) async {
    // 调 App 真正的入口：deferFirstFrame + runApp + 整条启动管线。
    // 不 await——启动管线要靠推帧前进（见 _pumpUntil 的注释）。
    unawaited(app.main());

    // ---- 1. 首页换入 ----
    await _pumpUntil(
      tester,
      () => find.byType(TimetableScreen).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '冷启动 ${_homeRevealTimeout.inSeconds}s 内首页未换入（TimetableScreen 不在树上）',
    );

    // ---- 2. 首页骨架就位 ----
    await _pumpUntil(
      tester,
      () => find.byType(TimetableWeekGrid).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '首页已换入但周课表网格（TimetableWeekGrid）没出现',
    );
    await _pumpUntil(
      tester,
      () => find.byType(TimetableWeekdayHeader).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '首页已换入但星期栏（TimetableWeekdayHeader）没出现',
    );

    // ---- 3. 核心断言：那门课真的从磁盘读出来、并画在网格上 ----
    //
    // 这是本文件与上一版的根本区别：不是「有网格」，是**「这门课在网格里」**。
    // 它同时证明了三件事：磁盘有数据、解析成功、渲染链路把它画出来了。
    await _pumpUntil(
      tester,
      () => _courseCardNamed(tester, _seededCourseName) != null,
      timeout: _homeRevealTimeout,
      reason:
          '磁盘里明明写着「$_seededCourseName」，首页却找不到它的卡片：'
          '「读存储 → 解析 → 渲染」这条链断了（用户症状：启动后课表是空的）',
    );

    // ---- 4. 卡片真的占了屏幕（不是 0 尺寸的幽灵） ----
    final cardFinder = _courseCardNamed(tester, _seededCourseName)!;
    final cardSize = tester.getSize(cardFinder.first);
    expect(
      cardSize.width,
      greaterThan(0),
      reason: '课程卡片宽度为 0：卡片被布局成了不可见尺寸',
    );
    expect(
      cardSize.height,
      greaterThan(0),
      reason: '课程卡片高度为 0：卡片被布局成了不可见尺寸',
    );

    // ---- 5. 数据层也对得上（不只是画了一张写着名字的卡） ----
    //
    // 卡片上显示的名字可能来自任何地方；这里再回读卡片持有的 course，
    // 确认「星期/节次」这两个决定它画在哪一格的字段没在读取过程中被改掉。
    final card = tester.widget<CourseCard>(cardFinder.first);
    expect(
      card.course.dayOfWeek,
      _seededCourse().dayOfWeek,
      reason: '卡片上的课星期与磁盘里的不一致：读取/解析过程改了字段',
    );
    expect(
      card.course.startSection,
      _seededCourse().startSection,
      reason: '卡片上的课节次与磁盘里的不一致：读取/解析过程改了字段',
    );
  });
}

/// 启动前写进磁盘的那门课。
///
/// 选第 2 天第 3 节：不在默认值（1/1）上，所以万一某处把字段丢了、
/// 回落到默认值，断言会立刻红——而不是因为「默认值恰好也在这里」假通过。
Course _seededCourse() {
  return Course(
    id: 'itest-seeded-course-0001',
    name: _seededCourseName,
    teacher: '集成测试',
    location: '测试地点',
    dayOfWeek: 2,
    startSection: 3,
    endSection: 4,
    startTime: '09:00',
    endTime: '10:30',
    color: '#FF6B6B',
  );
}

/// 找出网格里「课程名 == [name]」的那张 `CourseCard`；没有则返回 null。
///
/// 按 `CourseCard.course.name` 找，而不是只数 `CourseCard` 的数量：
/// 数量断言抓不到「别的课出现在这里」，而本测试要钉的正是「**这门**课在」。
Finder? _courseCardNamed(WidgetTester tester, String name) {
  final finder = find.byType(CourseCard);
  for (var i = 0; i < finder.evaluate().length; i++) {
    final card = tester.widget<CourseCard>(finder.at(i));
    if (card.course.name == name) {
      return find.byType(CourseCard).at(i);
    }
  }
  return null;
}

/// 轮询 [condition] 直到为真；超时仍未成立就带着 [reason] 失败。
///
/// 不用 `pumpAndSettle()`：首页永远不会静止（常驻动画、玻璃表面、下拉回弹），
/// 它只会等到超时。每一步 `pump` 都推进一帧——启动管线里「预解码启动图标 →
/// 放行首帧」就是靠 `addPostFrameCallback`（main.dart:819）触发的，
/// 不推帧它不往前走。
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
  if (condition()) {
    return;
  }
  fail('$reason（已等待 ${stopwatch.elapsed.inMilliseconds}ms）');
}
