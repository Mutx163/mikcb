package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.core.CourseSession
import com.mutx163.qingyu.core.CourseSessionPhase
import com.mutx163.qingyu.core.CourseSessionStats
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDateTime

private fun session(
    week: Int = 5,
    dayOfWeek: Int = 3,
    startSection: Int = 1,
    endSection: Int = 2,
    date: LocalDateTime? = LocalDateTime.of(2026, 9, 16, 8, 0),
    startTime: String? = "08:00",
    endTime: String? = "09:40",
    location: String = "A101",
    phase: CourseSessionPhase = CourseSessionPhase.DONE,
    noteText: String? = null,
    hasHomework: Boolean = false,
    examCount: Int = 0,
    hasReminder: Boolean = false,
) = CourseSession(
    courseId = "c1",
    week = week,
    date = date,
    dayOfWeek = dayOfWeek,
    startSection = startSection,
    endSection = endSection,
    startTime = startTime,
    endTime = endTime,
    location = location,
    phase = phase,
    noteText = noteText,
    hasHomework = hasHomework,
    taskCount = 0,
    examCount = examCount,
    hasReminder = hasReminder,
)

private fun stats(sessions: List<CourseSession>, hasCalendar: Boolean = true) = CourseSessionStats(
    courseName = "高数",
    teacher = "张老师",
    sessions = sessions,
    plannedSessions = sessions.count { it.isPlanned },
    hasCalendar = hasCalendar,
)

class SessionCardsModelTest {

    @Test
    fun `汇总四格取数口径`() {
        val data = stats(
            listOf(
                session(startSection = 1, endSection = 2, phase = CourseSessionPhase.DONE),
                // 第 3~5 节 = 3 节
                session(startSection = 3, endSection = 5, phase = CourseSessionPhase.DONE),
                session(phase = CourseSessionPhase.SUSPENDED),
                session(phase = CourseSessionPhase.UPCOMING, noteText = " 带教材 "),
            ),
        )
        val metrics = SessionCardsModel.summary(data)
        assertEquals(4, metrics.size)
        // 课次 = 全部列出的课次（含停课）
        assertEquals("4", metrics[0].value)
        assertEquals("课次", metrics[0].label)
        // 已过 = 2 次
        assertEquals("2", metrics[1].value)
        // 已上课时 = 2 + 3 = 5 节（停课与未来不算）
        assertEquals("5", metrics[2].value)
        assertEquals("课时", metrics[2].label)
        // 有备注 = 1 次
        assertEquals("1", metrics[3].value)
        assertEquals("有备注", metrics[3].label)
        // 只有首格高亮
        assertEquals(listOf(true, false, false, false), metrics.map { it.highlight })
    }

    @Test
    fun `覆盖卡分母是全部课次 不是计划课次`() {
        val data = stats(
            listOf(
                session(phase = CourseSessionPhase.DONE, noteText = "第一章"),
                session(phase = CourseSessionPhase.SUSPENDED, noteText = "停课周也记了"),
                session(phase = CourseSessionPhase.DONE, hasHomework = true),
                session(phase = CourseSessionPhase.HOLIDAY, hasReminder = true),
            ),
        )
        val rows = SessionCardsModel.coverage(data)
        assertEquals(3, rows.size)
        // 有备注 2 / 4（停课与假期都算在分母里）
        assertEquals("2 / 4", rows[0].countLabel)
        assertEquals(0.5, rows[0].fraction, 1e-9)
        // 有作业 1 / 4
        assertEquals("1 / 4", rows[1].countLabel)
        assertEquals(0.25, rows[1].fraction, 1e-9)
        // 设过提醒 1 / 4
        assertEquals("1 / 4", rows[2].countLabel)
        assertEquals(SessionTone.BLUE, rows[0].tone)
        assertEquals(SessionTone.ORANGE, rows[1].tone)
        assertEquals(SessionTone.PURPLE, rows[2].tone)
    }

    @Test
    fun `分母为零时比例为零且不出现 NaN`() {
        val row = SessionCardsModel.coverageRow("有备注", 0, 0, SessionTone.BLUE)
        assertEquals("0 / 0", row.countLabel)
        assertEquals(0.0, row.fraction, 1e-9)
    }

    @Test
    fun `标题 有真实日期写日期 没有就写周次`() {
        // 2026-09-16 是周三
        val withDate = session(date = LocalDateTime.of(2026, 9, 16, 8, 0), dayOfWeek = 3)
        assertEquals("9月16日 · 周三", SessionCardsModel.title(withDate, hasCalendar = true))
        // 没设开学日期：退回「第 N 周 · 周三」
        assertEquals("第 5 周 · 周三", SessionCardsModel.title(withDate, hasCalendar = false))
        // date 为 null 同样退回周次
        val noDate = session(date = null, week = 12)
        assertEquals("第 12 周 · 周三", SessionCardsModel.title(noDate, hasCalendar = true))
    }

    @Test
    fun `副标题按 节次 钟点 教室 拼接 缺项少拼`() {
        assertEquals(
            "第 1～2 节 · 08:00–09:40 · A101",
            SessionCardsModel.subtitle(session()),
        )
        // 钟点缺失：不拼钟点段
        assertEquals(
            "第 1～2 节 · A101",
            SessionCardsModel.subtitle(session(startTime = null, endTime = null)),
        )
        // 只有一端有钟点也不拼（Dart 要求两端都非空）
        assertEquals(
            "第 1～2 节 · A101",
            SessionCardsModel.subtitle(session(startTime = "08:00", endTime = null)),
        )
        // 教室空白：不拼教室段（Dart 先 trim 再判空）
        assertEquals(
            "第 1～2 节 · 08:00–09:40",
            SessionCardsModel.subtitle(session(location = "   ")),
        )
    }

    @Test
    fun `六种状态的文案与颜色`() {
        assertEquals("已过", SessionCardsModel.phaseLabel(CourseSessionPhase.DONE))
        assertEquals("今天", SessionCardsModel.phaseLabel(CourseSessionPhase.TODAY))
        assertEquals("未到", SessionCardsModel.phaseLabel(CourseSessionPhase.UPCOMING))
        assertEquals("停课", SessionCardsModel.phaseLabel(CourseSessionPhase.SUSPENDED))
        assertEquals("假期", SessionCardsModel.phaseLabel(CourseSessionPhase.HOLIDAY))
        assertEquals("日期未定", SessionCardsModel.phaseLabel(CourseSessionPhase.UNDATED))

        assertEquals(SessionTone.GREEN, SessionCardsModel.tone(CourseSessionPhase.DONE))
        assertEquals(SessionTone.PRIMARY, SessionCardsModel.tone(CourseSessionPhase.TODAY))
        assertEquals(SessionTone.BLUE, SessionCardsModel.tone(CourseSessionPhase.UPCOMING))
        assertEquals(SessionTone.ORANGE, SessionCardsModel.tone(CourseSessionPhase.SUSPENDED))
        assertEquals(SessionTone.PURPLE, SessionCardsModel.tone(CourseSessionPhase.HOLIDAY))
        assertEquals(SessionTone.SECONDARY, SessionCardsModel.tone(CourseSessionPhase.UNDATED))
    }

    @Test
    fun `行上的考试角标与备注`() {
        val row = SessionCardsModel.row(
            session(examCount = 1, noteText = "  带教材  "),
            hasCalendar = true,
        )
        assertEquals("考试", row.examBadge)
        // 备注两端空白被 trim
        assertEquals("带教材", row.noteText)

        // 没有考试 / 没有备注：两个字段都是 null（渲染层据此不占位）
        val plain = SessionCardsModel.row(session(examCount = 0, noteText = null), hasCalendar = true)
        assertNull(plain.examBadge)
        assertNull(plain.noteText)

        // 空白备注视作没有备注
        val blank = SessionCardsModel.row(session(noteText = "   "), hasCalendar = true)
        assertNull(blank.noteText)
    }

    @Test
    fun `空态文案来自 ARB`() {
        assertEquals("这门课没有排课", SessionCardsModel.emptyMessage)
        val empty = stats(emptyList())
        assertEquals(0, SessionCardsModel.rows(empty).size)
    }
}
