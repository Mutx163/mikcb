package com.mutx163.qingyu.pages.diagnostics

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 探针内核单测（源：`lib/utils/perf_probe.dart` 的纯逻辑部分）。
 *
 * 钉的是**结构契约**：快照键序、`totals` 的算法、未安装时的文本、页面 id 归一化。
 * 这些一漂，差分脚本就会静默少算（而不是报错），所以逐字钉住。
 */
class PerfProbeCoreTest {

    private var clock: Long = 0L

    @After
    fun tearDown() {
        PerfProbeCore.debugReset()
    }

    private fun install(rateHz: Double = 60.0, meta: Map<String, Any?> = emptyMap()): Boolean =
        PerfProbeCore.install(
            nowUs = { clock },
            readCost = { PerfCostReading(null, null) },
            refreshRateHz = { rateHz },
            metaProvider = { meta },
        )

    @Test
    fun `重复安装是空操作`() {
        assertTrue(install())
        assertFalse(install())
        assertTrue(PerfProbeCore.isInstalled)
    }

    @Test
    fun `安装之前的启动打点按原始时间戳补记`() {
        PerfProbeCore.configureClock { clock }
        // 进程刚起来：探针还不存在，这两条只能先缓冲。
        PerfProbeCore.markStartup("mainEnter")
        assertEquals(1, PerfProbeCore.pendingStartupMarkCount)

        clock = 0L
        install()
        assertEquals(0, PerfProbeCore.pendingStartupMarkCount)

        clock = 11_000L
        PerfProbeCore.markStartup("firstFrame")

        assertEquals(
            listOf(
                linkedMapOf("phase" to "mainEnter", "stepMs" to "0.0", "totalMs" to "0.0"),
                linkedMapOf("phase" to "firstFrame", "stepMs" to "11.0", "totalMs" to "11.0"),
            ),
            PerfProbeCore.currentStartup!!.toJson(),
        )
    }

    @Test
    fun `同名启动阶段只记第一次`() {
        PerfProbeCore.configureClock { clock }
        install()
        PerfProbeCore.markStartup("runApp")
        clock = 5_000
        PerfProbeCore.markStartup("runApp")
        assertEquals(1, PerfProbeCore.currentStartup!!.phaseList.size)
    }

    @Test
    fun `快照键序与 Dart 一致 并且 totals 由排行汇总`() {
        PerfProbeCore.configureClock { clock }
        install(
            meta = linkedMapOf(
                "capturedAt" to "2026-10-29T10:00:00.000",
                "isReleaseMode" to false,
                "refreshRateHz" to 60.0,
                "platform" to "android",
                "osKernelVersion" to "16 (API 36)",
                "cpuCount" to 8,
                "appVersion" to "3.4.0+340",
                "deviceModel" to "25060RK16C",
            ),
        )
        PerfProbeCore.beginPage("home")
        // 门槛 16667 × 1.25 = 20834：第一帧 21000 算卡，后两帧合计 12000 不算。
        PerfProbeCore.ingest(buildUs = 21_000, rasterUs = 0)
        clock += 16_667
        PerfProbeCore.ingest(buildUs = 8_000, rasterUs = 4_000)
        clock += 16_667
        PerfProbeCore.ingest(buildUs = 8_000, rasterUs = 4_000)

        val snapshot = PerfProbeCore.snapshotJson()
        assertEquals(
            listOf(
                "schema", "capturedAt", "isReleaseMode", "refreshRateHz", "platform",
                "osKernelVersion", "cpuCount", "appVersion", "deviceModel",
                "probe", "startup", "totals", "pages",
            ),
            snapshot.keys.toList(),
        )
        assertEquals(PerfProbeCore.SCHEMA_VERSION, snapshot["schema"])
        assertEquals(
            linkedMapOf(
                "budgetMs" to "16.7",
                "nominalMs" to "16.7",
                "observedVsyncMs" to "?",
            ),
            snapshot["probe"],
        )
        assertEquals(
            linkedMapOf("pages" to 1, "frames" to 3L, "janky" to 1L, "jankyPct" to "33.3"),
            snapshot["totals"],
        )
        @Suppress("UNCHECKED_CAST")
        val pages = snapshot["pages"] as List<Map<String, Any?>>
        assertEquals(1, pages.size)
        assertEquals("home", pages[0]["page"])
        assertEquals(3L, pages[0]["frames"])
        assertEquals(1L, pages[0]["janky"])
    }

    @Test
    fun `未安装时快照仍给出完整结构 但判据三栏是问号`() {
        val snapshot = PerfProbeCore.snapshotJson()
        assertEquals(
            linkedMapOf(
                "budgetMs" to "?",
                "nominalMs" to "?",
                "observedVsyncMs" to "?",
            ),
            snapshot["probe"],
        )
        @Suppress("UNCHECKED_CAST")
        assertTrue((snapshot["pages"] as List<*>).isEmpty())
        @Suppress("UNCHECKED_CAST")
        assertTrue((snapshot["startup"] as List<*>).isEmpty())
        assertEquals(
            linkedMapOf("pages" to 0, "frames" to 0L, "janky" to 0L, "jankyPct" to "0.0"),
            snapshot["totals"],
        )
    }

    @Test
    fun `文本报告三段齐全 未安装时给一行说明`() {
        assertEquals(
            "[perf-probe] not installed (release build without PERF_PROBE)\n",
            PerfProbeCore.reportText(),
        )

        PerfProbeCore.configureClock { clock }
        install(
            meta = linkedMapOf(
                "appVersion" to "3.4.0+340",
                "deviceModel" to "25060RK16C",
                "platform" to "android",
                "osKernelVersion" to "16 (API 36)",
                "refreshRateHz" to 60.0,
            ),
        )
        clock = 7_000
        PerfProbeCore.markStartup("firstFrame")
        PerfProbeCore.beginPage("home")
        PerfProbeCore.ingest(buildUs = 8_000, rasterUs = 4_000)

        val text = PerfProbeCore.reportText()
        assertTrue(text.startsWith("[perf-startup] phase=firstFrame stepMs=0.0 totalMs=0.0\n"))
        assertTrue(text.contains("[perf-page] report budgetMs=16.7"))
        assertTrue(text.contains("[perf-page] page=home frames=1"))
        assertTrue(
            text.endsWith(
                "[perf-probe] meta app=3.4.0+340 host=25060RK16C platform=android " +
                    "kernel=16 (API 36) rateHz=60.0\n",
            ),
        )
    }

    @Test
    fun `页面 id 归一化`() {
        assertEquals("settings", normalizePageId("/settings"))
        assertEquals("settings", normalizePageId("  settings  "))
        // 泛型参数是 payload 类型，不是页面身份
        assertEquals("AddCoursePage", normalizePageId("lib.AddCoursePage<Course>"))
        // 深链多级路径只留最后一段
        assertEquals("testing", normalizePageId("settings/live/testing"))
        // 壳的页面 id 本身就是点分形式：**不能**被当成库前缀剥掉，
        // 否则 `b.log` 与 `h.log` 会并成同一个 `log` 行。
        assertEquals("b.general", normalizePageId("b.general"))
        assertEquals("h.perfReport", normalizePageId("/h.perfReport"))
        assertEquals("b.log", normalizePageId("b.log"))
        assertEquals("h.log", normalizePageId("h.log"))
        // 空白折叠：报表行按空白切 token，带换行会把一行劈成两行
        assertEquals("a b", normalizePageId("a\n  b"))
        // 空串先回落 widgetType，再回落 unnamed
        assertEquals("HomeBody", normalizePageId("", "HomeBody"))
        assertEquals(PerfProbeCore.UNNAMED_PAGE, normalizePageId(null))
        assertEquals(PerfProbeCore.UNNAMED_PAGE, normalizePageId("   "))
    }

    @Test
    fun `未安装时切页与收帧都是空操作`() {
        PerfProbeCore.beginPage("home")
        PerfProbeCore.ingest(buildUs = 10_000, rasterUs = 5_000)
        assertEquals(0L, PerfProbeCore.observedFrames())
        assertNull(PerfProbeCore.currentLedger)
    }

    @Test
    fun `切页会归一化行名 回前台重开最后一段`() {
        PerfProbeCore.configureClock { clock }
        install()
        PerfProbeCore.beginPage("/b.general")
        PerfProbeCore.ingest(buildUs = 8_000, rasterUs = 4_000)
        assertEquals("b.general", PerfProbeCore.currentLedger!!.openPageId)

        // 退后台落账 → 开段被清掉；回前台要把最后那一页重新开起来，
        // 否则回前台之后的帧会全记到 boot 头上。
        PerfProbeCore.sealSegment()
        assertEquals(PerfPageLedger.BOOT_PAGE, PerfProbeCore.currentLedger!!.openPageId)
        clock = 60_000_000
        PerfProbeCore.resumeLastPage()
        assertEquals("b.general", PerfProbeCore.currentLedger!!.openPageId)
    }

    @Test
    fun `清空账本同时清掉帧数与启动分段`() {
        PerfProbeCore.configureClock { clock }
        install()
        PerfProbeCore.markStartup("mainEnter")
        PerfProbeCore.beginPage("home")
        PerfProbeCore.ingest(buildUs = 8_000, rasterUs = 4_000)
        assertEquals(1L, PerfProbeCore.observedFrames())

        PerfProbeCore.reset()
        assertEquals(0L, PerfProbeCore.observedFrames())
        assertTrue(PerfProbeCore.currentStartup!!.phaseList.isEmpty())
        assertTrue(PerfProbeCore.currentLedger!!.rankedBy().isEmpty())
    }
}
