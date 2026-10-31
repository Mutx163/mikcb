# 同步备份/情侣/数据迁移/统计 · 近期重构独立审核（2026-10-30）

审核员：`review-sync-statistics`（独立对抗复核，只读产品代码）
审核时间：2026-10-30 11:10 ~ 11:50（Asia/Shanghai）
真相源：`lib/`（Dart）＋ 工作区 Kotlin 源码；实施者自述文档一律不作为证据。

---

## 一、结论（先看这段）

**已提交的 HEAD（`d6c925ba`，2026-10-30 11:04）处于「编译不过 + 备份导入丢数据」的双重破损状态；修复代码全部在在途未提交的工作区里。**

| # | 结论 | 级别 |
|---|---|---|
| 1 | HEAD 的统计页分享接线 `StatisticsShareText.build(feedState)` 类型不匹配，**整个 `:app` 编译不过**；提交信息却声称「L1 `:app:compileDevDebugKotlin` 通过」。修法（`feedState.home`）只在在途工作区。 | **P0** |
| 2 | HEAD 的备份导入仍只写回档案/课表/设置/当前周，**作业、考试、日程条目、时间模板、日程规则五类全丢**；声称的「7 例往返测试」文件在在途且未提交（untracked），HEAD 上一条都没有。 | **P0** |
| 3 | `locationTimeGroups`（地点作息分组）在导出与导入两侧**被静默丢弃**，且代码注释已过期（谎称 snapshot 没有该字段）。Dart 的 `TransferPackage`/`FullAppDataBackup` 都带这个字段。 | **P0** |
| 4 | 云备份「恢复」流程与 Dart 严重不一致：无差异预览、无合并/覆盖选择、无「设为当前版本」确认、强制远端为准、**成功提示丢弃 Dart 的「撤销」动作**，且用系统 `Toast` 而非应用内胶囊。 | P1 |
| 5 | 跨设备导入时 `scheduleDateRules.timeSchemeId` **未按新模板 id 改写** → 规则引用悬空（Dart 有 `_remapScheduleDateRules`）。 | P1 |
| 6 | `QrTransferSendHost(title:)` 参数已加、壳却没传 `transferBridge.outboundTitle` → 两种发送范围标题一模一样，参数是死代码。 | P1 |
| 7 | 壳里硬编码中文「连接测试失败」「Compose 壳」，未走 `SyncStrings`/ARB（D3 违规）；CJK 门禁只扫 `composeP1/`，扫不到 `main/` 的壳。 | P1 |
| 8 | 统计深度分析页 `e.analysis` 的排行行在 HEAD 上可点但**默认空 lambda 无反应**，且该路由**不在** `DiagnosticsWiringGuardTest` 的受管清单里，无任何守卫。 | P1 |

**P0 条数：3。**（判据口径见 §六）

**判据总评**

| 判据 | 结论 |
|---|---|
| D1 接线真实性 | 通过（受管页面均有真宿主；`DiagnosticsWiringGuardTest` 已扩到 65 条并覆盖本域全部路由） |
| D2 功能复刻完整度 | **有缺陷**（恢复流程、地点分组、日程规则改写、全量合并） |
| D3 文案对拍 | **有缺陷**（壳层 2 处硬编码中文；`composeP1` 渲染层 0 处） |
| D4 分层 | 基本通过（2 个 public 辅助函数仅内部自用，属 P2） |
| D5 样式（机械） | 通过（sync/transfer/statistics 三域基线 0 条、新增 0 条） |
| D6 测试牙齿 | **有缺陷**（往返测试停在 `planWrites`，未覆盖宿主→仓储那一跳；且未提交） |

---

## 二、审核对象与在途标注

工作区正被另一会话实时修改。以下区分：

- **已提交**：`git show HEAD:<路径>` 取快照（HEAD = `d6c925ba`）。
- **在途，非已提交交付**：工作区有改动但 `git status` 显示 `M`，或文件 `??` 未跟踪。

本次涉及的关键在途件：

| 文件 | 状态 |
|---|---|
| `android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt` | **M（在途）** |
| `android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt` | **M（在途）** |
| `android/app/src/main/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferApplyLogic.kt` | **M（在途）** |
| `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferHost.kt` | **M（在途）** |
| `android/app/src/main/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferModel.kt` | **M（在途）** |
| `android/app/src/main/kotlin/com/mutx163/qingyu/pages/transfer/TransferPreviewModel.kt` | **D（在途删除）** |
| `android/app/src/test/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferRoundTripTest.kt` | **?? 未跟踪（在途）** |
| `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/AppToastCapsule.kt` | **?? 未跟踪（在途）** |
| `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/CourseStatisticsPage.kt` | **M（在途）** |
| `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsAnalysisPage.kt` | **M（在途）** |
| `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CoupleTimetableSettingsHost.kt` | **M（在途）** |
| `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferHosts.kt` / `QrTransferSendPage.kt` / `QrCameraHost.kt` | **M（在途）** |
| `android/app/src/main/kotlin/com/mutx163/qingyu/platform/CoupleTransferAdapter.kt` | **M（在途）** |

---

## 三、判据逐条

### D1 接线真实性 —— **通过**

**命令**

```powershell
grep -nE '= \{\}|\{\s*\}|= null|emptyList\(\)|SettingsPageState\(\)' android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt
```

**输出（关键行）**

```
241:private val LocalShellOpenPage = staticCompositionLocalOf<(String) -> Unit> { {} }
273:    onOpenPage: (String) -> Unit = {},
...
438:            spec = SettingsLivePage.spec(SettingsPageState()),
444:        "b.liveSelfCheck" -> SettingsScreen(SettingsLiveSelfCheckPage.spec(SettingsPageState()), onBack)
```

命中的空壳全部落在**非本域**路由（`b.live*`、`b.glassDockIcon` 属 F06 在途；`g2.webLogin` 属 F08 在途）。**本域（`e.*` / `f.*` / `g3.*`）分支内 0 处空 lambda / 空列表 / 空 state。**

本域壳分支逐条核对（工作区 `ShellPageIndex.kt`）：

| 路由 | 分支体 | 证据 |
|---|---|---|
| `e.statistics` | `CourseStatisticsPage(viewState = feedState.home, onOpenShare = {...shareStatisticsText...}, ...)` | `ShellPageIndex.kt:1145-1176` |
| `e.statisticsSettings` | `StatisticsSettingsPage(viewState = StatisticsSettingsLogic.buildViewState(...), onWeeklyReportToggle = {...})` | `:1177-1223` |
| `e.analysis` | `StatisticsAnalysisPage(viewState = StatisticsAnalysisModel.viewState(...), onOpenCourse = {...})` | `:1224-1255` |
| `e.session` | `StatisticsSessionPage(viewState = feedState.session, onSelectCourse = {...})` | `:1256-1279` |
| `f.cloudSync` | `CloudSyncPage(controller, onOpenBackup = { entryId -> openBackupId = entryId })` + `CloudBackupDetailHost(...)` | `:1281-1331` |
| `f.backupList` | `CloudBackupListPage(controller, onOpenBackup = {...})` + `CloudBackupDetailHost(...)` | `:1333-1363` |
| `f.couple` | `CoupleTimetableSettingsHost(wiring = wiring, onBack = onBack)` | `:1365-1367` |
| `g3.dataTransfer` | `DataTransferHost(repository = wiring.timetable, bridge = transferBridge, ...)` | `:1444-1451` |
| `g3.qrSend` | `QrTransferSendHost(session = ..., onBack, onStop)` | `:1477-1490` |
| `g3.qrScan` | `QrTransferScanHost(onBack, onImportFullBackup = { raw -> transferBridge.inboundBytes = raw; onBack() })` | `:1491-1500` |
| `g3.icsExport` | `IcsExportHost(wiring = wiring, onBack = onBack)` | `:1501` |
| `g3.lanEdit` | `LanEditHost(wiring = wiring, onBack = onBack)` | `:1508` |
| `g3.pickupCodes` | `PickupCodesHost(onBack = onBack, hapticsEnabled = wiring.enableHaptics)` | `:1509-1512` |

**机器守卫**：`DiagnosticsWiringGuardTest`（`android/app/src/test/kotlin/com/mutx163/qingyu/pages/shell/DiagnosticsWiringGuardTest.kt:188-283`）的 `MANAGED` 已纳入 `e.statistics` / `e.statisticsSettings` / `e.session` / `f.cloudSync` / `f.backupList` / `f.couple` / `g3.dataTransfer` / `g3.qrSend` / `g3.qrScan` / `g3.icsExport` / `g3.lanEdit` / `g3.pickupCodes`，并有 `FORBIDDEN`（`= {}`、`emptyList()`、`snapshot = null`、`SettingsPageState()`）判据。**`e.analysis` 未纳入**（见 P1-8）。

> 注：`e.analysis` 分支体里含 `wiring.pendingAddCourseSeed = null` 等一次性意图清空，被 `FORBIDDEN` 的「末尾 null」判据误伤，故未纳入——这是守卫判据过粗导致的覆盖缺口，不是接线缺口。

### D2 功能复刻完整度 —— **有缺陷**

逐项对 Dart（`lib/`）复核，发现 4 处实质偏差，详见 §五 P0-3 / P1-1 / P1-2 / P1-5。

**已核对一致的部分**

- 数据备份页三档导出（当前课表 / 全部数据 / 时间模板）→ `TransferScope`，按钮文案取 `TransferStrings`（`DataTransferPage.kt:121-135`）。
- 导入预览弹窗正文格式（`selectImportModeMessage` + `channel=/scope=/transferId=` + 差异行）与 Dart `transfer_preview_dialog.dart:19-35` 逐字一致（`DataTransferImportLogic.previewMessage`，`DataTransferImportLogic.kt:239-259`）。
- 预览弹窗三动作顺序与结果（取消 / 合并更改 / 覆盖当前课表）与 Dart 一致（`DataTransferModelTest.kt:298-308`）。
- 情侣课表九个动作（连接 / 拉取 / 上传 / 断开 / 导出 / 导入 / 解绑 / ±周偏移 / 换色）全部有落点（`CoupleTimetableSettingsHost.kt:174-207`），阻塞网络调用均在 `Dispatchers.IO`（`:183-207`、`:235-256`）。
- 取件码 7 个入口走真 `Intent` 多级回退（`PickupCodesHost.kt:74-106`）；局域网编辑走真 HTTP 服务 + 前台服务 + 剪贴板（`LanEditHost.kt:136-183`）。

### D3 文案对拍 —— **有缺陷（壳层 2 处）**

**机械对拍（我写的只读脚本，非仓库工具）**

```
扫描 android/app/src/{main,composeP1}/kotlin/com/mutx163/qingyu/pages/{transfer,sync,statistics}/**/*.kt
正则 (ArbText|ChartText)\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)
对照 lib/l10n/app_zh.arb
```

**输出**

```
total ArbText/ChartText entries: 565
OK: 565
MISSING in ARB: 0
VALUE MISMATCH: 0
```

→ `*Strings.kt` 层 565 条全部与 ARB 逐字一致。

**渲染层硬编码中文扫描**

```powershell
grep -rnP '[一-鿿]' android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/{sync,transfer,statistics} --include=*.kt | grep '"' | grep -vE 'Strings\.kt|ServiceMessages\.kt'
```

命中仅 4 处**符号**（`—`、`★`、`‹`、`›`），非中文文案，可接受。

**壳层（`main/kotlin`）命中 2 处用户可见硬编码** —— 见 §五 P1-4：

```
ShellPageIndex.kt:1300  deviceLabel = configStore.readDeviceLabel() ?: "Compose 壳"
ShellPageIndex.kt:1329  Toast.makeText(context, "连接测试失败", Toast.LENGTH_SHORT).show()
ShellPageIndex.kt:1352  deviceLabel = configStore.readDeviceLabel() ?: "Compose 壳"
```

`SyncStrings.cloudSyncTestFailed` 已存在（值 `WebDAV 连接失败，请检查账号、应用密码和网络`，`SyncStrings.kt:88`），ARB 键 `cloudSyncTestFailed` 也存在；`cloudBackupDefaultDeviceLabel` = `本机`（`SyncStrings.kt:116`）。壳没有走它们。

**门禁缺口**：`CjkLiteralGateTest` 只扫 `android/app/src/composeP1/kotlin`（`CjkLiteralGateTest.kt:88`），`main/kotlin` 的壳不在其射程内，所以这两处不会被机器抓住。

### D4 分层 —— **基本通过（2 处 P2）**

渲染/宿主层（`composeP1`）只调模型层（`main` 下 `*Model.kt` / `*Logic.kt` / `*Strings.kt`）：

- `CloudBackupDetailHost` → `CloudBackupListLogic.buildDetail` / `SyncResultToasts` ✅
- `DataTransferHost` → `DataTransferPackageLogic` / `DataTransferImportLogic` / `DataTransferApplyLogic` / `TransferServiceMessages` ✅
- `CoupleTimetableSettingsHost` → `CoupleTimetableSettingsController` / `CoupleStrings` ✅

**public 但渲染层 0 引用**（P2，仅内部自用，非缺陷但属冗余暴露）：

```
TransferApplyWrites       refs(outside def file)=0   # planWrites 的返回类型，宿主用推断类型
remapProfileSchemes       refs(outside def file)=0   # 仅 planWrites 内部调用
remapSettingsScheme       refs(outside def file)=0   # 仅 planWrites 内部调用
```

### D5 样式（机械）—— **通过**

```powershell
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain transfer
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain sync
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain statistics
```

**输出**

```
=== transfer ：0 处 ===  干净   合计：0 处
=== sync    ：0 处 ===  干净   合计：0 处
=== statistics：0 处 === 干净  合计：0 处
```

基线文件 `tool/compose_style_baseline/{transfer,sync,statistics}.txt` 均为空（仅注释头）。在途的 `QrCameraHost.kt` 写死灰 `Color(if (dark) 0xFFB0B0B8...)` 已改为 `QingyuTheme.secondaryText(dark)`（`QrCameraHost.kt:248-253`），未新增债。

### D6 测试牙齿 —— **有缺陷**

- 往返测试 `DataTransferRoundTripTest.kt` **7 例**（`@Test` 在 `:51/70/88/108/134/158/175`），但**边界画在 `planWrites`**，只断言「包里有的，计划里都有」；**没有**断言宿主 `applyImport` 真的把 `writes.tasks`/`writes.exams` 传给了仓储。文件头自述：「仓储进不了 JVM 单测，所以边界画在『要写什么』这一层」（`:36-38`）。
- 该文件 **未跟踪**（`git ls-files --error-unmatch` → `did not match any file(s) known to git`），即 HEAD 上**一条往返测试都没有**。
- 反向验证（咬合探针）在测试头注释里**声明**做了（`:40-43`），但我**未能运行**（禁令），只能读文本，标「未验」。
- `TimetableRepositoryTest.replaceActiveProfileContentWritesAllThreeBlocksWithOneNotification`（`:451-467`）覆盖了仓储侧写 tasks/exams，但**没有**覆盖 `scheduleItems` setter + `persistActiveProfileState()` 这条路径（全仓 grep `scheduleItems` 在该测试文件 0 命中）。
- `DiagnosticsWiringGuardTest` 未覆盖 `e.analysis`（见 P1-8）；`g3.qrSend` 只钉 `transferBridge.outboundPayload`，**没钉 `outboundTitle`**（见 P1-6）。

---

## 四、既有声明逐条复核

### 声明 1：全量备份导入丢数据，声称已修（新增 7 例往返测试）

**结论：在途已修，**已提交 HEAD 未修**。**

**HEAD 侧证据**（`git show HEAD:android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferHost.kt`）

```
423:            tasks = repository.tasks,
424:            exams = repository.exams,
...
438:            repository.replaceActiveProfileContent(
440:                tasks = repository.tasks,
441:                exams = repository.exams,
```

HEAD 的 `applyImport` 把**本机旧值** `repository.tasks` / `repository.exams` 写回去，等于把包里的作业与考试静默丢掉；且**完全没有** `scheduleItems` / `timeSchemes` / `scheduleDateRules` 的写入。HEAD 的 `DataTransferApplyLogic.kt` 里**没有** `planWrites`（`git show HEAD:... | grep planWrites` → 空）。

**在途侧证据**（工作区）

`DataTransferApplyLogic.kt:110-161` 新增 `planWrites`，单课表包分支：

```kotlin
tasks = if (mode == TransferApplyMode.MERGE) {
    mergeById(current.tasks, plan.tasks, CourseTask::id)
} else {
    plan.tasks
},
exams = if (mode == TransferApplyMode.MERGE) {
    mergeById(current.exams, plan.exams, Exam::id)
} else {
    plan.exams
},
scheduleItems = plan.scheduleItems,
settings = plan.settings?.let { remapSettingsScheme(it, schemeIdMap) },
currentWeek = plan.currentWeek,
timeSchemes = plan.timeSchemes,
scheduleDateRules = rules,
```

`DataTransferHost.kt:444-475` 宿主照单写盘（`replaceActiveProfileContent(courses, tasks, exams)` + `scheduleItems` + `updateSettings` + `setCurrentWeek` + `persistActiveProfileState` + `updateScheduleDateRules`）。**逻辑本身看起来对**，但：

1. 全部是**在途未提交**；
2. 7 例往返测试**未跟踪**；
3. 仍漏 `locationTimeGroups`（P0-3）与 `scheduleDateRules` 改写（P1-2）。

### 声明 2：统计主页分享图标可见可点但没反应，声称已修（F12）

**结论：修法在在途，但已提交 HEAD 是编译错误（比「没反应」更糟）。**

**HEAD 证据**（`git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt`）

```
1088:            val feedState = remember(snapshot, semesterView, selectedWeek) {
1089:                StatisticsFeed.feed(
...
1096:            CourseStatisticsPage(
1097:                viewState = feedState.home,
...
1103:                        text = StatisticsShareText.build(feedState),
```

`feedState` 的类型是 `StatisticsFeedState`（`StatisticsFeed.kt:309`），而 `StatisticsShareText.build` 的签名是 `fun build(viewState: CourseStatisticsViewState): String`（`StatisticsShareText.kt:46`）。`StatisticsFeedState` 不是 `CourseStatisticsViewState` 的子类型，Kotlin 无隐式转换 → **类型不匹配，编译失败**。`StatisticsShareText.kt` 只有这一个 `build` 重载（`grep -n "fun build"` → 仅 `:46`）。

提交信息却写着「L1 `:app:compileDevDebugKotlin` 通过」（`git log -1 --format='%B' d6c925ba`）。**自述与源码矛盾。**

**在途证据**（工作区 `ShellPageIndex.kt:1169-1172`）

```kotlin
// `StatisticsShareText.build` 要的是页面视图状态（`CourseStatisticsViewState`），
// 而 `feedState` 是 feed 整体（含 home/analysis/session 三份）——
// 统计主页那份是 `feedState.home`（与本分支 `viewState = feedState.home` 同源）。
text = StatisticsShareText.build(feedState.home),
```

`CourseStatisticsPage.onOpenShare` 也在在途改成 `onOpenShare: (() -> Unit)? = null`，且 `if (onOpenShare != null)` 才画图标（`CourseStatisticsPage.kt:111-118, 138-149`）。**在途版本正确。**

### 声明 3：备份详情假入口，声称已修（F12）

**结论：通过（已提交 HEAD 已修）。**

- `CloudBackupDetailHost.kt` / `CloudBackupDetailSheet.kt` 已提交（`git ls-files --error-unmatch` → TRACKED）。
- 壳 `f.cloudSync` / `f.backupList` 分支改为 `onOpenBackup = { entryId -> openBackupId = entryId }` + `CloudBackupDetailHost(...)`（HEAD `ShellPageIndex.kt`，见 §三 D1 表）。
- 模型层 `CloudSyncController.backupEntry / deleteBackup / lastErrorCode`（`CloudSyncController.kt:296, 308, 116`）与 `CloudBackupListLogic.buildDetail / deleteConfirmMessage`（`CloudBackupListModel.kt:186-217`）真实。
- 守卫 `CloudBackupDetailWiringTest` 8 例（`:44-150`）钉住「按 entryId 取条目」「删除成功/失败/未连接」「lastErrorCode 是原始码」。

**但**恢复流程与 Dart 不一致（见 P1-1），且 `onRestore` 成功提示丢掉了 Dart 的「撤销」动作。

### 声明 4：情侣课表九个动作全部有落点、阻塞调用都在 IO 线程、失败如实报

**结论：通过。**

- 九动作 = `WEBDAV_CONNECT / WEBDAV_PULL / WEBDAV_UPLOAD / WEBDAV_DISCONNECT / COUPLE_EXPORT / COUPLE_IMPORT / COUPLE_UNLINK` + `onShiftWeekOffset` + `onPickColor`，全部在 `CoupleTimetableSettingsHost.kt:174-207` 有 `when` 分支。
- 阻塞网络调用：`pullNow` / `uploadMine` / `disconnect` / `unlink` / `importFromContent` / `testConnection` / `connect` 全部 `withContext(Dispatchers.IO)`（`:183-207`、`:235-256`）。
- 失败如实报：控制器每个动作返回 `SyncToast`（含 `isError`），壳 `notify(result.message)`；`shiftWeekOffset` / `pickColor` 落盘失败保持原值并回「保存失败」（`CoupleTimetableSettingsController.kt:383-423`）。
- 解绑有二次确认（`CoupleTimetableSettingsPage.kt:173-180, 279-293`）。

**小瑕疵（非 P0）**：`shiftWeekOffset` / `pickColor` 走 `PrefsKeyValueStore` 同步写盘，在主线程调用；`exportMine()` 也在主线程（注释自述「只组包 + 拉起分享面板，不跑网络」）。属可接受的权衡，不构成阻塞调用违规。

### 声明 5：取件码 / 局域网编辑两页从「空模型 + 空回调」接到真服务（F03）

**结论：通过（已提交 `7184712f`）。**

- `g3.lanEdit` → `LanEditHost`：真 `LanEditHttpServer` / `LanEditServiceRuntime` 单例 / 前台服务 / 剪贴板 / 「离开后保持开启」偏好（`LanEditHost.kt:73-183`）。
- `g3.pickupCodes` → `PickupCodesHost`：`LauncherPickupCodePlatform` + `PickupCodeRunner`，`Intent` 直达 → 拉起 App → 网页兜底，已安装探测（`PickupCodesHost.kt:49-150`）。
- 壳分支注释自述接线前是「新建的空模型 + 3 个空回调」「7 条入口 `onEntryClick` 也是空的」（`ShellPageIndex.kt:1500-1507`），现已接真。

---

## 五、缺陷清单

### P0（3 条）

#### P0-1 已提交 HEAD 编译不过：统计分享接线类型错配

- **文件:行号**：`android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt:1103`（HEAD）；修法在工作区 `:1172`
- **原文**（HEAD）
  ```kotlin
  1096:            CourseStatisticsPage(
  1097:                viewState = feedState.home,
  ...
  1103:                        text = StatisticsShareText.build(feedState),
  ```
- **类型链**：`feedState: StatisticsFeedState`（`StatisticsFeed.kt:309`）→ `build(viewState: CourseStatisticsViewState)`（`StatisticsShareText.kt:46`）→ 不匹配。
- **命令与输出**
  ```powershell
  git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt | grep -n "StatisticsShareText.build"
  # 1103:                        text = StatisticsShareText.build(feedState),
  git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsShareText.kt | grep -n "fun build"
  # 46:    fun build(viewState: CourseStatisticsViewState): String {
  ```
- **影响**：整个 `:app` 编译失败，APK 出不来；提交信息「L1 通过」为假。
- **状态**：修法（`feedState.home`）**在途未提交**。

#### P0-2 已提交 HEAD 的备份导入丢 5 类数据（声称已修，实际未提交）

- **文件:行号**：HEAD `DataTransferHost.kt:423-424, 438-441`
- **原文**
  ```kotlin
  423:            tasks = repository.tasks,
  424:            exams = repository.exams,
  ...
  438:            repository.replaceActiveProfileContent(
  440:                tasks = repository.tasks,
  441:                exams = repository.exams,
  ```
- **丢什么**：包里的 `tasks` / `exams`（被本机旧值顶掉）、`scheduleItems` / `timeSchemes` / `scheduleDateRules`（根本没写）。
- **命令与输出**
  ```powershell
  git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferApplyLogic.kt | grep -n planWrites
  # （空输出 → HEAD 没有 planWrites）
  git ls-files --error-unmatch android/app/src/test/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferRoundTripTest.kt
  # error: pathspec ... did not match any file(s) known to git
  ```
- **影响**：用户「全部数据备份」→ 换机/换档案恢复后，作业、考试、日程、时间模板、日程规则全没。
- **状态**：修法（`planWrites` + 7 例往返测试）**在途未提交**；且修法仍漏 P0-3 / P1-2。

#### P0-3 地点作息分组（locationTimeGroups）导出/导入全丢

- **文件:行号**：`DataTransferPackageLogic.kt:57-58, 274`；`TimetableRepository.kt:44-45`；`TransferImportPlan`（`DataTransferImportLogic.kt:86-98`）无该字段
- **原文**
  ```kotlin
  // DataTransferPackageLogic.kt:57-58
  3. **`locationTimeGroups` 恒为空**：[TimetableSnapshot] 没有位置-作息分组字段
     （Dart `provider.locationTimeGroups`），本批不臆造该数据；...
  // DataTransferPackageLogic.kt:274
  locationTimeGroupsJson = emptyList(),
  ```
  ```kotlin
  // TimetableRepository.kt:44-45
  /** 地点作息分组（顶层 key `location_time_groups`，不属于单个档案）。 */
  val locationTimeGroups: List<LocationTimeGroup> = emptyList(),
  ```
- **注释已过期**：`locationTimeGroups` 是 `9c2ec06a`（时间模板页复刻）加进 `TimetableSnapshot` 的，**晚于**传输批 `7c8d11b6`；该注释与「恒为空」的实现都没跟上。
- **Dart 侧有**：`lib/services/transfer_package.dart:198, 307, 411-412, 449`；`FullAppDataBackup.locationTimeGroups`（`data_transfer_service.dart:71`）。
- **命令与输出**
  ```powershell
  grep -rn "locationTimeGroups" android/app/src/main/kotlin/com/mutx163/qingyu/app/TimetableRepository.kt
  # 45:    val locationTimeGroups: List<LocationTimeGroup> = emptyList(),
  grep -n "locationTimeGroups" lib/services/transfer_package.dart
  # 198:  final List<LocationTimeGroup> locationTimeGroups;
  # 307:      'locationTimeGroups': locationTimeGroups
  ```
- **影响**：Kotlin→Kotlin、Dart→Kotlin 两条方向都丢；用户在「地点匹配作息」里建的分组恢复后消失。属「丢数据」。

### P1（6 条）

#### P1-1 云备份「恢复」流程与 Dart 严重不一致，且成功提示丢「撤销」动作

- **文件:行号**：`CloudBackupDetailHost.kt:77-92`；`SyncResultToasts.kt:120-127`
- **原文**
  ```kotlin
  // CloudBackupDetailHost.kt:77-79
  fun toast(toast: SyncToast) {
      Toast.makeText(context, toast.message, Toast.LENGTH_SHORT).show()
  }
  // CloudBackupDetailHost.kt:85-92
  onRestore = {
      busy = true
      scope.launch {
          val kind = withContext(Dispatchers.IO) { controller.openBackup(entryId) }
          busy = false
          toast(SyncResultToasts.forRestore(kind == SyncResultKind.DOWNLOADED, controller.lastErrorCode))
          onDismiss()
      }
  },
  ```
- **Dart 侧**（`lib/screens/cloud_backup_list_screen.dart:135-199`）：`previewBackupRestore` → `showTransferPreviewDialog`（选合并/覆盖）→ `showAppConfirmDialog`（`cloudBackupUploadAsCurrentTitle`）→ `applyPreviewedBackupRestore` → 成功时 `showAppToastWithAction(..., actionLabel: l10n.themeUndo, onAction: _undoCloudRestore)`。
- **偏差**：① 无差异预览；② 无合并/覆盖选择；③ 无「设为当前版本」确认；④ Kotlin `openBackup` 强制 `KEEP_REMOTE`（`CloudSyncController.kt:271`）；⑤ 成功提示用系统 `Toast`，**丢掉 `SyncResultToasts.forRestore` 给的 `actionLabel = themeUndo`**，用户无法撤销恢复；⑥ 错误样式 `isError` 也被丢掉。
- **影响**：与 Dart 原版可见不一致 + 少一个能力（撤销）。
- **状态**：已提交（HEAD 即如此）；KDoc 自述「没有 Dart 那套二次确认」（`CloudBackupDetailHost.kt:51-53`），属已知但未被标记为缺陷的偏差。

#### P1-2 跨设备导入时日程规则的模板引用未改写 → 悬空

- **文件:行号**：`DataTransferApplyLogic.kt:118, 131, 159`
- **原文**
  ```kotlin
  118:        val rules = plan.scheduleDateRules
  ...
  131:                scheduleDateRules = rules,
  ...
  159:            scheduleDateRules = rules,
  ```
- **对照**：`remapCourseSchemes` / `remapSettingsScheme` / `remapProfileSchemes` 都按 `schemeIdMap` 改写了引用，但 `ScheduleDateRule.timeSchemeId`（`TimeSchemeLogic.kt:54`）**没有**对应改写。Dart 有 `_remapScheduleDateRules(incoming.scheduleDateRules, timeSchemeIdMap)`（`unified_transfer_service.dart:717-720, 934-945`）。
- **影响**：跨设备导入（模板 id 在本机不存在 → `reconcileTimeSchemes` 新建了新 id）后，日程规则指向不存在的模板 id，规则静默失效。
- **测试缺口**：`DataTransferRoundTripTest` 的 `模板 id 在本机不存在时 引用按映射改写`（`:176-193`）只断言 `settings.activeTimeSchemeId` 与 `courses.timeSchemeIdOverride`，**没断言 `scheduleDateRules[*].timeSchemeId`**。

#### P1-3 `QrTransferSendHost(title:)` 加了参数但壳没传 → 死参数

- **文件:行号**：`QrTransferHosts.kt:94-101`；`DataTransferHost.kt:190-191`；`ShellPageIndex.kt:1485-1489`
- **原文**
  ```kotlin
  // QrTransferHosts.kt:94-101
  /**
   * 顶栏标题（Dart 按发送范围给：`qrTransferSendCurrent` / `qrTransferSendAll`）。
   * 由壳从 `TransferShellBridge.outboundTitle` 传进来；null = 沿用分组标题兜底。
   */
  title: String? = null,
  ```
  ```kotlin
  // ShellPageIndex.kt:1485-1489
  QrTransferSendHost(
      session = session,
      onBack = onBack,
      onStop = onBack,
  )
  ```
- **`outboundTitle` 全仓引用**：只有写入（`DataTransferHost.kt:191`）与桥属性定义（`:596`），**没有任何读取方**。
- **命令与输出**
  ```powershell
  grep -rn "outboundTitle" android/app/src --include=*.kt
  # DataTransferHost.kt:191 / :596 / QrTransferHosts.kt:96 / QrTransferSendPage.kt:73（后两条是注释）
  ```
- **影响**：Dart 按范围给标题（`qrTransferSendCurrent` / `qrTransferSendAll`），Kotlin 两种发送范围标题完全相同（都回落 `model.title`）。
- **守卫缺口**：`DiagnosticsWiringGuardTest` 的 `g3.qrSend` 只钉 `transferBridge.outboundPayload`，没钉 `outboundTitle`。

#### P1-4 壳层硬编码中文，未走 ArbText

- **文件:行号**：`ShellPageIndex.kt:1300, 1329, 1352`
- **原文**
  ```kotlin
  1300:                    deviceLabel = configStore.readDeviceLabel() ?: "Compose 壳",
  1329:                            Toast.makeText(context, "连接测试失败", Toast.LENGTH_SHORT).show()
  1352:                    deviceLabel = configStore.readDeviceLabel() ?: "Compose 壳",
  ```
- **已有现成件**：`SyncStrings.cloudSyncTestFailed` = `WebDAV 连接失败，请检查账号、应用密码和网络`（`SyncStrings.kt:88`）；`SyncStrings.cloudBackupDefaultDeviceLabel` = `本机`（`:116`）。Dart 侧 `_testConnection` 用 `l10n.cloudSyncTestFailed`（`cloud_sync_screen.dart:1245-1250`），`resolveBackupDeviceLabel` 回落 `l10n.cloudBackupDefaultDeviceLabel`（`cloud_backup_ui_helpers.dart:23-33`）。
- **门禁缺口**：`CjkLiteralGateTest` 只扫 `android/app/src/composeP1/kotlin`（`:88`），`main/kotlin` 的壳不在射程。
- **影响**：用户可见文案与 Dart/ARB 不一致；`Compose 壳` 还会出现在云端备份的设备名里。

#### P1-5 全量备份不支持合并（Dart 支持），预览弹窗隐藏「合并更改」

- **文件:行号**：`DataTransferApplyLogic.kt:56-62`；`DataTransferHost.kt:268-269`
- **原文**
  ```kotlin
  56:        if (isFullBackupPlan(plan)) {
  57:            // 全量包只有「覆盖」是安全且已实现的语义：整份替换档案表。
  58:            if (mode == TransferApplyMode.MERGE) return ERROR_FULL_BACKUP_MERGE_UNSUPPORTED
  ```
  ```kotlin
  // DataTransferHost.kt:268-269
  canMerge = pendingImport?.let { !DataTransferApplyLogic.isFullBackupPlan(it.plan) } ?: true,
  ```
- **对照**：Dart `showTransferPreviewDialog` **无条件**给三个动作（`transfer_preview_dialog.dart:41-53`），全量包也能走 `_merge`（`unified_transfer_service.dart:753-840`）。
- **影响**：与 Dart 可见不一致（少一个能力）。代码注释已说明是刻意取舍（Kotlin 没有逐实体合并服务），但按 D2「不得有 Dart 里不存在的自造行为」，隐藏按钮属自造行为。

#### P1-6 `e.analysis` 排行行在 HEAD 可点但无反应，且无守卫

- **文件:行号**：HEAD `StatisticsAnalysisPage.kt:65`；HEAD `ShellPageIndex.kt`（`e.analysis` 分支未传 `onOpenCourse`）
- **原文**（HEAD）
  ```kotlin
  62:fun StatisticsAnalysisPage(
  63:    viewState: StatisticsAnalysisViewState,
  64:    onBack: () -> Unit,
  65:    onOpenCourse: (String) -> Unit = {},
  66:) {
  ```
- **Dart 侧**：`statistics_analysis_screen.dart:132` → `:190 _openCourseEdit`（按课名找课程 → 打开编辑页）。
- **在途**：`onOpenCourse: ((String) -> Unit)? = null`，`null` 时不加 `clickable`（`StatisticsAnalysisPage.kt:280-296`），壳改为传真处理函数（`ShellPageIndex.kt:1244-1253`）。**在途版本正确。**
- **守卫缺口**：`DiagnosticsWiringGuardTest.MANAGED` **没有** `e.analysis`（`DiagnosticsWiringGuardTest.kt:188-283`），注释说明是因 `wiring.pendingX = null` 被 `FORBIDDEN` 误伤而排除。

### P2（内部债）

- **P2-1** `DataTransferApplyLogic.remapProfileSchemes` / `remapSettingsScheme` / `TransferApplyWrites` 为 public 但渲染层 0 引用（仅内部自用/返回类型）。
- **P2-2** 7 例往返测试停在 `planWrites`，未覆盖宿主→仓储那一跳；且文件未跟踪。
- **P2-3** `DiagnosticsWiringGuardTest` 未覆盖 `e.analysis`；`g3.qrSend` 未钉 `outboundTitle`。
- **P2-4** CJK 字面量门禁只扫 `composeP1/kotlin`，扫不到 `main/kotlin` 壳里的硬编码中文（P1-4 因此漏网）。
- **P2-5** `DataTransferPackageLogic.kt:57-58` 的「已知差异 3」注释已过期（snapshot 已有 `locationTimeGroups`）。
- **P2-6** `DataTransferModel.kt` 在途删除了 `profileShareSubject` / `exportCurrentLabel` / `importLabel` / `previewContent`；已 grep 确认全仓（含测试）无残留引用，`TransferPreviewModel.kt` 删除后 `TransferPreviewContent` / `TransferPreviewAction` 已迁到 `DataTransferModel.kt:42-45`。属正常清理，无缺陷。

---

## 六、我没能验的（诚实清单）

1. **未跑任何编译/单测**：禁令禁止跑 Gradle（L1/L2）与 `scripts/test-kotlin-module.ps1`。P0-1 的「编译不过」是**静态类型推断**（Kotlin 无隐式转换，`StatisticsFeedState` ≠ `CourseStatisticsViewState`），置信度很高，但**没有编译器输出**作证。
2. **未跑咬合探针**：`DataTransferRoundTripTest` 头注释声明做过反向验证（把 `tasks = plan.tasks` 改回 `current.tasks` 会红），我**只读了文本**，未运行，无法确认测试真有牙。
3. **未跑 `DiagnosticsWiringGuardTest` / `ShellPageDispatchCoverageTest` / `CjkLiteralGateTest`**：因此「守卫会红/绿」是我的**读码推断**，不是实测。特别是 P1-6（`e.analysis` 未纳入 MANAGED）与 P1-4（CJK 门禁扫不到壳）是读守卫源码得出的覆盖缺口。
4. **未做真机验证**：WebDAV 真账号恢复/删除、系统分享面板、二维码收发、局域网编辑浏览器端、取件码拉起各 App——全部归用户验收。
5. **未核对 `TimetableSettings` 250+ 键差异**：`DataTransferPackageLogic.kt` 自述「设置只落 core 子集」（已知差异 4），我只确认了该注释存在，未逐键比对 Dart 与 Kotlin 的 settings 序列化。
6. **`e.analysis` 的 `wiring.pendingAnalysisModule` 生命周期**：壳在 `e.statistics` 里写、`e.analysis` 里读，未验证从其他入口直接进 `e.analysis` 时 `pendingAnalysisModule` 是否为 null（`StatisticsAnalysisModel.viewState(module = ...)` 的 null 分支）。

---

## 七、审核方法

**只读纪律**：全程未修改任何 `.kt` / `.dart` / `.arb` / 构建文件。唯一的写操作是本报告文件与一个临时脚本（`.tmp-arbcheck.py`，已删除）。

**命令清单**（全部只读）

```powershell
git status --porcelain ; git log --oneline -15
git show HEAD:<path> | grep -n ...
git ls-files --error-unmatch <path>
git cat-file -e HEAD:<path>
grep -rnP '[一-鿿]' <dirs> --include=*.kt
grep -rn "<symbol>" android/app/src --include=*.kt
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain {transfer,sync,statistics}
python .tmp-arbcheck.py        # 自写只读脚本：ArbText/ChartText vs app_zh.arb
```

**分层取证顺序**

1. `git status` / `git log` → 界定「已提交 vs 在途」。
2. 壳分派（`ShellPageIndex.kt` / `ShellWiring.kt`）→ D1。
3. 每页宿主 → 模型层 → 仓储，追到真正的写盘点 → D2/D4。
4. `*Strings.kt` / ARB 机械对拍 + 渲染层中文字面量扫描 → D3。
5. `compose-style-lint.ps1`（只读）→ D5。
6. 读单测源码，查断言是否钉住行为（尤其往返断言）→ D6。
7. 对每条既有声明回 `lib/` 找 Dart 原件逐行比对。

**判据口径**

- **P0**：用户点进去就发现坏了/骗人（死页、假成功、点了没反应、写不进去、丢数据、回显不对）。→ P0-1（编译不过，APK 出不来）、P0-2（丢 5 类数据）、P0-3（丢地点分组）。
- **P1**：与 Dart 原版可见不一致（缺功能、版式/文案不对、自造行为）。→ P1-1 ~ P1-6。
- **P2**：内部债（分层倒挂、模型层摆设、测试无牙、文档失真、注释过期）。→ P2-1 ~ P2-6。

**关键提醒（给 Lead）**

- 「已提交 HEAD」与「在途工作区」是两套状态。**HEAD 的编译错误与备份丢数据必须先修并提交**，否则当前交付物不可构建、且会丢用户数据。
- 在途修复（`planWrites` + 7 例往返测试 + `feedState.home`）方向正确，但**尚未提交**，且仍漏 `locationTimeGroups` 与 `scheduleDateRules` 改写。
- 建议把 `e.analysis` 纳入 `DiagnosticsWiringGuardTest.MANAGED`（先单独讨论 `FORBIDDEN` 的「末尾 null」判据），并把 `g3.qrSend` 的 `transferBridge.outboundTitle` 加进钉住的符号列表。
