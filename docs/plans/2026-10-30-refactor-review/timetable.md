# 课表域 · 近期重构独立审核（2026-10-30）

审核人：`review-timetable`（独立审核员，对抗式）
审核基线：HEAD `d6c925ba`（2026-10-30 11:04:34 +0800，`迁移(半接收尾 F12): 备份详情去掉假入口 + 统计分享接真文本`）
审核时刻：2026-10-30 11:10 ~ 11:40（Asia/Shanghai）
判据：任务书 D1..D6 + 分级 P0/P1/P2

> **只读产品代码**：本次未改任何 `.kt` / `.dart` / `.arb` / 构建文件，未 `git add` / `commit`。
> **唯一写作用域**：本报告文件。
> 工作区正被并行会话实时修改：凡引用提交内容一律用 `git show HEAD:<路径>` 取快照；工作树未提交改动一律标注「在途，非已提交交付」，**不计缺陷也不计通过**。

---

## 结论（先看这段）

### 一句话总评

**「近期重构（2026-10-28 至今）」的这 5 条修复，在提交里一条都没有落地。**

我用 `git log --all -S` 逐条查了 5 个关键符号在**全部分支、全部历史**里的出现情况：

| 声称已修的符号 | `git log --all -S` 结果 |
|---|---|
| `pendingDayViewDayOfWeek` | **0 个提交** |
| `DayViewDataAssembler` | **0 个提交** |
| `dayViewPageDataOf` | **0 个提交** |
| `dateWithWeekday` | **0 个提交** |
| `onOpenCourseNotes`（壳分支实参） | 仅 `b5b8bba2`（Phase 3 页面签名，**不是**壳接线） |

也就是说：这 5 条修复**只存在于当前工作树（未提交）**。`SETTLEMENT.md` 自己也承认「本轮所有修复未提交」（§五.2）。按任务书硬规矩，工作树改动属「在途，非已提交交付」，**既不算缺陷也不算通过**。

因此对**已提交交付（HEAD `d6c925ba`）**而言，这 5 条声称全部不成立，缺陷原样存在：

| # | 声称 | HEAD 实测 | 结论 |
|---|---|---|---|
| 1 | `ShellWiring.onOpenDay` 写 `pendingDayViewDayOfWeek`，`c3.day` 读后清空 | HEAD `ShellWiring.kt:549` 仍是 `onOpenDay = { _ -> onNavigate("c3.day") }`；`c3.day` 无 `pendingDayViewDayOfWeek` | **未落地**（P0-2） |
| 2 | 壳补 `onOpenCourseNotes` / `onOpenCourseTask` | HEAD `c3.day` 分支**未传**这两个参数；`DayViewPage` 默认 `= {}` | **未落地**（P0-1） |
| 3 | 壳改调 `DayViewDataAssembler.build` / `dayViewPageDataOf` | HEAD `c3.day` 仍 inline 拼 `DayViewPageData`，`scheduleCount = 0`，只造 `CourseEntry` | **未落地**（P1-1/P1-2/P1-4/P1-5） |
| 4 | 摘要卡大字标题不再自造中文 | HEAD `ShellPageIndex.kt:558` 仍 `dateLabel = "第 $week 周 · 周$dayOfWeek"` | **未落地**（P1-3） |
| 5 | 壳传 `totalWeeks = semesterWeekCount` / `visibleDays = visibleDayNumbers(hideWeekends)` | HEAD `c3.day` **两个都不传**，页面回落默认 `30 × 7` | **未落地**（P1-13） |

### 审核页面清单（含 commit / 是否在途）

| # | 页面 / 组件 | 路径 | 提交来源 | 状态 |
|---|---|---|---|---|
| 1 | 周视图整页 | `composeP1/.../pages/timetable/TimetableWeekPage.kt` | `a3902f85` / `ec76e320` | 已提交，干净 |
| 2 | 周网格课卡 | `.../timetable/CourseGridCard.kt` | `a3902f85` / `ec76e320` | 已提交，干净（**工作树有在途改动**） |
| 3 | 星期栏 / 时间列 / 周网格 | `TimetableWeekdayHeader.kt` / `TimetableTimeColumn.kt` / `TimetableWeekGrid.kt` | `a3902f85` | 已提交，干净 |
| 4 | 日视图 9 件 | `.../timetable/day/**` | `1e4c57b7` / `9f19cd26` / `86ed9fe9` | 已提交，干净（**工作树有在途改动**） |
| 5 | 课程操作弹层 | `.../pages/course/CourseActionSheet.kt` | `962a534b` | 已提交，干净（**工作树有在途样式改动**） |
| 6 | 关联弹层 / 备注弹层 | `CourseFollowupSheets.kt` / `CourseNoteSheet.kt` | `962a534b` | 已提交，干净 |
| 7 | 课程表单 / 总览 | `AddCoursePage.kt` / `CourseOverviewPage.kt` | 已提交 | 已提交，干净 |
| 8 | 日程族 | `schedule/ScheduleListPage.kt` / `AddScheduleItemPage.kt` / `ScheduleDateRulePage.kt` | 已提交 | 已提交，干净 |
| 9 | 考试族 | `exam/ExamListPage.kt` / `AddExamPage.kt` / `ExamPickerSheets.kt` | `a8a55bc3` | 已提交，干净 |
| 10 | 壳分派 | `main/.../pages/ShellPageIndex.kt` / `ShellWiring.kt` | `d6c925ba` | 已提交，干净（**工作树有在途改动**） |
| 11 | 新增模型层 5 件 | `main/.../pages/timetable/{CourseCardInk,TimetableDateLogic,WeekHolidayMarking}.kt`、`day/{DayViewDataAssembler,DayViewWeather}.kt` | — | **在途（未跟踪）** |
| 12 | 新增守卫 | `test/.../pages/shell/DayViewWiringGuardTest.kt` | — | **在途（未跟踪）** |

### 计数（仅统计**已提交交付 HEAD**；在途观察另列，不计入）

- **P0 2 条 / P1 13 条 / P2 8 条**
- 与既有审核文档不一致处：**1 条大项**（5 条「已修」声明全部未提交）+ 若干条小项（见 §「与既有文档不一致处」）

### 与既有审核文档不一致处

1. **大项**：`docs/plans/2026-10-29-quality-audit/SETTLEMENT.md` §二.1 把课表域 P0-2 / P0-1 / P1-12 / P1-13 / P1-14 记为「本轮（Lead）亲自修的」，但 §五.2 又写「本轮所有修复未提交」。本次用 `git log --all -S` 复核：**这 5 条修复在任何一个提交里都不存在**。因此「已修」只能指工作树，不能指已提交交付。
2. `SETTLEMENT.md` §四.B 记「日视图课程卡天气行（需宿主按节次喂天气）」仍未修 —— 与工作树实际一致（`DayViewWeather` 0 引用），**这条属实**。
3. `2026-10-29-quality-audit/timetable.md` §6 把 `DayViewCourseCard.kt:210-221` 的两颗胶囊描述为「恒渲染」，这是针对 HEAD 的；工作树已改成「未接线不渲染」。两者不矛盾，但引用行号已过期。

---

## 关键验证：5 条声明逐条回源码

### 声明 1 —— 点星期栏「周五」进日视图看到今天

**HEAD（已提交）—— 缺陷成立。**

```
$ git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt | sed -n '545,552p'
        onWeekChanged = { repository.setCurrentWeek(it) },
        // 点星期栏某一天 → 日视图（Dart `TimetableDayViewPart` 的入口）。
        // ⚠️ 已知缺口：`c3.day` 宿主目前不接收「要打开哪一天」，进去落在今天；
        // 传 day 的重载在日视图接线批次里补（见 `docs/plans/2026-10-29-compose-week-view-audit.md` §六 P2）。
        onOpenDay = { _ -> onNavigate("c3.day") },
```

```
$ git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt | sed -n '542,544p'
                initialWeek = snapshot.currentWeek.coerceAtLeast(1),
                initialDayOfWeek = LocalDate.now().dayOfWeek.value,
                homeTitleStyle = appSettings.homeTitleStyle,
```

`onOpenDay` 丢掉 `dayOfWeek`；`c3.day` 恒取 `LocalDate.now()`。**P0-2 成立。**

**工作树（在途）—— 代码已改，但未提交。**

```
$ grep -n "onOpenDay = \|pendingDayViewDayOfWeek" android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt
274:    var pendingDayViewDayOfWeek: Int? = null
559:        onOpenDay = { dayOfWeek ->
560:            wiring.pendingDayViewDayOfWeek = dayOfWeek
561:            onNavigate("c3.day")
```

```
$ sed -n '547,562p' android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt
            val dayIntent = remember {
                wiring.pendingDayViewDayOfWeek.also { wiring.pendingDayViewDayOfWeek = null }
            }
            ...
                initialDayOfWeek = dayIntent,
                visibleDays = visibleDays,
                totalWeeks = snapshot.settings.semesterWeekCount.coerceAtLeast(1),
```

读后清空的一次性意图写法正确。**但这是工作树，未提交。**

### 声明 2 —— 日视图课卡「作业」「备注」胶囊点了没反应

**HEAD —— 缺陷成立（P0-1）。**

```
$ git show HEAD:android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt | sed -n '70,78p'
    onOpenCourse: (courseId: String) -> Unit = {},
    onOpenCourseNotes: (courseId: String) -> Unit = {},
    onOpenCourseTask: (courseId: String) -> Unit = {},
    onOpenSchedule: (scheduleId: String) -> Unit = {},
    onOpenExam: (examId: String) -> Unit = {},
    onOpenTask: (task: CourseTask) -> Unit = {},
    onToggleTask: (task: CourseTask) -> Unit = {},
    onViewAllOverdue: () -> Unit = {},
```

```
$ git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt | grep -c "onOpenCourseNotes"
0
```

壳不传 → 页面默认 `= {}`（非空、可点）→ 胶囊照常渲染、点了没反应。**P0-1 成立。**

**工作树（在途）—— 已补。** `ShellPageIndex.kt:600-615` 传了 `onOpenCourseNotes`（带 courseId 进 `d1.addCourse`）与 `onOpenCourseTask`（`pendingTaskCourse` 进 `d2.addTask`）；页面签名改成可空、未接线不渲染。**未提交。**

### 声明 3 —— 日程卡 / 考试卡 / 待办带三条通道生产代码 0 构造

**HEAD —— 缺陷成立（P1-1 / P1-2）。**

```
$ git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt | sed -n '554,570p'
                dataProvider = { week, dayOfWeek ->
                    val dayCourses = snapshot.courses.filter { c ->
                        c.dayOfWeek == dayOfWeek && c.isActiveInWeek(week)
                    }
                    DayViewPageData(
                        summaryState = DayViewSummaryLogic.buildSummaryState(
                            week = week,
                            dateLabel = "第 $week 周 · 周$dayOfWeek",
                            isToday = week == snapshot.currentWeek && dayOfWeek == LocalDate.now().dayOfWeek.value,
                            courseCount = dayCourses.size,
                            scheduleCount = 0,
                        ),
                        agendaEntries = dayCourses.map { course ->
                            DayAgendaEntry.CourseEntry(
                                course = course,
                                isCurrentWeekCourse = true,
                            )
                        },
```

只构造 `CourseEntry`，`scheduleCount = 0`；`DayAgendaEntry.ScheduleEntry` / `ExamEntry` / `DayTaskBandData` 在生产代码里无构造点（`DayTaskBandLogic.resolve` 仅测试引用）。**P1-1 / P1-2 成立。**

**工作树（在途）—— 已补。** `ShellPageIndex.kt:574-587` 调 `DayViewDataAssembler.build(...)` + `dayViewPageDataOf(...)`；新模型 `main/.../day/DayViewDataAssembler.kt` 造课程/日程/考试/待办/摘要。**未提交。**

### 声明 4 —— 摘要卡大字标题自造中文且与上一行重复

**HEAD —— 缺陷成立（P1-3）。**

```
$ git show HEAD:android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt | grep -n 'dateLabel ='
558:                            dateLabel = "第 $week 周 · 周$dayOfWeek",
```

而 `DayViewSummaryCard.kt:86` 上一行已经画 `DayViewStrings.weekLabel(state.week)`（「第 N 周」），大字位置再画 `state.dateLabel`（「第 3 周 · 周1」）⇒ 同一句念两遍 + 自造中文。**P1-3 成立。**

**工作树（在途）—— 已修。** `DayViewDataAssembler.dateLabel()` 改用 `DayViewStrings.dateWithWeekday(...)` →「10月27日 周二」；壳里那句拼串已删。**未提交。**

### 声明 5 —— 日视图恒可翻 30 周 × 7 天

**HEAD —— 缺陷成立（P1-13）。**

```
$ git show HEAD:android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt | sed -n '65,68p'
    initialDayOfWeek: Int = 1,
    visibleDays: List<Int> = listOf(1, 2, 3, 4, 5, 6, 7),
    totalWeeks: Int = 30,
```

`pageCount = totalWeeks * visibleDays.size`（`:90`）。壳 `c3.day` 两个都不传 ⇒ 隐藏周末不生效、能翻到学期外。**P1-13 成立。**

**工作树（在途）—— 已补。** `ShellPageIndex.kt:555-562` 传 `visibleDays = TimetableHostLogic.visibleDayNumbers(displayPrefs.hideWeekends)`、`totalWeeks = snapshot.settings.semesterWeekCount.coerceAtLeast(1)`。**未提交。**

---

## 逐页结论

### 1. 周视图整页（`TimetableWeekPage.kt`，HEAD）

- **D1 接线真实性：有缺陷（P1-7）**。`c1.week` → `TimetableWithCourseActions` → `TimetableHost` → `TimetableWeekPage`，数据来自 `repository.snapshot`，课程/考试/日程/设置均为真值；回调有落点。**但** `holidayForDay` 是死参数：

  ```
  $ git grep -n "holidayForDay" HEAD -- 'android/app/src/**/*.kt'
  HEAD:.../timetable/TimetableWeekGrid.kt:56:    holidayForDay: (Int) -> Boolean = { false },
  HEAD:.../timetable/TimetableWeekGrid.kt:116:                                isHoliday = holidayForDay(dayOfWeek),
  ```

  全仓只有定义 + 自用两处，`TimetableWeekPage` / `TimetableHost` 都不传 ⇒ 恒 `false`，假期角标 + 0.3 压淡永不出现。Dart 侧真传（`timetable_day_column.dart:76` `provider.isHoliday(date)`）。**P1-7 成立。**

- **D2 复刻完整度：有缺陷（P1-8 / P1-9 / P1-10 / P1-12）**
  - `CourseGridCard.kt` 角标区只处理 `WeekCardBadge.CONFLICT`（`HEAD:294`），无「停」角标 ⇒ **P1-8**。
  - `CourseGridCard` 全文无 `hasHomework` / `hasReminder` ⇒ 作业指示点与单节提醒铃铛缺失 ⇒ **P1-9**。
  - `isHighlighted` 仅定义（`:117`）与自用（`:152`），无调用方 ⇒ 「正在上课」高亮永不出现 ⇒ **P1-10**。
  - 日课卡 `weatherInfo`（`DayViewCourseCard.kt:64`）在渲染层被消费（`:258`），但 `DayViewScrollContent`（HEAD）**从不传** ⇒ 天气行永不出现 ⇒ **P1-12**。

- **D2 复刻完整度：有缺陷（P2-6）**。`TimetableWeekPage.kt:139` `val sectionCount = sectionTimes.size.coerceAtLeast(12)`，而 Dart `timetable_week_grid.dart:101` 用 `settings.sectionCount`。两者口径不同（作息表条数 vs 配置节数）。**P2-6 成立。**
- **D3 文案：通过**（见 §审核方法 D3，240 条逐字全等）。
- **D4 分层：通过**。渲染层只读 `WeekViewStyle` / `WeekGridCourseMapping` / `WeekAgendaLogic`，没有自算冲突或排序。
- **D5 样式：通过**（9 处全在基线，见 §审核方法 D5）。
- **D6 测试牙齿：通过（模型层）**。`WeekGridCourseMappingTest.kt` 16 例全部按行为命名（透明度 0-62、排序键、角标优先级、停课周、无列平分字段）。

### 2. 周网格课卡（`CourseGridCard.kt`，HEAD）

- **D1**：数据来自模型层 `WeekCardModel` → 通过。
- **D2**：版式逐条对得上 `course_card.dart` 紧凑分支；缺口即 P1-7/8/9/10。**未发现自造行为**（旧的「按列平分」已删，`TimetableWeekGrid.kt:41-43` KDoc 自述）。
- **D3/D4/D5/D6**：通过（同上）。

### 3. 星期栏 / 时间列 / 周网格（HEAD）

- **D1**：通过。星期栏圆点用 `WeekAgendaLogic.hasExamOn/hasScheduleOn`；左端「{week} 周」点开周次选择器。
- **D2**：通过。`周一..周日` 走 ARB；`MM/DD` 两位补零；今天=底部 2dp 下划线且与选中互斥；两枚 4dp 圆点；分隔线 0.5dp。
- **D3**：通过（纯数字格式非文案）。
- **D4**：通过（`WeekdayHeaderMetrics` / `TimeColumnMetrics` 是渲染层内几何常量，与 Dart 同层）。
- **D5**：通过。
- **D6**：**未验** —— 无直接钉星期栏/时间列的用例，只有 `WeekViewStyleTest` / `WeekGridCourseMappingTest` 的间接覆盖。不算缺陷，只记账。

### 4. 课程操作弹层（`CourseActionSheet.kt`，HEAD）

- **D1**：通过。`ShellWiring.kt`（HEAD）逐条接 `CourseActionDispatcher.deleteCourse/deleteOccurrence/toggleSuspensionThisWeek/suspendAllWeeks/unsuspendAllWeeks/rescheduleOccurrence/saveCourseNotes`，失败 `catch` 后 toast；对象按事件 `courseId` 现取（`HEAD:579`）。
- **D2**：通过。头部块 / 8 类详情行 / 关联面板 / 6 个动作 / 三种范围子弹层都在；「父弹层隐藏而不是销毁」与 Dart 的差异写进了 KDoc。
- **D3**：通过（本族 240 条逐字对拍 0 不符）。
- **D4**：通过（行是否出现、副题、箭头、可用性由 `CourseActionSheetModel` 算）。
- **D5**：`course` 域基线为空，未见新增。
- **D6**：通过（`CourseActionSheetModelTest` / `CourseFollowupModelTest` / `CourseNoteModelTest` 断言行为）。

### 5. 关联弹层 / 备注弹层（HEAD）

- **D1/D2/D3/D4/D5/D6**：通过。删除「整门 / 本周这节」+ 二次确认、停课「本周 / 全部」、调课（周/日/起止节/地点 + 预览）、备注（课程简介 + 本节备注、只读态可看不可改）均与 Dart 同构。

### 6. 日视图（`pages/timetable/day/**`，HEAD）—— 重灾区

- **D1 接线真实性：有缺陷（2 条 P0）**
  - `c3.day` 壳分支（`ShellPageIndex.kt` HEAD 532-578）只传 10 个参数，页面签名里另有 **7 个回调**保持默认 `= {}`；壳不传 `onOpenCourseNotes` / `onOpenCourseTask`。
  - `DayViewScrollContent.kt`（HEAD）把 `onOpenNotes` / `onOpenTask` 转发给 `DayViewCourseCard`，而 `DayViewCourseCard.kt` 的胶囊是 `.clickable` ⇒ **点了没反应**（P0-1）。
  - `onOpenDay` 丢参 + `initialDayOfWeek = LocalDate.now()` ⇒ **点周五看到今天**（P0-2）。
- **D2 复刻完整度：有缺陷（P1-1 / P1-2 / P1-3 / P1-4 / P1-5）**
  - 日程/考试/待办带三条通道生产 0 构造（P1-1 / P1-2）。
  - 摘要大字标题自造中文且与上一行重复（P1-3）。
  - 摘要卡缺「日程 N 项 / 作业 N 项」分支、缺议程时间区间、缺 4 类状态胶囊（P1-4）。
  - 停课课程整条消失、非本周开关无效（P1-5）。
- **D3 文案：有缺陷（P1-14 / P2-8）**
  - `DayViewExamCard.kt`（HEAD）`:153` `append("座位: $seat")` —— 中文硬编码，ARB 是 `examSeatLabel = '座位号'`，Dart 用法 `'${l10n.examSeatLabel} $seat'` ⇒ **P1-14**。
  - `DayViewCommon.kt`（HEAD）`:145` `contentDescription = "作业"` —— 渲染层中文字面量（值虽与 ARB `courseTaskAction` 相同，纯分层问题）⇒ **P2-8**。
- **D4 分层：有缺陷（P2-4）**。壳 inline 重写 `getCoursesForDay`（`filter { c -> c.dayOfWeek == dayOfWeek && c.isActiveInWeek(week) }`），而模型层已有 `WeekGridCourseMapping.coursesForDay(allCourses, week, dayOfWeek, showNonCurrentWeekCourses)`（`WeekGridCourseMapping.kt:98`，KDoc 明确写「Dart `getCoursesForDay`，`day_course_display_logic.dart:196`」）。两边行为不等（无排序、无非本周开关、停课判据相反）。**P2-4 成立。**
- **D5 样式：通过**（R5 全在基线且写了「数据色」理由）。
- **D6 测试牙齿：有缺陷（P2-7）**。`DiagnosticsWiringGuardTest` 的 `MANAGED`（HEAD 176-198）只有 `b.diagnostics / h.log / h.memory / h.perfReport / h.fixture / k.feedback / i.more / i.moreSearch / i.startup`，**不含 `c1.week` / `c3.day`**；且日视图的空 lambda 是页面签名里的**默认参数值**，分支文本里干净，守卫的 `FORBIDDEN`（`=\s*\{\s*}`）抓不到 ⇒ **P2-7 成立**。

### 7. 壳分派与守卫（跨页）

- **D1**：`c1.week` / `c1.profiles` / `c2.month` / `c3.day` / `d1.addCourse` / `d1.overview` / `d2.scheduleList` / `d2.addSchedule` / `d2.dateRule` / `d2.taskList` / `d2.addTask` / `d3.timeSchemes` / `d3.timeSchemeEditor` / `d3.locationMatch` / `d3.addExam` / `d3.examList` 均喂真宿主，无 `emptyList()` / `= {}` / `SettingsPageState()`（后三者只在设置域 `b.homeWidget` / `b.liveSelfCheck` / `b.glassDockIcon` / `b.reset` 存在，属设置族，不在本域）。**课表域 D1 通过。**
- **D6**：`ShellPageDispatchCoverageTest` 只断言「每个 id 有分支、无重复、有兜底」，**不验证分支内容**。

### 8. 本族域级债（模型层摆设 / 渲染层中文字面量）

| 级别 | 缺陷 | 证据 |
|---|---|---|
| P2-1 | `TimetableGridMetrics` / `TimetableGridConfig` / `SectionTimeSlot`（`TimetableGridMetrics.kt`）生产 0 引用 | `git grep -n "\bTimetableGridMetrics\b" HEAD -- 'android/app/src/**/*.kt' \| grep -v /test/` 只命中自身文件 2 处；`TimetableGridConfig` 11 处、`SectionTimeSlot` 4 处全部在同一文件内 |
| P2-2 | `TimetableProfilesLogic` / `TimetableProfilesState`（`TimetableProfilesModel.kt`）生产 0 引用 | 只命中 `TimetableProfilesModel.kt` 自身（定义 + 自用）；真实页面用 `TimetableProfilesController` |
| P2-3 | `DayExamSummary`（`DayViewSummaryModel.kt`）渲染层 0 引用 | HEAD 下只命中 `DayViewSummaryModel.kt`（定义 + `buildSummaryState` 形参）；日视图不构造它 |
| P2-5 | `TimetableProfilesPage.kt` 存在一整块平行文案对象，36 条中文硬编码 | HEAD 版非注释 CJK 行 = 36（脚本统计）；对应 ARB 键在 `TimetableStrings.kt` 已存在（`timetableProfilesTitle/switchedToProfile/...`）⇒ 有键不用、另抄一份 |
| P2-7 | 壳接线守卫覆盖不到 `c1.week` / `c3.day` | 见 §6 D6 |
| P2-8 | `DayViewCommon.kt` 渲染层中文字面量「作业」 | 见 §6 D3 |

---

## 缺陷清单（一行一条，含修法）

**P0**

- `ShellPageIndex.kt`（HEAD `c3.day`）不传 `onOpenCourseNotes` / `onOpenCourseTask`，`DayViewPage` 默认 `= {}` ⇒ 日视图课卡「作业」「备注」胶囊点了没反应。**修法**：壳补两条能力回调（工作树已做：备注 → `d1.addCourse` 带 courseId；作业 → `d2.addTask` 带 `pendingTaskCourse`），页面签名改可空、未接线不渲染。
- `ShellWiring.kt:549` `onOpenDay = { _ -> ... }` + `ShellPageIndex.kt:543` `initialDayOfWeek = LocalDate.now()...` ⇒ 点星期栏某天进日视图看到的是今天。**修法**：`onOpenDay` 把 `dayOfWeek` 写进一次性意图，`c3.day` 读后清空（工作树已做）。

**P1**

- 壳只构造 `CourseEntry`，日程/考试/待办带三条通道生产 0 构造，`scheduleCount = 0`。**修法**：壳改调 `DayViewDataAssembler.build`（工作树已做）。
- `taskBandData` 恒 null、`courseTaskPresence` 恒空 ⇒ 待办带整块不出现、作业红点不亮。**修法**：装配器输出 `taskBandData` + `courseTaskPresence`（工作树已做）。
- 摘要大字标题自造中文「第 N 周 · 周1」且与上一行重复。**修法**：用 `MonthDay` + 星期名组「10月27日 周二」，周次交给上一行（工作树已做）。
- 摘要卡缺 count 分支 / 议程时间区间 / 4 类状态胶囊。**修法**：装配器填 `taskCount/currentCourseName/conflictCount/nonCurrentWeek/exams/first-last`（工作树已做）。
- 停课课程整条消失、非本周开关无效（壳 `isActiveInWeek` vs Dart `isInWeek`）。**修法**：改用 `WeekGridCourseMapping.coursesForDay`（工作树已做）。
- 课卡缺「假期」角标 + 0.3 压淡：`holidayForDay` 死参数恒 false。**修法**：`TimetableHost` 用 `HolidayPreferences` 算 `holidayOf` 下传（工作树已做）。
- 课卡缺「停课」角标（Dart 右上角「停」）。**修法**：角标区改「假 / 停 / 冲突」一行多枚（工作树已做）。
- 课卡缺作业指示点与单节提醒铃铛。**修法**：`WeekCardModel` 加 `hasHomework` / 提醒字段并下传（工作树只做了作业点，铃铛无数据源）。
- 「正在上课」高亮永不出现：`isHighlighted` 无调用方。**修法**：宿主按当前节次/时间算 `isCurrentCourse` 传入。
- 三个设置项改了无可见效果：`backToCurrentWeekOpacity` / `showWeatherOnCard` / `cardTitleColor{Light,Dark}` / `cardDetailColor{Light,Dark}` 渲染层 0 读。**修法**：接线或从 `WeekViewStyle` 删除并注明（工作树已做 ①②③）。
- 日视图课卡天气行参数 `weatherInfo` 无调用方。**修法**：宿主把天气 provider 按节次喂进 `DayViewPageData`（工作树只交付了 `DayViewWeather`，**仍未接线**）。
- 日视图恒可翻 30 周 × 7 天。**修法**：壳传 `totalWeeks = semesterWeekCount`、`visibleDays = visibleDayNumbers(hideWeekends)`（工作树已做）。
- 考试卡「座位: 」中文硬编码且与 ARB 不符。**修法**：走 `DayViewStrings.seatLabel()`（工作树已做）。

**P2**

- `TimetableGridMetrics` / `TimetableGridConfig` / `SectionTimeSlot` 模型层摆设（生产 0 引用）。**修法**：删除或接真宿主；`defaultSectionTimeSlots()` 自造的 08:00/08:45 默认钟点与用户作息表无关，应删。
- `TimetableProfilesLogic` / `TimetableProfilesState` 模型层摆设。**修法**：删除（真实页面用 `TimetableProfilesController`）。
- `DayExamSummary` 渲染层 0 引用（HEAD）。**修法**：装配器用它填摘要卡考试胶囊（工作树已做）。
- 壳 inline 重写 `getCoursesForDay`（分层倒挂）。**修法**：直接调 `coursesForDay`（工作树已做）。
- `TimetableProfilesPage` 36 条平行文案对象。**修法**：改引 `TimetableStrings`，同步下调 CJK 基线。
- 壳接线守卫覆盖不到 `c1.week` / `c3.day`。**修法**：把这两条加进 `DiagnosticsWiringGuardTest.MANAGED`，并补「页面签名不许有 `= {}` 默认」的文本守卫（工作树新增 `DayViewWiringGuardTest`，未提交）。
- `DayViewCommon` 渲染层中文字面量「作业」。**修法**：改 `DayViewStrings.courseTaskAction.zh`（工作树已做）。
- 周网格行数口径 `coerceAtLeast(12)` vs `settings.sectionCount`。**修法**：工作树已改成 `sectionCount = sectionTimes.size`（`TimetableWeekPage.kt:155`，注释称 Dart `settings.sectionCount => sections.length`）；但 Dart 用 `settings.sectionCount`（`timetable_week_grid.dart:101` `List.generate(settings.sectionCount, ...)`），而 Kotlin 的 `sectionTimes` 来自**当前作息表**的 `sections`。两者是否恒等**未验**（需确认「当前作息表节数」与「设置里的 sectionCount」是否同源）。

---

## 在途观察（非已提交交付，不计缺陷也不计通过）

以下均为**工作树未提交**内容，按任务书硬规矩不计入上面的 P0/P1/P2，但作为审核线索列出：

1. 5 条「已修」声明的代码**确实存在于工作树**（`ShellWiring.kt:274/559-562`、`ShellPageIndex.kt:547-628`、`day/DayViewDataAssembler.kt`、`day/DayViewWeather.kt`、`CourseCardInk.kt`、`TimetableDateLogic.kt`、`WeekHolidayMarking.kt`、`test/.../DayViewWiringGuardTest.kt`）。**但 `git log --all -S` 证明它们从未进入任何提交。**
2. 工作树 `onOpenExam = { onOpenPage("d3.examList") }`（`ShellPageIndex.kt:616`）**忽略 `examId`**：Dart 日视图考试卡 `openBuilder` 打开的是 `timetableFormPages.examForm(exam: exam)`（`day_view_exam_agenda_card.dart:91`），Compose 打开的是考试**列表**。参数被接收但不使用。
3. 工作树 `onOpenSchedule`（`ShellPageIndex.kt:617-623`）只传 series id、**不带 occurrence date**；Dart `scheduleItemForm(scheduleItem:, occurrenceDate: agendaItem.scheduleInstance?.occurrenceDate)`（`day_view_schedule_agenda_card.dart:94-97`）。重复日程从日视图点进去会编辑整条系列而不是那一次发生。
4. `DayViewWeather`（新模型层）**全仓 0 引用**（`grep -rn "DayViewWeather" android/app/src` 只命中自身），所以日课卡天气行仍然永不出现 —— 与 `SETTLEMENT.md` §四.B 自述一致。
5. 新增模型层 5 件（`DayViewDataAssembler` / `DayViewWeather` / `CourseCardInk` / `TimetableDateLogic` / `WeekHolidayMarking`）**没有任何单测引用**（`git grep -l <sym> HEAD -- 'android/app/src/test/**'` 均为 0；工作树也无 `DayViewDataAssemblerTest`）。
6. 工作树 `ShellPageIndex.kt` mtime 2026-10-30 11:07（审核开始时 11:10），即**另有会话在我审核期间仍在改这个文件**；本报告所有工作树引用均为当时快照。

---

## 我没能验的

1. **L0/L1/L2 是否真绿**：按纪律未跑 Gradle、未跑 `scripts/test-kotlin-module.ps1`。因此「221 例全绿 / L1 BUILD SUCCESSFUL / L2 5307 例」这类说法**未验证**，只作背景。工作树代码我做了符号级静态核对（`DayViewDataAssembler` 调用的 `scheduleEntryForDate` / `sortAgendaEntries` / `parseClockMinutes` / `resolve` / `conflictMap` / `coursesForDay` / `resolveProgress` / `actionableCount` 全部存在），但**未编译**。
2. **真机观感**：胶囊点击、点星期栏落日、隐藏周末翻页边界、深色模式对比度，需用户在 `dev` 变体 `PagesShellActivity` 逐页对照。
3. **`DayViewWiringGuardTest` 的咬合探针**：`SETTLEMENT.md` §二.3 称「把 `initialDayOfWeek = dayIntent` 改回 `LocalDate.now()` → 立即红；还原 → 61 例全绿」。我未跑测试，无法复核；且该守卫文件本身未提交。
4. **`onOpenExam` / `onOpenSchedule` 的真实跳转效果**：静态读出参数被忽略 / occurrence date 丢失，但未在真机验证用户可见差异。
5. **`DayViewDataAssembler` 与 Dart 的逐字段等价**：我核对了函数签名与构造链，但未做数据等价探针（例如「同一周同一天，Compose 装配出的 `agendaEntries` 与 Dart `_buildDayAgendaItems` 是否逐项一致」）。
6. **ARB 六个语言版本**：只对 `app_zh.arb` 判据对拍；en/ja/ko/zh_HK/zh_TW 未对。
7. **工作树代码的编译正确性**：工作树在审核期间仍在变动，且我未编译，故工作树相关结论一律标注「在途，未验编译」。

---

## 审核方法（跑了哪些命令、扫了多少文件）

### 1. 提交基线与改动面

```
git rev-parse HEAD                                  → d6c925ba414616163c1c4f007ec6566e2fafa294
git log -1 --format='%h %ad %s' --date=iso          → d6c925ba 2026-10-30 11:04:34 +0800 迁移(半接收尾 F12)...
git status --short                                   → 约 90 行 M/D + 约 20 行 ??
git log --oneline --since="2026-10-28"               → 172 条
git diff --stat HEAD -- ShellPageIndex.kt ShellWiring.kt
                                                     → 159 +/- 与 19 +/-
```

### 2. 5 条声明是否曾落地（决定性证据）

```
git log --all --oneline -S "pendingDayViewDayOfWeek" -- android/app/src   → 空
git log --all --oneline -S "DayViewDataAssembler"    -- android/app/src   → 空
git log --all --oneline -S "dayViewPageDataOf"       -- android/app/src   → 空
git log --all --oneline -S "dateWithWeekday"         -- android/app/src   → 空
git log --all --oneline -S "onOpenCourseNotes"       -- android/app/src   → b5b8bba2（页面签名，非壳接线）
```

### 3. D3 文案逐字对拍（独立脚本，HEAD 版）

用 `git show HEAD:<6 个 *Strings.kt>` 提取 `ArbText("key","value")`，与 `git show HEAD:lib/l10n/app_zh.arb` 逐字比较（Kotlin 转义解码后）：

```
declarations parsed = 240   mismatches = 0
```

（`CourseActionStrings.kt` 实际在 `app/` 下，脚本里写错路径，报 MISSING；其余 5 个文件 240 条全等。）

渲染层 CJK 字面量：仓库自带扫描器 `PYTHONIOENCODING=utf-8 python scripts/i18n-cjk-baseline.py` →

```
中文字面量总计 179 条，分布 19 个文件
   36  com/mutx163/qingyu/pages/timetable/TimetableProfilesPage.kt
   （day/DayViewCommon.kt、day/DayViewExamCard.kt 已不在列表）
```

HEAD 版定向 grep 确认两条存量债仍在 HEAD：

```
$ git show HEAD:.../day/DayViewCommon.kt   | grep -n "作业"     → 145: contentDescription = "作业",
$ git show HEAD:.../day/DayViewExamCard.kt | grep -n "座位"     → 153: append("座位: $seat")
```

### 4. D5 样式守卫（只读，秒级）

```
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain timetable
→ timetable 共 9 处：R5 ×7（CourseGridCard / DayViewCommon / DayViewCourseCard /
  DayViewScheduleCard / DayViewTaskBandCard / MonthDayCell / MonthPanelOverview）、
  R2 ×2（MonthViewPage:424、TimetableWeekPage:407）
→ 基线外违规 0 处
```

### 5. D4 分层扫描

`git grep -n "\b<sym>\b" HEAD -- 'android/app/src/**/*.kt' | grep -v /test/` 逐个核对 `TimetableGridMetrics` / `TimetableGridConfig` / `SectionTimeSlot` / `TimetableProfilesLogic` / `TimetableProfilesState` / `DayExamSummary` / `DayViewWeather` 的引用点。

### 6. D6 测试面

列出 HEAD 下 `pages/{timetable,course,schedule,exam,shell}/**/*Test.kt` 共 **44 个测试文件**，核对 `WeekGridCourseMappingTest`（16 例行为断言）、`DiagnosticsWiringGuardTest.MANAGED`（9 条，不含 `c1.week` / `c3.day`）、`ShellPageDispatchCoverageTest`（只断言分支存在性）。

### 7. 扫描面（约数）

- Kotlin：`composeP1/.../pages/timetable/**`（约 20 件）、`pages/course/**`（6 件）、`pages/schedule/**`（3 件）、`pages/exam/**`（3 件）、`main/.../ShellPageIndex.kt`（2073 行）、`ShellWiring.kt`（821 行）、`app/TimetableHost.kt`、`app/TimetableHostLogic.kt`、`core/{Course,CourseTask,ScheduleItem,Exam}.kt` —— 合计约 **12,000 行**。
- Dart：`lib/screens/timetable_day_view_part.dart`、`lib/widgets/timetable/day_view/*.dart`（12 件）、`lib/widgets/timetable/timetable_weekday_header.dart`、`lib/domain/day_course_display_logic.dart` —— 合计约 **6,500 行**。
- 6 个 `*Strings.kt` + `app_zh.arb`（HEAD 3930 键）。

### 8. 纪律

- 未改任何 `.kt` / `.dart` / `.arb` / 构建文件；未 `git add` / `commit`。
- 未跑 Gradle（L1/L2），未跑 `scripts/test-kotlin-module.ps1`。
- 只跑了只读 grep / read / 秒级脚本（`compose-style-lint.ps1`、`i18n-cjk-baseline.py`、自写 HEAD 对拍脚本，脚本用后即删）。
- 唯一写入文件：本报告。
