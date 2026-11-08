package com.mutx163.qingyu.pages.timetable

/**
 * 课卡墨色（标题 / 详情）的可读性守卫。
 *
 * ## 为什么要从 Dart 搬过来
 *
 * 设置里有「课卡标题色 / 详情色」四项（`courseCardTitleColorLight/Dark`、
 * `courseCardDetailColorLight/Dark`）。Dart 侧并不是直接拿来用，而是过一道
 * **对比度守卫**（`lib/utils/course_color_palette.dart:352-408`）：
 *
 * - 用户色与卡面底色对比度 ≥ [CRITICAL_CONTRAST_RATIO]（2.0）⇒ 用用户色；
 * - 否则回落到「白 / 近黑里对比度更高」的那一档（`_bestContrastInk`）；
 * - 详情墨再把**明暗极性**强行对齐标题墨（避免「白标题 + 黑简介」的半洗白卡），
 *   最后统一 0.7 alpha。
 *
 * 2026-10-29 二轮审核确认：Compose 侧这两个设置**映射进了模型却没人读**
 *（渲染层只用 `calculateInk` 自算），于是「设置里改了颜色，课卡纹丝不动」。
 *
 * ## 为什么用 `Int` ARGB 而不是 Compose `Color`
 *
 * 本文件在 `main:`（模型层），要能被纯 JVM 单测直接跑、也不该反向依赖 Compose。
 * 渲染层拿到 `Int` 之后 `Color(argb)` 一行即可。
 */
object CourseCardInk {

    /** 用户墨色达标线（Dart `courseCardCriticalContrastRatio = 2`，`:265`）。 */
    const val CRITICAL_CONTRAST_RATIO = 2.0

    /**
     * **自定义字色**（用户在设置里挑的墨色，如摘要卡的星期栏字色）被保留所需的对比度。
     *
     * 3:1 与 `HomeBackgroundModel.MIN_INK_CONTRAST_RATIO` 是同一条「压在壁纸上还看得见」的
     * 达标线（WCAG AA 大字/图形档）。低于 3:1 的自定义色一律丢掉、回自动黑 / 白：
     * 2026-11-07 复核实测，合成底亮度 0.45 上一个亮度 0.177 的自定义字色只有 2.2:1，
     * 而黑白择优能给 8.29:1 —— 留着它就是「所有文字可读」这条口径下的不可读。
     */
    const val PREFERRED_INK_MIN_CONTRAST = 3.0

    private const val LIGHT_INK = 0xFFFFFFFF.toInt()
    private const val DARK_INK = 0xFF1A1A1A.toInt()

    /**
     * WCAG 相对对比度（1.0–21.0，对称）。
     *
     * 逐行对齐 Dart `courseCardContrastRatio`（`:268-274`）：
     * `(较亮 + 0.05) / (较暗 + 0.05)`，亮度取 sRGB 相对亮度。
     */
    fun contrastRatio(first: Int, second: Int): Double {
        val a = relativeLuminance(first)
        val b = relativeLuminance(second)
        val lighter = if (a > b) a else b
        val darker = if (a > b) b else a
        return (lighter + 0.05) / (darker + 0.05)
    }

    /** 白 / 近黑里与背景对比度更高的一档（Dart `_bestContrastInk`，`:332-339`）。 */
    fun bestContrastInk(background: Int): Int =
        if (contrastRatio(LIGHT_INK, background) >= contrastRatio(DARK_INK, background)) {
            LIGHT_INK
        } else {
            DARK_INK
        }

    /**
     * 白 / 近黑里与**背景亮度**对比度更高的一档。
     *
     * 与 [bestContrastInk] 同一判据，只是背景以「已算好的亮度」传入 —— 压在壁纸上的
     * 卡面亮度是合成值，没有对应的 `Color` 实例。
     *
     * 判据是**实际对比度**，不是某个写死的亮度阈值：纯白（亮度 1.0）与近黑 `#1A1A1A`
     * （亮度 ≈0.0103）对比度相等的那个背景亮度（≈0.202）自动成为分界点。
     * 任何「0.20 / 0.45」这类阈值都只是这个点的近似，且两边对比度差会被白白浪费
     * （0.20 比真实分界低 0.002，落在 0.200–0.202 这段时会选到对比度略差的那一档）。
     */
    fun bestContrastInkForLuminance(backgroundLuminance: Double): Int =
        if (contrastAgainstLuminance(LIGHT_INK, backgroundLuminance) >=
            contrastAgainstLuminance(DARK_INK, backgroundLuminance)
        ) {
            LIGHT_INK
        } else {
            DARK_INK
        }

    /**
     * 半透明卡面压在壁纸上之后的**有效亮度**：卡底色亮度 × α + 壁纸亮度 × (1 − α)。
     *
     * 严格来说真实合成是「先逐通道混合、再算亮度」（gamma 空间），但采样层只给得出壁纸的
     * **标量亮度**、没有 RGB 通道数据，逐通道合成做不了；这里用亮度域加权，是数据可得性下
     * 能做到的最好近似（已知偏差：极端 alpha 下会偏亮，例如白卡以 30% 压在近黑壁纸上，
     * 真实亮度 ≈0.073、这里给 ≈0.30，会选到深墨；属于已知限制，不硬造通道）。
     *
     * @param fillArgb 卡自己底色的 ARGB（不透明）。
     * @param fillAlpha 这个底色压上去的比例（渲染层真正用的那个 alpha）。
     * @param wallpaperLuminance 卡背后壁纸的相对亮度（0–1）。
     */
    fun compositeLuminanceOverWallpaper(
        fillArgb: Int,
        fillAlpha: Float,
        wallpaperLuminance: Double,
    ): Double {
        val t = if (fillAlpha.isNaN()) 0.0 else fillAlpha.toDouble().coerceIn(0.0, 1.0)
        return relativeLuminance(fillArgb) * t + wallpaperLuminance.coerceIn(0.0, 1.0) * (1.0 - t)
    }

    /**
     * 半透明卡面的墨色：按 [compositeLuminanceOverWallpaper] 算出的**卡面有效亮度**，
     * 在白 / 近黑里取对比度更高的一档（两者在 0.2017 附近相等，不是任何写死的阈值）。
     *
     * 日视图那几张卡（课程 / 日程 / 考试 / 待办带 / 摘要）共用这一份，避免各写一套漂移。
     *
     * @param fillArgb 卡自己的底色（不透明；档位 alpha 由 [fillAlpha] 单独表述）。
     * @param fillAlpha 这个底色压上去的比例（渲染层真正用的那个值）。
     * @param wallpaperLuminance 这张卡背后壁纸的亮度；null = 还没采到。
     * @param showsWallpaper 卡面是否真的露出壁纸（玻璃档，或染色 alpha < 1）。
     *   为 false 时卡面是实色，壁纸与它无关，直接回 [fallbackArgb]。
     * @param fallbackArgb 实色 / 亮度未知时的墨色（各卡都用 `bestContrastInk(卡底色)`：
     *   实色卡不透明、壁纸不参与，但墨色仍按卡色自身的 WCAG 亮度择优；待办带 / 摘要卡
     *   的卡底色就是主题 surface）。
     * @param preferredArgb 用户在设置里挑的墨色（如摘要卡的星期栏字色）。对比度达标就用它；
     *   不达标 / 没配则回自动黑 / 白。null = 没有自定义色。
     * @param preferredMinContrast 自定义色要保留所需的对比度（默认 [PREFERRED_INK_MIN_CONTRAST]
     *   = 3:1，与 `HomeBackgroundModel.MIN_INK_CONTRAST_RATIO` 同一条达标线；低于它一律
     *   回自动黑 / 白）。
     * @param pageBackgroundLuminance 壁纸亮度未知（没壁纸 / 还没采到）时，卡实际压着的**页底**亮度。
     *   半透明卡（磨砂 0.55α / 液态染色）在无壁纸时压的是页底色，不是不透明卡色：只按卡色判
     *   会把「中调课色压深页底」判成深字、把「深课色压浅页底」判成白字。传了它就走
     *   [compositeLuminanceOverWallpaper] 的合成，没传则保持旧回退 [fallbackArgb]。
     */
    fun resolveCardInkOverWallpaper(
        fillArgb: Int,
        fillAlpha: Float,
        wallpaperLuminance: Double?,
        showsWallpaper: Boolean,
        fallbackArgb: Int,
        preferredArgb: Int? = null,
        preferredMinContrast: Double = PREFERRED_INK_MIN_CONTRAST,
        pageBackgroundLuminance: Double? = null,
    ): Int {
        if (!showsWallpaper) return fallbackArgb
        // 优先级：真实壁纸亮度 > 页底亮度 > 旧回退（实色 / 全不知道）。
        val backdropLuminance = wallpaperLuminance
            ?: pageBackgroundLuminance
            ?: return fallbackArgb
        val surfaceLuminance = compositeLuminanceOverWallpaper(fillArgb, fillAlpha, backdropLuminance)
        if (preferredArgb != null &&
            contrastAgainstLuminance(preferredArgb, surfaceLuminance) >= preferredMinContrast
        ) {
            return preferredArgb
        }
        return bestContrastInkForLuminance(surfaceLuminance)
    }

    /** [inkArgb] 在亮度为 [backgroundLuminance] 的背景上的 WCAG 对比度（1–21）。 */
    private fun contrastAgainstLuminance(inkArgb: Int, backgroundLuminance: Double): Double {
        val inkLuminance = relativeLuminance(inkArgb)
        val lighter =
            if (inkLuminance > backgroundLuminance) inkLuminance else backgroundLuminance
        val darker =
            if (inkLuminance > backgroundLuminance) backgroundLuminance else inkLuminance
        return (lighter + 0.05) / (darker + 0.05)
    }

    /**
     * 标题墨：用户色达标就用用户色，否则回落到自动墨。
     *
     * `preferred` 为 null（设置没配 / 解析失败）时等价于 Dart 的 `titleColorHex == null`
     * ——Dart 此时用 `defaultTitleHex`（卡色决定），这里直接用自动墨。
     */
    fun resolveTitleInk(preferred: Int?, cardColor: Int): Int {
        if (preferred == null) return bestContrastInk(cardColor)
        return if (contrastRatio(preferred, cardColor) >= CRITICAL_CONTRAST_RATIO) {
            preferred
        } else {
            bestContrastInk(cardColor)
        }
    }

    /**
     * 详情墨：先过与标题同一道守卫，再把极性对齐到 [resolvedTitleInk]。
     *
     * 对齐 Dart `resolveReadableCourseCardDetailColor`（`:385-408`）的实心卡分支。
     *
     * @return (argb, alpha)；alpha 恒为 0.7（Dart `withValues(alpha: 0.7)`）
     */
    fun resolveDetailInk(
        preferred: Int?,
        resolvedTitleInk: Int,
        cardColor: Int,
    ): Pair<Int, Float> {
        val guarded = resolveTitleInk(preferred, cardColor)
        val titleIsLight = relativeLuminance(resolvedTitleInk) >= 0.5
        val detailIsLight = relativeLuminance(guarded) >= 0.5
        val ink = if (titleIsLight == detailIsLight) guarded else resolvedTitleInk
        return ink to 0.7f
    }

    /**
     * sRGB 相对亮度（WCAG 2.x）。
     *
     * Flutter 的 `Color.computeLuminance()` 就是这一套：每通道先除以 255、
     * 再按 `c <= 0.03928 ? c/12.92 : ((c+0.055)/1.055)^2.4` 线性化，
     * 最后 `0.2126R + 0.7152G + 0.0722B`。
     */
    fun relativeLuminance(argb: Int): Double {
        val r = linearize(((argb shr 16) and 0xFF) / 255.0)
        val g = linearize(((argb shr 8) and 0xFF) / 255.0)
        val b = linearize((argb and 0xFF) / 255.0)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private fun linearize(channel: Double): Double =
        if (channel <= 0.03928) channel / 12.92 else Math.pow((channel + 0.055) / 1.055, 2.4)
}