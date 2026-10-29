package com.mutx163.qingyu.pages.diagnostics

/**
 * 性能探针的**可测内核**（源：`lib/utils/perf_probe.dart`，1082 行里的纯逻辑部分）。
 *
 * 与 `platform/PerfProbe.kt` 的分工：
 * * 本文件**不认识 Android**：账本、启动分段、快照结构、文本报表、页面 id 归一化都在这里，
 *   JVM 单测直接驱动；
 * * `platform/PerfProbe.kt` 只负责「从哪儿取每帧耗时与 vsync」（Choreographer +
 *   FrameMetrics）、成本采样、落盘与导出，取到就调这里的 [ingest] / [beginPage]。
 *
 * 这样切分的理由与 Dart 侧一致（`perf_page_ledger.dart` 顶部注释）：台账口径必须能靠
 * 手推的期望值判定，采样实现则只能在真机上验。任何口径混进 Android 层都会让
 * 单测失去意义。
 *
 * 未安装时（正式包）所有入口都是空操作，[isInstalled] 为 false，报表页因此走
 * Dart 同款「Probe is not installed in this build.」说明文案。
 */
object PerfProbeCore {
    /** 快照 JSON 的结构版本。字段改名/加义时**必须**升它。 */
    const val SCHEMA_VERSION: Int = 1

    /** 归一化失败时的最后一档行名（Dart `PerfProbe.unnamedPage`）。 */
    const val UNNAMED_PAGE: String = "unnamed"

    /** 每页 CPU/RSS 的采样周期（毫秒）。按帧读 /proc 会让探针自己变成掉帧来源。 */
    const val COST_SAMPLE_INTERVAL_MS: Long = 250L

    /** 落盘检查周期（毫秒）。真正写不写由帧数有没有涨决定。 */
    const val FLUSH_INTERVAL_MS: Long = 5_000L

    /** 导出快照最多保留几轮（json+txt 成对计数）。 */
    const val MAX_KEPT_EXPORTS: Int = 12

    /** 保留多少份历史会话（每份 = 一次 App 启动）。 */
    const val MAX_KEPT_SESSIONS: Int = 10

    private var installed = false
    private var ledger: PerfPageLedger? = null
    private var startup: PerfStartupRecorder? = null
    private var clock: (() -> Long)? = null
    private var metaProvider: () -> Map<String, Any?> = { emptyMap() }
    private var lastPageId: String? = null

    /** install 之前收到的启动打点（按收到的顺序）。 */
    private val pendingStartup = mutableListOf<Pair<String, Long>>()

    /** 探针是否已安装（未安装时所有接口是空操作）。 */
    val isInstalled: Boolean
        get() = installed

    /** 当前账本（单测与宿主读 `observedFrames` 用）；未安装为 null。 */
    val currentLedger: PerfPageLedger?
        get() = ledger

    /** 当前启动记录器；未安装为 null。 */
    val currentStartup: PerfStartupRecorder?
        get() = startup

    /** 缓冲里还压着几条启动打点（单测用；已安装恒为 0）。 */
    val pendingStartupMarkCount: Int
        get() = pendingStartup.size

    /**
     * 先装时钟。启动打点（`mainEnter` / `shellAttach` …）发生在 [install] 之前，
     * 没有时钟就取不到它们的真实时刻。可重复调用。
     */
    fun configureClock(nowUs: () -> Long) {
        clock = nowUs
    }

    /**
     * 安装探针。重复调用是空操作（返回 false）。
     *
     * 门控在**装配那一侧**（`platform/PerfProbe.kt` 的 `isEnabled`）：正式包根本走不到这里，
     * 于是「零开销」不靠这里的每次判断，而是连对象都不建。
     *
     * @return 本次是否真的装上（重复安装返回 false，便于调用方只做一次挂载）。
     */
    fun install(
        nowUs: () -> Long,
        readCost: () -> PerfCostReading,
        refreshRateHz: () -> Double,
        supportedRefreshRatesHz: List<Double> = emptyList(),
        minDwellUs: Long = PerfPageLedger.DEFAULT_MIN_DWELL_US,
        metaProvider: () -> Map<String, Any?> = { emptyMap() },
    ): Boolean {
        if (installed) return false
        installed = true
        clock = nowUs
        this.metaProvider = metaProvider
        ledger = PerfPageLedger(
            nowUs = nowUs,
            readCost = readCost,
            refreshRateHz = refreshRateHz,
            minDwellUs = minDwellUs,
            supportedRefreshRatesHz = supportedRefreshRatesHz,
        )
        startup = PerfStartupRecorder()
        // 装之前收到的启动打点在这里补记（用**原始时间戳**，否则会被压成 0ms）。
        flushPendingStartup()
        return true
    }

    /**
     * 记一个启动阶段（用探针自己的单调时钟）。未安装时先缓冲，装的时候按原时刻补记。
     *
     * 为什么必须能缓冲：`mainEnter` / `bind` 这类打点就发生在安装之前，
     * 早期实现直接丢掉，结果「进程起来 → 首次上屏」这段最贵的时间永远缺一段。
     */
    fun markStartup(label: String) {
        val atUs = clock?.invoke() ?: return
        val recorder = startup
        if (recorder != null) {
            recorder.mark(label, atUs)
            return
        }
        pendingStartup.add(label to atUs)
    }

    /** 显式时间戳版本（真机在 Application 里打点时用，避免依赖内部时钟设置顺序）。 */
    fun markStartup(label: String, atUs: Long) {
        val recorder = startup
        if (recorder != null) {
            recorder.mark(label, atUs)
            return
        }
        pendingStartup.add(label to atUs)
    }

    private fun flushPendingStartup() {
        val recorder = startup ?: return
        if (pendingStartup.isEmpty()) return
        val pending = pendingStartup.toList()
        pendingStartup.clear()
        for ((label, atUs) in pending) recorder.mark(label, atUs)
    }

    /**
     * 切页：壳在每次换页时调它（Dart 靠 `NavigatorObserver` 自动得到同一件事）。
     *
     * 页面 id 走 [normalizePageId]：不归一化会把一页拆成两行、或把两页并成一行，
     * 差分表就会得出「这页变慢了」的假结论。
     */
    fun beginPage(pageId: String) {
        val target = ledger ?: return
        val normalized = normalizePageId(pageId)
        lastPageId = normalized
        target.beginPage(normalized)
    }

    /** 收一帧（`platform/PerfProbe.kt` 的帧回调调它）。未安装时空操作。 */
    fun ingest(buildUs: Long, rasterUs: Long, vsyncUs: Long? = null) {
        ledger?.ingest(buildUs = buildUs, rasterUs = rasterUs, vsyncUs = vsyncUs)
    }

    /** 退后台时落一次账：否则后台那一大段 CPU/RSS 增量会全记到最后一页头上。 */
    fun sealSegment() {
        ledger?.sealSegment()
    }

    /** 回前台重新开段（路由观察者不会为「恢复」而触发，不开就没人记账）。 */
    fun resumeLastPage() {
        val id = lastPageId ?: return
        ledger?.beginPage(id)
    }

    /** 当前账本累计帧数（报表页「Clear ledger」右侧的 `<n> frames`）。 */
    fun observedFrames(): Long = ledger?.totalFrames ?: 0L

    /**
     * 整份快照（页面排行 + 启动分段 + 汇总 + 元数据）。
     *
     * 未安装时也返回完整结构（`probe` 三栏为 `?`、`pages` 为空）：正式包里报表页仍可能
     * 被打开，结构缺字段会被差分脚本当成「解析失败」而不是「这个包没采到数」。
     */
    fun snapshotJson(): Map<String, Any?> = buildPerfSnapshotJson(
        ledger = ledger,
        startup = startup,
        meta = metaProvider(),
    )

    /**
     * 人读文本（启动 + 排行 + 元数据三段），导出与剪贴板共用。
     *
     * 与 Dart 同口径：未安装时给一行 `[perf-probe] not installed ...`，
     * 而不是空串——空串会让人以为「采到了但没内容」。
     */
    fun reportText(): String {
        val current = ledger
        if (current == null) {
            return "[perf-probe] not installed (release build without PERF_PROBE)\n"
        }
        val buffer = StringBuilder()
        buffer.append(startup?.formatTextReport() ?: "")
        buffer.append(current.formatTextReport())
        val meta = metaProvider()
        buffer.append(
            "[perf-probe] meta app=${meta["appVersion"]} host=${meta["deviceModel"]} " +
                "platform=${meta["platform"]} kernel=${meta["osKernelVersion"]} " +
                "rateHz=${meta["refreshRateHz"]}\n",
        )
        return buffer.toString()
    }

    /** 清空累计值（新一轮巡检开始前调用）。 */
    fun reset() {
        ledger?.reset()
        startup?.reset()
        lastPageId = null
    }

    /** 仅供测试：把内核退回未安装态（真机上没有卸载路径）。 */
    internal fun debugReset() {
        installed = false
        ledger = null
        startup = null
        clock = null
        metaProvider = { emptyMap() }
        lastPageId = null
        pendingStartup.clear()
    }
}

/**
 * 页面 id 归一化（Dart `PerfProbe.normalizePageId`，`:467-495`）。
 *
 * 为什么必须统一做：路由名在本仓没有统一约定（`/settings` 与 `settings` 混用、
 * 匿名路由压根没有名字），两版本差分表靠「同一页的行名对得上」成立。
 */
fun normalizePageId(raw: String?, widgetType: String? = null): String {
    var value = (raw ?: "").trim()
    if (value.isEmpty()) value = (widgetType ?: "").trim()
    if (value.isEmpty()) return PerfProbeCore.UNNAMED_PAGE
    // 去掉泛型参数：`Foo<Bar>` 里那层是 payload 类型，不是页面身份。
    val angle = value.indexOf('<')
    if (angle > 0) value = value.substring(0, angle)
    // 多级路径只留最后一段（深链 `settings/live/testing` 同理）。
    val slash = value.lastIndexOf('/')
    if (slash >= 0) value = value.substring(slash + 1)
    // 类型串可能带库前缀（`material.Foo`）；页面/路由名里不会有点，取最后一段是安全的。
    //
    // ⚠️ 与 Dart 的**唯一一处语义适配**：Dart 无条件按点切断，是因为它只见过 Dart
    // 类型串。本仓 Compose 壳的页面 id 本身就是点分形式（`b.general` /
    // `h.perfReport`），逐字照抄会把 `b.log` 与 `h.log` 并成同一个 `log` 行、
    // 也会让 `b.general` 变成 `general` —— 排行会把两个域的页混在一起。
    // 因此只在「点后是 PascalCase 类型名」时才剥前缀（`material.Foo` → `Foo`）。
    val dot = value.lastIndexOf('.')
    if (dot >= 0 && dot + 1 < value.length && value[dot + 1].isUpperCase()) {
        value = value.substring(dot + 1)
    }
    // 报表行按空白切 token，名字里带换行会把一行劈成两行。
    value = value.replace(Regex("\\s+"), " ").trim()
    return if (value.isEmpty()) PerfProbeCore.UNNAMED_PAGE else value
}

/**
 * 快照结构（Dart `PerfProbe.buildSnapshotJson`，`:646-680`）。
 *
 * 抽成独立函数是为了让「字段名与层级」可测：差分脚本只认这份结构，
 * 字段漂了会静默少算而不是报错。
 */
fun buildPerfSnapshotJson(
    ledger: PerfPageLedger?,
    startup: PerfStartupRecorder?,
    meta: Map<String, Any?>,
): Map<String, Any?> {
    val pages = ledger?.toJsonRows() ?: emptyList()
    var frames = 0L
    var janky = 0L
    for (page in pages) {
        frames += (page["frames"] as? Number)?.toLong() ?: 0L
        janky += (page["janky"] as? Number)?.toLong() ?: 0L
    }
    val root = LinkedHashMap<String, Any?>()
    root["schema"] = PerfProbeCore.SCHEMA_VERSION
    root.putAll(meta)
    root["probe"] = ledger?.budgetJson() ?: linkedMapOf(
        "budgetMs" to "?",
        "nominalMs" to "?",
        "observedVsyncMs" to "?",
    )
    root["startup"] = startup?.toJson() ?: emptyList<Map<String, Any?>>()
    root["totals"] = linkedMapOf(
        "pages" to pages.size,
        "frames" to frames,
        "janky" to janky,
        "jankyPct" to if (frames == 0L) "0.0" else perfFixed1(janky * 100.0 / frames),
    )
    root["pages"] = pages
    return root
}
