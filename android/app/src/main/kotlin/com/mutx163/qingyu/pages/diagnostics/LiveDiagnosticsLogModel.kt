package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.infra.DiagnosticsLogEntry
import com.mutx163.qingyu.infra.DiagnosticsLogLevel
import com.mutx163.qingyu.infra.DiagnosticsLogSnapshot
import com.mutx163.qingyu.infra.buildFilteredDiagnosticsRawText
import com.mutx163.qingyu.infra.countDiagnosticsLevels
import com.mutx163.qingyu.infra.filterDiagnosticsEntries
import com.mutx163.qingyu.infra.formatDiagnosticsMillis
import com.mutx163.qingyu.infra.sortDiagnosticsEntries

/**
 * 诊断日志查看器的纯 Kotlin 展示模型
 * （源：`lib/screens/live_diagnostics_log_viewer_screen.dart`）。
 *
 * 这里只放「怎么算」，不放「怎么画」：不 import Compose / Android，
 * 以便 JVM 单测直接跑。渲染层（`composeP1/.../LiveDiagnosticsLogPage.kt`）
 * 消费 [DiagnosticsLogViewState]，不自己做业务计算。
 *
 * 三块相对独立：
 * 1. [DiagnosticsLogPaging]——分页窗口状态机（贴最新端 / 冻结末端 / 加载更早）；
 * 2. [buildDiagnosticsLogEntryView] / [buildDiagnosticsHeaderRows]——单条与表头展示模型；
 * 3. [buildDiagnosticsLogViewState]——把上面两块 + 三态（加载中 / 空 / 无匹配）拼成 viewState。
 *
 * 解析、按等级过滤、计数、时间格式化全部复用 Phase 2 的 `infra/DiagnosticsLog.kt`，
 * 不在这里重写一遍。
 */

/** 结构化 / 原文两种查看方式（Dart `DiagnosticsLogViewMode`）。 */
enum class DiagnosticsLogViewMode { STRUCTURED, RAW }

/** 时间排序（Dart `DiagnosticsLogTimeSort`）。 */
enum class DiagnosticsLogTimeSort { ASCENDING, DESCENDING }

/**
 * 分页窗口状态（Dart 里散在 `_stickToLatest / _pinnedStartIndex / _windowEndPin /
 * _currentStartIndex / _visibleEntries.length` 五个字段里）。
 *
 * 窗口恒按时间**正序**建模（下标 0 = 最旧），倒序只在渲染时反转；
 * 这样两种方向的分页、「加载更早」、「贴最新端不位移」语义完全一致
 * （Dart 300-305 行注释）。
 */
data class DiagnosticsLogViewport(
    val stickToLatest: Boolean = true,
    val pinnedStartIndex: Int? = null,
    val windowEndPin: Int? = null,
    val currentStartIndex: Int = 0,
    val visibleCount: Int = 0,
) {
    /** 窗口末端（不含），正序下标。 */
    val windowEndIndex: Int get() = currentStartIndex + visibleCount

    /** 起点之前还有没显示的更早日志（Dart `_hasEarlierEntries = start > 0`）。 */
    val hasEarlierEntries: Boolean get() = currentStartIndex > 0
}

/** 等级筛选芯片（Dart `_LevelFilterChip` 的入参）。 */
data class DiagnosticsLevelChip(
    val level: DiagnosticsLogLevel,
    val label: String,
    val count: Int,
    val selected: Boolean,
)

/** 键值展示行（设备信息 chip 与条目详情行共用）。 */
data class DiagnosticsKeyValueRow(
    val label: String,
    val value: String,
)

/** 单条日志的展示模型（折叠 / 展开两种形态共用一份数据）。 */
data class DiagnosticsLogEntryView(
    val id: String,
    val level: DiagnosticsLogLevel,
    val levelLabel: String,
    val sourceLabel: String,
    val isLevelInferred: Boolean,
    val categoryLabel: String,
    val formattedTime: String?,
    val message: String,
    val collapsedText: String,
    val rawText: String,
    val detailRows: List<DiagnosticsKeyValueRow>,
    val isExpanded: Boolean,
)

/** 日志查看器整页视图状态。 */
data class DiagnosticsLogViewState(
    val title: String,
    val viewMode: DiagnosticsLogViewMode,
    val timeSort: DiagnosticsLogTimeSort,
    val selectedLevel: DiagnosticsLogLevel,
    val levelChips: List<DiagnosticsLevelChip>,
    val entries: List<DiagnosticsLogEntryView>,
    val headerRows: List<DiagnosticsKeyValueRow>,
    val isDeviceInfoExpanded: Boolean,
    val loadEarlierLabel: String?,
    val hasEarlierEntries: Boolean,
    val currentStartIndex: Int,
    val showPausedHint: Boolean,
    val isLoading: Boolean,
    val isEmpty: Boolean,
    val showNoMatching: Boolean,
    val isParsing: Boolean,
    val loadError: String?,
    val canCopy: Boolean,
    val canExport: Boolean,
    val canClear: Boolean,
    val isExporting: Boolean,
    val isClearing: Boolean,
) {
    /** 最新条目在视口底部（正序）；倒序时最新在最上方。 */
    val latestAtBottom: Boolean get() = timeSort == DiagnosticsLogTimeSort.ASCENDING
}

/**
 * 分页窗口状态机。
 *
 * 与 Dart 逐行对齐的四个状态转移都在这里，全部是纯函数：
 * 传入当前窗口，返回新窗口；调用方（Compose 的 `remember`）负责保存。
 */
object DiagnosticsLogPaging {

    /**
     * 一页条数（Dart `_pageSize = 200`）。
     *
     * 全量一次进列表会让每帧的排序/重建/拼接都膨胀，日志页因此被拖到无响应；
     * 窗口只约束「渲染多少条」，解析、计数、复制/导出仍走全量。
     */
    const val PAGE_SIZE = 200

    /** 滚到离边缘多少像素内算「贴最新端」（Dart 48）。 */
    const val STICK_EDGE_PX = 48

    /**
     * 按当前 pin / 贴最新端标记算出窗口（Dart `_rebuildVisibleEntries` 300-334 行）。
     *
     * - 贴最新端时清掉钉住起点，窗口收拢回最新一页；
     * - 钉住起点越界（日志被截断/清空重写）时同样回落最新一页；
     * - 不贴最新端且末端被冻结时，新增日志不会把正在读的内容推出窗口。
     */
    fun resolve(
        total: Int,
        state: DiagnosticsLogViewport,
        pageSize: Int = PAGE_SIZE,
    ): DiagnosticsLogViewport {
        var pin = state.pinnedStartIndex
        if (state.stickToLatest) {
            pin = null
        } else if (pin != null && pin >= total) {
            pin = null
        }

        var end = total
        val frozenPin = state.windowEndPin
        if (!state.stickToLatest && frozenPin != null) {
            val frozen = frozenPin.coerceIn(0, total)
            if (frozen > (pin ?: 0)) {
                end = frozen
            }
        }

        val start = pin ?: if (end > pageSize) end - pageSize else 0
        return state.copy(
            pinnedStartIndex = pin,
            currentStartIndex = start,
            visibleCount = end - start,
        )
    }

    /**
     * 滚动位置变化时同步「贴最新端」（Dart `_syncStickToLatest` 382-400 行）。
     *
     * 离开最新端时**起点与末端一起钉住**：只钉末端时起点仍为 null，start 会由
     * end 反推出滑动窗口，新日志每批把正在读的内容顶掉一点；两端都钉住后窗口
     * 长度恒定，既不受新增扰动，也不会随新日志无限增长。
     */
    fun onStickToLatestChange(
        state: DiagnosticsLogViewport,
        nowStick: Boolean,
    ): DiagnosticsLogViewport {
        if (nowStick && !state.stickToLatest) {
            return state.copy(
                stickToLatest = true,
                pinnedStartIndex = null,
                windowEndPin = null,
            )
        }
        if (!nowStick && state.stickToLatest) {
            return state.copy(
                stickToLatest = false,
                pinnedStartIndex = state.pinnedStartIndex ?: state.currentStartIndex,
                windowEndPin = state.windowEndIndex,
            )
        }
        return state.copy(stickToLatest = nowStick)
    }

    /**
     * 「加载更早」：把窗口起点前移一页并冻结末端
     * （Dart `_loadEarlierEntriesWithAnchor` 872-890 行的纯计算部分）。
     *
     * 已经在最早处（`currentStartIndex <= 0`）时返回原状态。
     */
    fun loadEarlier(
        state: DiagnosticsLogViewport,
        pageSize: Int = PAGE_SIZE,
    ): DiagnosticsLogViewport {
        if (state.currentStartIndex <= 0) {
            return state
        }
        return state.copy(
            stickToLatest = false,
            windowEndPin = state.windowEndPin ?: state.windowEndIndex,
            pinnedStartIndex = if (state.currentStartIndex > pageSize) {
                state.currentStartIndex - pageSize
            } else {
                0
            },
        )
    }

    /**
     * 组装等级筛选芯片（Dart `_buildLevelFilterBar` 599-621 行）。
     *
     * 文案是 `'${label} ${count}'`；计数取**全量**条目，不随筛选变化。
     */
    fun buildLevelChips(
        counts: Map<DiagnosticsLogLevel, Int>,
        selected: DiagnosticsLogLevel,
    ): List<DiagnosticsLevelChip> = DiagnosticsLogLevel.entries.map { level ->
        val count = counts[level] ?: 0
        DiagnosticsLevelChip(
            level = level,
            label = "${DiagnosticsStrings.levelLabel(level)} $count",
            count = count,
            selected = level == selected,
        )
    }
}

/** 按窗口从时间正序全量里切片；窗口越界时自动收窄，不抛 `IndexOutOfBounds`。 */
fun <T> DiagnosticsLogViewport.slice(items: List<T>): List<T> {
    if (items.isEmpty()) return emptyList()
    val end = windowEndIndex.coerceIn(0, items.size)
    val start = currentStartIndex.coerceIn(0, end)
    return items.subList(start, end)
}

/** 当前等级筛选下的全量条目，恒按时间正序（Dart `chronological`）。 */
fun chronologicalDiagnosticsEntries(
    parsed: DiagnosticsLogSnapshot,
    level: DiagnosticsLogLevel,
): List<DiagnosticsLogEntry> =
    sortDiagnosticsEntries(filterDiagnosticsEntries(parsed.entries, level), ascending = true)

/**
 * 复制 / 导出用的全量文本（Dart `_buildFullLogText` 963-968 行）。
 *
 * 按当前等级筛选拼回全部命中条目的原文，**不经过分页窗口**——导出拿到的
 * 必须是完整日志，而不是当前显示的一页。
 */
fun buildDiagnosticsFullLogText(
    parsed: DiagnosticsLogSnapshot,
    level: DiagnosticsLogLevel,
): String = buildFilteredDiagnosticsRawText(
    parsed,
    filterDiagnosticsEntries(parsed.entries, level),
)

/** 详情 / 设备信息里的键名（Dart `_prettyKey` 1499-1517 行）。 */
fun prettyDiagnosticsFieldLabel(key: String): String = when (key) {
    "exportedAt" -> DiagnosticsStrings.diagnosticsExportedAt.zh
    "time" -> DiagnosticsStrings.diagnosticsTime.zh
    "category" -> DiagnosticsStrings.diagnosticsCategory.zh
    "message" -> DiagnosticsStrings.diagnosticsMessage.zh
    "stackTrace" -> DiagnosticsStrings.diagnosticsStackTrace.zh
    "level", "severity" -> DiagnosticsStrings.diagnosticsLevelLabel.zh
    // 未知键原样返回：Dart 侧 `localizeField` 未命中时同样回落到键名本身。
    else -> key
}

/**
 * 值里的毫秒时间戳渲染成可读时间，其余原样（Dart `_inlineValue` 1519-1522 行）。
 */
fun inlineDiagnosticsValue(value: String): String =
    formatDiagnosticsMillis(value) ?: value

/** 设备与导出信息（表头 kv）→ 展示行，保持解析顺序。 */
fun buildDiagnosticsHeaderRows(parsed: DiagnosticsLogSnapshot): List<DiagnosticsKeyValueRow> =
    parsed.headerEntries.map { (key, value) ->
        DiagnosticsKeyValueRow(
            label = prettyDiagnosticsFieldLabel(key),
            value = inlineDiagnosticsValue(value),
        )
    }

/**
 * 单条日志 → 展示模型。
 *
 * - 折叠行：`时间 + 空格 + 消息`，没有时间字段时不带前缀（Dart `_buildCollapsed`）；
 * - 详情行：`detailEntries` 已剔掉 time/category/message/level/severity/source，
 *   这里只负责键名翻译与值的时间格式化。
 */
fun buildDiagnosticsLogEntryView(
    entry: DiagnosticsLogEntry,
    expanded: Boolean,
): DiagnosticsLogEntryView {
    val formattedTime = entry.formattedTime
    val message = entry.message
    return DiagnosticsLogEntryView(
        id = entry.stableId,
        level = entry.level,
        levelLabel = DiagnosticsStrings.levelLabel(entry.level),
        sourceLabel = if (entry.isNativeSource) {
            DiagnosticsStrings.appLogsSourceNative.zh
        } else {
            DiagnosticsStrings.appLogsSourceApp.zh
        },
        isLevelInferred = entry.isLevelInferred,
        // 分类 / 消息的多语言映射（Dart `AppLogMessageLocalizer`，229 个键）属于跨页共享件，
        // 不在本批写作用域内；这里先原样带出，见认领文件的「遗留」。
        categoryLabel = entry.category,
        formattedTime = formattedTime,
        message = message,
        collapsedText = if (formattedTime == null) message else "$formattedTime $message",
        rawText = entry.rawBlock.trim(),
        detailRows = entry.detailEntries.map { (key, value) ->
            DiagnosticsKeyValueRow(
                label = prettyDiagnosticsFieldLabel(key),
                value = inlineDiagnosticsValue(value),
            )
        },
        isExpanded = expanded,
    )
}

/**
 * 组装整页视图状态。
 *
 * 三态互斥关系与 Dart 一致：
 * - `isLoading`：首帧还没解析出任何条目（显示进度圈，见 `_buildLogBody` 578-580 行）；
 * - `isEmpty`：解析完成且全量没有条目（`_parsed.entries.isEmpty && !_parsing`）；
 * - `showNoMatching`：有条目但当前等级筛不出（`_buildStructuredView` 680-682 行）。
 * 加载失败时三者都不成立——错误态不复用空态标题（Dart 550 行注释）。
 */
@Suppress("LongParameterList")
fun buildDiagnosticsLogViewState(
    title: String,
    parsed: DiagnosticsLogSnapshot,
    viewport: DiagnosticsLogViewport,
    viewMode: DiagnosticsLogViewMode = DiagnosticsLogViewMode.STRUCTURED,
    timeSort: DiagnosticsLogTimeSort = DiagnosticsLogTimeSort.ASCENDING,
    selectedLevel: DiagnosticsLogLevel = DiagnosticsLogLevel.ALL,
    expandedEntryIds: Set<String> = emptySet(),
    isDeviceInfoExpanded: Boolean = false,
    isRecordingEnabled: Boolean? = null,
    isInitializing: Boolean = false,
    isParsing: Boolean = false,
    loadError: String? = null,
    isExporting: Boolean = false,
    isClearing: Boolean = false,
    canExport: Boolean = true,
    canClear: Boolean = true,
): DiagnosticsLogViewState {
    val chronological = chronologicalDiagnosticsEntries(parsed, selectedLevel)
    val resolved = DiagnosticsLogPaging.resolve(chronological.size, viewport)
    val visible = resolved.slice(chronological)
    // 倒序渲染：正序窗口反转显示（最新条目 = 窗口末端 = 视口顶部）。
    val ordered = if (timeSort == DiagnosticsLogTimeSort.ASCENDING) visible else visible.asReversed()
    val entryViews = ordered.map { entry ->
        buildDiagnosticsLogEntryView(entry, expanded = expandedEntryIds.contains(entry.stableId))
    }

    val hasEntries = parsed.entries.isNotEmpty()
    val hasLoadError = loadError != null

    return DiagnosticsLogViewState(
        title = parsed.title.ifEmpty { title },
        viewMode = viewMode,
        timeSort = timeSort,
        selectedLevel = selectedLevel,
        levelChips = DiagnosticsLogPaging.buildLevelChips(
            counts = countDiagnosticsLevels(parsed.entries),
            selected = selectedLevel,
        ),
        entries = entryViews,
        headerRows = buildDiagnosticsHeaderRows(parsed),
        isDeviceInfoExpanded = isDeviceInfoExpanded,
        loadEarlierLabel = if (resolved.hasEarlierEntries) {
            DiagnosticsStrings.diagnosticsLoadEarlierLabel
                .filled("count", resolved.currentStartIndex.toString())
        } else {
            null
        },
        hasEarlierEntries = resolved.hasEarlierEntries,
        currentStartIndex = resolved.currentStartIndex,
        showPausedHint = isRecordingEnabled == false && hasEntries,
        isLoading = isInitializing && !hasEntries,
        isEmpty = !hasEntries && !isParsing && !hasLoadError,
        showNoMatching = visible.isEmpty() && hasEntries,
        isParsing = isParsing,
        loadError = loadError,
        canCopy = hasEntries,
        canExport = canExport && !isExporting && hasEntries,
        canClear = canClear && !isClearing,
        isExporting = isExporting,
        isClearing = isClearing,
    )
}
