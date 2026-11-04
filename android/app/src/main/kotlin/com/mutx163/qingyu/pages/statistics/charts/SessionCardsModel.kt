package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.core.CourseSession
import com.mutx163.qingyu.core.CourseSessionPhase
import com.mutx163.qingyu.core.CourseSessionStats

/** 单节课汇总卡的一格（课次 / 已过 / 课时 / 有备注）。 */
data class SessionMetric(
    val value: String,
    val label: String,
    /** 首格用主题色强调（Dart 只给第一格 `highlight: true`）。 */
    val highlight: Boolean,
)

/** 课次状态对应的语义色。 */
enum class SessionTone { GREEN, PRIMARY, BLUE, ORANGE, PURPLE, SECONDARY }

/** 课次列表的一行。 */
data class SessionRowModel(
    /** `9月16日 · 周三` 或 `第 5 周 · 周三`（没设开学日期时按周次列出）。 */
    val title: String,
    /** `第 1～2 节 · 08:00–09:40 · A101`（缺项自动少拼一段）。 */
    val subtitle: String,
    val phaseLabel: String,
    val tone: SessionTone,
    /** 当天有考试时的「考试」角标；没有则为 `null`。 */
    val examBadge: String?,
    /** 这次课已有的备注原文（已 trim）；没有则为 `null`。 */
    val noteText: String?,
)

/**
 * 单节课明细的模型层（汇总卡 / 列表卡）。
 *
 * 对应 Dart `session_summary_card.dart`（106 行）、`session_list_card.dart`（199 行）。
 * 数据本身来自领域层 `core/CourseSessionStats`（已移植，纯 Kotlin），这里只做
 * **展示口径**：计数、状态文案、日期/节次/时间的拼接。
 *
 * 覆盖卡（`session_coverage_card.dart`）不在这里：屏上走的是
 * `StatisticsSessionModel.coverageRows`（带「提醒数据是否可用」的真实分支），
 * 本对象曾有的 `coverage` / `SessionCoverageRow` 是无人引用的恒三行假实现，
 * 2026-11-03 按 Lead 裁决删除。
 */
object SessionCardsModel {

    // ────────── 汇总卡 ──────────

    /** 四格：课次 / 已过 / 课时 / 有备注，首格强调。 */
    fun summary(stats: CourseSessionStats): List<SessionMetric> = listOf(
        SessionMetric(
            value = stats.sessions.size.toString(),
            label = ChartsStrings.statisticsSessionMetricSessions.zh,
            highlight = true,
        ),
        SessionMetric(
            value = stats.doneSessions.toString(),
            label = ChartsStrings.statisticsSessionMetricDone.zh,
            highlight = false,
        ),
        SessionMetric(
            value = stats.doneSections.toString(),
            label = ChartsStrings.statisticsSessionMetricSections.zh,
            highlight = false,
        ),
        SessionMetric(
            value = stats.notedSessions.toString(),
            label = ChartsStrings.statisticsSessionMetricNoted.zh,
            highlight = false,
        ),
    )

    // ────────── 列表卡 ──────────

    /** 每次课一行，顺序沿用领域层排好的顺序（按日期/周次）。 */
    fun rows(stats: CourseSessionStats): List<SessionRowModel> =
        stats.sessions.map { session -> row(session, stats.hasCalendar) }

    /** 单次课 → 列表行。 */
    fun row(session: CourseSession, hasCalendar: Boolean): SessionRowModel = SessionRowModel(
        title = title(session, hasCalendar),
        subtitle = subtitle(session),
        phaseLabel = phaseLabel(session.phase),
        tone = tone(session.phase),
        examBadge = if (session.examCount > 0) ChartsStrings.examBadgeLabel.zh else null,
        noteText = if (session.hasNote) session.noteText?.trim() else null,
    )

    /**
     * 标题：有真实日期就写日期，否则退回「第 N 周」。
     *
     * 课程名不在这里重复（整页只谈一门课），标题只描述「哪一次」。
     */
    fun title(session: CourseSession, hasCalendar: Boolean): String {
        val weekday = ChartsStrings.weekdayFull(session.dayOfWeek)
        val date = session.date
        return if (date == null || !hasCalendar) {
            "${ChartsStrings.statisticsWeekSelector.filled("week", session.week.toString())} · $weekday"
        } else {
            "${SemesterProgressModel.formatMd(date.toLocalDate())} · $weekday"
        }
    }

    /**
     * 副标题：节次区间 · 钟点 · 教室，缺项自动少拼一段。
     *
     * 钟点用 en dash（`08:00–09:40`），与 Dart 的 `'$start–$end'` 一致；
     * 不要换成 ASCII 连字符，两版对照时会看出来。
     */
    fun subtitle(session: CourseSession): String {
        val parts = mutableListOf<String>()
        parts.add(
            ChartsStrings.sectionRangeLabel.filled(
                "startSection" to session.startSection.toString(),
                "endSection" to session.endSection.toString(),
            ),
        )
        val start = session.startTime
        val end = session.endTime
        if (start != null && end != null) parts.add("$start–$end")
        val location = session.location.trim()
        if (location.isNotEmpty()) parts.add(location)
        return parts.joinToString(" · ")
    }

    /** 状态文案（ARB 逐字）。 */
    fun phaseLabel(phase: CourseSessionPhase): String = when (phase) {
        CourseSessionPhase.DONE -> ChartsStrings.statisticsSessionPhaseDone.zh
        CourseSessionPhase.TODAY -> ChartsStrings.statisticsSessionPhaseToday.zh
        CourseSessionPhase.UPCOMING -> ChartsStrings.statisticsSessionPhaseUpcoming.zh
        CourseSessionPhase.SUSPENDED -> ChartsStrings.statisticsSessionPhaseSuspended.zh
        CourseSessionPhase.HOLIDAY -> ChartsStrings.statisticsSessionPhaseHoliday.zh
        CourseSessionPhase.UNDATED -> ChartsStrings.statisticsSessionPhaseUndated.zh
    }

    /** 状态角标颜色（Dart `_phaseColor`）：绿 / 主题色 / 蓝 / 橙 / 紫 / 灰。 */
    fun tone(phase: CourseSessionPhase): SessionTone = when (phase) {
        CourseSessionPhase.DONE -> SessionTone.GREEN
        CourseSessionPhase.TODAY -> SessionTone.PRIMARY
        CourseSessionPhase.UPCOMING -> SessionTone.BLUE
        CourseSessionPhase.SUSPENDED -> SessionTone.ORANGE
        CourseSessionPhase.HOLIDAY -> SessionTone.PURPLE
        CourseSessionPhase.UNDATED -> SessionTone.SECONDARY
    }

    /** 空态文案。 */
    val emptyMessage: String get() = ChartsStrings.statisticsSessionEmpty.zh
}
