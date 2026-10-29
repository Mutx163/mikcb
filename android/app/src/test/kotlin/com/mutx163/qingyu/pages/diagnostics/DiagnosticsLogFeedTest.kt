package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.infra.DiagnosticsLogLevel
import com.mutx163.qingyu.infra.DiagnosticsLogSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日志喂入状态机测试（源：`lib/screens/live_diagnostics_log_viewer_screen.dart`）。
 *
 * 钉的是三条最容易错的转移：
 * - `_applyLoadedLog` 188-243 行：新正文以旧正文为前缀 ⇒ **增量**（只解析新增段），
 *   否则整份重解析（日志被截断 / 清空后重写）；正文没变 ⇒ 只把 loading 落回 false；
 * - `_clearLogs` 1013-1021 行：清空成功后正文与解析结果一起复位；
 * - `_syncStickToLatest` 382-400 行 / 分页窗口 300-334 行：切换筛选解钉、
 *   「加载更早」之后条目在列表里的下标换算。
 */
class DiagnosticsLogFeedTest {

    private val title = "应用日志"

    private fun header(extraVersion: String = "1.2.3+456"): String =
        "log_export_title\nplatform=android\nversion=$extraVersion\n----"

    private fun block(time: Long, level: String, message: String): String =
        "time=$time\nlevel=$level\ncategory=update_check\nmessage=$message"

    @Test
    fun `首帧整份解析并补上入口标题`() {
        val loaded = header() + "\n" + block(1L, "info", "第一条") + "\n\n" + block(2L, "warn", "第二条")
        val state = DiagnosticsLogFeedLogic.onLoaded(DiagnosticsLogFeedState.INITIAL, loaded, title)
        assertEquals(2, state.parsed.entries.size)
        // 解析出的 title 是文件头首行（Dart 同口径），页面标题另由入口标题决定。
        assertEquals("log_export_title", state.parsed.title)
        assertEquals("android", state.parsed.headerEntries["platform"])
        assertFalse(state.isInitializing)
        assertFalse(state.isParsing)
        assertNull(state.loadError)
        assertTrue(state.body.isNotEmpty())
    }

    @Test
    fun `页面标题用入口标题而不是文件头首行`() {
        val loaded = header() + "\n" + block(1L, "info", "一条")
        val feed = DiagnosticsLogFeedLogic.onLoaded(DiagnosticsLogFeedState.INITIAL, loaded, title)
        val state = buildDiagnosticsLogViewState(
            title = title,
            parsed = feed.parsed,
            viewport = DiagnosticsLogViewport(),
        )
        // Dart 页头是 `Text(widget.title)`，`parsed.title` 不参与渲染；
        // 否则真数据一进来标题会变成 `log_export_title`。
        assertEquals(title, state.title)
    }

    @Test
    fun `正文前缀相同时走增量_不重复解析旧条目`() {
        val first = header() + "\n" + block(1L, "info", "第一条")
        val firstState = DiagnosticsLogFeedLogic.onLoaded(DiagnosticsLogFeedState.INITIAL, first, title)
        val second = first + "\n\n" + block(2L, "error", "第二条")
        val secondState = DiagnosticsLogFeedLogic.onLoaded(firstState, second, title)
        // 增量：旧条目原样保留、只多一条（重复解析会把第一条变两条）。
        assertEquals(2, secondState.parsed.entries.size)
        assertEquals("第一条", secondState.parsed.entries[0].message)
        assertEquals("第二条", secondState.parsed.entries[1].message)
        assertEquals(DiagnosticsLogLevel.ERROR, secondState.parsed.entries[1].level)
        assertTrue(secondState.body.startsWith(firstState.body))
    }

    @Test
    fun `正文被截断后整份重解析而不是继续追加`() {
        val first = header() + "\n" + block(1L, "info", "很早的一条") + "\n\n" + block(2L, "info", "第二条")
        val firstState = DiagnosticsLogFeedLogic.onLoaded(DiagnosticsLogFeedState.INITIAL, first, title)
        // 截断后的正文不再以旧正文为前缀 ⇒ 走全量重解析，旧条目必须消失。
        val truncated = header() + "\n" + block(9L, "warn", "截断后剩下的一条")
        val secondState = DiagnosticsLogFeedLogic.onLoaded(firstState, truncated, title)
        assertEquals(1, secondState.parsed.entries.size)
        assertEquals("截断后剩下的一条", secondState.parsed.entries[0].message)
    }

    @Test
    fun `正文没变时不动解析结果只把加载态落回`() {
        val loaded = header() + "\n" + block(1L, "info", "只有一条")
        val state = DiagnosticsLogFeedLogic.onLoaded(DiagnosticsLogFeedState.INITIAL, loaded, title)
        val parsing = state.copy(isParsing = true)
        val same = DiagnosticsLogFeedLogic.onLoaded(parsing, loaded, title)
        assertEquals(state.parsed.entries, same.parsed.entries)
        assertFalse(same.isParsing)
        assertFalse(same.isInitializing)
    }

    @Test
    fun `读失败走错误态且与空态互斥`() {
        val failed = DiagnosticsLogFeedLogic.onLoadError(DiagnosticsLogFeedState.INITIAL, "磁盘满了")
        assertEquals("磁盘满了", failed.loadError)
        assertFalse(failed.isInitializing)
        // 重试：只把 initializing 打开、清错误。
        val retried = DiagnosticsLogFeedLogic.onLoadStarted(failed)
        assertTrue(retried.isInitializing)
        assertNull(retried.loadError)
    }

    @Test
    fun `清空成功后正文与解析结果一起复位`() {
        val loaded = header() + "\n" + block(1L, "info", "一条")
        val state = DiagnosticsLogFeedLogic.onLoaded(DiagnosticsLogFeedState.INITIAL, loaded, title)
        val cleared = DiagnosticsLogFeedLogic.onCleared(state)
        assertEquals("", cleared.body)
        assertTrue(cleared.parsed.entries.isEmpty())
        assertNull(cleared.loadError)
    }

    @Test
    fun `只有 live 源在空文件时自己退出`() {
        // 真·空文本（连头部都没有）才算空：Dart 判的是 `body.trim().isEmpty`。
        val empty = DiagnosticsLogFeedLogic.onLoaded(DiagnosticsLogFeedState.INITIAL, "", title)
        assertTrue(empty.parsed.entries.isEmpty())
        assertTrue(DiagnosticsLogFeedLogic.shouldPopOnEmpty(empty, popsOnEmpty = true))
        assertFalse(DiagnosticsLogFeedLogic.shouldPopOnEmpty(empty, popsOnEmpty = false))
        val loaded = DiagnosticsLogFeedLogic.onLoaded(
            DiagnosticsLogFeedState.INITIAL,
            header() + "\n" + block(1L, "info", "有内容"),
            title,
        )
        assertFalse(DiagnosticsLogFeedLogic.shouldPopOnEmpty(loaded, popsOnEmpty = true))
        // 只有头部、没有正文：正文非空（Dart `_extractBody` 没有 `----` 分隔时整份当正文），
        // 所以**不**触发空态退出——与 Dart 一致。
        val headerOnly = DiagnosticsLogFeedLogic.onLoaded(DiagnosticsLogFeedState.INITIAL, header(), title)
        assertTrue(headerOnly.parsed.entries.isEmpty())
        assertFalse(DiagnosticsLogFeedLogic.shouldPopOnEmpty(headerOnly, popsOnEmpty = true))
    }

    @Test
    fun `切换等级筛选解除起点与末端冻结`() {
        val pinned = DiagnosticsLogViewport(
            stickToLatest = false,
            pinnedStartIndex = 400,
            windowEndPin = 600,
            currentStartIndex = 400,
            visibleCount = 200,
        )
        val reset = resetWindowForFilter(pinned)
        assertNull(reset.pinnedStartIndex)
        assertNull(reset.windowEndPin)
        // 贴最新端标记不由筛选改变（Dart 只清两个 pin）。
        assertFalse(reset.stickToLatest)
    }

    @Test
    fun `贴最新端的判据按方向取反`() {
        assertTrue(isStuckToLatest(latestAtBottom = true, canScrollForward = false, canScrollBackward = true))
        assertFalse(isStuckToLatest(latestAtBottom = true, canScrollForward = true, canScrollBackward = true))
        assertTrue(isStuckToLatest(latestAtBottom = false, canScrollForward = true, canScrollBackward = false))
        assertFalse(isStuckToLatest(latestAtBottom = false, canScrollForward = true, canScrollBackward = true))
    }

    @Test
    fun `时间排序偏好按 Dart 的字符串口径往返`() {
        assertEquals("ascending", timeSortPreferenceValue(DiagnosticsLogTimeSort.ASCENDING))
        assertEquals("descending", timeSortPreferenceValue(DiagnosticsLogTimeSort.DESCENDING))
        assertEquals(DiagnosticsLogTimeSort.DESCENDING, timeSortFromPreference("descending"))
        assertEquals(DiagnosticsLogTimeSort.ASCENDING, timeSortFromPreference("ascending"))
        assertEquals(DiagnosticsLogTimeSort.ASCENDING, timeSortFromPreference(null))
        assertEquals(DiagnosticsLogTimeSort.ASCENDING, timeSortFromPreference("garbage"))
    }

    @Test
    fun `列表下标换算把设备信息卡与更早入口行算进去`() {
        val blocks = (1..202).joinToString("\n\n") { block(it.toLong(), "info", "第 $it 条") }
        val parsed = com.mutx163.qingyu.infra.parseDiagnosticsLog(header() + "\n" + blocks)
        // 窗口钉在「还剩 2 条更早」的位置：此时列表顶部有设备信息卡 + 「加载更早」行。
        val state = buildDiagnosticsLogViewState(
            title = title,
            parsed = parsed,
            viewport = DiagnosticsLogViewport(stickToLatest = false, pinnedStartIndex = 200),
        )
        assertTrue(state.headerRows.isNotEmpty())
        assertTrue(state.entries.size == 2)
        assertEquals(2, diagnosticsItemIndexOfEntry(state, state.entries[0].id))
        assertEquals(3, diagnosticsItemIndexOfEntry(state, state.entries[1].id))
        assertEquals(state.entries[1].id, diagnosticsEntryIdAtItemIndex(state, 3))
        // 0 = 设备信息卡，1 = 更早入口行，都不是条目。
        assertNull(diagnosticsEntryIdAtItemIndex(state, 0))
        assertNull(diagnosticsEntryIdAtItemIndex(state, 1))
        assertNull(diagnosticsItemIndexOfEntry(state, "不存在"))
    }

    @Test
    fun `没有设备信息卡时下标从 0 开始`() {
        val parsed = DiagnosticsLogSnapshot.EMPTY.copy(
            title = title,
            entries = emptyList(),
        )
        val state = buildDiagnosticsLogViewState(title = title, parsed = parsed, viewport = DiagnosticsLogViewport())
        assertTrue(state.headerRows.isEmpty())
        assertNull(diagnosticsItemIndexOfEntry(state, "x"))
    }

    @Test
    fun `贴最新端要滚到的那一端按方向区分`() {
        assertEquals(4, latestEdgeItemIndex(latestAtBottom = true, itemCount = 5))
        assertEquals(0, latestEdgeItemIndex(latestAtBottom = false, itemCount = 5))
        assertEquals(0, latestEdgeItemIndex(latestAtBottom = true, itemCount = 0))
    }
}
