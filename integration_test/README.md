# `integration_test/` —— 真机 / 模拟器上的端到端路径

这一层验的是「东西在真设备上真能用」，组件测试证明不了。定位见
`AGENTS.md` 的 `TEST-POLICY` 节（本目录是允许新增的位置之一）。

**一条路径一个文件，跑通再补下一条。**

| # | 路径 | 文件 | 状态 |
|---|---|---|---|
| 1 | 冷启动 → **磁盘里那门课出现在首页网格上** | `cold_start_home_test.dart` | 已写，待跑 |
| 2 | 加课 → 保存 → **杀进程** → 重开 → 课还在 | `persist_write_phase_test.dart` + `persist_read_phase_test.dart` | 已写，待跑 |
| 2b | 加课 → 保存 → 首页能看到（UI 全链路） | `add_course_to_home_test.dart` | 已写，**真机通过**（旧 flavor） |
| 3 | 导入课表 → 解析 → 落库 → 首页能看到 | `import_ics_to_home_test.dart` | 已写，待跑 |
| 4 | 改设置 → **杀进程** → 重开 → 设置还在 | `settings_persist_write_test.dart` + `settings_persist_read_test.dart` | 已写，待跑 |
| 5 | 备份 → 清空 → 恢复 → 数据回来 | — | 未开始 |

> 「已写，待跑」= 代码与静态检查都过了，但**还没在任何设备上执行过**。
> 别把 `dart analyze` 通过当成验过——那是两件事。

---

## 核心设计：为什么「持久化」要拆成两个文件、跑两次

这是本目录最值得理解的一条，也是最容易被下一个人「优化掉」的一条。

### 结论

「杀进程重开」用**两个测试文件 + 两次 `flutter test` 调用**实现：

```bash
# 阶段一：写（跑完 App 被停掉 —— 那就是真的杀进程）
flutter test integration_test/persist_write_phase_test.dart \
  -d <device-id> --flavor itest --no-uninstall

# 阶段二：读（全新进程）
flutter test integration_test/persist_read_phase_test.dart \
  -d <device-id> --flavor itest
```

### 为什么不能合成一个文件

**不是因为做不到，是因为合成了就测不到真正要测的东西。**

`flutter test` 每跑一个**文件**是一个独立进程；同一个文件里的多个 `testWidgets`
共享同一个进程、同一套 Dart 静态状态——`StorageService` 单例、
`SharedPreferences` 的静态缓存、各种 pending 的写队列，全都还在。

如果在一个文件里写「存 → `resetForTesting()` → 再读」，验到的是
**「清掉内存缓存后重新从磁盘读」**，而不是**「进程死后重开」**。差别在于：

| 只有真进程死亡才抓得到的 bug | 同进程「清缓存重读」能否抓到 |
|---|---|
| 静态单例里缓存了旧值、没失效 | ❌ 抓不到（缓存还在） |
| 写操作进了内存队列但**还没落盘**，进程就退出 | ❌ 抓不到（队列还在） |
| 某个字段只存在内存、压根没序列化 | ❌ 抓不到（内存对象还在） |
| 启动时用默认值覆盖了读到的值 | ✅ 能抓到（这个跟进程无关） |

前三类正是「用户改完设置、杀掉 App、重开发现没保存」这类投诉的典型成因。
用同进程重读去测，它们一个都露不出来——**测试会一直是绿的**。

### 代价（如实记录）

- 必须跑两条命令，不能一条搞定；
- 阶段一必须带 `--no-uninstall`，否则包被卸掉、数据跟着没；
- 阶段二单独跑必然失败（磁盘里还没有数据）——那不是 bug，是设计前提。

### 「目标值必须偏离默认值」

同一个道理的另一面：持久化测试里，**要写进去的值不能等于默认值**。

如果默认值恰好等于测试值，那么「写根本没发生、读到的是默认值」这个 bug
会让断言**照样通过**。所以：

- 课程那条（第 2 条）写的是「第 4 天第 6 节」——默认是第 1 天第 1 节；
- 设置那条（第 4 条）写的是 `glassDock`——默认是 `classic`
  （timetable_settings.dart:781）。

阶段一还额外断言「起始状态 ≠ 目标值」，把这条纪律钉进代码里。

---

## 事故记录：一次跑测试清空了用户的调试包数据（2026-10-20）

**必须留在这里，因为它决定了本目录所有命令的写法。**

### 发生了什么

第一次真机跑第 1 条（当时只验「首页渲染出来」）时，用的是：

```bash
flutter test integration_test/cold_start_home_test.dart -d <phone> --flavor dev   # ← 错的
```

`--flavor dev` 的包名是 `com.mutx163.qingyu.debug`，**那正是开发者日常调试用的包**。
而 `flutter test` 跑完会做两件事（`integration_test_device.dart:141-150`）：

```dart
await device.stopApp(applicationPackage, ...);      // 停掉 App
if (debuggingOptions.uninstallApp) {                 // 默认 true
  await device.uninstallApp(applicationPackage, ...); // 卸掉包
}
```

卸载会连私有数据一起清掉。于是**测试通过的同时，那个包的课表与设置没了**。
选项本身就在 `flutter test --help` 里（`--[no-]uninstall`，默认 on），
出事前没人查过。

### 修法：独立包名

`android/app/build.gradle` 新增 `itest` flavor：

| flavor | 包名 | 用途 |
|---|---|---|
| prod | `com.mutx163.qingyu` | 正式发布 |
| perf | `com.mutx163.qingyu.profile` | 性能测量 |
| dev | `com.mutx163.qingyu.debug` | 日常调试（**曾被打回过**） |
| **itest** | `com.mutx163.qingyu.itest` | **集成测试专用** |

`.itest` 与前三个完全隔离：装、跑、卸载都只影响它自己。所以：

- **不再需要** `--no-uninstall`（卸不卸载都碰不到真实数据）；
- **不再需要** 内存 mock 的 `SharedPreferences.setMockInitialValues`——
  现在可以放心用**真实磁盘**，而这恰恰是持久化验证需要的
  （用内存替身等于把「真的落盘了吗」这条绕过去）。

### 一句话规则

> **本目录的任何命令，`--flavor itest` 不能省。**
> 看到 `--flavor dev` / `--flavor prod` / `--flavor perf` 就是写错了。

---

## 另一个坑：不指定 `-d` 会自动挑设备

`flutter test integration_test/xxx.dart` 不带 `-d` 时，flutter_tools 会自己找设备
（`commands/test.dart:619-621`）：

```dart
Device? integrationTestDevice;
if (_isIntegrationTest) {
  integrationTestDevice = await findTargetDevice();   // ← 不指定 -d 就自己挑
```

`findTargetDevice()`（`flutter_command.dart:2044`）的行为：**恰好一台设备就连上它**，
多台才让你选。所以在只连着一台手机的机器上，一条看起来「只是跑个测试」的命令会
装包、启动、跑完卸载。

**每次都必须显式 `-d <device-id>`。**

### 其他红线

- 跑 integration test 会在设备上**安装并启动** App。用户没说过「可以」就不要做。
- 不能用 `-d windows` / `-d chrome` 绕开：本仓没配 Windows 桌面工程
  （`No Windows desktop project configured`），web 被 flutter_tools 明确拒绝
  （`Web devices are not supported for integration tests yet.`）。

---

## 怎么跑

### 一键跑单条路径

```bash
flutter test integration_test/cold_start_home_test.dart \
  -d <device-id> --flavor itest

# 第 3 条（导入）
flutter test integration_test/import_ics_to_home_test.dart \
  -d <device-id> --flavor itest

# 第 2b 条（加课 UI 全链路）
flutter test integration_test/add_course_to_home_test.dart \
  -d <device-id> --flavor itest
```

### 第 2 条和第 4 条要跑**两条**命令（这是设计，不是麻烦）

这两条验的是「杀进程重开」，原理见上文的「核心设计」一节。

```bash
# ===== 第 2 条：加课持久化 =====
# 阶段一：写（跑完 App 会被停掉——那就是真的"杀进程"）
flutter test integration_test/persist_write_phase_test.dart \
  -d <device-id> --flavor itest --no-uninstall

# 阶段二：读（全新进程，验证上一阶段写的课还在）
flutter test integration_test/persist_read_phase_test.dart \
  -d <device-id> --flavor itest

# ===== 第 4 条：设置持久化 =====
flutter test integration_test/settings_persist_write_test.dart \
  -d <device-id> --flavor itest --no-uninstall

flutter test integration_test/settings_persist_read_test.dart \
  -d <device-id> --flavor itest
```

**单独跑阶段二必然失败**——磁盘里还没有数据。那不是 bug，是设计前提。

### `--no-uninstall` 加不加？——**按需加，不统一**

| 命令 | 加 `--no-uninstall`？ | 为什么 |
|---|---|---|
| 任何**阶段一（写）** | ✅ **必须** | 不加的话包被卸载、数据一起没，阶段二必然读不到 |
| 阶段二（读） | ❌ 不加 | 它跑完整个流程就结束了，卸载正好清干净 |
| 单文件路径（1 / 2b / 3） | ❌ 不加 | 独立包名下卸载碰不到任何真实数据，而且**卸载保证下次从干净状态起步**，避免上一条的残留污染下一条 |

一句话：**只有「要让数据活到下一次调用」的那条才加。**
全加或全不加都不对——全加会让残留数据在测试之间互相污染，
全不加会让跨进程测试必然失败。

---

## 给用户的运行清单

### 0. 前置（一次就好）

```bash
flutter pub get          # 让 integration_test 依赖生效（Windows 侧；WSL 侧禁止）
flutter devices          # 看设备列表
```

输出里能看到设备，例如：

```
25060RK16C (mobile) • 10.196.69.43:5555 • android-arm64 • Android 17 (API 37)
```

中间那列（`10.196.69.43:5555`）就是 `<device-id>`。

### 1. 手机上要做的（一次性）

- 开发者选项 → 打开「USB 调试」；
- 连线时若弹「允许 USB 调试吗」，点**允许**；
- 无线调试（示例里那种 IP:端口）要先配对，配好 `flutter devices` 才看得到。

> 这一步**要你自己做**：Agent 按铁律不能碰你的设备，包括不能替你点「允许」。

### 2. 跑（注意 `--flavor itest`）

见上一节。第一条建议先跑 `cold_start_home_test.dart`（最快、最基础）。

### 3. 结果怎么读

**通过**：最后一行 `All tests passed!`

**失败**：每条断言都带一句人话，直接告诉你是哪一环：

| 失败信息包含 | 含义 | 先查什么 |
|---|---|---|
| `首页未换入` | 卡在启动画面 | logcat 搜 `[boot]`；`home_reveal_watchdog` |
| `周课表网格…没出现` | 首页进来但骨架没搭起来 | 首页装配 |
| `磁盘里明明写着…却找不到它的卡片` | **读存储 → 渲染 断了** | 存储读取 / 课程解析 / 网格取数 |
| `数据没有活过进程重启` | **写没落盘**（阶段二） | 先确认阶段一跑过、且带了 `--no-uninstall` |
| `卡片宽度为 0` | 布局成了不可见尺寸 | 首页布局约束 |
| `保存没有落库` | 保存没生效 | 校验没过 / 落盘失败 / 保存键没点到 |
| `一条课都没解析出来` | ICS 格式不对（第 3 条） | DESCRIPTION 第一行是否含「第 N-M 节」 |
| `启动过程把这个设置覆盖了` | **设置被默认值盖掉**（第 4 条） | `AppGlobalSettingsService.resolveInitial` |

看设备日志（另开终端，只读）：

```bash
adb -s <device-id> logcat | grep -E "\[boot\]|home_reveal_watchdog|first_frame_watchdog"
```

### 4. 跑完

设备上会留一个「**轻屿课表集成测试**」的图标（包名 `.itest`）。
它与你日常用的三个包互不影响，不想要直接卸载即可。

---

## 已知缺口（如实记录，别当成已覆盖）

### 第 3 条：没覆盖「用户在学期面板上做选择」那一下

ICS 导入的真实 UI 流程里有**两道阻塞交互**（`ics_course_import_screen.dart:203-224`）：

1. `askImportReplaceExisting` —— 课表非空时问「覆盖 / 更新 / 取消」。
   **空课表时自动跳过**（源码里 `courses.isEmpty` 直接取 `true`），
   测试从空课表起步即可绕开。
2. `pickImportSemesterConfig` —— 底部面板，让用户确认学期起始日与第一周。
   **没有默认放行路径**，必须有人应答。

第 2 道没有自动化，理由是它问的是**用户的领域判断**（「这份课表从第几周开始」），
程序替不了。强行驱动它要写「点日期选择器、改周次下拉」一串操作，
任何 UI 调整都会假红，而那些都不是本路径要验的东西。

**所以第 3 条验的是**：解析正确 → 学期对齐正确 → 落库 → 冷启动后画在正确位置。
**没验的是**：用户在那个面板上点「确认」之后的那一跳。
那一段目前只有人肉验证。

如果将来要补，方向是用 Patrol（能驱动原生/复杂交互），而不是硬塞进
`integration_test`。

### 第 5 条：还没写

备份 → 清空 → 恢复 → 数据回来。设计要点已在 AGENTS.md 记过：
**必须先制造「数据确实没了」的中间态**，否则导入失败也是绿的。

---

## 写这一类测试的纪律

1. **调真的入口**：`import 'package:university_timetable/main.dart' as app;` 然后
   `app.main()`。手工拼 `MaterialApp` 会绕过 `deferFirstFrame` 与整条启动管线，
   而那正是要验的东西。
2. **用轮询，不用 `pumpAndSettle()`**：首页永远不会静止（常驻动画、玻璃表面、
   下拉回弹），`pumpAndSettle` 只会等到超时。参考各文件的 `_pumpUntil`。
3. **断言落在用户看得见的东西上**：某张卡片在场且有非零面积、某段文字在屏上。
   「widget 树非空」不算证据。
4. **判成败只能靠行为**：`main()` 装了自己的 `FlutterError.onError`
   （`main.dart:306`），顶掉 flutter_test 的异常收集器，启动期的框架异常
   不会自动让用例变红。
5. **参数透传要单独钉**：凡是「点了某处 → 打开某页并带上参数」，必须直接断言
   目标页面拿到的字段值，不能只断言「页面打开了」。AGENTS.md 有实证：
   删掉参数转发后存量 43 例全绿。
6. **要验「存住了」，别只验「出来了」**：用户原话是「这么简单的」。
   「首页渲染出来了」证明不了数据活着；「那门课在里面」才证明。
7. **等转场结束再点**：页面 push 时顶栏从屏幕外滑入，widget 两三帧就进树了但
   坐标还在屏幕外，此时 `tap` 会静默落空（只在日志里留一条
   `would not hit test` 警告）。要等目标控件矩形真正落进屏幕再点。
8. **setUp 里用 `resetForTesting`，不要在测试体裸露处调**：那个方法会重写
   存储的写链，在 FakeAsync 区调用会让后续真实异步永远等不到完成
   （详见 `.agents/notes/implemented/testing/2026-10-12-no-resetForTesting-inside-testbody-fakeasync.md`）。
