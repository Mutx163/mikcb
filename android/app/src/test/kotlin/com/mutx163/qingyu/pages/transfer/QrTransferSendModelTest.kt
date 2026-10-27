package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.QrTransferLimits
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 二维码发送页模型层测试。
 *
 * 期望值从 Dart 源手推（`lib/screens/qr_transfer_send_screen.dart`）：
 * - 进度文案：`qrTransferFrameProgress`（`已发送 {sent} 帧，约需 {total} 帧`，:361）；
 * - 超限与超时各自的提示（:390 与 ARB）；
 * - 停止按钮（:396）。
 *
 * 重点是三个「会撒谎」的边界：帧数没算好、sent 超过 total、超时后仍显示进度。
 */
class QrTransferSendModelTest {

    // ── 1. 进度文案 ──

    @Test
    fun `帧数就绪时给出进度`() {
        val model = QrTransferSendModel(sentFrames = 30, totalFrames = 100)
        assertEquals("已发送 30 帧，约需 100 帧", model.progressText)
        assertEquals(0.3f, model.progressFraction, 0.0001f)
    }

    @Test
    fun `帧数没算好时不显示进度`() {
        // totalFrames = 0 时显示「约需 0 帧」是在撒谎，应整行不画
        assertNull(QrTransferSendModel(sentFrames = 0, totalFrames = 0).progressText)
        assertNull(QrTransferSendModel(sentFrames = 5, totalFrames = -1).progressText)
        assertEquals(0f, QrTransferSendModel(totalFrames = 0).progressFraction, 0.0001f)
    }

    @Test
    fun `重复帧让 sent 超过 total 时不显示自相矛盾的数字`() {
        // 实测可能出现「已发送 120 帧，约需 100 帧」这种自相矛盾的说法
        val model = QrTransferSendModel(sentFrames = 120, totalFrames = 100)
        assertEquals("已发送 100 帧，约需 100 帧", model.progressText)
        assertEquals(1f, model.progressFraction, 0.0001f)
        assertTrue(model.isComplete)
    }

    @Test
    fun `刚发完时判定为完成`() {
        assertTrue(QrTransferSendModel(sentFrames = 100, totalFrames = 100).isComplete)
        assertFalse(QrTransferSendModel(sentFrames = 99, totalFrames = 100).isComplete)
        assertFalse("没算好帧数不算完成", QrTransferSendModel(sentFrames = 0, totalFrames = 0).isComplete)
    }

    // ── 2. 拦截提示的优先级 ──

    @Test
    fun `超资源上限与超时都能发`() {
        assertTrue(QrTransferSendModel().canSend)
        assertNull(QrTransferSendModel().blockingMessage)
    }

    @Test
    fun `超限时不能发并给出上限文案`() {
        val model = QrTransferSendModel(overResourceLimit = true)
        assertFalse(model.canSend)
        assertEquals("接收数据超过二维码传输资源上限，请重新开始并使用更小的备份。", model.blockingMessage)
    }

    @Test
    fun `超时时不能发并给出超时文案`() {
        val model = QrTransferSendModel(expired = true)
        assertFalse(model.canSend)
        assertEquals("二维码传输已超时，请重新开始并只对准一台设备。", model.blockingMessage)
    }

    @Test
    fun `同时超限与超时先说超限`() {
        // 超限时用户该看到「备份太大」；说超时他会一直重试同一份过大数据
        val model = QrTransferSendModel(overResourceLimit = true, expired = true)
        assertEquals("接收数据超过二维码传输资源上限，请重新开始并使用更小的备份。", model.blockingMessage)
    }

    // ── 3. 已用时间 ──

    @Test
    fun `已用时间按分秒格式`() {
        assertEquals("0:00", QrTransferSendModel(elapsedMillis = 0).elapsedText)
        assertEquals("0:05", QrTransferSendModel(elapsedMillis = 5_000).elapsedText)
        assertEquals("1:05", QrTransferSendModel(elapsedMillis = 65_000).elapsedText)
        assertEquals("15:00", QrTransferSendModel(elapsedMillis = 900_000).elapsedText)
    }

    @Test
    fun `负数时间不显示负号`() {
        assertEquals("0:00", QrTransferSendModel(elapsedMillis = -1000).elapsedText)
    }

    // ── 4. 文案与常量 ──

    @Test
    fun `文案取自 ARB`() {
        val model = QrTransferSendModel()
        assertEquals("二维码面对面传输", model.title)
        assertEquals("请对方打开扫码接收并对准屏幕，保持直到传输完成", model.sendHint)
        assertEquals("停止发送", model.stopLabel)
    }

    @Test
    fun `帧间隔取底层常量不另定一个数`() {
        assertEquals(QrTransferLimits.FRAME_INTERVAL_MILLIS, QrTransferSendModel().frameIntervalMillis)
    }
}
