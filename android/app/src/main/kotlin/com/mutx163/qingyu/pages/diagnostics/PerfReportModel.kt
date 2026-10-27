package com.mutx163.qingyu.pages.diagnostics

/**
 * 性能报告页（Perf Report）的纯 Kotlin 模型
 * （源：`lib/screens/perf_report_screen.dart`）。
 *
 * 这页**故意全英文**（Dart 源顶部注释：仓库有硬编码中文的棘轮基线
 * `tool/cjk_hardcode_baseline.txt`，只减不增；本页只在诊断包里可达，所以不做本地化）。
 * 因此这里没有 `Strings` + ARB 对拍的那一套，文案常量集中在 [PerfReportStrings] 里逐字抄。
 *
 * 模型只做三件事：
 * 1. 把快照里的 `verdict` 字符串映射成图标语义（ui-bound / raster-bound / both / 其它）；
 * 2. 按 jank 比例算强调色档位（≥25% 红、≥5% 黄、否则绿）；
 * 3. 拼三处文案：概览卡（janky / frames + 判据三栏）、启动阶段行、每页排行行。
 * 缺字段时的 `?` 与 `0` 回落口径与 Dart 一一对应（**不拿 0 填一个「阈值是 0 毫秒」的假判据**）。
 */
enum class PerfVerdict { UI_BOUND, RASTER_BOUND, BOTH, UNKNOWN }

/** 强调色档位（渲染层映射到具体颜色）。 */
enum class PerfAccent { RED, YELLOW, GREEN, DEFAULT }

/** 每页排行的一行（Dart `_pageTile`）。 */
data class PerfPageRowView(
    val page: String,
    val details: String,
    val subtitle: String,
    val verdict: PerfVerdict,
    val accent: PerfAccent,
    val jankRatio: Double,
)

/** 启动阶段的一行（Dart 里的 `HyperosListTile`）。 */
data class PerfStartupRowView(
    val phase: String,
    val details: String,
    val subtitle: String,
)

/** 整页视图状态。 */
data class PerfReportViewState(
    val isAvailable: Boolean,
    val summaryText: String,
    val summaryTitle: String,
    val summarySubtitle: String,
    val startupRows: List<PerfStartupRowView>,
    val pageRows: List<PerfPageRowView>,
    val clearLedgerDetails: String,
    val rawReportVisible: Boolean,
    val rawToggleText: String,
    val notInstalledText: String,
    val noStartupText: String,
    val noPagesText: String,
    val energyNote: String,
)

/** 页内英文文案（Dart 源里逐字硬编码，不属 ARB；照抄）。 */
internal object PerfReportStrings {
    const val pageTitle = "Perf Report"
    const val refreshTooltip = "Refresh now"
    const val exportTooltip = "Export timestamped files"

    const val notInstalled =
        "Probe is not installed in this build. Rebuild with " +
            "--dart-define=PERF_PROBE=true, or use a .debug / .profile " +
            "package."

    const val totalsSection = "Totals"
    const val summaryTitle = "janky / total frames"
    const val startupSection = "Startup phases"
    const val noStartup = "No startup phase recorded in this session."
    const val pageSection = "Per-page ranking"
    const val noPages = "No page has rendered a frame yet."
    const val roundSection = "Round control"
    const val clearLedger = "Clear ledger"
    const val clearLedgerHint = "start a fresh sweep round"
    const val showRaw = "Show raw report"
    const val hideRaw = "Hide raw report"
    const val copyText = "Copy text report"
    const val copyJson = "Copy JSON snapshot"

    const val energyNote =
        "Energy columns are proxies, not power draw. cpuMs is a " +
            "page's share of process CPU time; rssDeltaKb is its " +
            "resident-memory growth. This device exposes no readable " +
            "battery current or GPU frequency without root, so nothing " +
            "here is watts or mAh — compare two builds, do not read " +
            "absolute power out of it. budgetMs is the per-frame " +
            "allowance, tightened to the measured vsync gap; verdict " +
            "names the thread that blew it (ui = build/layout/paint, " +
            "raster = GPU/offscreen layers/blur)."

    const val toastCopied = "copied"
    const val toastExportFailed = "export failed (see console)"
    const val toastExported = "exported"
    const val toastLedgerCleared = "ledger cleared"
}

/** jank 比例 → 强调色档位（Dart：`ratio >= 0.25 红 / >= 0.05 黄 / 否则绿`）。 */
fun perfAccentFor(ratio: Double): PerfAccent = when {
    ratio >= 0.25 -> PerfAccent.RED
    ratio >= 0.05 -> PerfAccent.YELLOW
    else -> PerfAccent.GREEN
}

/** `verdict` 字符串 → 图标语义。 */
fun perfVerdictOf(raw: String?): PerfVerdict = when (raw) {
    "ui-bound" -> PerfVerdict.UI_BOUND
    "raster-bound" -> PerfVerdict.RASTER_BOUND
    "both" -> PerfVerdict.BOTH
    else -> PerfVerdict.UNKNOWN
}

/**
 * Dart `toString()` 的数值口径：整数不带小数点，double 整数值带 `.0`。
 *
 * 快照里 `fps` 可能是 60（int）也可能 59.9（double），直接 `toString()` 会
 * 在 int 上得到 `60`、double 上得到 `59.9`，与本函数一致；`60.0` 保持 `60.0`。
 */
fun dartNumberText(value: Any?): String = when (value) {
    null -> ""
    is Int, is Long, is Short, is Byte -> value.toString()
    is Double -> if (value.isFinite() && value == Math.floor(value) && Math.abs(value) < 1e15) {
        value.toLong().toString() + ".0"
    } else {
        value.toString()
    }
    is Float -> dartNumberText(value.toDouble())
    else -> value.toString()
}

/** `fps` 之类允许缺失的字段：缺失显示 `?`（Dart `?? '?'`）。 */
internal fun optionalNumberText(value: Any?): String =
    if (value == null) "?" else dartNumberText(value)

/** `_fmtNum`：数字固定 0 位小数，非数字原样。 */
internal fun formatWholeNumber(value: Any?): String =
    if (value is Number) {
        String.format(java.util.Locale.US, "%.0f", value.toDouble())
    } else {
        value?.toString() ?: "?"
    }

private fun Map<*, *>.mapAt2(key: String): Map<*, *> =
    this[key] as? Map<*, *> ?: emptyMap<String, Any?>()

private fun Map<*, *>.listAt2(key: String): List<Map<*, *>> =
    (this[key] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()

private fun Map<*, *>.intAt2(key: String): Long? = (this[key] as? Number)?.toLong()

/**
 * 快照 → 整页视图状态。
 *
 * @param snapshot 性能探针快照；`null` 表示这个包里没装探针（Dart `PerfProbe.isInstalled == false`）
 * @param showRaw 是否展开原文报告（纯 UI 状态，由调用方保存）
 * @param observedFrames 探针累计观察帧数（Dart `PerfProbe.observedFrames`）
 */
@Suppress("LongMethod")
fun buildPerfReportViewState(
    snapshot: Map<String, Any?>?,
    showRaw: Boolean = false,
    observedFrames: Long? = null,
): PerfReportViewState {
    val root = snapshot ?: emptyMap<String, Any?>()
    val available = snapshot != null
    val pages = root.listAt2("pages")
    val startup = root.listAt2("startup")
    val totals = root.mapAt2("totals")
    // 判据块：缺块时三栏都给 '?'，宁可显示「没量到」，也不拿 0 填一个假阈值。
    val probe = root["probe"] as? Map<*, *>
    val budgetMs = probe?.get("budgetMs") ?: "?"
    val nominalMs = probe?.get("nominalMs") ?: "?"
    val observedVsyncMs = probe?.get("observedVsyncMs") ?: "?"

    val pageRows = pages.map { row ->
        val frames = row.intAt2("frames") ?: 0L
        val janky = row.intAt2("janky") ?: 0L
        val ratio = if (frames == 0L) 0.0 else janky.toDouble() / frames.toDouble()
        val verdict = perfVerdictOf(row["verdict"]?.toString())
        PerfPageRowView(
            page = row["page"]?.toString() ?: "?",
            details = "${optionalNumberText(row["fps"])} fps   $janky/$frames",
            subtitle = "build worst ${optionalNumberText(row["worstBuildMs"])}/" +
                "${optionalNumberText(row["avgBuildMs"])} ms  " +
                "raster ${optionalNumberText(row["worstRasterMs"])}/" +
                "${optionalNumberText(row["avgRasterMs"])} ms  " +
                "first ${optionalNumberText(row["firstFrameMs"])} ms  " +
                "cpu ${optionalNumberText(row["cpuMs"])} ms  " +
                "rss ${optionalNumberText(row["rssDeltaKb"])} KB",
            verdict = verdict,
            accent = perfAccentFor(ratio),
            jankRatio = ratio,
        )
    }

    val startupRows = startup.map { row ->
        PerfStartupRowView(
            phase = row["phase"]?.toString() ?: "?",
            details = "${optionalNumberText(row["stepMs"])} ms",
            subtitle = "since start ${optionalNumberText(row["totalMs"])} ms",
        )
    }

    val summarySubtitle = "pages ${totals.intAt2("pages") ?: 0}  " +
        "janky ${totals["jankyPct"] ?: "0.0"}%  " +
        "budget ${dartNumberText(budgetMs)}ms " +
        "(nominal ${dartNumberText(nominalMs)}ms, " +
        "vsync ${dartNumberText(observedVsyncMs)}ms)  " +
        "rate ${formatWholeNumber(root["refreshRateHz"])}Hz"

    return PerfReportViewState(
        isAvailable = available,
        summaryText = "${totals.intAt2("janky") ?: 0} / ${totals.intAt2("frames") ?: 0}",
        summaryTitle = PerfReportStrings.summaryTitle,
        summarySubtitle = summarySubtitle,
        startupRows = startupRows,
        pageRows = pageRows,
        clearLedgerDetails = "${observedFrames ?: 0L} frames",
        rawReportVisible = showRaw,
        rawToggleText = if (showRaw) PerfReportStrings.hideRaw else PerfReportStrings.showRaw,
        notInstalledText = PerfReportStrings.notInstalled,
        noStartupText = PerfReportStrings.noStartup,
        noPagesText = PerfReportStrings.noPages,
        energyNote = PerfReportStrings.energyNote,
    )
}
