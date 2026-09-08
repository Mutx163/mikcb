package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 小组件课程色贯穿的可读性守卫。
 *
 * 这些断言是「防退化」的：任何人改公式或色板，只要把全色板的最低对比度
 * 拉低、或让色相漂出家族，CI 直接红。dart 镜像见
 * test/utils/widget_course_accent_test.dart（两侧常量必须同步）。
 */
class CourseWidgetAccentTest {

    /** 与 lib/utils/course_color_palette.dart 的 kPresetCourseColorHexes 同源。 */
    private val palette: List<String> = """
        #FCA5A5 #F87171 #EF4444 #DC2626 #B91C1C
        #FF5722 #FDBA74 #FB923C #F97316 #EA580C #C2410C
        #FCD34D #FBBF24 #F59E0B #FF9800 #D97706 #B45309
        #FDE047 #FACC15 #EAB308 #CA8A04 #A16207
        #BEF264 #A3E635 #84CC16 #65A30D #4D7C0F
        #86EFAC #4ADE80 #4CAF50 #22C55E #16A34A #15803D
        #6EE7B7 #34D399 #10B981 #059669 #047857
        #5EEAD4 #2DD4BF #14B8A6 #0D9488 #0F766E
        #67E8F9 #22D3EE #06B6D4 #00BCD4 #0891B2 #0E7490
        #7DD3FC #38BDF8 #0EA5E9 #0284C7 #0369A1
        #93C5FD #60A5FA #2196F3 #3B82F6 #2563EB #1D4ED8
        #A5B4FC #818CF8 #6366F1 #4F46E5 #4338CA
        #C4B5FD #A78BFA #8B5CF6 #7C3AED #6D28D9
        #D8B4FE #C084FC #A855F7 #9333EA #9C27B0 #7E22CE
        #F0ABFC #E879F9 #D946EF #C026D3 #A21CAF
        #F9A8D4 #F472B6 #EC4899 #E91E63 #DB2777 #BE185D
        #FDA4AF #FB7185 #F43F5E #E11D48 #BE123C
        #CBD5E1 #94A3B8 #607D8B #64748B #475569 #334155
        #D6D3D1 #A8A29E #78716C #795548 #57534E #44403C
    """.trimIndent().split(Regex("\\s+"))

    private fun parse(hex: String): Int = CourseWidgetAccent.parseHex(hex)!!

    @Test
    fun paletteIsFullyCovered() {
        assertEquals(104, palette.size)
    }

    @Test
    fun lightCardBarClearsThreeToOne() {
        val backgrounds = listOf(parse("#F8FAFC"), parse("#F0F0EE"), parse("#FFFFFF"))
        for (hex in palette) {
            val bar = CourseWidgetAccent.accentBarArgb(hex, "solid", false)
            assertNotNull("$hex should resolve a bar color", bar)
            for (bg in backgrounds) {
                val ratio = CourseWidgetAccent.contrastRatio(bar!!, bg)
                assertTrue(
                    "bar of $hex on ${Integer.toHexString(bg)} is only $ratio:1",
                    ratio >= 3.0,
                )
            }
        }
    }

    @Test
    fun gradientCardBarClearsThreeToOne() {
        val ends = listOf(parse("#0F766E"), parse("#2563EB"))
        for (hex in palette) {
            val bar = CourseWidgetAccent.accentBarArgb(hex, "gradient", false)
            assertNotNull("$hex should resolve a gradient bar color", bar)
            for (bg in ends) {
                val ratio = CourseWidgetAccent.contrastRatio(bar!!, bg)
                assertTrue(
                    "gradient bar of $hex is only $ratio:1",
                    ratio >= 3.0,
                )
            }
        }
    }

    @Test
    fun darkCardBarClearsThreeToOne() {
        val backgrounds = listOf(parse("#1E293B"), parse("#101828"), parse("#2A3341"))
        for (hex in palette) {
            val bar = CourseWidgetAccent.accentBarArgb(hex, "solid", true)
            assertNotNull("$hex should resolve a dark bar color", bar)
            for (bg in backgrounds) {
                val ratio = CourseWidgetAccent.contrastRatio(bar!!, bg)
                assertTrue(
                    "dark bar of $hex is only $ratio:1",
                    ratio >= 3.0,
                )
            }
        }
    }

    @Test
    fun lightChipTextBeatsCurrentGreyInk() {
        val chips = listOf(parse("#E0EAFF"), parse("#EEF2F7"))
        var worst = Double.MAX_VALUE
        for (hex in palette) {
            val text = CourseWidgetAccent.accentTextArgb(hex, "solid", false)
            assertNotNull(hex, text)
            for (chip in chips) {
                worst = minOf(worst, CourseWidgetAccent.contrastRatio(text!!, chip))
            }
        }
        // 现状固定灰字 #64748B 对 #E0EAFF 仅 3.94:1。
        assertTrue("worst chip text contrast is $worst:1", worst >= 4.5)
    }

    @Test
    fun darkChipTextClearsFourPointFive() {
        val chips = listOf(parse("#2C4A73"), parse("#324561"))
        for (hex in palette) {
            val text = CourseWidgetAccent.accentTextArgb(hex, "solid", true)
            assertNotNull(hex, text)
            for (chip in chips) {
                val ratio = CourseWidgetAccent.contrastRatio(text!!, chip)
                assertTrue("dark text of $hex is only $ratio:1", ratio >= 4.5)
            }
        }
    }

    @Test
    fun gradientStyleKeepsWhiteText() {
        for (hex in palette) {
            assertNull(
                "gradient text must stay white, got a tint for $hex",
                CourseWidgetAccent.accentTextArgb(hex, "gradient", false),
            )
        }
    }

    @Test
    fun clampingIsOneSidedAwayFromTheCard() {
        // 浅卡只压暗、深卡只提亮：反向钳制会把颜色拉向底色，对比度反而更低。
        for (hex in palette) {
            val before = CourseWidgetAccent.relativeLuminance(parse(hex))
            val lightBar = CourseWidgetAccent.accentBarArgb(hex, "solid", false)!!
            assertTrue(
                "$hex was brightened on a light card",
                CourseWidgetAccent.relativeLuminance(lightBar) <= before + 0.001,
            )
            val darkBar = CourseWidgetAccent.accentBarArgb(hex, "solid", true)!!
            assertTrue(
                "$hex was darkened on a dark card",
                CourseWidgetAccent.relativeLuminance(darkBar) >= before - 0.001,
            )
        }
    }

    @Test
    fun readableDarkColorsPassThroughUnchanged() {
        for (hex in listOf("#1D4ED8", "#334155", "#047857", "#B91C1C")) {
            assertEquals(
                "$hex should pass through unchanged on a light card",
                parse(hex),
                CourseWidgetAccent.accentBarArgb(hex, "solid", false),
            )
        }
    }

    @Test
    fun hueFamilyIsPreserved() {
        for (hex in palette) {
            val before = parse(hex)
            val hsl = CourseWidgetAccent.rgbToHsl(before)
            if (hsl.saturation < 0.12) continue // 灰系没有色相家族可言
            val after = CourseWidgetAccent.accentBarArgb(hex, "solid", false)!!
            val drift = CourseWidgetAccent.hueDriftDegrees(before, after)
            assertTrue("$hex drifted $drift deg", drift < 3.0)
        }
    }

    @Test
    fun missingOrMalformedColorsAreSilentlyIgnored() {
        for (bad in listOf("", "   ", "null", "#12345", "rgb(1,2,3)", "#GGGGGG")) {
            assertNull(bad, CourseWidgetAccent.accentBarArgb(bad, "solid", false))
            assertNull(bad, CourseWidgetAccent.accentTextArgb(bad, "solid", false))
        }
        assertNull(CourseWidgetAccent.accentBarArgb(null, "solid", false))
    }

    @Test
    fun accentModeValuesMatchTheDartSide() {
        assertEquals("off", WidgetCourseAccentMode.OFF.value)
        assertEquals("bar", WidgetCourseAccentMode.BAR.value)
        assertEquals("bar_and_text", WidgetCourseAccentMode.BAR_AND_TEXT.value)
        // 老快照/未知值按「条 + 字」兼容。
        assertEquals(WidgetCourseAccentMode.BAR_AND_TEXT, WidgetCourseAccentMode.fromValue(null))
        assertEquals(WidgetCourseAccentMode.BAR_AND_TEXT, WidgetCourseAccentMode.fromValue("legacy"))
        assertEquals(WidgetCourseAccentMode.OFF, WidgetCourseAccentMode.fromValue("off"))
        assertTrue(WidgetCourseAccentMode.OFF.showsBar.not())
        assertTrue(WidgetCourseAccentMode.OFF.showsText.not())
        assertTrue(WidgetCourseAccentMode.BAR.showsBar)
        assertTrue(WidgetCourseAccentMode.BAR.showsText.not())
        assertTrue(WidgetCourseAccentMode.BAR_AND_TEXT.showsText)
    }

    @Test
    fun colorFieldIsSanitizedLikeTheDartSide() {
        assertEquals("#22C55E", TodayWidgetSupport.sanitizeColorField("#22c55e"))
        assertEquals("#22C55E", TodayWidgetSupport.sanitizeColorField("22C55E"))
        assertEquals("", TodayWidgetSupport.sanitizeColorField(null))
        assertEquals("", TodayWidgetSupport.sanitizeColorField("null"))
        assertEquals("", TodayWidgetSupport.sanitizeColorField("#12345"))
        assertEquals("", TodayWidgetSupport.sanitizeColorField(""))
    }
}
