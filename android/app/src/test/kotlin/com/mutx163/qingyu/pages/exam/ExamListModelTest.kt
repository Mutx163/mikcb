package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ExamReminderPreset
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 考试列表页（`lib/screens/exam_list_screen.dart`）模型层测试。
 *
 * 期望值全部从 Dart 源手推（`exam.dart:308-336` 的 isExpired/daysUntil、
 * `exam_list_screen.dart:212-273` 的 live phase 与提醒摘要、`:117-145` 的日期串），
 * 不从 Kotlin 实现里抄。
 */
class ExamListModelTest {

    private val baseNow = LocalDateTime.of(2026, 10, 27, 10, 30) // 周二

    private fun exam(
        id: String,
        date: LocalDateTime = LocalDateTime.of(2026, 10, 27, 0, 0),
        start: String = "09:00",
        end: String = "11:00",
        name: String = "考试$id",
        courseId: String = "c1",
        location: String? = null,
        seat: String? = null,
        preset: ExamReminderPreset = ExamReminderPreset.DAY_1_AND_HOUR_1,
        customMinutes: List<Int> = emptyList(),
    ): Exam = Exam(
        id = id,
        courseId = courseId,
        name = name,
        dateTime = date,
        startTime = start,
        endTime = end,
        location = location,
        seatNumber = seat,
        note = null,
        reminderPreset = preset,
        customReminderMinutes = customMinutes,
        createdAt = baseNow,
        updatedAt = baseNow,
    )

    private fun course(
        id: String = "c1",
        name: String = "高等数学",
        teacher: String = "张老师",
        location: String = "教学楼 301",
        color: String = "#EF4444",
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = 2,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        color = color,
    )

    // ==========================================================
    // 1. isExpired / daysUntil（exam.dart:308-336）
    // ==========================================================

    @Test
    fun `考试结束时刻与当前时刻相等不算过期`() {
        val e = exam("a", end = "10:30")
        // now.isAfter(examEnd) 为 false（同一时刻）
        assertFalse(ExamListLogic.isExpired(e, baseNow))
    }

    @Test
    fun `考试结束一分钟后算过期`() {
        val e = exam("a", end = "10:29")
        assertTrue(ExamListLogic.isExpired(e, baseNow))
    }

    @Test
    fun `结束时间解析失败时按当天 23 时 59 分算`() {
        val e = exam("a", end = "不是时间")
        // 回落 23:59，10:30 还没过
        assertFalse(ExamListLogic.isExpired(e, LocalDateTime.of(2026, 10, 27, 23, 58)))
        assertTrue(ExamListLogic.isExpired(e, LocalDateTime.of(2026, 10, 28, 0, 0)))
    }

    @Test
    fun `倒计时按日历日差计算`() {
        assertEquals(0, ExamListLogic.daysUntil(exam("a"), baseNow))
        assertEquals(1, ExamListLogic.daysUntil(exam("a", date = LocalDateTime.of(2026, 10, 28, 0, 0)), baseNow))
        assertEquals(3, ExamListLogic.daysUntil(exam("a", date = LocalDateTime.of(2026, 10, 30, 0, 0)), baseNow))
        // 已过去的考试是负数
        assertEquals(-7, ExamListLogic.daysUntil(exam("a", date = LocalDateTime.of(2026, 10, 20, 0, 0)), baseNow))
    }

    @Test
    fun `倒计时不受时分秒影响`() {
        // 同一天 23:59 开始，仍是「今天」
        val late = exam("a", start = "23:59", end = "23:59")
        assertEquals(0, ExamListLogic.daysUntil(late, LocalDateTime.of(2026, 10, 27, 0, 1)))
    }

    // ==========================================================
    // 2. 考试进行阶段（exam_list_screen.dart:212-236）
    // ==========================================================

    @Test
    fun `开始前是 before`() {
        val e = exam("a")
        assertEquals(
            ExamLivePhase.BEFORE,
            ExamListLogic.resolveLivePhase(e, LocalDateTime.of(2026, 10, 27, 8, 59)),
        )
    }

    @Test
    fun `开始时刻正点算进行中`() {
        val e = exam("a")
        assertEquals(
            ExamLivePhase.ONGOING,
            ExamListLogic.resolveLivePhase(e, LocalDateTime.of(2026, 10, 27, 9, 0)),
        )
    }

    @Test
    fun `结束时刻正点仍算进行中`() {
        val e = exam("a")
        // current.isBefore(end) || current.isAtSameMomentAs(end)
        assertEquals(
            ExamLivePhase.ONGOING,
            ExamListLogic.resolveLivePhase(e, LocalDateTime.of(2026, 10, 27, 11, 0)),
        )
    }

    @Test
    fun `结束之后是 after`() {
        val e = exam("a")
        assertEquals(
            ExamLivePhase.AFTER,
            ExamListLogic.resolveLivePhase(e, LocalDateTime.of(2026, 10, 27, 11, 1)),
        )
    }

    // ==========================================================
    // 3. 日期串（exam_list_screen.dart:117-145）
    // ==========================================================

    @Test
    fun `没有开学日期时只显示月日和星期`() {
        val e = exam("a")
        assertEquals("10月27日 周二", ExamListLogic.formatExamDate(e, semesterStart = null))
    }

    @Test
    fun `有开学日期时前置第 N 周`() {
        // 开学 2026-09-01（周二）→ 所在周周一 08-31；10-27 所在周周一 10-26，
        // 相差 56 天 → 56/7+1 = 第 9 周
        val e = exam("a")
        assertEquals(
            "第 9 周 · 10月27日 周二",
            ExamListLogic.formatExamDate(e, semesterStart = LocalDateTime.of(2026, 9, 1, 0, 0)),
        )
    }

    @Test
    fun `日期早于开学日不显示周次`() {
        val e = exam("a", date = LocalDateTime.of(2026, 10, 20, 0, 0))
        // 10-20 所在周周一 10-19 早于 10-26 → getWeekIndex 返回 null
        assertEquals(
            "10月20日 周二",
            ExamListLogic.formatExamDate(e, semesterStart = LocalDateTime.of(2026, 10, 27, 0, 0)),
        )
    }

    @Test
    fun `九月的日期是单数字月`() {
        val e = exam("a", date = LocalDateTime.of(2026, 9, 1, 0, 0))
        // 2026-09-01 是周二
        assertEquals("9月1日 周二", ExamListLogic.formatExamDate(e, semesterStart = null))
    }

    // ==========================================================
    // 4. 提醒偏移文案（exam_list_screen.dart:255-273）
    // ==========================================================

    @Test
    fun `整天的偏移用天文案`() {
        assertEquals("考前 1 天", ExamListLogic.reminderOffsetLabel(1440))
        assertEquals("考前 2 天", ExamListLogic.reminderOffsetLabel(2880))
    }

    @Test
    fun `整小时的偏移用小时文案`() {
        assertEquals("考前 1 小时", ExamListLogic.reminderOffsetLabel(60))
        assertEquals("考前 3 小时", ExamListLogic.reminderOffsetLabel(180))
    }

    @Test
    fun `零散的分钟偏移用分钟文案`() {
        assertEquals("考前 30 分钟", ExamListLogic.reminderOffsetLabel(30))
        assertEquals("考前 5 分钟", ExamListLogic.reminderOffsetLabel(5))
    }

    @Test
    fun `混合偏移按天 小时 分钟用加号连接`() {
        assertEquals("考前 1 小时 + 考前 30 分钟", ExamListLogic.reminderOffsetLabel(90))
        assertEquals("考前 1 天 + 考前 1 小时", ExamListLogic.reminderOffsetLabel(1500))
        assertEquals("考前 1 天 + 考前 1 小时 + 考前 5 分钟", ExamListLogic.reminderOffsetLabel(1505))
    }

    // ==========================================================
    // 5. 提醒摘要（exam_list_screen.dart:238-253）
    // ==========================================================

    @Test
    fun `没有提醒时显示未设提醒`() {
        assertEquals(
            ExamStrings.examOverviewReminderOff.zh,
            ExamListLogic.reminderSummary(exam("a", preset = ExamReminderPreset.NONE)),
        )
        // 自定义预设但列表为空，同样是无提醒
        assertEquals(
            ExamStrings.examOverviewReminderOff.zh,
            ExamListLogic.reminderSummary(exam("a", preset = ExamReminderPreset.CUSTOM)),
        )
    }

    @Test
    fun `非自定义预设直接显示预设名`() {
        assertEquals(
            "考前 1 天 + 1 小时",
            ExamListLogic.reminderSummary(exam("a", preset = ExamReminderPreset.DAY_1_AND_HOUR_1)),
        )
        assertEquals(
            "考前 30 分钟",
            ExamListLogic.reminderSummary(exam("a", preset = ExamReminderPreset.MIN_30)),
        )
    }

    @Test
    fun `自定义预设最多列两条 其余折叠成加号计数`() {
        assertEquals(
            "考前 30 分钟 · 考前 1 小时",
            ExamListLogic.reminderSummary(
                exam("a", preset = ExamReminderPreset.CUSTOM, customMinutes = listOf(30, 60)),
            ),
        )
        assertEquals(
            "考前 30 分钟 · 考前 1 小时 · +1",
            ExamListLogic.reminderSummary(
                exam("a", preset = ExamReminderPreset.CUSTOM, customMinutes = listOf(30, 60, 90)),
            ),
        )
    }

    // ==========================================================
    // 6. 列表分组与排序（exam_list_screen.dart:24-28）
    // ==========================================================

    @Test
    fun `未结束的按时间正序 已结束的按时间倒序`() {
        val soon = exam("soon", date = LocalDateTime.of(2026, 10, 27, 0, 0), start = "11:00", end = "12:00")
        val later = exam("later", date = LocalDateTime.of(2026, 11, 2, 0, 0))
        val older = exam("older", date = LocalDateTime.of(2026, 10, 1, 0, 0))
        val newer = exam("newer", date = LocalDateTime.of(2026, 10, 20, 0, 0))

        val state = ExamListLogic.buildListViewState(
            exams = listOf(later, older, soon, newer),
            courses = listOf(course()),
            semesterStart = null,
            now = baseNow,
        )

        assertEquals(listOf("soon", "later"), state.upcoming.map { it.exam.id })
        assertEquals(listOf("newer", "older"), state.past.map { it.exam.id })
    }

    @Test
    fun `同一天按开始时刻排序 再按结束时刻 最后按 id`() {
        val a = exam("a", start = "14:00", end = "15:00")
        val b = exam("b", start = "09:00", end = "10:00")
        val c = exam("c", start = "09:00", end = "11:00")
        val d = exam("d", start = "09:00", end = "11:00")

        val state = ExamListLogic.buildListViewState(
            exams = listOf(a, b, c, d),
            courses = emptyList(),
            semesterStart = null,
            now = LocalDateTime.of(2026, 10, 27, 0, 1),
        )

        assertEquals(listOf("b", "c", "d", "a"), state.upcoming.map { it.exam.id })
    }

    @Test
    fun `今日考试场次只数未结束且就在今天的`() {
        val today1 = exam("t1", start = "09:00", end = "23:00")
        val today2 = exam("t2", start = "09:00", end = "23:00")
        val tomorrow = exam("tm", date = LocalDateTime.of(2026, 10, 28, 0, 0))
        val yesterday = exam("y", date = LocalDateTime.of(2026, 10, 26, 0, 0))

        val state = ExamListLogic.buildListViewState(
            exams = listOf(today1, today2, tomorrow, yesterday),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        )

        assertEquals(2, state.todayCount)
        assertEquals(3, state.upcoming.size)
    }

    @Test
    fun `没有考试时是空态 没有概览卡`() {
        val state = ExamListLogic.buildListViewState(
            exams = emptyList(),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        )
        assertTrue(state.isEmpty)
        assertNull(state.overview)
        assertTrue(state.upcoming.isEmpty())
        assertTrue(state.past.isEmpty())
    }

    // ==========================================================
    // 7. 概览卡（exam_list_screen.dart:276-483）
    // ==========================================================

    @Test
    fun `概览卡进行中显示考试进行中与结束时刻`() {
        val e = exam("a", name = " 期末考试 ", end = "11:00", location = " 教学楼 301 ", seat = " 12 ")
        val state = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = listOf(course()),
            semesterStart = null,
            now = baseNow,
        )
        val overview = state.overview!!
        assertEquals("考试进行中", overview.statusLabel)
        assertTrue(overview.isEmphasized)
        assertTrue(overview.isLive)
        assertEquals("期末考试", overview.name)
        assertEquals("至 11:00", overview.bigTimeText)
        assertEquals("09:00 – 11:00", overview.timeRangeText)
        // dateLabel + 考场 + 座位号，两空格夹中点
        assertEquals("10月27日 周二  ·  教学楼 301  ·  座位号 12", overview.metaText)
        // 进行中不显示倒计时数字
        assertNull(overview.countdownDays)
    }

    @Test
    fun `概览卡今天未开始显示今天有考试`() {
        val e = exam("a", start = "14:00", end = "16:00")
        val overview = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).overview!!
        assertEquals("今天有考试", overview.statusLabel)
        assertTrue(overview.isEmphasized)
        assertFalse(overview.isLive)
        assertEquals("14:00 – 16:00", overview.bigTimeText)
        assertNull(overview.countdownDays)
    }

    @Test
    fun `概览卡未来考试显示还有几天并给出倒计时`() {
        val e = exam("a", date = LocalDateTime.of(2026, 10, 30, 0, 0))
        val overview = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).overview!!
        assertEquals("距离考试还有 3 天", overview.statusLabel)
        assertFalse(overview.isEmphasized)
        assertEquals(3, overview.countdownDays)
    }

    @Test
    fun `概览卡名称为空时回落考试名称`() {
        val e = exam("a", name = "   ")
        val overview = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).overview!!
        assertEquals("考试名称", overview.name)
    }

    @Test
    fun `概览卡右侧优先显示今日场次 没有再显示总场次`() {
        val today = exam("t", start = "14:00", end = "16:00")
        val tom1 = exam("m1", date = LocalDateTime.of(2026, 10, 28, 0, 0))
        val tom2 = exam("m2", date = LocalDateTime.of(2026, 10, 29, 0, 0))

        val withToday = ExamListLogic.buildListViewState(
            exams = listOf(today, tom1, tom2),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).overview!!
        assertEquals("今日 1 场", withToday.trailingCountText)

        val withoutToday = ExamListLogic.buildListViewState(
            exams = listOf(tom1, tom2),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).overview!!
        assertEquals("共 2 场", withoutToday.trailingCountText)

        val single = ExamListLogic.buildListViewState(
            exams = listOf(tom1),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).overview!!
        // 只有一场未来考试，两项都不显示
        assertNull(single.trailingCountText)
    }

    @Test
    fun `概览卡有提醒时显示已设提醒加摘要`() {
        val e = exam("a", preset = ExamReminderPreset.DAY_1_AND_HOUR_1)
        val overview = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).overview!!
        assertTrue(overview.reminderEnabled)
        assertEquals("已设提醒  ·  考前 1 天 + 1 小时", overview.reminderText)
    }

    @Test
    fun `概览卡没有考场与座位时不显示副信息行`() {
        val e = exam("a")
        val overview = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).overview!!
        assertEquals("10月27日 周二", overview.metaText)
    }

    // ==========================================================
    // 8. 列表行（exam_list_screen.dart:530-717）
    // ==========================================================

    @Test
    fun `未来考试行显示天数徽标与课程名`() {
        val e = exam("a", date = LocalDateTime.of(2026, 10, 30, 0, 0), preset = ExamReminderPreset.NONE)
        val row = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = listOf(course()),
            semesterStart = null,
            now = baseNow,
        ).upcoming.single()

        assertEquals("高等数学", row.courseName)
        assertEquals("#EF4444", row.accentColorHex)
        assertEquals("3 天后", row.countdownBadge)
        assertFalse(row.isLive)
        assertEquals("10月30日 周五", row.dateLabel)
        assertEquals("09:00 – 11:00", row.timeRangeText)
        // 考试没填地点 → 回落课程地点；再接教师
        assertEquals("教学楼 301 · 张老师", row.metaText)
        // 没有提醒就不显示提醒行
        assertNull(row.reminderText)
    }

    @Test
    fun `今天的考试行徽标是今天`() {
        val e = exam("a", start = "14:00", end = "16:00", preset = ExamReminderPreset.NONE)
        val row = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).upcoming.single()
        assertEquals("今天", row.countdownBadge)
    }

    @Test
    fun `进行中的考试行徽标是进行中`() {
        val e = exam("a", preset = ExamReminderPreset.NONE)
        val state = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        )
        assertTrue(state.upcoming.single().isLive)
        assertEquals("进行中", state.upcoming.single().countdownBadge)
    }

    @Test
    fun `已结束的行没有徽标也没有提醒行`() {
        val e = exam("a", date = LocalDateTime.of(2026, 10, 1, 0, 0), preset = ExamReminderPreset.DAY_1)
        val row = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).past.single()

        assertTrue(row.isPast)
        assertNull(row.countdownBadge)
        assertNull(row.reminderText)
        assertNull(row.courseName)
        assertNull(row.accentColorHex)
    }

    @Test
    fun `考试自己填了考场就用考试的`() {
        val e = exam("a", location = " 实验楼 5 层 ", seat = "A12")
        val row = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = listOf(course()),
            semesterStart = null,
            now = baseNow,
        ).upcoming.single()
        assertEquals("实验楼 5 层 · 座位号 A12 · 张老师", row.metaText)
    }

    @Test
    fun `考点和座位都空时不出现多余分隔符`() {
        val c = course(location = "   ", teacher = "  ")
        val e = exam("a", location = null, seat = "  ")
        val row = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = listOf(c),
            semesterStart = null,
            now = baseNow,
        ).upcoming.single()
        assertNull(row.metaText)
    }

    @Test
    fun `有提醒的未结束考试行显示提醒摘要`() {
        val e = exam("a", preset = ExamReminderPreset.CUSTOM, customMinutes = listOf(30, 60, 90))
        val row = ExamListLogic.buildListViewState(
            exams = listOf(e),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        ).upcoming.single()
        assertEquals("考前 30 分钟 · 考前 1 小时 · +1", row.reminderText)
    }

    // ==========================================================
    // 9. 删除确认文案（exam_list_screen.dart:147-160）
    // ==========================================================

    @Test
    fun `删除确认文案带考试名`() {
        assertEquals(
            "确定删除考试 期末考试？",
            ExamStrings.deleteExamConfirm.filled("name", "期末考试"),
        )
    }

    @Test
    fun `列表状态里带着标题与空态文案`() {
        val state = ExamListLogic.buildListViewState(
            exams = emptyList(),
            courses = emptyList(),
            semesterStart = null,
            now = baseNow,
        )
        assertNotNull(state.emptyTitle)
        assertEquals("暂无考试安排", state.emptyTitle)
    }
}
