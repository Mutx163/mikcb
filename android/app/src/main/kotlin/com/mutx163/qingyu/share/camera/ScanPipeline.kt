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

    companion object {

        /**
         * 二维码**帧流**专用配置：关掉「异码之间至少隔 250ms」的全局防抖。
         *
         * ## 为什么通用默认值不能用于二维码传输
         *
         * 发送端每 250ms 换一帧（[com.mutx163.qingyu.share.QrTransferLimits.FRAME_INTERVAL_MILLIS]），
         * 而通用扫码默认 `minIntervalBetweenScansMs = 250ms`。两者同值 ⇒ 只要解码耗时有一点
         * 抖动，后一帧就会落在「距上次接受不足 250ms」的窗口里被丢掉；帧只展示 250ms，
         * 丢掉就再也补不回来。接收端因此达不到 4fps，接近资源上限的包会撞 15 分钟会话上限。
         *
         * 发布版（`mobile_scanner` + `QrTransferDecoder.submitFrame`）没有任何异码间隔闸门，
         * 重复帧只按 **seed** 去重。这里照做：异码间隔 0；同一段文本的 1500ms 冷却保留，
         * 它只是省一次解析（同文本必然是同一 seed 的重复画面），不会丢有效帧。
         *
         * 单次扫码（加课、配对等）仍用 [ScanPipelineConfig] 默认值，避免同一画面弹两次。
         */
        fun qrFrameStreamConfig(): ScanPipelineConfig = ScanPipelineConfig(
            minIntervalBetweenScansMs = 0L,
        )

        /** 二维码帧流管线（**唯一**给 `QrCameraHost` 用的构造入口）。 */
        fun forQrFrameStream(
            clock: ScanClock = SystemScanClock,
            initialHasPermission: Boolean = false,
        ): ScanPipeline = ScanPipeline(
            config = qrFrameStreamConfig(),
            clock = clock,
            initialHasPermission = initialHasPermission,
        )
    }
}
