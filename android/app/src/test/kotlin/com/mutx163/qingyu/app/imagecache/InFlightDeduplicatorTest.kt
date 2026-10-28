package com.mutx163.qingyu.app.imagecache

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [InFlightDeduplicator] 单测。手推语义：
 * - 首个 begin → LEADER 且计入 in-flight；
 * - 同键再次 begin → FOLLOWER，不新增计数；
 * - complete/fail 都清标记，之后 begin 又能当 LEADER。
 */
class InFlightDeduplicatorTest {

    @Test
    fun `首个调用者是 LEADER`() {
        val d = InFlightDeduplicator()
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k1"))
        assertTrue(d.isInFlight("k1"))
        assertEquals(1, d.inFlightCount())
    }

    @Test
    fun `同键并发第二个调用者是 FOLLOWER 且不增加计数`() {
        val d = InFlightDeduplicator()
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k1"))
        assertEquals(InFlightDeduplicator.Role.FOLLOWER, d.begin("k1"))
        assertEquals(InFlightDeduplicator.Role.FOLLOWER, d.begin("k1"))
        assertEquals(1, d.inFlightCount())
    }

    @Test
    fun `不同键各自是 LEADER`() {
        val d = InFlightDeduplicator()
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k1"))
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k2"))
        assertEquals(2, d.inFlightCount())
    }

    @Test
    fun `complete 后清除且可再次成为 LEADER`() {
        val d = InFlightDeduplicator()
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k1"))
        d.complete("k1")
        assertFalse(d.isInFlight("k1"))
        assertEquals(0, d.inFlightCount())
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k1"))
    }

    @Test
    fun `fail 后清除且可再次成为 LEADER`() {
        val d = InFlightDeduplicator()
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k1"))
        d.fail("k1")
        assertFalse(d.isInFlight("k1"))
        assertEquals(0, d.inFlightCount())
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k1"))
    }

    @Test
    fun `complete 不存在的键不抛错也不改计数`() {
        val d = InFlightDeduplicator()
        d.begin("k1")
        d.complete("nope")
        assertEquals(1, d.inFlightCount())
        assertFalse(d.isInFlight("nope"))
    }

    @Test
    fun `leader 完成后原来加入的 follower 场景可重新起一轮`() {
        val d = InFlightDeduplicator()
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k1"))
        assertEquals(InFlightDeduplicator.Role.FOLLOWER, d.begin("k1"))
        d.complete("k1")
        // 一轮结束后再请求，必须是新的 LEADER（而不是永远卡在 FOLLOWER）
        assertEquals(InFlightDeduplicator.Role.LEADER, d.begin("k1"))
        assertTrue(d.isInFlight("k1"))
    }
}
