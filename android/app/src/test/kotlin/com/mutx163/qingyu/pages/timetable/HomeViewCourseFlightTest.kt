package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程卡逐卡飞行的纯几何/节奏单测（C-1，阶段 B）。
 *
 * 这些函数都不碰 Compose，所以端点、中点、钳制、切换点、行数/行高档位都能在这里钉死。
 * 渲染层（`TimetableCourseFlightLayer`）只许调用这些函数，不许另写插值公式。
 */
class HomeViewCourseFlightTest {

    // ────────────────────────── 矩形插值 ──────────────────────────

    @Test
    fun `矩形两端与中点逐分量 lerp`() {
        val start = HomeViewFlightRect(0f, 0f, 10f, 20f)
        val end = HomeViewFlightRect(100f, 40f, 120f, 80f)

        val at0 = homeViewCourseFlightRect(start, end, 0f)
        assertEquals(0f, at0.left, 1e-4f)
        assertEquals(0f, at0.top, 1e-4f)
        assertEquals(10f, at0.width, 1e-4f)
        assertEquals(20f, at0.height, 1e-4f)

        val at1 = homeViewCourseFlightRect(start, end, 1f)
        assertEquals(100f, at1.left, 1e-4f)
        assertEquals(40f, at1.top, 1e-4f)
        assertEquals(20f, at1.width, 1e-4f)
        assertEquals(40f, at1.height, 1e-4f)

        val mid = homeViewCourseFlightRect(start, end, 0.5f)
        assertEquals(50f, mid.left, 1e-4f)
        assertEquals(20f, mid.top, 1e-4f)
        assertEquals(15f, mid.width, 1e-4f)
        assertEquals(30f, mid.height, 1e-4f)
    }

    @Test
    fun `矩形宽高至少一像素防除零`() {
        val deg = homeViewCourseFlightRect(
            HomeViewFlightRect(0f, 0f, 0f, 0f),
            HomeViewFlightRect(0f, 0f, 0f, 0f),
            0.5f,
        )
        assertTrue(deg.width >= 1f)
        assertTrue(deg.height >= 1f)
    }

    // ────────────────────────── 圆角 / 投影 ──────────────────────────

    @Test
    fun `圆角从 8 到终点常量且单调`() {
        assertEquals(8f, homeViewCourseFlightCornerDp(0f), 1e-4f)
        assertEquals(HOME_VIEW_COURSE_FLIGHT_END_CORNER_DP, homeViewCourseFlightCornerDp(1f), 1e-4f)
        // 当前终点常量必须等于真议程卡默认圆角 16dp（改真卡要同步这条）。
        assertEquals(16f, HOME_VIEW_COURSE_FLIGHT_END_CORNER_DP, 1e-4f)
        assertTrue(homeViewCourseFlightCornerDp(0.5f) > homeViewCourseFlightCornerDp(0.4f))
        // 越界夹取。
        assertEquals(8f, homeViewCourseFlightCornerDp(-1f), 1e-4f)
        assertEquals(16f, homeViewCourseFlightCornerDp(2f), 1e-4f)
    }

    @Test
    fun `投影从 0 到 0_18`() {
        assertEquals(0f, homeViewCourseFlightShadowAlpha(0f), 1e-4f)
        assertEquals(0.18f, homeViewCourseFlightShadowAlpha(1f), 1e-4f)
        assertEquals(0.09f, homeViewCourseFlightShadowAlpha(0.5f), 1e-4f)
    }

    // ────────────────────────── 只起点 / 只终点淡出淡入 ──────────────────────────

    @Test
    fun `只起点行在 0_45 到 0_58 淡出`() {
        assertEquals(1f, homeViewCourseFlightStartOnlyAlpha(0.45f), 1e-4f)
        assertEquals(0f, homeViewCourseFlightStartOnlyAlpha(0.58f), 1e-4f)
        assertTrue(homeViewCourseFlightStartOnlyAlpha(0.4f) >= 1f)
        assertTrue(homeViewCourseFlightStartOnlyAlpha(0.6f) <= 0f)
    }

    @Test
    fun `只终点行在 0_58 到 0_85 淡入`() {
        assertEquals(0f, homeViewCourseFlightEndOnlyAlpha(0.58f), 1e-4f)
        assertEquals(1f, homeViewCourseFlightEndOnlyAlpha(0.85f), 1e-4f)
        assertTrue(homeViewCourseFlightEndOnlyAlpha(0.5f) <= 0f)
        assertTrue(homeViewCourseFlightEndOnlyAlpha(0.9f) >= 1f)
    }

    // ────────────────────────── 换文案 ──────────────────────────

    @Test
    fun `换文案点在 0_45`() {
        assertFalse(homeViewCourseFlightUsesEndText(0.44f))
        assertTrue(homeViewCourseFlightUsesEndText(0.45f))
        assertTrue(homeViewCourseFlightUsesEndText(0.9f))
    }

    // ────────────────────────── 文字档位 ──────────────────────────

    @Test
    fun `按卡数三档降级`() {
        assertEquals(HomeViewCourseFlightTextMode.FULL, homeViewCourseFlightTextMode(0))
        assertEquals(HomeViewCourseFlightTextMode.FULL, homeViewCourseFlightTextMode(10))
        assertEquals(HomeViewCourseFlightTextMode.COMPACT, homeViewCourseFlightTextMode(11))
        assertEquals(HomeViewCourseFlightTextMode.COMPACT, homeViewCourseFlightTextMode(16))
        assertEquals(HomeViewCourseFlightTextMode.SURFACE_ONLY, homeViewCourseFlightTextMode(17))
    }

    @Test
    fun `各档允许画的行`() {
        assertTrue(homeViewCourseFlightLineVisible(HomeViewCourseFlightTextMode.FULL, "name"))
        assertTrue(homeViewCourseFlightLineVisible(HomeViewCourseFlightTextMode.FULL, "weeks"))
        assertTrue(homeViewCourseFlightLineVisible(HomeViewCourseFlightTextMode.COMPACT, "name"))
        assertTrue(homeViewCourseFlightLineVisible(HomeViewCourseFlightTextMode.COMPACT, "time"))
        assertFalse(homeViewCourseFlightLineVisible(HomeViewCourseFlightTextMode.COMPACT, "teacher"))
        assertFalse(homeViewCourseFlightLineVisible(HomeViewCourseFlightTextMode.SURFACE_ONLY, "name"))
    }

    // ────────────────────────── 行数 / 行高（P1-5/6/7）──────────────────────────

    @Test
    fun `行数按换文案点在两端之间切换`() {
        // 周卡课名可 4 行、日卡课名 2 行：切换点前 4、后 2（C-1 要求）。
        assertEquals(4, homeViewCourseFlightMaxLines(4, 2, useEndText = false))
        assertEquals(2, homeViewCourseFlightMaxLines(4, 2, useEndText = true))
        assertEquals(3, homeViewCourseFlightMaxLines(3, 1, useEndText = false))
    }

    @Test
    fun `行高两端都有则插值 否则按切换点取`() {
        assertEquals(11f, homeViewCourseFlightLineHeight(10f, 12f, 0.5f), 1e-4f)
        // 周卡未指定行高（0）→ 切换点前取 0、之后取日卡 22。
        assertEquals(0f, homeViewCourseFlightLineHeight(0f, 22f, 0.1f), 1e-4f)
        assertEquals(22f, homeViewCourseFlightLineHeight(0f, 22f, 0.9f), 1e-4f)
    }

    // ────────────────────────── 卡键四元 ──────────────────────────

    @Test
    fun `卡键是四周日课id起始节四元`() {
        assertEquals("3|5|c1|2", courseFlightCardKey(3, 5, "c1", 2))
    }

    @Test
    fun `卡键越界起始节规整到至少1`() {
        // P-5：脏数据（≤0）两端都要收敛到 1，否则周/日 key 会不等。
        assertEquals(courseFlightCardKey(3, 5, "c1", 1), courseFlightCardKey(3, 5, "c1", 0))
        assertEquals(courseFlightCardKey(3, 5, "c1", 1), courseFlightCardKey(3, 5, "c1", -2))
    }

    // ────────────────────────── 负例自测（P-1：咬合探针，证明断言有牙齿）──────────────────────────

    @Test
    fun `负例自测_终点常量若改回20会与真卡不符被判红`() {
        // 断言逻辑：真议程卡半径是 16。若把常量误改回 20，这条「相等」断言必红。
        fun matchesAgendaCard(endDp: Float): Boolean = endDp == HOME_VIEW_COURSE_FLIGHT_END_CORNER_DP
        assertTrue("常量 16 必须与真卡一致", matchesAgendaCard(16f))
        assertFalse("20 不是真卡半径，应被判不符", matchesAgendaCard(20f))
    }
}
