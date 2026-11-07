package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.ScheduleRecurrence
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.pages.timetable.TimetableDateLogic
import com.mutx163.qingyu.widgetdata.CoupleOverlay
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 日视图装配器（`DayViewDataAssembler`）的行为单测。
 *
 * 钉的是 2026-10-30/31 两轮审核里「壳拼错、页面照单全收」的那几类病：
 * 没有开学日时日程/考试/待办整块消失、作业红点按错周、非本周课不剪枝、
 * 摘要区间取法不同、天气行不接线。期望值全部从 Dart 原版逐行推出来
 *（`timetable_day_view_part.dart` / `day_course_display_logic.dart` /
 * `timetable_course_service.dart`），不是从实现里抄的。
 */
class DayViewDataAssemblerTest {

    private val today = LocalDate.of(2026, 10, 28) // 周三
    private val now = today.atTime(9, 0)

    @Test
    fun `没有开学日时按今天所在周兜底 日期与今天判定都要对`() {
        val settings = TimetableSettings(semesterWeekCount = 20, semesterStartDate = null)

        // 同一周的周三 = 今天。
        val wednesday = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = emptyList(),
            settings = settings,
            currentWeek = 3,
            now = now,
        )
        assertEquals(today, wednesday.date)
        assertTrue("同一周、同一天应当判为今天", wednesday.summaryState.isToday)

        // 同一周的周五：日期是本周五，但不算今天。
        val friday = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 5,
            courses = emptyList(),
            settings = settings,
            currentWeek = 3,
            now = now,
        )
        assertEquals(LocalDate.of(2026, 10, 30), friday.date)
        assertFalse(friday.summaryState.isToday)

        // 下一周的周三：Dart `_resolveDisplayDateForWeekDay` 在**没有开学日**时只按
        // 「星期几相对今天」推日期（`timetable_day_view_part.dart:340-355`，`week - _visibleWeek`
        // 在本页恒为 0），所以第 4 周的周三也落在「今天所在这一周」的周三；
        // 但「今天」判定只认当前周 ⇒ 不算今天。这里钉住这条口径（跨页显示同一批日程）。
        val nextWeek = DayViewDataAssembler.build(
            week = 4,
            dayOfWeek = 3,
            courses = emptyList(),
            settings = settings,
            currentWeek = 3,
            now = now,
        )
        assertEquals(today, nextWeek.date)
        assertFalse(nextWeek.summaryState.isToday)
    }

    @Test
    fun `有开学日时按学期周次算日期 只有真实当天才算今天`() {
        val start = LocalDateTime.of(2026, 9, 7, 0, 0) // 周一
        val settings = TimetableSettings(semesterWeekCount = 20, semesterStartDate = start)
        val examDay = LocalDate.of(2026, 9, 23) // 第 3 周周三
        val day = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = emptyList(),
            settings = settings,
            currentWeek = 3,
            now = examDay.atTime(9, 0),
        )
        assertEquals(examDay, day.date)
        assertTrue(day.summaryState.isToday)
    }

    @Test
    fun `作业红点按来源周取 已完成也算`() {
        val settings = TimetableSettings(semesterWeekCount = 20, semesterStartDate = null)
        val target = course(id = "c1")
        val tasks = listOf(
            task(id = "t1", courseId = "c1", sourceWeek = 3L, completed = true),
            task(id = "t2", courseId = "c1", sourceWeek = 2L, completed = false),
        )

        val currentWeek = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = listOf(target),
            settings = settings,
            currentWeek = 3,
            tasks = tasks,
            now = now,
        )
        assertEquals(
            "Dart `tasksForCourse(courseId, sourceWeek: week)` 不看完成态",
            true,
            currentWeek.courseTaskPresence["c1"],
        )

        val otherWeek = DayViewDataAssembler.build(
            week = 4,
            dayOfWeek = 3,
            courses = listOf(target),
            settings = settings,
            currentWeek = 4,
            tasks = tasks,
            now = now,
        )
        assertEquals(false, otherWeek.courseTaskPresence["c1"])
    }

    @Test
    fun `被本周课压住的非本周课不画 剪枝与周视图同口径`() {
        val settings = TimetableSettings(semesterWeekCount = 20, semesterStartDate = null)
        val current = course(id = "A", startWeek = 1, endWeek = 16)
        val nonCurrent = course(id = "B", startWeek = 5, endWeek = 10)

        val day = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = listOf(current, nonCurrent),
            settings = settings,
            currentWeek = 3,
            now = now,
            showNonCurrentWeekCourses = true,
        )

        val ids = day.agendaEntries.filterIsInstance<DayAgendaEntry.CourseEntry>().map { it.course.id }
        assertEquals(listOf("A"), ids)
    }

    @Test
    fun `日程与考试进入议程 摘要计数按真实条数`() {
        val settings = TimetableSettings(semesterWeekCount = 20, semesterStartDate = null)
        val schedule = ScheduleItem(
            id = "s1",
            title = "社团活动",
            startDate = LocalDateTime.of(2026, 10, 28, 0, 0),
            endDate = LocalDateTime.of(2026, 10, 28, 0, 0),
            startTime = "14:00",
            endTime = "15:00",
            createdAt = now,
            updatedAt = now,
            recurrence = ScheduleRecurrence.NONE,
        )
        val exam = Exam(
            id = "e1",
            courseId = "c1",
            name = "高等数学期中",
            dateTime = LocalDateTime.of(2026, 10, 28, 0, 0),
            startTime = "10:00",
            endTime = "11:30",
            createdAt = now,
            updatedAt = now,
        )

        val day = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = listOf(course(id = "c1")),
            settings = settings,
            currentWeek = 3,
            scheduleItems = listOf(schedule),
            exams = listOf(exam),
            now = now,
        )

        assertEquals(3, day.agendaEntries.size)
        assertEquals(1, day.agendaEntries.count { it is DayAgendaEntry.ScheduleEntry })
        assertEquals(1, day.agendaEntries.count { it is DayAgendaEntry.ExamEntry })
        // 排序：08:00 课程 → 10:00 考试 → 14:00 日程；重复日程的条目 id 带发生日。
        assertEquals(listOf("c1", "e1", "s1@2026-10-28"), day.agendaEntries.map { it.id })

        assertEquals("1 门课", day.summaryState.countLabel)
        assertEquals("日程 1 项", day.summaryState.scheduleLabel)
        assertEquals("08:00 开始 · 15:00 结束", day.summaryState.agendaRangeLabel)
    }

    @Test
    fun `没有开学日时待办带仍然出现`() {
        val settings = TimetableSettings(semesterWeekCount = 20, semesterStartDate = null)
        val task = task(id = "t1", courseId = "c1", sourceWeek = 3L, completed = false)

        val day = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = emptyList(),
            settings = settings,
            currentWeek = 3,
            tasks = listOf(task),
            now = now,
        )

        val band = day.taskBandData
        assertNotNull("兜底日期算得出来，待办带就不该整条消失", band)
        assertEquals(1, band!!.today.size)
        assertEquals("作业 1 项", day.summaryState.countLabel)
    }

    @Test
    fun `天气行只喂给当天课程 且没有取数器时为空`() {
        val settings = TimetableSettings(semesterWeekCount = 20, semesterStartDate = null)
        val courses = listOf(course(id = "c1"), course(id = "c2", startSection = 3, endSection = 4))

        val withWeather = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = courses,
            settings = settings,
            currentWeek = 3,
            now = now,
            weatherOf = { _, target -> if (target.id == "c1") "晴 20°C" else null },
        )
        assertEquals(mapOf("c1" to "晴 20°C"), withWeather.weatherLines)

        val withoutWeather = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = courses,
            settings = settings,
            currentWeek = 3,
            now = now,
        )
        assertTrue(withoutWeather.weatherLines.isEmpty())
    }

    @Test
    fun `摘要区间取排序后首条开始与末条结束`() {
        val settings = TimetableSettings(semesterWeekCount = 20, semesterStartDate = null)
        val courses = listOf(
            course(id = "early", startSection = 1, endSection = 6, startTime = "08:00", endTime = "12:00"),
            course(id = "late", startSection = 7, endSection = 7, startTime = "14:00", endTime = "14:45"),
        )

        val day = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = courses,
            settings = settings,
            currentWeek = 3,
            now = now,
        )
        assertEquals("08:00 开始 · 14:45 结束", day.summaryState.agendaRangeLabel)
        assertNull("没有考试时不应有考试胶囊", day.summaryState.statusChips
            .firstOrNull { it.kind == SummaryChipKind.EXAM })
    }

    @Test
    fun `考试结束钟点缺失时按 23-59 过期 与 Dart Exam-isExpired 同口径`() {
        // Dart `lib/models/exam.dart:309-324`：`endTime` 解析不出时回落到 23:59，
        // 即「当天 23:59 之前都算未过期」。此前这里回落到「跨日才算过期」，
        // 23:59:30 仍把考试列在首页，与 Dart 差一分钟。
        val exam = Exam(
            id = "e-empty-end",
            courseId = "c-none",
            name = "晚课小测",
            dateTime = LocalDateTime.of(2026, 10, 28, 0, 0),
            startTime = "20:00",
            endTime = "",
            createdAt = now,
            updatedAt = now,
        )
        assertFalse(
            "23:58:59 还没过 23:59 的边界，不该判过期",
            DayViewDataAssembler.isExamExpired(exam, LocalDateTime.of(2026, 10, 28, 23, 58, 59)),
        )
        assertTrue(
            "23:59 之后即过期（Dart 回落 23:59，不是跨日才过期）",
            DayViewDataAssembler.isExamExpired(exam, LocalDateTime.of(2026, 10, 28, 23, 59, 30)),
        )
        assertTrue(
            "次日 00:00:30 已过 23:59，应判过期",
            DayViewDataAssembler.isExamExpired(exam, LocalDateTime.of(2026, 10, 29, 0, 0, 30)),
        )

        // 装配层同判据：过期当天考试不进议程。
        val day = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = emptyList(),
            settings = TimetableSettings(semesterWeekCount = 20, semesterStartDate = null),
            currentWeek = 3,
            exams = listOf(exam),
            now = LocalDateTime.of(2026, 10, 28, 23, 59, 30),
        )
        assertEquals(0, day.agendaEntries.count { it is DayAgendaEntry.ExamEntry })
    }

    @Test
    fun `考试结束钟点写 24-00 时同样按 Dart 口径处理`() {
        val exam = Exam(
            id = "e-midnight-end",
            courseId = "c-none",
            name = "跨零点考试",
            dateTime = LocalDateTime.of(2026, 10, 28, 0, 0),
            startTime = "23:00",
            endTime = "24:00",
            createdAt = now,
            updatedAt = now,
        )
        assertFalse(
            "24:00 应解析成当天 23:59 前后仍在进行，不该在 23:30 判过期",
            DayViewDataAssembler.isExamExpired(exam, LocalDateTime.of(2026, 10, 28, 23, 30)),
        )
        assertTrue(
            DayViewDataAssembler.isExamExpired(exam, LocalDateTime.of(2026, 10, 29, 0, 0, 1)),
        )
    }

    @Test
    fun `同一次取钟 跨零点一瞬周次与今天判定不错位`() {
        val semesterStart = LocalDate.of(2026, 9, 1)
        val settings = TimetableSettings(
            semesterWeekCount = 20,
            semesterStartDate = semesterStart.atStartOfDay(),
        )
        // 23:59:59 这一瞬取钟：壳里 `realCurrentWeek` 与装配器必须共用同一个 now。
        val now = LocalDateTime.of(2026, 10, 28, 23, 59, 59)
        val week = requireNotNull(
            TimetableDateLogic.currentSemesterWeek(
                semesterStart = semesterStart,
                totalWeeks = 20,
                today = now.toLocalDate(),
            ),
        )
        val sameClock = DayViewDataAssembler.build(
            week = week,
            dayOfWeek = now.dayOfWeek.value,
            courses = emptyList(),
            settings = settings,
            currentWeek = week,
            now = now,
        )
        assertTrue("同一次取钟：这一页仍是今天", sameClock.isToday)

        // 壳里旧写法（周次用 LocalDate.now()、装配器再取一次 now）在跨零点一瞬会拆成两半：
        // 周次还是昨天所在周，装配器已按次日判「今天」——同一页被判成昨天。
        val splitClock = DayViewDataAssembler.build(
            week = week,
            dayOfWeek = now.dayOfWeek.value,
            courses = emptyList(),
            settings = settings,
            currentWeek = week,
            now = now.plusSeconds(1),
        )
        assertFalse("拆钟后同一页被判成昨天，这正是单次取钟要消除的错位", splitClock.isToday)
    }

    // ── 情侣课表叠加（B1 第一阶段 · 2026-11-06）────────────────────────
    //
    // 判据：partnerOverlay != null 时当天课程走合并内核（`coupleMergedDayCoursesTagged`），
    // TA 课追加且 `isPartnerCourse=true`（`DayViewCourseCard:231` 的「TA的课」徽标自动亮）；
    // null = 完全现行为。Dart 对照 `buildCoupleDayCourseDisplayItems`
    //（`day_course_display_logic.dart:464-476`）：TA 课不吃「非本周开关」，由合并内核按
    // 周偏移映射后的周次过滤；同行程（同名 + 节次重叠）按我的那份去重。

    @Test
    fun `不传叠加时行为不变 TA徽标不出现`() {
        val day = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = listOf(course("m1")),
            settings = TimetableSettings(semesterWeekCount = 20),
            currentWeek = 3,
            now = now,
        )
        val entries = day.agendaEntries.filterIsInstance<DayAgendaEntry.CourseEntry>()
        assertEquals(listOf("m1"), entries.map { it.course.id })
        assertTrue("旧路径不叠加，徽标一个都不该亮", entries.none { it.isPartnerCourse })
    }

    @Test
    fun `传叠加后TA课追加并带徽标 同行程按我的去重`() {
        val day = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = listOf(course("m1")),
            settings = TimetableSettings(semesterWeekCount = 20),
            currentWeek = 3,
            now = now,
            partnerOverlay = CoupleOverlay(
                weekOffset = 0,
                mineColorHex = "#111111",
                partnerColorHex = "#222222",
                togetherColorHex = "#333333",
                partnerCourses = listOf(
                    // 同名同天节次重叠 = 同行程：按我的那份去重，不重复出现。
                    Course(id = "p_dup", name = "课程m1", teacher = "", location = "", dayOfWeek = 3, startSection = 2, endSection = 3, startTime = "08:00", endTime = "09:40"),
                    // 独立的 TA 课：追加，徽标亮。
                    course(id = "p1", dayOfWeek = 3, startSection = 5),
                ),
            ),
        )
        val entries = day.agendaEntries.filterIsInstance<DayAgendaEntry.CourseEntry>()
        assertEquals("同行程去重后 = 我的 1 门 + TA 独立 1 门", listOf("m1", "p1"), entries.map { it.course.id })
        val partnerEntry = entries.single { it.course.id == "p1" }
        assertTrue("TA 课必须带「TA的课」徽标", partnerEntry.isPartnerCourse)
        assertFalse("我的课不带徽标", entries.single { it.course.id == "m1" }.isPartnerCourse)
    }

    @Test
    fun `叠加时三色随绑定 我的课着色 TA课着TA色`() {
        val day = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = listOf(course("m1")),
            settings = TimetableSettings(semesterWeekCount = 20),
            currentWeek = 3,
            now = now,
            partnerOverlay = CoupleOverlay(
                weekOffset = 0,
                mineColorHex = "#111111",
                partnerColorHex = "#222222",
                togetherColorHex = "#333333",
                partnerCourses = listOf(course(id = "p1", dayOfWeek = 3, startSection = 5)),
            ),
        )
        val entries = day.agendaEntries.filterIsInstance<DayAgendaEntry.CourseEntry>()
        assertEquals("#111111", entries.first { it.course.id == "m1" }.course.color)
        assertEquals("#222222", entries.first { it.course.id == "p1" }.course.color)
    }

    @Test
    fun `叠加的TA课按周偏移映射过滤 本周无效的TA课不出现`() {
        // TA 课只在 TA 的第 5 周（= 我的第 3 周 + 偏移 2）有效；偏移 2 时我的第 3 周
        // 应该看到它；偏移 0 时 TA 的第 3 周它没课，不该出现。
        fun build(offset: Int) = DayViewDataAssembler.build(
            week = 3,
            dayOfWeek = 3,
            courses = listOf(course("m1")),
            settings = TimetableSettings(semesterWeekCount = 20),
            currentWeek = 3,
            now = now,
            partnerOverlay = CoupleOverlay(
                weekOffset = offset,
                mineColorHex = "#111111",
                partnerColorHex = "#222222",
                togetherColorHex = "#333333",
                partnerCourses = listOf(
                    course(id = "p_far", dayOfWeek = 3, startSection = 5, startWeek = 5, endWeek = 5),
                ),
            ),
        )
        assertTrue(
            "偏移 2：TA 的第 5 周正好有课",
            build(offset = 2).agendaEntries.filterIsInstance<DayAgendaEntry.CourseEntry>()
                .any { it.course.id == "p_far" && it.isPartnerCourse },
        )
        assertTrue(
            "偏移 0：TA 的第 3 周没课，不该出现",
            build(offset = 0).agendaEntries.filterIsInstance<DayAgendaEntry.CourseEntry>()
                .none { it.course.id == "p_far" },
        )
    }

    // ------------------------------------------------------------------ 夹具

    private fun course(
        id: String,
        dayOfWeek: Int = 3,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        startTime: String = "08:00",
        endTime: String = "09:40",
    ) = Course(
        id = id,
        name = "课程$id",
        teacher = "张老师",
        location = "教二201",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
        startWeek = startWeek,
        endWeek = endWeek,
    )

    private fun task(
        id: String,
        courseId: String?,
        sourceWeek: Long?,
        completed: Boolean,
    ) = CourseTask(
        id = id,
        title = "作业$id",
        courseId = courseId,
        sourceWeek = sourceWeek,
        dueDate = LocalDateTime.of(2026, 10, 28, 0, 0),
        isCompleted = completed,
        createdAt = now,
        updatedAt = now,
    )
}
