package com.mutx163.qingyu.pages.timetable

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页「日 ↔ 周」切换对齐已发布 2141 实机观感（tag v2.1.4.1）的源码守卫。
 *
 * 实机观感：壁纸是页面级共享静态底、不动；日视图内容/课程卡**全宽、从顶部往下展开**
 * （heightFactor 0.04→1 的高度 reveal + 淡入 + 圆角收束；**不做垂直位移**，否则会带动壁纸）。
 * **无逐卡飞行、无窗口裁切、无横向列锚点/宽度收缩、无垂直位移、无 graphicsLayer 缩放。**
 */
class TimetableDayPanelGuardTest {

    private val weekPage: String by lazy { strip(read(WEEK_PAGE)) }
    private val motion: String by lazy { strip(read(MOTION)) }

    @Test
    fun `面板公式在场`() {
        val s = weekPage
        assertTrue("缺 heightFactor = max(0.04, progress)", s.contains("max(0.04f, progress)"))
        assertTrue("缺 opacity = easeOutCubic(progress)", s.contains("homeViewEaseOutCubic(progress)"))
        assertTrue("缺面板曲线 easeInOutCubicEmphasized", s.contains("homeViewEaseInOutCubicEmphasized"))
        assertTrue("周网格缺 alpha = 1 - value", s.contains("1f - dayExpand.value"))
        assertTrue(
            "缺圆角收束 homeViewExpandCornerRadiusFactor",
            s.contains("homeViewExpandCornerRadiusFactor(progress)"),
        )
        assertTrue(
            "缺全宽（.width(maxW) 或 fillMaxWidth）",
            s.contains(".width(maxW)") || s.contains("fillMaxWidth()"),
        )
        assertTrue("缺顶部对齐 Alignment.TopCenter（从上往下展开）", s.contains("Alignment.TopCenter"))
    }

    @Test
    fun `全宽从上往下_无列锚点无缩放无飞行无裁切窗`() {
        val s = weekPage
        listOf(
            "TimetableCourseFlightLayer",
            "DayViewSummaryFlightLayer",
            "homeViewExpandWindow",
            "clipPath(",
            "scaleX",
            "scaleY",
            "BiasAlignment(",
            "widthFactor",
            "translateY",
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
    fun `负例自测_改回列锚点或缩放或旧飞行或裁切会被判红`() {
        fun ok(s: String): Boolean =
            s.contains("max(0.04f, progress)") &&
                s.contains("Alignment.TopCenter") &&
                !s.contains("scaleX") &&
                !s.contains("scaleY") &&
                !s.contains("TimetableCourseFlightLayer") &&
                !s.contains("clipPath(") &&
                !s.contains("homeViewExpandWindow") &&
                !s.contains("BiasAlignment(") &&
                !s.contains("widthFactor") &&
                !s.contains("translateY")
        assertTrue("真实源码应通过", ok(weekPage))
        assertFalse("改成 graphicsLayer 缩放应判红", ok(weekPage + "\n val scaleX = 1f"))
        assertFalse("恢复逐卡飞行层应判红", ok(weekPage + "\n TimetableCourseFlightLayer("))
        assertFalse("恢复窗口裁切 clipPath 应判红", ok(weekPage + "\n clipPath(x)"))
        assertFalse("恢复 homeViewExpandWindow 应判红", ok(weekPage + "\n homeViewExpandWindow(p)"))
        assertFalse("退回当天列锚点 BiasAlignment 应判红", ok(weekPage + "\n BiasAlignment(a, -1f)"))
        assertFalse("退回宽度收缩 widthFactor 应判红", ok(weekPage + "\n val widthFactor = 1f"))
        assertFalse("日面板垂直位移（会带动壁纸上下动）应判红", ok(weekPage + "\n val translateY = 5f"))
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
