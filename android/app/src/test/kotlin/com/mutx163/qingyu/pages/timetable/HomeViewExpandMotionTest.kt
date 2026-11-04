package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页「周 ↔ 日」切换的时长 / 曲线 / 降级判据（对齐已发布 2141）。
 *
 * 2141 的观感：周网格按原始进度淡出；日面板整块按 `easeInOutCubicEmphasized` 缓出的进度
 * 从当天列顶部「长」到整屏（宽高因子 + 裁剪），同时 `easeOutCubic` 淡入、上移兜底。
 * 这里钉住能靠纯函数/常量证明的部分。
 */
class HomeViewExpandMotionTest {

    @Test
    fun `时长按用户速度缩放_基准 360ms`() {
        assertEquals(360, homeViewExpandDurationMillis(1.0))
        assertEquals(180, homeViewExpandDurationMillis(2.0))
        assertEquals(720, homeViewExpandDurationMillis(0.5))
        // 超出滑杆区间按边界算，不能把时长打成 0 或负数。
        assertEquals(720, homeViewExpandDurationMillis(0.1))
        assertEquals(144, homeViewExpandDurationMillis(2.5))
        assertEquals(144, homeViewExpandDurationMillis(9.0))
    }

    @Test
    fun `减少动画判据_缩放归零即降级`() {
        assertTrue(homeViewExpandReducedMotion(0f))
    }

    @Test
    fun `减少动画判据_正常缩放不降级`() {
        assertFalse(homeViewExpandReducedMotion(1f))
        assertFalse(homeViewExpandReducedMotion(0.5f))
        assertFalse(homeViewExpandReducedMotion(2.5f))
    }

    @Test
    fun `减少动画判据_负数按不播动画处理`() {
        assertTrue(homeViewExpandReducedMotion(-1f))
    }

    @Test
    fun `easeOutCubic 端点与中点`() {
        assertEquals(0f, homeViewEaseOutCubic(0f), 1e-5f)
        assertEquals(1f, homeViewEaseOutCubic(1f), 1e-5f)
        // 1 - (1-0.5)^3 = 1 - 0.125 = 0.875
        assertEquals(0.875f, homeViewEaseOutCubic(0.5f), 1e-4f)
        // 越界夹取。
        assertEquals(0f, homeViewEaseOutCubic(-1f), 1e-5f)
        assertEquals(1f, homeViewEaseOutCubic(2f), 1e-5f)
    }

    @Test
    fun `easeInOutCubicEmphasized 是三点贝塞尔 端点与中点值对齐`() {
        val e = homeViewEaseInOutCubicEmphasized
        assertEquals(0f, e.transform(0f), 1e-4f)
        assertEquals(1f, e.transform(1f), 1e-4f)
        // 第一段终点（x=midX=0.166666）必须落在 y=midY=0.4 —— 这是 ThreePointCubic 的定义点。
        assertEquals(0.4f, e.transform(0.166666f), 2e-3f)
    }

    @Test
    fun `easeInOutCubicEmphasized 全程单调不减`() {
        val e = homeViewEaseInOutCubicEmphasized
        var last = -1f
        for (i in 0..100) {
            val y = e.transform(i / 100f)
            assertTrue("progress=${i / 100f} 处曲线回退：$y < $last", y >= last - 1e-4f)
            assertTrue("取值越界：$y", y >= -1e-4f && y <= 1.0001f)
            last = y
        }
    }

    @Test
    fun `easeInOutCubicEmphasized 起步比线性快_不是慢起步`() {
        // 三点贝塞尔的「强调」：前 1/6 就跑完约 40%（y(0.1667)=0.4），远快于线性 0.1667。
        assertTrue(homeViewEaseInOutCubicEmphasized.transform(0.166666f) > 0.3f)
    }

    @Test
    fun `圆角收束_全程保 28dp 仅贴边 0_2% 收平`() {
        assertEquals(1f, homeViewExpandCornerRadiusFactor(0f), 1e-5f)
        assertEquals(1f, homeViewExpandCornerRadiusFactor(0.5f), 1e-5f)
        assertEquals(1f, homeViewExpandCornerRadiusFactor(0.99f), 1e-5f)
        // (1-0.999)/0.002 = 0.5
        assertEquals(0.5f, homeViewExpandCornerRadiusFactor(0.999f), 5e-3f)
        assertEquals(0f, homeViewExpandCornerRadiusFactor(1f), 1e-5f)
    }
}
