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