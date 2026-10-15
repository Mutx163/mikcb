package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「同一列文字落在同一条垂直参考线上」这件事的守卫。
 *
 * 背景（2026-10-15 用户评价）：卡片开了「课程颜色」后，主课名被色条顶开
 * 9dp（条 3dp + 间距 6dp），而下面的时间/教室行没有这份缩进 —— 看起来
 * 就像「时间起止字比课名起始字左出一点」。修法是下发时给同列文字补等宽的
 * 左内边距（[TodayWidgetSupport.applyHeroTextGutter]，宽度取
 * [TodayWidgetSupport.HERO_ACCENT_GUTTER_DP]）。
 *
 * 于是同一个数字同时活在「布局 XML」和「Kotlin 常量」两处，布局里把
 * 3dp / 6dp 改掉而忘了改常量，对齐会**静默**失效（单测和真机都不会报错，
 * 只有肉眼能看出差了几个 dp）。这个测试把两边钉死。
 *
 * 同一个布局文件里还有第二条同类约定：主卡色条的高度必须跟着课名走
 * （alignTop + alignBottom 绑到课名），而条里的字墨又要恒高于条高。
 * 两条都是「改错了只在真机上看得出来」的，一并在这里钉住。
 *
 * 注：目前只有 2×2 主卡真的用上了这份下发；本篇把同几何的另外两根
 * hero 色条（2×4 概览、4×2 横宽）也一并钉住，将来给它们补对齐时不用再改测试。
 * 行内色条（迷你列表 / 概览 / 横宽的「接下来」几行）间距是 5dp、几何不同，
 * 不在本篇口径里。
 */
class HeroAccentGutterLayoutTest {

    /** 与来源同几何的 hero 色条：view id → 所在布局。 */
    private val heroAccentBars = mapOf(
        "widget_course_name_accent" to "layout/widget_today_compact.xml",
        "widget_medium_title_accent" to "layout/widget_today_medium.xml",
        "widget_wide_course_accent" to "layout/widget_today_wide.xml",
    )

    @Test
    fun heroAccentBarsAreAsWideAsTheGutterConstant() {
        heroAccentBars.forEach { (viewId, layout) ->
            val tag = findTextViewTag(layout, viewId)
            val barWidth = requireDp(tag, "android:layout_width", viewId)
            val gap = requireDp(tag, "android:layout_marginEnd", viewId)
            assertEquals(
                "$layout 里 $viewId 的宽度 + 间距应与 HERO_ACCENT_GUTTER_DP 同值" +
                    "（改了这里就要同步改常量，否则同列文字又错开）",
                TodayWidgetSupport.HERO_ACCENT_GUTTER_DP,
                barWidth + gap,
            )
        }
    }

    @Test
    fun compactMetaHasNoStaticLeftPadding() {
        // 主卡的时间/教室行整份左内边距都由 applyHeroTextGutter 下发
        // （setViewPadding 会整体覆盖静态 padding）。这里若有人加回静态
        // paddingLeft，色条关掉时那一行就会比课名多缩进一段。
        val tag = findTextViewTag("layout/widget_today_compact.xml", "widget_meta")
        assertFalse(
            "widget_meta 不要写静态 paddingLeft，左内边距由 applyHeroTextGutter 下发",
            tag.contains("android:paddingLeft"),
        )
        assertTrue(
            "widget_meta 应当仍是 TextView（applyHeroTextGutter 走 setViewPadding）",
            tag.startsWith("<TextView"),
        )
    }

    @Test
    fun compactHeroBarIsHeightBoundToTheCourseName() {
        val tag = findTextViewTag("layout/widget_today_compact.xml", "widget_course_name_accent")
        // 色条高度不能写死：两条边都钉在课名上，课名一行条就一行高、
        // 折成两行条就两行高（相对布局对两端都固定的子视图走 EXACTLY）。
        assertTrue(
            "色条高度要跟着课名走：layout_alignTop 与 layout_alignBottom 必须双双绑到 widget_course_name",
            tag.contains("""android:layout_alignTop="@id/widget_course_name"""") &&
                tag.contains("""android:layout_alignBottom="@id/widget_course_name""""),
        )
    }

    @Test
    fun compactHeroBarInkCoversTwoLines() {
        // 条里的字墨是「整块字符被自身边界裁出来的实心块」：字墨必须恒高于条高，
        // 否则条会在上下两端露出透明（字墨比视图矮）。这里按最不利的一档算：
        // 两行课名（provider 里最宽的档位 19sp）× 行高 1.2em。
        val tag = findTextViewTag("layout/widget_today_compact.xml", "widget_course_name_accent")
        val requiredSp = 2f * 19f * 1.2f
        val barTextSizeSp = requireSp(tag, "android:textSize", "widget_course_name_accent")
        assertTrue(
            "色条 textSize=${barTextSizeSp}sp 盖不住两行 19sp 课名（至少 ${requiredSp}sp），" +
                "条会在两端露透明",
            barTextSizeSp >= requiredSp,
        )
    }

    /** 取该 id 所在 TextView 的完整开标签（属性顺序无关，`[^>]*` 不会跨过标签结尾）。 */
    private fun findTextViewTag(layout: String, viewId: String): String {
        val text = findResFile(layout).readText()
        val pattern = Regex("""(?s)<TextView\b[^>]*android:id="@\+id/$viewId"[^>]*>""")
        return pattern.find(text)?.value
            ?: throw AssertionError("$layout 里找不到 TextView @+id/$viewId")
    }

    private fun requireDp(tag: String, attribute: String, viewId: String): Int {
        val raw = Regex("""\b$attribute="([^"]+)"""").find(tag)?.groupValues?.get(1)
            ?: throw AssertionError("$viewId 缺少属性 $attribute")
        val value = raw.removeSuffix("dp").toFloatOrNull()
            ?: throw AssertionError("$viewId 的 $attribute=\"$raw\" 不是 dp 值")
        return value.toInt()
    }

    private fun requireSp(tag: String, attribute: String, viewId: String): Float {
        val raw = Regex("""\b$attribute="([^"]+)"""").find(tag)?.groupValues?.get(1)
            ?: throw AssertionError("$viewId 缺少属性 $attribute")
        return raw.removeSuffix("sp").toFloatOrNull()
            ?: throw AssertionError("$viewId 的 $attribute=\"$raw\" 不是 sp 值")
    }

    /** 单测的工作目录是模块目录（android/app），但不同构建方式下可能不同，逐级向上找。 */
    private fun findResFile(relative: String): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".")
        while (dir != null) {
            for (candidate in listOf("src/main/res/$relative", "app/src/main/res/$relative")) {
                val file = File(dir, candidate)
                if (file.isFile) return file
            }
            dir = dir.parentFile
        }
        throw AssertionError("找不到 res/$relative（user.dir=${System.getProperty("user.dir")}）")
    }
}
