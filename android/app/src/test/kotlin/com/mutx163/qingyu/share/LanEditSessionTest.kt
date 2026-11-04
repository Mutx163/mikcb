package com.mutx163.qingyu.share

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
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

    /**
     * 2026-11-02 并发回归钉：HTTP 工作线程 verifyPin/markClientConnected 写、
     * UI 线程 connectedClientCount（内部 removeIf）/isPinLocked/expiresAt 读。
     * 加锁前裸 LinkedHashMap 会撞并发修改异常、跨 IP 失败预算会互相丢。
     */
    @Test fun `并发认证与状态读取不抛异常且失败计数不丢`() {
        val session = sessionAt(1_750_000_000_000L, FakeClock(1_750_000_000_000L))
        val failThreads = 4
        val failsPerThread = 10 // 总失败 40，留在会话预算 50 以内，方便精确断言
        val successRounds = 200
        val start = CountDownLatch(1)
        val readersDone = CountDownLatch(1)
        val writersDone = CountDownLatch(failThreads + 1)
        val errors = java.util.concurrent.atomic.AtomicReference<Throwable?>(null)
        val reads = java.util.concurrent.atomic.AtomicInteger(0)

        // 写侧 1：各 IP 打错 PIN（并发写 pinAttempts 与 totalPinFailures）。
        // 每次失败用不同 IP：单 IP 5 次就限速、限速后不再计入总预算，
        // 这里要测的是「总预算计数不丢」，所以每个 IP 只打一次。
        repeat(failThreads) { t ->
            Thread {
                try {
                    start.await()
                    repeat(failsPerThread) { i -> session.verifyPin("000000", "10.0.$t.$i") }
                } catch (throwable: Throwable) {
                    errors.compareAndSet(null, throwable)
                } finally {
                    writersDone.countDown()
                }
            }.start()
        }
        // 写侧 2：轮换 40 个 IP 用正确 PIN——put 新 key 会改 LinkedHashMap 结构，
        // 与读侧 connectedClientCount 的 removeIf 遍历构成真正的并发修改面
        // （单 IP 重复 put 已存在 key 不改结构，咬合不到遍历竞态）。
        val successIps = 40
        Thread {
            try {
                start.await()
                repeat(successRounds) { session.verifyPin("123456", "192.168.1.${it % successIps}") }
            } catch (throwable: Throwable) {
                errors.compareAndSet(null, throwable)
            } finally {
                writersDone.countDown()
            }
        }.start()
        // 读侧：模拟 UI 主线程连读全部状态面（含 connectedClientCount 的 removeIf 清理）。
        Thread {
            try {
                start.await()
                // do-while：保证至少真读一轮——快机上写侧可能先于读线程启动跑完，
                // `while (count > 0)` 会一轮不进、让下面 reads>0 的断言时序性翻车。
                do {
                    // 任何一个读在加锁前都可能撞并发修改异常或拿到撕裂状态。
                    session.connectedClientCount
                    session.isPinLocked
                    session.isExpired
                    session.expiresAt
                    session.lastActivityAtMillis
                    session.boundProfileId
                    reads.incrementAndGet()
                } while (writersDone.count > 0)
            } catch (throwable: Throwable) {
                errors.compareAndSet(null, throwable)
            } finally {
                readersDone.countDown()
            }
        }.start()

        start.countDown()
        writersDone.await()
        readersDone.await()

        errors.get()?.let { throw it }
        assertTrue("读侧必须真的并发读过若干轮", reads.get() > 0)
        assertEquals("跨 IP 失败预算一次都不能丢", failThreads * failsPerThread, session.totalPinFailures())
        assertEquals("每个成功认证过的 IP 恰好各计一台在线（时钟没推进都不离线）", successIps, session.connectedClientCount)
        assertFalse("40 次失败不该触发会话锁死", session.isPinLocked)
    }
}
