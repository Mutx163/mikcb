package com.mutx163.qingyu.statistics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * ClockTime 移植测试（源：lib/utils/clock_time.dart）。
 *
 * 期望值来源标注：
 * - 「Dart 逐行」= 按 lib/utils/clock_time.dart 的实现逐行推演；
 * - 「人推边界」= 独立推出来的边界值（不是从实现抄的）。
 */
class ClockTimeTest {

    // ---------- tryParse 基本形态（Dart 逐行 clock_time.dart:24-48） ----------

    @Test
    fun `parses zero padded hh mm`() {
        val t = ClockTime.tryParse("08:00")
        assertNotNull(t)
        assertEquals(480, t!!.totalMinutes)
        assertEquals(8, t.hour)
        assertEquals(0, t.minute)
    }

    @Test
    fun `trims surrounding and inner whitespace`() {
        // Dart 逐行：text 先 trim，parts[0]/parts[1] 各自再 trim
        assertEquals(480, ClockTime.tryParse("  08:00 ")!!.totalMinutes)
        assertEquals(485, ClockTime.tryParse("08: 05")!!.totalMinutes)
    }

    // ---------- 拒绝形态（Dart 逐行 + 人推边界） ----------

    @Test
    fun `rejects null empty and wrong shape`() {
        assertNull(ClockTime.tryParse(null))
        assertNull(ClockTime.tryParse(""))
        assertNull(ClockTime.tryParse("   "))
        assertNull(ClockTime.tryParse("8")) // 无列分隔（timetable_settings 允许它进库）
        assertNull(ClockTime.tryParse("08.30")) // 点号分隔
        assertNull(ClockTime.tryParse("上午8点")) // 非数字
        assertNull(ClockTime.tryParse("08:0a")) // 分钟非数字
    }

    @Test
    fun `minute boundaries 59 ok 60 and negative rejected`() {
        // 人推边界：minute ∈ 0..59（Dart 逐行 :38-40）
        assertEquals(539, ClockTime.tryParse("08:59")!!.totalMinutes) // 8*60+59=539（对拍 Dart clock_time.dart totalMinutes）
        assertNull(ClockTime.tryParse("08:60"))
        assertNull(ClockTime.tryParse("08:-1"))
    }

    @Test
    fun `hour 23 ok hour 24 only as exact end of day`() {
        // 人推边界：hour ∈ 0..23；24:00 仅在 allowEndOfDay 下放行（Dart 逐行 :41-46）
        assertEquals(23 * 60 + 59, ClockTime.tryParse("23:59")!!.totalMinutes)
        assertNull(ClockTime.tryParse("24:00"))
        val endOfDay = ClockTime.tryParse("24:00", allowEndOfDay = true)
        assertEquals(24 * 60, endOfDay!!.totalMinutes)
        // 24:30 / 25:00 即使放行 24:00 也一律拒绝（会被 DateTime 静默归一到次日）
        assertNull(ClockTime.tryParse("24:30", allowEndOfDay = true))
        assertNull(ClockTime.tryParse("25:00", allowEndOfDay = true))
    }

    // ---------- formatted（Dart 逐行 :54-55） ----------

    @Test
    fun `formatted pads both fields`() {
        assertEquals("08:05", ClockTime.tryParse("8:05")!!.formatted)
        assertEquals("24:00", ClockTime(24, 0).formatted)
    }
}
