package com.mutx163.qingyu.pages.diagnostics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 页面性能台账单测（源：`lib/utils/perf_page_ledger.dart`）。
 *
 * **期望值全部从 Dart 源手推**，不是从实现里抄的（TEST-POLICY「纯逻辑」那一行）：
 * * 预算 = `min(上报 16667µs, 实测 8333µs)`，卡顿门槛 = `预算 × 1.25` 再四舍五入
 *   （8333 × 1.25 = 10416.25 → 10416）；
 * * 等效帧率 = `(帧数 - 1) ÷ 跨度`：3 帧跨 33334µs → `2e6 / 33334 = 59.9988` → `60.0`；
 * * 毫秒一律 1 位小数（`33.334ms` 打印成 `33.3`）。
 *
 * 时钟与成本读数都是注入的，所以「页内 CPU 毫秒」这类期望是人手算出来的。
 */
class PerfPageLedgerTest {

    private class FakeClock(var nowUs: Long = 0L)

    private class Cost(var cpuMicros: Long? = null, var rssKb: Long? = null) {
        fun read(): PerfCostReading = PerfCostReading(cpuMicros, rssKb)
    }

    private fun ledger(
        clock: FakeClock = FakeClock(),
        cost: Cost = Cost(),
        rateHz: Double = 60.0,
        minDwellUs: Long = PerfPageLedger.DEFAULT_MIN_DWELL_US,
        supportedRates: List<Double> = emptyList(),
    ): PerfPageLedger = PerfPageLedger(
        nowUs = { clock.nowUs },
        readCost = { cost.read() },
        refreshRateHz = { rateHz },
        minDwellUs = minDwellUs,
        supportedRefreshRatesHz = supportedRates,
    )

    @Test
    fun `还没采到 vsync 时预算按上报刷新率 观测值是问号`() {
        val book = ledger(rateHz = 120.0)

        // 1e6 / 120 = 8333.33 → round 8333 → "8.3"
        assertEquals(8_333L, book.budgetUs)
        assertEquals(
            linkedMapOf(
                "budgetMs" to "8.3",
                "nominalMs" to "8.3",
                // 没采到样本必须是 '?'，给 0 会被读成「这块屏的帧周期是 0 毫秒」。
                "observedVsyncMs" to "?",
            ),
            book.budgetJson(),
        )
    }

    @Test
    fun `实测 vsync 只收紧不放宽 卡顿门槛按收紧后的预算算`() {
        val clock = FakeClock()
        val book = ledger(clock = clock, rateHz = 60.0)

        // 第一帧：还没有上一个 vsync，采不到样本 → 门槛仍是 16667 × 1.25 = 20834。
        book.ingest(buildUs = 7_000, rasterUs = 3_000, vsyncUs = 1_000_000)
        // 第二帧：间隔 8333µs（120Hz）→ 预算收紧到 8333，门槛 10416。
        clock.nowUs = 16_667
        book.ingest(buildUs = 7_000, rasterUs = 4_000, vsyncUs = 1_008_333)

        assertEquals(8_333L, book.budgetUs)
        assertEquals("8.3", book.budgetJson()["budgetMs"])
        assertEquals("16.7", book.budgetJson()["nominalMs"])
        assertEquals("8.3", book.budgetJson()["observedVsyncMs"])

        val row = book.rankedBy().single()
        assertEquals(2L, row.frames)
        // 第一帧合计 10000（< 20834）不算卡；第二帧合计 11000（> 10416）算卡。
        assertEquals(1L, row.jankyFrames)
    }

    @Test
    fun `等效帧率用间隔数而不是帧数`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)
        book.beginPage("home")
        book.ingest(buildUs = 8_000, rasterUs = 4_000)
        clock.nowUs = 16_667
        book.ingest(buildUs = 8_000, rasterUs = 4_000)
        clock.nowUs = 33_334
        book.ingest(buildUs = 8_000, rasterUs = 4_000)

        val row = book.rankedBy().single()
        // 跨度 = 33334µs；(3-1) * 1e6 / 33334 = 59.9988 → "60.0"
        assertEquals(33_334L, row.spanUs)
        assertEquals(59.99880024, row.fps!!, 1e-6)
        assertEquals("60.0", row.toJson()["fps"])
        assertEquals("33.3", row.toJson()["spanMs"])
        assertEquals("0.0", row.toJson()["jankyPct"])
    }

    @Test
    fun `排行先按掉帧数再按帧数最后按出现顺序`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)

        // a：3 帧、2 帧掉帧（每帧 21000 > 门槛 20834）
        book.beginPage("a")
        repeat(2) {
            book.ingest(buildUs = 21_000, rasterUs = 0)
            clock.nowUs += 16_667
        }
        book.ingest(buildUs = 10_000, rasterUs = 8_000)
        clock.nowUs += 200_000

        // b：2 帧、1 帧掉帧
        book.beginPage("b")
        book.ingest(buildUs = 21_000, rasterUs = 0)
        clock.nowUs += 16_667
        book.ingest(buildUs = 10_000, rasterUs = 8_000)
        clock.nowUs += 200_000

        // c：1 帧、1 帧掉帧（与 b 同掉帧数，帧数更少 ⇒ 排在 b 之后）
        book.beginPage("c")
        book.ingest(buildUs = 21_000, rasterUs = 0)

        assertEquals(listOf("a", "b", "c"), book.rankedBy().map { it.pageId })
        assertEquals(listOf(2L, 1L, 1L), book.rankedBy().map { it.jankyFrames })
        assertEquals(listOf(3L, 2L, 1L), book.rankedBy().map { it.frames })
    }

    @Test
    fun `同掉帧同帧数时按首次出现顺序`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)
        for (id in listOf("second", "first")) {
            book.beginPage(id)
            book.ingest(buildUs = 21_000, rasterUs = 0)
            clock.nowUs += 200_000
        }
        assertEquals(listOf("second", "first"), book.rankedBy().map { it.pageId })
    }

    @Test
    fun `停留不足最短驻留时间的一页并进前一页`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)

        book.beginPage("a")
        book.ingest(buildUs = 10_000, rasterUs = 0)
        clock.nowUs = 1_000
        book.ingest(buildUs = 10_000, rasterUs = 0)

        // a 停留 200ms（>= 150ms）→ 正常结算，prev = a
        clock.nowUs = 200_000
        book.beginPage("b")
        clock.nowUs = 210_000
        book.ingest(buildUs = 10_000, rasterUs = 0)

        // b 只停留 50ms（< 150ms）→ 3 帧全部并进 a
        clock.nowUs = 250_000
        book.beginPage("c")

        val rows = book.rankedBy()
        assertEquals(listOf("a"), rows.map { it.pageId })
        assertEquals(3L, rows.single().frames)
    }

    @Test
    fun `驻留时间判据是产品口径 150 毫秒`() {
        assertEquals(150_000L, PerfPageLedger.DEFAULT_MIN_DWELL_US)
        // 关掉合并（minDwellUs = 0）后两页各自成行。
        val clock = FakeClock()
        val book = ledger(clock = clock, minDwellUs = 0L)
        book.beginPage("a")
        book.ingest(buildUs = 1_000, rasterUs = 0)
        clock.nowUs = 10_000
        book.beginPage("b")
        book.ingest(buildUs = 1_000, rasterUs = 0)
        assertEquals(2, book.rankedBy().size)
    }

    @Test
    fun `首帧延迟是进入页面到第一帧的距离`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)
        book.beginPage("heavy")
        clock.nowUs = 120_000
        book.ingest(buildUs = 8_000, rasterUs = 4_000)

        val row = book.rankedBy().single()
        assertEquals(120_000L, row.firstFrameLatencyUs)
        assertEquals("120.0", row.toJson()["firstFrameMs"])
        // 只有一帧：跨度 0、帧数 < 2 ⇒ fps 没有意义，给 '?' 而不是天文数字。
        assertNull(row.fps)
        assertEquals("?", row.formatLine().substringAfter("fps=").substringBefore(" "))
    }

    @Test
    fun `页内 CPU 与 RSS 是段内增量`() {
        val clock = FakeClock()
        val cost = Cost(cpuMicros = 1_000_000, rssKb = 100_000)
        val book = ledger(clock = clock, cost = cost)

        book.beginPage("a")
        book.ingest(buildUs = 8_000, rasterUs = 4_000)
        // 段内：CPU +500000µs（= 500ms）、RSS +40000KB
        cost.cpuMicros = 1_500_000
        cost.rssKb = 140_000
        clock.nowUs = 200_000
        book.beginPage("b")

        val row = book.samplesByName()["a"]!!
        assertEquals(500_000L, row.cpuMicros)
        assertEquals("500.0", row.toJson()["cpuMs"])
        assertEquals(40_000L, row.rssDeltaKb)
        assertEquals(40_000L, row.toJson()["rssDeltaKb"])
    }

    @Test
    fun `成本读不到时是未知而不是零`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)
        book.beginPage("a")
        book.ingest(buildUs = 8_000, rasterUs = 4_000)
        clock.nowUs = 200_000
        book.beginPage("b")

        val row = book.samplesByName()["a"]!!
        assertNull(row.cpuMicros)
        assertNull(row.rssDeltaKb)
        assertNull(row.toJson()["cpuMs"])
        assertNull(row.toJson()["rssDeltaKb"])
        // 文本行里同样是 '?'，不是 0
        assertTrue(row.formatLine().contains("cpuMs=? rssDeltaKb=?"))
    }

    @Test
    fun `verdict 按最差帧的 build raster 比例归因`() {
        val clock = FakeClock()
        val book = ledger(clock = clock, minDwellUs = 0L)

        fun row(id: String, buildUs: Long, rasterUs: Long): PerfPageSample {
            book.beginPage(id)
            book.ingest(buildUs = buildUs, rasterUs = rasterUs)
            clock.nowUs += 200_000
            return book.samplesByName()[id]!!
        }

        assertEquals("ui-bound", row("ui", 20_000, 0).verdict)
        assertEquals("raster-bound", row("raster", 0, 20_000).verdict)
        // 20 vs 5：20 >= 5 * 1.3 ⇒ 单边 UI（口径就是 1.3，不是「差不多」）
        assertEquals("ui-bound", row("ui2", 20_000, 5_000).verdict)
        // 都接近（10 vs 9）⇒ both
        assertEquals("both", row("both", 10_000, 9_000).verdict)
        // 两个都是 0 ⇒ 没有可归因的耗时，给 '-'
        assertEquals("-", row("none", 0, 0).verdict)
    }

    @Test
    fun `不支持的面板档位被过滤掉`() {
        val clock = FakeClock()
        // 设备支持 60/120Hz：周期 16667 / 8333。
        val book = ledger(clock = clock, supportedRates = listOf(60.0, 120.0))

        // 6200µs ≈ 161Hz：不是任何真实档位（2026-10-25 真机采到过），必须挡掉，
        // 否则预算会从 8333 收紧到 6200、门槛压 -26%，合格帧成批判成掉帧。
        book.ingest(buildUs = 1_000, rasterUs = 0, vsyncUs = 1_000_000)
        clock.nowUs += 6_200
        book.ingest(buildUs = 1_000, rasterUs = 0, vsyncUs = 1_006_200)
        assertEquals("?", book.budgetJson()["observedVsyncMs"])
        assertEquals(16_667L, book.budgetUs)

        // 8333µs = 120Hz，是真实档位 ⇒ 采纳
        clock.nowUs += 8_333
        book.ingest(buildUs = 1_000, rasterUs = 0, vsyncUs = 1_014_533)
        assertEquals("8.3", book.budgetJson()["observedVsyncMs"])
        assertEquals(8_333L, book.budgetUs)
    }

    @Test
    fun `不在可信区间的间隔一律不采纳`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)
        // 3500µs < 4000（引擎一次投递多帧）→ 不采；50000µs > 40000（卡顿）→ 不采
        book.ingest(buildUs = 1_000, rasterUs = 0, vsyncUs = 1_000_000)
        clock.nowUs += 3_500
        book.ingest(buildUs = 1_000, rasterUs = 0, vsyncUs = 1_003_500)
        assertEquals("?", book.budgetJson()["observedVsyncMs"])
        clock.nowUs += 50_000
        book.ingest(buildUs = 1_000, rasterUs = 0, vsyncUs = 1_053_500)
        assertEquals("?", book.budgetJson()["observedVsyncMs"])
        assertEquals(16_667L, book.budgetUs)
    }

    @Test
    fun `零帧的页面不进排行`() {
        val book = ledger()
        book.beginPage("a")
        book.beginPage("b")
        assertTrue(book.samplesByName().isEmpty())
        assertTrue(book.rankedBy().isEmpty())
    }

    @Test
    fun `启动期的帧归到 boot 行`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)
        book.ingest(buildUs = 8_000, rasterUs = 4_000)
        assertEquals(PerfPageLedger.BOOT_PAGE, book.openPageId)
        assertEquals(listOf("boot"), book.rankedBy().map { it.pageId })
    }

    @Test
    fun `清空账本后预算回到上报值`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)
        book.beginPage("home")
        book.ingest(buildUs = 1_000, rasterUs = 0, vsyncUs = 1_000_000)
        clock.nowUs += 8_333
        book.ingest(buildUs = 1_000, rasterUs = 0, vsyncUs = 1_008_333)
        assertEquals(8_333L, book.budgetUs)

        book.reset()
        assertEquals(0L, book.totalFrames)
        assertEquals(16_667L, book.budgetUs)
        assertEquals("?", book.budgetJson()["observedVsyncMs"])
        assertTrue(book.rankedBy().isEmpty())
        assertEquals(PerfPageLedger.BOOT_PAGE, book.openPageId)
    }

    @Test
    fun `文本报表头部给出判据 空表给一行说明`() {
        val book = ledger()
        assertEquals(
            "[perf-page] report budgetMs=16.7 nominalMs=16.7 observedVsyncMs=?\n" +
                "[perf-page] no page has rendered a frame yet\n",
            book.formatTextReport(),
        )
    }

    @Test
    fun `文本报表每行可被差分脚本按等号切分`() {
        val clock = FakeClock()
        val cost = Cost(cpuMicros = 1_000_000, rssKb = 100_000)
        val book = ledger(clock = clock, cost = cost)
        book.beginPage("home")
        clock.nowUs = 120_000
        book.ingest(buildUs = 12_000, rasterUs = 6_000)
        clock.nowUs = 136_667
        book.ingest(buildUs = 8_000, rasterUs = 4_000)
        cost.cpuMicros = 1_500_000
        cost.rssKb = 140_000
        clock.nowUs = 336_667
        book.beginPage("logs")

        val lines = book.formatTextReport().trim().split('\n')
        assertEquals("[perf-page] report budgetMs=16.7 nominalMs=16.7 observedVsyncMs=?", lines[0])
        val row = lines[1]
        assertTrue(row.startsWith("[perf-page] page=home frames=2 janky=0(0%) "))
        assertTrue(row.contains("firstFrameMs=120.0"))
        assertTrue(row.contains("worstBuildMs=12.0"))
        assertTrue(row.contains("worstRasterMs=6.0"))
        assertTrue(row.contains("avgBuildMs=10.0"))
        assertTrue(row.contains("avgRasterMs=5.0"))
        assertTrue(row.contains("cpuMs=500.0"))
        assertTrue(row.contains("rssDeltaKb=40000"))
        assertTrue(row.contains("verdict=ui-bound"))
        assertTrue(row.contains("budgetMs=16.7"))
    }

    @Test
    fun `读报表不会推进账本`() {
        val clock = FakeClock()
        val cost = Cost(cpuMicros = 1_000_000, rssKb = 100_000)
        val book = ledger(clock = clock, cost = cost)
        book.beginPage("home")
        book.ingest(buildUs = 8_000, rasterUs = 4_000)
        cost.cpuMicros = 1_500_000

        val first = buildPerfSnapshotJson(book, null, emptyMap())["pages"]
        val second = buildPerfSnapshotJson(book, null, emptyMap())["pages"]
        // 报表页每 5 秒刷一次：读数不能随读取次数漂移（Dart `:320-322`）。
        assertEquals(first, second)
    }

    @Test
    fun `未闭合段可以改名 已闭合段与 boot 段不许改`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)

        // boot 段（还没 beginPage）：拒绝
        assertFalse(book.retargetOpenSegment("home"))

        // 未闭合段：改名后已落的帧原样保留（最贵的首帧不能藏在占位名下）
        book.beginPage(PerfProbeCore.UNNAMED_PAGE)
        book.ingest(buildUs = 30_000, rasterUs = 0)
        assertTrue(book.retargetOpenSegment("route:home"))
        assertEquals("route:home", book.rankedBy().single().pageId)

        // 已闭合段：不受影响
        clock.nowUs = 200_000
        book.beginPage("b")
        book.ingest(buildUs = 1_000, rasterUs = 0)
        // route:home 有 1 帧掉帧（30000 > 门槛），b 一帧没掉 ⇒ 掉帧多的在前
        assertEquals(listOf("route:home", "b"), book.rankedBy().map { it.pageId })
    }

    @Test
    fun `json 行字段与 Dart 一致`() {
        val clock = FakeClock()
        val cost = Cost(cpuMicros = 1_000_000, rssKb = 100_000)
        val book = ledger(clock = clock, cost = cost)
        book.beginPage("home")
        clock.nowUs = 120_000
        book.ingest(buildUs = 12_000, rasterUs = 6_000)
        clock.nowUs = 136_667
        book.ingest(buildUs = 8_000, rasterUs = 4_000)
        cost.cpuMicros = 1_500_000
        cost.rssKb = 140_000
        clock.nowUs = 336_667
        book.beginPage("logs")

        assertEquals(
            listOf(
                "page", "frames", "janky", "jankyPct", "spanMs", "fps", "firstFrameMs",
                "worstBuildMs", "worstRasterMs", "avgBuildMs", "avgRasterMs", "cpuMs",
                "rssDeltaKb", "budgetMs", "verdict",
            ),
            book.toJsonRows().first().keys.toList(),
        )
        val row = book.toJsonRows().first()
        assertEquals("home", row["page"])
        assertEquals(2L, row["frames"])
        assertEquals(0L, row["janky"])
        assertEquals("0.0", row["jankyPct"])
        // 跨度 136667 - 120000 = 16667µs → (2-1)*1e6/16667 = 59.9988 → "60.0"
        assertEquals("60.0", row["fps"])
        assertEquals("120.0", row["firstFrameMs"])
        assertEquals("500.0", row["cpuMs"])
        assertEquals(40_000L, row["rssDeltaKb"])
        assertEquals("16.7", row["budgetMs"])
    }

    @Test
    fun `单页可以按名字取 json`() {
        val clock = FakeClock()
        val book = ledger(clock = clock)
        book.beginPage("home")
        book.ingest(buildUs = 8_000, rasterUs = 4_000)
        assertEquals("home", book.toJsonFor("home")!!["page"])
        assertNull(book.toJsonFor("missing"))
    }
}
