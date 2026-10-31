# 诊断族 + 关于/版本更新族 · 质量审核（2026-10-29，独立复核）

审核基线：HEAD 3f3b7354（2026-10-29 20:10 提交）；审核时刻：2026-10-29 20:33（开始）/ 21:12（收口）。
**修复轮基线：HEAD bf0e5a57（2026-10-29 21:53 提交）；修复轮时刻：22:29 ~ 23:05。**
判据：`docs/plans/2026-10-29-quality-audit/_RUBRIC.md`。只读审核 + 定向修复；未跑 Gradle / L0。

> **第二轮（修复轮）怎么读这份报告**：§一~§五 是第一轮（审核）的原始证据，**行号按 HEAD 3f3b7354**；
> **§六「二轮验真与修复状态表」**给出每条缺陷在 `bf0e5a57 + 修复轮改动` 下的最新状态与处置，以那一节为准。
> 第一轮证据保留不删，方便对照「当时凭什么这么判」。


## 结论（先看这段）

**审核页面清单（commit / 是否在途）**

| 对象 | 交付提交 | 在途? | 判定依据的版本 |
|---|---|---|---|
| `pages/settings/SettingsDiagnosticsPage.kt` + `app/DiagnosticsSettingsHost.kt`（设置→诊断，`b.diagnostics`） | 2d171f22 | 否 | HEAD = 工作区 |
| `app/DiagnosticsLogHost.kt` + `pages/diagnostics/LiveDiagnosticsLogPage.kt`（`h.log`） | 141ff16d / e25baddb / 51578aa3 | 否 | HEAD = 工作区 |
| `app/MemoryStatsHost.kt` + `pages/diagnostics/MemoryStatsPage.kt`（`h.memory`） | 57ad8ca5 / 795d797a（误带） | 否 | HEAD = 工作区 |
| `app/PerfReportHost.kt` + `pages/diagnostics/PerfReportPage.kt`（`h.perfReport`） | 7339b35e / 95cf9c40 | 否 | HEAD = 工作区 |
| `app/LiveTestingFixtureHost.kt` + `pages/diagnostics/LiveTestingFixturePage.kt`（`h.fixture`） | 2d171f22 | 否 | HEAD = 工作区 |
| `infra/AppLogStore.kt` / `infra/AppLogFile.kt`（日志写入层） | 795d797a / 012e068d | 否 | HEAD = 工作区 |
| `pages/shell/DiagnosticsWiringGuardTest.kt`（守卫本体） | 16110db9 | 否 | HEAD = 工作区 |
| `pages/ShellPageIndex.kt`（五支分派） | 见审计文档 §「归属串台」 | **是（他人正在改）** | **`git show HEAD:`** |
| `pages/about/AboutUpdateHost.kt` / `AboutUpdatePage.kt` / `AdvancedOptionsPage.kt` / `ReleaseNotesMarkdownView.kt` | a7e57f51 / 7ae6264a | 否 | HEAD = 工作区 |
| `pages/about/AboutStaticPage.kt` | 7befcba0 / 9f19cd26 | 否 | HEAD = 工作区 |

**计数（第一轮）：P0 2 条 / P1 5 条 / P2 11 条。**

**计数（二轮修复后，详见 §六）：已修 8 条 / 部分已修 4 条 / 他人泳道在修 2 条（F06 实时自检、F09 鸣谢与贡献者）/ 不修有理由 2 条 / 未修（受写作用域阻塞）1 条 / 误判 0 条。**
原 P0-2（`b.liveSelfCheck` 空壳）按 Lead 二轮分工**划归 F06**，原 P1-5（`a.support` 死按钮）划归 F09——两条根因证据仍保留在 §P0-2 / §P1-5。

**守卫 MANAGED 是否漏页：诊断族本身没漏（5/5 正好覆盖 P3-H 四页 + 设置→诊断入口），但「同类事故还能重演」成立——守卫自己的 FORBIDDEN 判据在未受管分支上今天就有 3 个活靶子（`a.support` / `a.contributors` / `b.liveSelfCheck`）。** 依据见 §D1-守卫复核。

**与既有审核文档不一致处：2 条**（`docs/plans/2026-10-28-about-family-audit.md` 的 L1 命令已不可执行；两份宿主 KDoc 自述的「未接线/未注册」状态与源码相反）。诊断族审计文档 `2026-10-29-diagnostics-family-audit.md` 的入口表与我的复核**一致**（live/warehouseImport 入口它自己已列为未完成）。

**D5（样式机械判据）：通过。** `-Domain diagnostics` → 0 处；`-Domain about` → 0 处；两个基线文件都只有注释行（空基线）。但 lint 只扫 `composeP1/pages/<域>/*.kt`，**不覆盖 `composeP1/app/*Host.kt` 五个宿主文件**（见「我没能验的」）。

---

## 一、五条受管分派是否真的接了真宿主（本次最高价值项）

### 复核方法（不依赖守卫自述）

用**与守卫同一套正则**（`^[ \t]*"([A-Za-z0-9._-]+)"[ \t]*->`）把 HEAD 版 `ShellPageIndex.kt` 切成「id → 分支体」，再逐条对 `MANAGED` 与 `FORBIDDEN` 判：

```
$ python .agents/tmp/audit-guardcheck.py /tmp/audit-diag/ShellPageIndex.HEAD.kt
branches=87 unique=87 dups=none
guard#1 all MANAGED have branch: True
  b.diagnostics  host_present=True  body_lines=5
  h.log          host_present=True  body_lines=1
  h.memory       host_present=True  body_lines=5
  h.perfReport   host_present=True  body_lines=1
  h.fixture      host_present=True  body_lines=3
guard#3 forbidden hits:
guard#4 blocks>=70: True  empty_blocks: []
```

（系统编码把中文打花了，`forbidden hits:` 之后为空即代表五支都没命中空 lambda / 空列表 / 空快照 / 空构造 state。）

### HEAD 原文（`git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt`）

```
399:        "b.diagnostics" -> DiagnosticsSettingsHost(
400:            store = wiring.settingsModel,
401:            onBack = onBack,
402:            onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
403:        )
```

```
1216:        "h.log" -> DiagnosticsLogHost(onBack = onBack)
1217:        "h.memory" -> MemoryStatsHost(
1218:            onBack = onBack,
1219:            // 内存统计页里的「查看性能报告」：走壳内推页，不要在本页内嵌。
1220:            onOpenPerfReport = { onOpenPage("h.perfReport") },
1221:        )
1222:        "h.perfReport" -> PerfReportHost(onBack = onBack)
1223:        "h.fixture" -> LiveTestingFixtureHost(repository = wiring.timetable, onBack = onBack)
```

**逐支追到真源（不是只看宿主名字在不在）**：

- `b.diagnostics` → `DiagnosticsSettingsHost` 真读 `store.load()`、真写 `store.save(next)`、两行可见性用 `MemoryStatsCollector.isDiagnosticsPackage(context)` 同步真值、NAVIGATE 走 `onNavigate`（`app/DiagnosticsSettingsHost.kt:73/83/70/144`）。
- `h.log` → 宿主数据源是 `AppLogStore.readMergedText()` / `nativeFingerprint()`（`app/DiagnosticsLogHost.kt:137-148`），9 个交互逐个落真（`:235-337`）；`AppLogStore` 在 `UmengApplication.onCreate` 真初始化（`UmengApplication.kt:22`）；原生日志写入方 `UmengDiagnosticReporter.appendToLocalFile` 写的是同一路径 `filesDir/logs/live_update_diagnostics.log`（`UmengDiagnosticReporter.kt:405` vs `AppLogStore.kt:60-62`）——**路径逐字一致**。
- `h.memory` → `MemoryStatsCollector.buildSnapshot(context)` 真采集，3 秒自动刷新 + 前台门控 + 防重入（`app/MemoryStatsHost.kt:112-161`）。
- `h.perfReport` → `PerfProbe.attach(context)` + `snapshotJson()`；**探针壳挂载也已就位**：`PagesShellActivity.kt:125 PerfProbe.attach(this)`、`ShellPageIndex.kt:258 LaunchedEffect(pageId) { PerfProbe.beginPage(pageId) }`。
- `h.fixture` → `LiveTestingFixtureHost(repository = wiring.timetable, …)` 真仓储。

⇒ **D1（接线真实性）：五条全通过。2026-10-29 那次「五张死页」的形态在 HEAD 里已经不存在。**

## 二、守卫本身：会不会空转 / 能不能绕过

读了 `DiagnosticsWiringGuardTest.kt`（189 行）并复刻其四条判据：

| # | 判据 | 复核结论 | 证据 |
|---|---|---|---|
| 1 | 受管 id 都有分支 | 通过 | 5/5 `host_present=True` |
| 2 | 分支里必须出现宿主符号 | 通过 | 同上 |
| 3 | 分支里不许有空数据/空回调 | 通过（5 支全干净） | `forbidden hits:` 空 |
| 4 | 防空转：`blocks.size >= 70`、清单非空、无空分支体 | 通过 | `blocks>=70: True  empty_blocks: []`；实测 87 支 |

**没有空转，也拿到了当前的正确结论。** 但有 4 条可绕过通道（P2，见缺陷清单 P2-1/P2-2）：

1. **`= null` 的回调只在分支体末尾才被抓到**。`FORBIDDEN` 第 3 条是 `\bnull\b\s*,?\s*$|snapshot\s*=\s*null`（`:181`），正则没开 `MULTILINE`，`$` 只锚输入末尾；`MemoryStatsHost(onBack = onBack, onOpenPerfReport = null)` 这种「中间位置传 null」不会被命中（`null` 后面紧跟 `)`）。带 `snapshot = null` 的快照写法仍被后半段兜住。
2. **宿主符号是纯文本包含**（`:57 blocks[id]?.contains(host)`）：把 `// 宿主见 DiagnosticsLogHost` 这类注释留在受管分支体内即可变绿，与真正调没调用无关。
3. **只扫 `ShellPageIndex.kt` 一个文件**（`:132-149`）：如果将来把某页挪去别处分派、或上层 `when` 提前拦掉，这条分支变成不可达死代码时守卫仍绿。
4. **不验宿主内部**：宿主本身可以是个空实现，守卫只认符号名。

**MANAGED 漏页复核（结论：诊断族没漏，事故类别未兜住）**

- 目录侧反证：`ShellPageCatalog.kt:276-283` P3-H 只有 4 页（log / memory / perfReport / fixture），加 `b.diagnostics` 入口 = 5，与 `MANAGED` 5 条**一一对应**。设置首页入口（`SettingsTimetablePage.kt:82 ROUTE_DIAGNOSTICS = "/settings/diagnostics"` → `ShellWiring.kt:715`）与开发者工具组两行（`ROUTE_MEMORY_STATS`，可见性已传真值 `SettingsSemesterHost.kt:395-403`）都落在受管分支上。
- 类别侧反证（**这就是「漏」的实证**）：把守卫自己的 `FORBIDDEN` 判据套到未受管分支上——

```
-- 同 pattern 扫「未受管」的 about 族分支 --
  a.about          forbidden=none
  a.support        forbidden=[空回调 `= {}`]
  a.contributors   forbidden=[空回调 `= {}`, 空列表 `emptyList()`]
  a.licenses       forbidden=none
  b.liveSelfCheck  forbidden=[空构造 state]
```

  即：**同样的空壳写法今天仍然存在于 3 条未受管分支上**，守卫管不到它们。其中 `b.liveSelfCheck` 正是诊断族第二个日志入口（LIVE 源）的承载页（见 P0-2）；`a.support` 的 `onReload = {}` 已经是一个真的死按钮（见 P1-5）。

## 三、日志链路端到端（任务 3）

`写入层 → 页面读的源 → 清空/导出/分享落点`，四段都核过：

| 环节 | 结论 | 证据 |
|---|---|---|
| 写入层初始化 | 通过（不是「代码在、没人调」） | `UmengApplication.kt:22 AppLogStore.initialize(this)`，且 `AndroidManifest.xml:130 android:name=".UmengApplication"` |
| 写入层口径 | 通过 | `AppLogFile.kt:38 appLogMaxBytes=512*1024`、`:168 mergeAppLogText`、`:184 appLogFingerprint`（`size:mtime`），与 Dart 行号逐条写在 KDoc |
| 页面读的源 | 通过 | `DiagnosticsLogHost.kt:137-148`：`fingerprint()`/`nativeFingerprint()` 相同则整轮跳过，变了才 `readMergedText()`；轮询 1 秒（`:371`） |
| 清空 | 通过（双文件一起清，与 Dart 一致） | `DiagnosticsLogHost.kt:316-320`：`AppLogStore.clear()` + `clearNative()`，两者都成功才提示成功；`AppLogStore.kt:170-197` 真删文件 |
| 导出/分享 | 通过（不再是纯文本降级） | `DiagnosticsLogHost.kt:405-441` 写 `cacheDir/log-share/<name>` → `FileProvider.getUriForFile` → `createChooser`；`file_paths.xml` 有 `<cache-path name="log_share" path="log-share/">`；`AndroidManifest.xml:143-151` provider 已注册（authority `${applicationId}.fileprovider`） |
| 「贴最新端」是否还读过期窗口 | **已修住，未复现** | `DiagnosticsLogHost.kt:200-208`：`rememberUpdatedState(resolvedViewport)` + `onStickToLatestChange(latestResolvedViewport.value, next)`；`latestAtBottom` 只依赖 `timeSort`（`LiveDiagnosticsLogModel.kt:113`），effect 的 key 覆盖它，故闭包里的 `viewState.latestAtBottom` 不会过期 |

**剩下的真问题在「写入广度」**（P1-4）：Kotlin 侧 `AppLogStore.append` 只有 1 个调用点（`DiagnosticsSettingsHost.kt:119` 手动快照），而 Dart 侧 `AppLogService` 有 **139 处引用**（`grep -rn "AppLogService" lib/ --include=*.dart | grep -v app_log_service.dart | wc -l` → 139）。也就是说：「应用日志」这一列今天有内容，靠的是**迁移期 Flutter 还活着、还在写同一个文件**；Flutter 入口一下线，应用日志只剩用户手动点快照那一条。

## 四、版本更新页：检查更新 → 下载 → 发布说明（任务 4）

- **检查更新**：不会假成功。`AboutUpdateHost.kt:238-247` `Malformed → null`，页面 `resolveAboutUpdatePagePhase(packageInfoAvailable, checking, result)` 走 `CHECK_FAILED` 并给重试（`AboutUpdatePage.kt:109-118`）。网络失败/限流都不会伪装成「已是最新」。
- **发布说明渲染**：完整。摘要（`buildReleaseNotesDigest`）+ 兜底 Markdown 两条分支都在，与 Dart 同构（`AboutUpdatePage.kt:438-462`、`ReleaseNotesMarkdownView.kt`）。
- **下载**：有三处与 Dart 不一致且是「用户能察觉」的（P1-2 / P1-3）。
- **「查看手机日志」行是死的**（P0-1）——更新页自己就挂着诊断族的入口，点了没反应。

## 五、逐页结论

### 设置 → 诊断（`pages/ShellPageIndex.kt:399` HEAD / `app/DiagnosticsSettingsHost.kt`）
- D1 通过：四行四交互各有真落点（`:144` NAVIGATE→`onNavigate`；`:146-148` 开关写回；`:149-152` 快照真打一条）。
- D2 通过：`showMemoryStats` 用同步真判定，不再有「永远不渲染两行」。
- D3 通过：文案全走 `SettingsStringsExt3` / `DiagnosticsStrings`；本族未发现渲染层新增中文字面量。
- D4 通过：算法在 `DiagnosticsRecordingLogic` / `PerformanceSnapshot`。
- D6 通过（模型层）：`DiagnosticsRecordingLogicTest` 6 例、`PerformanceSettingsSnapshotTest` 9 例。
- 缺陷：无（P0/P1 级无）。

### 应用日志查看器（`app/DiagnosticsLogHost.kt` + `pages/diagnostics/LiveDiagnosticsLogPage.kt`）
- D1 通过：9 交互全落真（选级别 / 加载更早 / 展开 / 设备信息 / 视图模式 / 时间排序（落盘）/ 复制 / 导出分享 / 清空，`:235-357`）。清空带二次确认（`LiveDiagnosticsLogPage.kt:307-316`）。
- D2 部分有缺陷：Dart 有 `LIVE` 与 `warehouseImport` 两个源 + 「实时诊断日志」入口，Kotlin 壳只有 MERGED（见 P0-2、P2-8）。
- D3 通过（键值）：`DiagnosticsStringsParityTest` 覆盖；`ArbText` 只有 zh → 见 P2-8。
- D6 通过：`LiveDiagnosticsLogViewerModelTest` 32 例、`DiagnosticsLogFeedTest` 14 例、`AppLogFileTest` 22 例、`AppLogStoreTest` 10 例。
- 缺陷：P1-4（写入广度）、P2-6（导出/复制失败静默）。

### 内存统计（`app/MemoryStatsHost.kt` + `pages/diagnostics/MemoryStatsPage.kt`）
- D1 通过：首帧真采 + 3 秒自动刷新 + 前台门控（`:137-161`），「查看性能报告」真推页（`:176`）。
- D2 通过（含诚实边界：`dartVm`/`flutterImageCache` 按 `—`，`MemoryStatsHost.kt:74-79`）。
- D3 有缺陷（已冻结）：`MemoryStatsPage.kt:641` `"堆 ${row.heapRatioText}  ${row.liveLabel}  压力 ${row.pressureLevel}"`、`:727-728` `"  ·主进程"` / `"  ·疑似超级岛相关"` —— 3 条中文字面量，正好等于 `cjk-literal-baseline.txt` 里 `MemoryStatsPage.kt:3`；Dart 原文也硬编码（`lib/screens/memory_stats_screen.dart:910/1049-1050`），属忠实复刻的存量 i18n 债。
- D6 通过：`MemoryStatsModelTest` 35 例、`MemoryStatsCollectorKeyCompatTest` 15 例。
- 缺陷：P2-7。

### 性能报告（`app/PerfReportHost.kt` + `pages/diagnostics/PerfReportPage.kt`）
- D1 通过：`PerfProbe.attach` + `snapshotJson` + 6 交互（导出写 `filesDir/perf_reports`、清台账、展开、复制文本/JSON）；**壳侧挂载也真的在**（`PagesShellActivity.kt:125`、`ShellPageIndex.kt:258`），换页时 `beginPage` 被调用，不会全部记成 `boot`。
- D2 通过（探针口径与 Dart 的四点适配写在 `platform/PerfProbe.kt` KDoc）。
- D6 通过：`PerfPageLedgerTest` 22 例、`PerfProbeCoreTest` 10 例、`PerfReportModelTest` 13 例。
- 缺陷：P2-3（KDoc 过期，说「壳里还没装」）。

### 临时测试夹具（`app/LiveTestingFixtureHost.kt`）
- D1 通过：`repository = wiring.timetable` 真仓储；只审到「分派 + 宿主入参 + 模型层单向依赖」，**页面内交互逐条未验**（时间盒）。
- 缺陷：未发现新增。

### 设置 → 实时活动自检（`pages/ShellPageIndex.kt:376` HEAD，含诊断族 LIVE 入口）
- **P0-2**：仍是 `SettingsScreen(SettingsLiveSelfCheckPage.spec(SettingsPageState()), onBack)`。

### 关于主页（`pages/about/AboutStaticPage.kt`）
- D1 通过：`routeOf()`（`:171-184`）7 个导航入口 + 3 个说明/仓库类就地弹层；壳传 `onOpenPage`（HEAD `ShellPageIndex.kt:267`）。其中 `APP_LOGS -> "h.log"`（`:177`）——关于页的诊断入口是通的。
- D3 通过：`grep` 无中文字面量（注释除外）；标题走 `AboutInfoStrings.aboutTitle`（`:101`）。
- D2 有缺陷（旁支）：见 P1-5。

### 版本更新（`pages/about/AboutUpdateHost.kt` / `AboutUpdatePage.kt` / `AdvancedOptionsPage.kt` / `ReleaseNotesMarkdownView.kt`）
- D1 **有缺陷**：高级选项页两行没有落点（P0-1、P1-1）。
- D2 **有缺陷**：下载链路三处不一致（P1-2、P1-3、P2-9）。
- D3 通过：`AboutUpdatePageStrings` / `AboutUpdateStrings` / `AboutInfoStrings` 与 ARB **逐字一致**——我用脚本机械比对 51 条 `ArbText(key, value)`，`total=51 ok=51 missing=0 diff=0`（含 `lib/l10n/app_zh.arb`）。
- D4 通过：判据/解析在 `AboutUpdatePageModel` / `AppUpdateCheckParser` / `AppUpdateSettings`。
- D6 通过：`AppUpdateModelTest` 16 例（模型层）；**页面级接线无测试**。
- 缺陷：见下。

---

## 缺陷清单

### P0（用户点进去就能发现坏了 / 点了没反应）

**P0-1 高级选项页「查看手机日志」行是空 lambda，点了完全没反应（且这是诊断族入口）。**
`android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdateHost.kt:185`
```kotlin
            onOpenDiagnostics = { /* 日志页路由未在本批次接入 */ },
```
行本身无条件渲染：`AdvancedOptionsPage.kt:196-203`
```kotlin
            item(key = "diag-title") { QingyuSectionTitle(AboutUpdatePageStrings.diagnosticsTitle) }
            item(key = "diag-group") {
                GroupCard {
                    ArrowRow(
                        title = AboutUpdatePageStrings.viewPhoneLogsAction,
                        onClick = onOpenDiagnostics,
                    )
                }
            }
```
Dart 这一行是真入口：`lib/screens/about_screen.dart:1246 openLogViewer(context, AppLogSource.merged)`。
建议修法：`onOpenDiagnostics = { onBack(); … }` 不行——宿主没有路由出口；应给 `AboutUpdateHostPage` 加 `onNavigate: (String) -> Unit`，壳里 `"a.update"` 传 `{ onOpenPage("h.log") }`。

**P0-2 设置→实时活动自检整页仍是空壳（诊断族 LIVE 日志入口的承载页）。**
`git show HEAD:…/ShellPageIndex.kt:376`
```kotlin
        "b.liveSelfCheck" -> SettingsScreen(SettingsLiveSelfCheckPage.spec(SettingsPageState()), onBack)
```
`SettingsScreen` 只放行 NAVIGATE（HEAD `ShellPageIndex.kt:1360-1372`：`onAction = { _, target, _ -> shellPageIdForRoute(target)?.let(openPage) }`）。而这一页的读数全来自 `LiveSelfCheckData()` 默认值（`SettingsLiveSelfCheckPage.kt:486-516`：`serviceRunning=false`、`debugSections=emptyMap()`、`refreshedAtText=null`），三个日志按钮（清空日志 / 查看手机日志 / 更多测试选项，`:384-397`）都是 RUN_NOW/无落点 ⇒ 点了没反应。Dart 的「查看手机日志」= `settings_live.dart:1168 onPressed: _openLiveDiagnosticsViewer` → `openLogViewer(context, AppLogSource.live)`（`:327-328`）。
建议修法：按 `DiagnosticsSettingsHost` 同款建 `LiveSelfCheckHost`（真诊断状态 + 三个动作），并把 `b.liveSelfCheck` 加进 `MANAGED`（否则还会再烂一次）。

### P1（与 Dart 原版可见不一致）

**P1-1「填写/修改自定义下载地址」是假动作：只弹一条标签 toast。**
`AboutUpdateHost.kt:184`
```kotlin
            onEditMirrorUrl = { Toast.makeText(context, AboutUpdatePageStrings.mirrorPrefixLabel, Toast.LENGTH_SHORT).show() },
```
Dart 是文本输入弹窗并写回设置（`lib/screens/about_screen.dart:2259-2276`：`showAppTextInputDialog(title: aboutSetMirrorSourceTitle, initialValue: settings.appUpdateMirrorUrlPrefix, …)` 然后 `updateTimetableSettings`）。用户看到的是「镜像地址前缀」五个字，什么都没有发生。

**P1-2 下载「取消」只停 UI 轮询，不取消下载，也不提示。**
`AboutUpdateHost.kt:202-205`
```kotlin
            onCancelDownload = {
                cancelPolling = true
                download = null
            },
```
`startDownload` 里 DownloadManager 的 `id` 是局部变量（`:114`），没有任何 `manager.remove(id)`；APK 会在后台继续下载，用户以为已取消。Dart：`about_screen.dart:1550-1559 _downloadController?.cancel()` 真取消 + `aboutDownloadCancelled` 提示。

**P1-3「应用内下载」实际没用应用内下载，且丢掉 sha256 校验与安装拉起。**
`AboutUpdateHost.kt:199`
```kotlin
            onInAppDownload = { url, _ /* expectedApkSha256 */, _ /* fallbackUrl */ -> startDownload(url) },
```
`startDownload`（`:96-119`）对不可信 URL 直接 `openUrl`（浏览器），可信 URL 交给 `DownloadManager`；`expectedApkSha256` 被丢弃，下载完成只 toast `installReady`（`:139`），不打开安装器。Dart：`about_screen.dart:1462-1505` 走 `_updateService.downloadAndInstallUpdate(..., expectedApkSha256: expectedApkSha256)`，且拒绝安装时错误码是 `update_sha256_unverified_install_refused`。
⇒ 高级选项里「应用内下载 / 系统下载器」两个选项**行为相同**（都走系统下载器），选项本身失去意义。

**P1-4 应用日志写入点只剩 1 处，日志页的「应用日志」内容靠迁移期 Flutter 侧喂。**
Kotlin 唯一写入点：`app/DiagnosticsSettingsHost.kt:119 AppLogStore.append(...)`（手动快照那一次，且受「记录应用日志」开关门控）。
Dart 侧引用数：`grep -rn "AppLogService" lib/ --include=*.dart | grep -v app_log_service.dart | wc -l` → **139**。
即：Flutter 入口下线后，「应用日志」页基本只有用户手动点「设置快照」产生的一两条；与 Dart「各处关键事件都落盘」可见不同。建议：把 Kotlin 侧关键路径（更新检查、导入、通知、崩溃）逐个接 `AppLogStore.append`，或在文档里明确「应用日志在 Flutter 下线前不完整」。

**P1-5「支持作者」页的鸣谢刷新是真按钮 + 空回调（关于族旁支，同批次改动）。**
`git show HEAD:…/ShellPageIndex.kt:273-278`
```kotlin
        "a.support" -> SupportCreatorPage(
            donorData = null,
            onBack = onBack,
            onReload = {},
            isLoading = false,
            loadError = null,
        )
```
页面把 `onReload` 挂在按钮上：`SupportCreatorPage.kt:256 onClick = onReload`。点了没反应。

### P2（内部债 / 文档失真 / 测试无牙）

**P2-1 守卫的 `= null` 判据只能抓「分支体末尾」的 null。** `DiagnosticsWiringGuardTest.kt:181`
```kotlin
            Regex("""\bnull\b\s*,?\s*$|snapshot\s*=\s*null""") to "空快照 `snapshot = null`",
```
正则未开 `MULTILINE`，`$` 只锚输入末尾（分支体末尾常是空白，`\s*` 可吞），所以 `Host(onBack = onBack, onOpenPerfReport = null)` 这类中间位置的 null 回调不会红。建议改成 `Regex("""(?<![A-Za-z0-9_])=\s*null\b""")`。

**P2-2 守卫只认「宿主符号出现过」，注释里写一次也能绿。** `DiagnosticsWiringGuardTest.kt:57`
```kotlin
            .filter { (id, host) -> blocks[id]?.contains(host) != true }
```
建议同时断言该符号出现在行尾 `->` 之后的**非注释行**，并跨文件校验宿主 composable 声明存在。

**P2-3 守卫只扫 `ShellPageIndex.kt` 一个分派文件，且 `MANAGED` 只覆盖诊断族 5 个 id。** `DiagnosticsWiringGuardTest.kt:132-149`（`dispatchSource()` 候选只有 1 个现役路径）与 `:159-170`（`MANAGED`）。今天已有 3 个未受管分支命中它自己的 FORBIDDEN（`a.support` / `a.contributors` / `b.liveSelfCheck`），见 §二 输出。

**P2-4（文档失真）`PerfReportHost` 的 KDoc 还说探针没装。** `app/PerfReportHost.kt:59-60`
```
 * 但要让**其它页面**也有数据，还需要壳在 Activity 起来时就装上、并在切页时告知页面 id
 * （见 `platform/PerfProbe.kt` 类注释里的两行接线说明；`ShellPageIndex.kt` 属 Lead）。
```
实际已接：`PagesShellActivity.kt:125`、`ShellPageIndex.kt:258`。同理 `platform/PerfProbe.kt:65` 开始的那节「挂载点（壳里要加的那一行）」也已过时（原文写「壳里要加的那一行」，实际两行都已在 HEAD 里）。

**P2-5（文档失真）`AboutUpdateHost` 说 manifest 没注册 FileProvider。** `AboutUpdateHost.kt:41-42`
```
 * - **应用内下载 + 安装**依赖 `FileProvider`（manifest 未注册，属 Lead），本版把「应用内下载」
 *   URL 交给浏览器打开（受信任的直连则走系统下载器）。系统下载器路径完整可用。
```
实际 `AndroidManifest.xml:143-151` 已注册 `${applicationId}.fileprovider`。

**P2-6 日志导出/复制在失败路径上会「假成功」或完全静默。** `DiagnosticsLogHost.kt:276-278`（clipboard 为 null 也 toast「已复制当前日志」）；`:292-304` 调 `shareLogText(...)` 但**丢弃返回值**（该函数 `:395` 的 KDoc 明确 `@return 是否成功拉起过分享面板`），`startActivity` 抛异常时用户看不到任何提示。

**P2-7 内存页 3 条中文硬编码（已冻结的 i18n 债，Dart 同款）。** `MemoryStatsPage.kt:641/727/728`，基线 `cjk-literal-baseline.txt` 记为 `…/diagnostics/MemoryStatsPage.kt:3`。

**P2-8 诊断族文案只有中文一份。** `DiagnosticsStrings.kt:14-25` 的 `ArbText` 只带 `zh` 字段；`MemoryStatsStrings`（`MemoryStatsModel.kt:268`）与 `PerfReportStrings`（`PerfReportModel.kt:57`）是裸 `const val` 中文，**不参与** ARB 对拍（`DiagnosticsStringsParityTest` 只覆盖 `ArbText` 句柄）。切到 en/ja/ko 时整族仍是中文。

**P2-9 模型层 LIVE / warehouseImport 配置在壳里 0 引用（模型层摆设）。** `LogViewerEntryModel.kt:62-77` 备好了 `LIVE`、`WAREHOUSE_IMPORT` 两份 config（标题/分享文案/空态文案），壳里只有 MERGED。审计文档已把 N2/N3 记为未完成，代码侧等于「写完没人调」。

**P2-10 新守卫没有 red→green 留痕。** 审计文档 §七 写「咬合探针共 7 次（…新守卫）」，但 `.agents/compose-phase3/claims/_DIAG-*.md` 里没有这次的反向验证输出；`16110db9` 只新增了 189 行测试文件，没有 red 日志。

**P2-11（文档失真）关于族审计文档给的 L1 命令今天不可执行。** `docs/plans/2026-10-28-about-family-audit.md:156`
```
- **L1** `pwsh scripts/safe-gradle.ps1 :app:compileComposeUiDebugKotlin` → **BUILD SUCCESSFUL**
```
`android/app/build.gradle:7` 已写明「迁移期的 composeP1 / composeUi 两个 flavor 已删除」，`grep composeUi android/app/build.gradle` 只剩注释 ⇒ 该命令现在没有对应任务，后来者照抄会拿到任务不存在。

---

## 六、二轮验真与修复状态表（基线 `bf0e5a57` + 本轮改动）

### 6.1 状态总表（18 条逐条）

> 计数（按最新状态）：**已修 8 条 / 部分已修 4 条 / 他人泳道在修 2 条 / 不修（有理由）2 条 / 未修（受写作用域阻塞）1 条 / 误判 0 条**。
> 第一轮记的 P0×2 / P1×5 / P2×11 一条都没有变成「误判」——全部在当前代码里重新定位到了。

| # | 第一轮结论 | 当前状态 | 依据（当前文件:行号，非第一轮行号） |
|---|---|---|---|
| P0-1 | 高级选项「查看手机日志」空 lambda | **已修** | `composeP1/…/pages/about/AboutUpdateHost.kt:330-335` 不再是空 lambda：有壳出口走 `onOpenPage("h.log")`，没有则 `showLogs = true` 渲染真 `DiagnosticsLogHost`；`AdvancedOptionsPage.kt:238` 那行 `onClick = onOpenDiagnostics` 现在有落点，兜底渲染在 `AboutUpdateHost.kt:302-303` |
| P0-2 | `b.liveSelfCheck` 整页空壳 | **他人泳道在修（F06）** | 壳侧仍是 `HEAD bf0e5a57 的 ShellPageIndex.kt:425` `SettingsScreen(SettingsLiveSelfCheckPage.spec(SettingsPageState()), onBack)`（根因证据见第一轮 §P0-2，此处不改，避免与 F06 撞车） |
| P1-1 | 镜像地址编辑只弹一条标签 toast | **已修** | `AdvancedOptionsPage.kt:83-101/246-…`（真 `OverlayDialog` + `TextField`，非法值就地报 `mirrorPrefixInvalid`）+ `AboutUpdateHost.kt:318-327`（`normalizeMirrorUrlPrefix` 后 `persist`，提示 `mirrorSaved`） |
| P1-2 | 取消只停 UI 轮询 | **已修** | `AboutUpdateHost.kt:197-206 cancelDownload()`：先 `DownloadManager.remove(id)` 再停轮询；`onCancelDownload = { cancelDownload() }`（`:354`） |
| P1-3 | 应用内下载丢 sha256、不装包 | **部分已修** | 已做：`finishDownload()`（`AboutUpdateHost.kt:153-196`，suspend + IO 线程算摘要）下载完成后自算 SHA-256，`MISMATCH`/`UNVERIFIABLE` 都 `remove(id)` 并拒绝安装；`MATCH`/未声明才用系统下载器的 content Uri 拉起安装器。**仍缺**：Dart 的应用内进度条 UI 与 `fallbackUrl` 换源重试（Dart `about_screen.dart:1509-1530`），已在 KDoc 与本节登记 |
| P1-4 | 应用日志写入点只剩 1 处 | **部分已修** | 新增 `appendLog`（`AboutUpdateHost.kt:100-111` + 门控缓存在 `:82-93`）+ 5 个落盘点（检查失败 / 入队失败 / 下载失败 / 摘要不符 / 无法算摘要 / 安装器拉起失败），门控读 `recordingEnabledFromPrefs`（与 Dart 隐私口径一致）。全仓仍远少于 Dart 的 139 处引用 |
| P1-5 | `a.support` 鸣谢刷新死按钮 | **他人泳道在修（F09）** | 壳侧 `HEAD bf0e5a57:283-289` 仍 `onReload = {}`；按 Lead 分工不动 |
| P2-1 | 守卫 `= null` 只抓末尾 | **已修（Lead）** | `DiagnosticsWiringGuardTest.kt:198` 已加 `RegexOption.MULTILINE` |
| P2-2 | 守卫认注释里的宿主名 | **已修（Lead）** | `DiagnosticsWiringGuardTest.kt:54-60` 走 `codeOf(blocks[id])` 去注释后再判 |
| P2-3 | 守卫只扫一个文件 + MANaged 覆盖窄 | **部分已修（Lead + 待 F06/F09）** | `MANAGED` 值已改 `Map<String, List<String>>`（`:176`）；仍只覆盖诊断 5 id，`b.liveSelfCheck`/`a.support`/`a.contributors` 等 F06/F09 落地后再加（见 §6.4） |
| P2-4 | PerfReportHost/PerfProbe KDoc 说探针没接 | **已修** | `PerfReportHost.kt:54-62` 改写为「壳已挂载」；`platform/PerfProbe.kt:65-75` 改成「已接线，不要再重复加」并点明两处已落地位置 |
| P2-5 | AboutUpdateHost KDoc 说 manifest 没注册 FileProvider | **已修** | `AboutUpdateHost.kt:42-50`：改成「下载完成后本层自校验 + 用系统下载器的 content Uri 装包；FileProvider 是给日志/ICS/传输包用的，与本页无关」 |
| P2-6 | 日志复制/导出假成功 | **已修** | `DiagnosticsLogHost.kt:275-322`：复制只有真写进剪贴板才 toast，导出按 `shareLogText` 返回值判断，失败走 `Log.w(LOG_TAG, …)`（不再骗人）。缺专用失败文案 → §6.5 ARB 请求 |
| P2-7 | 内存页 3 条中文硬编码 | **不修（有理由）** | `MemoryStatsPage.kt:641/727/728` 与 Dart `memory_stats_screen.dart:910/1049-1050` **逐字同源**；修它要新增 ARB 键（本轮禁改 ARB），且 i18n 棘轮已把该文件冻结在 3 条 |
| P2-8 | 整族文案只有 zh | **不修（系统性）** | `DiagnosticsStrings.kt:14-25` 的 `ArbText` 只有 `zh` 字段，是**全仓 Compose 迁移**的统一现状（37 个 `*Strings.kt` 同款），单族改会造出两套口径 |
| P2-9 | LIVE / warehouseImport 配置 0 引用 | **部分已修** | LIVE 源现在有真落点路径（`AboutUpdateHost` 的页内兜底用的是 MERGED；LIVE 仍主要在 F06 的 host 里接）；`WAREHOUSE_IMPORT` 仍无数据源（Dart 侧是内存态会话日志，见第一轮 N2） |
| P2-10 | 新守卫无 red→green 留痕 | **未修（无法在本轮做）** | 只读+L0 禁止约束下我做不了「改坏→红→还原」；Lead 已在二轮加固守卫本身，建议由其跑一次反向验证并把输出贴进 `.agents/compose-phase3/claims/` |
| P2-11 | 关于族审计文档的 L1 命令不可执行 | **未修（文件不属我）** | `docs/plans/2026-10-28-about-family-audit.md` 在 `git status` 里是 `??`（他人未提交文件），按纪律不改。替换行见 §6.6 |

### 6.2 本轮改了哪些文件（全部在授权写作用域内）

| 文件 | 改了什么 |
|---|---|
| `composeP1/…/pages/about/AboutUpdateHost.kt` | ①新增 `onOpenPage` 出口 + 页内 `DiagnosticsLogHost` 兜底（P0-1）；②`startDownload(url, expectedApkSha256)` + `finishDownload` 真校验真装包（P1-3）；③`cancelDownload()` 真 `remove`（P1-2）；④`onMirrorPrefixSubmit` 归一化写盘（P1-1）；⑤`appendLog` 5 处落盘 + 隐私门控（P1-4）；⑥KDoc 更正（P2-5） |
| `composeP1/…/pages/about/AdvancedOptionsPage.kt` | 镜像地址编辑改成真弹窗（`OverlayDialog` + `TextField` + 校验 + 取消/确认），`onEditMirrorUrl` → `onMirrorPrefixSubmit`（P1-1） |
| `main/…/pages/about/ApkDigest.kt`（新） | 纯 JVM 摘要判据：`normalizeExpectedSha256` / `apkDigestVerdict` / `sha256Hex`（bytes & stream）（P1-3 的可测内核） |
| `main/…/pages/about/AboutUpdatePageStrings.kt` | 移植 5 条**已有** ARB 键（`cancelAction` / `confirmAction` / `serviceMsgUpdateDownloadHashMismatch` / `…Sha256UnverifiedRefused` / `…OpenInstallerFailed`），未新增任何 ARB |
| `composeP1/…/app/DiagnosticsLogHost.kt` | 复制/导出不再假成功（P2-6），新增 `LOG_TAG` |
| `composeP1/…/app/PerfReportHost.kt` | KDoc 更正（P2-4） |
| `main/…/platform/PerfProbe.kt` | KDoc 更正（P2-4） |
| `test/…/pages/about/ApkDigestTest.kt`（新） | 7 例：标准向量、流/数组一致、归一化、四种 verdict（含「声明了却算不出要拒装」） |
| `test/…/pages/about/AboutUpdatePageStringsArbTest.kt` | 对拍表补 5 条新移植的键（ARB 逐字） |
| 本报告 | 本节与 §6.3~§6.6 |

**没碰**：`ShellPageIndex.kt` / `ShellWiring.kt` / `ShellPageCatalog.kt` / 壳 Activity / `build.gradle` / `AndroidManifest.xml` / `theme/` / `settings/**` / `course/**` / `guide/**` / 任何 ARB。

### 6.3 壳接线请求（Lead 专属文件，我不改）

**请求 1（P0-1 收口，可选但推荐）**：给更新页一个真路由出口，这样「打开日志页」与其它入口走同一套壳内推页（返回键、日志页复用都更一致）。页内兜底已能工作，所以这条不是阻塞项。

```kotlin
// ShellPageIndex.kt：找不到约 291 行的 "a.update" 分支（当前为 AboutUpdateHostPage(onBack = onBack)）
        "a.update" -> AboutUpdateHostPage(
            onBack = onBack,
            onOpenPage = onOpenPage,
        )
```

**请求 2（P0-2 / F06）**：`b.liveSelfCheck` 接真宿主后就地替换。**注意顺序**：先落地宿主与分派，再往 `MANAGED` 加行，否则守卫会红。

```kotlin
// ShellPageIndex.kt:425
        "b.liveSelfCheck" -> LiveSelfCheckHost(onBack = onBack, onNavigate = onOpenPage)
```

**请求 3（P2-11 文档）**：`docs/plans/2026-10-28-about-family-audit.md:156` 的旧命令今天没有对应任务（`android/app/build.gradle:7` 已写明 composeUi flavor 删除），改为：

```markdown
- **L1** `pwsh scripts/safe-gradle.ps1 :app:compileDevDebugKotlin` → **BUILD SUCCESSFUL**（壳+全部 composeP1 渲染层编译通过）
```

### 6.4 守卫 MANAGED：本轮没扩，原因是顺序与分工

- 我没接任何**新页面 id**：P0-1 只是给已有 `a.update` 分支加出口参数并做页内兜底，`a.update` 原本就不在 `MANAGED` 里（它一直是真宿主 `AboutUpdateHostPage`，加不加是覆盖策略问题，不是事故风险点）。
- `b.liveSelfCheck`（F06）、`a.support` / `a.contributors`（F09）都归他人泳道。**现在往 `MANAGED` 加这三行会立刻把 L0 打红**（三分支今天仍命中 FORBIDDEN），所以必须等对应批次把分支换成真宿主后**同一提交**再加。
- 落地时按 Lead 加固后的**列表写法**加（`Map<String, List<String>>`）：

```kotlin
            // F06 落地后加（LiveSelfCheckHost 必须同时钉住「Live 日志入口」这个回调）
            "b.liveSelfCheck" to listOf("LiveSelfCheckHost", "DiagnosticsLogHost"),
            // F09 落地后加（工作区里 F09 已新建 SupportCreatorHost.kt / ContributorsHost.kt，
            // 未提交；等它的壳分支接线一并落地再加这三行）
            "a.support" to listOf("SupportCreatorHost"),
            "a.contributors" to listOf("ContributorsHost"),
```

### 6.5 ARB 新增请求（本轮按纪律没动 ARB，只登记）

| 建议键 | 中文（建议值） | 用在哪 | 现状（临时处置） |
|---|---|---|---|
| `appLogsCopyFailed` | 复制失败，剪贴板不可用 | `DiagnosticsLogHost.copyLogs` 失败分支 | 只 `Log.w`，**不**假报成功 |
| `appLogsExportFailed` | 没能打开分享面板，请稍后重试 | `DiagnosticsLogHost.exportLogs` 失败分支 | 只 `Log.w` |
| `aboutDownloadCancelled` | 已取消下载 | `AboutUpdateHost.cancelDownload` 成功取消后 | 静默取消（Dart 有此提示，`about_screen.dart:1552` 附近 `aboutDownloadCancelled`） |

> 另：`serviceMsgUpdateDownloadHashMismatch` / `serviceMsgUpdateSha256UnverifiedRefused` /
> `serviceMsgUpdateOpenInstallerFailed` 三条 ARB 键**已存在**（`app_zh.arb:4920/4921/4931`），
> Kotlin 侧只是还没有 service message 表，所以按原键名抄进 `AboutUpdatePageStrings`。
> 建议后续移植 `ServiceMessageStrings` 时把这三条迁出去，别留两份。

### 6.6 未修原因（逐条，不含糊）

1. **P0-2 / P1-5（F06 / F09）**：按 Lead 二轮分工归他人泳道；我不碰 `settings/**` 与那两条壳分支，避免双写冲突。根因证据保留在第一轮 §P0-2 与 §P1-5。
2. **P1-3 剩余部分**（应用内进度条 UI / `fallbackUrl` 换源重试）：需要一套应用内 HTTP 下载控制器（Dart `AppUpdateDownloadController`，含断点、取消、换源），属于「新增能力层」而不是修一个回调；本轮先保证**安全判据**（sha256 校验 + 拒绝装包）不再缺失。
3. **P1-4 剩余部分**：把 Kotlin 全仓关键路径都接日志是跨域工作（导入/通知/崩溃/同步各域各接一处），单族做不完。
4. **P2-7 / P2-8**：见 6.1 表内理由（Dart 同源硬编码 / 全仓统一现状 + 禁改 ARB）。
5. **P2-9 的 warehouseImport 源**：Kotlin 侧没有该会话日志的实现，属「功能未移植」，不是接线问题。
6. **P2-10**：需要跑测试才能证明，本轮硬约束禁止（Lead 统一跑）。
7. **P2-11**：目标文件是他人未提交（`??`），按纪律不改，替换行已给。

### 6.7 本轮验证到什么程度（不许误读）

- **没有跑 Gradle / L0**（硬约束）。所以「编译通过」「单测绿」这两句**本轮一句都不能说**。
- 我能给的证据是：改后的文件逐个重新读过、括号配平脚本通过（5 个改动文件 braces/parens 均为 0 差值）、
  用到的每个 API 都在同仓找到既有用法（`OverlayDialog`/`TextField`/`useLabelAsPlaceholder`/`colorScheme.error`/
  `recordingEnabledFromPrefs`/`AppLogStore.append` 各自的先例位置已在改动 KDoc 里标注）。
- 新测试 `ApkDigestTest`（7 例）与 `AboutUpdatePageStringsArbTest` 的 5 条新增对拍**尚未执行**，
  需 Lead 的 L0 跑绿才算数；`ApkDigestTest` 的期望值是公开 SHA-256 向量与 Dart 错误码语义推出来的，
  不是从实现里抄的（反向验证方式：把 `apkDigestVerdict` 的 `UNVERIFIABLE` 分支改成 `NOT_DECLARED`，
  第 7 例必须红）。

## 我没能验的

1. **真机（L4）**：五个诊断页 + 关于/更新页在 `dev` 包里的实际观感、滚动、分享面板行为——铁律禁止 agent 操作设备，全部未验。任何「能跑 / 能装上」的结论都不成立。
2. **L0 / L1 / L2 一律没跑**（任务硬约束）。因此：`DiagnosticsStringsParityTest`、`DiagnosticsWiringGuardTest`、`AppUpdateModelTest` 等**实际是否绿，我没有执行证据**；我只做了「判据复刻 + 源码核对」。
3. **守卫的咬合探针**（改坏→红→还原）需要写文件，只读约束下做不了 ⇒ 新守卫「有牙齿」这一点**未验**。
4. **样式 lint 不覆盖宿主文件**：`scripts/compose-style-lint.ps1` 只扫 `composeP1/pages/<域>/*.kt`，`composeP1/app/{DiagnosticsLogHost,DiagnosticsSettingsHost,MemoryStatsHost,PerfReportHost,LiveTestingFixtureHost,AboutUpdateHost}.kt` 都不在扫描面内 ⇒ 这 6 个文件的 R1..R6 合规性**未验**（我人工看了 `DiagnosticsLogHost` 用的是 `LiveDiagnosticsLogPage`，未逐个核对全部宿主）。
5. **`h.fixture`（临时测试夹具）只审到分派与宿主入参**，页面内 24 时段安装 / 只删 `live_test_` / 触发某节三个动作没逐条追到 Dart。
6. **`LIVE` 源日志页**（`DiagnosticsLogHost(source = LIVE)`）没有任何壳入口 ⇒ 该分支（空态即 pop、`popsOnEmpty`、`supportsClear=false`）**运行时未验**。
7. **`b.liveSelfCheck` 的 P0 判定依据**：我核到「空 state + 只放行 NAVIGATE」，但**没有逐条核对** `SettingsLiveSelfCheckPage` 14 个区块里哪几行是纯展示、哪几行带动作，所以「整页全死」的精确范围只到「三个日志按钮 + 开关类动作」。该页属实时活动族，建议该族审核员复核。
8. **更新页下载链路**：`DownloadManager` 在真实设备上的落盘路径、通知点击行为、`setDestinationInExternalPublicDir` 在 scoped storage 下是否需要额外权限，**无法静态判定**。
9. **`a.support` / `a.contributors` 的其它缺口**（二维码是否真图、保存到相册、名单数据源）只抽样，未逐项对 Dart。

## 审核方法（跑了哪些命令、扫了哪些文件、多少行）

**基线处理**：审核开始时 `git status --porcelain` 里我域内只有 `ShellPageIndex.kt` 是 `M`；它在审核过程中被另一会话连续修改（md5 `dd02328b` → `72505904`），所以**判据一律取 `git show HEAD:… › /tmp/audit-diag/ShellPageIndex.HEAD.kt`**，并用脚本证明「HEAD 与工作区的五支受管分支逐字相同」：

```
$ python .agents/tmp/audit-branchcmp.py /tmp/audit-diag/ShellPageIndex.HEAD.kt android/…/ShellPageIndex.kt
SAME  b.diagnostics  ea023ee37b86
SAME  h.log          e4e639e9c8d0
SAME  h.memory       2160deb5fc64
SAME  h.perfReport   a661c8433da2
SAME  h.fixture     21d0dc9fe96d
branches_total head=87 wt=87 ; managed same=5 diff=0
```

**读过的文件（行数为 HEAD 版）**

| 文件 | 行数 |
|---|---|
| `pages/ShellPageIndex.kt`（HEAD） | 1513 |
| `pages/shell/DiagnosticsWiringGuardTest.kt` | 189 |
| `pages/shell/ShellPageCatalog.kt` | 360 |
| `pages/ShellWiring.kt`（路由段 690-745） | — |
| `composeP1/app/{DiagnosticsLogHost,DiagnosticsSettingsHost,MemoryStatsHost,PerfReportHost}.kt` | 446 / 169 / 178 / 142 |
| `pages/diagnostics/{DiagnosticsStrings,AppLogFile,AppLogStore,…}.kt` | 175 / 252 / 229 |
| `composeP1/pages/about/{AboutUpdateHost,AboutUpdatePage,AdvancedOptionsPage,ReleaseNotesMarkdownView,AboutStaticPage}.kt` | 295 / 635 / 331 / 115 / 476 |
| `pages/about/{AppUpdateSettings,ReleaseNotesDigest,…}` | 抽样 |
| Dart 对照：`lib/screens/about_screen.dart`(2727)、`live_diagnostics_log_viewer_screen.dart`、`log_viewer_entry.dart`、`memory_stats_screen.dart`、`perf_probe.dart`、`settings/settings_live.dart`、`settings/settings_diagnostics.dart`、`lib/l10n/app_zh.arb` | — |
| 既有文档：`docs/plans/2026-10-29-diagnostics-family-audit.md`(191)、`docs/plans/2026-10-28-about-family-audit.md`(166)、`.agents/compose-phase3/claims/_DIAG-*.md` | — |

**关键命令与真实输出**

1. 分支清点（防「同一 id 写两遍只取第一段」的绕过）：
```
$ grep -cE '^[ \t]*"[A-Za-z0-9._-]+"[ \t]*->' HEAD-ShellPageIndex.kt   → 87
$ grep -cE 'page\("P3-' ShellPageCatalog.kt                            → 87
$ … | sort | uniq -d                                                    → （无输出，无重复 id）
```
2. 守卫判据复刻（4 条全绿）→ `guard#1 True` / `host_present=True ×5` / `forbidden hits:` 空 / `blocks>=70 True empty_blocks: []`。
3. 未受管分支的同 pattern 扫描 → `a.support`=空回调、`a.contributors`=空回调+空列表、`b.liveSelfCheck`=空构造 state。
4. HEAD vs 工作区五支逐字比对 → `managed same=5 diff=0`。
5. ARB 逐字对拍（`ArbText(key,value)` vs `lib/l10n/app_zh.arb`）→ `total=51 ok=51 missing=0 diff=0`。
6. 渲染层中文字面量扫描（排除纯注释行）→ 只有 `MemoryStatsPage.kt` 3 条（= 基线登记值）、其余为 `·`/`→`/`•` 纯符号。
7. 样式 lint：`pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain diagnostics` → `0`；`-Domain about` → `0`；两个基线文件只有注释行。
8. 日志链路 grep：`AppLogStore.append` 调用点 = 1（`DiagnosticsSettingsHost.kt:119`）；Dart `AppLogService` 引用 = 139。
9. FileProvider 落地：`AndroidManifest.xml:143-151` + `res/xml/file_paths.xml` 的 `<cache-path name="log_share" path="log-share/">` 与 `DiagnosticsLogHost.kt:382 LOG_SHARE_DIR_NAME = "log-share"` **逐字一致**。
10. 探针挂载：`grep -rn "PerfProbe" android/app/src` → `PagesShellActivity.kt:125`、`ShellPageIndex.kt:258`、`PerfReportHost.kt:69-71`。

> 第一轮只读：本报告当时是唯一写过的文件；`.agents/tmp/audit-*.py` 是我为复核临时落的自用脚本（`.agents/` 已 gitignore，未入任何提交），可随时删。
> 第二轮（修复）改动的产品文件见 §6.2；**未提交**（提交由 Lead 统一做，`git status` 里还能看到）。
