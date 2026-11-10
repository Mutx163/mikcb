package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 空态判墨的 JVM 单测（方案 §5A.2「判墨单测」那一条）。
 *
 * 被测件是纯 Kotlin（[resolveEmptyStateColorsArgb]，无 Compose 类型），所以能直接进
 * `scripts/test-kotlin-module.ps1 -Module pages/shell` 的 classpath。
 *
 * 六个用例对应六条规则：主题原样 / 沉浸白两档 / 深底翻白 / 浅底翻近黑 /
 * 亮度未知回主题 / 自定义色对比度够就保色相。
 *
 * ## 2026-11-10 评审六补测 5 条（判墨加固）
 *
 * 原六例只覆盖两端（0.02 / 0.9），中间口径与三条回退分支是零用例，阈值改回 0.45 也能全绿。
 * 现在补齐：①`pageBackgroundLuminance` 回退 + 「壁纸优先」的 `?:` 语义；②亮度未知但有自定义色
 * （直接回配置色的 else 分支）；③`defaultInkHex` 语义（配置色 == 内置默认 ⇒ 按亮度翻黑白，
 * 即「深壁纸黑字」修复的关键口径）；④中灰 0.30 分界（旧 0.45 阈值会判成白字）；
 * ⑤自定义色那条的说明色钉死成精确 ARGB（原先是 `assertNotEquals` + 掩码软断言）。
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
        // 副标题仍是标题墨的淡一档，且与标题同色相：红自身亮度 0.2126 < 0.55 ⇒ 0.70 压淡（179=0xB3）。
        assertEquals(0xB3FF0000.toInt(), colors.bodyArgb)
    }

    // ── 2026-11-10 评审六补测 5 条 ──

    /** ① 壁纸亮度缺失时回退页底亮度（没壁纸的自定义深色页底也要翻对）。 */
    @Test
    fun pageBackground_isFallbackWhenWallpaperLuminanceMissing() {
        val colors = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(wallpaperLuminance = null, pageBackgroundLuminance = 0.9),
            themeTitle,
            themeBody,
        )
        assertEquals(0xFF1A1A1A.toInt(), colors.titleArgb)
        assertEquals(0xB31A1A1A.toInt(), colors.bodyArgb)
    }

    /** ①′ `?:` 语义：壁纸亮度有值时**不看**页底亮度（否则深色页底会把白字翻回黑）。 */
    @Test
    fun wallpaperLuminanceWinsOverPageBackground() {
        val colors = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(wallpaperLuminance = 0.02, pageBackgroundLuminance = 0.9),
            themeTitle,
            themeBody,
        )
        assertEquals(0xFFFFFFFF.toInt(), colors.titleArgb)
        assertEquals(0xB8FFFFFF.toInt(), colors.bodyArgb)
    }

    /** ② 亮度未知但有自定义色：走 else 分支直接回配置色（红），说明色跟标题同色相压淡。 */
    @Test
    fun noLuminance_butConfiguredColor_returnsConfiguredColor() {
        val colors = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(configuredArgbHex = "#FF0000"),
            themeTitle,
            themeBody,
        )
        assertEquals(0xFFFF0000.toInt(), colors.titleArgb)
        assertEquals(0xB3FF0000.toInt(), colors.bodyArgb)
    }

    /**
     * ③ `defaultInkHex` 语义：配置色 == 内置默认 ⇒ 视为「没改过」，按亮度翻黑白。
     *
     * 这是 2026-11-09「深壁纸黑字」修复的关键口径：内置默认黑若走进「保色相推亮度」，深壁纸上会得到
     * 中灰而不是纯白。对照组（不传 `defaultInkHex`）断言「**不是**纯白」，证明这条分支真的在起作用。
     */
    @Test
    fun builtInDefaultInk_isTreatedAsUnset_andFlipsByLuminance() {
        val asBuiltInDefault = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(
                wallpaperLuminance = 0.02,
                configuredArgbHex = "#000000",
                defaultInkHex = "#000000",
            ),
            themeTitle,
            themeBody,
        )
        assertEquals(0xFFFFFFFF.toInt(), asBuiltInDefault.titleArgb)
        assertEquals(0xB8FFFFFF.toInt(), asBuiltInDefault.bodyArgb)

        val asRealCustom = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(wallpaperLuminance = 0.02, configuredArgbHex = "#000000"),
            themeTitle,
            themeBody,
        )
        org.junit.Assert.assertNotEquals(
            "不传 defaultInkHex 时应走「保色相推亮度」，不该得到纯白——否则本用例证明不了 defaultInkHex 分支",
            0xFFFFFFFF.toInt(),
            asRealCustom.titleArgb,
        )
    }

    /**
     * ④ 中灰 0.30 分界：按 WCAG 对比度择优，白只有 3.0:1、近黑 5.8:1 ⇒ 取近黑。
     *
     * 旧实现是写死 0.45 阈值，0.30 会判成白字（对比度掉到 3.0:1）；这条把分界钉住，改回阈值就红。
     */
    @Test
    fun midGrey_030_picksNearBlackInk() {
        val colors = resolveEmptyStateColorsArgb(
            EmptyStateInk.OverBackdrop(wallpaperLuminance = 0.30),
            themeTitle,
            themeBody,
        )
        assertEquals(0xFF1A1A1A.toInt(), colors.titleArgb)
        assertEquals(0xB31A1A1A.toInt(), colors.bodyArgb)
    }
}
