package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * ClassReminderPlan 移植测试。
 *
 * 期望值来源：
 * - [Dart抄录]：`lib/services/class_reminder_service.dart:64-116`（buildFires）、
 *   `:15-40`（parse/format）、`:59-60`（requestCode）、
 *   `lib/models/class_reminder.dart:25-37,84-100`（id / isValid / 日期校验）；
 * - [Dart推演]：`lib/widgets/class_reminder_sheet.dart:37-48`（真实日期推算）；
 * - [人推]：同刻排序的次级键、跨零点提前量（Dart 注释 `class_reminder.dart:21`
 *   明确「同日内表达，不跨午夜」，跨日只能靠 date 回退）。
 *
 * 锚点：2026-09-07 是周一（与 CourseSessionStatsTest 同一学期锚点）。
 */
class ClassReminderPlanTest {

    private val semesterStart: LocalDateTime = DartTime.dateTime(2026, 9, 9) // 周三

    private fun course(
        id: String = "c1",
        name: String = "线性代数",
        location: String = "A101",
        dayOfWeek: Int = 3,
        startTime: String = "08:00",
        endTime: String = "09:40",
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = startTime,
        endTime = endTime,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
    )

    // ------------------------------------------------------------------
    // requestCode 稳定性（Lead 指定单独一条断言）
    // ------------------------------------------------------------------

    @Test
    fun requestCode_同一课同一周同一分钟多次计算结果不变() {
        val entry = ClassReminderPlan.Entry("c1", "2026-09-16", 570) // 09:30
        val first = ClassReminderPlan.requestCode(entry)
        val second = ClassReminderPlan.requestCode(entry.copy())
        val third = ClassReminderPlan.requestCode(
            ClassReminderPlan.Entry("c1", "2026-09-16", 570),
        )
        assertEquals("同一条目的 requestCode 必须可重复计算", first, second)
        assertEquals("重建的等价条目必须拿到同一个 requestCode", first, third)
        // 命名空间位：与 Dart `requestCodeNamespace`（exam_reminder_service.dart:38）逐位一致
        assertEquals(
            ClassReminderPlan.REQUEST_CODE_NAMESPACE,
            first and 0xFF000000.toInt(),
        )
    }

    @Test
    fun requestCode_不同分钟必不同() {
        // Dart `stableRequestCode` 的键是 "$id#$minuteOfDay"（exam_reminder_service.dart:75），
        // minuteOfDay 参与哈希：改时间 = 换 PendingIntent 身份。
        val at0930 = ClassReminderPlan.requestCode(
            ClassReminderPlan.Entry("c1", "2026-09-16", 570),
        )
        val at0931 = ClassReminderPlan.requestCode(
            ClassReminderPlan.Entry("c1", "2026-09-16", 571),
        )
        assertNotEquals("同一课同一日期、不同响点必须拿到不同 requestCode", at0930, at0931)
    }

    // ------------------------------------------------------------------
    // 周规则（单双周 / 停课周 / 自定义周 / 无开学日 / 日期算术）
    // ------------------------------------------------------------------

    @Test
    fun occurrenceDate_单双周错位返回null() {
        // 2026-09-16 是第 2 周周三；单周课在第 2 周不上。
        val oddCourse = course(isOddWeek = true, startWeek = 1, endWeek = 4)
        assertNull(ClassReminderPlan.occurrenceDate(oddCourse, 2, semesterStart))
        assertEquals(
            LocalDate.of(2026, 9, 9),
            ClassReminderPlan.occurrenceDate(oddCourse, 1, semesterStart),
        )

        val evenCourse = course(isEvenWeek = true, startWeek = 1, endWeek = 4)
        assertNull(ClassReminderPlan.occurrenceDate(evenCourse, 1, semesterStart))
        assertEquals(
            LocalDate.of(2026, 9, 16),
            ClassReminderPlan.occurrenceDate(evenCourse, 2, semesterStart),
        )
    }

    @Test
    fun occurrenceDate_停课周跳过() {
        val suspended = course(suspendedWeeks = listOf(2))
        assertNull(ClassReminderPlan.occurrenceDate(suspended, 2, semesterStart))
        assertEquals(
            LocalDate.of(2026, 9, 9),
            ClassReminderPlan.occurrenceDate(suspended, 1, semesterStart),
        )
    }

    @Test
    fun occurrenceDate_自定义周() {
        // customWeeks 覆盖 start..end 与单双周：第 2/5 周上，第 3 周不上。
        val custom = course(startWeek = 1, endWeek = 10, customWeeks = listOf(2, 5))
        assertEquals(
            LocalDate.of(2026, 9, 16),
            ClassReminderPlan.occurrenceDate(custom, 2, semesterStart),
        )
        assertNull(ClassReminderPlan.occurrenceDate(custom, 3, semesterStart))
        // 第 5 周周一 = 10-05，周三 = 10-07。
        assertEquals(
            LocalDate.of(2026, 10, 7),
            ClassReminderPlan.occurrenceDate(custom, 5, semesterStart),
        )
    }

    @Test
    fun occurrenceDate_无开学日返回null() {
        assertNull(ClassReminderPlan.occurrenceDate(course(), 1, null))
    }

    @Test
    fun occurrenceDate_开学日归到所在周的周一再推算() {
        // 开学日 2026-09-09（周三）：第 1 周周三 = 09-09，第 2 周周三 = 09-16。
        assertEquals(
            LocalDate.of(2026, 9, 9),
            ClassReminderPlan.occurrenceDate(course(), 1, semesterStart),
        )
        assertEquals(
            LocalDate.of(2026, 9, 16),
            ClassReminderPlan.occurrenceDate(course(), 2, semesterStart),
        )
    }

    // ------------------------------------------------------------------
    // buildFires：过滤 / 正文 / 排序 / offsetMinutes
    // ------------------------------------------------------------------

    @Test
    fun buildFires_已过期的条目不出fire() {
        val past = ClassReminderPlan.Entry("c1", "2026-09-16", 540) // 09:00
        val now = DartTime.dateTime(2026, 9, 16, 9, 30)
        assertEquals(
            emptyList<ClassReminderPlan.Fire>(),
            ClassReminderPlan.buildFires(listOf(past), { course() }, now),
        )

        // Dart `!fireAt.isAfter(now)`（:80）：恰好等于 now 也算过期。
        val exactlyNow = ClassReminderPlan.Entry("c1", "2026-09-16", 570) // 09:30
        assertEquals(
            emptyList<ClassReminderPlan.Fire>(),
            ClassReminderPlan.buildFires(listOf(exactlyNow), { course() }, now),
        )

        val future = ClassReminderPlan.Entry("c1", "2026-09-16", 571) // 09:31
        assertEquals(
            1,
            ClassReminderPlan.buildFires(listOf(future), { course() }, now).size,
        )
    }

    @Test
    fun buildFires_坏条目与已删课程被丢弃() {
        val entries = listOf(
            ClassReminderPlan.Entry("c1", "2026-02-31", 570), // 不存在的日期
            ClassReminderPlan.Entry("c1", "2026-09-16", 1440), // 响点越界
            ClassReminderPlan.Entry("   ", "2026-09-16", 570), // 课程 id 空白
            ClassReminderPlan.Entry("ghost", "2026-09-16", 570), // 课程已删
            ClassReminderPlan.Entry("c1", "2026-09-16", 570), // 唯一合法
        )
        val fires = ClassReminderPlan.buildFires(
            entries = entries,
            resolveCourse = { id -> if (id == "c1") course() else null },
            now = DartTime.dateTime(2026, 9, 16, 8, 0),
        )
        assertEquals(1, fires.size)
        assertEquals("classreminder:c1@2026-09-16", fires[0].entryId)
    }

    @Test
    fun buildFires_正文为地点或回落响点钟点() {
        val entry = ClassReminderPlan.Entry("c1", "2026-09-16", 570)
        val now = DartTime.dateTime(2026, 9, 16, 8, 0)

        val withLocation = ClassReminderPlan.buildFires(
            listOf(entry),
            { course(location = "  A101  ") },
            now,
        )
        assertEquals("A101", withLocation[0].body)
        assertEquals("线性代数", withLocation[0].title)

        // 地点空白 → 响点钟点（Dart :83-92，避开原生「你有一场即将开始的考试」兜底）
        val noLocation = ClassReminderPlan.buildFires(
            listOf(entry),
            { course(location = "   ", name = "  线性代数  ") },
            now,
        )
        assertEquals("09:30", noLocation[0].body)
        assertEquals("线性代数", noLocation[0].title)

        // offsetMinutes 恒为 0（Dart :105-107：填 0 让原生加减法退化成恒等）
        assertEquals(0, noLocation[0].offsetMinutes)
    }

    @Test
    fun buildFires_同一时刻多课排序稳定() {
        // 三节课同一天同一响点；主键 fireAt 相等 → 次级键 entryId 决定顺序。
        val a = ClassReminderPlan.Entry("c1", "2026-09-16", 570)
        val b = ClassReminderPlan.Entry("c2", "2026-09-16", 570)
        val c = ClassReminderPlan.Entry("c3", "2026-09-16", 570)
        val now = DartTime.dateTime(2026, 9, 16, 8, 0)
        val resolve: (String) -> Course? = { id ->
            course(id = id, name = "课程$id", location = "A101")
        }

        val first = ClassReminderPlan.buildFires(listOf(c, a, b), resolve, now)
        assertEquals(
            listOf(
                "classreminder:c1@2026-09-16",
                "classreminder:c2@2026-09-16",
                "classreminder:c3@2026-09-16",
            ),
            first.map { it.entryId },
        )

        // 输入顺序无关：反序再建一次，结果不变（次级键保证确定性）。
        val second = ClassReminderPlan.buildFires(listOf(b, c, a), resolve, now)
        assertEquals(first.map { it.entryId }, second.map { it.entryId })
    }

    @Test
    fun buildFires_按响点升序_过期条目不影响其余条目() {
        val morning = ClassReminderPlan.Entry("c1", "2026-09-16", 570) // 09:30
        val afternoon = ClassReminderPlan.Entry("c2", "2026-09-16", 840) // 14:00
        val past = ClassReminderPlan.Entry("c3", "2026-09-15", 600) // 前一天，已过期
        val now = DartTime.dateTime(2026, 9, 16, 8, 0)
        val fires = ClassReminderPlan.buildFires(
            listOf(afternoon, past, morning),
            { id -> course(id = id, name = "课程$id") },
            now,
        )
        assertEquals(
            listOf(
                DartTime.dateTime(2026, 9, 16, 9, 30),
                DartTime.dateTime(2026, 9, 16, 14, 0),
            ),
            fires.map { it.fireAt },
        )
    }

    // ------------------------------------------------------------------
    // entryFor：提前量 / 跨零点
    // ------------------------------------------------------------------

    @Test
    fun entryFor_提前量跨零点回退一天() {
        // 00:10 的课，提前 30 分钟 → 前一天 23:40（minuteOfDay 不跨午夜）
        val entry = ClassReminderPlan.entryFor(
            courseId = "c1",
            occurrence = LocalDate.of(2026, 9, 17),
            startMinuteOfDay = 10,
        )
        assertEquals("2026-09-16", entry.date)
        assertEquals(1420, entry.minuteOfDay)
        assertEquals(
            DartTime.dateTime(2026, 9, 16, 23, 40),
            ClassReminderPlan.occurrenceDateTime(entry),
        )
        assertTrue(entry.isValid)
    }

    @Test
    fun entryFor_课程跨零点结束不影响响点() {
        // 23:50 开课、00:30 结束（跨零点结束），提前 30 分钟 → 同日 23:20，不回退。
        val entry = ClassReminderPlan.entryFor(
            courseId = "c1",
            occurrence = LocalDate.of(2026, 9, 16),
            startMinuteOfDay = ClassReminderPlan.parseClockMinutes("23:50")!!,
        )
        assertEquals("2026-09-16", entry.date)
        assertEquals(ClassReminderPlan.parseClockMinutes("23:20"), entry.minuteOfDay)

        // 端到端：这门课的响点仍是同一个自然日的 23:20，与结束时刻（次日 00:30）无关。
        val nightCourse = course(startTime = "23:50", endTime = "00:30")
        val fires = ClassReminderPlan.buildFires(
            listOf(entry),
            { nightCourse },
            DartTime.dateTime(2026, 9, 16, 8, 0),
        )
        assertEquals(DartTime.dateTime(2026, 9, 16, 23, 20), fires[0].fireAt)
    }

    // ------------------------------------------------------------------
    // 时钟解析/格式化（与 ClassAlarmPlanLogic 同源，防止两套实现漂移）
    // ------------------------------------------------------------------

    @Test
    fun 时钟解析与格式化口径() {
        assertEquals(570, ClassReminderPlan.parseClockMinutes("09:30"))
        assertNull(ClassReminderPlan.parseClockMinutes("24:00"))
        assertNull(ClassReminderPlan.parseClockMinutes("9:30:00"))
        assertEquals("23:40", ClassReminderPlan.formatClock(-20))
        assertEquals("00:00", ClassReminderPlan.formatClock(1440))
    }
}
