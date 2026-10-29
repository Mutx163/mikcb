# 诊断族 · 迁移质量审核与完善（2026-10-29）

> **范围**：P3-H「诊断与测试夹具」全部 5 页 —— 设置→诊断、应用日志查看器、内存统计、性能报告、临时测试夹具。
> **对照物**：Flutter 原版（`lib/screens/…` + `lib/services/…` + `lib/utils/…`）。
> **被审对象**：Compose 渲染层 `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/`、
> 模型层 `android/app/src/main/kotlin/com/mutx163/qingyu/pages/diagnostics/`、壳接线 `pages/ShellPageIndex.kt`。
>
> **一句话结论**：P3-H 交的是**模型层 + 渲染层 + 91 例单测**，但**壳接线层是空壳**——4 个页面全部喂空数据、
> 19 个交互全是空 lambda，另有一个页面（设置→诊断）用空 state 渲染。所以「页面在、功能没接」。
> 本轮把数据源与交互接成真的，并把三个 Kotlin 侧根本不存在的能力层（应用日志写入、帧性能探针 + 台账、
> 性能设置快照）补了出来。**页面结构同时逐块对齐了 Dart**（明细见 §四 与各泳道 gap 文档）。

---

## 一、壳接线层实测（本轮修复的 P0）

`pages/ShellPageIndex.kt` 逐行核对（审核前状态）：

| 壳 id | 审核前接线 | 判定 | 本轮处置 |
|---|---|---|---|
| `b.diagnostics` | `SettingsScreen(SettingsDiagnosticsPage.spec(SettingsPageState()), onBack)` | ✗ 空 state：`recordingEnabled` 恒 false、开关拨了没反应；`showMemoryStats = null` ⇒ **内存状态 / 设置快照两行永远不渲染**；应用日志行无 `onAction` ⇒ 点了没反应 | 换真宿主 `DiagnosticsSettingsHost` |
| `h.log` | `parsed = DiagnosticsLogSnapshot.EMPTY` + 9 个 `{}` | ✗ 永远空页，9 个交互全死 | 换真宿主 `DiagnosticsLogHost`（真读文件 + 轮询） |
| `h.memory` | `snapshot = null` + 4 个 `{}` | ✗ 永远「还没采到」；`MemoryStatsCollector`（688 行真采集）就在仓库里却一行没接 | 换真宿主 `MemoryStatsHost` |
| `h.perfReport` | `buildPerfReportViewState(snapshot = null)` + 6 个 `{}` | ✗ Kotlin 侧无探针/台账 ⇒ 永远「Probe is not installed」，6 个交互全死 | 补探针 + 台账，换真宿主 `PerfReportHost` |
| `h.fixture` | `sections = emptyList()`, `courses = emptyList()` + 4 个 `{}` | ✗ 永远空态，装/清都没动静 | 换真宿主 `LiveTestingFixtureHost` |

**为什么长期没被发现**：P3-H 的验收列是「模型层 ✅ / 渲染层 ✅ / 单测 ✅ / 真机对照 ⬜」，
接线在「第四列之外」；派工大表 §五 只用一句话承认「诊断族 页面在、真数据未接」，没落到行号。
⇒ 审核口径要补一条：**渲染层交付 ≠ 页面可用，回路必须过壳**。

## 二、入口覆盖（用户能不能走到这 5 页）

Dart 侧一共 7 个入口：

| # | 入口 | Dart 出处 | 壳现状 | 处置 |
|---|---|---|---|---|
| 1 | 设置首页 →「诊断」行 | `timetable_settings_screen.dart:302` | 行在、`onNavigate` 已接 → `b.diagnostics` | 通 |
| 2 | 关于 →「应用日志」 | `about_screen.dart:526`、:1246 | `AboutStaticPage.routeOf(APP_LOGS)` → `h.log` | 通（依赖 #4） |
| 3 | 设置→诊断 →「应用日志」 | `settings_diagnostics.dart:118-119` | 无 `onAction` | 已修 |
| 4 | 设置→诊断 →「内存状态」 | 同上 :67-79 | 行永不渲染（`showMemoryStats = null`） | 已修 |
| 5 | 设置首页「开发者工具」组 → 内存状态 / 实时活动夹具 | `timetable_settings_screen.dart:1052-1070` | **整组可见性由 `diagnosticsBuild` / `releaseBuild` 决定，而 `SettingsTimetableHubHost` 两处都用默认 `false`** ⇒ 诊断构建里也永远不显示 | 已修（传真值） |
| 6 | 内存统计 →「性能报告」 | `memory_stats_screen.dart:250` | 页面有回调参数，壳里是 `{}` | 已修（`onOpenPerfReport`） |
| 7 | 设置→实时活动 →「实时诊断日志」（live 源）/ 教务导入会话日志（warehouseImport 源） | `settings_live.dart:328`、`warehouse_shared.dart:35` | `SettingsLivePage` **没有这一行**；也没有「导入会话日志」采集层 | 见 §六（未完成） |

> 入口 5 是最容易误判为「已经好了」的一条：页面在、行在、路由表也通，
> 唯一的问题是可见性开关从来没被喂过真值。

## 三、数据源（功能复刻的前置条件）

| 页面 | Dart 数据源 | Kotlin 审核前 | 本轮结果 |
|---|---|---|---|
| 应用日志 | `AppLogService`（639 行：写入 / 截断 / 合并 / 变更轮询） | **完全没有写入层** | 新增 `infra/AppLogFile.kt` + `infra/AppLogStore.kt`（同路径同格式 `filesDir/logs/app_runtime.log`，可与 Flutter 那份互读），`UmengApplication` 启动时初始化 |
| 内存统计 | `MemoryStatsService` → MethodChannel → `MemoryStatsCollector` | 采集器在，**没有任何页面调用 `buildSnapshot()`** | 宿主直接 `buildSnapshot(context)`（IO 线程），不再走 channel |
| 性能报告 | `PerfProbe` + `PerfPageLedger`（614 行台账） | **都没有** | 新增 `PerfPageLedger.kt`(≈560) / `PerfProbeCore.kt` / `PerfStartupRecorder.kt` / `PerfSessionFiles.kt` / `PerfJson.kt` + `platform/PerfProbe.kt`（原生 `FrameMetrics` 采集） |
| 临时测试夹具 | `LiveTestingFixtureService`（481 行） | 只有节次/命名纯逻辑，**无安装/清理服务** | 新增 `LiveTestingFixtureActions.kt`（安装 24 时段 / 只删夹具 / 触发某节） |
| 设置快照行 | `logPerformanceSettingsSnapshot`（340 行） | **没有** | `PerformanceSettingsSnapshot.kt`（26/76 键有真读源，其余登记为 pending，不编造） |

## 四、逐页结论（审核 → 处置）

> 完整证据表（Dart 行号 → Kotlin 文件:行）见 `.agents/compose-phase3/claims/_DIAG-<泳道>-gaps.md`。

### 4.1 设置 → 诊断（`settings_diagnostics.dart` 148 行）

- **结构**：标题 + 单一分组 + 4 行，与 Dart 一一对应（应用日志用 `details`（行尾）槽位，Dart 就这么写的）。
- **四行全部接真**：应用日志 → `onNavigate("app-logs")`；开关 → 读模型真值 + 合并写 + 失败把开关拨回真源并提示；
  内存状态 → `MemoryStatsCollector.isDiagnosticsPackage(context)`（**Kotlin 同步判定**，不再有 `FutureBuilder` 的 null 中间态）；
  设置快照 → 真打一条（`reason=manualExport`）并按「记录应用日志」开关决定是否落盘 + toast。
- **新增**：`TimetableSettingsModel.liveEnableLocalDiagnostics`（字段 / `toJsonPatch` / `OWNED_KEYS` / `fromJson` 四处）。

### 4.2 应用日志查看器（`live_diagnostics_log_viewer_screen.dart` 1522 行）

33 项逐块对照，**9 个交互全部落地**：选级别、加载更早（含视口锚定）、展开条目、设备信息、
视图模式（结构化/原文）、时间排序（含落盘 `diagnostics_log_time_sort`）、复制、导出/分享、清空。
真数据：应用日志 + 原生超级岛诊断日志（`live_update_diagnostics.log`）合并，每秒按 `size:mtime` 指纹去重轮询。
**抓到一个反向 bug**：原模型 `title = parsed.title.ifEmpty { title }`，真数据一进来页头会变成文件头首行
`log_export_title`（Dart 从不渲染 `parsed.title`）——已改为 `title.ifEmpty { parsed.title }` 并用测试钉住。

### 4.3 内存统计（`memory_stats_screen.dart` 1116 行）

22 项对照。真采集（首帧就有数）、自动刷新 3 秒（Dart `:24`）、仅前台刷新（生命周期门控）、
防重入、手动刷新才显示加载、复制 JSON（2 空格缩进口径）、打开性能报告；
UI 补齐：行首图标语义色（16 行原本一律灰蓝）、弹层限高 + 内部滚动（长内容原本被顶出屏幕）、
键值表 128dp 定宽、可清性标签 12% 底色、等宽原文、错误态红条、无快照时禁用。
`dartVm` / `flutterImageCache` 两行**不编数字**（原生采集器不产出该键），按 `—` 渲染并用测试钉死。

### 4.4 性能报告（`perf_report_screen.dart` 305 行 + 台账 614 行）

**这是唯一「能力层整体缺失」的页**：Kotlin 侧没有探针也没有台账，所以永远走「未安装」分支。
本轮移植：预算收紧 / 卡顿容差 1.25 / vsync 可信区间 / 面板档位 8% 容差 / `boot` 行 / 150ms 最短驻留 /
等效帧率 / 三级排行 / verdict 1.3 倍判据 / 文本报表 / 快照 JSON 键序 / 导出保留 12 轮 / 会话保留 10 份。
原生采集用 `Window.OnFrameMetricsAvailableListener`（主线程三段=build、渲染合成三段=raster）+ `Choreographer`（vsync），
CPU/RSS 走 `Process.getElapsedCpuTime()` + `/proc/self/statm`；启用门控 = `DEBUG` / `bench` / `debuggable`，
正式包判「未安装」并显示 Dart 同款文案。UI 补齐：Totals 徽标、startup teal、Round control 行级点击（去掉嵌卡）、
原文 `SelectionContainer` + 等宽、导出图标语义（`save_alt` → `Download`）、5 秒自动刷新、四句 toast。

### 4.5 临时测试夹具（`live_testing_fixture_screen.dart` 395 行）

数据来自仓储真快照（课程 / 节次 / 时间模板），安装 24 时段测试课表（清旧 → 套 24 段 → 每节一门 → **一次落盘**）、
清空（**只删 `live_test_` 前缀**，用户真实课程原样保留，有反向验证过的单测）、课前提醒档位（1/3/5/8 分钟）、
触发当前/下一节（写课；原生超级岛刷新未移植，见 §六）。「当前/下一节」每 30 秒自己走，比 Dart 的「每次 build 取 now」更准。

## 五、本轮修复清单

| 泳道 | 文件 | 内容 |
|---|---|---|
| Lead（接线 + 入口） | `pages/ShellPageIndex.kt`、`composeP1/app/SettingsSemesterHost.kt`、`UmengApplication.kt`、`pages/PagesShellActivity.kt` | 5 个壳分支换真宿主；设置首页开发者工具组传真 `diagnosticsBuild`/`releaseBuild`；应用日志存储层初始化；性能探针挂载 + 换页打点 |
| A 日志 | `infra/AppLogFile.kt`、`infra/AppLogStore.kt`、`pages/diagnostics/DiagnosticsLogFeedModel.kt`、`composeP1/app/DiagnosticsLogHost.kt`、`composeP1/pages/diagnostics/LiveDiagnosticsLogPage.kt` | 写入层 + 合并源 + 9 个交互 + 结构对齐 |
| B 内存 | `pages/diagnostics/MemoryStatsModel.kt`、`composeP1/pages/diagnostics/MemoryStatsPage.kt`、`composeP1/app/MemoryStatsHost.kt` | 真采集 + 自动刷新 + 弹层/键值/配色对齐 |
| C 性能 | `pages/diagnostics/Perf{PageLedger,ProbeCore,StartupRecorder,SessionFiles,Json}.kt`、`platform/PerfProbe.kt`、`composeP1/app/PerfReportHost.kt`、`composeP1/pages/diagnostics/PerfReportPage.kt` | 探针 + 台账 + 6 个交互 + 结构对齐 |
| D 设置/夹具 | `pages/diagnostics/{DiagnosticsRecordingLogic,PerformanceSettingsSnapshot,LiveTestingFixtureActions}.kt`、`composeP1/app/{DiagnosticsSettingsHost,LiveTestingFixtureHost}.kt`、`app/TimetableSettingsModel.kt` | 四行四交互 + 快照移植 + 模型补字段 |

## 六、未完成 / 依赖阻塞（诚实清单）

| # | 缺口 | 为什么没做 | 需要什么 |
|---|---|---|---|
| N1 | 日志「分类/消息」229 键本地化（Dart `AppLogMessageLocalizer`） | 跨页共享件，要同步 ARB 与 key 表，属单独一批 | 移植后改 `buildDiagnosticsLogEntryView` 的 `categoryLabel`/`message` 出口 |
| N2 | `warehouseImport` 源（教务导入执行日志）无数据 | Kotlin 侧没有该会话日志的实现 | 服务移植后给 `DiagnosticsLogHost(source = WAREHOUSE_IMPORT)` 传正文（配置已就绪） |
| N3 | `live` 源在壳里没有独立入口 | 设置→实时活动页没有「实时诊断日志」行 | 补该行 + `DiagnosticsLogHost(source = LIVE)` |
| N4 | 导出拿不到 `.log` 附件（只能纯文本分享） | `AndroidManifest.xml` 未注册 `FileProvider`（全仓 0 处） | 注册 `FileProvider` + `res/xml` 路径；代码里的附件分支已写好 |
| N5 | 性能快照 76 键只接了 26 键 | 玻璃材质 / 材质工厂 / 壁纸路径 / 动画缩放 **没有 Kotlin 读源**，Dart 源文件明确禁止重新推导 | 逐个接读源，接一个删一条 `PENDING_DART_KEYS` |
| N6 | 夹具「24 时段方案条目」没建 | `TimetableRepository` 没有 `createTimeScheme` / `updateTimeScheme` / `applyTimeScheme` | 给仓储加这三个方法 |
| N7 | 夹具「触发某节」不刷新原生超级岛 | `live_testing_trigger.dart`(978) 的岛刷新链路在 Kotlin 侧没有生产实现 | 移植 `LiveHostFace` 的生产实现 |
| N8 | 设置→诊断的「规则拒绝」支今天不可达 | Kotlin 合并写没有任何规则校验（Dart 那条是针对节次数的载荷校验） | 逻辑位与单测已就位，真规则上线即接上 |
| N9 | 顶栏毛玻璃 | 全仓未接线（AGENTS 待办） | 共享套件批次 |
| N10 | **真机逐页对照** | 铁律禁止 agent 操作设备 | 用户装 `dev` 包，在 `PagesShellActivity` 里逐页看（见 §七） |

## 七、验证口径

- **已做（可复跑）**：L0 `pages/diagnostics` → **OK (236 tests)**；样式守卫 `-Domain diagnostics` → **0 处**。
  咬合探针共 4 次（内存 key 对拍 / 日志页标题 / 夹具清空不误删 / 台账 ranking），每次都是「改坏 → 红 → 还原 → 绿」。
- **能在真机上验的**（需要用户，本机做不了）：
  1. 设置 → 诊断：开关拨一下退出再进，值还在；诊断包里能看到「内存状态 / 设置快照」两行。
  2. 应用日志：进页面应当有内容（不是空态）；切级别 / 切排序 / 复制 / 导出各点一次。
  3. 内存统计：首屏就有数字，停 3 秒数字会变；长按「原始 JSON」应直接复制。
  4. 性能报告：`dev` 或 `devBench` 包应出排行（不再显示「未安装」）；正式包应仍显示「未安装」（这是对的）。
  5. 临时测试夹具：装一次 → 课表里出现一批临时课；清空 → 只剩你自己的课。
- **不能声明的**：像素级一致（受 miuix 组件能力限制，见 §八）、手势/滚动手感、系统分享面板真实行为。

## 八、有意偏差登记（与 Dart 不同，且是故意的）

| # | 偏差 | 原因 |
|---|---|---|
| 1 | 清空日志**加了二次确认** | Dart 点了就清（`:1001-1037`）。日志被误清无法恢复，加确认更安全；文案复用已有 ARB 键 |
| 2 | 分组间距 8dp（Dart 12dp）、原文块用主题字阶（Dart 写死 10sp） | 样式守则 R2/R4 禁止自拼间距、禁止写死 `fontSize` |
| 3 | 换页打点用 `LaunchedEffect(pageId)`（C 建议 `SideEffect`） | `beginPage` 会「收掉上一段、开一段新的」，`SideEffect` 每帧重组都调会把一次停留切成无数 0 帧片段 |
| 4 | 「记录已关闭」提示固定在筛选条下方（Dart 在列表第一项，会随日志滚走） | 提示属页面级状态，跟着滚走会看不见；口径不变只挪位置 |
| 5 | 内存概览图标用 `Stopwatch`（Dart 是内存/芯片图标） | miuix 图标集 156 个里没有内存/沙漏类图标（详见 §六 N9 类共享限制） |

## 九、给下一批的建议

1. **把「壳接线」纳入验收列**：这一族的 19 个空回调不是个例，`h.*`/`g3.*`/`i.*` 还有一批同类页。
   建议在台账里加一列「壳分支是否真宿主」，用脚本扫 `= {}` / `= emptyList()` / `= null` 的实参。
2. N1（日志本地化）与 N4（FileProvider）是**跨页共享件**，一次做完可以让日志/备份/分享三处同时受益。
3. 真机对照建议与「关于页族」合并成一次 `dev` 包巡场，省用户时间。
