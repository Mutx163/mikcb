package com.mutx163.qingyu.pages.timetable.month

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 月视图**字阶 / 墨色 / 栅格**的守卫（对应 Dart `test/utils/month_metrics_test.dart` 的口径）。
 *
 * 这一页曾经的现场：9 级字号（9 / 9.5 / 11 / 11.5 / 12 / 12.5 / 13 / 13.5 / 14 / 15 /
 * 16 / 17 / 21）与四条左线（11.7 / 13.5 / 14.1 / 17.2），半像素字号与差 1~5dp 的轴线
 * 让层级完全不可预期。这些用例就是「别再散回去」的钉子。
 */
class MonthMetricsTest {

    // ------------------------------------------------------------------
    // 字阶
    // ------------------------------------------------------------------

    @Test
    fun `字阶只有 5 级且全部落在官方字级上`() {
        val ladder = MonthType.ladder
        assertEquals("字阶级数", 5, ladder.size)
        requireLadder(ladder)
    }

    /**
     * 咬合探针：把「半档字号」塞回阶梯，[requireLadder] 必须红。
     *
     * 12.5 / 15 / 22 都不在 Miuix 官方字级里（旧实现真实用过 12.5 与 15/22，
     * 但它们分别来自 body2/title3 的误标），不验这一步，守卫会退化成摆设。
     */
    @Test
    fun `咬合探针_字阶守卫能抓住半档字号混入`() {
        val regressed = listOf(11.0, 12.5, 15.0, 18.0, 22.0)
        assertThrows(AssertionError::class.java) { requireLadder(regressed) }
        // 同一判据对真实阶梯放行。
        requireLadder(MonthType.ladder)
    }

    /**
     * 字阶守卫：**只许 Miuix 官方字级 + 严格递增**。
     *
     * 旧规则是「相邻比 ≥1.15」，但官方字库里 13→14（1.08）、18→20（1.11）都达不到；
     * 那条规则逼着代码把 14 写成 15、20 写成 22，结果规格与上屏永久脱节。
     * 现在守的是「不许自己发明字号」，层级由字重（BOLD / SEMIBOLD / 常规）补。
     */
    private fun requireLadder(ladder: List<Double>) {
        val official = setOf(11.0, 13.0, 14.0, 16.0, 17.0, 18.0, 20.0, 24.0, 32.0)
        ladder.forEach { size ->
            assertTrue("字阶 $size 不是 Miuix 官方字级（半档字号会重新制造层级噪声）", official.contains(size))
        }
        ladder.zipWithNext().forEach { (small, large) ->
            assertTrue("字阶必须严格递增：$small → $large", large > small)
        }
    }

    @Test
    fun `字阶严格递增且各档语义固定`() {
        val ladder = MonthType.ladder
        assertEquals(ladder.sorted(), ladder)
        assertEquals(11.0, MonthType.CAPTION, 0.0)
        assertEquals(13.0, MonthType.BODY, 0.0)
        assertEquals(14.0, MonthType.TITLE, 0.0)
        assertEquals(18.0, MonthType.DAY_NUMBER, 0.0)
        assertEquals(20.0, MonthType.DISPLAY, 0.0)
    }

    @Test
    fun `周次轨复用 caption 字号 不是第七级`() {
        // 40dp 列宽扣 4dp 右留白 = 36dp，11sp 的「第 17 周」约 33dp，一行放得下；
        // 真放不下时由 WeekRailLabel 等比缩小——那是渲染兜底，不是新增字级。
        assertEquals(MonthType.CAPTION, MonthType.RAIL, 0.0)
        assertTrue(MonthType.ladder.contains(MonthType.RAIL))
    }

    // ------------------------------------------------------------------
    // 墨色
    // ------------------------------------------------------------------

    @Test
    fun `墨色只有 5 档且从深到浅`() {
        val levels = MonthInk.levels
        assertEquals("墨色档数", 5, levels.size)
        assertEquals(levels.sortedDescending(), levels)
        assertEquals(levels.distinct().size, levels.size)
        assertEquals(1.0, MonthInk.PRIMARY, 0.0)
    }

    @Test
    fun `只有前 3 档可以写字 hairline 与 fill 是纯非文字档`() {
        val textLevels = MonthInk.textLevels
        assertEquals(3, textLevels.size)
        assertEquals(listOf(MonthInk.PRIMARY, MonthInk.SECONDARY, MonthInk.TERTIARY), textLevels)
        assertFalse(textLevels.contains(MonthInk.HAIRLINE))
        assertFalse(textLevels.contains(MonthInk.FILL))
        // 文字档与非文字档不重叠：拿 6% 当正文色就是「看不见」。
        assertTrue(MonthInk.HAIRLINE < MonthInk.TERTIARY)
        assertTrue(MonthInk.FILL < MonthInk.HAIRLINE)
        // 五档 = 三档文字 + 两档非文字，没有第六档藏在别处。
        assertEquals(
            MonthInk.levels.toSet(),
            (textLevels + MonthInk.HAIRLINE + MonthInk.FILL).toSet(),
        )
    }

    @Test
    fun `副行档与表头档之间留出可辨间距 0_15`() {
        // 旧实现这里有 0.55/0.62/0.66/0.70/0.72 五档几乎看不出差别却各管一种语义。
        val gap = MonthInk.SECONDARY - MonthInk.TERTIARY
        assertTrue("次级墨与三级墨只差 $gap，读起来是同一档", gap >= 0.10)
    }

    // ------------------------------------------------------------------
    // 左轴与栅格
    // ------------------------------------------------------------------

    @Test
    fun `左轴由外沿加内边距推出 不另写一个数`() {
        requireAxisInset(
            axisInset = MonthMetrics.AXIS_INSET,
            cardInset = MonthMetrics.CARD_INSET,
            cardPadding = MonthMetrics.CARD_PADDING,
        )
    }

    /** 咬合探针：多写一条轴线（旧实现 4 条：11.7 / 13.5 / 14.1 / 17.2）时必须红。 */
    @Test
    fun `咬合探针_左轴守卫能抓住多写的一条轴线`() {
        assertThrows(AssertionError::class.java) {
            requireAxisInset(axisInset = 15.7, cardInset = 8.0, cardPadding = 14.0)
        }
        requireAxisInset(
            axisInset = MonthMetrics.AXIS_INSET,
            cardInset = MonthMetrics.CARD_INSET,
            cardPadding = MonthMetrics.CARD_PADDING,
        )
    }

    private fun requireAxisInset(axisInset: Double, cardInset: Double, cardPadding: Double) {
        assertEquals(
            "左轴 ≠ 卡片外沿 + 卡内内边距",
            axisInset,
            cardInset + cardPadding,
            1e-9,
        )
    }

    @Test
    fun `网格内边距必须从卡片内沿再让一格缝`() {
        assertEquals(
            MonthMetrics.AXIS_INSET - MonthMetrics.CELL_GAP,
            MonthMetrics.GRID_HORIZONTAL_PADDING,
            1e-9,
        )
        // 关键：GRID_INNER_PADDING 不是 CELL_GAP（写成 1.5 会让表头贴着卡片圆角）。
        assertEquals(
            MonthMetrics.GRID_HORIZONTAL_PADDING - MonthMetrics.CARD_INSET,
            MonthMetrics.GRID_INNER_PADDING,
            1e-9,
        )
        assertTrue(
            "卡片内边距被写成了格缝：${MonthMetrics.GRID_INNER_PADDING}",
            MonthMetrics.GRID_INNER_PADDING > MonthMetrics.CELL_GAP * 2,
        )
        // 卡片内左沿与日期数字的左沿是同一条线（都落在 AXIS_INSET 再让一格缝上）。
        assertEquals(
            MonthMetrics.AXIS_INSET - MonthMetrics.CELL_GAP,
            MonthMetrics.CARD_INSET + MonthMetrics.GRID_INNER_PADDING,
            1e-9,
        )
    }

    @Test
    fun `标记槽位高度恒等于间距加标记高`() {
        assertEquals(
            MonthMetrics.DAY_NUMBER_MARK_GAP + MonthMetrics.CELL_MARK_HEIGHT,
            MonthMetrics.CELL_MARK_SLOT_HEIGHT,
            1e-9,
        )
        assertTrue(MonthMetrics.CELL_MARK_SLOT_HEIGHT > MonthMetrics.CELL_MARK_HEIGHT)
    }

    @Test
    fun `日期格行高按宽度决定 目标是正方形`() {
        // 393dp 屏、周次列 40：可用 393 − 2×20.5 − 40 = 312 → 格宽 44.571…
        val width = 393.0
        val usable = width - 2 * MonthMetrics.GRID_HORIZONTAL_PADDING - 40.0
        assertEquals(usable / 7.0, MonthMetrics.gridRowHeight(width, 40.0), 1e-9)
        assertEquals(312.0 / 7.0, MonthMetrics.gridRowHeight(width, 40.0), 1e-9)
    }

    @Test
    fun `周次列不占位时格子更宽 但绝不返回负数`() {
        val withRail = MonthMetrics.gridRowHeight(360.0, 40.0)
        val withoutRail = MonthMetrics.gridRowHeight(360.0, 0.0)
        assertTrue(withoutRail > withRail)
        assertEquals(0.0, MonthMetrics.gridRowHeight(0.0, 40.0), 1e-9)
        assertEquals(0.0, MonthMetrics.gridRowHeight(10.0, 40.0), 1e-9)
    }

    // ------------------------------------------------------------------
    // 版面契约
    // ------------------------------------------------------------------

    @Test
    fun `卡顶导航行 40 与周_日视图顶栏同高`() {
        // 用户 2026-10-20 报过「为什么和日视图周视图的顶栏不一样高」。
        assertEquals(40.0, MonthMetrics.CALENDAR_NAV_HEIGHT, 0.0)
    }

    @Test
    fun `日历卡圆角比信息卡大一级 外大内小`() {
        assertTrue(MonthMetrics.CALENDAR_CARD_RADIUS > MonthMetrics.CARD_RADIUS)
        // 日期格圆角必须明显小于卡片圆角：20 会把 ~44dp 的格子削成圆形（旧实现「一排药丸」）。
        assertTrue(MonthMetrics.CELL_RADIUS < MonthMetrics.CARD_RADIUS)
        assertTrue(MonthMetrics.CELL_RADIUS < 20.0)
    }

    /**
     * 日历卡「非表格」高度 = 导航 40 + 分隔线 1 + 拉杆区 26 = 67（Dart `cardChrome`）。
     *
     * ⚠️ 为什么不直接断言 `MonthCalendarChrome.CARD_CHROME`：那个常量在
     * `src/composeP1` 源集里，而本测试源集是**所有变体共用**的（`:app:testProdDebugUnitTest`
     * 也要编它），引用 composeP1 的类会让 prod 变体的测试编译直接红。
     * L0 只编 `main/` + `test/`，所以这里钉住 L0 能看见的两端（40 / 26）与分隔线 1，
     * 任何一段被改（或有人把 40 改成 41），这条先红，不用等真机上「贴边/溢出」。
     *
     * 另外：`MonthCalendarChrome.CARD_CHROME` 是这三段的**和**（不是另写的字面量），
     * 所以它不会与这三段脱节；风险只在「三段本身和 Dart 不一致」，正是本用例覆盖的。
     */
    @Test
    fun `日历卡非表格高度 40 加 1 加 26 等于 67`() {
        assertEquals(40.0, MonthMetrics.CALENDAR_NAV_HEIGHT, 0.0)
        assertEquals(26.0, MonthMetrics.CALENDAR_HANDLE_HEIGHT, 0.0)
        requireCardChrome(
            navHeight = MonthMetrics.CALENDAR_NAV_HEIGHT,
            dividerHeight = 1.0,
            handleAreaHeight = MonthMetrics.CALENDAR_HANDLE_HEIGHT,
        )
    }

    /** 咬合探针：把分隔线改成 2（旧 Dart 版本曾误算过一段）时，67 的判据必须红。 */
    @Test
    fun `咬合探针_卡片高度账能抓住多算的一段`() {
        assertThrows(AssertionError::class.java) {
            requireCardChrome(navHeight = 40.0, dividerHeight = 2.0, handleAreaHeight = 26.0)
        }
        requireCardChrome(navHeight = 40.0, dividerHeight = 1.0, handleAreaHeight = 26.0)
    }

    private fun requireCardChrome(
        navHeight: Double,
        dividerHeight: Double,
        handleAreaHeight: Double,
    ) {
        assertEquals(
            "日历卡非表格高度（导航 + 分隔线 + 拉杆区）必须等于 Dart cardChrome = 67",
            67.0,
            navHeight + dividerHeight + handleAreaHeight,
            1e-9,
        )
    }

    @Test
    fun `收起态按可用高度反推行数 至少留 1 行`() {
        assertEquals(1, MonthMetrics.upcomingRowCapacity(0.0))
        assertEquals(1, MonthMetrics.upcomingRowCapacity(10.0))
        assertEquals(3, MonthMetrics.upcomingRowCapacity(MonthMetrics.UPCOMING_ROW_HEIGHT * 3))
        assertEquals(4, MonthMetrics.upcomingRowCapacity(MonthMetrics.UPCOMING_ROW_HEIGHT * 4 + 1))
    }
}
