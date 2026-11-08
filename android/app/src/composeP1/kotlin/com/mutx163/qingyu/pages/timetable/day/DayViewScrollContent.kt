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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
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
    /** 冲突课程卡面透明度（设置 `timetableConflictCourseOpacity`，默认 0.70）。见 [DayViewCourseCard]。 */
    conflictCourseOpacity: Float = 0.70f,
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
     * 无壁纸 / 亮度还没采到时，卡实际压着的**页底**亮度（`DayViewPage` 算好后下传）。
     * 课程 / 日程 / 考试卡在半透明档据此合成判墨；null = 保持旧的「按不透明卡色」回退。
     */
    pageBackgroundLuminance: Double? = null,
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
        // top = 0：14dp 留缝改成列表首个 item（`day-top-seam`，2026-11-07），
        // 不用 contentPadding —— stickyHeader 的钉住位是 `-beforeContentPadding`
        //（foundation `LazyLayoutStickyItems`），padding 会把吸顶卡算到视口上方。
        top = 0.dp,
        bottom = bottomInset,
    ),
) {
    // ── 短日补白：让「一节课 / 没课」这种不足一屏的日子也有纵向响应（2026-11-08）──
    // 纵向可滚范围 = 内容高 − 视口高。内容比视口矮的那几天范围是 0，上下滑一动不动
    // （用户报的「日视图有时候上下滑完全没反应」）；只高一点的那几天范围几十 dp，
    // 一次上滑就见底 ⇒「只能下滑，下滑回来又能上滑」。
    //
    // 这里在列表末尾挂一条 `day-scroll-tail` 空白，把**可滚范围的下限**抬到视口的
    // [DayViewScrollTail.MIN_RANGE_FRACTION]：短日滑得动、每天手感一致；内容本来就
    // 更长的日子算式给 0，等于没有这一项，行为一点没变。
    var viewportHeightPx by remember { mutableIntStateOf(0) }
    var tailHeightPx by remember(lazyListState) { mutableIntStateOf(0) }
    val density = LocalDensity.current
    val bottomPaddingPx = with(density) { contentPadding.calculateBottomPadding().toPx() }

    LaunchedEffect(lazyListState, viewportHeightPx, bottomPaddingPx) {
        if (viewportHeightPx <= 0) {
            tailHeightPx = 0
            return@LaunchedEffect
        }
        snapshotFlow {
            val info = lazyListState.layoutInfo
            val lastReal = info.visibleItemsInfo.lastOrNull { it.key != DayViewScrollTail.KEY }
            DayViewScrollTail.naturalContentPx(
                // 顶部判据读**状态**：布局信息里没有「第一个可见项的下标」这一项。
                firstVisibleItemIndex = lazyListState.firstVisibleItemIndex,
                totalItemsCount = info.totalItemsCount,
                lastRealVisibleIndex = lastReal?.index,
                lastRealVisibleBottomPx = lastReal?.let { it.offset + it.size } ?: 0,
            )
        }.collect { naturalPx ->
            // null = 这一刻读不到可信的内容高度（滚到中途 / 内容超一屏）：
            // **保持上一次的补白**，撤掉会让滚动位置被夹回去、页面跳一下。
            if (naturalPx != null) {
                tailHeightPx = DayViewScrollTail.tailHeightPx(
                    viewportHeightPx = viewportHeightPx,
                    // 真实内容 + 底部避让：避让本来就占可滚范围。
                    contentHeightPx = naturalPx + bottomPaddingPx.toInt(),
                )
            }
        }
    }

    LazyColumn(
        state = lazyListState,
        modifier = modifier
            .fillMaxSize()
            .onSizeChanged { viewportHeightPx = it.height }
            .scrollEndHaptic()
            .overScrollVertical(),
        contentPadding = contentPadding,
        ) {
        // ── 顶部留缝（14dp，与 Dart `timetable_day_view_part.dart:37` 同数值）──
        // 放在**列表里**而不是滚动区外面：静止时首卡离星期栏 14dp；上滑时这道缝
        // 跟着滚走，摘要卡吸顶后紧贴星期栏底边——屏幕上不再有一条永远滚不走的空带
        //（2026-11-07 用户口径：「吸顶卡不要贴住星期栏，但上滑时也不要留空隙」）。
        item(key = "day-top-seam") {
            Spacer(modifier = Modifier.height(DAY_VIEW_TOP_SEAM_DP.dp))
        }

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
                            conflictCourseOpacity = conflictCourseOpacity,
                            material = material,
                            glassBackdrop = glassBackdrop,
                            wallpaperLuminance = wallpaperLuminance,
                            pageBackgroundLuminance = pageBackgroundLuminance,
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
                            pageBackgroundLuminance = pageBackgroundLuminance,
                        )
                    }

                    is DayAgendaEntry.ExamEntry -> {
                        DayViewExamCard(
                            entry = entry,
                            onTap = onOpenExam?.let { open -> { open(entry.exam.id) } },
                            material = material,
                            glassBackdrop = glassBackdrop,
                            wallpaperLuminance = wallpaperLuminance,
                            pageBackgroundLuminance = pageBackgroundLuminance,
                        )
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }
        }

        // ── 短日补白（长度见函数上方说明）：长日算出来是 0，等价于没有这一项。──
        // 常驻是刻意的：高度为 0 时它也在树里，`totalItemsCount − 2` 这条「真实末项」
        // 的算法才恒定，不会因为补白忽隐忽现而漂。
        item(key = DayViewScrollTail.KEY) {
            Spacer(modifier = Modifier.height(with(LocalDensity.current) { tailHeightPx.toDp() }))
        }
    }
}

/**
 * 顶部留缝（14dp，Dart `timetable_day_view_part.dart:37` 同数值）。
 *
 * 做成**列表首个 item** 而不是滚动区外的 Spacer：静止时首卡离星期栏 14dp，
 * 上滑时这道缝跟着滚走，摘要卡吸顶后紧贴星期栏底边，不会留一条滚不走的空带。
 */
private const val DAY_VIEW_TOP_SEAM_DP = 14f
