package com.mutx163.qingyu.pages.diagnostics

import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.util.Locale

/**
 * 内存统计页（公平运行内存 / 全应用内存）的纯 Kotlin 模型
 * （源：`lib/screens/memory_stats_screen.dart` + `lib/services/memory_stats_service.dart`）。
 *
 * 不 import Compose / Android，JVM 单测直接跑。快照数据来自 Phase 2 的
 * `MemoryStatsCollector.buildSnapshot()`（`Map<String, Any?>`），本层只做
 * 「怎么算、怎么说」：单位换算、三分段概览、各行取值、各弹层键值行。
 *
 * 注意：Dart 侧快照里的 `dartVm` / `flutterImageCache` 由 Flutter 补进来，
 * 原生 Collector 没有这两个键——缺失时按 Dart 的 `formatBytes(null) = —` 渲染。
 */

/** 单位换算与时间格式（Dart `MemoryStatsService` 的四个静态格式化函数）。 */
object MemoryStatsFormat {

    /** Dart `formatBytes`：<1024 用 B，<1024KB 一位小数，<1024MB 两位小数，否则 GB 两位小数。 */
    fun formatBytes(bytes: Long?): String {
        if (bytes == null || bytes < 0) return "—"
        if (bytes < 1024L) return "$bytes B"
        // 先用 Double 再比阈值：与 Dart `bytes / 1024.0` 的浮点口径一致。
        val kilobytes = bytes.toDouble() / 1024.0
        if (kilobytes < 1024.0) return fixed(kilobytes, 1) + " KB"
        val megabytes = kilobytes / 1024.0
        if (megabytes < 1024.0) return fixed(megabytes, 2) + " MB"
        val gigabytes = megabytes / 1024.0
        return fixed(gigabytes, 2) + " GB"
    }

    /** Dart `formatKb`：先乘 1024 再走字节口径。 */
    fun formatKb(kilobytes: Long?): String {
        if (kilobytes == null || kilobytes < 0) return "—"
        return formatBytes(kilobytes * 1024L)
    }

    /** Dart `formatDuration`：>1h 给 `1h 2m 5s`，>1m 给 `1m 1s`，否则 `3s`。 */
    fun formatDuration(millis: Long?): String {
        if (millis == null || millis < 0) return "—"
        val totalSeconds = millis / 1000L
        val hours = totalSeconds / 3600L
        val minutes = (totalSeconds % 3600L) / 60L
        val seconds = totalSeconds % 60L
        return when {
            hours > 0 -> "${hours}h ${minutes}m ${seconds}s"
            minutes > 0 -> "${minutes}m ${seconds}s"
            else -> "${seconds}s"
        }
    }

    /** Dart `formatPercent`：一位小数；null / NaN 都是 `—`。 */
    fun formatPercent(ratio: Double?): String {
        if (ratio == null || ratio.isNaN()) return "—"
        return fixed(ratio * 100.0, 1) + "%"
    }

    /** `HH:mm:ss`（Dart `_formatClock`）。 */
    fun formatClock(time: LocalTime): String = buildString {
        append(two(time.hour)).append(':').append(two(time.minute)).append(':').append(two(time.second))
    }

    /** `MM-dd HH:mm:ss`；null / ≤0 一律 `—`（Dart `_formatEpochMillis`）。 */
    fun formatEpochMillis(millis: Long?, zone: ZoneId = ZoneId.systemDefault()): String {
        if (millis == null || millis <= 0L) return "—"
        val local = Instant.ofEpochMilli(millis).atZone(zone).toLocalDateTime()
        return "${two(local.monthValue)}-${two(local.dayOfMonth)} " +
            "${two(local.hour)}:${two(local.minute)}:${two(local.second)}"
    }

    private fun two(value: Int): String = value.toString().padStart(2, '0')

    /** Dart `toStringAsFixed`：小数点用 `.`，与系统语言无关。 */
    private fun fixed(value: Double, digits: Int): String =
        String.format(Locale.US, "%.${digits}f", value)
}

/** 内存压力等级（快照 `pressureLevel`）。 */
enum class MemoryPressure(val label: String) {
    NORMAL("正常"),
    ELEVATED("升高"),
    HIGH("偏高"),
    CRITICAL("危急（接近 OOM / 系统低内存）");

    companion object {
        fun of(raw: String?): MemoryPressure = when (raw) {
            "critical" -> CRITICAL
            "high" -> HIGH
            "elevated" -> ELEVATED
            else -> NORMAL
        }
    }
}

/** PSS 分类的可清性（快照 `cleanable`）。 */
enum class MemoryCleanability(val label: String) {
    PARTIAL("部分可清"),
    NO("基本不可清"),
    HARD("难清");

    companion object {
        fun of(raw: String?): MemoryCleanability = when (raw) {
            "partial" -> PARTIAL
            "no" -> NO
            else -> HARD
        }
    }
}

/** 页内每个可跳转的行（渲染层据此选图标与打开哪个弹层）。 */
enum class MemoryStatsRow {
    AUTO_REFRESH,
    PERF_REPORT,
    JAVA_HEAP,
    PSS_BREAKDOWN,
    DEBUG_MEMORY,
    IMAGE_CACHE,
    SYSTEM_MEMORY,
    APP_OVERVIEW,
    BACKGROUND_SAMPLING,
    LIVE_ISLAND,
    PROCESS_LIST,
    ANALYSIS,
    HISTORY,
    MEMORY_STATS,
    RAW_JSON,
    FAIR_MEMORY,
}

/** 页内弹层标识。 */
enum class MemorySheet {
    OVERVIEW,
    BACKGROUND,
    JAVA_HEAP,
    PSS_BREAKDOWN,
    DEBUG_MEMORY,
    IMAGE_CACHE,
    SYSTEM_MEMORY,
    LIVE_ISLAND,
    PROCESS_LIST,
    ANALYSIS,
    HISTORY,
    MEMORY_STATS,
    RAW_JSON,
    FAIR_MEMORY,
}

/** 列表行：标题 + 右侧取值 + 可选副标题。 */
data class MemoryRowView(
    val row: MemoryStatsRow,
    val title: String,
    val details: String,
    val subtitle: String? = null,
)

/** 弹层里的一行键值。 */
data class MemoryKvRow(val label: String, val value: String)

/** PSS 分类的一行（Dart `_BreakdownRow`）。 */
data class MemoryBreakdownRow(
    val label: String,
    val pssText: String,
    val ratioText: String,
    val cleanableLabel: String,
    val cleanable: MemoryCleanability,
    val meaning: String,
)

/** 进程列表的一行（Dart `_ProcessRow`）。 */
data class MemoryProcessRow(
    val name: String,
    val pidText: String,
    val pssText: String,
    val privateDirtyText: String,
    val isMainProcess: Boolean,
    val likelyLiveIsland: Boolean,
)

/** 采样历史的一行（Dart `_showHistorySheet` 里的单行文本）。 */
data class MemoryHistoryRow(
    val timeText: String,
    val stateLabel: String,
    val pssText: String,
    val heapRatioText: String,
    val liveLabel: String,
    val pressureLevel: String,
)

/** 一个弹层的展示模型；不同弹层用不同字段（键值 / 分类 / 进程 / 历史 / 纯文本）。 */
data class MemoryStatsSheet(
    val sheet: MemorySheet,
    val title: String,
    val description: String? = null,
    val rows: List<MemoryKvRow> = emptyList(),
    val breakdown: List<MemoryBreakdownRow> = emptyList(),
    val processes: List<MemoryProcessRow> = emptyList(),
    val history: List<MemoryHistoryRow> = emptyList(),
    val historySummary: String? = null,
    val bullets: List<String> = emptyList(),
    val cleanableSummary: String? = null,
    val bodyText: String? = null,
    val emptyText: String? = null,
)

/** 整页视图状态。 */
data class MemoryStatsViewState(
    val ready: Boolean,
    val summaryText: String,
    val summarySubtitle: String,
    val refreshDescription: String,
    val pressure: MemoryPressure,
    val appStateLabel: String,
    val javaHeapUsageRatio: Double,
    val nearOom: Boolean,
    val autoRefreshEnabled: Boolean,
    val isLoading: Boolean,
    val loadingHint: String,
    val errorText: String?,
    val samplingRows: List<MemoryRowView>,
    val compositionRows: List<MemoryRowView>,
    val environmentRows: List<MemoryRowView>,
    val toolRows: List<MemoryRowView>,
    val sheets: Map<MemorySheet, MemoryStatsSheet>,
) {
    /** 有快照（可以展开任何弹层）。 */
    val hasSnapshot: Boolean get() = ready

    /** 没有快照、没在加载、也没有错误——真正的空态。 */
    val isEmptyState: Boolean get() = !ready && !isLoading && errorText == null
}

/** 页内文案常量（Dart 源里是**硬编码中文**，不走 ARB；逐字抄录）。 */
internal object MemoryStatsStrings {
    const val pageTitle = "内存统计"
    const val refreshTooltip = "立即刷新"
    const val copyJsonTooltip = "复制 JSON"

    const val overviewSection = "运行概览"
    const val samplingSection = "采样控制"
    const val compositionSection = "内存构成"
    const val environmentSection = "运行环境"
    const val toolsSection = "诊断工具"

    const val summaryTitle = "整包总 PSS"
    const val loadingHint = "正在读取当前内存快照…"
    const val neverRefreshed = "尚未刷新"

    const val autoRefreshTitle = "自动刷新"
    const val perfReportTitle = "Perf Report"
    const val perfReportSubtitle = "Per-page fps + energy proxy"

    const val javaHeapTitle = "Java 堆"
    const val breakdownTitle = "PSS 分类与可清性"
    const val debugMemoryTitle = "当前进程 Debug.MemoryInfo"
    const val imageCacheTitle = "Dart / Flutter 图片缓存"
    const val systemMemoryTitle = "系统内存"
    const val lowMemory = "低内存"
    const val normalMemory = "正常"
    const val compositionDescription = "PSS 详情按需展开，避免常驻技术字段干扰当前状态。"

    const val appOverviewTitle = "应用总览"
    const val backgroundTitle = "前台 / 后台采样"
    const val foreground = "前台"
    const val background = "后台"
    const val liveIslandTitle = "超级岛服务"
    const val liveIslandRunning = "运行中"
    const val liveIslandStopped = "未运行"
    const val processListTitle = "整包进程列表"

    const val analysisFallbackTitle = "自动分析"
    const val analysisNoConclusion = "暂无结论"
    const val historyTitle = "会话采样历史"
    const val memoryStatsTitle = "系统 memoryStats 原始字段"
    const val rawJsonTitle = "复制 / 查看原始 JSON"
    const val noSnapshot = "暂无快照"
    const val fullSnapshot = "完整快照"
    const val fairMemoryTitle = "公平运行内存事件"

    const val dashboardDash = "—"
    const val dash = "—"
    const val yes = "是"
    const val no = "否"
    const val islandOn = "岛开"
    const val islandOff = "岛关"
}

/** 从快照读出整页视图状态（`snapshot = null` 表示还没拿到快照）。 */
@Suppress("LongParameterList", "LongMethod")
fun buildMemoryStatsViewState(
    snapshot: Map<String, Any?>?,
    autoRefreshEnabled: Boolean,
    refreshIntervalSeconds: Int,
    lastRefreshedAt: LocalTime?,
    isLoading: Boolean = false,
    errorText: String? = null,
): MemoryStatsViewState {
    val root = snapshot ?: emptyMap<String, Any?>()
    val app = root.mapAt("app")
    val javaHeap = root.mapAt("javaHeap")
    val debugMemory = root.mapAt("debugMemoryInfo")
    val system = root.mapAt("system")
    val liveIsland = root.mapAt("liveIsland")
    val fairMemory = root.mapAt("fairMemory")
    val dartVm = root.mapAt("dartVm")
    val imageCache = root.mapAt("flutterImageCache")
    val processes = root.mapsAt("processes")
    val history = root.mapsAt("history")
    val backgroundStats = root.mapAt("backgroundStats")
    val analysis = root.mapAt("analysis")
    val cleanable = analysis.mapAt("cleanableEstimate")
    val breakdown = root.mapAt("pssBreakdown")
    val memoryStats = root.mapAt("memoryStats")
    val pressure = MemoryPressure.of(root.stringAt("pressureLevel"))

    val ready = snapshot != null
    val totalPssText = MemoryStatsFormat.formatKb(app.longAt("totalPssKb"))
    val peakPssText = MemoryStatsFormat.formatKb(app.longAt("peakTotalPssKb"))
    val heapUsage = javaHeap.doubleAt("usageRatio") ?: 0.0
    val appStateLabel = if (root.flagAt("appInForeground")) {
        MemoryStatsStrings.foreground
    } else {
        MemoryStatsStrings.background
    }
    // 快照自带 pressureLabel 时优先用它（分类规则在 Collector 里老化，页面只负责显示）。
    val pressureLabel = root.stringAt("pressureLabel") ?: pressure.label

    val refreshedText = lastRefreshedAt?.let { MemoryStatsFormat.formatClock(it) }
        ?: MemoryStatsStrings.neverRefreshed

    val summarySubtitle = if (!ready) {
        MemoryStatsStrings.dash
    } else {
        "压力 $pressureLabel · $appStateLabel · 峰值 $peakPssText"
    }

    val refreshDescription = "统计主进程与同 UID 的其它进程（含超级岛服务）。" +
        "数据每 $refreshIntervalSeconds 秒更新一次，可在下方关闭自动采样。最近刷新：$refreshedText"

    val autoRefreshSubtitle = if (autoRefreshEnabled) {
        "每 $refreshIntervalSeconds 秒采样一次"
    } else {
        "已关闭自动刷新，使用右上角按钮手动更新"
    }

    val samplingRows = listOf(
        MemoryRowView(
            row = MemoryStatsRow.AUTO_REFRESH,
            title = MemoryStatsStrings.autoRefreshTitle,
            details = "",
            subtitle = autoRefreshSubtitle,
        ),
        MemoryRowView(
            row = MemoryStatsRow.PERF_REPORT,
            title = MemoryStatsStrings.perfReportTitle,
            details = "",
            subtitle = MemoryStatsStrings.perfReportSubtitle,
        ),
    )

    val compositionRows = listOf(
        MemoryRowView(
            row = MemoryStatsRow.JAVA_HEAP,
            title = MemoryStatsStrings.javaHeapTitle,
            details = MemoryStatsFormat.formatPercent(heapUsage),
        ),
        MemoryRowView(
            row = MemoryStatsRow.PSS_BREAKDOWN,
            title = MemoryStatsStrings.breakdownTitle,
            details = totalPssText,
        ),
        MemoryRowView(
            row = MemoryStatsRow.DEBUG_MEMORY,
            title = MemoryStatsStrings.debugMemoryTitle,
            details = MemoryStatsFormat.formatKb(debugMemory.longAt("totalPssKb")),
        ),
        MemoryRowView(
            row = MemoryStatsRow.IMAGE_CACHE,
            title = MemoryStatsStrings.imageCacheTitle,
            details = MemoryStatsFormat.formatBytes(imageCache.longAt("currentSizeBytes")),
        ),
        MemoryRowView(
            row = MemoryStatsRow.SYSTEM_MEMORY,
            title = MemoryStatsStrings.systemMemoryTitle,
            details = if (system.flagAt("isLowMemory")) {
                MemoryStatsStrings.lowMemory
            } else {
                MemoryStatsStrings.normalMemory
            },
        ),
    )

    val environmentRows = listOf(
        MemoryRowView(
            row = MemoryStatsRow.APP_OVERVIEW,
            title = MemoryStatsStrings.appOverviewTitle,
            details = "${app.longAt("processCount") ?: MemoryStatsStrings.dash} 个进程",
        ),
        MemoryRowView(
            row = MemoryStatsRow.BACKGROUND_SAMPLING,
            title = MemoryStatsStrings.backgroundTitle,
            details = if (backgroundStats.flagAt("currentlyBackground")) {
                MemoryStatsStrings.background
            } else {
                MemoryStatsStrings.foreground
            },
        ),
        MemoryRowView(
            row = MemoryStatsRow.LIVE_ISLAND,
            title = MemoryStatsStrings.liveIslandTitle,
            details = if (liveIsland.flagAt("serviceRunning")) {
                MemoryStatsStrings.liveIslandRunning
            } else {
                MemoryStatsStrings.liveIslandStopped
            },
        ),
        MemoryRowView(
            row = MemoryStatsRow.PROCESS_LIST,
            title = MemoryStatsStrings.processListTitle,
            details = "${processes.size} 个",
        ),
    )

    val toolRows = listOf(
        MemoryRowView(
            row = MemoryStatsRow.ANALYSIS,
            title = analysis.stringAt("headline") ?: MemoryStatsStrings.analysisFallbackTitle,
            details = analysis.stringAt("severityLabel") ?: MemoryStatsStrings.analysisNoConclusion,
        ),
        MemoryRowView(
            row = MemoryStatsRow.HISTORY,
            title = MemoryStatsStrings.historyTitle,
            details = "${history.size} 条",
        ),
        MemoryRowView(
            row = MemoryStatsRow.MEMORY_STATS,
            title = MemoryStatsStrings.memoryStatsTitle,
            details = "${memoryStats.size} 项",
        ),
        MemoryRowView(
            row = MemoryStatsRow.RAW_JSON,
            title = MemoryStatsStrings.rawJsonTitle,
            details = if (ready) MemoryStatsStrings.fullSnapshot else MemoryStatsStrings.noSnapshot,
        ),
        MemoryRowView(
            row = MemoryStatsRow.FAIR_MEMORY,
            title = MemoryStatsStrings.fairMemoryTitle,
            details = MemoryStatsFormat.formatEpochMillis(fairMemory.longAt("lastKillAtMillis")),
        ),
    )

    val sheets = buildSheetMap(
        root = root,
        ready = ready,
        app = app,
        javaHeap = javaHeap,
        debugMemory = debugMemory,
        system = system,
        liveIsland = liveIsland,
        fairMemory = fairMemory,
        dartVm = dartVm,
        imageCache = imageCache,
        processes = processes,
        history = history,
        backgroundStats = backgroundStats,
        analysis = analysis,
        cleanable = cleanable,
        breakdown = breakdown,
        memoryStats = memoryStats,
        heapUsage = heapUsage,
    )

    return MemoryStatsViewState(
        ready = ready,
        summaryText = if (ready) totalPssText else MemoryStatsStrings.dash,
        summarySubtitle = summarySubtitle,
        refreshDescription = refreshDescription,
        pressure = pressure,
        appStateLabel = appStateLabel,
        javaHeapUsageRatio = heapUsage,
        nearOom = javaHeap.flagAt("nearOom"),
        autoRefreshEnabled = autoRefreshEnabled,
        isLoading = isLoading,
        loadingHint = MemoryStatsStrings.loadingHint,
        errorText = errorText,
        samplingRows = samplingRows,
        compositionRows = compositionRows,
        environmentRows = environmentRows,
        toolRows = toolRows,
        sheets = sheets,
    )
}

@Suppress("LongParameterList", "LongMethod")
private fun buildSheetMap(
    root: Map<String, Any?>,
    ready: Boolean,
    app: Map<*, *>,
    javaHeap: Map<*, *>,
    debugMemory: Map<*, *>,
    system: Map<*, *>,
    liveIsland: Map<*, *>,
    fairMemory: Map<*, *>,
    dartVm: Map<*, *>,
    imageCache: Map<*, *>,
    processes: List<Map<*, *>>,
    history: List<Map<*, *>>,
    backgroundStats: Map<*, *>,
    analysis: Map<*, *>,
    cleanable: Map<*, *>,
    breakdown: Map<*, *>,
    memoryStats: Map<*, *>,
    heapUsage: Double,
): Map<MemorySheet, MemoryStatsSheet> {
    fun kb(value: Long?) = MemoryStatsFormat.formatKb(value)
    fun bytes(value: Long?) = MemoryStatsFormat.formatBytes(value)
    fun num(value: Long?): String = value?.toString() ?: "0"

    val overview = MemoryStatsSheet(
        sheet = MemorySheet.OVERVIEW,
        title = MemoryStatsStrings.appOverviewTitle,
        description = "公平运行内存页统计的是同 UID 进程总量。",
        rows = listOf(
            MemoryKvRow("运行时长", MemoryStatsFormat.formatDuration(root.longAt("uptimeMillis"))),
            MemoryKvRow("包名", root.stringAt("packageName") ?: MemoryStatsStrings.dash),
            MemoryKvRow("进程数", app.longAt("processCount")?.toString() ?: MemoryStatsStrings.dash),
            MemoryKvRow("会话采样次数", num(app.longAt("sampleCount"))),
            MemoryKvRow(
                "前台 / 后台采样次数",
                "${num(app.longAt("foregroundSampleCount"))} / ${num(app.longAt("backgroundSampleCount"))}",
            ),
            MemoryKvRow("系统 onLowMemory 次数", num(app.longAt("lowMemoryEventCount"))),
            MemoryKvRow("当前进程 PSS", kb(app.longAt("selfPssKb"))),
            MemoryKvRow("进程接口合计 PSS", kb(app.longAt("processSumPssKb"))),
            MemoryKvRow("Private Dirty 合计", kb(app.longAt("totalPrivateDirtyKb"))),
        ),
    )

    val background = MemoryStatsSheet(
        sheet = MemorySheet.BACKGROUND,
        title = MemoryStatsStrings.backgroundTitle,
        description = "前台约 15 秒、后台约 30 秒采样；进出前后台会立即补采。",
        rows = listOf(
            MemoryKvRow(
                "当前是否后台",
                if (backgroundStats.flagAt("currentlyBackground")) {
                    MemoryStatsStrings.yes
                } else {
                    MemoryStatsStrings.no
                },
            ),
            MemoryKvRow(
                "采样间隔 前台 / 后台",
                "${backgroundStats.longAt("foregroundSampleIntervalSec") ?: 15}s / " +
                    "${backgroundStats.longAt("backgroundSampleIntervalSec") ?: 30}s",
            ),
            MemoryKvRow(
                "是否已有后台采样",
                if (backgroundStats.flagAt("hasBackgroundSamples")) {
                    "是（${num(backgroundStats.longAt("backgroundPointCount"))} 点）"
                } else {
                    "否（回桌面待一会儿再回来）"
                },
            ),
            MemoryKvRow("最近前台 PSS", kb(backgroundStats.longAt("lastForegroundPssKb"))),
            MemoryKvRow("最近后台 PSS", kb(backgroundStats.longAt("lastBackgroundPssKb"))),
            MemoryKvRow(
                "后台 − 前台（最近）",
                kb(backgroundStats.longAt("backgroundMinusLastForegroundKb")),
            ),
            MemoryKvRow(
                "前台峰值 / 均值",
                "${kb(backgroundStats.longAt("peakForegroundPssKb"))} / " +
                    kb(backgroundStats.longAt("avgForegroundPssKb")),
            ),
            MemoryKvRow(
                "后台峰值 / 均值",
                "${kb(backgroundStats.longAt("peakBackgroundPssKb"))} / " +
                    kb(backgroundStats.longAt("avgBackgroundPssKb")),
            ),
            MemoryKvRow(
                "上次进前台",
                MemoryStatsFormat.formatEpochMillis(backgroundStats.longAt("lastForegroundAtMillis")),
            ),
            MemoryKvRow(
                "上次进后台",
                MemoryStatsFormat.formatEpochMillis(backgroundStats.longAt("lastBackgroundAtMillis")),
            ),
            MemoryKvRow(
                "说明",
                backgroundStats.stringAt("note") ?: "进程被杀后无法继续后台采样",
            ),
        ),
    )

    val javaHeapSheet = MemoryStatsSheet(
        sheet = MemorySheet.JAVA_HEAP,
        title = MemoryStatsStrings.javaHeapTitle,
        description = "用于观察接近 OOM 的风险，不代表整包 PSS。",
        rows = listOf(
            MemoryKvRow(
                "已用 / 上限",
                "${bytes(javaHeap.longAt("allocBytes"))} / ${bytes(javaHeap.longAt("maxBytes"))}",
            ),
            MemoryKvRow("使用率", MemoryStatsFormat.formatPercent(heapUsage)),
            MemoryKvRow(
                "接近 OOM（≥85%）",
                if (javaHeap.flagAt("nearOom")) MemoryStatsStrings.yes else MemoryStatsStrings.no,
            ),
            MemoryKvRow("会话峰值堆占用", kb(app.longAt("peakJavaHeapAllocKb"))),
        ),
    )

    val debugMemorySheet = MemoryStatsSheet(
        sheet = MemorySheet.DEBUG_MEMORY,
        title = MemoryStatsStrings.debugMemoryTitle,
        description = "Android 当前进程的 PSS 分类，不包含同 UID 的其它进程。",
        rows = listOf(
            MemoryKvRow("Java / Dalvik", kb(debugMemory.longAt("dalvikPssKb"))),
            MemoryKvRow("Native", kb(debugMemory.longAt("nativePssKb"))),
            MemoryKvRow("Graphics", kb(debugMemory.longAt("graphicsPssKb"))),
            MemoryKvRow("Code", kb(debugMemory.longAt("codePssKb"))),
            MemoryKvRow("Stack", kb(debugMemory.longAt("stackPssKb"))),
            MemoryKvRow(
                "Other / System",
                "${kb(debugMemory.longAt("otherPssKb"))} / ${kb(debugMemory.longAt("systemPssKb"))}",
            ),
        ),
    )

    val imageCacheSheet = MemoryStatsSheet(
        sheet = MemorySheet.IMAGE_CACHE,
        title = MemoryStatsStrings.imageCacheTitle,
        rows = listOf(
            MemoryKvRow("Dart RSS", bytes(dartVm.longAt("currentRssBytes"))),
            MemoryKvRow("Dart max RSS", bytes(dartVm.longAt("maxRssBytes"))),
            MemoryKvRow("图片缓存占用", bytes(imageCache.longAt("currentSizeBytes"))),
            MemoryKvRow("图片缓存上限", bytes(imageCache.longAt("maximumSizeBytes"))),
            MemoryKvRow(
                "图片条目 live / pending",
                "${imageCache.longAt("liveImageCount") ?: 0} / ${imageCache.longAt("pendingImageCount") ?: 0}",
            ),
        ),
    )

    val systemSheet = MemoryStatsSheet(
        sheet = MemorySheet.SYSTEM_MEMORY,
        title = MemoryStatsStrings.systemMemoryTitle,
        rows = listOf(
            MemoryKvRow(
                "设备可用 / 总量",
                "${bytes(system.longAt("availMemBytes"))} / ${bytes(system.longAt("totalMemBytes"))}",
            ),
            MemoryKvRow("低内存阈值", bytes(system.longAt("thresholdBytes"))),
            MemoryKvRow(
                "系统 isLowMemory",
                if (system.flagAt("isLowMemory")) MemoryStatsStrings.yes else MemoryStatsStrings.no,
            ),
            MemoryKvRow(
                "memoryClass / large",
                "${system.longAt("memoryClassMb") ?: MemoryStatsStrings.dash} / " +
                    "${system.longAt("largeMemoryClassMb") ?: MemoryStatsStrings.dash} MB",
            ),
        ),
    )

    val liveIslandSheet = MemoryStatsSheet(
        sheet = MemorySheet.LIVE_ISLAND,
        title = "超级岛（LiveUpdateService）",
        rows = listOf(
            MemoryKvRow(
                "服务是否在跑",
                if (liveIsland.flagAt("serviceRunning")) MemoryStatsStrings.yes else MemoryStatsStrings.no,
            ),
            MemoryKvRow("服务类名", liveIsland.stringAt("serviceClass") ?: MemoryStatsStrings.dash),
            MemoryKvRow(
                "说明",
                liveIsland.stringAt("note") ?: "与主进程同 UID，计入总 PSS",
            ),
        ),
    )

    val fairMemorySheet = MemoryStatsSheet(
        sheet = MemorySheet.FAIR_MEMORY,
        title = MemoryStatsStrings.fairMemoryTitle,
        rows = listOf(
            MemoryKvRow(
                "最近 KILL 时间",
                MemoryStatsFormat.formatEpochMillis(fairMemory.longAt("lastKillAtMillis")),
            ),
            MemoryKvRow(
                "notifyType / notifyId",
                "${fairMemory.longAt("lastKillNotifyType") ?: 0} / " +
                    "${fairMemory.longAt("lastKillNotifyId") ?: 0}",
            ),
            MemoryKvRow("reason", fairMemory.stringAt("lastKillReason") ?: MemoryStatsStrings.dash),
        ),
    )

    // PSS 分类：顺序取 `ordered`，缺失时用 Dart 的默认顺序。
    val orderedKeys = (breakdown["ordered"] as? List<*>)
        ?.mapNotNull { it?.toString() }
        ?: listOf("privateOther", "system", "graphics", "nativeHeap", "javaHeap", "code", "stack")
    val breakdownRows = orderedKeys.mapNotNull { key ->
        val data = breakdown[key] as? Map<*, *> ?: return@mapNotNull null
        val cleanableKind = MemoryCleanability.of(data.stringAt("cleanable"))
        MemoryBreakdownRow(
            label = data.stringAt("label") ?: data.stringAt("key") ?: MemoryStatsStrings.dash,
            pssText = kb(data.longAt("pssKb")),
            ratioText = MemoryStatsFormat.formatPercent(data.doubleAt("ratio")),
            cleanableLabel = cleanableKind.label,
            cleanable = cleanableKind,
            meaning = data.stringAt("meaning") ?: "",
        )
    }
    val breakdownSheet = MemoryStatsSheet(
        sheet = MemorySheet.PSS_BREAKDOWN,
        title = MemoryStatsStrings.breakdownTitle,
        description = "占比相对总 PSS；可清性是应用层能否主动释放的判断。",
        breakdown = breakdownRows,
    )

    val bullets = (analysis["bullets"] as? List<*>)
        ?.mapNotNull { it?.toString() }
        ?: emptyList()
    val analysisSheet = MemoryStatsSheet(
        sheet = MemorySheet.ANALYSIS,
        title = analysis.stringAt("headline") ?: MemoryStatsStrings.analysisFallbackTitle,
        description = "严重度：${analysis.stringAt("severityLabel") ?: MemoryStatsStrings.dash} · 基于当前 PSS 拆解与包类型",
        cleanableSummary = "可节约粗估：易清 ${cleanable.longAt("easyMb") ?: 0} MB · " +
            "中等 ${cleanable.longAt("mediumMb") ?: 0} MB · " +
            "难清 ${cleanable.longAt("hardMb") ?: 0} MB",
        bullets = bullets,
        emptyText = if (bullets.isEmpty()) "暂无分析结论，请刷新。" else null,
    )

    val historyRows = history.asReversed().take(MAX_HISTORY_ROWS).map { sample ->
        MemoryHistoryRow(
            timeText = MemoryStatsFormat.formatEpochMillis(sample.longAt("atMillis")),
            stateLabel = if (sample.flagAt("appInForeground")) {
                MemoryStatsStrings.foreground
            } else {
                MemoryStatsStrings.background
            },
            pssText = kb(sample.longAt("totalPssKb")),
            heapRatioText = MemoryStatsFormat.formatPercent(sample.doubleAt("javaHeapUsageRatio")),
            liveLabel = if (sample.flagAt("liveServiceRunning")) {
                MemoryStatsStrings.islandOn
            } else {
                MemoryStatsStrings.islandOff
            },
            pressureLevel = sample.stringAt("pressureLevel") ?: MemoryStatsStrings.dash,
        )
    }
    val historySheet = MemoryStatsSheet(
        sheet = MemorySheet.HISTORY,
        title = MemoryStatsStrings.historyTitle,
        description = "最多保留 240 点；这里展示最近 20 条，完整数据请复制 JSON。",
        history = historyRows,
        historySummary = "共 ${history.size} 点 · 最早→最晚",
        emptyText = if (history.isEmpty()) {
            "采样尚未积累。可先回桌面 1～2 分钟再回来，查看后台 PSS。"
        } else {
            null
        },
    )

    val memoryStatsText = if (memoryStats.isEmpty()) {
        null
    } else {
        memoryStats.entries.joinToString("\n") { "${it.key} = ${it.value}" }
    }
    val memoryStatsSheet = MemoryStatsSheet(
        sheet = MemorySheet.MEMORY_STATS,
        title = MemoryStatsStrings.memoryStatsTitle,
        description = "Android Debug.MemoryInfo.getMemoryStats() 全量键值，便于对照 dumpsys。",
        bodyText = memoryStatsText,
        emptyText = if (memoryStatsText == null) "当前系统未提供 memoryStats（或 API 过低）。" else null,
    )

    val processRows = processes.map { process ->
        MemoryProcessRow(
            name = process.stringAt("processName") ?: MemoryStatsStrings.dash,
            pidText = process.longAt("pid")?.toString() ?: MemoryStatsStrings.dash,
            pssText = kb(process.longAt("pssKb")),
            privateDirtyText = kb(process.longAt("privateDirtyKb")),
            isMainProcess = process.flagAt("isMainProcess"),
            likelyLiveIsland = process.flagAt("likelyLiveIsland"),
        )
    }
    val processSheet = MemoryStatsSheet(
        sheet = MemorySheet.PROCESS_LIST,
        title = MemoryStatsStrings.processListTitle,
        description = "同 applicationId 下各进程 PSS；超级岛一般在主进程或同 UID 服务内。",
        processes = processRows,
        emptyText = if (processRows.isEmpty()) "暂无进程数据" else null,
    )

    val rawJsonSheet = MemoryStatsSheet(
        sheet = MemorySheet.RAW_JSON,
        title = "原始 JSON",
        description = "便于粘贴到 issue / 对照公平内存 TRIM·KILL。长按列表行也可直接复制。",
        bodyText = if (ready) memorySnapshotJson(root) else MemoryStatsStrings.dash,
    )

    return mapOf(
        MemorySheet.OVERVIEW to overview,
        MemorySheet.BACKGROUND to background,
        MemorySheet.JAVA_HEAP to javaHeapSheet,
        MemorySheet.DEBUG_MEMORY to debugMemorySheet,
        MemorySheet.IMAGE_CACHE to imageCacheSheet,
        MemorySheet.SYSTEM_MEMORY to systemSheet,
        MemorySheet.LIVE_ISLAND to liveIslandSheet,
        MemorySheet.FAIR_MEMORY to fairMemorySheet,
        MemorySheet.PSS_BREAKDOWN to breakdownSheet,
        MemorySheet.ANALYSIS to analysisSheet,
        MemorySheet.HISTORY to historySheet,
        MemorySheet.MEMORY_STATS to memoryStatsSheet,
        MemorySheet.PROCESS_LIST to processSheet,
        MemorySheet.RAW_JSON to rawJsonSheet,
    )
}

/** 采样历史一次最多展示多少条（Dart `history.reversed().take(20)`）。 */
const val MAX_HISTORY_ROWS = 20

/**
 * 快照 → 缩进 JSON（对齐 Dart `JsonEncoder.withIndent('  ')`）。
 *
 * 原生侧没有 `org.json` 的 JVM 实现可直接用，这里按 JSON 规范手写一份，
 * 只用于「原始 JSON」弹层与「复制 JSON」，不参与任何解析。
 */
fun memorySnapshotJson(value: Any?, depth: Int = 0): String {
    val pad = "  ".repeat(depth)
    val innerPad = "  ".repeat(depth + 1)
    return when (value) {
        null -> "null"
        is String -> jsonQuote(value)
        is Boolean -> value.toString()
        is Int, is Long -> value.toString()
        is Double -> if (value.isNaN() || value.isInfinite()) "null" else value.toString()
        is Float -> value.toDouble().let { if (it.isNaN() || it.isInfinite()) "null" else it.toString() }
        is Map<*, *> -> {
            if (value.isEmpty()) {
                "{}"
            } else {
                value.entries.joinToString(
                    separator = ",\n",
                    prefix = "{\n",
                    postfix = "\n$pad}",
                ) { (k, v) -> "$innerPad${jsonQuote(k.toString())} : ${memorySnapshotJson(v, depth + 1)}" }
            }
        }
        is List<*> -> {
            if (value.isEmpty()) {
                "[]"
            } else {
                value.joinToString(
                    separator = ",\n",
                    prefix = "[\n",
                    postfix = "\n$pad]",
                ) { item -> innerPad + memorySnapshotJson(item, depth + 1) }
            }
        }
        else -> jsonQuote(value.toString())
    }
}

private fun jsonQuote(text: String): String {
    val sb = StringBuilder(text.length + 2)
    sb.append('"')
    for (ch in text) {
        when (ch) {
            '"' -> sb.append("\\\"")
            '\\' -> sb.append("\\\\")
            '\n' -> sb.append("\\n")
            '\r' -> sb.append("\\r")
            '\t' -> sb.append("\\t")
            else -> if (ch < ' ') sb.append("\\u").append(ch.code.toString(16).padStart(4, '0')) else sb.append(ch)
        }
    }
    sb.append('"')
    return sb.toString()
}

// ── 快照读取辅助（Dart `MemoryStatsService.asInt/asDouble/asStringKeyMap/asMapList`）──

internal fun Map<*, *>.mapAt(key: String): Map<*, *> =
    this[key] as? Map<*, *> ?: emptyMap<String, Any?>()

internal fun Map<*, *>.mapsAt(key: String): List<Map<*, *>> =
    (this[key] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()

internal fun Map<*, *>.longAt(key: String): Long? = (this[key] as? Number)?.toLong()

internal fun Map<*, *>.doubleAt(key: String): Double? = (this[key] as? Number)?.toDouble()

internal fun Map<*, *>.stringAt(key: String): String? =
    this[key]?.toString()?.takeIf { it.isNotEmpty() }

internal fun Map<*, *>.flagAt(key: String): Boolean = this[key] == true
