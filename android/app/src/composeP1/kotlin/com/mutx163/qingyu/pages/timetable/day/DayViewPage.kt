package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.clickable
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.shell.HomeFloatingMetrics
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.pages.timetable.ApplyChromeStatusBarInk
import com.mutx163.qingyu.pages.timetable.homeFloatingChipSurface
import com.mutx163.qingyu.pages.timetable.TimetableDateLogic
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import com.mutx163.qingyu.pages.timetable.TimetableTopBar
import com.mutx163.qingyu.pages.timetable.TimetableWeekdayHeader
import com.mutx163.qingyu.pages.timetable.WeekSelectorSheet
import com.mutx163.qingyu.pages.timetable.WeekViewStyle
import com.mutx163.qingyu.pages.timetable.TimetableChromeBandGlass
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 单日页面全量数据载体。
 *
 * 聚合全天概览卡状态、当日议程列表、当日待办带数据以及课程关联作业的存在性映射。
 */
data class DayViewPageData(
    val summaryState: DayViewSummaryState,
    val agendaEntries: List<DayAgendaEntry> = emptyList(),
    val taskBandData: DayTaskBandData? = null,
    val courseTaskPresenceMap: Map<String, Boolean> = emptyMap(),
    /** 议程条目 id → 该节次的天气一行（无数据时为空；Dart `day_course_weather_row.dart`）。 */
    val weatherLines: Map<String, String> = emptyMap(),
)

/**
 * 模型层 [DayViewDay] → 渲染层 [DayViewPageData] 的唯一转换点。
 *
 * 壳里不再自己拼 `DayViewPageData`（那正是 P1-1/P1-2/P1-3/P1-4/P1-5 的病根：
 * 壳拼错了模型，页面只能照单全收）。现在壳只要给出仓储数据，装配交给
 * `DayViewDataAssembler`，这里只做一次字段搬运。
 */
fun dayViewPageDataOf(day: DayViewDay): DayViewPageData = DayViewPageData(
    summaryState = day.summaryState,
    agendaEntries = day.agendaEntries,
    taskBandData = day.taskBandData,
    courseTaskPresenceMap = day.courseTaskPresence,
    weatherLines = day.weatherLines,
)

/**
 * 日视图顶层页面（Day View Page · Compose Phase 3）。
 *
 * 对应 Flutter `lib/screens/timetable_day_view_part.dart`：
 * - 基于 Compose 原生 [HorizontalPager] 实现无限平滑切日；
 * - 维护当前选中日期状态（周次 + 星期几），与全局连续页号严格互逆（[DayViewPaging]）；
 * - 内置 1 Hz 局部进度心跳驱动：仅计算进行中课程/日程的实时进度比与剩余分钟数，驱动卡片局部重组，避免无谓全页刷新；
 * - 统一向外暴露导航动作与条目点击回调：
 *   - [onCloseToWeekView]：关闭日视图，返回周视图
 *   - [onOpenCourse]：点击课程卡片打开详情或编辑
 *   - [onOpenCourseNotes]：记备注入口
 *   - [onOpenCourseTask]：记作业入口
 *   - [onOpenSchedule]：点击日程卡片打开日程详情
 *   - [onOpenExam]：点击考试卡片打开考试详情
 *   - [onOpenTask]：点击待办行进入待办编辑
 *   - [onToggleTask]：切换待办勾选状态
 *   - [onViewAllOverdue]：查看全部逾期任务
 *   - [onPageChanged]：翻页时同步报告最新的 (week, dayOfWeek)
 *
 * ## 能力型回调：`null` 不等于「空 lambda」（2026-10-29 二轮修复）
 *
 * 审核结论 P0-1：这些参数原先都写成 `= {}`，于是壳不传也能编译——页面照样把
 * 「作业」「备注」两个胶囊画出来，点下去**什么都不发生**（`DayViewCourseCard.kt`
 * 的胶囊是 `.clickable`）。那是「假成功」的另一种形态。
 *
 * 现在改成**可空**，语义是「本页尚未具备这项能力」：
 * - 传了回调 ⇒ 入口照常出现、照常可点；
 * - 不传（null）⇒ **入口不渲染**（不画点了没反应的按钮），而不是静默吞掉点击。
 *
 * 这也是本仓既有口径：`CourseActionSheetModel` 对「单节课提醒」一行就是
 * 「与其画一个点了没反应的入口，不如诚实地不画」。
 *
 * ## 从周视图点某天进来
 *
 * [initialDayOfWeek] 是**显式意图**：点「周五」就传 5。不传（null）才回落今天——
 * 这是唯一没有意图时的行为，不是默认值巧合。审核结论 P0-2 就是壳丢了这一参数。
 */
@Composable
fun DayViewPage(
    initialWeek: Int = 1,
    /**
     * 从星期栏点进来的那一天（1..7）。
     *
     * `null` = 没有具体意图（例如从底栏进日视图）⇒ 落在今天；
     * 不在 [visibleDays] 里时由 [DayViewPaging.normalizeDayOfWeek] 归一到第一个可见日
     * （与 Dart `normalizeDayOfWeekForVisibleDays` 同口径）。
     */
    initialDayOfWeek: Int? = null,
    visibleDays: List<Int> = listOf(1, 2, 3, 4, 5, 6, 7),
    totalWeeks: Int = 30,
    /**
     * 学期开始日（`null` = 没设，页面按「今天所在这一周」兜底算日期）。
     *
     * 顶部星期条的日期（`10/26`）、「今天」下划线、回今日浮钮都靠它；
     * 只给周次的话这几样只能瞎猜。
     */
    semesterStartDate: LocalDate? = null,
    /** 仓储认的「当前周」；空 = 按 [semesterStartDate] 现算或回落到 [initialWeek]。 */
    realCurrentWeek: Int? = null,
    /** 注入时钟（测试用）。 */
    todayDate: LocalDate = LocalDate.now(),
    /** 顶部星期条的考试红点判定（Dart `TimetableWeekdayHeader.hasExamOn`）。 */
    hasExamOnDate: (LocalDate) -> Boolean = { false },
    /** 顶部星期条的日程圆点判定（Dart `TimetableWeekdayHeader.hasScheduleOn`）。 */
    hasScheduleOnDate: (LocalDate) -> Boolean = { false },
    /** 星期条配色（星期栏字色 / 强调色两对 hex，Dart 与周视图同源）。 */
    weekdayStyle: WeekViewStyle = WeekViewStyle(),
    /** 「课卡显示冲突角标」开关（Dart `showConflictBadgeOnTimetable`；关掉只藏角标，保留冲突边框）。 */
    showConflictBadge: Boolean = true,
    /**
     * 是否显示顶部星期日期条。
     *
     * Dart 日视图是**叠在首页上**的面板，顶栏、星期条都还在（`timetable_day_view_part.dart:10-39`
     * 只替换面板本体）。Compse 迁移后它成了独立页面，星期条一度整块丢掉：
     * 看不到今天标记、看不到哪天有考试/日程，也不能点某天直接切过去。
     */
    showWeekdayHeader: Boolean = true,
    dataProvider: (week: Int, dayOfWeek: Int) -> DayViewPageData,
    onCloseToWeekView: () -> Unit,
    onOpenCourse: ((courseId: String) -> Unit)? = null,
    /**
     * 卡片右上角「备注」胶囊。
     *
     * 参数带 [week]：Dart `showCourseNoteSheet(course:, week:)` 打开的是**那一周的
     * 单节备注**（`day_view_course_agenda_card.dart:159-166`），周次传丢会编辑成
     * 「本周」的备注，翻到别的周再点就写错行。
     */
    onOpenCourseNotes: ((courseId: String, week: Int) -> Unit)? = null,
    /**
     * 卡片右上角「记作业」胶囊。
     *
     * 参数带 [week]：Dart `taskForm(initialCourse:, initialWeek: week)` 把**当前查看的
     * 那一周**作为来源周带进作业表单（`day_view_course_agenda_card.dart:174-183`）；
     * 只给课程会让壳退回仓储当前周，跨周查看时来源周记错。
     */
    onOpenCourseTask: ((courseId: String, week: Int) -> Unit)? = null,
    /**
     * 日程卡点击。
     *
     * 参数带 [occurrenceDate]：Dart `scheduleItemForm(scheduleItem:, occurrenceDate:)`
     * 编辑的是**那一次发生**（`day_view_schedule_agenda_card.dart:94-97`）；
     * 丢了它，重复日程会从「改这一次」变成「改整条系列」。
     */
    onOpenSchedule: ((scheduleId: String, occurrenceDate: java.time.LocalDateTime?) -> Unit)? = null,
    onOpenExam: ((examId: String) -> Unit)? = null,
    onOpenTask: ((task: CourseTask) -> Unit)? = null,
    onToggleTask: ((task: CourseTask) -> Unit)? = null,
    onViewAllOverdue: (() -> Unit)? = null,
    courseResolver: (CourseTask) -> Course? = { null },
    onPageChanged: ((week: Int, dayOfWeek: Int) -> Unit)? = null,
    homeTitleStyle: HomeTitleStyle = HomeTitleStyle.CLASSIC,
    profileName: String? = null,
    showTopBar: Boolean = true,
    homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST,
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
    /**
     * 页面**最底层**的背景槽（首页壁纸，`HomeWallpaperBackdrop`）。
     *
     * 与周视图同一条层次（Dart `TimetableHomeStack`：壁纸 → 状态栏遮罩 → 内容）：
     * 非空时页面底色改透明、把这层画在内容下面。为空时行为与旧版完全一致（不透明主题底）。
     */
    backdrop: (@Composable BoxScope.() -> Unit)? = null,
    /**
     * 壁纸上的顶栏墨色：`Light` = 浅墨（深色壁纸）、`Dark` = 深墨（浅色壁纸）、
     * `null` = 没有壁纸 ⇒ 主题墨色（旧行为）。
     *
     * 判据不在这里算：宿主用壁纸顶部亮度过
     * [com.mutx163.qingyu.pages.shell.HomeBackgroundModel] 的 `chromeInkPolarity`。
     */
    chromeInk: HomeInkPolarity? = null,
    /**
     * 壁纸三档亮度带（顶栏 / 星期栏 / 正文）。星期栏与空态的字色靠它翻深/翻浅
     * （Dart `homePageOverWallpaperInk` 同口径，见
     * [com.mutx163.qingyu.pages.shell.HomeBackgroundModel.inkOverWallpaperArgb]）。
     * `null` = 没壁纸 / 亮度未知 ⇒ 保持设置 / 主题原色。
     */
    wallpaperBands: HomeBackgroundModel.InkBands? = null,
    /**
     * 材质快照（`SettingsMaterialModel.renderSpecOf` 的唯一出口）。null = 老行为
     * （顶栏不画玻璃带、议程卡按各自的实体填充）。
     */
    material: HomeMaterialRenderSpec? = null,
    /**
     * 当前有没有可用壁纸。顶栏玻璃带与议程卡液态档都只有在壁纸之上才值得采样
     * （没有壁纸时 Dart 一律回落实体）。
     */
    hasBackdrop: Boolean = false,
    /**
     * 无壁纸 / 实体玻璃带用的页底色（ARGB，来自 `HomeBackdropSnapshot.pageColorArgb`）。
     * null = 主题兜底色（老行为）。
     */
    pageColorArgb: Int? = null,
    /**
     * 「回今日」浮钮的底边距（从屏幕底端起，已含系统内边距）。
     *
     * 由宿主按**玻璃坞药丸的真实占用**算好传进来（`HomeFloatingMetrics`）：页面自己拿不到
     * 坞的几何，以前写死的 `20dp` 直接落在药丸底下 —— 用户报的「按钮在导航栏底下」就是这一条。
     *
     * `null` = 宿主没接 ⇒ 退回旧口径（系统内边距 + 20dp）。
     */
    floatingButtonBottomInset: Dp? = null,
    /**
     * 可滚动内容的底部避让（从屏幕底端起，已含系统内边距）：玻璃坞形态 = 药丸占用，
     * 经典形态 = 系统手势条。`null` = 退回 `innerPadding.bottom + 64dp`。
     */
    contentBottomInset: Dp? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val pageCount = (totalWeeks * visibleDays.size).coerceAtLeast(1)

    // 打开哪一天：显式意图优先（点「周五」就开周五），没有意图才回落今天。
    // 不在 visibleDays 里时归一到第一个可见日（Dart `normalizeDayOfWeekForVisibleDays`）。
    val initialPage = remember(initialWeek, initialDayOfWeek, visibleDays) {
        val seededDay = DayViewPaging.normalizeDayOfWeek(
            visibleDays = visibleDays,
            dayOfWeek = initialDayOfWeek ?: LocalDate.now().dayOfWeek.value,
        )
        DayViewPaging.globalPage(visibleDays, initialWeek, seededDay)
    }

    val pagerState = rememberPagerState(
        initialPage = initialPage.coerceIn(0, pageCount - 1),
        pageCount = { pageCount },
    )

    val scope = rememberCoroutineScope()
    var showWeekSelector by remember { mutableStateOf(false) }

    // 「今天在哪一周」：优先按开学日现算（跨周自动跟手），算不出才用仓储当前周。
    val todayWeek = realCurrentWeek
        ?: TimetableDateLogic.currentSemesterWeek(
            semesterStart = semesterStartDate,
            totalWeeks = totalWeeks.coerceAtLeast(1),
            today = todayDate,
        )
        ?: initialWeek

    // 当前页（用于星期条高亮 / 周次选择器 / 回今日浮钮显隐）。
    val currentTarget = DayViewPaging.targetForGlobalPage(visibleDays, pagerState.currentPage)
    val currentTargetWeek = currentTarget?.week ?: initialWeek
    val currentTargetDayOfWeek = currentTarget?.dayOfWeek
        ?: DayViewPaging.normalizeDayOfWeek(visibleDays, todayDate.dayOfWeek.value)
    val isCurrentPageToday = currentTarget != null &&
        if (semesterStartDate != null) {
            TimetableDateLogic.dateForWeekDay(
                semesterStart = semesterStartDate,
                week = currentTarget.week,
                dayOfWeek = currentTarget.dayOfWeek,
            ) == todayDate
        } else {
            // 没设开学日：与装配器同口径——同一周内、星期相同才算今天。
            currentTarget.dayOfWeek == todayDate.dayOfWeek.value && currentTarget.week == todayWeek
        }

    // ── 1 Hz 局部进度心跳驱动 ──
    // 维护当前时间的日内分钟数（精确到浮点小数，如 09:30:15 -> 570.25）
    // 仅驱动进行中卡片的重组，静止卡片与其它页面不受影响
    var currentMinuteOfDay by remember {
        val now = LocalDateTime.now()
        mutableDoubleStateOf(now.hour * 60.0 + now.minute + now.second / 60.0)
    }

    LaunchedEffect(Unit) {
        while (isActive) {
            delay(1000L)
            val now = LocalDateTime.now()
            currentMinuteOfDay = now.hour * 60.0 + now.minute + now.second / 60.0
        }
    }

    // ── 翻页监听与外部状态同步 ──
    // 只在**停稳**后上报一次：`snapshotFlow { currentPage }` 在快速甩动跨页时每越一页
    // 都会发射，直接同步会给仓储每页写一次盘（Dart 也是 ScrollEnd 后才 commit，见
    // `day_view_transition_controller.dart:646-702`）。
    LaunchedEffect(pagerState, visibleDays) {
        snapshotFlow { pagerState.currentPage to pagerState.isScrollInProgress }
            .collect { (page, scrolling) ->
                if (scrolling) return@collect
                val target = DayViewPaging.targetForGlobalPage(visibleDays, page)
                if (target != null) {
                    onPageChanged?.invoke(target.week, target.dayOfWeek)
                }
            }
    }

    // ── 首页壁纸 + 顶栏玻璃带 + 课卡液态档（2026-11-01）──
    // 与周视图（`TimetableWeekPage`）同一套三层接线，缺了任一层就会出现
    // 「周视图有壁纸、日视图是纯色底」这种同页不一致：
    //   ① 把壁纸层录进 `pageBackdrop`（记录 ≠ 上屏，壁纸照常画）；
    //   ② 顶栏玻璃带（状态栏 + 标题行 + 星期栏 = 一条带）在带子上采样 + 高斯 + 染色；
    //   ③ 议程卡从**整页共享的预糊层**取自己那块像素，一屏十来张卡只糊一趟。
    // 只有「液态档 + 真有壁纸 + 设备支持 RuntimeShader」三件事同时成立才真采样。
    val density = LocalDensity.current
    val scaffoldBg = Color(QingyuTheme.scaffoldBackground(dark))
    val pageBackdrop = rememberLayerBackdrop()
    val cardGlassBackdrop = rememberLayerBackdrop()
    // 玻璃带是否「液态档 + 真有壁纸 + 设备支持」：判据与渲染层同一份
    //（`TimetableChromeBandGlass` 里那段 `when`）。这里留一份只为给下面的
    // `pageBackdropActive`（要不要挂录像层）用，不参与画玻璃。
    val bandBlurActive = material?.band == SurfaceMaterialState.LIQUID_GLASS &&
        hasBackdrop && isRuntimeShaderSupported()
    // 星期条背后是不是壁纸：没画带子（老行为 / OFF）或液态玻璃 ⇒ 是；实体档 ⇒ 否。
    val bandOverWallpaper = material == null ||
        material.band == SurfaceMaterialState.OFF ||
        bandBlurActive
    val bandSolidColor = pageColorArgb?.let { Color(it) } ?: scaffoldBg
    // 形状边界要往屏幕外推多少（逻辑 dp，只算作用带那一份）：取值理由见
    // `SettingsMaterialModel.bandGlassOverdrawDp`。左右还要再叠上安全区，
    // 那一步要 `innerPadding`，所以在 Scaffold 内容里算（见下方 bandOverdrawPx）。
    val bandOverdrawBaseDp = SettingsMaterialModel.bandGlassOverdrawDp(
        material?.liquidRefractionBand ?: 0f,
    )


    // 状态栏图标 / 文字的明暗：沿用标题行同一条判据 [chromeInk]（宿主用壁纸顶部亮度算的）。
    //   Light = 深色壁纸 ⇒ 浅墨 ⇒ 状态栏图标要浅色（isAppearanceLightStatusBars = false）
    //   Dark  = 浅色壁纸 ⇒ 深墨 ⇒ 状态栏图标要深色（true）
    // 没有壁纸 / 亮度还没量出来 ⇒ 跟系统明暗，与壳的兜底一致。
    val lightStatusBarIcons = when (chromeInk) {
        HomeInkPolarity.Light -> false
        HomeInkPolarity.Dark -> true
        null -> !dark
    }
    ApplyChromeStatusBarInk(lightIcons = lightStatusBarIcons)

    // 议程卡液态档：门控与顶栏带同构，三件事缺一件就退回各卡原有的实体填充。
    val cardGlassActive = material?.courseCard == SurfaceMaterialState.LIQUID_GLASS &&
        hasBackdrop && isRuntimeShaderSupported()
    val cardBlurSigmaPx = with(density) {
        (material?.courseCardBlurSigma ?: 0f).dp.toPx()
    }
    // σ = 0 是**有效的清档**（Dart 清澈档）：背景原样透出、不跑高斯，连预糊也省掉。
    val cardPreblurActive = cardGlassActive && cardBlurSigmaPx > 0f
    // ── 「回今日」浮钮的玻璃档（与周视图「回本周」同一条，见 `homeFloatingChipSurface`）──
    // 跟的是**玻璃坞**那一档（作用范围 → 玻璃坞），不是课程卡片的材质。
    val floatingGlassActive = (material?.dock == SurfaceMaterialState.LIQUID_GLASS ||
        material?.dock == SurfaceMaterialState.FROST) &&
        hasBackdrop && isRuntimeShaderSupported()
    // 浮钮只在「当前看的不是今天」时出现；不可见就不为它录整屏。
    // 今天还必须是可见星期、且落在学期内（Dart `_canNavigateDayViewToToday`，
    // `timetable_screen.dart:1428-1435`：假期/学期末、或今天那个星期被隐藏时不给入口，
    // 免得点一下跳到「上周同一个星期几」；判据收敛在 [TimetableDateLogic.canNavigateToToday]）。
    val showsBackToToday = TimetableDateLogic.canNavigateToToday(
        isCurrentPageToday = isCurrentPageToday,
        visibleDays = visibleDays,
        semesterStart = semesterStartDate,
        totalWeeks = totalWeeks.coerceAtLeast(1),
        today = todayDate,
    )
    // 录像带只在真有人采时才挂：顶栏带要采、议程卡液态档要采，或浮钮真要玻璃。
    val pageBackdropActive = bandBlurActive || cardGlassActive ||
        (floatingGlassActive && showsBackToToday)
    val cardGlassSource: Backdrop? = when {
        !cardGlassActive -> null
        cardPreblurActive -> cardGlassBackdrop
        else -> pageBackdrop
    }

    Scaffold(
        // 有壁纸时底色必须透明，否则不透明主题底会把壁纸整张盖掉。
        containerColor = if (backdrop == null) scaffoldBg else Color.Transparent,
        modifier = modifier.fillMaxSize(),
    ) { innerPadding ->
        // 列表底部避让的账（Dart `_glassDockContentScrollInset` + `_backToTodayButtonScrollInset`）：
        // 坞占用（或系统手势条）打底；「回今日」浮钮可见时再补「钮高 + 间隙」那一段，
        // 让最后一张卡能滚到钮的上方。浮钮不可见时不为一颗看不见的按钮白留空白。
        val listBottomInset = maxOf(
            innerPadding.calculateBottomPadding() + 64.dp,
            (contentBottomInset ?: 0.dp) +
                if (showsBackToToday) HomeFloatingMetrics.BACK_TO_TODAY_SCROLL_EXTRA_DP.dp else 0.dp,
        )
        Box(modifier = Modifier.fillMaxSize()) {
        // 壁纸层在最底（Dart 的层次：壁纸 → 内容）。没有壁纸时这一行什么也不画。
        // 顶栏玻璃带与议程卡都要采样它，所以包一层（只有真要玻璃时才挂 `layerBackdrop`）。
        if (backdrop != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (pageBackdropActive) {
                            Modifier.layerBackdrop(pageBackdrop)
                        } else {
                            Modifier
                        },
                    ),
            ) {
                backdrop.invoke(this)
            }
        }
        // ── 议程卡的共享预糊层：整屏只糊**这一趟** ──
        // `alpha(0f)` = 这一层不上屏，唯一作用是把自己录进 `cardGlassBackdrop`。
        // 所有卡随后都只从这张图里取自己那块：一屏十来张卡共用一次高斯。
        if (cardPreblurActive) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .alpha(0f)
                    .layerBackdrop(cardGlassBackdrop)
                    .drawBackdrop(
                        backdrop = pageBackdrop,
                        shape = { RectangleShape },
                        effects = {
                            blur(cardBlurSigmaPx)
                            vibrancy()
                        },
                    ),
            )
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 左右吃安全区；顶部**刻意不吃**——玻璃带要从 y = 0（状态栏背后）开始，
                // 由带子内部用等高的 Spacer 把标题行顶到状态栏下面。
                // 底部也刻意不吃——滚动视口要铺到屏幕最底，卡片从手势条底下穿过去。
                .padding(
                    start = innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    end = innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                ),
        ) {
            // 玻璃节点是带子盒子的孩子，而带子盒子被左右安全区内缩过（上面 Column 的
            // padding）。横屏挖孔时只推「作用带 + 1」还压不住屏幕边 —— 形状的左 / 右边界
            // 会落进可见区，读成一条竖折射边。把安全区一起加进外溢量，形状边界才真的出屏
            //（Dart 那条带是 `Positioned(left: 0, right: 0)` 的全宽层，天然没这问题）。
            val bandOverdrawPx = with(density) {
                (bandOverdrawBaseDp.dp + maxOf(
                    innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                )).toPx()
            }
            // ── 顶栏玻璃带：状态栏 + 标题行 + 星期栏 = 同一条带 ──
            // 三块内容装在同一个盒子里，玻璃只在**一个**节点上挂一次（一次采样、
            // 一次高斯、一次折射、一次染色）。玻璃层本身是共享件
            //（`TimetableChromeBandGlass`），与周/月视图同一条带。
            TimetableChromeBandGlass(
                material = material,
                hasBackdrop = hasBackdrop,
                backdrop = pageBackdrop,
                solidColor = bandSolidColor,
                overdrawDp = (bandOverdrawBaseDp.dp + maxOf(
                    innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                )),
            ) {

                Column(modifier = Modifier.fillMaxWidth()) {
                    // 状态栏区域留白：带子画到屏幕最顶，内容仍停在状态栏下面。
                    Spacer(modifier = Modifier.height(innerPadding.calculateTopPadding()))

                    // 顶栏「轻屿课表」+ 右上角「更多」菜单（Flutter 日视图叠在首页上，顶部仍是它）。
                    if (showTopBar) {
                        TimetableTopBar(
                            brand = homeTitleStyle == HomeTitleStyle.BRAND,
                            inkPolarity = chromeInk,
                            profileName = profileName,
                            homeMenuStyle = homeMenuStyle,
                            menuItems = homeMenuItems,
                            onMenuSelect = onHomeMenuSelect,
                        )
                    }
                    // 顶部星期日期条（Dart 日视图叠在首页上，这一条一直可见）：
                    // 周次 + 周一..周日 + 日期 + 今天标记 + 考试/日程圆点 + 点某天换日。
                    if (showWeekdayHeader && currentTarget != null) {
                        TimetableWeekdayHeader(
                            week = currentTarget.week,
                            currentWeek = todayWeek,
                            todayDate = todayDate,
                            semesterStartDate = semesterStartDate,
                            visibleDays = visibleDays,
                            style = weekdayStyle,
                            // 星期条压在**壁纸**上才谈壁纸墨色：实体档的带子是不透明的
                            // 页底色条，底下没有壁纸（Dart `homePageWeekdayBarOverWallpaper`）。
                            wallpaperLuminance = wallpaperBands?.weekday?.takeIf {
                                bandOverWallpaper
                            },
                            selectedDayOfWeek = currentTarget.dayOfWeek,
                            hasExamOnDate = hasExamOnDate,
                            hasScheduleOnDate = hasScheduleOnDate,
                            onDayClick = { dayOfWeek ->
                                scope.launch {
                                    pagerState.animateScrollToPage(
                                        DayViewPaging.globalPage(
                                            visibleDays = visibleDays,
                                            week = currentTarget.week,
                                            dayOfWeek = dayOfWeek,
                                        ).coerceIn(0, pageCount - 1),
                                    )
                                }
                            },
                            onWeekTitleClick = { showWeekSelector = true },
                        )
                    }
                }
            }
            // 下方内容：从玻璃带底部开始，占满剩余高度（底部仍铺到屏幕最底）。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            ) {
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier.fillMaxSize(),
                ) { page ->
                    val target = DayViewPaging.targetForGlobalPage(visibleDays, page)
                    if (target != null) {
                        val pageData = dataProvider(target.week, target.dayOfWeek)

                        // 仅在当前查看的日子是今天时，计算进行中的进度快照
                        val progressMap = remember(
                            pageData.agendaEntries,
                            currentMinuteOfDay,
                            target.week,
                            target.dayOfWeek,
                        ) {
                            if (!pageData.summaryState.isToday) {
                                emptyMap()
                            } else {
                                val map = mutableMapOf<String, DayAgendaProgress>()
                                for (entry in pageData.agendaEntries) {
                                    val progress = DayAgendaLogic.resolveProgress(
                                        startTime = entry.startTime,
                                        endTime = entry.endTime,
                                        currentMinutes = currentMinuteOfDay,
                                    )
                                    if (progress != null) {
                                        map[entry.id] = progress
                                    }
                                }
                                map
                            }
                        }

                        DayViewScrollContent(
                            summaryState = pageData.summaryState,
                            agendaEntries = pageData.agendaEntries,
                            dayOfWeek = target.dayOfWeek,
                            taskBandData = pageData.taskBandData,
                            progressMap = progressMap,
                            courseTaskPresenceMap = pageData.courseTaskPresenceMap,
                            onCloseToWeekView = onCloseToWeekView,
                            onOpenCourse = onOpenCourse,
                            onOpenCourseNotes = onOpenCourseNotes,
                            onOpenCourseTask = onOpenCourseTask,
                            onOpenSchedule = onOpenSchedule,
                            onOpenExam = onOpenExam,
                            onOpenTask = onOpenTask,
                            onToggleTask = onToggleTask,
                            onViewAllOverdue = onViewAllOverdue,
                            courseResolver = courseResolver,
                            showConflictBadge = showConflictBadge,
                            // 空态文字直接压在壁纸上：正文那档亮度决定字色。
                            wallpaperLuminance = wallpaperBands?.body,
                            // 天气行：装配器按课程 id 算好的「一行文本」，不传就永远不显示
                            //（2026-10-29 二轮审核 P1-12 的病根就在这一行缺失）。
                            weatherLines = pageData.weatherLines,
                            // 材质与整页共享采样层（见本函数上方那三段接线）。
                            material = material,
                            glassBackdrop = cardGlassSource,
                            // 视口铺到屏幕最底，底部避让由页面统一定好（含坞与浮钮）。
                            bottomInset = listBottomInset,
                        )
                    }
                }

                // 「回今日」浮钮（Dart `timetable_screen.dart:1556-1574`）：
                // 翻到别的日期后一键回到今天；停在今天时不出现。
                if (showsBackToToday) {
                    val todayButtonShape = RoundedCornerShape(BACK_TO_TODAY_HEIGHT_DP.dp / 2)
                    val todayChipSurface = homeFloatingChipSurface(
                        backdrop = if (floatingGlassActive) pageBackdrop else null,
                        material = material,
                        hasBackdrop = hasBackdrop,
                        shape = todayButtonShape,
                        solidColor = MiuixTheme.colorScheme.surface,
                    )
                    BackToTodayButton(
                        onClick = {
                            scope.launch {
                                pagerState.animateScrollToPage(
                                    DayViewPaging.globalPage(
                                        visibleDays = visibleDays,
                                        week = todayWeek,
                                        dayOfWeek = todayDate.dayOfWeek.value,
                                    ).coerceIn(0, pageCount - 1),
                                )
                            }
                        },
                        surface = todayChipSurface,
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            // 底边距由宿主按玻璃坞药丸的真实占用算好（见 `HomeFloatingMetrics`）；
                            // 宿主没接时退回旧口径（系统内边距 + 20dp）。
                            .padding(
                                bottom = floatingButtonBottomInset
                                    ?: (innerPadding.calculateBottomPadding() + 20.dp),
                            ),
                    )
                }
            }
        }
        }
    }

    // 周次选择器：Dart 星期条左端的「第 N 周」可点开（`timetable_weekday_header.dart:176-196`）。
    WeekSelectorSheet(
        show = showWeekSelector,
        availableWeeks = (1..totalWeeks.coerceAtLeast(1)).toList(),
        visibleWeek = currentTargetWeek,
        currentSemesterWeek = todayWeek,
        onDismiss = { showWeekSelector = false },
        onSelect = { week ->
            showWeekSelector = false
            scope.launch {
                pagerState.animateScrollToPage(
                    DayViewPaging.globalPage(
                        visibleDays = visibleDays,
                        week = week,
                        dayOfWeek = currentTargetDayOfWeek,
                    ).coerceIn(0, pageCount - 1),
                )
            }
        },
    )
}

/**
 * 日视图底部居中的「回今日」浮钮。
 *
 * Dart `timetable_back_to_today_button.dart`：38dp 高、圆角 = 半高、左右 16dp、
 * 14sp / w700 / 主题强调色，**磨砂胶囊底**（液态档是同一块玻璃 + 折射）。
 * 这里用 [QingyuCard]（官方卡片的按压反馈）承载同一套尺寸与文案，卡面由
 * [homeFloatingChipSurface] 画（玻璃 / 实底回落）—— 与周视图「回本周」同一份判据。
 *
 * @param surface 卡面 modifier（玻璃或实底），由调用方在 composition 里建好。
 */
@Composable
private fun BackToTodayButton(
    onClick: () -> Unit,
    surface: Modifier,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    QingyuCard(
        modifier = modifier.height(BACK_TO_TODAY_HEIGHT_DP.dp).then(surface),
        cornerRadius = BACK_TO_TODAY_HEIGHT_DP.dp / 2,
        insideMargin = PaddingValues(horizontal = 16.dp),
        // 卡面自己画（上面那条 modifier），卡片本体让开 —— 否则主题实底会把玻璃盖住。
        colors = CardDefaults.defaultColors(color = Color.Transparent),
        onClick = onClick,
    ) {
        Text(
            text = DayViewStrings.backToTodayAction.zh,
            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.BOLD),
            color = Color(QingyuTheme.primary(dark = dark)),
        )
    }
}

/** 「回今日」钮高（Dart `TimetableBackToTodayButton.height = 38`），圆角恒为其一半。 */
private const val BACK_TO_TODAY_HEIGHT_DP = 38f


