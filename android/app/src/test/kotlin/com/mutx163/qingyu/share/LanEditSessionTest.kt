package com.mutx163.qingyu.share

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/**
 * 局域网编辑会话端口测试。
 * dart 源：lib/services/lan_edit_session.dart；
 * 抄录 test/services/lan_edit_session_test.dart 全量（过期/限速/客户端计数/
 * 会话级总预算）。期望值人推：边界时刻（==timeout 未过期、+1s 过期）、
 * 失败 5 次锁单 IP、50 次锁全会话、90 万组合量级。
 */
class LanEditSessionTest {

    private class FakeClock(var now: Long) {
        fun get(): Long = now
    }

    private fun sessionAt(base: Long, clock: FakeClock): LanEditSession =
        LanEditSession.forTest(
            pin = "123456",
            token = "token",
            createdAtMillis = base,
            lastActivityAtMillis = base,
            clockMillis = clock::get,
        )

    @Test fun `空闲超时边界`() {
        val base = 1_750_000_000_000L
        val session = sessionAt(base, FakeClock(base))
        assertFalse(session.isExpiredAt(base + LanEditSession.IDLE_TIMEOUT_MILLIS))
        assertTrue(session.isExpiredAt(base + LanEditSession.IDLE_TIMEOUT_MILLIS + 1))
    }

    @Test fun `硬上限到达即过期`() {
        val base = 1_750_000_000_000L
        val clock = FakeClock(base)
        val session = LanEditSession.forTest(
            pin = "123456",
            token = "token",
            createdAtMillis = base,
            lastActivityAtMillis = base + LanEditSession.MAX_DURATION_MILLIS,
            clockMillis = clock::get,
        )
        assertFalse(session.isExpiredAt(base + LanEditSession.MAX_DURATION_MILLIS))
        assertTrue(session.isExpiredAt(base + LanEditSession.MAX_DURATION_MILLIS + 1))
    }

    @Test fun `同IP失败5次被限速`() {
        val clock = FakeClock(1_750_000_000_000L)
        val session = sessionAt(clock.now, clock)
        repeat(LanEditSession.MAX_PIN_ATTEMPTS_PER_IP) {
            assertFalse(session.verifyPin("000000", "10.0.0.8"))
        }
        assertTrue(session.isPinRateLimited("10.0.0.8"))
        // 正确 PIN 也被拦。
        assertFalse(session.verifyPin("123456", "10.0.0.8"))
        // 别的 IP 不受牵连。
        assertFalse(session.isPinRateLimited("10.0.0.9"))
    }

    @Test fun `成功后计入已连接客户端`() {
        val clock = FakeClock(1_750_000_000_000L)
        val session = sessionAt(clock.now, clock)
        assertEquals(0, session.connectedClientCount)
        assertTrue(session.verifyPin("123456", "192.168.1.5"))
        assertEquals(1, session.connectedClientCount)
        assertTrue(session.verifyTokenForRequest("token", "192.168.1.6"))
        assertEquals(2, session.connectedClientCount)
    }

    @Test fun `静默超idleTimeout不再计入在线`() {
        val clock = FakeClock(1_750_000_000_000L)
        val session = sessionAt(clock.now, clock)
        assertTrue(session.verifyPin("123456", "192.168.1.5"))
        assertTrue(session.verifyTokenForRequest("token", "192.168.1.6"))
        assertEquals(2, session.connectedClientCountAt(clock.now))
        clock.now += LanEditSession.IDLE_TIMEOUT_MILLIS - 60_000L
        // 注意：verifyToken 的 touch 会刷新 lastActivity，但客户端 seenAt 不动；
        // 此处只推进时间不补请求，仍算在线。
        assertEquals(2, session.connectedClientCountAt(clock.now))
        clock.now += 61_001L // 合计 idleTimeout + 1s
        assertEquals(0, session.connectedClientCountAt(clock.now))
        // 被判离线的客户端再授权后重新计入，且只出现一次。
        clock.now = session.lastActivityAtMillis // 回到会话有效期内授权
        assertTrue(session.verifyTokenForRequest("token", "192.168.1.9"))
        assertEquals(1, session.connectedClientCountAt(clock.now))
    }

    @Test fun `换源地址各试一次达总预算后锁死`() {
        val clock = FakeClock(1_750_000_000_000L)
        val session = sessionAt(clock.now, clock)
        assertFalse(session.isPinLocked)
        repeat(LanEditSession.MAX_PIN_FAILURES_PER_SESSION) { i ->
            assertFalse(session.verifyPin("000000", "10.0.$i.1"))
        }
        assertTrue(session.isPinLocked)
        // 锁死后正确 PIN 也不放行。
        assertFalse(session.verifyPin("123456", "10.0.99.9"))
        // 任意 IP 都表现为限速（服务端回 429）。
        assertTrue(session.isPinRateLimited("10.0.99.9"))
    }

    @Test fun `预算内成功不受影响且不计入失败`() {
        val clock = FakeClock(1_750_000_000_000L)
        val session = sessionAt(clock.now, clock)
        assertFalse(session.verifyPin("000000", "10.0.0.1"))
        assertFalse(session.verifyPin("000000", "10.0.0.2"))
        assertFalse(session.isPinLocked)
        assertTrue(session.verifyPin("123456", "10.0.0.3"))
        assertFalse(session.isPinLocked)
        assertEquals(2, session.totalPinFailures())
    }

    @Test fun `总预算远小于穷举空间`() {
        // 钉住量级：有人把预算调到"穷举可行"时先红再议（Dart 原文）。
        assertTrue(LanEditSession.MAX_PIN_FAILURES_PER_SESSION < 1000)
        assertTrue(
            LanEditSession.MAX_PIN_FAILURES_PER_SESSION >
                LanEditSession.MAX_PIN_ATTEMPTS_PER_IP,
        )
    }

    @Test fun `token校验语义`() {
        val clock = FakeClock(1_750_000_000_000L)
        val session = sessionAt(clock.now, clock)
        assertFalse(session.verifyToken(null))
        assertFalse(session.verifyToken(""))
        assertFalse(session.verifyToken("wrong"))
        // 长度不等直接拒。
        assertFalse(session.verifyToken("tokenX"))
        assertTrue(session.verifyToken("token"))
        // 过期后拒收。
        clock.now += LanEditSession.IDLE_TIMEOUT_MILLIS + 1
        assertFalse(session.verifyToken("token"))
    }

    @Test fun `PIN前后空白被容忍`() {
        val clock = FakeClock(1_750_000_000_000L)
        val session = sessionAt(clock.now, clock)
        assertTrue(session.verifyPin("  123456 ", "10.0.0.1"))
    }

    @Test fun `create生成6位数字PIN与uuid`() {
        val session = LanEditSession.create(random = Random(42))
        assertTrue(session.pin.matches(Regex("[0-9]{6}")))
        assertTrue(session.pin.toInt() in 100000..999999)
        assertTrue(session.token.matches(Regex("[0-9a-f-]{36}")))
        assertEquals(session.createdAtMillis, session.lastActivityAtMillis)
    }

    @Test fun `expiresAt取idle与硬上限较小者`() {
        val base = 1_750_000_000_000L
        val session = sessionAt(base, FakeClock(base))
        assertEquals(base + LanEditSession.IDLE_TIMEOUT_MILLIS, session.expiresAt)
        // lastActivity 推到硬上限附近时，硬上限更小。
        val clock = FakeClock(base + LanEditSession.MAX_DURATION_MILLIS - 1000L)
        val late = sessionAt(base, clock)
        late.touch()
        assertEquals(base + LanEditSession.MAX_DURATION_MILLIS, late.expiresAt)
    }
}
