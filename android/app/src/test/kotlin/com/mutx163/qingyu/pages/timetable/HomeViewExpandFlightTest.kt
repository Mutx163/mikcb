package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页「周 → 日」摘要卡飞行的判据（2026-11-03，阶段 A）。
 *
 * 用户原话：「还是很恶心的展开效果……你看看 flutter 最新的效果，做成那个样子不行吗」。
 * 只做圆角窗口裁切时，读起来是**一块窗口从选中列擦开**；Flutter 版的主体是
 * **卡片自己从格位飞向落点**。这一批把摘要卡那一颗补上，判据钉住三件事：
 *
 * 1. **起点 = 星期栏实测格位、终点 = 摘要卡实测位置**：t=0 与 t=1 的矩形必须
 *    分别等于两端，误差 ≤1dp（不是「差不多」，不许写死比例）。
 * 2. **圆角从 14 长到真卡的 16**：终点圆角必须与 `QingyuCardDefaults.Corner` 一致，
 *    否则落定那一帧（0.999 换真卡）会看到圆角跳一下。
 * 3. **卡面在前 30% 淡入、文案在 0.45 切换**：起点格子里不能凭空冒出一张卡
 *    （那又会退回「窗口擦除」），标题也不该在卡还很小时就撑出格子。
 *
 * 为什么这些是纯函数：渲染层只允许调用它们。同一套 lerp 写在 Composable 里
 * 就没人能这样直接钉住，也挡不住后来者另写一份公式。
 */
class HomeViewExpandFlightTest {

    @Test
    fun `起点格位按星期栏实测宽度与时间列换算`() {
        // 400px 宽、40px 高、时间列 44px、7 天可见 ⇒ 日宽 (400 - 44) / 7 = 50.857…
        val header = HomeViewFlightRect(left = 0f, top = -40f, right = 400f, bottom = 0f)
        val cell = homeViewSummaryStartCell(
            header = header,
            timeColumnWidth = 44f,
            visibleDayCount = 7,
            selectedDayIndex = 3,
        )
        val expectedLeft = 44f + 3f * ((400f - 44f) / 7f)
        assertEquals(expectedLeft, cell.left, 0.01f)
        assertEquals(expectedLeft + (400f - 44f) / 7f, cell.right, 0.01f)
        // 星期栏在内容区之上 ⇒ 起点顶边必须是负的（-40dp 在 1x 密度下就是 -40px）。
        assertEquals(-40f, cell.top, 0.01f)
        assertEquals(0f, cell.bottom, 0.01f)
    }

    @Test
    fun `隐藏周末时起点按 5 天换算`() {
        val header = HomeViewFlightRect(left = 12f, top = -40f, right = 412f, bottom = 0f)
        val cell = homeViewSummaryStartCell(
            header = header,
            timeColumnWidth = 40f,
            visibleDayCount = 5,
            selectedDayIndex = 4,
        )
        assertEquals(12f + 40f + 4f * ((400f - 40f) / 5f), cell.left, 0.01f)
    }

    @Test
    fun `进度 0 恰好落在源格位`() {
        val start = HomeViewFlightRect(left = 120f, top = -40f, right = 180f, bottom = 0f)
        val end = HomeViewFlightRect(left = 14f, top = 96f, right = 386f, bottom = 220f)
        val flight = homeViewSummaryFlightRect(start, end, 0f)
        assertRectEquals(start, flight)
    }

    @Test
    fun `进度 1 恰好落在目标卡位`() {
        val start = HomeViewFlightRect(left = 120f, top = -40f, right = 180f, bottom = 0f)
        val end = HomeViewFlightRect(left = 14f, top = 96f, right = 386f, bottom = 220f)
        val flight = homeViewSummaryFlightRect(start, end, 1f)
        assertRectEquals(end, flight)
    }

    @Test
    fun `进度被夹在 0 到 1 之间`() {
        val start = HomeViewFlightRect(left = 120f, top = -40f, right = 180f, bottom = 0f)
        val end = HomeViewFlightRect(left = 14f, top = 96f, right = 386f, bottom = 220f)
        assertRectEquals(start, homeViewSummaryFlightRect(start, end, -0.5f))
        assertRectEquals(end, homeViewSummaryFlightRect(start, end, 1.5f))
    }

    @Test
    fun `中间帧严格按分量线性插值`() {
        val start = HomeViewFlightRect(left = 0f, top = -40f, right = 60f, bottom = 0f)
        val end = HomeViewFlightRect(left = 20f, top = 60f, right = 420f, bottom = 180f)
        val flight = homeViewSummaryFlightRect(start, end, 0.25f)
        assertEquals(5f, flight.left, 0.01f)
        assertEquals(-15f, flight.top, 0.01f)
        // 宽 = lerp(60, 400, 0.25) = 145。
        assertEquals(0.75f * 60f + 0.25f * 400f, flight.width, 0.01f)
        assertTrue("中间帧高度必须连续变化", flight.height > 0f)
    }

    @Test
    fun `圆角从 14 长到真卡圆角`() {
        assertEquals(HOME_VIEW_SUMMARY_FLIGHT_START_CORNER_DP, homeViewSummaryFlightCornerDp(0f), 0.01f)
        assertEquals(HOME_VIEW_SUMMARY_FLIGHT_END_CORNER_DP, homeViewSummaryFlightCornerDp(1f), 0.01f)
    }

    @Test
    fun `终点圆角必须与真卡圆角常量一致`() {
        // 落定那一帧（进度 0.999 换真摘要卡）两侧圆角不一样会看到「跳一下」。
        // 真卡圆角唯一来源：`QingyuCardDefaults.Corner` = `QingyuShapes.CARD_CORNER`
        //（`components/QingyuCard.kt:110-111`）。这里直接引用常量，改了圆角这里就红。
        assertEquals(
            "摘要卡飞行终点圆角（${HOME_VIEW_SUMMARY_FLIGHT_END_CORNER_DP}dp）" +
                "与真卡圆角（${com.mutx163.qingyu.theme.QingyuShapes.CARD_CORNER}dp）不一致",
            com.mutx163.qingyu.theme.QingyuShapes.CARD_CORNER,
            HOME_VIEW_SUMMARY_FLIGHT_END_CORNER_DP.toDouble(),
            0.01,
        )
    }

    @Test
    fun `卡面在前 30 百分比内淡入`() {
        assertEquals(0f, homeViewSummarySurfaceAlpha(0f), 0.001f)
        assertEquals(0.5f, homeViewSummarySurfaceAlpha(HOME_VIEW_SUMMARY_FLIGHT_SURFACE_RAMP / 2f), 0.05f)
        assertEquals(1f, homeViewSummarySurfaceAlpha(HOME_VIEW_SUMMARY_FLIGHT_SURFACE_RAMP), 0.001f)
        assertEquals(1f, homeViewSummarySurfaceAlpha(1f), 0.001f)
    }

    @Test
    fun `文案在 0_45 从格内日期切换为摘要卡标题`() {
        val before = homeViewSummaryDateLine(0.44f, "03/20", "10月27日 周二")
        assertEquals("03/20", before.text)
        val after = homeViewSummaryDateLine(HOME_VIEW_SUMMARY_FLIGHT_TEXT_SWITCH_AT, "03/20", "10月27日 周二")
        assertEquals("10月27日 周二", after.text)
        // 字号随进度连续长大：8.5sp → 16sp（0.44 时约 11.8sp，不是两端跳变）。
        assertEquals(8.5f, homeViewSummaryDateLine(0f, "03/20", "10月27日 周二").sizeSp, 0.001f)
        assertTrue("字号必须随进度连续变大", before.sizeSp > 8.5f && before.sizeSp < 16f)
        assertEquals(16f, homeViewSummaryDateLine(1f, "03/20", "10月27日 周二").sizeSp, 0.001f)
    }

    @Test
    fun `终点专属文案与关闭叉只在后段淡入`() {
        assertEquals(0f, homeViewSummaryMetaAlpha(0.5f), 0.001f)
        assertEquals(1f, homeViewSummaryMetaAlpha(0.95f), 0.001f)
        assertEquals(0f, homeViewSummaryCloseAlpha(0.5f), 0.001f)
        assertEquals(1f, homeViewSummaryCloseAlpha(1f), 0.001f)
    }

    private fun assertRectEquals(expected: HomeViewFlightRect, actual: HomeViewFlightRect) {
        // 「误差 ≤1dp」：单测里不做密度换算，按 1x 密度（1dp = 1px）判。
        assertEquals(expected.left, actual.left, 1f)
        assertEquals(expected.top, actual.top, 1f)
        assertEquals(expected.right, actual.right, 1f)
        assertEquals(expected.bottom, actual.bottom, 1f)
    }

}
