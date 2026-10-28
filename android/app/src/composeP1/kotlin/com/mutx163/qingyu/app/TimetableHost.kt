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
 * ## 显示偏好为什么是入参而不是从 `settings` 读
 *
 * `core.TimetableSettings` 是本族裁定的**四键子集**（sections / activeTimeSchemeId /
 * semesterWeekCount / semesterStartDate），没有 `timetableHideWeekends` /
 * `timeColumnWidthMode` / `sectionHeight` / `longPressEmptySlotToAddCourseEnabled`。
 * 完整设置模型由设置族移植，在那之前这几个值只能由壳接线层注入（默认值取 Dart 默认）。
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
 * @param display 显示偏好（见 [TimetableHostDisplayPrefs]，默认值取 Dart 默认）。
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
    display: TimetableHostDisplayPrefs = TimetableHostDisplayPrefs(),
) {
    // 首帧直接用仓储当前快照，避免「先画空网格再跳成有课」的闪一下。
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }

    DisposableEffect(repository) {
        val subscription = repository.observe { updated -> snapshot = updated }
        onDispose { subscription.close() }
    }

    val settings = snapshot.settings
    // 周次钳制复用模型层判据（Dart `clampWeek`，domain/timetable_layout.dart:23-27），不重写。
    val currentWeek = clampCurrentWeekToSettings(snapshot.currentWeek.toLong(), settings).toInt()
    val visibleDays = remember(display.hideWeekends) {
        TimetableHostLogic.visibleDayNumbers(display.hideWeekends)
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
        timeColumnWidth = TimetableHostLogic.timeColumnWidthDp(display.wideTimeColumn).dp,
        sectionHeight = display.sectionHeightDp.dp,
        onCourseClick = onOpenCourse,
        onEmptySlotClick = { dayOfWeek, section ->
            // Dart 判据：`!longPressEmptySlotToAddCourseEnabled || span <= 0` 就隐藏标记格
            // （widgets/timetable/timetable_empty_slot_layer.dart:46）。点击路径上被点的格子
            // 本身就是存在的空档，所以 span 传 1（> 0），开关关着就整个不放行。
            if (TimetableHostLogic.shouldAllowEmptySlotAdd(
                    longPressToAddCourseEnabled = display.longPressEmptySlotToAddCourseEnabled,
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
    )
}
