// 主路径 5/5：备份 → **清空** → 恢复 → 数据回来
//
// ## 为什么这条价值最高
//
// 「备份了但恢复不出来」是用户投诉里最伤人的一类：他做对了所有事
// （及时备份、妥善保存），却在最需要的时候发现备份是废的。
// 本仓 `importAppDataBackup` 有很完整的回滚保护
// （`timetable_import_export_service.dart:647` 那段注释写了它的来历），
// 但**没有端到端测试证明「导出 → 清空 → 恢复」这条链真的通**。
//
// ## 必须走真的 `importAppDataBackup`
//
// 本文件启动 App、从 provider 拿真实的 `importAppDataBackup`，
// 而不是「解析备份 → `storage.saveCourses(...)`」。区别很实在：
// 后者跳过了字段映射、坏条目隔离、失败回滚那一整套，
// 而那些恰恰是这条路径最容易坏的地方。
//
// ## 关键纪律一：必须制造「数据确实没了」的中间态
//
// 这是整条路径的命门。如果原地导入（不清空），那么**导入完全失效**
// 也会显示「数据都在」——旧数据还躺在磁盘里，断言照样通过。
// 那条测试会永远绿、永远测不出东西，比没有测试更危险。
//
// 流程：写 A → 导出 → **清空并确认清空生效** → 导入 → 读回 A
//
// ## 关键纪律二：目标值偏离默认值
//
// 课写「第 5 天第 8 节」（默认 1/1）、当前周写 7（默认 1）。
// 否则「恢复根本没发生、读到的是默认值」这个 bug 会让断言照样通过。
//
// ## 关键纪律三：跨进程
//
// 备份恢复的典型 bug 是「内存恢复了、磁盘没写」：屏幕上一瞬间是对的，
// 用户退出重进就没了。所以最后必须跨进程验证——两次 `flutter test` 调用：
//
//   # 阶段一（本文件）：写 → 导出 → 清空 → 导入
//   flutter test integration_test/backup_restore_write_phase_test.dart \
//     -d <device-id> --flavor itest --no-uninstall
//
//   # 阶段二：全新进程，读回
//   flutter test integration_test/backup_restore_read_phase_test.dart \
//     -d <device-id> --flavor itest

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:university_timetable/main.dart' as app;
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/data_transfer_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/timetable/timetable_week_grid.dart';

import 'backup_restore_fixture.dart';

/// 首页出现的等待上限。
const Duration _homeRevealTimeout = Duration(seconds: 30);

/// 单次轮询步长。
const Duration _pollStep = Duration(milliseconds: 100);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('阶段一（写→导出→清空→导入）：恢复后磁盘里数据回来了', (tester) async {
    final storage = StorageService();

    // ---------- 0. 从干净状态起步 ----------
    //
    // ⚠️ 清空必须打在 App 真正读取的键上。启动路径读的是**档案化存储**
    // （`timetable_profiles`，经 `_doEnsureProfilesInitialized` 迁移/兜底），
    // 而 legacy `courses` 键早已无生产写方（risk-register R2）——只清 legacy
    // 等于没清：`.itest` 包里残留的档案会让「课表为空」这个前提不成立。
    // （2026-10-20 实测：只清 legacy 时，persist 测试留下的课直接让
    //   前提断言红掉：「启动后课表不是空的」。）
    storage.resetForTesting();
    await storage.init();
    await storage.saveProfiles(const []);
    await storage.saveCourses(const <Course>[]);
    await storage.setAcceptedPrivacyPolicy(true);
    await storage.setHasSeenUserGuide(true);
    storage.resetForTesting();

    // ---------- 1. 启动 App，拿到真实 provider ----------
    //
    // 为什么要启动 App：`importAppDataBackup` 是 provider 的方法
    // （`timetable_provider.dart:3191`），它需要 provider 的完整端口——
    // 档案仓库、存储、分析、回滚快照。绕过去自己拼一条等价路径，
    // 就把这条路径最想验的东西（回滚、字段映射）绕没了。
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

    final element = find.byType(TimetableScreen).evaluate().first;
    final provider = Provider.of<TimetableProvider>(element, listen: false);

    // 前提：此刻课表是空的（上面清过）。
    expect(
      provider.courses,
      isEmpty,
      reason: '启动后课表不是空的，这条测试的前提不成立',
    );

    // ---------- 2. 造「原始数据」并导出备份 ----------
    //
    // 导出用真实的 `DataTransferService.buildBackupJson`——App 导出备份走的
    // 就是它。不手搓 JSON：手搓就把「导出能不能产出合法备份」绕过去了。
    final originalCourse = backupFixtureCourse();
    final transferService = DataTransferService();
    final backupJson = transferService.buildBackupJson(
      courses: <Course>[originalCourse],
      settings: provider.settings,
      currentWeek: kBackupFixtureWeek,
    );

    expect(backupJson, isNotEmpty, reason: '导出产出为空：备份生成这一步就是坏的');

    // 自检：导出的内容能被自己的解析器读回来。否则后面导入失败会被误判成
    // 「恢复逻辑坏了」，而实际是导出格式就坏了。
    final reparsed = transferService.parseBackupJson(backupJson);
    expect(
      reparsed.courses.any((c) => c.name == kBackupCourseName),
      isTrue,
      reason: '导出→解析往返失败：备份里没有那门课，导出格式与解析不一致',
    );

    // ---------- 3. 清空（并且**确认真的清了**） ----------
    //
    // 命门所在，理由见文件头「关键纪律一」。
    // 与第 0 步同理：档案 + legacy 两条键都要清（App 启动读档案）。
    await storage.saveProfiles(const []);
    await storage.saveCourses(const <Course>[]);

    final afterClearProfiles = await storage.getProfiles();
    expect(
      afterClearProfiles.expand((p) => p.courses),
      isEmpty,
      reason: '档案里仍有课程：中间态没造出来（App 启动读的是档案，不是 legacy 键）',
    );
    final afterClear = await storage.getCourses();
    expect(
      afterClear,
      isEmpty,
      reason:
          '清空后仍能读到课程：中间态没造出来。'
          '这样即使后面导入完全失效，「数据都在」的假象也会让断言通过',
    );

    // ---------- 4. 导入备份（走真的 importAppDataBackup） ----------
    final importError = await provider.importAppDataBackup(backupJson);

    expect(
      importError,
      isNull,
      reason:
          'importAppDataBackup 返回了错误码「$importError」：'
          '恢复失败（格式不认 / 回滚不完整）。这条路径的核心就在这里',
    );

    // ---------- 5. 自查：本进程内数据回来了 ----------
    await _pumpUntil(
      tester,
      () => provider.courses.any((c) => c.name == kBackupCourseName),
      timeout: const Duration(seconds: 15),
      reason: '导入返回成功，但 provider.courses 里没有「$kBackupCourseName」',
    );

    final restoredCourse = provider.courses.firstWhere(
      (c) => c.name == kBackupCourseName,
    );
    expect(
      restoredCourse.dayOfWeek,
      originalCourse.dayOfWeek,
      reason: '恢复后星期变了：备份/恢复过程丢字段',
    );
    expect(
      restoredCourse.startSection,
      originalCourse.startSection,
      reason: '恢复后节次变了：备份/恢复过程丢字段',
    );
    expect(
      restoredCourse.teacher,
      originalCourse.teacher,
      reason: '恢复后教师变了',
    );

    // 当前周也一起恢复了（这是备份里另一个独立字段，容易漏）。
    expect(
      provider.currentWeek,
      kBackupFixtureWeek,
      reason: '当前周没恢复成备份里的 $kBackupFixtureWeek（默认值是 1，写成 1 就测不出问题）',
    );

    // ---------- 6. 落盘自查：从磁盘读回来 ----------
    //
    // 这一步把「内存里恢复了」与「磁盘上真写了」分开。
    //
    // ⚠️ **这不是重复验证阶段二要验的东西，别删。** 两个断言各管一段故障：
    //   - 这里红 = 恢复根本没落盘（问题在写路径）；
    //   - 阶段二才红 = 落了盘但没活过进程边界（问题在静态缓存 / 延迟写队列）。
    // 两种故障的排查路径完全不同，能在这里就分开定位是它的全部价值。
    // 它也不会增加假绿风险：这里过了不代表阶段二能过。
    storage.resetForTesting();
    await storage.init();
    // 导入走的是档案化仓储（`repository.saveProfiles`），磁盘读回也必须读档案——
    // legacy `courses` 键在导入路径里根本不会被写（R2）。
    final onDiskProfiles = await storage.getProfiles();
    final onDiskCourses = onDiskProfiles.expand((p) => p.courses);
    expect(
      onDiskCourses.any((c) => c.name == kBackupCourseName),
      isTrue,
      reason:
          '内存里恢复了，但重新从磁盘读却读不到：'
          '恢复只改了内存、没有落盘（用户症状：恢复成功，退出重进就没了）',
    );

    // 丢掉缓存交给阶段二：确保那边是真正从磁盘重新读。
    storage.resetForTesting();
  });
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
