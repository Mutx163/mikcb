package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
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
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import top.yukonga.miuix.kmp.blur.Backdrop

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
    // 能力型回调：null = 壳还没接线 ⇒ 对应入口**不渲染**（不画点了没反应的按钮）。
    // 见 DayViewPage 的 KDoc「能力型回调：null 不等于空 lambda」。
    onOpenCourse: ((courseId: String) -> Unit)? = null,
    onOpenCourseNotes: ((courseId: String, week: Int) -> Unit)? = null,
    onOpenCourseTask: ((courseId: String, week: Int) -> Unit)? = null,
    onOpenSchedule: ((scheduleId: String, occurrenceDate: java.time.LocalDateTime?) -> Unit)? = null,
    onOpenExam: ((examId: String) -> Unit)? = null,
    onOpenTask: ((task: CourseTask) -> Unit)? = null,
    onToggleTask: ((task: CourseTask) -> Unit)? = null,
    onViewAllOverdue: (() -> Unit)? = null,
    courseResolver: (CourseTask) -> Course? = { null },
    weatherLines: Map<String, String> = emptyMap(),
    /** 「课卡显示冲突角标」开关（Dart `showConflictBadgeOnTimetable`）。 */
    showConflictBadge: Boolean = true,
    /**
     * 材质快照（`SettingsMaterialModel.renderSpecOf`）。整页一份，逐卡下传。
     * null = 老行为（各卡原有的实体填充）。
     */
    material: HomeMaterialRenderSpec? = null,
    /**
     * 液态档的**整页共享**背景采样源（`DayViewPage` 建好后整页共用一层）。
     * 非空且生效档为液态时各卡才真采样，否则退回实底填充。
     */
    glassBackdrop: Backdrop? = null,
    /**
     * 列表底部的**总**避让（dp，从屏幕底端起算）。
     *
     * 页面自 2026-11-01 起不再吃 Scaffold 的底部内边距（视口要铺到屏幕最底，卡片从手势条
     * 底下穿过去），所以由页面把这笔账算好传进来：系统手势条 / 玻璃坞药丸占用 +（「回今日」
     * 浮钮出现时）钮高与间隙。默认 64 是「没有坞、没有浮钮」时的呼吸余量。
     */
    bottomInset: Dp = 64.dp,
    /** 空态那块的壁纸亮度（正文带）；null = 没壁纸，保持主题原色。 */
    wallpaperLuminance: Double? = null,
    /**
     * 摘要卡背后壁纸的**星期栏那档**亮度（玻璃压壁纸时按卡面有效亮度翻墨色）；
     * null = 没壁纸 / 亮度未知 ⇒ 摘要卡用主题前景色。
     */
    summaryWallpaperLuminance: Double? = null,
    /** 摘要卡用的自定义星期栏字色（hex）与默认值（hex，用于识别"没改过=按亮度翻"）。 */
    summaryWeekdayFontColorHex: String? = null,
    summaryWeekdayFontDefaultHex: String? = null,
    /**
     * 真摘要卡的附加修饰器（首页展开态的飞行测量 + 飞行期间不画）。
     *
     * 挂**卡本身**而不是外面的 stickyHeader 盒子：飞行终点要的是卡片四边，
     * 盒子还含 12dp 下呼吸间距，量成盒子会让落点整体偏下 12dp。
     */
    summaryModifier: Modifier = Modifier,
    modifier: Modifier = Modifier,
    lazyListState: LazyListState = rememberLazyListState(),
    contentPadding: PaddingValues = PaddingValues(
        start = 14.dp,
        end = 14.dp,
        // top = 0（2026-11-03）：星期栏与滚动区之间的缝由页面在滚动区**外**给
        // （`DayViewPage.DAY_VIEW_CONTENT_TOP_SEAM_DP`，Dart `timetable_day_view_part.dart:37`
        // 的 14dp 同口径）。stickyHeader 的钉住位是 `-beforeContentPadding`
        // （foundation `LazyLayoutStickyItems`），top padding 只在静止时有缝、
        // 滚过 2×padding 后首卡会贴死星期栏——缝必须在滚动区外才钉住不消失。
        top = 0.dp,
        bottom = bottomInset,
    ),
) {
    LazyColumn(
        state = lazyListState,
        modifier = modifier.fillMaxSize().scrollEndHaptic().overScrollVertical(),
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
                    material = material,
                    glassBackdrop = glassBackdrop,
                    wallpaperLuminance = summaryWallpaperLuminance,
                    weekdayFontColorHex = summaryWeekdayFontColorHex,
                    weekdayFontColorDefaultHex = summaryWeekdayFontDefaultHex,
                    modifier = summaryModifier,
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
                    material = material,
                    glassBackdrop = glassBackdrop,
                    wallpaperLuminance = wallpaperLuminance,
                )
                Spacer(modifier = Modifier.height(8.dp))
            }
        }

        // ── 空态卡片（无课程且无日程且无待办时展示） ──
        if (agendaEntries.isEmpty() && (taskBandData == null || taskBandData.isEmpty)) {
            item(key = "day-empty-state-item") {
                // Dart 是 `SliverFillRemaining(hasScrollBody: false)` ⇒ 空态在可视区里垂直居中；
                // 直接当普通 item 摆会贴在摘要卡下面（2026-10-31 审核 P2-7）。
                Box(
                    modifier = Modifier.fillParentMaxHeight(),
                    contentAlignment = androidx.compose.ui.Alignment.Center,
                ) {
                    DayViewEmptyState(
                        week = summaryState.week,
                        dayOfWeek = dayOfWeek,
                        wallpaperLuminance = wallpaperLuminance,
                    )
                }
            }
        } else {
            // ── 议程列表（各卡片按时间稳定排序） ──
            items(
                items = agendaEntries,
                key = { it.id },
            ) { entry ->
                when (entry) {
                    is DayAgendaEntry.CourseEntry -> {
                        // 备注 / 记作业都要带**这一页的周次**（Dart 两处调用都以当前查看周为上下文），
                        // 不是仓储当前周：翻到第 5 周再点，写进去的必须是第 5 周。
                        val viewedWeek = summaryState.week
                        DayViewCourseCard(
                            entry = entry,
                            week = viewedWeek,
                            progress = progressMap[entry.id],
                            onTap = onOpenCourse?.let { open -> { open(entry.course.id) } },
                            onOpenNotes = onOpenCourseNotes?.let { open -> { open(entry.course.id, viewedWeek) } },
                            onOpenTask = onOpenCourseTask?.let { open -> { open(entry.course.id, viewedWeek) } },
                            hasTask = courseTaskPresenceMap[entry.course.id] == true,
                            weatherInfo = weatherLines[entry.id],
                            showConflictBadge = showConflictBadge,
                            material = material,
                            glassBackdrop = glassBackdrop,
                            wallpaperLuminance = wallpaperLuminance,
                        )
                    }

                    is DayAgendaEntry.ScheduleEntry -> {
                        DayViewScheduleCard(
                            entry = entry,
                            progress = progressMap[entry.id],
                            onTap = onOpenSchedule?.let { open ->
                                { open(entry.scheduleItem.id, entry.occurrenceDate) }
                            },
                            material = material,
                            glassBackdrop = glassBackdrop,
                            wallpaperLuminance = wallpaperLuminance,
                        )
                    }

                    is DayAgendaEntry.ExamEntry -> {
                        DayViewExamCard(
                            entry = entry,
                            onTap = onOpenExam?.let { open -> { open(entry.exam.id) } },
                            material = material,
                            glassBackdrop = glassBackdrop,
                            wallpaperLuminance = wallpaperLuminance,
                        )
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}
