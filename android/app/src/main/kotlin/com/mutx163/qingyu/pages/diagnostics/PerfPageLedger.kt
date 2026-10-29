package com.mutx163.qingyu.pages.diagnostics

import java.util.Locale
import kotlin.math.roundToLong

/**
 * 页面性能台账（源：`lib/utils/perf_page_ledger.dart`，614 行）。
 *
 * 职责与 Dart 一致：把「哪一页掉帧、哪一页费电」累计成一张**可排序、可导出**的表。
 * 与 `pages/diagnostics/PerfReportModel.kt`（渲染层视图状态）的分工：
 * 本文件产出结构化快照与文本报表，页面只负责把快照翻译成控件。
 *
 * ## 为什么这个文件是纯 Kotlin
 *
 * 台账的全部行为都能在不碰 Android 的前提下逐条判定（`PerfPageLedgerTest`）。
 * 时钟、成本读数、刷新率都是**注入**的：真机接线在 `platform/PerfProbe.kt`（Choreographer +
 * FrameMetrics），单测里换成可控时钟，于是「页内 CPU 毫秒」这类期望值是人手算出来的。
 *
 * ## 口径必须与 Dart 逐条对齐（改这里等于改差分表）
 *
 * | 常量 / 行为 | Dart 出处 | 值 |
 * |---|---|---|
 * | 「这一帧算卡」的容差倍数 | `perf_page_ledger.dart:168` | [BUDGET_TOLERANCE] = 1.25 |
 * | 可信 vsync 间隔下限 | `:171` | [MIN_PLAUSIBLE_GAP_US] = 4000µs |
 * | 可信 vsync 间隔上限 | `:174` | [MAX_PLAUSIBLE_GAP_US] = 40000µs |
 * | 面板档位容差 | `:186` | [MODE_TOLERANCE] = 0.08 |
 * | 启动期帧的归属名 | `:177` | [BOOT_PAGE] = "boot" |
 * | 短访问并入前一页 | `:195` | [DEFAULT_MIN_DWELL_US] = 150000µs |
 * | 预算只收紧不放宽 | `:248-254` | `min(实测, 上报)` |
 * | 等效帧率用「间隔数」 | `:87-88` | `(frames-1)÷span` |
 * | 0 帧页面不进排行 | `:306-310` | 过滤 |
 * | 排行同分按出现顺序 | `:333-354` | janky↓ / frames↓ / 首次出现↑ |
 *
 * ## 与 Dart 的**有意的**差异（只有两处，都不是口径而是数值格式）
 *
 * 1. Dart `toStringAsFixed` 的舍入在 .5 边界是「远离零」，Java `String.format("%.1f")`
 *    在二进制浮点上按 HALF_UP 处理 —— 对本次出现的量级（毫秒、百分比）结果一致，
 *    但严格说不是同一个算法。
 * 2. 数值一律用 [Locale.US]，避免系统语言把小数点变成逗号（Dart 侧永远用点）。
 */
data class PerfCostReading(
    /** 进程累计 CPU 时间（微秒）。读不到是 null —— **不能填 0**（0 会被读成「这页不费电」）。 */
    val cpuMicros: Long?,
    /** 常驻内存（KB）。读不到是 null。 */
    val rssKb: Long?,
)

/** 一个页面的累计读数；报表的每一行就是它（Dart `PagePerfSample`）。 */
data class PerfPageSample(
    val pageId: String,
    /** 落在这一页的帧数。 */
    val frames: Long,
    /** 其中 `build + raster > 预算 × 1.25` 的帧数。 */
    val jankyFrames: Long,
    /** 有帧的墙钟跨度之和（微秒）：只算这一页自己有帧的时间。 */
    val spanUs: Long,
    /** 「进入这一页 → 这一页第一帧」的延迟（微秒）；没出过帧的页面不会出现在报表里。 */
    val firstFrameLatencyUs: Long?,
    val worstBuildUs: Long,
    val worstRasterUs: Long,
    val avgBuildUs: Double,
    val avgRasterUs: Double,
    /** 这一页期间进程烧掉的 CPU 时间（微秒）；读不到为 null。 */
    val cpuMicros: Long?,
    /** 这一页期间 RSS 的最大段内增量（KB）；读不到为 null。 */
    val rssDeltaKb: Long?,
    /** 结算时的单帧预算（微秒），让每行读数自带判据。 */
    val budgetUs: Long,
) {
    val jankyRatio: Double
        get() = if (frames == 0L) 0.0 else jankyFrames.toDouble() / frames.toDouble()

    /**
     * 等效帧率：`(帧数 - 1) ÷ 跨度`。
     *
     * 分子必须是**间隔数**：n 帧只覆盖 n-1 个间隔，用帧数会把 60Hz 的稳定喂帧读成 72fps。
     * 跨度不足 1ms 或帧数 < 2 时给 null（引擎一次投递多帧时分子分母都不可信）。
     */
    val fps: Double?
        get() = if (frames < 2 || spanUs < 1000) null
        else (frames - 1) * 1_000_000.0 / spanUs.toDouble()

    /**
     * 谁把这一页拖过预算：最差帧里 build / raster 占 1.3 倍以上才算单边。
     * 另一栏为 0 也要判得出来（构建瓶颈页的 raster 常常就是 0）。
     */
    val verdict: String
        get() {
            if (worstBuildUs <= 0 && worstRasterUs <= 0) return "-"
            if (worstRasterUs == 0L || worstBuildUs >= worstRasterUs * 1.3) return "ui-bound"
            if (worstBuildUs == 0L || worstRasterUs >= worstBuildUs * 1.3) return "raster-bound"
            return "both"
        }

    /** 差分脚本读这一份（Dart `:105-121`）。键序 = Dart 的键序。 */
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "page" to pageId,
        "frames" to frames,
        "janky" to jankyFrames,
        "jankyPct" to perfFixed1(jankyRatio * 100),
        "spanMs" to perfMs(spanUs),
        "fps" to fps?.let { perfFixed1(it) },
        "firstFrameMs" to firstFrameLatencyUs?.let { perfMs(it) },
        "worstBuildMs" to perfMs(worstBuildUs),
        "worstRasterMs" to perfMs(worstRasterUs),
        "avgBuildMs" to perfFixed1(avgBuildUs / 1000.0),
        "avgRasterMs" to perfFixed1(avgRasterUs / 1000.0),
        "cpuMs" to cpuMicros?.let { perfMs(it) },
        "rssDeltaKb" to rssDeltaKb,
        "budgetMs" to perfMs(budgetUs),
        "verdict" to verdict,
    )

    /** 一行文本读数（导出给人看、给差分脚本 grep；Dart `:124-136`）。 */
    fun formatLine(): String {
        val fpsText = fps?.let { perfFixed0(it) } ?: "?"
        val firstText = firstFrameLatencyUs?.let { perfMs(it) } ?: "?"
        val cpuText = cpuMicros?.let { perfMs(it) } ?: "?"
        val rssText = rssDeltaKb?.toString() ?: "?"
        return "page=$pageId frames=$frames janky=$jankyFrames(${perfFixed0(jankyRatio * 100)}%) " +
            "fps=$fpsText spanMs=${perfMs(spanUs)} firstFrameMs=$firstText " +
            "worstBuildMs=${perfMs(worstBuildUs)} worstRasterMs=${perfMs(worstRasterUs)} " +
            "avgBuildMs=${perfFixed1(avgBuildUs / 1000.0)} " +
            "avgRasterMs=${perfFixed1(avgRasterUs / 1000.0)} " +
            "cpuMs=$cpuText rssDeltaKb=$rssText verdict=$verdict " +
            "budgetMs=${perfMs(budgetUs)}"
    }
}

/**
 * 页面账本。由 `platform/PerfProbe.kt` 在诊断包里实例化；正式版根本不构造它。
 *
 * @param nowUs 单调时钟（微秒）。与 [beginPage] / [ingest] 同源，偏移才可比。
 * @param readCost 成本读数（CPU 微秒 + RSS KB），必须允许返回 null 表示「没量到」。
 * @param refreshRateHz 显示上报刷新率（Hz）。
 * @param minDwellUs 一段访问短于它并进前一页（150ms = 转场时长量级，产品口径）。
 * @param supportedRefreshRatesHz 面板**支持**的刷新率（Hz）；空 = 不知道，此时不加过滤。
 */
class PerfPageLedger(
    private val nowUs: () -> Long,
    private val readCost: () -> PerfCostReading,
    private val refreshRateHz: () -> Double,
    val minDwellUs: Long = DEFAULT_MIN_DWELL_US,
    private val supportedRefreshRatesHz: List<Double> = emptyList(),
) {
    /** 「这一帧算卡」的容差倍数：真机帧耗时本来就在预算附近抖动。 */
    private var configuredBudgetUs: Long = (1_000_000.0 / safeRate()).roundToLong()

    /** 实测到的最小可信 vsync 间隔（微秒）；0 = 还没采到样本。 */
    private var observedMinGapUs: Long = 0L
    private var lastVsyncUs: Long? = null

    private var framesAll: Long = 0L

    /** 已结算页面的累计桶（按首次出现顺序 —— `LinkedHashMap` 就是 Dart 的 Map 有序性）。 */
    private val closed = LinkedHashMap<String, Accum>()

    /** 当前正在计量的一段。 */
    private var seg = Seg()

    /** 上一个结算过的页面 id，用于「短访问并入前一页」。 */
    private var prevPageId: String? = null

    /**
     * 本次会话累计收下的帧数（跨所有页面，含未闭合段）。
     *
     * 门面（`platform/PerfProbe.kt`）的「这段时间有没有新东西」判据用它：空闲/挂机时
     * 账本不涨，就不该写盘。一个常驻诊断件每 5 秒无条件写一次文件，等于给用户手机
     * 加了一个周期性 I/O 任务 —— 测功耗的工具自己费电，是最讽刺的失效方式。
     */
    val totalFrames: Long
        get() = framesAll

    /**
     * 判据读数：报表与差分脚本都要知道「这一轮是按什么阈值判的红」。
     *
     * 三栏必须并排，不能只给生效的那个：`budgetMs` 会被实测 vsync 收紧，而收紧本身
     * 可能出错（2026-09-16 首轮探针照显示上报的 60Hz 算预算，把 120Hz 面板上的整段
     * 卡顿读成「全绿」）。只有 `nominalMs`（上报值）与 `observedVsyncMs`（实测值）
     * 同时在场，读的人才能判断这次收紧对不对。
     */
    fun budgetJson(): Map<String, Any?> = linkedMapOf(
        "budgetMs" to perfMs(budgetUs),
        "nominalMs" to perfMs(configuredBudgetUs),
        // 没采到样本必须是 '?'：给 0 会被读成「这块屏的帧周期是 0 毫秒」。
        "observedVsyncMs" to if (observedMinGapUs == 0L) "?" else perfMs(observedMinGapUs),
    )

    /**
     * 单帧预算（微秒）：取「显示上报」与「实测最小帧间隔」里更紧的那个。
     *
     * 必须收紧是真机踩过的：面板空闲 60Hz / 交互 120Hz，启动时读到的往往是空闲档，
     * 照它算会把预算放宽一倍，整段卡顿一帧都记不上。
     */
    val budgetUs: Long
        get() {
            val observed = observedMinGapUs
            if (observed <= 0L) return configuredBudgetUs
            return if (observed < configuredBudgetUs) observed else configuredBudgetUs
        }

    private val jankyThresholdUs: Long
        get() = (budgetUs * BUDGET_TOLERANCE).roundToLong()

    private fun safeRate(): Double {
        val rate = refreshRateHz()
        return if (rate.isFinite() && rate > 1.0) rate else 60.0
    }

    /**
     * 切页：结算上一段、开新段。重复 begin 同一页是空操作 ——
     * 滚动、回前台这类「还在这一页」不该被当成换了一页。
     */
    fun beginPage(pageId: String) {
        val now = nowUs()
        val current = seg.pageId ?: BOOT_PAGE
        if (current == pageId) return
        closeSeg(now)
        val cost = readCost()
        seg = Seg(pageId = pageId, startUs = now, cpuStart = cost.cpuMicros, rssStart = cost.rssKb)
    }

    /**
     * 收一帧。时刻由账本自己的时钟取（与 [beginPage] 同源，偏移才可比）。
     *
     * [vsyncUs] 是**引擎给的该帧 vsync 时刻**（单调时间轴），只用来估面板节奏；
     * 不传等于这一帧没有该样本。
     */
    fun ingest(buildUs: Long, rasterUs: Long, vsyncUs: Long? = null) {
        sampleVsyncPeriod(vsyncUs)
        framesAll++
        seg.ingest(
            atUs = nowUs(),
            buildUs = buildUs,
            rasterUs = rasterUs,
            janky = buildUs + rasterUs > jankyThresholdUs,
        )
    }

    /**
     * 生命周期变化点（退后台 / 回前台）落一次账：否则整段静止时间会因为
     * 「还挂着这一页」把 CPU/RSS 增量全记到最后一页头上。
     */
    fun sealSegment() {
        if (seg.frames > 0 || seg.pageId != null) {
            closeSeg(nowUs())
        }
        seg = Seg()
    }

    /**
     * 每页快照（含当前未结算的那一段），按页面首次出现顺序。
     *
     * 0 帧的页面不出现：它没有任何可报的读数，列出来只会稀释排行，
     * 还会让「一帧都没画出来」看起来像「画得很快」。
     */
    fun samplesByName(): Map<String, PerfPageSample> {
        val result = LinkedHashMap<String, PerfPageSample>()
        for ((pageId, accum) in closed) {
            val agg = accum.copy()
            if (agg.frames > 0) result[pageId] = sampleOf(pageId, agg)
        }
        val openId = seg.pageId ?: if (seg.frames > 0) BOOT_PAGE else null
        if (openId != null && seg.frames > 0) {
            // 并进**副本**再出读数：查报表不能把未结算段落进账本，否则报表页每刷新
            // 一次，这一页的 CPU / 帧账就多落一次（读数随读取次数漂移）。
            val agg = closed[openId]?.copy() ?: Accum()
            seg.applyTo(agg, cost = readCost())
            if (agg.frames > 0) result[openId] = sampleOf(openId, agg)
        }
        return result
    }

    /**
     * 排行：掉帧数多的在前；同分按帧数多的在前，再按出现顺序
     * （保证可复现，差分表两次跑出来的行序必须一致）。
     */
    fun rankedBy(): List<PerfPageSample> {
        val samples = samplesByName().values.toMutableList()
        val order = HashMap<String, Int>()
        var index = 0
        for (id in closed.keys) order[id] = index++
        val openId = seg.pageId
        if (openId != null && !order.containsKey(openId)) order[openId] = index
        samples.sortWith(Comparator { a, b ->
            if (a.jankyFrames != b.jankyFrames) {
                b.jankyFrames.compareTo(a.jankyFrames)
            } else if (a.frames != b.frames) {
                b.frames.compareTo(a.frames)
            } else {
                (order[a.pageId] ?: 0).compareTo(order[b.pageId] ?: 0)
            }
        })
        return samples.toList()
    }

    fun toJsonFor(pageId: String): Map<String, Any?>? = samplesByName()[pageId]?.toJson()

    /**
     * 整表文本（导出用）。头部一行给出判据：读日志的人不必去翻代码，
     * 也不知道该按哪个阈值判红。
     */
    fun formatTextReport(): String {
        val buffer = StringBuilder()
        buffer.append(
            "[perf-page] report budgetMs=${perfMs(budgetUs)} " +
                "nominalMs=${perfMs(configuredBudgetUs)} " +
                "observedVsyncMs=${if (observedMinGapUs == 0L) "?" else perfMs(observedMinGapUs)}\n",
        )
        val ranked = rankedBy()
        if (ranked.isEmpty()) {
            buffer.append("[perf-page] no page has rendered a frame yet\n")
            return buffer.toString()
        }
        for (sample in ranked) {
            buffer.append("[perf-page] ").append(sample.formatLine()).append('\n')
        }
        return buffer.toString()
    }

    /** 整表 JSON（落盘用；两版本差分脚本读这一份）。 */
    fun toJsonRows(): List<Map<String, Any?>> = rankedBy().map { it.toJson() }

    /** 清空账本（新一轮巡检前调用），预算也重新按上报刷新率起算。 */
    fun reset() {
        closed.clear()
        framesAll = 0L
        seg = Seg()
        prevPageId = null
        observedMinGapUs = 0L
        lastVsyncUs = null
        configuredBudgetUs = (1_000_000.0 / safeRate()).roundToLong()
    }

    /** 当前未闭合段的页面 id（还没切过页时是 [BOOT_PAGE]）。 */
    val openPageId: String
        get() = seg.pageId ?: BOOT_PAGE

    /**
     * 给**当前未闭合段**换页面 id，已落的帧与耗时原样保留。
     *
     * 存在的理由与 Dart 相同（`:412-420`）：匿名路由推入那一刻可能还认不出是哪一页，
     * 只能先挂占位 id；那几帧恰恰是「进这一页」最贵的账。已闭合的段一律不动
     * （boot 段也拒绝）：改历史行名会让两次巡检的差分表对不齐。
     */
    fun retargetOpenSegment(pageId: String): Boolean {
        if (seg.pageId == null) return false
        seg.pageId = pageId
        return true
    }

    private fun closeSeg(now: Long) {
        // 段 id 为 null 时是 boot 段（还没切过页），照样有账要落。
        val id = seg.pageId ?: BOOT_PAGE
        val agg = closed.getOrPut(id) { Accum() }
        val cost = readCost()
        val short = now - seg.startUs < minDwellUs
        if (short && seg.frames > 0) {
            // 短访问并进前一页 —— 但前一页必须真的上过屏（有帧）。否则等于把这一页的
            // 证据塞进一个空行，排行上只是换了个名字。
            val prev = prevPageId
            val prevAgg = prev?.let { closed[it] }
            if (prevAgg != null && prevAgg.frames > 0) {
                seg.applyTo(prevAgg, cost = cost)
                prevPageId = prev
                seg = Seg()
                return
            }
        }
        seg.applyTo(agg, cost = cost)
        prevPageId = id
        seg = Seg()
    }

    private fun sampleOf(pageId: String, agg: Accum): PerfPageSample = PerfPageSample(
        pageId = pageId,
        frames = agg.frames,
        jankyFrames = agg.jankyFrames,
        spanUs = agg.spanUs,
        firstFrameLatencyUs = agg.firstFrameLatencyUs,
        worstBuildUs = agg.worstBuildUs,
        worstRasterUs = agg.worstRasterUs,
        avgBuildUs = if (agg.frames == 0L) 0.0 else agg.sumBuildUs.toDouble() / agg.frames,
        avgRasterUs = if (agg.frames == 0L) 0.0 else agg.sumRasterUs.toDouble() / agg.frames,
        cpuMicros = agg.cpuMicros,
        rssDeltaKb = agg.rssDeltaKb,
        budgetUs = budgetUs,
    )

    /**
     * 采一个 vsync 周期样本。**必须是引擎给的每帧 vsync 时刻**，不能用回调到达时间：
     * UI 线程忙时引擎把积压的多帧一次性投递，同批到达时间几乎相同、批次之间又隔得
     * 很远，「最小到达间隔」要么没有样本、要么自相矛盾。
     */
    private fun sampleVsyncPeriod(vsyncUs: Long?) {
        if (vsyncUs == null) return
        val previous = lastVsyncUs
        lastVsyncUs = vsyncUs
        if (previous == null) return
        // 相邻两帧的 vsync 相隔整数个刷新周期：取最小的可信值就是面板节奏
        //（掉 vsync 的帧给出 2 倍、3 倍周期，取最小自然被排除）。
        // 一次会话内只收紧不放宽：反复跳档会让 jank 计数不可比。
        val gap = vsyncUs - previous
        if (gap < MIN_PLAUSIBLE_GAP_US || gap > MAX_PLAUSIBLE_GAP_US) return
        if (!isPanelPeriod(gap)) return
        if (observedMinGapUs == 0L || gap < observedMinGapUs) observedMinGapUs = gap
    }

    /**
     * 这个间隔是否落在某个「支持模式的周期」上（±8%）。
     *
     * 不知道支持哪些模式（空表）时一律放行：多一条规则就多一处能猜错的地方，
     * 而「不知道」不该被当成「都不像」。
     */
    private fun isPanelPeriod(gapUs: Long): Boolean {
        if (supportedRefreshRatesHz.isEmpty()) return true
        for (hz in supportedRefreshRatesHz) {
            if (hz <= 0.0) continue
            val periodUs = 1_000_000.0 / hz
            if (kotlin.math.abs(gapUs - periodUs) <= periodUs * MODE_TOLERANCE) return true
        }
        return false
    }

    /** 一个页面的累计桶（账本内部的可变状态；Dart `_Accum`）。 */
    private class Accum {
        var frames: Long = 0
        var jankyFrames: Long = 0
        var spanUs: Long = 0
        var firstFrameLatencyUs: Long? = null
        var worstBuildUs: Long = 0
        var worstRasterUs: Long = 0
        var sumBuildUs: Long = 0
        var sumRasterUs: Long = 0
        var cpuMicros: Long? = null
        var rssDeltaKb: Long? = null

        /** 快照副本：查报表绝不能推进账本（报表页每 5 秒刷新一次）。 */
        fun copy(): Accum = Accum().also {
            it.frames = frames
            it.jankyFrames = jankyFrames
            it.spanUs = spanUs
            it.firstFrameLatencyUs = firstFrameLatencyUs
            it.worstBuildUs = worstBuildUs
            it.worstRasterUs = worstRasterUs
            it.sumBuildUs = sumBuildUs
            it.sumRasterUs = sumRasterUs
            it.cpuMicros = cpuMicros
            it.rssDeltaKb = rssDeltaKb
        }
    }

    /** 一段「某个页面正在上屏」的窗口（Dart `_Seg`）。 */
    private class Seg(
        /** null = 还没切过页（账落给 [BOOT_PAGE]）。可写：见 [retargetOpenSegment]。 */
        var pageId: String? = null,
        val startUs: Long = 0,
        val cpuStart: Long? = null,
        val rssStart: Long? = null,
    ) {
        var frames: Long = 0
        var jankyFrames: Long = 0
        var firstFrameUs: Long = 0
        var lastFrameUs: Long = 0
        var firstFrameLatencyUs: Long? = null
        var worstBuildUs: Long = 0
        var worstRasterUs: Long = 0
        var sumBuildUs: Long = 0
        var sumRasterUs: Long = 0

        fun ingest(atUs: Long, buildUs: Long, rasterUs: Long, janky: Boolean) {
            if (frames == 0L) {
                firstFrameUs = atUs
                lastFrameUs = atUs
                firstFrameLatencyUs = atUs - startUs
            } else {
                lastFrameUs = atUs
            }
            frames++
            if (janky) jankyFrames++
            sumBuildUs += buildUs
            sumRasterUs += rasterUs
            if (buildUs > worstBuildUs) worstBuildUs = buildUs
            if (rasterUs > worstRasterUs) worstRasterUs = rasterUs
        }

        /**
         * 把这段并进目标桶。一帧都没有的段不落账：它唯一的「信息」是
         * 「这一页根本没画出来」，而那不是一行性能读数。
         */
        fun applyTo(agg: Accum, cost: PerfCostReading) {
            if (frames == 0L) return
            agg.frames += frames
            agg.jankyFrames += jankyFrames
            agg.sumBuildUs += sumBuildUs
            agg.sumRasterUs += sumRasterUs
            if (worstBuildUs > agg.worstBuildUs) agg.worstBuildUs = worstBuildUs
            if (worstRasterUs > agg.worstRasterUs) agg.worstRasterUs = worstRasterUs
            agg.spanUs += lastFrameUs - firstFrameUs
            if (agg.firstFrameLatencyUs == null) agg.firstFrameLatencyUs = firstFrameLatencyUs
            val cpuEnd = cost.cpuMicros
            val cpuBegin = cpuStart
            if (cpuBegin != null && cpuEnd != null) {
                agg.cpuMicros = (agg.cpuMicros ?: 0L) + (cpuEnd - cpuBegin)
            }
            val rssEnd = cost.rssKb
            val rssBegin = rssStart
            if (rssBegin != null && rssEnd != null) {
                val delta = rssEnd - rssBegin
                val existing = agg.rssDeltaKb
                if (existing == null || delta > existing) agg.rssDeltaKb = delta
            }
        }
    }

    companion object {
        /** 「这一帧算卡」的容差倍数（Dart `:168`）。 */
        const val BUDGET_TOLERANCE: Double = 1.25

        /** 可信 vsync 间隔下限（微秒）：低于它不是面板节奏，是引擎一次投递多帧。 */
        const val MIN_PLAUSIBLE_GAP_US: Long = 4_000L

        /** 可信 vsync 间隔上限（微秒）：高于它是卡顿或长空闲后的第一帧。 */
        const val MAX_PLAUSIBLE_GAP_US: Long = 40_000L

        /** 还没切过页时的归属：启动期的帧不该无处可去。 */
        const val BOOT_PAGE: String = "boot"

        /** 面板档位容差（Dart `:186`）：间隔落在某个支持模式周期 ±8% 内才算可信。 */
        const val MODE_TOLERANCE: Double = 0.08

        /** 一段访问短于这个时长就并进前一页（Dart `:195`）。 */
        const val DEFAULT_MIN_DWELL_US: Long = 150_000L

    }
}

/**
 * 微秒 → 毫秒文本，固定 1 位小数（Dart `(micros / 1000).toStringAsFixed(1)`）。
 *
 * 放在文件级而不是 companion 里：`PerfPageSample` / `PerfStartupRecorder` 都要用，
 * 且这几个函数只做格式化、不带任何台账状态。
 */
internal fun perfMs(micros: Long): String = String.format(Locale.US, "%.1f", micros / 1000.0)

/** 固定 1 位小数（Dart `toStringAsFixed(1)`）。 */
internal fun perfFixed1(value: Double): String = String.format(Locale.US, "%.1f", value)

/** 固定 0 位小数（Dart `toStringAsFixed(0)`）。 */
internal fun perfFixed0(value: Double): String = String.format(Locale.US, "%.0f", value)
