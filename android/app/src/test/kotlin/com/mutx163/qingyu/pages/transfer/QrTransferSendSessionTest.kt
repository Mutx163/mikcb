package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.QrTransferFrame
import com.mutx163.qingyu.share.QrTransferLimits
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 发送会话的单测（Phase 3.5 · TQ1）。
 *
 * 期望值是手推的：帧间隔取底层常量 250ms，于是
 * «已发送帧数» 在 249ms 时是 0、250ms 时是 1、1000ms 时是 4、1249ms 时还是 4、1250ms 时是 5。
 */
class QrTransferSendSessionTest {

    /** 一小段可压缩文本；压缩后的长度不参与手推断言，只用它建立真实会话。 */
    private fun samplePayload(): ByteArray =
        buildString {
            repeat(40) { append("课程-$it：高等数学 A，周一第 1-2 节，教三-201；\n") }
        }.toByteArray()

    @Test
    fun 帧间隔就是底层常量250毫秒() {
        val session = QrTransferSendSession.prepare(samplePayload())
        assertEquals(250L, session.frameIntervalMillis)
        assertEquals(QrTransferLimits.FRAME_INTERVAL_MILLIS, session.frameIntervalMillis)
    }

    @Test
    fun 已发送帧数按帧间隔手推() {
        val session = QrTransferSendSession.prepare(samplePayload())
        assertEquals("0ms 还没发", 0, session.modelAt(0).sentFrames)
        assertEquals("249ms 未到一拍", 0, session.modelAt(249).sentFrames)
        assertEquals("250ms 第一拍", 1, session.modelAt(250).sentFrames)
        assertEquals("1000ms 第四拍", 4, session.modelAt(1000).sentFrames)
        assertEquals("1249ms 仍属第四拍", 4, session.modelAt(1249).sentFrames)
        assertEquals("1250ms 第五拍", 5, session.modelAt(1250).sentFrames)
    }

    @Test
    fun 负数时间按0处理_不出现负帧数() {
        val session = QrTransferSendSession.prepare(samplePayload())
        val model = session.modelAt(-9999)
        assertEquals(0, model.sentFrames)
        assertEquals(0L, model.elapsedMillis)
    }

    @Test
    fun 播完一轮后只有时间在走_进度夹在满格() {
        val session = QrTransferSendSession.prepare(samplePayload())
        val cycle = session.cycleLength
        // 一轮正好是 cycleLength 拍；再过一轮，sent 继续涨但比例不能再涨。
        val afterTwoCycles = session.modelAt(cycle * 2L * session.frameIntervalMillis)
        assertEquals("已发送帧数继续增长（是真实计数）", cycle * 2, afterTwoCycles.sentFrames)
        assertEquals(1f, afterTwoCycles.progressFraction, 0.0001f)
        // 文案里 sent 会被夹到 total，避免「已发送 120 帧，约需 100 帧」这种自相矛盾
        assertEquals("已发送 $cycle 帧，约需 $cycle 帧", afterTwoCycles.progressText)
    }

    @Test
    fun 约需帧数与估算公式一致() {
        val session = QrTransferSendSession.prepare(samplePayload())
        val capacity = session.capacity
        assertNotNull("可发的会话必须有容量预算", capacity)
        assertEquals(
            "估算帧数 = (k*12+9)/10",
            (capacity!!.sourceSymbolCount * 12 + 9) / 10,
            session.cycleLength,
        )
        assertEquals(capacity.estimatedFrameCount, session.modelAt(0).totalFrames)
    }

    @Test
    fun 首帧进度文案逐字() {
        val session = QrTransferSendSession.prepare(samplePayload())
        val cycle = session.cycleLength
        assertEquals("已发送 0 帧，约需 $cycle 帧", session.modelAt(0).progressText)
        assertNull(
            "约需帧数没算好时不能显示进度行",
            QrTransferSendSession.prepare(ByteArray(0)).modelAt(0).progressText,
        )
    }

    @Test
    fun 轮播拍号到种子的映射() {
        val session = QrTransferSendSession.prepare(samplePayload())
        val cycle = session.cycleLength
        assertEquals("第 0 拍用 seed 1", 1, session.seedAt(0))
        assertEquals(2, session.seedAt(1))
        assertEquals("一轮最后一拍", cycle, session.seedAt(cycle - 1))
        assertEquals("第二轮第一拍必须是全新 seed（重播同一 seed 对解码无贡献）", cycle + 1, session.seedAt(cycle))
        assertEquals(cycle * 2 + 1, session.seedAt(cycle * 2))
        assertEquals("负数拍按第一拍处理", 1, session.seedAt(-5))
    }

    @Test
    fun 生成的帧能被帧协议解析回同一份会话信息() {
        val session = QrTransferSendSession.prepare(samplePayload())
        val text = session.frameTextForTick(0)
        assertNotNull("有数据就必须生成得出帧", text)
        assertTrue("帧必须以 QRV2 开头", text!!.startsWith("QRV2|"))
        val parsed = QrTransferFrame.parse(text)
        assertEquals(session.info, parsed.info)
        assertEquals("第 0 拍的 seed 是 1", 1, parsed.seed)
        assertTrue("度数必须 ≥1", parsed.degree >= 1)
    }

    @Test
    fun 不同拍给出不同帧_同拍给同一帧() {
        val session = QrTransferSendSession.prepare(samplePayload())
        val first = session.frameTextForTick(0)
        val again = session.frameTextForTick(0)
        val second = session.frameTextForTick(1)
        assertNotNull(first)
        assertEquals("同一拍必须稳定（缓存 + 纯函数）", first, again)
        assertNotEquals("相邻两拍必须是不同种子/内容的帧", first, second)
    }

    @Test
    fun 空载荷没有可播的帧() {
        val session = QrTransferSendSession.prepare(ByteArray(0))
        assertFalse(session.hasFrames)
        assertNull(session.info)
        val model = session.modelAt(5000)
        assertEquals("没数据就不能显示「约需 N 帧」", 0, model.totalFrames)
        assertNull(model.progressText)
        assertEquals("空载荷不是超限，不能给一句「超过资源上限」", null, model.blockingMessage)
    }

    @Test
    fun 超过15分钟显示超时且不再显示进度() {
        val session = QrTransferSendSession.prepare(samplePayload())
        val justBefore = QrTransferLimits.MAX_SESSION_DURATION_MILLIS - 1
        assertFalse(session.modelAt(justBefore).expired)
        assertNull(session.modelAt(justBefore).blockingMessage)

        val model = session.modelAt(QrTransferLimits.MAX_SESSION_DURATION_MILLIS)
        assertTrue("到达上限即超时", model.expired)
        assertFalse(model.canSend)
        assertEquals("必须换成超时文案", TransferStrings.qrTransferSessionExpired.zh, model.blockingMessage)
    }

    @Test
    fun 数据超过资源上限时给出上限文案而不是超时文案() {
        // 约 6.3MB 不可压缩数据：symbolSize 落在 2048，k≈3077，估算帧数 ≈3693 > 一轮 3600 帧上限
        val payload = kotlin.random.Random(7).nextBytes(6_300_000)
        val session = QrTransferSendSession.prepare(payload)
        assertTrue("这份数据必须触发资源上限", session.overResourceLimit)
        assertFalse("超限时不能生成帧", session.hasFrames)
        val model = session.modelAt(0)
        assertTrue(model.overResourceLimit)
        assertEquals(
            "超限优先于超时：先说「备份太大」，否则用户会一直重试同一份过大数据",
            TransferStrings.qrTransferResourceLimit.zh,
            model.blockingMessage,
        )
        assertNull("超限时不画进度行", model.progressText)
        assertEquals(0f, model.progressFraction, 0.0001f)
    }
}
