package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import top.yukonga.miuix.kmp.basic.Scaffold
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
 */
@Composable
fun DayViewPage(
    initialWeek: Int = 1,
    initialDayOfWeek: Int = 1,
    visibleDays: List<Int> = listOf(1, 2, 3, 4, 5, 6, 7),
    totalWeeks: Int = 30,
    dataProvider: (week: Int, dayOfWeek: Int) -> DayViewPageData,
    onCloseToWeekView: () -> Unit,
    onOpenCourse: (courseId: String) -> Unit = {},
    onOpenCourseNotes: (courseId: String) -> Unit = {},
    onOpenCourseTask: (courseId: String) -> Unit = {},
    onOpenSchedule: (scheduleId: String) -> Unit = {},
    onOpenExam: (examId: String) -> Unit = {},
    onOpenTask: (task: CourseTask) -> Unit = {},
    onToggleTask: (task: CourseTask) -> Unit = {},
    onViewAllOverdue: () -> Unit = {},
    courseResolver: (CourseTask) -> Course? = { null },
    onPageChanged: ((week: Int, dayOfWeek: Int) -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val pageCount = (totalWeeks * visibleDays.size).coerceAtLeast(1)

    val initialPage = remember(initialWeek, initialDayOfWeek, visibleDays) {
        DayViewPaging.globalPage(visibleDays, initialWeek, initialDayOfWeek)
    }

    val pagerState = rememberPagerState(
        initialPage = initialPage.coerceIn(0, pageCount - 1),
        pageCount = { pageCount },
    )

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
    LaunchedEffect(pagerState, visibleDays) {
        snapshotFlow { pagerState.currentPage }.collect { page ->
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
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
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
                )
            }
        }
    }
}
