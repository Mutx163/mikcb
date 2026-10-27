package com.mutx163.qingyu.pages.diagnostics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 性能报告页模型层测试（源：`lib/screens/perf_report_screen.dart`）。
 *
 * 期望值从 Dart 源手推：
 * - 概览卡：`'${totals['janky'] ?? 0} / ${totals['frames'] ?? 0}'`，
 *   副标题三栏 `pages / janky% / budget(nominal, vsync) / rate`，
 *   缺 `probe` 块时三栏都 `?`（Dart 注释：宁可显示没量到，也不拿 0 填假阈值）；
 * - 每页排行：`'${fps ?? '?'} fps   $janky/$frames'`，
 *   `'build worst ${worstBuildMs}/${avgBuildMs} ms  raster …  first …  cpu …  rss … KB'`，
 *   强调色档位 `ratio >= 0.25 红 / >= 0.05 黄 / 否则绿`；
 * - 启动阶段：`'${stepMs} ms'` + `'since start ${totalMs} ms'`。
 *
 * 这页在 Dart 里刻意全英文（避免硬编码中文棘轮上涨），所以没有 ARB 对拍，
 * 文案常量在 [PerfReportStrings] 里逐字抄。
 */
class PerfReportModelTest {

    private fun sampleSnapshot(): Map<String, Any?> = linkedMapOf(
        "pages" to listOf(
            linkedMapOf(
                "page" to "home",
                "fps" to 59.9,
                "janky" to 30,
                "frames" to 100,
                "worstBuildMs" to 12.3,
                "avgBuildMs" to 8.0,
                "worstRasterMs" to 9.5,
                "avgRasterMs" to 4.0,
                "firstFrameMs" to 123.4,
                "cpuMs" to 900,
                "rssDeltaKb" to 2048,
                "verdict" to "ui-bound",
            ),
            linkedMapOf(
                "page" to "logs",
                "frames" to 0,
                "janky" to 0,
                "verdict" to "weird",
            ),
        ),
        "startup" to listOf(
            linkedMapOf("phase" to "engine", "stepMs" to 120.0, "totalMs" to 300.0),
        ),
        "totals" to linkedMapOf(
            "pages" to 2,
            "janky" to 30,
            "frames" to 100,
            "jankyPct" to "30.0",
        ),
        "probe" to linkedMapOf(
            "budgetMs" to 8.3,
            "nominalMs" to 8.0,
            "observedVsyncMs" to 16.7,
        ),
        "refreshRateHz" to 120.0,
    )

    @Test
    fun `概览卡是 janky 比 总帧数 加判据三栏`() {
        val state = buildPerfReportViewState(sampleSnapshot())

        assertEquals("30 / 100", state.summaryText)
        assertEquals("janky / total frames", state.summaryTitle)
        assertEquals(
            "pages 2  janky 30.0%  budget 8.3ms (nominal 8.0ms, vsync 16.7ms)  rate 120Hz",
            state.summarySubtitle,
        )
    }

    @Test
    fun `缺 probe 块时三栏都是问号而不是零`() {
        val snapshot = sampleSnapshot().toMutableMap()
        snapshot.remove("probe")

        val state = buildPerfReportViewState(snapshot)

        assertEquals(
            "pages 2  janky 30.0%  budget ?ms (nominal ?ms, vsync ?ms)  rate 120Hz",
            state.summarySubtitle,
        )
    }

    @Test
    fun `每页排行把 fps 与帧数拼在一行`() {
        val state = buildPerfReportViewState(sampleSnapshot())
        val first = state.pageRows[0]

        assertEquals("home", first.page)
        // Dart：`'${row['fps'] ?? '?'} fps   $janky/$frames'`
        assertEquals("59.9 fps   30/100", first.details)
        assertEquals(
            "build worst 12.3/8.0 ms  raster 9.5/4.0 ms  first 123.4 ms  cpu 900 ms  rss 2048 KB",
            first.subtitle,
        )
        assertEquals(PerfVerdict.UI_BOUND, first.verdict)
        assertEquals(PerfAccent.RED, first.accent)
        assertEquals(0.3, first.jankRatio, 0.000001)
    }

    @Test
    fun `缺字段时用问号占位且零帧不算卡顿`() {
        val state = buildPerfReportViewState(sampleSnapshot())
        val second = state.pageRows[1]

        assertEquals("logs", second.page)
        assertEquals("? fps   0/0", second.details)
        assertEquals(
            "build worst ?/? ms  raster ?/? ms  first ? ms  cpu ? ms  rss ? KB",
            second.subtitle,
        )
        assertEquals(PerfVerdict.UNKNOWN, second.verdict)
        assertEquals(PerfAccent.GREEN, second.accent)
        assertEquals(0.0, second.jankRatio, 0.000001)
    }

    @Test
    fun `强调色档位按四分之一与二十分之一两条线`() {
        assertEquals(PerfAccent.RED, perfAccentFor(0.25))
        assertEquals(PerfAccent.RED, perfAccentFor(0.9))
        assertEquals(PerfAccent.YELLOW, perfAccentFor(0.05))
        assertEquals(PerfAccent.YELLOW, perfAccentFor(0.249))
        assertEquals(PerfAccent.GREEN, perfAccentFor(0.049))
        assertEquals(PerfAccent.GREEN, perfAccentFor(0.0))
    }

    @Test
    fun `verdict 字符串映射四种图标语义`() {
        assertEquals(PerfVerdict.UI_BOUND, perfVerdictOf("ui-bound"))
        assertEquals(PerfVerdict.RASTER_BOUND, perfVerdictOf("raster-bound"))
        assertEquals(PerfVerdict.BOTH, perfVerdictOf("both"))
        assertEquals(PerfVerdict.UNKNOWN, perfVerdictOf("nonsense"))
        assertEquals(PerfVerdict.UNKNOWN, perfVerdictOf(null))
    }

    @Test
    fun `启动阶段行是 毫秒 加 since start`() {
        val state = buildPerfReportViewState(sampleSnapshot())
        val row = state.startupRows.single()

        assertEquals("engine", row.phase)
        assertEquals("120.0 ms", row.details)
        assertEquals("since start 300.0 ms", row.subtitle)
    }

    @Test
    fun `没有探针时不是可用态也不铺行`() {
        val state = buildPerfReportViewState(snapshot = null)

        assertFalse(state.isAvailable)
        assertTrue(state.pageRows.isEmpty())
        assertTrue(state.startupRows.isEmpty())
        assertEquals("0 / 0", state.summaryText)
        assertEquals(PerfReportStrings.notInstalled, state.notInstalledText)
    }

    @Test
    fun `没有启动阶段与排行时用两句提示语`() {
        val state = buildPerfReportViewState(
            linkedMapOf("totals" to linkedMapOf("pages" to 0, "janky" to 0, "frames" to 0)),
        )

        assertTrue(state.startupRows.isEmpty())
        assertEquals("No startup phase recorded in this session.", state.noStartupText)
        assertEquals("No page has rendered a frame yet.", state.noPagesText)
    }

    @Test
    fun `清空账本行带观察帧数且缺省是 0`() {
        assertEquals("0 frames", buildPerfReportViewState(sampleSnapshot()).clearLedgerDetails)
        assertEquals(
            "1234 frames",
            buildPerfReportViewState(sampleSnapshot(), observedFrames = 1234L).clearLedgerDetails,
        )
    }

    @Test
    fun `原文报告开关的标题随展开状态变化`() {
        assertEquals(
            "Show raw report",
            buildPerfReportViewState(sampleSnapshot(), showRaw = false).rawToggleText,
        )
        assertEquals(
            "Hide raw report",
            buildPerfReportViewState(sampleSnapshot(), showRaw = true).rawToggleText,
        )
        assertTrue(buildPerfReportViewState(sampleSnapshot(), showRaw = true).rawReportVisible)
    }

    @Test
    fun `Dart 数值文本口径 整数不带小数点 double 整数值带点零`() {
        assertEquals("60", dartNumberText(60))
        assertEquals("60", dartNumberText(60L))
        assertEquals("60.0", dartNumberText(60.0))
        assertEquals("59.9", dartNumberText(59.9))
        assertEquals("", dartNumberText(null))
        assertEquals("?", optionalNumberText(null))
    }

    @Test
    fun `整千分位刷新率固定零位小数`() {
        assertEquals("120", formatWholeNumber(120.0))
        assertEquals("60", formatWholeNumber(59.5))
        assertEquals("?", formatWholeNumber(null))
        assertEquals("unknown", formatWholeNumber("unknown"))
    }
}
