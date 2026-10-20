// 主路径 4/5 第二阶段（读，全新进程）：上一阶段改的设置还在
//
// 运行配方见同目录 `settings_persist_write_test.dart` 文件头。简版：
//
//   flutter test integration_test/settings_persist_write_test.dart \
//     -d <device-id> --flavor itest --no-uninstall    # 阶段一：写
//   flutter test integration_test/settings_persist_read_test.dart \
//     -d <device-id> --flavor itest                    # 阶段二：读
//
// ⚠️ 单独跑本文件必然失败（磁盘里还没有那个设置值）。那不是 bug，是设计前提。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:university_timetable/main.dart' as app;
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/timetable/timetable_week_grid.dart';

import 'settings_persist_fixture.dart';

/// 首页出现的等待上限。
const Duration _homeRevealTimeout = Duration(seconds: 30);

/// 单次轮询步长。
const Duration _pollStep = Duration(milliseconds: 100);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('阶段二（读，全新进程）：上一阶段改的设置还在，且界面按它渲染', (tester) async {
    // ---- 1. 先不启动 App，直接问磁盘 ----
    //
    // 与课程那条同理：放在启动之前，单独失败时含义很明确——
    // **设置根本没活过进程重启**，与界面层无关。
    final settingsOnDisk = await StorageService().getTimetableSettings();

    expect(
      settingsOnDisk.homeNavigationForm,
      kPersistedNavigationForm,
      reason:
          '阶段一明明把首页导航形态改成了 $kPersistedNavigationFormLabel，'
          '全新进程却读回 ${settingsOnDisk.homeNavigationForm}：'
          '设置没有活过进程重启（写没落盘 / 落到了别处 / 被默认值盖掉）。'
          '先确认阶段一跑过、且带了 --no-uninstall',
    );

    // ---- 2. 冷启动，确认界面真的按这个设置渲染 ----
    //
    // 「值读回来了」和「界面照它画了」是两件事：
    // `AppGlobalSettingsService.resolveInitial` 会把全局那份设置盖到
    // 激活课表上，覆盖恰恰发生在这里。所以还要看界面。
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

    // ---- 3. 核心：App 读回来之后，设置仍然是改后的值 ----
    //
    // 这一条钉的是「启动过程有没有把它盖掉」。磁盘那条已经过了，
    // 所以这里失败就一定指向覆盖/合并逻辑，不可能是写盘问题。
    final element = find.byType(TimetableScreen).evaluate().first;
    final provider = Provider.of<TimetableProvider>(element, listen: false);

    expect(
      provider.settings.homeNavigationForm,
      kPersistedNavigationForm,
      reason:
          '磁盘里是 $kPersistedNavigationFormLabel，App 冷启动后内存里却变成了 '
          '${provider.settings.homeNavigationForm}：'
          '启动过程把这个设置覆盖了（查 AppGlobalSettingsService.resolveInitial '
          '把全局设置盖到课表设置上那条路）',
    );
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
