// 主路径 2/5 第二阶段（读）：全新进程冷启动 → 上一阶段写的课还在首页上
//
// 运行配方与原理见同目录 `persist_write_phase_test.dart` 的文件头。
// 简版：
//
//   flutter test integration_test/persist_write_phase_test.dart \
//     -d <device-id> --flavor itest --no-uninstall    # 阶段一：写
//   flutter test integration_test/persist_read_phase_test.dart \
//     -d <device-id> --flavor itest                    # 阶段二：读
//
// 第一次跑之前不需要单独准备什么：阶段一自己会建立数据。
//
// ⚠️ 单独跑本文件（不先跑阶段一）**必然失败**，因为磁盘里没有那门课。
// 这不是 bug —— 本文件的设计前提就是「上一个进程写过东西」。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:university_timetable/main.dart' as app;
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/course_card.dart';
import 'package:university_timetable/widgets/timetable/timetable_week_grid.dart';

import 'persist_fixture.dart';

/// 首页出现的等待上限：真机冷启动要跑完整个启动管线。
const Duration _homeRevealTimeout = Duration(seconds: 30);

/// 单次轮询步长：`pump` 推进一帧并真实等待这么久。
const Duration _pollStep = Duration(milliseconds: 100);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('阶段二（读，全新进程）：上一阶段加的课仍在首页网格上', (tester) async {
    // ---- 1. 先不启动 App，直接问磁盘：那门课在不在 ----
    //
    // 这一步与 UI 无关，单独失败时的含义很明确：**数据根本没活过进程重启**。
    // 把它放在启动 App 之前，是为了让失败原因不被界面层的水花盖住。
    //
    // 注意这里**没有** resetForTesting：本进程是新的，存储还没被初始化过，
    // 第一次 init() 就是真读磁盘。若在这里 reset 反而会多绕一圈。
    final coursesOnDisk = await StorageService().getCourses();
    final survived = coursesOnDisk.where((c) => c.name == kPersistCourseName);

    expect(
      survived,
      isNotEmpty,
      reason:
          '阶段一明明写过「$kPersistCourseName」，全新进程却从磁盘读不到它：'
          '数据没有活过进程重启（写没落盘 / 落到了别处 / 被清了）。'
          '这是本路径最核心的失败，先确认阶段一跑过且带了 --no-uninstall',
    );

    // 字段级核对：不只是「名字还在」，是「完整地还在」。
    final persisted = survived.first;
    final expected = persistFixtureCourse();
    expect(
      persisted.dayOfWeek,
      expected.dayOfWeek,
      reason: '落盘/读回过程中星期被改了',
    );
    expect(
      persisted.startSection,
      expected.startSection,
      reason: '落盘/读回过程中节次被改了',
    );
    expect(
      persisted.teacher,
      expected.teacher,
      reason: '落盘/读回过程中教师被改了',
    );
    expect(
      persisted.location,
      expected.location,
      reason: '落盘/读回过程中地点被改了',
    );

    // ---- 2. 再用真的 App 冷启动一次，确认它出现在界面上 ----
    //
    // 「磁盘里有」不等于「用户看得见」。这一段补上渲染那半截。
    unawaited(app.main());

    await _pumpUntil(
      tester,
      () => find.byType(TimetableScreen).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '冷启动 ${_homeRevealTimeout.inSeconds}s 内首页未换入',
    );
    await _pumpUntil(
      tester,
      () => find.byType(TimetableWeekGrid).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '首页已换入但周课表网格没出现',
    );

    // ---- 3. 那门课的卡片真的在网格上 ----
    await _pumpUntil(
      tester,
      () => _courseCardNamed(tester, kPersistCourseName) != null,
      timeout: _homeRevealTimeout,
      reason:
          '磁盘里读得到「$kPersistCourseName」，但首页网格上找不到它的卡片：'
          '数据活着、界面没画出来（用户症状：课还在，但打开看不到）',
    );

    // 卡片不是 0 尺寸的幽灵。
    final cardFinder = _courseCardNamed(tester, kPersistCourseName)!;
    final cardSize = tester.getSize(cardFinder.first);
    expect(cardSize.width, greaterThan(0), reason: '卡片宽度为 0：布局成了不可见尺寸');
    expect(cardSize.height, greaterThan(0), reason: '卡片高度为 0：布局成了不可见尺寸');

    // ---- 4. 再确认一次：App 读回来的数据与磁盘一致，没有被默认值覆盖 ----
    //
    // 这条防的是「启动管线用默认设置把读到的数据盖掉了」这类 bug——
    // 界面能画出来、但画的是错的（比如全被塞到第 1 天第 1 节）。
    final card = tester.widget<CourseCard>(cardFinder.first);
    expect(
      card.course.dayOfWeek,
      expected.dayOfWeek,
      reason: '界面上那门课的星期与磁盘不一致：启动过程把它覆盖了',
    );
    expect(
      card.course.startSection,
      expected.startSection,
      reason: '界面上那门课的节次与磁盘不一致：启动过程把它覆盖了',
    );
  });
}

/// 找出网格里「课程名 == [name]」的那张 `CourseCard`；没有则返回 null。
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
/// 与其它 integration test 同一份实现、同一条理由：首页永不停滞到「静止」，
/// `pumpAndSettle()` 只会等到超时。
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
