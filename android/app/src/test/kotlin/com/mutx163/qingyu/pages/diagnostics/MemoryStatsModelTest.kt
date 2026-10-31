package com.mutx163.qingyu.pages.diagnostics

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalTime
import java.util.TimeZone

/**
 * 内存统计页模型层测试（源：`lib/screens/memory_stats_screen.dart` +
 * `lib/services/memory_stats_service.dart`）。
 *
 * 期望值从 Dart 源手推：
 * - 单位/百分比/时长格式：`MemoryStatsService.formatBytes/formatKb/formatDuration/formatPercent`
 *   （Dart `toStringAsFixed(1/2)`，`bytes < 1024` 走 B、`<1024 KB` 走 KB、`<1024 MB` 走 MB，否则 GB）；
 * - 概览 subtitle / 采样说明 / 各分组行：build 里 200-560 行；
 * - 每个弹层的键值行：`_showOverviewSheet` / `_showBackgroundSheet` / `_showKvSheet` 等；
 * - 可清性文案：`_BreakdownRow` 的 `cleanable == 'partial' ? '部分可清' : 'no' ? '基本不可清' : '难清'`；
 * - 采样历史行：`'${时间}  [$state]  PSS $pss  堆 $ratio  $live  压力 $level'`，
 *   `_formatEpochMillis` 口径 `MM-dd HH:mm:ss`，空值/≤0 一律 `—`。
 */
class MemoryStatsModelTest {

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

    // ==========================================
    // 1. 单位与百分比格式
    // ==========================================

    @Test
    fun `字节格式化按 B KB MB GB 四档且保留位数一致`() {
        assertEquals("—", MemoryStatsFormat.formatBytes(null))
        assertEquals("—", MemoryStatsFormat.formatBytes(-1L))
        assertEquals("0 B", MemoryStatsFormat.formatBytes(0L))
        assertEquals("1023 B", MemoryStatsFormat.formatBytes(1023L))
        // 1024 → kilobytes = 1.0 → 一位小数
        assertEquals("1.0 KB", MemoryStatsFormat.formatBytes(1024L))
        assertEquals("1.5 KB", MemoryStatsFormat.formatBytes(1536L))
        // 1234 / 1024 = 1.205078125 → 1.2
        assertEquals("1.2 KB", MemoryStatsFormat.formatBytes(1234L))
        assertEquals("1.00 MB", MemoryStatsFormat.formatBytes(1024L * 1024L))
        // 1234567 B → 1.1773746... MB → 1.18
        assertEquals("1.18 MB", MemoryStatsFormat.formatBytes(1234567L))
        assertEquals("1.50 GB", MemoryStatsFormat.formatBytes(1610612736L))
    }

    @Test
    fun `KB 先乘 1024 再走字节格式化`() {
        assertEquals("—", MemoryStatsFormat.formatKb(null))
        assertEquals("—", MemoryStatsFormat.formatKb(-5L))
        assertEquals("512.0 KB", MemoryStatsFormat.formatKb(512L))
        assertEquals("10.00 MB", MemoryStatsFormat.formatKb(10240L))
        assertEquals("1.00 GB", MemoryStatsFormat.formatKb(1048576L))
    }

    @Test
    fun `百分比保留一位小数且空值与 NaN 都是破折号`() {
        assertEquals("—", MemoryStatsFormat.formatPercent(null))
        assertEquals("—", MemoryStatsFormat.formatPercent(Double.NaN))
        assertEquals("0.0%", MemoryStatsFormat.formatPercent(0.0))
        assertEquals("25.0%", MemoryStatsFormat.formatPercent(0.25))
        assertEquals("12.5%", MemoryStatsFormat.formatPercent(0.125))
        assertEquals("100.0%", MemoryStatsFormat.formatPercent(1.0))
        // 1/3 → 33.333...% → 33.3%
        assertEquals("33.3%", MemoryStatsFormat.formatPercent(1.0 / 3.0))
    }

    @Test
    fun `时长按 时 分 秒 逐级省略高位`() {
        assertEquals("—", MemoryStatsFormat.formatDuration(null))
        assertEquals("—", MemoryStatsFormat.formatDuration(-1L))
        assertEquals("0s", MemoryStatsFormat.formatDuration(0L))
        assertEquals("59s", MemoryStatsFormat.formatDuration(59_000L))
        assertEquals("1m 1s", MemoryStatsFormat.formatDuration(61_000L))
        assertEquals("1h 0m 0s", MemoryStatsFormat.formatDuration(3_600_000L))
        assertEquals("1h 2m 5s", MemoryStatsFormat.formatDuration(3_725_000L))
    }

    @Test
    fun `时刻格式是两位补零的 时分秒`() {
        assertEquals("09:05:07", MemoryStatsFormat.formatClock(LocalTime.of(9, 5, 7)))
        assertEquals("00:00:00", MemoryStatsFormat.formatClock(LocalTime.of(0, 0, 0)))
        assertEquals("23:59:59", MemoryStatsFormat.formatClock(LocalTime.of(23, 59, 59)))
    }

    @Test
    fun `毫秒时间戳格式是 月日 时分秒 且非正数是破折号`() {
        assertEquals("—", MemoryStatsFormat.formatEpochMillis(null))
        assertEquals("—", MemoryStatsFormat.formatEpochMillis(0L))
        assertEquals("—", MemoryStatsFormat.formatEpochMillis(-1L))
        // 1_000_000_000_000ms = 2001-09-09T01:46:40Z，Asia/Shanghai = 09:46:40
        assertEquals("09-09 09:46:40", MemoryStatsFormat.formatEpochMillis(1_000_000_000_000L))
    }

    // ==========================================
    // 2. 压力等级与可清性标签
    // ==========================================

    @Test
    fun `压力标签优先取快照自带的文案`() {
        assertEquals("危急（接近 OOM / 系统低内存）", MemoryPressure.of("critical").label)
        assertEquals("偏高", MemoryPressure.of("high").label)
        assertEquals("升高", MemoryPressure.of("elevated").label)
        assertEquals("正常", MemoryPressure.of("normal").label)
        // 未知值不崩、按正常处理（快照里的 pressureLabel 仍会原样显示）
        assertEquals("正常", MemoryPressure.of("weird").label)
        assertEquals(MemoryPressure.NORMAL, MemoryPressure.of(null))
    }

    @Test
    fun `可清性三档文案`() {
        assertEquals("部分可清", MemoryCleanability.of("partial").label)
        assertEquals("基本不可清", MemoryCleanability.of("no").label)
        assertEquals("难清", MemoryCleanability.of("hard").label)
        // 未知值按难清（Dart `_ => '难清'`）
        assertEquals("难清", MemoryCleanability.of("whatever").label)
    }

    // ==========================================
    // 3. 整页视图状态
    // ==========================================

    private fun sampleSnapshot(): Map<String, Any?> = linkedMapOf(
        "uptimeMillis" to 3_725_000L,
        "packageName" to "com.mutx163.qingyu.debug",
        "diagnosticsPackage" to true,
        "pressureLevel" to "high",
        "pressureLabel" to "偏高",
        "appState" to "foreground",
        "appInForeground" to true,
        "app" to linkedMapOf(
            "totalPssKb" to 10240L,
            "selfPssKb" to 9000L,
            "processSumPssKb" to 10240L,
            "totalPrivateDirtyKb" to 4096L,
            "peakTotalPssKb" to 20480L,
            "peakJavaHeapAllocKb" to 8192L,
            "sampleCount" to 12L,
            "foregroundSampleCount" to 9L,
            "backgroundSampleCount" to 3L,
            "lowMemoryEventCount" to 1L,
            "processCount" to 2,
        ),
        "javaHeap" to linkedMapOf(
            "allocBytes" to 262144L,
            "maxBytes" to 1048576L,
            "usageRatio" to 0.25,
            "nearOom" to false,
        ),
        "debugMemoryInfo" to linkedMapOf(
            "totalPssKb" to 8192L,
            "dalvikPssKb" to 2048L,
            "nativePssKb" to 4096L,
            "graphicsPssKb" to 1024L,
            "codePssKb" to 512L,
            "stackPssKb" to 64L,
            "otherPssKb" to 256L,
            "systemPssKb" to 192L,
        ),
        "system" to linkedMapOf(
            "isLowMemory" to false,
            "availMemBytes" to 1073741824L,
            "totalMemBytes" to 8589934592L,
            "thresholdBytes" to 268435456L,
            "memoryClassMb" to 256,
            "largeMemoryClassMb" to 512,
        ),
        "liveIsland" to linkedMapOf(
            "serviceRunning" to true,
            "serviceClass" to "com.mutx163.qingyu.LiveUpdateService",
            "note" to "超级岛前台服务与主进程同 UID；进程行中可能单独列出",
        ),
        "fairMemory" to linkedMapOf(
            "lastKillAtMillis" to 1_000_000_000_000L,
            "lastKillNotifyType" to 7,
            "lastKillNotifyId" to 42,
            "lastKillReason" to "FGS",
        ),
        "backgroundStats" to linkedMapOf(
            "currentlyBackground" to false,
            "foregroundSampleIntervalSec" to 15L,
            "backgroundSampleIntervalSec" to 30L,
            "hasBackgroundSamples" to true,
            "backgroundPointCount" to 3,
            "lastForegroundPssKb" to 10240L,
            "lastBackgroundPssKb" to 12288L,
            "backgroundMinusLastForegroundKb" to 2048L,
            "peakForegroundPssKb" to 16384L,
            "avgForegroundPssKb" to 12000L,
            "peakBackgroundPssKb" to 14336L,
            "avgBackgroundPssKb" to 13000L,
            "lastForegroundAtMillis" to 1_000_000_000_000L,
            "lastBackgroundAtMillis" to 1_000_000_060_000L,
            "note" to "后台采样仅在进程仍存活时有效",
        ),
        "pssBreakdown" to linkedMapOf(
            "totalPssKb" to 10240L,
            "javaHeap" to linkedMapOf(
                "key" to "javaHeap",
                "label" to "Java 堆",
                "pssKb" to 2048L,
                "ratio" to 0.2,
                "cleanable" to "partial",
                "meaning" to "Android/Java 对象",
            ),
            "system" to linkedMapOf(
                "key" to "system",
                "label" to "System 系统分摊",
                "pssKb" to 192L,
                "ratio" to 0.01875,
                "cleanable" to "no",
                "meaning" to "系统库分摊",
            ),
            "ordered" to listOf("javaHeap", "system"),
        ),
        "analysis" to linkedMapOf(
            "headline" to "约 10 MB · 偏高",
            "severityLabel" to "偏高",
            "severity" to "high",
            "bullets" to listOf("整应用约 10 MB PSS。", "Java 堆使用率仅 25.0%，不是 Java OOM。"),
            "cleanableEstimate" to linkedMapOf(
                "easyMb" to 1,
                "mediumMb" to 2,
                "hardMb" to 3,
                "note" to "easy≈图片缓存等",
            ),
        ),
        "processes" to listOf(
            linkedMapOf(
                "pid" to 1234,
                "processName" to "com.mutx163.qingyu.debug",
                "pssKb" to 10240L,
                "privateDirtyKb" to 4096L,
                "isMainProcess" to true,
                "likelyLiveIsland" to false,
            ),
        ),
        "history" to listOf(
            linkedMapOf(
                "atMillis" to 1_000_000_000_000L,
                "totalPssKb" to 10240L,
                "javaHeapUsageRatio" to 0.25,
                "liveServiceRunning" to true,
                "appInForeground" to false,
                "pressureLevel" to "high",
            ),
        ),
        "memoryStats" to linkedMapOf("summary.total-pss" to "10240"),
        // 图片缓存：Compose 壳读采集器的 imageCache 块（真实 LruCache），
        // 不再是 Dart 时代的 dartVm / flutterImageCache（Flutter 运行时专属，Compose 里恒为 —）。
        "imageCache" to linkedMapOf(
            "currentSizeBytes" to 262144L,
            "maxSizeBytes" to 16777216L,
            "entryCount" to 3L,
            "source" to "AndroidImageLoader",
        ),
    )

    private fun buildState(
        snapshot: Map<String, Any?>? = sampleSnapshot(),
        autoRefreshEnabled: Boolean = true,
        lastRefreshedAt: LocalTime? = LocalTime.of(12, 34, 56),
    ): MemoryStatsViewState = buildMemoryStatsViewState(
        snapshot = snapshot,
        autoRefreshEnabled = autoRefreshEnabled,
        refreshIntervalSeconds = 3,
        lastRefreshedAt = lastRefreshedAt,
    )

    @Test
    fun `概览卡是总 PSS 加压力 前后台 峰值三段`() {
        val state = buildState()

        assertEquals("10.00 MB", state.summaryText)
        assertEquals("压力 偏高 · 前台 · 峰值 20.00 MB", state.summarySubtitle)
    }

    @Test
    fun `采样说明带刷新间隔与最近刷新时刻`() {
        val withTime = buildState()
        assertEquals(
            "统计主进程与同 UID 的其它进程（含超级岛服务）。数据每 3 秒更新一次，可在下方关闭自动采样。最近刷新：12:34:56",
            withTime.refreshDescription,
        )

        val never = buildState(lastRefreshedAt = null)
        assertTrue(never.refreshDescription.endsWith("最近刷新：尚未刷新"))
    }

    @Test
    fun `自动刷新开关的副标题随开关变化`() {
        val on = buildState(autoRefreshEnabled = true)
        val off = buildState(autoRefreshEnabled = false)

        assertEquals("每 3 秒采样一次", on.samplingRows.first { it.row == MemoryStatsRow.AUTO_REFRESH }.subtitle)
        assertEquals(
            "已关闭自动刷新，使用右上角按钮手动更新",
            off.samplingRows.first { it.row == MemoryStatsRow.AUTO_REFRESH }.subtitle,
        )
    }

    @Test
    fun `内存构成行的取值跟随快照`() {
        val state = buildState()

        val byRow = state.compositionRows.associateBy { it.row }
        assertEquals("25.0%", byRow.getValue(MemoryStatsRow.JAVA_HEAP).details)
        assertEquals("10.00 MB", byRow.getValue(MemoryStatsRow.PSS_BREAKDOWN).details)
        assertEquals("8.00 MB", byRow.getValue(MemoryStatsRow.DEBUG_MEMORY).details)
        assertEquals("256.0 KB", byRow.getValue(MemoryStatsRow.IMAGE_CACHE).details)
        assertEquals("正常", byRow.getValue(MemoryStatsRow.SYSTEM_MEMORY).details)
    }

    @Test
    fun `图片缓存弹层读采集器的 imageCache 块而不是 Flutter 运行时`() {
        val sheet = buildState().sheets.getValue(MemorySheet.IMAGE_CACHE)
        val byLabel = sheet.rows.associate { it.label to it.value }

        assertEquals("图片缓存", sheet.title)
        assertEquals("AndroidImageLoader", byLabel.getValue("来源"))
        assertEquals("256.0 KB / 16.00 MB", byLabel.getValue("占用 / 上限"))
        assertEquals("3 条", byLabel.getValue("缓存条目数"))
        // 旧版这里放着 Dart RSS / Dart max RSS 两行（读 dartVm，Compose 里恒为 —）。
        assertTrue(byLabel.keys.none { it.contains("Dart") || it.contains("Flutter") })
    }

    @Test
    fun `页面可见文案里不再出现 Flutter 运行时指标`() {
        // 这一页在 Compose 壳里运行，没有任何 Flutter 运行时；再出现「Dart / Flutter 图片缓存」
        // 这类字眼就是把一个已经不存在的对象挂给用户看（2026-10-31 用户实测反馈）。
        val visible = listOf(
            MemoryStatsStrings.imageCacheTitle,
            MemoryStatsStrings.imageCacheDescription,
            MemoryStatsStrings.imageCacheSourceLabel,
            MemoryStatsStrings.imageCacheUsageLabel,
            MemoryStatsStrings.imageCacheEntryLabel,
        )
        for (text in visible) {
            assertFalse("可见文案不应含 Flutter 运行时字眼：$text", text.contains("Flutter"))
            assertFalse("可见文案不应含 Flutter 运行时字眼：$text", text.contains("Dart"))
        }
    }

    @Test
    fun `运行环境行把进程数与前后台说清`() {
        val state = buildState()
        val byRow = state.environmentRows.associateBy { it.row }

        assertEquals("2 个进程", byRow.getValue(MemoryStatsRow.APP_OVERVIEW).details)
        assertEquals("前台", byRow.getValue(MemoryStatsRow.BACKGROUND_SAMPLING).details)
        assertEquals("运行中", byRow.getValue(MemoryStatsRow.LIVE_ISLAND).details)
        assertEquals("1 个", byRow.getValue(MemoryStatsRow.PROCESS_LIST).details)
    }

    @Test
    fun `诊断工具行用快照里的结论与时间`() {
        val state = buildState()
        val byRow = state.toolRows.associateBy { it.row }

        assertEquals("约 10 MB · 偏高", byRow.getValue(MemoryStatsRow.ANALYSIS).title)
        assertEquals("偏高", byRow.getValue(MemoryStatsRow.ANALYSIS).details)
        assertEquals("1 条", byRow.getValue(MemoryStatsRow.HISTORY).details)
        assertEquals("1 项", byRow.getValue(MemoryStatsRow.MEMORY_STATS).details)
        assertEquals("完整快照", byRow.getValue(MemoryStatsRow.RAW_JSON).details)
        assertEquals("09-09 09:46:40", byRow.getValue(MemoryStatsRow.FAIR_MEMORY).details)
    }

    @Test
    fun `没有快照时是空态且原始 JSON 行说暂无快照`() {
        val state = buildState(snapshot = null)

        assertFalse(state.hasSnapshot)
        assertTrue(state.isEmptyState)
        assertEquals("—", state.summaryText)
        // Dart `:202` 的副标题是无条件拼的：没有快照时照样是「压力 — · 后台 · 峰值 —」。
        // 旧实现这里返回整行破折号，与 Dart 不一致（空态下少了两段信息槽位）。
        assertEquals("压力 — · 后台 · 峰值 —", state.summarySubtitle)
        assertEquals("暂无快照", state.toolRows.first { it.row == MemoryStatsRow.RAW_JSON }.details)
        assertEquals("暂无进程数据", state.sheets[MemorySheet.PROCESS_LIST]?.emptyText)
    }

    @Test
    fun `压力标签缺失时用破折号而不是回算成正常`() {
        val noLabel = LinkedHashMap(sampleSnapshot()).also { it.remove("pressureLabel") }
        val state = buildState(snapshot = noLabel)

        // Dart `snapshot?['pressureLabel'] ?? '—'`：缺键就是破折号，
        // 不能拿 pressureLevel 回算一个「正常」出来（那样空态会凭空生出结论）。
        assertEquals("压力 — · 前台 · 峰值 20.00 MB", state.summarySubtitle)
        // 压力等级本身仍用于图标配色，这条不受影响。
        assertEquals(MemoryPressure.HIGH, state.pressure)
    }

    @Test
    fun `自动刷新档位就是 Dart 的 3 秒`() {
        // 出处 `lib/screens/memory_stats_screen.dart:24`
        // `static const Duration _autoRefreshInterval = Duration(seconds: 3);`
        assertEquals(3, DEFAULT_REFRESH_INTERVAL_SECONDS)
        val state = buildState()
        assertEquals("每 3 秒采样一次", state.samplingRows[0].subtitle)
    }

    @Test
    fun `行首语义色逐行对齐 Dart 的 iconAccent`() {
        val state = buildState()
        val accents = (
            state.samplingRows + state.compositionRows +
                state.environmentRows + state.toolRows
            ).associate { it.row to it.accent }

        assertEquals(MemoryRowAccent.BLUE, accents[MemoryStatsRow.AUTO_REFRESH])
        assertEquals(MemoryRowAccent.TEAL, accents[MemoryStatsRow.PERF_REPORT])
        assertEquals(MemoryRowAccent.BLUE, accents[MemoryStatsRow.JAVA_HEAP])
        assertEquals(MemoryRowAccent.INDIGO, accents[MemoryStatsRow.PSS_BREAKDOWN])
        assertEquals(MemoryRowAccent.CYAN, accents[MemoryStatsRow.DEBUG_MEMORY])
        assertEquals(MemoryRowAccent.PURPLE, accents[MemoryStatsRow.IMAGE_CACHE])
        assertEquals(MemoryRowAccent.TEAL, accents[MemoryStatsRow.SYSTEM_MEMORY])
        assertEquals(MemoryRowAccent.BLUE, accents[MemoryStatsRow.APP_OVERVIEW])
        assertEquals(MemoryRowAccent.ORANGE, accents[MemoryStatsRow.BACKGROUND_SAMPLING])
        assertEquals(MemoryRowAccent.GREEN, accents[MemoryStatsRow.LIVE_ISLAND])
        assertEquals(MemoryRowAccent.CYAN, accents[MemoryStatsRow.PROCESS_LIST])
        assertEquals(MemoryRowAccent.PRESSURE, accents[MemoryStatsRow.ANALYSIS])
        assertEquals(MemoryRowAccent.PURPLE, accents[MemoryStatsRow.HISTORY])
        assertEquals(MemoryRowAccent.TEAL, accents[MemoryStatsRow.MEMORY_STATS])
        assertEquals(MemoryRowAccent.ORANGE, accents[MemoryStatsRow.RAW_JSON])
        assertEquals(MemoryRowAccent.RED, accents[MemoryStatsRow.FAIR_MEMORY])
    }

    @Test
    fun `Java 堆行在接近 OOM 时转红`() {
        // Dart `:263-265`：`heapUsage >= 0.85 ? red : blue`。
        val nearOom = sampleSnapshot().also {
            @Suppress("UNCHECKED_CAST")
            val heap = it["javaHeap"] as MutableMap<String, Any?>
            heap["usageRatio"] = 0.86
            heap["nearOom"] = true
        }
        val state = buildState(snapshot = nearOom)
        val javaHeap = state.compositionRows.first { it.row == MemoryStatsRow.JAVA_HEAP }

        assertEquals(MemoryRowAccent.RED, javaHeap.accent)
        assertEquals("86.0%", javaHeap.details)
    }

    @Test
    fun `超级岛未运行时图标取靛蓝`() {
        val stopped = sampleSnapshot().also {
            @Suppress("UNCHECKED_CAST")
            val island = it["liveIsland"] as MutableMap<String, Any?>
            island["serviceRunning"] = false
        }
        val state = buildState(snapshot = stopped)
        val row = state.environmentRows.first { it.row == MemoryStatsRow.LIVE_ISLAND }

        assertEquals(MemoryRowAccent.INDIGO, row.accent)
        assertEquals("未运行", row.details)
    }

    @Test
    fun `分析弹层把可清性口径说明也带出来`() {
        val sheet = buildState().sheets.getValue(MemorySheet.ANALYSIS)

        // Dart `_showAnalysisSheet:715-721`：粗估下面还有一行 `cleanable['note']`。
        assertEquals("easy≈图片缓存等", sheet.cleanableNote)
    }

    @Test
    fun `分析弹层没有口径说明时不硬造一行`() {
        val noNote = sampleSnapshot().also {
            @Suppress("UNCHECKED_CAST")
            val analysis = it["analysis"] as MutableMap<String, Any?>
            @Suppress("UNCHECKED_CAST")
            val cleanable = analysis["cleanableEstimate"] as MutableMap<String, Any?>
            cleanable.remove("note")
        }
        val sheet = buildState(snapshot = noNote).sheets.getValue(MemorySheet.ANALYSIS)

        assertNull(sheet.cleanableNote)
        assertEquals("可节约粗估：易清 1 MB · 中等 2 MB · 难清 3 MB", sheet.cleanableSummary)
    }

    @Test
    fun `采样历史没有点时只留那句提示`() {
        val noHistory = LinkedHashMap(sampleSnapshot()).also { it["history"] = emptyList<Any?>() }
        val sheet = buildState(snapshot = noHistory).sheets.getValue(MemorySheet.HISTORY)

        // Dart `:878-889`：空态只显示提示句，不再多一行「共 0 点 · 最早→最晚」。
        assertNull(sheet.historySummary)
        assertEquals("采样尚未积累。可先回桌面 1～2 分钟再回来，查看后台 PSS。", sheet.emptyText)
    }

    @Test
    fun `应用总览弹层给出九行运行数据`() {
        val sheet = buildState().sheets.getValue(MemorySheet.OVERVIEW)

        assertEquals("应用总览", sheet.title)
        assertEquals("公平运行内存页统计的是同 UID 进程总量。", sheet.description)
        assertEquals(
            listOf(
                "运行时长",
                "包名",
                "进程数",
                "会话采样次数",
                "前台 / 后台采样次数",
                "系统 onLowMemory 次数",
                "当前进程 PSS",
                "进程接口合计 PSS",
                "Private Dirty 合计",
            ),
            sheet.rows.map { it.label },
        )
        assertEquals("1h 2m 5s", sheet.rows[0].value)
        assertEquals("com.mutx163.qingyu.debug", sheet.rows[1].value)
        assertEquals("2", sheet.rows[2].value)
        assertEquals("12", sheet.rows[3].value)
        assertEquals("9 / 3", sheet.rows[4].value)
        assertEquals("8.79 MB", sheet.rows[6].value)
    }

    @Test
    fun `前后台采样弹层给出间隔与最近 PSS`() {
        val sheet = buildState().sheets.getValue(MemorySheet.BACKGROUND)

        assertEquals("前台 / 后台采样", sheet.title)
        assertEquals("前台约 15 秒、后台约 30 秒采样；进出前后台会立即补采。", sheet.description)
        val byLabel = sheet.rows.associate { it.label to it.value }
        assertEquals("否", byLabel.getValue("当前是否后台"))
        assertEquals("15s / 30s", byLabel.getValue("采样间隔 前台 / 后台"))
        assertEquals("是（3 点）", byLabel.getValue("是否已有后台采样"))
        assertEquals("10.00 MB", byLabel.getValue("最近前台 PSS"))
        assertEquals("12.00 MB", byLabel.getValue("最近后台 PSS"))
        assertEquals("2.00 MB", byLabel.getValue("后台 − 前台（最近）"))
        assertEquals("16.00 MB / 11.72 MB", byLabel.getValue("前台峰值 / 均值"))
        assertEquals("09-09 09:46:40", byLabel.getValue("上次进前台"))
    }

    @Test
    fun `Java 堆弹层带已用上限与接近 OOM 判断`() {
        val sheet = buildState().sheets.getValue(MemorySheet.JAVA_HEAP)

        val byLabel = sheet.rows.associate { it.label to it.value }
        assertEquals("256.0 KB / 1.00 MB", byLabel.getValue("已用 / 上限"))
        assertEquals("25.0%", byLabel.getValue("使用率"))
        assertEquals("否", byLabel.getValue("接近 OOM（≥85%）"))
        assertEquals("8.00 MB", byLabel.getValue("会话峰值堆占用"))
    }

    @Test
    fun `PSS 分类弹层按 ordered 顺序并带可清性`() {
        val sheet = buildState().sheets.getValue(MemorySheet.PSS_BREAKDOWN)

        assertEquals(listOf("Java 堆", "System 系统分摊"), sheet.breakdown.map { it.label })
        assertEquals("2.00 MB", sheet.breakdown[0].pssText)
        assertEquals("20.0%", sheet.breakdown[0].ratioText)
        assertEquals("部分可清", sheet.breakdown[0].cleanableLabel)
        assertEquals("基本不可清", sheet.breakdown[1].cleanableLabel)
    }

    @Test
    fun `进程列表与采样历史按 Dart 字段渲染`() {
        val state = buildState()
        val process = state.sheets.getValue(MemorySheet.PROCESS_LIST).processes.single()
        assertEquals("com.mutx163.qingyu.debug", process.name)
        assertEquals("1234", process.pidText)
        assertEquals("10.00 MB", process.pssText)
        assertTrue(process.isMainProcess)
        // 渲染层只画 detailLine（文案组装在模型层，页面不含中文字面量）。
        assertEquals("pid=1234  PSS=10.00 MB  privateDirty=4.00 MB  ·主进程", process.detailLine)

        val historySheet = state.sheets.getValue(MemorySheet.HISTORY)
        assertEquals("共 1 点 · 最早→最晚", historySheet.historySummary)
        val row = historySheet.history.single()
        // Dart `'${_formatEpochMillis(at)}  [$state]  PSS $pss  堆 $ratio  $live  压力 $level'`
        assertEquals("09-09 09:46:40", row.timeText)
        assertEquals("后台", row.stateLabel)
        assertEquals("10.00 MB", row.pssText)
        assertEquals("25.0%", row.heapRatioText)
        assertEquals("岛开", row.liveLabel)
        assertEquals("high", row.pressureLevel)
        // 渲染层只画 lineText（文案组装在模型层，页面不含中文字面量）。
        assertEquals(
            "09-09 09:46:40  [后台]  PSS 10.00 MB  堆 25.0%  岛开  压力 high",
            row.lineText,
        )
    }

    @Test
    fun `自动分析弹层带可节约粗估与要点`() {
        val sheet = buildState().sheets.getValue(MemorySheet.ANALYSIS)

        assertEquals("约 10 MB · 偏高", sheet.title)
        assertEquals("严重度：偏高 · 基于当前 PSS 拆解与包类型", sheet.description)
        assertEquals(
            "可节约粗估：易清 1 MB · 中等 2 MB · 难清 3 MB",
            sheet.cleanableSummary,
        )
        assertEquals(2, sheet.bullets.size)
    }

    @Test
    fun `公平内存弹层把空 reason 显示成破折号`() {
        val sheet = buildState().sheets.getValue(MemorySheet.FAIR_MEMORY)
        val byLabel = sheet.rows.associate { it.label to it.value }

        assertEquals("09-09 09:46:40", byLabel.getValue("最近 KILL 时间"))
        assertEquals("7 / 42", byLabel.getValue("notifyType / notifyId"))
        assertEquals("FGS", byLabel.getValue("reason"))
    }

    @Test
    fun `原始 JSON 与 memoryStats 弹层是等宽原文`() {
        val state = buildState()

        val memoryStats = state.sheets.getValue(MemorySheet.MEMORY_STATS)
        assertEquals("summary.total-pss = 10240", memoryStats.bodyText)

        val json = state.sheets.getValue(MemorySheet.RAW_JSON)
        assertTrue(json.bodyText!!.contains("\"packageName\""))
    }

    @Test
    fun `错误文案原样带出且不是空态`() {
        val state = buildMemoryStatsViewState(
            snapshot = null,
            autoRefreshEnabled = true,
            refreshIntervalSeconds = 3,
            lastRefreshedAt = null,
            errorText = "PlatformException(读取失败)",
        )

        assertEquals("PlatformException(读取失败)", state.errorText)
        assertFalse(state.isEmptyState)
    }

    @Test
    fun `加载中且没有快照时显示读取提示`() {
        val state = buildMemoryStatsViewState(
            snapshot = null,
            autoRefreshEnabled = true,
            refreshIntervalSeconds = 3,
            lastRefreshedAt = null,
            isLoading = true,
        )

        assertTrue(state.isLoading)
        assertNull(state.errorText)
        assertEquals("正在读取当前内存快照…", state.loadingHint)
    }

    @Test
    fun `快照里带 error 时提取成错误文案`() {
        // Dart `:80`：`_errorText = snapshot['error']?.toString()`。
        assertEquals(
            "PlatformException(读取失败)",
            memorySnapshotError(linkedMapOf<String, Any?>("error" to "PlatformException(读取失败)")),
        )
        // 没有 error 键 / 空串 / 快照本身为 null 都是「没错误」。
        assertNull(memorySnapshotError(linkedMapOf<String, Any?>("supported" to true)))
        assertNull(memorySnapshotError(linkedMapOf<String, Any?>("error" to "")))
        assertNull(memorySnapshotError(null))
    }

    @Test
    fun `历史行的前后台判定按 Dart 的等假口径`() {
        // Dart `:904-906` 写的是 `sample['appInForeground'] == false ? '后台' : '前台'`，
        // 键缺失时会落到「前台」——与 `!= true` 的直觉写法不同，这里钉住它。
        val missingFlag = sampleSnapshot().also {
            @Suppress("UNCHECKED_CAST")
            val sample = (it["history"] as List<MutableMap<String, Any?>>).single()
            sample.remove("appInForeground")
        }
        val row = buildState(snapshot = missingFlag)
            .sheets.getValue(MemorySheet.HISTORY)
            .history.single()

        assertEquals("前台", row.stateLabel)
    }
}
