package com.mutx163.qingyu.share.camera

/**
 * 扫码管线配置。
 */
data class ScanPipelineConfig(
    val minFrameIntervalMs: Long = 100L,
    val frameBudgetMs: Long = 50L,
    val dedupWindowMs: Long = 1500L,
    val minIntervalBetweenScansMs: Long = 250L,
    val consecutiveHitsRequired: Int = 1,
)

/**
 * 相机扫码调度管线（整合权限状态机、帧预算节流、结果去重与防抖）。
 *
 * 宿主层通过将此管线注入 CameraX 的 ImageAnalysis.Analyzer 或自定义帧捕获器中，
 * 即可直接获得防抖、防热、防刷与安全去重的开箱即用扫码能力。
 */
class ScanPipeline(
    val config: ScanPipelineConfig = ScanPipelineConfig(),
    val clock: ScanClock = SystemScanClock,
    initialHasPermission: Boolean = false,
) {
    val permissionMachine: CameraPermissionStateMachine = CameraPermissionStateMachine(
        initialHasPermission = initialHasPermission,
    )

    val throttler: ScanFrameThrottler = ScanFrameThrottler(
        minIntervalMs = config.minFrameIntervalMs,
        frameBudgetMs = config.frameBudgetMs,
        dropPolicy = FrameDropPolicy.DROP_IF_BUSY,
        clock = clock,
    )

    val deduplicator: ScanResultDeduplicator = ScanResultDeduplicator(
        dedupWindowMs = config.dedupWindowMs,
        minIntervalBetweenScansMs = config.minIntervalBetweenScansMs,
        consecutiveHitsRequired = config.consecutiveHitsRequired,
        clock = clock,
    )

    /**
     * 收到一帧相机图像，调度分析并输出过滤后的条码结果。
     *
     * @param timestampMs 当前帧到达时间戳
     * @param decoder 实际的图像解码算法（如 ZXing 或 MLKit）；若帧被节流拦截，decoder 根本不会被调用，从而节省 CPU。
     * @return 经过防抖去重后通过的有效条码结果；若被丢帧、无条码、或判定为重复条码则返回 null。
     */
    fun onFrame(
        timestampMs: Long = clock.currentTimeMillis(),
        decoder: () -> BarcodeScanResult?,
    ): BarcodeScanResult? {
        if (!permissionMachine.isGranted) {
            return null
        }

        val decodedResult = throttler.runBudgeted(timestampMs) {
            decoder()
        } ?: return null

        val decision = deduplicator.evaluate(decodedResult)
        return if (decision == DedupDecision.ACCEPT) {
            decodedResult
        } else {
            null
        }
    }

    /**
     * 重置管线内部的节流与去重状态（例如切换页面或重新开始扫码）。
     */
    fun reset(preservePermission: Boolean = true) {
        throttler.reset()
        deduplicator.reset()
        if (!preservePermission) {
            permissionMachine.reset()
        }
    }
}
