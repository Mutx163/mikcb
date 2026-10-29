package com.mutx163.qingyu.pages.diagnostics

/**
 * 启动分段记录器（源：`lib/utils/perf_startup.dart`，135 行）。
 *
 * 与「页面排行」的分工：页面账本回答「哪一页慢」，本文件回答「启动慢在哪一段」。
 * `mainEnter` / `bindingReady` 这类阶段发生在探针安装之前，所以 [PerfProbeCore]
 * 会把它们先缓冲起来、安装时按**原始时间戳**补记（见 `perf_probe.dart:150-183`）。
 *
 * 两栏耗时的分工（别只看一个数）：
 * * `stepUs`：距上一个阶段多久 —— 定位「哪一段在吃时间」。
 * * `totalUs`：距起点多久 —— 看「到这一刻为止总共花了多少」。
 *
 * 纪律：只记不报，不持有计时器（否则组件测试会被 pending timer 打挂）。
 */
data class PerfStartupPhase(
    /** 阶段名（`mainEnter` / `runApp` / `firstFrame` / `homeRevealed` …）。 */
    val label: String,
    /** 该阶段的绝对时间戳（与 [PerfStartupRecorder.mark] 传入的同源时钟）。 */
    val atUs: Long,
    /** 距上一个阶段多久（微秒）。第一段为 0。 */
    val stepUs: Long,
    /** 距第一个阶段多久（微秒）。第一段为 0。 */
    val totalUs: Long,
) {
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "phase" to label,
        "stepMs" to perfMs(stepUs),
        "totalMs" to perfMs(totalUs),
    )

    fun formatLine(): String =
        "phase=$label stepMs=${perfMs(stepUs)} " +
            "totalMs=${perfMs(totalUs)}"
}

/** 启动阶段记录器（Dart `PerfStartup`）。 */
class PerfStartupRecorder {
    private val phases = mutableListOf<PerfStartupPhase>()
    private val indexByLabel = HashMap<String, Int>()
    private var baseUs: Long? = null
    private var lastUs: Long? = null
    private var accumulatedUs: Long = 0L

    /**
     * 记一个阶段。[atUs] 是调用方时钟上的绝对时刻（微秒，单调）。
     *
     * 同名阶段**只记第一次**：回前台、深链唤起都会重跑部分启动路径，
     * 第二次落进来会把总时长改成一个「不像启动」的数。
     */
    fun mark(label: String, atUs: Long) {
        if (indexByLabel.containsKey(label)) return
        val first = baseUs
        if (first == null) {
            // 第一个 mark 锚定基准：耗时都是 0。
            baseUs = atUs
            lastUs = atUs
            indexByLabel[label] = phases.size
            phases.add(PerfStartupPhase(label = label, atUs = atUs, stepUs = 0L, totalUs = 0L))
            return
        }
        // 时钟被回拨时（单调时钟不会，但注入的假时钟可能）间隔夹到 0：
        // 负数会把总账算短，比「看不出这段花了多久」更糟。
        val stepUs = atUs - (lastUs ?: first)
        val clampedStep = if (stepUs > 0L) stepUs else 0L
        indexByLabel[label] = phases.size
        phases.add(
            PerfStartupPhase(
                label = label,
                atUs = atUs,
                stepUs = clampedStep,
                totalUs = accumulatedUs + clampedStep,
            ),
        )
        lastUs = atUs
        accumulatedUs += clampedStep
    }

    /** 已记录阶段（按记录顺序）。 */
    val phaseList: List<PerfStartupPhase>
        get() = phases.toList()

    /** 最后一段的总耗时；没记录过为 0。 */
    val totalUs: Long
        get() = if (phases.isEmpty()) 0L else accumulatedUs

    /** 某阶段距起点的耗时；没记过这个 label 给 null（不猜）。 */
    fun elapsedUs(label: String): Long? = indexByLabel[label]?.let { phases[it].totalUs }

    /** 某阶段距上一阶段的耗时；没记过给 null。 */
    fun sincePreviousUs(label: String): Long? = indexByLabel[label]?.let { phases[it].stepUs }

    fun toJson(): List<Map<String, Any?>> = phases.map { it.toJson() }

    /** 文本报告（落盘与导出共用一份口径，差分脚本 grep `phase=`）。 */
    fun formatTextReport(): String {
        if (phases.isEmpty()) return "[perf-startup] no startup phase recorded\n"
        val buffer = StringBuilder()
        for (phase in phases) {
            buffer.append("[perf-startup] ").append(phase.formatLine()).append('\n')
        }
        return buffer.toString()
    }

    fun reset() {
        phases.clear()
        indexByLabel.clear()
        baseUs = null
        lastUs = null
        accumulatedUs = 0L
    }
}
