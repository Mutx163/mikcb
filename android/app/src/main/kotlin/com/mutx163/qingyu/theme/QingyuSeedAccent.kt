package com.mutx163.qingyu.theme

import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * 主题 seed 派生（`lib/utils/theme_seed_accent.dart:17-141` 的 Kotlin 端口）。
 *
 * 口径：
 * - 所见即所得：seed 合法就原样返回（浅色亮黄也是黄，不回落墨色）；
 * - 唯一例外是深色近黑 seed（luminance < 0.08）：黑与深底同色等于主题色没显示，
 *   回落 null 由调用方兜墨色；
 * - 禁用底 = 强调色浅色状态（浅向白混 0.7 / 深向 `#242424` 混 0.7）；
 * - 禁用墨：浅恒近白 `#FFFCFCFC`，深为强调色向暗底混 0.35。
 *
 * 纯 Int ARGB 位运算（同 `CourseWidgetAccent` 的做法，不碰
 * `android.graphics.Color`，JVM 单测与真机同一公式）。
 */
object QingyuSeedAccent {
    val BLACK = 0xFF000000L.toInt()
    val WHITE = 0xFFFFFFFFL.toInt()
    val DARK_BASE = 0xFF242424L.toInt()
    val DISABLED_INK_LIGHT = 0xFFFCFCFCL.toInt()

    private const val NEAR_BLACK_LUMINANCE = 0.08
    private const val ON_ACCENT_INK_THRESHOLD = 0.5
    private const val DISABLED_MIX = 0.7
    private const val DISABLED_INK_MIX_DARK = 0.35
    private const val SURFACE_LIFT_MIX_DARK = 0.45

    /** 与 Dart `tryParseHexColor` 同口径：去空白、`#` 可选、必须恰好 6 位 hex。 */
    fun parseHex(value: String?): Int? {
        val raw = value?.trim().orEmpty()
        if (raw.isEmpty()) return null
        val hex = if (raw.startsWith("#")) raw.substring(1) else raw
        if (hex.length != 6) return null
        return try {
            Integer.parseInt(hex, 16) or 0xFF000000.toInt()
        } catch (_: NumberFormatException) {
            null
        }
    }

    fun relativeLuminance(argb: Int): Double {
        fun channel(raw: Int): Double {
            val v = raw / 255.0
            return if (v <= 0.03928) v / 12.92 else ((v + 0.055) / 1.055).pow(2.4)
        }
        return 0.2126 * channel(redOf(argb)) +
            0.7152 * channel(greenOf(argb)) +
            0.0722 * channel(blueOf(argb))
    }

    fun contrastRatio(a: Int, b: Int): Double {
        val la = relativeLuminance(a)
        val lb = relativeLuminance(b)
        return (maxOf(la, lb) + 0.05) / (minOf(la, lb) + 0.05)
    }

    /** 等价于 Dart `Color.lerp(a, b, t)`（不透明色，alpha 恒 255）。 */
    fun lerpArgb(a: Int, b: Int, t: Double): Int {
        fun mix(from: Int, to: Int): Int =
            (from + (to - from) * t).roundToInt().coerceIn(0, 255)
        return argbOf(
            mix(alphaOf(a), alphaOf(b)),
            mix(redOf(a), redOf(b)),
            mix(greenOf(a), greenOf(b)),
            mix(blueOf(a), blueOf(b)),
        )
    }

    /** 强调色上的墨水：亮底黑墨、暗底白墨（阈值 luminance > 0.5）。 */
    fun onAccentInk(accent: Int): Int =
        if (relativeLuminance(accent) > ON_ACCENT_INK_THRESHOLD) BLACK else WHITE

    fun resolveSeedAccent(seedHex: String?, dark: Boolean): Int? {
        val seed = parseHex(seedHex) ?: return null
        if (dark && relativeLuminance(seed) < NEAR_BLACK_LUMINANCE) return null
        return seed
    }

    fun resolveSeedSurface(seedHex: String?, dark: Boolean): Int? {
        val seed = parseHex(seedHex) ?: return null
        if (dark && relativeLuminance(seed) < NEAR_BLACK_LUMINANCE) {
            return lerpArgb(seed, WHITE, SURFACE_LIFT_MIX_DARK)
        }
        return seed
    }

    fun resolveSeedDisabled(accent: Int?, dark: Boolean): Int? {
        if (accent == null) return null
        return lerpArgb(accent, if (dark) DARK_BASE else WHITE, DISABLED_MIX)
    }

    fun resolveSeedDisabledInk(accent: Int?, dark: Boolean): Int? {
        if (accent == null) return null
        return if (dark) lerpArgb(accent, DARK_BASE, DISABLED_INK_MIX_DARK) else DISABLED_INK_LIGHT
    }

    /**
     * 在 [background] 上仍读得清的禁用态墨水：黑白两方向各取最小达标混比
     *（默认 4.5:1），与 Dart `disabledInkOn` 同算法。
     */
    fun disabledInkOn(background: Int, targetContrast: Double = 4.5): Int {
        fun toward(target: Int): Int? {
            for (step in 1..50) {
                val candidate = lerpArgb(background, target, step / 50.0)
                if (contrastRatio(candidate, background) >= targetContrast) return candidate
            }
            return null
        }
        return toward(BLACK) ?: toward(WHITE) ?: background
    }

    private fun alphaOf(argb: Int): Int = (argb ushr 24) and 0xFF
    private fun redOf(argb: Int): Int = (argb shr 16) and 0xFF
    private fun greenOf(argb: Int): Int = (argb shr 8) and 0xFF
    private fun blueOf(argb: Int): Int = argb and 0xFF

    private fun argbOf(alpha: Int, red: Int, green: Int, blue: Int): Int =
        (alpha shl 24) or (red shl 16) or (green shl 8) or blue
}
