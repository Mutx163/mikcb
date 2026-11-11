# 近期重构页面 · 质量审核（总报告，2026-10-29）

> **审核基线**：HEAD `3f3b7354`（2026-10-29 20:10 提交）。审核时刻 20:33~21:30。
> **工作区当时正被另一会话实时修改**（未提交文件 64 → 84+，`ShellPageIndex.kt`/`TaskHost.kt`/`FeedbackModel.kt` 的 mtime 落在 20:36~20:39），
> 因此**所有判据一律取 `git show HEAD:<路径>`**，工作树差异单列「在途改动（他人，不入判）」，不算缺陷也不算通过。
> **判据文件**：`docs/plans/2026-10-29-quality-audit/_RUBRIC.md`（D1..D6 / 证据规范 / P0-P2 分级）。
> **分报告**（同目录，全部只读复核，未改任何产品代码）：
> [课表核心](2026-10-29-quality-audit/timetable.md) · [设置/时间模板/节假日](2026-10-29-quality-audit/settings-time-scheme.md) · [云同步/备份迁移](2026-10-29-quality-audit/sync-transfer.md) · [诊断/关于](2026-10-29-quality-audit/diagnostics-about.md) · [任务/考试/天气/统计/live](2026-10-29-quality-audit/misc-wiring.md)

---

## 零、结论（先看这段）

**判定：「页面复刻」这一层大部分达标；「接线闭环」这一层系统性不达标。**

| 维度 | 实况 |
|---|---|
| 计数 | **P0 15 条 / P1 37 条 / P2 41 条**；另有「文档与源码不符」**16 条** |
| P0 的性质 | **15 条全部是「用户点得到、但没反应 / 没生效 / 丢数据」**，没有一条是样式或像素问题 |
| 真复刻且经得起查的 | 周视图（周网格/课卡/表头/时间列）、情侣课表、学期设置、节假日两页、时间模板两页、天气选城市、任务清单、诊断五页（10-29 那次的死页已修） |
| 系统性病灶 | ① 动作通道断头 ② 守卫只覆盖 5 页且可绕过 ③ 文档/台账失真 |
| 交付卫生 | **HEAD 的 JVM 闸门本身是红的**（2 条真失败）；**暂存区里有一份 −1720 行的删除**，谁不带路径提交谁就把这堆回退带上去 |

一句话给决策人：**这批页面的「像不像」做到了，「能不能用」没有普遍做到；而且交付方的自述文档已经不可信（16 处与源码相反）。**

---

## 一、审核口径（为什么结论能站住）

1. **判据来源优先级**：Dart 原版源码 + `lib/l10n/app_zh.arb` > 真机基线截图 > 本仓文档（含既有审核文档、认领文件，**只作线索**）。
2. **五个域各一名独立审核员**（互不依赖，各写各的报告），同一份判据，逐页给 D1..D6 结论 + 证据。
3. **Lead 独立复核**：机械层（样式/文案/中文硬编码/ARB 对拍覆盖）+ **在 HEAD 快照上实跑 L0**（不在移动的工作树上跑，见 §五）。
4. **最严重的一批断言由 Lead 逐条回源码复核**（见 §四.5「已复核清单」），不是转述审核员。

---

## 二、机械层结论（客观可复核，全部在 HEAD）

| 关卡 | 结果 | 证据 |
|---|---|---|
| Compose 样式守卫（R1..R6） | **0 新增 / 0 过期**。当前 12 处违规**全部在基线内且都写了例外理由**：timetable 9（课程/日程/假期/考试的数据色 + 两处滚动容器例外）、exam 2（`AddExamPage` R2 表单滚动、`ExamListPage` R5 两个固定状态色）、guide 1（组件展厅的固定色样例）；其余 18 域 0 | `pwsh -File scripts/compose-style-lint.ps1 -Domain all`，与 `tool/compose_style_baseline/{timetable,exam,guide}.txt` 逐行比对（9/2/1 条，一一对应） |
| 文案守卫（行内超宽/死键/复述） | 超宽 203 条存量、新增 **0**；死键 537 条存量、新增 **0**；复述句 **0** | `dart run tool/copy_style_lint.dart` |
| 中文硬编码闸门（CJK 棘轮） | 24 个文件计数冻结；本轮五个族的扫描**未发现基线外新增**（timetable 域仅 2 条真命中，且都在基线里） | 各族报告 D3 节；`CjkLiteralGateTest` 的基线文件 |
| ARB 逐字对拍 | 课表 243 条、课程弹层 243 条、情侣 212 条、设置 652 条、其余族合计 —— **0 处不一致** | 各族机械对拍脚本（对 HEAD 的 `app_zh.arb`） |

**机械层唯一的结构性缺口（Lead 发现，P2）**：
`TimetableProfilesPage.kt` 线上在用的 `TimetableProfilesStrings`（24 条 `const val` 硬编码，CJK 基线冻结 36 条）与 `TimetableStrings`（24 条 `ArbText`，有 `TimetableStringsParityTest` 守卫）**是同一批文案的两套来源**；
页面用的是**没有对拍守卫**的那一套，其中 6 条（`timetableProfilesTitle` / `createdProfile` / `switchedToProfile` / `renamedProfile` / `clearedProfile` / `deletedProfile`）在受守卫的副本里**0 引用**。
当前值逐字一致（已机械核过 24/24 都能在 ARB 值集里找到），但**下次 ARB 改字，页面不会跟，守卫也不会红**。

---

## 三、逐族结论

| 族 | 入判页面 | P0 / P1 / P2 | 一句话 | 最严重的一条 |
|---|---|---|---|---|
| **课表核心** | 10（周视图 6 + 弹层 3 + 日视图 9 件） | **2 / 14 / 9** | 周视图是真复刻；**日视图是半接** | 日视图每张课卡的「作业」「备注」胶囊点了没反应（壳没传回调）；点「周五」进的是今天 |
| **设置 / 时间模板 / 节假日** | 13 | **4 / 8 / 6** | 学期、节假日、时间模板扎实；**设置族整条动作通道没人接** | 主题管理 4 处 + 课卡「重新配色」点了没反应（`onIntent` 默认 `{}`，壳一次没传）；11 个设置分支喂空构造 state |
| **云同步 / 备份迁移** | 12 | **3 / 3 / 7** | 情侣课表是全仓最扎实的一线；**导入会丢数据** | 全量备份导入只写回档案/课程，时间模板/日程规则/作业/考试全丢，而界面文案说「全部数据备份」 |
| **诊断 / 关于** | 6 | **2 / 5 / 11** | 五条受管分支已真接宿主（10-29 事故形态已消失）；**入口仍是空的** | 「查看手机日志」空 lambda；`b.liveSelfCheck` 整页空壳（而它正是 LIVE 日志入口） |
| **任务 / 考试 / 天气 / 统计 / live** | 6 族 | **4 / 7 / 8** | 任务真接、天气全绿；考试表单与统计分享是死的 | `d3.addExam` 是彻底死表单（16 个空回调，列表的「+」和「点一条」都进它）；live 显示设置 3 条路由改了不落盘 |

**各族报告里的正面证据也一并记了**（避免只看缺陷误判整批）：周视图 243 条 ARB 全等、模型层与 Dart 逐分支对应；情侣课表九个动作全部有落点、阻塞调用都在 IO 线程、失败如实报；学期设置 13 例行为断言（含「开学前算第 1 周不算 0」）；节假日/时间模板/天气/任务各有对应宿主与断言。

---

## 四、系统性问题（这才是本次审核的主结论）

### 4.1 动作通道断头：同一病灶出现在 6 个族、8 类（20+ 处控件）

模式完全一样：**渲染层发动作 → 分派器翻成意图 → 宿主/壳的入口默认值是 `{}` / `= {}` → 生产代码 0 消费者**。
屏上控件照常渲染、能点、无反应，而且单测全绿（测的是模型层与渲染层）。

| # | 位置 | 现象 | 根因 |
|---|---|---|---|
| 1 | `settings`：主题管理「导出/导入/保存当前主题/已存主题更多操作」+ 课卡「课表重新配色」 | 5 处控件点了没反应 | `SettingsHost.kt:124 onIntent = {}`，壳 `ShellPageIndex.kt:330-335`（HEAD）没传；`ShowSheet/ShowDialog/ClipboardExport/ShowRecolorSheet` 生产 0 消费者 |
| 2 | `exam`：`d3.addExam` | 新增/编辑考试表单完全不可用 | 空 state + **16 个空 lambda**；列表两个入口都指向它 |
| 3 | `timetable`：日视图课卡「作业」「备注」胶囊 | 每张卡都有、点了没反应 | `c3.day` 分支没传 `onOpenCourseNotes/onOpenCourseTask`，页面默认 `= {}` |
| 4 | `live`：显示设置 3 条路由 + 提醒时机 | 改了退出即还原；选图恒 null；免打扰/速览空实现 | 便捷重载用 `remember { mutableStateOf(initialState) }`，`onPersist` 默认 `{}` |
| 5 | `statistics`：主页分享 | 图标有数据时可见可点，点了没反应 | `onOpenShare = {}`（代码注释诚实登记为「链缺口」，但控件没隐藏也没给实话） |
| 6 | `about`：高级选项「查看手机日志」 | 点了没反应（且它是诊断族在更新页的入口） | `onOpenDiagnostics = { /* 路由未接入 */ }` |
| 7 | `transfer`：局域网编辑 / 取件码 | 两页全空回调 | `LanEditModel()` 默认值 + 3 个空回调；`onEntryClick = {}` + `installedOf` 恒 true |
| 8 | `settings`：11 个分支 | 开关/滑杆不动 | `SettingsScreen(SettingsPageState(), …)` 空构造 state（存量，非本期） |

**共同修法（一次性能治住大半）**：把「控件可见但无落点」变成机器可判 —— 见 4.2。

### 4.2 守卫覆盖不足，且当前守卫本身有两处可绕过

- `DiagnosticsWiringGuardTest` 只管 `MANAGED` 里的 **5 个诊断页**。它的 `FORBIDDEN` 已经包含 `SettingsPageState()` 模式，但**没登记任何一个设置页** ⇒ 把设置页加进 `MANAGED` 就会立刻红（现成修法）。
- 两条绕过通道：
  ① `\bnull\b\s*,?\s*$` 未开 `MULTILINE`，`= null` 只有落在分支体末尾才被抓；
  ② 宿主符号是**纯文本包含**判断，在注释里写一次即绿。
- 覆盖盲区（今天就有活靶子）：`a.support`（`onReload = {}` 挂成按钮）、`a.contributors`（空回调 + `emptyList()`）、`b.liveSelfCheck`、`c3.day` 页面签名默认值里的空 lambda（守卫不读页面签名，只读分派分支）。

### 4.3 文档失真 16 条（「已做」其实没做，也有「没做」其实已做）

| 类型 | 例子 | 后果 |
|---|---|---|
| 已做写成没做（消息过期） | 派工大表 ST1「统计仍喂 `emptyList()`、用户看到空页」→ HEAD 三个统计分支全走真快照；`RECON-L4.md`/台账「缺宿主槽位 2、全仓无 CameraX」→ 扫码真宿主 + CameraX/MLKit 已进；情侣课表文档「本仓没有 FileProvider」→ 19:04 就注册了（比该文档所属提交早 3 分钟） | 下一个接单的人白跑一趟；或不敢用已具备的能力 |
| 没做写成已做（虚标） | `claims/P35-settings-dead-controls.md` 把「保存当前主题」记为已接；`compose-general-page-audit.md` 说写盘失败静默「已改」→ 复核仍在（`commit()` 返回值被丢弃） | 台账失真，验收被绕过 |
| 注释/KDoc 过期 | `TimetableWeekPage.kt:80-81`「设置全部下传」→ 7 个属性渲染层 0 读；`PerfReportHost.kt` 说「壳里没接」→ 已接；`SettingsRowRenderTable.kt` 承诺的 `SettingsRenderContractTest` 全仓不存在 | 读代码的人被误导 |

### 4.4 存量死页群（P0/P1 混合，先记账再排期）

`b.liveSelfCheck`、`d3.locationMatch`、`d3.addExam`、`g3.lanEdit`、`g3.pickupCodes`、11 个 `SettingsPageState()` 设置分支 —— 共 **16 条可进入路由**在 HEAD 上「能打开、不能用」。

### 4.5 Lead 已逐条复核的断言（不是转述）

1. `d3.addExam` 空 state + 16 空 lambda（HEAD `ShellPageIndex.kt:823-844`）✅
2. `j.live`/`j.displayBefore`/`j.displayDuring` 三条路由走 `remember` + 默认空回调（HEAD `:1280-1282` ↔ `DisplaySettingsPage.kt:515-545`）✅
3. `j.reminderTiming` 的 `onPersist` 默认 `{}` ✅；统计 `onOpenShare = {}` ✅
4. 数据迁移导入不写回 tasks/exams/timeSchemes（`DataTransferHost.kt:397-460`），而 Dart `unified_transfer_service.dart:663-744/800-1029` 全写回 ✅ —— 且界面文案说「全部数据备份」，未提示缺口 ✅
5. `g3.lanEdit` / `g3.pickupCodes` 空回调 ✅
6. 全量备份「合并」显示「发生未知错误」：机器码 `full_backup_merge_unsupported` 未登记，`TransferServiceMessages.localize` 兜底到 `unknownError` ✅

### 4.6 交付卫生两条（不属于页面质量，但会直接坑到下一次提交）

1. **HEAD 的闸门是红的**：`MonthViewStringsParityTest` 少 ARB 键 `monthOverviewMoreDays`（HEAD `app_zh.arb` 里 0 次，工作区 2 次）；`ShellPageDispatchCoverageTest` 的路径常量仍指向**已删除的 `composeUi` 源集**（5 例全红）。两处修复都只存在于未提交的工作区。
2. **暂存区里有一份 −1720 行的删除**（`git diff --cached --stat`：8 files, +22 −1720，含 `LiveDisplayHost.kt −320`、`LiveDisplayStore.kt −526`、`SettingsPageRenderers −239`、`SettingsPageModel −68`）。任何人此刻**不带路径**执行 `git commit` 都会把它提交上去。
3. 附带：工作区当前**编译不过**（`app/TimetableSettingsModel.kt` 引用尚未落盘的 `LiquidGlassTuningModel`，HEAD 无此引用）——这是另一会话的在途状态，不是被审页面的缺陷；但它意味着**此刻任何 L0/L1/L2 结果都不能归因到 HEAD**。

---

## 五、HEAD 闸门实跑（Lead 本轮做的独立证据）

方法：`git archive HEAD` 建 30MB 快照（`android/app/src` + `lib` + `docs/releases`），用仓库同一脚本 `scripts/test-kotlin-module.ps1` 在快照上串行跑——**避开移动的工作树，结果可归因到 HEAD**。

| 域 | 例数 | 结果 |
|---|---|---|
| about | 148 | ✅ |
| course | 211 | ✅ |
| diagnostics | 236 | ✅ |
| exam | 81 | ✅ |
| holiday | 36 | ✅ |
| import/warehouse | 73 | ✅（补 `lib/` 后转绿，原失败是快照缺 Dart 文件） |
| live | 107 | ✅ |
| schedule | 23 | ✅ |
| settings | 644 | ✅（补 `lib/` 后转绿，原失败是快照缺 `settings_shared.dart`） |
| shell | 52 | ❌ **5 例**：路径指向已删除 `composeUi` 源集 |
| statistics | 255 | ✅ |
| sync | 213 | ✅ |
| task | 26 | ✅ |
| time_scheme | 129 | ✅ |
| timetable | 221 | ❌ **2 例**：HEAD `app_zh.arb` 缺 `monthOverviewMoreDays` |
| transfer | 206 | ✅ |
| weather | 17 | ✅ |

**合计 2678 例，7 例红，2 个模块**（其余「红」经补文件后确认是快照环境问题，不是代码问题）。

> 口径限制：L0 只覆盖 `pages/<域>` 的模型层与域内测试；**根级守卫**（`ComposePageStyleGuardTest`、`PageScaffoldGuardTest`、`i18n/CjkLiteralGateTest`）要 L2 才跑，本轮未跑。
> 咬合探针（改坏→红）本轮**没有做**——这是 L2 级别的动作，且工作树不稳定。

---

## 六、没能验证的（诚实边界）

- **真机（L3/L4）一条都没验**：所有「点了没反应」都是源码链推断，需真机逐页对照确认（尤其 P0 清单）。
- **L1 编译 / L2 全量单测**：未跑（工作树不编译 + 会与另一会话抢资源）。
- **咬合探针**：未做反向验证，守卫「有没有牙齿」只有代码阅读结论。
- 样式 lint 不覆盖 `composeP1/app/*Host.kt`（6 个宿主文件）——宿主的布局债不在机械判据内。
- 契约层（参数透传）只做了壳分支静态比对，没有补契约测试。

---

## 七、建议修复顺序（按「用户损失 × 修复成本」排）

| 顺序 | 事项 | 为什么先修 | 涉及 |
|---|---|---|---|
| 1 | **数据迁移导入补齐**：tasks/exams/timeSchemes/scheduleDateRules 写回；补不了就在界面上诚实提示 | 唯一会**损坏用户数据**的缺陷；导出侧已带全，解析侧已解析，仓储已有方法 | sync |
| 2 | **设置族动作通道接线**：壳传 `onIntent`，接 `ShowSheet/ShowDialog/ClipboardExport/ShowRecolorSheet` | 5 处控件在设置首页附近，用户最容易撞上 | settings |
| 3 | **考试表单接真宿主**：`d3.addExam` 换成真状态/回调（列表已真） | 考试族一半是好的，差的一半是死表单 | exam |
| 4 | **live 显示设置与提醒时机落盘**：`onPersist` 接仓储；选图接系统相册；免打扰/速览要么真做要么给实话 | 设置类页面「改了不生效」最难被用户容忍 | live |
| 5 | **日视图补齐**：作业/备注胶囊落点、点哪天带哪天、日程/考试/待办三条通道、摘要卡文案 | 日视图是主路径之一 | timetable |
| 6 | **四个死页**：`b.liveSelfCheck`、`d3.locationMatch`、`g3.lanEdit`、`g3.pickupCodes`（+ 11 个空 state 设置分支排期） | 能进但没功能 | settings/sync |
| 7 | **守卫补强**（一次投入长期收益）：把设置/live/日视图页加进 `MANAGED`；`FORBIDDEN` 的 `= null` 开 `MULTILINE`；宿主符号判断排除注释；把「页面签名默认值里的 `= {}`」纳入扫描 | 断头病灶 8 处里有 6 处能被这条守卫抓住 | shell/guard |
| 8 | **交付卫生**：提交前修 HEAD 的两条红（ARB 键 + 壳测试路径）；**清理暂存区那份 −1720 行删除**（先确认归属） | 不修则下一批交付的「闸门绿」不可信 | Lead |

---

## 八、给用户的一句话

**这批页面的「看起来像原版」已经做到了，但「点下去真的有用」还有 15 处硬伤；其中最该先修的是数据迁移导入（会丢数据）和设置族的 5 个死控件，其余按上表排。**