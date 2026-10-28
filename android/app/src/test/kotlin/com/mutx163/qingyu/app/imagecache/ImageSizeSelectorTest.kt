package com.mutx163.qingyu.app.imagecache

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * [ImageSizeSelector] 单测。手推 BitmapFactory 语义：
 * 取最大 2 的幂 s，使 src/s >= target（宽高都满足）。
 * - 4000x3000 → 目标 1000x750：s=4（4000/4=1000, 3000/4=750），s=8 会让宽变 500<1000；
 * - 8000x8000 → 100x100：s=64（8000/64=125 >=100），s=128 → 62<100；
 * - 源小于目标（放大）→ 1；源等于目标 → 1。
 */
class ImageSizeSelectorTest {

    @Test
    fun `常规下采样取最大可行 2 的幂`() {
        assertEquals(4, ImageSizeSelector.inSampleSize(4000, 3000, 1000, 750))
    }

    @Test
    fun `超大源图选到较大采样`() {
        assertEquals(64, ImageSizeSelector.inSampleSize(8000, 8000, 100, 100))
    }

    @Test
    fun `放大场景返回 1`() {
        assertEquals(1, ImageSizeSelector.inSampleSize(50, 50, 100, 100))
    }

    @Test
    fun `源恰好等于目标返回 1`() {
        assertEquals(1, ImageSizeSelector.inSampleSize(100, 100, 100, 100))
    }

    @Test
    fun `受较短边约束`() {
        // 高是瓶颈：4000x1000 → 500x500，s=2 时高 1000/2=500 刚好；s=4 高 250<500
        assertEquals(2, ImageSizeSelector.inSampleSize(4000, 1000, 500, 500))
    }

    @Test
    fun `受较窄边约束`() {
        // 宽是瓶颈：1000x8000 → 500x500，s=2 宽 500 刚好；s=4 宽 250<500
        assertEquals(2, ImageSizeSelector.inSampleSize(1000, 8000, 500, 500))
    }

    @Test
    fun `整数倍下采样`() {
        assertEquals(4, ImageSizeSelector.inSampleSize(2000, 2000, 500, 500))
    }

    @Test
    fun `非正输入一律返回 1`() {
        assertEquals(1, ImageSizeSelector.inSampleSize(0, 0, 100, 100))
        assertEquals(1, ImageSizeSelector.inSampleSize(100, 100, 0, 0))
        assertEquals(1, ImageSizeSelector.inSampleSize(-1, 100, 100, 100))
    }

    @Test
    fun `结果恒为 2 的幂且解码后不低于目标`() {
        val cases = listOf(
            intArrayOf(4000, 3000, 800, 600),
            intArrayOf(1920, 1080, 720, 720),
            intArrayOf(300, 200, 64, 64),
            intArrayOf(5000, 4000, 500, 400),
        )
        for (c in cases) {
            val s = ImageSizeSelector.inSampleSize(c[0], c[1], c[2], c[3])
            assertEquals("采样必须是 2 的幂: $s", 0, s and (s - 1))
            if (c[0] / s < c[2] || c[1] / s < c[3]) {
                throw AssertionError("解码后低于目标: case=${c.toList()} s=$s")
            }
            // 再翻一倍应当已低于目标（说明已取到最大可行值）
            val twice = s * 2
            org.junit.Assert.assertTrue(
                "再翻倍应已低于目标: case=${c.toList()} s=$s",
                c[0] / twice < c[2] || c[1] / twice < c[3],
            )
        }
    }
}
