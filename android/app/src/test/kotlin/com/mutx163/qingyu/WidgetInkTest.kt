package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 字色「同源」这件事的两条守卫：
 *
 * 1. 决策逻辑：什么时候把字色交给宿主的主题属性、什么时候下发固定值；
 * 2. 两份事实必须同值：宿主解析用的 `values[-night]/colors.xml` 里的 `widget_ink_*`，
 *    与 App 渲染时算的 `TodayWidgetSupport.inkFallback`（本机真机不可得，改用
 *    「XML 值 == 这里钉住的字面值」来兜住 XML 那一半漂移）。
 *
 * 卡片底色走 `drawable-night`、字色若在渲染时算成固定值，两条通道就各听一个时钟：
 * 系统换档后桌面把底换成新一档、字色留在旧一档 —— 深底深字或浅底浅字。
 * 见 .agents/notes/implemented/bug-fix/2026-10-10-widget-night-mode-stale-ink.md。
 */
class WidgetInkTest {

    @Test
    fun themeInkChannelIsDisabledOnHyperOs() {
        // 2026-10-10 真机证伪：HyperOS 桌面解析主题属性拿到白天档（深底压深字），
        // 属性通道整体停用、字色一律由渲染时算的固定值下发。这条钉子防止有人
        // 只改开关忘了同步注释与笔记。
        assertFalse(shouldResolveInkFromTheme("solid", 31))
        assertFalse(shouldResolveInkFromTheme("glass", 34))
        assertFalse(shouldResolveInkFromTheme("solid", 36))
        assertFalse(shouldResolveInkFromTheme("gradient", 34))
    }

    @Test
    fun strongStatesUseStrongChipInk() {
        // strong 集合的唯一事实来源是 TodayWidgetSupport.isStrongChipState。
        assertEquals(WidgetInk.CHIP_STRONG, chipInkRole("ongoing"))
        assertEquals(WidgetInk.CHIP_STRONG, chipInkRole("upcoming"))
        assertEquals(WidgetInk.CHIP_STRONG, chipInkRole("holiday"))
        assertEquals(WidgetInk.CHIP_DIM, chipInkRole("completed"))
        assertEquals(WidgetInk.CHIP_DIM, chipInkRole("no_course"))
    }

    @Test
    fun inkAttributesAreDistinct() {
        val attrs = WidgetInk.values().map { it.attrId }
        assertEquals(attrs.size, attrs.toSet().size)
    }

    @Test
    fun inkColorResourcesMatchTheKotlinFallbacks() {
        // 与 TodayWidgetSupport.primaryTextColor / secondaryTextColor / chipTextColor
        // 的取值一致：白天四色 + 夜间四色。
        val day = readInkColors("values")
        val night = readInkColors("values-night")
        assertEquals("#FF0F172A", day["widget_ink_primary"])
        assertEquals("#FF64748B", day["widget_ink_secondary"])
        assertEquals("#FF1D4ED8", day["widget_ink_chip_strong"])
        assertEquals("#FF334155", day["widget_ink_chip_dim"])
        assertEquals("#FFE2E8F0", night["widget_ink_primary"])
        assertEquals("#FF94A3B8", night["widget_ink_secondary"])
        assertEquals("#FFE2E8F0", night["widget_ink_chip_strong"])
        assertEquals("#FFE2E8F0", night["widget_ink_chip_dim"])
    }

    private fun readInkColors(qualifier: String): Map<String, String> {
        val file = findResFile("$qualifier/colors.xml")
        val text = file.readText()
        return Regex("""<color name="(widget_ink_[a-z_]+)">([^<]+)</color>""")
            .findAll(text)
            .associate { it.groupValues[1] to it.groupValues[2].trim() }
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
