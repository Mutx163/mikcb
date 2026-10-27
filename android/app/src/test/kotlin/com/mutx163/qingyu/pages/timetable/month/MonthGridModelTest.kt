package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayType
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.ScheduleRecurrence
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 月视图 42 格网格模型的领域判据（对齐 `lib/domain/month_view_logic.dart`）。
 *
 * 期望值都是照着 Dart 原件推出来的，不是从实现里抄的：
 * - 2026-10-01 是周四，含 1 号的那一周从 2026-09-28（周一）起算；
 * - 学期开学日 2026-09-07（周一），故 10-01 是第 4 周、10-08 第 5 周、10-15 第 6 周。
 */
class MonthGridModelTest {

    // ------------------------------------------------------------------
    // 夹具
    // ------------------------------------------------------------------

    private val semesterStart: LocalDateTime = DartTime.dateTime(2026, 9, 7)

    private val settings = TimetableSettings(
        semesterWeekCount = 16,
        semesterStartDate = semesterStart,
    )

    private val now: LocalDateTime = DartTime.dateTime(2026, 10, 27, 12, 0)

    private fun date(year: Int, month: Int, day: Int): LocalDateTime =
        DartTime.dateTime(year, month, day)

    private fun course(
        id: String,
        dayOfWeek: Int,
        startWeek: Int = 1,
        endWeek: Int = 16,
        color: String = "#2196F3",
        customWeeks: List<Int>? = null,
    ): Course = Course(
        id = id,
        name = "课程$id",
        teacher = "张老师",
        location = "教二201",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        color = color,
        startWeek = startWeek,
        endWeek = endWeek,
        customWeeks = customWeeks,
    )

    private fun exam(
        id: String,
        date: LocalDateTime,
        endTime: String = "23:59",
        startTime: String = "09:00",
    ): Exam = Exam(
        id = id,
        courseId = "c1",
        name = "考试$id",
        dateTime = date,
        startTime = startTime,
        endTime = endTime,
        createdAt = now,
        updatedAt = now,
    )

    private fun schedule(
        id: String,
        startDate: LocalDateTime,
        endDate: LocalDateTime,
        recurrence: ScheduleRecurrence = ScheduleRecurrence.NONE,
        exceptionDates: List<LocalDateTime> = emptyList(),
        seriesId: String? = null,
        occurrenceDate: LocalDateTime? = null,
        enabled: Boolean = true,
    ): ScheduleItem = ScheduleItem(
        id = id,
        title = "日程$id",
        startDate = startDate,
        endDate = endDate,
        startTime = "12:00",
        endTime = "13:00",
        color = "#3B82F6",
        createdAt = now,
        updatedAt = now,
        recurrence = recurrence,
        exceptionDates = exceptionDates,
        enabled = enabled,
        seriesId = seriesId,
        occurrenceDate = occurrenceDate,
    )

    private fun build(
        courses: List<Course> = emptyList(),
        exams: List<Exam> = emptyList(),
        scheduleItems: List<ScheduleItem> = emptyList(),
        holidayData: HolidayData? = null,
        semester: LocalDateTime? = semesterStart,
        year: Int = 2026,
        month: Int = 10,
        holidayOverrideEnabled: Boolean = false,
        holidayMarkingEnabled: Boolean = true,
    ): MonthGrid = MonthGridModel.build(
        semesterStart = semester,
        settings = settings,
        courses = courses,
        exams = exams,
        scheduleItems = scheduleItems,
        holidayData = holidayData,
        today = now,
        year = year,
        month = month,
        holidayOverrideEnabled = holidayOverrideEnabled,
        holidayMarkingEnabled = holidayMarkingEnabled,
    )

    // ------------------------------------------------------------------
    // 42 格骨架
    // ------------------------------------------------------------------

    @Test
    fun `固定 42 格 6 行 7 列 从含 1 号的周一算起`() {
        val grid = build()

        assertEquals(6, grid.weeks.size)
        assertEquals(42, grid.days.size)
        grid.weeks.forEach { assertEquals(7, it.days.size) }

        // 2026-10-01 是周四 → 网格首日是 2026-09-28（周一）。
        assertEquals(date(2026, 9, 28), grid.days.first().date)
        assertEquals(date(2026, 11, 8), grid.days.last().date)
        // 42 格连续不断档。
        grid.days.zipWithNext().forEach { (left, right) ->
            assertEquals(left.date.plusDays(1), right.date)
        }
    }

    @Test
    fun `前后月补位格标 isOutsideMonth 本周补位格不画色带`() {
        val grid = build()
        val outside = grid.days.filter { it.isOutsideMonth }
        // 9 月补 28/29/30 三天 + 11 月补 1..8 八天。
        assertEquals(11, outside.size)
        assertTrue(grid.days.take(3).all { it.isOutsideMonth })
        assertTrue(grid.days.last().isOutsideMonth)
        assertFalse(grid.entryFor(date(2026, 10, 1))!!.isOutsideMonth)
    }

    @Test
    fun `本月真正要画的行数按最后一天所在行算`() {
        // 2026-10：10/31 落在第 5 行 → 画 5 行（不是恒 6 行）。
        assertEquals(5, build(month = 10).rowsInMonth)
        // 2026-08：8/31（周一）落在第 6 行 → 6 行。
        assertEquals(6, build(year = 2026, month = 8).rowsInMonth)
        // 2021-02：2/1 是周一、共 28 天 → 恰好 4 行。
        assertEquals(4, build(year = 2021, month = 2).rowsInMonth)
    }

    @Test
    fun `行周次取该行首日的真实周次_同周七天一致`() {
        val grid = build()
        // 首行 09-28 起：第 4 周（09-07 开学，09-28 差 21 天 → 4）。
        assertEquals(4L, grid.weeks[0].weekIndex)
        assertEquals(5L, grid.weeks[1].weekIndex)
        grid.weeks.forEach { week ->
            assertTrue(week.days.all { it.weekIndex == week.weekIndex })
        }
    }

    // ------------------------------------------------------------------
    // 课程计数（最容易迁错的一条）
    // ------------------------------------------------------------------

    @Test
    fun `课程只数当天真实发生的 不按周网格的淡化扩展`() {
        val thursday = course("t", dayOfWeek = 4)
        val grid = build(courses = listOf(thursday))

        // 10 月的周四：1 / 8 / 15 / 22 / 29。
        val thursdays = listOf(1, 8, 15, 22, 29)
        for (day in thursdays) {
            assertEquals("10-$day 应有 1 门课", 1, grid.entryFor(date(2026, 10, day))!!.courseCount)
        }
        // 10-02（周五）没有被任何课占格——这是「淡化扩展」会算错的典型日子。
        assertEquals(0, grid.entryFor(date(2026, 10, 2))!!.courseCount)
        assertEquals(0, grid.entryFor(date(2026, 10, 6))!!.courseCount)
    }

    @Test
    fun `课程按 isInWeek 判周次_未到 startWeek 不算`() {
        val late = course("late", dayOfWeek = 4, startWeek = 6)
        val grid = build(courses = listOf(late))

        assertEquals(0, grid.entryFor(date(2026, 10, 1))!!.courseCount) // 第 4 周
        assertEquals(0, grid.entryFor(date(2026, 10, 8))!!.courseCount) // 第 5 周
        assertEquals(1, grid.entryFor(date(2026, 10, 15))!!.courseCount) // 第 6 周
    }

    @Test
    fun `customWeeks 课程只认列出的周`() {
        val custom = course("cw", dayOfWeek = 4, customWeeks = listOf(4))
        val grid = build(courses = listOf(custom))

        assertEquals(1, grid.entryFor(date(2026, 10, 1))!!.courseCount)
        assertEquals(0, grid.entryFor(date(2026, 10, 8))!!.courseCount)
    }

    @Test
    fun `课程色带去重保序且最多 3 个`() {
        val courses = listOf(
            course("a", 4, color = " #E5484D "),
            course("b", 4, color = "#E5484D"),
            course("c", 4, color = ""),
            course("d", 4, color = "#3B82F6"),
            course("e", 4, color = "#22C55E"),
        )
        val entry = build(courses = courses).entryFor(date(2026, 10, 1))!!
        assertEquals(5, entry.courseCount)
        // 去空白、去重、保序、封顶 3。
        assertEquals(listOf("#E5484D", "#3B82F6", "#22C55E"), entry.courseColorHexes)
    }

    @Test
    fun `学期未配置时周次为 null 课程一律不计`() {
        val grid = build(courses = listOf(course("t", 4)), semester = null)
        val entry = grid.entryFor(date(2026, 10, 1))!!

        assertNull(entry.weekIndex)
        assertFalse(entry.weekInSemester)
        assertEquals(0, entry.courseCount)
        assertTrue(grid.weeks.all { it.weekIndex == null })
    }

    @Test
    fun `周次不按学期周数钳制_超学期只由 weekInSemester 标记`() {
        // 开学 2026-09-07 + semesterWeekCount=16：11-09 是第 10 周（学期内）；
        // 用一份 8 周的设置把它挤到学期外仍然要保留真实周次。
        val shortSettings = TimetableSettings(semesterWeekCount = 8, semesterStartDate = semesterStart)
        val grid = MonthGridModel.build(
            semesterStart = semesterStart,
            settings = shortSettings,
            courses = emptyList(),
            exams = emptyList(),
            scheduleItems = emptyList(),
            holidayData = null,
            today = now,
            year = 2026,
            month = 11,
        )
        val entry = grid.entryFor(date(2026, 11, 9))!!
        assertEquals(10L, entry.weekIndex) // 真实周次 10，没被钳到 8
        assertFalse(entry.weekInSemester) // 但已不在学期内
    }

    // ------------------------------------------------------------------
    // 考试 / 日程
    // ------------------------------------------------------------------

    @Test
    fun `考试只数未过期的_过期口径含 endTime 缺省 2359`() {
        val expiredToday = exam("a", date(2026, 10, 27), endTime = "09:00")
        val stillRunning = exam("b", date(2026, 10, 27), endTime = "18:00")
        val later = exam("c", date(2026, 10, 28), endTime = "10:00")

        val grid = build(exams = listOf(expiredToday, stillRunning, later))
        // now = 10-27 12:00：09:00 结束的那场已过期。
        assertEquals(1, grid.entryFor(date(2026, 10, 27))!!.examCount)
        assertEquals(1, grid.entryFor(date(2026, 10, 28))!!.examCount)
        assertEquals(0, grid.entryFor(date(2026, 10, 26))!!.examCount)
    }

    @Test
    fun `考试按开始钟点升序`() {
        val late = exam("late", date(2026, 10, 20), startTime = "14:00")
        val early = exam("early", date(2026, 10, 20), startTime = "08:30")
        // 站在当天上午看：两场都还没过期（now 是 10-27，直接拿它会把两场都判过期）。
        val morning = DartTime.dateTime(2026, 10, 20, 6, 0)
        val sorted = MonthGridModel.examsOnDate(listOf(late, early), date(2026, 10, 20), morning)
        assertEquals(listOf("early", "late"), sorted.map { it.id })
    }

    @Test
    fun `日程重复规则与例外日期决定当天有没有实例`() {
        val weekly = schedule(
            "w",
            startDate = date(2026, 10, 1),
            endDate = date(2026, 10, 31),
            recurrence = ScheduleRecurrence.WEEKLY,
            exceptionDates = listOf(date(2026, 10, 8)),
        )
        val grid = build(scheduleItems = listOf(weekly))

        assertEquals(1, grid.entryFor(date(2026, 10, 1))!!.scheduleCount)
        assertEquals(0, grid.entryFor(date(2026, 10, 8))!!.scheduleCount) // 例外
        assertEquals(1, grid.entryFor(date(2026, 10, 15))!!.scheduleCount)
        assertEquals(0, grid.entryFor(date(2026, 10, 2))!!.scheduleCount) // 非周四
    }

    @Test
    fun `暂停的日程仍计入_与日视图同口径`() {
        val paused = schedule(
            "p",
            startDate = date(2026, 10, 5),
            endDate = date(2026, 10, 5),
            enabled = false,
        )
        assertEquals(1, build(scheduleItems = listOf(paused)).entryFor(date(2026, 10, 5))!!.scheduleCount)
    }

    @Test
    fun `系列例外覆盖同日原实例_两条例外撞日各留一份`() {
        val root = schedule(
            "root",
            startDate = date(2026, 10, 1),
            endDate = date(2026, 10, 31),
            recurrence = ScheduleRecurrence.WEEKLY,
        )
        // 把 10-01 那次改到 10-08（原 10-08 系列实例被覆盖实例顶掉）。
        val moveOne = schedule(
            "move1",
            startDate = date(2026, 10, 8),
            endDate = date(2026, 10, 8),
            seriesId = "root",
            occurrenceDate = date(2026, 10, 1),
        )
        val instances = MonthGridModel.scheduleInstancesOnDate(
            listOf(root, moveOne),
            date(2026, 10, 8),
        )
        assertEquals(1, instances.size)
        assertTrue(instances.single().isSeriesOverride)
        assertEquals("root@2026-10-01", instances.single().occurrenceId)

        // 再把 10-15 那次也改到 10-08：两条例外都在，不能被去重吃掉。
        val moveTwo = schedule(
            "move2",
            startDate = date(2026, 10, 8),
            endDate = date(2026, 10, 8),
            seriesId = "root",
            occurrenceDate = date(2026, 10, 15),
        )
        val both = MonthGridModel.scheduleInstancesOnDate(
            listOf(root, moveOne, moveTwo),
            date(2026, 10, 8),
        )
        assertEquals(2, both.size)
        assertEquals(
            setOf("root@2026-10-01", "root@2026-10-15"),
            both.map { it.occurrenceId }.toSet(),
        )
    }

    // ------------------------------------------------------------------
    // 假期 / 调休 / 今天
    // ------------------------------------------------------------------

    @Test
    fun `假期与调休上班日分别标记`() {
        val holidayData = HolidayData(
            year = 2026,
            version = 1,
            entries = listOf(
                HolidayEntry(date(2026, 10, 1), "国庆节", HolidayType.Vacation),
                HolidayEntry(date(2026, 10, 10), "调休上班", HolidayType.AdjustedWorkday),
            ),
        )
        val grid = build(holidayData = holidayData)
        val nationalDay = grid.entryFor(date(2026, 10, 1))!!
        assertTrue(nationalDay.isHoliday)
        assertFalse(nationalDay.isAdjustedWorkday)

        val workday = grid.entryFor(date(2026, 10, 10))!!
        assertFalse(workday.isHoliday) // 调休上班优先
        assertTrue(workday.isAdjustedWorkday)

        assertFalse(grid.entryFor(date(2026, 10, 2))!!.isHoliday)
    }

    @Test
    fun `假期覆盖开关与标记开关都折算进 isHoliday`() {
        val holidayData = HolidayData(
            year = 2026,
            version = 1,
            entries = listOf(HolidayEntry(date(2026, 10, 1), "国庆节", HolidayType.Vacation)),
        )
        // 覆盖开关打开：所有日子都按假期算。
        val overrideGrid = build(holidayData = holidayData, holidayOverrideEnabled = true)
        assertTrue(overrideGrid.entryFor(date(2026, 10, 2))!!.isHoliday)

        // 标记关闭：假期不显示。
        val markingOff = build(holidayData = holidayData, holidayMarkingEnabled = false)
        assertFalse(markingOff.entryFor(date(2026, 10, 1))!!.isHoliday)
    }

    @Test
    fun `isOutsideMonth 的补位格有课也不进 busyDays`() {
        // 2026-09-30 是补位格；给它排一门周三的课。
        val wednesday = course("w", dayOfWeek = 3)
        val grid = build(courses = listOf(wednesday))

        val outsideWithCourse = grid.entryFor(date(2026, 9, 30))!!
        assertTrue(outsideWithCourse.isOutsideMonth)
        assertEquals(1, outsideWithCourse.courseCount)
        assertTrue(grid.busyDays.none { it.isOutsideMonth })
    }

    @Test
    fun `busyDays 只收本月有内容的日子并按日期升序`() {
        val courses = listOf(course("t", dayOfWeek = 4))
        // 考试排在今天之后：10-20 已经过期（now = 10-27），不会进 busyDays。
        val exams = listOf(exam("e", date(2026, 10, 28)))
        val schedules = listOf(
            schedule("s", startDate = date(2026, 10, 11), endDate = date(2026, 10, 11)),
        )
        val grid = build(courses = courses, exams = exams, scheduleItems = schedules)

        val expected = listOf(1, 8, 11, 15, 22, 28, 29).map { date(2026, 10, it) }
        assertEquals(expected, grid.busyDays.map { it.date })
        assertEquals(expected.size, grid.busyDayCount)
        assertTrue(grid.busyDays.all { it.hasContent })
        // 严格升序。
        grid.busyDays.zipWithNext().forEach { (left, right) ->
            assertTrue(right.date.isAfter(left.date))
        }
    }

    @Test
    fun `hasContent 只数数量 三种来源任一算有内容`() {
        val onlyExam = MonthDayEntry(
            date = date(2026, 10, 1), weekIndex = null, weekInSemester = false,
            courseCount = 0, courseColorHexes = emptyList(), examCount = 1,
            scheduleCount = 0, isHoliday = false, isAdjustedWorkday = false,
            isOutsideMonth = false,
        )
        assertTrue(onlyExam.hasContent)
        assertFalse(onlyExam.copy(examCount = 0).hasContent)
        assertTrue(onlyExam.copy(examCount = 0, scheduleCount = 1).hasContent)
    }

    @Test
    fun `entryFor 接受带时分秒的日期并按日历日匹配`() {
        val grid = build(courses = listOf(course("t", 4)))
        val entry = grid.entryFor(DartTime.dateTime(2026, 10, 1, 23, 30))
        assertNotNull(entry)
        assertEquals(date(2026, 10, 1), entry!!.date)
        assertNull(grid.entryFor(date(2026, 12, 25)))
    }

    @Test
    fun `月份越界按日历顺延_13 月等于次年 1 月`() {
        val dates = MonthGridModel.monthGridDates(2026, 13)
        assertEquals(date(2026, 12, 28), dates.first())
        assertTrue(dates.all { it.year == 2026 || it.year == 2027 })
        assertEquals(date(2027, 2, 7), dates.last())
    }
}
