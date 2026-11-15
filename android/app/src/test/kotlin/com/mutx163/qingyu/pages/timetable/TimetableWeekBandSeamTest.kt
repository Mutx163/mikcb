package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 周视图「带下沿缝」几何测试（2026-11-15）。
 *
 * 用户口径：日视图玻璃底下的课卡边缘是正常好看的模糊，周视图很奇怪；切周/日视图
 * 顶栏玻璃的颜色还会变。根因是**周视图第 1 节课卡紧贴带下沿**，而玻璃第二遍玻璃
 * 比带子多录 24dp（`TIMETABLE_BAND_STRIP_MARGIN_DP`）：
 *
 * - 那 24dp 正好录到第 1 节的彩色课卡 ⇒ 带子下半截被卡片染色，切视图时颜色跟着变；
 * - 卡片被带下沿横切 ⇒ 玻璃里是糊过的卡，玻璃底下还透着一份锐利的卡边。
 *
 * 修法：带下沿留一道与日视图 `DAY_VIEW_TOP_SEAM_DP` **同一个常数**的缝，缝只加在
 * 留白里、不参与节高基准（[weekGridSectionBasisDp]）。
 *
 * 本测试钉两件事：① 缝真的画出来、且排在带高留白之后；② 缝的取值来自日视图那个
 * 常数，不许在周页另写一个 14；③ 节高基准只减下穿带高、不减缝。
 */
class TimetableWeekBandSeamTest {

    @Test
    fun `缝只在带子画玻璃时生效 且取值来自日视图同一常数`() {
        val source = weekPageSource()
        assertTrue(
            "周页没有把带下沿缝交给 WeekPageContent —— 第 1 节课卡又会紧贴带下沿，" +
                "玻璃下半截重新被课卡染色。",
            Regex("""topSeamDp\s*=\s*if \(bandStripActive\)\s*DAY_VIEW_TOP_SEAM_DP\.dp\s*else\s*0\.dp""")
                .containsMatchIn(source),
        )
        assertSourceContains(source, "DAY_VIEW_TOP_SEAM_DP.dp", WEEK_PAGE_PATH)
    }

    @Test
    fun `缝必须排在带高留白之后 且真的画出来`() {
        val source = weekPageSource()
        val bandSpacer = "Spacer(modifier = Modifier.height(underlapHeightDp))"
        val seamSpacer = "Spacer(modifier = Modifier.height(topSeamDp))"
        assertSourceContains(source, seamSpacer, WEEK_PAGE_PATH)
        assertSourceContains(source, bandSpacer, WEEK_PAGE_PATH)
        assertTrue(
            "带下沿缝排在了带高留白之前 —— 缝会落在带子底下被吃掉，第 1 节仍紧贴带下沿。",
            source.indexOf(seamSpacer) > source.indexOf(bandSpacer),
        )
        assertSourceContains(source, "topSeamDp: Dp = 0.dp", WEEK_PAGE_PATH)
    }

    @Test
    fun `日视图那道缝仍是 14dp`() {
        assertSourceContains(
            daySource(),
            "internal const val DAY_VIEW_TOP_SEAM_DP = 14f",
            DAY_SCROLL_CONTENT_PATH,
        )
    }

    @Test
    fun `节高基准只减下穿带高 不减缝`() {
        // 盒子 800、带高 94：可见网格区 = 706。若把 14dp 的缝也减掉，会得到 692，
        // 每节矮 14dp，一屏十几节累积出一条底部空带。
        assertEquals(706f, weekGridSectionBasisDp(contentHeightDp = 800f, bandUnderlapDp = 94f), 1e-4f)
        // 没下穿（预览 / 无玻璃 / 首帧带高还没量出来）：基准就是盒子高。
        assertEquals(800f, weekGridSectionBasisDp(contentHeightDp = 800f, bandUnderlapDp = 0f), 1e-4f)
        // 下穿比盒子还高（异常值）：不出负数。
        assertEquals(0f, weekGridSectionBasisDp(contentHeightDp = 100f, bandUnderlapDp = 140f), 1e-4f)
        // 盒子高异常为负：不出负数。
        assertEquals(0f, weekGridSectionBasisDp(contentHeightDp = -20f, bandUnderlapDp = 0f), 1e-4f)
    }

    /** 走共享剥离器（R21 口径）：不剥注释的读法会被「把目标行注释掉」静默骗绿。 */
    private fun weekPageSource(): String = readKotlinSourceNoStrings(WEEK_PAGE_PATH)

    private fun daySource(): String = readKotlinSourceNoStrings(DAY_SCROLL_CONTENT_PATH)

    private companion object {
        const val WEEK_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
        const val DAY_SCROLL_CONTENT_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewScrollContent.kt"
    }
}
