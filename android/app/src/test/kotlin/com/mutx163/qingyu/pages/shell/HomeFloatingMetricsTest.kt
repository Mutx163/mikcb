package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页浮钮 / 内容的底部避让（[HomeFloatingMetrics]）。
 *
 * 为什么单独测：这两颗钮以前各写了一个魔法数（`72dp` / `20dp`），都不认识底栏，
 * 用户真机上看到的是「按钮被导航栏盖住」。这组数字是**纯算术**，写错了编译不报、
 * 界面只是又被盖住一次 —— 只有这里能钉住。
 *
 * 判据来源：Dart `timetable_back_to_current_week_button.dart` 的
 * `max(24, glassDockPillOccupancy + 12) + viewPadding.bottom`、
 * `_backToTodayButtonBottomInset`、`_glassDockContentScrollInset`。
 */
class HomeFloatingMetricsTest {

    @Test
    fun `玻璃坞药丸占用等于底部内边距加药丸高度`() {
        // 手势导航：导航栏内边距 24 → 8 + 24 + 54 = 86。
        assertEquals(86f, HomeFloatingMetrics.dockPillOccupancyDp(24f), 0.0001f)
        // 无导航栏内边距：兜底 36 + 54 = 90（与 GlassDockNavigationBar 同口径）。
        assertEquals(90f, HomeFloatingMetrics.dockPillOccupancyDp(0f), 0.0001f)
        // 三键导航：内边距 48 → 8 + 48 + 54 = 110。
        assertEquals(110f, HomeFloatingMetrics.dockPillOccupancyDp(48f), 0.0001f)
    }

    @Test
    fun `玻璃坞形态下浮钮浮在药丸之上`() {
        // 86 + 12 = 98：钮底边落在药丸顶边（86）上方 12dp。
        assertEquals(98f, HomeFloatingMetrics.floatingButtonBottomDp(true, 24f), 0.0001f)
        // 关键回归：旧的 72dp 会落进药丸（药丸顶边 86），这就是用户报的遮挡。
        assertTrue(
            "玻璃坞形态下浮钮底边距必须大于药丸占用",
            HomeFloatingMetrics.floatingButtonBottomDp(true, 24f) >
                HomeFloatingMetrics.dockPillOccupancyDp(24f),
        )
    }

    @Test
    fun `经典形态只让开系统手势条`() {
        assertEquals(48f, HomeFloatingMetrics.floatingButtonBottomDp(false, 24f), 0.0001f)
        assertEquals(24f, HomeFloatingMetrics.floatingButtonBottomDp(false, 0f), 0.0001f)
    }

    @Test
    fun `内容避让在玻璃坞形态让到药丸顶边`() {
        assertEquals(86f, HomeFloatingMetrics.contentBottomDp(true, 24f), 0.0001f)
        assertEquals(24f, HomeFloatingMetrics.contentBottomDp(false, 24f), 0.0001f)
    }

    @Test
    fun `浮钮高度与间隙覆盖日视图列表那一段`() {
        // 38（钮高）+ 12（间隙）：日视图列表要多让这一段，最后一卡才停在钮上方。
        assertEquals(50f, HomeFloatingMetrics.BACK_TO_TODAY_SCROLL_EXTRA_DP, 0.0001f)
    }
}
