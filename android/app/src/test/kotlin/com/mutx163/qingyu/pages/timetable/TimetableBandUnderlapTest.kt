package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 「周网格钻进玻璃带底下」录制条带的契约（2026-11-08）。
 *
 * 钉两件事：条带 = 带高 + 下沿余量（给高斯核 / 折射位移留料），且永远不超出录制
 * 节点自身高度、带子没量出来时不录（返回 0 ⇒ 整段不挂）。
 */
class TimetableBandUnderlapTest {

    @Test
    fun `带子没量出来时不录`() {
        assertEquals(0, timetableBandStripPx(bandHeightPx = 0, marginPx = 72, contentHeightPx = 2400))
    }

    @Test
    fun `负的带高按不录处理`() {
        assertEquals(0, timetableBandStripPx(bandHeightPx = -20, marginPx = 72, contentHeightPx = 2400))
    }

    @Test
    fun `条带等于带高加下沿余量`() {
        assertEquals(420, timetableBandStripPx(bandHeightPx = 348, marginPx = 72, contentHeightPx = 2400))
    }

    @Test
    fun `条带不得超出录制节点高度`() {
        assertEquals(500, timetableBandStripPx(bandHeightPx = 480, marginPx = 72, contentHeightPx = 500))
    }

    @Test
    fun `负余量按零处理`() {
        assertEquals(300, timetableBandStripPx(bandHeightPx = 300, marginPx = -40, contentHeightPx = 2400))
    }

    @Test
    fun `录制节点高度为0时条带为0`() {
        assertEquals(0, timetableBandStripPx(bandHeightPx = 300, marginPx = 72, contentHeightPx = 0))
    }

    @Test
    fun `余量常量取值契约`() {
        // 24dp 覆盖 blur 的采样外扩与 lens 的位移（≤8dp）；改值必须是有意的。
        assertEquals(24f, TIMETABLE_BAND_STRIP_MARGIN_DP)
    }
}
