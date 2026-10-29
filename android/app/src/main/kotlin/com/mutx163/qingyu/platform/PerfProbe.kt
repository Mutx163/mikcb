package com.mutx163.qingyu.platform

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.util.Log
import android.view.Choreographer
import android.view.FrameMetrics
import android.view.Window
import com.mutx163.qingyu.BuildConfig
import com.mutx163.qingyu.pages.diagnostics.PerfCostReading
import com.mutx163.qingyu.pages.diagnostics.PerfPageLedger
import com.mutx163.qingyu.pages.diagnostics.PerfProbeCore
import com.mutx163.qingyu.pages.diagnostics.PerfSessionFiles
import com.mutx163.qingyu.pages.diagnostics.perfSnapshotJsonText
import java.io.File
import java.time.Instant
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * 帧性能探针的 **Android 原生采集层**（源：`lib/utils/perf_probe.dart` 里依赖引擎的那部分）。
 *
 * ## 取数用哪个原生 API、为什么
 *
 * | 要的量 | 用什么 | 为什么是它 |
 * |---|---|---|
 * | 每帧 build 耗时 | `Window.OnFrameMetricsAvailableListener` + `FrameMetrics.ANIMATION_DURATION / LAYOUT_MEASURE_DURATION / DRAW_DURATION` | 这三段就是 Android 主线程的「动画 / 布局测量 / 记录绘制命令」，对应 Dart `FrameTiming.buildDuration`（build + layout + paint）。**逐帧**给出，不是采样估算 |
 * | 每帧 raster 耗时 | 同一回调的 `SYNC_DURATION / COMMAND_ISSUE_DURATION / SWAP_BUFFERS_DURATION` | 这三段在渲染线程与合成器一侧（GPU 同步、下发命令、交换缓冲），对应 Dart `FrameTiming.rasterDuration` |
 * | 帧间隔（判面板节奏） | `Choreographer.postFrameCallback` 的 `frameTimeNanos`，主用 `FrameMetrics.INTENDED_VSYNC_TIMESTAMP`（缺失退 `VSYNC_TIMESTAMP`） | 必须是**引擎/面板的 vsync 时刻**，不能用回调到达时间：UI 线程忙时多帧一次性送达，到达间隔要么没有样本要么自相矛盾（Dart 侧同一个坑，`perf_page_ledger.dart:460-462`） |
 * | 进程 CPU / RSS | `Process.getElapsedCpuTime()`（毫秒）+ `/proc/self/statm` | 都不用 binder、不用起进程；`getElapsedCpuTime` 就是进程累计 CPU 时间，`statm` 第二个字段 × 页大小 = RSS。Dart 读 `/proc/self/stat`，口径同源 |
 *
 * ## 口径适配（照抄不了的四处，理由都写在这里）
 *
 * 1. **build / raster 的切分不是 1:1**：Dart 的 `FrameTiming` 天然只有 build 与 raster 两段；
 *    Android 的 `FrameMetrics` 按渲染流水线切成七段。本文件把「主线程侧」三段相加算 build、
 *    「渲染/合成侧」三段相加算 raster；两者都为 0（个别机型不给子阶段）时整段记进 build，
 *    免得一帧真实存在的耗时被读成「0ms，全绿」。
 * 2. **CPU 时间分辨率是毫秒**（Dart 是 USER_HZ 刻度，10ms）：比 Dart 更细，但单位必须
 *    写进 meta（`cpuTimeResolutionMs=1`），否则两版本差分时会被当成同一把尺子。
 * 3. **面板档位来自 `Display.supportedModes`**（Dart 是「上报值 + 60/90/120/144 硬编码」）：
 *    真机报的档位表比硬编码准，挡「不存在的节奏」这件事因此更可靠。
 * 4. **落盘目录是 `filesDir/perf_reports`**（Dart 是 `applicationSupportDirectory/perf_reports`）：
 *    Android 上没有 applicationSupportDirectory，`filesDir` 是不清缓存的等价位置。
 *
 * ## 启用变体（正式包必须判为「未安装」）
 *
 * [isEnabled] 三个条件任一成立才装：
 * * `BuildConfig.DEBUG`（debug / profile 变体）；
 * * `BuildConfig.BUILD_TYPE == "bench"`（性能包：R8 + 非 debuggable，但同包名）；
 * * `ApplicationInfo.FLAG_DEBUGGABLE`（兜底：任何被标记为可调试的包）。
 *
 * 都不成立 ⇒ [attach] 直接返回 false、[PerfProbeCore] 保持未安装，报表页走 Dart 同款
 * 「Probe is not installed in this build.」文案 —— **不是**用空数据糊住。
 *
 * ## 挂载点（壳里要加的那一行）
 *
 * ```kotlin
 * // PagesShellActivity.onCreate(...) 里，setContent 之前：
 * PerfProbe.attach(this)          // 装上帧采集 + 窗口监听；正式包里是空操作
 * // 每次换页时（shellPageId 确定的那一处）：
 * PerfProbe.beginPage(pageId)     // 例如 "b.general" / "h.perfReport"
 * ```
 *
 * 没有这一行也能跑：`PerfReportHost` 首次打开时会自己 [attach] 一次，只是开始计量的时刻
 * 变成「第一次进性能报告页」，前面的页面不会有数据。
 */
object PerfProbe {
    private const val TAG = "[perf-probe]"

    /** 读不到上报刷新率时的兜底（与 Dart `_reportedRefreshRate` 一致）。 */
    private const val FALLBACK_RATE_HZ = 60.0

    /** 记录窗口监听只挂一次（重复 attach 是空操作）。 */
    private var windowAttached = false
    private var lifecycleRegistered = false
    private var samplerStarted = false
    private var sessionRotated = false

    private var appContext: Context? = null
    private var reportedRateHz: Double = FALLBACK_RATE_HZ
    private var costHandler: Handler? = null

    /** 成本读数（-1 = 还没量到，**不是**量到 0；见 `PerfCostReading` 的口径）。 */
    @Volatile
    private var lastCpuMicros: Long = -1L

    @Volatile
    private var lastRssKb: Long = -1L

    /**
     * Choreographer 给的最近一帧 vsync 时刻（微秒）。
     * 只在 `FrameMetrics.INTENDED_VSYNC_TIMESTAMP` / `VSYNC_TIMESTAMP` 都用不了时兜底。
     */
    @Volatile
    private var latestChoreographerVsyncUs: Long = -1L

    /** 上一次落盘时的帧数，用来判断「这 5 秒到底有没有新东西」。 */
    @Volatile
    private var framesAtLastFlush: Long = 0L

    /** 探针是否已安装（未安装时所有接口是空操作）。 */
    val isInstalled: Boolean
        get() = PerfProbeCore.isInstalled

    /**
     * 这个包装的是不是「诊断包 / 性能包」。
     *
     * 注意不能用包名后缀判断：`bench` 变体**故意不加后缀**（与正式版同包名、同一份真实数据，
     * 见 `android/app/build.gradle:196-199`），所以只能靠 buildType / debuggable 位。
     */
    fun isEnabled(context: Context): Boolean {
        if (BuildConfig.BUILD_TYPE == "bench") return true
        if (BuildConfig.DEBUG) return true
        return (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    /**
     * 安装探针并挂上窗口帧监听。重复调用是空操作。
     *
     * @return 本次是否真的装上（正式包返回 false）。
     */
    fun attach(context: Context): Boolean {
        val app = context.applicationContext
        appContext = app
        if (PerfProbeCore.isInstalled) {
            // 已经装过：只补挂窗口（换 Activity 重建时窗口是新的）。
            attachWindowIfPossible(context)
            return false
        }
        if (!isEnabled(app)) {
            Log.i(TAG, "disabled in this build (buildType=${BuildConfig.BUILD_TYPE}) - report page stays 'not installed'")
            return false
        }

        reportedRateHz = resolveRefreshRate(context)
        val installed = PerfProbeCore.install(
            nowUs = { SystemClock.elapsedRealtimeNanos() / 1000L },
            readCost = { PerfCostReading(cpuOrNull(lastCpuMicros), rssOrNull(lastRssKb)) },
            refreshRateHz = { reportedRateHz },
            supportedRefreshRatesHz = resolveSupportedRates(context, reportedRateHz),
            minDwellUs = PerfPageLedger.DEFAULT_MIN_DWELL_US,
            metaProvider = { buildMeta(app) },
        )
        if (!installed) return false

        // 起点先取一次读数，第一段页面才不会一上来就是 null。
        sampleCost()
        rotatePreviousSession(app)
        // 生命周期与成本采样要 Application（`registerActivityLifecycleCallbacks` 在它上面）。
        // 拿不到（单测里的假 Context）就只装账本 + Choreographer，不崩也不假装有数据。
        val application = app as? Application
        if (application != null) {
            registerLifecycle(application)
            startSampler(application)
        } else {
            Log.i(TAG, "application context unavailable - lifecycle/cost sampling skipped")
        }
        attachWindowIfPossible(context)
        Log.i(
            TAG,
            "installed buildType=${BuildConfig.BUILD_TYPE} rateHz=$reportedRateHz " +
                "schema=${PerfProbeCore.SCHEMA_VERSION}",
        )
        return true
    }

    /** 壳在每次换页时告知当前页面 id（Dart 靠 `NavigatorObserver` 自动拿到同一件事）。 */
    fun beginPage(pageId: String) {
        PerfProbeCore.beginPage(pageId)
    }

    /** 记一个启动阶段（探针装之前也能调，按原时刻补记）。 */
    fun markStartup(label: String) {
        PerfProbeCore.markStartup(label)
    }

    fun snapshotJson(): Map<String, Any?> = PerfProbeCore.snapshotJson()

    fun reportText(): String = PerfProbeCore.reportText()

    /** 报表页「Clear ledger」右侧那个帧数。 */
    fun observedFrames(): Long = PerfProbeCore.observedFrames()

    /** 清空账本（新一轮巡检开始前调用）。 */
    fun reset() {
        PerfProbeCore.reset()
        framesAtLastFlush = 0L
        lastCpuMicros = -1L
        lastRssKb = -1L
        sampleCost()
    }

    /** 人读文本（导出用），与剪贴板同一份口径。 */
    fun snapshotJsonText(): String = perfSnapshotJsonText(snapshotJson())

    /**
     * 导出一份带时间戳的快照（人为触发：报表页按钮）。返回 txt 路径；失败返回 null。
     *
     * 与自动落盘的区分：这一份**永远写**（用户点了就要有文件），并顺手清理旧轮次；
     * 自动那份只在有新帧时覆盖同一个滚动文件（[flushIfBusy]）。
     */
    fun exportSnapshot(context: Context): String? {
        if (!PerfProbeCore.isInstalled) return null
        return try {
            val dir = reportDirectory(context)
            val stamp = System.currentTimeMillis()
            val base = PerfSessionFiles.exportBaseName(stamp)
            File(dir, "$base.json").writeText(perfSnapshotJsonText(snapshotJson()), Charsets.UTF_8)
            val txt = File(dir, "$base.txt")
            txt.writeText(reportText(), Charsets.UTF_8)
            pruneExports(dir)
            txt.absolutePath
        } catch (error: Exception) {
            Log.w(TAG, "export failed: ${error.message}")
            null
        }
    }

    // ── 窗口帧采集 ────────────────────────────────────────────────

    private fun attachWindowIfPossible(context: Context) {
        if (windowAttached) return
        val activity = findActivity(context) ?: run {
            // 拿不到 Activity 也能继续：Choreographer 与成本采样不依赖窗口，
            // 只是没有逐帧 build/raster（报表会显示「还没画过帧」而不是假数据）。
            Log.i(TAG, "no Activity in context chain - frame metrics not attached")
            return
        }
        val window = activity.window ?: return
        windowAttached = true
        val handler = Handler(Looper.getMainLooper())
        window.addOnFrameMetricsAvailableListener(
            Window.OnFrameMetricsAvailableListener { _, metrics, _ -> onFrameMetrics(metrics) },
            handler,
        )
        Choreographer.getInstance().postFrameCallback(choreographerCallback)
    }

    /** 逐帧 vsync 时刻（兜底用；`INTENDED_VSYNC_TIMESTAMP` 缺失时它至少让预算能收紧）。 */
    private val choreographerCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            latestChoreographerVsyncUs = frameTimeNanos / 1000L
            if (windowAttached) {
                Choreographer.getInstance().postFrameCallback(this)
            }
        }
    }

    /**
     * 一帧的 FrameMetrics → 账本的一行。
     *
     * 映射见类注释「口径适配」第 1 条：主线程三段相加算 build，渲染/合成三段相加算 raster。
     */
    private fun onFrameMetrics(metrics: FrameMetrics) {
        val totalUs = metricUs(metrics, FrameMetrics.TOTAL_DURATION)
        val buildUs = metricUs(metrics, FrameMetrics.ANIMATION_DURATION) +
            metricUs(metrics, FrameMetrics.LAYOUT_MEASURE_DURATION) +
            metricUs(metrics, FrameMetrics.DRAW_DURATION)
        val rasterUs = metricUs(metrics, FrameMetrics.SYNC_DURATION) +
            metricUs(metrics, FrameMetrics.COMMAND_ISSUE_DURATION) +
            metricUs(metrics, FrameMetrics.SWAP_BUFFERS_DURATION)

        // 子阶段缺失（个别机型 / 某些帧只给 TOTAL）：整段记 build，
        // 宁可高估一栏，也不要让一帧真实耗时被读成 0ms。
        val buildForLedger = if (buildUs <= 0L && rasterUs <= 0L) totalUs else buildUs

        // `INTENDED_VSYNC_TIMESTAMP` = 这一帧「本该」对齐的 vsync 时刻（ns，CLOCK_MONOTONIC），
        // 语义与 Dart `FramePhase.vsyncStart` 一致；缺失时退 `VSYNC_TIMESTAMP`，再退 Choreographer。
        val intendedVsyncUs = metricUs(metrics, FrameMetrics.INTENDED_VSYNC_TIMESTAMP)
        val presentedVsyncUs = metricUs(metrics, FrameMetrics.VSYNC_TIMESTAMP)
        val vsyncUs = when {
            intendedVsyncUs > 0L -> intendedVsyncUs
            presentedVsyncUs > 0L -> presentedVsyncUs
            latestChoreographerVsyncUs > 0L -> latestChoreographerVsyncUs
            else -> null
        }
        PerfProbeCore.ingest(buildUs = buildForLedger, rasterUs = rasterUs, vsyncUs = vsyncUs)
    }

    /**
     * `FrameMetrics.getMetric` 的返回值**一律是纳秒**（时长与时间戳都一样），这里统一换成微秒。
     *
     * 换算是必须的：账本的预算、门槛、vsync 间隔全按微秒算（Dart `FrameTiming` 也是微秒），
     * 少除这一次会让每一帧都「超预算一千倍」。
     */
    private fun metricUs(metrics: FrameMetrics, id: Int): Long {
        val nanos = metrics.getMetric(id)
        // 未定义/不可用会给负值，一律当 0：负数会把 sum 拖成负预算。
        return if (nanos > 0L) nanos / 1000L else 0L
    }

    // ── 生命周期 ──────────────────────────────────────────────────

    private fun registerLifecycle(app: Application) {
        if (lifecycleRegistered) return
        lifecycleRegistered = true
        app.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityStarted(activity: Activity) {
                attachWindowIfPossible(activity)
            }

            override fun onActivityResumed(activity: Activity) {
                // 回前台重新开段：观察者不会为「恢复」而触发，不开就没人记账。
                PerfProbeCore.resumeLastPage()
            }

            override fun onActivityPaused(activity: Activity) {
                // 退后台落一次账：否则后台那一大段 CPU/RSS 增量会全记到最后一页头上。
                PerfProbeCore.sealSegment()
            }

            override fun onActivityStopped(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
    }

    // ── 成本采样与落盘 ────────────────────────────────────────────

    private fun startSampler(app: Application) {
        if (samplerStarted) return
        samplerStarted = true
        val thread = HandlerThread("perf-probe-cost").apply { start() }
        val handler = Handler(thread.looper)
        costHandler = handler

        val sample = object : Runnable {
            override fun run() {
                sampleCost()
                handler.postDelayed(this, PerfProbeCore.COST_SAMPLE_INTERVAL_MS)
            }
        }
        val flush = object : Runnable {
            override fun run() {
                flushIfBusy(app)
                handler.postDelayed(this, PerfProbeCore.FLUSH_INTERVAL_MS)
            }
        }
        handler.post(sample)
        handler.postDelayed(flush, PerfProbeCore.FLUSH_INTERVAL_MS)
    }

    /**
     * 读一次成本。**读不到就保持 -1**，不要填 0 —— 0 会被读成「这一页不费电」。
     *
     * 在后台 HandlerThread 上跑：`/proc` 读取几十微秒，但放在主线程的周期性任务里
     * 仍然是探针自己给自己造卡顿（Dart 侧同样纪律）。
     */
    private fun sampleCost() {
        try {
            lastCpuMicros = Process.getElapsedCpuTime() * 1000L
        } catch (_: Throwable) {
            // 保持上一轮读数
        }
        try {
            val pages = File("/proc/self/statm").readText().trim().split(' ').getOrNull(1)?.toLongOrNull()
            if (pages != null) lastRssKb = pages * PAGE_SIZE_BYTES / 1024L
        } catch (_: Throwable) {
            // SELinux / 非 Android：RSS 留 null
        }
    }

    /**
     * 没新帧就不写盘：空闲时一个字节都不该动。
     *
     * 一个常驻诊断件如果每 5 秒无条件写一次文件，等于给用户手机加了个周期性 I/O 任务
     * —— 测功耗的工具自己费电，是最讽刺的失效方式（Dart `perf_probe.dart:382-401`）。
     */
    private fun flushIfBusy(context: Context) {
        val frames = PerfProbeCore.observedFrames()
        if (frames <= framesAtLastFlush) return
        framesAtLastFlush = frames
        try {
            val dir = reportDirectory(context)
            File(dir, PerfSessionFiles.LIVE_JSON_NAME).writeText(perfSnapshotJsonText(snapshotJson()), Charsets.UTF_8)
            File(dir, PerfSessionFiles.LIVE_TXT_NAME).writeText(reportText(), Charsets.UTF_8)
        } catch (error: Exception) {
            Log.w(TAG, "flush failed: ${error.message}")
        }
    }

    private fun reportDirectory(context: Context): File {
        val dir = File(context.applicationContext.filesDir, PerfSessionFiles.REPORT_DIR_NAME)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    /**
     * 启动时把上一份 live 文件轮转成会话文件，并清理过旧的那些。
     *
     * 为什么要有历史会话：账本在内存里，冷启动会清零；不轮转的话每次启动都覆盖同一份
     * live 文件，一次巡检跨几次重启就只剩最后那次的数据（Dart `:296-311` 踩过）。
     *
     * 刻意用同步 I/O：它是**一次性**动作，发生在首帧之前，几个元数据操作在这个位置
     * 完全看不见；同步还顺手消掉「刚写出新 live 文件又被轮转改名」的竞争。
     */
    private fun rotatePreviousSession(context: Context) {
        if (sessionRotated) return
        sessionRotated = true
        try {
            val dir = reportDirectory(context)
            val live = File(dir, PerfSessionFiles.LIVE_JSON_NAME)
            if (!live.exists()) return
            val stamp = Instant.ofEpochMilli(live.lastModified())
            val base = PerfSessionFiles.sessionFileName(stamp)
            val target = File(dir, base)
            if (target.exists()) {
                // 同一秒内重复启动：不覆盖已有的那份（宁可少一份，不要毁一份）。
                return
            }
            live.renameTo(target)
            val txt = File(dir, PerfSessionFiles.LIVE_TXT_NAME)
            if (txt.exists()) {
                txt.renameTo(File(dir, base.replace(".json", ".txt")))
            }
            val names = dir.listFiles()?.filter { it.isFile }?.map { it.name } ?: emptyList()
            for (name in PerfSessionFiles.sessionsToPrune(names)) {
                runCatching { File(dir, name).delete() }
            }
        } catch (error: Exception) {
            Log.w(TAG, "session rotate failed: ${error.message}")
        }
    }

    private fun pruneExports(dir: File) {
        try {
            val names = dir.listFiles()?.filter { it.isFile }?.map { it.name } ?: return
            for (name in PerfSessionFiles.exportsToPrune(names)) {
                runCatching { File(dir, name).delete() }
            }
        } catch (_: Exception) {
            // 清理失败无所谓：导出本身已经成功。
        }
    }

    // ── 元数据与显示参数 ──────────────────────────────────────────

    private fun buildMeta(context: Context): Map<String, Any?> {
        val packageInfo = runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0)
        }.getOrNull()
        // `versionCode` 在 API 28+ 走 longVersionCode；minSdk 33，直接读。
        val versionCode = packageInfo?.longVersionCode ?: 0L
        val versionName = packageInfo?.versionName ?: "unknown"
        return linkedMapOf(
            "capturedAt" to LocalDateTime.now().format(TIMESTAMP_FORMAT),
            "isReleaseMode" to (BuildConfig.BUILD_TYPE == "release" || BuildConfig.BUILD_TYPE == "bench"),
            "refreshRateHz" to reportedRateHz,
            "platform" to "android",
            // 与 Dart 同义：内核版本串（不是 Android 版本号），只用来确认「两次跑的是同一台」。
            "osKernelVersion" to (System.getProperty("os.version") ?: "unknown"),
            "androidRelease" to Build.VERSION.RELEASE,
            "apiLevel" to Build.VERSION.SDK_INT,
            "cpuCount" to Runtime.getRuntime().availableProcessors(),
            // Android 这一层拿到的 CPU 时间是毫秒分辨率（Dart 是 USER_HZ 刻度）。
            // 写进 meta 是为了让读报表的人知道两版本不是同一把尺子。
            "cpuTimeResolutionMs" to 1,
            "rssSource" to "/proc/self/statm",
            "appVersion" to if (versionName.isEmpty()) "unknown" else "$versionName+$versionCode",
            "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
        )
    }

    private fun resolveRefreshRate(context: Context): Double {
        val activity = findActivity(context)
        val display = activity?.display
        val rate = display?.refreshRate ?: 0f
        return if (rate.isFinite() && rate > 1f) rate.toDouble() else FALLBACK_RATE_HZ
    }

    /**
     * 面板支持的刷新率（Hz）。空表 = 不知道 ⇒ 账本不加过滤。
     *
     * 为什么必须给：真机上采到过 6.2ms（≈161Hz）这种不存在的节奏，而它会把预算从
     * 8.33 收紧到 6.20、掉帧门槛压下 26%，把合格帧成批判成掉帧（Dart `:179-186`）。
     */
    private fun resolveSupportedRates(context: Context, reported: Double): List<Double> {
        val rates = mutableListOf<Double>()
        if (reported.isFinite() && reported > 1.0) rates.add(reported)
        val modes = runCatching { findActivity(context)?.display?.supportedModes }.getOrNull()
        modes?.forEach { mode ->
            val hz = mode.refreshRate.toDouble()
            if (hz > 1.0 && rates.none { kotlin.math.abs(it - hz) < 1.0 }) rates.add(hz)
        }
        // 读不到档位表（极少数机型）时退回常见档位，与 Dart 同一份候选。
        if (rates.size <= 1) {
            for (hz in COMMON_REFRESH_RATES) {
                if (rates.none { kotlin.math.abs(it - hz) < 1.0 }) rates.add(hz)
            }
        }
        return rates
    }

    private fun findActivity(context: Context): Activity? {
        var current: Context? = context
        while (current is ContextWrapper) {
            if (current is Activity) return current
            current = current.baseContext
        }
        return null
    }

    private fun cpuOrNull(value: Long): Long? = if (value < 0L) null else value

    private fun rssOrNull(value: Long): Long? = if (value < 0L) null else value

    private const val PAGE_SIZE_BYTES = 4096L

    private val COMMON_REFRESH_RATES = listOf(60.0, 90.0, 120.0, 144.0)

    private val TIMESTAMP_FORMAT: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS")
}
