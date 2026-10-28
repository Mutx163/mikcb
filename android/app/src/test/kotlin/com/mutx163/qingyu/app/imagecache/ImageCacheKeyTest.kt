package com.mutx163.qingyu.app.imagecache

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * [ImageCacheKey] 单测。期望值全部**手推**（不是从实现抄）：
 * - 尺寸桶：把宽高向上取最近的 2 的幂（1,2,4,...,128,...）；
 * - 100 → 128（128 是 >=100 的最小 2 的幂），64 → 64，65 → 128；
 * - URL 规范化只改 scheme/authority 大小写与首尾空白，path/query 原样。
 */
class ImageCacheKeyTest {

    @Test
    fun `基础键 = 规范化URL + 尺寸桶`() {
        // 100 上去最近的 2 的幂 = 128
        assertEquals(
            "https://a.com/x.png|128x128",
            ImageCacheKey.of("https://a.com/x.png", 100, 100),
        )
    }

    @Test
    fun `相同输入稳定可复现`() {
        val a = ImageCacheKey.of("https://a.com/x.png", 300, 200)
        val b = ImageCacheKey.of("https://a.com/x.png", 300, 200)
        assertEquals(a, b)
    }

    @Test
    fun `首尾空白被裁掉、scheme与主机名小写、path 大小写保留`() {
        // "  HTTPS://A.COM/Path/Img.PNG " → scheme 小写、host 小写、/Path/Img.PNG 原样
        assertEquals(
            "https://a.com/Path/Img.PNG|128x128",
            ImageCacheKey.of("  HTTPS://A.COM/Path/Img.PNG ", 100, 100),
        )
    }

    @Test
    fun `query 原样保留不被小写`() {
        // 主机 a.com 小写；query ?V=2 的大小写保留
        assertEquals(
            "https://a.com/x.png?V=2|128x128",
            ImageCacheKey.of("HTTPS://A.COM/x.png?V=2", 100, 100),
        )
    }

    @Test
    fun `尺寸桶向上去到 2 的幂`() {
        assertEquals(1, ImageCacheKey.sizeBucket(1))
        assertEquals(2, ImageCacheKey.sizeBucket(2))
        assertEquals(4, ImageCacheKey.sizeBucket(3))   // 3 -> 4
        assertEquals(64, ImageCacheKey.sizeBucket(64)) // 恰好 2 的幂不变
        assertEquals(128, ImageCacheKey.sizeBucket(65)) // 65 -> 128
        assertEquals(128, ImageCacheKey.sizeBucket(100))
    }

    @Test
    fun `尺寸桶对非正数归零、超大钳到上限`() {
        assertEquals(0, ImageCacheKey.sizeBucket(0))
        assertEquals(0, ImageCacheKey.sizeBucket(-5))
        assertEquals(4096, ImageCacheKey.sizeBucket(4000))   // 4000 -> 4096
        assertEquals(4096, ImageCacheKey.sizeBucket(4096))
        assertEquals(4096, ImageCacheKey.sizeBucket(99999))  // 超过上限钳到 4096
    }

    @Test
    fun `不同尺寸桶产生不同键`() {
        val small = ImageCacheKey.of("https://a.com/x.png", 100, 100) // 128x128
        val big = ImageCacheKey.of("https://a.com/x.png", 500, 500)   // 512x512
        assertNotEquals(small, big)
    }

    @Test
    fun `同桶内不同目标尺寸共享同一个键`() {
        // 100 与 120 都落在 128 桶 → 同键（这正是桶的意义：少建缓存条目）
        assertEquals(
            ImageCacheKey.of("https://a.com/x.png", 100, 100),
            ImageCacheKey.of("https://a.com/x.png", 120, 120),
        )
    }

    @Test
    fun `无 scheme 的串只做 trim`() {
        assertEquals("a.com/X", ImageCacheKey.normalizeUrl(" a.com/X "))
    }
}
