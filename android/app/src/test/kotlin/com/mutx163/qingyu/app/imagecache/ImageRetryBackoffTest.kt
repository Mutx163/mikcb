package com.mutx163.qingyu.app.imagecache

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [ImageRetryBackoff] 单测。手推：
 * - MAX_ATTEMPTS = 3（最多 3 次尝试：attempt 1、2 可重试，3 不可）；
 * - delay = 500 * 2^(attempt-1)，封顶 8000：
 *   attempt 1→500, 2→1000, 3→2000, 4→4000, 5→8000, 6→8000。
 */
class ImageRetryBackoffTest {

    @Test
    fun `最多尝试三次`() {
        assertEquals(3, ImageRetryBackoff.MAX_ATTEMPTS)
    }

    @Test
    fun `shouldRetry 只在 1 与 2 时为真`() {
        assertFalse(ImageRetryBackoff.shouldRetry(0))
        assertTrue(ImageRetryBackoff.shouldRetry(1))
        assertTrue(ImageRetryBackoff.shouldRetry(2))
        assertFalse(ImageRetryBackoff.shouldRetry(3))
        assertFalse(ImageRetryBackoff.shouldRetry(4))
        assertFalse(ImageRetryBackoff.shouldRetry(-1))
    }

    @Test
    fun `退避序列 500-1000-2000-4000-8000`() {
        assertEquals(0L, ImageRetryBackoff.delayMillis(0))
        assertEquals(500L, ImageRetryBackoff.delayMillis(1))
        assertEquals(1000L, ImageRetryBackoff.delayMillis(2))
        assertEquals(2000L, ImageRetryBackoff.delayMillis(3))
        assertEquals(4000L, ImageRetryBackoff.delayMillis(4))
        assertEquals(8000L, ImageRetryBackoff.delayMillis(5))
    }

    @Test
    fun `退避到上限后封顶不再增长`() {
        assertEquals(8000L, ImageRetryBackoff.delayMillis(6))
        assertEquals(8000L, ImageRetryBackoff.delayMillis(10))
        assertEquals(8000L, ImageRetryBackoff.delayMillis(50))
        assertEquals(8000L, ImageRetryBackoff.MAX_DELAY_MILLIS)
    }

    @Test
    fun `延迟单调不减且不超过上限`() {
        var prev = 0L
        for (attempt in 1..20) {
            val d = ImageRetryBackoff.delayMillis(attempt)
            assertTrue("delay 应单调不减: attempt=$attempt", d >= prev)
            assertTrue("delay 不应超过上限: attempt=$attempt, d=$d", d <= ImageRetryBackoff.MAX_DELAY_MILLIS)
            prev = d
        }
    }
}
