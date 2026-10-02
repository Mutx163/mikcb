package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Calendar

/**
 * `LiveClock` 的口径（2026-10-02 审查）。
 *
 * 原生四份钟点解析只做"两段 + 能转整数"，不校验范围；
 * `Calendar.set(HOUR_OF_DAY, 25)` 与 `set(MINUTE, 75)` 是宽松的，
 * 会把时间静默推进到次日 01:00 / 下一小时，调用方拿到的仍像是"成功"。
 * 这些用例钉住的是：越界值必须返回 null（调用方据此跳过该提醒），
 * 而 `24:00` 作为"当天结束"必须精确落到次日零点。
 */
class LiveClockTest {
    @Test
    fun parsesValidClockTimes() {
        assertEquals(0, LiveClock.minutesOfDay("00:00"))
        assertEquals(480, LiveClock.minutesOfDay("08:00"))
        // Dart 侧 ClockTime.tryParse 接受个位数小时并规范化成 HH:MM。
        assertEquals(480, LiveClock.minutesOfDay("8:00"))
        assertEquals(495, LiveClock.minutesOfDay(" 08:15 "))
        assertEquals(1439, LiveClock.minutesOfDay("23:59"))
    }

    @Test
    fun treatsEndOfDayAsFourteenForty() {
        assertEquals(1440, LiveClock.minutesOfDay("24:00"))
    }

    @Test
    fun rejectsOutOfRangeAndMalformed() {
        assertNull(LiveClock.minutesOfDay("25:00"))
        assertNull(LiveClock.minutesOfDay("24:30"))
        assertNull(LiveClock.minutesOfDay("08:75"))
        assertNull(LiveClock.minutesOfDay("08:60"))
        assertNull(LiveClock.minutesOfDay("-1:00"))
        assertNull(LiveClock.minutesOfDay("08:-1"))
        assertNull(LiveClock.minutesOfDay("8"))
        assertNull(LiveClock.minutesOfDay("08:00:00"))
        assertNull(LiveClock.minutesOfDay("08.30"))
        assertNull(LiveClock.minutesOfDay("上午8点"))
        assertNull(LiveClock.minutesOfDay(""))
        assertNull(LiveClock.minutesOfDay(null))
    }

    @Test
    fun mapsOntoGivenDayAndClearsSeconds() {
        val day = Calendar.getInstance().apply {
            set(2026, Calendar.SEPTEMBER, 7, 13, 45, 12)
            set(Calendar.MILLISECOND, 300)
        }
        val millis = LiveClock.toMillis(day, "09:30")!!
        val got = Calendar.getInstance().apply { timeInMillis = millis }

        assertEquals(2026, got.get(Calendar.YEAR))
        assertEquals(Calendar.SEPTEMBER, got.get(Calendar.MONTH))
        assertEquals(7, got.get(Calendar.DAY_OF_MONTH))
        assertEquals(9, got.get(Calendar.HOUR_OF_DAY))
        assertEquals(30, got.get(Calendar.MINUTE))
        assertEquals(0, got.get(Calendar.SECOND))
        assertEquals(0, got.get(Calendar.MILLISECOND))
    }

    @Test
    fun endOfDayRollsToNextMidnight() {
        val day = Calendar.getInstance().apply {
            set(2026, Calendar.SEPTEMBER, 7, 23, 59, 59)
            set(Calendar.MILLISECOND, 0)
        }
        val millis = LiveClock.toMillis(day, "24:00")!!
        val got = Calendar.getInstance().apply { timeInMillis = millis }

        assertEquals(8, got.get(Calendar.DAY_OF_MONTH))
        assertEquals(0, got.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, got.get(Calendar.MINUTE))
        assertEquals(0, got.get(Calendar.SECOND))
    }

    @Test
    fun refusesToNormalizeInvalidTimeIntoMillis() {
        val day = Calendar.getInstance().apply {
            set(2026, Calendar.SEPTEMBER, 7, 8, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        // 旧实现会返回"次日 01:00"的毫秒数并照常排闹钟。
        assertNull(LiveClock.toMillis(day, "25:00"))
        assertNull(LiveClock.toMillis(day, "08:75"))
        assertNull(LiveClock.toMillis(day, ""))
    }
}
