# `integration_test/` —— 真机 / 模拟器上的端到端路径

这一层验的是「东西在真设备上真能用」，组件测试证明不了。定位见
`AGENTS.md` 的 `TEST-POLICY` 节（本目录是允许新增的位置之一）。

**一条路径一个文件，跑通再补下一条。**

| # | 路径 | 文件 | 状态 |
|---|---|---|---|
| 1 | 冷启动 → **磁盘里那门课出现在首页网格上** | `cold_start_home_test.dart` | 已写，待跑 |
| 2 | 加课 → 保存 → **杀进程** → 重开 → 课还在 | `persist_write_phase_test.dart` + `persist_read_phase_test.dart` | 已写，待跑 |
| 2b | 加课 → 保存 → 首页能看到（UI 全链路） | `add_course_to_home_test.dart` | 已写，**真机通过**（旧 flavor） |
| 3 | 导入课表 → 解析 → 首页能看到 | — | 未开始 |
| 4 | 改设置 → 重开 → 设置还在 | — | 未开始 |
| 5 | 备份 → 清空 → 恢复 → 数据回来 | — | 未开始 |

> 「已写，待跑」= 代码与静态检查都过了，但**还没在任何设备上执行过**。
> 别把 `dart analyze` 通过当成验过——那是两件事。

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
```

### 第 2 条要跑**两条**命令（这是设计，不是麻烦）

第 2 条验的是「杀进程重开」。`flutter test` 每次跑一个文件是**一个独立进程**，
所以「杀进程重开」用两次调用实现：

```bash
# 阶段一：写（跑完 App 会被停掉——那就是真的"杀进程"）
# --no-uninstall 让包留着，数据才能活到下一次
flutter test integration_test/persist_write_phase_test.dart \
  -d <device-id> --flavor itest --no-uninstall

# 阶段二：读（全新进程，验证上一阶段写的课还在）
flutter test integration_test/persist_read_phase_test.dart \
  -d <device-id> --flavor itest
```

**为什么不能合成一条**：同一个文件里的多个 `testWidgets` 共享同一个进程与
Dart 静态状态（`StorageService` 单例、prefs 缓存）。那样测只是「清缓存重读」，
**没经过进程死亡**，「只在进程活着时成立」的 bug（静态缓存、未落盘的待写队列）
一个都抓不到。跨进程正是这条路径唯一要证明的事。

**单独跑阶段二必然失败**——磁盘里没有那门课。那不是 bug，是设计前提。

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
| `数据没有活过进程重启` | **写没落盘**（第 2 条阶段二） | 先确认阶段一跑过、且带了 `--no-uninstall` |
| `卡片宽度为 0` | 布局成了不可见尺寸 | 首页布局约束 |
| `保存没有落库` | 保存没生效 | 校验没过 / 落盘失败 / 保存键没点到 |

看设备日志（另开终端，只读）：

```bash
adb -s <device-id> logcat | grep -E "\[boot\]|home_reveal_watchdog|first_frame_watchdog"
```

### 4. 跑完

设备上会留一个「**轻屿课表集成测试**」的图标（包名 `.itest`）。
它与你日常用的三个包互不影响，不想要直接卸载即可。

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
