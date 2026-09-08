package com.mutx163.qingyu

import android.graphics.Color
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * 桌面小组件「课程色贯穿」的档位。
 *
 * 与 Dart 侧 [WidgetCourseAccentMode]（lib/utils/widget_course_accent.dart）
 * 一一对应；字符串取值必须同步，否则两条数据通路会给出不同观感。
 */
enum class WidgetCourseAccentMode(val value: String) {
    OFF("off"),
    BAR("bar"),
    BAR_AND_TEXT("bar_and_text"),
    ;

    val showsBar: Boolean get() = this != OFF
    val showsText: Boolean get() = this == BAR_AND_TEXT

    companion object {
        /** 旧值/未知值一律按「条 + 字」兼容。 */
        fun fromValue(value: String?): WidgetCourseAccentMode =
            entries.firstOrNull { it.value == value } ?: BAR_AND_TEXT
    }
}

/**
 * 小组件课程色贯穿的可读性钳制：把任意课程色压/提到一个相对亮度带里。
 *
 * ## 为什么钳「相对亮度 Y」而不是 HSL 的 L
 *
 * WCAG 对比度算的是相对亮度 `Y = 0.2126R' + 0.7152G' + 0.0722B'`，绿色通道占
 * 71.5%、蓝色只占 7.2%。同一个 HSL 的 L 在不同色相下实际亮度能差三倍以上：
 * L=0.55 的黄绿接近白、同 L 的蓝紫接近黑。所以「把 L 压到某值」在冷色区等于
 * 没做、在暖色区又压过头，色条会一半隐形一半发灰。
 *
 * 这里在 **Y** 上钳制，再二分反解出对应的 L（Y 对 L 单调），色相与饱和度全程
 * 不动——「数据结构A 是绿色」不会被算法改没，只是被压到可读。
 *
 * 与 Dart 侧 [WidgetCourseAccent] 的带位常量逐项对齐，改一处必须改两处
 * （测试 `CourseWidgetAccentTest` 覆盖全色板最低对比度）。
 */
object CourseWidgetAccent {
    private const val LIGHT_BAR_MAX_Y = 0.24
    private const val LIGHT_TEXT_MAX_Y = 0.10

    private const val DARK_BAR_MIN_Y = 0.35
    private const val DARK_TEXT_MIN_Y = 0.55

    private const val GRADIENT_BAR_MIN_Y = 0.62

    /** 色条颜色；课程色缺失时返回 null（渲染侧不画条）。 */
    fun accentBarArgb(
        colorHex: String?,
        backgroundStyle: String,
        darkMode: Boolean,
    ): Int? = resolve(
        colorHex = colorHex,
        backgroundStyle = backgroundStyle,
        darkMode = darkMode,
        isText = false,
    )

    /**
     * 课程名 / 状态胶囊文字颜色。
     *
     * 渐变底例外：主标题原本统一白字（5.17~5.56:1），换成课程色最坏只有
     * 3.27:1，为「贯穿」把主标题对比度砍半不划算，故渐变底恒返回 null。
     */
    fun accentTextArgb(
        colorHex: String?,
        backgroundStyle: String,
        darkMode: Boolean,
    ): Int? = resolve(
        colorHex = colorHex,
        backgroundStyle = backgroundStyle,
        darkMode = darkMode,
        isText = true,
    )

    private fun resolve(
        colorHex: String?,
        backgroundStyle: String,
        darkMode: Boolean,
        isText: Boolean,
    ): Int? {
        if (backgroundStyle == "gradient") {
            if (isText) return null
            return clamp(colorHex, minY = GRADIENT_BAR_MIN_Y, maxY = null)
        }
        if (darkMode) {
            return clamp(
                colorHex,
                minY = if (isText) DARK_TEXT_MIN_Y else DARK_BAR_MIN_Y,
                maxY = null,
            )
        }
        return clamp(
            colorHex,
            minY = null,
            maxY = if (isText) LIGHT_TEXT_MAX_Y else LIGHT_BAR_MAX_Y,
        )
    }

    /**
     * 单向钳制：[maxY] 非空时只压暗，[minY] 非空时只提亮。
     *
     * 双向钳制会把浅卡上的深色课程**提亮**——那正好朝底色靠，对比度反而
     * 更低（#334155 被提亮后对 #F8FAFC 只有 5.4:1，原色 10.4:1）。
     */
    private fun clamp(
        colorHex: String?,
        minY: Double?,
        maxY: Double?,
    ): Int? {
        val base = parseHex(colorHex) ?: return null
        val hsl = rgbToHsl(base)
        val y = relativeLuminance(base)
        if (maxY != null && y > maxY) {
            return argbOf(
                hsl.hue,
                hsl.saturation,
                solveLightnessForLuminance(hsl.hue, hsl.saturation, maxY),
            )
        }
        if (minY != null && y < minY) {
            return argbOf(
                hsl.hue,
                hsl.saturation,
                solveLightnessForLuminance(hsl.hue, hsl.saturation, minY),
            )
        }
        return argbOf(hsl.hue, hsl.saturation, hsl.lightness)
    }

    internal fun parseHex(value: String?): Int? {
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

    internal fun relativeLuminance(argb: Int): Double {
        fun channel(raw: Int): Double {
            val value = raw / 255.0
            return if (value <= 0.03928) {
                value / 12.92
            } else {
                ((value + 0.055) / 1.055).pow(2.4)
            }
        }
        return 0.2126 * channel(Color.red(argb)) +
            0.7152 * channel(Color.green(argb)) +
            0.0722 * channel(Color.blue(argb))
    }

    internal data class Hsl(val hue: Double, val saturation: Double, val lightness: Double)

    internal fun rgbToHsl(argb: Int): Hsl {
        val r = Color.red(argb) / 255.0
        val g = Color.green(argb) / 255.0
        val b = Color.blue(argb) / 255.0
        val max = maxOf(r, g, b)
        val min = minOf(r, g, b)
        val lightness = (max + min) / 2.0
        val delta = max - min
        if (delta == 0.0) {
            return Hsl(0.0, 0.0, lightness)
        }
        val saturation = if (lightness > 0.5) {
            delta / (2.0 - max - min)
        } else {
            delta / (max + min)
        }
        val hue = when (max) {
            r -> ((g - b) / delta + (if (g < b) 6.0 else 0.0))
            g -> (b - r) / delta + 2.0
            else -> (r - g) / delta + 4.0
        } * 60.0
        return Hsl(((hue % 360.0) + 360.0) % 360.0, saturation, lightness)
    }

    internal fun hslToArgb(hue: Double, saturation: Double, lightness: Double): Int {
        val s = saturation.coerceIn(0.0, 1.0)
        val l = lightness.coerceIn(0.0, 1.0)
        if (s <= 0.0) {
            val v = (l * 255).roundToInt().coerceIn(0, 255)
            return Color.argb(255, v, v, v)
        }
        val q = if (l < 0.5) l * (1 + s) else l + s - l * s
        val p = 2 * l - q
        val h = (((hue % 360.0) + 360.0) % 360.0) / 360.0
        fun channel(t: Double): Double {
            var x = t
            if (x < 0.0) x += 1.0
            if (x > 1.0) x -= 1.0
            return when {
                x < 1.0 / 6.0 -> p + (q - p) * 6.0 * x
                x < 0.5 -> q
                x < 2.0 / 3.0 -> p + (q - p) * (2.0 / 3.0 - x) * 6.0
                else -> p
            }
        }
        val r = channel(h + 1.0 / 3.0)
        val g = channel(h)
        val b = channel(h - 1.0 / 3.0)
        return Color.argb(
            255,
            (r * 255).roundToInt().coerceIn(0, 255),
            (g * 255).roundToInt().coerceIn(0, 255),
            (b * 255).roundToInt().coerceIn(0, 255),
        )
    }

    private fun argbOf(hue: Double, saturation: Double, lightness: Double): Int =
        hslToArgb(hue, saturation, lightness)

    /** 二分反解：给定色相/饱和度，求相对亮度为 [targetY] 时的 L（Y 对 L 单调）。 */
    internal fun solveLightnessForLuminance(
        hue: Double,
        saturation: Double,
        targetY: Double,
    ): Double {
        var low = 0.0
        var high = 1.0
        repeat(50) {
            val mid = (low + high) / 2.0
            if (relativeLuminance(hslToArgb(hue, saturation, mid)) < targetY) {
                low = mid
            } else {
                high = mid
            }
        }
        return (low + high) / 2.0
    }

    /** WCAG 对比度（1.0–21.0），供单测与调试使用。 */
    internal fun contrastRatio(a: Int, b: Int): Double {
        val la = relativeLuminance(a)
        val lb = relativeLuminance(b)
        val lighter = maxOf(la, lb)
        val darker = minOf(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /** 钳制前后的色相偏移（度），供单测断言「颜色家族没被改没」。 */
    internal fun hueDriftDegrees(before: Int, after: Int): Double {
        val a = rgbToHsl(before)
        val b = rgbToHsl(after)
        val diff = abs(b.hue - a.hue)
        return if (diff > 180.0) 360.0 - diff else diff
    }
}
