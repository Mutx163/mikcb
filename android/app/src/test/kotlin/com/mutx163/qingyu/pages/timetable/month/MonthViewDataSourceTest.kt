package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayType
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.ScheduleRecurrence
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 月视图**宿主数据装配层**（[MonthViewDataSource]）的契约测试。
 *
 * ## 夹具口径（期望值是人推的，不是从实现里抄的）
 *
 * - 学期开学日 = **2026-09-07（周一）**，于是每周一都是第 N 周的第一天：
 *   09-07 = 第 1 周、09-28 = 第 4 周、10-26 = 第 8 周、12-28 = 第 17 周、
 *   2027-01-25 = 第 21 周。
 * - **2026-10-01 是周四**（含 1 号的那一周的周一是 09-28），所以 10 月的 42 格是
 *   `09-28 … 11-08`：前 3 格 + 本月 31 格 + 后 8 格 = 42，`rowsInMonth = 5`
 *   （10-31 是周六，落在第 5 行）。
 * - **2027-01-01 是周五**，所以 1 月的 42 格是 `2026-12-28 … 2027-02-07`：
 *   前 4 格（跨年补位）+ 本月 31 格 + 后 7 格 = 42，`rowsInMonth = 5`。
 * - **2026-12-01 是周二**，12 月的 42 格是 `2026-11-30 … 2027-01-10`（跨年）。
 * - **2026-10-10 是周六**（国庆调休上班日），属第 5 周。
 *
 * ⚠️ 全部用**固定日期**，不出现「今天」：否则明天就老化翻红。
 */
class MonthViewDataSourceTest {

    private val semesterStart: LocalDateTime = LocalDateTime.of(2026, 9, 7, 0, 0)

    /** 基准「此刻」：2026-10-27（周二）上午 08:00，第 8 周。 */
    private val now: LocalDateTime = LocalDateTime.of(2026, 10, 27, 8, 0)

    private val threeSections = listOf(
        SectionTime("08:00", "08:45"),
        SectionTime("09:00", "09:45"),
        SectionTime("10:00", "10:45"),
    )

    /** 周二第 2 节、第 1~16 周：命中 2026-10-27（第 8 周）。 */
    private val tuesdayCourse = course(
        id = "c-tue",
        name = "高等数学",
        dayOfWeek = 2,
        startSection = 2,
        startWeek = 1,
        endWeek = 16,
        color = "#FF5722",
    )

    /** 同一时段但只有第 1~3 周：10-27 是第 8 周，**不该**被数进去。 */
    private val expiredTuesdayCourse = course(
        id = "c-tue-old",
        name = "旧课",
        dayOfWeek = 2,
        startSection = 2,
        startWeek = 1,
        endWeek = 3,
        color = "#000000",
    )

    /** 周六第 1 节：命中 2026-10-10（调休上班日，第 5 周）。 */
    private val saturdayCourse = course(
        id = "c-sat",
        name = "调休补课",
        dayOfWeek = 6,
        startSection = 1,
        startWeek = 1,
        endWeek = 16,
        color = "#4CAF50",
    )

    private val settings = TimetableSettings(
        sections = threeSections,
        activeTimeSchemeId = null,
        semesterWeekCount = 20,
        semesterStartDate = semesterStart,
    )

    private fun course(
        id: String,
        name: String,
        dayOfWeek: Int,
        startSection: Int,
        startWeek: Int,
        endWeek: Int,
        color: String,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "王老师",
        location = "A101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = startSection,
        startTime = "09:00",
        endTime = "09:45",
        color = color,
        startWeek = startWeek,
        endWeek = endWeek,
    )

    private fun scheme(id: String, sections: List<SectionTime>): TimeScheme = TimeScheme(
        id = id,
        name = "模板 $id",
        sections = sections,
        createdAt = LocalDateTime.of(2026, 8, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 8, 1, 0, 0),
    )

    private fun snapshot(
        courses: List<Course> = listOf(tuesdayCourse),
        settings: TimetableSettings = this.settings,
        currentWeek: Int = 8,
        semesterStartEpochDay: Long? = semesterStart.toLocalDate().toEpochDay(),
        timeSchemes: List<TimeScheme> = emptyList(),
        activeTimeSchemeId: String? = null,
    ): TimetableSnapshot = TimetableSnapshot(
        courses = courses,
        settings = settings,
        currentWeek = currentWeek,
        semesterStartEpochDay = semesterStartEpochDay,
        timeSchemes = timeSchemes,
        activeTimeSchemeId = activeTimeSchemeId,
    )

    private fun source(
        snapshot: TimetableSnapshot = snapshot(),
        now: LocalDateTime = this.now,
        exams: List<Exam> = emptyList(),
        scheduleItems: List<ScheduleItem> = emptyList(),
        holidayData: HolidayData? = null,
        holidayOverrideEnabled: Boolean = false,
        holidayMarkingEnabled: Boolean = true,
    ): MonthViewDataSource = MonthViewDataSource(
        snapshot = snapshot,
        now = now,
        exams = exams,
        scheduleItems = scheduleItems,
        holidayData = holidayData,
        holidayOverrideEnabled = holidayOverrideEnabled,
        holidayMarkingEnabled = holidayMarkingEnabled,
    )

    // ------------------------------------------------------------------
    // 开学日：天序优先，设置回落
    // ------------------------------------------------------------------

    @Test
    fun `开学日优先取快照天序而不是设置里的时刻`() {
        // 天序 = 2026-09-07，设置里写 2026-09-01：两处不一致时以天序为准。
        val conflicted = snapshot(
            settings = settings.copy(semesterStartDate = LocalDateTime.of(2026, 9, 1, 9, 30)),
        )
        assertEquals(
            LocalDateTime.of(2026, 9, 7, 0, 0),
            MonthViewDataSource.semesterStartOf(conflicted),
        )
        // 天序换算出来的必须是本地零点，不能带时分秒（否则 42 格的日期比较全错）。
        assertEquals(LocalDateTime.of(2026, 9, 7, 0, 0), source(conflicted).semesterStart)
    }

    @Test
    fun `天序缺失时回落设置里的开学日`() {
        val fallback = snapshot(
            settings = settings.copy(semesterStartDate = LocalDateTime.of(2026, 9, 7, 0, 0)),
            semesterStartEpochDay = null,
        )
        assertEquals(
            LocalDateTime.of(2026, 9, 7, 0, 0),
            MonthViewDataSource.semesterStartOf(fallback),
        )
    }

    @Test
    fun `两处都没有开学日时判为学期未配置`() {
        val unconfigured = snapshot(
            settings = settings.copy(semesterStartDate = null),
            semesterStartEpochDay = null,
        )
        assertNull(MonthViewDataSource.semesterStartOf(unconfigured))
        val data = source(unconfigured)
        assertNull(data.semesterStart)
        assertFalse("没有开学日就不该画周次列", data.hasSemester)
        // 学期未配置 → 42 格里一门课都不该出现（周次无从谈起）。
        assertEquals(0, data.grid(2026, 10).days.sumOf { it.courseCount })
    }

    // ------------------------------------------------------------------
    // 节次表：当前生效模板优先，缺失回落设置
    // ------------------------------------------------------------------

    @Test
    fun `节次表优先用当前生效的时间模板`() {
        val schemeSections = listOf(
            SectionTime("09:30", "10:15"),
            SectionTime("10:25", "11:10"),
            SectionTime("11:20", "12:05"),
        )
        val withScheme = snapshot(
            timeSchemes = listOf(scheme("s-1", schemeSections)),
            activeTimeSchemeId = "s-1",
        )
        assertEquals(schemeSections, MonthViewDataSource.sectionsOf(withScheme))
        // 议程的钟点必须跟着模板走（课程自己写的 startTime 是另一套口径，不许顶替）。
        // 课程在第 2 节 → 取模板里下标 1 的那一节。
        val rows = source(withScheme).agenda(LocalDateTime.of(2026, 10, 27, 0, 0))
        assertEquals(1, rows.size)
        assertEquals("10:25", rows[0].clockText)
    }

    @Test
    fun `快照上的模板 id 优先于设置里的模板 id`() {
        val quick = listOf(SectionTime("07:00", "07:45"))
        val configured = listOf(SectionTime("08:00", "08:45"))
        val both = snapshot(
            settings = settings.copy(activeTimeSchemeId = "s-settings"),
            timeSchemes = listOf(scheme("s-snapshot", quick), scheme("s-settings", configured)),
            activeTimeSchemeId = "s-snapshot",
        )
        assertEquals(quick, MonthViewDataSource.sectionsOf(both))
    }

    @Test
    fun `模板找不到或模板内节次为空时回落设置里的节次表`() {
        // ① 设置里有 id，但快照里没有这份模板。
        val dangling = snapshot(settings = settings.copy(activeTimeSchemeId = "s-missing"))
        assertEquals(threeSections, MonthViewDataSource.sectionsOf(dangling))
        // ② 模板存在但节次为空（用户建了模板还没填）—— 空模板不能用，否则每门课
        //    的钟点都会变成占位符。
        val emptyScheme = snapshot(
            timeSchemes = listOf(scheme("s-empty", emptyList())),
            activeTimeSchemeId = "s-empty",
        )
        assertEquals(threeSections, MonthViewDataSource.sectionsOf(emptyScheme))
    }

    @Test
    fun `没有配置任何模板时用设置里的节次表`() {
        val rows = source().agenda(LocalDateTime.of(2026, 10, 27, 0, 0))
        assertEquals("09:00", rows[0].clockText)
    }

    // ------------------------------------------------------------------
    // 跨月：2026-10 的 42 格
    // ------------------------------------------------------------------

    @Test
    fun `十月网格从前月周一补位到后月周日共42格`() {
        val grid = source().grid(2026, 10)

        assertEquals(2026, grid.year)
        assertEquals(10, grid.month)
        assertEquals(42, grid.days.size)
        // 含 10-01 的那一周的周一是 09-28；42 格一路排到 11-08。
        assertEquals(LocalDateTime.of(2026, 9, 28, 0, 0), grid.days.first().date)
        assertEquals(LocalDateTime.of(2026, 11, 8, 0, 0), grid.days.last().date)
        // 前 3 格 + 后 8 格是邻月补位。
        assertEquals(11, grid.days.count { it.isOutsideMonth })
        // 10-31 是周六，落在第 5 行 → 只画 5 行（6 行月不留空行）。
        assertEquals(5, grid.rowsInMonth)
        // 每行首日的周次：09-28 = 第 4 周，10-26 = 第 8 周。
        assertEquals(4L, grid.weeks.first().weekIndex)
        assertEquals(8L, grid.weeks[4].weekIndex)
    }

    @Test
    fun `经历的日子与真实课程数一致且邻月补位不进忙碌日`() {
        val grid = source().grid(2026, 10)

        // 2026-10-27 是周二、第 8 周：只有 c-tue 命中（c-tue-old 只到第 3 周）。
        val oct27 = grid.entryFor(LocalDateTime.of(2026, 10, 27, 0, 0))
        assertTrue(oct27 != null)
        assertEquals(1, oct27!!.courseCount)
        assertEquals(listOf("#FF5722"), oct27.courseColorHexes)
        assertTrue(oct27.weekInSemester)
        assertEquals(8L, oct27.weekIndex)

        // 09-29（周二、第 4 周）在邻月补位格里：仍然要算真实课程，但不进 busyDays。
        val sep29 = grid.entryFor(LocalDateTime.of(2026, 9, 29, 0, 0))
        assertTrue(sep29 != null)
        assertTrue(sep29!!.isOutsideMonth)
        assertEquals(1, sep29.courseCount)

        // 2026-10 的四个周二（06/13/20/27，第 5~8 周）都有课 → 四个忙碌日。
        assertEquals(4, grid.busyDayCount)
        assertFalse("忙碌日只收本月日子", grid.busyDays.any { it.isOutsideMonth })
        assertEquals(
            listOf(
                LocalDateTime.of(2026, 10, 6, 0, 0),
                LocalDateTime.of(2026, 10, 13, 0, 0),
                LocalDateTime.of(2026, 10, 20, 0, 0),
                LocalDateTime.of(2026, 10, 27, 0, 0),
            ),
            grid.busyDays.map { it.date },
        )
    }

    // ------------------------------------------------------------------
    // 跨年：2027-01（前月是 2026-12）与 2026-12（后月跨进 2027）
    // ------------------------------------------------------------------

    @Test
    fun `一月网格含去年十二月的补位格且行数不跳变`() {
        val grid = source().grid(2027, 1)

        assertEquals(2027, grid.year)
        assertEquals(1, grid.month)
        assertEquals(42, grid.days.size)
        // 2027-01-01 是周五 → 含它的那一周周一是 2026-12-28。
        assertEquals(LocalDateTime.of(2026, 12, 28, 0, 0), grid.days.first().date)
        assertEquals(LocalDateTime.of(2027, 2, 7, 0, 0), grid.days.last().date)
        // 前 4 格跨年补位 + 后 7 格。
        assertEquals(11, grid.days.count { it.isOutsideMonth })
        assertEquals(5, grid.rowsInMonth)
        assertEquals(17L, grid.weeks.first().weekIndex)
        assertEquals(21L, grid.weeks[4].weekIndex)

        // 2026-12-29 落在 2027 年 1 月网格的补位格里：周次照算（第 17 周），
        // 但不属于本月 → 没有忙碌日。
        val dec29 = grid.entryFor(LocalDateTime.of(2026, 12, 29, 0, 0))
        assertTrue(dec29 != null)
        assertTrue(dec29!!.isOutsideMonth)
        assertEquals(17L, dec29.weekIndex)
        assertEquals(0, grid.busyDayCount)
    }

    @Test
    fun `十二月网格排到次年一月`() {
        val grid = source().grid(2026, 12)

        // 2026-12-01 是周二 → 网格起点 11-30（周一），排到 2027-01-10。
        assertEquals(LocalDateTime.of(2026, 11, 30, 0, 0), grid.days.first().date)
        assertEquals(LocalDateTime.of(2027, 1, 10, 0, 0), grid.days.last().date)
        assertTrue("最后一格已是次年", grid.days.last().date.year == 2027)
        assertTrue(grid.days.last().isOutsideMonth)
        assertEquals(1, grid.days.count { it.date.year == 2026 && it.isOutsideMonth })
    }

    @Test
    fun `月份越界按日历顺延`() {
        // 13 月 = 次年 1 月（Dart DateTime(y, 13) 同口径）。
        val rolled = source().grid(2026, 13)
        assertEquals(2027, rolled.year)
        assertEquals(1, rolled.month)
        assertEquals(LocalDateTime.of(2026, 12, 28, 0, 0), rolled.days.first().date)
        // 归一之后「本月 / 邻月」仍要判对：不归一会整屏 42 格全判成邻月。
        assertEquals(11, rolled.days.count { it.isOutsideMonth })
        assertEquals(5, rolled.rowsInMonth)
        // 与直接取 2027-01 完全一致。
        assertEquals(source().grid(2027, 1), rolled)

        // 0 月 = 上一年 12 月。
        val previous = source().grid(2026, 0)
        assertEquals(2025, previous.year)
        assertEquals(12, previous.month)
        assertEquals(LocalDateTime.of(2025, 12, 1, 0, 0), previous.days.first().date)
    }

    // ------------------------------------------------------------------
    // 假期 / 调休
    // ------------------------------------------------------------------

    private val holidays2026 = HolidayData(
        year = 2026,
        version = 1,
        entries = listOf(
            HolidayEntry(LocalDateTime.of(2026, 10, 1, 0, 0), "国庆节", HolidayType.Vacation),
            HolidayEntry(LocalDateTime.of(2026, 10, 10, 0, 0), "调休上班", HolidayType.AdjustedWorkday),
        ),
    )

    @Test
    fun `假期与调休上班日各自打标`() {
        val withSaturday = snapshot(courses = listOf(tuesdayCourse, saturdayCourse))
        val grid = source(withSaturday, holidayData = holidays2026).grid(2026, 10)

        val nationalDay = grid.entryFor(LocalDateTime.of(2026, 10, 1, 0, 0))!!
        assertTrue(nationalDay.isHoliday)
        assertFalse(nationalDay.isAdjustedWorkday)
        // 10-01 是周四，夹具里没有周四的课。
        assertEquals(0, nationalDay.courseCount)

        val makeup = grid.entryFor(LocalDateTime.of(2026, 10, 10, 0, 0))!!
        assertFalse("调休上班日不能被判成假期", makeup.isHoliday)
        assertTrue(makeup.isAdjustedWorkday)
        // 调休上班日的课照常算（那天是周六，第 5 周）。
        assertEquals(1, makeup.courseCount)

        // 普通日子两个标都不亮。
        val plain = grid.entryFor(LocalDateTime.of(2026, 10, 9, 0, 0))!!
        assertFalse(plain.isHoliday)
        assertFalse(plain.isAdjustedWorkday)
    }

    @Test
    fun `标记关闭后假期不亮但调休上班日仍亮`() {
        val withSaturday = snapshot(courses = listOf(tuesdayCourse, saturdayCourse))
        val grid = source(withSaturday, holidayData = holidays2026, holidayMarkingEnabled = false)
            .grid(2026, 10)

        assertFalse(grid.entryFor(LocalDateTime.of(2026, 10, 1, 0, 0))!!.isHoliday)
        assertTrue(grid.entryFor(LocalDateTime.of(2026, 10, 10, 0, 0))!!.isAdjustedWorkday)
    }

    @Test
    fun `覆盖模式把普通日子也判成假期`() {
        val grid = source(holidayData = holidays2026, holidayOverrideEnabled = true).grid(2026, 10)

        // 10-09 是普通周五，覆盖模式下按假期处理；调休上班日仍是例外。
        assertTrue(grid.entryFor(LocalDateTime.of(2026, 10, 9, 0, 0))!!.isHoliday)
        assertFalse(grid.entryFor(LocalDateTime.of(2026, 10, 10, 0, 0))!!.isHoliday)
    }

    @Test
    fun `没有节假日数据时不打任何假标`() {
        val grid = source(holidayData = null).grid(2026, 10)
        assertFalse(grid.days.any { it.isHoliday || it.isAdjustedWorkday })
    }

    // ------------------------------------------------------------------
    // 考试 / 日程：宿主的额外输入真的进得去
    // ------------------------------------------------------------------

    private fun exam(
        id: String,
        date: LocalDateTime,
        endTime: String,
    ): Exam = Exam(
        id = id,
        courseId = "c-tue",
        name = "期中考试",
        dateTime = date,
        startTime = "09:00",
        endTime = endTime,
        location = "B203",
        createdAt = LocalDateTime.of(2026, 9, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 0, 0),
    )

    @Test
    fun `未过期考试进网格与议程`() {
        val data = source(
            exams = listOf(exam("e-1", LocalDateTime.of(2026, 10, 28, 0, 0), "10:00")),
            now = LocalDateTime.of(2026, 10, 28, 9, 0),
        )
        assertEquals(1, data.grid(2026, 10).entryFor(LocalDateTime.of(2026, 10, 28, 0, 0))!!.examCount)
        assertEquals(
            listOf(MonthAgendaKind.EXAM),
            data.agenda(LocalDateTime.of(2026, 10, 28, 0, 0)).map { it.kind },
        )
    }

    @Test
    fun `已过结束时刻的考试连网格与议程一起消失`() {
        val data = source(
            exams = listOf(exam("e-1", LocalDateTime.of(2026, 10, 28, 0, 0), "10:00")),
            now = LocalDateTime.of(2026, 10, 28, 11, 0),
        )
        assertEquals(0, data.grid(2026, 10).entryFor(LocalDateTime.of(2026, 10, 28, 0, 0))!!.examCount)
        assertTrue(data.agenda(LocalDateTime.of(2026, 10, 28, 0, 0)).isEmpty())
    }

    @Test
    fun `一次性日程进网格与议程`() {
        val item = ScheduleItem(
            id = "s-1",
            title = "社团活动",
            location = "综合楼",
            startDate = LocalDateTime.of(2026, 10, 29, 0, 0),
            endDate = LocalDateTime.of(2026, 10, 29, 0, 0),
            startTime = "15:00",
            endTime = "16:00",
            createdAt = LocalDateTime.of(2026, 9, 1, 0, 0),
            updatedAt = LocalDateTime.of(2026, 9, 1, 0, 0),
        )
        val data = source(scheduleItems = listOf(item))
        assertEquals(1, data.grid(2026, 10).entryFor(LocalDateTime.of(2026, 10, 29, 0, 0))!!.scheduleCount)
        val rows = data.agenda(LocalDateTime.of(2026, 10, 29, 0, 0))
        assertEquals(1, rows.size)
        assertEquals(MonthAgendaKind.SCHEDULE, rows[0].kind)
        assertEquals("社团活动", rows[0].title)
    }

    // ------------------------------------------------------------------
    // 教学周次：学期内钳制，学期未配置回落快照当前周
    // ------------------------------------------------------------------

    @Test
    fun `教学周次按开学日推算并钳到学期周数`() {
        val data = source()
        assertEquals(1, data.weekForDate(LocalDateTime.of(2026, 9, 7, 0, 0)))
        assertEquals(1, data.weekForDate(LocalDateTime.of(2026, 9, 1, 0, 0))) // 开学前一律第 1 周
        assertEquals(8, data.weekForDate(LocalDateTime.of(2026, 10, 27, 0, 0)))
        // 学期周数 20：2027-06 的真实周次早已超出 → 钳到 20。
        assertEquals(20, data.weekForDate(LocalDateTime.of(2027, 6, 1, 0, 0)))
    }

    @Test
    fun `学期未配置时周次回落快照当前周`() {
        val unconfigured = snapshot(
            courses = emptyList(),
            settings = settings.copy(semesterStartDate = null),
            currentWeek = 7,
            semesterStartEpochDay = null,
        )
        assertEquals(7, source(unconfigured).weekForDate(LocalDateTime.of(2026, 10, 27, 0, 0)))
    }

    // ------------------------------------------------------------------
    // 版本戳与幂等
    // ------------------------------------------------------------------

    @Test
    fun `同一份输入重复取网格结果完全一致`() {
        val data = source()
        assertEquals(data.grid(2026, 10), data.grid(2026, 10))
    }

    @Test
    fun `课程或考试变化会换版本戳`() {
        val base = source()
        // 同样的输入重建一个 data source：版本戳必须相等，否则页面会被无谓重算。
        assertEquals(base.revision, source().revision)
        // 课程、考试、日程任一变化都要换戳（这是页面丢弃缓存的唯一依据）。
        assertNotEquals(base.revision, source(snapshot(courses = emptyList())).revision)
        assertNotEquals(
            base.revision,
            source(exams = listOf(exam("e-1", LocalDateTime.of(2026, 10, 28, 0, 0), "10:00"))).revision,
        )
        assertNotEquals(base.revision, source(scheduleItems = emptyList(), holidayData = holidays2026).revision)
    }

    @Test
    fun `此刻不进版本戳`() {
        // now 只影响考试过期判定，不该让页面在拖拽的每一帧重算 42 格。
        assertEquals(source(now = now).revision, source(now = now.plusHours(3)).revision)
    }

    @Test
    fun `日程实例按显示日去重后只算一次`() {
        val weekly = ScheduleItem(
            id = "s-weekly",
            title = "每周例会",
            startDate = LocalDateTime.of(2026, 9, 1, 0, 0),
            endDate = LocalDateTime.of(2026, 12, 31, 0, 0),
            startTime = "19:00",
            endTime = "20:00",
            createdAt = LocalDateTime.of(2026, 9, 1, 0, 0),
            updatedAt = LocalDateTime.of(2026, 9, 1, 0, 0),
            recurrence = ScheduleRecurrence.WEEKLY,
        )
        val data = source(scheduleItems = listOf(weekly))
        // 2026-10-27 是周二；weekly 的起点 2026-09-01 也是周二 → 命中。
        val entry = data.grid(2026, 10).entryFor(LocalDateTime.of(2026, 10, 27, 0, 0))!!
        assertEquals(1, entry.scheduleCount)
    }
}
