package com.mutx163.qingyu.share

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.LocalDate

/**
 * 传输信封层端口测试。
 * dart 源：transfer_package.dart（TransferScope/Channel/Mode、信封常量）、
 * unified_transfer_service.dart（_isTransferEnvelope、newPackageId、
 * _TransferScopeWindow）；抄录 transfer_package_test.dart 的信封/round-trip
 * 口径与「同一微秒生成的 packageId 不撞号」。
 * 学期/窗口期望值人推：以周一为周起始的日期算术。
 */
class TransferEnvelopeTest {

    @Test fun `scope值映射与未知拒绝`() {
        assertEquals("current_timetable", TransferScope.CURRENT_TIMETABLE.value)
        assertEquals("selected_courses", TransferScope.SELECTED_COURSES.value)
        assertEquals("all_data", TransferScope.ALL_DATA.value)
        assertEquals("week_timetable", TransferScope.WEEK_TIMETABLE.value)
        assertEquals("selected_course", TransferScope.SELECTED_COURSE.value)
        assertEquals("time_template", TransferScope.TIME_TEMPLATE.value)
        assertEquals(TransferScope.WEEK_TIMETABLE, TransferScope.fromValue("week_timetable"))
        assertEquals(TransferScope.ALL_DATA, TransferScope.fromValue("  all_data "))
        try {
            TransferScope.fromValue("nope")
            fail("expected invalid")
        } catch (e: IllegalArgumentException) {
            assertEquals("transfer_scope_invalid", e.message)
        }
        try {
            TransferScope.fromValue(null)
            fail("expected invalid")
        } catch (e: IllegalArgumentException) {
            assertEquals("transfer_scope_invalid", e.message)
        }
    }

    @Test fun `scope语义`() {
        // 局部覆盖走合并语义：包边界外的本机数据不动。
        assertTrue(TransferScope.SELECTED_COURSES.overwriteUsesMergeSemantics)
        assertTrue(TransferScope.SELECTED_COURSE.overwriteUsesMergeSemantics)
        assertTrue(TransferScope.WEEK_TIMETABLE.overwriteUsesMergeSemantics)
        assertTrue(TransferScope.TIME_TEMPLATE.overwriteUsesMergeSemantics)
        assertFalse(TransferScope.CURRENT_TIMETABLE.overwriteUsesMergeSemantics)
        assertFalse(TransferScope.ALL_DATA.overwriteUsesMergeSemantics)
        // 只有整表传输可带设置。
        assertTrue(TransferScope.CURRENT_TIMETABLE.carriesSettings)
        assertTrue(TransferScope.ALL_DATA.carriesSettings)
        assertFalse(TransferScope.WEEK_TIMETABLE.carriesSettings)
        assertFalse(TransferScope.SELECTED_COURSES.carriesSettings)
        assertFalse(TransferScope.SELECTED_COURSE.carriesSettings)
        assertFalse(TransferScope.TIME_TEMPLATE.carriesSettings)
    }

    @Test fun `channel映射未知回落file`() {
        assertEquals(TransferChannel.QR, TransferChannel.fromValue("qr"))
        assertEquals(TransferChannel.LAN, TransferChannel.fromValue(" LAN "))
        assertEquals(TransferChannel.CLOUD, TransferChannel.fromValue("Cloud"))
        // Dart 原样：未知 channel 不抛，回落 file。
        assertEquals(TransferChannel.FILE, TransferChannel.fromValue("pigeon"))
        assertEquals(TransferChannel.FILE, TransferChannel.fromValue(null))
        assertEquals("file", TransferChannel.FILE.value)
    }

    @Test fun `信封探测只认mikcb加transfer`() {
        assertEquals("mikcb", TransferEnvelope.APP_ID)
        assertEquals("transfer", TransferEnvelope.PACKAGE_TYPE)
        assertEquals(1, TransferEnvelope.SCHEMA_VERSION)
        assertTrue(
            TransferEnvelope.isTransferEnvelopeJson(
                """{"app":"mikcb","packageType":"transfer","schemaVersion":1}""",
            ),
        )
        assertFalse(TransferEnvelope.isTransferEnvelopeJson("""{"app":"other"}"""))
        assertFalse(
            TransferEnvelope.isTransferEnvelopeJson(
                """{"app":"mikcb","packageType":"backup"}""",
            ),
        )
        assertFalse(TransferEnvelope.isTransferEnvelopeJson("not json"))
        assertFalse(TransferEnvelope.isTransferEnvelopeJson(""))
        assertFalse(TransferEnvelope.isTransferEnvelopeJson("[1,2]"))
    }

    @Test fun `同一微秒生成的packageId不撞号`() {
        val fixedMicros = 1750000000000000L
        val first = TransferEnvelope.newPackageId(nowMicros = fixedMicros, salt = 1L)
        val second = TransferEnvelope.newPackageId(nowMicros = fixedMicros, salt = 2L)
        assertEquals("transfer-$fixedMicros-1", first)
        assertNotEquals(first, second)
        // 格式：transfer-<微秒>-<0~2^32)。
        val parts = TransferEnvelope.newPackageId().split("-")
        assertEquals(3, parts.size)
        assertEquals("transfer", parts[0])
        assertTrue(parts[1].toLong() > 0)
        val salt = parts[2].toLong()
        assertTrue(salt >= 0 && salt < (1L shl 32))
    }

    // 学期起点：2026-09-01 是周二，归一到周一 2026-08-31。
    private val semesterMonday = LocalDate.of(2026, 8, 31)

    @Test fun `窗口起止按周展开`() {
        val window = TransferScopeWindow(
            weeks = setOf(2, 3),
            semesterStartWeek = semesterMonday,
            fallbackWeekStart = LocalDate.of(2026, 6, 27),
        )
        // 第 2 周周一 = 8-31+7 = 09-07；第 3 周周日 = 8-31+21-1 = 09-20。
        assertEquals(LocalDate.of(2026, 9, 7), window.startDate())
        assertEquals(LocalDate.of(2026, 9, 20), window.endDate())
    }

    @Test fun `containsDate按周归属`() {
        val window = TransferScopeWindow(
            weeks = setOf(2),
            semesterStartWeek = semesterMonday,
            fallbackWeekStart = LocalDate.of(2026, 6, 27),
        )
        assertTrue(window.containsDate(LocalDate.of(2026, 9, 7))) // 周一
        assertTrue(window.containsDate(LocalDate.of(2026, 9, 13))) // 周日
        assertFalse(window.containsDate(LocalDate.of(2026, 9, 14))) // 第 3 周
        assertFalse(window.containsDate(LocalDate.of(2026, 8, 30))) // 学期前
        // 空窗口一律 false。
        assertFalse(TransferScopeWindow.empty(LocalDate.of(2026, 6, 27)).containsDate(LocalDate.of(2026, 9, 7)))
    }

    @Test fun `无学期退回自然周`() {
        val fallback = LocalDate.of(2026, 6, 29) // 周一
        val window = TransferScopeWindow(
            weeks = setOf(1),
            semesterStartWeek = null,
            fallbackWeekStart = fallback,
        )
        assertEquals(fallback, window.startDate())
        assertEquals(fallback.plusDays(6), window.endDate())
        assertTrue(window.containsDate(fallback.plusDays(3)))
        assertFalse(window.containsDate(fallback.plusDays(7)))
    }

    @Test fun `overlapsDateRange边界`() {
        val window = TransferScopeWindow(
            weeks = setOf(2),
            semesterStartWeek = semesterMonday,
            fallbackWeekStart = LocalDate.of(2026, 6, 27),
        )
        val weekStart = LocalDate.of(2026, 9, 7)
        val weekEnd = LocalDate.of(2026, 9, 13)
        assertTrue(window.overlapsDateRange(weekStart, weekEnd))
        assertTrue(window.overlapsDateRange(weekEnd, weekEnd.plusDays(3))) // 尾部相交
        assertTrue(window.overlapsDateRange(weekStart.minusDays(3), weekStart)) // 头部相交
        assertFalse(window.overlapsDateRange(weekEnd.plusDays(1), weekEnd.plusDays(2)))
        // 倒置区间恒 false。
        assertFalse(window.overlapsDateRange(weekEnd, weekStart))
        assertFalse(TransferScopeWindow.empty(fallbackWeekStart = weekStart).overlapsDateRange(weekStart, weekEnd))
    }
}
