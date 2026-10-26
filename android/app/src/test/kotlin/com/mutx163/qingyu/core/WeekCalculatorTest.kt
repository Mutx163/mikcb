package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * WeekCalculator 移植测试。
 *
 * 期望值来源：
 * - [Dart测试抄录]：test/domain/week_calculator_test.dart（2026-08-24 为周一等
 *   日期锚点与全部断言值原样翻成 Kotlin）；
 * - [人推]：日历日差与周次边界的独立推导。
 */
class WeekCalculatorTest {

    private fun t(s: String): java.time.LocalDateTime = DartTime.parseIso(s)

    // ---------- startOfWeek [Dart测试抄录] ----------

    @Test
    fun `startOfWeek snaps any time to monday midnight`() {
        val result = WeekCalculator.startOfWeek(t("2026-08-29T15:42:00.000"))
        assertEquals("2026-08-24T00:00:00.000", DartTime.toIso(result))
        // 周一 = weekday 1
        assertEquals(1, DartTime.dayOfWeekOf(result))
    }

    @Test
    fun `startOfWeek monday snaps to itself`() {
        assertEquals(
            t("2026-08-24T00:00:00.000"),
            WeekCalculator.startOfWeek(t("2026-08-24T15:30:00.000")),
        )
    }

    @Test
    fun `startOfWeek sunday snaps back not forward`() {
        assertEquals(
            t("2026-08-24T00:00:00.000"),
            WeekCalculator.startOfWeek(t("2026-08-30T23:00:00.000")),
        )
    }

    // ---------- getWeekIndex [Dart测试抄录] ----------

    @Test
    fun `getWeekIndex semester day is week 1`() {
        val start = t("2026-08-24T00:00:00.000")
        assertEquals(1L, WeekCalculator.getWeekIndex(start, start))
    }

    @Test
    fun `getWeekIndex same week plus six days still week 1`() {
        assertEquals(
            1L,
            WeekCalculator.getWeekIndex(t("2026-08-30T00:00:00.000"), t("2026-08-24T00:00:00.000")),
        )
    }

    @Test
    fun `getWeekIndex plus seven days is week 2`() {
        assertEquals(
            2L,
            WeekCalculator.getWeekIndex(t("2026-08-31T00:00:00.000"), t("2026-08-24T00:00:00.000")),
        )
    }

    @Test
    fun `getWeekIndex before semester returns null`() {
        assertNull(
            WeekCalculator.getWeekIndex(t("2026-08-23T00:00:00.000"), t("2026-08-24T00:00:00.000")),
        )
    }

    @Test
    fun `getWeekIndex midweek semester start aligns to that weeks monday`() {
        val wedStart = t("2026-08-26T00:00:00.000")
        assertEquals(1L, WeekCalculator.getWeekIndex(t("2026-08-24T00:00:00.000"), wedStart))
        assertNull(WeekCalculator.getWeekIndex(t("2026-08-23T00:00:00.000"), wedStart))
    }

    // ---------- weekForDate [Dart测试抄录] ----------

    @Test
    fun `weekForDate no semester returns fallback`() {
        assertEquals(
            5,
            WeekCalculator.weekForDate(
                t("2026-08-29T00:00:00.000"),
                semesterStart = null,
                semesterWeekCount = 18,
                fallback = 5,
            ),
        )
    }

    @Test
    fun `weekForDate before semester always week 1 not fallback`() {
        assertEquals(
            1,
            WeekCalculator.weekForDate(
                t("2026-08-23T00:00:00.000"),
                semesterStart = t("2026-08-24T00:00:00.000"),
                semesterWeekCount = 18,
                fallback = 5,
            ),
        )
    }

    @Test
    fun `weekForDate mid semester returns real week`() {
        assertEquals(
            2,
            WeekCalculator.weekForDate(
                t("2026-09-01T00:00:00.000"),
                semesterStart = t("2026-08-24T00:00:00.000"),
                semesterWeekCount = 18,
                fallback = 5,
            ),
        )
    }

    @Test
    fun `weekForDate beyond semester clamps to last week`() {
        assertEquals(
            18,
            WeekCalculator.weekForDate(
                DartTime.addDays(t("2026-08-24T00:00:00.000"), 20 * 7),
                semesterStart = t("2026-08-24T00:00:00.000"),
                semesterWeekCount = 18,
                fallback = 5,
            ),
        )
    }

    // ---------- calendarWeekForDate [Dart测试抄录] ----------

    @Test
    fun `calendarWeekForDate no semester returns fallback`() {
        assertEquals(
            7,
            WeekCalculator.calendarWeekForDate(
                t("2026-08-29T00:00:00.000"),
                semesterStart = null,
                fallback = 7,
            ),
        )
    }

    @Test
    fun `calendarWeekForDate before semester returns 0`() {
        assertEquals(
            0,
            WeekCalculator.calendarWeekForDate(
                t("2026-08-23T00:00:00.000"),
                semesterStart = t("2026-08-24T00:00:00.000"),
                fallback = 7,
            ),
        )
    }

    @Test
    fun `calendarWeekForDate mid semester returns real week`() {
        assertEquals(
            2,
            WeekCalculator.calendarWeekForDate(
                t("2026-09-01T00:00:00.000"),
                semesterStart = t("2026-08-24T00:00:00.000"),
                fallback = 7,
            ),
        )
    }

    @Test
    fun `calendarWeekForDate beyond configured weeks not clamped`() {
        assertEquals(
            21,
            WeekCalculator.calendarWeekForDate(
                DartTime.addDays(t("2026-08-24T00:00:00.000"), 20 * 7),
                semesterStart = t("2026-08-24T00:00:00.000"),
                fallback = 7,
            ),
        )
    }

    // ---------- daysBetween / addDays [人推] ----------

    @Test
    fun `daysBetween same day zero earlier negative`() {
        val a = t("2026-08-24T00:00:00.000")
        assertEquals(0L, WeekCalculator.daysBetween(a, a))
        assertEquals(-7L, WeekCalculator.daysBetween(a, t("2026-08-17T00:00:00.000")))
        assertEquals(6L, WeekCalculator.daysBetween(a, t("2026-08-30T12:00:00.000")))
    }

    @Test
    fun `addDays keeps time of day and crosses month boundary`() { // [人推]
        val base = t("2026-01-30T08:30:00.000")
        val moved = DartTime.addDays(base, 3)
        assertEquals("2026-02-02T08:30:00.000", DartTime.toIso(moved))
    }

    @Test
    fun `addDays negative`() { // [人推]
        val moved = DartTime.addDays(t("2026-03-01T00:00:00.000"), -1)
        assertEquals("2026-02-28T00:00:00.000", DartTime.toIso(moved))
    }

    // ---------- 跨年边界 [人推] ----------

    @Test
    fun `week index across year boundary`() {
        // 2025-12-29 是周一；2026-01-05 是下一周周一 → 第 2 周
        assertEquals(
            2L,
            WeekCalculator.getWeekIndex(t("2026-01-05T00:00:00.000"), t("2025-12-29T00:00:00.000")),
        )
    }
}
