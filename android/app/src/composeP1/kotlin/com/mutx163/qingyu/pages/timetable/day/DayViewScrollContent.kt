package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask

/**
 * 单日内容滚动壳（Day View Scroll Content）。
 *
 * 对应 Flutter `lib/widgets/timetable/day_view/day_view_scroll_shell.dart`：
 * - 基于 [LazyColumn] 原生高效滚动容器；
 * - 顶部 [DayViewSummaryCard] 通过 [stickyHeader] 悬浮吸顶；
 * - 自带 12dp 下呼吸间隙（让列表向上滑动时自然钻入卡片底下，而不是死截断）；
 * - 依次编排：
 *   1. 吸顶全天概览卡（SummaryCard）；
 *   2. 全天待办折叠带（[DayViewTaskBandCard]，若有任务）；
 *   3. 议程列表（各卡片按时间严格稳定排序）；
 *   4. 空态卡片（[DayViewEmptyState]，在无课程且无日程且无待办时居中展示）。
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun DayViewScrollContent(
    summaryState: DayViewSummaryState,
    agendaEntries: List<DayAgendaEntry>,
    dayOfWeek: Int? = null,
    taskBandData: DayTaskBandData? = null,
    progressMap: Map<String, DayAgendaProgress> = emptyMap(),
    courseTaskPresenceMap: Map<String, Boolean> = emptyMap(),
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
    modifier: Modifier = Modifier,
    lazyListState: LazyListState = rememberLazyListState(),
    contentPadding: PaddingValues = PaddingValues(
        start = 14.dp,
        end = 14.dp,
        top = 8.dp,
        bottom = 64.dp, // 底部留出悬浮底坞与避让余量
    ),
) {
    LazyColumn(
        state = lazyListState,
        modifier = modifier.fillMaxSize(),
        contentPadding = contentPadding,
    ) {
        // ── 吸顶全天概览卡 ──
        // 12dp 的下内边距就是概览卡与议程列表之间的呼吸间距：
        // 静止时间距优美，列表滑动时自然滑入概览卡底下。
        stickyHeader(key = "day-summary-sticky-header") {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
            ) {
                DayViewSummaryCard(
                    state = summaryState,
                    onClose = onCloseToWeekView,
                )
            }
        }

        // ── 全天待办带（有任务时展示，折叠或展开） ──
        if (taskBandData != null && taskBandData.isNotEmpty) {
            item(key = "day-task-band-item") {
                DayViewTaskBandCard(
                    data = taskBandData,
                    onToggleTask = onToggleTask,
                    onEditTask = onOpenTask,
                    onViewAllOverdue = onViewAllOverdue,
                    courseResolver = courseResolver,
                )
                Spacer(modifier = Modifier.height(8.dp))
            }
        }

        // ── 空态卡片（无课程且无日程且无待办时展示） ──
        if (agendaEntries.isEmpty() && (taskBandData == null || taskBandData.isEmpty)) {
            item(key = "day-empty-state-item") {
                DayViewEmptyState(
                    week = summaryState.week,
                    dayOfWeek = dayOfWeek,
                )
            }
        } else {
            // ── 议程列表（各卡片按时间稳定排序） ──
            items(
                items = agendaEntries,
                key = { it.id },
            ) { entry ->
                when (entry) {
                    is DayAgendaEntry.CourseEntry -> {
                        DayViewCourseCard(
                            entry = entry,
                            week = summaryState.week,
                            progress = progressMap[entry.id],
                            onTap = { onOpenCourse(entry.course.id) },
                            onOpenNotes = { onOpenCourseNotes(entry.course.id) },
                            onOpenTask = { onOpenCourseTask(entry.course.id) },
                            hasTask = courseTaskPresenceMap[entry.course.id] == true,
                        )
                    }

                    is DayAgendaEntry.ScheduleEntry -> {
                        DayViewScheduleCard(
                            entry = entry,
                            progress = progressMap[entry.id],
                            onTap = { onOpenSchedule(entry.scheduleItem.id) },
                        )
                    }

                    is DayAgendaEntry.ExamEntry -> {
                        DayViewExamCard(
                            entry = entry,
                            onTap = { onOpenExam(entry.exam.id) },
                        )
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}
