package com.mutx163.qingyu.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.clampCurrentWeekToSettings
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import com.mutx163.qingyu.pages.timetable.TimetableStyleMapping
import com.mutx163.qingyu.pages.timetable.TimetableWeekPage
import com.mutx163.qingyu.pages.timetable.WeekAgendaCardModel
import com.mutx163.qingyu.pages.timetable.WeekViewStyle
import java.time.LocalDateTime

/**
 * Phase 3.5 · L4 课表宿主层：把 [TimetableRepository] 接到 [TimetableWeekPage] 上。
 *
 * ## 这一层存在的理由
 *
 * Phase 3 交付的页面是「纯函数 + 数据入口」形态：模型层不持有状态、渲染层只负责画。
 * 壳里原先写的是 `TimetableWeekPage()` **零参调用**，于是既没有真数据、也没有真回调，
 * 表现就是「按钮点了没反应」。本层负责：订阅仓储快照 → 逐参喂给页面 → 把页面回调
 * 接到导航/仓储上。
 *
 * ## 参数透传纪律（这类 bug 的高发区）
 *
 * 页面每个业务参数都**逐个显式**传下去，不靠默认值（历史事故：删掉一个转发，
 * 全仓测试仍全绿，因为存量 UI 测试只断言「页面打开了」）。
 *
 * ## 2026-10-29 重做：设置终于进到渲染层
 *
 * 旧版把 `sectionHeight` / `timeColumnWidth` 两个值当「全部显示偏好」传给页面，
 * 设置里的卡面字段开关、字号、材质、冲突开关、时间列显示档、星期栏字色一个都没传，
 * 于是「设置里改了没反应」。现在由 [TimetableStyleMapping.weekViewStyle] 一次映射成
 * [WeekViewStyle] 交给页面，映射表逐键带 Dart 行号（见该函数 KDoc）。
 *
 * @param repository 课表仓储（task-7 交付）。
 * @param onOpenAddCourse **长按**空白格加课（带星期几与节次预填）。
 * @param onOpenCourse 点课程卡片：由壳决定先去操作层还是编辑页。
 * @param onOpenDay 点表头某一天（日视图入口）。
 * @param onSwitchProfile 点标题区：切换课表（Dart 标题触发器口径）。
 * @param onWeekChanged 翻周/选周后回调，壳写回 `currentWeek`（Dart `commitPendingWeek`）。
 * @param onAgendaClicked 点周网格里的考试/日程卡（Dart 去考试页 / 日程编辑页）。
 * @param settingsModel 完整设置模型（用户存档）。给了它才读得到真实显示偏好。
 * @param display 显示偏好**注入点**（测试用）；`null` = 按 [settingsModel] 推导。
 */
@Composable
fun TimetableHost(
    repository: TimetableRepository,
    onOpenAddCourse: (dayOfWeek: Int, section: Int) -> Unit,
    onOpenCourse: (Course) -> Unit,
    onOpenDay: (dayOfWeek: Int) -> Unit = {},
    onSwitchProfile: () -> Unit = {},
    onWeekChanged: (week: Int) -> Unit = {},
    onAgendaClicked: (WeekAgendaCardModel) -> Unit = {},
    // ⚠️ 名字带 Model 后缀是**必须的**：函数体里已有一个局部 `settings`（= `snapshot.settings`，
    // 是 `core.TimetableSettings` 那个子集），同名的参数会被它遮蔽、且极易读错。
    settingsModel: TimetableSettingsModel? = null,
    display: TimetableHostDisplayPrefs? = null,
    // 顶栏「轻屿课表」+ 右上角「更多」菜单：条目与选中回调由壳注入（页面不认识路由）。
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
) {
    // 首帧直接用仓储当前快照，避免「先画空网格再跳成有课」的闪一下。
    // ⚠️ 这不是优化，是**接口语义**：`TimetableRepository.observe` 只在**后续变更**时回调，
    // 订阅那一刻**不会**推一次当前值（见 `TimetableRepository.kt:56-61` 的通知语义）。
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
    // 渲染风格：设置模型 → 页面（唯一映射点，纯 Kotlin 可测）。
    val style: WeekViewStyle = remember(settingsModel) {
        settingsModel?.let { TimetableStyleMapping.weekViewStyle(it) } ?: WeekViewStyle()
    }
    // 周次钳制复用模型层判据（Dart `clampWeek`，domain/timetable_layout.dart:23-27），不重写。
    val currentWeek = clampCurrentWeekToSettings(snapshot.currentWeek.toLong(), settings).toInt()
    val visibleDays = remember(resolvedDisplay.hideWeekends) {
        TimetableHostLogic.visibleDayNumbers(resolvedDisplay.hideWeekends)
    }
    // 课表课时数据 + 考试 + 日程：周网格的考试/日程落格卡要用（Dart `_agendaEntriesFor`）。
    // 考试不在 `TimetableSnapshot` 里（各自仓储），从 `repository.exams` 现取。
    val exams = repository.exams
    val scheduleItems = snapshot.scheduleItems
    // 只在数据变化时取一次「此刻」：考试过期判定随它走，但不该每帧变。
    val now = remember(snapshot) { LocalDateTime.now() }

    TimetableWeekPage(
        courses = snapshot.courses,
        timeScheme = TimetableHostLogic.resolveActiveTimeScheme(
            schemes = snapshot.timeSchemes,
            activeTimeSchemeId = snapshot.activeTimeSchemeId,
        ),
        settings = settings,
        style = style,
        profileName = TimetableHostLogic.resolveProfileName(
            profiles = snapshot.profiles,
            activeProfileId = snapshot.activeProfileId,
        ),
        currentWeek = currentWeek,
        totalWeeks = settings.semesterWeekCount,
        initialWeek = currentWeek,
        visibleDays = visibleDays,
        exams = exams,
        scheduleItems = scheduleItems,
        now = now,
        onCourseClick = onOpenCourse,
        // 长按空白格加课：Dart 判据是「开关打开 + 这一格要有跨度」
        // （`timetable_empty_slot_layer.dart:46`），开关本身由 style 下传，页面只在
        // 开关开着时才装长按手势。
        onLongPressEmptySlot = { dayOfWeek, section -> onOpenAddCourse(dayOfWeek, section) },
        onAgendaClick = onAgendaClicked,
        onDayClick = onOpenDay,
        onSwitchProfileClick = onSwitchProfile,
        onWeekChanged = onWeekChanged,
        // 标题样式取自用户存档（Dart `homeTitleStyle`，:1478 默认 classic）。
        homeTitleStyle = settingsModel?.homeTitleStyle ?: HomeTitleStyle.CLASSIC,
        // 菜单形态取自用户存档（Dart `homeMenuStyle`，:1489 默认 list）；壳没传就走默认。
        homeMenuStyle = settingsModel?.homeMenuStyle ?: HomeMenuStyle.LIST,
        homeMenuItems = homeMenuItems,
        onHomeMenuSelect = onHomeMenuSelect,
    )
}
