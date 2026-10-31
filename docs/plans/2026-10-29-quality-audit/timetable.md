# 课表核心族 · 质量审核（2026-10-29，独立复核）

审核基线：HEAD 3f3b7354（2026-10-29 20:10 提交）；审核时刻：2026-10-29 20:33（Asia/Shanghai）。

> 判据：`docs/plans/2026-10-29-quality-audit/_RUBRIC.md`（唯一判据）。
> 工作区有他人在途改动，凡 `git status --porcelain` 里 M 的文件一律按 `git show HEAD:<path>` 判，
> 差异集中列在「在途改动（他人，不入判）」一节。本报告**不改任何产品代码**，唯一写作用域就是本文件。

## 结论（先看这段）

### 审核页面清单（含 commit / 是否在途）

| # | 页面 / 组件 | 路径 | 来源 | 状态 |
|---|---|---|---|---|
| 1 | 周视图整页 | `composeP1/.../pages/timetable/TimetableWeekPage.kt`（469 行） | a3902f85 / ec76e320 | 已提交，干净 |
| 2 | 周网格课卡 | `.../timetable/CourseGridCard.kt`（337 行） | a3902f85 / ec76e320 | 已提交，干净 |
| 3 | 星期栏 | `.../timetable/TimetableWeekdayHeader.kt`（390 行） | a3902f85 | 已提交，干净 |
| 4 | 时间列 | `.../timetable/TimetableTimeColumn.kt`（207 行） | a3902f85 | 已提交，干净 |
| 5 | 周网格 | `.../timetable/TimetableWeekGrid.kt`（237 行） | a3902f85 | 已提交，干净 |
| 6 | 顶栏 | `.../timetable/TimetableTopBar.kt`（356 行） | 1e4c57b7 / 9f19cd26 | 已提交，干净 |
| 7 | 课程操作弹层 | `.../pages/course/CourseActionSheet.kt`（HEAD 679 行） | 962a534b | **在途**（按 HEAD 判） |
| 8 | 关联弹层四件 | `.../pages/course/CourseFollowupSheets.kt`（944 行） | 962a534b | 已提交，干净 |
| 9 | 备注弹层 | `.../pages/course/CourseNoteSheet.kt`（321 行） | 962a534b | 已提交，干净 |
| 10 | 日视图 9 件 | `.../timetable/day/**`（1821 行） | 1e4c57b7 / 9f19cd26 / 86ed9fe9 | 已提交，干净（**不是**在途） |

日视图 `git status --porcelain -- .../pages/timetable/day` 输出为空 ⇒ 任务书里「如在途则标注在途」的前提不成立，按已提交交付判。

### 计数

- **P0 2 条 / P1 14 条 / P2 9 条**（P2 清单在 §7/§8 与各页缺陷表内；P2-9 同时算进下面那 4 条文档不符）
- 与既有审核文档不一致的地方：**4 条**（2 条事实不符、1 条等级低估、1 条「8 行可点」不实；逐条见「审核方法」§8）

### 一句话总评

**周视图（周网格、课卡、表头、时间列）这一刀是真的复刻**：数据来自真仓储、模型层 `WeekGridCourseMapping`/`WeekAgendaLogic` 有 Dart 逐行对应、文案 243 条逐字对拍全等、样式守卫 9 处全在基线内。
**坏在日视图**：`c3.day` 壳分支只喂了「课程」一类条目，页面里**每天都在渲染的「作业」「备注」两个可点胶囊**（`DayViewCourseCard.kt:210-221`）在壳里没有落点 ⇒ 点了没反应；日程 / 考试 / 待办带三条通道在生产代码里**一次都没被构造过**；摘要卡的大字标题被喂成自造中文 `"第 N 周 · 周1"`（`ShellPageIndex.kt:503`），位置上方还已经写过一遍「第 N 周」。

---

## 逐页结论

### 1. 周视图整页（`TimetableWeekPage.kt`）

- **D1 接线真实性：通过（有 1 处参数丢失，见 P1-6）**
  `c1.week` → `TimetableWithCourseActions`（`ShellWiring.kt`，HEAD 412 行起）→ `TimetableHost`（`TimetableHost.kt:51-136`）→ `TimetableWeekPage`，数据来自 `repository.snapshot`（`TimetableHost.kt:70-75` 先读初值再 `observe`），课程/考纲/日程/设置全部真值：

  ```
  // TimetableHost.kt:97-104
  val exams = repository.exams
  val scheduleItems = snapshot.scheduleItems
  ...
  courses = snapshot.courses,
  timeScheme = TimetableHostLogic.resolveActiveTimeScheme(...)
  ```
  回调全部有落点：`onCourseClick → actionTarget`（弹层）、`onLongPressEmptySlot → d1.addCourse`、`onWeekChanged → repository.setCurrentWeek`、`onAgendaClicked → 考试页/日程编辑页`（`ShellWiring.kt` HEAD 533-552）。没有 `= {}`、没有 `emptyList()`。

- **D2 功能复刻完整度：有缺陷（P1-7/8/9/10/12，P2-6）**

- **D3 文案：通过**
  `TimetableStrings` 全量 243 条 `ArbText` 与 `app_zh.arb`（HEAD 与工作区各对一次）**逐字全等，0 处不符**（命令见「审核方法」§3）。本文件无 CJK 字面量。

- **D4 分层：通过**
  渲染层只读 `WeekViewStyle` / `WeekGridCourseMapping` / `WeekAgendaLogic` / `WeekViewStyle.weekSectionHeight`，没有自算冲突或排序。`weekSectionHeight` 与 Dart `gridSectionHeight` 逐分支一致（`WeekViewStyle.kt:93-102` ↔ `lib/domain/timetable_layout.dart:42-53`）。

- **D5 样式：通过**（9 处全在基线，见「审核方法」§5）

- **D6 测试牙齿：通过（模型层）/ 有缺口（壳层）**
  `WeekGridCourseMappingTest.kt`（554 行，12 例）钉的是行为而非「页面能打开」：`非本周课透明度固定 0-62 且优先于冲突设置值`、`当日排序是开始节次、本周课靠后、结束节次、id`、`关掉冲突角标开关后卡面不再标冲突但透明度照旧压淡`。**但没有任何测试碰 `c1.week`/`c3.day` 的壳分支**（`grep -rn '"c3.day"' android/app/src/test` = 0 命中）。

**缺陷清单**

| 级别 | 缺陷 | 证据 | 建议修法 |
|---|---|---|---|
| P1-6 | 点星期栏某一天进日视图**不带那天**，永远落在今天 | `ShellWiring.kt`（HEAD）529：`onOpenDay = { _ -> onNavigate("c3.day") },`（下面 527-528 行自己写了「已知缺口」） | `c3.day` 分支加 `initialDayOfWeek` 入参（`ShellWiring` 已有 `pending*` 意图载体可复用） |
| P1-7 | 课卡缺「假期」角标 + 0.3 压淡：`holidayForDay` 是**死参数** | 声明 `TimetableWeekGrid.kt:56 holidayForDay: (Int) -> Boolean = { false }`，消费 `:116 isHoliday = holidayForDay(dayOfWeek)`；全仓 `grep -rn "holidayForDay" android/app/src` 只有这 2 行 ⇒ 永远 false。Dart 侧真传：`timetable_day_column.dart:76 final isDayHoliday = date != null && provider.isHoliday(date);` → `:149 isHoliday: isDayHoliday`，角标 `course_card.dart:450-464` + `:626 l10n.holidayBadgeLabel` | 宿主用 `calendar/HolidayResolver.isHoliday(date)` 组一个 `holidayForDay` 传下去；卡面补「假」角标 |
| P1-8 | 课卡缺「停课」角标（Dart 是右上角「停」，Compose 只有 0.4 alpha） | `CourseGridCard.kt:146-150` 只有 `model.isSuspended -> 0.4f`；角标区只有 `:294 if (model.badge == WeekCardBadge.CONFLICT)`。Dart `timetable_day_column.dart:150 isSuspended: item.course.isSuspendedInWeek(week)` + `course_card.dart:460-461 showSuspended` + `:635 l10n.suspendedBadgeLabel` | 角标区改成 Dart 那种「一行多枚」（假/停/铃/备注并排） |
| P1-9 | 课卡缺**作业指示点**与**单节提醒铃铛** | Compose `CourseGridCard` 全文无 `hasHomeworkIndicator`/`hasReminder`；Dart `timetable_day_column.dart:138 hasReminder:`（`provider.classReminderFor(...)`）与 `:146 showHomeworkIndicator: item.course.hasHomeworkInWeek(week)` | 卡模型加两个布尔，宿主用 `hasHomeworkInWeek` 与提醒仓储填 |
| P1-10 | 「正在上课」高亮永不出现：`isHighlighted` 无调用方 | `CourseGridCard.kt:117 isHighlighted: Boolean = false`、`:152-156` 用它画白边；`grep -rn "isHighlighted" android/app/src/composeP1/.../timetable` 只有这两处。Dart `timetable_day_column.dart:148 isHighlighted: item.isCurrentCourse` | 宿主按「当前节次/当前时间」算 `isCurrentCourse` 传入 |
| P1-11 | 三个设置项改了**没有可见效果**：回本周浮钮透明度、课卡标题/详情色、课卡天气行 | 映射进了模型（`TimetableStyleMapping.kt:84 cardTitleColorLight=…`、`:115-117 backToCurrentWeekOpacity/showWeatherOnCard`），但 `holidayMarkingEnabled`/`backToCurrentWeekOpacity`/`showWeatherOnCard`/`cardTitleColor*`/`cardDetailColor*` 在渲染层读取次数 **0**（`grep -rn "\.<prop>\b"` 去重后仅命中映射赋值与测试）。渲染层实际：`CourseGridCard.kt:130-132` 用 `calculateInk(rawColor)` 自算墨色、`TimetableWeekPage.kt:214 colors = ButtonDefaults.buttonColors()` | 要么接线，要么从 `WeekViewStyle` 删掉并在映射表注明「未接线」（现状是测试断言它映射成功，给人假信心） |
| P1-12 | 日视图课卡天气行参数 `weatherInfo` 无调用方 | `DayViewCourseCard.kt:64 weatherInfo: String? = null`；唯一调用点 `DayViewScrollContent.kt:115-123` 不传；Dart 有 `lib/widgets/timetable/day_view/day_course_weather_row.dart` | 宿主把 `WeatherProvider` 按节次喂进 `DayViewPageData` |
| P2-6 | 周网格行数口径与 Dart 不同：`sectionTimes.size.coerceAtLeast(12)` vs `settings.sectionCount` | `TimetableWeekPage.kt:139 val sectionCount = sectionTimes.size.coerceAtLeast(12)`；Dart `timetable_week_grid.dart:101 children: List.generate(settings.sectionCount, ...)` | 改成 `settings.sectionCount`（作息表条数与配置节数是两件事） |

### 2. 周网格课卡（`CourseGridCard.kt`）

- **D1**：数据来自 `WeekCardModel`（模型层算好），不是壳层直接拼 → 通过。
- **D2**：版式（圆角 8、内边距 4/4~6、行距 2、字号 title/‒1/‒1、非本周 0.62、冲突压淡取设置值）逐条对得上 `course_card.dart` 紧凑分支；缺口即上表 P1-7/8/9/10。**没有发现自造行为**：旧版的「按列平分」已被删除，KDoc 自己也写了这件事（`TimetableWeekGrid.kt:41-43`），`grep -rn "平分"` 只剩注释。
- **D3/D4/D5/D6**：通过（同上一节）。

### 3. 星期栏 / 时间列 / 顶栏

- **D1**：通过。星期栏圆点用 `WeekAgendaLogic.hasExamOn/hasScheduleOn`（`TimetableWeekPage.kt:360-361`），考试/日程真实来自 `repository.exams` 与 `snapshot.scheduleItems`；左端「{week} 周」点开周次选择器（Dart 同款 `onShowWeekSelector`，`timetable_weekday_header.dart:175`）。
- **D2**：通过。逐项对上了：`周一..周日` 走 ARB（`:131` 修掉了旧版「一/二」）、`MM/DD` 两位补零（`:104-105` ↔ Dart `:309`）、今天=底部 2dp 下划线且与选中互斥（`:245` ↔ Dart `:246`）、两枚 4dp 圆点（`:347-373` ↔ Dart `:317-361`）、分隔线 0.5dp。刻意没做的（壁纸明暗自适应、选中指示条滑动形变）在 KDoc 里写明并指向 Dart 行号，属实。
- **D3**：通过（`"$sectionIndex"`、`String.format(Locale.ROOT, "%02d/%02d", ...)` 是纯数字格式，非文案）。
- **D4**：通过（`WeekdayHeaderMetrics`/`TimeColumnMetrics` 是渲染层内的几何常量，与 Dart 同层，不算模型倒挂）。
- **D5**：无违规（本域 9 处违规不含这三个文件）。
- **D6**：未验——这三个组件的断言在 `WeekViewStyleTest`/`WeekGridCourseMappingTest` 里只有间接覆盖，没有直接钉星期栏/时间列的用例。**不算缺陷，只记账**。

**缺陷清单**：无（本族三件未发现 P0/P1/P2）。

### 4. 课程操作弹层（`CourseActionSheet.kt`，**在途，按 HEAD 判**）

- **D1 接线：通过**。事件全部有落点，且写库是真的：`ShellWiring.kt`（HEAD）601-652 逐条接 `CourseActionDispatcher.deleteCourse/deleteOccurrence/toggleSuspensionThisWeek/suspendAllWeeks/unsuspendAllWeeks/rescheduleOccurrence/saveCourseNotes`，失败 `catch` 后 toast，不静默；`CourseActionDispatcher.isClassAlarmAvailable() = false`（`CourseActionDispatcher.kt:405`）⇒「单节课提醒」行由模型不产生（`CourseActionSheetModel.kt:701-704` 注释同步），不是画了没反应。
  对象按事件 `courseId` 现取而不是用 `actionTarget`（HEAD 579 行），冲突课切换后编辑/删除落到正确那门。
- **D2 复刻：通过（1 处刻意不同，已自述）**。头部块/8 类详情行/关联面板/6 个动作/三种范围子弹层都在；「父弹层隐藏而不是销毁」与 Dart `_dismissThen` 的差异写进了 KDoc（HEAD 143-152）。
- **D3 文案：通过**（`CourseActionSheetStrings`/`CourseFollowupStrings`/`CourseNoteStrings`/`CourseActionStrings` 合计 243 条中的全部条目逐字对拍 0 不符）。
- **D4**：通过（行是否出现、副题、箭头、可用性都由 `CourseActionSheetModel` 算）。
- **D5**：`course` 域基线为空，本次未见新增。
- **D6**：通过。`CourseActionSheetModelTest` / `CourseFollowupModelTest` / `CourseNoteModelTest` 存在且断言行为。

**缺陷清单**

| 级别 | 缺陷 | 证据 |
|---|---|---|
| P2-9 | 既有审核文档称「Dart 弹层是 8 行**可点**详情」，实际只有 2 行可点 | `CourseActionSheet.kt`（HEAD）173-181 `onRowTap` 只有 `OPEN_NOTE`/`OPEN_TASK` 两个分支，其余 `null -> null`；`CourseActionSheetModel.kt:668-699` 只有备注行（C5）与作业行（C6）`showsChevron = true` |

### 5. 关联弹层（`CourseFollowupSheets.kt`）/ 备注弹层（`CourseNoteSheet.kt`）

- **D1**：通过。三个范围弹层的返回值都抛成 `CourseActionEvent` 并被壳接住写库（上节证据）；备注走 `CourseActionDispatcher.saveCourseNotes`，`hasHomework` 由分派器保留原值（`ShellWiring.kt` HEAD 641-649 注释 + 实现）。
- **D2**：通过。删除「整门 / 本周这节」+ 二次确认、停课「本周 / 全部」、调课（周/日/起止节/地点 + 预览）、备注（课程简介 + 本节备注、只读态可看不可改）都与 Dart `course_followup_sheets.dart`（1015 行）/`course_note_sheet.dart`（363 行）同构。
- **D3/D4/D5/D6**：通过。

**缺陷清单**：无。

### 6. 日视图（`pages/timetable/day/**`，9 件 1821 行）

这是本族唯一的重灾区。

- **D1 接线真实性：有缺陷（2 条 P0）**

  壳分支 `c3.day`（`ShellPageIndex.kt` HEAD 477-523）只传了 10 个参数，页面签名里另有 **6 个回调 + `courseResolver` 保持默认空实现**：

  ```
  // DayViewPage.kt:69-80
  dataProvider: (week: Int, dayOfWeek: Int) -> DayViewPageData,
  onOpenCourseNotes: (courseId: String) -> Unit = {},
  onOpenCourseTask: (courseId: String) -> Unit = {},
  onOpenSchedule: (scheduleId: String) -> Unit = {},
  onOpenExam: (examId: String) -> Unit = {},
  onOpenTask: (task: CourseTask) -> Unit = {},
  onToggleTask: (task: CourseTask) -> Unit = {},
  onViewAllOverdue: () -> Unit = {},
  courseResolver: (CourseTask) -> Course? = { null },
  ```
  而每一张课程卡**恒渲染**这两个可点胶囊：

  ```
  // DayViewScrollContent.kt:115-123 → DayViewCourseCard.kt:210-221
  onOpenNotes = { onOpenCourseNotes(entry.course.id) },
  onOpenTask = { onOpenCourseTask(entry.course.id) },
  ...
  DayAgendaTaskAction(ink = ink, onPressed = onOpenTask, hasTask = hasTask),
  DayAgendaNoteAction(ink = ink, onPressed = onOpenNotes),
  ```
  `DayAgendaTaskAction` 是 `.clickable(onClick = onPressed)`（`DayViewCommon.kt:205-211`）⇒ **点下去没有任何反应**。

- **D2 复刻完整度：有缺陷（P1-1..5）**

- **D3 文案：有缺陷（P1-14 / P2-8）**

- **D4 分层：有缺陷（P2-4）**

- **D5 样式：通过**（`DayViewCommon/DayViewCourseCard/DayViewScheduleCard/DayViewTaskBandCard` 的 R5 全在基线且写了「数据色」理由）

- **D6 测试牙齿：有缺陷（P2-7 / 见「D6 缺口」）**

**缺陷清单**

| 级别 | 缺陷 | 证据 | 建议修法 |
|---|---|---|---|
| **P0-1** | 日视图每张课程卡上的「作业」「备注」两个胶囊**点了没反应** | `ShellPageIndex.kt`（HEAD）485-522 未传 `onOpenCourseNotes`/`onOpenCourseTask`；`DayViewPage.kt:72-73` 默认 `= {}`；`DayViewScrollContent.kt:120-121` 转发；`DayViewCommon.kt:205-211` 真 clickable | 壳里补两条：备注 → `d1.addCourse`（带 courseId）或备注弹层、作业 → `d2.addTask`（`pendingTaskCourse`），与周视图弹层同一落点 |
| **P0-2** | 点星期栏的「周五」进日视图，看到的是**今天**（回显不对） | `ShellWiring.kt`（HEAD）529 `onOpenDay = { _ -> onNavigate("c3.day") }` + `ShellPageIndex.kt:487 initialDayOfWeek = LocalDate.now().dayOfWeek.value`。Dart 入口带 `(week, dayOfWeek)`（`timetable_screen.dart:406 _dayAgendaScrollKey(int week, int dayOfWeek)`，日视图按它算滚动位置） | 同 P1-6：把 `dayOfWeek` 经 `pending*` 带进 `c3.day`，`initialDayOfWeek` 从意图读，缺省才回落今天 |
| P1-1 | 日视图**永远没有日程卡与考试卡**：模型支持两种条目，生产代码里 0 处构造 | `DayAgendaModel.kt:39-58` 定义 `ScheduleEntry`/`ExamEntry`；`grep -rn "DayAgendaEntry.ScheduleEntry\|DayAgendaEntry.ExamEntry" android/app/src --include=*.kt \| grep -v /test/` 只命中渲染层 `is` 分支与模型自身，**没有任何构造点**；壳只造 `CourseEntry`（`ShellPageIndex.kt:508-513`）。Dart 三类都造：`timetable_day_view_part.dart:602-620`（`_getCoursesForDay` → `_buildHomeDayDisplayItems` → `_buildDayAgendaItems`） | 壳里补 `scheduleItems`/`exams` 两类条目（`DayAgendaModel.kt:257` 已有 `DayAgendaLogic.scheduleEntryForDate(...)` 可复用） |
| P1-2 | 日视图**待办带整块不出现**，「本周有作业」红点也不亮 | `taskBandData` 恒 `null`（`DayViewPageData` 默认，壳不传）；`DayTaskBandLogic.resolve(...)` 生产 0 调用（仅 `DayTaskBandModelTest`）；`courseTaskPresenceMap` 恒 `emptyMap()` ⇒ `hasTask = false`。Dart：`timetable_day_view_part.dart:620 final taskBand = _buildDayTaskBand(provider, settings, week, dayOfWeek);` | 壳里用 `repository.tasks` + `DayTaskBandLogic.resolve` 组 `taskBandData`，并把 `courseTaskPresenceMap` 填上 |
| P1-3 | 摘要卡大字标题是**自造中文**且与上一行重复：显示「第 3 周 · 周1」 | `ShellPageIndex.kt`（HEAD）503：`dateLabel = "第 $week 周 · 周$dayOfWeek",`；卡片上一行已经画 `DayViewStrings.weekLabel(state.week)`（`DayViewSummaryCard.kt:85-90`），大字位置是 `state.dateLabel`（`:108-117`，注释写「如 "10月27日 周二"」）。Dart `timetable_day_view_part.dart:585-591`：`DateFormat.MMMd(localeName)` + `_weekdayLabel` | 用 `MonthDay` 格式 + `DayViewStrings.weekdayLabel` 组 「10月27日 周二」，周次交给上一行 |
| P1-4 | 摘要卡缺「日程 N 项 / 作业 N 项」分支、缺议程时间区间、缺 4 类状态胶囊 | 壳只传 `courseCount`/`scheduleCount=0`（`ShellPageIndex.kt:505-506`），`taskCount`/`currentCourseName`/`conflictCount`/`nonCurrentWeekCourseCount`/`exams`/`firstStartTime`/`lastEndTime` 全走默认 ⇒ `resolveCountLabel` 永远第一个分支、`statusChips` 恒空（`DayViewSummaryModel.kt:76-83,177-199`）。Dart 侧卡内自己算 `conflictCount`（`day_view_summary_card.dart:119`），另有 `currentCourse`（`:42`）、`dayExams`（`:48`）、`taskCount`（`:58`） | 壳里把当日考试、进行中课程、冲突节数、首末时间算好传进 `buildSummaryState` |
| P1-5 | **停课课程在日视图整条消失**；「显示非本周课程」开关无效 | 壳过滤 `c.isActiveInWeek(week)`（`ShellPageIndex.kt:497-499`），而 `core/Course.kt:196-199`：`if (suspendedWeeks?.contains(week) == true) return false`。Dart `day_course_display_logic.dart:200-210` 用 `isInWeek`（停课照常列出）+ 非本周开关 `timetableShowNonCurrentWeekCourses`。壳还把 `isCurrentWeekCourse = true` 写死（`:511`）⇒ `DayViewCourseCard.kt:71-72` 的灰化 0.62 与 `:184-190` 的「非本周」徽标永不出现 | 改用模型层 `WeekGridCourseMapping.coursesForDay(...)`（见 P2-4），并按 `isInWeek` 算 `isCurrentWeekCourse` |
| P1-13 | 日视图恒可翻 **30 周 × 7 天**：`totalWeeks`/`visibleDays` 都没传 | `DayViewPage.kt:67-68` 默认 `visibleDays = (1..7)`、`totalWeeks = 30`，`pageCount = (totalWeeks * visibleDays.size)`（`:90`）。Dart `day_view_transition_controller.dart:282-284`：`visibleDayNumbers(settings).length * settings.semesterWeekCount` | 壳传 `totalWeeks = settings.semesterWeekCount`、`visibleDays = TimetableHostLogic.visibleDayNumbers(...)` |
| P1-14 | 考试卡座位文案中文硬编码，且与 ARB 不一致：屏上出现「座位: 3-12」 | `DayViewExamCard.kt:149-155`：`if (isNotEmpty()) append(" · ")` / `append("座位: $seat")`。ARB `examSeatLabel = '座位号'`，Dart 用法 `exam_list_screen.dart:320 '${l10n.examSeatLabel} $seat'` | 走 `ArbText("examSeatLabel", "座位号")`（`DayViewStrings` 补一条） |
| P2-8 | 日视图另 1 条中文硬编码（无障碍描述），值与 ARB 相同、纯分层问题 | `DayViewCommon.kt:143-145`：`Icon(imageVector = MiuixIcons.Tasks, contentDescription = "作业", …)`；ARB `courseTaskAction = "作业"`（`DayViewStrings.kt:47`） |
| P2-4 | **分层倒挂**：壳里 inline 重写了 `getCoursesForDay`，而模型层已有逐行对应实现 | 壳 `ShellPageIndex.kt:497-499` inline `filter {}`；模型 `WeekGridCourseMapping.kt:79-91 coursesForDay(allCourses, week, dayOfWeek, showNonCurrentWeekCourses)`（KDoc 明确写「Dart `getCoursesForDay`，`day_course_display_logic.dart:196`」）。两边行为不等（无排序、无「非本周」、停课判据相反） | 直接调 `coursesForDay`，删掉 inline 版本 |

### 7. 壳分派与守卫（跨页）

| 级别 | 缺陷 | 证据 |
|---|---|---|
| **P2-7** | 日视图这类「页面能开、点了没反应」的缺陷**任何测试都抓不到**：`DiagnosticsWiringGuardTest` 只覆盖 5 个诊断页，且它查的是**分支文本里**有没有 `= {}`；日视图的空 lambda 是页面签名里的**默认参数值**，分支文本里干净 | `DiagnosticsWiringGuardTest.kt:159-176` `MANAGED` 只有 `b.diagnostics / h.log / h.memory / h.perfReport / h.fixture`；`:178-184` `FORBIDDEN` = `=\s*\{\s*}` / `emptyList()` / `snapshot = null` / `DiagnosticsLogSnapshot.EMPTY` / `SettingsPageState()`。`grep -rn '"c3.day"' android/app/src/test` = 0 命中 |

### 8. 本族域级债（模型层摆设 / 渲染层中文字面量）

| 级别 | 缺陷 | 证据 |
|---|---|---|
| P2-1 | `TimetableGridMetrics` / `TimetableGridConfig` / `SectionTimeSlot`（166 行）是**纯摆设**：生产代码 0 引用，只有自己的测试在用 | `grep -rn "TimetableGridMetrics\|TimetableGridConfig\|SectionTimeSlot" android/app/src --include=*.kt` 去掉自身文件后只命中 `TimetableGridMetricsTest.kt:12,24,40,43,50,52,55,57,66`。它里面的 `defaultSectionTimeSlots()` 还自造了一套 08:00/08:45 的默认钟点（`:35-49`），与用户作息表无关 |
| P2-2 | `TimetableProfilesLogic` / `TimetableProfilesState`（`TimetableProfilesModel.kt`）生产 0 引用 | 只命中 `TimetableProfilesModelTest.kt:15,21,26,32,59,86,108,128,140`；真实页面用的是 `TimetableProfilesController`（`ShellPageIndex.kt:425,432`） |
| P2-3 | `DayExamSummary` 生产 0 引用 | 只命中 `DayViewSummaryModelTest.kt:47-48`；与 P1-1/P1-4 同源（考试通道整条没接） |
| P2-5 | 渲染层存在一整块**平行文案对象**（本域内、非本次改动面，但同目录）：`TimetableProfilesStrings` 36 条中文硬编码 | `TimetableProfilesPage.kt:73-107`：`object TimetableProfilesStrings { const val TITLE_PROFILES = "课表管理" … fun switchedToProfile(name: String): String = "已切换到 $name" }`，页内引用 31 处（`grep -c "TimetableProfilesStrings\." = 31`）。对应 ARB 键全部已存在（`TimetableStrings.kt:29-58` 有 `timetableProfilesTitle/switchedToProfile/createdProfile/…/coursesAndWeekSummary`）⇒ **有键不用、另抄一份**。已在 `cjk-literal-baseline.txt` 冻结 36 条 |

---

## 在途改动（他人，不入判）

`git status --porcelain` 共 70 行（审核开始时）。与本族相关、已按 HEAD 判、差异如下：

| 文件 | 差异要点 | 是否影响本次结论 |
|---|---|---|
| `composeP1/.../pages/course/CourseActionSheet.kt` | +49 行，**纯样式/版式**：`insideMargin = DpSize(16.dp, 0.dp)`（对齐 Dart 16 而非 miuix 默认 24）、内容底部补 `WindowInsets.navigationBars` + 16dp 呼吸、编辑按钮改 `ButtonDefaults.buttonColorsPrimary()` | 否（HEAD 版无这些，本报告所有弹层结论基于 HEAD；不把在途样式当缺陷） |
| `pages/ShellPageIndex.kt` | 「作业 → 查看课程」补 `pendingEditWeek`；`d2.taskList` 抽成 `TaskListHost`；删掉两个空实现参数 | 否（改动都在 d1/d2，`c1.week`/`c3.day` 分支逐字未动——已用 `git show HEAD:…` 对照） |
| `pages/ShellWiring.kt` | +11 行：新增 `pendingEditWeek` 字段与清理 | 否 |
| `pages/PagesShellActivity.kt` | 底栏 `DockSlot.TASK` 从 `shellSampleTaskViewState()` 死页改 `TaskListHost` | 否（任务域，不属课表核心族） |
| `lib/l10n/app_zh.arb` | +2 键（`monthOverviewMoreDays` 及其元数据），HEAD 3930 键 → 工作区 3932 键 | 否（已对 HEAD 版重跑文案对拍，243 条 0 不符） |
| `lib/widgets/timetable/month_view/**`、`lib/domain/month_*.dart` 等 | 月视图在途重构 | 否（月视图不在本族审核对象内） |

---

## 我没能验的

1. **真机观感**（周视图卡片是否被手势条压、弹层底部是否被小白条压、深色模式对比度）：需要用户在 `dev` 变体 `PagesShellActivity` 上逐页对照，agent 不碰设备。
2. **L0/L1/L2 是否真绿**：按纪律不跑 `test-kotlin-module.ps1` 与 Gradle，所以「231 例/251 例绿」这类来自提交信息与既有文档的说法**没有被本报告验证**，只作为背景。
3. **调课弹层在真实仓储上的写库效果**（跨周挪课是否与 Dart 等价）：只做了静态对读（`CourseActionDispatcher.rescheduleOccurrence:221-295`），没有跑数据等价探针。
4. **周视图「长按空白格」的完整 Dart 流程**：Dart 是「长按 → 出虚线框 → 拖动调跨度 → 点框进加课」（`timetable_empty_slot_layer.dart:46,68,139-158`），Compose 是「长按 → 直接进加课」。既有审核文档把它记成 G2/P2「部分」，我确认了源码事实但**没有判定它算 P1 还是 P2**（属交互子系统缺口，不是本刀引入的错）。
5. **周次选择弹层与 Dart 的版式差异**：Dart `onShowWeekSelector` 的弹层实现不在我读过的文件里，只确认了入口与文案键（`selectWeekTitle`）存在。
6. **ARB 六个语言版本**：只对 `app_zh.arb`（判据指定），en/ja/ko/zh_HK/zh_TW 未对拍。

---

## 审核方法（跑了哪些命令、扫了哪些文件、多少行）

### 1. 改动面确认

```
git log --since="2026-10-28 00:00" --name-only --pretty='== %h %ad %s' --date=short -- .../pages/timetable .../pages/course
→ 962a534b(弹层三件) / ec76e320(KDoc) / a3902f85(周视图五件) / bbdd629a / 1e4c57b7 / 9f19cd26 / 951967b1 / 86ed9fe9 / a49930cf / 09f3787d / 8866b3b5

git status --porcelain -- .../pages/timetable .../pages/timetable/day   → 空（日视图不是在途）
git status --porcelain | wc -l                                          → 70
git log -1 --format='%H %h %ad %s'                                      → 3f3b7354 … 2026-10-29 20:10:12
```
在途文件的判据一律取 `git show HEAD:<path> | cat -n`，逐个核对过本报告引用的行号（`ShellPageIndex.kt` 477-523、`ShellWiring.kt` 412-657 与 529、`CourseActionSheet.kt` 143-302）。

### 2. 源码阅读面（Kotlin 约 11,900 行 + Dart 约 6,300 行，合计约 18,200 行）

- 渲染层（composeP1）：`TimetableWeekPage.kt` 469、`CourseGridCard.kt` 337、`TimetableWeekdayHeader.kt` 390、`TimetableTimeColumn.kt` 207、`TimetableWeekGrid.kt` 237、`TimetableTopBar.kt` 356、`day/*.kt` 1821、`CourseActionSheet.kt`（HEAD 679）、`CourseFollowupSheets.kt` 944、`CourseNoteSheet.kt` 321、`app/TimetableHost.kt` 137
- 模型层（main）：`TimetableStrings.kt` 276、`WeekViewStyle.kt` 102、`WeekGridCourseMapping.kt` 240、`WeekAgendaModel.kt` 235、`TimetableGridMetrics.kt` 166、`TimetableStyleMapping.kt` 119、`day/{DayAgendaModel 287, DayTaskBandModel 219, DayViewPaging 83, DayViewSummaryModel 201, DayViewStrings 200}`、`app/CourseActionDispatcher.kt` 406、`pages/course/CourseActionSheetModel.kt` 906
- 壳：`ShellPageIndex.kt`（HEAD）、`ShellWiring.kt`（HEAD 748）、`PagesShellActivity.kt`
- Dart 真相源：`widgets/course_card.dart` 975、`widgets/timetable/timetable_day_column.dart` 334、`timetable_weekday_header.dart` 466、`timetable_empty_slot_layer.dart` 162、`domain/day_course_display_logic.dart` 404、`widgets/course_action_sheet.dart` 1168、`course_followup_sheets.dart` 1015、`course_note_sheet.dart` 363、`screens/timetable_day_view_part.dart` 984、`controllers/day_view_transition_controller.dart`、`domain/timetable_layout.dart`

### 3. 文案逐字对拍（D3，机械）

```
PYTHONIOENCODING=utf-8 python - <<'PY' … 解析 6 个 *Strings.kt 的 ArbText(key, value)，与 app_zh.arb 比对 …
→ declarations parsed= 243 exact-match= 242 key-missing= 0 value-diff= 1
  （首轮差异是 \n 转义比较口径不同；按 Kotlin 转义解码后重跑：）
→ VALUE DIFF after Kotlin-escape decoding: 0
（再用 HEAD 版 ARB 复跑：HEAD keys: 3930  WT keys: 3932  added: monthOverviewMoreDays
 → declarations: 243  mismatches vs HEAD: 0）
```
渲染层 CJK 字面量扫描（**用仓库自带扫描器**，不用裸 grep——bash 的 `grep '[\u4e00-\u9fa5]'` 不认 `\u` 转义，会给出大量假阳性，我第一版就踩了这个坑）：

```
PYTHONIOENCODING=utf-8 python scripts/i18n-cjk-baseline.py
→ 中文字面量总计 188 条，分布 24 个文件
    36  com/mutx163/qingyu/pages/timetable/TimetableProfilesPage.kt
     1  com/mutx163/qingyu/pages/timetable/day/DayViewCommon.kt
     1  com/mutx163/qingyu/pages/timetable/day/DayViewExamCard.kt
  （其余 21 个文件都不在本族）

逐条定位（同一套字面量规则重跑）：
→ DayViewCommon.kt 145  '作业'（contentDescription）        = P2-8
→ DayViewExamCard.kt 153 '座位: $seat'                       = P1-14
基线核对：android/app/src/test/.../i18n/cjk-literal-baseline.txt 三个文件分别登记 36 / 1 / 1
⇒ 本族**没有新增**中文字面量，这 2 条是已冻结的存量债（棘轮绿，但按 rubric D3 仍是缺陷）
```

### 4. 接线扫描（D1）

```
grep -rn "c3.day\|c1.week" .../ShellPageIndex.kt      → 477 / 412 两处分支
diff DayViewPage 形参清单 vs c3.day 实参清单           → 缺 6 个回调 + courseResolver + totalWeeks + visibleDays + onPageChanged
grep -rn "holidayForDay" android/app/src              → 仅 TimetableWeekGrid.kt:56,116（0 调用方）
grep -rn "isHighlighted" …/pages/timetable            → 仅 CourseGridCard.kt:117,152（0 调用方）
grep -rn "DayAgendaEntry.ScheduleEntry|ExamEntry" … | grep -v /test/   → 无构造点
grep -rn "DayTaskBandLogic.resolve(" android/app/src → 只命中 test
grep -rn "fun shellTimetableMenuPageId" …             → ShellWiring.kt:755（8 条菜单 id 全部有落点，另有 MoreFeaturesNavigationGuardTest 守卫）
```

### 5. 分层扫描（D4）

```
python: 遍历 composeP1（151 文件 / 2.12 MB）统计模型层 public 件被引用次数
→ 0 引用：TimetableGridMetrics / TimetableGridConfig / SectionTimeSlot / DayViewPageTarget /
          DayViewSummaryLogic（渲染层 0，仅壳用）/ DayExamSummary / TimetableProfilesLogic / TimetableProfilesState
grep -rn "<sym>" android/app/src | 排除自身文件 复核 →
   TimetableGridMetrics/GridConfig/SectionTimeSlot：只被 TimetableGridMetricsTest.kt 用（= P2-1）
   TimetableProfilesLogic/State：只被 TimetableProfilesModelTest.kt 用（= P2-2）
   DayExamSummary：只被 DayViewSummaryModelTest.kt 用（= P2-3）
WeekViewStyle 38 个属性逐个统计读取次数 → 13 个在渲染层 0 读（其中 6 个在模型层有消费，
   7 个全仓只有「映射赋值 + 测试断言」：holidayMarkingEnabled / showWeatherOnCard /
   backToCurrentWeekOpacity / cardTitleColor{Light,Dark} / cardDetailColor{Light,Dark}）= P1-11
```

### 6. 样式守卫（D5）

```
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain timetable
→ timetable 共 9 处：R5 ×7（CourseGridCard / DayViewCommon / DayViewCourseCard /
   DayViewScheduleCard / DayViewTaskBandCard / MonthDayCell / MonthPanelOverview）、
   R2 ×2（MonthViewPage:424、TimetableWeekPage:377）
cat tool/compose_style_baseline/timetable.txt → 9 行，逐条带「例外：…」理由
⇒ 基线外违规 0 处
```

### 7. 测试面（D6）

读了 `android/app/src/test/kotlin/com/mutx163/qingyu/pages/timetable/`（8 文件 2414 行）、
`.../timetable/day/`（6 文件 815 行）、`.../pages/course/`（11 文件，含 5 个 `*StringsParityTest`）、
`.../pages/shell/DiagnosticsWiringGuardTest.kt`、`MoreFeaturesNavigationGuardTest.kt`。

```
grep -rn '"c3.day"\|DayViewPage(\|DayViewPageData(' android/app/src/test → 0 命中（壳接线 0 覆盖）
grep -n "fun \`" WeekGridCourseMappingTest.kt → 12 例，全部按行为命名（透明度/排序/角标优先级/停课周）
sed -n '95,126p' WeekViewStyleMappingTest.kt → 断言 style.backToCurrentWeekOpacity==0.8f、
   assertFalse(style.showWeatherOnCard) —— 这两个值渲染层从不读取（= P1-11 的测试侧）
```

### 8. 既有审核文档复核

读了 `docs/plans/2026-10-29-compose-week-view-audit.md`（271 行）、`2026-10-29-compose-course-action-sheet-audit.md`（381 行），逐条回源码复核。**与源码不符 / 需修正 4 处**：

1. week-view audit §六（第 262 行）：「作业指示 / 备注角标 / 单节提醒铃铛 | 未做 | **周视图 Dart 只画作业指示**；另两项日视图才有」
   → **不符**。`timetable_day_column.dart:138-150` 周视图同时传 `hasReminder:` 与 `isHoliday:`/`isSuspended:`，`course_card.dart:450-464` 紧凑卡画的是「铃铛 + 假 + 停 + 备注」整行角标。周视图确实也画另外两项。
2. `TimetableWeekPage.kt:80-81` KDoc：「**设置全部下传**：卡面字段/字号/材质/冲突开关/时间列显示档/星期栏字色都由 `WeekViewStyle` 决定，页面不再写死」
   → **部分不符**。`WeekViewStyle` 的 38 个属性里有 5 个渲染层 0 读取（P1-11），「材质」也只落到 `surfaceStyle` 一个键，课卡标题/详情色仍由 `calculateInk(rawColor)` 自算（`CourseGridCard.kt:130-132`）。
3. week-view audit §六（第 258 行）：「假期灰显 / 调休标记 | 课卡 `isHoliday` 通道已留，宿主恒传 false」
   → 事实**对**，但**等级低估**：这不是内部债（P2），用户在假期当天看到课卡照常高亮可点，是可见缺功能（本报告记 P1-7）。
4. course-action-sheet audit §零 表格：「详情行 … 8 类行」+ 「**8 行可点详情**」
   → **可点性不实**：只有备注/作业两行可点（`CourseActionSheet.kt` HEAD 173-181）。

### 9. 未做的事（纪律）

- 没有改任何 `.kt` / `.dart` / `.arb` / 构建脚本；没有 `git add` / `commit`；没有动他人的在途文件。
- 没有跑 Gradle、没有跑 `scripts/test-kotlin-module.ps1`；只跑了秒级的 `compose-style-lint.ps1`。
- 唯一写入的文件：本文件。

---

# 二轮验真（2026-10-29 二轮，基线 HEAD bf0e5a57 + 当前工作树）

> 复核时间：2026-10-29 22:28 ~ 23:40。
> 复核方式：**全部重新定位**（`grep -n` / 读当前工作树），不沿用一审行号。
> 本族自 `3f3b7354` 起**没有任何提交**（`git log 3f3b7354..HEAD -- <本族路径>` = 空），
> 且本族路径 `git status --porcelain` 当时为空 ⇒ 一审结论的源码侧前提未变。

## 状态表（25 条逐条）

| # | 一审结论 | 二轮状态 | 依据 / 谁改的 |
|---|---|---|---|
| P0-1 | 日视图课卡「作业」「备注」胶囊无落点 | **部分修复（我：页面侧已改；端到端仍存在，等壳）** | 页面回调已改可空 + 未接线不渲染；壳 `ShellPageIndex.kt:532-` 仍未传，需按下节「壳接线请求 §2」 |
| P0-2 | 点星期栏某天进日视图不带那天 | **部分修复（我：`initialDayOfWeek` 改显式意图；端到端仍存在）** | `DayViewPage` 入参改 `Int?`（null = 今天）；壳 `ShellWiring.kt` 的 `onOpenDay = { _ -> … }` 仍丢参，见壳接线请求 §1 |
| P1-1 | 日视图日程/考试卡永不出现（生产 0 构造） | **部分修复（我：装配器已交付；端到端仍存在）** | 新增 `day/DayViewDataAssembler.kt`（造 `ScheduleEntry` / `ExamEntry`）；壳仍只造课程条目 |
| P1-2 | 待办带整块不出现、作业红点不亮 | **部分修复（我）** | 同一装配器输出 `taskBandData` + `courseTaskPresence`；壳未传 |
| P1-3 | 摘要卡大字标题自造中文「第 N 周 · 周1」 | **部分修复（我）** | 装配器改 `DayViewStrings.dateWithWeekday`（ARB `monthViewAgendaTitle`）→「10月27日 周二」；壳仍是旧拼法 |
| P1-4 | 摘要卡缺 count 分支 / 时间区间 / 4 类状态胶囊 | **部分修复（我）** | 装配器填 `taskCount/currentCourseName/conflictCount/nonCurrentWeek/exams/first-last` |
| P1-5 | 停课课整条消失、非本周开关无效 | **部分修复（我）** | 装配器改用 `WeekGridCourseMapping.coursesForDay`（停课照常列出）+ `isInWeek` 判本周 |
| P1-6 | 点某天进日视图不带该天（与 P0-2 同源） | **部分修复（同上）** | 同 P0-2 |
| P1-7 | 课卡缺「假期」角标 + 0.3 压淡（`holidayForDay` 死参数） | **已修（我）** | 新增 `WeekHolidayMarking.kt`；`TimetableHost` 用 `HolidayPreferences` 算 `holidayOf`；`TimetableWeekPage` 传 `holidayForDay`；`CourseGridCard` 画「假」角标 |
| P1-8 | 课卡缺「停课」角标 | **已修（我）** | `CourseGridCard` 角标行改为「假 / 停 / 冲突」一行多枚（Dart `_buildBadgeRow` 顺序与优先级） |
| P1-9 | 课卡缺作业指示点 / 单节提醒铃铛 | **部分修复（我：作业点已修；铃铛未做）** | `WeekCardModel.hasHomework` → 卡面左上白底红点；铃铛**无数据源**（Kotlin 侧没有任何「单节课提醒」存储，见「未修原因」） |
| P1-10 | 「正在上课」高亮永不出现 | **误判（反证）** | Dart 周网格 `timetable_week_grid.dart:130-136` 调 `buildDisplayItems` 时**不传** `currentCourseIds`，形参默认 `const <String>{}`（`timetable_screen.dart:1212`）⇒ 周视图 `isCurrentCourse` 恒 false。Compose 不高亮与 Dart 一致；只有日视图才标 |
| P1-11 | 7 个「设置改了渲染层不读」的字段 | **已修（我）** | ①`backToCurrentWeekOpacity` → 浮钮 `.alpha()`；②`cardTitleColor{Light,Dark}`/`cardDetailColor{Light,Dark}` → 新增 `CourseCardInk.kt`（WCAG 对比度守卫，逐行移植 `course_color_palette.dart:352-408`）并在 `CourseGridCard` 生效；③`showWeatherOnCard`+三档开关 → 卡面天气行；④`holidayMarkingEnabled` → gate `holidayOf` |
| P1-12 | 日视图课卡天气行参数无调用方 | **部分修复（我：取数胶水已交付）** | 新增 `day/DayViewWeather.kt`；装配器输出 `weatherLines`、卡面已吃 `weatherInfo`；需壳传 `weatherProvider` |
| P1-13 | 日视图恒可翻 30 周 × 7 天 | **仍存在（壳侧）** | 页面参数 `totalWeeks`/`visibleDays` 早就存在，壳不传；见壳接线请求 §2 |
| P1-14 | 考试卡「座位: 」中文硬编码且与 ARB 不符 | **已修（我）** | `DayViewStrings.examSeatLabel`（ARB `examSeatLabel` =「座位号」）+ `seatLabel()`；`DayViewExamCard` 改用它 |
| P2-1 | `TimetableGridMetrics` 三件生产 0 引用 | **仍存在（未做）** | 删除属独立清理批次，本轮未动（风险：同时要删它的 119 行单测） |
| P2-2 | `TimetableProfilesLogic`/`State` 生产 0 引用 | **仍存在（未做）** | 同上；真实页面用 `TimetableProfilesController` |
| P2-3 | `DayExamSummary` 生产 0 引用 | **已修（我）** | 装配器用它填摘要卡考试胶囊 |
| P2-4 | 壳 inline 重写 `getCoursesForDay`（分层倒挂） | **部分修复（我：模型层唯一实现已就位）** | 装配器内改调 `WeekGridCourseMapping.coursesForDay`；壳仍在 inline filter，等 §2 |
| P2-5 | `TimetableProfilesStrings` 36 条平行文案对象 | **仍存在（未做）** | 需改 31 处引用 + 下调 CJK 基线；属独立批次（且基线文件不在我写作用域） |
| P2-6 | 周网格行数口径 `coerceAtLeast(12)` vs `sections.length` | **已修（我）** | `TimetableWeekPage: sectionCount = sectionTimes.size`（Dart `timetable_settings.dart:2479`） |
| P2-7 | 守卫/测试覆盖不到壳接线 | **仍存在（未做）** | `DiagnosticsWiringGuardTest` 在 `test/pages/shell/**`（不在我写作用域）；建议把 `c1.week`/`c3.day` 加进 `MANAGED` 并补一条「页面签名不许有 `= {}`」的文本守卫 |
| P2-8 | `DayViewCommon` 中文硬编码「作业」 | **已修（我）** | 改 `DayViewStrings.courseTaskAction.zh` |
| P2-9 | 既有文档「8 行可点详情」不实 | **已修（文档，我）** | 见本文一审核 §8 第 4 条；本轮不动 `course/**` 源码 |

**计数**：已修 8 条（P1-7、P1-8、P1-11、P1-14、P2-3、P2-6、P2-8、P2-9）；
部分修复 11 条（P0-1、P0-2、P1-1~P1-6、P1-9、P1-12、P2-4）；
仍存在 5 条（P1-13、P2-1、P2-2、P2-5、P2-7）；误判 1 条（P1-10）；
他人泳道在修 0 条（本族没有别人在改的文件）。

---

# 修复（本轮实际改动）

> 只改了下表文件；`ShellPageIndex.kt` / `ShellWiring.kt` / ARB / CJK 基线**一个字节都没动**（见后两节请求）。

## 新增文件（4 个，全部在 `main:` 模型层）

| 文件 | 作用 | 对应缺陷 |
|---|---|---|
| `main/…/pages/timetable/TimetableDateLogic.kt` | 周次↔日期换算（从渲染层搬出，唯一实现） | P2-4 支撑；装配器与周视图共用 |
| `main/…/pages/timetable/CourseCardInk.kt` | 标题/详情墨色的 WCAG 对比度守卫（移植 `course_color_palette.dart:352-408`） | P1-11（课卡色四项） |
| `main/…/pages/timetable/WeekHolidayMarking.kt` | 「某天是否假期」（官方年度 + 自定义条目合并） | P1-7 |
| `main/…/pages/timetable/day/DayViewDataAssembler.kt` | 日视图整页装配（课程/日程/考试/待办/摘要/天气） | P1-1~P1-5、P2-3、P2-4 |
| `main/…/pages/timetable/day/DayViewWeather.kt` | 日卡天气取数胶水（provider + 设置 → 一行文本） | P1-12 |

## 修改文件

| 文件 | 改了什么 | 对应缺陷 |
|---|---|---|
| `composeP1/…/day/DayViewPage.kt` | 6 个回调 + `onOpenCourse`/`onToggleTask`/`onViewAllOverdue` 改**可空能力**（null ⇒ 入口不渲染，不留 `= {}`）；`initialDayOfWeek: Int?`（null = 今天，非 null 走 `normalizeDayOfWeek`）；`DayViewPageData.weatherLines`；新增 `dayViewPageDataOf(DayViewDay)` 映射 | **P0-1 / P0-2 / P1-12** |
| `composeP1/…/day/DayViewScrollContent.kt` | 同上可空化；待办带/日程/考试/课程卡按能力渲染；天气行透传 | P0-1 |
| `composeP1/…/day/DayViewCourseCard.kt` | 备注/作业胶囊**未接线就整块不画**；卡片点击可空 | **P0-1** |
| `composeP1/…/day/DayViewScheduleCard.kt` / `DayViewExamCard.kt` | `onTap` 可空（无落点不可点） | P0-1 |
| `composeP1/…/day/DayViewTaskBandCard.kt` | 勾选框/编辑箭头按能力渲染（无落点不画） | P0-1 |
| `composeP1/…/day/DayViewExamCard.kt` | 「座位: 」→ `DayViewStrings.seatLabel()`（ARB「座位号」） | **P1-14** |
| `composeP1/…/day/DayViewCommon.kt` | `contentDescription = "作业"` → ARB `courseTaskAction` | **P2-8** |
| `main/…/day/DayViewStrings.kt` | 新增 `examSeatLabel`、`monthViewAgendaTitle`、`courseTaskAction`、`dateWithWeekday()`、`seatLabel()` | P1-14 / P1-3 / P2-8 |
| `main/…/TimetableStrings.kt` | 新增 `holidayBadgeLabel`、`suspendedBadgeLabel`、`courseTaskAction`、三条天气模板 + `formatWeatherLine()`；全部登记进 `arbTexts` | P1-7 / P1-8 / P1-11 |
| `composeP1/…/CourseGridCard.kt` | 角标行「假/停/冲突」多枚；作业红点；天气行；墨色改走 `CourseCardInk`（吃设置里的四项颜色）；`dark` 提升 | P1-7 / P1-8 / P1-9 / P1-11 |
| `main/…/WeekGridCourseMapping.kt` | `WeekCardModel` 增 `hasHomework`/`weatherText`；`displayCards`/`cardsForWeek` 增 `weatherOf`；KDoc 补「正在上课」误判反证 | P1-9 / P1-11 / P1-10 |
| `composeP1/…/TimetableWeekPage.kt` | 新增 `holidayOf`/`weatherOf` 参数并下传网格；`sectionCount = sectionTimes.size`；浮钮 `.alpha(backToCurrentWeekOpacity)`；日期换算改为委托 `TimetableDateLogic` | P1-7 / P1-11 / **P2-6** / P2-4 |
| `composeP1/app/TimetableHost.kt` | 新增 `weatherProvider` 参数；算 `holidayOf`（`HolidayPreferences` + `enableHolidayMarking`）与 `weatherOf`（三档开关 + `WeatherStrings.categoryLabel`）；下传页面 | P1-7 / P1-11 |

## 未完成 / 草稿状态（如实）

- **校验状态：未编译、未跑单测**（按纪律不跑 Gradle / `test-kotlin-module.ps1`）。我改的都是 Kotlin 源码，**需要你那边 L0 先验 `pages/timetable` 模块**；如果红了，失败点发我，我按行修。
- 我**没有新增测试文件**（时间不够）。建议下一批补：`DayViewDataAssemblerTest`（日程/考试/待办三通道 + 摘要文案）、`CourseCardInkTest`（对比度 2.0 边界）、`WeekHolidayMarkingTest`（官方+自定义合并、标记关闭）。
- `TimetableWeekGrid.kt` 本身没改（`holidayForDay` 参数本来就有，只是没人传；现在由页面传）。

---

# 壳接线请求（请 Lead 统一应用到 `ShellPageIndex.kt` / `ShellWiring.kt`）

> 我这边**没有**也**不会**改这两个文件。下面两段是可直接替换的精确分支体；需要新增的两个意图字段请加在 `ShellWiring`（`pendingEditWeek` 旁边）。

## 0. `ShellWiring` 新增字段（必需，否则 §1 的 `{ day -> … }` 没处存）

```kotlin
/**
 * 从星期栏某一天点进日视图时要打开的那一天（1..7）。
 *
 * 与 [pendingEditWeek] 同属「跨子树传一次、用完即清」的意图载体：
 * 点「周五」就存 5，`c3.day` 读它作为 `initialDayOfWeek`；
 * 从底栏等没有具体日期的入口进来时为 null ⇒ 日视图回落今天。
 */
var pendingDayViewDayOfWeek: Int? = null
```

`clearAddCourseIntent()` 附近不必清它（它不是加课意图）；但**日视图页面 `onPageChanged` 里可以清**（可选）。

## 1. `ShellWiring.kt`：「点星期栏某天」带日期（P0-2 / P1-6）

把现有的

```kotlin
onOpenDay = { _ -> onNavigate("c3.day") },
```

替换为

```kotlin
onOpenDay = { dayOfWeek ->
    wiring.pendingDayViewDayOfWeek = dayOfWeek
    onNavigate("c3.day")
},
```

## 2. `ShellPageIndex.kt`：`c3.day` 分支整体替换（P0-1 / P0-2 / P1-1~P1-6 / P1-12 / P1-13 / P2-4）

```kotlin
        "c3.day" -> {
            val repository = wiring.timetable
            var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
            DisposableEffect(repository) {
                val subscription = repository.observe { snapshot = it }
                onDispose { subscription.close() }
            }
            val settingsModel = wiring.settingsModel
