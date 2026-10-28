package com.mutx163.qingyu.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.clampCurrentWeekToSettings
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import com.mutx163.qingyu.pages.timetable.TimetableWeekPage

/**
 * Phase 3.5 · L4 课表宿主层：把 [TimetableRepository] 接到 [TimetableWeekPage] 上。
 *
 * ## 这一层存在的理由
 *
 * Phase 3 交付的页面是「纯函数 + 数据入口」形态：模型层不持有状态、渲染层只负责画。
 * 壳里原先写的是 `TimetableWeekPage()` **零参调用**——15 个参数全走默认值，
 * 于是既没有真数据、也没有真回调，表现就是「按钮点了没反应」。
 * 本层负责：订阅仓储快照 → 逐参喂给页面 → 把页面回调接到导航/仓储上。
 *
 * ## 参数透传纪律（这类 bug 的高发区）
 *
 * [TimetableWeekPage] 一共 15 个业务参数（`TimetableWeekPage.kt:78-96`），本层**逐个显式**
 * 传下去，一个都不靠默认值：
 *
 * | 页面参数 | 本层喂什么 |
 * |---|---|
 * | `courses` | `snapshot.courses`（真数据） |
 * | `timeScheme` | [TimetableHostLogic.resolveActiveTimeScheme] |
 * | `settings` | `snapshot.settings` |
 * | `profileName` | [TimetableHostLogic.resolveProfileName] |
 * | `currentWeek` | `snapshot.currentWeek`，按 `clampCurrentWeekToSettings` 钳制 |
 * | `totalWeeks` | `settings.semesterWeekCount` |
 * | `initialWeek` | 同 `currentWeek`（首帧落位） |
 * | `visibleDays` | [TimetableHostLogic.visibleDayNumbers] |
 * | `timeColumnWidth` | [TimetableHostLogic.timeColumnWidthDp] |
 * | `sectionHeight` | [TimetableHostDisplayPrefs.sectionHeightDp] |
 * | `onCourseClick` | [onOpenCourse] |
 * | `onEmptySlotClick` | [onOpenAddCourse]，**先过空档开关判据** |
 * | `onDayClick` | [onOpenDay] |
 * | `onAddClick` | [onOpenAddCoursePlain] |
 * | `onManageProfilesClick` | [onOpenProfiles] |
 * | `onSwitchProfileClick` | [onSwitchProfile] |
 * | `onWeekChanged` | [onWeekChanged] |
 *
 * ## 空态
 *
 * 没有课时**不做任何包装**：[TimetableWeekPage] 自己会把空列表渲染成
 * 「本周没有排课」的空态卡（`TimetableWeekPage.kt:313-346`）。宿主加壳反而会盖住它。
 *
 * ## 显示偏好的来源（S1 起）：**用户存档**，不是宿主默认
 *
 * 四个显示偏好（隐藏周末 / 时间列宽档 / 节次行高 / 长按空档加课）从 [settings] 推导，
 * 推导规则在 `TimetableHostDisplayPrefs.fromSettings`（纯 Kotlin，逐条对齐 Dart 并带行号）。
 * 壳接线层把 `settingsModel.load()` 交给本参数即可，**不再传「假默认」**。
 *
 * [display] 保留为**注入点**：给了它就以它为准（测试、以及将来要做「临时覆盖」时用）。
 *
 * 解析顺序：`display ?: settings?.let { fromSettings(it) } ?: TimetableHostDisplayPrefs()`。
 *
 * ⚠️ 历史：S1 之前这里写着「这四个值只能由壳接线层注入（默认值取 Dart 默认）」
 * ——那是 task-8 的临时做法（`core.TimetableSettings` 当时只有四键子集），
 * 注释里留了「待办：设置族并入时对齐」。设置族并入后该待办已消，故本段重写。
 *
 * @param repository 课表仓储（task-7 交付）。
 * @param onOpenAddCourse 点/长按**空白格**加课，带星期几与节次预填。
 * @param onOpenCourse 点课程卡片：打开详情/编辑。
 * @param onOpenProfiles 右上角课表管理。
 * @param onOpenAddCoursePlain 右上角「+」：不带预填的加课。
 * @param onOpenDay 点表头某一天（日视图入口，Phase 3.5 后续接线）。
 * @param onSwitchProfile 点标题区：切换课表。
 * @param onWeekChanged 翻周/选周后回调。⚠️ 冻结的仓储 API **没有** setCurrentWeek，
 *   本层只能透传（Dart 侧是 `provider.currentWeek = v` 并写回 profile）。
 * @param settings 完整设置模型（用户存档）。给了它、又没给 [display] 时，
 *   显示偏好由 `TimetableHostDisplayPrefs.fromSettings(settings)` 推导。
 * @param display 显示偏好**注入点**（见上）；`null`（默认）表示「按 [settings] 推导」。
 */
@Composable
fun TimetableHost(
    repository: TimetableRepository,
    onOpenAddCourse: (dayOfWeek: Int, section: Int) -> Unit,
    onOpenCourse: (Course) -> Unit,
    onOpenProfiles: () -> Unit,
    onOpenAddCoursePlain: () -> Unit,
    onOpenDay: (dayOfWeek: Int) -> Unit = {},
    onSwitchProfile: () -> Unit = {},
    onWeekChanged: (week: Int) -> Unit = {},
    // ⚠️ 名字带 Model 后缀是**必须的**：函数体里已有一个局部 `settings`（= `snapshot.settings`，
    // 是 `core.TimetableSettings` 那个四键子集），同名的参数会被它遮蔽、且极易读错。
    settingsModel: TimetableSettingsModel? = null,
    display: TimetableHostDisplayPrefs? = null,
    // 顶栏「轻屿课表」+ 右上角「更多」菜单：条目与选中回调由壳注入（页面不认识路由）。
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
) {
    // 首帧直接用仓储当前快照，避免「先画空网格再跳成有课」的闪一下。
    // ⚠️ 这不是优化，是**接口语义**：`TimetableRepository.observe` 只在**后续变更**时回调，
    // 订阅那一刻**不会**推一次当前值（见 `TimetableRepository.kt:56-61` 的通知语义）。
    // 所以任何宿主都必须先读 `repository.snapshot` 拿初值，否则首帧永远是空数据。
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }

    DisposableEffect(repository) {
        val subscription = repository.observe { updated -> snapshot = updated }
        onDispose { subscription.close() }
    }

    val settings = snapshot.settings
    // 显示偏好解析（S1）：注入点优先 → 用户存档推导 → Dart 默认。
    // `remember` 必须**无条件**调用（Compose 的调用结构要稳定），所以三种情况都在这一个
    // remember 里算完，而不是写成 `display ?: settingsModel?.let { remember { … } }`。
    val resolvedDisplay = remember(display, settingsModel) {
        display
            ?: settingsModel?.let { TimetableHostDisplayPrefs.fromSettings(it) }
            ?: TimetableHostDisplayPrefs()
    }
    // 周次钳制复用模型层判据（Dart `clampWeek`，domain/timetable_layout.dart:23-27），不重写。
    val currentWeek = clampCurrentWeekToSettings(snapshot.currentWeek.toLong(), settings).toInt()
    val visibleDays = remember(resolvedDisplay.hideWeekends) {
        TimetableHostLogic.visibleDayNumbers(resolvedDisplay.hideWeekends)
    }

    TimetableWeekPage(
        courses = snapshot.courses,
        timeScheme = TimetableHostLogic.resolveActiveTimeScheme(
            schemes = snapshot.timeSchemes,
            activeTimeSchemeId = snapshot.activeTimeSchemeId,
        ),
        settings = settings,
        profileName = TimetableHostLogic.resolveProfileName(
            profiles = snapshot.profiles,
            activeProfileId = snapshot.activeProfileId,
        ),
        currentWeek = currentWeek,
        totalWeeks = settings.semesterWeekCount,
        initialWeek = currentWeek,
        visibleDays = visibleDays,
        timeColumnWidth = TimetableHostLogic.timeColumnWidthDp(resolvedDisplay.wideTimeColumn).dp,
        sectionHeight = resolvedDisplay.sectionHeightDp.dp,
        onCourseClick = onOpenCourse,
        onEmptySlotClick = { dayOfWeek, section ->
            // Dart 判据：`!longPressEmptySlotToAddCourseEnabled || span <= 0` 就隐藏标记格
            // （widgets/timetable/timetable_empty_slot_layer.dart:46）。点击路径上被点的格子
            // 本身就是存在的空档，所以 span 传 1（> 0），开关关着就整个不放行。
            if (TimetableHostLogic.shouldAllowEmptySlotAdd(
                    longPressToAddCourseEnabled = resolvedDisplay.longPressEmptySlotToAddCourseEnabled,
                    span = 1,
                )
            ) {
                onOpenAddCourse(dayOfWeek, section)
            }
        },
        onDayClick = onOpenDay,
        onAddClick = onOpenAddCoursePlain,
        onManageProfilesClick = onOpenProfiles,
        onSwitchProfileClick = onSwitchProfile,
        onWeekChanged = onWeekChanged,
        // 标题样式取自用户存档（Dart `homeTitleStyle`，:1478 默认 classic）。
        homeTitleStyle = settingsModel?.homeTitleStyle ?: HomeTitleStyle.CLASSIC,
        homeMenuItems = homeMenuItems,
        onHomeMenuSelect = onHomeMenuSelect,
    )
}
