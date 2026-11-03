package com.mutx163.qingyu.pages.shell

/**
 * 玻璃坞标签 / 图标的墨色判据 —— **全仓唯一实现**（2026-11-03）。
 *
 * ## 为什么要有
 *
 * 坞是一块半透明药丸，压在壁纸（或页面底色）上。以前的渲染层固定取
 * `MiuixTheme.colorScheme.onBackground`（主题墨色）：
 *
 * * 浅色主题 + 暗壁纸 ⇒ 近黑的字压在暗照片上，几乎看不见；
 * * 深色主题 + 亮壁纸 ⇒ 近白的字压在亮照片上，同样看不见；
 * * 药丸染色强度（`tintAlpha`）从 0 拉到 0.9 时，实际底色在壁纸与药丸色之间
 *   连续变化，固定主题墨色不可能两端都对。
 *
 * 判据来自 Dart 旧版 `lib/widgets/timetable/timetable_glass_dock.dart:86-98,160-174`：
 * 半透明材质按**壁纸亮度**翻黑 / 白（阈值 0.45），实体档按主题；未选中 0.62（白）/
 * 0.48（黑），选中为白（浅墨档）或主色（深墨档，深色主题 + 亮底时退到 0.80 的黑）。
 *
 * ## 与旧版的唯一一处差异
 *
 * 旧版只看壁纸亮度；这里先算**合成后的有效亮度**：药丸 `surfaceContainer` 以
 * [tintAlpha] 压在壁纸上，`L = a * L_pill + (1 - a) * L_wallpaper`。这样材质滑杆两端
 * （0 = 几乎全透、0.9 = 几乎实色）也落在同一判据里，而不是「壁纸暗但药丸刷成不透明
 * 浅色」时仍用白字。阈值与各档 alpha 沿用旧版，未改。
 *
 * 纯 Kotlin（不依赖 Compose）：JVM 单测钉住阈值边界与四种组合。
 */
data class DockInkColors(
    /** true = 浅墨（近白）；false = 深墨（近黑）。 */
    val useLightInk: Boolean,
    /**
     * 选中项是否改用主题主色（`MiuixTheme.colorScheme.primary`）。
     * 浅底上的主色对比够；深色主题 + 亮底时不够，此时为 false（退成深墨 0.80）。
     */
    val selectedUsesAccent: Boolean,
    val selectedAlpha: Float,
    val unselectedAlpha: Float,
)

object DockInkRule {

    /** 墨色翻面阈值：与 Dart `homePageChromeForegroundForLuminance` 同一口径（0.45）。 */
    const val INK_FLIP_LUMINANCE = 0.45

    /** 未选中的浅墨透明度（Dart `timetable_glass_dock.dart:166`）。 */
    const val UNSELECTED_ALPHA_LIGHT = 0.62f

    /** 未选中的深墨透明度（Dart `:167`）。 */
    const val UNSELECTED_ALPHA_DARK = 0.48f

    /** 深色主题 + 亮底时选中项的深墨透明度（Dart `:172-173`）。 */
    const val SELECTED_ALPHA_DARK = 0.80f

    /**
     * 药丸实际底色压出来的有效亮度。
     *
     * @param surfaceLuminance 药丸染色色（`surfaceContainer`）的相对亮度。
     * @param wallpaperLuminance 药丸底下壁纸的相对亮度；null = 底下不是壁纸
     *   （内嵌页的实色面 / 没有壁纸），此时直接用主题面的亮度。
     * @param tintAlpha 染色强度（`containerColor` 的 alpha）；实体档传 1.0。
     */
    fun effectiveLuminance(
        surfaceLuminance: Double,
        wallpaperLuminance: Double?,
        tintAlpha: Double,
    ): Double {
        val surface = surfaceLuminance.coerceIn(0.0, 1.0)
        val wallpaper = wallpaperLuminance?.coerceIn(0.0, 1.0) ?: return surface
        val alpha = tintAlpha.coerceIn(0.0, 1.0)
        return (alpha * surface + (1.0 - alpha) * wallpaper).coerceIn(0.0, 1.0)
    }

    /**
     * 由有效亮度给出四档墨色参数。
     *
     * @param backgroundLuminance [effectiveLuminance] 的结果。
     * @param isDarkTheme 当前是否深色主题（决定亮底上的选中项能不能用主色）。
     */
    fun resolve(backgroundLuminance: Double, isDarkTheme: Boolean): DockInkColors {
        // 恰好等于阈值按「亮底」处理（与 Dart `< 0.45` 同方向）。
        val useLightInk = backgroundLuminance < INK_FLIP_LUMINANCE
        val selectedUsesAccent = !useLightInk && !isDarkTheme
        return DockInkColors(
            useLightInk = useLightInk,
            selectedUsesAccent = selectedUsesAccent,
            selectedAlpha = if (useLightInk || selectedUsesAccent) 1f else SELECTED_ALPHA_DARK,
            unselectedAlpha = if (useLightInk) UNSELECTED_ALPHA_LIGHT else UNSELECTED_ALPHA_DARK,
        )
    }
}
