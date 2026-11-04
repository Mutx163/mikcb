package com.mutx163.qingyu.pages.timetable

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
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 周网格「考试 / 日程」落格逻辑单测（`WeekAgendaLogic`）。
 *
 * 期望值全部由 Dart 真源人推，**不抄 Kotlin 实现**：
 * - 钟点 → 节次映射（任一重叠即算、不重叠钳最近、并列取更早）：
 *   `lib/domain/week_grid_agenda_placement.dart:178-247`（`sectionSpanForClockRange`）；
 * - 落格组装与过滤：`:85-176`（`resolve`）；考试「当天 + 未过期」：`:106-130`；
 * - 跨天日程按 `00:00` / `23:59` 参与映射：`:132-157`；
 * - 日程不过滤 `enabled`：`:88-91` 的注释（「日视图议程也不过滤，两处必须一致」）；
 * - 排序：开始钟点 → 结束钟点 → 类型（日程 1、考试 2）→ id：`:159-174`；
 * - 过期口径：`lib/models/exam.dart:309-323`（`isExpired`，结束钟点缺省 23:59，严格 `isAfter`）。
 *
 * 全部用固定日期 + 固定 `now`，不依赖「今天」，否则明天就翻红。
 */
class WeekAgendaModelTest {

    // ------------------------------------------------------------------
    // 夹具
    // ------------------------------------------------------------------

    /** 六节的标准作息（第 1 节 08:00 起）。 */
    private fun sections(): List<SectionTime> = listOf(
        SectionTime("08:00", "08:45"), // 第 1 节
        SectionTime("08:55", "09:40"), // 第 2 节
        SectionTime("10:00", "10:45"), // 第 3 节
        SectionTime("10:55", "11:40"), // 第 4 节
        SectionTime("14:00", "14:45"), // 第 5 节
        SectionTime("14:55", "15:40"), // 第 6 节
    )

    private fun dateOf(text: String): LocalDate = LocalDate.parse(text)

    /** 夹具同时接受「2026-10-29」与「2026-10-29T12:00:00」两种写法。 */
    private fun dateTimeOf(text: String): LocalDateTime =
        if (text.length <= 10) LocalDate.parse(text).atStartOfDay() else LocalDateTime.parse(text)

    /** 2026-10-29 是周四。 */
    private val fixedNow: LocalDateTime = dateTimeOf("2026-10-29T12:00:00")

    private fun exam(
        id: String,
        dateTime: String,
        startTime: String,
        endTime: String,
        location: String? = null,
    ): Exam = Exam(
        id = id,
        courseId = "course-$id",
        name = "考试 $id",
        dateTime = dateTimeOf(dateTime),
        startTime = startTime,
        endTime = endTime,
        location = location,
        createdAt = fixedNow,
        updatedAt = fixedNow,
    )

    private fun schedule(
        id: String,
        startDate: String,
        endDate: String,
        startTime: String = "09:00",
        endTime: String = "10:00",
        recurrence: ScheduleRecurrence = ScheduleRecurrence.NONE,
        enabled: Boolean = true,
        seriesId: String? = null,
        occurrenceDate: String? = null,
    ): ScheduleItem = ScheduleItem(
        id = id,
        title = "日程 $id",
        location = "会议室",
        startDate = dateTimeOf(startDate),
        endDate = dateTimeOf(endDate),
        startTime = startTime,
        endTime = endTime,
        color = "#5B9CF6",
        createdAt = fixedNow,
        updatedAt = fixedNow,
        recurrence = recurrence,
        enabled = enabled,
        seriesId = seriesId,
        occurrenceDate = occurrenceDate?.let { dateTimeOf(it) },
    )

    // ------------------------------------------------------------------
    // 1. 钟点 → 节次映射
    // ------------------------------------------------------------------

    @Test
    fun `任一节次重叠即算，跨多节取并集`() {
        // 08:30–10:30：第 1 节(08:00-08:45)、第 2 节(08:55-09:40)、
        // 第 3 节(10:00-10:45 与 10:30 仍相交) ⇒ 第 1-3 节（Dart :226-229）。
        assertEquals(
            1..3,
            WeekAgendaLogic.sectionSpanForClockRange("08:30", "10:30", sections()),
        )
        // 08:00–15:40 覆盖整天：第 1-6 节。
        assertEquals(
            1..6,
            WeekAgendaLogic.sectionSpanForClockRange("08:00", "15:40", sections()),
        )
        // 08:40–09:00 骑在第 1、2 节之间（8:45 与 8:55 都落在区间内）⇒ 第 1-2 节。
        assertEquals(
            1..2,
            WeekAgendaLogic.sectionSpanForClockRange("08:40", "09:00", sections()),
        )
    }

    @Test
    fun `完全不重叠时钳到距离最近的节`() {
        // 19:00–20:00 在末节之后：第 6 节 15:40 结束，间隔 200 分钟；第 5 节 14:45
        // 结束，间隔 255 分钟 ⇒ 第 6 节（Dart :230-246）。
        assertEquals(
            6..6,
            WeekAgendaLogic.sectionSpanForClockRange("19:00", "20:00", sections()),
        )
        // 07:00–07:30 在第 1 节之前：距 08:00 还差 30 分钟 ⇒ 第 1 节。
        assertEquals(
            1..1,
            WeekAgendaLogic.sectionSpanForClockRange("07:00", "07:30", sections()),
        )
        // 09:45–09:55 正好落在第 2 节(…09:40)与第 3 节(10:00…)之间，两侧都差 5 分钟：
        // Dart :235 用严格 `<` 比较距离 ⇒ 并列时保留先遇到的更早那节（第 2 节）。
        assertEquals(
            2..2,
            WeekAgendaLogic.sectionSpanForClockRange("09:45", "09:55", sections()),
        )
    }

    @Test
    fun `结束早于开始按单点算`() {
        // 外来数据可能把起止反填：Dart :207-208 把 end 抬到 start，按单点映射。
        // 10:30 落在第 3 节(10:00-10:45)里 ⇒ 第 3 节单行卡。
        assertEquals(
            3..3,
            WeekAgendaLogic.sectionSpanForClockRange("10:30", "09:00", sections()),
        )
    }

    @Test
    fun `钟点不可解析、节次表为空或全坏时返回 null`() {
        // Dart :188-190 点名的三种 null：空表、钟点不可解析、表里全不可解析。
        assertNull(
            "空节次表",
            WeekAgendaLogic.sectionSpanForClockRange("08:30", "09:30", emptyList()),
        )
        assertNull(
            "脏钟点 08.30（ClockTime.tryParse 拒收）",
            WeekAgendaLogic.sectionSpanForClockRange("08.30", "09:30", sections()),
        )
        assertNull(
            "只有小时没有分钟",
            WeekAgendaLogic.sectionSpanForClockRange("8", "09:30", sections()),
        )
        assertNull(
            "空串",
            WeekAgendaLogic.sectionSpanForClockRange("", "09:30", sections()),
        )
        assertNull(
            "节次表全坏",
            WeekAgendaLogic.sectionSpanForClockRange(
                "08:30",
                "09:30",
                listOf(SectionTime("08.30", "09.30")),
            ),
        )
    }

    @Test
    fun `坏节次跳过但节次序号不变`() {
        // 第 1 条是脏节次（"08.30" 能进库，SectionTime.fromJson 只要求非空串），
        // 跳过后第 2 条仍然算「第 2 节」（Dart :221-225 的 continue 不改变 index+1）。
        val dirtyThenGood = listOf(
            SectionTime("08.30", "09.30"),
            SectionTime("10:00", "10:45"),
        )
        assertEquals(
            2..2,
            WeekAgendaLogic.sectionSpanForClockRange("10:10", "10:20", dirtyThenGood),
        )
    }

    // ------------------------------------------------------------------
    // 2. 考试过滤（固定 now）
    // ------------------------------------------------------------------

    @Test
    fun `isExamExpired 以当天结束钟点为准，相等不算过期`() {
        val exam = exam("e1", "2026-10-29T08:30", "08:30", "10:30")

        assertFalse(
            "刚好到结束时刻不算过期（Dart exam.dart:323 严格 isAfter）",
            WeekAgendaLogic.isExamExpired(exam, dateTimeOf("2026-10-29T10:30:00")),
        )
        assertTrue(
            "过了结束时刻即过期",
            WeekAgendaLogic.isExamExpired(exam, dateTimeOf("2026-10-29T10:31:00")),
        )
        assertFalse(
            "前一天不算过期",
            WeekAgendaLogic.isExamExpired(exam, dateTimeOf("2026-10-28T23:00:00")),
        )

        // 结束钟点不可解析 ⇒ 回落 23:59（Dart exam.dart:311-315 的 fallbackHour/Minute）。
        val brokenEnd = exam("e2", "2026-10-29T08:30", "08:30", "")
        assertFalse(
            WeekAgendaLogic.isExamExpired(brokenEnd, dateTimeOf("2026-10-29T23:58:00")),
        )
        assertTrue(
            WeekAgendaLogic.isExamExpired(brokenEnd, dateTimeOf("2026-10-30T00:00:00")),
        )
    }

    @Test
    fun `resolve 只收当天且未过期的考试`() {
        val entries = WeekAgendaLogic.resolve(
            date = dateOf("2026-10-29"),
            sections = sections(),
            exams = listOf(
                // 当天已结束（10:30 早于 now 12:00）⇒ 过期剔除。
                exam("expired", "2026-10-29T08:30", "08:30", "10:30"),
                // 当天下午还没开始 ⇒ 收下，落在第 5-6 节。
                exam("upcoming", "2026-10-29T14:00", "14:00", "15:30", location = "  "),
                // 次日 ⇒ 不是当天，剔除。
                exam("tomorrow", "2026-10-30T09:00", "09:00", "10:00"),
            ),
            now = fixedNow,
        )

        assertEquals(1, entries.size)
        val card = entries.single()
        assertEquals("upcoming", card.id)
        assertEquals(WeekAgendaKind.EXAM, card.kind)
        assertEquals("考试 upcoming", card.title)
        assertNull("全空白地点按无地点收下", card.location)
        assertNull("考试没有自身颜色，渲染层用主题错误红", card.colorHex)
        assertEquals(5, card.startSection)
        assertEquals(6, card.endSection)
        assertEquals("14:00", card.startTime)
        assertEquals("15:30", card.endTime)
        assertFalse(card.isCrossDay)
        assertEquals(2, card.sectionSpan)
    }

    @Test
    fun `showExams 关掉后考试不再出现`() {
        val entries = WeekAgendaLogic.resolve(
            date = dateOf("2026-10-29"),
            sections = sections(),
            exams = listOf(exam("upcoming", "2026-10-29T14:00", "14:00", "15:30")),
            now = fixedNow,
            showExams = false,
        )
        assertTrue(entries.isEmpty())

        val noSections = WeekAgendaLogic.resolve(
            date = dateOf("2026-10-29"),
            sections = emptyList(),
            exams = listOf(exam("upcoming", "2026-10-29T14:00", "14:00", "15:30")),
            now = fixedNow,
        )
        assertTrue("没有节次表就无从落格", noSections.isEmpty())
    }

    // ------------------------------------------------------------------
    // 3. 跨天日程
    // ------------------------------------------------------------------

    @Test
    fun `跨天日程按 00-00 到 23-59 占满整列`() {
        val multiDay = schedule(
            id = "camp",
            startDate = "2026-10-28",
            endDate = "2026-10-30",
            startTime = "09:00",
            endTime = "10:00",
        )
        val entries = WeekAgendaLogic.resolve(
            date = dateOf("2026-10-29"),
            sections = sections(),
            scheduleItems = listOf(multiDay),
            now = fixedNow,
            showExams = false,
        )

        val card = entries.single()
        assertEquals(WeekAgendaKind.SCHEDULE, card.kind)
        assertEquals("前日续来 ⇒ 00:00（Dart :136）", "00:00", card.startTime)
        assertEquals("续到次日 ⇒ 23:59（Dart :137）", "23:59", card.endTime)
        assertEquals("整天区间覆盖全部节次", 1, card.startSection)
        assertEquals(sections().size, card.endSection)
        assertTrue("跨天标记", card.isCrossDay)
        assertEquals("#5B9CF6", card.colorHex)
        assertEquals("会议室", card.location)
    }

    @Test
    fun `只续到次日的日程从自身开始时刻落格`() {
        // startDate == 目标日 ⇒ 不从 00:00 起；endDate 在次日 ⇒ 到 23:59 止。
        val entry = schedule(
            id = "untilTomorrow",
            startDate = "2026-10-29",
            endDate = "2026-10-31",
            startTime = "09:00",
            endTime = "10:00",
        )
        val card = WeekAgendaLogic.resolve(
            date = dateOf("2026-10-29"),
            sections = sections(),
            scheduleItems = listOf(entry),
            now = fixedNow,
            showExams = false,
        ).single()

        assertEquals("09:00", card.startTime)
        assertEquals("23:59", card.endTime)
        assertEquals("09:00 起 ⇒ 从第 2 节落格", 2, card.startSection)
        assertEquals(6, card.endSection)
        assertTrue(card.isCrossDay)
    }

    @Test
    fun `单日日程保持自身钟点且不标跨天`() {
        val single = schedule(
            id = "single",
            startDate = "2026-10-29",
            endDate = "2026-10-29",
            startTime = "09:00",
            endTime = "10:00",
        )
        val card = WeekAgendaLogic.resolve(
            date = dateOf("2026-10-29"),
            sections = sections(),
            scheduleItems = listOf(single),
            now = fixedNow,
            showExams = false,
        ).single()

        assertEquals("09:00", card.startTime)
        assertEquals("10:00", card.endTime)
        assertEquals("09:00–10:00 骑在第 2、3 节之间", 2, card.startSection)
        assertEquals(3, card.endSection)
        assertFalse(card.isCrossDay)
    }

    // ------------------------------------------------------------------
    // 4. dead 开关：日程不过滤 enabled
    // ------------------------------------------------------------------

    @Test
    fun `enabled 为 false 的日程仍然出现在周网格`() {
        // Dart :88-91：「日程实例由调用方按日期展开……这里不再过滤 enabled
        // ——日视图议程也不过滤，两处必须一致」。
        val disabled = schedule(
            id = "disabled",
            startDate = "2026-10-29",
            endDate = "2026-10-29",
            enabled = false,
        )

        assertEquals(
            1,
            WeekAgendaLogic.scheduleInstancesOnDate(listOf(disabled), dateOf("2026-10-29")).size,
        )
        assertEquals(
            listOf("disabled"),
            WeekAgendaLogic.resolve(
                date = dateOf("2026-10-29"),
                sections = sections(),
                scheduleItems = listOf(disabled),
                now = fixedNow,
                showExams = false,
            ).map { it.id },
        )
        assertTrue(
            "星期栏圆点也照标",
            WeekAgendaLogic.hasScheduleOn(dateOf("2026-10-29"), listOf(disabled)),
        )
    }

    @Test
    fun `showSchedules 关掉后日程不再出现`() {
        val single = schedule(id = "single", startDate = "2026-10-29", endDate = "2026-10-29")
        assertTrue(
            WeekAgendaLogic.resolve(
                date = dateOf("2026-10-29"),
                sections = sections(),
                scheduleItems = listOf(single),
                now = fixedNow,
                showSchedules = false,
            ).isEmpty(),
        )
    }

    // ------------------------------------------------------------------
    // 5. 排序
    // ------------------------------------------------------------------

    @Test
    fun `排序是开始钟点、结束钟点、日程先于考试、id`() {
        val scheduleEarly = schedule(
            id = "sched-0800", startDate = "2026-10-29", endDate = "2026-10-29",
            startTime = "08:00", endTime = "08:30",
        )
        val scheduleSameSpan = schedule(
            id = "sched-0900", startDate = "2026-10-29", endDate = "2026-10-29",
            startTime = "09:00", endTime = "10:00",
        )
        val examSameSpan = exam("exam-0900", "2026-10-29T09:00", "09:00", "10:00")
        val scheduleIdA = schedule(
            id = "a-sched", startDate = "2026-10-29", endDate = "2026-10-29",
            startTime = "11:00", endTime = "11:30",
        )
        val scheduleIdB = schedule(
            id = "b-sched", startDate = "2026-10-29", endDate = "2026-10-29",
            startTime = "11:00", endTime = "11:30",
        )

        val ordered = WeekAgendaLogic.resolve(
            date = dateOf("2026-10-29"),
            sections = sections(),
            exams = listOf(examSameSpan),
            scheduleItems = listOf(scheduleIdB, scheduleSameSpan, scheduleIdA, scheduleEarly),
            // 固定 now 早于全部考试结束时刻，避免过期过滤干扰排序断言。
            now = dateTimeOf("2026-10-29T07:00:00"),
        )

        assertEquals(
            "08:00 最早 → 09:00 同跨度日程先考试后 → 11:00 按 id（Dart :159-174）",
            listOf("sched-0800", "sched-0900", "exam-0900", "a-sched", "b-sched"),
            ordered.map { it.id },
        )
        assertEquals(
            listOf(
                WeekAgendaKind.SCHEDULE,
                WeekAgendaKind.SCHEDULE,
                WeekAgendaKind.EXAM,
                WeekAgendaKind.SCHEDULE,
                WeekAgendaKind.SCHEDULE,
            ),
            ordered.map { it.kind },
        )
    }

    // ------------------------------------------------------------------
    // 6. 星期栏圆点判据
    // ------------------------------------------------------------------

    @Test
    fun `hasExamOn 当天有未过期考试才为真`() {
        val exams = listOf(
            exam("expiredToday", "2026-10-29T08:30", "08:30", "10:30"),
            exam("tomorrow", "2026-10-30T09:00", "09:00", "10:00"),
        )
        assertFalse(
            "当天那门已过期 ⇒ 不标红点",
            WeekAgendaLogic.hasExamOn(dateOf("2026-10-29"), exams, fixedNow),
        )
        assertTrue(
            "次日那门还没到，是「当天有考试」",
            WeekAgendaLogic.hasExamOn(dateOf("2026-10-30"), exams, fixedNow),
        )
        assertFalse(
            "无考试的日子",
            WeekAgendaLogic.hasExamOn(dateOf("2026-10-31"), exams, fixedNow),
        )
        assertTrue(
            "换成未过期的当天考试 ⇒ 红点亮",
            WeekAgendaLogic.hasExamOn(
                dateOf("2026-10-29"),
                listOf(exam("upcoming", "2026-10-29T14:00", "14:00", "15:30")),
                fixedNow,
            ),
        )
    }

    @Test
    fun `hasScheduleOn 只看当天有没有日程实例`() {
        val items = listOf(schedule(id = "s1", startDate = "2026-10-29", endDate = "2026-10-29"))
        assertTrue(WeekAgendaLogic.hasScheduleOn(dateOf("2026-10-29"), items))
        assertFalse(WeekAgendaLogic.hasScheduleOn(dateOf("2026-10-30"), items))
        assertFalse(WeekAgendaLogic.hasScheduleOn(dateOf("2026-10-29"), emptyList()))
    }

    // ------------------------------------------------------------------
    // 7. 系列实例去重（Dart ScheduleItemExpander.instancesForDate 口径）
    // ------------------------------------------------------------------

    @Test
    fun `同一系列只留一份且系列例外优先`() {
        // 2026-10-01 是周四 ⇒ 每周四重复到 10-29；改期条目把 10-29 这一次换成新内容。
        val series = schedule(
            id = "series",
            startDate = "2026-10-01",
            endDate = "2026-10-31",
            recurrence = ScheduleRecurrence.WEEKLY,
        )
        val override = schedule(
            id = "override",
            startDate = "2026-10-29",
            endDate = "2026-10-29",
            seriesId = "series",
            occurrenceDate = "2026-10-29",
        )

        val instances = WeekAgendaLogic.scheduleInstancesOnDate(
            listOf(series, override),
            dateOf("2026-10-29"),
        )
        assertEquals(1, instances.size)
        val instance = instances.single()
        assertEquals("例外条目顶掉系列原型", "override", instance.item.id)
        assertTrue(instance.isSeriesOverride)
        assertEquals("series@2026-10-29", instance.occurrenceId)

        val otherThursday = WeekAgendaLogic.scheduleInstancesOnDate(
            listOf(series, override),
            dateOf("2026-10-22"),
        ).single()
        assertEquals("series", otherThursday.item.id)
        assertFalse(otherThursday.isSeriesOverride)
        assertEquals("series@2026-10-22", otherThursday.occurrenceId)
    }

    @Test
    fun `两条不同的例外被移到同一天 各留一张卡`() {
        // Dart `schedule_item_expander.dart:43-46/59-62`：两条例外被分别改到同一天
        // （10-08 那次挪到 10-29、10-15 那次也挪到 10-29）是两条真实条目，
        // 持久层各占一条；原先后一条被丢弃——界面少一张卡，且它再也点不到、删不掉。
        val series = schedule(
            id = "series",
            startDate = "2026-10-01",
            endDate = "2026-10-31",
            recurrence = ScheduleRecurrence.WEEKLY,
        )
        val movedFromOct08 = schedule(
            id = "moved-1008",
            startDate = "2026-10-29",
            endDate = "2026-10-29",
            seriesId = "series",
            occurrenceDate = "2026-10-08",
        )
        val movedFromOct15 = schedule(
            id = "moved-1015",
            startDate = "2026-10-29",
            endDate = "2026-10-29",
            seriesId = "series",
            occurrenceDate = "2026-10-15",
        )

        val instances = WeekAgendaLogic.scheduleInstancesOnDate(
            listOf(series, movedFromOct08, movedFromOct15),
            dateOf("2026-10-29"),
        )

        assertEquals("两张例外卡都要保留", 2, instances.size)
        assertEquals(
            setOf("moved-1008", "moved-1015"),
            instances.map { it.item.id }.toSet(),
        )
        assertEquals(
            "occurrenceId 仍指向各自的原始日期（供持久化与撤销）",
            setOf("series@2026-10-08", "series@2026-10-15"),
            instances.map { it.occurrenceId }.toSet(),
        )
        assertTrue(instances.all { it.isSeriesOverride })
    }

    @Test
    fun `实例日期落在日期区间外则不出现`() {
        val item = schedule(id = "s1", startDate = "2026-10-29", endDate = "2026-10-29")
        assertNotNull(item)
        assertEquals(
            0,
            WeekAgendaLogic.scheduleInstancesOnDate(listOf(item), dateOf("2026-11-05")).size,
        )
    }
}
