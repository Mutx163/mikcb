package com.mutx163.qingyu.pages.timetable.month

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.FrameMetrics
import android.view.Window
import com.mutx163.qingyu.BuildConfig
import java.util.Locale
import kotlin.math.abs

/**
 * 月视图**纵向滑动的逐帧观测台**（诊断用；正式包里是空操作）。
 *
 * 为什么要有它：用户报「上下滑动不丝滑」，但这句话有三条完全不同的成因，靠猜会改错地方：
 *
 * | 观感 | 真因 | 本探针里的证据 |
 * |---|---|---|
 * | 跟手但一顿一顿 | 主线程每帧超预算（重组 / 测量 / 录制绘制命令） | `build` 的 med/p90/max 贴着 budget |
 * | 手指在动、画面明显滞后 | 渲染线程来不及（大图层、阴影、离屏合成） | `raster`（sync/issue/swap）高，`build` 正常 |
 * | 整帧迟迟不开始 | 上一帧把 UI 线程占满，这一帧排队才轮上 | `delay`（vsync → 真正开始干活）高 |
 * | 起手 / 松手那一下顿 | 输入分发或吸附动画本身掉帧 | `input` 高，或 `TAIL` 段帧数不足 |
 *
 * ## 装在哪、什么时候装
 *
 * [attach] 由 `MonthViewPage` 组合时调一次（换窗口会重挂）。只在
 * `BuildConfig.DEBUG` 或 `bench` 变体里生效 —— 与 `platform/PerfProbe` 同一口径：
 * 正式包不采、也不写一行日志。
 *
 * ## 一次手势输出什么（tag `MonthScroll`）
 *
 * ```text
 * g7 START kind=grid frames=1204
 * g7 END dur=612ms events=68 gap(ms) med=8.3 p90=16.6 max=33.1 dy=-412.0 peak=24.0 list=0/0.0 progress 1.000→0.174 velocity=-820
 * g7 DRAG FRAMES n=37 budget=16.7ms jank=2 gap=1 maxgap=33.3 | build med=3.1 p90=7.8 max=12.4 | raster … | input … | delay … | total …
 * g7 DRAG PHASES anim med=0.1 p90=0.4 max=0.6 | meas med=6.0 … | draw med=2.0 …
 * g7 DRAG SLOW #12 total=24.1 build=19.9 (anim=0.2 meas=14.1 draw=5.6) raster=4.2 (sync=1.0 issue=2.1 swap=1.1) input=2.2
 * g7 DRAG COUNTS body=0 gridCompose=0 gridDraw=37 panel=0 overviewSlice=37 cardMeasure=37 windowMeasure=111
 * g7 TAIL FRAMES …（松手后 420ms 内：吸附动画那一段）
 * ```
 *
 * 读法：
 * * `build` = 主线程三段相加（动画回调 + 测量布局 + 录制绘制命令），对应「我们自己的代码」；
 * * `raster` = 渲染/合成三段相加（GPU 同步 + 下发命令 + 交换缓冲），对应「图层与 GPU」；
 * * `jank` = `total` 超过 1.5×budget 的帧数；`gap` = vsync 间隔超过 1.5×budget 的次数
 *   （gap > jank 说明有整帧没画，通常是掉进了别的窗口或掉帧没被 FrameMetrics 记到）；
 * * `COUNTS` 是**本次手势内**的增量：`body`/`panel` 应为 0（设计上拖拽只重测不重组），
 *   `gridDraw` 应≈帧数，`overviewSlice` 若≈帧数就说明「概览卡按高度每帧重组」，
 *   `cardMeasure`/`windowMeasure` ≈ 帧数 × 页数说明高度每帧重测整棵子树。
 *
 * ## 它不是性能基线
 *
 * 探针自己挂了一个 `OnFrameMetricsAvailableListener`，每帧有一点固定开销（合计量级
 * 0.1~0.3ms），绝对值会被略微抬高。看**分布与阶段占比**，不要拿它跟别的包比绝对数。
 * 要报数就用 bench 包 + `PerfProbe` 的报表页。
 */
internal object MonthScrollProbe {

    /** logcat 过滤用：`adb logcat -s MonthScroll`。 */
    private const val TAG = "MonthScroll"

    /** 帧样本环形缓冲：1024 帧 ≈ 60Hz 下 17 秒，够覆盖一次手势 + 吸附。 */
    private const val RING_SIZE = 1024

    /** 拇指滑一次大概 300~800ms；超过这个时长的「手势」基本是探针没收尾。 */
    private const val MAX_DRAG_MS = 4_000.0

    /** 松手后继续收帧的时长（吸附动画 70~220ms，留余量）。 */
    private const val TAIL_WINDOW_MS = 420L

    /** 等最后 1~2 帧的 FrameMetrics 回调到齐。 */
    private const val DRAG_SETTLE_WAIT_MS = 60L

    /** 一次手势最多打几条慢帧明细。 */
    private const val MAX_SLOW_LINES = 6

    /** 只有 dev / bench 包采数；正式包一律空操作（与 `PerfProbe.isEnabled` 同口径）。 */
    val enabled: Boolean = BuildConfig.DEBUG || BuildConfig.BUILD_TYPE == "bench"

    // ── 计数器（本次手势内的增量） ────────────────────────────────

    /** 整个月视图主体（`MonthViewBody`）组合了几次。 */
    const val C_BODY = 0

    /** 网格（`MonthGrid`，含 pager 预组合的相邻两页）组合了几次。 */
    const val C_GRID_COMPOSE = 1

    /** 网格绘制了几次（pager 三页合计）。 */
    const val C_GRID_DRAW = 2

    /** 面板内容（`MonthPanelContent`）组合了几次。 */
    const val C_PANEL_COMPOSE = 3

    /** 「本月有安排的日子」那段 `BoxWithConstraints` 子组合重算了几次（按高度反算行数）。 */
    const val C_OVERVIEW_SLICE = 4

    /** 日历卡高度（`heightDeferred`）测了几次。 */
    const val C_CARD_MEASURE = 5

    /** 网格窗口高度（页面层 + 每一页各一处 `heightDeferred`）测了几次。 */
    const val C_GRID_WINDOW_MEASURE = 6

    private const val C_COUNT = 7

    private val counters = LongArray(C_COUNT)

    private val mainHandler = Handler(Looper.getMainLooper())

    // ── 帧样本 ───────────────────────────────────────────────────

    private class FrameRow {
        var seq = 0L

        /** 本帧在「这段窗口」里的序号（只在拼慢帧明细时写入，报给人看）。 */
        var indexInWindow = 0L
        var vsyncUs = 0L
        var totalUs = 0L

        /** vsync 到「主线程真正开始干活」之间那段（UI 线程被上一帧占着的量）。 */
        var delayUs = 0L
        var buildUs = 0L
        var rasterUs = 0L
        var animUs = 0L
        var measureUs = 0L
        var drawUs = 0L
        var inputUs = 0L
        var syncUs = 0L
        var issueUs = 0L
        var swapUs = 0L
    }

    private val ring = Array(RING_SIZE) { FrameRow() }

    /** 已记录帧数（即下一个帧的 seq）。只在主线程读写。 */
    private var frames = 0L

    private var attachedWindow: Window? = null
    private var listener: Window.OnFrameMetricsAvailableListener? = null

    /** 一帧的预算（微秒），来自窗口所在 display 的刷新率。 */
    private var budgetUs = 16_667L

    // ── 当前手势 ─────────────────────────────────────────────────

    private class Drag(
        val id: Int,
        val kind: String,
        val startFrame: Long,
        val startCounters: LongArray,
        val startedAtNs: Long,
    )

    private var active: Drag? = null
    private var dragId = 0

    private var lastEventNs = 0L
    private val eventGaps = ArrayList<Double>(128)
    private var dyTotal = 0.0
    private var dyPeak = 0.0
    private var listEvents = 0
    private var listDy = 0.0

    /**
     * 挂上窗口帧监听。同一个窗口重复调用是空操作；换窗口（Activity 重建）会先摘再挂。
     *
     * @return 本次是否真的挂上（非诊断包 / 拿不到 Activity 窗口都返回 false）。
     */
    fun attach(context: Context): Boolean {
        if (!enabled) return false
        val activity = context.findActivity() ?: return false
        val window = activity.window ?: return false
        if (window === attachedWindow) return true
        attachedWindow?.let { old ->
            listener?.let { old.removeOnFrameMetricsAvailableListener(it) }
        }
        val fresh = Window.OnFrameMetricsAvailableListener { _, metrics, _ -> onFrame(metrics) }
        window.addOnFrameMetricsAvailableListener(fresh, mainHandler)
        attachedWindow = window
        listener = fresh
        val hz = activity.display?.refreshRate?.takeIf { it.isFinite() && it > 1f } ?: 60f
        budgetUs = (1_000_000.0 / hz).toLong()
        Log.i(
            TAG,
            "probe attached buildType=${BuildConfig.BUILD_TYPE} rateHz=$hz " +
                "budgetMs=${fmt(budgetUs / 1000.0)}",
        )
        return true
    }

    /** 计数器 +1（组合 / 绘制 / 测量各调一处；非诊断包直接返回）。 */
    fun bump(id: Int) {
        if (!enabled) return
        counters[id]++
    }

    /**
     * 开始一次纵向手势。
     *
     * 三个入口都调它，`kind` 用来分辨症状落在哪条路径上：
     * `grid` = 日历网格上直接上下拖、`handle` = 卡底拉杆、
     * `panel` = 面板上拖（先收放日历）、`list` = 议程列表自己滚（日历已收到底）。
     */
    fun beginDrag(kind: String) {
        if (!enabled) return
        // 上一条没收尾（手指被系统抢走 / 回调没回来）：先结束它，别把两段混成一段。
        finishDrag(velocityDp = 0.0, startProgress = Float.NaN, endProgress = Float.NaN)
        dragId++
        eventGaps.clear()
        dyTotal = 0.0
        dyPeak = 0.0
        listEvents = 0
        listDy = 0.0
        lastEventNs = System.nanoTime()
        active = Drag(dragId, kind, frames, counters.copyOf(), lastEventNs)
        Log.i(TAG, "g$dragId START kind=$kind frame=$frames")
    }

    /** 一次指针移动的位移（dp，向上为负）。只做累加，不打日志（拖拽中不允许有 I/O）。 */
    fun onDragEvent(dyDp: Float) {
        if (!enabled) return
        if (active == null) return
        val now = System.nanoTime()
        eventGaps.add((now - lastEventNs) / 1_000_000.0)
        lastEventNs = now
        dyTotal += dyDp
        dyPeak = maxOf(dyPeak, abs(dyDp.toDouble()))
    }

    /** 议程列表吃掉的位移（`dispatchRawDelta` 真正滚动的那部分）。 */
    fun onListScroll(dyDp: Float) {
        if (!enabled) return
        if (active == null) return
        listEvents++
        listDy += dyDp
    }

    /**
     * 松手。
     *
     * @param velocityDp 抬手纵向速度（dp/s），吸附判据的输入。
     * @param startProgress 本次手势起点展开进度（1 = 展开）；`NaN` = 这条路径不涉及。
     * @param endProgress 松手瞬间的展开进度。
     */
    fun endDrag(velocityDp: Double, startProgress: Float, endProgress: Float) {
        if (!enabled) return
        finishDrag(velocityDp, startProgress, endProgress)
    }

    private fun finishDrag(velocityDp: Double, startProgress: Float, endProgress: Float) {
        val drag = active ?: return
        active = null
        val nowNs = System.nanoTime()
        val durMs = (nowNs - drag.startedAtNs) / 1_000_000.0
        val endFrame = frames

        val progressText = if (startProgress.isNaN() || endProgress.isNaN()) {
            "progress=-"
        } else {
            "progress ${fmt3(startProgress)}→${fmt3(endProgress)}"
        }
        Log.i(
            TAG,
            "g${drag.id} END dur=${fmt(durMs)}ms events=${eventGaps.size + 1} " +
                "gap(ms) ${describe(eventGaps)} dy=${fmt(dyTotal)} peak=${fmt(dyPeak)} " +
                "list=$listEvents/${fmt(listDy)} $progressText velocity=${fmt(velocityDp)}",
        )

        // 拖拽段：等 60ms 让最后几帧的回调到齐，再落一次账。
        mainHandler.postDelayed(
            {
                dumpWindow(drag, drag.startFrame, frames, "DRAG", drag.startCounters)
            },
            DRAG_SETTLE_WAIT_MS,
        )
        // 吸附段：松手后的动画（70~220ms）。期间又起了新手势就不打，免得两段糊在一起。
        val generation = dragId
        mainHandler.postDelayed(
            {
                if (generation == dragId && active == null) {
                    dumpWindow(drag, endFrame, frames, "TAIL", null)
                }
            },
            TAIL_WINDOW_MS,
        )

        if (durMs > MAX_DRAG_MS) {
            Log.i(TAG, "g${drag.id} WARN 手势时长 ${fmt(durMs)}ms 超过 ${fmt(MAX_DRAG_MS)}ms，检查是不是回调没回来")
        }
    }

    // ── 帧采集 ───────────────────────────────────────────────────

    private fun onFrame(metrics: FrameMetrics) {
        val intended = metricUs(metrics, FrameMetrics.INTENDED_VSYNC_TIMESTAMP)
        val presented = metricUs(metrics, FrameMetrics.VSYNC_TIMESTAMP)
        val anim = metricUs(metrics, FrameMetrics.ANIMATION_DURATION)
        val measure = metricUs(metrics, FrameMetrics.LAYOUT_MEASURE_DURATION)
        val draw = metricUs(metrics, FrameMetrics.DRAW_DURATION)
        val sync = metricUs(metrics, FrameMetrics.SYNC_DURATION)
        val issue = metricUs(metrics, FrameMetrics.COMMAND_ISSUE_DURATION)
        val swap = metricUs(metrics, FrameMetrics.SWAP_BUFFERS_DURATION)

        val row = ring[(frames % RING_SIZE).toInt()]
        row.seq = frames
        row.vsyncUs = if (intended > 0L) intended else presented
        row.animUs = anim
        row.measureUs = measure
        row.drawUs = draw
        row.inputUs = metricUs(metrics, FrameMetrics.INPUT_HANDLING_DURATION)
        row.delayUs = metricUs(metrics, FrameMetrics.UNKNOWN_DELAY_DURATION)
        row.buildUs = anim + measure + draw
        row.syncUs = sync
        row.issueUs = issue
        row.swapUs = swap
        row.rasterUs = sync + issue + swap
        val total = metricUs(metrics, FrameMetrics.TOTAL_DURATION)
        // 个别机型 / 某些帧只给 TOTAL：整段记 build，宁可高估也不要读成「0ms 全绿」。
        row.totalUs = if (total > 0L) total else row.buildUs + row.rasterUs
        frames++
    }

    private fun metricUs(metrics: FrameMetrics, id: Int): Long {
        val nanos = metrics.getMetric(id)
        return if (nanos > 0L) nanos / 1000L else 0L
    }

    // ── 落账 ─────────────────────────────────────────────────────

    /**
     * 打出 `[from, to)` 这段帧的分布。
     *
     * @param baseline 非空时同时打出与它的计数器增量（只有拖拽段需要）。
     */
    private fun dumpWindow(drag: Drag, from: Long, to: Long, segment: String, baseline: LongArray?) {
        val build = ArrayList<Double>()
        val raster = ArrayList<Double>()
        val total = ArrayList<Double>()
        val anim = ArrayList<Double>()
        val measure = ArrayList<Double>()
        val drawSeries = ArrayList<Double>()
        val input = ArrayList<Double>()
        val delay = ArrayList<Double>()
        val intervals = ArrayList<Double>()
        val slow = ArrayList<FrameRow>()

        var jank = 0
        var gaps = 0
        var maxGapMs = 0.0
        var previousVsync = 0L
        val thresholdUs = (budgetUs * 1.5).toLong()

        var index = 0L
        var seq = from
        while (seq < to) {
            if (seq >= frames - RING_SIZE) {
                val row = ring[(seq % RING_SIZE).toInt()]
                if (row.seq == seq) {
                    build.add(row.buildUs / 1000.0)
                    raster.add(row.rasterUs / 1000.0)
                    total.add(row.totalUs / 1000.0)
                    anim.add(row.animUs / 1000.0)
                    measure.add(row.measureUs / 1000.0)
                    drawSeries.add(row.drawUs / 1000.0)
                    input.add(row.inputUs / 1000.0)
                    delay.add(row.delayUs / 1000.0)
                    if (row.totalUs > thresholdUs) jank++

                    val vsync = row.vsyncUs
                    if (previousVsync > 0L && vsync > previousVsync) {
                        val gapMs = (vsync - previousVsync) / 1000.0
                        intervals.add(gapMs)
                        if (gapMs > budgetUs * 1.5 / 1000.0) gaps++
                        if (gapMs > maxGapMs) maxGapMs = gapMs
                    }
                    if (vsync > 0L) previousVsync = vsync

                    // 只留最慢的几帧：插进去再截断，避免每帧都分配对象。
                    if (slow.size < MAX_SLOW_LINES || row.totalUs > slow.last().totalUs) {
                        row.indexInWindow = index
                        slow.add(row)
                        slow.sortByDescending { it.totalUs }
                        if (slow.size > MAX_SLOW_LINES) slow.removeAt(slow.size - 1)
                    }
                }
            }
            seq++
            index++
        }

        if (total.isEmpty()) {
            Log.i(TAG, "g${drag.id} $segment FRAMES n=0（这段窗口没画帧，或探针没挂上窗口）")
            return
        }

        // 实际帧节奏：面板是 120Hz 时，稳定 16.7ms 就是「稳 60fps」，不是掉帧；
        // 16.7 / 33.3 混在一起才是一顿一顿。预算按面板算，节奏按实测算，两个一起看。
        val cadence = if (intervals.size >= 2) {
            val sorted = intervals.sorted()
            val median = sorted[(sorted.size - 1) / 2]
            val p90 = sorted[((sorted.size - 1) * 0.9).toInt().coerceIn(0, sorted.size - 1)]
            "fps ${fmt(if (median > 0.0) 1000.0 / median else 0.0)} " +
                "(interval med=${fmt(median)} p90=${fmt(p90)} max=${fmt(sorted.last())})"
        } else {
            "fps - (样本不足)"
        }

        Log.i(
            TAG,
            "g${drag.id} $segment FRAMES n=${total.size} budget=${fmt(budgetUs / 1000.0)}ms " +
                "jank=$jank gap=$gaps maxgap=${fmt(maxGapMs)} | $cadence | " +
                "build ${describe(build)} | raster ${describe(raster)} | " +
                "input ${describe(input)} | delay ${describe(delay)} | total ${describe(total)}",
        )
        Log.i(
            TAG,
            "g${drag.id} $segment PHASES anim ${describe(anim)} | " +
                "meas ${describe(measure)} | draw ${describe(drawSeries)}",
        )

        for (row in slow) {
            Log.i(
                TAG,
                "g${drag.id} $segment SLOW #${row.indexInWindow} total=${fmt(row.totalUs / 1000.0)} " +
                    "delay=${fmt(row.delayUs / 1000.0)} " +
                    "build=${fmt(row.buildUs / 1000.0)} " +
                    "(anim=${fmt(row.animUs / 1000.0)} meas=${fmt(row.measureUs / 1000.0)} " +
                    "draw=${fmt(row.drawUs / 1000.0)}) " +
                    "raster=${fmt(row.rasterUs / 1000.0)} " +
                    "(sync=${fmt(row.syncUs / 1000.0)} issue=${fmt(row.issueUs / 1000.0)} " +
                    "swap=${fmt(row.swapUs / 1000.0)}) input=${fmt(row.inputUs / 1000.0)}",
            )
        }

        if (baseline != null) {
            Log.i(
                TAG,
                "g${drag.id} $segment COUNTS body=${delta(baseline, C_BODY)} " +
                    "gridCompose=${delta(baseline, C_GRID_COMPOSE)} " +
                    "gridDraw=${delta(baseline, C_GRID_DRAW)} " +
                    "panel=${delta(baseline, C_PANEL_COMPOSE)} " +
                    "overviewSlice=${delta(baseline, C_OVERVIEW_SLICE)} " +
                    "cardMeasure=${delta(baseline, C_CARD_MEASURE)} " +
                    "windowMeasure=${delta(baseline, C_GRID_WINDOW_MEASURE)}",
            )
        }
    }

    private fun delta(baseline: LongArray, id: Int): Long = counters[id] - baseline[id]

    /** `med=… p90=… max=…`（毫秒）。 */
    private fun describe(values: List<Double>): String {
        if (values.isEmpty()) return "med=- p90=- max=-"
        val sorted = values.sorted()
        val median = sorted[(sorted.size - 1) / 2]
        val p90 = sorted[((sorted.size - 1) * 0.9).toInt().coerceIn(0, sorted.size - 1)]
        return "med=${fmt(median)} p90=${fmt(p90)} max=${fmt(sorted.last())}"
    }

    private fun fmt(value: Double): String = String.format(Locale.US, "%.1f", value)

    private fun fmt3(value: Float): String = String.format(Locale.US, "%.3f", value)

    private fun Context.findActivity(): Activity? {
        var current: Context? = this
        while (current is ContextWrapper) {
            if (current is Activity) return current
            current = current.baseContext
        }
        return null
    }
}
