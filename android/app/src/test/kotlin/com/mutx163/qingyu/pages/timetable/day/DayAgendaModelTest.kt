package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 日视图多源议程模型、时钟排序与进度量化单元测试。
 */
class DayAgendaModelTest {

    @Test
    fun `时钟文本解析为分钟数与24点放行`() {
        assertEquals(480, DayAgendaLogic.parseClockMinutes("08:00"))
        assertEquals(540, DayAgendaLogic.parseClockMinutes("9:00"))
        assertEquals(540, DayAgendaLogic.parseClockMinutes("09:00"))
        assertEquals(600, DayAgendaLogic.parseClockMinutes("10:00"))
        assertEquals(1439, DayAgendaLogic.parseClockMinutes("23:59"))

        // 作息表放行 24:00 当天结束
        assertEquals(1440, DayAgendaLogic.parseClockMinutes("24:00", allowEndOfDay = true))
        assertNull(DayAgendaLogic.parseClockMinutes("24:00", allowEndOfDay = false))

        // 越界与脏数据拒绝
        assertNull(DayAgendaLogic.parseClockMinutes("24:01"))
        assertNull(DayAgendaLogic.parseClockMinutes("25:00"))
        assertNull(DayAgendaLogic.parseClockMinutes("12:60"))
        assertNull(DayAgendaLogic.parseClockMinutes("-1:00"))
        assertNull(DayAgendaLogic.parseClockMinutes("invalid"))
        assertNull(DayAgendaLogic.parseClockMinutes(null))
        assertNull(DayAgendaLogic.parseClockMinutes(""))
    }

    @Test
    fun `钟点排序避免9点与10点在字典序下反转`() {
        // 关键用例：在普通字符串字典序中 "10:00" < "9:00"（'1' < '9'）
        assertTrue(
            "字典序自身确实存在此反常",
            "10:00".compareTo("9:00") < 0,
        )

        // compareClockText 正确按钟表分钟数比较：9:00 (540) 早于 10:00 (600)
        assertTrue(
            "9:00 必须排在 10:00 之前",
            DayAgendaLogic.compareClockText("9:00", "10:00") < 0,
        )
        assertTrue(
            "10:00 必须排在 9:00 之后",
            DayAgendaLogic.compareClockText("10:00", "9:00") > 0,
        )

        // 补零与未补零等值
        assertEquals(0, DayAgendaLogic.compareClockText("09:00", "9:00"))

        // 正常时间顺序
        assertTrue(DayAgendaLogic.compareClockText("08:30", "09:00") < 0)
        assertTrue(DayAgendaLogic.compareClockText("23:59", "24:00") < 0)

        // 脏数据排在有效数据之后
        assertTrue(DayAgendaLogic.compareClockText("08:00", "invalid") < 0)
        assertTrue(DayAgendaLogic.compareClockText("invalid", "08:00") > 0)
        assertEquals(0, DayAgendaLogic.compareClockText(null, null))
    }

    @Test
    fun `多源议程条目混合排序稳定且全序`() {
        val now = LocalDateTime.of(2026, 10, 27, 10, 0)

        val courseLate = DayAgendaEntry.CourseEntry(
            course = createCourse(id = "c_late", name = "高数", startTime = "10:00", endTime = "11:30"),
        )
        val courseEarly = DayAgendaEntry.CourseEntry(
            course = createCourse(id = "c_early", name = "英语", startTime = "9:00", endTime = "10:00"),
        )
        val scheduleSameTime = DayAgendaEntry.ScheduleEntry(
            scheduleItem = createSchedule(id = "s_early", title = "组会", startTime = "09:00", endTime = "10:00", now = now),
        )
        val examLong = DayAgendaEntry.ExamEntry(
            exam = createExam(id = "e_long", name = "期中考", startTime = "09:00", endTime = "11:00", now = now),
        )

        val entries = listOf(courseLate, examLong, scheduleSameTime, courseEarly)
        val sorted = DayAgendaLogic.sortAgendaEntries(entries)

        // 期望顺序：
        // 1. courseEarly (09:00 - 10:00, course 类型优先)
        // 2. scheduleSameTime (09:00 - 10:00, schedule 类型次之)
        // 3. examLong (09:00 - 11:00, 结束更晚排在同开始时间后面)
        // 4. courseLate (10:00 - 11:30, 开始时间晚)
        assertEquals(listOf("c_early", "s_early", "e_long", "c_late"), sorted.map { it.id })
    }

    @Test
    fun `跨天日程按起止日期正确剪裁为0点与23点59分`() {
        val startDay = LocalDateTime.of(2026, 10, 27, 0, 0)
        val endDay = LocalDateTime.of(2026, 10, 29, 0, 0)
        val schedule = createSchedule(
            id = "s_cross",
            title = "学术年会",
            startTime = "09:00",
            endTime = "17:00",
            startDate = startDay,
            endDate = endDay,
            now = startDay,
        )

        assertTrue(DayAgendaLogic.isCrossDaySchedule(schedule))

        // 第一天（2026-10-27）：原开始时间 09:00，次日续剪裁为 23:59
        val day1Entry = DayAgendaLogic.scheduleEntryForDate(schedule, targetDate = startDay)
        assertFalse(day1Entry.continuesFromPreviousDay)
        assertTrue(day1Entry.continuesToNextDay)
        assertEquals("09:00", day1Entry.startTime)
        assertEquals("23:59", day1Entry.endTime)

        // 中间天（2026-10-28）：两头续剪裁为 00:00 ~ 23:59
        val midDay = startDay.plusDays(1)
        val day2Entry = DayAgendaLogic.scheduleEntryForDate(schedule, targetDate = midDay)
        assertTrue(day2Entry.continuesFromPreviousDay)
        assertTrue(day2Entry.continuesToNextDay)
        assertEquals("00:00", day2Entry.startTime)
        assertEquals("23:59", day2Entry.endTime)

        // 最后一天（2026-10-29）：前日续 00:00，原结束时间 17:00
        val day3Entry = DayAgendaLogic.scheduleEntryForDate(schedule, targetDate = endDay)
        assertTrue(day3Entry.continuesFromPreviousDay)
        assertFalse(day3Entry.continuesToNextDay)
        assertEquals("00:00", day3Entry.startTime)
        assertEquals("17:00", day3Entry.endTime)
    }

    @Test
    fun `进行中进度计算量化档位与剩余时间精确`() {
        // 08:00 (480) ~ 10:00 (600)
        // 当前时间 09:00 (540) -> 进度正好 50%
        val progressHalf = DayAgendaLogic.resolveProgress(
            startTime = "08:00",
            endTime = "10:00",
            currentMinutes = 540.0,
        )
        assertNotNull(progressHalf)
        assertEquals(0.5, progressHalf!!.rawProgress, 0.001)
        assertEquals(0.5, progressHalf.quantizedProgress, 0.001)
        assertEquals(60, progressHalf.remainingMinutes)
        assertFalse(progressHalf.isEndingSoon)

        // 剩余 8 分钟 (09:52 -> 592 分钟)：isEndingSoon 为 true
        val progressEnding = DayAgendaLogic.resolveProgress(
            startTime = "08:00",
            endTime = "10:00",
            currentMinutes = 592.0,
        )
        assertNotNull(progressEnding)
        assertEquals(8, progressEnding!!.remainingMinutes)
        assertTrue(progressEnding.isEndingSoon)

        // 越界判定：尚未开始或已结束返回 null
        assertNull(DayAgendaLogic.resolveProgress("08:00", "10:00", currentMinutes = 479.9))
        assertNull(DayAgendaLogic.resolveProgress("08:00", "10:00", currentMinutes = 600.0))
        assertNull(DayAgendaLogic.resolveProgress("08:00", "10:00", currentMinutes = 610.0))
    }

    @Test
    fun `进度量化正确卡在0点02与0点98`() {
        // 极小值 clamp 0.02（避免胶囊绘制出现破口）
        assertEquals(0.02, DayAgendaLogic.quantizeProgress(0.001), 0.0001)
        assertEquals(0.02, DayAgendaLogic.quantizeProgress(0.0), 0.0001)

        // 极大值 clamp 0.98（避免贴死卡片右端）
        assertEquals(0.98, DayAgendaLogic.quantizeProgress(0.999), 0.0001)
        assertEquals(0.98, DayAgendaLogic.quantizeProgress(1.0), 0.0001)

        // 250 档步长测试：0.004 为一档
        val q1 = DayAgendaLogic.quantizeProgress(0.200)
        val q2 = DayAgendaLogic.quantizeProgress(0.203)
        assertEquals(q1, q2, 0.00001)
    }

    private fun createCourse(id: String, name: String, startTime: String, endTime: String): Course {
        return Course(
            id = id,
            name = name,
            teacher = "张老师",
            location = "教一101",
            dayOfWeek = 2,
            startSection = 1,
            endSection = 2,
            startWeek = 1,
            endWeek = 16,
            startTime = startTime,
            endTime = endTime,
        )
    }

    private fun createSchedule(
        id: String,
        title: String,
        startTime: String,
        endTime: String,
        startDate: LocalDateTime = LocalDateTime.of(2026, 10, 27, 0, 0),
        endDate: LocalDateTime = startDate,
        now: LocalDateTime,
    ): ScheduleItem {
        return ScheduleItem(
            id = id,
            title = title,
            startDate = startDate,
            endDate = endDate,
            startTime = startTime,
            endTime = endTime,
            createdAt = now,
            updatedAt = now,
        )
    }

    private fun createExam(
        id: String,
        name: String,
        startTime: String,
        endTime: String,
        now: LocalDateTime,
    ): Exam {
        return Exam(
            id = id,
            courseId = "c1",
            name = name,
            dateTime = now,
            startTime = startTime,
            endTime = endTime,
            createdAt = now,
            updatedAt = now,
        )
    }
}
