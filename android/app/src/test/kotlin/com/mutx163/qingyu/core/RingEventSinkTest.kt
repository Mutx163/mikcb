package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors

/**
 * 环形缓冲 sink 的行为测试：有上限、满了丢最旧、回调可达、并发不炸。
 * 口径见 [RingEventSink] 的 KDoc（不落盘、不联网、绝不无限增长）。
 */
class RingEventSinkTest {

    @Test
    fun `容量有上限_满了丢最旧`() {
        val sink = RingEventSink(capacity = 3)
        for (i in 1..5) sink.log("event_$i", mapOf("seq" to i))

        assertEquals(3, sink.size)
        // 第 1、2 条被挤掉，剩下 3、4、5。
        assertEquals(listOf("event_3", "event_4", "event_5"), sink.snapshot().map { it.name })
        assertEquals(listOf(3, 4, 5), sink.snapshot().map { it.parameters["seq"] })
    }

    @Test
    fun `快照是副本_外部修改不影响缓冲`() {
        val sink = RingEventSink(capacity = 2)
        sink.log("a", mapOf("k" to 1))
        val snap = sink.snapshot().toMutableList()
        snap.clear()
        assertEquals(1, sink.size)
    }

    @Test
    fun `onEmit 回调收到每条事件`() {
        val emitted = mutableListOf<Pair<String, Map<String, Any>>>()
        val sink = RingEventSink(capacity = 8) { name, params -> emitted.add(name to params) }
        sink.log("course_created", mapOf("day_of_week" to 1))
        sink.log("course_deleted", emptyMap())

        assertEquals(listOf("course_created", "course_deleted"), emitted.map { it.first })
        assertEquals(1, emitted[0].second["day_of_week"])
    }

    @Test
    fun `clear 清空缓冲`() {
        val sink = RingEventSink()
        sink.log("a", emptyMap())
        sink.clear()
        assertEquals(0, sink.size)
    }

    @Test
    fun `容量必须为正`() {
        var threw = false
        try {
            RingEventSink(capacity = 0)
        } catch (expected: IllegalArgumentException) {
            threw = true
        }
        assertTrue("capacity=0 应抛 IllegalArgumentException", threw)
    }

    @Test
    fun `并发写入不丢锁不炸_且不超上限`() {
        val sink = RingEventSink(capacity = 64)
        val threads = 8
        val perThread = 200
        val pool = Executors.newFixedThreadPool(threads)
        val done = CountDownLatch(threads)
        repeat(threads) {
            pool.submit {
                repeat(perThread) { i -> sink.log("concurrent", mapOf("i" to i)) }
                done.countDown()
            }
        }
        done.await()
        pool.shutdown()
        assertEquals(64, sink.size)
        assertEquals("所有写入都应带参数", 64, sink.snapshot().count { it.parameters.containsKey("i") })
    }

    @Test
    fun `共享单例可复位`() {
        EventSinks.resetForTesting()
        EventSinks.shared.log("x", emptyMap())
        assertEquals(1, EventSinks.shared.size)
        EventSinks.resetForTesting()
        assertEquals(0, EventSinks.shared.size)
    }
}
