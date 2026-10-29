# Compose 周视图 · 重构质量审核（2026-10-29）

> 触发：用户「周视图页面审核一下重构质量，功能有没有复刻完，页面有没有一模一样做过来，把他完善好」。
> 审核对象：`TimetableWeekPage` 及其全部子件（`pages/timetable/` 顶层 6 件 + 宿主 2 件）。
> 对照物：Flutter 正式版（包 `com.mutx163.qingyu`）**同一台真机截图** + Dart 源码逐文件。
> 唯一判据是 Dart 源码与 ARB；本仓文档（含 L4 清单）与旧认领文件只作线索。

---

## 零、结论（先看这段）

**判定：旧版「看着像」，不是复刻。** 2026-10-27 域审核给 P3-C1 的「需重做」结论**到本次审核开始时仍然成立**，
并且具体到可逐条数出来的程度：

| 维度 | 旧版实况 | 本次处置 |
|---|---|---|
| 设置联动 | 设置里 40+ 个与周视图有关的键，**只有 4 个**（隐藏周末/时间列宽/节高/长按开关）被读了 | 新增 `WeekViewStyle` 一层，把 **33 个键**映射到渲染层，映射点单测钉住 |
| 视觉版式 | 星期标签「一/二」、日期只写日号、今天用蓝胶囊、左端写「10月」、课卡 13sp + 16/10dp 圆角、网格线自绘 | 全部按 Dart 改：`周一..周日`、`MM/DD`、今天下划线、`8 周`、9/8sp + 8dp 圆角、**删掉自绘网格线** |
| 冲突排版 | 自创「同天重叠按列平分」（Interval Coloring），Dart 里根本没有 | 改成 Dart 口径：**整列宽叠放 + 冲突透明度 + 左上小字 + 右上角标** |
| 考试/日程 | 周网格里完全没有 | 新增 `WeekAgendaModel`（钟点→节次映射、考试过期、跨天日程、排序）并接进网格与表头圆点 |
| 交互 | 点空白格就加课（Dart 点击无操作，只有长按才出现加课）；无「回本周」；无考试/日程卡 | 按 Dart 改：点空白无操作、长按加课、新增「回本周」浮钮、考试/日程卡可点 |
| 文案 | 渲染层 12 处中文字面量、其中 5 处是自造（ARB/Dart 都没有） | 全部改走 `TimetableStrings`（ARB 逐字）；删掉伪造的 ARB 键 `noCourseThisWeek` |
| 分层 | 模型层 4 件在渲染层 **0 引用**（渲染层自己重写算法） | 渲染层只调 `WeekGridCourseMapping` / `WeekAgendaLogic` / `WeekViewStyle` / `TimetableStrings` |

**现在到什么程度**：页面主体（表头 / 时间列 / 网格 / 课卡 / 考试日程落格 / 周切换 / 回本周 / 设置联动 / 文案）已按 Dart 复刻；
**还差的 6 项都在本页之外**（壁纸与玻璃坞、下拉快捷导入、飞行动效、天气行、情侣叠加、日视图按天进入），见 §六。
**真机一次都没验**（agent 只能声明编译与 JVM 单测，见 §五）。

---

## 一、审核方法

1. 读 Dart 侧周视图全部源码（`timetable_screen.dart` 1842 行、`widgets/timetable/*.dart` 55 件中与周视图相关的 20 余件、
   `domain/day_course_display_logic.dart`、`domain/week_grid_agenda_placement.dart`、`domain/timetable_layout.dart`）；
2. 逐件对照 Compose 渲染层，把「Dart 有的 / Kotlin 没有的 / Kotlin 自造的」三类分开记；
3. 用真机基线截图（`.agents/golden/ui-baseline-2026-10-26/`，Flutter 正式版 1280×2772）核对版式口径；
4. 重构后用 **L0（模块 JVM 单测）+ L1（编译闸门）+ 样式守卫 + 咬合探针** 四道证据收口。

---

## 二、逐项对照（Dart 出处 → 旧 Compose → 现在）

### A. 页面骨架 / 周切换

| # | Dart 行为（出处） | 旧 Compose | 现在 |
|---|---|---|---|
| A1 | 顶栏只有一条「轻屿课表」+ 右上「更多」（`timetable_title_bar.dart`） | 已有 `TimetableTopBar`（2026-10-28 补） | 保持，标题点击 = 切课表流程（Dart `TimetableProfileSwitcherTrigger`） |
| A2 | `PageView` 1..N 周，停稳后写回 `provider.currentWeek`（`week_pager_controller.dart:199-204`、`:326`） | `HorizontalPager` + `onWeekChanged` | 保持（宿主 `repository.setCurrentWeek`） |
| A3 | 周次选择：点星期栏左端「8 周」开弹层（`timetable_weekday_header.dart:174-189`） | Dialog + 自造中文 | 保持交互，文案改 ARB；高亮「真实本周」而不是「当前被浏览周」 |
| A4 | 「回本周」浮钮：浏览周 ≠ 按开学日算出的真实周时出现（`timetable_screen.dart:1457-1480`） | **无** | 新增；判据 `currentSemesterWeek()` 复用 Dart 口径 |
| A5 | 「本周无课」**没有空态卡**（`grep 本周没有排课 lib/` = 0） | **自造**空态卡 + 自造文案 | **删除**（无课就是空白网格） |

### B. 星期表头（`timetable_weekday_header.dart`）

| # | Dart 行为 | 旧 Compose | 现在 |
|---|---|---|---|
| B1 | 左端 `{week} 周`（ARB `currentWeekCompact`，10sp、w800） | 「10月」/「N周」（漏空格） | `TimetableStrings.formatCurrentWeekCompact`，10sp w800 |
| B2 | 星期标签 `周一..周日`（ARB `weekdayMon..Sun`） | 「一/二/…」（错用了 short 那套） | ARB 周X |
| B3 | 日期 `MM/DD` 两位补零（`:309`） | 只画日号 | `MM/DD` |
| B4 | 今天 = 底部 2dp 强调色下划线（alpha .35，`:272-281`） | 蓝胶囊 + 白字（自造） | 下划线 |
| B5 | 选中日与今天互斥，选中用强调色（`:246`） | 无选中态 | `selectedDayOfWeek` 支持 |
| B6 | 考试红点 + 日程圆点（各 4dp，`:317-361`） | **无** | 已接（数据来自宿主 `exams` / `scheduleItems`） |
| B7 | 字色/强调色读设置 `weekdayBarFontColor*` / `weekdayBarAccentColor*`（`:210-237`） | 固定 `QingyuTheme.primary/secondaryText` | 读设置 |
| B8 | 壁纸明暗自适应（`homePageOverWallpaperInk`） | — | **未做**（Compose 无壁纸管线，走 Dart「无壁纸」分支） |

### C. 时间列（`timetable_section_time_cell.dart`）

| # | Dart | 旧 Compose | 现在 |
|---|---|---|---|
| C1 | 三档显示：`hidden` / `startOnly` / `startAndEnd`（`:60-65`） | 永远两行 | 读 `sectionTimeMode` |
| C2 | 字号 `compactFontSize` clamp(8,11) / (compact-2) clamp(6,10)，行高 1.05 | 用 `footnote1/footnote2` 字阶 | 按设置字号 |
| C3 | 字色读 `timeAxisFontColor*`，次要行 0.72/0.70 压淡 | 固定主题次要色 | 读设置 |
| C4 | 无「当前节次高亮」 | 自造高亮（虽未启用） | 删除 |

### D. 课程卡（`course_card.dart` 紧凑分支）

| # | Dart | 旧 Compose | 现在 |
|---|---|---|---|
| D1 | 七个内容开关（课名/教师/地点/时间/时间标签/周次/简介，`:1405-1413`） | **一个都没读**，固定画课名/教师/地点 | 全部读设置 |
| D2 | 字号 `courseCardFontSize`（默认 9），详情 = 标题-1 clamp(7,14)，小字 = 详情-1 | `footnote2`（13sp）偏大 | 按设置字号 |
| D3 | 圆角 8dp、外缩 = `timetableCourseCardGap.clamp(0,3)`（默认 1.25） | 圆角 10dp、外缩硬编码 1/1.5 | 8dp + 设置内缩 |
| D4 | 非本周透明度 **0.62**（`kNonCurrentWeekCourseOpacity`） | 0.45（偏淡） | 0.62 |
| D5 | 冲突透明度 = `timetableConflictCourseOpacity`（默认 0.70） | 固定 0.92 | 读设置 |
| D6 | 「非本周」是左上角**小字**；「冲突」= 左上小字 + 右上角标（角标受 `showConflictBadgeOnTimetable` 控制） | 两枚胶囊、语义混用 | 照 Dart |
| D7 | 停课 alpha 0.4 / 假期 alpha 0.3（`CourseCard.build`） | 无 | 已加（假期数据未接，见 §六） |
| D8 | 材质 `solid` / `gaussian` / `refraction`，无壁纸时后两档退化成半透明实体 | 一律 0.92 纯色 | 三档（降级口径已写注释） |
| D9 | 统一卡色 `timetableUseUnifiedCardColor` + `timetableUnifiedCardColor` | 无 | 已接 |
| D10 | 卡面标题/详情色 `courseCardTitleColor*` / `courseCardDetailColor*`，课程自带 `textColor` 优先 | 固定 `calculateInk` | 已接 |
| D11 | 内容对齐 `courseCardVerticalAlign` / `HorizontalAlign` | 固定居中 | 已接 |
| D12 | 天气行（`CourseWeatherDisplay`，受 `weatherShowOnWeekCard` 等 4 键控制） | 无 | **未做**（Compose 天气数据未接进课表宿主，见 §六 P1） |
| D13 | 备注角标 / 单节提醒铃铛 / 作业指示（`hasHomeworkInWeek`） | 无 | **未做**（周视图 Dart 只画作业指示；另两项是日视图） |

### E. 网格与冲突（`timetable_week_grid.dart` / `timetable_day_column.dart`）

| # | Dart | 旧 Compose | 现在 |
|---|---|---|---|
| E1 | **没有背景网格线**（`gridLines` 只是空白标记槽） | Canvas 自绘横竖线 | 删除 |
| E2 | 课卡整列宽 `Positioned(left:0,right:0)`，重叠按排序压叠 | 自创列平分 | 整列宽叠放 |
| E3 | 非本周：默认不显示；开了开关也只显示「没被本周压住」且「离本周最近」的那门；已结课不显示（`day_course_display_logic.dart:196-283`） | 简单按 `isInWeek` 过滤 | 三条判据全部实现（`WeekGridCourseMapping`） |
| E4 | 排序：开始节次 → 本周课靠后 → 结束节次 → id | 开始节次 → 结束节次 | 照 Dart |
| E5 | 冲突索引整周算一次（`CourseDomain.buildConflictMap(week)`） | 每人各算一套（自写 cluster） | 复用 `CourseDomain` |
| E6 | 日列圆角（首日左/末日右，半径 12，`groupedDayColumnBorderRadius`） | 无 | **未做**（P2，与无壁纸时的观感差异很小） |

### F. 考试 / 日程落格（`domain/week_grid_agenda_placement.dart` + `week_grid_agenda_card.dart`）

| # | Dart | 旧 Compose | 现在 |
|---|---|---|---|
| F1 | 钟点 → 重叠节次映射；完全不重叠钳到最近节（并列取更早）；脏钟点返回 null | 无 | `WeekAgendaLogic.sectionSpanForClockRange`（逐条移植，18 例单测） |
| F2 | 考试：当天 + 未过期；日程：当天实例、**不过滤 enabled**、系列例外优先 | 无 | 已实现 |
| F3 | 跨天日程 `00:00` / `23:59` 整列占位，卡上不画时刻 | 无 | 已实现 |
| F4 | 排序：开始钟点 → 结束钟点 → 日程先于考试 → id | 无 | 已实现 |
| F5 | 卡面：圆角 8、徽标药丸（考试红/日程本色）、标题 2 行、时刻 1 行 | 无 | 已实现 |
| F6 | 开关 `weekGridShowExams` / `weekGridShowSchedules`（关掉时卡与占用一起消失） | 无 | 已实现 |
| F7 | 点击：考试 → 考试页；日程 → 日程编辑页（带 occurrenceDate） | 无 | 已接（`ShellWiring` 按 id 找回实体；日程走 `pendingScheduleEdit`，考试进考试列表） |

### G. 空白格加课（`timetable_empty_slot_layer.dart`）

| # | Dart | 旧 Compose | 现在 |
|---|---|---|---|
| G1 | 点击空白格**什么都不做** | 每格都可点 → 直接加课（误触） | 点击无操作 |
| G2 | 开「长按空白格加课」时长按出现虚线标记，可拖拽跨节再点开加课 | 无 | **部分**：长按直接带（星期, 节次）进加课页；虚线标记 + 拖拽跨节未做（P1） |
| G3 | 开关默认 `false`（`:1541`） | 默认 `false`（一致） | 一致 |

### H. 设置联动总表（这是本次最大的改动面）

`app/TimetableHostLogic.weekViewStyle(model)` 一次映射 33 个键，逐键带 Dart 行号（见该函数 KDoc）；
单测 `TimetableHostLogicTest` 两例（默认存档 / 自定义存档）钉住映射，改映射不改断言就会红。

### I. 文案与 ARB

| # | 旧问题 | 现在 |
|---|---|---|
| I1 | 渲染层 12 处中文字面量；「本周没有排课 / 点击空白格子或右上角 + 号添课 / 我的课表 / 添加 / 课表管理」5 处是自造 | 全部走 `TimetableStrings`；自造控件已删 |
| I2 | 伪造 ARB 键 `noCourseThisWeek` 且被排除在对拍清单外 | 删除；对拍清单新增 13 条真实键 |
| I3 | 星期标签用 short 那套（一/二） | 改 `weekdayMon..Sun` |
| I4 | 「回到本周」（多一个「到」） | 改 `backToCurrentWeekAction`（回本周） |

### J. 分层

| 层 | 文件 | 谁调用 |
|---|---|---|
| 设置映射 | `app/TimetableHostLogic.weekViewStyle` | `TimetableHost`（宿主） |
| 风格快照 | `pages/timetable/WeekViewStyle.kt` | 渲染层全部 |
| 课卡排版 | `pages/timetable/WeekGridCourseMapping.kt` | `TimetableWeekGrid` |
| 考试日程落格 | `pages/timetable/WeekAgendaModel.kt` | `TimetableWeekPage` / 表头圆点 |
| 文案 | `pages/timetable/TimetableStrings.kt` | 渲染层全部 |

模型层与渲染层**不再是两张皮**：旧版 4 个模型文件在渲染层 0 引用，现在每个都有真实调用点。

---

## 三、本次改动的文件

渲染层（`composeP1`）：
- `TimetableWeekPage.kt`（整页重写：去空态、自动充满节高、回本周浮钮、考试日程入参、样式入参）
- `TimetableWeekGrid.kt`（重写：去网格线、整列宽叠放、考试日程卡、长按空白）
- `CourseGridCard.kt`（重写：七个内容开关 + 字号/材质/对齐/配色/冲突角标/压淡）
- `TimetableWeekdayHeader.kt`（重写：周X + MM/DD + 下划线今天 + 双圆点 + 设置字色）
- `TimetableTimeColumn.kt`（重写：三档显示 + 设置字号/字色）
- `app/TimetableHost.kt`（宿主：喂 style/exams/schedules/now，新回调）

模型层（`main`）：
- `pages/timetable/WeekViewStyle.kt`（新，含 `weekSectionHeight`）
- `pages/timetable/WeekAgendaModel.kt`（新）
- `pages/timetable/WeekGridCourseMapping.kt`（**整份替换**：删列平分模型，改 Dart 语义）
- `pages/timetable/TimetableStrings.kt`（+13 键与 5 个格式化函数，删伪造键）
- `app/TimetableHostLogic.kt`（+`weekViewStyle` 33 键映射）
- `pages/ShellWiring.kt`（考试/日程卡点击、点日期进日视图）

测试：
- `WeekGridCourseMappingTest`（15 例，整份重写）
- `WeekAgendaModelTest`（18 例，新）
- `WeekViewStyleTest`（11 例，新）
- `TimetableStringsParityTest`（6 例，改）
- `app/TimetableHostLogicTest`（+2 例，共 32）

---

## 四、证据（命令原文 + 结果）

### 4.1 L0 模块单测

```
pwsh -NoProfile -File scripts/test-kotlin-module.ps1 -Module "pages/timetable"
...
OK (219 tests)
```

宿主映射测试（`app/` 不在 L0 的模块锚点里，按仓内既有做法用 ExtraSources 收进来）：

```
& ./scripts/test-kotlin-module.ps1 -Module "pages/timetable" -ExtraSources @(
  "android/app/src/test/kotlin/com/mutx163/qingyu/app/TimetableHostLogicTest.kt",
  "android/app/src/main/kotlin/com/mutx163/qingyu/pages/course"
)
...
OK (251 tests)
```

### 4.2 L1 编译闸门

```
pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin
BUILD SUCCESSFUL in 41s
```

（第一次跑出来是红的：缺 `dp` import 1 处 + 函数名写错 1 处，修完复跑才绿；两次都在本条留痕。）

### 4.3 样式守卫（棘轮）

```
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain timetable
合计：9 处（与基线完全一致：R5 数据色 7 处 + R2 月视图 1 处 + R2 周视图 1 处）
```
没有新增违规，也没有「已修好却还挂在基线」的过期行。

### 4.4 咬合探针（改坏 → 红 → 还原 → 绿）

坏法：`WeekGridCourseMapping.NON_CURRENT_WEEK_OPACITY` 0.62 → 0.61。

```
probe injected
FAILURES!!!
Tests run: 219,  Failures: 2      ← `非本周课透明度固定 0-62…` 等两条
restored
OK (219 tests)
```

---

## 五、真机待验（必须由用户做，agent 不能声明）

装 `dev` 包（或用户在 AS 里出的包），在周视图逐条看：

1. **表头**：左端是「8 周」（不是你开学第几周就不用管，只要不是「10月」）；星期是「周一..周日」；日期是 `10/26` 这种；今天那一格是**下划线**不是蓝胶囊。
2. **时间列**：设置 → 课表页面 → 时间列显示，切「隐藏 / 开始 / 起止」三档，回来时间列应立刻跟着变（当前实现每次重组读一次设置，切完回来会生效）。
3. **课卡**：设置 → 课程卡片，关掉「显示教师」「显示地点」，回来卡片上那两行应消失；把字号调大调小，卡上字跟着变。
4. **非本周课**：打开「显示非本周课程」，翻到非本周，应看到灰卡（半透明）；关掉开关，灰卡消失。
5. **冲突**：造两门同天同节次的本周课，两张卡应**叠在一起**（后画的在上），左上角有「冲突」小字、右上角有「冲突」角标；关掉「显示冲突标记」后角标消失。
6. **考试/日程**：设了开学日 + 当天有考试/日程时，对应日期格底部应有红点/蓝点，网格里出现考试/日程卡（在课程卡之上）；点考试卡进考试列表，点日程卡进日程编辑。
7. **空白格**：点空白格应该**没反应**；打开「长按空白格加课」后长按空白格，应直接进加课页并预填这一天/这一节。
8. **回本周**：翻到别的周，底部应出现「回本周」按钮，点它回到真实本周；在本周时按钮不出现。
9. **空周**：翻到没有课的周，应该是一张空白网格（**没有**「本周没有排课」的卡）。

---

## 六、仍未复刻 / 已知差异（诚实清单）

按影响排序，全部在**本页之外**或需要新增管线：

| 级别 | 项 | 现状 | 为什么没在这次做 |
|---|---|---|---|
| P1 | **壁纸 + 玻璃坞 + 顶栏磨砂** | 壳级（`PagesShellActivity` / `GlassDockNavigationBar`）目前是纯色底 + 4 槽底栏；Flutter 是壁纸 + 可自定义玻璃坞 | 属壳（Lead 专属），且 Flutter 的坞是「底部动作坞」（日/周/统计/外观），与当前 Compose 的「四大槽位导航」是两套信息架构，需要单独一批 |
| P1 | **下拉快捷导入** | 无 | `home_pull_*` 5 件 + 教务导入链路，属导入域 |
| P1 | **周 ↔ 日 / 月 飞行动效** | 无 | `flight_*` 9 件 2919 行，是独立动效子系统；当前日/月是各自页面跳转 |
| P1 | **课卡天气行** | 无 | Compose 天气（`weather/WeatherProvider`）还没接进课表宿主；按设置 `weatherShowOnWeekCard` 等 4 键，需先在宿主喂「某天某时段天气」，属接线批次 |
| P2 | **长按空白格的虚线标记 + 拖拽跨节** | 长按直接进加课页（带起始节次），没有「拖到第几节」那一步 | 需要指针拖拽与跨节预览，属交互子系统；先保住「长按可加课」这条主路径 |
| P2 | **假期灰显 / 调休标记** | 课卡 `isHoliday` 通道已留，宿主恒传 false | `HolidayResolver` 已存在，但「课表日是否假期」还没在宿主组装；接上只需一层映射 |
| P2 | **日列圆角 / 选中指示条滑动形变 / 壁纸墨色自适应** | 未做 | 都依赖壁纸或日视图 pager 联动 |
| P2 | **日视图按天进入** | 点日期进的是「今天」的日视图 | `c3.day` 宿主还不接收目标日期；需日视图批次加参 |
| P2 | **情侣课表叠加** | 未接 | 情侣数据不在 `TimetableSnapshot`，需 Couple 域接线 |
| P2 | **作业指示 / 备注角标 / 单节提醒铃铛** | 未做 | 周视图 Dart 只画作业指示；另两项日视图才有。需要 `hasHomeworkInWeek` 传入卡模型（一行参数） |

---

## 七、给下一个人的提醒

- **不要再引入「冲突分列」**：Dart 没有，用户口径是「一模一样」。`WeekGridCourseMapping` 的 KDoc 写清楚了为什么。
- **改渲染前先读 `WeekViewStyle`**：想加一个设置项，先加字段 → 在 `weekViewStyle` 加映射与单测 → 渲染层读字段，三步缺一不可。
- **周视图没有空态**：不要好心再补一张卡。
- **点空白格不加课**：只有长按（且开关打开）才加。
