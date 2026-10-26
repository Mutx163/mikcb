package com.mutx163.qingyu.infra

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 诊断日志解析单测。
 *
 * 期望值来源：
 * - Dart 测试抄录（test/logging/diagnostics_log_parser_test.dart）：sampleLog
 *   的三段解析、native 推断、helpers 四组行为；
 * - Dart 逐行（diagnostics_log_parser.dart）：severity 别名、inferred 标记、
 *   detailEntries 排除集；
 * - 人推边界：severity 别名 err/trace、miui_live/diagnostics_ 归属、
 *   空段跳过、无头 body 透传、非法 millis。
 */
class DiagnosticsLogTest {

    private val sampleLog = """
Diagnostics Export
exportedAt=1000
----
time=1000
level=error
source=app
category=Sync
message=upload failed
extras=
  code=500

time=2000
level=warn
source=native
category=live_update
message=delayed

time=3000
category=InfoCat
message=plain info without level
""".trim()

    // ---------- parseDiagnosticsLog（Dart 测试抄录） ----------

    @Test
    fun `blank input returns fallback titled empty snapshot`() {
        val parsed = parseDiagnosticsLog("   ", fallbackTitle = "Fallback")
        assertEquals("Fallback", parsed.title)
        assertTrue(parsed.entries.isEmpty())
        assertEquals("", parsed.fullText)
    }

    @Test
    fun `parses header body and entries`() {
        val parsed = parseDiagnosticsLog(sampleLog)
        assertEquals("Diagnostics Export", parsed.title)
        assertEquals("1000", parsed.headerEntries["exportedAt"])
        assertEquals(3, parsed.entries.size)

        val first = parsed.entries[0]
        assertEquals(DiagnosticsLogLevel.ERROR, first.level)
        assertFalse(first.isLevelInferred)
        assertEquals("Sync", first.category)
        assertEquals("upload failed", first.message)
        assertEquals("app", first.sourceKey)
        assertFalse(first.isNativeSource)
        assertEquals(1000L, first.timeMillis)
        assertTrue(first.formattedTime != null)

        val second = parsed.entries[1]
        assertEquals(DiagnosticsLogLevel.WARN, second.level)
        assertEquals("native", second.sourceKey)
        assertTrue(second.isNativeSource)

        val third = parsed.entries[2]
        assertEquals(DiagnosticsLogLevel.INFO, third.level)
        assertTrue(third.isLevelInferred)
    }

    @Test
    fun `infers native source from live_update category without source field`() {
        val parsed = parseDiagnosticsLog("title\n----\ntime=1\ncategory=live_update_push\nmessage=hello\n")
        assertEquals("native", parsed.entries.single().sourceKey)
    }

    @Test
    fun `infers error level from message keywords`() {
        val parsed = parseDiagnosticsLog("title\n----\ntime=1\ncategory=Demo\nmessage=something failed badly\n")
        val entry = parsed.entries.single()
        assertEquals(DiagnosticsLogLevel.ERROR, entry.level)
        assertTrue(entry.isLevelInferred)
    }

    // ---------- helpers（Dart 测试抄录） ----------

    @Test
    fun `extract body strips header`() {
        val body = extractDiagnosticsLogBody(sampleLog)
        assertFalse(body.contains("Diagnostics Export"))
        assertTrue(body.contains("upload failed"))
    }

    @Test
    fun `filter sort and count entries`() {
        val parsed = parseDiagnosticsLog(sampleLog)
        val errors = filterDiagnosticsEntries(parsed.entries, DiagnosticsLogLevel.ERROR)
        assertEquals(1, errors.size)
        assertEquals(DiagnosticsLogLevel.ERROR, errors.single().level)

        val descending = sortDiagnosticsEntries(parsed.entries, ascending = false)
        assertEquals(3000L, descending.first().timeMillis)
        assertEquals(1000L, descending.last().timeMillis)

        val counts = countDiagnosticsLevels(parsed.entries)
        assertEquals(3, counts[DiagnosticsLogLevel.ALL])
        assertEquals(1, counts[DiagnosticsLogLevel.ERROR])
        assertEquals(1, counts[DiagnosticsLogLevel.WARN])
        assertEquals(1, counts[DiagnosticsLogLevel.INFO])
    }

    @Test
    fun `build filtered raw text keeps header`() {
        val parsed = parseDiagnosticsLog(sampleLog)
        val filtered = filterDiagnosticsEntries(parsed.entries, DiagnosticsLogLevel.ERROR)
        val raw = buildFilteredDiagnosticsRawText(parsed, filtered)
        assertTrue(raw.contains("Diagnostics Export"))
        assertTrue(raw.contains("----"))
        assertTrue(raw.contains("upload failed"))
        assertFalse(raw.contains("plain info without level"))
    }

    @Test
    fun `append body merges new entries`() {
        val current = parseDiagnosticsLog(sampleLog)
        val appended = "time=4000\nlevel=debug\ncategory=Demo\nmessage=extra\n"
        val merged = appendDiagnosticsLogBody(
            current,
            appended,
            mergedFullText = current.fullText + "\n\n" + appended,
        )
        assertEquals(4, merged.entries.size)
        assertEquals(DiagnosticsLogLevel.DEBUG, merged.entries.last().level)
        assertEquals("extra", merged.entries.last().message)
    }

    @Test
    fun `format millis returns null for invalid input`() {
        assertNull(formatDiagnosticsMillis(null))
        assertNull(formatDiagnosticsMillis("abc"))
        assertTrue(formatDiagnosticsMillis("1000") != null)
        // 人推：输出形态 yyyy-MM-dd HH:mm:ss。
        assertTrue(
            Regex("\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}")
                .matches(formatDiagnosticsMillis("1000")!!),
        )
    }

    @Test
    fun `snapshot copy replaces selected fields`() {
        val parsed = parseDiagnosticsLog(sampleLog)
        val copied = parsed.copy(title = "New title", entries = emptyList())
        assertEquals("New title", copied.title)
        assertTrue(copied.entries.isEmpty())
        assertEquals(parsed.fullText, copied.fullText)
    }

    // ---------- 人推边界 ----------

    @Test
    fun `severity aliases resolve`() {
        // Dart 逐行：severity 与 level 同表；err→error，trace→verbose。
        val parsed = parseDiagnosticsLog(
            "t\n----\ntime=1\nseverity=err\ncategory=A\nmessage=a\n\n" +
                "time=2\nseverity=trace\ncategory=B\nmessage=b\n",
        )
        assertEquals(DiagnosticsLogLevel.ERROR, parsed.entries[0].level)
        assertEquals(DiagnosticsLogLevel.VERBOSE, parsed.entries[1].level)
    }

    @Test
    fun `miui and diagnostics categories infer native source`() {
        val parsed = parseDiagnosticsLog(
            "t\n----\ntime=1\ncategory=miui_live_push\nmessage=a\n\n" +
                "time=2\ncategory=diagnostics_foo\nmessage=b\n\n" +
                "time=3\ncategory=Sync\nmessage=c\n",
        )
        assertEquals("native", parsed.entries[0].sourceKey)
        assertEquals("native", parsed.entries[1].sourceKey)
        assertEquals("app", parsed.entries[2].sourceKey)
    }

    @Test
    fun `throwable presence forces error level`() {
        // Dart 逐行：含 throwable 键即 error，无需关键词。
        val parsed = parseDiagnosticsLog("t\n----\ntime=1\ncategory=Sync\nthrowable=boom\n")
        assertEquals(DiagnosticsLogLevel.ERROR, parsed.entries.single().level)
    }

    @Test
    fun `detail entries exclude structural keys but keep extras`() {
        val parsed = parseDiagnosticsLog(sampleLog)
        val keys = parsed.entries[0].detailEntries.map { it.key }
        assertTrue(keys.contains("extras"))
        assertFalse(keys.contains("time"))
        assertFalse(keys.contains("level"))
        assertFalse(keys.contains("source"))
        assertFalse(keys.contains("category"))
        assertFalse(keys.contains("message"))
    }

    @Test
    fun `body without header passes through`() {
        // 人推：无 ---- 分隔时整段即 body。
        assertEquals("hello", extractDiagnosticsLogBody("hello"))
        assertEquals("", extractDiagnosticsLogBody("   "))
    }

    @Test
    fun `filter all returns everything and sort ascending orders by time`() {
        val parsed = parseDiagnosticsLog(sampleLog)
        assertEquals(3, filterDiagnosticsEntries(parsed.entries, DiagnosticsLogLevel.ALL).size)
        val ascending = sortDiagnosticsEntries(parsed.entries, ascending = true)
        assertEquals(1000L, ascending.first().timeMillis)
        assertEquals(3000L, ascending.last().timeMillis)
    }
}
