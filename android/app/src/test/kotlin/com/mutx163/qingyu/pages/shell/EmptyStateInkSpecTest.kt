package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * 空态判墨的 JVM 单测（方案 §5A.2「判墨单测」那一条）。
 *
 * 被测件是纯 Kotlin（[resolveEmptyStateColorsArgb]，无 Compose 类型），所以能直接进
 * `scripts/test-kotlin-module.ps1 -Module pages/shell` 的 classpath。
 *
 * 六个用例对应六条规则：主题原样 / 沉浸白两档 / 深底翻白 / 浅底翻近黑 /
 * 亮度未知回主题 / 自定义色对比度够就保色相。
 */
class EmptyStateInkSpecTest {

    private val themeTitle = 0xFF333333.toInt()
    private val themeBody = 0xFF666666.toInt()

    @Test
    fun theme_keepsThemeInk() {
        val colors = resolveEmptyStateColorsArgb(EmptyStateInk.Theme, themeTitle, themeBody)
        assertEquals(themeTitle, colors.titleArgb)
        assertEquals(themeBody, colors.bodyArgb)
    }

    @Test
    fun onPhoto_usesTwoFixedWhites() {
        val colors = resolveEmptyStateColorsArgb(EmptyStateInk.OnPhoto, themeTitle, themeBody)
        assertEquals(0xDBFFFFFF.toInt(), colors.titleArgb)
        assertEquals(0x99FFFFFF.toInt(), colors.bodyArgb)
    }

    @Test
    fun darkBackdrop_flipsToWhiteAndMutesBody() {
        val colors = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(wallpaperLuminance = 0.02),
            themeTitle,
            themeBody,
        )
        assertEquals(0xFFFFFFFF.toInt(), colors.titleArgb)
        // 白墨压淡一档：alpha 0.72 → 184（四舍五入），色本身不变。
        assertEquals(0xB8FFFFFF.toInt(), colors.bodyArgb)
    }

    @Test
    fun lightBackdrop_flipsToNearBlackAndMutesBody() {
        val colors = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(wallpaperLuminance = 0.9),
            themeTitle,
            themeBody,
        )
        assertEquals(0xFF1A1A1A.toInt(), colors.titleArgb)
        // 近黑墨自身亮度 < 0.55 ⇒ alpha 0.70 → 179。
        assertEquals(0xB31A1A1A.toInt(), colors.bodyArgb)
    }

    @Test
    fun noLuminance_fallsBackToThemeInk() {
        val colors = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(wallpaperLuminance = null, pageBackgroundLuminance = null),
            themeTitle,
            themeBody,
        )
        assertEquals(themeTitle, colors.titleArgb)
        assertEquals(themeBody, colors.bodyArgb)
    }

    @Test
    fun configuredColorWithEnoughContrast_keepsItsHue() {
        val colors = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(
                wallpaperLuminance = 0.02,
                configuredArgbHex = "#FF0000",
            ),
            themeTitle,
            themeBody,
        )
        // 红在 0.02 亮度底上对比度约 3.75:1 ⇒ 原样保留（不翻白、不推亮度）。
        assertEquals(0xFFFF0000.toInt(), colors.titleArgb)
        // 副标题仍是标题墨的淡一档，且与标题同色相（不出现「主句红了、副句是灰」）。
        assertNotEquals(colors.titleArgb, colors.bodyArgb)
        assertEquals(0x00FF0000, colors.bodyArgb and 0x00FFFFFF)
    }
}
