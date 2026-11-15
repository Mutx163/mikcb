package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 顶栏玻璃带「两层染色」的合成算式（2026-11-15）。
 *
 * 用户口径：带子那一层要「把录进来的内容一起压暗」，不能只压壁纸。两层 alpha 合成后
 * 必须仍然等于材质面板那根 `tintAlpha`——否则调滑块的总强度会跟观感对不上。
 */
class BandGlassTintTest {

    @Test
    fun `两层合成后等于总强度`() {
        for (total in listOf(0.2f, 0.5f, 0.7f, 0.9f)) {
            val (first, top) = bandTintLayerAlphas(total)
            val composed = 1f - (1f - first) * (1f - top)
            assertEquals("总强度 $total 的合成值必须回到 $total", total, composed, 1e-4f)
        }
    }

    @Test
    fun `顶层要拿到绝大部分强度`() {
        // 第一遍只给壁纸串色，课卡那遍看不到它；顶层才是「压在卡片上」的那层。
        val (first, top) = bandTintLayerAlphas(0.7f)
        assertTrue("第一遍的份额应低于两成，实际 $first", first < 0.2f)
        assertTrue("顶层应接近总强度，实际 $top", top > 0.6f)
    }

    @Test
    fun `零强度两层都是零`() {
        assertEquals(0f to 0f, bandTintLayerAlphas(0f))
    }

    @Test
    fun `满强度与越界值都收敛在合法区间`() {
        val (firstMax, topMax) = bandTintLayerAlphas(1f)
        assertEquals(1f, 1f - (1f - firstMax) * (1f - topMax), 1e-4f)
        assertEquals(bandTintLayerAlphas(1f), bandTintLayerAlphas(2.5f))
        assertEquals(bandTintLayerAlphas(0f), bandTintLayerAlphas(-1f))
        for (total in listOf(-1f, 0f, 0.3f, 1f, 3f)) {
            val (first, top) = bandTintLayerAlphas(total)
            assertTrue("first 越界：$first", first in 0f..1f)
            assertTrue("top 越界：$top", top in 0f..1f)
        }
    }
}
