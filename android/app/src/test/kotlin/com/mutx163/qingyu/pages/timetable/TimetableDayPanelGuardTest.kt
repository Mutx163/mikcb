package com.mutx163.qingyu.pages.timetable

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页「日 ↔ 周」切换对齐**已发布 2141（tag v2.1.4.1）简单面板**的源码守卫。
 *
 * 2141 的形态：周网格 `alpha=1-value` 淡出；日面板一整块按
 * `progress=easeInOutCubicEmphasized`、`widthFactor=0.18+0.82*progress`、
 * `heightFactor=max(0.04,progress)`、`translateY=(1-progress)*(-24)`、`opacity=easeOutCubic`、
 * 从当天列顶部锚点裁剪窗口长大。**无逐卡飞行、无窗口裁切、无缩放**。
 *
 * 防守的是「又退回被否掉的复杂做法」：逐卡飞行层 / 窗口裁切 / graphicsLayer 缩放 / 自研转场 API。
 */
class TimetableDayPanelGuardTest {

    private val weekPage: String by lazy { strip(read(WEEK_PAGE)) }
    private val motion: String by lazy { strip(read(MOTION)) }

    @Test
    fun `面板公式在场`() {
        val s = weekPage
        assertTrue("缺 widthFactor = 0.18 + 0.82*progress", s.contains("0.18f + 0.82f * progress"))
        assertTrue("缺 heightFactor = max(0.04, progress)", s.contains("max(0.04f, progress)"))
        assertTrue("缺 translateY = (1-progress)*(-24)", s.contains("(1f - progress) * (-24f)"))
        assertTrue("缺 opacity = easeOutCubic(progress)", s.contains("homeViewEaseOutCubic(progress)"))
        assertTrue("缺面板曲线 easeInOutCubicEmphasized", s.contains("homeViewEaseInOutCubicEmphasized"))
        assertTrue("周网格缺 alpha = 1 - value", s.contains("1f - dayExpand.value"))
        assertTrue(
            "缺圆角收束 28f * homeViewExpandCornerRadiusFactor（线性 28*(1-progress) 是被否做法）",
            s.contains("homeViewExpandCornerRadiusFactor(progress)"),
        )
    }

    @Test
    fun `无飞行层无裁切窗无缩放`() {
        val s = weekPage
        listOf(
            "TimetableCourseFlightLayer",
            "DayViewSummaryFlightLayer",
            "homeViewExpandWindow",
            "clipPath(",
            "scaleX",
            "scaleY",
        ).forEach { forbidden ->
            assertFalse("又出现被否掉的旧做法：`$forbidden`", s.contains(forbidden))
        }
    }

    @Test
    fun `不自研转场 API`() {
        for (src in listOf(weekPage, motion)) {
            assertFalse("出现 AnimatedContent（自研转场）", src.contains("AnimatedContent"))
            assertFalse("出现 slideIn（自研滑入）", src.contains("slideIn"))
            assertFalse("出现 fadeIn（自研淡入）", src.contains("fadeIn"))
        }
    }

    // 咬合探针（负例自测）：证明上面的判据有牙齿。
    @Test
    fun `负例自测_改回缩放或旧飞行或裁切会被判红`() {
        fun ok(s: String): Boolean =
            s.contains("0.18f + 0.82f * progress") &&
                s.contains("max(0.04f, progress)") &&
                !s.contains("scaleX") &&
                !s.contains("scaleY") &&
                !s.contains("TimetableCourseFlightLayer") &&
                !s.contains("clipPath(") &&
                !s.contains("homeViewExpandWindow")
        assertTrue("真实源码应通过", ok(weekPage))
        assertFalse("改成 graphicsLayer 缩放应判红", ok(weekPage + "\n val scaleX = 1f"))
        assertFalse("恢复逐卡飞行层应判红", ok(weekPage + "\n TimetableCourseFlightLayer("))
        assertFalse("恢复窗口裁切 clipPath 应判红", ok(weekPage + "\n clipPath(x)"))
        assertFalse("恢复 homeViewExpandWindow 应判红", ok(weekPage + "\n homeViewExpandWindow(p)"))
        assertFalse(
            "heightFactor 退化应判红",
            ok(weekPage.replace("max(0.04f, progress)", "progress")),
        )
    }

    private fun read(rel: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, rel)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        throw AssertionError("找不到 $rel —— 守卫无法验证，按失败处理")
    }

    private fun strip(src: String): String =
        Regex("/\\*[\\s\\S]*?\\*/").replace(src, " ")
            .lineSequence().joinToString("\n") { it.substringBefore("//") }

    private companion object {
        const val WEEK_PAGE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
        const val MOTION =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/HomeViewExpandMotion.kt"
    }
}
