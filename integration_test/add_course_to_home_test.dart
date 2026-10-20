// 主路径 2/5：加一门课 → 保存 → 首页能看到
//
// 这是继「冷启动 → 首页渲染出来」之后第二条真机路径。与第 1 条的区别：
// 第 1 条只读（空存储启动），这一条**要写**——它会真的往存储里加一门课。
//
// ## 这条路径要证明什么
//
// 用户视角的一句话：**在课表上点一个空格、填个名字、点保存，然后真的能在课表上看到它。**
// 中间任何一环断掉，用户看到的是「保存了但课表没变」或者「课表变了但位置不对」。
//
// 所以断言必须**两头顶**（缺一不可）：
//   1. 数据层：`provider.courses` 里确实多了这门课，且**星期/节次就是点的那一格**；
//   2. 界面层：回到首页后，那门课的卡片真的画在屏幕上，且有非零面积。
//
// 只钉第 1 条 → 抓不到「存进去了但画不出来」（用户什么都看不见）；
// 只钉第 2 条 → 抓不到「画出来了但存在错的格子里」（断言按类型找照样通过）。
//
// ## 为什么走「长按空槽」这条入口
//
// 首页加课有几条入口，选这条的理由：
//   - 它是**参数最全**的一条：`_openAddCourseFromEmptySlot(week, dayOfWeek,
//     startSection, endSection)`（timetable_screen.dart:1339）四个参数一起进表单，
//     正好能验「参数透传」——AGENTS.md 的 TEST-POLICY 点名要求这类改动必须
//     直接断言目标对象收到的字段，不能只断言「页面打开了」；
//   - 「更多菜单 → 添加」那条要走玻璃弹层的形变动画（`showTopActionsSheet`），
//     动画链长、不稳定，而且它最终弹出的加课弹层不带槽位参数，验不到透传。
//
// 代价：长按入口默认**关闭**（`longPressEmptySlotToAddCourseEnabled = false`，
// timetable_settings.dart:802），所以测试先用 provider 的公开 API 把它打开。
// 这不是绕过被测代码——那个开关本来就是真实用户能在设置里打开的。
//
// ## 为什么「保存」这一步必须真点 UI
//
// 造数据可以走 provider API（见下），但**保存这一下必须点**：本路径要验的正是
// 「表单 → provider」这一跳。直接调 `provider.addCourse` 就把要验的东西绕没了。
//
// ## 造数据的边界
//
// 除了「打开那个开关」和「点保存」，本测试**不点任何 UI 造数据**：
// 输入课程名用 `tester.enterText`（等价于用户打字，但避开输入法/焦点问题），
// 其余一切走默认值。理由：输入法、滚动、校验弹层任何一处不稳都会变成假红，
// 而那些不是这条路径要验的东西。
//
// ## 已知坑（读源码得出）
//
// `_saveCourse` 里有 `await Future<void>.delayed(Duration(milliseconds: 16))`
// （add_course_screen.dart:1951）再校验、再落盘；保存成功后还要弹一次 toast
// 再 `Navigator.pop`。所以**点完保存不能立刻断言**，必须轮询等
// `provider.courses` 变化（见 `_pumpUntil`）。
//
// ## 破坏性提醒
//
// 这条路径**写数据**，写的是**真实磁盘**（专用 flavor `itest`，包名
// `com.mutx163.qingyu.itest`，与 prod/profile/dev 完全隔离）。
// 之所以敢用真盘：2026-10-20 的事故是「用 dev flavor 跑测试 → 跑完自动卸载
// → 用户 .debug 包的数据没了」，隔离包名之后这条路走不通了。
//
// 用真盘而不是内存 mock，是因为本路径要验「保存真的落盘了」——
// 内存替身会把这一条绕过去。详见 README 的事故记录。
//
// ## 怎么跑
//
//   flutter test integration_test/add_course_to_home_test.dart \
//     -d <device-id> --flavor itest
//
// **`-d` 不能省**：不指定时 flutter_tools 会自己挑设备（commands/test.dart:621），
// 只连着一台手机时就会装上去跑——那是在控制用户的实体设备。详见 README。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:university_timetable/main.dart' as app;
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/domain/timetable_layout.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/add_course_screen.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/course_card.dart';
import 'package:university_timetable/widgets/timetable/timetable_week_grid.dart';
import 'package:university_timetable/widgets/timetable/timetable_weekday_header.dart';

/// 首页出现的等待上限。与第 1 条同口径（真机冷启动要跑完整个启动管线）。
const Duration _homeRevealTimeout = Duration(seconds: 30);

/// 单次轮询步长：`pump` 推进一帧并真实等待这么久。
const Duration _pollStep = Duration(milliseconds: 100);

/// 本测试要加的那门课的名字。
///
/// 取一个**不可能与任何真实课程重名**的值（带下划线与数字），
/// 这样「按名字找卡片」不会误命中。中文名同样可行，但纯 ASCII 更利于排错时 grep。
const String _courseName = 'itest_lane_2_course';

/// 长按进入哪一格：第 3 天（周三）、第 5 节。
///
/// 为什么不是「第 1 天第 1 节」：1/1 是最容易被**默认值**命中的位置——
/// 表单的默认 `dayOfWeek` 就是 1、默认 `startSection` 也是 1
/// （add_course_screen.dart:324-325 的 `?? 1`）。若测试点第 1 天第 1 节，
/// 即使 `initialDayOfWeek` / `initialStartSection` 这两个参数**完全没被转发**，
/// 表单拿到默认值也照样是 1/1，断言会假通过。
/// 选一个默认值之外的位置，参数透传一旦断掉，断言立刻红。
const int _targetDayOfWeek = 3;
const int _targetSection = 5;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 单例存储会把 `_initFuture` / `_prefs` 缓存住；每个用例前清一次，
    // 避免用例之间串状态。
    StorageService().resetForTesting();
    await StorageService().init();

    // 从空课表起步：本用例要验「加课前后」，前提是加之前确实没有。
    await StorageService().saveCourses(const <Course>[]);

    // 预置「已接受隐私政策 + 已看过引导」，让冷启动走老用户快速路径
    // （否则全新安装会停在引导页等用户点击，首页永远不出现）。
    //
    // 这里写的是**真实磁盘**（隔离包 .itest 的私有目录），不是内存 mock：
    // 本用例要验「保存真的落盘」，内存替身会把这一条绕过去。
    // 隔离包名保证碰不到用户真实数据，见文件头的「破坏性提醒」。
    await StorageService().setAcceptedPrivacyPolicy(true);
    await StorageService().setHasSeenUserGuide(true);

    // 丢掉缓存，确保接下来 app.main() 里的 provider 从磁盘重新读。
    StorageService().resetForTesting();
  });

  testWidgets('加一门课 → 点保存 → 首页上出现这门课的卡片', (tester) async {
    unawaited(app.main());

    // ---- 1. 等首页起来（与第 1 条同一套等待逻辑） ----
    await _pumpUntil(
      tester,
      () => find.byType(TimetableScreen).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '冷启动 ${_homeRevealTimeout.inSeconds}s 内首页未换入（TimetableScreen 不在树上）',
    );
    await _pumpUntil(
      tester,
      () => find.byType(TimetableWeekGrid).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '首页已换入但周课表网格没出现',
    );
    // 网格里要有可点的空格，星期栏也得在（说明这一页真的排好了）。
    await _pumpUntil(
      tester,
      () => find.byType(TimetableWeekdayHeader).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '首页已换入但星期栏没出现',
    );

    // ---- 2. 打开「长按空格加课」开关（该设置默认关闭） ----
    //
    // 走 provider 的公开写 API，与用户在设置页拨开关是同一条落盘路径。
    // 不点设置页 UI 造这个前置条件：那要跳好几层页面，任何一层不稳都会假红，
    // 而这个开关本身不是本路径要验的东西。
    final provider = _providerFrom(tester);
    expect(
      provider.courses,
      isEmpty,
      reason: '这条测试假定从空课表起步；存储没被重置或上一个用例漏了清理',
    );
    await provider.updateSettings(
      provider.settings.copyWith(longPressEmptySlotToAddCourseEnabled: true),
    );
    // 让界面跟上这个设置变化（网格手势层要重建一帧）。
    // 这里不能用「等某个东西消失」的轮询：标记本来就不在场，
    // 条件立刻为真等于没等。推两帧让 rebuild 落地即可。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // ---- 3. 长按第 3 天第 5 节那一格，出现虚线标记 ----
    final gridRect = tester.getRect(find.byType(TimetableWeekGrid).first);
    final markerPoint = _cellCenter(
      tester,
      gridRect: gridRect,
      provider: provider,
      dayOfWeek: _targetDayOfWeek,
      section: _targetSection,
    );
    final gesture = await tester.startGesture(markerPoint);
    // 长按判定的默认阈值是 500ms（kLongPressTimeout）；给足余量。
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pump();

    await _pumpUntil(
      tester,
      () =>
          find.byKey(const ValueKey('empty-slot-add-marker')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
      reason:
          '长按空格后没有出现添加标记（empty-slot-add-marker）。'
          '可能是长按手势没落在可点格子上，或 longPressEmptySlotToAddCourseEnabled 没生效',
    );

    // ---- 4. 点标记 → 进加课表单 ----
    await tester.tap(find.byKey(const ValueKey('empty-slot-add-marker')).first);
    await _pumpUntil(
      tester,
      () => find.byType(AddCourseScreen).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      reason: '点了空槽标记但加课表单（AddCourseScreen）没打开',
    );

    // ⚠️ 必须等**转场动画真正走完**，不能只等「widget 进了树」。
    //
    // 2026-10-20 真机实测（第一次跑就踩到）：页面 push 时顶栏从屏幕右侧外面
    // 滑进来，`AddCourseScreen` 在两三帧内就进树了，但顶栏还停在 x≈412.6
    // （屏宽只有 393.8）。此时点保存键 = 点在屏幕外，`tap` 的命中测试落空，
    // 日志里只有一条 "would not hit test on the specified widget" 警告，
    // 表现为「点了保存但什么都没发生」，极难定位。
    //
    // 判据：等保存按钮（按 semantics 找）的矩形中心真正落在屏幕内。
    // 这比「等固定 500ms」可靠——转场时长走
    // `HyperosMotionPlatform.scaledDuration`，会跟着设备的动画速度设置变。
    //
    // `find.bySemanticsLabel` 要求语义树开启（否则抛 StateError），
    // 所以这里先 ensureSemantics，用完在文件末尾统一 dispose。
    final semanticsHandle = tester.ensureSemantics();
    await _pumpUntil(
      tester,
      () {
        final saveFinder = find.bySemanticsLabel('保存');
        if (saveFinder.evaluate().isEmpty) {
          return false;
        }
        final rect = tester.getRect(saveFinder.first);
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        return rect.center.dx > 0 &&
            rect.center.dx < screen.width &&
            rect.center.dy > 0 &&
            rect.center.dy < screen.height;
      },
      timeout: const Duration(seconds: 15),
      reason: '加课表单的保存按钮一直没滑进屏幕（页面转场没走完，或顶栏布局溢出）',
    );

    // ---- 5. 核心断言 A：表单收到的初始槽位 = 用户点的那一格（参数透传） ----
    //
    // 这里断言的是**目标对象实例字段**，不是「页面打开了」。
    // AGENTS.md 的 TEST-POLICY 有实证：删掉 `initialCourse` 的转发后，
    // 存量 43 例 UI 测试全绿——它们只断言页面打开了。
    final form = tester.widget<AddCourseScreen>(find.byType(AddCourseScreen));
    expect(
      form.initialDayOfWeek,
      _targetDayOfWeek,
      reason:
          '表单收到的 initialDayOfWeek 与长按的那一天不符：'
          '空槽 → 表单的参数透传断了（用户点周三，表单却预填别的日子）',
    );
    expect(
      form.initialStartSection,
      _targetSection,
      reason:
          '表单收到的 initialStartSection 与长按的那一节不符：'
          '空槽 → 表单的参数透传断了',
    );

    // ---- 6. 填课程名（真实用户的打字动作，但不引入输入法依赖） ----
    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, _courseName);
    await tester.pump();

    // ---- 7. 点保存（本路径要验的核心一跳：表单 → provider） ----
    //
    // 保存键在顶栏，是按 semantics label 找的图标按钮（`FHeaderAction` 里
    // 包了 `Semantics(label: ...)`）。
    //
    // ⚠️ 两个必须注意的点：
    //   1. `find.bySemanticsLabel` 要求**语义树已开启**——`semanticsHandle`
    //      在上面等转场时已经开了，这里直接复用，别重复开。
    //   2. 它是**精确相等**匹配，不是 includes。所以这里能安全地用「保存」——
    //      不会误命中保存中的「保存中……」（那是另一个 label）。
    final saveButton = find.bySemanticsLabel('保存');
    expect(
      saveButton,
      findsOneWidget,
      reason: '没找到唯一的保存按钮（semanticsLabel「保存」），顶栏结构可能变了',
    );
    await tester.tap(saveButton);
    semanticsHandle.dispose();
    await tester.pump();

    // ---- 8. 核心断言 B：数据真的进了 provider，且字段就是点的那一格 ----
    //
    // 必须轮询：_saveCourse 里有 16ms 延迟 + 落盘 + toast + pop，点完不会立刻生效。
    await _pumpUntil(
      tester,
      () => provider.courses.any((c) => c.name == _courseName),
      timeout: const Duration(seconds: 15),
      reason:
          '点了保存但 provider.courses 里没有「$_courseName」：'
          '保存没有落库（校验没过 / 落盘失败 / 保存键没点到）',
    );

    final saved = provider.courses.firstWhere((c) => c.name == _courseName);
    expect(
      saved.dayOfWeek,
      _targetDayOfWeek,
      reason: '存下来的课不在长按的那一天：表单初始值或保存链路把星期改了',
    );
    expect(
      saved.startSection,
      _targetSection,
      reason: '存下来的课不在长按的那一节：表单初始值或保存链路把节次改了',
    );

    // ---- 9. 等表单关掉、回到首页 ----
    await _pumpUntil(
      tester,
      () => find.byType(AddCourseScreen).evaluate().isEmpty,
      timeout: const Duration(seconds: 15),
      reason: '保存成功后加课表单没有关闭（Navigator.pop 没执行）',
    );
    await _pumpUntil(
      tester,
      () => find.byType(TimetableWeekGrid).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '表单关闭后没有回到首页（周课表网格不在树上）',
    );

    // ---- 10. 核心断言 C：首页上真的画出了这门课的卡片，且有非零面积 ----
    //
    // 按 `CourseCard.course.name` 找，而不是只数 `CourseCard` 的数量：
    // 数量断言抓不到「错课出现在对的位置」或「对课出现在错的位置」。
    await _pumpUntil(
      tester,
      () => _courseCardNamed(tester, _courseName) != null,
      timeout: _homeRevealTimeout,
      reason:
          '数据里已经有「$_courseName」但首页上找不到它的卡片：'
          '课程卡没有渲染出来（用户「保存了但课表没变」）',
    );

    final cardFinder = _courseCardNamed(tester, _courseName)!;
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

    // 再钉一层位置：这张卡应当落在它该在的那一列里。
    // 卡片水平中心点的 x 若明显不在第 3 天那一列，说明排错天了
    // （数据对了、界面也画了，但画在了别的日子上）。
    final cardCenter = tester.getCenter(cardFinder.first);
    final expectedX = markerPoint.dx;
    final columnWidth = gridRect.width / 7; // 默认显示 7 天
    expect(
      (cardCenter.dx - expectedX).abs(),
      lessThan(columnWidth),
      reason:
          '课程卡片出现了，但水平位置偏离第 $_targetDayOfWeek 天那一列超过一整列宽：'
          '课程被排到了错误的日子上',
    );
  });
}

/// 从当前 widget 树里取 [TimetableProvider]。
///
/// `TimetableScreen` 的 context 就在 `MultiProvider` 之下，取得到。
TimetableProvider _providerFrom(WidgetTester tester) {
  final element = find.byType(TimetableScreen).evaluate().first;
  return Provider.of<TimetableProvider>(element, listen: false);
}

/// 找出首页上「课程名 == [name]」的那张 `CourseCard`；没有则返回 null。
///
/// 为什么按 `CourseCard.course.name` 而不是按类型数数量：见调用处的注释。
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

/// 把「第几天、第几节」换算成屏幕坐标（用于长按那一格）。
///
/// ## 算式来源（读源码抄的，不是猜的）
///
/// `TimetableWeekGrid`（lib/widgets/timetable/timetable_week_grid.dart:80）：
/// ```
/// dayWidth = (availableWidth - timeColumnWidth) / visibleDays.length
/// ```
/// 时间列在左侧、宽度 `timeColumnWidth`；每天一列等分剩下的宽度
/// （`:95` 的 `SizedBox(width: timeColumnWidth)` 是时间列，`:160` 是每天列）。
///
/// `timeColumnWidth` 由 `lib/domain/timetable_layout.dart:12` 给：
/// narrow = 34、wide = 40（逻辑像素），默认 narrow（timetable_settings.dart:761）。
///
/// 长按落在哪个格子由 `cellAt`（timetable_empty_slot_layer.dart:120）判定：
/// `dayIndex = (dx / dayWidth).floor()`、`sectionIndex = (dy / sectionHeight).floor()`，
/// 且 `section = sectionIndex + 1`。所以只要坐标落在目标格内部就够准，
/// 不需要像素级对齐。
///
/// ## 为什么用网格实测宽度算，而不是写死屏宽
///
/// 设备屏宽千差万别（这也是要跑真机的原因之一）。网格矩形 `gridRect` 是
/// 实测出来的（`tester.getRect`），时间列宽与节高从 provider 的设置里取真实值，
/// 所以换任何设备、改任何作息方案，这个换算都成立。
Offset _cellCenter(
  WidgetTester tester, {
  required Rect gridRect,
  required TimetableProvider provider,
  required int dayOfWeek,
  required int section,
}) {
  final settings = provider.settings;
  final timeColumnWidthValue = timeColumnWidth(settings);
  final visibleDays = settings.timetableHideWeekends
      ? const [1, 2, 3, 4, 5]
      : const [1, 2, 3, 4, 5, 6, 7];

  final dayAreaWidth = gridRect.width - timeColumnWidthValue;
  final dayWidth = dayAreaWidth / visibleDays.length;
  final sectionHeight = gridRect.height / settings.sectionCount;

  // 目标天在 visibleDays 里的下标（隐藏周末时 6/7 不在列表里）。
  final dayIndex = visibleDays.indexOf(dayOfWeek);
  expect(
    dayIndex,
    greaterThanOrEqualTo(0),
    reason:
        '第 $dayOfWeek 天不在当前可见天列表 $visibleDays 里'
        '（设置里隐藏了周末），这条测试挑的格子得是可见的',
  );

  final dx =
      gridRect.left + timeColumnWidthValue + dayWidth * (dayIndex + 0.5);
  final dy = gridRect.top + sectionHeight * (section - 0.5);
  return Offset(dx, dy);
}

/// 轮询 [condition] 直到为真；超过 [timeout] 仍未成立就带着 [reason] 失败。
///
/// 与第 1 条同一个实现、同一条理由：首页永远不静止，`pumpAndSettle()` 会等到超时；
/// 写死「等 N 秒」在慢设备上必假红。每一步 `pump` 都推进一帧，
/// 靠帧回调推进的启动/保存步骤才会往前走。
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
