# Compose 周视图「课程操作弹层」· 重构质量审核（2026-10-29）

> 触发：用户「周视图课程弹窗页面审核一下重构质量，功能有没有复刻完，页面有没有一模一样做过来，把他完善好」。
>
> 审核对象（Dart 唯一判据）：
> - `lib/widgets/course_action_sheet.dart`（1168 行）= 点课卡弹出的**课程操作弹层**本体；
> - `lib/widgets/course_followup_sheets.dart`（1015 行）= 删除范围 / 停课范围 / 调课 / 删除确认四个后续弹层；
> - `lib/widgets/course_note_sheet.dart`（363 行）= 备注弹层；
> - `lib/widgets/timetable/timetable_course_action_items.dart`（203 行）+ `timetable_course_action_flow.dart`（67 行）= 弹层前的取数（冲突课 / 情侣课预览）；
> - `lib/widgets/timetable/timetable_course_sheet_actions.dart`（312 行）= 三条后续流程的装配。
>
> Compose 对位（审核时的实况）：
> - `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/CourseActionSheet.kt`（344 行，渲染层）
> - `android/app/src/main/kotlin/com/mutx163/qingyu/app/CourseActionDispatcher.kt`（362 行，动作分派）
> - `android/app/src/main/kotlin/com/mutx163/qingyu/app/CourseActionStrings.kt`（17 条文案）
> - 壳接线：`pages/ShellWiring.kt` 的 `TimetableWithCourseActions`

---

## 零、结论（先看这段）

**判定：旧版是「能点、能改库」的最小实现，不是复刻；并且有一处会导致数据损失的写入口径错误。**

三句话：

1. **功能没复刻完**：Dart 弹层是「课程信息 + 8 行可点详情 + 冲突/情侣课面板 + 6 个动作」，
   旧 Compose 只剩「3 行纯文字 + 5 个按钮」；关联课程面板、备注、作业关联、天气、说明行里的周次高亮、
   只读（对方课）语义**全部缺失**。
2. **页面对不上**：没有头部（课程色图标块 + 课名 + 必修/选修 + 冲突/情侣角标 + 「第 N 周 · 简介」），
   详情行没有图标 / 没有副标题 / 没有箭头，容器没有 80% 限高与滚动。观感是「一张表单」，不是 Dart 的「一张课程卡」。
3. **一处危险差异**：Dart 点「删除」先问「删整门 / 只删这周这节」并**二次确认**；
   旧 Compose 点「删除」直接 `deleteCourse(整门)`，**没有确认、没有范围选择**——
   用户在周视图误点一次，等于把一门课从整个学期抹掉。

| 维度 | Dart 实况 | 旧 Compose 实况 | 本轮回合 |
|---|---|---|---|
| 容器 | `showMiuixBottomSheet` 底栏弹层，内容限高 `屏高×0.8` + 内部滚动 | `OverlayBottomSheet`，无高度约束、无滚动 | 补齐 |
| 头部 | 48dp 课程色图标块 + 课名 + 必修/选修 + 冲突/情侣角标 + `第N周 · 简介/周次描述` | 无（弹层标题只有课名） | 补齐 |
| 详情行 | 8 类行（时间/教师/地点/天气/备注/作业/提醒/说明），每行 = 图标 + 主标题 + 副标题 + trailing | 3 行纯文字（时间/教师/地点），无图标无副题 | 补齐（提醒行按「无调度器」不显示） |
| 关联课程 | 冲突课/情侣课折叠面板 + 可切换 + 每条带时间地点与角标 | 无 | 冲突课补齐；情侣课留缺口（见 §六） |
| 动作 | 编辑（主）/ 调课 / 停课·恢复 / 删除 + 只读课隐藏全部动作 | 同 4 个 + 底部「作业」按钮 | 补齐（作业归位到详情行） |
| 删除流程 | 范围选择 → 删除确认 → 写库 | 直接删整门 | **补齐（安全项）** |
| 停课流程 | 范围选择（本周 / 全部） | 只本周 | 补齐 |
| 调课流程 | 选周 / 星期 / 起止节次 / **地点**，带「当前 → 目标」预览，无变化时确认置灰 | 数字步进器，不能改地点，无预览 | 补齐 |
| 备注 | 独立弹层：课程简介 + 本节备注，只读态可看不可改 | 无 | 补齐 |
| 文案 | 全部走 ARB（本族 60+ 键） | 17 条对拍，其余缺失 | 补齐（逐字对拍） |
| 分层 | `buildTimetableCourseActionPreviewItems` 纯函数 + 三条后续流程各自独立文件 | 数据装配与渲染混在壳里，无模型层 | 补齐（模型层可 JVM 测） |

---

## 一、审核方法

1. 逐行读 Dart 上述 5 个文件，把每一条可观察行为（版式、文案、点击、写入口径、判据）单独列一行；
2. 逐行读 Compose 4 个文件，按「Dart 有 / Compose 没有 / Compose 自造」三类归档；
3. 写入口径**只认数据效果**：同一动作两边写库后，课程字段是否等价（`activeWeeks` / `suspendedWeeks` / `sessionNotes`）；
4. 文案只认 ARB（`lib/l10n/app_zh.arb`）与 `CourseActionStringsParityTest` 的对拍口径；
5. 收口证据：L0（模块 JVM 单测）+ L1（编译闸门）+ 样式守卫 + i18n 中文门禁 + 咬合探针。

---

## 二、逐项对照（Dart 出处 → 旧 Compose → 本轮）

### A. 容器与滚动

| # | Dart（出处） | 旧 Compose | 本轮 |
|---|---|---|---|
| A1 | 底栏弹层，正文 `ConstrainedBox(maxHeight = 屏高 * 0.8)` + `SingleChildScrollView`（`:168-207`） | 无约束 | 限高 + 可滚 |
| A2 | 正文直接从面板上沿开始，把手条悬浮（`:114-138` 长注释：42→24 的空档账） | `OverlayBottomSheet(title=课名)` | 保留官方容器；内容自管滚动 |

### B. 头部块（`_CourseActionSheetContent.build` `:704-757`）

| # | Dart | 旧 Compose | 本轮 |
|---|---|---|---|
| B1 | 48×48 圆角块，底色 = 课程色 14% alpha，图标 = 情侣心 / 对方人形 / 默认书本 | 无 | 有 |
| B2 | 课名 + 必修/选修（对方课不显示性质）+ 「冲突」红字 + 情侣角标 | 只有弹层标题 | 有 |
| B3 | 第二行 `第N周 · (课程简介 优先，否则周次描述)`，最多 2 行 | 无 | 有 |

### C. 详情行（`_CourseDetailTile` `:963-1048`，行序 `:759-870`）

行结构：`HyperosFrostedSurface` → 18dp 图标（次要墨色）+ 主标题（13sp，可选 2 行）+ 副标题（11sp 次要色，2 行）+ 右侧 trailing（箭头 / 时刻）。

| # | 行 | Dart 口径 | 旧 Compose | 本轮 |
|---|---|---|---|---|
| C1 | 时间 | 标题 `周X · 第A-B节`；副标题 `MM月DD日 第N周 [单/双周]`（学期开始日未设为无日期）；trailing `HH:mm-HH:mm` | 一行 `时刻 + 第A-B节` | 有 |
| C2 | 教师 | 标题 教师/未知教师；副标题：有简介→周次描述，否则有短名→`短名：X`，否则周次描述 | 只有教师名 | 有 |
| C3 | 地点 | 标题 地点/未知地点；副标题：有短名且有简介→`短名：X`，否则周次描述 | 只有地点名 | 有 |
| C4 | 天气 | 受 `weatherShowOnSheet` / `weatherShowPhenomenon` / `Temperature` / `Probability` 四键控制；对方课与停课周、无日期不显示；数据未到画「天气加载中…」占位；副标题「该节课时段内的天气」 | 无 | 有（数据由壳注入） |
| C5 | 备注 | 标题：本周备注 优先 → 课程简介 → 「备注」；副标题四态（都有/只有本节/只有简介/都没有）；trailing 箭头；点击 → 备注弹层（只读课可看不可改） | 无 | 有 |
| C6 | 作业 | 只读课不显示；标题 = 关联作业标题（否则「添加作业」），副标题 = 作业清单/已完成；trailing 箭头；点击 → 作业页 | 底部一个「作业」按钮，无关联信息 | 有（按钮并入行） |
| C7 | 单节课提醒 | 仅当 `onSetAlarm != null && _isAlarmAvailable(...)`（当天已开课不显示、过去不显示） | 无（调度器缺失） | **不显示**（保持诚实缺口，见 §六） |
| C8 | 说明行 | info 图标 + 说明句，句中的周次数字用前景色高亮（`:1050-1084`） | 纯文本、无高亮、无图标 | 有 |

### D. 关联课程面板（`_RelatedCoursesPanel` `:210-473`）

| # | Dart | 旧 Compose | 本轮 |
|---|---|---|---|
| D1 | 只在 `previewItems.length > 1` 时出现；折叠条 = 图标徽章 + 标题（冲突 N 门 / 情侣 N 门 / 相关 N 门）+ 副标题（课名预览或展开提示）+ 展开箭头 | 无 | 有（冲突课） |
| D2 | 展开后逐条：课程色圆点 + 课名 + 角标（冲突/一起/对方/我的）+ `周X · 第A-B节 · HH:mm-HH:mm` + 地点 + 右侧「切换」 | 无 | 有（冲突课） |
| D3 | 点某条 → 切换为选中课，滚动归零（`_selectCourse` `:136-152`） | 无 | 有 |
| D4 | 冲突课取数：整周冲突映射（`CourseDomain.buildConflictMap(week)`），按 星期→开始节次→id 排序，去重（`timetable_course_action_items.dart:184-203`） | 无 | 有（模型层纯函数） |
| D5 | 情侣课（`coupleKind` / `isPartnerCourse`）来自情侣覆盖层；只读课隐藏动作、显示「对方课程只读」说明 | 无 | **缺口**：Compose 周视图尚无情侣叠加层，弹层不伪造数据（见 §六） |

### E. 动作区（`:871-917`）

| # | Dart | 旧 Compose | 本轮 |
|---|---|---|---|
| E1 | 只读课整块不渲染 | — | 有 |
| E2 | 编辑：整宽主按钮 | 同 | 保持 |
| E3 | 第二排三枚等宽次按钮：调课（本周没课则置灰）/ 停课·恢复 / 删除（危险色） | 同 | 保持 + 补无变化禁用的调课确认 |
| E4 | 作业与提醒不在底部，是详情行 | 底部多一个「作业」按钮 | 归位到详情行 |

### F. 三个后续弹层（`course_followup_sheets.dart`）

| # | Dart | 旧 Compose | 本轮 |
|---|---|---|---|
| F1 | 删除范围：`删除方式` 标题 + 「删除这个课」+「删除这节课」（不可用则置灰并解释本周为何不能删）+ 取消 | 无 | 有 |
| F2 | 删除确认：标题 + 说明块 + 取消 / 删除（危险） | 无 | 有 |
| F3 | 停课范围：`停课` + `选择停课范围`，两项（按当前状态切换成「恢复」文案）+ 取消 | 无 | 有 |
| F4 | 调课：标题 + 副题 + 「当前：…」行 + 地点行 + 周步进 + 星期胶囊 + 起止节次选择 + 目标时段 + 地点可改/可选建议 + 「→ 目标」预览 + 取消 / 确认调课（无变化置灰） | 四个数字步进器 + 取消 / 确认，不能改地点 | 有 |

### G. 备注弹层（`course_note_sheet.dart`）

| # | Dart | 旧 Compose | 本轮 |
|---|---|---|---|
| G1 | 标题 `课程备注`；副标题 `课名 · 第N周 · 第A-B节` | 无 | 有 |
| G2 | 两段输入：课程简介（同名课共享）、本节备注（只对本周有效） | 无 | 有 |
| G3 | 只读态（对方课）：`对方课程仅可查看备注，无法编辑`，输入框禁编辑、无保存 | 无 | 有 |
| G4 | 保存：`description` 写共享简介、清空 legacy `note`、`sessionNotes[week]` 写本节备注（`hasHomework` 保留原值） | 无 | 有 |
| G5 | 键盘避让：聚焦后把输入框滚到可视区（`didChangeMetrics` `:101-147`） | 无 | 有（`imePadding` + `bringIntoView`） |

### H. 文案

| # | 旧问题 | 本轮 |
|---|---|---|
| H1 | 旧只对拍 17 条；Dart 本族实际用到的 ARB 键 60+（删/停课范围、备注四态、关联面板、作业、天气…） | 按需补齐并逐字对拍 |
| H2 | `targetWeekLabel` 常量是渲染层自拟中文（ARB 无此键） | 改用 ARB 真实键（`rescheduleTargetWeekLabel` 等） |

### I. 分层

| 层 | 旧 | 本轮 |
|---|---|---|
| 取数（冲突课预览） | 无 | `pages/course/CourseActionSheetModel.kt`（纯函数） |
| 行内容（8 类行的标题/副题/trailing/是否显示） | 渲染层各写各的 | 同一个模型文件产出 `CourseActionDetailRow` 列表 |
| 后续弹层状态机 | 无（只有调课的本地 `pickingReschedule`） | `CourseFollowupModel.kt`（范围选择 / 预算目标） |
| 备注写入 | 无 | `CourseActionDispatcher.saveCourseNotes` + `CourseNoteModel` |
| 渲染 | 344 行一坨 | 三个渲染文件，只画不算 |

---

## 三、本轮工作包与写作用域

> 多 Agent 并行：每个包一个泳道，**只写自己那几行路径**，交叉文件归 Lead。

| 包 | 内容 | 写作用域（唯一） | 负责人 |
|---|---|---|---|
| **L** | 审核报告、分派器补写、壳接线、收口（L0/L1/守卫/提交） | `docs/plans/2026-10-29-compose-course-action-sheet-audit.md`、`main: app/CourseActionDispatcher.kt`、`main: app/CourseActionStrings.kt`、`main: pages/ShellWiring.kt`、`test: app/CourseActionDispatcherTest.kt` | Lead |
| **S（弹层本体）** | 模型 + 渲染 + 文案 + 测试 | `main: pages/course/CourseActionSheetModel.kt`、`main: pages/course/CourseActionSheetStrings.kt`、`composeP1: pages/course/CourseActionSheet.kt`、`test: app/CourseActionSheetModelTest.kt`、`test: app/CourseActionSheetStringsParityTest.kt` | 泳道 S |
| **F（后续弹层）** | 删除范围 / 停课范围 / 删除确认 / 调课 | `main: pages/course/CourseFollowupModel.kt`、`main: pages/course/CourseFollowupStrings.kt`、`composeP1: pages/course/CourseFollowupSheets.kt`、`test: app/CourseFollowupModelTest.kt`、`test: app/CourseFollowupStringsParityTest.kt` | 泳道 F |
| **N（备注）** | 备注弹层 | `main: pages/course/CourseNoteModel.kt`、`main: pages/course/CourseNoteStrings.kt`、`composeP1: pages/course/CourseNoteSheet.kt`、`test: app/CourseNoteModelTest.kt`、`test: app/CourseNoteStringsParityTest.kt` | 泳道 N |

### 契约（三个人都按这个签名写，改签名先报 Lead）

包：渲染层 `com.mutx163.qingyu.pages.course`（`composeP1: pages/course/`）；模型层同包（`main: pages/course/`）。
模型层**不许** import `androidx.compose.*` / `top.yukonga.miuix.*` / `android.*`（L0 是真 JVM）。

> **类型落点修正（2026-10-29，S 泳道提出）**：`CourseDeleteScope` / `CourseSuspendScope` /
> `CourseRescheduleTarget` 三个纯类型**声明在 `main: pages/course/CourseFollowupModel.kt`（F 泳道）**，
> 不放在 `composeP1`。理由：`scripts/test-kotlin-module.ps1 -Module "pages/course"` 只收
> `main/pages/course` + `test/pages/course` + 共享目录，**不收 composeP1**；而 S 的
> `CourseActionEvent`（在 `main`）要用这三个类型作 payload，放 composeP1 会让模型层 L0 永远
> Unresolved reference；两边都声明又会在 L1 撞「同包同名 redeclaration」（composeP1 与 main
> 同属一个编译单元）。凡是要被 `main` 引用的类型，一律先确认它落在 `main`。

```kotlin
// ── F 泳道交付（main: pages/course/CourseFollowupModel.kt —— 三个纯类型 + 预算）──
enum class CourseDeleteScope { WHOLE_COURSE, THIS_WEEK }
enum class CourseSuspendScope { THIS_WEEK, ALL_WEEKS }

data class CourseRescheduleTarget(
    val targetWeek: Int,
    val targetDayOfWeek: Int,
    val targetStartSection: Int,
    val targetEndSection: Int,
    val targetLocation: String,
)

// ── F 泳道交付（composeP1: pages/course/CourseFollowupSheets.kt —— 只放组合函数）──
@Composable fun CourseDeleteScopeSheet(
    show: Boolean, canDeleteOccurrence: Boolean, week: Int,
    onDismiss: () -> Unit, onSelect: (CourseDeleteScope) -> Unit,
)

@Composable fun CourseSuspendScopeSheet(
    show: Boolean, suspendedThisWeek: Boolean, hasAnySuspended: Boolean,
    onDismiss: () -> Unit, onSelect: (CourseSuspendScope) -> Unit,
)

@Composable fun CourseDeleteConfirmSheet(
    show: Boolean, title: String, message: String,
    onDismiss: () -> Unit, onConfirm: () -> Unit,
)

@Composable fun CourseRescheduleSheet(
    show: Boolean, course: Course, sourceWeek: Int, weekCount: Int,
    weekdayLabels: List<String>, sectionTimes: List<SectionTime>,
    onDismiss: () -> Unit, onConfirm: (CourseRescheduleTarget) -> Unit,
)

// ── N 泳道交付（composeP1: pages/course/CourseNoteSheet.kt）──
@Composable fun CourseNoteSheet(
    show: Boolean, course: Course?, week: Int, readOnly: Boolean,
    onDismiss: () -> Unit, onSave: (wholeNote: String?, sessionNote: String?) -> Unit,
)

// ── S 泳道对壳交付（main: pages/course/CourseActionSheetModel.kt）──
sealed interface CourseActionEvent {
    /** 事件所属那门课（= 当前选中 section 的 courseId）。⚠️ 见下方「为什么必须带 courseId」。 */
    val courseId: String
    data class Edit(override val courseId: String) : CourseActionEvent
    data class AddTask(override val courseId: String) : CourseActionEvent
    data class Delete(override val courseId: String, val scope: CourseDeleteScope) : CourseActionEvent
    data class Suspend(override val courseId: String, val scope: CourseSuspendScope) : CourseActionEvent
    data class Reschedule(override val courseId: String, val target: CourseRescheduleTarget) : CourseActionEvent
    data class SaveNotes(override val courseId: String, val wholeNote: String?, val sessionNote: String?) : CourseActionEvent
}

// 为什么必须带 courseId（收口期发现的参数透传缺口）：
// 弹层内部允许切到冲突课（Dart `_selectedIndex` 是**弹层内部状态**）。事件不带课标识时，
// 壳只能拿「最初点开弹层的那门课」——用户先切到冲突课再点编辑/删除/停课，就会**对错误的课写库**。
// 契约第一版没带，S 泳道实现时补上并由单测钉住（`切到冲突课之后事件带的是当前选中那条的 courseId`）。

@Composable fun CourseActionSheet(
    course: Course?,
    week: Int,
    previewItems: List<CourseActionPreviewItem>,
    details: CourseActionSheetDetails,
    onEvent: (CourseActionEvent) -> Unit,
    onDismiss: () -> Unit,
)
```

`CourseActionPreviewItem` / `CourseActionSheetDetails` / `CourseActionDetailRow` 由 S 泳道在模型文件里定义并带单测。

预览列表由 S 的 `CourseActionSheetModel.buildPreviewItems(courses, primary, week)` 产出
（Dart `timetable_course_action_items.dart` 的冲突课那一半；情侣课本轮无数据源，参数留空口）。

天气行由壳注入两份数据（S 定义类型，壳按它构造）：

```kotlin
data class CourseSheetWeatherPrefs(
    val showOnSheet: Boolean = true, val showPhenomenon: Boolean = true,
    val showTemperature: Boolean = true, val showProbability: Boolean = false,
)
data class CourseSheetWeatherInfo(
    val date: java.time.LocalDate? = null,
    val summary: com.mutx163.qingyu.weather.CourseWeatherSummary? = null,
    val awaiting: Boolean = false,
)
```

---

## 四、证据（命令原文 + 结果，2026-10-29 收口）

### 4.1 L0 模块单测（真 JVM）

```
pwsh -NoProfile -File scripts/test-kotlin-module.ps1 -Module "pages/course" \
  -ExtraSources "android/app/src/test/kotlin/com/mutx163/qingyu/app/CourseActionDispatcherTest.kt"
...
OK (231 tests)
```

231 例 = 本族新增 **127 例**（弹层模型 41 + 弹层文案对拍 11 + 后续弹层模型 32 + 后续弹层文案 6
+ 备注模型 14 + 备注文案 4 + 分派器补的 6，另有各文件既有的对拍/模型例）＋ `pages/course` 存量例。

### 4.2 L1 编译闸门

```
pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin
BUILD SUCCESSFUL in 4s
182 actionable tasks: 3 executed, 179 up-to-date
> Task :app:compileDevDebugKotlin UP-TO-DATE
```

⚠️ **这句话要读对**：`UP-TO-DATE` 是 Gradle 的**输入内容哈希**判定，即「当前工作树的源码
（与上一次成功执行时逐字节一致）已经被成功编译过」。本批最后一次**真正执行**编译的时间是
**19:19:31**（`build/app/tmp/kotlin-classes/devDebug/.../CourseActionSheetKt.class` 的 mtime），
晚于全部源码的最后修改（`CourseActionSheetModel.kt` 19:17:31 / `ShellWiring.kt` 19:05:28）。
所以它的含义是「现在这份树编译过、且没有编译错误」，不是「没编译」。

### 4.3 样式守卫（`course` 域）

```
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain course
=== course 域 0 处 ===
```

`tool/compose_style_baseline/course.txt` **仍是空表**（没有为了变绿往里加行）。

### 4.4 i18n 中文门禁

三个新渲染文件（`CourseActionSheet.kt` / `CourseFollowupSheets.kt` / `CourseNoteSheet.kt`）
按 `CjkLiteralGateTest` 的判据（去注释、抠双引号字面量）独立扫过：**CJK literals: 0**。
全部屏上文字来自 `CourseActionSheetStrings` / `CourseFollowupStrings` / `CourseNoteStrings`
（复用同包顶层 `ArbText`）+ `app/CourseActionStrings`。

另做了一次**独立于测试的** ARB 核对：四个文案文件共声明 **134 条**键，与
`lib/l10n/app_zh.arb` 逐键比对，**缺失 0 条**；本轮**没有新增任何 ARB 键**（要同步 6 份 ARB
+ `gen-l10n`，越界）。

### 4.5 咬合探针（每条泳道各自做过，红 → 还原 → 绿）

| 泳道 | 故意改坏什么 | 结果 |
|---|---|---|
| S | `Events.edit` 返回固定错 id；删掉天气行的「停课周不出现」判据 | `Tests run: 210, Failures: 2`（`expected c1 but was WRONG-PROBE` / `停课周不显示天气`）→ 还原 `OK` |
| S（第二轮） | 把关联面板的 `coupleCount` 改回 Dart 的 `others.size - conflictCount` | `expected:<还有 1 节[相关]课程> but was:<还有 1 节[情侣课表]课程>` → 还原 `OK (211)` |
| F | 把「地点」从 `hasChanges` 判据里删掉（旧 Compose 的病根） | `Tests run: 38, Failures: 2` → 还原 `OK (38)` |
| N | `initialWholeNote` 的「回落 legacy note」改空 | `Tests run: 18, Failures: 3` → 还原 `OK (18)` |

### 4.6 收口时发现并修掉的**真问题**（这些是"页面看起来对、其实错"的那类）

1. **事件不带课标识**（参数透传缺口）：弹层内部能切到冲突课，事件只带动作时，壳只能拿「最初
   点开的那门课」→ 切课后再点编辑/删除会对**错误的课**写库。已补 `courseId` 并由单测钉住。
2. **两层底栏叠在一起**：开子弹层时父弹层还开着。已改 `show = course != null && stage == NONE`。
3. **「还有 1 节情侣课表课程」这句错话**：Dart 把「所有非冲突课」都算成情侣课，切到冲突课后
   必然显示。已改为按 `coupleKind != null` 真数（见 §五 第 4 条）。
4. **删除一口价**：旧 Compose 点删除直接删整门、无确认。现在必须「选范围 → 二次确认」才写库。
5. **`app/` 反向依赖 `pages.timetable`**（顺手修，单独提交 `dccff342`）：周视图上次那批把
   `weekViewStyle` 写进 `app/TimetableHostLogic.kt`，让**除课表域以外每个模块的 L0 都编译失败**；
   已挪到 `pages/timetable/TimetableStyleMapping.kt`。

---

## 五、诚实清单（本轮没做 / 与 Dart 的已知差异 / 未验）

### 5.1 能力缺口（不是偷懒，是依赖的东西还不存在）

1. **单节课提醒行不出现**：Compose 侧没有 class-alarm 调度器（全仓只有考试提醒 / 实时活动 / 周报），
   按 Dart「不可用时整个入口不出现」处理，**不做一个点了没反应的入口**。
   `CourseActionRowKind.ALARM` / 图标路径已留好，调度器到位加一条即可。
2. **情侣课（对方课）通道未接**：Compose 周视图还没有情侣叠加层，弹层的
   `isPartnerCourse` / `coupleKind` / 只读态**代码路径与文案齐全**，
   `buildPreviewItems(coupleOverlayActive = true)` 会**明确抛错**（不静默出半成品）；线上拿不到数据。
3. **磨砂行面**：Dart 每行是 `HyperosFrostedSurface`；Compose 用官方 `QingyuCard`
   （有按压反馈、无磨砂）。磨砂是全局缺口（与顶栏毛玻璃同一批）。
4. **天气图标只有一朵云**：仓库只有 `MiuixIcons`，没有天气族；Dart 的 9 种现象图标 +
   温度计/百分号「认领」逻辑退化成统一云图标。**文字部分（现象/温度/概率与三个开关）是照抄的。**
5. **日期文案复用 ARB `monthViewAgendaTitle`**（值 `{month}月{day}日`，与 zh `MMMd` 输出逐字一致）。
   ARB 没有通用的「课程详情日期」键，按「不许新增 ARB 键」的纪律复用，未自拟。
6. **调课的地点只能手输/清空**，没有历史候选：Dart 的建议列表要壳注入（`locationSuggestions`），
   本轮契约没这个入参；不伪造候选。

### 5.2 与 Dart 的**故意**差异（都写了理由，不是漏做）

7. **取消子弹层会回到课程弹层**（Dart 是直接落回课表）。Dart 那样是框架限制（同层不能叠两个
   bottom sheet）逼出来的；我们保留父弹层状态、只是暂时隐藏，取消后原地回来。
8. **修掉 Dart 的「情侣课」计数 bug**：Dart `coupleCount = others.size - conflictCount` 会把主课
   算成情侣课，切课后标题必显示「还有 N 节情侣课表课程」。新口径按 `coupleKind != null` 真数，
   标题退化成「还有 N 节相关课程」。单测钉着新口径。
9. **头部「冲突」只画一次**：Dart 会对冲突课在头部画两遍「冲突」（红字 + 课程色各一次），
   这里合成一处红字。

### 5.3 未覆盖 / 未验（必须说清）

10. **真机一次都没验**：agent 只能声明「编译通过（L1）」与「JVM 单测通过（L0）」。
    要用户在 `dev` 变体上逐条对照的是：点课卡出弹层 → 8 行内容 → 冲突课面板切换 →
    删除（范围+确认）→ 停课（本周/全部）→ 调课（含地点）→ 备注（两段字，杀进程重开还在）。
11. **备注保存失败会丢已输入的文字**：弹层发出 `SaveNotes` 后即关闭，壳写库失败只能 toast。
    Dart 是「写失败保持打开、内容还在输入框里」。要对齐需要把 `onSave` 改成返回布尔
    （跨 S/N 两条泳道的签名变更），本轮未做。
12. **备注键盘避让**用 `imePadding()` + `BringIntoViewRequester`（滚进可视区），
    不是 Dart 的「对齐到可视区 90% + 180ms easeOutCubic」。
13. **调课弹层限高**用 `heightIn(max = 480dp)` + 内部滚动，不是 Dart 的「屏高 × 0.88」；
    周/节次选择器是**列表弹层**（对应 Dart `showHyperosSelectSheet`），不是滚轮。
14. **调课的节次表按「主课」解析**（`TimeSchemeLogic.resolveCourseTimeScheme`）。弹层允许切到
    冲突课，若冲突课钉了另一套作息，调课面板里的钟点会按主课的模板算——Dart 是按被操作那门课算。
15. **本轮未跑 L2**（`:app:testDevDebugUnitTest`）：收口时该任务被**别人的文件**顶着红
    （`sync/CoupleTimetableSettingsPage.kt` 一条过期样式基线行、`composeP1/app/TimeSchemeHost.kt`
    两条中文字面量），与本族无关；本族的逻辑证据是 §4.1 的 231 例。

