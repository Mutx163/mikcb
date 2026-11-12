package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * [WidgetRoundRunner] 的 JVM 单测：钉「卡死路径」的保底。
 *
 * 场景：一轮刷新**永不返回**（不抛异常、线程不结束）。没有这层超时，串行线程会一直
 * 卡在 join 上，后续所有轮次（含 `finish()` 与 15 分钟兜底）永远排队。
 *
 * 三条断言：
 * 1. 卡死的一轮超时后必须回调 `onTimeout`；
 * 2. 卡死那一轮**不能把队列堵死**——下一轮仍要在合理时间内跑起来；
 * 3. 正常结束的一轮不触发超时（避免把慢设备误判成卡死）。
 *
 * 咬合探针（可复现）：把 `submit` 里的 `if (round.isAlive) onTimeout()` 删掉 →
 * 第 1、2 例红（第 2 例会超时失败）；还原后绿。
 */
class WidgetRoundRunnerTest {

    @Test
    fun `永不返回的刷新会被判超时并回调`() {
        val executor = Executors.newSingleThreadExecutor()
        val runner = WidgetRoundRunner(executor)
        val timedOut = CountDownLatch(1)
        val release = CountDownLatch(1)
        try {
            runner.submit(timeoutMillis = 200, onTimeout = { timedOut.countDown() }) {
                // 模拟卡死：直到测试主动放行才返回。
                release.await()
            }
            assertTrue("卡死的一轮必须在超时后回调 onTimeout", timedOut.await(5, TimeUnit.SECONDS))
        } finally {
            release.countDown()
            executor.shutdownNow()
        }
    }

    @Test
    fun `卡死一轮后下一轮不被永久阻塞`() {
        val executor = Executors.newSingleThreadExecutor()
        val runner = WidgetRoundRunner(executor)
        val firstTimedOut = CountDownLatch(1)
        val release = CountDownLatch(1)
        val secondRan = CountDownLatch(1)
        try {
            runner.submit(timeoutMillis = 200, onTimeout = { firstTimedOut.countDown() }) {
                release.await()
            }
            assertTrue("第一轮应先被判超时", firstTimedOut.await(5, TimeUnit.SECONDS))

            runner.submit(timeoutMillis = 5_000, onTimeout = { }) { secondRan.countDown() }

            assertTrue("卡死的那一轮不能把后续轮次堵死", secondRan.await(5, TimeUnit.SECONDS))
        } finally {
            release.countDown()
            executor.shutdownNow()
        }
    }

    @Test
    fun `正常结束的一轮不触发超时`() {
        val executor = Executors.newSingleThreadExecutor()
        val runner = WidgetRoundRunner(executor)
        val ran = CountDownLatch(1)
        val timeouts = AtomicInteger(0)
        try {
            runner.submit(timeoutMillis = 5_000, onTimeout = { timeouts.incrementAndGet() }) {
                ran.countDown()
            }
            assertTrue(ran.await(5, TimeUnit.SECONDS))
            // 给超时判定留一点时间，确认它没有误触发。
            Thread.sleep(300)
            assertEquals("正常结束不该判超时", 0, timeouts.get())
        } finally {
            executor.shutdownNow()
        }
    }
}
