# 其余近期接线页面（任务 / 考试 / 日程 / 天气 / 统计 / live）· 质量审核（2026-10-29，独立复核）

审核基线：**HEAD `3f3b7354`**（2026-10-29 20:10）；审核时刻：**2026-10-29T20:33（Asia/Shanghai）**
第二轮（修复阶段 FY5）基线：**HEAD `bf0e5a57`**（2026-10-29 22:2x）；动手时刻 **2026-10-29T22:29**
→ 逐条状态表见下面「**第二轮修复状态总表**」，本轮的改动 / 壳接线请求 / ARB 新增请求在文末三节。

> 判据：`docs/plans/2026-10-29-quality-audit/_RUBRIC.md`（全文按该文件 D1..D6 / §3 证据规范 / §4 分级 / §6 结构）。
> 基线口径（Lead 2026-10-29 20:43 下达）：`git status --porcelain` 里未提交的文件，判据一律用 `git show HEAD:<路径>`；
> 工作区与 HEAD 的差异单列「在途改动（他人，不入判）」，既不算缺陷也不算通过。
> 本报告所有 `ShellPageIndex.kt` 行号均取自 `git show HEAD:...` 的副本（第一轮 `/tmp/shell_head.kt` 1513 行；
> 第二轮 `/tmp/shell_new.kt` **1672 行**），**不是工作区现行内容**。

---

## 第二轮修复状态总表（HEAD `bf0e5a57`，Lead 裁决后分工 FY5）

**计数：已修 6 条（本轮 5 + 他人 1）/ 他人泳道在修 8 条 / 仍存在 5 条（全在写作用域外）/ 误判 0 条。**
所谓「误判 0 条」= 第一轮 19 条逐条回查后，**没有一条被源码反证推倒**；但有 1 条口径被修正（P1-3，见下）。

| 编号 | 一句话 | 第二轮状态 | 证据 / 去向 |
|---|---|---|---|
| P0-1 | `d3.addExam` 16 个空回调的死表单 | **他人泳道在修（F10）** | 壳 HEAD `ShellPageIndex.kt:851-872` **一字未变**；对方 22:32 新建了前置件 `?? pages/exam/ExamPickerSheets.kt`、`?? main/pages/exam/AddExamFormReducer.kt`。我按 Lead 裁决**不碰** `pages/exam/**` |
| P0-2 | live 显示设置改了不落盘 | **已修（F01：`96fee704` 主体 + `60f85d69` 收尾）** | 壳 HEAD `:1307-1309` 已换成 `LiveDisplayHost(forDuringEnd = …)`（三个路由），不再走「内存态便捷重载」 |
| P0-3 | live 提醒时机不落盘 | **已修（F01：同上）** | 壳 HEAD `:1311 "j.reminderTiming" -> LiveReminderTimingHost(onBack = onBack)` |
| P0-4 | 统计主页分享按钮 `onOpenShare = {}` | **他人泳道在修（F12）** | 壳 HEAD `:932 onOpenShare = {},` 仍在；Lead 明示分享链路归 F12，我**不动** `pages/statistics/**` 的分享链路 |
| P1-1 | 考试日期 `semesterStart = null` | **他人泳道在修（F10）** | 壳 HEAD `:890 semesterStart = null,` 仍在（同一分支归 F10） |
| P1-2 | 考试删除无 `runCatching`，失败异常直穿点击回调 | **他人泳道在修（F10）** | 壳 HEAD `:896 onDeleteExam = { examService.deleteExam(it.id) },` 仍在；`TimetableExamService.kt:135 throw e` |
| P1-3 | 深度分析排行点课程名没落点 | **已修（本轮，页面侧）+ 壳接线请求** | ① 页面：`StatisticsAnalysisPage.kt` 的 `onOpenCourse` 改 `((String) -> Unit)? = null`，`RankingRows` **有落点才加 `clickable`**（此前连 `.clickable` 都没有，等于「照片上的按钮」）；② 壳分支 HEAD `:976-999` 仍不传 ⇒ 现在是「纯展示、不可点」，不再是死热区 |
| P1-4 | 单节课明细「设过提醒」恒 0（假读数） | **已修（本轮）** | `StatisticsSessionModel.coverageRows(stats, reminderDataAvailable)`：拿不到提醒数据就**不画那一行**；`StatisticsFeed.sessionViewState/feed` 的 `reminderKeys` 改 `Set<String>? = null`（null = 拿不到）。根因（Kotlin `TimetableSettings` 无 `classReminders` 字段）未变，属设置族 |
| P1-5 | 日程保存/删除失败零提示、成功零确认 | **已修（本轮）+ 壳接线请求** | 新增 `composeP1/.../pages/schedule/ScheduleEditHost.kt`：失败弹 `saveFailed`/`deleteFailed` 且**不关页**，成功弹 `scheduleSavedHint`/`scheduleUpdatedHint` 再关页（对齐 Dart `:906-925` / `:1024-1040`） |
| P1-6 | `AddScheduleItemPage.kt:346` 写死「已启用/已暂停」+ 按钮代开关 | **已修（本轮）** | 换成官方 `SwitchPreference`，文案走 `scheduleEnabledTitle` / `scheduleDisabledSubtitle` |
| P1-7 | `ScheduleDateRulePage.kt:437` 写死「已启用/已停用」 | **已修（本轮）** | 换成官方 `SwitchPreference(title = scheduleDateRuleEnabled)`（="启用"，与 Dart `:328-333` 的开关同义） |
| P2-1 | 导出模型 + 546 行导出 UI 零调用方 | **他人泳道在修（F12）** | 分享链路归 F12；现状仍未接（`grep` 仍 0 生产调用方） |
| P2-2 | `TaskStrings` 声称「有单测对拍」但其实没有 parity 测试 | **已修（本轮）** | 新增 `test/.../pages/task/TaskStringsParityTest.kt`（39 条逐字对拍 + 5 个占位符函数 + 3 个未入 ARB 的量纲键单列）；`TaskStrings.kt` 类注释改成与事实一致 |
| P2-3 | 壳里三个空 lambda（`onCourseFilterClick` 等） | **已修（他人：`b8eb9533` 复刻收口 / `21b29038` 对抗复核）** | `onCourseFilterClick` 已从页面 API 删除（`TaskListPage.kt:97` A11 注释）；壳 HEAD `:704-757` 只剩真回调 |
| P2-4 | 派工大表 ST1「统计仍是空页」与源码不符 | **仍存在（写作用域外）** | 见文末「台账更正请求」：可直接替换的更正文字已写好 |
| P2-5 | `A4-task-list.md` / `B1-exam-service.md` 认领文件过期 | **仍存在（写作用域外）** | 同上，附更正文字 |
| P2-6 | `fc2c4520` / `0f160480` 指向已删除的 `src/composeUi/` | **仍存在（历史事实）** | commit 内容已随 `8929b848` 搬进 `main/`；只能靠台账加注，不能改历史 |
| P2-7 | 壳注释「Kotlin 侧没有导出实现」说得过重 | **仍存在（壳禁碰）** | 已并入壳接线请求里的注释替换建议 |
| P2-8 | 统计设置周报开关失败无提示 | **仍存在 + 壳接线请求** | 壳 HEAD `:913-947` 的 `onWeeklyReportToggle` 没有失败分支；Dart `statistics_settings_screen.dart:85-93` 会弹 `saveFailed` |

**本轮新发现（第一轮没写的，登记但不计入上面计数）**

| 新编号 | 内容 | 级别 | 证据 |
|---|---|---|---|
| N-1 | `charts/SessionCards.kt` 的 `SessionCoverageCard` / `SessionListCard` 两个公开 composable **零调用方**（页面自己内联画了 `CoverageLine`） | P2（死码） | `grep -rn "SessionCoverageCard\|SessionListCard" --include=*.kt android/app/src` 只命中定义处与两行注释；`StatisticsSessionPage.kt:168` 用的是 `viewState.coverageRows` 内联渲染 |
| N-2 | 天气域文件自第一轮后**未再变动** | — | `git log --oneline -3 -- .../pages/weather/` 最新为 `9f19cd26`（早于本轮基线），故第一轮「0 缺陷」结论继续成立 |

---

## 结论（先看这段）

### 审核页面清单（含 commit 号 / 是否在途）

| 族 | 页面 / 文件（相对 `android/app/src/`） | 来源 commit | 入判状态 |
|---|---|---|---|
| 任务 | `composeP1/.../pages/task/TaskListPage.kt`、`AddTaskPage.kt`、`TaskPickerSheets.kt` | `fc2c4520`（实改 `src/composeUi/...`，见 P2-6） | **任务族当前有在途改动**（`?? composeP1/app/TaskHost.kt`、`M ShellPageIndex.kt`、`M TaskPickerSheets.kt`）；本报告对任务的结论**只对 HEAD 成立** |
| 考试 | `composeP1/.../pages/exam/ExamListPage.kt`、`AddExamPage.kt` | `0f160480`（同上，实改 `src/composeUi/...`） | 已提交，入判 |
| 日程 | `main/.../app/ScheduleHost.kt`、`ScheduleItemService.kt`、`TimetableRepository.kt`、`TimetableStore.kt`、`main/.../pages/schedule/ScheduleItemBridge.kt` | `1cfbd360` | 已提交，入判（页面本体 `pages/schedule/**` 一并看） |
| 天气 | `composeP1/.../pages/weather/WeatherCityPickerPage.kt`、`WeatherCityPickerHost.kt` | `cb3cfcc7`（样式）+ 宿主 | 已提交，入判 |
| 统计 | `composeP1/.../pages/statistics/**`（5 页 + 12 图表件）、`main/.../pages/statistics/**` | `4ab773e0`（ST1） | 已提交，入判 |
| live | `composeP1/.../pages/live/DisplaySettingsPage.kt`、`LiveIslandPreview.kt`、`LiveKeepAliveSettingsPage.kt`、`ReminderTimingPage.kt` | `afc3fb34`（样式）+ 宿主 | 已提交，入判 |

### 计数

**P0 4 条 / P1 7 条 / P2 8 条。**

### 两个「钉死」的核心问题（本报告的优先交付）

**① 统计族不是死页（与派工大表 ST1 的说法相反）。**
HEAD `ShellPageIndex.kt:874-910`（`e.statistics`）、`:948-968`（`e.analysis`）、`:972-991`（`e.session`）**三个分支全部**走
`StatisticsFeed.feed(input = StatisticsFeed.Input.fromSnapshot(snapshot), …)`，而 `fromSnapshot` 里
`courses = snapshot.courses`（`StatisticsFeed.kt:143`）——真课表快照，**不是** `emptyList()`。
派工大表 §二 ST1 写的「壳仍喂 `courses = emptyList()`（`:532`/`:545`/`:787`）⇒ 用户打开看到的仍是空页」在 HEAD 上**已不成立**：
`/tmp/shell_head.kt` 的 532/545 行是 `AddCoursePage(...)` 的 `initialCourse` / `courseGroup` 参数，787 行是 `d3.timeSchemes -> TimeSchemeManagementHost(...)` 的注释，**都不含 `emptyList()`**。
⇒ 这一条记为 **P2-4 文档失真**（方向上是「好消息过期了」，但会让下一个接单的人白跑一趟）。

**② 任务族接线是真的；考试族只有一半是真的——`d3.addExam` 是一张彻底死掉的表单。**
- 任务：HEAD `:628-684` 经 `TaskListController`（`TaskListController.kt`，真读 `port.tasks`/`port.courses`，勾完成/删除真写 `TimetableCourseService`）——**D1 通过**。
- 考试列表：HEAD `:845-870` 真读 `repository.exams`、删除真走 `TimetableExamService`——**列表这一半是真的**。
- 考试表单：HEAD `:823-844` `AddExamPage(viewState = AddExamViewState(isEditing = false), …)` + **16 个空回调**——输入名字不上屏、选日期无反应、点保存零动作。而考试列表的两个入口 `onAddExam` / `onOpenExam` 都指向它（`:867`/`:868`）。**P0-1。**

---

## 逐页结论

### 1. 考试 · 新增/编辑考试（`android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/AddExamPage.kt`）

- **D1 接线真实性：有缺陷（P0）。** 壳体在该路由喂空 state + 16 个空 lambda，页面能打开但**任何输入都不进状态**。
  证据（HEAD 原文，`git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt | sed -n '823,844p'`）：

  ```
  823        "d3.addExam" -> AddExamPage(
  824            viewState = AddExamViewState(isEditing = false),
  825            selectedCourse = null,
  826            courseGroupsEmpty = false,
  827            dateDisplayText = "",
  828            locationHintText = "",
  829            onBack = onBack,
  830            onSave = {},
  831            onDelete = {},
  832            onNameChange = {},
  ...
  843            onRemoveCustomReminder = {},
  844        )
  ```

  页面的交互面就是这些回调（`AddExamPage.kt` 签名 21 个参数，其中 16 个是交互回调）：
  `onNameChange: (String) -> Unit` / `onSave: () -> Unit` / `onPickCourse` / `onPickDate` / `onPickStartTime` / `onPickEndTime` / `onLocationChange` / `onSeatChange` / `onNoteChange` / `onReminderPresetChange` / `onAddCustomReminder` / `onEditCustomReminder` / `onRemoveCustomReminder` / `onDelete`。
  ⇒ 用户从考试列表点「+」或点任意一条考试进来，看到的是一张**完全不可输入、保存无反应**的表单。
  对照 Dart `lib/screens/add_exam_screen.dart` 是完整可用表单（同目录，Dart 侧有 `Form`/`FormField` 校验）。
- **D2 功能复刻：有缺陷（同 P0）。** 连「编辑既有考试」也没有：`onOpenExam` 与 `onAddExam` 走同一路由，且 `isEditing = false`、`selectedCourse = null` ⇒ 点已有考试打开的是一张**空白新建表单**，不是该考试的编辑态。
- **D3 文案：未验（页面渲染了，但没有可比较的「已接线状态」）。**
- **D4 分层：有缺陷（P2 形态）。** 模型层 `AddExamModelTest` 的存在给了「考试域有测试」的假安全感，而壳里这一页是死的——正是 rubric D1 点名的「模型层单测全绿、页面照旧死」事故形态。
- **D5 样式：通过。** `pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain exam` → `R2 exam/AddExamPage.kt`、`R5 exam/ExamListPage.kt` 共 2 处，**两者都在基线里且写了例外理由**（`tool/compose_style_baseline/exam.txt` 末两行：`exam/AddExamPage.kt|R2|例外：表单页…`、`exam/ExamListPage.kt|R5|例外：进行中橙标 kLiveOrange / 默认课程蓝 kDefaultAccent 两个固定语义色…`）。
- **D6 测试牙齿：部分通过。** `AddExamModelTest.kt` / `ExamListModelTest.kt` / `ExamStringsParityTest.kt` 存在且断言模型行为；但**没有任何测试覆盖「壳是否把回调接上」**，所以这 16 个空 lambda 全绿通过。
- **缺陷清单**
  - **P0-1**：`d3.addExam` 是死表单（HEAD `ShellPageIndex.kt:823-844`）。建议修法：按 `TimetableExamService` + `AddExamFormReducer`（若缺则补）落地真实宿主，`onOpenExam` 带被点考试 id 进编辑态；补一条「壳→页面回调非空」的守卫或契约测试。

### 2. 考试 · 考试列表（`android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/ExamListPage.kt`）

- **D1 接线真实性：通过（列表）/ 有缺陷（删除失败路径）。**
  HEAD `:845-870`：真读 `repository.exams` + `repository.courses`，`remember(repository) { TimetableExamService(CoursePortExamAdapter(repository)) }`，`observe { tick++ }` 触发刷新。列表本身不是死页。
  但删除是 `onDeleteExam = { examService.deleteExam(it.id) }`（HEAD `:868`），而 `TimetableExamService.deleteExam` 在落盘失败时**上抛异常**：
  `main/.../course/TimetableExamService.kt:125-142`：
  ```
  130        try {
  131            port.persistActiveProfileState()
  132        } catch (e: Exception) {
  133            port.exams = snapshotExams
  134            port.profiles = snapshotProfiles
  135            throw e
  ```
  壳里没有 `runCatching` —— 异常会穿透 Compose 的 `onClick` 回调。**同一份壳文件里任务族正好是反例**（HEAD `:661-668`：`runCatching { taskController.deleteTask(task) }.onFailure { Toast… }`）。
  ⇒ 落盘失败时不是「删不掉」，而是**可能崩**（未捕获异常）。**P1-2。**
- **D2 功能复刻完整度：有缺陷（P1）。** 考试日期串永远缺「第 N 周 · 」前缀。
  HEAD `:858-863`：`ExamListLogic.buildListViewState(exams = …, courses = …, semesterStart = null, now = …)` —— **`semesterStart` 写死 null**。
  模型层判据（`main/.../pages/exam/ExamListModel.kt:131-143`）：
  ```
  131    fun formatExamDate(exam: Exam, semesterStart: LocalDateTime?): String {
  ...
  137        if (semesterStart != null) {
  138            val weekIndex = WeekCalculator.getWeekIndex(date, semesterStart)
  ```
  Dart 原件用的是真开学日（`lib/screens/exam_list_screen.dart:137-141`）：
  ```
  137    final semesterStart = provider.semesterStartDate;
  138    if (semesterStart != null) {
  139      final weekIndex = provider.getWeekIndex(date, semesterStart);
  140      if (weekIndex != null && weekIndex >= 1) {
  141        weekInfo = '${l10n.weekLabel(weekIndex)} · ';
  ```
  ⇒ Dart 显示「第 3 周 · 5月20日 周三」，Compose 只显示「5月20日 周三」。**P1-1。**
- **D3 文案：通过。** `ExamStrings.kt` 76 条 `ArbText` 逐字比对 `lib/l10n/app_zh.arb` **0 处不一致**（比对脚本见「审核方法」）；渲染层中文扫描 `grep -rn '"[^"]*[一-龥]' exam/` **0 命中**。
- **D4 分层：通过。** 渲染层只吃 `ExamListViewState`，排序/文案/倒计时全在 `ExamListLogic`（`ExamListPage.kt:77` 明确写「不做任何业务计算」）。
- **D5 样式：通过**（2 处均基线内，见上）。
- **D6 测试牙齿：通过。** `ExamListModelTest.kt` 断言分组/周次/提醒偏移等行为；认领文件 `B1-exam-service.md` 有咬合探针记录（把回滚删掉 → 两个用例双红）。
- **缺陷清单**
  - **P1-1**：`semesterStart = null` ⇒ 考试日期缺周次前缀（HEAD `:861`；Dart `exam_list_screen.dart:137-141`）。建议：从 `repository.snapshot` 取开学日（`semesterStartEpochDay` 或 `settings.semesterStartDate`）传进去。
  - **P1-2**：删除失败无 `runCatching`/无提示、异常直穿点击回调（HEAD `:868`；`TimetableExamService.kt:135 throw e`）。建议照任务族的 `runCatching + Toast`。
  - **P2-已知差异（不计缺陷）**：Dart 用 `Dismissible` 侧滑删除，Compose 改行尾删除按钮 + 确认弹窗，**已在页面 KDoc 与认领文件登记**（`ExamListPage.kt:79-80`），符合「登记过的偏差」口径。

### 3. 任务 · 任务清单（`android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/TaskListPage.kt`）
> ⚠️ 任务族当前有在途改动（`?? composeP1/app/TaskHost.kt`、`M ShellPageIndex.kt`、`M TaskPickerSheets.kt`、`?? docs/plans/2026-10-29-compose-task-family-audit.md`）。**本节结论只对 HEAD 成立。**

- **D1 接线真实性：通过。** HEAD `:628-684` 经 `TaskListController` 接真仓储：
  ```
  var tick by remember(repository) { mutableStateOf(0) }
  DisposableEffect(repository) { val subscription = repository.observe { tick++ }; onDispose { subscription.close() } }
  val taskController = remember(repository) { TaskListController(repository) }
  ```
  `TaskListController.kt:39-41`：`viewState()` 走 `TaskFilterLogic.buildTaskListViewState(allTasks = port.tasks, courses = port.courses, …)`；
  `:74-81`：`toggleTask` → `TimetableCourseService.toggleTaskCompleted`、`deleteTask` → `TimetableCourseService.deleteTask`（真写库）。
  勾完成/删除失败有 `runCatching + Toast(TaskStrings.saveFailed)`（HEAD `:661-668`）。
  ⇒ 对照认领文件 A4 说的「壳喂 `shellSampleTaskViewState()` 空态 + 6 个空回调」，**HEAD 上已经不成立**（见 P2-5）。
- **D2 功能复刻完整度：通过（已核对项）。** Dart `task_list_screen.dart` 的要素在 Compose 侧都有：三档日期筛选（`:16 enum _TaskDateFilter { all, today, week }` ↔ `TaskDateSegmentedControl`）、课程筛选卡 + 弹层（Dart `:212`/`:285`）、分段（逾期/进行/已完成，Dart `:263-265` ↔ `TaskStrings.taskOverdueSection`/`taskCompletedSection`）、无日期任务提示（Dart `:159-160` ↔ `TaskStrings.taskUndatedHint`/`taskUndatedHintSubtitle`）、空态按筛选区分（Dart `:178-180`）。
- **D3 文案：通过（值对拍）/ 有缺陷（守卫缺失，归 P2）。** `TaskStrings.kt` 42 个常量，其中 39 个键在 ARB 里且**逐字相等（0 处不一致）**；`datePickerYear/Month/Day`（`:65-67`）三个键 **ARB 里没有**（`grep -n "datePicker" lib/l10n/app_zh.arb` 无输出）。
  渲染层中文扫描 `grep -rn '"[^"]*[一-龥]' task/` 只命中两处**纯符号**（`TaskPickerSheets.kt:116 "✓"`、`:227 "−"`），属 rubric 允许的例外。
- **D4 分层：通过。** 页面只吃 `TaskListViewState`，筛选/分组在 `TaskFilterLogic`，写库在 `TimetableCourseService`。
- **D5 样式：通过。** `-Domain task` → `合计：0 处`。
- **D6 测试牙齿：通过。** `TaskListControllerTest.kt` 断言的是行为（`allFilterShowsEveryTask` 等 7 例，`visibleItemCount` 直接数条目）；`AddTaskFormReducerTest.kt` 断言 reducer 输出。A4 认领文件有咬合探针记录（`deleteTask` 改 no-op → 用例红）。
- **缺陷清单**
  - **P2-3**：HEAD 上仍留三处空 lambda：`:646 onCourseFilterClick = {},`、`:729 onPickCourseClick = {},`、`:731 onPickDueDateClick = {},`。前者的真实弹层由页面自己弹（`TaskListPage.kt:157-162` 里先 `onCourseFilterClick()` 再自判 `showCourseFilter = true`），所以**用户可见影响为零**，但按 rubric D1「空 lambda 一个都不许留」仍是债；后两个同理（页面内部弹层）。在途改动已把三者删掉，收敛后消失。
  - **P2-2**：`TaskStrings.kt:4` 声称「逐字对齐 `lib/l10n/app_zh.arb`，**通过单元测试逐条对拍**」，但仓库里**没有** `TaskStringsParityTest`（34 个 `*StringsParityTest.kt` 里没有 task）。注释失实 + 缺守卫。

### 4. 任务 · 添加/编辑任务（`android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/AddTaskPage.kt`、`TaskPickerSheets.kt`）
> ⚠️ 同上，任务族有在途改动；本节只对 HEAD 成立。

- **D1 接线真实性：通过（按 HEAD）。** HEAD `:689-...` 用 `AddTaskFormReducer.initialFromTask / initial / withTitle / withNote / coursePickerOptions / applyPickedCourseOption / withDueDate / withHasDueDate / withCompleted / validate / buildTask` 全链路接上状态机；保存分 `TimetableCourseService.updateTask` / `addTask`；失败按 `TaskFilterLogic.mapSaveError(error)` 三分说法弹 Toast（HEAD `:770-778`），与 Dart `add_task_screen.dart:411-424` 一致。
  唯一的空项是 `:729 onPickCourseClick = {}` / `:731 onPickDueDateClick = {}`（见 P2-3，页面内部弹层，可见影响为零）。
- **D2 功能复刻完整度：通过（已核对项）。** 编辑态载入原值（`initialFromTask(editingTask, taskSnapshot.courses)`）、编辑态才出现删除按钮且删除前弹确认（HEAD `:716-736`，对齐 Dart `_confirmDelete`）、标题必填校验走字段错误（`titleError`）而非 toast。
- **D3 文案：通过。** 渲染层无中文字面量（仅 `TaskPickerSheets.kt` 的两个纯符号）。
- **D4 分层：通过。** 表单状态全在 `AddTaskFormReducer`（模型层），页面只渲染。
- **D5 样式：通过。**
- **D6 测试牙齿：通过。** `AddTaskFormReducerTest.kt`（含 `initialFromTask` 的编辑态契约）、`AddTaskFormReducerEditTest.kt`。
- **缺陷清单**：无独立缺陷（只承接 P2-3）。

### 5. 日程 · 列表与编辑（`main/.../app/ScheduleHost.kt`、`main/.../pages/schedule/**`，commit `1cfbd360`）

- **D1 接线真实性：通过（列表与落盘）/ 有缺陷（失败静默）。**
  `ScheduleHost.kt:39-53`：`remember(repository) { … repository.snapshot }` + `repository.observe { updated -> snapshot = updated }`，`ScheduleListPage(groups = ScheduleItemBridge.buildListGroups(snapshot.scheduleItems, todayIso), …)` —— 真数据。
  保存/删除：HEAD `:586-600`（`d2.scheduleList` 的 `onAdd`/`onEdit`/`onDelete` 都落到 `onOpenPage("d2.addSchedule")` 与 `wiring.deleteScheduleItem`），`d2.addSchedule` 的 `onSave` → `wiring.saveScheduleItem(draft, applyToAll)`（HEAD `:610-615`）；
  `ShellWiring.kt:340-357` 里 `saveScheduleItem` 走 `ScheduleEditDispatcher.save(port = timetable, …)`、`ScheduleItemService` 真正调用 `persistActiveProfileState()`（`ScheduleItemService.kt:409-450`）。
  但**失败是静的**：
  ```
  HEAD 610            onSave = { draft, applyToAll ->
  HEAD 611                if (wiring.saveScheduleItem(draft, applyToAll)) {
  HEAD 612                    wiring.clearScheduleIntent()
  HEAD 613                    onBack()
  HEAD 614                }
  HEAD 615            },
  ```
  `saveScheduleItem` 失败时 `catch { false }`（`ShellWiring.kt:354-356`），壳里没有任何 else 分支 ⇒ 用户点保存、**页面不动、零提示**。
  Dart 两侧都有提示（`lib/screens/add_schedule_item_screen.dart:906-911` 失败弹 `saveFailed`）：
  ```
  906    } catch (_) {
  907      if (!mounted) { return; }
  908      showAppToast(
  909        context,
  910        message: l10n.saveFailed,
  911        kind: AppToastKind.error,
  ```
  而且 Dart 成功后也有成功提示（`:919-925` `existing == null ? l10n.scheduleSavedHint : l10n.scheduleUpdatedHint`），Compose 这边保存成功只是静默 `onBack()`。
  ⇒ 失败零提示 + 成功零确认，两头都缺。**P1-5。**
- **D2 功能复刻完整度：有缺陷（P1，两处自造交互）。**
  「启用日程」这一行：Dart 是官方开关行（`add_schedule_item_screen.dart:471-475`）：
  ```
  471        HyperosSwitchTile(
  472          title: l10n.scheduleEnabledTitle,
  473          subtitle: _enabled ? null : l10n.scheduleDisabledSubtitle,
  474          value: _enabled,
  475          onChanged: (value) => setState(() => _enabled = value),
  ```
  Compose 改成「文字标题 + 一颗会变字的按钮」（`AddScheduleItemPage.kt:333-348`），按钮文字是**写死中文** `"已启用"` / `"已暂停"`。
  日期规则页同病（`ScheduleDateRulePage.kt:428-438`）：标题用 ARB 的 `scheduleDateRuleEnabled`（="启用"，ARB `:6161`）+ 按钮写死 `"已启用"` / `"已停用"`，而 Dart 用的是 `value: enabled` 的开关（`schedule_date_rule_screen.dart:329-332`）。
  ⇒ 违反 R3「官方 preference 优先」精神与 D3「渲染层不许有中文字面量」，且**用户可见**：同一个开关在 Dart 是滑动开关，在 Compose 是一颗按钮，且按钮文字在 ARB 里根本不存在。**P1-6 / P1-7。**
  （分组口径没问题：`ScheduleListGrouping.kt:20-27` 的 `upcoming/past/paused` 与 Dart `schedule_list_screen.dart:33-35` 的 `scheduleUpcomingSection/schedulePausedSection` 对得上。）
- **D3 文案：有缺陷。** 两处写死中文（上条）；`ScheduleStrings.kt` 117 条 `ArbText` 与 ARB **0 处不一致**；`ScheduleListPage.kt:437` 的 `"$date $weekday · $timeSpan"` 只含分隔符 `·`（纯符号，允许）。
- **D4 分层：通过。** `ScheduleItemBridge`（`main/.../pages/schedule/ScheduleItemBridge.kt`）承担 core↔UI 的纯转换并被宿主真引用；分组在 `ScheduleListGrouping`；写库在 `ScheduleItemService`。宿主层 KDoc 还明确写了「提醒通知调度属 Phase 4，本层不假装会弹提醒」——诚实。
- **D5 样式：通过。** `-Domain schedule` → `合计：0 处`。
- **D6 测试牙齿：通过。** `ScheduleListGroupingTest.kt`、`ScheduleDateRuleModelTest.kt`、`ScheduleQuickPresetsTest.kt`、`ScheduleStringsParityTest.kt`；`ScheduleItemServiceTest.kt` 321 行（`1cfbd360` 自带）。
- **缺陷清单**
  - **P1-5**：保存/删除**失败零提示、成功零确认**（HEAD `:610-621`；`ShellWiring.kt:354-356` 返回 false 后无 else；Dart `add_schedule_item_screen.dart:906-911` 失败弹 `saveFailed`、`:919-925` 成功弹 `scheduleSavedHint`/`scheduleUpdatedHint`）。建议：false 时弹 `ScheduleStrings` 的保存失败提示；成功时补 `scheduleSavedHint` / `scheduleUpdatedHint`。
  - **P1-6**：`AddScheduleItemPage.kt:346` 写死 `"已启用"/"已暂停"`，且以按钮替代 Dart 的 `HyperosSwitchTile`。
  - **P1-7**：`ScheduleDateRulePage.kt:437` 写死 `"已启用"/"已停用"`，同上。

### 6. 天气 · 选择城市（`composeP1/.../pages/weather/WeatherCityPickerPage.kt` + `WeatherCityPickerHost.kt`）

- **D1 接线真实性：通过。** `WeatherCityPickerHost.kt:117-128` 把真实 `WeatherProvider` 接上：搜索 `provider.searchLocations(trimmed)`（联网地理编码）、点选 `provider.setLocation(location)` 后 `onBack()`、定位权限走 `rememberLauncherForActivityResult(RequestMultiplePermissions)` + `provider.locateCurrentPosition()`、错误经 `locationFailureText(provider.lastLocateFailure)` 上屏。壳侧 HEAD `:1323-1326` 传的是 `wiring.weather`（**同一个 provider 实例**，`:252` 注释说明「设置页、选城页、课表弹层读的都是同一个实例」）。**每个能点的东西都有落点。**
- **D2 功能复刻完整度：通过。** 防抖 400ms、最少 2 字，与 Dart 逐条一致：
  Dart `weather_city_picker_screen.dart:28` `static const Duration _debounceDelay = Duration(milliseconds: 400);`、`:31 static const int _minQueryLength = 2;`
  Compose `WeatherCityPickerHost.kt:57-68`：`delay(400)` 且 `if (trimmed.length < 2) { results = emptyList(); … return@LaunchedEffect }`。
  「当前位置」成功后返回上一页，与 Dart 一致（`Host:77` 注释：「与『点选城市』一致：回到设置页那一行已显示新地点」）。
- **D3 文案：通过。** `WeatherStrings.kt` 41 条 `ArbText` 与 ARB **0 处不一致**；渲染层中文扫描 `weather/` **0 命中**（样式重写 `cb3cfcc7` 没留下字面量）。
- **D4 分层：通过。** 地理/权限/失败枚举都在 `weather/` 模型与平台层，页面只吃 `WeatherCityPickerUiState`。
- **D5 样式：通过。** `-Domain weather` → `合计：0 处`（`cb3cfcc7` 还把 `tool/compose_style_baseline/weather.txt` 的 3 行债删干净了，`git show --stat cb3cfcc7` 可见 `weather.txt | 3 -`）。
- **D6 测试牙齿：通过。** `WeatherCityPickerModelTest.kt` + `WeatherStringsParityTest.kt`。
- **缺陷清单**：**无。**

### 7. 统计 · 主页 / 明细 / 深度分析 / 统计设置（`main/.../pages/statistics/**` + `composeP1/.../pages/statistics/**`，ST1 `4ab773e0`）

- **D1 接线真实性：通过（数据源）/ 有缺陷（三个可见动作没落点）。**
  数据源（**这是本节最要紧的一条**）：HEAD `:874-910`：
  ```
  874        "e.statistics" -> {
  875            val repository = wiring.timetable
  876            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
  877            DisposableEffect(repository) { … repository.observe { snapshot = it } … }
  885            val feedState = remember(snapshot, semesterView, selectedWeek) {
  886                StatisticsFeed.feed(
  887                    input = StatisticsFeed.Input.fromSnapshot(snapshot),
  ```
  `StatisticsFeed.kt:139-154`：`courses = snapshot.courses`、`settings = snapshot.settings`、`currentWeek = snapshot.currentWeek`、`tasks = active?.tasks ?: emptyList()`、`exams = active?.exams ?: emptyList()`。
  ⇒ **courses 不是空表**，课程数、学期进度、周视图、排行全部有真数据。`e.session`（`:972-991`）同源、`e.analysis`（`:948-968`）同源。**统计族不是死页。**
  但三个「点了没反应」：
  ① **分享**：页面顶栏有一个可见的分享图标（`CourseStatisticsPage.kt:134 IconButton(onClick = { if (!isExporting) onOpenShare() })`，只在 `showHeaderActions == true` 即「有数据」时出现，`CourseStatisticsModel.kt:604`），壳里接的是空实现（HEAD `:904 onOpenShare = {},`）。Dart 有真实现：`course_statistics_screen.dart:60 await StatisticsShareService.exportAndShare(...)` + `:147` 分享图标。**P0-4。**
  ② **深度分析点课程名**：`e.analysis` 分支（HEAD `:961-968`）没传 `onOpenCourse`，而页面签名默认就是空实现（`StatisticsAnalysisPage.kt:65 onOpenCourse: (String) -> Unit = {},`，`:141 AnalysisCardRole.RANKING -> RankingRows(viewState, onOpenCourse)`）。Dart 会进编辑页（`statistics_analysis_screen.dart:132` → `:190 void _openCourseEdit(...)` → `:199 Navigator.push(...)`）。**P1-3。**
  ③ **单节课提醒**：Dart 用真设置构造 `reminderKeys`（`statistics_session_screen.dart:68-69 for (final entry in provider.settings.classReminders)`），Compose 壳没传 ⇒ 走默认 `reminderKeys: Set<String> = emptySet()`（`StatisticsFeed.kt:216`），`CourseSessionStatsCalculator` 拿到的提醒集合恒空 ⇒ 每节课的「已设提醒」显示不出来。**P1-4。**
     补充核实（避免冤枉交付方）：Kotlin 侧压根**没有** `classReminders` 这个字段——`grep -rn "classReminders" --include=*.kt android/app/src/main` 只命中 `StatisticsFeed.kt:61` 的一句注释，`core/TimetableSettings.kt` 里没有该字段。所以这**不是「壳漏传一个已有字段」，而是「设置族字段整体没移植」**；交付方已在 `StatisticsFeed.kt:61` 的诚实清单里写明「快照不含该键（属设置族/通知族，尚未接）…计数恒 0」。仍按 D2 功能缺口记 P1（Dart 有、Compose 没有），但**不算隐瞒**。
- **D2 功能复刻完整度：另有 P2（导出层）。** 导出这一块其实**模型层和渲染层都写了**：`charts/ExportModels.kt`（`ExportDocumentModel/ExportSheetModel/ExportBrandModel/ExportRankingModel`，286 行）+ `charts/StatisticsExportCards.kt`（546 行，5 个公开 composable）。但**没有任何生产调用方**：
  ```
  $ grep -rn "StatisticsExportDocument\|StatisticsExportSheetContent\|QrCodeCanvas\|StatisticsExportCourseRanking" --include=*.kt android/app/src | grep -v "charts/StatisticsExportCards.kt"
  (无输出)
  ```
  `ExportModels` 只被 `StatisticsExportCards.kt` 自己和 `ExportModelsTest.kt` 引用。⇒ 约 830 行「导出 UI + 模型」是死的，而用户能点的分享按钮接的是 `{}`。**P2-1**，并让壳里那句注释（HEAD `:900-903`「Kotlin 侧没有『统计图导出并分享』的实现」）**说得过重**——图形卡是有的，缺的只是「光栅化 + 系统分享适配器」。**P2-7。**
- **D3 文案：通过。** `StatisticsStrings.kt` 113 条 + `StatisticsExtStrings.kt` 28 条 `ArbText`，与 ARB **0 处不一致**；渲染层中文扫描只命中纯符号（`charts/RatioAndCompareCards.kt:209 "—"`、`CourseStatisticsPage.kt:658 "★"`、`:1069 "‹"`、`:1079 "›"`），属允许例外。
- **D4 分层：有缺陷（导出层摆设）。** 除导出件外，`CourseStatisticsModel`（`CourseStatisticsLogic.buildViewState`）、`StatisticsSessionModel`、`StatisticsAnalysisModel`、`StatisticsSettingsModel`、`chart` 各模型都被渲染层真引用（`CourseRankingModel/WeekStatsModel/TimeUtilizationModel/VenueStatsModel/OverviewModel/DataStoryModel` 逐一 grep 均有渲染层引用）。
- **D5 样式：通过。** `-Domain statistics` → `合计：0 处`。
- **D6 测试牙齿：通过。** `StatisticsFeedTest.kt` 25 例，注释里明确写了咬合探针的靶点（`:81 「咬合探针打的就是这条：把 fromSnapshot 改回写死演示课程，『0 门课』立刻变成 3 门。」`）；另有 `CourseStatisticsModelTest`、`StatisticsAnalysisModelTest`、`charts/*Test`（7 个）、`StatisticsStringsParityTest`、`StatisticsExtStringsParityTest`。
- **缺陷清单**
  - **P0-4**：统计主页分享图标点了没反应（HEAD `:904`；`CourseStatisticsPage.kt:134`；Dart `course_statistics_screen.dart:60/147`）。按 rubric P0「点了没反应」判；**交付方已在注释里如实登记为链缺口、没有造假动作**（这点值得肯定，但用户侧仍是可见缺陷）。
  - **P1-3**：深度分析排行点课程名没反应（HEAD `:961-968` 未传 `onOpenCourse`；`StatisticsAnalysisPage.kt:65` 默认空；Dart `statistics_analysis_screen.dart:190-199`）。
  - **P1-4**：单节课明细的「已设提醒」恒 0（`StatisticsFeed.kt:216` 默认 `emptySet()`；根因是 Kotlin `core/TimetableSettings.kt` 没有 `classReminders` 字段——`grep` 全仓仅命中 `StatisticsFeed.kt:61` 注释；Dart `statistics_session_screen.dart:68-69`）。交付方已在诚实清单登记，属**字段未移植**而非漏传。
  - **P2-1**：导出模型 + 546 行导出 UI 零调用方（死层）。
  - **P2-7**：壳注释「Kotlin 侧没有导出实现」不准确（缺的是适配器，不是全部）。
  - **P2-8**：`e.statisticsSettings` 的周报开关失败无提示。HEAD `:916-946` 里 `onWeeklyReportToggle` 只调 `WeeklyReportScheduler.scheduleNext(...)` / `cancel(...)`，没有结果判断与 Toast；Dart `statistics_settings_screen.dart:91 message: l10n.saveFailed` 有失败提示。
  - **P2-4**：派工大表 ST1 与 HEAD 不符（见「结论 · ①」）。

### 8. live · 显示设置（`composeP1/.../pages/live/DisplaySettingsPage.kt`，壳 HEAD `:1280-1282`）

- **D1 接线真实性：有缺陷（P0）。** 三个入口全部挂到「便捷重载」，而这个重载把状态关在页面内的 `remember` 里、且所有外部回调走默认值：
  HEAD `:1280-1282`：
  ```
  1280        "j.live" -> DisplaySettingsPage(forDuringEnd = false, onBack = onBack)
  1281        "j.displayBefore" -> DisplaySettingsPage(forDuringEnd = false, onBack = onBack)
  1282        "j.displayDuring" -> DisplaySettingsPage(forDuringEnd = true, onBack = onBack)
  ```
  被调用的重载（`DisplaySettingsPage.kt:523-548`）：
  ```
  524    @Composable
  525    fun DisplaySettingsPage(
  526        forDuringEnd: Boolean = false,
  527        onBack: () -> Unit,
  528        initialState: LiveDisplayState = LiveDisplayState(),
  529        onPickImage: (LiveImagePickTarget) -> String? = { null },
  530        onOpenDoNotDisturbAccess: () -> Unit = {},
  531        onStagePreviewStart: () -> Unit = {},
  532        onStagePreviewStop: () -> Unit = {},
  533    ) {
  534        var state by remember { mutableStateOf(initialState) }
  ```
  ⇒ ① 任何开关/滑杆/下拉只改内存态，**退出页面即还原**（没有落盘、没有读现存设置）；
  ② 选图片恒返回 `null`（`onPickImage = { null }`）⇒ 岛上图标/标签图选不了；
  ③ 「去开启免打扰权限」=`{}` ⇒ 点了没反应；
  ④ 「速览」按钮只翻一个局部布尔（`previewActive`），`onStagePreviewStart/Stop` 都是 `{}` ⇒ 不会真的弹岛。
  Dart 三条全是真功能：自动保存 `live_settings_subpages.dart:1246-1251`（`_enqueuePersist` → `_saveQueue…then((_) => _persistDraft(next))`）、速览会起真会话并退后台（`:409-470`）。
- **D2 功能复刻完整度：有缺陷（同 P0-2）。** 除此之外，页面本体版式是 1:1 重建的（`afc3fb34` 清空了 live 域 11 行样式债），`forDuringEnd` 两支、岛预览、字段重复提示（`DisplaySettingsModel.showCourseNameDuplicatedHint` 等）都在。
- **D3 文案：通过。** `DisplaySettingsStrings.kt` 120 条 `ArbText` + `LiveStrings.kt` 34 条 + `LiveKeepAliveStrings.kt` 12 条，与 ARB **0 处不一致**；渲染层中文扫描只命中 `LiveIslandPreview.kt:389` 的全角括号包装（`"${line.text}（$unfilledSuffix）"`），而 `unfilledSuffix` 本身来自 ARB（`DisplaySettingsStrings.kt:123 liveExpandedDetailUnfilledSuffix`），括号属纯符号 ⇒ 不算缺陷。
- **D4 分层：通过。** 所有判断都走 `DisplaySettingsModel`（`LiveDisplayState` 数据类、`shouldDimStageText`、`islandCourseName` 等），页面只渲染。
- **D5 样式：通过。** `-Domain live` → `合计：0 处`（`afc3fb34` 已把 `tool/compose_style_baseline/live.txt` 的 11 行删净）。
- **D6 测试牙齿：通过（但只到模型层）。** `DisplaySettingsModelTest.kt`、`LiveIslandPreviewModelTest.kt`、`DisplaySettingsStringsParityTest.kt`、`LiveStringsParityTest.kt` 都在，断言的是模型判据；**没有一条测试能发现「壳没把状态接出去」**——这正是它全绿而页面不可用的原因。
- **缺陷清单**
  - **P0-2**：显示设置的全部改动不落盘、图片选不了、免打扰跳转与速览都是空实现（HEAD `:1280-1282` + `DisplaySettingsPage.kt:525-534`；Dart `live_settings_subpages.dart:1246-1251`）。

### 9. live · 提醒时机（`composeP1/.../pages/live/ReminderTimingPage.kt`，壳 HEAD `:1283`）

- **D1 接线真实性：有缺陷（P0）。** HEAD `:1283 "j.reminderTiming" -> LiveReminderTimingPage(onBack = onBack)` 命中的是状态化重载，`onPersist` 默认空：
  ```
  ReminderTimingPage.kt:232    fun LiveReminderTimingPage(
  ReminderTimingPage.kt:233        onBack: () -> Unit,
  ReminderTimingPage.kt:234        initialState: ReminderTimingState = ReminderTimingState(),
  ReminderTimingPage.kt:235        onPersist: (ReminderTimingState) -> Unit = {},
  ReminderTimingPage.kt:236    ) {
  ReminderTimingPage.kt:237        var state by remember { mutableStateOf(ReminderTimingLogic.sanitize(initialState)) }
  ReminderTimingPage.kt:244                onPersist(sanitized)
  ```
  ⇒ 「课前几分钟提醒 / 下课前几秒」改完不落盘、也不从现有设置读初值。Dart 是真读真存（`live_settings_subpages.dart:99-110`：`_draft = context.read<TimetableProvider>().settings`、`_enqueuePersist(_draft)`；`:259 _persistDraft`）。**P0-3。**
- **D2：** 页内控件与选项集与 Dart 一致（Dart `:83-86 _beforeClassMinutesOptions [1,5,10,15,20,30,40,50,60]` / `_endSecondsOptions [15,30,45,60,90]`）；缺陷只在持久化。
- **D3 文案：通过。** `ReminderTimingStrings.kt` 19 条 `ArbText`，与 ARB **0 处不一致**；渲染层中文 **0 命中**。
- **D4 分层：通过。** 清洗走 `ReminderTimingLogic.sanitize`。
- **D5 样式：通过。**
- **D6 测试牙齿：通过（模型层）。** `ReminderTimingModelTest.kt`、`ReminderTimingStringsParityTest.kt`。
- **缺陷清单**
  - **P0-3**：提醒时机不落盘（壳 HEAD `:1283` + `ReminderTimingPage.kt:232-245`）。建议：壳里读 `wiring.timetable.snapshot.settings` 构造初值，`onPersist` 走仓储写入口。

### 10. live · 保活设置（`composeP1/.../pages/live/LiveKeepAliveSettingsPage.kt`，壳 HEAD `:1290-1330`）

- **D1 接线真实性：通过。** 壳里带真实落点：
  `initialHideFromRecents` 读 `SharedPreferences("native_runtime_prefs").getBoolean("hide_from_recents", false)`；
  `onPersistHideFromRecents` = 写同一份 prefs + `am?.appTasks?.forEach { it.setExcludeFromRecents(hidden) }`；
  `onProbeAccessibilityEnabled = { KeepAliveAccessibilityStatus.isEnabled(context) }`（读平台真值，不是常量）；
  `onOpenAccessibilitySettings` = 真 `startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))`。
  与注释里的自述一致（HEAD `:1284-1299`）。
- **D2/D3/D4/D5/D6：通过。** `LiveKeepAliveStrings.kt` 12 条 `ArbText` 与 ARB **0 处不一致**；渲染层中文 0 命中；`LiveKeepAliveModelTest.kt` + `LiveKeepAliveStringsParityTest.kt` 存在；`-Domain live` 样式 0 处。
- **缺陷清单**：**无。**（这是 live 族里唯一接全的一页。）

---

## 与既有审核文档 / 台账不一致的地方（3 条，均归 P2）

1. **P2-4 派工大表 §二 ST1**（`docs/plans/2026-10-28-compose-master-dispatch-table.md:80`）写：
   「壳 `ShellPageIndex.kt` 仍喂 `courses = emptyList()`（`:532` / `:545` / `:787`），`e.session` 也是 `courseNames = emptyList()`…`4ab773e0` **只改了模型层**…**用户打开统计看到的仍是空页**」。
   **与 HEAD 不符**：三个统计分支都走 `StatisticsFeed.Input.fromSnapshot(snapshot)`（HEAD `:874-910`/`:948-968`/`:972-991`）；引用的 532/545/787 行现在是 `AddCoursePage` 的参数与 `d3.timeSchemes` 的注释（`/tmp/shell_head.kt:530-534`、`:544-547`、`:785-790`），**不含 `emptyList()`**。
2. **P2-5 认领文件过期**：
   - `.agents/compose-phase3/claims/A4-task-list.md`「状态」行写「**壳接线未做**（属 ShellPageIndex…）」+ 诚实清单 1「壳 `d2.taskList` 未接线：`ShellPageIndex.kt:574` 仍喂空态」。**与 HEAD 不符**：HEAD `:628-684` 已经是 `TaskListController` 真接线。
   - `.agents/compose-phase3/claims/B1-exam-service.md` 诚实清单 1「壳 `d3.addExam` / `d3.examList` 未接线：仍喂演示数据」。**与 HEAD 部分不符**：`d3.examList` 已接真仓储（HEAD `:845-870`）；而 `d3.addExam` **仍然死着**，但原因不是「喂演示数据」，是**16 个空回调**（P0-1）——照原文档读会以为两页同源、修一处即可。
3. **P2-6 提交溯源失真**：`git show --stat fc2c4520` 与 `0f160480` 的落点都是
   `android/app/src/composeUi/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt`，
   而 `android/app/src/composeUi/` 已被 `8929b848`（「删除 composeUi / composeP1 两个迁移期变体」）整体删除；
   `find android -name ShellPageIndex.kt` 现在只剩 `main/.../pages/` 下那个。
   ⇒ 用这两个 commit 号在 HEAD 上**追不到**对应代码（内容随 `8929b848` 搬进了 main，但历史断开）。审核/回溯时会误判「这个提交改的文件不存在」。

---

## 在途改动（他人，不入判）

`git status --porcelain` 共 68 项（Lead 20:43 通报时为 68）。与本次审核范围相关的：

| 文件 | 状态 | 说明 |
|---|---|---|
| `android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TaskHost.kt` | `??` 新增（20:38） | 任务清单宿主，抽出来给「路由 + 底栏 tab」两处复用 |
| `android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt` | `M`（+41/−60） | `d2.taskList` 改为 `TaskListHost(...)`；删掉 `onCourseFilterClick/onPickCourseClick/onPickDueDateClick` 三个空 lambda；`d1.addCourse` 补 `initialWeek`（来源周次） |
| `android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt` | `M` | 配合上述 `pendingEditWeek` |
| `android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt` | `M` | 底栏 tab 侧接线 |
| `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/TaskPickerSheets.kt` | `M` | 任务族 |
| `docs/plans/2026-10-28-task-family-audit.md`、`docs/plans/2026-10-29-compose-task-family-audit.md` | `??` | 他人正在写/刚写的审核文档，未入判 |

**本报告对任务族的全部结论（第 3、4 节）只对 HEAD `3f3b7354` 成立**；在途改动确实在修 P2-3（三个空 lambda）与 D2 的来源周次缺口，但那属他人交付，我不代为判定。

---

## 我没能验的

1. **真机行为一律未验**（rubric 明确要求真机/用户点击，我只做只读取证）。具体牵连：分享按钮、速览弹岛、免打扰跳转、无障碍跳转、删除考试失败时的实际表现（是否真的崩）、定位权限流。
2. **未跑 Gradle / 未跑 `scripts/test-kotlin-module.ps1`**（硬约束）。所以「单测绿」不是我验的，我只核对了测试文件存在与其断言对象；D6 的判定依据是**读源码**（断言内容 + 咬合探针注释/认领记录），不是运行结果。
3. **统计数字的正确性**未验：`StatisticsFeed` 是否把 `semesterStartEpochDay` / `currentWeek` 换装正确、`CourseSessionStatsCalculator` 的课次口径与 Dart 是否逐节一致——这要逐函数对拍 `lib/domain/` 的统计实现，属另一批工作量（我验的是「数据源是真快照」这一层）。
4. **`d3.locationMatch`（`composeP1/.../pages/time_scheme/LocationTimeMatchPage.kt`）也是死页**（HEAD `:814-822`：`onCreateGroup = {}` / `onEditGroup = {}` / `onDeleteGroup = {}` / `onToggleGroup = { _, _ -> }` / `onApplyActive = {}`，`model = LocationTimeMatchModel()` 空构造）。它**不在我的审核对象清单里**（属作息与考试族，另有 `2026-10-29-compose-time-scheme-audit.md`），且 `onOpenLocationEntry` 从时间模板页可达（HEAD `:794`）。**转给该族审核员复核**，本报告不计入我的 P0 计数。
5. 任务族 D2 我只核对了「筛选三档 / 课程筛选 / 三段分组 / 无日期提示 / 空态分支 / 行内动作」这些**结构性**要素，没有逐像素对版式；TaskPickerSheets 的两个子弹层交互细节（步进器边界、选择回显）只读未测。

---

## 审核方法（跑了哪些命令、扫了哪些文件、多少行）

**范围与基线**
- `git rev-parse HEAD` → `3f3b7354d093ce83d78853660c59676f8518ed19`；`git status --porcelain | wc -l` → `68`。
- `git show --stat fc2c4520 / 0f160480 / 1cfbd360 / cb3cfcc7 / afc3fb34 / 4ab773e0` 逐个定位实际文件（并发现前两个落在已删除的 `src/composeUi/`）。
- `git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt > /tmp/shell_head.kt`（1513 行）——**本报告全部壳行号引自这个副本**；再 `git diff HEAD -- …/ShellPageIndex.kt` 隔离在途改动（只动了 `d1.addCourse` / `d2.taskList` / `d2.addTask` / `k.conflict` 四处）。

**读了多少**
- 壳体：`ShellPageIndex.kt` 1513 行（重点读 `:580-620`、`:628-790`、`:814-1000`、`:1280-1330`）+ `ShellWiring.kt`（`:330-380` 逐行）。
- Kotlin 模型/宿主：`TaskListController.kt`（80 行全读）、`TaskModel.kt`（view state 段）、`StatisticsFeed.kt`（317 行全读）、`CourseStatisticsModel.kt`（`showHeaderActions` 段）、`StatisticsAnalysisPage.kt`（签名 + 调用点）、`CourseStatisticsPage.kt`（顶栏 action 段）、`ExamListModel.kt`（`formatExamDate` 全读）、`TimetableExamService.kt`（`deleteExam` 全读）、`ScheduleHost.kt`（头 50 行）、`ScheduleItemBridge.kt`、`ScheduleListGrouping.kt`、`DisplaySettingsPage.kt`（两个重载 + `:500-560`）、`ReminderTimingPage.kt`（`:224-250`）、`LiveIslandPreview.kt`（`:375-400`）、`AddExamPage.kt`（签名）、`AddScheduleItemPage.kt:330-360`、`ScheduleDateRulePage.kt:405-445`、`TaskListPage.kt`（`:140-184`、`:295-329`）、`ExamListPage.kt:72-92`。
- Strings / 文案：`TaskStrings.kt` 75 行、`ExamStrings.kt`、`ScheduleStrings.kt`、`DisplaySettingsStrings.kt`、`ReminderTimingStrings.kt`、`LiveStrings.kt`、`LiveKeepAliveStrings.kt`、`StatisticsStrings.kt`、`StatisticsExtStrings.kt`、`ChartsStrings.kt`、`WeatherStrings.kt`。
- Dart 对照：`lib/screens/live_settings_subpages.dart`（2252 行，读 `:72-120`、`:288-330`、`:446-540`）、`exam_list_screen.dart`（`:110-148`、`:147-160`）、`task_list_screen.dart`（`:16-80`、`:159-212`、`:263-300`）、`schedule_list_screen.dart`、`add_schedule_item_screen.dart`（`:64-120`、`:471-475`）、`schedule_date_rule_screen.dart:329-332`、`statistics_analysis_screen.dart`（`:132`、`:190-199`）、`statistics_session_screen.dart:66-82`、`course_statistics_screen.dart`（`:9`、`:60`、`:147`）、`statistics_settings_screen.dart`（112 行全读）、`weather_city_picker_screen.dart`（`:28`、`:31`、`:47-64`）、`lib/l10n/app_zh.arb`（`schedulePausedSection` `:3507`、`scheduleDateRuleEnabled` `:6161`、`scheduleEnabledTitle` `:6336`、`scheduleDisabledSubtitle` `:6337`）。
- 文档（只作线索，逐条回源码复核）：`docs/plans/2026-10-28-compose-master-dispatch-table.md:80/102`、`docs/plans/2026-10-29-quality-audit/_RUBRIC.md`、`.agents/compose-phase3/claims/A4-task-list.md`、`B1-exam-service.md`。

**关键命令与真实输出**

```bash
# 1) 统计族到底是死页还是活页（本报告核心结论 ①）
$ git show HEAD:.../ShellPageIndex.kt | sed -n '874,900p'
"e.statistics" -> {
    val repository = wiring.timetable
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    …
    val feedState = remember(snapshot, semesterView, selectedWeek) {
        StatisticsFeed.feed(input = StatisticsFeed.Input.fromSnapshot(snapshot), …)

$ grep -n "courses = snapshot.courses" main/.../pages/statistics/StatisticsFeed.kt
143:                    courses = snapshot.courses,

# 2) 文档引用的三行现在是什么
$ sed -n '530,534p;544,547p;785,790p' /tmp/shell_head.kt
AddCoursePage( / initialCourse = wiring.pendingEditCourse, / courseGroup = wiring.pendingEditGroup,
val section = sections.getOrNull(index) / AddCourseEntryClock(startTime = …)
"d3.timeSchemes" -> TimeSchemeManagementHost(

# 3) 文案逐字对拍（六个域一次性跑）
$ python -c "<解析 ArbText/const 与 app_zh.arb 逐键比对>"
ExamStrings.kt        arbtext= 76 const=  0 mismatch=0
DisplaySettingsStrings.kt arbtext=120 const= 0 mismatch=0
LiveKeepAliveStrings.kt   arbtext= 12 const= 0 mismatch=0
LiveStrings.kt            arbtext= 34 const=  5 mismatch=0
ReminderTimingStrings.kt  arbtext= 19 const=  0 mismatch=0
ScheduleStrings.kt        arbtext=117 const=  0 mismatch=0
StatisticsExtStrings.kt   arbtext= 28 const=  0 mismatch=0
StatisticsStrings.kt      arbtext=113 const=  0 mismatch=0
TaskStrings.kt            arbtext=  0 const= 42 mismatch=0
WeatherStrings.kt         arbtext= 41 const=  0 mismatch=0
# TaskStrings 单独再比一次：42 个常量，39 个键在 ARB 且 0 处不一致，3 个键不在 ARB：
#   ('datePickerYear', '年') ('datePickerMonth', '月') ('datePickerDay', '日')

# 4) 渲染层中文字面量（剔除纯注释行）
$ for d in task exam statistics weather live schedule; do grep -rn '"[^"]*[一-龥]' $d/ | awk -F: '…跳过 // 与 * 开头行…'; done
task/TaskPickerSheets.kt:116:  text = "✓",                     ← 纯符号，允许
task/TaskPickerSheets.kt:227:  TextButton(text = "−", …)       ← 纯符号，允许
statistics/charts/RatioAndCompareCards.kt:209: "—"             ← 纯符号
statistics/CourseStatisticsPage.kt:658/1069/1079: "★" "‹" "›"  ← 纯符号
live/LiveIslandPreview.kt:389: "${line.text}（$unfilledSuffix）" ← 括号为符号，suffix 来自 ARB
schedule/AddScheduleItemPage.kt:346: if (enabled) "已启用" else "已暂停"   ← 缺陷 P1-6
schedule/ScheduleDateRulePage.kt:437: if (enabled) "已启用" else "已停用"  ← 缺陷 P1-7
schedule/ScheduleDateRulePage.kt:417: "✓"                       ← 纯符号
schedule/ScheduleListPage.kt:437: "$date $weekday · $timeSpan"  ← 仅分隔符

# 5) 导出层是否死代码
$ grep -rn "StatisticsExportDocument\|StatisticsExportSheetContent\|QrCodeCanvas\|StatisticsExportCourseRanking" --include=*.kt android/app/src | grep -v "charts/StatisticsExportCards.kt"
（无输出）
$ grep -rl "ExportDocumentModel\|ExportBrandModel" --include=*.kt android/app/src
…/charts/StatisticsExportCards.kt
…/charts/ExportModels.kt
…/test/.../charts/ExportModelsTest.kt      ← 只有自己、渲染件自身、自己的测试
$ wc -l .../charts/StatisticsExportCards.kt
546

# 6) 样式（D5）六域
$ for d in task statistics live weather schedule exam; do pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain $d; done
task:        合计：0 处
statistics:  合计：0 处
live:        合计：0 处
weather:     合计：0 处
schedule:    合计：0 处
exam:        合计：2 处   ← R2 AddExamPage.kt / R5 ExamListPage.kt，均在基线且写了例外理由
$ cat tool/compose_style_baseline/exam.txt
exam/AddExamPage.kt|R2|例外：表单页（有限输入控件 + 焦点/键盘联动）…
exam/ExamListPage.kt|R5|例外：进行中橙标 kLiveOrange / 默认课程蓝 kDefaultAccent 两个固定语义色…

# 7) 测试资产清点（D6 的存在性）
$ find android/app/src/test -path "*task*" -o -path "*exam*" -o -path "*statistics*" -o -path "*live*" -o -path "*weather*" -o -path "*schedule*"
task: TaskListControllerTest / TaskModelTest / AddTaskFormReducerEditTest
exam: AddExamModelTest / ExamListModelTest / ExamStringsParityTest
statistics: StatisticsFeedTest(25 例) / CourseStatisticsModelTest / StatisticsAnalysisModelTest / charts 7 个 / 2 个 parity
live: DisplaySettingsModelTest / LiveIslandPreviewModelTest / LiveKeepAliveModelTest / ReminderTimingModelTest / 4 个 parity
weather: WeatherCityPickerModelTest / WeatherStringsParityTest
schedule: ScheduleListGroupingTest / ScheduleDateRuleModelTest / ScheduleQuickPresetsTest / ScheduleStringsParityTest
$ find android/app/src/test -name "*StringsParity*" | wc -l
34        ← 里面有 exam/live/weather/schedule/statistics/wear… 但**没有 task**
```

**没做的事（明确声明）**：未改任何 `.kt` / `.dart` / `.arb` / 构建文件；未 `git add` / `commit`；未跑 Gradle、未跑 `scripts/test-kotlin-module.ps1`；未碰他人在途文件。本报告是本会话唯一写入的文件。

---

# 第二轮（FY5）：本轮实际改了什么

基线 HEAD `bf0e5a57`。写作用域按 Lead 裁决收窄：**不碰** `pages/exam/**`（F10）、**不碰**统计分享链路（F12）、不碰壳与别的域。

| # | 文件（相对 `android/app/src/`） | 性质 | 改了什么 |
|---|---|---|---|
| 1 | `composeP1/.../pages/schedule/AddScheduleItemPage.kt` | 改 | 「启用日程」行：`文字 + MiuixActionButton("已启用"/"已暂停")` → 官方 `SwitchPreference(title, summary, checked, onCheckedChange)`；清除写死中文（P1-6） |
| 2 | `composeP1/.../pages/schedule/ScheduleDateRulePage.kt` | 改 | 启用开关改成 `SwitchPreference(title = scheduleDateRuleEnabled)`；清除写死中文（P1-7） |
| 3 | `composeP1/.../pages/schedule/ScheduleEditHost.kt` | **新增** | 日程编辑页宿主：拿 `(draft, applyToAll) -> Boolean` / `(item, applyToAll) -> Boolean`，**失败弹失败提示且不关页、成功弹成功提示再关页**（P1-5） |
| 4 | `main/.../pages/statistics/StatisticsSessionModel.kt` | 改 | `coverageRows(stats, reminderDataAvailable = true)` + `viewState(..., reminderDataAvailable)`：拿不到提醒数据就**不画「设过提醒」行**（P1-4） |
| 5 | `main/.../pages/statistics/StatisticsFeed.kt` | 改 | `sessionViewState` / `feed` 的 `reminderKeys` 由 `Set<String> = emptySet()` 改 `Set<String>? = null`（null = 拿不到），并把 `reminderDataAvailable = reminderKeys != null` 传给模型（P1-4） |
| 6 | `composeP1/.../pages/statistics/StatisticsAnalysisPage.kt` | 改 | `onOpenCourse` 改可空 `((String) -> Unit)? = null`；`RankingRows` **只有传了处理函数才加 `clickable`**，并真正调用 `onOpenCourse(row.first)`（P1-3，页面侧） |
| 7 | `main/.../pages/task/TaskStrings.kt` | 改 | 类注释与日期量纲键注释改成与事实一致（不再声称「已有单测对拍」而实际没有）（P2-2） |
| 8 | `test/.../pages/task/TaskStringsParityTest.kt` | **新增** | 39 条「ARB 键 → 屏上值」逐字对拍 + 5 个占位符函数比对 + 3 个未入 ARB 的量纲键单列并断言「ARB 里确实还没有」（P2-2） |
| 9 | `test/.../pages/statistics/StatisticsSessionModelTest.kt` | 改 | 加 2 例：`reminderDataAvailable=false` 只剩两行、`=true` 三行都在（P1-4 的回归网） |
| 10 | `test/.../pages/statistics/StatisticsFeedTest.kt` | 改 | 加 1 例：`feed()` 不传 `reminderKeys` → 2 行；传真键集 → 3 行（钉住「默认不撒谎」） |

**为什么没在页面里直接弹 toast/关页**：`AddScheduleItemPage.onSave` 返回 `Unit`，页面**无法知道**落盘成败；
在页面里弹「已保存」只能靠猜，那就是 rubric 判 P0 的「假成功」。所以成败判据留在宿主（拿到 `Boolean`），
页面继续只管渲染 —— 这也是 `ScheduleEditHost` 存在的唯一理由。

**验证边界（诚实说明）**：按硬约束**没有跑** Gradle / `test-kotlin-module.ps1`，所以本轮的 Kotlin 改动
**只做过源码级自校验**（导入是否齐全、参数名与既有调用点是否匹配、`grep` 确认旧写法已清零），
**没有编译通过与单测通过的证据**。编译/单测闸门由 Lead 统一跑。

---

# 壳接线请求（`ShellPageIndex.kt` 属 Lead 写作用域，我只给精确代码块）

> 三处都是「分支替换」，不含新增依赖。下面行号是对 HEAD `bf0e5a57` 的 `ShellPageIndex.kt`（1672 行）的定位。

## 请求 1（P1-5）：`d2.addSchedule` 换成 `ScheduleEditHost`（HEAD `:657-681`）

现在（失败静默）：

```kotlin
        "d2.addSchedule" -> AddScheduleItemPage(
            scheduleItem = wiring.pendingScheduleEdit,
            initialDate = wiring.pendingScheduleInitialDate ?: LocalDate.now().toString(),
            occurrenceDate = wiring.pendingScheduleOccurrenceDate,
            onBack = {
                wiring.clearScheduleIntent()
                onBack()
            },
            onSave = { draft, applyToAll ->
                if (wiring.saveScheduleItem(draft, applyToAll)) {
                    wiring.clearScheduleIntent()
                    onBack()
                }
            },
            onDelete = { item, applyToAll ->
                if (wiring.deleteScheduleItem(item, applyToAll)) {
                    wiring.clearScheduleIntent()
                    onBack()
                }
            },
        )
```

改成：

```kotlin
        "d2.addSchedule" -> ScheduleEditHost(
            scheduleItem = wiring.pendingScheduleEdit,
            initialDate = wiring.pendingScheduleInitialDate ?: LocalDate.now().toString(),
            occurrenceDate = wiring.pendingScheduleOccurrenceDate,
            // 成败判据留在宿主：失败要提示且不关页（Dart `add_schedule_item_screen.dart:906-911`）。
            onSave = { draft, applyToAll -> wiring.saveScheduleItem(draft, applyToAll) },
            onDelete = { item, applyToAll -> wiring.deleteScheduleItem(item, applyToAll) },
            onFinish = {
                wiring.clearScheduleIntent()
                onBack()
            },
        )
```

并加一行 import：`import com.mutx163.qingyu.pages.schedule.ScheduleEditHost`
（同文件已有 `import com.mutx163.qingyu.pages.schedule.AddScheduleItemPage`，可原地替换掉它。）

## 请求 2（P1-3）：`e.analysis` 补 `onOpenCourse` 落点（HEAD `:976-999`）

现在（不传 ⇒ 排行行纯展示、不可点）：

```kotlin
            StatisticsAnalysisPage(
                viewState = StatisticsAnalysisModel.viewState(
                    module = wiring.pendingAnalysisModule,
                    courseCount = feedState.courseCount,
                ),
                onBack = onBack,
                // ⚠️ 页面签名里 `onOpenCourse` 的默认实现就是空的（普查第 6 个盲区：
                // 「只扫显式空回调」扫不到签名默认值）⇒ 点课程名进该课明细**尚不可用**。
                // 有意不在这里塞一个空 lambda 冒充「已接」，等明细页选中态可复用后再接。
            )
```

改成（对齐 Dart `statistics_analysis_screen.dart:190-199`：按**课名**找课程 → 打开该课编辑页）：

```kotlin
                onBack = onBack,
                // 排行点课名 → 该课编辑（Dart `_openCourseEdit`：按名字找课程）。
                // 找不到就什么都不做（Dart 也是 `if (course == null) return;`）。
                onOpenCourse = { courseName ->
                    val course = snapshot.courses.firstOrNull { it.name == courseName }
                    if (course != null) {
                        wiring.pendingEditCourse = course
                        wiring.pendingEditGroup = null
                        wiring.pendingAddCourseSeed = null
                        onOpenPage("d1.addCourse")
                    }
                },
```

> 说明：这三行赋值与同文件 `k.conflict` 分支（HEAD `:1370-1376`）的写法一致。
> Dart 还会带 `courseGroup`（`AddCourseScreen(courseGroup:, initialCourse:)`），而 `ShellWiring` 没有
> 「按课程找组」的公开方法，故这里按既有的「不带组」口径走；这条差异已记在本报告里。

## 请求 3（P2-8）：`e.statisticsSettings` 给周报开关补失败提示（HEAD `:913-947`）

`onWeeklyReportToggle` 现在是「调了就当成功」。Dart 的对应实现在 `lib/screens/statistics_settings_screen.dart:81-93`：
`updateSettings` 失败 → 弹 `saveFailed` 并 **return**（不回读成已开启）。最小改法：

```kotlin
                onWeeklyReportToggle = { enabled ->
                    val ok = runCatching {
                        if (enabled) {
                            val now = LocalDateTime.now()
                            val snap = wiring.timetable.snapshot
                            WeeklyReportScheduler.scheduleNext(
                                context = wiring.context,
                                enabled = true,
                                fireAtMillis = WeeklyReportScheduleLogic.nextFireAtMillis(now),
                                title = WeeklyReportScheduleLogic.buildTitle(),
                                body = WeeklyReportScheduleLogic.buildBody(
                                    courses = snap.courses,
                                    currentWeek = snap.currentWeek,
                                    semesterWeekCount = snap.settings.semesterWeekCount,
                                ),
                            )
                        } else {
                            WeeklyReportScheduler.cancel(wiring.context)
                        }
                    }.isSuccess
                    if (!ok) {
                        Toast.makeText(
                            wiring.context,
                            StatisticsStrings.saveFailed.zh,   // ARB `saveFailed` = 「保存失败」
                            Toast.LENGTH_SHORT,
                        ).show()
                    }
                },
```

> `StatisticsStrings` 里若还没有 `saveFailed`，用 `main/.../pages/statistics/StatisticsStrings.kt` 里同名的
> `ArbText("saveFailed", "保存失败")` 新增一条即可（ARB 已有该键，**不算新文案**）。这条改动属统计设置页分支，
> 在 F12 的写作用域边缘，**若 F12 同时改这一支，以 F12 为准**。

---

# ARB 新增请求（Lead 写作用域，我不动 `lib/l10n/app_zh.arb`）

| 建议键名 | 建议中文值 | 现在在哪 | 为什么需要 |
|---|---|---|---|
| `datePickerYear` | `年` | `TaskStrings.kt:65`（`const val`，渲染层常量） | 任务日期滚轮的**量纲标签**，ARB 里没有独立键；现由 `TaskStringsParityTest` 单列钉住，补键后应改成对拍 |
| `datePickerMonth` | `月` | `TaskStrings.kt:66` | 同上 |
| `datePickerDay` | `日` | `TaskStrings.kt:67` | 同上 |

> 三条都是「量纲标签」，与系统日期控件同义；**没有自拟新句式**，只是把已在屏上的三个字纳入 ARB 管辖。
> 六份 ARB（zh / zh_HK / zh_TW / en / ja / ko）都要同步，`gen-l10n` 重跑；`TaskStrings` 改为 `ArbText` 后
> 把 `TaskStringsParityTest.参数未进 ARB 的日期量纲标签` 那条断言翻过来（测试里已写好提示语）。

**本轮没有其它新增文案需求**：日程宿主用的 `saveFailed` / `deleteFailed` / `scheduleSavedHint` / `scheduleUpdatedHint`
都是 ARB 已有键（`app_zh.arb:1068` / `:503` / `:3491` / `:3492`），`ScheduleStrings` 里也已有对应的 `ArbText`。

---

# 台账更正请求（写作用域外，附可直接替换的文字）

## 1. 派工大表 §二 ST1（`docs/plans/2026-10-28-compose-master-dispatch-table.md:80`）

原文结论「壳仍喂 `courses = emptyList()`（`:532`/`:545`/`:787`）⇒ 用户打开统计看到的仍是空页」在 HEAD 上已不成立。
建议把那两行 ⚠️ 换成：

> ✅ **2026-10-29 复核（misc-wiring 第二轮）**：壳 `e.statistics` / `e.analysis` / `e.session` 三个分支已全部走
> `StatisticsFeed.feed(input = StatisticsFeed.Input.fromSnapshot(snapshot), …)`（`ShellPageIndex.kt:874-910` / `:948-968` / `:972-991`），
> `StatisticsFeed.kt:143 courses = snapshot.courses` ⇒ **读真实课表快照，不是空页**。
> 上文引用的 `:532`/`:545`/`:787` 三行现在是 `AddCoursePage` 参数与 `d3.timeSchemes` 注释，**不含 `emptyList()`**。
> 统计族剩余缺口是：分享（F12）、排行点名落点（本轮已修页面侧，待壳接线）、单节课提醒数据（设置族未移植 `classReminders`）。

## 2. 认领文件（`.agents/compose-phase3/claims/A4-task-list.md`、`B1-exam-service.md`）

- `A4-task-list.md`「状态」行与诚实清单 1 说「壳 `d2.taskList` 未接线：`ShellPageIndex.kt:574` 仍喂空态」——
  HEAD `:688-712` 已是 `TaskListHost(repository = wiring.timetable, …)`（真数据、真回调，底栏 tab 与路由同一份接线）。
  建议把该条改：**✅ 2026-10-29 壳已接线（`TaskHost.kt` + `ShellPageIndex.kt:688`），本条已完成**。
- `B1-exam-service.md` 诚实清单 1 说「`d3.addExam` / `d3.examList` 未接线：仍喂演示数据」——
  `d3.examList` 已是真仓储（HEAD `:873-899`）；`d3.addExam` **仍然死着**，但原因不是「喂演示数据」而是
  **16 个空回调**，且已由泳道 F10 接手中（`ExamPickerSheets.kt` / `AddExamFormReducer.kt`）。
  建议改成两条分开写，避免下一个人以为「接一次就两页都好」。

## 3. `fc2c4520` / `0f160480` 的落点

这两个 commit 的 `--stat` 指向 `android/app/src/composeUi/.../ShellPageIndex.kt`，而该目录已被 `8929b848` 整体删除
（内容搬进 `main/`）。建议在台账里加一句：**「2026-10-29 12:46 `8929b848` 之后，2026-10-28 那些指向 `src/composeUi/`
的提交路径在树上已不存在，追代码请看 `src/main/.../pages/`」**，否则回溯时容易误判「这个提交改的文件没了」。

---

# 未修原因（逐条）

| 项 | 为什么不修 |
|---|---|
| P0-1 / P1-1 / P1-2（考试族三条） | Lead 裁决：`pages/exam/**` 与 `d3.addExam` 归泳道 **F10**（对方已在写 `ExamPickerSheets.kt` / `AddExamFormReducer.kt`）。我若再写宿主会与其覆盖 |
| P0-4 / P2-1（统计分享、导出层死码） | Lead 裁决：分享链路归 **F12**。我若动 `CourseStatisticsPage` 的分享入口会与其冲突 |
| P1-3 / P1-5 / P2-8 的**壳部分** | `ShellPageIndex.kt` 在禁碰清单里；已给逐行可替换的代码块（上面三节请求） |
| P1-4 的**根因** | Kotlin `core/TimetableSettings` 没有 `classReminders` 字段，属设置族写作用域（`settings/**` 禁碰）。本轮只做了「拿不到就不画假读数」 |
| P2-4 / P2-5 / P2-6（文档失真） | 三者都在别人写作用域（派工大表、`.agents/` 认领文件、git 历史）。已给可直接粘贴的更正文字 |
| P2-7（壳注释不准确） | 壳禁碰；已并入请求 2 的注释替换建议 |
| N-1（`SessionCards.kt` 两个死 composable） | 删除属 F12 的统计渲染层收口范围；本轮只登记，避免与对方同文件冲突 |

---

# 统计分享的实际落点（核实给 F12 / Lead 用，我不改动）

Lead 问「统计分享的实际落点」。按本轮基线 `bf0e5a57` 逐段核实，现状是**三段有、一段断**：

| 环节 | 现状 | 证据 |
|---|---|---|
| ① 模块选择弹层（UI） | **已有、可直接用** | `charts/StatisticsExportCards.kt:486 StatisticsExportSheetContent(hasAchievements, hasStories, dark, onConfirm, onEmptySelection)`；勾选逻辑全在 `ExportSheetModel`（`ExportModels.kt:116-178`，纯 Kotlin 已测） |
| ② 导出长图（UI） | **已有、可直接用** | `charts/StatisticsExportCards.kt:204 StatisticsExportDocument(options, semesterStats, achievements, stories, dark)`；段落取舍在 `ExportDocumentModel.sections(...)` |
| ③ 数据装配（模型） | **已有** | `StatisticsService.calculateSemester / calculateAchievements / generateDataStories`（`statistics/StatisticsService.kt:55 / :107 / :238`）；`Course → CourseStub` 的映射已有两份（`CourseStatisticsModel.kt:655` 的 `private fun Course.toStatisticsStub()`、`WeeklyReportScheduleLogic.kt:132`）——**F12 若要复用，需把前者从 `private` 放成 `internal`** |
| ④ 光栅化 + 系统分享（胶水） | **断的就在这里** | 仓里没有任何 Compose→Bitmap 的捕获器（`grep -rn toImageBitmap\|rememberGraphicsLayer` 只在 `components/liquid` 命中阴影层，不是导出）；`platform/AndroidShareAdapter` 是 **ICS 专用**（`text/calendar` + `.ics` 写入），不能直接发 PNG |

**FileProvider 白名单是这条链路的硬约束**（Lead 写作用域）：

```
$ grep -n "cache-path" android/app/src/main/res/xml/file_paths.xml
38:    <cache-path name="ics_export"      path="ics-export/" />
41:    <cache-path name="transfer_share"  path="transfer-share/" />
56:    <cache-path name="log_share"       path="log-share/" />
```

只有三个子目录，**没有统计导出**。所以 F12 有两条路，二选一：

1. **加一行白名单**（推荐，与 ICS/日志同构）：`<cache-path name="statistics_share" path="statistics-share/" />`
   —— 这是 `res/xml/file_paths.xml`，属 Lead 写作用域；加完后把 PNG 写 `cacheDir/statistics-share/`，
   用 `FileProvider.getUriForFile(context, "${packageName}.fileprovider", file)` 拿 content Uri 分享（临时副本，与 Dart 一致）。
2. **走 MediaStore**：插 `MediaStore.Images`（`RELATIVE_PATH=Pictures/…`，minSdk 33 无需权限）再分享该 content Uri
   —— 零配置今天就能通，代价是分享图会**留在用户相册**里（与 Dart 用临时文件不一致）。

分享失败时的文案 ARB 里已有现成的键，不必新造：`serviceMsgStatisticsShareFailed` = 「分享失败：{detail}」
（`lib/l10n/app_zh.arb:5072`，带 `{detail}` 占位符；Kotlin 侧尚未 port）。空选择提示用 `statisticsExportSelectModuleHint`
（「请至少选择一个模块」，`ChartsStrings.kt:175` 已有）。

