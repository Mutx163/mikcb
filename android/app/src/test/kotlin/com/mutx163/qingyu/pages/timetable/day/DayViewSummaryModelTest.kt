package com.mutx163.qingyu.pages.timetable.day

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 顶部概览卡状态模型与文案装配单元测试。
 */
class DayViewSummaryModelTest {

    @Test
    fun `主计数胶囊遵循课程日程作业四级降级规则`() {
        // 1. 有课时优先显示门数
        assertEquals("3 门课", DayViewSummaryLogic.resolveCountLabel(courseCount = 3, scheduleCount = 2, taskCount = 5))

        // 2. 无课有日程时显示日程数（ARB: "日程 {count} 项"）
        assertEquals("日程 2 项", DayViewSummaryLogic.resolveCountLabel(courseCount = 0, scheduleCount = 2, taskCount = 5))

        // 3. 无课无日程但有未完成作业时显示作业数（救助有作业没课的日子，ARB: "作业 {count} 项"）
        assertEquals("作业 4 项", DayViewSummaryLogic.resolveCountLabel(courseCount = 0, scheduleCount = 0, taskCount = 4))

        // 4. 全空时兜底为 0 门课
        assertEquals("0 门课", DayViewSummaryLogic.resolveCountLabel(courseCount = 0, scheduleCount = 0, taskCount = 0))
    }

    @Test
    fun `副日程胶囊仅在既有课又有日程时显示`() {
        assertEquals("日程 2 项", DayViewSummaryLogic.resolveScheduleLabel(courseCount = 3, scheduleCount = 2))
        assertNull(DayViewSummaryLogic.resolveScheduleLabel(courseCount = 0, scheduleCount = 2))
        assertNull(DayViewSummaryLogic.resolveScheduleLabel(courseCount = 3, scheduleCount = 0))
    }

    @Test
    fun `议程起止时间区间格式化`() {
        assertEquals("08:00 开始 · 20:30 结束", DayViewSummaryLogic.resolveAgendaRangeLabel("08:00", "20:30"))
        assertNull(DayViewSummaryLogic.resolveAgendaRangeLabel(null, "20:30"))
        assertNull(DayViewSummaryLogic.resolveAgendaRangeLabel("08:00", null))
        assertNull(DayViewSummaryLogic.resolveAgendaRangeLabel("", ""))
    }

    @Test
    fun `状态小胶囊列表正确生成`() {
        val exams = listOf(
            DayExamSummary(id = "e1", name = "线性代数", daysUntil = 0),
            DayExamSummary(id = "e2", name = "大学英语", daysUntil = 5),
        )

        val chips = DayViewSummaryLogic.buildStatusChips(
            currentCourseName = "高等数学",
            conflictCount = 2,
            nonCurrentWeekCourseCount = 1,
            exams = exams,
        )

        assertEquals(5, chips.size)
        assertEquals(SummaryChip(SummaryChipKind.ONGOING_COURSE, "正在上课 · 高等数学"), chips[0])
        assertEquals(SummaryChip(SummaryChipKind.CONFLICT, "冲突 2 节"), chips[1])
        assertEquals(SummaryChip(SummaryChipKind.NON_CURRENT_WEEK, "非本周 1 门课"), chips[2])
        assertEquals(SummaryChip(SummaryChipKind.EXAM, "线性代数 · 今天"), chips[3])
        assertEquals(SummaryChip(SummaryChipKind.EXAM, "大学英语 · 5 天后"), chips[4])
    }

    @Test
    fun `整卡状态完整装配`() {
        val state = DayViewSummaryLogic.buildSummaryState(
            week = 4,
            dateLabel = "10月27日 周二",
            isToday = true,
            courseCount = 3,
            scheduleCount = 1,
            taskCount = 2,
            currentCourseName = "大学物理",
            firstStartTime = "08:00",
            lastEndTime = "17:30",
        )

        assertEquals(4, state.week)
        assertEquals("10月27日 周二", state.dateLabel)
        assertTrue(state.isToday)
        assertEquals("3 门课", state.countLabel)
        assertEquals("日程 1 项", state.scheduleLabel)
        assertEquals("08:00 开始 · 17:30 结束", state.agendaRangeLabel)
        assertEquals(1, state.statusChips.size)
        assertEquals("正在上课 · 大学物理", state.statusChips[0].text)
        assertTrue(state.hasAgenda)
    }
}
