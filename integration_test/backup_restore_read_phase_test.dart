// 主路径 5/5 第二阶段（读，全新进程）：备份恢复的数据真的活在磁盘上
//
// 运行配方见同目录 `backup_restore_write_phase_test.dart` 文件头。简版：
//
//   flutter test integration_test/backup_restore_write_phase_test.dart \
//     -d <device-id> --flavor itest --no-uninstall
//   flutter test integration_test/backup_restore_read_phase_test.dart \
//     -d <device-id> --flavor itest
//
// ⚠️ 单独跑本文件必然失败（磁盘里还没有恢复的数据）。那不是 bug，是设计前提。
//
// ## 这一步为什么不能省
//
// 备份恢复最典型的 bug 是「内存恢复了、磁盘没写」：
// 提示「恢复成功」、屏幕上一瞬间数据都在，用户退出重进就没了。
// 阶段一末尾虽然已经从磁盘重读过一次，但那还是**同一个进程**——
// 静态缓存、未 flush 的写队列都可能帮它蒙混过关。
// 只有真的换一个进程，才能确定数据是**写到了磁盘**而不是**留在了内存**。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:university_timetable/main.dart' as app;
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/course_card.dart';
import 'package:university_timetable/widgets/timetable/timetable_week_grid.dart';

import 'backup_restore_fixture.dart';

/// 首页出现的等待上限。
const Duration _homeRevealTimeout = Duration(seconds: 30);

/// 单次轮询步长。
const Duration _pollStep = Duration(milliseconds: 100);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('阶段二（读，全新进程）：恢复的课还在磁盘上，也画在首页上', (tester) async {
    // ---- 1. 先不启动 App，直接问磁盘 ----
    //
    // 放在启动之前：单独失败时含义很明确——恢复的数据没落到磁盘，
    // 与界面层无关。
    final storage = StorageService();
    // 导入把数据写进档案化存储（`repository.saveProfiles`）；legacy `courses`
    // 键在导入路径里不会被写（R2），从这里读永远是空的——必须读档案。
    final profilesOnDisk = await storage.getProfiles();
    final coursesOnDisk = profilesOnDisk.expand((p) => p.courses);

    final survived = coursesOnDisk.where((c) => c.name == kBackupCourseName);
    expect(
      survived,
      isNotEmpty,
      reason:
          '阶段一明明恢复过「$kBackupCourseName」，全新进程却从磁盘读不到：'
          '恢复的数据没有活过进程重启（恢复只改了内存、没落盘）。'
          '先确认阶段一跑过且带了 --no-uninstall',
    );

    // 字段级核对：不只看名字，看决定它画在哪一格的字段。
    final restored = survived.first;
    final expected = backupFixtureCourse();
    expect(restored.dayOfWeek, expected.dayOfWeek, reason: '恢复后星期变了');
    expect(restored.startSection, expected.startSection, reason: '恢复后节次变了');
    expect(restored.teacher, expected.teacher, reason: '恢复后教师变了');
    expect(restored.location, expected.location, reason: '恢复后地点变了');

    // 当前周也一起恢复过（第 5 条顺便覆盖）。
    //
    // ⚠️ 读的是**激活档案的 currentWeek 字段**，不是全局 `current_week` 键：
    // 启动口径（2026-08-31 拍板，timetable_provider.dart:1139-1146）是
    // 「无开学时间 → 从档案的 currentWeek 读」；全局键只是迁移种子，导入路径
    // 不写它（restorePersistence 的 7 类 key 里没有周次）——从全局键读永远
    // 只会读到默认值 1，那是 legacy 探针假红，不是恢复失败。
    final activeIdOnDisk = await storage.getActiveProfileId();
    final activeOnDisk = profilesOnDisk.firstWhere(
      (p) => p.id == activeIdOnDisk,
      orElse: () => profilesOnDisk.first,
    );
    final weekOnDisk = activeOnDisk.currentWeek;
    expect(
      weekOnDisk,
      kBackupFixtureWeek,
      reason:
          '激活档案的 currentWeek 没有恢复成备份里的 $kBackupFixtureWeek（默认是 1）。'
          '写成 1 就永远测不出「周次没恢复」这个问题',
    );

    // ---- 2. 冷启动，确认界面真的画出来了 ----
    //
    // 「磁盘里有」不等于「用户看得见」。
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

    // ---- 3. 核心：恢复的课在首页网格上 ----
    await _pumpUntil(
      tester,
      () => _courseCardNamed(tester, kBackupCourseName) != null,
      timeout: _homeRevealTimeout,
      reason:
          '磁盘里有「$kBackupCourseName」，首页却找不到它的卡片：'
          '恢复的数据没被渲染出来（用户症状：备份恢复说成功，课表还是空的）',
    );

    final cardFinder = _courseCardNamed(tester, kBackupCourseName)!;
    final cardSize = tester.getSize(cardFinder.first);
    expect(cardSize.width, greaterThan(0), reason: '卡片宽度为 0：布局成了不可见尺寸');
    expect(cardSize.height, greaterThan(0), reason: '卡片高度为 0：布局成了不可见尺寸');

    // ---- 4. 位置与字段都对 ----
    //
    // 这条能抓「恢复了但排错天」——只断言「卡片存在」抓不到。
    final card = tester.widget<CourseCard>(cardFinder.first);
    expect(
      card.course.dayOfWeek,
      expected.dayOfWeek,
      reason: '首页上那门课不在第 ${expected.dayOfWeek} 天：恢复的星期在渲染链路里被改了',
    );
    expect(
      card.course.startSection,
      expected.startSection,
      reason: '首页上那门课不在第 ${expected.startSection} 节：恢复的节次被改了',
    );

    // ---- 5. App 读回来的当前周也对 ----
    final element = find.byType(TimetableScreen).evaluate().first;
    final provider = Provider.of<TimetableProvider>(element, listen: false);
    expect(
      provider.currentWeek,
      kBackupFixtureWeek,
      reason:
          '磁盘里当前周是 $kBackupFixtureWeek，App 冷启动后却变成 ${provider.currentWeek}：'
          '启动过程把恢复的周次覆盖了',
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
