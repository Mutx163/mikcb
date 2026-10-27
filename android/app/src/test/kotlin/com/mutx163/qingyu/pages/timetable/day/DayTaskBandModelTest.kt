package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.CourseTask
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 待办带分档、逾期折叠与完成态过滤单元测试。
 */
class DayTaskBandModelTest {

    private val targetDate = LocalDateTime.of(2026, 10, 27, 12, 0)

    @Test
    fun `逾期超过3条时正确折叠并保留隐藏计数`() {
        val tasks = listOf(
            createTask("t1", "逾期作业1", dueDate = targetDate.minusDays(5)),
            createTask("t2", "逾期作业2", dueDate = targetDate.minusDays(4)),
            createTask("t3", "逾期作业3", dueDate = targetDate.minusDays(3)),
            createTask("t4", "逾期作业4", dueDate = targetDate.minusDays(2)),
            createTask("t5", "逾期作业5", dueDate = targetDate.minusDays(1)),
        )

        val band = DayTaskBandLogic.resolve(tasks, targetDate)

        // 最多显示 3 条，其余 2 条折叠
        assertEquals(3, band.overdue.size)
        assertEquals(2, band.hiddenOverdueCount)
        assertEquals(3, band.visibleCount)
        // 行动项为可视逾期 + 今日未完成 (3 + 0 = 3)
        assertEquals(3, band.actionableCount)
        assertEquals(5, band.overdue.size + band.hiddenOverdueCount)
        assertFalse(band.isEmpty)
        assertTrue(band.isNotEmpty)

        // 折叠保留的是欠得最久的 3 条（按到期日升序）：t1, t2, t3
        assertEquals(listOf("t1", "t2", "t3"), band.overdue.map { it.task.id })
        assertEquals(5, band.overdue[0].overdueDays)
        assertEquals(4, band.overdue[1].overdueDays)
        assertEquals(3, band.overdue[2].overdueDays)
    }

    @Test
    fun `完成态过滤：仅保留目标日当天完成的任务，历史完成任务不污染今日`() {
        val tasks = listOf(
            // 今天到期且已完成 -> 保留（支持当天查看交了什么与撤销）
            createTask("t_done_today", "今日已交作业", dueDate = targetDate, isCompleted = true),
            // 昨天到期且已完成 -> 过滤掉（不属于今天）
            createTask("t_done_yesterday", "昨天已交作业", dueDate = targetDate.minusDays(1), isCompleted = true),
            // 3天前到期且已完成 -> 过滤掉
            createTask("t_done_old", "上周已交作业", dueDate = targetDate.minusDays(3), isCompleted = true),
            // 今天到期未完成 -> 今日档
            createTask("t_today", "今日待办作业", dueDate = targetDate, isCompleted = false),
        )

        val band = DayTaskBandLogic.resolve(tasks, targetDate)

        assertEquals(0, band.overdue.size)
        assertEquals(1, band.today.size)
        assertEquals("t_today", band.today.first().task.id)

        // 仅保留了当天完成的一条
        assertEquals(1, band.completed.size)
        assertEquals("t_done_today", band.completed.first().task.id)

        // 行动项计数仅计算未完成的：1 条
        assertEquals(1, band.actionableCount)
        // 可视总行数：today + completed = 2 条
        assertEquals(2, band.visibleCount)
    }

    @Test
    fun `未设置截止日期与未来日期的任务不进入当日待办带`() {
        val tasks = listOf(
            // 无截止日期：日视图不显示（只在任务清单全部里）
            createTask("t_undated", "随手记待办", dueDate = null),
            // 未来到期：当前日期不显示
            createTask("t_future", "明天要交作业", dueDate = targetDate.plusDays(1)),
        )

        val band = DayTaskBandLogic.resolve(tasks, targetDate)

        assertTrue(band.isEmpty)
        assertEquals(0, band.visibleCount)
        assertEquals(0, band.actionableCount)
    }

    @Test
    fun `同档内排序：有关联课程优先于无关联任务`() {
        val tasks = listOf(
            createTask("t_no_course", "无课作业", dueDate = targetDate, courseId = null),
            createTask("t_with_course", "算法作业", dueDate = targetDate, courseId = "c_algo"),
        )

        val band = DayTaskBandLogic.resolve(tasks, targetDate)

        assertEquals(2, band.today.size)
        // 有关联课程的优先排在前面
        assertEquals("t_with_course", band.today[0].task.id)
        assertEquals("t_no_course", band.today[1].task.id)
    }

    @Test
    fun `空标题默认兜底为课程作业`() {
        val blankTask = createTask("t_blank", "   ", dueDate = targetDate)
        val normalTask = createTask("t_normal", "阅读课文", dueDate = targetDate)

        assertTrue(DayTaskBandLogic.needsDefaultTitle(blankTask))
        assertFalse(DayTaskBandLogic.needsDefaultTitle(normalTask))

        assertEquals("课程作业", DayTaskBandLogic.resolveDisplayTitle(blankTask))
        assertEquals("阅读课文", DayTaskBandLogic.resolveDisplayTitle(normalTask))
    }

    private fun createTask(
        id: String,
        title: String,
        dueDate: LocalDateTime?,
        courseId: String? = null,
        isCompleted: Boolean = false,
        createdAt: LocalDateTime = LocalDateTime.of(2026, 10, 20, 10, 0),
    ): CourseTask {
        return CourseTask(
            id = id,
            title = title,
            dueDate = dueDate,
            courseId = courseId,
            isCompleted = isCompleted,
            createdAt = createdAt,
            updatedAt = createdAt,
        )
    }
}
