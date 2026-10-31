package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.clickable
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.pages.timetable.TimetableDateLogic
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import com.mutx163.qingyu.pages.timetable.TimetableTopBar
import com.mutx163.qingyu.pages.timetable.TimetableWeekdayHeader
import com.mutx163.qingyu.pages.timetable.WeekSelectorSheet
import com.mutx163.qingyu.pages.timetable.WeekViewStyle
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
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

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        modifier = modifier.fillMaxSize(),
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            // 顶栏「轻屿课表」+ 右上角「更多」菜单（Flutter 日视图叠在首页上，顶部仍是它）。
            if (showTopBar) {
                TimetableTopBar(
                    brand = homeTitleStyle == HomeTitleStyle.BRAND,
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
                            // 天气行：装配器按课程 id 算好的「一行文本」，不传就永远不显示
                            //（2026-10-29 二轮审核 P1-12 的病根就在这一行缺失）。
                            weatherLines = pageData.weatherLines,
                        )
                    }
                }

                // 「回今日」浮钮（Dart `timetable_screen.dart:1556-1574`）：
                // 翻到别的日期后一键回到今天；停在今天时不出现。
                if (!isCurrentPageToday) {
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
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = 20.dp),
                    )
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
 * 14sp / w700 / 主题强调色，磨砂胶囊底。这里用 [QingyuCard]（官方卡片的按压反馈）
 * 承载同一套尺寸与文案；玻璃/磨砂底属全站未接线的公共缺口（miuix-blur 尚未接入任何页面）。
 */
@Composable
private fun BackToTodayButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    QingyuCard(
        modifier = modifier.height(38.dp),
        cornerRadius = 19.dp,
        insideMargin = PaddingValues(horizontal = 16.dp),
        onClick = onClick,
    ) {
        Text(
            text = DayViewStrings.backToTodayAction.zh,
            style = MiuixTheme.textStyles.body2,
            fontWeight = FontWeight.Bold,
            color = Color(QingyuTheme.primary(dark = dark)),
        )
    }
}


