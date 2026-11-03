package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 顶栏玻璃带「底边折射」夹具的契约（2026-11-03）。
 *
 * 钉三件事：位移拖到 0 ⇒ 严格零折射；作用带被压进交界窄带（≤8dp）且不超出带盒；
 * 位移量被压到 ≤8dp——滑杆拖多大都跑不出这个范围，交界以外的画面保持与下方内容连续。
 */
class TimetableBandRefractionTest {

    @Test
    fun `位移量为0时严格零折射`() {
        val r = timetableBandRefraction(
            bandBoxHeightDp = 60f,
            requestedBandDp = 8f,
            requestedAmountDp = 0f,
        )
        assertEquals(0f, r.bandDp)
        assertEquals(0f, r.amountDp)
    }

    @Test
    fun `负位移按零处理`() {
        val r = timetableBandRefraction(60f, requestedBandDp = 8f, requestedAmountDp = -3f)
        assertEquals(0f, r.bandDp)
        assertEquals(0f, r.amountDp)
    }

    @Test
    fun `作用带被夹具压住_超大值也不能超过上限`() {
        val r = timetableBandRefraction(
            bandBoxHeightDp = 60f,
            requestedBandDp = 24f, // 滑杆历史最大值
            requestedAmountDp = 6f,
        )
        assertEquals(TIMETABLE_BAND_REFRACTION_MAX_BAND_DP, r.bandDp)
        assertEquals(6f, r.amountDp)
    }

    @Test
    fun `位移量被夹具压住`() {
        val r = timetableBandRefraction(
            bandBoxHeightDp = 60f,
            requestedBandDp = 8f,
            requestedAmountDp = 20f, // 滑杆历史最大值
        )
        assertEquals(TIMETABLE_BAND_REFRACTION_MAX_AMOUNT_DP, r.amountDp)
    }

    @Test
    fun `作用带不得超出带盒高度`() {
        val r = timetableBandRefraction(
            bandBoxHeightDp = 5f,
            requestedBandDp = 8f,
            requestedAmountDp = 6f,
        )
        assertEquals(5f, r.bandDp)
    }

    @Test
    fun `正常值原样透传`() {
        val r = timetableBandRefraction(60f, requestedBandDp = 6f, requestedAmountDp = 6f)
        assertEquals(6f, r.bandDp)
        assertEquals(6f, r.amountDp)
    }

    @Test
    fun `作用带非正时零折射`() {
        val r = timetableBandRefraction(60f, requestedBandDp = 0f, requestedAmountDp = 6f)
        assertEquals(0f, r.bandDp)
        assertEquals(0f, r.amountDp)
    }

    @Test
    fun `上限常量取值契约`() {
        // 8dp 级别的窄带是「交界以外画面连续」的几何前提（位移 ≤8dp 时恰好容纳
        // 一个完整位移周期）；改值必须是有意的。
        assertEquals(8f, TIMETABLE_BAND_REFRACTION_MAX_BAND_DP)
        assertEquals(8f, TIMETABLE_BAND_REFRACTION_MAX_AMOUNT_DP)
    }
}
