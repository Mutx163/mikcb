package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * CountdownFormat 纯函数覆盖：10 种样式的常规分支与边界
 * （60s 阈值、flooredMinutes 至少 1 分钟、formatMinuteSecond 的 trimEnd('/')）。
 */
class CountdownFormatTest {

    // ---------- formatDuration：样式路由 ----------

    @Test
    fun `formatDuration routes to smart duration by default`() {
        // 未知样式回落 smart（zh 后缀默认「分钟/秒」）
        assertEquals("2分钟", CountdownFormat.formatDuration(90_000L, "unknown_style"))
        assertEquals("2分钟", CountdownFormat.formatDuration(150_000L, "unknown_style"))
    }

    // ---------- formatSmartDuration ----------

    @Test
    fun `smart below threshold shows seconds`() {
        assertEquals("45秒", CountdownFormat.formatSmartDuration(45_999L, 60_000L))
        // 恰好等于阈值仍走秒（<=）
        assertEquals("60秒", CountdownFormat.formatSmartDuration(60_000L, 60_000L))
    }

    @Test
    fun `smart between one and two minutes rounds up`() {
        // 61s → 2分钟（向上取整）
        assertEquals("2分钟", CountdownFormat.formatSmartDuration(61_000L, 60_000L))
        assertEquals("2分钟", CountdownFormat.formatSmartDuration(119_999L, 60_000L))
    }

    @Test
    fun `smart above two minutes floors`() {
        assertEquals("2分钟", CountdownFormat.formatSmartDuration(120_001L, 60_000L))
        assertEquals("2分钟", CountdownFormat.formatSmartDuration(179_000L, 60_000L))
        // 500ms 先命中 <= 60s 阈值分支，走秒（flooredMinutes 的 coerceAtLeast(1) 不在此路径）
        assertEquals("0秒", CountdownFormat.formatSmartDuration(500L, 60_000L))
    }

    @Test
    fun `smart negative duration clamps to zero seconds`() {
        assertEquals("0秒", CountdownFormat.formatSmartDuration(-1L, 60_000L))
    }

    @Test
    fun `smart custom suffixes`() {
        assertEquals("45s", CountdownFormat.formatSmartDuration(45_000L, 60_000L, "min", "s"))
        assertEquals("2min", CountdownFormat.formatSmartDuration(90_000L, 60_000L, "min", "s"))
    }

    // ---------- formatMinuteSecondCn ----------

    @Test
    fun `minuteSecondCn combinations`() {
        assertEquals("1分钟1秒", CountdownFormat.formatMinuteSecondCn(61_000L))
        assertEquals("1分钟", CountdownFormat.formatMinuteSecondCn(60_000L))
        assertEquals("59秒", CountdownFormat.formatMinuteSecondCn(59_000L))
        assertEquals("0秒", CountdownFormat.formatMinuteSecondCn(0L))
        assertEquals("0秒", CountdownFormat.formatMinuteSecondCn(-5_000L))
    }

    // ---------- formatMinuteSecond（min/s / min//s 变体） ----------

    @Test
    fun `minuteSecond with min and s suffixes`() {
        assertEquals("1min5s", CountdownFormat.formatMinuteSecond(65_000L, "min", "s"))
        assertEquals("2min", CountdownFormat.formatMinuteSecond(120_000L, "min", "s"))
        assertEquals("40s", CountdownFormat.formatMinuteSecond(40_000L, "min", "s"))
    }

    @Test
    fun `minuteSecond trims trailing slash from minute suffix`() {
        // "min/" 样式在只有分钟时不能残留斜杠
        assertEquals("2min", CountdownFormat.formatMinuteSecond(120_000L, "min/", "s"))
        assertEquals("1min/5s", CountdownFormat.formatMinuteSecond(65_000L, "min/", "s"))
        assertEquals("1min", CountdownFormat.formatMinuteSecond(60_000L, "min/", "s"))
    }

    // ---------- formatMinuteSecondColon ----------

    @Test
    fun `minuteSecondColon pads to two digits`() {
        assertEquals("01:05", CountdownFormat.formatMinuteSecondColon(65_000L))
        assertEquals("00:59", CountdownFormat.formatMinuteSecondColon(59_000L))
        assertEquals("10:00", CountdownFormat.formatMinuteSecondColon(600_000L))
        assertEquals("00:00", CountdownFormat.formatMinuteSecondColon(0L))
    }

    // ---------- formatMinuteOnly ----------

    @Test
    fun `minuteOnly floors to at least one minute`() {
        assertEquals("1分钟", CountdownFormat.formatMinuteOnly(500L, "分钟"))
        assertEquals("1分钟", CountdownFormat.formatMinuteOnly(59_999L, "分钟"))
        assertEquals("2分钟", CountdownFormat.formatMinuteOnly(120_000L, "分钟"))
        assertEquals("3min", CountdownFormat.formatMinuteOnly(180_000L, "min"))
        assertEquals("5/min", CountdownFormat.formatMinuteOnly(300_000L, "/min"))
    }

    // ---------- formatSecondOnly ----------

    @Test
    fun `secondOnly keeps raw seconds`() {
        assertEquals("45秒", CountdownFormat.formatSecondOnly(45_000L, "秒"))
        assertEquals("0秒", CountdownFormat.formatSecondOnly(0L, "秒"))
        assertEquals("90s", CountdownFormat.formatSecondOnly(90_000L, "s"))
        assertEquals("90/s", CountdownFormat.formatSecondOnly(90_000L, "/s"))
    }

    // ---------- formatDuration 全样式烟测 ----------

    @Test
    fun `formatDuration all named styles`() {
        val ms = 65_000L
        // smart 对 65s（>60s 且 <=120s）向上取整
        assertEquals("2min", CountdownFormat.formatDuration(ms, "smart_min_s", 60_000L))
        assertEquals("1分钟5秒", CountdownFormat.formatDuration(ms, "minute_second_cn"))
        assertEquals("01:05", CountdownFormat.formatDuration(ms, "minute_second_colon"))
        assertEquals("1min5s", CountdownFormat.formatDuration(ms, "minute_second_min_s"))
        assertEquals("1min/5s", CountdownFormat.formatDuration(ms, "minute_second_min_slash_s"))
        assertEquals("1分钟", CountdownFormat.formatDuration(ms, "minute_only_cn"))
        assertEquals("1min", CountdownFormat.formatDuration(ms, "minute_only_min"))
        assertEquals("1/min", CountdownFormat.formatDuration(ms, "minute_only_slash"))
        assertEquals("65秒", CountdownFormat.formatDuration(ms, "second_only_cn"))
        assertEquals("65s", CountdownFormat.formatDuration(ms, "second_only_short"))
        assertEquals("65/s", CountdownFormat.formatDuration(ms, "second_only_slash"))
    }
}
