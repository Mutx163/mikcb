# 诊断/关于/任务/考试/反馈 · 近期重构独立审核（2026-10-30）

> 审核员：`review-diagnostics-task`（独立对抗式复核）
> 审核基准：**已提交交付 = `git show HEAD:<路径>`**（HEAD = `d6c925ba`）。
> 工作区另有一批**在途未提交**改动（ShellPageIndex / ShellWiring / AboutUpdateHost / ExamPickerSheets / ExamStrings / TaskStrings / ARB / DiagnosticsLogHost / PerfReportHost / i18n 基线 等），本文一律标注「**在途，非已提交交付**」，不与 HEAD 结论混算。
> 只读审核：未改任何 `.kt` / `.dart` / `.arb` / 构建文件；未跑 Gradle（L1/L2），未跑 `scripts/test-kotlin-module.ps1`。

---

## 一、结论

**总体：近期重构（2026-10-28 至今）在「接线真实性」上大体落地，但 HEAD 里仍有 1 个用户可见的 P0 死按钮、1 个 P1 可见差异、1 个会让 i18n 闸门变红的文案债，以及一批「修好了但没人守」的守卫缺口。**

| 判据 | 结论 |
|---|---|
| D1 接线真实性 | **有缺陷**。壳分派里本族页面基本都喂真宿主；但 `a.update` 宿主内部给高级选项页传了**空 lambda**（P0）。 |
| D2 功能复刻完整度 | **有缺陷**。`d3.examList` 传 `semesterStart = null`，考试列表日期少了 Dart 的「第 N 周 · 」前缀（P1）。 |
| D3 文案对拍 | **有缺陷**。`ExamPickerSheets` 在渲染层硬编码 4 处中文，且**不在本域 i18n 基线里**（HEAD 会让 `CjkLiteralGateTest` 变红）；另有 4 处已入基线的存量字面量（P2）。 |
| D4 分层 | **有缺陷**。`ExamStrings.datePickerYear/Month/Day`（在途新增）在 HEAD 尚不存在；HEAD 的考试滚轮文案既不在 ARB、也不在 strings 层，属渲染层自造（P1/P2）。 |
| D5 样式（机械） | **通过（含 2 处已登记例外）**。about / task / diagnostics / feedback 四域 0 违规；exam 域 2 处，均为基线里注明理由的例外。 |
| D6 测试牙齿 | **有缺陷**。诊断族 / 任务族有接线守卫；**关于族（F09）与考试族（F10）没有接线守卫**，且 `ExamListModelTest` 从不测非空 `semesterStart`，正好漏掉本次发现的 D2 缺陷。 |

**已提交交付的 P0 条数：1**（`AboutUpdateHost.kt:185` 的「打开日志页」空回调）。

---

## 二、逐页 D1..D6 + 证据

> 下文所有 `HEAD:` 行号均指 `git show HEAD:<路径>` 的快照行号。命令与真实输出附在每条后面。

### 2.1 壳分派全景（D1）

命令：

```
git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt | grep -nE '^\s*"[a-z][a-z0-9.]*"\s*->'
```

本族相关分支（节选真实输出）：

```
293:        "a.about" -> AboutStaticPage(onBack = onBack, onOpenPage = onOpenPage)
296:        "a.changelog" -> ChangelogPage(onBack = onBack)
298:        "a.licenses" -> OpenSourceLicensesHost(onBack = onBack)
301:        "a.support" -> SupportCreatorHostPage(onBack = onBack)
304:        "a.contributors" -> ContributorsHostPage(onBack = onBack)
307:        "a.update" -> AboutUpdateHostPage(onBack = onBack)
454:        "b.diagnostics" -> DiagnosticsSettingsHost(
694:        "d2.taskList" -> TaskListHost(
722:        "d2.addTask" -> {
880:        "d3.addExam" -> {
1030:        "d3.examList" -> {
1414:        "h.log" -> DiagnosticsLogHost(onBack = onBack)
1415:        "h.memory" -> MemoryStatsHost(
1421:        "h.fixture" -> LiveTestingFixtureHost(repository = wiring.timetable, onBack = onBack)
1478:        "i.more" -> MoreFeaturesWithSearch(
1485:        "i.moreSearch" -> MoreFeaturesSearchOverlay(
1492:        "h.perfReport" -> PerfReportHost(onBack = onBack)
1578:        "k.feedback" -> {
```

**D1 判定：本族壳分支没有一处直接喂 `emptyList()` / `= {}` / `SettingsPageState()` / `snapshot = null` 的空壳。** 逐条核对：

- `a.support` → `SupportCreatorHostPage`（真宿主，见 2.2）
- `a.contributors` → `ContributorsHostPage`（真宿主，见 2.2）
- `d2.taskList` → `TaskListHost`（真宿主，见 2.4）
- `d3.addExam` → 真状态机（见 2.5）
- `d3.examList` → 真数据 + 真删除服务（见 2.5，但有 D2 缺陷）
- 诊断族五页 → 真宿主（见 2.6）
- `i.more` → 真宿主（见 2.7）
- `k.feedback` → 真宿主（见 2.8）

**但** `a.update` 分支本身只传 `onBack`，它内部再调 `AdvancedOptionsPage` 时传了空 lambda（见 3.1，P0）。

### 2.2 关于族：支持作者 / 代码贡献者（声明 1，F09 / `ab69ec2d`）

**复核结论：声明属实。**

- `a.support` 分支（`ShellPageIndex.kt:301`）→ `SupportCreatorHostPage(onBack)`。
- `SupportCreatorHostPage`（`pages/about/SupportCreatorHost.kt`）用 `SupportDonorsFeed(http).fetch()` 真拉取，`when` 三分支 `Success / NotModified / Failure`，`onReload = { reloadToken += 1 }` 真重拉，失败把 `loadError` 交给页面显示真原因 + 重试。原文：

```
51:    LaunchedEffect(reloadToken) {
52:        isLoading = true
53:        loadError = null
54:        when (val outcome = withContext(Dispatchers.IO) { feed.fetch() }) {
55:            is DonorsFetchOutcome.Success -> donorData = outcome.data
...
64:    SupportCreatorPage(
65:        donorData = donorData,
66:        onBack = onBack,
67:        onReload = { reloadToken += 1 },
68:        isLoading = isLoading,
69:        loadError = loadError,
70:    )
```

- `a.contributors` 分支（`ShellPageIndex.kt:304`）→ `ContributorsHostPage(onBack)`。
- `ContributorsHostPage`（`pages/about/ContributorsHost.kt`）先读缓存（`warehouse_maintainers_cache_v1`）→ 再拉 `root_index.yaml` + 每校 `adapters.yaml` → 成功替换并回写缓存，失败保留缓存 + 显示真原因 + 重试。原文（节选）：

```
55:    LaunchedEffect(reloadToken) {
56:        val cached = readMaintainersCache(store)
...
71:        when (val outcome = withContext(Dispatchers.IO) { feed.fetch() }) {
72:            is MaintainersFetchOutcome.Success -> {
73:                maintainers = outcome.groups
...
88:            is MaintainersFetchOutcome.Failure -> {
89:                error = outcome.reason
90:            }
91:        }
```

- 数据层真实：`pages/about/DonorsFeed.kt`（官方 raw 主 / GitCode 备，逐候选 200 即返，失败带真 reason）、`pages/about/MaintainersFeed.kt`（222 校并发读、缓存编码、YAML 子集解析器 + 单测）。

**D1/D2 通过。** 唯一缺口是**没有接线守卫**（见 3.6，P2）。

### 2.3 关于族：版本更新 / 高级选项（`a.update`）

**D1：有缺陷（P0）。**

`AboutUpdateHost.kt`（HEAD）里 `showAdvanced == true` 时调 `AdvancedOptionsPage`：

```
179:    if (showAdvanced) {
180:        AdvancedOptionsPage(
...
184:            onEditMirrorUrl = { Toast.makeText(context, AboutUpdatePageStrings.mirrorPrefixLabel, Toast.LENGTH_SHORT).show() },
185:            onOpenDiagnostics = { /* 日志页路由未在本批次接入 */ },
186:        )
```

而 `AdvancedOptionsPage` 把这一回调接到「打开日志页」行的点击上（HEAD）：

```
196:            item(key = "diag-title") { QingyuSectionTitle(AboutUpdatePageStrings.diagnosticsTitle) }
197:            item(key = "diag-group") {
198:                GroupCard {
199:                    ArrowRow(
200:                        title = AboutUpdatePageStrings.viewPhoneLogsAction,
201:                        onClick = onOpenDiagnostics,
202:                    )
```

`AboutUpdatePageStrings.diagnosticsTitle = "测试与诊断"`、`viewPhoneLogsAction = "打开日志页"`（`AboutUpdatePageStrings.kt:95,98`），ARB 键为 `aboutDiagnosticsTitle` / `aboutViewPhoneLogsAction`（`app_zh.arb:2506,2511`），文案对拍通过。

**后果：用户进「版本更新 → 高级选项 → 打开日志页」，点了没反应。** 这正是判据 D1「空 lambda 一个都不许留」与 P0「点了没反应」。

**在途（非已提交交付）**：工作区 `AboutUpdateHost.kt` 已把它改成真出口：

```
331:            onOpenDiagnostics = {
332:                val openPage = onOpenPage
333:                if (openPage != null) openPage("h.log") else showLogs = true
334:            },
```

并把 `AboutUpdateHostPage` 签名加了 `onOpenPage: ((String) -> Unit)? = null`（HEAD 只有 `onBack`）。**但工作区壳分支仍是 `"a.update" -> AboutUpdateHostPage(onBack = onBack)`（ShellPageIndex.kt:318），没传 `onOpenPage`**，所以即使在途版本也只是退化为「页内嵌日志查看器」，而不是走 `h.log` 壳分支。

**D3（文案）**：本族 `AboutUpdatePageStringsArbTest` 已存在且逐条对拍 ARB（含 `aboutDiagnosticsTitle` / `aboutViewPhoneLogsAction`），**通过**。

### 2.4 任务族（声明 5，`21b29038`）

**复核结论：三条声明全部属实，且底栏入口已接真宿主。**

1. **保存键禁用态封死报错路径**（V1）：`AddTaskPage.kt`（HEAD）保存键已无 `enabled`：

```
193:                        // 2026-10-29 复核更正（V1）：这里原先 `enabled = viewState.canSave`,
...
201:                        IconButton(onClick = onSave) {
...
211:                                contentDescription = TaskStrings.saveTask,
212:                                tint = Color(QingyuTheme.actionIcon(dark)),
```

2. **卡头字号 20sp→17sp**（V2）：

```
249:                                Text(
250:                                    text = TaskStrings.taskListTitle,
251:                                    style = MiuixTheme.textStyles.main,
```

3. **筛选取消被当成选全部**（V3）：`TaskListPage.kt`（HEAD）只在真选中时回写：

```
264:        onPick = { picked ->
265:            showCourseFilter = false
...
274:            if (picked != null) {
275:                onCourseFilterPicked?.invoke(picked)
276:            }
277:        },
```

4. **底栏任务入口接真宿主**：`PagesShellActivity.kt:305` 的 `DockSlot.TASK -> TaskListHost(...)`，与路由 `d2.taskList` 共用同一宿主。`TaskWiringGuardTest` 三条断言钉住「两个渲染点都调 `TaskListHost(`」「不许 `shellSampleTaskViewState`」「`shellSampleTaskViewState` 函数不许复活」。

**D1/D2/D5/D6 通过。**

### 2.5 考试族（声明 2，F10 / `a8a55bc3`）

**D1：`d3.addExam` 已接真状态机，声明属实。**

`ShellPageIndex.kt:880-1028`（HEAD）用 `AddExamFormReducer` 驱动 16 个回调，写库走 `TimetableExamService`：

```
886:            var examForm by remember(editingExam?.id) {
887:                mutableStateOf(AddExamFormReducer.initial(editingExam))
888:            }
...
898:            AddExamPage(
...
911:                onSave = {
912:                    val checked = AddExamFormReducer.validate(examForm)
...
923:                            if (editingExam != null) service.updateExam(exam) else service.addExam(exam)
...
```

`AddExamPage` 的 16 个 `on*` 参数**全部没有默认值**，壳 16 个全传（签名见 `AddExamPage.kt` HEAD）。`d3.examList` 用 `ExamListLogic.buildListViewState` + `TimetableExamService(CoursePortExamAdapter(repository)).deleteExam`，`onOpenExam` 把考试对象写进 `wiring.pendingEditExam` 再跳页。

**D2：有缺陷（P1）。** `d3.examList` 传 `semesterStart = null`（HEAD `ShellPageIndex.kt:1047`）：

```
1030:        "d3.examList" -> {
...
1043:                    ExamListLogic.buildListViewState(
1044:                        exams = repository.exams,
1045:                        courses = repository.courses,
1046:                        semesterStart = null,
1047:                        now = LocalDateTime.now(),
1048:                    )
```

Dart 原件用真开学日期给日期串加「第 N 周 · 」前缀（`lib/screens/exam_list_screen.dart:136-145`）：

```
136:    final semesterStart = provider.semesterStartDate;
137:    if (semesterStart != null) {
138:      final weekIndex = provider.getWeekIndex(date, semesterStart);
139:      if (weekIndex != null && weekIndex >= 1) {
140:        weekInfo = '${l10n.weekLabel(weekIndex)} · ';
141:      }
142:    }
143:
144:    return '$weekInfo$datePart $weekday';
```

Kotlin 的 `ExamListModel.formatExamDate` 明确实现了同一逻辑（`ExamListModel.kt:131-145`），注释还写着「有开学日期且周次 ≥ 1 时前置「第 N 周 · 」」，但壳把 `semesterStart` 写死 `null`，于是**用户看到的考试列表日期永远没有周次前缀**。同分支里 `repository.snapshot.settings.semesterStartDate` 是可用的（`d3.addExam` 分支就用它喂日期选择器）。

**在途（非已提交交付）**：工作区 `ShellPageIndex.kt:1113` **仍是 `semesterStart = null`**，即该缺陷在在途版本里也未修。

**D6：`ExamListModelTest` 的牙齿不足以抓这条。** 该测试在 `buildListViewState` 的所有用例里都传 `semesterStart = null`（`ExamListModelTest.kt:288,306,323,336,355,377`），只有 `formatExamDate` 的用例覆盖了非空值（`:170,180`）。也就是说「壳有没有把真开学日期喂进来」这条没有任何测试钉住——本次发现的 D2 缺陷恰好落在这个盲区里。

### 2.6 诊断族五张死页（声明 6）

**复核结论：五页都已接真宿主，声明属实。** 逐页核对：

| 页面 | 分支 | 真宿主 | 关键证据 |
|---|---|---|---|
| 设置→诊断 | `b.diagnostics`（`:454`） | `DiagnosticsSettingsHost` | 读 `TimetableSettingsModelStore`；开关走 `DiagnosticsRecordingLogic.toggle` + 落盘失败回滚到盘上真值；「设置快照」真打 `PerformanceSnapshot` + `AppLogStore.append` |
| 应用日志 | `h.log`（`:1414`） | `DiagnosticsLogHost` | 读 `AppLogStore` 两份文件 + 每秒指纹轮询；9 个交互逐个落成真动作 |
| 内存状态 | `h.memory`（`:1415`） | `MemoryStatsHost` | 真采集 + 自动刷新 + 跳性能报告 |
| 性能报告 | `h.perfReport`（`:1492`） | `PerfReportHost` | `PerfProbe.attach` + `snapshotJson` + 6 个交互 |
| 测试夹具 | `h.fixture`（`:1421`） | `LiveTestingFixtureHost` | 仓储真读写 |

`DiagnosticsWiringGuardTest`（HEAD）的 `MANAGED` 表恰好登记了这五页 + `k.feedback` / `i.more` / `i.moreSearch` / `i.startup`，并有 `守卫本身没有空转`（要求解析出 ≥70 个分支）与「去注释后判据」两条防空转断言。命令：

```
grep -nE 'DiagnosticsLogSnapshot\.EMPTY|snapshot = null|SettingsPageState\(\)|emptyList\(\)|=\s*\{\s*\}' <各分支体>
```

本族五分支均未命中。

**D1 通过。** 但守卫只覆盖 `MANAGED` 表（声明 6 自己已注明），**关于族与考试族不在其中**（见 3.6）。

### 2.7 反馈渠道与「全部功能」导航（声明 3 / 4，F02/F11）

**反馈渠道（`k.feedback`）：D1 通过。** `ShellPageIndex.kt:1578-1596`（HEAD）把 `onOpenChannel` / `onCopyChannel` 接到 `runFeedbackOpenPlan` + `FeedbackChannelHost.open/copy/toast` 三件套：

```
1580:                onOpenChannel = { channel ->
1581:                    runFeedbackOpenPlan(
1582:                        plan = feedbackOpenPlanFor(channel),
1583:                        launch = { url -> FeedbackChannelHost.open(context, url) },
1584:                        copy = { value -> FeedbackChannelHost.copy(context, value) },
1585:                        notify = { message -> FeedbackChannelHost.toast(context, message) },
1586:                    )
```

`FeedbackModel.kt` 有 5 个渠道（`FeedbackModel.kt:109,124,143,157,175`），与 Dart `feedback_screen.dart` 的 5 个 `_FeedbackChannelTile` 一致。**在途** `DiagnosticsLogHost.kt` 又补了「复制失败不假装成功」「分享面板没拉起时留 logcat」两条（见 4.2）。

**「全部功能」（`i.more`）：D1 通过。** `ShellPageIndex.kt:1661-1700`（HEAD）的 `MoreFeaturesWithSearch` 里，页内浮层选中走「先关浮层、再跳页」：

```
1691:        MoreFeaturesSearchOverlay(
1692:            groups = groups,
1693:            onDismiss = { searchOpen = false },
1694:            onSelectFeature = { featureId ->
1695:                searchOpen = false
1696:                openFeature(featureId)
1697:            },
1698:        )
```

`MoreFeaturesModel.buildDefaultFeatureGroups()` 共 39 个条目（40 行 `MoreFeatureItem(` 减去 1 行 `data class` 定义）。`MoreFeaturesNavigationGuardTest` 钉住「每条目都能解析到壳页面」「目标在目录里且标着可进入」「关键条目落点与 Dart 目录一致」。

**独立路由 `i.moreSearch`：D1/D2 有缺陷（P2，潜在）。** 该分支（HEAD `ShellPageIndex.kt:1485-1491`）的顺序是**先推页再退栈**：

```
1485:        "i.moreSearch" -> MoreFeaturesSearchOverlay(
1486:            onDismiss = onBack,
1487:            onSelectFeature = { featureId ->
1488:                shellTimetableMenuPageId(featureId)?.let(onOpenPage)
1489:                onBack()
1490:            },
1491:        )
```

而 Dart 是先摘浮层再 open（`more_features_screen.dart:152-155`）。**但该路由当前不可达**：`ShellPageIndexScreen` 全仓只有定义、没有任何调用点（`grep -rn ShellPageIndexScreen` 仅命中自身），`shellPageIdForRoute` 也没有映射到 `i.moreSearch`。所以这是**潜在缺陷**，不是用户可见缺陷。

**声明准确性**：`95f82d43` 的提交说明明确写了「`ShellPageIndex.kt` 里的 `i.moreSearch` 顺序修复单独留在工作区……等它们落地后再随下一次该文件提交一起进 HEAD」，即**提交说明声称的壳侧修复并未进 HEAD**。组件侧（`MoreFeaturesSearchOverlay` 不再顺带调 `onDismiss`）已提交，所以**可达的页内浮层是正确的**；不可达的独立路由仍是旧顺序。**在途**工作区已把它改成先 `onBack()` 再推页。

**引导按钮「正在打开」（声明 4，F11）：D1/D2 通过。** `StartupFlowPage.kt`（HEAD）在 `onOpenOldApp()` 之后立即复位：

```
111:                        onOpenOldApp = {
112:                            stateMachine.setOpeningOldApp(true)
113:                            currentState = stateMachine.state
114:                            onOpenOldApp()
...
119:                            stateMachine.setOpeningOldApp(false)
120:                            currentState = stateMachine.state
121:                        },
```

该修复随 `95f82d43` 提交，壳侧 `onOpenOldApp` 也真调 `openLegacyApp(context, STARTUP_LEGACY_PACKAGE_CANDIDATES)`（`ShellPageIndex.kt` HEAD 的 `StartupFlowHost` 段）。

### 2.8 D3 文案对拍（机械）

命令（逐文件、去注释行）：

```
git show HEAD:<file> | grep -nP '[一-鿿]' | grep -vE ':\s*(//|\*|/\*)'
```

本族命中（渲染层字面量）：

| 文件 | HEAD 行 | 字面量 | 基线状态 |
|---|---|---|---|
| `exam/ExamPickerSheets.kt` | 297 | `"$it 年"` | **不在基线** |
| | 311 | `"$it 月"` | **不在基线** |
| | 320 | `"$it 日"` | **不在基线** |
| | 602 | `removePrefix("周")` | **不在基线** |
| `diagnostics/MemoryStatsPage.kt` | 641 | `"堆 … 压力 …"` | 基线 3 条 |
| | 684 | `"… · …"` | 同上 |
| | 727/728 | `"  ·主进程"` / `"  ·疑似超级岛相关"` | 同上 |
| `feedback/FeedbackPage.kt` | 151 | `"复制 ${channel.copyValue}"` | 基线 1 条 |

用仓库自带的扫描逻辑（`scripts/i18n-cjk-baseline.py` 的 `count_line`）对 HEAD 快照逐文件计数，真实输出：

```
4 android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/ExamPickerSheets.kt
3 android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/MemoryStatsPage.kt
1 android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/feedback/FeedbackPage.kt
0 …/exam/AddExamPage.kt
0 …/exam/ExamListPage.kt
0 …/task/TaskListPage.kt
0 …/task/AddTaskPage.kt
0 …/task/TaskPickerSheets.kt
```

而 HEAD 的基线文件（`git show HEAD:android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt`）里**没有 `ExamPickerSheets.kt` 这一行**（`grep -c ExamPickerSheets` = 0）。`ExamPickerSheets.kt` 由 `a8a55bc3` 新建，而基线最后一次更新是更早的 `9c2ec06a`（`git merge-base --is-ancestor 9c2ec06a a8a55bc3` = YES，即基线更新在前、文件新建在后）。

**判定：HEAD 上 `CjkLiteralGateTest` 会因「新增未登记文件 `…/ExamPickerSheets.kt`：4 条中文字面量」变红。** 该提交（`a8a55bc3`）的验证说明只写了「样式守卫 exam 域无新增违规；文案自查无新增超宽/复述」，**没有提 i18n 字面量闸门**。

**在途（非已提交交付）**：工作区已把 4 处全部改走 `ExamStrings.datePickerYear.zh` / `weekdayShortLabel()`，并在 `ExamStrings.kt` 新增 `weekdayShort*` 与 `datePicker*`，ARB 也补了 `datePickerYear/Month/Day`（`app_zh.arb:1776-1778`，在途）。同时工作区重写了 `cjk-literal-baseline.txt`（删除若干已修行），`ExamPickerSheets` 因归零而不再出现——**这与修复后的状态自洽**。

### 2.9 D4 分层

规则：渲染层只能调模型层（`main:` 下 `*Model.kt` / `*Logic.kt` / `*Strings.kt`）；模型层 public 件若渲染层 0 引用 = 缺陷。

- 渲染层（`composeP1/pages/**`）确实只从 `com.mutx163.qingyu.pages.<域>`（Model/Logic/Strings）与 `components` / `theme` / `ui` / `core` / `infra` 取数，未直接 import `android.*` 业务实现（除 `AboutUpdateHost` 这类**宿主**文件，宿主允许碰 `infra` / `platform`）。
- 命中项：HEAD 的 `ExamPickerSheets.kt:297/311/320/602` 在渲染层直接写中文，**既不在 `ExamStrings`（HEAD 的 `ExamStrings.kt` 没有 `datePicker*`，`git show HEAD:…ExamStrings.kt | grep datePicker` 无输出），也不在 ARB**（`git show HEAD:lib/l10n/app_zh.arb | grep datePicker` 无输出）。这是「渲染层自造文案」的典型 D3/D4 双违。
- `TaskStrings.datePickerYear/Month/Day`（HEAD `TaskStrings.kt:65-67`）是 strings 层常量，但 HEAD 注释自己承认「ARB 里没有独立键」「TaskStrings 无 parity 测试枚举」，且 HEAD **不存在** `TaskStringsParityTest.kt`（`git ls-files` 报 not known to git）。在途新增了该测试并补了 ARB 键。
- 另有一批 `main:` 下文件在 composeP1 里 0 引用（`AboutInfoModel.kt`、`ChangelogModel.kt`、`SupportCreatorModel.kt`、`ExamListModel.kt`、`MemoryStatsModel.kt`、`PerfReportModel.kt` …）。**注意**：这些多为「Model 被 Logic 调用、Logic 再被渲染层调用」的正常分层，逐文件判「摆设」需要逐个符号级核对，本次未逐一展开（见第五节）。其中与本次缺陷直接相关的是 `ExamListModel`：它被 `ExamListLogic` 调用、逻辑本身正确，问题出在**壳没把真数据喂进去**，不是文件摆设。

### 2.10 D5 样式（机械，只读）

命令：

```
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain about|task|exam|diagnostics|feedback
```

真实输出：

```
about     ：0 处
task      ：0 处
exam      ：2 处
  R2   exam/AddExamPage.kt  用 Column+verticalScroll 当主滚动（非惰性，第 161 行）
  R5   exam/ExamListPage.kt  写死颜色 3 处，首处第 62 行（应用主题语义槽）
diagnostics：0 处
feedback  ：0 处
```

`tool/compose_style_baseline/exam.txt` 里两行均已登记且写明理由：

```
exam/AddExamPage.kt|R2|例外：表单页（有限输入控件 + 焦点/键盘联动），与输入控件同处单一滚动容器，非惰性列表可接受
exam/ExamListPage.kt|R5|例外：进行中橙标 kLiveOrange / 默认课程蓝 kDefaultAccent 两个固定语义色，与主题无关
```

**D5 判定：通过（含 2 处已登记例外），无新增违规。**

### 2.11 D6 测试牙齿

| 声明/缺陷 | 有无测试 | 牙齿评估 |
|---|---|---|
| 诊断族五页接线 | `DiagnosticsWiringGuardTest` | **有牙**：读源码文本、去注释后判「宿主符号必须出现」+「空数据/空回调/空 state 必须不出现」，另有「解析出 ≥70 分支」的防空转断言 |
| 任务族两渲染点 | `TaskWiringGuardTest` | **有牙**：钉「两个渲染点都调 `TaskListHost(`」「不许 `shellSampleTaskViewState`」「函数不许复活」 |
| 「全部功能」39 行 | `MoreFeaturesNavigationGuardTest` | **有牙**：逐条目 id 查壳表 + 目录 kind |
| 反馈渠道 5 行 | `FeedbackModelTest` + 壳分支 | 模型层有牙（打开顺序/回落）；**壳分支无文本守卫** |
| **关于族 a.support / a.contributors（F09）** | **无** | `DiagnosticsWiringGuardTest.MANAGED` 未登记，`TaskWiringGuardTest` / `MoreFeaturesNavigationGuardTest` 也不覆盖这两个分支体 |
| **考试族 d3.addExam / d3.examList（F10）** | **无** | 同上；`AddExamFormReducerTest` 只测模型层（460 行、覆盖五道阻断 + 提醒三态 + 组装），不测壳接线 |
| **`d3.examList` 的 `semesterStart`** | `ExamListModelTest` 只测 `formatExamDate` 非空，`buildListViewState` 全用 null | **无牙**：正好漏掉本次发现的 D2 缺陷 |
| i18n 字面量闸门 | `CjkLiteralGateTest` + 基线 | **闸门本身有牙**，但 HEAD 基线漏登记 `ExamPickerSheets` ⇒ HEAD 应为红（见 2.8） |

---

## 三、缺陷清单

### P0（用户点进去就发现坏了）

**P0-1 高级选项「打开日志页」是死按钮（HEAD）**
- 位置：`android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdateHost.kt:185`（HEAD）
- 原文：`onOpenDiagnostics = { /* 日志页路由未在本批次接入 */ },`
- 触发点：`pages/about/AdvancedOptionsPage.kt:199-202`（HEAD）`ArrowRow(title = AboutUpdatePageStrings.viewPhoneLogsAction, onClick = onOpenDiagnostics)`
- 现象：`版本更新 → 高级选项 → 打开日志页` 点击无反应。
- 判据：D1（空 lambda 一个都不许留）+ P0（点了没反应）。
- 在途：工作区已修为 `openPage("h.log")` 或页内嵌真宿主；但壳分支 `ShellPageIndex.kt:318` 仍只传 `onBack`。

### P1（与 Dart 可见不一致 / 缺功能）

**P1-1 考试列表日期缺「第 N 周 · 」前缀（HEAD，在途也未修）**
- 位置：`android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt:1046`（HEAD）/ `:1113`（在途）
- 原文：`semesterStart = null,`
- 对照：Dart `lib/screens/exam_list_screen.dart:136-143` 用 `provider.semesterStartDate` 计算 `weekInfo`；Kotlin `ExamListModel.kt:131-145` 已实现同一逻辑但拿不到值。
- 现象：考试列表每条日期只有「M月D日 周X」，比 Dart 少「第 N 周 · 」。
- 判据：D2。

**P1-2 考试日期滚轮在渲染层硬编码中文，且未登记进 i18n 基线（HEAD）**
- 位置：`android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/ExamPickerSheets.kt:297,311,320,602`（HEAD）
- 原文：`label = { "$it 年" }` / `"$it 月"` / `"$it 日"`；`ExamStrings.weekdayLabel(dayOfWeek).removePrefix("周")`
- 基线：HEAD `cjk-literal-baseline.txt` 无 `ExamPickerSheets.kt`；`ExamStrings.kt`（HEAD）无 `datePicker*`；ARB（HEAD）无 `datePicker*`。
- 后果：`CjkLiteralGateTest` 在 HEAD 上会报「新增未登记文件 …4 条中文字面量」而变红。
- 判据：D3 + D4。
- 在途：已改为 `ExamStrings.datePickerYear.zh` 等 + 新增 ARB 键。

### P2（内部债）

**P2-1 存量渲染层中文字面量（已入基线，未清）**
- `diagnostics/MemoryStatsPage.kt:641,684,727,728`（3 条）、`feedback/FeedbackPage.kt:151`（1 条），HEAD 基线已登记。属冻结债，非新增；D3 口径下仍是渲染层字面量。

**P2-2 关于族 / 考试族无接线守卫**
- `DiagnosticsWiringGuardTest.MANAGED` 未登记 `a.support` / `a.contributors` / `d3.addExam` / `d3.examList`，也没有其它守卫覆盖这些分支体。F09 / F10 的修复一旦被回退，编译与现有单测都不会响。判据：D6。

**P2-3 独立路由 `i.moreSearch` 顺序仍是「先推页再退栈」**
- `ShellPageIndex.kt:1487-1489`（HEAD）。该路由不可达（`ShellPageIndexScreen` 无任何调用点），故为潜在缺陷；但 `95f82d43` 提交说明声称已修，属**声明与交付不一致**。在途已改。

**P2-4 `ExamListModelTest` 的 `buildListViewState` 用例全部传 `semesterStart = null`**
- `ExamListModelTest.kt:288,306,323,336,355,377`。恰好放过 P1-1。判据：D6。

**P2-5 `TaskStrings.datePickerYear/Month/Day` 在 HEAD 既无 ARB 键也无 parity 测试**
- `TaskStrings.kt:65-67`（HEAD）注释自认；`TaskStringsParityTest.kt` 在 HEAD 不存在（`git ls-files` 报 not known）。在途已补 ARB 键与测试。判据：D3/D6。

---

## 四、在途改动（非已提交交付，仅供参考，不计入上表结论）

工作区当前有一批未提交改动，与本次审核范围高度重叠。它们**不是已交付内容**，但方向上都是修本次发现的问题：

1. `ShellPageIndex.kt`：日视图 `pendingDayViewDayOfWeek` / `visibleDays` / `totalWeeks`（P0-2、P1-14）、`DayViewDataAssembler` 装配、能力型回调（`onOpenCourseNotes` / `onOpenCourseTask` / `onOpenExam` / `onOpenSchedule` / `onOpenTask` / `onViewAllOverdue`）、`i.moreSearch` 改为先退栈再推页、统计分享 `feedState.home`、周报调度 `runCatching` + 失败 toast、排行页 `onOpenCourse`。
2. `ShellWiring.kt`：新增 `pendingDayViewDayOfWeek`，`onOpenDay` 带星期几。
3. `AboutUpdateHost.kt`：`onOpenDiagnostics` 真出口 + `onOpenPage` 参数。
4. `ExamPickerSheets.kt` / `ExamStrings.kt` / `TaskStrings.kt` / `app_zh.arb` / `TaskStringsParityTest.kt`（新增）：日期滚轮与星期短名改走 strings 层 + 补 ARB 键。
5. `DiagnosticsLogHost.kt` / `PerfReportHost.kt`：复制失败不假装成功、分享面板未拉起时留 logcat。
6. `cjk-literal-baseline.txt`：随修复下调。

**这些改动未编译验证（本审核不许跑 Gradle），也未提交。**

---

## 五、我没能验的

1. **没有跑任何测试**：按硬规矩未跑 Gradle（L1/L2），未跑 `scripts/test-kotlin-module.ps1`。因此「HEAD 上 `CjkLiteralGateTest` 变红」「`ExamListModelTest` 抓不到 P1-1」都是**按测试源码与基线规则推导**的结论，不是实跑输出。
2. **没有真机对照**：所有「用户可见差异」都来自 Dart 源码逐字对照，未在设备上确认渲染结果。
3. **`main:` 下 0 引用文件未逐个符号级判定**：`AboutInfoModel.kt` / `ChangelogModel.kt` / `SupportCreatorModel.kt` / `ExamListModel.kt` / `MemoryStatsModel.kt` / `PerfReportModel.kt` 等文件的公开符号可能被 `*Logic.kt` 间接调用（渲染层 → Logic → Model 是合法分层）。要把它们判成「模型层摆设」需要逐个符号核对引用链，本次只对与缺陷直接相关的 `ExamListModel` 做了确认（它被 `ExamListLogic` 正常调用，问题在于壳喂数据）。
4. **在途改动未编译**：工作区那批改动可能编译不过（例如 `AboutUpdateHost` 新参数与壳调用点的匹配、`ExamStrings` 新增项是否被 parity 测试完整枚举），本次未验证。
5. **`SupportCreatorPage` / `ContributorsPage` 的视觉复刻度**：只核对了数据与交互落点，未逐块比对 Dart 的版式/间距/空态文案。

---

## 六、审核方法

1. **基线锁定**：`git status` 发现工作区有大量在途改动。对已提交文件一律用 `git show HEAD:<路径>` 取快照；对在途改动单独用 `git diff` 记录并标注「在途，非已提交交付」。
2. **壳分派逐分支核对（D1）**：用 `grep -nE '^\s*"[a-z][a-z0-9.]*"\s*->'` 列出全部 87 个分支，再对本族 17 个分支逐个读分支体，检查 `emptyList()` / `= {}` / `SettingsPageState()` / `snapshot = null` / `null` 实参。
3. **声明逐条回源码（D1/D2）**：对 6 条既有声明，先确认声明 commit 是 HEAD 祖先（`git merge-base --is-ancestor`），再回 HEAD 快照读实现与 Dart 对照。
4. **文案机械扫描（D3）**：用 `grep -nP '[一-鿿]'` 逐文件扫渲染层，剔除纯注释行；再用仓库自带的 `scripts/i18n-cjk-baseline.py` 的 `count_line` 逻辑对 HEAD 快照计数，与 HEAD 基线文件比对。
5. **样式机械扫描（D5）**：只跑只读的 `scripts/compose-style-lint.ps1 -Domain <域>`，并核对 `tool/compose_style_baseline/*.txt` 的例外行。
6. **分层（D4）**：列出渲染层 import，确认只落在 `pages.<域>` 的 Model/Logic/Strings 与 `components` / `theme` / `ui` / `core` / `infra`；对可疑文件做符号级引用核对。
7. **测试牙齿（D6）**：列出本域全部测试文件，逐条判断「断言的是行为还是存在」，并检查壳接线是否有文本守卫覆盖。
8. **只读约束**：全程未改任何产品代码；唯一的写操作是本报告文件。
