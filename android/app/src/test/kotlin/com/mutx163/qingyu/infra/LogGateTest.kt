package com.mutx163.qingyu.infra

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalTime

/**
 * 日志门控单测。
 *
 * 期望值来源：
 * - Dart 逐行（app_log_service.dart）：门控语义、取模节流、截断核、注入规则；
 * - Dart 测试口径（app_update_dot_share 不相关；时间格式照 async_utils.dart 手算）；
 * - 人推边界：未知级别、空 extras、长 CJK 尾部 trim。
 */
class LogGateTest {

    // ---------- normalizeLogLevel（Dart _normalizeLevel） ----------

    @Test
    fun `normalize keeps known levels lowercased`() {
        assertEquals("error", normalizeLogLevel(" error "))
        assertEquals("warn", normalizeLogLevel("WARN"))
        assertEquals("info", normalizeLogLevel("Info"))
        assertEquals("debug", normalizeLogLevel("Debug"))
        assertEquals("verbose", normalizeLogLevel("VERBOSE"))
    }

    @Test
    fun `normalize falls back to info for unknown or blank`() {
        // 人推边界：未知级别与空串一律 info（Dart default 分支）。
        assertEquals("info", normalizeLogLevel("fatal"))
        assertEquals("info", normalizeLogLevel(""))
        assertEquals("info", normalizeLogLevel("  "))
    }

    // ---------- shouldRecordLog（Dart _shouldRecord） ----------

    @Test
    fun `force skips logging switch but never privacy consent`() {
        // force=true 跳过的是 loggingEnabled，不是 privacyAccepted。
        assertTrue(shouldRecordLog(privacyAccepted = true, loggingEnabled = false, force = true))
        assertFalse(shouldRecordLog(privacyAccepted = false, loggingEnabled = true, force = true))
        assertFalse(shouldRecordLog(privacyAccepted = false, loggingEnabled = false, force = true))
    }

    @Test
    fun `non force requires both switches`() {
        assertTrue(shouldRecordLog(privacyAccepted = true, loggingEnabled = true, force = false))
        assertFalse(shouldRecordLog(privacyAccepted = true, loggingEnabled = false, force = false))
        assertFalse(shouldRecordLog(privacyAccepted = false, loggingEnabled = true, force = false))
    }

    // ---------- shouldAlertWriteFailure（取模节流） ----------

    @Test
    fun `alert every five consecutive failures`() {
        // 人推：1-4 静默，5 告警，6 静默，10 告警。
        assertFalse(shouldAlertWriteFailure(1))
        assertFalse(shouldAlertWriteFailure(4))
        assertTrue(shouldAlertWriteFailure(5))
        assertFalse(shouldAlertWriteFailure(6))
        assertTrue(shouldAlertWriteFailure(10))
    }

    // ---------- retainedLogTail（Dart _trimIfNeeded） ----------

    @Test
    fun `no trim when within limit`() {
        assertNull(retainedLogTail("abc", maxChars = 10))
        assertNull(retainedLogTail("0123456789", maxChars = 10))
    }

    @Test
    fun `retains second half and trims leading whitespace`() {
        // maxChars=10 → retain 5；"0123456789ABCDE"(15) 尾部 5 字符 "ABCDE"。
        assertEquals("ABCDE", retainedLogTail("0123456789ABCDE", maxChars = 10))
        // 人推边界：尾部前导空白被 trimStart 吃掉。
        assertEquals("ABCDE", retainedLogTail("0123456789   ABCDE", maxChars = 10))
    }

    // ---------- injectSourceIntoSections ----------

    @Test
    fun `injects source after time line`() {
        val body = "time=1000\ncategory=Sync\nmessage=hi"
        assertEquals("time=1000\nsource=app\ncategory=Sync\nmessage=hi", injectSourceIntoSections(body, "app"))
    }

    @Test
    fun `keeps sections that already carry source`() {
        val body = "time=1\nsource=native\nmessage=a\n\ntime=2\nmessage=b"
        assertEquals(
            "time=1\nsource=native\nmessage=a\n\ntime=2\nsource=app\nmessage=b",
            injectSourceIntoSections(body, "app"),
        )
    }

    @Test
    fun `prepends source when no time line`() {
        assertEquals("source=app\nmessage=lonely", injectSourceIntoSections("message=lonely", "app"))
    }

    @Test
    fun `drops empty sections`() {
        assertEquals("source=app\nmessage=b", injectSourceIntoSections("\n\nmessage=b\n\n", "app"))
    }

    // ---------- formatLogTimestamp / timeString ----------

    @Test
    fun `formatLogTimestamp pads fields`() {
        // 人推：LocalTime(8,5,9,123ms) → "[08:05:09.123]"。
        assertEquals("[08:05:09.123]", formatLogTimestamp(LocalTime.of(8, 5, 9, 123_000_000)))
        assertEquals("[00:00:00.000]", formatLogTimestamp(LocalTime.of(0, 0, 0, 0)))
    }

    @Test
    fun `update log entry time string`() {
        assertEquals("08:05:09", UpdateLogEntry(0L, 8, 5, 9, "m").timeString)
    }

    // ---------- buildLogEntryPayload ----------

    @Test
    fun `payload shape redacts personal fields on every outlet`() {
        // Dart 逐行：message/error 走正则脱敏；命中表键的 extras 整值抹。
        val payload = buildLogEntryPayload(
            level = "info",
            category = "Sync",
            message = "hello course=高等数学 id=12",
            extras = linkedMapOf("code" to 500, "courseName" to "高等数学"),
            error = "bad course=y",
            stackTrace = "trace line",
            timeMillis = 1000L,
        )
        val expected = "time=1000\n" +
            "level=info\n" +
            "source=app\n" +
            "category=Sync\n" +
            "message=hello course=** id=12\n" +
            "extras=\n" +
            "  code=500\n" +
            "  courseName=**\n" +
            "error=bad course=**\n" +
            "stackTrace=\n" +
            "trace line\n" +
            "\n"
        assertEquals(expected, payload)
    }

    @Test
    fun `payload without optionals ends with blank line`() {
        // 人推边界：无 extras/error/stack 时仍以空行结尾（段落分隔符）。
        val payload = buildLogEntryPayload(
            level = "debug",
            category = "Demo",
            message = "plain",
            timeMillis = 7L,
        )
        assertEquals("time=7\nlevel=debug\nsource=app\ncategory=Demo\nmessage=plain\n\n", payload)
    }
}
