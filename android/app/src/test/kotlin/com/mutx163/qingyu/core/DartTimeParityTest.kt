package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId

/**
 * D2：DartTime 读入口径 = **双向放宽**（Dart 会写的形状 + 本项目历史宽松形状），
 * 写出口径 = Dart canonical（本地墙钟、无偏移、毫秒/微秒按 Dart 规则）。
 *
 * 期望值全部来自 Dart 2.x 实测（`DateTime.tryParse` / `toIso8601String`），
 * 不是凭记忆写的：
 * - `20260101`、`20260101T00`、`20260101T000000`、`20260101 000000` 均被 Dart 接受；
 * - `2026-1-2 3:4:5` 与首尾空格被 Dart 拒绝，但历史数据里存在，Kotlin 继续接受；
 * - 带 `Z`/偏移的输入是 UTC 实例，`.toLocal()` 得本机墙钟；
 * - `DateTime(2026,1,1,0,0,0,0,123456).toIso8601String()` = `…T00:00:00.123456`，
 *   `…,123000)` = `…T00:00:00.123`。
 */
class DartTimeParityTest {

    private fun localOf(isoOffset: String): LocalDateTime =
        OffsetDateTime.parse(isoOffset)
            .atZoneSameInstant(ZoneId.systemDefault())
            .toLocalDateTime()

    @Test
    fun `Dart 基础日期格式 20260101 可读为午夜`() {
        assertEquals(LocalDateTime.of(2026, 1, 1, 0, 0), DartTime.tryParseIso("20260101"))
    }

    @Test
    fun `Dart 基础格式小时、满位、空格分隔都可读`() {
        val midnight = LocalDateTime.of(2026, 1, 1, 0, 0)
        assertEquals(midnight, DartTime.tryParseIso("20260101T00"))
        assertEquals(midnight, DartTime.tryParseIso("20260101T0000"))
        assertEquals(midnight, DartTime.tryParseIso("20260101T000000"))
        assertEquals(midnight, DartTime.tryParseIso("20260101T000000.000"))
        assertEquals(midnight, DartTime.tryParseIso("20260101 000000"))
    }

    @Test
    fun `带 Z 的输入按本机时区折算成墙上时刻`() {
        assertEquals(localOf("2026-01-01T00:00:00Z"), DartTime.tryParseIso("2026-01-01T00:00:00Z"))
        // 基础格式 + Z 也是 Dart 接受的形状。
        assertEquals(localOf("2026-01-01T00:00:00Z"), DartTime.tryParseIso("20260101T00Z"))
    }

    @Test
    fun `带正负偏移的输入保持同一瞬间`() {
        val plus8 = DartTime.tryParseIso("2026-01-01T00:00:00+08:00")!!
        val minus5 = DartTime.tryParseIso("2026-01-01T00:00:00-0500")!!
        assertEquals(localOf("2026-01-01T00:00:00+08:00"), plus8)
        assertEquals(localOf("2026-01-01T00:00:00-05:00"), minus5)
        // 同一瞬间可以相差一天，但 epoch 毫秒必须完全一致。
        assertEquals(
            OffsetDateTime.parse("2026-01-01T00:00:00-05:00").toInstant().toEpochMilli(),
            DartTime.toEpochMillis(minus5),
        )
    }

    @Test
    fun `历史宽松格式与首尾空格继续可读`() {
        assertEquals(LocalDateTime.of(2026, 1, 2, 3, 4, 5), DartTime.tryParseIso("2026-1-2 3:4:5"))
        assertEquals(LocalDateTime.of(2026, 1, 2, 3, 4), DartTime.tryParseIso(" 2026-1-2 3:4 "))
        assertEquals(LocalDateTime.of(2026, 1, 1, 0, 0), DartTime.tryParseIso(" 20260101 "))
    }

    @Test
    fun `微秒非零时按 Dart 输出六位、否则三位`() {
        assertEquals(
            "2026-01-01T00:00:00.123456",
            DartTime.toIso(DartTime.tryParseIso("2026-01-01T00:00:00.123456")!!),
        )
        assertEquals(
            "2026-01-01T00:00:00.123",
            DartTime.toIso(DartTime.tryParseIso("2026-01-01T00:00:00.123")!!),
        )
        assertEquals("2026-01-01T00:00:00.000", DartTime.toIso(LocalDateTime.of(2026, 1, 1, 0, 0)))
        // 1 毫秒 = 1000 微秒 → Dart 输出 `.001`（三位）。
        assertEquals(
            "2026-01-01T00:00:00.001",
            DartTime.toIso(LocalDateTime.of(2026, 1, 1, 0, 0, 0, 1_000_000)),
        )
        // 纳秒被 Dart 的微秒精度截断：123456789ns → `.123456`。
        assertEquals(
            "2026-01-01T00:00:00.123456",
            DartTime.toIso(LocalDateTime.of(2026, 1, 1, 0, 0, 0, 123_456_789)),
        )
    }

    @Test
    fun `写出永远本地无偏移`() {
        val fromUtc = DartTime.tryParseIso("2026-01-01T00:00:00.000Z")!!
        val text = DartTime.toIso(fromUtc)
        assertFalse("不应带 Z：$text", text.endsWith("Z"))
        assertTrue(text.matches(Regex("""\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,6}""")))
        // 往返稳定：再读回同一墙钟。
        assertEquals(fromUtc, DartTime.tryParseIso(text))
    }

    @Test
    fun `坏输入一律返回 null 不抛`() {
        assertNull(DartTime.tryParseIso(null))
        assertNull(DartTime.tryParseIso(""))
        assertNull(DartTime.tryParseIso("   "))
        assertNull(DartTime.tryParseIso("abc"))
        assertNull(DartTime.tryParseIso("2026-01-01T"))
        assertNull(DartTime.tryParseIso("2026-01-01T00:00:00+8"))
        assertNull(DartTime.tryParseIso("2026010"))
    }

    @Test
    fun `闰日与越界月日按 Dart 构造函数归一`() {
        // Dart 实证：'"2023-02-29"` → 2023-03-01；'"2026-13-05"` → 2027-01-05。
        assertEquals(LocalDateTime.of(2023, 3, 1, 0, 0), DartTime.tryParseIso("2023-02-29"))
        assertEquals(LocalDateTime.of(2027, 1, 5, 0, 0), DartTime.tryParseIso("2026-13-05"))
    }
}
