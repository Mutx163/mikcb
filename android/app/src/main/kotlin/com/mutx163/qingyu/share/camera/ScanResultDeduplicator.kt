package com.mutx163.qingyu.share.camera

/**
 * 扫码去重与防抖判定结果。
 */
enum class DedupDecision {
    /** 判定通过：作为有效的新扫码结果分发给业务层。 */
    ACCEPT,

    /** 抑制：在去重时间窗口内重复扫描到完全相同的内容。 */
    DUPLICATE_IGNORED,

    /** 抑制：扫码频率过高，触发全局防抖保护窗口。 */
    DEBOUNCE_DROPPED,

    /** 等待确认：启用了连续命中确认模式，当前连续识别帧数尚未达到目标阈值。 */
    AWAITING_CONFIRMATION,
}

/**
 * 扫码去重与防抖统计快照。
 */
data class DedupStats(
    val totalEvaluated: Long,
    val totalAccepted: Long,
    val totalDuplicatesSuppressed: Long,
    val totalDebounceSuppressed: Long,
    val totalAwaitingConfirmation: Long,
    val lastAcceptedValue: String?,
    val lastAcceptedTimestampMs: Long,
)

/**
 * 条码扫描结果去重与防抖控制器。
 *
 * ## 为什么需要扫码结果去重与防抖
 *
 * 1. 相同内容重复命中抑制：
 *    在视频流连续扫描时，用户将镜头对准同一个静态二维码，相机每秒会识别出 5~10 次相同的字符串。
 *    对于单次触发型业务（如加入课表、配对），必须进行时间窗口（如 1500ms）内的静默抑制，
 *    避免瞬间弹出多个提示窗或发起多次网络请求。
 * 2. 跨条码防抖保护：
 *    当视野内同时存在两个条码或条码在边缘晃动时，可能在 30ms 内连续交替切码，
 *    通过全局防抖间隔（如 250ms）防止界面剧烈抖动。
 * 3. 连续帧命中确认（可选）：
 *    在远距离或光照条件不佳的环境下，可能偶尔有一帧因光学畸变解析出错误/不完整的脏数据，
 *    通过配置 `consecutiveHitsRequired`（例如要求连续 2 帧识别出同一内容），
 *    可彻底过滤掉单帧脏数据。
 */
class ScanResultDeduplicator(
    /** 同一内容重复扫码的去重冷却窗口（毫秒）。默认 1500ms。在此窗口内重复命中同一内容直接忽略。 */
    val dedupWindowMs: Long = 1500L,
    /** 任意两次成功分发之间的最小防抖间隔（毫秒）。默认 250ms。 */
    val minIntervalBetweenScansMs: Long = 250L,
    /** 确认一个条码有效所需的连续命中帧数。默认 1（即只要命中一次立刻生效）。 */
    val consecutiveHitsRequired: Int = 1,
    /** 时钟源。可在测试中注入虚拟时钟。 */
    val clock: ScanClock = SystemScanClock,
) {
    init {
        require(dedupWindowMs >= 0) { "dedupWindowMs 必须 >= 0" }
        require(minIntervalBetweenScansMs >= 0) { "minIntervalBetweenScansMs 必须 >= 0" }
        require(consecutiveHitsRequired >= 1) { "consecutiveHitsRequired 必须 >= 1" }
    }

    var totalEvaluated: Long = 0L
        private set
    var totalAccepted: Long = 0L
        private set
    var totalDuplicatesSuppressed: Long = 0L
        private set
    var totalDebounceSuppressed: Long = 0L
        private set
    var totalAwaitingConfirmation: Long = 0L
        private set

    var lastAcceptedValue: String? = null
        private set
    var lastAcceptedTimestampMs: Long = 0L
        private set

    private var candidateValue: String? = null
    private var candidateConsecutiveCount: Int = 0

    /**
     * 评估一个条码扫描结果。
     *
     * @param rawValue 条码内容文本
     * @param timestampMs 扫描时间戳（毫秒）
     * @return 过滤判定结果 [DedupDecision]
     */
    fun evaluate(rawValue: String, timestampMs: Long = clock.currentTimeMillis()): DedupDecision {
        totalEvaluated++

        // 1. 相同内容去重检查：如果和上次接受的内容相同，且在去重冷却窗口期内，直接忽略
        if (rawValue == lastAcceptedValue && (timestampMs - lastAcceptedTimestampMs) < dedupWindowMs) {
            totalDuplicatesSuppressed++
            return DedupDecision.DUPLICATE_IGNORED
        }

        // 2. 全局防抖检查：不同内容之间距离上次接受任意结果的时间过短，防止界面剧烈抖动
        val elapsedSinceLastAccepted = timestampMs - lastAcceptedTimestampMs
        if (lastAcceptedTimestampMs > 0L && elapsedSinceLastAccepted < minIntervalBetweenScansMs) {
            totalDebounceSuppressed++
            return DedupDecision.DEBOUNCE_DROPPED
        }

        // 3. 连续命中确认检查（如果要求连续 N 帧）
        if (consecutiveHitsRequired > 1) {
            if (rawValue == candidateValue) {
                candidateConsecutiveCount++
            } else {
                candidateValue = rawValue
                candidateConsecutiveCount = 1
            }

            if (candidateConsecutiveCount < consecutiveHitsRequired) {
                totalAwaitingConfirmation++
                return DedupDecision.AWAITING_CONFIRMATION
            }
        }

        // 4. 通过全部检查，正式接受
        lastAcceptedValue = rawValue
        lastAcceptedTimestampMs = timestampMs
        candidateValue = null
        candidateConsecutiveCount = 0
        totalAccepted++
        return DedupDecision.ACCEPT
    }

    /**
     * 重载辅助方法：直接传入 [BarcodeScanResult]。
     */
    fun evaluate(result: BarcodeScanResult): DedupDecision {
        val ts = if (result.timestampEpochMs > 0L) result.timestampEpochMs else clock.currentTimeMillis()
        return evaluate(result.rawValue, ts)
    }

    /**
     * 强制刷新/重置去重状态（例如用户点击了「重新扫码」或切换了业务流程）。
     */
    fun reset() {
        lastAcceptedValue = null
        lastAcceptedTimestampMs = 0L
        candidateValue = null
        candidateConsecutiveCount = 0
        totalEvaluated = 0L
        totalAccepted = 0L
        totalDuplicatesSuppressed = 0L
        totalDebounceSuppressed = 0L
        totalAwaitingConfirmation = 0L
    }

    /** 获取统计快照。 */
    fun snapshot(): DedupStats = DedupStats(
        totalEvaluated = totalEvaluated,
        totalAccepted = totalAccepted,
        totalDuplicatesSuppressed = totalDuplicatesSuppressed,
        totalDebounceSuppressed = totalDebounceSuppressed,
        totalAwaitingConfirmation = totalAwaitingConfirmation,
        lastAcceptedValue = lastAcceptedValue,
        lastAcceptedTimestampMs = lastAcceptedTimestampMs,
    )
}
