// 主路径 2/5：加课 → 保存 → **杀进程** → 重开 → 课还在
//
// 这是用户最关心的一条：「我加了一门课，关掉 App 再打开，它还在吗？」
//
// ## 怎么做到「真杀进程」（这是本文件最要紧的设计）
//
// `flutter test integration_test/xxx.dart` 跑的是**一个进程内的测试**，
// 测试代码没法杀掉自己再重开。但 flutter_tools 每次跑一个文件都会：
//   1. 装机 → 2. 启动 App → 3. 跑测试 → 4. **停掉 App**（`kill()`，
//   见 integration_test_device.dart:141 的 `stopApp`）→ 5. 按 `--uninstall`
//   决定卸不卸载（默认卸）。
//
// 所以「杀进程重开」可以**用两次独立调用**实现：第一阶段写数据并退出，
// 第二阶段是全新的 App 进程，读盘验证。两阶段之间 App 真的被 kill 了，
// Dart VM 也整个没了——这不是模拟，是真的重启。
//
// 代价是必须跑**两条命令**，而且中间要 `--no-uninstall`（否则第一阶段结束
// 就把包卸了、数据一起没）。运行配方：
//
//   # 第一阶段：写（跑完 App 会被停掉，但包留着）
//   flutter test integration_test/persist_write_phase_test.dart \
//     -d <device-id> --flavor itest --no-uninstall
//
//   # 第二阶段：读（全新进程，验证上一阶段写的数据还在）
//   flutter test integration_test/persist_read_phase_test.dart \
//     -d <device-id> --flavor itest
//
// 两个文件、两条命令，别合成一条：合成一条就退化成同一个进程内，
// 而「跨进程」正是这条路径唯一要证明的事。
//
// ## 为什么两个阶段必须用不同的文件
//
// 一个文件里的多个 `testWidgets` 共享同一个进程、同一套 Dart 静态状态
// （`StorageService` 单例、`SharedPreferences` 缓存等）。在同一个文件里
// 「写完 resetForTesting 再读」只是清缓存重读，**没有经过进程死亡**，
// 任何「只在进程活着时成立」的 bug（静态缓存、未落盘的待写队列）都会被漏掉。
//
// ## 存储用真实磁盘
//
// 用专用 flavor `itest`（包名 `com.mutx163.qingyu.itest`，与 prod/profile/dev
// 完全隔离）。所以这里**不做任何内存 mock**——要验的就是「真的落盘了」，
// 用内存替身等于把要验的东西绕过去。
//
// 事故背景（为什么必须隔离包名）见 README 与 cold_start_home_test.dart 文件头。
//
// ## 本文件负责第一阶段（写）
//
// 第二阶段在同目录 `persist_read_phase_test.dart`。两个文件共用
// `persist_fixture.dart` 里的数据定义，避免两边各写一份、悄悄写歪。

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/storage_service.dart';

import 'persist_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('阶段一（写）：把一门带标记的课写进磁盘', (tester) async {
    // 从干净状态起步：这是「加课」这个动作之前的状态。
    StorageService().resetForTesting();
    await StorageService().init();
    await StorageService().saveCourses(const <Course>[]);

    // 预置「已接受隐私政策 + 已看过引导」。
    //
    // 为什么这一阶段也要：第二阶段会用真的 `app.main()` 冷启动，
    // 那条路径要求这两个键都为真才走老用户快速路径（main.dart:1018 起）；
    // 否则会弹引导页 await 用户点击，首页永远不出现。
    // 在这一阶段写好，第二阶段才有得读——这本身也是一次跨进程持久化。
    await StorageService().setAcceptedPrivacyPolicy(true);
    await StorageService().setHasSeenUserGuide(true);

    // ---- 真正的「加课」：走 App 自己保存时用的同一个写入口 ----
    //
    // 这里刻意**不走 UI**：本阶段要验的是「数据能不能活过进程重启」，
    // 不是「表单能不能点」。点 UI 加课那条链由另一条用例覆盖
    // （`add_course_to_home_test.dart`）。两件事分开验，失败时定位才准。
    await StorageService().saveCourses(<Course>[persistFixtureCourse()]);

    // ---- 自检：确认刚写的东西读得回来（在本进程内） ----
    final written = await StorageService().getCourses();
    expect(
      written.any((c) => c.name == kPersistCourseName),
      isTrue,
      reason: '阶段一自检失败：刚写进磁盘的课在本进程内就读不回来，写路径本身有问题',
    );
  });
}
