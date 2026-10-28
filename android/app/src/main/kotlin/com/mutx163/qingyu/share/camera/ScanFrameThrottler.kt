package com.mutx163.qingyu.share.camera

/**
 * 帧丢弃策略。
 */
enum class FrameDropPolicy {
    /** 当上一帧仍在解码分析中时，立即丢弃新到达的预览帧（保持低时延，绝不排队积压）。 */
    DROP_IF_BUSY,

    /** 严格按时间窗口节流，无论是否忙碌。 */
    THROTTLE_ONLY,
}

/**
 * 帧分析性能与调度指标快照。
 */
data class FrameThrottleStats(
    val totalFramesReceived: Long,
    val framesProcessed: Long,
    val framesDroppedBusy: Long,
    val framesDroppedInterval: Long,
    val totalProcessingTimeMs: Long,
    val maxProcessingTimeMs: Long,
    val lastProcessingDurationMs: Long,
) {
    /** 丢帧率（0.0 ~ 1.0）。 */
    val dropRate: Double
        get() = if (totalFramesReceived > 0) {
            (totalFramesReceived - framesProcessed).toDouble() / totalFramesReceived
        } else {
            0.0
        }

    /** 平均每帧处理耗时（毫秒）。 */
    val averageProcessingTimeMs: Double
        get() = if (framesProcessed > 0) {
            totalProcessingTimeMs.toDouble() / framesProcessed
        } else {
            0.0
        }
}

/**
 * 相机扫码帧预算与节流控制器。
 *
 * ## 为什么需要帧预算与节流
 *
 * 手机相机传感器以 30fps 或 60fps 输出原始图像（每 16~33ms 一帧），
 * 而条形码/二维码软解（如 ZXing 或 MLKit）在 CPU 上单帧可能消耗 15~60ms。
 * 如果不对帧率进行节流与丢帧管控：
 * 1. 帧队列积压：算法处理的是数秒前的历史旧帧，用户明明对准了却反应迟钝；
 * 2. 持续 CPU 满载：导致整机发热、掉电加快，甚至触发系统降频；
 * 3. 阻塞 Compose 主线程与渲染管线。
 *
 * 本控制器提供：
 * - 最小解帧间隔控制（默认 100ms，即上限 10fps，对动态码传输完全足够且功耗降低 70%+）；
 * - 忙碌丢帧（DROP_IF_BUSY）：上一帧没解完时，新帧直接丢弃；
 * - 详尽的帧指标统计（接收数、处理数、丢弃数、耗时分布）。
 */
class ScanFrameThrottler(
    /** 两帧之间的最小时间间隔（毫秒）。默认 100ms（约 10fps）。 */
    val minIntervalMs: Long = 100L,
    /** 单帧处理预算警示阈值（毫秒）。超出可用于上报性能诊断。 */
    val frameBudgetMs: Long = 50L,
    /** 丢帧策略。默认忙碌即丢。 */
    val dropPolicy: FrameDropPolicy = FrameDropPolicy.DROP_IF_BUSY,
    /** 时钟源。可在测试中注入虚拟时钟。 */
    val clock: ScanClock = SystemScanClock,
) {
    var totalFramesReceived: Long = 0L
        private set
    var framesProcessed: Long = 0L
        private set
    var framesDroppedBusy: Long = 0L
        private set
    var framesDroppedInterval: Long = 0L
        private set
    var totalProcessingTimeMs: Long = 0L
        private set
    var maxProcessingTimeMs: Long = 0L
        private set
    var lastProcessingDurationMs: Long = 0L
        private set

    /** 当前是否有正在执行中的帧分析任务。 */
    var isBusy: Boolean = false
        private set

    private var lastProcessStartTimeMs: Long = 0L
    private var currentFrameStartTimeMs: Long = 0L

    /**
     * 判断新到达的帧是否应当被处理。
     *
     * 满足以下条件时返回 true：
     * 1. 距离上一帧开始处理的时间 >= [minIntervalMs]；
     * 2. 如果策略是 [FrameDropPolicy.DROP_IF_BUSY]，则当前必须处于非忙碌状态。
     */
    fun shouldProcess(timestampMs: Long = clock.currentTimeMillis()): Boolean {
        totalFramesReceived++

        if (dropPolicy == FrameDropPolicy.DROP_IF_BUSY && isBusy) {
            framesDroppedBusy++
            return false
        }

        val elapsedSinceLast = timestampMs - lastProcessStartTimeMs
        if (lastProcessStartTimeMs > 0L && elapsedSinceLast < minIntervalMs) {
            framesDroppedInterval++
            return false
        }

        return true
    }

    /**
     * 标记开始处理一帧。
     *
     * @return 如果成功获取执行资格返回 true；若被拦截则返回 false。
     */
    fun beginFrame(timestampMs: Long = clock.currentTimeMillis()): Boolean {
        if (!shouldProcess(timestampMs)) {
            return false
        }
        isBusy = true
        lastProcessStartTimeMs = timestampMs
        currentFrameStartTimeMs = timestampMs
        return true
    }

    /**
     * 标记当前帧处理完成，结算耗时并释放忙碌标记。
     */
    fun endFrame(timestampMs: Long = clock.currentTimeMillis()) {
        if (!isBusy) return
        val duration = (timestampMs - currentFrameStartTimeMs).coerceAtLeast(0L)
        lastProcessingDurationMs = duration
        totalProcessingTimeMs += duration
        if (duration > maxProcessingTimeMs) {
            maxProcessingTimeMs = duration
        }
        framesProcessed++
        isBusy = false
    }

    /**
     * 包装一个执行块：如果满足帧预算则执行并返回结果，否则返回 null。
     */
    inline fun <T> runBudgeted(
        timestampMs: Long = clock.currentTimeMillis(),
        block: () -> T,
    ): T? {
        if (!beginFrame(timestampMs)) {
            return null
        }
        return try {
            block()
        } finally {
            endFrame(clock.currentTimeMillis())
        }
    }

    /** 获取统计快照。 */
    fun snapshot(): FrameThrottleStats = FrameThrottleStats(
        totalFramesReceived = totalFramesReceived,
        framesProcessed = framesProcessed,
        framesDroppedBusy = framesDroppedBusy,
        framesDroppedInterval = framesDroppedInterval,
        totalProcessingTimeMs = totalProcessingTimeMs,
        maxProcessingTimeMs = maxProcessingTimeMs,
        lastProcessingDurationMs = lastProcessingDurationMs,
    )

    /** 重置计数器与状态。 */
    fun reset() {
        totalFramesReceived = 0L
        framesProcessed = 0L
        framesDroppedBusy = 0L
        framesDroppedInterval = 0L
        totalProcessingTimeMs = 0L
        maxProcessingTimeMs = 0L
        lastProcessingDurationMs = 0L
        isBusy = false
        lastProcessStartTimeMs = 0L
        currentFrameStartTimeMs = 0L
    }
}
