package com.mutx163.qingyu.share.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 二维码帧流管线的行为契约（2026-11-10 修「扫码防抖把帧流限速」）。
 *
 * ## 背景
 *
 * 发送端每 250ms 换一帧；通用 [ScanPipelineConfig] 的 `minIntervalBetweenScansMs` 也是
 * 250ms。两者同值时，只要解码耗时有一点抖动，后一帧就会被「距上次接受不足 250ms」丢掉，
 * 而那一帧已经翻过去了、补不回来。接收端因此到不了 4fps，接近资源上限的包会撞 15 分钟。
 *
 * 发布版（`mobile_scanner` + `QrTransferDecoder.submitFrame`）没有异码间隔闸门，
 * 重复帧只按 seed 去重。这里钉住两条：
 * 1. [ScanPipeline.forQrFrameStream] 的异码间隔必须是 0；
 * 2. 1ms 内两个**不同**码都必须放行；同一段文本仍按通用冷却窗口抑制（省一次解析，
 *    同文本必然同 seed，不会丢有效帧）。
 */
class ScanPipelineQrStreamTest {

    private class FakeClock(var now: Long) : ScanClock {
        override fun currentTimeMillis(): Long = now
    }

    private fun result(value: String, timestampMs: Long) = BarcodeScanResult(
        rawValue = value,
        timestampEpochMs = timestampMs,
    )

    @Test
    fun `二维码帧流关掉异码 250ms 闸门`() {
        val pipeline = ScanPipeline.forQrFrameStream(initialHasPermission = true)
        assertEquals(
            "异码间隔必须为 0：发送端 250ms 一帧，通用 250ms 闸门会丢帧",
            0L,
            pipeline.config.minIntervalBetweenScansMs,
        )
    }

    @Test
    fun `两次不同码间隔 100ms 都放行`() {
        val clock = FakeClock(1_000L)
        val pipeline = ScanPipeline.forQrFrameStream(clock = clock, initialHasPermission = true)

        // 100ms 是「帧分析节流」允许的最小间隔；通用去重的 250ms 闸门会在这一步把
        // 第 2 帧丢掉，所以这组时间戳正好只测「异码闸门有没有去掉」。
        val first = pipeline.onFrame(1_000L) { result("QRV2|frame-1", 1_000L) }
        val second = pipeline.onFrame(1_100L) { result("QRV2|frame-2", 1_100L) }

        assertNotNull("第 1 帧必须放行", first)
        assertNotNull("第 2 帧必须放行（异码间隔已关）", second)
        assertEquals(2L, pipeline.deduplicator.totalAccepted)
        assertEquals(0L, pipeline.deduplicator.totalDebounceSuppressed)
    }

    @Test
    fun `同一段文本仍按冷却窗口抑制_不重复喂解码会话`() {
        val clock = FakeClock(1_000L)
        val pipeline = ScanPipeline.forQrFrameStream(clock = clock, initialHasPermission = true)

        assertNotNull(pipeline.onFrame(1_000L) { result("QRV2|same", 1_000L) })
        assertNull(
            "同一画面被相机反复识别只该进业务一次；seed 去重仍在会话层兜底",
            pipeline.onFrame(1_100L) { result("QRV2|same", 1_100L) },
        )
        assertEquals(1L, pipeline.deduplicator.totalDuplicatesSuppressed)
    }

    @Test
    fun `通用扫码仍保留 250ms 异码防抖_单次扫码不会被改坏`() {
        val clock = FakeClock(1_000L)
        val pipeline = ScanPipeline(clock = clock, initialHasPermission = true)

        assertNotNull(pipeline.onFrame(1_000L) { result("CODE-A", 1_000L) })
        assertNull(
            "加课/配对等单次扫码仍需要防抖：100ms 后换码不能连弹两次",
            pipeline.onFrame(1_100L) { result("CODE-B", 1_100L) },
        )
    }
}
