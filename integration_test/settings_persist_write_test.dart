// 主路径 4/5 第一阶段（写）：改一个设置并落盘
//
// ## 这条路径验什么
//
// 「我改了个设置，关掉 App 再打开，它还在吗？」
//
// 和第 2 条（加课持久化）是同一类问题，但**走的不是同一条存储路径**：
// 课程走 `StorageService` 的课程写链，设置走 `AppGlobalSettingsService` +
// profile 的设置镜像。两条链各有各的坑，所以分开验、各写一条。
//
// 尤其设置这条：`AppGlobalSettingsService.resolveInitial`（启动时调用）
// 会把「全局那份」设置盖到激活课表上。也就是说**写下去的可能是 A，
// 读回来被盖成了 B**——这类 bug 只在跨进程重启后才暴露，同进程内测不出来。
//
// ## 怎么做到「真杀进程」
//
// 与第 2 条同一套配方（原理见 `persist_write_phase_test.dart` 文件头）：
// `flutter test` 每跑一个文件就是一个独立进程，跑完 `stopApp`。
//
//   # 第一阶段：写（跑完 App 被杀，--no-uninstall 让数据活下来）
//   flutter test integration_test/settings_persist_write_test.dart \
//     -d <device-id> --flavor itest --no-uninstall
//
//   # 第二阶段：读（全新进程）
//   flutter test integration_test/settings_persist_read_test.dart \
//     -d <device-id> --flavor itest
//
// ## 为什么选「首页导航形态」这个设置
//
// 挑设置项有讲究，不是随便找一个：
//   - 它必须**在首页可见**（底部导航形态：经典底栏 vs 玻璃坞），这样第二阶段
//     能同时验「值读回来了」和「界面真的按它渲染了」；
//   - 它必须走 `AppGlobalSettingsService` 那条**会被全局值覆盖合并**的路，
//     那正是最容易出「读回来被默认值盖掉」的地方；
//   - 它不能依赖网络/权限（那种设置的失败原因与本路径无关）。
//
// 相比之下，选个纯装饰性的值（比如某个颜色 hex）验不出「被覆盖合并」这类问题。

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/storage_service.dart';

import 'settings_persist_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('阶段一（写）：把首页导航形态改成玻璃坞并落盘', (tester) async {
    // 从干净状态起步。
    StorageService().resetForTesting();
    await StorageService().init();
    await StorageService().saveCourses(const <Course>[]);

    // 预置引导标志：第二阶段会用 app.main() 冷启动，
    // 这两个键都为真才走老用户快速路径（否则停在引导页等点击）。
    await StorageService().setAcceptedPrivacyPolicy(true);
    await StorageService().setHasSeenUserGuide(true);

    // ---- 读当前设置，改一个字段，写回去 ----
    //
    // 走 `StorageService` 的设置读写（与 `TimetableSettingsWriter` 写的是同一份
    // 存储），因为这一阶段还没有 provider 实例（App 未启动）。
    final before = await StorageService().getTimetableSettings();
    expect(
      before.homeNavigationForm,
      isNot(kPersistedNavigationForm),
      reason:
          '起始状态就已经是目标值了，这条测试会假通过。'
          '存储没被重置，或 $kPersistedNavigationForm 变成了默认值',
    );

    await StorageService().saveTimetableSettings(
      before.copyWith(homeNavigationForm: kPersistedNavigationForm),
    );

    // ---- 自检：本进程内读回来是改后的值 ----
    final after = await StorageService().getTimetableSettings();
    expect(
      after.homeNavigationForm,
      kPersistedNavigationForm,
      reason: '阶段一自检失败：刚写的设置在本进程内就读不回来，写路径本身有问题',
    );
  });
}
