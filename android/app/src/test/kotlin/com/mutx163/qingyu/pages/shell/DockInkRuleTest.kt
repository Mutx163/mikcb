package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 底栏墨色判据的 JVM 单测（[DockInkRule]，纯 Kotlin）。
 *
 * 覆盖用户点名的四种组合：亮壁纸 / 暗壁纸 / 深色模式 / 玻璃强度滑杆两端，
 * 外加阈值边界（0.45 恰好等于时按亮底处理，与 Dart `< 0.45` 同方向）。
 */
class DockInkRuleTest {

    /** 浅色主题的 `surfaceContainer`（近白）。 */
    private val lightSurface = 0.92

    /** 深色主题的 `surfaceContainer`（近黑）。 */
    private val darkSurface = 0.15

    @Test
    fun `无壁纸时有效亮度就是主题面亮度`() {
        assertEquals(lightSurface, DockInkRule.effectiveLuminance(lightSurface, null, 0.4), 1e-9)
        assertEquals(darkSurface, DockInkRule.effectiveLuminance(darkSurface, null, 0.9), 1e-9)
    }

    @Test
    fun `染色强度两端分别落到壁纸与药丸色`() {
        // 滑杆拉到 0 = 几乎全透：看到的是壁纸。
        assertEquals(0.10, DockInkRule.effectiveLuminance(lightSurface, 0.10, 0.0), 1e-9)
        // 滑杆拉到 1 = 实色：看到的是药丸。
        assertEquals(lightSurface, DockInkRule.effectiveLuminance(lightSurface, 0.10, 1.0), 1e-9)
        // 中间值按 alpha 线性合成。
        assertEquals(
            0.4 * lightSurface + 0.6 * 0.10,
            DockInkRule.effectiveLuminance(lightSurface, 0.10, 0.4),
            1e-9,
        )
    }

    @Test
    fun `亮壁纸浅色主题用深墨且选中项走主色`() {
        val luminance = DockInkRule.effectiveLuminance(lightSurface, 0.85, 0.4)
        val ink = DockInkRule.resolve(luminance, isDarkTheme = false)
        assertFalse("亮底应该用深墨", ink.useLightInk)
        assertTrue("浅色主题亮底上的主色对比够，选中项应该用主色", ink.selectedUsesAccent)
        assertEquals(1f, ink.selectedAlpha, 0f)
        assertEquals(DockInkRule.UNSELECTED_ALPHA_DARK, ink.unselectedAlpha, 0f)
    }

    @Test
    fun `暗壁纸浅色主题翻成浅墨`() {
        // 0.4 * 0.92 + 0.6 * 0.10 = 0.428 < 0.45 ⇒ 浅墨（这是用户截图里发灰的那种）。
        val luminance = DockInkRule.effectiveLuminance(lightSurface, 0.10, 0.4)
        val ink = DockInkRule.resolve(luminance, isDarkTheme = false)
        assertTrue("暗壁纸必须翻成浅墨，否则近黑的字压在照片上看不见", ink.useLightInk)
        assertFalse(ink.selectedUsesAccent)
        assertEquals(1f, ink.selectedAlpha, 0f)
        assertEquals(DockInkRule.UNSELECTED_ALPHA_LIGHT, ink.unselectedAlpha, 0f)
    }

    @Test
    fun `深色模式暗壁纸用浅墨`() {
        val luminance = DockInkRule.effectiveLuminance(darkSurface, 0.08, 0.4)
        val ink = DockInkRule.resolve(luminance, isDarkTheme = true)
        assertTrue(ink.useLightInk)
        assertEquals(DockInkRule.UNSELECTED_ALPHA_LIGHT, ink.unselectedAlpha, 0f)
    }

    @Test
    fun `深色模式亮壁纸且药丸刷实时不许用主色`() {
        // 0.2 * 0.15 + 0.8 * 0.90 = 0.75 ⇒ 亮底；深色主题的主色偏亮，压不住，
        // 选中项必须退到 0.80 的深墨（Dart `:172-173` 同一条）。
        val luminance = DockInkRule.effectiveLuminance(darkSurface, 0.90, 0.2)
        val ink = DockInkRule.resolve(luminance, isDarkTheme = true)
        assertFalse(ink.useLightInk)
        assertFalse("深色主题 + 亮底，主色对比不够", ink.selectedUsesAccent)
        assertEquals(DockInkRule.SELECTED_ALPHA_DARK, ink.selectedAlpha, 0f)
        assertEquals(DockInkRule.UNSELECTED_ALPHA_DARK, ink.unselectedAlpha, 0f)
    }

    @Test
    fun `玻璃强度拉满时以药丸色为准`() {
        // 浅色主题 + 暗壁纸，但药丸几乎实色（0.9）：实际底色是浅色，仍用深墨。
        val luminance = DockInkRule.effectiveLuminance(lightSurface, 0.10, 0.9)
        val ink = DockInkRule.resolve(luminance, isDarkTheme = false)
        assertFalse("药丸已刷实，底色是浅色", ink.useLightInk)
        assertTrue(ink.selectedUsesAccent)
    }

    @Test
    fun `阈值边界恰好045按亮底处理`() {
        assertFalse(DockInkRule.resolve(0.45, isDarkTheme = false).useLightInk)
        assertTrue(DockInkRule.resolve(0.4499, isDarkTheme = false).useLightInk)
    }

    @Test
    fun `输入越界会被夹到0到1`() {
        assertEquals(1.0, DockInkRule.effectiveLuminance(1.4, 2.0, 0.4), 1e-9)
        assertEquals(0.0, DockInkRule.effectiveLuminance(-0.3, -1.0, 0.4), 1e-9)
    }
}
