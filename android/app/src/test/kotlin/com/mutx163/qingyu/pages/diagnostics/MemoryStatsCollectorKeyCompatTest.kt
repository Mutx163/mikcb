package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.util.TimeZone

/**
 * **真数据口径对照**：原生 `MemoryStatsCollector.buildSnapshot()` 的 key 表 ↔
 * 模型层 `buildMemoryStatsViewState(...)` 的读取 key。
 *
 * ## 为什么要有这个文件
 *
 * 内存统计页的数据只有一条真来源：`android/app/src/main/kotlin/com/mutx163/qingyu/MemoryStatsCollector.kt`
 * 的 `buildSnapshot(context): Map<String, Any?>`（`:145`）。Dart 版也是同一份数据
 * （`MainActivity.kt:477-491` 的 `getMemorySnapshot` 通道直接 `result.success(buildSnapshot(...))`）。
 *
 * 这条链上**最容易悄悄坏掉的一环是 key 名**：模型层用的是 Map 取值，
 * 写成 `debugMemory` 而不是 `debugMemoryInfo`、`peakJavaHeapAllocKb` 少个字母，
 * 编译照样过、测试照样绿（只是取值变 `—`），真机上才看得出来「这行怎么是破折号」。
 * 所以这里钉两件事：
 *
 * 1. [collectorSnapshotFixture] 的 key/类型**逐字照抄采集器 `:243-306`** 的
 *    `linkedMapOf(...)`，断言每个字段都真的渲染出值（不是 `—`）；
 * 2. [collectorKeyTableMatchesModelReads] 直接扫采集器源码，确认模型读的每个 key
 *    在采集器里确实存在（有人在那边改名 → 这里红）。
 *
 * ## 明确不覆盖的部分
 *
 * `dartVm` / `flutterImageCache` 是 Dart `MemoryStatsService.fetchSnapshot:82-94` 从 Flutter
 * 运行时补进来的，采集器**不产出**这两个键；2026-10-31 起页面也不再读它们，改读采集器的
 * `imageCache` 块（`AndroidImageLoader` 的真实 LruCache），见 [imageCacheRowUsesComposeLoaderBlock]。
 *
 * ## 读法：剥注释、**保留字符串**（默认档，2026-11-12 B4 批）
 *
 * 三处读采集器源码的判据（[collectorHasNoFlutterRuntimeKeys] / [collectorKeyTableMatchesModelReads] /
 * [keyTableScanDetectsUnknownKey]）判的都是**字符串字面量**：`text.contains("\"$key\"")`、
 * 不许出现 `"dartVm"`、以及「字符串里不许出现 Flutter」。
 *
 * - **不许**换成中性化档（`readKotlinSourceNoStrings`）：它把字符串内容抹成空格，
 *   `"$key"` 全部消失 ⇒ key 表判据恒红，而 `assertFalse(contains("\"dartVm\""))` 变成**恒真**
 *   （洗白：加回 `"dartVm"` 也抓不到）。这是本文件唯一不能踩的档位坑。
 * - **必须剥注释**：不剥时把采集器里某个 key 行注释掉，注释掉的 `"key"` 原文还在文本里 ⇒
 *   模型层读它仍判「采集器有这个键」（B4 批 before/after 探针实测：迁移前绿、迁移后红）。
 *
 * 否定式断言前另有「正向锚存在」的断言（见各 test 内注释）：源码读成空窜时否定式恒真，
 * 本批按 AGENTS.md「源码守卫」纪律补上。
 */
class MemoryStatsCollectorKeyCompatTest {

    private lateinit var originalTimeZone: TimeZone

    @Before
    fun fixTimeZone() {
        originalTimeZone = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"))
    }

    @org.junit.After
    fun restoreTimeZone() {
        TimeZone.setDefault(originalTimeZone)
    }

    /**
     * 采集器 `:243-306` 返回的 Map，逐字照抄（类型也照抄：`Long` / `Int` / `Double` / `Boolean` / `String`）。
     *
     * 注意 `memoryStats` 的值在采集器里是 `Map<String, String>`（`readAllMemoryStats` 的
     * `toSortedMap()`），`ordered` 是 `List<String>`（`:555-557`）。
     */
    private fun collectorSnapshotFixture(): Map<String, Any?> = linkedMapOf(
        "generatedAtMillis" to 1_700_000_000_000L,
        "uptimeMillis" to 3_725_000L,
        "packageName" to "com.mutx163.qingyu.debug",
        "diagnosticsPackage" to true,
        "pressureLevel" to "high",
        "pressureLabel" to "偏高",
        "appState" to "foreground",
        "appInForeground" to true,
        "app" to linkedMapOf(
            "totalPssKb" to 512_000L,
            "selfPssKb" to 480_000L,
            "processSumPssKb" to 530_000L,
            "totalPrivateDirtyKb" to 204_800L,
            "peakTotalPssKb" to 614_400L,
            "peakJavaHeapAllocKb" to 276_480L,
            "sampleCount" to 24L,
            "foregroundSampleCount" to 18L,
            "backgroundSampleCount" to 6L,
            "lowMemoryEventCount" to 2L,
            "processCount" to 2,
        ),
        "backgroundStats" to linkedMapOf(
            "currentlyBackground" to false,
            "foregroundSampleIntervalSec" to 15L,
            "backgroundSampleIntervalSec" to 30L,
            "foregroundSampleCount" to 18L,
            "backgroundSampleCount" to 6L,
            "peakForegroundPssKb" to 614_400L,
            "peakBackgroundPssKb" to 563_200L,
            "avgForegroundPssKb" to 500_000L,
            "avgBackgroundPssKb" to 540_000L,
            "lastForegroundPssKb" to 512_000L,
            "lastBackgroundPssKb" to 550_000L,
            "lastForegroundAtMillis" to 1_700_000_000_000L,
            "lastBackgroundAtMillis" to 1_700_000_060_000L,
            "backgroundMinusLastForegroundKb" to 38_000L,
            "hasBackgroundSamples" to true,
            "backgroundPointCount" to 6,
            "note" to "后台采样仅在进程仍存活时有效；若进程被杀，历史中不会再增加后台点。",
        ),
        "javaHeap" to linkedMapOf(
            "allocBytes" to 268_435_456L,
            "totalBytes" to 301_989_888L,
            "freeBytes" to 33_554_432L,
            "maxBytes" to 536_870_912L,
            "usageRatio" to 0.5,
            "nearOom" to false,
        ),
        "debugMemoryInfo" to linkedMapOf(
            "totalPssKb" to 409_600L,
            "totalPrivateDirtyKb" to 204_800L,
            "totalSharedDirtyKb" to 12_288L,
            "dalvikPssKb" to 61_440L,
            "nativePssKb" to 153_600L,
            "graphicsPssKb" to 81_920L,
            "codePssKb" to 40_960L,
            "stackPssKb" to 1_024L,
            "otherPssKb" to 51_200L,
            "systemPssKb" to 19_456L,
        ),
        "memoryStats" to linkedMapOf(
            "summary.total-pss" to "520192",
            "summary.java-heap" to "61440",
            "summary.native-heap" to "153600",
        ),
        "pssBreakdown" to linkedMapOf(
            "totalPssKb" to 512_000L,
            "debugTotalPssKb" to 520_192L,
            "javaHeap" to breakdownRow("javaHeap", "Java 堆", 61_440L, 0.12, "partial", "Android/Java 对象"),
            "nativeHeap" to breakdownRow("nativeHeap", "Native 堆", 153_600L, 0.3, "hard", "C/C++ 堆"),
            "graphics" to breakdownRow("graphics", "Graphics 图形", 81_920L, 0.16, "partial", "GPU/纹理"),
            "code" to breakdownRow("code", "Code 代码映射", 40_960L, 0.08, "no", "so/dex/oat 映射"),
            "stack" to breakdownRow("stack", "Stack 栈", 1_024L, 0.002, "no", "线程栈"),
            "privateOther" to breakdownRow("privateOther", "Private Other 其它私有", 51_200L, 0.1, "hard", "匿名映射"),
            "system" to breakdownRow("system", "System 系统分摊", 19_456L, 0.038, "no", "共享库分摊"),
            "ordered" to listOf(
                "privateOther", "system", "graphics", "nativeHeap", "javaHeap", "code", "stack",
            ),
        ),
        "analysis" to linkedMapOf(
            "severity" to "high",
            "severityLabel" to "偏高",
            "headline" to "约 500 MB · 偏高",
            "bullets" to listOf("整应用约 500 MB PSS。", "Java 堆使用率仅 50.0%，不是 Java OOM。"),
            "cleanableEstimate" to linkedMapOf(
                "easyMb" to 0,
                "mediumMb" to 20,
                "hardMb" to 219,
                "note" to "easy≈图片缓存等；medium≈图形/壁纸/模糊；hard≈原生运行时与系统分摊（难清）。估算仅供参考。",
            ),
        ),
        "system" to linkedMapOf(
            "memoryClassMb" to 256,
            "largeMemoryClassMb" to 512,
            "isLowMemory" to false,
            "availMemBytes" to 1_073_741_824L,
            "totalMemBytes" to 8_589_934_592L,
            "thresholdBytes" to 268_435_456L,
            "sdkInt" to 34,
        ),
        // 采集器新增块：Compose 图片加载器的真实 LruCache（取代 Flutter 运行时的图片缓存）。
        "imageCache" to linkedMapOf(
            "currentSizeBytes" to 1_048_576L,
            "maxSizeBytes" to 16_777_216L,
            "entryCount" to 2,
            "source" to "AndroidImageLoader",
        ),
        "liveIsland" to linkedMapOf(
            "serviceRunning" to true,
            "serviceClass" to "com.mutx163.qingyu.LiveUpdateService",
            "note" to "超级岛前台服务与主进程同 UID；进程行中可能单独列出",
        ),
        "fairMemory" to linkedMapOf(
            "lastKillAtMillis" to 1_700_000_000_000L,
            "lastKillNotifyType" to 3,
            "lastKillNotifyId" to 12,
            "lastKillReason" to "FGS",
        ),
        "processes" to listOf(
            linkedMapOf(
                "pid" to 4242,
                "processName" to "com.mutx163.qingyu.debug",
                "importance" to 100,
                "pssKb" to 409_600L,
                "privateDirtyKb" to 204_800L,
                "sharedDirtyKb" to 12_288L,
                "isMainProcess" to true,
                "likelyLiveIsland" to false,
            ),
            linkedMapOf(
                "pid" to 4243,
                "processName" to "com.mutx163.qingyu.debug:live",
                "importance" to 125,
                "pssKb" to 102_400L,
                "privateDirtyKb" to 51_200L,
                "sharedDirtyKb" to 4_096L,
                "isMainProcess" to false,
                "likelyLiveIsland" to true,
            ),
        ),
        "history" to listOf(
            linkedMapOf(
                "atMillis" to 1_700_000_000_000L,
                "totalPssKb" to 512_000L,
                "selfPssKb" to 480_000L,
                "processSumPssKb" to 530_000L,
                "javaHeapAllocBytes" to 268_435_456L,
                "javaHeapUsageRatio" to 0.5,
                "pressureLevel" to "high",
                "liveServiceRunning" to true,
                "processCount" to 2,
                "appState" to "background",
                "appInForeground" to false,
            ),
        ),
    )

    private fun breakdownRow(
        key: String,
        label: String,
        pssKb: Long,
        ratio: Double,
        cleanable: String,
        meaning: String,
    ): Map<String, Any?> = linkedMapOf(
        "key" to key,
        "label" to label,
        "pssKb" to pssKb,
        "ratio" to ratio,
        "cleanable" to cleanable,
        "meaning" to meaning,
    )

    private fun buildState(snapshot: Map<String, Any?> = collectorSnapshotFixture()): MemoryStatsViewState =
        buildMemoryStatsViewState(
            snapshot = snapshot,
            autoRefreshEnabled = true,
            refreshIntervalSeconds = DEFAULT_REFRESH_INTERVAL_SECONDS,
            lastRefreshedAt = java.time.LocalTime.of(9, 8, 7),
        )

    // ==========================================
    // 1. 采集器 key 表 → 页面每一行都真有值
    // ==========================================

    @Test
    fun `概览与采样说明吃掉采集器的顶层字段`() {
        val state = buildState()

        assertEquals("500.00 MB", state.summaryText)
        assertEquals("压力 偏高 · 前台 · 峰值 600.00 MB", state.summarySubtitle)
        assertEquals(MemoryPressure.HIGH, state.pressure)
        assertEquals("前台", state.appStateLabel)
        assertEquals(0.5, state.javaHeapUsageRatio, 0.0001)
        assertTrue(
            state.refreshDescription.endsWith("最近刷新：09:08:07"),
        )
    }

    @Test
    fun `内存构成四行取值全部来自采集器`() {
        val byRow = buildState().compositionRows.associateBy { it.row }

        assertEquals("50.0%", byRow.getValue(MemoryStatsRow.JAVA_HEAP).details)
        assertEquals("500.00 MB", byRow.getValue(MemoryStatsRow.PSS_BREAKDOWN).details)
        assertEquals("400.00 MB", byRow.getValue(MemoryStatsRow.DEBUG_MEMORY).details)
        assertEquals("正常", byRow.getValue(MemoryStatsRow.SYSTEM_MEMORY).details)
    }

    @Test
    fun `运行环境四行取值全部来自采集器`() {
        val byRow = buildState().environmentRows.associateBy { it.row }

        assertEquals("2 个进程", byRow.getValue(MemoryStatsRow.APP_OVERVIEW).details)
        assertEquals("前台", byRow.getValue(MemoryStatsRow.BACKGROUND_SAMPLING).details)
        assertEquals("运行中", byRow.getValue(MemoryStatsRow.LIVE_ISLAND).details)
        assertEquals("2 个", byRow.getValue(MemoryStatsRow.PROCESS_LIST).details)
    }

    @Test
    fun `诊断工具五行取值全部来自采集器`() {
        val byRow = buildState().toolRows.associateBy { it.row }

        assertEquals("约 500 MB · 偏高", byRow.getValue(MemoryStatsRow.ANALYSIS).title)
        assertEquals("偏高", byRow.getValue(MemoryStatsRow.ANALYSIS).details)
        assertEquals("1 条", byRow.getValue(MemoryStatsRow.HISTORY).details)
        assertEquals("3 项", byRow.getValue(MemoryStatsRow.MEMORY_STATS).details)
        assertEquals("完整快照", byRow.getValue(MemoryStatsRow.RAW_JSON).details)
        // 1_700_000_000_000ms = 2023-11-14T22:13:20Z → Asia/Shanghai 11-15 06:13:20
        assertEquals("11-15 06:13:20", byRow.getValue(MemoryStatsRow.FAIR_MEMORY).details)
    }

    @Test
    fun `应用总览弹层把 app 与 uptime 都用上`() {
        val byLabel = buildState().sheets.getValue(MemorySheet.OVERVIEW).rows.associate { it.label to it.value }

        assertEquals("1h 2m 5s", byLabel.getValue("运行时长"))
        assertEquals("com.mutx163.qingyu.debug", byLabel.getValue("包名"))
        assertEquals("2", byLabel.getValue("进程数"))
        assertEquals("24", byLabel.getValue("会话采样次数"))
        assertEquals("18 / 6", byLabel.getValue("前台 / 后台采样次数"))
        assertEquals("2", byLabel.getValue("系统 onLowMemory 次数"))
        assertEquals("468.75 MB", byLabel.getValue("当前进程 PSS"))
        assertEquals("517.58 MB", byLabel.getValue("进程接口合计 PSS"))
        assertEquals("200.00 MB", byLabel.getValue("Private Dirty 合计"))
    }

    @Test
    fun `Debug 内存弹层七类 PSS 都有值`() {
        val byLabel = buildState().sheets.getValue(MemorySheet.DEBUG_MEMORY).rows.associate { it.label to it.value }

        assertEquals("60.00 MB", byLabel.getValue("Java / Dalvik"))
        assertEquals("150.00 MB", byLabel.getValue("Native"))
        assertEquals("80.00 MB", byLabel.getValue("Graphics"))
        assertEquals("40.00 MB", byLabel.getValue("Code"))
        assertEquals("1.00 MB", byLabel.getValue("Stack"))
        assertEquals("50.00 MB / 19.00 MB", byLabel.getValue("Other / System"))
    }

    @Test
    fun `系统内存弹层用 system 的七个字段`() {
        val byLabel = buildState().sheets.getValue(MemorySheet.SYSTEM_MEMORY).rows.associate { it.label to it.value }

        assertEquals("1.00 GB / 8.00 GB", byLabel.getValue("设备可用 / 总量"))
        assertEquals("256.00 MB", byLabel.getValue("低内存阈值"))
        assertEquals("否", byLabel.getValue("系统 isLowMemory"))
        assertEquals("256 / 512 MB", byLabel.getValue("memoryClass / large"))
    }

    @Test
    fun `PSS 分类弹层按采集器 ordered 顺序铺开七类`() {
        val sheet = buildState().sheets.getValue(MemorySheet.PSS_BREAKDOWN)

        assertEquals(
            listOf(
                "Private Other 其它私有",
                "System 系统分摊",
                "Graphics 图形",
                "Native 堆",
                "Java 堆",
                "Code 代码映射",
                "Stack 栈",
            ),
            sheet.breakdown.map { it.label },
        )
        assertEquals("部分可清", sheet.breakdown.first { it.label == "Java 堆" }.cleanableLabel)
        assertEquals("基本不可清", sheet.breakdown.first { it.label == "Stack 栈" }.cleanableLabel)
    }

    @Test
    fun `分析弹层带采集器的粗估与口径说明`() {
        val sheet = buildState().sheets.getValue(MemorySheet.ANALYSIS)

        assertEquals("可节约粗估：易清 0 MB · 中等 20 MB · 难清 219 MB", sheet.cleanableSummary)
        assertEquals(
            "easy≈图片缓存等；medium≈图形/壁纸/模糊；hard≈原生运行时与系统分摊（难清）。估算仅供参考。",
            sheet.cleanableNote,
        )
        assertEquals(2, sheet.bullets.size)
    }

    @Test
    fun `进程弹层按采集器字段拼一行说明`() {
        val processes = buildState().sheets.getValue(MemorySheet.PROCESS_LIST).processes

        assertEquals(2, processes.size)
        assertEquals("com.mutx163.qingyu.debug", processes[0].name)
        assertEquals("4242", processes[0].pidText)
        assertTrue(processes[0].isMainProcess)
        assertEquals("com.mutx163.qingyu.debug:live", processes[1].name)
        assertTrue(processes[1].likelyLiveIsland)
    }

    @Test
    fun `历史弹层用 history 的采样字段`() {
        val sheet = buildState().sheets.getValue(MemorySheet.HISTORY)
        val row = sheet.history.single()

        assertEquals("共 1 点 · 最早→最晚", sheet.historySummary)
        assertEquals("11-15 06:13:20", row.timeText)
        assertEquals("后台", row.stateLabel)
        assertEquals("500.00 MB", row.pssText)
        assertEquals("50.0%", row.heapRatioText)
        assertEquals("岛开", row.liveLabel)
        assertEquals("high", row.pressureLevel)
    }

    @Test
    fun `memoryStats 弹层把键值表按行拼出来`() {
        val body = buildState().sheets.getValue(MemorySheet.MEMORY_STATS).bodyText!!

        assertTrue(body.contains("summary.total-pss = 520192"))
        assertTrue(body.contains("summary.native-heap = 153600"))
    }

    /**
     * 图片缓存行读的是采集器的 `imageCache` 块（Compose 图片加载器），
     * 而不是 Flutter 运行时补进来的 `dartVm` / `flutterImageCache`。
     */
    @Test
    fun imageCacheRowUsesComposeLoaderBlock() {
        val state = buildState()
        val imageCache = state.compositionRows.first { it.row == MemoryStatsRow.IMAGE_CACHE }

        assertEquals("1.00 MB", imageCache.details)
        val sheetRows = state.sheets.getValue(MemorySheet.IMAGE_CACHE).rows.associate { it.label to it.value }
        assertEquals("AndroidImageLoader", sheetRows.getValue("来源"))
        assertEquals("1.00 MB / 16.00 MB", sheetRows.getValue("占用 / 上限"))
        assertEquals("2 条", sheetRows.getValue("缓存条目数"))
        assertNull(memorySnapshotError(collectorSnapshotFixture()))
    }

    /**
     * 反向守卫：采集器源码里不再有 Flutter 运行时专属的 key。
     *
     * 这是 2026-10-31 用户实测反馈的机器化拦网——「内存统计页的参数怎么都是统计 Flutter 的」。
     * 谁把 `dartVm` / `flutterImageCache` 加回采集器（或把这两个 key 塞进模型读取），这条先红。
     * 用户可见字符串里也不许再出现 `Flutter`（注释不拦，源码里只有字符串会被扫到）。
     */
    @Test
    fun collectorHasNoFlutterRuntimeKeys() {
        val source = collectorSource()
        assumeTrue("未定位到 MemoryStatsCollector.kt，跳过", source != null)
        val text = collectorText(source!!)

        // 否定式断言在空读上恒真：先钉一个必须存在的正向锚，否则「路径写错」= 全绿。
        assertTrue(
            "采集器源码里读不到 `fun buildSnapshot(`：路径 / 读法错了，" +
                "下面两条否定式断言会在空文本上恒真",
            text.contains("fun buildSnapshot("),
        )
        assertFalse("采集器里不该再产出 dartVm", text.contains("\"dartVm\""))
        assertFalse("采集器里不该再产出 flutterImageCache", text.contains("\"flutterImageCache\""))
        // 只扫字符串字面量（`"..."`），注释里的历史说明不拦（行注释已由 collectorText 剥掉）。
        val literals = Regex("\"((?:[^\"\\\\]|\\\\.)*)\"").findAll(text).map { it.groupValues[1] }.toList()
        assertTrue(
            "采集器源码里一个字符串字面量都没抽到：读法把内容擦掉了（例如误用了中性化档）？",
            literals.isNotEmpty(),
        )
        for (literal in literals) {
            assertFalse("用户可见文案里不该再出现 Flutter：$literal", literal.contains("Flutter"))
        }
    }

    // ==========================================
    // 2. 源码级 key 表对拍（采集器改名 → 这里红）
    // ==========================================

    /**
     * 模型层会读的 key（**不含** `dartVm` / `flutterImageCache`：那两个是 Flutter 运行时专属，
     * 页面已改为读 `imageCache` 块）。
     *
     * 这张表是「模型要什么」的清单；[collectorKeyTableMatchesModelReads] 负责证明
     * 「采集器确实给什么」。
     */
    private val modelReadKeys = listOf(
        // 顶层
        "uptimeMillis", "packageName", "pressureLevel", "pressureLabel", "appInForeground",
        "app", "javaHeap", "debugMemoryInfo", "system", "liveIsland", "fairMemory",
        "backgroundStats", "pssBreakdown", "analysis", "memoryStats", "processes", "history",
        // imageCache（Compose 图片加载器，取代 Flutter 运行时的 dartVm / flutterImageCache）
        "imageCache", "currentSizeBytes", "maxSizeBytes", "entryCount", "source",
        // app
        "totalPssKb", "selfPssKb", "processSumPssKb", "totalPrivateDirtyKb", "peakTotalPssKb",
        "peakJavaHeapAllocKb", "sampleCount", "foregroundSampleCount", "backgroundSampleCount",
        "lowMemoryEventCount", "processCount",
        // javaHeap
        "allocBytes", "maxBytes", "usageRatio", "nearOom",
        // debugMemoryInfo
        "dalvikPssKb", "nativePssKb", "graphicsPssKb", "codePssKb", "stackPssKb",
        "otherPssKb", "systemPssKb",
        // system
        "isLowMemory", "availMemBytes", "totalMemBytes", "thresholdBytes",
        "memoryClassMb", "largeMemoryClassMb",
        // liveIsland / fairMemory
        "serviceRunning", "serviceClass", "lastKillAtMillis", "lastKillNotifyType",
        "lastKillNotifyId", "lastKillReason",
        // backgroundStats
        "currentlyBackground", "foregroundSampleIntervalSec", "backgroundSampleIntervalSec",
        "hasBackgroundSamples", "backgroundPointCount", "lastForegroundPssKb",
        "lastBackgroundPssKb", "backgroundMinusLastForegroundKb", "peakForegroundPssKb",
        "avgForegroundPssKb", "peakBackgroundPssKb", "avgBackgroundPssKb",
        "lastForegroundAtMillis", "lastBackgroundAtMillis", "note",
        // pssBreakdown
        "ordered", "key", "label", "pssKb", "ratio", "cleanable", "meaning",
        // analysis
        "headline", "severityLabel", "bullets", "cleanableEstimate", "easyMb", "mediumMb", "hardMb",
        // processes / history
        "pid", "processName", "isMainProcess", "likelyLiveIsland",
        "atMillis", "javaHeapUsageRatio", "liveServiceRunning",
    )

    /** 从任意工作目录向上找仓库根（L0 在仓库根跑，Gradle 单测在 `android/app` 跑）。 */
    private fun collectorSource(): File? {
        val relative = "android/app/src/main/kotlin/com/mutx163/qingyu/MemoryStatsCollector.kt"
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate
            dir = dir.parentFile
        }
        return null
    }

    /**
     * 采集器源码的**默认档**读法：剥注释、**保留字符串内容**（档位理由见类注释「读法」一节）。
     *
     * 行尾先归一（工作区是 CRLF，索引是 LF），否则带换行的锚点会随机假红。
     */
    private fun collectorText(file: File): String =
        stripKotlinComments(
            file.readText(Charsets.UTF_8).replace("\r\n", "\n"),
            neutralizeStrings = false,
        )

    @Test
    fun collectorKeyTableMatchesModelReads() {
        val source = collectorSource()
        // 找不到源码（例如测试在别的目录跑）就跳过，不让它变成假红。
        assumeTrue("未定位到 MemoryStatsCollector.kt，跳过源码级 key 对拍", source != null)
        val text = collectorText(source!!)

        val missing = modelReadKeys.filterNot { key -> text.contains("\"$key\"") }
        assertEquals(
            "这些 key 模型层在读、但采集器源码里找不到（有人改名了？）：$missing",
            emptyList<String>(),
            missing,
        )
    }

    /**
     * 反向证明上一行的扫法是「真的有牙齿」：一个不存在的 key 必须被判定为缺失。
     *
     * （与 [collectorKeyTableMatchesModelReads] 同一条判据，只是换成假 key。）
     */
    @Test
    fun keyTableScanDetectsUnknownKey() {
        val source = collectorSource()
        assumeTrue("未定位到 MemoryStatsCollector.kt，跳过源码级 key 对拍", source != null)
        val text = collectorText(source!!)

        assertNotEquals(-1, text.indexOf("\"totalPssKb\""))
        assertEquals(-1, text.indexOf("\"definitelyNotACollectorKey\""))
    }
}
