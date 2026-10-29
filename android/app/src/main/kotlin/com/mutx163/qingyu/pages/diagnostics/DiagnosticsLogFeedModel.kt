package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.infra.DiagnosticsLogSnapshot
import com.mutx163.qingyu.infra.appendDiagnosticsLogBody
import com.mutx163.qingyu.infra.extractAppLogBody
import com.mutx163.qingyu.infra.parseDiagnosticsLog

/**
 * 日志查看器的**数据喂入状态机**（源：`lib/screens/live_diagnostics_log_viewer_screen.dart`
 * 的 `_applyLoadedLog` 188-243 行 / `_parseFullLogText` 273-298 行 / `_clearLogs` 1001-1037 行）。
 *
 * 抽出来的理由：Dart 那三条状态转移直接写在 `State` 里、和 `setState` 缠在一起，
 * Kotlin 侧如果照抄进 Compose，就只能靠真机看「有没有重复条目 / 追加有没有生效」。
 * 这里做成纯函数后可用 JVM 单测钉住「增量 vs 全量重解析」这条最容易错的路径。
 *
 * 与 Dart 的两个关键判定：
 * 1. **增量**：新正文以前一份正文为前缀且更长 ⇒ 只解析新增那段（`appendDiagnosticsLogBody`）；
 *    否则整份重解析（日志被截断 / 清空后重写 / 换了源）。
 * 2. **正文相同**：不动解析结果，只把 `isInitializing` / `isParsing` 落回 false
 *    （Dart 197-204 行：轮询每秒会重复推同一份文本）。
 */
data class DiagnosticsLogFeedState(
    /** `----` 之后的正文（Dart `_lastBody`），用来判定增量。 */
    val body: String = "",
    val parsed: DiagnosticsLogSnapshot = DiagnosticsLogSnapshot.EMPTY,
    /** 首帧还没读到任何内容（Dart `_initializing`）⇒ 页面显示进度圈。 */
    val isInitializing: Boolean = true,
    /** 正在解析（Dart `_parsing`）⇒ 筛选条尾部的小进度圈。 */
    val isParsing: Boolean = false,
    /** 读文件失败（Dart `_loadError`）⇒ 错误态，不复用空态标题。 */
    val loadError: String? = null,
) {
    companion object {
        val INITIAL = DiagnosticsLogFeedState()
    }
}

object DiagnosticsLogFeedLogic {

    /**
     * 收到一份新的完整文本（Dart `_applyLoadedLog`）。
     *
     * [fallbackTitle] 是入口标题（`LogViewerEntryLogic.configFor(...).title`），
     * 只在解析结果自己没拿到标题时补上（Dart 284-286 行）。
     */
    fun onLoaded(
        current: DiagnosticsLogFeedState,
        loaded: String,
        fallbackTitle: String,
    ): DiagnosticsLogFeedState {
        val body = extractAppLogBody(loaded)
        if (body == current.body) {
            if (current.isInitializing || current.isParsing) {
                return current.copy(isInitializing = false, isParsing = false, loadError = null)
            }
            return current
        }
        val previousBody = current.body
        val isAppend = previousBody.isNotEmpty() &&
            body.startsWith(previousBody) &&
            body.length > previousBody.length
        if (isAppend) {
            val appended = body.substring(previousBody.length)
            return current.copy(
                body = body,
                parsed = appendDiagnosticsLogBody(
                    current = current.parsed,
                    appendedBody = appended,
                    mergedFullText = loaded,
                ),
                isInitializing = false,
                isParsing = false,
                loadError = null,
            )
        }
        val parsed = parseDiagnosticsLog(loaded, fallbackTitle)
        return current.copy(
            body = body,
            parsed = if (parsed.title.isEmpty()) parsed.copy(title = fallbackTitle) else parsed,
            isInitializing = false,
            isParsing = false,
            loadError = null,
        )
    }

    /** 读到空文件且这个入口要求「空就自己退出」（只有 live 源）时是否应当 pop。 */
    fun shouldPopOnEmpty(current: DiagnosticsLogFeedState, popsOnEmpty: Boolean): Boolean =
        popsOnEmpty && current.body.isBlank() && current.parsed.entries.isEmpty()

    /** 读文件/解析抛错（Dart 175-184 / 457-466 行）：三态一起落回，错误走 `loadError`。 */
    fun onLoadError(current: DiagnosticsLogFeedState, message: String): DiagnosticsLogFeedState =
        current.copy(isInitializing = false, isParsing = false, loadError = message)

    /** 开始一次一次性加载（Dart `_loadLogs` 446-450 行），只用于错误态的重试按钮。 */
    fun onLoadStarted(current: DiagnosticsLogFeedState): DiagnosticsLogFeedState =
        current.copy(isInitializing = true, loadError = null)

    /** 清空成功后的复位（Dart `_clearLogs` 1013-1021 行）：正文与解析结果都清掉。 */
    fun onCleared(current: DiagnosticsLogFeedState): DiagnosticsLogFeedState =
        current.copy(
            body = "",
            parsed = DiagnosticsLogSnapshot.EMPTY,
            isParsing = false,
            loadError = null,
        )
}

/**
 * 切换等级筛选时的窗口复位（Dart `_buildLevelFilterBar` 605-615 行）：
 * 起点与冻结末端一起解除，回到「贴最新一页」。
 */
fun resetWindowForFilter(viewport: DiagnosticsLogViewport): DiagnosticsLogViewport =
    viewport.copy(pinnedStartIndex = null, windowEndPin = null)

/**
 * 是否贴在「最新」端（Dart `_syncStickToLatest` 382-400 行的判据）。
 *
 * Dart 用滚动像素判（正序 `pixels >= max - 48`，倒序 `pixels <= 48`）；Compose 侧
 * 直接问 `LazyListState` 还能不能往那个方向滚，等价且不依赖像素单位。
 * 48px 的容差因此变成「恰好到底」，差别只在触底前最后一小段，不影响行为。
 */
fun isStuckToLatest(
    latestAtBottom: Boolean,
    canScrollForward: Boolean,
    canScrollBackward: Boolean,
): Boolean = if (latestAtBottom) !canScrollForward else !canScrollBackward

/** 时间排序偏好 → 盘上值（Dart `DiagnosticsLogViewerPreferences.saveTimeSort`）。 */
fun timeSortPreferenceValue(sort: DiagnosticsLogTimeSort): String = when (sort) {
    DiagnosticsLogTimeSort.ASCENDING -> "ascending"
    DiagnosticsLogTimeSort.DESCENDING -> "descending"
}

/** 盘上值 → 时间排序（Dart `loadTimeSort`：除 `descending` 外一律回落正序）。 */
fun timeSortFromPreference(raw: String?): DiagnosticsLogTimeSort =
    if (raw == "descending") DiagnosticsLogTimeSort.DESCENDING else DiagnosticsLogTimeSort.ASCENDING

/**
 * 条目在 `LazyColumn` 里的下标。
 *
 * 列表结构（`LiveDiagnosticsLogPage` 的 `DiagnosticsLogList`）与 Dart 一致：
 * `[设备信息卡]? [更早入口行(仅正序在顶部)]? 条目… [更早入口行(仅倒序在末尾)]?`
 * 「加载更早」的锚定要用它把「原先第一可见条目」换算回新下标。
 */
fun diagnosticsItemIndexOfEntry(
    viewState: DiagnosticsLogViewState,
    entryId: String,
): Int? {
    val index = viewState.entries.indexOfFirst { it.id == entryId }
    if (index < 0) {
        return null
    }
    var offset = 0
    if (viewState.headerRows.isNotEmpty()) offset++
    if (viewState.loadEarlierLabel != null && viewState.latestAtBottom) offset++
    return offset + index
}

/** 指定列表下标上是不是某条日志（不是则 null：设备信息卡 / 更早入口行）。 */
fun diagnosticsEntryIdAtItemIndex(
    viewState: DiagnosticsLogViewState,
    itemIndex: Int,
): String? {
    if (itemIndex < 0) return null
    var offset = 0
    if (viewState.headerRows.isNotEmpty()) offset++
    if (viewState.loadEarlierLabel != null && viewState.latestAtBottom) offset++
    val entryIndex = itemIndex - offset
    return viewState.entries.getOrNull(entryIndex)?.id
}

/** 贴最新端时应当滚到哪个下标（正序=最后一项，倒序=第一项）。 */
fun latestEdgeItemIndex(latestAtBottom: Boolean, itemCount: Int): Int {
    if (itemCount <= 0) return 0
    return if (latestAtBottom) itemCount - 1 else 0
}
