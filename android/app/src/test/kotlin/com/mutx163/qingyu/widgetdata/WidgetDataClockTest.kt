package com.mutx163.qingyu.widgetdata

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 时钟纯逻辑的端口测试（移植 lib/domain/clock_order.dart 与
 * LiveActivityLogic.buildCourseDateTime / 快照服务 _buildCourseDateTime 口径）。
 *
 * 期望值来源：注释规则推演（[Dart推演]）；`compareClockText` 的排序契约来自
 * clock_order.dart 头注释记载的历史事故（[Dart抄录]）。
 */
class WidgetDataClockTest {

    private val day: LocalDateTime = LocalDateTime.of(2026, 3, 2, 0, 0)

    @Test
    fun compareClockIgnoresZeroPadding() { // [Dart抄录] "9:00" 必须排在 "10:00" 之前
        assertTrue(WidgetDataClock.compareClockText("9:00", "10:00") < 0)
        assertTrue(WidgetDataClock.compareClockText("10:00", "9:00") > 0)
        assertEquals(0, WidgetDataClock.compareClockText("09:00", "9:00"))
    }

    @Test
    fun compareClockUnparseableSortsLast() { // [Dart抄录] 坏值排最后、双坏退字典序
        assertTrue(WidgetDataClock.compareClockText("10:00", "bad") < 0)
        assertTrue(WidgetDataClock.compareClockText("bad", "10:00") > 0)
        assertEquals(0, WidgetDataClock.compareClockText("abc", "abc"))
    }

    @Test
    fun endOfDayClockCountsAs1440() { // [Dart抄录] 24:00 放行 = 1440 分钟
        assertEquals(1440, WidgetDataClock.clockTextToMinutes("24:00"))
        assertEquals(null, WidgetDataClock.clockTextToMinutes("24:30"))
        assertEquals(null, WidgetDataClock.clockTextToMinutes("25:00"))
        assertEquals(null, WidgetDataClock.clockTextToMinutes("08:75"))
        assertEquals(null, WidgetDataClock.clockTextToMinutes(""))
    }

    @Test
    fun courseDateTimeRejectsOutOfBoundsHour() { // [Dart抄录] 25:00 → null（不挪天）
        assertEquals(null, WidgetDataClock.courseDateTimeOn(day, "25:00"))
        assertEquals(null, WidgetDataClock.courseDateTimeOn(day, "08:75"))
        assertEquals(null, WidgetDataClock.courseDateTimeOn(day, ""))
    }

    @Test
    fun courseDateTimeBuildsSameDayMidnight() { // [Dart推演]
        assertEquals(
            LocalDateTime.of(2026, 3, 2, 8, 0),
            WidgetDataClock.courseDateTimeOn(day, "08:00"),
        )
        assertEquals(
            LocalDateTime.of(2026, 3, 2, 23, 59),
            WidgetDataClock.courseDateTimeOn(day, "23:59"),
        )
    }

    @Test
    fun endOfDayClockRollsToNextMidnight() { // [Dart推演] 24:00 = 次日 00:00
        assertEquals(
            LocalDateTime.of(2026, 3, 3, 0, 0),
            WidgetDataClock.courseDateTimeOn(day, "24:00"),
        )
    }

    @Test
    fun nextMidnightCrossesMonth() { // [Dart推演] 月末跨天
        val monthEnd = LocalDateTime.of(2026, 3, 31, 10, 0)
        assertEquals(
            LocalDateTime.of(2026, 4, 1, 0, 0),
            WidgetDataClock.nextMidnight(monthEnd),
        )
    }
}
