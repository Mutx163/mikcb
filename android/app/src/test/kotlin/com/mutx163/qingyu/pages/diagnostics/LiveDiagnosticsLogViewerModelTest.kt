package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.infra.DiagnosticsLogEntry
import com.mutx163.qingyu.infra.DiagnosticsLogLevel
import com.mutx163.qingyu.infra.DiagnosticsLogSnapshot
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.TimeZone

/**
 * 日志查看器模型层测试（源：`lib/screens/live_diagnostics_log_viewer_screen.dart`）。
 *
 * 期望值全部从 Dart 源手推，不抄实现：
 * - 分页窗口/贴最新端/冻结末端：Dart `_rebuildVisibleEntries`（300-334 行）、
 *   `_syncStickToLatest`（382-400 行）、`_loadEarlierEntriesWithAnchor`（872-911 行）；
 * - 等级芯片文案：Dart `_buildLevelFilterBar`（599-621 行）`'${label} ${count}'`；
 * - 折叠行文案：Dart `_buildCollapsed`（1290-1314 行）时间前缀 + 消息；
 * - 复制/导出文本：Dart `_buildFullLogText`（963-968 行）+ `infra` 的
 *   `buildFilteredDiagnosticsRawText`；
 * - 三态互斥（加载中 / 空 / 无匹配）：Dart `_buildLogBody`（577-588 行）、
 *   `_buildStructuredView`（679-682 行）。
 *
 * 时区：Dart 与 Kotlin 两侧都走系统本地时区格式化时间，测试固定为 Asia/Shanghai，
 * 期望值按该时区手推（epoch 0 → `1970-01-01 08:00:00`）。
 */
class LiveDiagnosticsLogViewerModelTest {

    private lateinit var originalTimeZone: TimeZone

    @Before
    fun fixTimeZone() {
        originalTimeZone = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"))
    }

    @After
    fun restoreTimeZone() {
        TimeZone.setDefault(originalTimeZone)
    }

    private fun entry(
        timeMillis: Long,
        level: DiagnosticsLogLevel,
        message: String,
        category: String = "app_logger",
        extra: Map<String, String> = emptyMap(),
        isLevelInferred: Boolean = false,
    ): DiagnosticsLogEntry {
        val fields = linkedMapOf<String, String>()
        fields["time"] = timeMillis.toString()
        fields["level"] = level.name.lowercase()
        fields["category"] = category
        fields["message"] = message
        for ((k, v) in extra) fields[k] = v
        val raw = fields.entries.joinToString("\n") { "${it.key}=${it.value}" }
        return DiagnosticsLogEntry(
            rawBlock = raw,
            fields = fields,
            level = level,
            isLevelInferred = isLevelInferred,
        )
    }

    private fun snapshot(entries: List<DiagnosticsLogEntry>): DiagnosticsLogSnapshot =
        DiagnosticsLogSnapshot(
            title = "应用日志",
            rawHeader = "应用日志",
            fullText = "",
            headerEntries = linkedMapOf("app" to "qingyu", "version" to "1.0.0"),
            entries = entries,
        )

    // ==========================================
    // 1. 分页窗口（默认只渲染最新一页）
    // ==========================================

    @Test
    fun `贴最新端时窗口只覆盖最后一页 200 条`() {
        val viewport = DiagnosticsLogPaging.resolve(
            total = 500,
            state = DiagnosticsLogViewport(),
        )

        // Dart：end = total = 500；start = 500 > 200 ? 500-200 : 0 = 300。
        assertEquals(300, viewport.currentStartIndex)
        assertEquals(500, viewport.windowEndIndex)
        assertEquals(200, viewport.visibleCount)
        assertTrue(viewport.hasEarlierEntries)
        assertTrue(viewport.stickToLatest)
        assertNull(viewport.pinnedStartIndex)
    }

    @Test
    fun `不足一页时不出现加载更早入口`() {
        val viewport = DiagnosticsLogPaging.resolve(120, DiagnosticsLogViewport())

        assertEquals(0, viewport.currentStartIndex)
        assertEquals(120, viewport.visibleCount)
        assertFalse(viewport.hasEarlierEntries)
    }

    @Test
    fun `没有日志时窗口为空且不出现加载更早入口`() {
        val viewport = DiagnosticsLogPaging.resolve(0, DiagnosticsLogViewport())

        assertEquals(0, viewport.currentStartIndex)
        assertEquals(0, viewport.visibleCount)
        assertFalse(viewport.hasEarlierEntries)
    }

    @Test
    fun `冻结末端时新增日志不把正在读的内容推出窗口`() {
        // 用户在正序下级窗口里往上滚走了：窗口钉在 500..700（200 条）。
        val reading = DiagnosticsLogPaging.resolve(
            total = 1000,
            state = DiagnosticsLogViewport(
                stickToLatest = false,
                pinnedStartIndex = 500,
                windowEndPin = 700,
            ),
        )
        assertEquals(500, reading.currentStartIndex)
        assertEquals(700, reading.windowEndIndex)
        assertEquals(200, reading.visibleCount)

        // 流式新增 50 条：正序窗口末端被冻结，start/end 都不动（Dart 320-329 行）。
        val afterAppend = DiagnosticsLogPaging.resolve(
            total = 1050,
            state = reading,
        )
        assertEquals(500, afterAppend.currentStartIndex)
        assertEquals(700, afterAppend.windowEndIndex)
        assertEquals(200, afterAppend.visibleCount)
    }

    @Test
    fun `冻结末端落在钉住起点之前时忽略冻结`() {
        // Dart：`if (frozen > (_pinnedStartIndex ?? 0)) end = frozen;` —— 不成立时 end 仍是 total。
        val viewport = DiagnosticsLogPaging.resolve(
            total = 500,
            state = DiagnosticsLogViewport(
                stickToLatest = false,
                pinnedStartIndex = 300,
                windowEndPin = 200,
            ),
        )

        assertEquals(300, viewport.currentStartIndex)
        assertEquals(500, viewport.windowEndIndex)
        assertEquals(200, viewport.visibleCount)
    }

    @Test
    fun `钉住起点越界时回落最新一页`() {
        // 日志被截断/清空重写后 pin 会 >= total（Dart 315-317 行把它清空）。
        val viewport = DiagnosticsLogPaging.resolve(
            total = 500,
            state = DiagnosticsLogViewport(
                stickToLatest = false,
                pinnedStartIndex = 700,
                windowEndPin = 900,
            ),
        )

        assertNull(viewport.pinnedStartIndex)
        assertEquals(300, viewport.currentStartIndex)
        assertEquals(200, viewport.visibleCount)
    }

    // ==========================================
    // 2. 贴最新端状态机
    // ==========================================

    @Test
    fun `滚动离开最新端时起点与末端一起钉住`() {
        val latest = DiagnosticsLogPaging.resolve(500, DiagnosticsLogViewport())
        val reading = DiagnosticsLogPaging.onStickToLatestChange(latest, nowStick = false)

        assertFalse(reading.stickToLatest)
        assertEquals(300, reading.pinnedStartIndex)
        // Dart：`_windowEndPin = _currentStartIndex + _visibleEntries.length`
        assertEquals(500, reading.windowEndPin)
    }

    @Test
    fun `回到最新端时清掉两端钉住并收拢回最新一页`() {
        val reading = DiagnosticsLogPaging.onStickToLatestChange(
            DiagnosticsLogPaging.resolve(500, DiagnosticsLogViewport()),
            nowStick = false,
        )
        val back = DiagnosticsLogPaging.onStickToLatestChange(reading, nowStick = true)
            .let { DiagnosticsLogPaging.resolve(total = 900, state = it) }

        assertTrue(back.stickToLatest)
        assertNull(back.pinnedStartIndex)
        assertNull(back.windowEndPin)
        // 新增到 900 条后仍只渲染最后 200 条。
        assertEquals(700, back.currentStartIndex)
        assertEquals(200, back.visibleCount)
    }

    @Test
    fun `点加载更早把起点前移一页并冻结在最新端`() {
        val latest = DiagnosticsLogPaging.resolve(500, DiagnosticsLogViewport())
        val earlier = DiagnosticsLogPaging.loadEarlier(latest)
            .let { DiagnosticsLogPaging.resolve(total = 500, state = it) }

        assertFalse(earlier.stickToLatest)
        assertEquals(100, earlier.currentStartIndex)
        assertEquals(500, earlier.windowEndIndex)
        assertEquals(400, earlier.visibleCount)

        // 再点一次：起点归零，窗口覆盖全部 500 条。
        val oldest = DiagnosticsLogPaging.loadEarlier(earlier)
            .let { DiagnosticsLogPaging.resolve(total = 500, state = it) }
        assertEquals(0, oldest.currentStartIndex)
        assertEquals(500, oldest.visibleCount)
        assertFalse(oldest.hasEarlierEntries)
    }

    @Test
    fun `已在最早处时加载更早不变`() {
        val oldest = DiagnosticsLogPaging.resolve(
            120,
            DiagnosticsLogViewport(stickToLatest = false, pinnedStartIndex = 0),
        )
        assertEquals(oldest, DiagnosticsLogPaging.loadEarlier(oldest))
    }

    // ==========================================
    // 3. 等级筛选与排序
    // ==========================================

    @Test
    fun `等级芯片文案是等级名加计数并以全部开头`() {
        val counts = mapOf(
            DiagnosticsLogLevel.ALL to 7,
            DiagnosticsLogLevel.ERROR to 2,
            DiagnosticsLogLevel.WARN to 1,
            DiagnosticsLogLevel.INFO to 3,
            DiagnosticsLogLevel.DEBUG to 1,
            DiagnosticsLogLevel.VERBOSE to 0,
        )

        val chips = DiagnosticsLogPaging.buildLevelChips(counts, DiagnosticsLogLevel.WARN)

        assertEquals(
            listOf("全部 7", "错误 2", "警告 1", "信息 3", "调试 1", "详细 0"),
            chips.map { it.label },
        )
        assertEquals(
            listOf(
                DiagnosticsLogLevel.ALL,
                DiagnosticsLogLevel.ERROR,
                DiagnosticsLogLevel.WARN,
                DiagnosticsLogLevel.INFO,
                DiagnosticsLogLevel.DEBUG,
                DiagnosticsLogLevel.VERBOSE,
            ),
            chips.map { it.level },
        )
        assertEquals(listOf(false, false, true, false, false, false), chips.map { it.selected })
    }

    @Test
    fun `缺失计数按 0 显示`() {
        val chips = DiagnosticsLogPaging.buildLevelChips(
            mapOf(DiagnosticsLogLevel.ALL to 0),
            DiagnosticsLogLevel.ALL,
        )
        assertEquals(
            listOf("全部 0", "错误 0", "警告 0", "信息 0", "调试 0", "详细 0"),
            chips.map { it.label },
        )
    }

    @Test
    fun `正序渲染按时间从旧到新`() {
        val state = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = snapshot(
                listOf(
                    entry(3_000, DiagnosticsLogLevel.INFO, "第三条"),
                    entry(1_000, DiagnosticsLogLevel.INFO, "第一条"),
                    entry(2_000, DiagnosticsLogLevel.INFO, "第二条"),
                ),
            ),
            viewport = DiagnosticsLogViewport(),
            timeSort = DiagnosticsLogTimeSort.ASCENDING,
        )

        assertEquals(listOf("第一条", "第二条", "第三条"), state.entries.map { it.message })
    }

    @Test
    fun `倒序渲染是正序窗口的整体反转`() {
        val parsed = snapshot(
            listOf(
                entry(3_000, DiagnosticsLogLevel.INFO, "第三条"),
                entry(1_000, DiagnosticsLogLevel.INFO, "第一条"),
                entry(2_000, DiagnosticsLogLevel.INFO, "第二条"),
            ),
        )
        val state = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = parsed,
            viewport = DiagnosticsLogViewport(),
            timeSort = DiagnosticsLogTimeSort.DESCENDING,
        )

        assertEquals(listOf("第三条", "第二条", "第一条"), state.entries.map { it.message })
    }

    @Test
    fun `等级筛选只留下对应等级且计数仍按全量`() {
        val parsed = snapshot(
            listOf(
                entry(1_000, DiagnosticsLogLevel.ERROR, "炸了"),
                entry(2_000, DiagnosticsLogLevel.INFO, "正常"),
                entry(3_000, DiagnosticsLogLevel.WARN, "小心"),
            ),
        )
        val state = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = parsed,
            viewport = DiagnosticsLogViewport(),
            selectedLevel = DiagnosticsLogLevel.ERROR,
        )

        assertEquals(listOf("炸了"), state.entries.map { it.message })
        // 芯片计数是全量口径，不随筛选变化（Dart `_levelCounts` 由 `_parsed.entries` 算出）。
        assertEquals("全部 3", state.levelChips.first().label)
        assertEquals("错误 1", state.levelChips[1].label)
    }

    // ==========================================
    // 4. 单条日志的展示模型
    // ==========================================

    @Test
    fun `折叠行是时间前缀加消息`() {
        val view = buildDiagnosticsLogEntryView(
            entry(0L, DiagnosticsLogLevel.INFO, "启动完成"),
            expanded = false,
        )

        assertEquals("1970-01-01 08:00:00 启动完成", view.collapsedText)
        assertEquals("1970-01-01 08:00:00", view.formattedTime)
        assertFalse(view.isExpanded)
    }

    @Test
    fun `没有时间字段时折叠行不带前缀`() {
        val noTime = DiagnosticsLogEntry(
            rawBlock = "level=info\nmessage=裸消息",
            fields = linkedMapOf("level" to "info", "message" to "裸消息"),
            level = DiagnosticsLogLevel.INFO,
            isLevelInferred = false,
        )

        val view = buildDiagnosticsLogEntryView(noTime, expanded = false)

        assertNull(view.formattedTime)
        assertEquals("裸消息", view.collapsedText)
    }

    @Test
    fun `详情行剔掉公共字段并翻译键名与时间值`() {
        val rich = entry(
            timeMillis = 0L,
            level = DiagnosticsLogLevel.ERROR,
            message = "同步失败",
            category = "live_update",
            extra = linkedMapOf(
                "source" to "native",
                "throwable" to "java.lang.IllegalStateException",
                "untilMillis" to "0",
            ),
        )

        val view = buildDiagnosticsLogEntryView(rich, expanded = true)

        // Dart `detailEntries` 只剔 time/category/message/level/severity/source。
        assertEquals(
            listOf("throwable", "untilMillis"),
            view.detailRows.map { it.label },
        )
        // `_inlineValue`：能解析成毫秒时间戳的值渲染成时间，否则原样。
        assertEquals("1970-01-01 08:00:00", view.detailRows[1].value)
        assertEquals("java.lang.IllegalStateException", view.detailRows[0].value)
        assertEquals("超级岛", view.sourceLabel)
        assertEquals("错误", view.levelLabel)
        assertTrue(view.isExpanded)
    }

    @Test
    fun `设备信息行的键名按 ARB 翻译`() {
        val parsed = DiagnosticsLogSnapshot(
            title = "应用日志",
            rawHeader = "应用日志",
            fullText = "",
            headerEntries = linkedMapOf(
                "exportedAt" to "0",
                "app" to "com.mutx163.qingyu",
                "level" to "info",
            ),
            entries = listOf(entry(1_000, DiagnosticsLogLevel.INFO, "一")),
        )

        val state = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = parsed,
            viewport = DiagnosticsLogViewport(),
        )

        assertEquals(
            listOf("导出时间", "app", "等级"),
            state.headerRows.map { it.label },
        )
        assertEquals("1970-01-01 08:00:00", state.headerRows[0].value)
        assertEquals("com.mutx163.qingyu", state.headerRows[1].value)
    }

    @Test
    fun `推断等级与分类原样带出`() {
        val inferred = entry(
            timeMillis = 1_000,
            level = DiagnosticsLogLevel.DEBUG,
            message = "快照",
            category = "debug_snapshot",
            isLevelInferred = true,
        )

        val view = buildDiagnosticsLogEntryView(inferred, expanded = true)

        assertTrue(view.isLevelInferred)
        assertEquals("debug_snapshot", view.categoryLabel)
        assertEquals("调试", view.levelLabel)
    }

    // ==========================================
    // 5. 三态与按钮可用性
    // ==========================================

    @Test
    fun `首次加载中显示进度而不是空态`() {
        val state = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = DiagnosticsLogSnapshot.EMPTY,
            viewport = DiagnosticsLogViewport(),
            isInitializing = true,
            isParsing = true,
        )

        assertTrue(state.isLoading)
        assertFalse(state.isEmpty)
    }

    @Test
    fun `解析完成且没有条目时是空态`() {
        val state = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = DiagnosticsLogSnapshot.EMPTY,
            viewport = DiagnosticsLogViewport(),
        )

        assertTrue(state.isEmpty)
        assertFalse(state.showNoMatching)
        assertFalse(state.isLoading)
    }

    @Test
    fun `有条目但当前等级筛不出时是无匹配态`() {
        val state = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = snapshot(listOf(entry(1_000, DiagnosticsLogLevel.INFO, "正常"))),
            viewport = DiagnosticsLogViewport(),
            selectedLevel = DiagnosticsLogLevel.ERROR,
        )

        assertTrue(state.showNoMatching)
        assertFalse(state.isEmpty)
        // 无匹配不是空态：导出/复制仍按全量（Dart 复制按钮只看 `_parsed.entries.isEmpty`）。
        assertTrue(state.canCopy)
    }

    @Test
    fun `加载失败时不显示空态且保留错误文案`() {
        val state = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = DiagnosticsLogSnapshot.EMPTY,
            viewport = DiagnosticsLogViewport(),
            loadError = "PlatformException(读取失败)",
        )

        assertEquals("PlatformException(读取失败)", state.loadError)
        assertFalse(state.isEmpty)
        assertFalse(state.isLoading)
    }

    @Test
    fun `记录关闭时在有条目的前提下显示暂停提示`() {
        val parsed = snapshot(listOf(entry(1_000, DiagnosticsLogLevel.INFO, "一")))

        val paused = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = parsed,
            viewport = DiagnosticsLogViewport(),
            isRecordingEnabled = false,
        )
        val recording = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = parsed,
            viewport = DiagnosticsLogViewport(),
            isRecordingEnabled = true,
        )
        val unknown = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = parsed,
            viewport = DiagnosticsLogViewport(),
            isRecordingEnabled = null,
        )

        assertTrue(paused.showPausedHint)
        assertFalse(recording.showPausedHint)
        assertFalse(unknown.showPausedHint)
    }

    @Test
    fun `复制导出清空按钮的可用性跟随条目与回调`() {
        val empty = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = DiagnosticsLogSnapshot.EMPTY,
            viewport = DiagnosticsLogViewport(),
        )
        assertFalse(empty.canCopy)
        assertFalse(empty.canExport)
        assertTrue(empty.canClear) // 清空不要求已有条目，只看回调与是否正在清

        val noExportCallback = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = snapshot(listOf(entry(1_000, DiagnosticsLogLevel.INFO, "一"))),
            viewport = DiagnosticsLogViewport(),
            canExport = false,
        )
        assertTrue(noExportCallback.canCopy)
        assertFalse(noExportCallback.canExport)

        val noClearCallback = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = snapshot(listOf(entry(1_000, DiagnosticsLogLevel.INFO, "一"))),
            viewport = DiagnosticsLogViewport(),
            canClear = false,
        )
        assertFalse(noClearCallback.canClear)

        val busy = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = snapshot(listOf(entry(1_000, DiagnosticsLogLevel.INFO, "一"))),
            viewport = DiagnosticsLogViewport(),
            isExporting = true,
            isClearing = true,
        )
        assertFalse(busy.canExport)
        assertFalse(busy.canClear)
    }

    @Test
    fun `加载更早入口文案带未显示条数`() {
        val parsed = snapshot(
            (1..300).map { entry(it * 1_000L, DiagnosticsLogLevel.INFO, "第 $it 条") },
        )
        val latestViewport = DiagnosticsLogPaging.resolve(300, DiagnosticsLogViewport())

        val latest = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = parsed,
            viewport = latestViewport,
        )
        assertEquals("加载更早日志 剩余 100 条", latest.loadEarlierLabel)
        assertEquals(200, latest.entries.size)

        // 点一次「加载更早」后窗口覆盖全量，入口行消失（Dart `_hasEarlierEntries = start > 0`）。
        val allViewport = DiagnosticsLogPaging.loadEarlier(latestViewport)
            .let { DiagnosticsLogPaging.resolve(300, it) }
        val all = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = parsed,
            viewport = allViewport,
        )
        assertNull(all.loadEarlierLabel)
        assertEquals(300, all.entries.size)
    }

    // ==========================================
    // 6. 复制 / 导出用的是全量文本
    // ==========================================

    @Test
    fun `复制导出文本按当前等级拼全文而不是当前窗口`() {
        val errorEntry = entry(1_000, DiagnosticsLogLevel.ERROR, "炸了")
        val infoEntry = entry(2_000, DiagnosticsLogLevel.INFO, "正常")
        val parsed = DiagnosticsLogSnapshot(
            title = "应用日志",
            rawHeader = "应用日志\n  app=qingyu",
            fullText = "",
            headerEntries = linkedMapOf("app" to "qingyu"),
            entries = listOf(errorEntry, infoEntry),
        )

        val text = buildDiagnosticsFullLogText(parsed, DiagnosticsLogLevel.ERROR)

        // Dart `buildFilteredDiagnosticsRawText`：rawHeader + "\n----\n" + 命中块。
        assertEquals(
            "应用日志\n  app=qingyu\n----\n" + errorEntry.rawBlock.trim(),
            text,
        )
    }

    @Test
    fun `选择全部时全量文本包含所有块`() {
        val a = entry(1_000, DiagnosticsLogLevel.ERROR, "炸了")
        val b = entry(2_000, DiagnosticsLogLevel.INFO, "正常")
        val parsed = DiagnosticsLogSnapshot(
            title = "应用日志",
            rawHeader = "应用日志",
            fullText = "",
            headerEntries = emptyMap(),
            entries = listOf(a, b),
        )

        val text = buildDiagnosticsFullLogText(parsed, DiagnosticsLogLevel.ALL)

        assertEquals(
            "应用日志\n----\n" + a.rawBlock.trim() + "\n\n" + b.rawBlock.trim(),
            text,
        )
    }

    // ==========================================
    // 7. 窗口切片
    // ==========================================

    @Test
    fun `窗口切片取出时间正序的连续一段`() {
        val chronological = (1..500).toList()
        val latest = DiagnosticsLogPaging.resolve(500, DiagnosticsLogViewport())

        val slice = latest.slice(chronological)

        assertEquals(200, slice.size)
        assertEquals(301, slice.first())
        assertEquals(500, slice.last())
    }

    @Test
    fun `窗口越界时切片自动收窄而不抛异常`() {
        val chronological = (1..120).toList()
        val stale = DiagnosticsLogPaging.resolve(
            total = 120,
            state = DiagnosticsLogViewport(
                stickToLatest = false,
                pinnedStartIndex = 100,
                windowEndPin = 500,
            ),
        )

        val slice = stale.slice(chronological)

        assertEquals((101..120).toList(), slice)
    }

    @Test
    fun `查看模式与排序枚举默认值`() {
        val state = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = snapshot(listOf(entry(1_000, DiagnosticsLogLevel.INFO, "一"))),
            viewport = DiagnosticsLogViewport(),
        )

        assertEquals(DiagnosticsLogViewMode.STRUCTURED, state.viewMode)
        assertEquals(DiagnosticsLogTimeSort.ASCENDING, state.timeSort)
        assertEquals(DiagnosticsLogLevel.ALL, state.selectedLevel)
        assertFalse(state.isDeviceInfoExpanded)
    }
}
