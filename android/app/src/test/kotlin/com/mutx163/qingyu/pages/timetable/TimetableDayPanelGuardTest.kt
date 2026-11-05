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
    private val dayPage: String by lazy { strip(read(DAY_PAGE)) }

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

    // ── ① 去掉周页 alpha 离屏层：只在日视图可见/过渡（dayVisible）时挂，普通周浏览不挂 ──
    @Test
    fun `① 周页 alpha 离屏层仅日可见时挂`() {
        fun okAlpha(s: String): Boolean =
            // 旧的「无条件」离屏层两处都不得回归
            !s.contains(".graphicsLayer { alpha = (1f - dayExpand.value).coerceIn(0f, 1f) },") &&
                !s.contains(".graphicsLayer { alpha = 1f },") &&
                // 2141 淡出层本身要保留（只是被 dayVisible 门控到 else 分支）
                s.contains("1f - dayExpand.value") &&
                // 精确钉「门控结构」：外层 `when` 的首支必须是 `!dayVisible -> Modifier`
                //（旧判据 `contains("if (dayVisible)")` 会被无关的 hitGate `if (dayVisible)` 误命中）
                s.contains("!dayVisible -> Modifier")
        assertTrue("真实源码应通过（离屏层受 dayVisible 门控、淡出层仍在）", okAlpha(weekPage))
        assertFalse(
            "回归无条件外层 alpha 离屏层应判红（整块 pager 每帧离屏→左右滑卡顿）",
            okAlpha(weekPage + "\n .graphicsLayer { alpha = (1f - dayExpand.value).coerceIn(0f, 1f) },"),
        )
        assertFalse(
            "回归无条件每页 alpha 离屏层应判红（每页一层离屏）",
            okAlpha(weekPage + "\n .graphicsLayer { alpha = 1f },"),
        )
        assertFalse(
            "门控结构退化（丢了 !dayVisible -> Modifier）应判红",
            okAlpha(weekPage.replace("!dayVisible -> Modifier", "dayVisible -> Modifier")),
        )
    }

    // ── ② 嵌入日视图不画自己壁纸、吃页面级预糊层（壁纸不随展开层移动）──
    @Test
    fun `② 嵌入日页不画自己壁纸_吃页面级预糊层`() {
        val w = weekPage
        val d = dayPage
        assertTrue(
            "TimetableWeekPage 未把页面级预糊层经 CompositionLocal 交给嵌入日视图",
            w.contains("LocalEmbeddedDayGlassBackdrop provides cardGlassSource"),
        )
        assertTrue(
            "DayViewPage 缺嵌入判据 embeddedInHomePanel",
            d.contains("val embeddedInHomePanel = contentTopInset != null"),
        )
        assertTrue("嵌入日视图没跳过自己的壁纸层", d.contains("if (backdrop != null && !embeddedInHomePanel)"))
        assertTrue("嵌入日视图没跳过本地预糊层", d.contains("if (cardPreblurActive && !embeddedInHomePanel)"))
        assertTrue("嵌入日视图 cardGlassSource 未改吃 embeddedGlass", d.contains("embeddedInHomePanel -> embeddedGlass"))
    }

    @Test
    fun `负例自测_嵌入日页若又画自己壁纸应红`() {
        fun okEmbedded(d: String): Boolean =
            d.contains("if (backdrop != null && !embeddedInHomePanel)") &&
                !d.contains("if (backdrop != null) {")
        assertTrue("真实源码应通过", okEmbedded(dayPage))
        assertFalse(
            "退回「嵌入也画自己壁纸」应判红",
            okEmbedded(dayPage.replace("if (backdrop != null && !embeddedInHomePanel)", "if (backdrop != null)")),
        )
    }

    // ── ③ 展开层读数时机：几何/透明度必须在测量期、绘制期读，不能回到组合期 ──
    //
    // 2026-11-05：原先组合期就把 `dayExpand.value` 换算成 heightFactor / cornerDp / panelAlpha，
    // 360ms 转场里整棵子树逐帧重组重测。改成「高度在 layout 块、圆角在 graphicsLayer 的 shape、
    // alpha 走 derivedStateOf 委托且只在 graphicsLayer 里取值」。
    // 上面 `面板公式在场` 只钉公式字面量，分不清读数时机 —— 这条专门钉形态，
    // 免得将来又被人写回组合期而守卫无感。
    @Test
    fun `展开层读数时机后移到测量与绘制期`() {
        fun ok(s: String): Boolean =
            s.contains("private fun Modifier.expandPanelGeometry(") &&
                // 高度：在 layout 的 measure 块里读进度
                s.contains("val heightPx = (maxHeight * max(0.04f, progress)).roundToPx()") &&
                // 圆角：在 graphicsLayer 的 shape 里读进度
                s.contains("shape = RoundedCornerShape((28f * homeViewExpandCornerRadiusFactor(progress)).dp)") &&
                // alpha：derivedStateOf 委托 + 只在绘制层取值
                s.contains("val panelAlpha by") &&
                s.contains("derivedStateOf {") &&
                s.contains("graphicsLayer { alpha = panelAlpha }") &&
                // 反向：不得出现组合期直接求值的老形态
                !s.contains("val panelAlpha = homeViewEaseOutCubic(") &&
                !s.contains("val cornerDp = 28f * homeViewExpandCornerRadiusFactor(")

        assertTrue("真实源码应通过（读数已后移到测量/绘制期）", ok(weekPage))

        // 咬合探针：四种回退各判红一次，证明判据有牙齿而不是空判
        assertFalse(
            "alpha 回到组合期求值应判红",
            ok(weekPage + "\n val panelAlpha = homeViewEaseOutCubic(progress)"),
        )
        assertFalse(
            "圆角回到组合期求值应判红",
            ok(weekPage + "\n val cornerDp = 28f * homeViewExpandCornerRadiusFactor(progress)"),
        )
        assertFalse(
            "高度不再在测量期读进度应判红",
            ok(weekPage.replace("(maxHeight * max(0.04f, progress)).roundToPx()", "maxHeight.roundToPx()")),
        )
        assertFalse(
            "alpha 脱离绘制层应判红",
            ok(weekPage.replace("graphicsLayer { alpha = panelAlpha }", ".then(Modifier)")),
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
        const val DAY_PAGE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt"
    }
}
