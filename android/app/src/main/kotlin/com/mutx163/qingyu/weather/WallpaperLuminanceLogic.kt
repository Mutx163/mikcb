package com.mutx163.qingyu.weather

/**
 * 壁纸亮度的**纯计算**部分（Dart `lib/utils/home_page_background.dart` +
 * `lib/utils/wallpaper_luminance_profile.dart` 的可移植子集）。
 *
 * 覆盖：
 * - sRGB 线性化与 WCAG 相对亮度（引擎同款阈值 0.03928）；
 * - 逐行亮度剖面的查询/序列化（三带口径逐位一致）；
 * - 采样键构造（取景三自由度全部进键）；
 * - 墨色极性判定（顶栏 0.45 / 状态栏 0.1791 / 卡面 0.20 三套分界点）；
 * - cover 取景几何（可见源矩形）。
 *
 * 不移植（IO 清单）：图像解码与像素遍历（ui.Image / readEncodedImageSize）、
 * 文件存在性、Color 类型本身（Kotlin 侧用参数化的 Double 亮度承载）。
 */

/** WCAG 相对亮度：sRGB → 线性 → 加权（Flutter 引擎同款阈值 0.03928）。 */
fun relativeLuminanceOf(red: Int, green: Int, blue: Int): Double =
    0.2126 * linearizeSrgbComponent(red / 255.0) +
        0.7152 * linearizeSrgbComponent(green / 255.0) +
        0.0722 * linearizeSrgbComponent(blue / 255.0)

/** sRGB 单通道线性化（引擎阈值 0.03928；WCAG 2.x 的 0.04045 修正刻意不采用）。 */
fun linearizeSrgbComponent(component: Double): Double {
    if (component <= 0.03928) return component / 12.92
    return Math.pow((component + 0.055) / 1.055, 2.4)
}

/**
 * 壁纸**逐行**亮度剖面：解码后每一像素行（按 cover 裁剪出的可见列范围）的
 * 平均 WCAG 相对亮度。
 *
 * 三带平均值描述不了「这张卡坐在哪一行」——真实照片的竖直亮度跨度可以到 100 倍
 * 以上（2026-10-21 真机：日视图第三张卡坐在近黑水面上被判成中等偏亮背景，
 * 对比度 1.5:1 读不出来）。保留逐行数据后，调用方可以按任意屏幕竖直区间取那一段。
 */
class WallpaperLuminanceProfile(val rowLuminances: List<Double>) {

    val isEmpty: Boolean get() = rowLuminances.isEmpty()
    val isNotEmpty: Boolean get() = rowLuminances.isNotEmpty()

    /** 可见区域的整体平均亮度；空剖面为 null。 */
    fun average(): Double? {
        if (rowLuminances.isEmpty()) return null
        var total = 0.0
        for (value in rowLuminances) total += value
        return total / rowLuminances.size
    }

    /** average 的属性形态（与 Dart getter 同形）。 */
    val averageValue: Double? get() = average()

    /**
     * 屏幕竖直区间 `[fromFraction, toFraction)`（0~1，从上往下）的平均亮度。
     *
     * 区间收口到 `[0,1]`，按旧三带同一套 floor/ceil 取整，保证 0~0.09 这类
     * 区间与 [bands] 里的 top 逐位一致。返回 null 表示剖面不可用（调用方回落
     * 到「按主题猜」，而不是猜一个亮度出来）。
     */
    fun luminanceForVerticalRange(fromFraction: Double, toFraction: Double): Double? {
        val count = rowLuminances.size
        if (count == 0) return null
        val from = fromFraction.coerceIn(0.0, 1.0)
        val to = toFraction.coerceIn(0.0, 1.0)
        val low = if (from <= to) from else to
        val high = if (from <= to) to else from
        val fromRow = Math.floor(count * low).toInt().coerceIn(0, count - 1)
        val toRow = Math.ceil(count * high).toInt().coerceIn(fromRow + 1, count)
        var total = 0.0
        for (row in fromRow until toRow) {
            total += rowLuminances[row]
        }
        return total / (toRow - fromRow)
    }

    /** 三条 chrome 亮度带（top/weekday/body）；空剖面为 null。 */
    fun bands(): WallpaperLuminanceBands? {
        val top = luminanceForVerticalRange(0.0, 0.09) ?: return null
        val weekday = luminanceForVerticalRange(0.07, 0.20) ?: return null
        val body = luminanceForVerticalRange(0.22, 0.72) ?: return null
        return WallpaperLuminanceBands(top, weekday, body)
    }

    /** 同值判断（采样结果没变时不要通知重建）：1e-9 容差 + 长度必须一致。 */
    fun sameValuesAs(other: WallpaperLuminanceProfile?): Boolean {
        if (this === other) return true
        if (other == null || other.rowLuminances.size != rowLuminances.size) return false
        for (i in rowLuminances.indices) {
            if (Math.abs(rowLuminances[i] - other.rowLuminances[i]) > 1e-9) return false
        }
        return true
    }

    override fun equals(other: Any?): Boolean =
        other is WallpaperLuminanceProfile && sameValuesAs(other)

    override fun hashCode(): Int = rowLuminances.map { (it * 1e9).toLong() }.hashCode()

    /** 存档 / 进程间共享用：行数会随壁纸长宽比变化，必须一起序列化。 */
    fun toJson(): List<Double> = rowLuminances.toList()

    companion object {
        val empty = WallpaperLuminanceProfile(emptyList())

        fun fromJson(json: Any?): WallpaperLuminanceProfile? {
            if (json !is List<*>) return null
            val rows = ArrayList<Double>(json.size)
            for (value in json) {
                (value as? Number)?.toDouble() ?: return null
                rows.add((value as Number).toDouble())
            }
            return if (rows.isEmpty()) empty else WallpaperLuminanceProfile(rows)
        }
    }
}

/** 三条 chrome 亮度带（对应 Dart 的 record `({top, weekday, body})`）。 */
data class WallpaperLuminanceBands(
    val top: Double,
    val weekday: Double,
    val body: Double,
)

/** 壁纸缩放的上下限（编辑页与渲染侧共用一份口径）。 */
const val WALLPAPER_MIN_SCALE = 1.0
const val WALLPAPER_MAX_SCALE = 4.0

/**
 * 壁纸亮度带采样的缓存键：`路径|视口|alignX|alignY|scale`。
 *
 * 取景的三个自由度都必须进键：alignX/alignY 决定看到哪一段，scale 决定那一段
 * 被放大成什么。漏掉任何一维，「取景其实已经变了」就会继续复用旧的亮度带。
 * 三个入参都先按采样端的口径钳制，避免越界值凭空多出档位。
 */
fun homePageBackdropSampleKey(
    path: String,
    viewportKey: String,
    alignX: Double,
    alignY: Double,
    scale: Double,
): String =
    "$path|$viewportKey|" +
        "${alignX.coerceIn(-1.0, 1.0)}|" +
        "${alignY.coerceIn(-1.0, 1.0)}|" +
        "${scale.coerceIn(WALLPAPER_MIN_SCALE, WALLPAPER_MAX_SCALE)}"

/** 采样键里的视口段：拿不到有效视口时统一记成「整图采样」。 */
fun homePageBackdropViewportKey(viewportSize: String?): String =
    viewportSize ?: "full-image"

/** 墨色极性（要画的墨是什么颜色：LIGHT=白墨、DARK=黑墨；Dart 里是两个具体 Color）。 */
enum class ChromeInk { LIGHT, DARK }

/**
 * 顶栏 / 星期栏 / 时间轴 chrome 的墨色极性：亮度低于 [darkThreshold]（暗背景）→
 * 白墨，否则黑墨。亮度未知（还没采到）回落 [fallback]——按主题明暗先猜一个极性，
 * 等采样落地再修正。
 */
fun chromeInkForLuminance(
    luminance: Double?,
    darkThreshold: Double = 0.45,
    fallback: ChromeInk = ChromeInk.LIGHT,
): ChromeInk {
    if (luminance == null) return fallback
    return if (luminance < darkThreshold) ChromeInk.LIGHT else ChromeInk.DARK
}

/** 状态栏图标极性翻面的分界亮度：黑白对比度相等的那一点（解 1.05/(L+0.05)=(L+0.05)/0.06）。 */
const val STATUS_BAR_ICON_FLIP_LUMINANCE = 0.1791

/** 卡面玻璃上墨色翻黑白的分界亮度（对比度相等点 ≈ 0.20，不是顶栏那套 0.45）。 */
const val CARD_GLASS_INK_FLIP_LUMINANCE = 0.2

/** 状态栏图标用黑墨还是白墨（按 0.1791 等对比点判定：暗背景 → 白图标）。 */
fun statusBarInkFor(luminance: Double): StatusBarInk =
    if (luminance < STATUS_BAR_ICON_FLIP_LUMINANCE) StatusBarInk.White else StatusBarInk.Black

/** 状态栏图标墨色（Dart 里映射到 Brightness.dark/light）。 */
enum class StatusBarInk { Black, White }

/** 卡面玻璃墨色极性（分界点 0.20：暗卡面 → 白墨）。 */
fun cardGlassInkForLuminance(luminance: Double): ChromeInk =
    if (luminance < CARD_GLASS_INK_FLIP_LUMINANCE) ChromeInk.LIGHT else ChromeInk.DARK

/** WCAG 对比度（1.0–21.0）。 */
fun contrastRatio(a: Double, b: Double): Double {
    val lighter = maxOf(a, b)
    val darker = minOf(a, b)
    return (lighter + 0.05) / (darker + 0.05)
}

/**
 * 卡面玻璃的有效亮度：卡自己的底色与壁纸那条带按染色强度混合。
 *
 * 判字色必须用这份混合后的亮度，否则会把白字判到被冲白的卡面上
 * （浅色主题下卡面被 32%~42% 的白底冲成中灰）。
 */
fun cardGlassSurfaceLuminance(
    cardFillLuminance: Double,
    washAlpha: Double,
    wallpaperLuminance: Double,
): Double {
    val t = washAlpha.coerceIn(0.0, 1.0)
    return cardFillLuminance * t + wallpaperLuminance * (1.0 - t)
}

/** cover 取景下的可见源矩形（占源图的比例）。 */
data class WallpaperSourceRect(
    val left: Double,
    val top: Double,
    val width: Double,
    val height: Double,
)

/**
 * [imageSize] 以 cover 方式渲染进 [viewportSize]、对齐 [alignX]/[alignY]、
 * 放大 [zoom] 倍时，源图上实际可见的矩形（比例坐标）。
 *
 * 与渲染端同一套几何：亮度采样不会看到屏幕外的那部分横/竖壁纸。用户放大倍数
 * 让取景窗口按比例缩小（可见比例 ÷ 倍数），位置仍由对齐值决定——align=-1/0/+1
 * 三处与不放大时完全一致。
 */
fun homePageWallpaperVisibleSourceRect(
    viewportSize: String,
    imageSize: String,
    alignX: Double = 0.0,
    alignY: Double = 0.0,
    zoom: Double = 1.0,
): WallpaperSourceRect {
    val (vw, vh) = parseSize(viewportSize)
    val (iw, ih) = parseSize(imageSize)
    if (vw <= 0 || vh <= 0 || iw <= 0 || ih <= 0 ||
        !vw.isFinite() || !vh.isFinite() || !iw.isFinite() || !ih.isFinite()
    ) {
        return WallpaperSourceRect(0.0, 0.0, 1.0, 1.0)
    }
    val viewportAspect = vw / vh
    val imageAspect = iw / ih
    val visibleWidth = if (imageAspect > viewportAspect) viewportAspect / imageAspect else 1.0
    val visibleHeight = if (imageAspect < viewportAspect) imageAspect / viewportAspect else 1.0
    val normalizedAlignX = alignX.coerceIn(-1.0, 1.0)
    val normalizedAlignY = alignY.coerceIn(-1.0, 1.0)
    val zoomed = zoom.coerceIn(WALLPAPER_MIN_SCALE, WALLPAPER_MAX_SCALE)
    val visibleWidthAtZoom = visibleWidth / zoomed
    val visibleHeightAtZoom = visibleHeight / zoomed
    val left = (1.0 - visibleWidthAtZoom) * (normalizedAlignX + 1.0) / 2.0
    val top = (1.0 - visibleHeightAtZoom) * (normalizedAlignY + 1.0) / 2.0
    return WallpaperSourceRect(left, top, visibleWidthAtZoom, visibleHeightAtZoom)
}

private fun parseSize(text: String): Pair<Double, Double> {
    val parts = text.lowercase().split("x", "×", "*")
    if (parts.size != 2) return Pair(0.0, 0.0)
    val w = parts[0].trim().toDoubleOrNull() ?: return Pair(0.0, 0.0)
    val h = parts[1].trim().toDoubleOrNull() ?: return Pair(0.0, 0.0)
    return Pair(w, h)
}
