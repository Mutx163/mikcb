package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 面板展示模型的**纯逻辑**用例（L0 可跑）。
 *
 * 覆盖 `WarehouseImportLogPage` 里除「布局 / 配色观感 / 横滚手感」以外的全部计算：
 * 分组与组头、行格式、强调判定、分享文本拼装。UI 那一层因此只剩「铺列表 + 映射颜色 +
 * 发 Intent」——它不重现这里的任何一条规则（源码守卫 `WarehouseImportLogEntryGuardTest` 盯着）。
 */
class WarehouseImportLogViewTest {

    // ---------------------------------------------------------------
    // 1. 分组与组头
    // ---------------------------------------------------------------

    @Test
    fun `sections keep run order and number headers from one`() {
        val failed = run("auto-1", failed = true, entries = listOf(entry()))
        val ended = run("auto-2", finished = true, endReason = "complete", entries = listOf(entry()))
        val running = run("auto-3", entries = listOf(entry()))

        val sections = WarehouseImportLogView.buildLogSections(snapshotOf(failed, ended, running))

        assertEquals(3, sections.size)
        assertEquals(
            listOf("RUN 1 · FAILED", "RUN 2 · COMPLETE", "RUN 3 · RUNNING"),
            sections.map { it.title },
        )
        assertEquals(listOf(1, 1, 1), sections.map { it.lines.size })
    }

    @Test
    fun `finished run without end reason falls back to OK and keeps reasons otherwise`() {
        val noReason = run("auto-1", finished = true, endReason = null)
        val timeout = run("auto-2", finished = true, endReason = "timeout")
        val spaced = run("auto-3", finished = true, endReason = "page navigation")

        val titles = WarehouseImportLogView.buildLogSections(snapshotOf(noReason, timeout, spaced))
            .map { it.title }

        assertEquals(listOf("RUN 1 · OK", "RUN 2 · TIMEOUT", "RUN 3 · PAGE_NAVIGATION"), titles)
    }

    @Test
    fun `empty snapshot has no sections`() {
        assertTrue(WarehouseImportLogView.buildLogSections(snapshotOf()).isEmpty())
    }

    // ---------------------------------------------------------------
    // 2. 行格式
    // ---------------------------------------------------------------

    @Test
    fun `line is timestamp plus category plus key value pairs`() {
        val line = WarehouseImportLogView.formatEntryLine(
            entry(
                category = WarehouseLogCategory.MACRO_STEP,
                fields = linkedMapOf(
                    "step" to "1/3",
                    "type" to "click",
                    "selector" to "#login .primary",
                ),
            ),
        )

        assertTrue(
            "line must start with HH:mm:ss.SSS then the category: $line",
            Regex("""^\d{2}:\d{2}:\d{2}\.\d{3} MACRO_STEP """).containsMatchIn(line),
        )
        assertTrue("field order must be preserved: $line", line.endsWith("step=1/3 type=click selector=#login .primary"))
    }

    @Test
    fun `long values are never truncated`() {
        val longSelector = "div." + "x".repeat(300) + " > button"
        val line = WarehouseImportLogView.formatEntryLine(
            entry(fields = linkedMapOf("selector" to longSelector)),
        )

        assertTrue("long selector must survive for the horizontal scroll: ${line.length}", line.contains(longSelector))
    }

    @Test
    fun `newlines inside values are folded into spaces`() {
        val line = WarehouseImportLogView.formatEntryLine(
            entry(category = WarehouseLogCategory.SCRIPT, fields = linkedMapOf("message" to "first\nsecond")),
        )

        assertTrue("one entry must stay on one line: $line", line.contains("message=first second"))
        assertFalse("no raw newline may survive: $line", line.contains("\n"))
    }

    // ---------------------------------------------------------------
    // 3. 强调判定
    // ---------------------------------------------------------------

    @Test
    fun `emphasis truth table`() {
        assertEquals(
            LogEmphasis.ERROR,
            WarehouseImportLogView.logEmphasis(entry(category = WarehouseLogCategory.FAILURE, fields = linkedMapOf("code" to "x"))),
        )
        assertEquals(
            LogEmphasis.ERROR,
            WarehouseImportLogView.logEmphasis(entry(category = WarehouseLogCategory.INTERNAL, fields = linkedMapOf("where" to "write"))),
        )
        assertEquals(
            LogEmphasis.ERROR,
            WarehouseImportLogView.logEmphasis(entry(fields = linkedMapOf("status" to "failed"))),
        )
        assertEquals(
            LogEmphasis.WARN,
            WarehouseImportLogView.logEmphasis(entry(fields = linkedMapOf("status" to "skipped"))),
        )
        assertEquals(
            LogEmphasis.WARN,
            WarehouseImportLogView.logEmphasis(entry(fields = linkedMapOf("skipReason" to "element_not_found"))),
        )
        assertEquals(
            LogEmphasis.NORMAL,
            WarehouseImportLogView.logEmphasis(entry(fields = linkedMapOf("status" to "ok"))),
        )
        assertEquals(
            LogEmphasis.NORMAL,
            WarehouseImportLogView.logEmphasis(entry(category = WarehouseLogCategory.SCRIPT, fields = linkedMapOf("level" to "log"))),
        )
        assertEquals(
            LogEmphasis.NORMAL,
            WarehouseImportLogView.logEmphasis(entry(category = WarehouseLogCategory.BRIDGE, fields = linkedMapOf("dir" to "req"))),
        )
        // status 是脚本写进日志的字符串：大小写/空白不该让判定翻车。
        assertEquals(
            LogEmphasis.WARN,
            WarehouseImportLogView.logEmphasis(entry(fields = linkedMapOf("status" to " SKIPPED "))),
        )
    }

    @Test
    fun `every entry of a failed run is marked as error`() {
        val failed = run(
            "auto-1",
            failed = true,
            entries = listOf(
                entry(fields = linkedMapOf("status" to "ok")),
                entry(category = WarehouseLogCategory.BRIDGE, fields = linkedMapOf("dir" to "req")),
            ),
        )

        val lines = WarehouseImportLogView.buildLogSections(snapshotOf(failed)).single().lines

        assertEquals(listOf(LogEmphasis.ERROR, LogEmphasis.ERROR), lines.map { it.emphasis })
    }

    // ---------------------------------------------------------------
    // 4. 分享文本
    // ---------------------------------------------------------------

    @Test
    fun `share text takes the subject template and replaces the log placeholder`() {
        val snapshot = snapshotOf(run("auto-1", entries = listOf(entry(tsMs = FIXED_NOW))))
        val share = WarehouseImportLogView.buildShareText(
            snapshot = snapshot,
            deviceInfo = DEVICE,
            shareTextTemplate = "Opening line. {log} Closing line.",
            shareSubjectTemplate = "  Subject line  ",
            nowMs = FIXED_NOW,
        )

        assertEquals("Subject line", share.subject)
        assertTrue("template must stay verbatim: ${share.text}", share.text.startsWith("Opening line. "))
        assertTrue("export body must be substituted into the template", share.text.contains("model=Pixel 7"))
        assertTrue("template tail must stay after the body", share.text.endsWith(" Closing line."))
    }

    @Test
    fun `share text without placeholder prepends the template as a paragraph`() {
        val snapshot = snapshotOf(run("auto-1", entries = listOf(entry(tsMs = FIXED_NOW))))
        val share = WarehouseImportLogView.buildShareText(
            snapshot = snapshot,
            deviceInfo = DEVICE,
            shareTextTemplate = "Header only.",
            shareSubjectTemplate = "Subject",
            nowMs = FIXED_NOW,
        )

        assertTrue("header paragraph first: ${share.text.take(40)}", share.text.startsWith("Header only.\n\n"))
        assertTrue("body follows the header", share.text.contains("version=1.2.3-debug"))
    }

    @Test
    fun `share text never carries plaintext secrets`() {
        val secretRun = run(
            "auto-1",
            entries = listOf(
                entry(
                    tsMs = FIXED_NOW,
                    category = WarehouseLogCategory.FAILURE,
                    fields = linkedMapOf(
                        "password" to "hunter2",
                        "Cookie" to "JSESSIONID=abcd",
                        "account" to "Abc123456",
                        "url" to "https://jw.example.edu/xskb/list?token=xyz",
                    ),
                ),
            ),
        )
        val share = WarehouseImportLogView.buildShareText(
            snapshot = snapshotOf(secretRun),
            deviceInfo = DEVICE,
            shareTextTemplate = "",
            shareSubjectTemplate = "Subject",
            nowMs = FIXED_NOW,
        )

        assertTrue("share text must not be blank", share.text.isNotBlank())
        listOf("hunter2", "Abc123456", "abcd", "xyz", "/xskb").forEach { leaked ->
            assertFalse("plaintext leaked into the share text: $leaked", share.text.contains(leaked))
        }
        // 正向一侧：不是靠「什么都不记」过关。
        assertTrue("password must be masked: ${share.text}", share.text.contains("password=***"))
        assertTrue("account keeps its mask shape", share.text.contains("A*******6"))
        assertTrue("host-only url survives", share.text.contains("https://jw.example.edu"))
    }

    @Test
    fun `share text works for an empty snapshot`() {
        val share = WarehouseImportLogView.buildShareText(
            snapshot = snapshotOf(),
            deviceInfo = DEVICE,
            shareTextTemplate = "Header.",
            shareSubjectTemplate = "Subject",
            nowMs = FIXED_NOW,
        )

        assertTrue(share.text.startsWith("Header.\n\n"))
        assertTrue("export header still present", share.text.contains("verdict=running"))
        assertEquals("Subject", share.subject)
    }

    // ---------------------------------------------------------------
    // 构造器
    // ---------------------------------------------------------------

    private fun entry(
        tsMs: Long = FIXED_NOW,
        category: WarehouseLogCategory = WarehouseLogCategory.MACRO_STEP,
        fields: Map<String, String> = linkedMapOf("step" to "1/3", "status" to "ok"),
    ) = WarehouseImportLogEntry(tsMs = tsMs, category = category, fields = fields)

    private fun run(
        runId: String,
        entries: List<WarehouseImportLogEntry> = emptyList(),
        endReason: String? = null,
        failed: Boolean = false,
        finished: Boolean = false,
    ) = WarehouseImportLogRun(
        runId = runId,
        school = "",
        adapterId = "",
        entries = entries,
        endReason = endReason,
        failed = failed,
        finished = finished,
    )

    private fun snapshotOf(vararg runs: WarehouseImportLogRun) = WarehouseImportLogSnapshot(
        runs = runs.toList(),
        lastFailureReason = null,
    )

    private companion object {
        /** 固定时钟：时间列格式之外不依赖真实时间（行内断言只判结构）。 */
        const val FIXED_NOW = 1_700_000_000_000L

        val DEVICE = WarehouseDeviceInfo(
            model = "Pixel 7",
            androidVersion = "14",
            appVersion = "1.2.3-debug",
        )
    }
}
