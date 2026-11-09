package com.mutx163.qingyu.pages.timetable.day

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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
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
 * - 基于 [LazyColumn] 原生高效滚动容器；列表里**没有**任何补白 / 吸附条目 ——
 *   短日内容不足一屏时可滚范围天然是 0，到边界的手感全部交给 miuix `overScrollVertical()`
 *   （和下拉走同一条路，见下方「短日不做补白」注释）；
 * - 全天概览卡是**普通条目**（2026-11-08 起不再吸顶，理由见下方卡片处的注释）；
 * - 自带 12dp 下呼吸间隙；
 * - 依次编排：
 *   1. 全天概览卡（SummaryCard）；
 *   2. 全天待办折叠带（[DayViewTaskBandCard]，若有任务）；
 *   3. 议程列表（各卡片按时间严格稳定排序）；
 *   4. 空态（[DayViewEmptyState]）：无课程且无日程且无待办时**固定在视口里居中**，
 *      不进 [`LazyColumn`]（2026-11-09 用户口径：上下滑时「暂无课程 / 第 N 周」不许跟着手走）。
 */
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
    /**
     * 天气预报「该有、但还没到」：课程卡先占住天气行的高度（不可见），到货后淡入。
     * 装配层已按「开关 + 城市 + 未失败」门控过（`DayViewDay.weatherAwaiting`）。
     */
    weatherAwaiting: Boolean = false,
    /** 「课卡显示冲突角标」开关（Dart `showConflictBadgeOnTimetable`）。 */
    showConflictBadge: Boolean = true,
    /** 冲突课程卡面透明度（设置 `timetableConflictCourseOpacity`，默认 0.70）。见 [DayViewCourseCard]。 */
    conflictCourseOpacity: Float = 0.70f,
    /** 课程卡是否按课程颜色上色（设置 `dayViewUseCourseColor`）。见 [DayViewCourseCard]。 */
    useCourseColors: Boolean = true,
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
    /**
     * 自定义**星期栏字色**（hex）与它的内置默认值（hex，用于识别「没改过 = 按亮度翻黑白」）。
     *
     * 摘要卡与空态共用这一对：Dart 两处读的是同一组设置
     * （`day_view_summary_card.dart` 与 `day_view_empty_state.dart:44-52` 都取
     * `weekdayBarFontColorLight/Dark`）。空态原先没接，于是「亮/暗两档字色」只在摘要卡上生效，
     * 空态的「暂无课程 / 第 N 周」两档永远按主题硬走（2026-11-09 用户报）。
     */
    summaryWeekdayFontColorHex: String? = null,
    summaryWeekdayFontDefaultHex: String? = null,
    /**
     * 真摘要卡的附加修饰器（首页展开态的飞行测量 + 飞行期间不画）。
     *
     * 挂**卡本身**而不是外面的条目盒子：飞行终点要的是卡片四边，
     * 盒子还含 12dp 下呼吸间距，量成盒子会让落点整体偏下 12dp。
     */
    summaryModifier: Modifier = Modifier,
    /**
     * 列表顶部要额外补的**下穿留白**（dp，= 首页顶栏玻璃带的高度）。
     *
     * 非 0 时列表视口已被宿主向上接到屏幕顶，这里补一个等高 item，第 1 张卡仍停在
     * 带子下沿；上滑时卡片才能滑进玻璃带底下（2026-11-08）。独立日页 / 预览传 0。
     */
    topUnderlap: Dp = 0.dp,
    modifier: Modifier = Modifier,
    lazyListState: LazyListState = rememberLazyListState(),
    contentPadding: PaddingValues = PaddingValues(
        start = 14.dp,
        end = 14.dp,
        // top = 0：14dp 留缝改成列表首个 item（`day-top-seam`，2026-11-07）。
        // 概览卡 2026-11-08 起不再吸顶，但留缝仍留在 item 里：空日那块「正好一屏」的
        // 定高算式按 item 高度推（视口 − 缝 − 概览卡 − 避让），改成 padding 要重推一遍。
        top = 0.dp,
        bottom = bottomInset,
    ),
) {
    val density = LocalDensity.current
    val topSeamPx = with(density) { DAY_VIEW_TOP_SEAM_DP.dp.roundToPx() }
    val topUnderlapPx = with(density) { topUnderlap.roundToPx() }
    // 概览卡的实测高（含它下面 12dp 呼吸间距）：空态固定层按它把文字推到卡片下方，
    // 静止时与「跟在概览卡后面」逐像素一致（见下方空态那一段）。
    var summaryHeightPx by remember { mutableIntStateOf(0) }
    // 空日 = 无课程、无日程、无待办：正文只剩「顶缝 + 概览卡」，空态走固定层。
    val flatDay = agendaEntries.isEmpty() && (taskBandData == null || taskBandData.isEmpty)

    // ── 短日不做补白（2026-11-08 撤掉）──
    // 这里曾经在列表末尾挂一条 `day-scroll-tail`（把可滚范围的下限抬到视口 1/5），
    // 再在松手停在补白里时 `animateScrollToItem(0)` 回顶。那条路是自研橡皮筋：
    // 上滑变成「真的把内容滚走 + 程序化滚回」，下拉却还是 miuix `overScrollVertical()`
    // 的阻尼拉伸 + 临界阻尼弹簧，两个方向两套运动模型，手感必然对不上。
    //
    // 现在的口径：**短日不补可滚余量**。内容不足一屏时列表本来就没有可滚范围，
    // 上滑与下拉落在同一个边界上，都由 `overScrollVertical()` 接管（同一段阻尼曲线、
    // 同一个弹簧、同样的速度衰减）。内容真的超过一屏时，上滑就是滚内容、到边界才拉伸，
    // 这也是正确行为。因此下面不再有「补白 / 内容高探测 / 松手回顶」的状态与副作用。

    Box(modifier = modifier.fillMaxSize()) {
        // ── 空态：**固定层**，不随列表滚动（2026-11-09）──
        if (flatDay) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(contentPadding)
                    .padding(
                        top = with(density) {
                            (topUnderlapPx + topSeamPx + summaryHeightPx).toDp()
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                DayViewEmptyState(
                    week = summaryState.week,
                    dayOfWeek = dayOfWeek,
                    wallpaperLuminance = wallpaperLuminance,
                    // 没壁纸时按页底亮度判墨：纯黑页底色 + 主题深灰字 = 看不见（2026-11-09 用户报）。
                    pageBackgroundLuminance = pageBackgroundLuminance,
                    configuredArgbHex = summaryWeekdayFontColorHex,
                    defaultInkHex = summaryWeekdayFontDefaultHex,
                )
            }
        }

        LazyColumn(
            state = lazyListState,
            // `modifier` 已经挂在外层 Box 上，这里不能再用一次（padding 之类会被算两遍）。
            modifier = Modifier
                .fillMaxSize()
                .scrollEndHaptic()
                .overScrollVertical(),
            contentPadding = contentPadding,
        ) {
            // —— 下穿留白（首页展开层）：列表视口已接到屏幕顶，这截把第 1 张卡顶回带子下沿。
            // 它必须是一个 item（不能是 contentPadding）：滑动时要跟着滚走，卡片才能真的
            // 钻进带子底下。键位固定，不因 create/destroy 改变列表位置身份。
            if (topUnderlapPx > 0) {
                item(key = "day-top-underlap") {
                    Spacer(modifier = Modifier.height(topUnderlap))
                }
            }

            // ── 顶部留缝（14dp，与 Dart `timetable_day_view_part.dart:37` 同数值）──
            // 放在**列表里**而不是滚动区外面：静止时首卡离星期栏 14dp，上滑时这道缝跟着
            // 一起滚走，屏幕上不会留一条永远滚不走的空带。
            item(key = "day-top-seam") {
                Spacer(modifier = Modifier.height(DAY_VIEW_TOP_SEAM_DP.dp))
            }

            // ── 全天概览卡（普通条目，不吸顶）──
            // 2026-11-08 用户口径：下拉时概览卡与课卡一起动，上滑却被钉住、只让下面的卡
            // 一段段穿过去——同一屏两种手势两种行为，读作「很奇怪」。改成普通条目后上下
            // 都是整体滚动，手势方向不再决定「谁在动」。
            //
            // 代价：上滑以后当天概览卡会跟着滚出屏幕（吸顶原本就是为让它常驻）。
            // 键名保留 `day-summary-sticky-header`：它是这一条的保存状态身份，改名会让
            // 已经记住的滚动位置失效。
            //
            // 12dp 的下内边距是概览卡与议程列表之间的呼吸间距。
            item(key = "day-summary-sticky-header") {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        // 量的是**含 12dp 呼吸间距**的整条（修饰符在 `padding` 之前，报的是外层尺寸），
                        // 空态块按它反推剩余高。
                        .onSizeChanged { summaryHeightPx = it.height }
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
                        // 情侣叠加时的「共同空闲」模块：数据源由首页周视图经
                        // `LocalDayViewSharedFree` 交下来（没绑定 / 没开叠加 = null ⇒ 不画）。
                        // 这一天是哪天只有这里知道，所以在这里按 (周次, 星期) 取快照。
                        sharedFree = dayOfWeek?.let { day ->
                            LocalDayViewSharedFree.current?.uiFor(
                                week = summaryState.week,
                                dayOfWeek = day,
                                isToday = summaryState.isToday,
                            )
                        },
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
                            weatherAwaiting = weatherAwaiting,
                            showConflictBadge = showConflictBadge,
                            conflictCourseOpacity = conflictCourseOpacity,
                            useCourseColor = useCourseColors,
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
    }
}

/**
 * 顶部留缝（14dp，Dart `timetable_day_view_part.dart:37` 同数值）。
 *
 * 做成**列表首个 item** 而不是滚动区外的 Spacer：静止时首卡离星期栏 14dp，
 * 上滑时这道缝跟着内容一起滚走，不会变成一条永远滚不走的空带。
 */
private const val DAY_VIEW_TOP_SEAM_DP = 14f
