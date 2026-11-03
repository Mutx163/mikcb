package com.mutx163.qingyu.utils

/**
 * 「按钮看得出来吗」对比度判据（2026-11-03 按钮可点击性观感排查引入，**仅测试源集**）。
 *
 * ## 背景
 *
 * 2026-11-03 用户实报桌面小组件设置页「添加到桌面」按钮与背景同色：按钮容器走的是
 * 官方 `buttonColors()` 默认值 = `secondaryVariant`（亮 `#F0F0F0`），而本仓把设置页底
 * 覆写成 `#F2F2F2`（`QingyuMikcbOverrides.SETTINGS_BACKGROUND`），两个色的 WCAG 对比比
 * 只有 ~1.02，肉眼无法区分。守卫 [com.mutx163.qingyu.pages.settings.SettingsButtonStyleGuardTest]
 * 钉源码写法；本对象给「给定两个色，算不算分不出来」的可复算判据。
 *
 * ## 判据（唯一权威定义）
 *
 * - [contrastRatio]：WCAG 2.x 相对亮度对比比，(L亮 + 0.05) / (L暗 + 0.05)，范围 [1, 21]。
 * - [isIndistinguishable]：对比比 **< 1.05** 即判「融进背景」。
 *
 * 为什么阈值取 1.05 而不是更宽松的 1.3：
 * - 本故障类是「容器色 ≈ 背景色」（1.018 才出事），不是「任何低对比」——
 *   Dart 原版 secondary 按钮 `#E6E6E6` 落在页底 `#F2F2F2` 上对比比 ~1.11，
 *   靠墨色（`#303030`，对比比 ~9）承担可读性，是 HyperOS 有意为之的弱表面层级，
 *   不在打击范围；官方弹层白底上的默认灰（1.14）同样要放过。
 * - 1.05 恰好卡在「故障案例 1.018」与「合法弱表面 1.11+」之间，两边都不误伤。
 *
 * 纯 Int ARGB 进出，不依赖 Compose / android.graphics，JVM 单测直跑。
 */
object ButtonContrastRules {

    /**
     * WCAG 2.x 相对亮度（sRGB 线性化 + 三通道加权）。
     * 入参是 `0xAARRGGBB` 的 Int（alpha 不参与亮度计算，调用方自行保证不透明）。
     */
    fun relativeLuminance(argb: Int): Double {
        val r = linearize((argb ushr 16) and 0xFF)
        val g = linearize((argb ushr 8) and 0xFF)
        val b = linearize(argb and 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /**
     * 前景/背景的 WCAG 对比比，恒 ≥ 1.0（自动把亮的一边放分子）。
     */
    fun contrastRatio(foreground: Int, background: Int): Double {
        val l1 = relativeLuminance(foreground)
        val l2 = relativeLuminance(background)
        val lighter = maxOf(l1, l2)
        val darker = minOf(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /**
     * 容器色与背景色是否「融成一片」：对比比低于 [threshold]（默认 [DEFAULT_THRESHOLD]）。
     */
    fun isIndistinguishable(
        container: Int,
        background: Int,
        threshold: Double = DEFAULT_THRESHOLD,
    ): Boolean = contrastRatio(container, background) < threshold

    /** 「融进背景」的判定线：低于它 = 肉眼同色。理由见类 KDoc。 */
    const val DEFAULT_THRESHOLD: Double = 1.05

    /** WCAG sRGB 通道线性化（`c ≤ 0.03928` 走低压段，否则 gamma 展开）。 */
    private fun linearize(channel: Int): Double {
        val c = channel / 255.0
        return if (c <= 0.03928) c / 12.92 else Math.pow((c + 0.055) / 1.055, 2.4)
    }
}
