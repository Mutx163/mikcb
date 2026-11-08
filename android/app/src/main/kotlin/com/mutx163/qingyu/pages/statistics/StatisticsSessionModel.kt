package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.CourseSession
import com.mutx163.qingyu.core.CourseSessionPhase
import com.mutx163.qingyu.core.CourseSessionStats
import com.mutx163.qingyu.pages.statistics.charts.ChartsStrings
import com.mutx163.qingyu.pages.statistics.charts.SessionCardsModel
import com.mutx163.qingyu.pages.statistics.charts.SessionTone

/**
 * 单节课明细页（`lib/screens/statistics_session_screen.dart`，147 行）模型层。
 *
 * ## 这一页在做什么
 *
 * 选一门课，把它在学期里「哪几次上过、每次留下什么记录」摊开。数据全部从已有记录
 * 推导（课程周次 + 备注 + 作业 + 提醒 + 考试），**不新增录入入口**。
 *
 * ## 算数不在这里
 *
 * 课次展开与聚合由 Phase 2 已迁好的 `com.mutx163.qingyu.core.CourseSessionStatsCalculator`
 * 负责（对应 Dart `lib/domain/course_session_stats.dart`）。本类只做屏层的事：
 *
 * 1. **选中项收敛**：Dart `_resolveSelection`——上次选中的课被删了要回落到第一门；
 * 2. **四格汇总**：课次 / 已过 / 课时 / 有备注（`session_summary_card.dart`）；
 * 3. **覆盖三行**：有备注 / 有作业 / 设过提醒（`session_coverage_card.dart`），
 *    分子分母同口径（分母 = 全部课次，含停课与假期），因此不会出现超过 100%；
 * 4. **课次阶段标签**：六种 phase → ARB 文案（`session_list_card.dart:167-172`）。
 *
 * ## 一个容易抄错的地方
 *
 * 覆盖行的分母是 `stats.sessions.size` 而**不是** `plannedSessions`。Dart 侧注释写得很清楚：
 * 停课周不清备注，「停课周有备注」真实存在，分母用 plannedSessions 能构造出「3/1」
 * 的自相矛盾。这里照抄全部课次口径，并在单测里钉住这条。
 */
object StatisticsSessionModel {

    /**
     * 选中项收敛（Dart `_resolveSelection`，`statistics_session_screen.dart:130-136`）。
     *
     * 规则：上次选中的名字还在 → 用它；否则回落第一门。
     * `names` 为空时返回 null（调用方应先走空态，不该走到这里）。
     */
    fun resolveSelection(names: List<String>, previous: String?): String? {
        if (names.isEmpty()) return null
        return if (previous != null && names.contains(previous)) previous else names.first()
    }

    /** 页面标题。 */
    val title: String get() = StatisticsExtStrings.statisticsSessionTitle.text

    /** 「课程」选择行标签（Dart `HyperosSelectTile<String>(label: statisticsSessionCourseLabel)`）。 */
    val courseLabel: String get() = StatisticsExtStrings.statisticsSessionCourseLabel.text

    /** 没设开学日期时的提示（Dart：`if (!stats.hasCalendar)` 才显示）。 */
    fun noCalendarHint(hasCalendar: Boolean): String? =
        if (hasCalendar) null else StatisticsExtStrings.statisticsSessionNoCalendarHint.text

    /** 四格汇总里的一格。首格（课次）用主题色强调，见 `session_summary_card.dart`。 */
    data class SummaryMetric(val value: String, val label: String, val highlight: Boolean = false)

    /**
     * 四格汇总（Dart `SessionSummaryCard`：课次 / 已过 / 课时 / 有备注）。
     *
     * 空列表返回空集合——Dart 侧 `if (stats.isEmpty) return SizedBox.shrink()`，
     * 渲染层据此不画这张卡。
     */
    fun summaryMetrics(stats: CourseSessionStats): List<SummaryMetric> {
        if (stats.isEmpty) return emptyList()
        return listOf(
            SummaryMetric(
                stats.sessions.size.toString(),
                StatisticsExtStrings.statisticsSessionMetricSessions.text,
                highlight = true,
            ),
            SummaryMetric(
                stats.doneSessions.toString(),
                StatisticsExtStrings.statisticsSessionMetricDone.text,
            ),
            SummaryMetric(
                stats.doneSections.toString(),
                StatisticsExtStrings.statisticsSessionMetricSections.text,
            ),
            SummaryMetric(
                stats.notedSessions.toString(),
                StatisticsExtStrings.statisticsSessionMetricNoted.text,
            ),
        )
    }

    /**
     * 覆盖三行里的一行。
     *
     * @param ratio 0.0~1.0，供渲染层画进度条。分母为 0 时给 0.0（Dart 同口径：
     *   `total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0)`）。
     */
    data class CoverageRow(
        val label: String,
        val count: Int,
        val total: Int,
        val ratio: Float,
        val valueText: String,
    )

    /**
     * 记录覆盖行（Dart `SessionCoverageCard`：有备注 / 有作业 / 设过提醒）。
     *
     * 分母固定为**全部课次**（含停课与假期），见类注释里那条「3/1」的坑。
     *
     * @param reminderDataAvailable 「单节课提醒」这份数据到底拿不拿得到。
     *   数据源在 `core/TimetableSettings.classReminders`（2026-11-02 已接），
     *   [StatisticsFeed] 恒传真键集 ⇒ 这里恒为 true；参数保留只为让「拿不到数据」
     *   的调用方（如将来某个离线快照）显式隐藏第三行，而不是画一个恒 0 的假读数。
     */
    fun coverageRows(
        stats: CourseSessionStats,
        reminderDataAvailable: Boolean = true,
    ): List<CoverageRow> {
        val total = stats.sessions.size
        val rows = mutableListOf(
            coverageRow(StatisticsExtStrings.statisticsSessionCoverageNote.text, stats.notedSessions, total),
            coverageRow(StatisticsExtStrings.statisticsSessionCoverageHomework.text, stats.homeworkSessions, total),
        )
        if (reminderDataAvailable) {
            rows += coverageRow(
                StatisticsExtStrings.statisticsSessionCoverageReminder.text,
                stats.reminderSessions,
                total,
            )
        }
        return rows
    }

    private fun coverageRow(label: String, count: Int, total: Int): CoverageRow {
        val ratio = if (total <= 0) 0f else (count.toFloat() / total).coerceIn(0f, 1f)
        return CoverageRow(
            label = label,
            count = count,
            total = total,
            ratio = ratio,
            // Dart `session_coverage_card.dart:100` 是 `'$count / $total'`（斜杠两侧有空格）。
            // 上一版漏了空格，屏上是 `3/4` 而 Dart 是 `3 / 4`；两版逐字对照时会当成文案错。
            valueText = "$count / $total",
        )
    }

    /** 覆盖卡空态文案（Dart `if (total == 0) Text(statisticsSessionEmpty)`）。 */
    val coverageEmptyText: String get() = StatisticsExtStrings.statisticsSessionEmpty.text

    /** 课次阶段标签（Dart `session_list_card.dart:167-172` 的 switch）。 */
    fun phaseLabel(phase: CourseSessionPhase): String = when (phase) {
        CourseSessionPhase.DONE -> StatisticsExtStrings.statisticsSessionPhaseDone.text
        CourseSessionPhase.TODAY -> StatisticsExtStrings.statisticsSessionPhaseToday.text
        CourseSessionPhase.UPCOMING -> StatisticsExtStrings.statisticsSessionPhaseUpcoming.text
        CourseSessionPhase.SUSPENDED -> StatisticsExtStrings.statisticsSessionPhaseSuspended.text
        CourseSessionPhase.HOLIDAY -> StatisticsExtStrings.statisticsSessionPhaseHoliday.text
        CourseSessionPhase.UNDATED -> StatisticsExtStrings.statisticsSessionPhaseUndated.text
    }

    /**
     * 课次列表的一行视图模型。
     *
     * 照抄 Dart `session_list_card.dart` 的 `_SessionRow`：
     * - `title`：哪一次——`dateText`（调用方已拼好「9月16日 · 周X」），没有日期轴时
     *   回落「第 N 周 · 周X」；
     * - `subtitle`：节次区间 + 钟点 + 教室（Dart `_subtitle`，缺项跳过）；
     * - `examBadge`：当天有考试时的角标（Dart `if (session.examCount > 0)`）；
     * - `tone`：阶段语义色（Dart `_phaseColor`）：已过绿 / 今天主题色 /
     *   未到蓝 / 停课橙 / 假期紫 / 未定灰，与 `SessionCardsModel.tone` 同源——
     *   渲染层据此取色，初版 Composition 移植时只留了文案、把六色压成灰，
     *   真机扫读时连状态都要逐字看。
     */
    data class SessionRow(
        val title: String,
        val phaseLabel: String,
        val tone: SessionTone,
        val subtitle: String,
        val noteText: String?,
        val examBadge: String?,
    )

    fun sessionRow(session: CourseSession, dateText: String?): SessionRow {
        val resolvedDateText = dateText?.takeIf { it.isNotEmpty() }
            ?: "${StatisticsStrings.statisticsWeekSelector.filled("week" to session.week.toString())} · " +
            StatisticsStrings.weekdayFull(session.dayOfWeek)

        val parts = mutableListOf(
            ChartsStrings.sectionRangeLabel.filled(
                "startSection" to session.startSection.toString(),
                "endSection" to session.endSection.toString(),
            ),
        )
        val start = session.startTime
        val end = session.endTime
        if (start != null && end != null) parts += "$start–$end"
        val location = session.location.trim()
        if (location.isNotEmpty()) parts += location

        return SessionRow(
            title = resolvedDateText,
            phaseLabel = phaseLabel(session.phase),
            tone = SessionCardsModel.tone(session.phase),
            subtitle = parts.joinToString(" · "),
            noteText = session.noteText?.takeIf { it.trim().isNotEmpty() },
            examBadge = if (session.examCount > 0) ChartsStrings.examBadgeLabel.text else null,
        )
    }

    /** 逐课次生成列表行。 */
    fun sessionRows(stats: CourseSessionStats, dateTextOf: (CourseSession) -> String?): List<SessionRow> =
        stats.sessions.map { sessionRow(it, dateTextOf(it)) }

    /**
     * 整页视图状态：渲染层入参。
     *
     * `stats == null` 表示「一门课都没有」——Dart 侧走 `HyperosEmptyState` 空态，
     * 连课程选择行都不出现。这与「有课但没课次」是两种不同画面，所以分开表达。
     */
    data class StatisticsSessionViewState(
        val title: String,
        val courseLabel: String,
        val courseNames: List<String>,
        val selectedCourse: String?,
        val stats: CourseSessionStats?,
        val summaryMetrics: List<SummaryMetric>,
        val coverageRows: List<CoverageRow>,
        val sessionRows: List<SessionRow>,
        val noCalendarHint: String?,
        val emptyTitle: String,
        val emptySubtitle: String,
        val coverageEmptyText: String,
    ) {
        val hasCourses: Boolean get() = courseNames.isNotEmpty()
        val isEmpty: Boolean get() = !hasCourses
    }

    /**
     * 组装视图状态。
     *
     * @param statsOf 按课程名取该课的课次统计（算数在 `CourseSessionStatsCalculator`，不在这里）。
     * @param dateTextOf 把课次格式化成屏上日期文本；没有日期轴时返回 null。
     * @param reminderDataAvailable 「单节课提醒」数据是否可用（见 [coverageRows] 的说明）。
     */
    fun viewState(
        courseNames: List<String>,
        previousSelection: String?,
        statsOf: (String) -> CourseSessionStats?,
        dateTextOf: (CourseSession) -> String?,
        reminderDataAvailable: Boolean = true,
    ): StatisticsSessionViewState {
        val selected = resolveSelection(courseNames, previousSelection)
        val stats = selected?.let(statsOf)
        return StatisticsSessionViewState(
            title = title,
            courseLabel = courseLabel,
            courseNames = courseNames,
            selectedCourse = selected,
            stats = stats,
            summaryMetrics = stats?.let { summaryMetrics(it) } ?: emptyList(),
            coverageRows = stats?.let { coverageRows(it, reminderDataAvailable) } ?: emptyList(),
            sessionRows = stats?.let { sessionRows(it, dateTextOf) } ?: emptyList(),
            noCalendarHint = stats?.let { noCalendarHint(it.hasCalendar) },
            emptyTitle = StatisticsExtStrings.statisticsNoData.text,
            emptySubtitle = StatisticsExtStrings.statisticsNoDataHint.text,
            coverageEmptyText = coverageEmptyText,
        )
    }
}
