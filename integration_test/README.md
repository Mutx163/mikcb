# `integration_test/` —— 真机 / 模拟器上的端到端路径

这一层验的是「东西在真设备上真能用」，组件测试证明不了。定位见
`AGENTS.md` 的 `TEST-POLICY` 节（本目录是允许新增的位置之一）。

**一条路径一个文件，跑通再补下一条。** 第 1 条必须先在任何设备上跑通，
再动第 2 条——否则断言写错了、时序不对，出错的地方会被复制五遍。

| # | 路径 | 状态 |
|---|---|---|
| 1 | 冷启动 → 首页渲染出来 | `cold_start_home_test.dart`（已写，**未验**，见「当前未验状态」） |
| 2 | 加一门课 → 保存 → 首页能看到 | 设计见下文，未写代码 |
| 3 | 导入课表 → 解析 → 首页能看到 | 设计见下文，未写代码 |
| 4 | 改设置 → 杀进程重开 → 设置还在 | 设计见下文，未写代码 |
| 5 | 备份恢复 → 数据回来 | 设计见下文，未写代码 |

## 当前未验状态（如实记录，别当成已覆盖）

第 1 条**一次都没在设备上跑过**。写它的时候本机 `flutter emulators` →
`Unable to find any emulator sources`（没有 AVD），`flutter devices` 里唯一的
Android 目标是用户的实体手机，按 DEVICE-CONTROL 铁律不能碰；`-d windows` 因为
本仓没配 Windows 桌面工程而失败，`-d chrome` 被 flutter_tools 明确拒绝。

所以下面的断言设计全是**静态推导**（读源码得出「应该断言什么」），
不是「实测跑通了」。第 1 条在真机上跑通之前，这套设计都还有被推翻的可能。

---

## 第 2～5 条的断言设计

每条只写「断言什么、为什么这么选」，不写代码。设计原则沿用第 1 条的四条纪律
（见下文「写这一类测试的纪律」）：调真入口、轮询不等固定时长、断言落在用户看得见
的东西上、失败时能指向具体哪一环。

### 共同难点：这些路径都要「先造数据」

第 1 条是**只读**的（只用空存储启动）。第 2～5 条都要先有数据或要触发交互，
所以必须先定一个贯穿四条的共同策略：

**数据用 provider 的公开 API 造，不点 UI 造。** 理由：

- provider 的写方法（`addCourse` / `updateSettings` / `importAppDataBackup` …）
  **就是** App 自己保存时走的那条路（表单页最终也调它），数据是真实落盘的；
- 点 UI 造数据要面对输入法、滚动、校验、弹层，任何一处不稳都会变成假红，
  而那些环节并不是这四条路径要验的东西；
- 造完数据后，**回到首页看结果**才是断言重点——那一步是纯 UI，绕不掉。

例外是路径 2 的「保存」动作本身：它验的正是「表单 → provider」这一跳，
所以那一步必须点 UI（点保存按钮），不能直接调 provider。

### 路径 2：加一门课 → 保存 → 首页能看到

**要断言的三件事，缺一不可：**

1. **表单真的打开了，且收到了正确的初始值。**
   从首页空槽点进去后，断言表单页在场（`AddCourseScreen`）。
   若从某个具体槽位进入，还要断言表单拿到的 `initialDayOfWeek` /
   `initialStartSection` 与点的那个槽一致——**这是参数透传**，只断言「页面打开了」
   抓不到丢失（AGENTS.md 的 TEST-POLICY 有专门的实证：删掉参数转发后 43 例全绿）。
2. **保存后数据真的进了 provider。**
   `provider.courses` 里出现那门课（按课程名匹配），且 `dayOfWeek` /
   `startSection` 与填的一致。「保存按钮点了没报错」不算证据。
3. **回到首页，课程卡片在屏幕上。**
   断言那张卡片在场**且有非零面积**（`tester.getSize(...).width > 0`）。
   这是本路径唯一真正「端到端」的部分：数据 → 网格布局 → 卡片绘制。

**为什么这样选：**

- 只验第 2 条（provider 里有数据）→ 那只是「存进去了」，没验「看得见」，
  而用户要的是后者；
- 只验第 3 条（卡片在）→ 抓不到「存错了槽位」（卡片可能出现在错误的位置，
  断言按类型找照样通过）；
- 所以必须「数据字段 + 屏幕上可见」两头都钉。

**已知坑：**

- 保存是异步的（`_saveCourse` 里有 `await Future.delayed(16ms)` 再落盘），
  点完按钮必须轮询等 `provider.courses` 变化，不能点完立刻断言。
- 首页课程卡片有多个渲染档（液态玻璃 / 高斯磨砂 / 实体），断言的 widget 类型
  要选**三档共用**的那一层，否则会随设置漂移。

**破坏性提醒**：这条路径会往存储里**写入真实课程**。
在共享设备上必须用内存存储（见纪律第 5 条），否则会污染用户真实课表。

### 路径 3：导入课表 → 解析 → 首页能看到

这是五条里**交互最多**的一条，也是设计上最需要提前说清的。

**关键事实（读源码得出）：** ICS 导入的入口 `IcsCourseImportScreen` 支持
`initialIcsContent` 参数，给了内容就能跳过文件选择器；但导入主流程
`_executeIcsImportCore` 里有**两道阻塞式交互**：

1. `askImportReplaceExisting(...)` —— 已有课程时问「替换还是追加」；
2. `pickImportSemesterConfig(...)` —— 确认学期起始日与第一周。

所以「导入」这条路**不可能一键跑完**，测试必须处理这两个对话框
（或者在造数据阶段就让 `provider.courses` 为空，使第 1 道自动跳过——
源码里 `courses.isEmpty` 时 `replaceExisting` 直接取 `true`，不问）。

**要断言的三件事：**

1. **解析出来的课程字段正确。**
   不只是 `provider.courses.length` 变大——那只能证明有东西进来，
   证明不了解析对不对。要钉某门已知课程的名称、星期、节次与你给的 ICS 内容一致。
2. **学期对齐后周次正确。**
   导入会把课程按 `firstCourseWeek` 平移（`shiftCoursesToSemesterWeeks`）。
   断言某个课程的 `startWeek` / `endWeek` 与你预期的一致——
   这是**独立推导**出来的期望值（从 ICS 里的日期 + 你设定的学期起始日算），
   不是从实现里抄的。
3. **回到首页，卡片出现在正确的星期列。**
   同路径 2 的第 3 条，但更严格：不只要「有卡片」，还要在**你预期的那一天**
   那一列。这是唯一能抓到「导入进去了但排错天」这类 bug 的断言。

**为什么不用文件选择器：**
`FilePicker` 是平台通道，Flutter 测试点不到；而且真机上它会弹系统文件选择器，
那是**原生交互面**——AGENTS.md 的 TEST-POLICY 已说明这类要用 Patrol，
Flutter 自带 `integration_test` 够不着。所以走 `initialIcsContent` 注入。

**这条路径的取舍**：它验的是「解析 + 对齐 + 落库 + 显示」，
**不验**「用户怎么选到那个文件」。后者属于原生面，单独的事。

### 路径 4：改设置 → 杀进程重开 → 设置还在

**这条是五条里唯一必须面对「进程重启」的**，也是最难在 integration test 里做的一条。

**核心难点（必须先想清楚再动手）：**
`flutter test integration_test/` 跑的是**一个进程内的测试**，测试代码没法
「杀掉自己再重开」。有两条可行路线：

- **路线 A（推荐）**：同进程内分段验证——
  1. 改一个可观察的设置（如 `homeNavigationForm` 或主题色）；
  2. 断言 `provider.settings` 变了**且落盘完成**
     （`StorageService` 的写链是 `await` 得到的，等它返回即可）；
  3. 重建整棵 App（`pumpWidget` 换一个新的根，或回到第 1 条的冷启动路径）；
  4. 断言新树上读回来的设置**就是改后的值**。

  这验的是「写下去 → 重新初始化能读回来」这一整条，只是没经历真正的进程重启。
- **路线 B**：用 `flutter drive` + 外部脚本在两次运行之间重启 App。
  更接近真实，但要引入 driver 脚本与设备编排，成本高一个量级。

**建议先做路线 A。** 理由：进程重启本身是 Android 的事，不是本仓代码的事；
本仓可能出错的环节是「写没写下去」「读回来时有没有被默认值盖掉」
（`AppGlobalSettingsService.resolveInitial` 这条路径历史上就有过类似坑），
路线 A 两件都能验到。

**要断言的三件事：**

1. 设置值真的变了（不是点了没生效）；
2. 重建后读回来的是**改后的值**，不是默认值——这条是重点，
   「能改」和「能存住」是两件事；
3. 落盘的键确实存在（可选用 `SharedPreferences` 读一下原始键，
   确认不是只在内存里改的）。

**为什么选「导航形态 / 主题色」这类设置：**
它们的值在首页可见、且会被 `AppGlobalSettingsService` 覆盖式合并
（`resolveInitial` 会把全局那份盖到激活课表上），正好是「读回来被盖掉」这类
bug 的高发区。选个纯装饰性的设置验不出问题。

### 路径 5：备份恢复 → 数据回来

**要断言的三件事：**

1. **导出真的产出了内容**：`DataTransferService.buildBackupJson(...)` 的返回值
   非空、且能解析成合法的 `TransferPackage`（schemaVersion 对得上）。
2. **清空后导入，数据回来了**：把课表清空（或换一个空 profile），
   再 `importAppDataBackup(json)`，断言课程数、某门课的字段、设置值都恢复。
3. **恢复后的数据在首页看得见**：同路径 2 第 3 条。

**为什么必须「先清空再导入」：**
如果只是原地导入，导入失败也会「数据都在」（旧数据还在），测试永远绿。
**必须制造一个「数据确实没了」的中间状态**，导入才有意义——
这是这条路径唯一的价值所在，也是最容易偷懒写错的地方。

**这条路径顺带覆盖的坑**：导入失败时的回滚（本仓有
`transfer_rollback_atomicity_test.dart` 这类存量测试，但那是纯逻辑层）。
真机上要验的是「导入到一半失败，数据没被搞坏」——
建议后续单独加一条变体：**导入一个故意损坏的备份，断言原有数据完好**。

---

## 前置条件

1. **依赖**：`pubspec.yaml` 的 `dev_dependencies` 要有 `integration_test: sdk: flutter`。
   缺它 `flutter test` 会直接拒绝执行（不是跑失败，是拒绝跑）。
   加完必须在 **Windows 侧**跑一次 `flutter pub get`；**WSL 侧禁止**
   （会改写两边共用的 `.dart_tool/package_config.json`，见 `docs/WSL_DEVELOPMENT.md`）。
2. **设备**：真机或已启动的模拟器，`flutter devices` 能列出来即可。
   **未经用户明确许可，不要驱动实体设备**——见下面「设备安全」。

## 设备安全（硬红线，来自 AGENTS.md 的 DEVICE-CONTROL 节）

### 最大的坑：不指定 `-d` 会自动挑设备

**`flutter test integration_test/xxx.dart` 不带 `-d` 时，flutter_tools 会自己找设备。**
源码位置 `flutter_tools/lib/src/commands/test.dart:619-621`：

```dart
Device? integrationTestDevice;
if (_isIntegrationTest) {
  integrationTestDevice = await findTargetDevice();   // ← 不指定 -d 就自己挑
```

`findTargetDevice()`（`flutter_command.dart:2044`）的行为是：**恰好一台设备就连上它**，
多台才让你选。所以在只连着一台手机的机器上，一条看起来「只是跑个测试」的命令
会：

1. 把 debug 包**装到那台手机上**（与 App 同包名，会覆盖用户装的同一个 App）；
2. **启动它**；
3. 跑完可能把它留在前台。

**这等于控制用户的实体设备。** 所以本目录下的任何命令都必须显式写 `-d <device-id>`。

### 其他红线

- 跑 integration test 会在设备上**安装并启动** App。用户没说过「可以」就不要做；
  即使说了，也只在那一次、那台设备上。
- 不能用 `-d windows` / `-d chrome` 绕开：本仓没配 Windows 桌面工程
  （`No Windows desktop project configured`），web 则被 flutter_tools 明确拒绝
  （`Web devices are not supported for integration tests yet.`）。
- 测试会往存储里写真实数据。**共享设备上必须用内存存储**
  （`SharedPreferences.setMockInitialValues`），否则会读写这台设备上用户真实的
  课表与设置（路径 2～5 都是写操作，这点比第 1 条更要紧）。

---

## 给用户的运行清单

从零到看到结果，按顺序做。命令都在**仓库根目录**执行。

### 0. 确认前置（一次就好）

```bash
flutter pub get          # 让 integration_test 依赖生效（Windows 侧；WSL 侧禁止）
flutter devices          # 看设备列表
```

`flutter devices` 的输出里要能看到你的设备，例如：

```
25060RK16C (mobile) • 10.196.69.43:5555 • android-arm64 • Android 17 (API 37)
```

**把那一列中间的值（`10.196.69.43:5555`）记下来，就是 `<device-id>`。**

### 1. 手机上要做的（一次性设置）

- 打开「开发者选项」→ 打开「USB 调试」；
- 数据线连上电脑，手机可能弹「允许 USB 调试吗」，点**允许**；
- 无线调试（示例里 `10.196.69.43:5555` 那种）需要先在手机上调出配对码配对，
  配好之后 `flutter devices` 才看得到。

> 这一步**要你自己做**：本 Agent 按铁律不能碰你的设备，包括不能替你点「允许」。

### 2. 跑第 1 条（只读，最安全的一条先跑）

```bash
flutter test integration_test/cold_start_home_test.dart -d <device-id> --flavor dev
```

**注意 `-d` 和 `--flavor dev` 两个都不能省**（`-d` 的理由见上面「最大的坑」；
`--flavor` 的理由：本仓 android 有 dev/perf/prod 三个 flavor）。

### 3. 怎么判断结果

**通过**（绿）—— 最后一行长这样：

```
00:42 +1: All tests passed!
```

含义：冷启动管线在你的设备上跑通了，首页的周课表网格和星期栏**真的渲染出来了**，
并且有非零尺寸。这是「App 能正常起来」的第一个自动化证据。

**失败**（红）—— 看它是红在哪一段，措辞能直接告诉你是哪一环：

| 失败信息包含 | 含义 | 先查什么 |
|---|---|---|
| `应当先渲染自绘启动画面` | 启动画面的分支结构变了 | `main.dart` 里 `_homeRevealed` 相关的 `AnimatedSwitcher` |
| `首页仍未换入` | **真机「卡在启动画面」** | logcat 里搜 `[boot]`；再看 AppLogService 的 `home_reveal_watchdog` / `first_frame_watchdog` |
| `周课表网格（TimetableWeekGrid）没出现` | 首页进来了但骨架没搭起来 | 首页装配（`timetable_home_page_assembly.dart`） |
| `星期栏（TimetableWeekdayHeader）没出现` | 网格有、表头没有 | `timetable_week_page.dart` |
| `启动画面（AppStartupSplash）一直没退场` | 两棵树叠在一起 | `kHomeRevealFadeMs` 那段淡入 |
| `宽度为 0` / `高度为 0` | 网格被布局成不可见尺寸 | 首页布局约束 |

**看设备日志**（跑的时候另开一个终端；这是只读命令）：

```bash
adb -s <device-id> logcat | grep -E "\[boot\]|home_reveal_watchdog|first_frame_watchdog"
```

### 4. 跑完之后

- 设备上会留下一个 debug 包（包名带 `.debug`），**和你日常用的正式版是分开的**；
- 想清掉：手机上直接卸载那个「轻屿课表调试版」即可；
- 告诉 Agent 结果（绿还是红、红的哪一段），好决定能不能进第 2 条。

---

## 写这一类测试的纪律

- **调真的入口**（`import 'package:university_timetable/main.dart' as app;` 然后
  `app.main()`），不要手工拼一个 `MaterialApp` —— 那样测的就不是同一条启动管线了。
- **用轮询等待，不要 `pumpAndSettle()`**。首页永远不会静止（常驻动画、玻璃表面、
  下拉回弹），`pumpAndSettle` 只会等到超时。参考 `cold_start_home_test.dart` 的 `_pumpUntil`。
- **断言落在用户看得见的东西上**：某个具体 widget 有面积、某段文字在屏上。
  「widget 树非空」不算证据。
- **判成败只能靠行为**：`main()` 会装自己的 `FlutterError.onError`
  （`main.dart:306`），顶掉 flutter_test 的异常收集器，启动期的框架异常不会自动
  让用例变红。
- **注意共享设备上的真实数据**：integration test 与 App 同包名。需要独立存储时用
  `SharedPreferences.setMockInitialValues` 换成内存实现（见 `cold_start_home_test.dart`），
  否则会读写这台设备上用户真实的课表与设置。
- **造数据走 provider 的公开 API，不点 UI 造**（路径 2 的保存动作除外）。
  理由见上文「共同难点」。
- **参数透传要单独钉**：凡是「点了某处 → 打开某页并带上参数」的路径，
  必须直接断言目标页面拿到的字段值，不能只断言「页面打开了」。
  AGENTS.md 的 TEST-POLICY 有实证：删掉参数转发后存量 43 例全绿。
