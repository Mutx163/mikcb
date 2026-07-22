package com.mutx163.qingyu

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.os.SystemClock
import java.util.ArrayDeque
import java.util.concurrent.atomic.AtomicBoolean
import android.app.Activity
import android.app.Application
import android.os.Bundle
import java.util.concurrent.atomic.AtomicInteger

/**
 * 全应用内存快照与会话采样（调试版 / 性能版）。
 *
 * 统计范围包含主进程、超级岛 [LiveUpdateService] 所在进程，以及同包名下其它子进程。
 * 正式版（无 `.debug` / `.profile` 后缀）不会启动采样。
 *
 * 后台统计说明：
 * - 进程仍存活时（回桌面、仅超级岛 FGS 等）可继续采样并标记 foreground/background
 * - 进程被系统杀掉后无法再采样；回前台后只能看到「被杀前」最后若干后台点
 */
object MemoryStatsCollector {
    private const val TAG = "MemoryStatsCollector"
    private const val CHANNEL_NAME = "com.mutx163.qingyu/memory_stats"
    private const val FOREGROUND_SAMPLE_INTERVAL_MILLIS = 15_000L
    private const val BACKGROUND_SAMPLE_INTERVAL_MILLIS = 30_000L
    private const val MAX_HISTORY_SAMPLES = 240
    private const val PREFS_FAIR_MEMORY = "fair_memory_runtime"

    private val samplingStarted = AtomicBoolean(false)
    private val historyLock = Any()
    private val historySamples = ArrayDeque<Map<String, Any?>>(MAX_HISTORY_SAMPLES)
    private val startedActivityCount = AtomicInteger(0)

    private var workerHandler: Handler? = null
    private var sampleRunnable: Runnable? = null
    private var processStartElapsedRealtimeMillis: Long = 0L
    private var peakTotalPssKb: Long = 0L
    private var peakJavaHeapAllocKb: Long = 0L
    private var peakForegroundPssKb: Long = 0L
    private var peakBackgroundPssKb: Long = 0L
    private var sampleCount: Long = 0L
    private var foregroundSampleCount: Long = 0L
    private var backgroundSampleCount: Long = 0L
    private var lowMemoryEventCount: Long = 0L
    private var lastForegroundAtMillis: Long = 0L
    private var lastBackgroundAtMillis: Long = 0L
    private var lastForegroundPssKb: Long = 0L
    private var lastBackgroundPssKb: Long = 0L
    private var lifecycleCallbacksRegistered = false

    val methodChannelName: String get() = CHANNEL_NAME

    fun isDiagnosticsPackage(context: Context): Boolean {
        val packageName = context.packageName
        return packageName.endsWith(".debug") || packageName.endsWith(".profile")
    }

    fun initializeIfAllowed(context: Context) {
        if (!isDiagnosticsPackage(context)) {
            return
        }
        if (!samplingStarted.compareAndSet(false, true)) {
            return
        }
        processStartElapsedRealtimeMillis = SystemClock.elapsedRealtime()
        lastForegroundAtMillis = System.currentTimeMillis()
        registerLifecycleCallbacksIfPossible(context)
        val handlerThread = HandlerThread(TAG).apply { start() }
        val handler = Handler(handlerThread.looper)
        workerHandler = handler
        val appContext = context.applicationContext
        val runnable = object : Runnable {
            override fun run() {
                try {
                    recordSample(appContext)
                } catch (_: Exception) {
                }
                val delay = if (isAppInForeground()) {
                    FOREGROUND_SAMPLE_INTERVAL_MILLIS
                } else {
                    BACKGROUND_SAMPLE_INTERVAL_MILLIS
                }
                workerHandler?.postDelayed(this, delay)
            }
        }
        sampleRunnable = runnable
        // 首帧延迟一点，避免 Application 启动尖峰污染基线。
        handler.postDelayed(runnable, 2_000L)
    }

    fun onSystemLowMemory() {
        lowMemoryEventCount += 1
    }

    fun isAppInForeground(): Boolean = startedActivityCount.get() > 0

    private fun registerLifecycleCallbacksIfPossible(context: Context) {
        if (lifecycleCallbacksRegistered) {
            return
        }
        val application = context.applicationContext as? Application ?: return
        application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityStarted(activity: Activity) {
                val count = startedActivityCount.incrementAndGet()
                if (count == 1) {
                    lastForegroundAtMillis = System.currentTimeMillis()
                    // 回前台立刻补采一点，便于对比刚从后台回来的 PSS。
                    workerHandler?.post {
                        try {
                            recordSample(application)
                        } catch (_: Exception) {
                        }
                    }
                }
            }
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivityStopped(activity: Activity) {
                val count = startedActivityCount.decrementAndGet()
                if (count <= 0) {
                    startedActivityCount.set(0)
                    lastBackgroundAtMillis = System.currentTimeMillis()
                    workerHandler?.post {
                        try {
                            recordSample(application)
                        } catch (_: Exception) {
                        }
                    }
                }
            }
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
        lifecycleCallbacksRegistered = true
    }

    fun buildSnapshot(context: Context): Map<String, Any?> {
        val appContext = context.applicationContext
        val activityManager =
            appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val runtime = Runtime.getRuntime()
        val javaHeapMaxBytes = runtime.maxMemory()
        val javaHeapTotalBytes = runtime.totalMemory()
        val javaHeapFreeBytes = runtime.freeMemory()
        val javaHeapAllocBytes = javaHeapTotalBytes - javaHeapFreeBytes
        val javaHeapUsageRatio =
            if (javaHeapMaxBytes > 0) {
                javaHeapAllocBytes.toDouble() / javaHeapMaxBytes.toDouble()
            } else {
                0.0
            }

        val selfPssKb = Debug.getPss()
        val detailedMemoryInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(detailedMemoryInfo)

        val processRows = collectProcessRows(appContext, activityManager)
        // 部分机型上 getProcessMemoryInfo 会“粘滞”，Debug.getPss() 更实时。
        // 单进程：以 self 为准；多进程：各子进程 + 主进程用 max(子进程行, self)。
        val processSumPssKb = processRows.sumOf { (it["pssKb"] as? Number)?.toLong() ?: 0L }
        val totalPssKb = when {
            processRows.size <= 1 -> maxOf(selfPssKb, processSumPssKb)
            else -> {
                val others = processRows
                    .filter { it["isMainProcess"] != true }
                    .sumOf { (it["pssKb"] as? Number)?.toLong() ?: 0L }
                others + maxOf(selfPssKb, processRows
                    .firstOrNull { it["isMainProcess"] == true }
                    ?.let { (it["pssKb"] as? Number)?.toLong() ?: 0L }
                    ?: 0L)
            }
        }.coerceAtLeast(selfPssKb)
        val totalPrivateDirtyKb = processRows.sumOf {
            (it["privateDirtyKb"] as? Number)?.toLong() ?: 0L
        }

        val memoryClassMb = activityManager.memoryClass
        val largeMemoryClassMb = activityManager.largeMemoryClass
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        val isLowMemory = memoryInfo.lowMemory

        val liveServiceRunning = isLiveUpdateServiceRunning(activityManager)
        val fairMemoryMarker = readFairMemoryMarker(appContext)

        val uptimeMillis = SystemClock.elapsedRealtime() - processStartElapsedRealtimeMillis
        val appInForeground = isAppInForeground()
        val appState = if (appInForeground) "foreground" else "background"
        synchronized(historyLock) {
            if (totalPssKb > peakTotalPssKb) {
                peakTotalPssKb = totalPssKb
            }
            if (appInForeground) {
                if (totalPssKb > peakForegroundPssKb) {
                    peakForegroundPssKb = totalPssKb
                }
                lastForegroundPssKb = totalPssKb
            } else {
                if (totalPssKb > peakBackgroundPssKb) {
                    peakBackgroundPssKb = totalPssKb
                }
                lastBackgroundPssKb = totalPssKb
            }
            val allocKb = javaHeapAllocBytes / 1024L
            if (allocKb > peakJavaHeapAllocKb) {
                peakJavaHeapAllocKb = allocKb
            }
        }

        val pressureLevel = classifyPressure(
            javaHeapUsageRatio = javaHeapUsageRatio,
            isLowMemory = isLowMemory,
            systemAvailMemBytes = memoryInfo.availMem,
            systemThresholdBytes = memoryInfo.threshold,
        )

        val memoryStatsMap = readAllMemoryStats(detailedMemoryInfo)
        val breakdown = buildPssBreakdown(
            detailed = detailedMemoryInfo,
            stats = memoryStatsMap,
            totalPssKb = totalPssKb,
        )
        val analysis = buildAnalysisHints(
            totalPssKb = totalPssKb,
            javaHeapUsageRatio = javaHeapUsageRatio,
            graphicsPssKb = (breakdown["graphics"] as? Map<*, *>)?.get("pssKb") as? Number,
            privateOtherPssKb = (breakdown["privateOther"] as? Map<*, *>)?.get("pssKb") as? Number,
            nativePssKb = (breakdown["nativeHeap"] as? Map<*, *>)?.get("pssKb") as? Number,
            systemPssKb = (breakdown["system"] as? Map<*, *>)?.get("pssKb") as? Number,
            imageCacheBytes = 0L,
            liveServiceRunning = liveServiceRunning,
            isDebugPackage = isDiagnosticsPackage(appContext),
        )

        return linkedMapOf(
            "generatedAtMillis" to System.currentTimeMillis(),
            "uptimeMillis" to uptimeMillis.coerceAtLeast(0L),
            "packageName" to appContext.packageName,
            "diagnosticsPackage" to isDiagnosticsPackage(appContext),
            "pressureLevel" to pressureLevel,
            "pressureLabel" to pressureLabelZh(pressureLevel),
            "appState" to appState,
            "appInForeground" to appInForeground,
            "app" to linkedMapOf(
                "totalPssKb" to totalPssKb,
                "selfPssKb" to selfPssKb,
                "processSumPssKb" to processSumPssKb,
                "totalPrivateDirtyKb" to totalPrivateDirtyKb,
                "peakTotalPssKb" to peakTotalPssKb,
                "peakJavaHeapAllocKb" to peakJavaHeapAllocKb,
                "sampleCount" to sampleCount,
                "foregroundSampleCount" to foregroundSampleCount,
                "backgroundSampleCount" to backgroundSampleCount,
                "lowMemoryEventCount" to lowMemoryEventCount,
                "processCount" to processRows.size,
            ),
            "backgroundStats" to buildBackgroundStats(totalPssKb = totalPssKb, appInForeground = appInForeground),
            "javaHeap" to linkedMapOf(
                "allocBytes" to javaHeapAllocBytes,
                "totalBytes" to javaHeapTotalBytes,
                "freeBytes" to javaHeapFreeBytes,
                "maxBytes" to javaHeapMaxBytes,
                "usageRatio" to javaHeapUsageRatio,
                "nearOom" to (javaHeapUsageRatio >= 0.85),
            ),
            "debugMemoryInfo" to linkedMapOf(
                "totalPssKb" to detailedMemoryInfo.totalPss.toLong(),
                "totalPrivateDirtyKb" to detailedMemoryInfo.totalPrivateDirty.toLong(),
                "totalSharedDirtyKb" to detailedMemoryInfo.totalSharedDirty.toLong(),
                "dalvikPssKb" to readStatKb(detailedMemoryInfo, "summary.java-heap", detailedMemoryInfo.dalvikPss),
                "nativePssKb" to readStatKb(detailedMemoryInfo, "summary.native-heap", detailedMemoryInfo.nativePss),
                "graphicsPssKb" to readStatKb(detailedMemoryInfo, "summary.graphics", 0),
                "codePssKb" to readStatKb(detailedMemoryInfo, "summary.code", 0),
                "stackPssKb" to readStatKb(detailedMemoryInfo, "summary.stack", 0),
                "otherPssKb" to readStatKb(detailedMemoryInfo, "summary.private-other", detailedMemoryInfo.otherPss),
                "systemPssKb" to readStatKb(detailedMemoryInfo, "summary.system", 0),
            ),
            "memoryStats" to memoryStatsMap,
            "pssBreakdown" to breakdown,
            "analysis" to analysis,
            "system" to linkedMapOf(
                "memoryClassMb" to memoryClassMb,
                "largeMemoryClassMb" to largeMemoryClassMb,
                "isLowMemory" to isLowMemory,
                "availMemBytes" to memoryInfo.availMem,
                "totalMemBytes" to memoryInfo.totalMem,
                "thresholdBytes" to memoryInfo.threshold,
                "sdkInt" to Build.VERSION.SDK_INT,
            ),
            "liveIsland" to linkedMapOf(
                "serviceRunning" to liveServiceRunning,
                "serviceClass" to LiveUpdateService::class.java.name,
                "note" to "超级岛前台服务与主进程同 UID；进程行中可能单独列出",
            ),
            "fairMemory" to fairMemoryMarker,
            "processes" to processRows,
            "history" to snapshotHistory(),
        )
    }

    private fun recordSample(context: Context) {
        val snapshot = buildSnapshot(context)
        val app = snapshot["app"] as? Map<*, *> ?: return
        val javaHeap = snapshot["javaHeap"] as? Map<*, *> ?: return
        val appInForeground = snapshot["appInForeground"] == true
        val appState = snapshot["appState"]?.toString() ?: if (appInForeground) "foreground" else "background"
        val sample = linkedMapOf<String, Any?>(
            "atMillis" to snapshot["generatedAtMillis"],
            "totalPssKb" to app["totalPssKb"],
            "selfPssKb" to app["selfPssKb"],
            "processSumPssKb" to app["processSumPssKb"],
            "javaHeapAllocBytes" to javaHeap["allocBytes"],
            "javaHeapUsageRatio" to javaHeap["usageRatio"],
            "pressureLevel" to snapshot["pressureLevel"],
            "liveServiceRunning" to (snapshot["liveIsland"] as? Map<*, *>)?.get("serviceRunning"),
            "processCount" to app["processCount"],
            "appState" to appState,
            "appInForeground" to appInForeground,
        )
        synchronized(historyLock) {
            sampleCount += 1
            if (appInForeground) {
                foregroundSampleCount += 1
            } else {
                backgroundSampleCount += 1
            }
            historySamples.addLast(sample)
            while (historySamples.size > MAX_HISTORY_SAMPLES) {
                historySamples.removeFirst()
            }
        }
    }

    private fun buildBackgroundStats(totalPssKb: Long, appInForeground: Boolean): Map<String, Any?> {
        val history = snapshotHistory()
        val backgroundPoints = history.filter { it["appInForeground"] == false }
        val foregroundPoints = history.filter { it["appInForeground"] == true }
        fun avgPss(points: List<Map<String, Any?>>): Long {
            if (points.isEmpty()) {
                return 0L
            }
            val sum = points.sumOf { (it["totalPssKb"] as? Number)?.toLong() ?: 0L }
            return sum / points.size
        }
        val avgBackground = avgPss(backgroundPoints)
        val avgForeground = avgPss(foregroundPoints)
        val lastBg = backgroundPoints.lastOrNull()?.let { (it["totalPssKb"] as? Number)?.toLong() }
            ?: lastBackgroundPssKb.takeIf { it > 0 }
        val lastFg = foregroundPoints.lastOrNull()?.let { (it["totalPssKb"] as? Number)?.toLong() }
            ?: lastForegroundPssKb.takeIf { it > 0 }
        val delta = if (lastBg != null && lastFg != null) lastBg - lastFg else null
        return linkedMapOf(
            "currentlyBackground" to !appInForeground,
            "foregroundSampleIntervalSec" to (FOREGROUND_SAMPLE_INTERVAL_MILLIS / 1000L),
            "backgroundSampleIntervalSec" to (BACKGROUND_SAMPLE_INTERVAL_MILLIS / 1000L),
            "foregroundSampleCount" to foregroundSampleCount,
            "backgroundSampleCount" to backgroundSampleCount,
            "peakForegroundPssKb" to peakForegroundPssKb,
            "peakBackgroundPssKb" to peakBackgroundPssKb,
            "avgForegroundPssKb" to avgForeground,
            "avgBackgroundPssKb" to avgBackground,
            "lastForegroundPssKb" to (lastFg ?: 0L),
            "lastBackgroundPssKb" to (lastBg ?: 0L),
            "lastForegroundAtMillis" to lastForegroundAtMillis,
            "lastBackgroundAtMillis" to lastBackgroundAtMillis,
            "backgroundMinusLastForegroundKb" to (delta ?: 0L),
            "hasBackgroundSamples" to backgroundPoints.isNotEmpty(),
            "backgroundPointCount" to backgroundPoints.size,
            "note" to "后台采样仅在进程仍存活时有效；若进程被杀，历史中不会再增加后台点。",
        )
    }

    private fun snapshotHistory(): List<Map<String, Any?>> {
        synchronized(historyLock) {
            return historySamples.map { LinkedHashMap(it) }
        }
    }

    private fun collectProcessRows(
        context: Context,
        activityManager: ActivityManager,
    ): List<Map<String, Any?>> {
        val packageName = context.packageName
        val running = activityManager.runningAppProcesses ?: emptyList()
        val ownProcesses = running.filter { processInfo ->
            processInfo.processName == packageName ||
                processInfo.processName.startsWith("$packageName:") ||
                processInfo.pkgList?.contains(packageName) == true
        }
        if (ownProcesses.isEmpty()) {
            val selfInfo = Debug.MemoryInfo()
            Debug.getMemoryInfo(selfInfo)
            return listOf(
                linkedMapOf(
                    "pid" to Process.myPid(),
                    "processName" to packageName,
                    "importance" to "self",
                    "pssKb" to Debug.getPss(),
                    "privateDirtyKb" to selfInfo.totalPrivateDirty.toLong(),
                    "sharedDirtyKb" to selfInfo.totalSharedDirty.toLong(),
                    "isMainProcess" to true,
                    "likelyLiveIsland" to false,
                ),
            )
        }

        val pids = ownProcesses.map { it.pid }.toIntArray()
        val memoryInfos = try {
            activityManager.getProcessMemoryInfo(pids)
        } catch (_: Exception) {
            emptyArray()
        }

        return ownProcesses.mapIndexed { index, processInfo ->
            val memoryInfo = memoryInfos.getOrNull(index)
            val pssKb = memoryInfo?.totalPss?.toLong() ?: 0L
            val processName = processInfo.processName.orEmpty()
            linkedMapOf(
                "pid" to processInfo.pid,
                "processName" to processName,
                "importance" to processInfo.importance,
                "pssKb" to pssKb,
                "privateDirtyKb" to (memoryInfo?.totalPrivateDirty?.toLong() ?: 0L),
                "sharedDirtyKb" to (memoryInfo?.totalSharedDirty?.toLong() ?: 0L),
                "isMainProcess" to (processName == packageName),
                "likelyLiveIsland" to processName.contains("live", ignoreCase = true),
            )
        }.sortedByDescending { (it["pssKb"] as? Number)?.toLong() ?: 0L }
    }

    private fun isLiveUpdateServiceRunning(activityManager: ActivityManager): Boolean {
        val target = LiveUpdateService::class.java.name
        @Suppress("DEPRECATION")
        val services = activityManager.getRunningServices(50) ?: return false
        return services.any { it.service.className == target }
    }

    private fun readFairMemoryMarker(context: Context): Map<String, Any?> {
        val prefs = context.getSharedPreferences(PREFS_FAIR_MEMORY, Context.MODE_PRIVATE)
        return linkedMapOf(
            "lastKillAtMillis" to prefs.getLong("last_kill_at_millis", 0L),
            "lastKillNotifyType" to prefs.getInt("last_kill_notify_type", 0),
            "lastKillNotifyId" to prefs.getInt("last_kill_notify_id", 0),
            "lastKillReason" to (prefs.getString("last_kill_reason", "") ?: ""),
        )
    }

    private fun readStatKb(memoryInfo: Debug.MemoryInfo, key: String, fallback: Int): Long {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val raw = memoryInfo.getMemoryStat(key) ?: return fallback.toLong()
            return raw.toLongOrNull() ?: fallback.toLong()
        }
        return fallback.toLong()
    }

    private fun readAllMemoryStats(memoryInfo: Debug.MemoryInfo): Map<String, String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return emptyMap()
        }
        return try {
            val stats = memoryInfo.memoryStats ?: return emptyMap()
            stats.toSortedMap()
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun buildPssBreakdown(
        detailed: Debug.MemoryInfo,
        stats: Map<String, String>,
        totalPssKb: Long,
    ): Map<String, Any?> {
        fun row(key: String, label: String, pssKb: Long, cleanable: String, meaning: String): Map<String, Any?> {
            val ratio = if (totalPssKb > 0) pssKb.toDouble() / totalPssKb.toDouble() else 0.0
            return linkedMapOf(
                "key" to key,
                "label" to label,
                "pssKb" to pssKb,
                "ratio" to ratio,
                "cleanable" to cleanable,
                "meaning" to meaning,
            )
        }

        val javaHeap = readStatKb(detailed, "summary.java-heap", detailed.dalvikPss)
        val nativeHeap = readStatKb(detailed, "summary.native-heap", detailed.nativePss)
        val code = readStatKb(detailed, "summary.code", 0)
        val stack = readStatKb(detailed, "summary.stack", 0)
        val graphics = readStatKb(detailed, "summary.graphics", 0)
        val privateOther = readStatKb(detailed, "summary.private-other", detailed.otherPss)
        val system = readStatKb(detailed, "summary.system", 0)
        val totalFromStats = stats["summary.total-pss"]?.toLongOrNull()
            ?: detailed.totalPss.toLong()

        return linkedMapOf(
            "totalPssKb" to totalPssKb,
            "debugTotalPssKb" to totalFromStats,
            "javaHeap" to row(
                key = "javaHeap",
                label = "Java 堆",
                pssKb = javaHeap,
                cleanable = "partial",
                meaning = "Android/Java 对象（含部分插件）。堆使用率高才像泄漏；当前多为正常业务对象。",
            ),
            "nativeHeap" to row(
                key = "nativeHeap",
                label = "Native 堆",
                pssKb = nativeHeap,
                cleanable = "hard",
                meaning = "C/C++ 堆：Flutter Engine、Skia、编解码、部分 SDK。难用应用层 GC 直接清掉。",
            ),
            "graphics" to row(
                key = "graphics",
                label = "Graphics 图形",
                pssKb = graphics,
                cleanable = "partial",
                meaning = "GPU/纹理/Surface/渲染缓冲。壁纸、毛玻璃、复杂课表绘制、多层模糊会抬高。",
            ),
            "code" to row(
                key = "code",
                label = "Code 代码映射",
                pssKb = code,
                cleanable = "no",
                meaning = "so/dex/oat 映射。调试版通常更大，几乎不可清，属于固定开销。",
            ),
            "stack" to row(
                key = "stack",
                label = "Stack 栈",
                pssKb = stack,
                cleanable = "no",
                meaning = "线程栈，通常很小。",
            ),
            "privateOther" to row(
                key = "privateOther",
                label = "Private Other 其它私有",
                pssKb = privateOther,
                cleanable = "hard",
                meaning = "未归入上述类的私有映射：引擎内部、匿名共享、部分图形/IO 缓冲。往往是 Flutter 大头之一。",
            ),
            "system" to row(
                key = "system",
                label = "System 系统分摊",
                pssKb = system,
                cleanable = "no",
                meaning = "系统库/共享映射按比例摊到本进程的 PSS。不是你 new 出来的对象，也难主动释放。",
            ),
            "ordered" to listOf(
                "privateOther", "system", "graphics", "nativeHeap", "javaHeap", "code", "stack",
            ),
        )
    }

    private fun buildAnalysisHints(
        totalPssKb: Long,
        javaHeapUsageRatio: Double,
        graphicsPssKb: Number?,
        privateOtherPssKb: Number?,
        nativePssKb: Number?,
        systemPssKb: Number?,
        imageCacheBytes: Long,
        liveServiceRunning: Boolean,
        isDebugPackage: Boolean,
    ): Map<String, Any?> {
        val totalMb = totalPssKb / 1024.0
        val graphicsMb = (graphicsPssKb?.toLong() ?: 0L) / 1024.0
        val otherMb = (privateOtherPssKb?.toLong() ?: 0L) / 1024.0
        val nativeMb = (nativePssKb?.toLong() ?: 0L) / 1024.0
        val systemMb = (systemPssKb?.toLong() ?: 0L) / 1024.0

        val severity = when {
            totalMb >= 700 -> "severe"
            totalMb >= 450 -> "high"
            totalMb >= 300 -> "elevated"
            else -> "ok"
        }
        val severityLabel = when (severity) {
            "severe" -> "严重偏高"
            "high" -> "偏高"
            "elevated" -> "略高"
            else -> "可接受"
        }

        val bullets = mutableListOf<String>()
        bullets.add(
            "整应用约 ${"%.0f".format(totalMb)} MB PSS。" +
                if (isDebugPackage) {
                    "当前是调试/性能包，通常比正式版更肥（JIT/断言/调试符号）。"
                } else {
                    "正式包口径。"
                },
        )
        if (javaHeapUsageRatio < 0.25) {
            bullets.add(
                "Java 堆使用率仅 ${"%.1f".format(javaHeapUsageRatio * 100)}%，" +
                    "不是 Java OOM，也不是课表对象堆泄漏的典型形态。",
            )
        } else if (javaHeapUsageRatio >= 0.85) {
            bullets.add("Java 堆接近上限，优先查大对象/缓存泄漏。")
        }
        if (otherMb >= 150) {
            bullets.add(
                "Private Other 约 ${"%.0f".format(otherMb)} MB，通常是 Flutter Engine / 匿名映射大头，" +
                    "难用「清图片缓存」直接砍掉。",
            )
        }
        if (systemMb >= 80) {
            bullets.add(
                "System 分摊约 ${"%.0f".format(systemMb)} MB，属共享库 PSS 记账，清理业务缓存几乎不动它。",
            )
        }
        if (graphicsMb >= 40) {
            bullets.add(
                "Graphics 约 ${"%.0f".format(graphicsMb)} MB：重点怀疑全屏壁纸、多层 BackdropFilter 毛玻璃、" +
                    "复杂课表重绘与截屏模糊管线。",
            )
        }
        if (nativeMb >= 40) {
            bullets.add(
                "Native 约 ${"%.0f".format(nativeMb)} MB：引擎/Skia/插件原生堆，属中长期优化项。",
            )
        }
        if (imageCacheBytes <= 0L) {
            bullets.add(
                "Flutter 图片缓存当前为 0：公平内存 TRIM 的「清图」几乎省不了 PSS；" +
                    "真正可抠的是壁纸解码尺寸、模糊层数、页面常驻。",
            )
        }
        if (!liveServiceRunning) {
            bullets.add("超级岛服务此刻未运行：以上占用主要来自主界面/引擎，不是 LiveUpdateService。")
        } else {
            bullets.add("超级岛服务正在运行：总 PSS 已包含前台服务同 UID 开销。")
        }
        bullets.add(
            "可尝试节约：关/降毛玻璃、换浅色纯色背景代替高清壁纸、少开多层 Sheet、" +
                "用性能版/正式版对比调试版、避免同时开导入 WebView。",
        )

        return linkedMapOf(
            "severity" to severity,
            "severityLabel" to severityLabel,
            "headline" to "约 ${"%.0f".format(totalMb)} MB · $severityLabel",
            "bullets" to bullets,
            "cleanableEstimate" to linkedMapOf(
                "easyMb" to 0,
                "mediumMb" to (graphicsMb * 0.25).toInt().coerceAtLeast(0),
                "hardMb" to (otherMb + systemMb + nativeMb * 0.3).toInt().coerceAtLeast(0),
                "note" to "easy≈图片缓存等；medium≈图形/壁纸/模糊；hard≈引擎与系统分摊（难清）。估算仅供参考。",
            ),
        )
    }

    private fun classifyPressure(
        javaHeapUsageRatio: Double,
        isLowMemory: Boolean,
        systemAvailMemBytes: Long,
        systemThresholdBytes: Long,
    ): String {
        if (javaHeapUsageRatio >= 0.92 || isLowMemory) {
            return "critical"
        }
        if (javaHeapUsageRatio >= 0.80 ||
            (systemThresholdBytes > 0 && systemAvailMemBytes <= systemThresholdBytes * 1.5)
        ) {
            return "high"
        }
        if (javaHeapUsageRatio >= 0.60) {
            return "elevated"
        }
        return "normal"
    }

    private fun pressureLabelZh(level: String): String {
        return when (level) {
            "critical" -> "危急（接近 OOM / 系统低内存）"
            "high" -> "偏高"
            "elevated" -> "升高"
            else -> "正常"
        }
    }
}
