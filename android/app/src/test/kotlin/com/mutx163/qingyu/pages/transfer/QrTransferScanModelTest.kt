package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 二维码扫码接收页模型层测试。
 *
 * 期望值从 Dart 源手推（`lib/screens/qr_transfer_scan_screen.dart`）与 ARB：
 * - 七种错误各有专属文案（搞混任何一种都会把用户引向错误的重试方向）；
 * - 进度文案：`已接收 {received} 帧 · 已解出 {decoded}/{total}`；
 * - `totalSymbols = 0`（头帧未到）时不显示 `0/0`；
 * - 「重新开始」只在失败态出现。
 */
class QrTransferScanModelTest {

    // ── 1. 七种错误各自的文案 ──

    @Test
    fun `会话不匹配`() {
        val model = QrTransferScanModel(error = QrTransferScanModel.Error.SESSION_MISMATCH)
        assertEquals("检测到不同传输内容，请确认只对准一份数据", model.errorMessage)
    }

    @Test
    fun `校验和失败`() {
        assertEquals(
            "传输校验失败，请重新开始",
            QrTransferScanModel(error = QrTransferScanModel.Error.CHECKSUM_FAILED).errorMessage,
        )
    }

    @Test
    fun `接收长度不符`() {
        assertEquals(
            "接收数据长度校验失败，请重新开始",
            QrTransferScanModel(error = QrTransferScanModel.Error.RAW_LENGTH_MISMATCH).errorMessage,
        )
    }

    @Test
    fun `解压失败`() {
        assertEquals(
            "数据解压失败，请重新开始",
            QrTransferScanModel(error = QrTransferScanModel.Error.DECOMPRESSION_FAILED).errorMessage,
        )
    }

    @Test
    fun `超资源上限`() {
        assertEquals(
            "接收数据超过二维码传输资源上限，请重新开始并使用更小的备份。",
            QrTransferScanModel(error = QrTransferScanModel.Error.RESOURCE_LIMIT).errorMessage,
        )
    }

    @Test
    fun `会话超时`() {
        assertEquals(
            "二维码传输已超时，请重新开始并只对准一台设备。",
            QrTransferScanModel(error = QrTransferScanModel.Error.SESSION_EXPIRED).errorMessage,
        )
    }

    @Test
    fun `解码失败`() {
        assertEquals(
            "二维码数据解码失败，请重新开始",
            QrTransferScanModel(error = QrTransferScanModel.Error.DECODE_FAILED).errorMessage,
        )
    }

    @Test
    fun `七条错误文案互不相同`() {
        // 全都一样就说明有人复制粘贴时漏改了键名
        val messages = QrTransferScanModel.Error.entries.map { it.messageOf() }
        assertEquals("错误种类应有 7 种", 7, messages.size)
        assertEquals("错误文案不该重复：$messages", messages.size, messages.toSet().size)
        assertTrue(messages.all { it.isNotBlank() })
    }

    // ── 2. 阶段判定 ──

    @Test
    fun `刚开始是收集中`() {
        val model = QrTransferScanModel()
        assertTrue(model.isScanning)
        assertFalse(model.isComplete)
        assertNull(model.errorMessage)
        assertFalse("正常收集中不该出现重新开始", model.showRestart)
    }

    @Test
    fun `有错误时不在收集中而且能重来`() {
        val model = QrTransferScanModel(error = QrTransferScanModel.Error.CHECKSUM_FAILED)
        assertFalse(model.isScanning)
        assertTrue(model.showRestart)
    }

    @Test
    fun `收齐后判定完成且不显示重新开始`() {
        // 收齐后重来会和导入流程抢时序
        val model = QrTransferScanModel(decodedSymbols = 50, totalSymbols = 50)
        assertTrue(model.isComplete)
        assertFalse(model.isScanning)
        assertFalse("收齐后不该让人重来", model.showRestart)
    }

    // ── 3. 进度 ──

    @Test
    fun `头帧未到时不显示进度`() {
        // totalSymbols = 0 时显示 0/0 只会让人困惑
        assertNull(QrTransferScanModel(receivedFrames = 3).progressText)
        assertEquals(0f, QrTransferScanModel().progressFraction, 0.0001f)
    }

    @Test
    fun `有总量时给出进度`() {
        val model = QrTransferScanModel(receivedFrames = 12, decodedSymbols = 25, totalSymbols = 100)
        assertEquals("已接收 12 帧 · 已解出 25/100", model.progressText)
        assertEquals(0.25f, model.progressFraction, 0.0001f)
    }

    @Test
    fun `解出数超过总量时夹住不显示超 100%`() {
        val model = QrTransferScanModel(receivedFrames = 200, decodedSymbols = 120, totalSymbols = 100)
        assertEquals("已接收 200 帧 · 已解出 100/100", model.progressText)
        assertEquals(1f, model.progressFraction, 0.0001f)
    }

    // ── 4. 收齐后的完整备份提示 ──

    @Test
    fun `完整备份要说明会替换本机数据`() {
        val model = QrTransferScanModel()
        assertEquals("确认后，该完整备份会替换本设备上的数据。", model.fullBackupWarning)
        assertEquals("导入完整备份", model.importFullBackupLabel)
    }

    // ── 5. 文案 ──

    @Test
    fun `标题与提示取自 ARB`() {
        val model = QrTransferScanModel()
        assertEquals("扫码接收", model.title)
        assertEquals("将摄像头对准对方手机屏幕，保持稳定，等待进度完成", model.scanHint)
        assertEquals("数据接收完成，正在导入……", model.completeMessage)
        assertEquals("重新开始", model.restartLabel)
        assertTrue("明文提醒不能为空", model.plaintextWarning.isNotBlank())
    }
}
