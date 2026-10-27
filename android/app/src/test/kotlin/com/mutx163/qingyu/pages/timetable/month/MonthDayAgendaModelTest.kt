package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.ScheduleRecurrence
import com.mutx163.qingyu.core.SectionTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 当日议程行的组装：课程 / 考试 / 日程混排、钟点排序、空态。
 *
 * ## 夹具口径（人推的期望值）
 *
 * 学期开学日 = **2026-09-07（周一）**，被查的那天 = **2026-10-27（周二）**。
 * 从 9/7 那个周一起算，10/26 是第 8 周，所以 10/27 属于**第 8 周**。
 * 任何「这门课该不该出现」的期望值都按这两条算，不是从实现里抄的。
 */
class MonthDayAgendaModelTest {

    private val semesterStart: LocalDateTime = LocalDateTime.of(2026, 9, 7, 0, 0)
    private val targetDate: LocalDateTime = LocalDateTime.of(2026, 10, 27, 0, 0)
    private val now: LocalDateTime = LocalDateTime.of(2026, 10, 27, 7, 30)

    /** 三节作息：第 1 节 08:00、第 2 节 09:00、第 3 节 10:00。 */
    private val sections = listOf(
        SectionTime("08:00", "08:45"),
        SectionTime("09:00", "09:45"),
        SectionTime("10:00", "10:45"),
    )

    // ------------------------------------------------------------------
    // 节次 → 钟点
    // ------------------------------------------------------------------

    @Test
    fun `节次映射到作息表起始钟点`() {
        assertEquals("08:00", MonthDayAgendaModel.sectionStartClock(sections, 1))
        assertEquals("09:00", MonthDayAgendaModel.sectionStartClock(sections, 2))
        assertEquals("10:00", MonthDayAgendaModel.sectionStartClock(sections, 3))
        // 越界 / 0 / 负数 / 空作息：一律 null（渲染层画占位），**不猜**课程自己的
        // startTime —— 那是另一套口径，混用会让同一天在不同页显示不同钟点。
        assertNull(MonthDayAgendaModel.sectionStartClock(sections, 4))
        assertNull(MonthDayAgendaModel.sectionStartClock(sections, 0))
        assertNull(MonthDayAgendaModel.sectionStartClock(sections, -1))
        assertNull(MonthDayAgendaModel.sectionStartClock(emptyList(), 1))
        // 作息表里那一节的起始时间缺失：也返回 null。
        assertNull(
            MonthDayAgendaModel.sectionStartClock(listOf(SectionTime("  ", "08:45")), 1),
        )
    }

    // ------------------------------------------------------------------
    // 课程 / 考试 / 日程的入列判据
    // ------------------------------------------------------------------

    @Test
    fun `当天真实发生的课才入列`() {
        val courses = listOf(
            // 周二、第 8 周在 1..16 内 → 出现。
            course(id = "c_ok", dayOfWeek = 2, startWeek = 1, endWeek = 16),
            // 周三 → 不是这天的课。
            course(id = "c_wrong_day", dayOfWeek = 3, startWeek = 1, endWeek = 16),
            // 周二但只排到第 5 周 → 第 8 周没课。
            course(id = "c_expired_week", dayOfWeek = 2, startWeek = 1, endWeek = 5),
            // 周二、自定义周次里含第 8 周 → 出现（自定义周次优先于区间）。
            course(id = "c_custom", dayOfWeek = 2, startWeek = 1, endWeek = 2, customWeeks = listOf(8)),
        )

        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = courses,
            exams = emptyList(),
            scheduleItems = emptyList(),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        )
        assertEquals(listOf("c_ok", "c_custom"), rows.map { it.id })
        assertTrue(rows.all { it.kind == MonthAgendaKind.COURSE })
    }

    @Test
    fun `学期未配置时没有任何课`() {
        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = listOf(course(id = "c1", dayOfWeek = 2)),
            exams = emptyList(),
            scheduleItems = emptyList(),
            semesterStart = null,
            sections = sections,
            now = now,
        )
        assertTrue(rows.isEmpty())
        assertTrue(MonthDayAgendaModel.isEmpty(rows))
    }

    @Test
    fun `已过期的考试不入列`() {
        val exams = listOf(
            // 今天 09:00-10:30，此刻 07:30 还没考 → 入列。
            exam(id = "e_future", dateTime = LocalDateTime.of(2026, 10, 27, 0, 0), start = "09:00", end = "10:30"),
            // 今天 06:00-07:00，此刻 07:30 已经考完 → 不入列。
            exam(id = "e_passed", dateTime = LocalDateTime.of(2026, 10, 27, 0, 0), start = "06:00", end = "07:00"),
            // 明天 → 不入列。
            exam(id = "e_other_day", dateTime = LocalDateTime.of(2026, 10, 28, 0, 0), start = "09:00", end = "10:30"),
        )

        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = emptyList(),
            exams = exams,
            scheduleItems = emptyList(),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        )
        assertEquals(listOf("e_future"), rows.map { it.id })
        val row = rows.single()
        assertEquals(MonthAgendaKind.EXAM, row.kind)
        assertEquals("09:00", row.clockText)
        // 考试没有自己的颜色：渲染层固定用考试红。
        assertNull(row.colorHex)
        assertNotNull(row.exam)
    }

    @Test
    fun `日程实例入列_跨天与重复都按 occursOn 判`() {
        val items = listOf(
            // 一次性日程，正是今天 → 入列。
            schedule(id = "s_today", date = targetDate),
            // 一次性日程，昨天 → 不入列。
            schedule(id = "s_yesterday", date = targetDate.minusDays(1)),
            // 每周重复：9/1 起的周二，10/27 是周二且区间内 → 入列。
            schedule(
                id = "s_weekly",
                date = LocalDateTime.of(2026, 9, 1, 0, 0),
                endDate = LocalDateTime.of(2026, 12, 1, 0, 0),
                recurrence = ScheduleRecurrence.WEEKLY,
            ),
        )

        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = emptyList(),
            exams = emptyList(),
            scheduleItems = items,
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        )
        // 重复日程的身份是**这一次发生的 occurrenceId**（`系列根@显示日`），不是
        // 源条目 id —— 同一条每周日程在一个月里会出现四、五次，用源 id 当 key
        // 会让列表里只剩一条（`LazyColumn` 的 key 也会撞）。
        assertEquals(listOf("s_today", "s_weekly@2026-10-27"), rows.map { it.id })
        assertTrue(rows.all { it.kind == MonthAgendaKind.SCHEDULE })
    }

    @Test
    fun `停用的日程仍然列出（与日视图同口径）`() {
        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = emptyList(),
            exams = emptyList(),
            scheduleItems = listOf(schedule(id = "s_off", date = targetDate, enabled = false)),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        )
        // 日视图不过滤 enabled，月视图必须一致：两边不同会出现「日视图有、月视图没有」。
        assertEquals(listOf("s_off"), rows.map { it.id })
    }

    // ------------------------------------------------------------------
    // 排序与稳定序
    // ------------------------------------------------------------------

    @Test
    fun `混排按钟点升序_课程节次映射不到则垫底`() {
        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = listOf(
                // 第 1 节 → 08:00。
                course(id = "c_first", dayOfWeek = 2, startSection = 1),
                // 第 9 节 → 作息表里没有，钟点为 null，必须垫底。
                course(id = "c_unmapped", dayOfWeek = 2, startSection = 9),
            ),
            exams = listOf(
                exam(id = "e_0900", dateTime = LocalDateTime.of(2026, 10, 27, 0, 0), start = "09:00", end = "10:30"),
            ),
            scheduleItems = listOf(
                // 07:00 最早的日程。
                schedule(id = "s_0700", date = targetDate, start = "07:00", end = "08:00"),
            ),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        )

        assertEquals(
            listOf("s_0700", "c_first", "e_0900", "c_unmapped"),
            rows.map { it.id },
        )
        assertNull(rows.last().clockText)
    }

    @Test
    fun `同一钟点保持注入序_课在考试前`() {
        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = listOf(
                course(id = "c_a", dayOfWeek = 2, startSection = 2), // 09:00
                course(id = "c_b", dayOfWeek = 2, startSection = 2), // 09:00
            ),
            exams = listOf(
                // 同样是 09:00 的考试：注入序在课之后，因此排在两节课后面。
                exam(id = "e_same", dateTime = LocalDateTime.of(2026, 10, 27, 0, 0), start = "09:00", end = "10:00"),
            ),
            scheduleItems = emptyList(),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        )
        assertEquals(listOf("c_a", "c_b", "e_same"), rows.map { it.id })
    }

    // ------------------------------------------------------------------
    // 展示字段与空态
    // ------------------------------------------------------------------

    @Test
    fun `副行与颜色的空值口径`() {
        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = listOf(
                // 地点为空 → 副行 null（渲染层少画一行，不留一条空白）。
                course(id = "c_blank", dayOfWeek = 2, location = "  ", color = "  "),
            ),
            exams = listOf(
                exam(
                    id = "e_no_loc",
                    dateTime = LocalDateTime.of(2026, 10, 27, 0, 0),
                    start = "09:00",
                    end = "10:30",
                    location = null,
                ),
            ),
            scheduleItems = emptyList(),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        )

        val courseRow = rows.first { it.id == "c_blank" }
        assertNull(courseRow.subtitle)
        assertNull(courseRow.colorHex)
        assertNull(rows.first { it.id == "e_no_loc" }.subtitle)

        // 有地点 / 有颜色的照原样透传（渲染层用课程色画行首竖条）。
        val filled = MonthDayAgendaModel.build(
            date = targetDate,
            courses = listOf(course(id = "c_full", dayOfWeek = 2, location = "教一 101", color = "#2196F3")),
            exams = emptyList(),
            scheduleItems = emptyList(),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        ).single()
        assertEquals("教一 101", filled.subtitle)
        assertEquals("#2196F3", filled.colorHex)
    }

    @Test
    fun `日程的色与地点取自源条目_身份取 occurrenceId`() {
        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = emptyList(),
            exams = emptyList(),
            scheduleItems = listOf(
                schedule(id = "s1", date = targetDate, location = "图书馆", color = "#8E44AD"),
            ),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        ).single()

        assertEquals("s1", rows.id)
        assertEquals("图书馆", rows.subtitle)
        assertEquals("#8E44AD", rows.colorHex)
        assertNotNull(rows.schedule)
        assertEquals(targetDate, rows.schedule?.date)
    }

    @Test
    fun `什么都没排的那天判成空态`() {
        val rows = MonthDayAgendaModel.build(
            date = targetDate,
            courses = emptyList(),
            exams = emptyList(),
            scheduleItems = emptyList(),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        )
        assertTrue(rows.isEmpty())
        assertTrue(MonthDayAgendaModel.isEmpty(rows))
        // 反向：有任意一条就**不是**空态（否则卡里会同时出现「这天没有安排」与一行课）。
        val one = MonthDayAgendaModel.build(
            date = targetDate,
            courses = listOf(course(id = "c1", dayOfWeek = 2)),
            exams = emptyList(),
            scheduleItems = emptyList(),
            semesterStart = semesterStart,
            sections = sections,
            now = now,
        )
        assertFalse(MonthDayAgendaModel.isEmpty(one))
    }

    // ------------------------------------------------------------------
    // 夹具
    // ------------------------------------------------------------------

    private fun course(
        id: String,
        dayOfWeek: Int,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        customWeeks: List<Int>? = null,
        location: String = "教一101",
        color: String = "#2196F3",
    ): Course = Course(
        id = id,
        name = "课程 $id",
        teacher = "张老师",
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        color = color,
        startWeek = startWeek,
        endWeek = endWeek,
        customWeeks = customWeeks,
    )

    private fun exam(
        id: String,
        dateTime: LocalDateTime,
        start: String,
        end: String,
        location: String? = "教二 202",
    ): Exam = Exam(
        id = id,
        courseId = "c1",
        name = "考试 $id",
        dateTime = dateTime,
        startTime = start,
        endTime = end,
        location = location,
        createdAt = now,
        updatedAt = now,
    )

    private fun schedule(
        id: String,
        date: LocalDateTime,
        endDate: LocalDateTime = date,
        start: String = "07:00",
        end: String = "08:00",
        recurrence: ScheduleRecurrence = ScheduleRecurrence.NONE,
        location: String? = null,
        color: String = "#5B9CF6",
        enabled: Boolean = true,
    ): ScheduleItem = ScheduleItem(
        id = id,
        title = "日程 $id",
        location = location,
        startDate = date,
        endDate = endDate,
        startTime = start,
        endTime = end,
        color = color,
        createdAt = now,
        updatedAt = now,
        recurrence = recurrence,
        enabled = enabled,
    )
}
