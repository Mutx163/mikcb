package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.imagecache.ImageSizeSelector
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * 首页壁纸背景的**纯算术层**（无 Compose / Android 依赖，JVM 单测直接钉）。
 *
 * ## 对照物（唯一判据是 Dart 源码，别自己编数）
 *
 * | 这里 | Dart |
 * |---|---|
 * | [HomeBackgroundModel.coverScale] / [HomeBackgroundModel.drawRect] | `lib/utils/home_page_background.dart:531-580`（`Image(fit: cover)` + `Transform.scale(alignment:)`） |
 * | [HomeBackgroundModel.decodeWidthPx] / [HomeBackgroundModel.decodePlan] | `:192-213`（`homePageBackdropDecodeWidth` + `ResizeImage(width:)`） |
 * | [HomeBackgroundModel.clampScale] / [HomeBackgroundModel.clampBlurSigma] | `:552-587`（`kWallpaperMinScale` / `kWallpaperMaxScale`、sigma 夹 0…24） |
 * | [HomeBackgroundModel.backdropKey] / [HomeBackdropSnapshot.hasWallpaper] | `:346-392`（`resolveHomePageBackdropImagePath` / `homePageBackdropKey`） |
 * | [HomeBackgroundModel.resolvePageColorArgb] | `:273-285` + `lib/utils/hex_color.dart:3-21` |
 * | [HomeBackdropScope] / [HomeBackdropRegion] / [HomeBackgroundModel.regionPaint] | `:467-501` + `lib/models/settings/timetable_settings_enums.dart:110-125` |
 * | 墨色极性 [HomeBackgroundModel.chromeInkPolarity] / [HomeBackgroundModel.cardGlassInkPolarity] | 2026-11-07 起改为**白/近黑 WCAG 对比度择优**（不再用 0.45 / 0.20 阈值）；状态栏仍按 `:287-343` 的 0.1791 |
 * | [HomeBackgroundModel.cardGlassSurfaceLuminance] | `:809-820` |
 * | [HomeBackgroundModel.hasSufficientContrast] | `:863-878` |
 * | [HomeBackgroundModel.relativeLuminance] / [HomeBackgroundModel.meanRelativeLuminance] / [HomeBackgroundModel.bandRows] | `:1330-1358`（逐像素 sRGB 线性化 + 三带 floor/ceil）+ `lib/utils/wallpaper_luminance_profile.dart:61-88` |
 * | [HomeBackgroundModel.exifRotationDegrees] | Dart 侧由引擎解码时自动按 EXIF 摆正（`FileImage`），这里显式补上 |
 *
 * ## Kotlin 设置模型目前**缺**的一项（别在这层伪造）
 *
 * 1. `homePageBackgroundScope`（区域位标志）——Kotlin 侧没有，`pages/diagnostics/
 *    PerformanceSettingsSnapshot.kt:153` 已把它记成已知缺口。所以 [HomeBackdropSnapshot.scope]
 *    默认 [HomeBackdropScope.DEFAULT]（= 四区全铺，与 Dart 默认值一致）。
 *
 * （`timetablePageBackgroundColor` 已在 `TimetableSettingsModel` 里；宿主
 * `TimetableHost` 从 2026-11-01 起把 `pageColorHex` 传给 [snapshotOf]，页底色真正上屏。）
 *
 * ## 谁在用
 *
 * 只有 `composeP1/.../pages/shell/HomeWallpaperBackdrop.kt` 一个消费者；接线方式（建快照 → 传给
 * 组件）写在那份文件的文件头。本文件不碰磁盘以外的任何系统能力，唯一 IO 是
 * [HomeBackgroundModel.backdropKey] 的 `exists` 回调（默认 `java.io.File.exists()`，与 Dart
 * `_homePageFileExistsSync` 同口径；单测注入假判据，不依赖真实文件）。
 */

/** 首页背景可以单独铺图的区域（Dart `HomePageBackgroundScope` 的四个位）。 */
enum class HomeBackdropRegion(val bit: Int) {
    /** 课表（周/日/月视图本体）。 */
    Timetable(1),

    /** 星期条。 */
    WeekdayBar(2),

    /** 顶栏（标题行）。 */
    Header(4),

    /** 状态栏。 */
    StatusBar(8),
}

/** 区域位标志的读写口径，与 Dart `HomePageBackgroundScope`（`timetable_settings_enums.dart:111-125`）逐值一致。 */
object HomeBackdropScope {
    const val TIMETABLE = 1
    const val WEEKDAY_BAR = 2
    const val HEADER = 4
    const val STATUS_BAR = 8

    /** 默认四区全铺（Dart `defaultValue`，无壁纸时无感知）。 */
    const val DEFAULT = TIMETABLE or WEEKDAY_BAR or HEADER or STATUS_BAR

    fun includes(scope: Int, region: Int): Boolean = (scope and region) != 0

    fun toggle(scope: Int, region: Int, enabled: Boolean): Int =
        if (enabled) scope or region else scope and region.inv()

    fun includes(scope: Int, region: HomeBackdropRegion): Boolean = includes(scope, region.bit)
}

/** 墨色极性：浅墨 = 上白/近白字（压在深色壁纸上），深墨 = 上近黑字（压在浅色壁纸上）。 */
enum class HomeInkPolarity {
    /** 深墨（Dart `homePageChromeForegroundOnLight` = `0xFF1A1A1A`），用于**浅**壁纸。 */
    Dark,

    /** 浅墨（Dart `homePageChromeForegroundOnDark` = `0xFFFFFFFF`），用于**深**壁纸。 */
    Light,
}

/** 一次绘制里壁纸该占的矩形（屏幕物理像素，原点在视口左上角；左/上可为负 = 溢出视口）。 */
data class HomeBackdropRect(
    val left: Double,
    val top: Double,
    val width: Double,
    val height: Double,
)

/** 解码计划：目标尺寸决定「够用就行」，[inSampleSize] 是 `BitmapFactory` 的 2 的幂采样值。 */
data class HomeBackdropDecodePlan(
    val targetWidthPx: Int,
    val targetHeightPx: Int,
    val inSampleSize: Int,
)

/** 尺寸（[HomeBackgroundModel.orientedSize] 的返回）。 */
data class HomeBackdropSize(val width: Int, val height: Int)

/** 某个区域的底色决策：`colorArgb == null` 表示**透明**（透出壁纸那一层）。 */
data class HomeBackdropRegionPaint(val colorArgb: Int?) {
    val isTransparent: Boolean get() = colorArgb == null

    companion object {
        val Transparent = HomeBackdropRegionPaint(null)

        fun solid(argb: Int) = HomeBackdropRegionPaint(argb)
    }
}

/**
 * 首页背景的**不可变快照**：渲染层只认这个对象，不再回头读设置。
 *
 * 所有数值在这层已经收口（scale 1…4、align -1…1、sigma 0…24、decodeWidth 720…2160），
 * 渲染层拿到什么就用什么，不需要也不许再夹一次——否则两处口径分叉就会出现
 * 「设置页读数 4 倍、屏幕上是 3.7 倍」这种对不上的问题。
 */
data class HomeBackdropSnapshot(
    /** 已确认可用的壁纸绝对路径；`null` = 没有壁纸（回退纯色底）。 */
    val wallpaperPath: String?,
    val alignX: Double,
    val alignY: Double,
    /** 放大倍数，1 = cover 原大小（Dart `kWallpaperMinScale`…`kWallpaperMaxScale`）。 */
    val scale: Double,
    /** 壁纸高斯模糊 sigma（逻辑像素 = dp，Dart 口径），0 = 不模糊。 */
    val blurSigma: Double,
    /** 按宽下采样的目标宽（物理像素）；解码器据此算 `inSampleSize`。 */
    val decodeWidthPx: Int,
    /** 区域位标志，见 [HomeBackdropScope]。 */
    val scope: Int,
    /** 无壁纸 / 该区域不铺壁纸时的底色（ARGB；由调用方从主题语义槽取，模型不写颜色字面量）。 */
    val pageColorArgb: Int,
    /** 背景是否跟着周次翻页一起滑动（Dart `homePageBackdropFollowsWeekPager`）。 */
    val followsWeekPager: Boolean,
) {
    val hasWallpaper: Boolean get() = !wallpaperPath.isNullOrEmpty()

    /** 该区域是否透出壁纸（Dart `homePageRegionShowsBackdrop`，`home_page_background.dart:467-475`）。 */
    fun showsBackdrop(region: HomeBackdropRegion): Boolean =
        hasWallpaper && HomeBackdropScope.includes(scope, region.bit)

    /** 该区域该画什么：透明（壁纸）还是纯色（Dart `resolveHomePageRegionBackground`）。 */
    fun regionPaint(region: HomeBackdropRegion): HomeBackdropRegionPaint =
        if (showsBackdrop(region)) {
            HomeBackdropRegionPaint.Transparent
        } else {
            HomeBackdropRegionPaint.solid(pageColorArgb)
        }

    /** 跟着周页滑动时，同一张壁纸在相邻页上的重复次数（见 [HomeBackgroundModel.stripPageOffsets]）。 */
    fun stripPageOffsets(weekPageOffset: Float): List<Float> =
        if (followsWeekPager) HomeBackgroundModel.stripPageOffsets(weekPageOffset) else listOf(0f)
}

object HomeBackgroundModel {

    // ───────────── 常量（全部抄自 Dart，改一处就要改对照表） ─────────────

    /** 放大倍数下限：1 = 刚好铺满（`cover` 的原始大小），再小就露底色。`home_page_background.dart:586-587`。 */
    const val MIN_SCALE = 1.0

    /** 放大倍数上限：4 倍够看细节，再大只是糊（`:587`）。 */
    const val MAX_SCALE = 4.0

    /** 壁纸模糊下限（`timetable_settings.dart:353`，0 = 不模糊）。 */
    const val MIN_BLUR_SIGMA = 0.0

    /** 壁纸模糊上限（`:354`）。 */
    const val MAX_BLUR_SIGMA = 24.0

    /** 按宽解码的下限（`home_page_background.dart:199` 的 `clamp(720, 2160)`）。 */
    const val MIN_DECODE_WIDTH_PX = 720

    /** 按宽解码的上限（同上）。 */
    const val MAX_DECODE_WIDTH_PX = 2160

    /** 拿不到视口时的解码宽兜底（`:196` 的 `1440`）。 */
    const val FALLBACK_DECODE_WIDTH_PX = 1440


    /**
     * 状态栏图标极性的分界（`:310` 的 `statusBarIconFlipLuminance = 0.1791`）。
     *
     * 判据方向与上面两个**相反**：这里算的是「状态栏该配什么底色」——
     * 亮度 > 0.1791 配白底（深色图标），否则配深底（浅色图标）。
     */
    const val STATUS_BAR_INK_FLIP_LUMINANCE = 0.1791

    /** 浅墨（白字）那次级墨色的透明度（`:730-733`）。 */
    const val MUTED_ALPHA_LIGHT_INK = 0.72

    /** 深墨（近黑字）那次级墨色的透明度（`:730-733`）。 */
    const val MUTED_ALPHA_DARK_INK = 0.62

    /** 字色对壁纸至少要有 3:1 对比度，低于此值视为「压在照片上看不见」（`:869-878`）。 */
    const val MIN_INK_CONTRAST_RATIO = 3.0

    /** 浅色壁纸上的深墨（Dart `homePageChromeForegroundOnLight`，`:709-712`）。 */
    val ON_LIGHT_INK_ARGB: Int = 0xFF1A1A1A.toInt()

    /** 深色壁纸上的浅墨（Dart `homePageChromeForegroundOnDark`，`:709-712`）。 */
    val WHITE_ARGB: Int = 0xFFFFFFFF.toInt()

    /**
     * 顶栏 / 状态栏那条亮度带的竖直区间（Dart `home_page_background.dart:1355` 的
     * `band(0, 0.09)`，也就是 `bands.top`）。
     *
     * ⚠️ 不是「顶部 1/3」：Dart 判顶栏墨色读的是**顶部 9%**（状态栏 + 标题行那一带）。
     * 取 1/3 会把屏幕中段（星期条以下、卡片区开头）混进来，平均后被冲淡，
     * 深色壁纸容易被判成浅色 ⇒ 深墨压深底。区间沿用 Dart，改这里等于改行为。
     */
    const val CHROME_TOP_BAND_FROM = 0.0
    const val CHROME_TOP_BAND_TO = 0.09

    /** 星期条那条带（`:1356`，Dart `bands.weekday`）。 */
    const val WEEKDAY_BAND_FROM = 0.07
    const val WEEKDAY_BAND_TO = 0.20

    /** 日视图内容卡那片区域（`:1357`，Dart `bands.body`）。 */
    const val BODY_BAND_FROM = 0.22
    const val BODY_BAND_TO = 0.72

    /**
     * 玻璃坞（底部药丸）压住的那条带：从药丸上沿到系统手势条上沿。
     *
     * 这是 Compose 侧新加的第四条带（Dart 旧版没有，坞借的是 `body`）：坞贴在屏幕
     * **底部**，而正文带在 0.72 就截止了。照片下半部（山体 / 建筑 / 夜色）通常比
     * 中段暗得多，「正文区亮、坞底下暗」时按正文带判会把坞的字判成深色，压在暗底上
     * 看不见（2026-11-03 用户报「底栏字体反色有问题」的真机截图就是这种构图）。
     * 区间取药丸本体（高 64dp + 底部内边距，约在 78%~96% 视口高），不含状态栏侧。
     */
    const val DOCK_BAND_FROM = 0.78
    const val DOCK_BAND_TO = 0.96

    /**
     * miuix-blur 的 blur **半径**换算成 sigma 的斜率。
     *
     * 出处：`top.yukonga.miuix.kmp.blur` 内部 `BLUR_RADIUS_TO_SIGMA = 0.45f`
     * （`blur/internal/BlurEffect.kt:22`，`BackdropEffects.blur` 直接乘它）。
     *
     * 为什么需要这一条：Dart 的 `ImageFilter.blur(sigmaX:)` 直接吃 **sigma**（逻辑像素），
     * 而 miuix 的 `blur(radiusX)` 吃的是 **半径**（像素）。把 sigma 当半径传，糊度会
     * 偏小约 2.2 倍，设置页读数与屏幕观感对不上。
     *
     * ⚠️ **被守卫引用**：`components/TopBarProgressiveBlurGuardTest` 内联了同一个 `0.45`
     * 当期望值（它不 import 本常量——引用被测模块的常量会让「漂移」也一起漂，守卫就失效了）。
     * 改这里的值时，去那边同步，并顺手确认那个守卫仍能红。
     */
    const val MIUIX_BLUR_SIGMA_PER_RADIUS = 0.45

    /**
     * sigma 到这个值以下一律按「不模糊」处理（Dart 侧 0 档 = 原图直出，别为看不见的模糊
     * 白跑一遍采样 + 高斯链）。
     */
    const val BLUR_SIGMA_MIN_EFFECTIVE = 0.5

    // ───────────── 数值收口 ─────────────

    /** 对齐值夹进 -1…1（Dart `home_page_background.dart:537-538`）；NaN 按 0 处理（居中）。 */
    fun clampAlign(value: Double): Double =
        if (value.isNaN()) 0.0 else value.coerceIn(-1.0, 1.0)

    /** 放大倍数夹进 1…4（`:567-570`）；NaN 按 1 处理（出厂档）。 */
    fun clampScale(value: Double): Double =
        if (value.isNaN()) MIN_SCALE else value.coerceIn(MIN_SCALE, MAX_SCALE)

    /** 模糊 sigma 夹进 0…24（`:552-555`）；NaN 按 0 处理（不模糊）。 */
    fun clampBlurSigma(value: Double): Double =
        if (value.isNaN()) MIN_BLUR_SIGMA else value.coerceIn(MIN_BLUR_SIGMA, MAX_BLUR_SIGMA)

    // ───────────── 绘制几何 ─────────────

    /**
     * `BoxFit.cover` 的基准倍率：`max(视口宽/图宽, 视口高/图高)`。
     *
     * 也就是「图至少铺满视口」所需的最小放大。任何一维非正都返回 0（不可绘制），
     * 调用方据此跳过绘制而不是画一个 0 尺寸矩形。
     */
    fun coverScale(imageWidth: Int, imageHeight: Int, viewportWidth: Int, viewportHeight: Int): Double {
        if (imageWidth <= 0 || imageHeight <= 0 || viewportWidth <= 0 || viewportHeight <= 0) return 0.0
        return max(
            viewportWidth.toDouble() / imageWidth,
            viewportHeight.toDouble() / imageHeight,
        )
    }

    /**
     * 壁纸最终在屏幕上占的矩形（`cover` × 用户倍数，绕对齐点放大）。
     *
     * ## 为什么是「按放大后的溢出量」而不是「基础溢出 × 倍数」
     *
     * Dart 是 `Image(fit: cover, alignment: a)` 外套 `Transform.scale(scale: s, alignment: a)`
     * （`home_page_background.dart:540-579`）。`Transform.scale` 绕**对齐点**缩放，把
     * `left = -(cover宽 - 视口宽) × (a+1)/2` 代入「绕点缩放」展开后，等价于
     *
     * ```
     * 宽 = 图宽 × cover × s
     * left = -(宽 - 视口宽) × (a+1)/2
     * ```
     *
     * 也就是「放大**之后**的溢出量」乘以对齐比例。`home_page_background.dart:575-578`
     * 的注释原话：「溢出量随之变大（放大 s 倍后是 `s × 封面尺寸 − 视口尺寸`，不是
     * 『基础溢出 × s』）」。
     *
     * 返回 `null` 表示这一帧画不了（图或视口有非正维），调用方跳过绘制。
     */
    fun drawRect(
        imageWidth: Int,
        imageHeight: Int,
        viewportWidth: Int,
        viewportHeight: Int,
        scale: Double,
        alignX: Double,
        alignY: Double,
    ): HomeBackdropRect? {
        val base = coverScale(imageWidth, imageHeight, viewportWidth, viewportHeight)
        if (base <= 0.0) return null
        val s = clampScale(scale)
        val ax = (clampAlign(alignX) + 1.0) / 2.0
        val ay = (clampAlign(alignY) + 1.0) / 2.0
        val width = imageWidth * base * s
        val height = imageHeight * base * s
        return HomeBackdropRect(
            left = -(width - viewportWidth) * ax,
            top = -(height - viewportHeight) * ay,
            width = width,
            height = height,
        )
    }

    /**
     * 壁纸在 `cover` + 取景倍数 / 对齐下，**屏幕上真正可见的那块原图**（比例 0..1）。
     *
     * Dart `homePageWallpaperVisibleSourceRect`（`home_page_background.dart:1067-1111`）：
     * 三档亮度带与逐行剖面都在**这块矩形里**取比例，而不是拿整张原图的行号。
     * 用户把壁纸放大 2 倍并居中时，屏幕顶部那块壁纸其实来自原图的中上部；
     * 按原图 0..9% 取样会量到画外像素（2026-11-01 审计发现）。
     */
    data class VisibleSourceRect(
        val leftFraction: Double,
        val topFraction: Double,
        val widthFraction: Double,
        val heightFraction: Double,
    )

    fun visibleSourceRect(
        imageWidth: Int,
        imageHeight: Int,
        viewportWidth: Int,
        viewportHeight: Int,
        scale: Double,
        alignX: Double,
        alignY: Double,
    ): VisibleSourceRect? {
        val rect = drawRect(
            imageWidth = imageWidth,
            imageHeight = imageHeight,
            viewportWidth = viewportWidth,
            viewportHeight = viewportHeight,
            scale = scale,
            alignX = alignX,
            alignY = alignY,
        ) ?: return null
        if (rect.width <= 0.0 || rect.height <= 0.0) return null
        val left = (-rect.left / rect.width).coerceIn(0.0, 1.0)
        val top = (-rect.top / rect.height).coerceIn(0.0, 1.0)
        val width = (viewportWidth / rect.width).coerceIn(0.0, 1.0 - left)
        val height = (viewportHeight / rect.height).coerceIn(0.0, 1.0 - top)
        return VisibleSourceRect(left, top, width, height)
    }

    /**
     * 跟周页滑动时，同一张壁纸要画几次、每次偏移多少「页宽」。
     *
     * Dart `HomePageSlidingBackdropLayer`（`:657-707`）把整屏壁纸当作一条长条，按
     * `controller.page` 平移；每页画的都是同一张图，所以要**相邻页也画一份**，
     * 否则滑动到一半时侧边会露出页面底色。偏移单位是「页宽」（= 视口宽）。
     *
     * 偏移 0（静止）时只返回一个 0 —— 多画两份是纯浪费。
     */
    fun stripPageOffsets(weekPageOffset: Float): List<Float> {
        val offset = if (weekPageOffset.isNaN()) 0f else weekPageOffset
        if (offset == 0f) return listOf(0f)
        return listOf(offset - 1f, offset, offset + 1f)
    }

    // ───────────── 解码 ─────────────

    /** 按宽解码的目标宽（物理像素）：无有效视口 → 1440，否则夹进 720…2160（`:192-200`）。 */
    fun decodeWidthPx(viewportWidthPx: Int?): Int {
        if (viewportWidthPx == null) return FALLBACK_DECODE_WIDTH_PX
        return viewportWidthPx.coerceIn(MIN_DECODE_WIDTH_PX, MAX_DECODE_WIDTH_PX)
    }

    /**
     * 解码计划：目标宽 [targetWidthPx]（先按 [decodeWidthPx] 的口径收口），
     * 目标高按原图比例反推，采样值复用 `app/imagecache/ImageSizeSelector`
     * （与 `AndroidImageLoader` 同一个 2 的幂算法，不另写一份）。
     *
     * 源图或目标非正 → `null`（没法解）。
     */
    fun decodePlan(sourceWidth: Int, sourceHeight: Int, targetWidthPx: Int): HomeBackdropDecodePlan? {
        if (sourceWidth <= 0 || sourceHeight <= 0 || targetWidthPx <= 0) return null
        val width = targetWidthPx.coerceIn(MIN_DECODE_WIDTH_PX, MAX_DECODE_WIDTH_PX)
        val height = max(1, ((sourceHeight.toLong() * width).toDouble() / sourceWidth).roundToInt())
        val sample = ImageSizeSelector.inSampleSize(sourceWidth, sourceHeight, width, height)
        return HomeBackdropDecodePlan(targetWidthPx = width, targetHeightPx = height, inSampleSize = sample)
    }

    /**
     * Dart 侧 `ImageFilter.blur(sigma)` 的 sigma（逻辑像素）→ miuix-blur
     * `blur(radiusX)` 该传的半径（**像素**，不是 dp）。
     *
     * 半径 = sigma ÷ [MIUIX_BLUR_SIGMA_PER_RADIUS] × 屏幕密度（sigma 是逻辑像素，
     * miuix 的半径是物理像素）。sigma ≤ [BLUR_SIGMA_MIN_EFFECTIVE] 时返回 0（= 走原图）。
     *
     * **别拿旧的 Compose 口径来套**：`Modifier.blur` 的半径是 dp、且
     * `sigma = radius × 0.57735 + 0.5`；同一个 sigma 下 miuix 要的半径更大，
     * 两套混用会变成「设置里拉到最大，屏幕上几乎没糊」。
     */
    fun blurRadiusPxForSigma(sigma: Double, density: Float): Double {
        val clamped = clampBlurSigma(sigma)
        if (clamped <= BLUR_SIGMA_MIN_EFFECTIVE) return 0.0
        val scale = density.coerceAtLeast(0f).toDouble()
        return clamped / MIUIX_BLUR_SIGMA_PER_RADIUS * scale
    }

    /**
     * EXIF 方向 → 需要顺时针旋转的角度（0 / 90 / 180 / 270）。
     *
     * Flutter 解码时由引擎按 EXIF 摆正，`BitmapFactory` **不会**：不补这一步，手机拍的
     * 竖图会横躺在首页上。只处理旋转（1/3/6/8 四种，覆盖绝大多数照片）；
     * 镜像档（2/4/5/7）按不旋转处理，已在报告里记为未验项。
     */
    fun exifRotationDegrees(orientation: Int): Int = when (orientation) {
        3 -> 180
        6 -> 90
        8 -> 270
        else -> 0
    }

    /** 旋转后图片的显示尺寸：90 / 270 度要把宽高对调。 */
    fun orientedSize(width: Int, height: Int, rotationDegrees: Int): HomeBackdropSize =
        if (rotationDegrees == 90 || rotationDegrees == 270) {
            HomeBackdropSize(width = height, height = width)
        } else {
            HomeBackdropSize(width = width, height = height)
        }

    // ───────────── 墨色建议（阈值全抄 Dart，别自己定 0.5） ─────────────

    /**
     * 顶栏 / 标题墨色：壁纸亮度上**白墨与近黑墨谁对比度高就用谁**。
     *
     * 2026-11-07 之前这里是硬阈值 0.45（发布版那套「背景多暗才配白字」）。阈值在
     * 0.20–0.45 这一段是错的：亮度 0.30 的壁纸配白字只有 3.0:1、配近黑有 5.8:1，
     * 白字反而更难读。现在按 [HomeBackgroundModel.relativeLuminance] 的 WCAG 对比度
     * 择优，分界点自动落在 ~0.2017（近黑 `#1A1A1A` 与纯白的相等点）。
     *
     * 亮度未知（没壁纸 / 首帧）⇒ 深墨（浅色主题兜底，旧行为不变）。
     */
    fun chromeInkPolarity(wallpaperLuminance: Double?): HomeInkPolarity {
        if (wallpaperLuminance == null) return HomeInkPolarity.Dark
        return if (contrastOnLuminance(WHITE_ARGB, wallpaperLuminance) >=
            contrastOnLuminance(ON_LIGHT_INK_ARGB, wallpaperLuminance)
        ) {
            HomeInkPolarity.Light
        } else {
            HomeInkPolarity.Dark
        }
    }

    /**
     * 日视图**内容卡**玻璃档的墨色：同样按对比度择优（不再用写死的 0.20）。
     *
     * 传进来的亮度应当是 [cardGlassSurfaceLuminance] 的结果（卡面混合后的亮度），
     * 不是裸壁纸亮度。
     */
    fun cardGlassInkPolarity(surfaceLuminance: Double?): HomeInkPolarity {
        if (surfaceLuminance == null) return HomeInkPolarity.Dark
        return if (contrastOnLuminance(WHITE_ARGB, surfaceLuminance) >=
            contrastOnLuminance(ON_LIGHT_INK_ARGB, surfaceLuminance)
        ) {
            HomeInkPolarity.Light
        } else {
            HomeInkPolarity.Dark
        }
    }

    /**
     * 状态栏系统图标极性（`resolveHomePageStatusBarBackground`，`:318-343`）。
     *
     * 方向与上面两个相反：亮度 **> 0.1791** → 状态栏配白底 = 深色图标（[HomeInkPolarity.Dark]）；
     * 否则配深底 = 浅色图标（[HomeInkPolarity.Light]）。正好等于 0.1791 时按「不大于」算，
     * 也就是浅色图标（与 Dart 的 `>` 严格比较一致）。
     */
    fun statusBarInkPolarity(wallpaperLuminance: Double?): HomeInkPolarity {
        if (wallpaperLuminance == null) return HomeInkPolarity.Light
        return if (wallpaperLuminance > STATUS_BAR_INK_FLIP_LUMINANCE) {
            HomeInkPolarity.Dark
        } else {
            HomeInkPolarity.Light
        }
    }

    /** 次级（muted）墨色的透明度：浅墨 0.72，深墨 0.62（Dart `homePageChromeMutedForeground`）。 */
    fun mutedInkAlpha(polarity: HomeInkPolarity): Float = when (polarity) {
        HomeInkPolarity.Light -> MUTED_ALPHA_LIGHT_INK.toFloat()
        HomeInkPolarity.Dark -> MUTED_ALPHA_DARK_INK.toFloat()
    }

    /**
     * 卡面玻璃的**有效亮度**：卡自己的底色亮度 × 染色强度 + 壁纸亮度 × (1 − 染色强度)
     * （Dart `cardGlassSurfaceLuminance`，`:813-820`）。
     *
     * 只看壁纸会把白字判到「被白底冲成中灰」的卡面上，是 2026-09-22 真机反馈的那条旧账。
     */
    fun cardGlassSurfaceLuminance(
        cardFillLuminance: Double,
        washAlpha: Double,
        wallpaperLuminance: Double,
    ): Double {
        val t = if (washAlpha.isNaN()) 0.0 else washAlpha.coerceIn(0.0, 1.0)
        return cardFillLuminance * t + wallpaperLuminance * (1 - t)
    }

    /** 字色对背景是否还有 ≥ [minContrastRatio] 的对比度（Dart `homePageInkHasSufficientContrast`）。 */
    fun hasSufficientContrast(
        inkLuminance: Double,
        wallpaperLuminance: Double,
        minContrastRatio: Double = MIN_INK_CONTRAST_RATIO,
    ): Boolean {
        val hi = max(inkLuminance, wallpaperLuminance)
        val lo = minOf(inkLuminance, wallpaperLuminance)
        return (hi + 0.05) / (lo + 0.05) >= minContrastRatio
    }

    // ───────────── 压在壁纸上的墨色（Dart `homePageOverWallpaper*`） ─────────────

    /**
     * 壁纸三档亮度带（Dart `home_page_background.dart:1320-1357`）：
     * 顶栏 `0..0.09`、星期栏 `0.07..0.20`、正文 `0.22..0.72`。
     *
     * 「顶栏」那一档决定 chrome 的翻面；星期栏/正文档位决定**压在壁纸上的那些字**
     * （星期栏、时间列、日视图空态）该用深墨还是浅墨。三档来自同一张位图、一次扫描。
     */
    data class InkBands(val top: Double?, val weekday: Double?, val body: Double?, val dock: Double? = null)

    /**
     * 压在壁纸上的墨色（Dart `homePageOverWallpaperInk`，`home_page_background.dart:763-799`）。
     *
     * * 没有壁纸 / 亮度未知 ⇒ 用配置色（没有配置色就用主题兜底）；
     * * **没配置 / 就是内置默认色** ⇒ 按亮度直接翻黑 / 白（Dart `:794-798`）；
     * * 配置色**本身对比度够**（≥ 3:1）⇒ 原样保留（尊重用户在设置里挑的颜色）；
     * * 不够 ⇒ 保持色相，**朝白和朝黑都推**（5% 一步，最多 20 步），取先到 3:1 的那侧；
     * * 两侧都推不到 ⇒ 按亮度翻黑 / 白（深壁纸白、浅壁纸近黑）。
     *
     * 这条是「黑色壁纸上黑字」的根治：以前星期栏 / 时间列 / 空态都直接用主题或设置里的
     * 深色字，压在深壁纸上看不见（2026-11-01 用户报）。
     */
    fun inkOverWallpaperArgb(
        configuredArgb: Int?,
        fallbackArgb: Int,
        wallpaperLuminance: Double?,
        /**
         * 这一项的**内置默认色**（设置里的「没改过」等价于这个值）。传了就按 Dart
         * `homePageInkUsesBuiltInDefault`（`:740-750`）处理：默认色 = 直接翻黑 / 白，
         * 不走进「保色相推亮度」那条 —— 否则深壁纸上的黑字会被推成中灰而不是纯白。
         */
        builtInDefaultArgb: Int? = null,
    ): Int {
        if (wallpaperLuminance == null) return configuredArgb ?: fallbackArgb
        val configured = configuredArgb?.takeIf { it != builtInDefaultArgb }
        // 没配置 / 就是内置默认 ⇒ 按亮度翻黑 / 白（Dart `:794-798`）。
        if (configured == null) return flipInkArgb(wallpaperLuminance)
        if (hasSufficientContrast(relativeLuminance(configured), wallpaperLuminance)) {
            return configured
        }
        // 两侧都试：先到 3:1 的那一侧胜出（Dart `:936-996`）。只朝一侧推会在中灰壁纸上
        // 永远到不了 3:1（例：亮度 0.40 时白色最多 2.33:1），然后掉进一个更差的结果。
        val toWhite = pushTowardContrast(configured, WHITE_ARGB, wallpaperLuminance)
        val toBlack = pushTowardContrast(configured, ON_LIGHT_INK_ARGB, wallpaperLuminance)
        return when {
            toWhite != null && toBlack != null ->
                if (toWhite.second <= toBlack.second) toWhite.first else toBlack.first
            toWhite != null -> toWhite.first
            toBlack != null -> toBlack.first
            // 两侧都推不到（物理上不可能有 3:1）⇒ 按波段极性翻黑 / 白（Dart `:968`）。
            else -> flipInkArgb(wallpaperLuminance)
        }
    }

    /**
     * 按亮度翻黑 / 白：**白墨与近黑墨里对比度更高的那一档**（旧版是写死 0.45 阈值）。
     *
     * 阈值在 0.20–0.45 这段会把该用近黑的中灰背景判成白字（对比度掉到 1.7–3.0:1）；
     * 现在直接比 WCAG 对比度，分界点自动落在约 0.2017（近黑 `#1A1A1A` 与纯白的相等点）。
     */
    fun flipInkArgb(wallpaperLuminance: Double): Int =
        if (contrastOnLuminance(WHITE_ARGB, wallpaperLuminance) >=
            contrastOnLuminance(ON_LIGHT_INK_ARGB, wallpaperLuminance)
        ) {
            WHITE_ARGB
        } else {
            ON_LIGHT_INK_ARGB
        }

    /** [inkArgb] 在亮度为 [backgroundLuminance] 的背景上的 WCAG 对比度（1–21）。 */
    private fun contrastOnLuminance(inkArgb: Int, backgroundLuminance: Double): Double {
        val inkLuminance = relativeLuminance(inkArgb)
        val hi = max(inkLuminance, backgroundLuminance)
        val lo = minOf(inkLuminance, backgroundLuminance)
        return (hi + 0.05) / (lo + 0.05)
    }

    /**
     * 解析设置里的墨色：`#RRGGBB` 与 `#AARRGGBB` 都接受（8 位只取 RGB）。
     *
     * 比 [parseHexArgb] 宽松一位：设置页的规范化允许 9 字符（`#AARRGGBB`），
     * 用严格 6 位解析会把这类用户挑的颜色静默换成主题色（2026-11-01 审计发现）。
     */
    fun parseInkArgb(value: String?): Int? {
        val trimmed = value?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        val hex = trimmed.removePrefix("#")
        val rgb = when (hex.length) {
            6 -> hex
            8 -> hex.substring(2)
            else -> return null
        }
        if (!rgb.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }) return null
        return 0xFF000000.toInt() or rgb.toInt(16)
    }

    /**
     * 次级墨色：浅墨压到 0.72、深墨压到 0.70
     * （Dart `homePageOverWallpaperMutedInk`，`:999-1010`；判据是墨色自身亮度 > 0.55）。
     *
     * alpha **四舍五入**（0.72 → 184、0.70 → 179），与 Flutter `withValues().toARGB32()`
     * 一致；截断会各差 1 个 LSB。
     */
    fun mutedInkOverWallpaperArgb(inkArgb: Int): Int {
        val alpha = if (relativeLuminance(inkArgb) > 0.55) 0.72f else 0.70f
        return (inkArgb and 0x00FFFFFF) or ((alpha * 255f).roundToInt() shl 24)
    }

    /**
     * 朝 [targetArgb] 逐 5% 推 [fromArgb]：返回「第一次够对比度的颜色」与「走了几步」。
     *
     * 步数给两侧比较用（Dart 取步数少的那侧，`:968-991`）；20 步（= 5%）是上限。
     */
    private fun pushTowardContrast(
        fromArgb: Int,
        targetArgb: Int,
        wallpaperLuminance: Double,
    ): Pair<Int, Int>? {
        val fromR = (fromArgb shr 16) and 0xFF
        val fromG = (fromArgb shr 8) and 0xFF
        val fromB = fromArgb and 0xFF
        val toR = (targetArgb shr 16) and 0xFF
        val toG = (targetArgb shr 8) and 0xFF
        val toB = targetArgb and 0xFF
        for (step in 1..20) {
            val t = step / 20.0
            val r = (fromR + (toR - fromR) * t).roundToInt().coerceIn(0, 255)
            val g = (fromG + (toG - fromG) * t).roundToInt().coerceIn(0, 255)
            val b = (fromB + (toB - fromB) * t).roundToInt().coerceIn(0, 255)
            val candidate = 0xFF000000.toInt() or (r shl 16) or (g shl 8) or b
            if (hasSufficientContrast(relativeLuminance(candidate), wallpaperLuminance)) {
                return candidate to step
            }
        }
        return null
    }

    // ───────────── 壁纸亮度采样（顶栏墨色的输入） ─────────────

    /**
     * sRGB 8bit 通道 → 线性值（WCAG 公式，Dart `_linearizeSrgbComponent`，`:1256-1267`）。
     *
     * 必须是这条曲线：直接拿 `(r+g+b)/3/255` 当亮度，中灰会偏高、暗部会严重高估，
     * 深色壁纸就被判成「亮」而上了深墨字——这正是 Dart 侧 2026-09-21 修掉的那个坑。
     */
    fun srgbChannelToLinear(channel: Int): Double = SRGB_LINEAR_LUT[channel.coerceIn(0, 255)]

    /**
     * 8bit sRGB → 线性值查表（Dart 同款 `_srgbLinearizeLut`，`:1263-1277`）。
     *
     * 逐像素调 `pow()` 在整张壁纸上要几百万次；一张 256 项的表把这一步从「几十毫秒」
     * 压到「几毫秒」（2026-11-01 审计：三带扫描在首帧同步路径里跑，必须有这张表）。
     */
    private val SRGB_LINEAR_LUT: DoubleArray = DoubleArray(256) { value ->
        val c = value / 255.0
        if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }

    /**
     * 单像素 WCAG 相对亮度（与 Dart `Color.computeLuminance()` 同口径，`:1340-1343`）。
     *
     * **忽略 alpha**：壁纸整张是不透明的，透明通道在这里没有语义。
     */
    fun relativeLuminance(argb: Int): Double {
        val r = srgbChannelToLinear((argb shr 16) and 0xFF)
        val g = srgbChannelToLinear((argb shr 8) and 0xFF)
        val b = srgbChannelToLinear(argb and 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /**
     * 一组 ARGB 像素的**平均色**（按 alpha 加权，全透明像素不计入）。
     *
     * 冷启动首帧的壁纸主色就用它算：壁纸还没解出来（文件损坏 / 存储卡住）时，先用这坨
     * 颜色铺满背景，用户看到的是「近似壁纸的底色」而不是页面近白色。
     *
     * 为什么按 alpha 加权：壁纸文件理论上不透明，但 PNG / 带透明边的截图会有 alpha=0 的
     * 边，直接平均会把它们当成黑色拉低结果。返回的色值自身是**不透明**的（背景不能透底）。
     *
     * @param argbPixels 行优先的 ARGB 像素（`Bitmap.getPixels` 直接产出）；
     *   空数组 / 全透明返回 `null`，调用方据此回落到页面底色。
     */
    fun averageColorArgb(argbPixels: IntArray): Int? {
        if (argbPixels.isEmpty()) return null
        var sumR = 0L
        var sumG = 0L
        var sumB = 0L
        var sumA = 0L
        var count = 0L
        for (argb in argbPixels) {
            val alpha = (argb ushr 24) and 0xFF
            if (alpha == 0) continue
            sumR += ((argb shr 16) and 0xFF).toLong() * alpha
            sumG += ((argb shr 8) and 0xFF).toLong() * alpha
            sumB += (argb and 0xFF).toLong() * alpha
            sumA += alpha.toLong()
            count++
        }
        if (count == 0L || sumA == 0L) return null
        val r = (sumR / sumA).toInt().coerceIn(0, 255)
        val g = (sumG / sumA).toInt().coerceIn(0, 255)
        val b = (sumB / sumA).toInt().coerceIn(0, 255)
        return (0xFF shl 24) or (r shl 16) or (g shl 8) or b
    }

    /**
     * 壁纸叠层的绘制 alpha：**只有在下面已经垫着一张不透明的图时**才允许淡入。
     *
     * 这条规则是 2026-11-09 真机问题（「白屏之后冒出一个奇怪的影子」）的根因修正：
     * 高清图从「全透明」淡入到空白背景上时，会有 100~200ms 停在半透明状态——
     * 一层半透明的壁纸压在白底上，看起来就是一块残影。没有垫底（缓存命中 / 缩略图
     * 解不出来）时直接不透明贴上，不做淡入。
     *
     * @param highResAlpha 淡入动画当前值（0…1）
     * @param hasOpaqueUnderlay 下面是否已有一张不透明底图（缩略图）
     */
    fun wallpaperOverlayAlpha(highResAlpha: Float, hasOpaqueUnderlay: Boolean): Float =
        if (hasOpaqueUnderlay) highResAlpha.coerceIn(0f, 1f) else 1f

    /**
     * 竖直比例区间 → 行下标区间 `[fromRow, toRow)`（Dart `:1330-1333` 的 floor/ceil 取整）。
     *
     * 取整公式必须一致：Dart 的 `top` 带（0…0.09）与逐行剖面靠这套 floor/ceil 对齐，
     * 改一处就会让「同一条带」在两边差一行。区间总是至少一行（高 > 0 时），
     * 高度非正返回空区间（调用方据此回 null，而不是猜 0 亮度）。
     */
    fun bandRows(height: Int, fromFraction: Double, toFraction: Double): IntRange {
        if (height <= 0) return IntRange.EMPTY
        val a = if (fromFraction.isNaN()) 0.0 else fromFraction.coerceIn(0.0, 1.0)
        val b = if (toFraction.isNaN()) 0.0 else toFraction.coerceIn(0.0, 1.0)
        val low = minOf(a, b)
        val high = maxOf(a, b)
        val fromRow = floor(height * low).toInt().coerceIn(0, height - 1)
        val toRow = ceil(height * high).toInt().coerceIn(fromRow + 1, height)
        return fromRow until toRow
    }

    /**
     * 若干行内的**平均相对亮度**（Dart `:1334-1347` 的 band 累加口径）。
     *
     * @param argbPixels 行优先的 ARGB 像素（`Bitmap.getPixels` 直接产出）；
     * @param width 像素行宽；
     * @param fromRow / @param toRow 左闭右开的行区间。
     * 参数不自洽（宽非正、区间越界、像素不够铺满这些行）时返回 `null`——
     * 「未知亮度」必须能被调用方区分出来，不能混成 0。
     */
    fun meanRelativeLuminance(
        argbPixels: IntArray,
        width: Int,
        fromRow: Int,
        toRow: Int,
        fromColumn: Int = 0,
        toColumn: Int = width,
        rowStep: Int = 1,
        columnStep: Int = 1,
    ): Double? {
        if (width <= 0 || fromRow < 0 || toRow <= fromRow) return null
        val colFrom = fromColumn.coerceIn(0, width - 1)
        val colTo = toColumn.coerceIn(colFrom + 1, width)
        if (argbPixels.size < toRow.toLong() * width) return null
        val rowStride = rowStep.coerceAtLeast(1)
        val columnStride = columnStep.coerceAtLeast(1)
        var total = 0.0
        var count = 0
        var row = fromRow
        while (row < toRow) {
            val rowOffset = row * width
            var column = colFrom
            while (column < colTo) {
                total += relativeLuminance(argbPixels[rowOffset + column])
                count++
                column += columnStride
            }
            row += rowStride
        }
        return if (count == 0) null else total / count
    }

    /**
     * 便捷版：按 [bandRows] 先算行区间，再求平均。高度 / 区间非法 → `null`。
     */
    fun meanRelativeLuminanceForVerticalRange(
        argbPixels: IntArray,
        width: Int,
        height: Int,
        fromFraction: Double,
        toFraction: Double,
        fromColumn: Int = 0,
        toColumn: Int = width,
        rowStep: Int = 1,
        columnStep: Int = 1,
    ): Double? {
        val rows = bandRows(height, fromFraction, toFraction)
        if (rows.isEmpty()) return null
        return meanRelativeLuminance(
            argbPixels = argbPixels,
            width = width,
            fromRow = rows.first,
            toRow = rows.last + 1,
            fromColumn = fromColumn,
            toColumn = toColumn,
            rowStep = rowStep,
            columnStep = columnStep,
        )
    }

    // ───────────── 来源（路径 / 底色） ─────────────

    /**
     * 全屏壁纸路径：先壁纸字段，再老版本的背景图字段（Dart
     * `resolveHomePageBackdropImagePath`，`:346-356`）。
     *
     * 兜底**只在壁纸字段为空时生效**：壁纸字段非空但文件丢了，`Dart 不会退回去用老背景图`
     * （存在性判定在 [backdropKey] 那一步，结果直接是「无背景」）。
     * 本函数**不做存在性检查**（那是 [backdropKey]）。
     */
    fun resolveBackdropImagePath(wallpaperPath: String?, legacyBackgroundPath: String?): String? {
        if (!wallpaperPath.isNullOrEmpty()) return wallpaperPath
        if (!legacyBackgroundPath.isNullOrEmpty()) return legacyBackgroundPath
        return null
    }

    /**
     * 背景身份键：路径可用且**文件真的在**才返回（Dart `homePageBackdropKey`，`:382-392`）。
     *
     * 文件丢失（重装 / 清数据 / 跨设备同步只带回 JSON）时返回 `null` = 视为无背景，
     * 首页回退纯色底，而不是停在一条失效路径上什么都不画。
     */
    fun backdropKey(
        wallpaperPath: String?,
        legacyBackgroundPath: String?,
        exists: (String) -> Boolean = ::defaultPathExists,
    ): String? {
        val path = resolveBackdropImagePath(wallpaperPath, legacyBackgroundPath) ?: return null
        return if (exists(path)) path else null
    }

    /**
     * 无壁纸时的页底色（Dart `resolveHomePageBackgroundColor`，`:273-285`）：
     * 深色模式**永远**用主题兜底色（自定义色不生效），浅色模式才读自定义 hex，
     * 非法 / 缺省同样回落主题色。
     */
    fun resolvePageColorArgb(
        configuredHex: String?,
        isDark: Boolean,
        themeFallbackArgb: Int,
    ): Int {
        if (isDark) return themeFallbackArgb
        return parseHexArgb(configuredHex) ?: themeFallbackArgb
    }

    /**
     * `#RRGGBB` / `RRGGBB` → 不透明 ARGB（Dart `tryParseHexColor`，`lib/utils/hex_color.dart:3-17`）。
     *
     * 只认**恰好 6 位**十六进制：3 位缩写、8 位带 alpha、任何非 hex 字符一律 `null`
     * （Dart 就是这么收口的，别在这里放宽）。
     */
    fun parseHexArgb(value: String?): Int? {
        val trimmed = value?.trim() ?: return null
        if (trimmed.isEmpty()) return null
        val hex = if (trimmed.startsWith("#")) trimmed.substring(1) else trimmed
        if (hex.length != 6) return null
        if (!hex.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }) return null
        return 0xFF000000.toInt() or hex.toInt(16)
    }

    /**
     * 从设置快照出一份渲染层直接能用的 [HomeBackdropSnapshot]。
     *
     * 这是**唯一**的接线入口：调用方只需要 `settings` / 深色开关 / 视口物理宽 / 主题兜底 ARGB，
     * 其余收口都在这里做。`pageColorHex` 由宿主传 `settings.timetablePageBackgroundColor`
     * （深色模式仍走主题兜底，见 [resolvePageColorArgb]）。
     *
     * @param viewportWidthPx 视口物理宽（`screenWidthDp × density`）；`null` = 拿不到，按 Dart 兜底 1440。
     * @param themeFallbackArgb 无壁纸底色，调用方传主题语义槽（如 `QingyuTheme.scaffoldBackground(isDark)`）。
     * @param exists 文件存在判据，默认真实探盘；单测可注入假判据。
     */
    fun snapshotOf(
        settings: TimetableSettingsModel,
        isDark: Boolean,
        viewportWidthPx: Int?,
        themeFallbackArgb: Int,
        pageColorHex: String? = null,
        legacyBackgroundPath: String? = null,
        scope: Int = HomeBackdropScope.DEFAULT,
        exists: (String) -> Boolean = ::defaultPathExists,
    ): HomeBackdropSnapshot = HomeBackdropSnapshot(
        wallpaperPath = backdropKey(settings.homePageWallpaperPath, legacyBackgroundPath, exists),
        alignX = clampAlign(settings.homePageWallpaperAlignX),
        alignY = clampAlign(settings.homePageWallpaperAlignY),
        scale = clampScale(settings.homePageWallpaperScale),
        blurSigma = clampBlurSigma(settings.homePageWallpaperBlurSigma),
        decodeWidthPx = decodeWidthPx(viewportWidthPx),
        scope = scope,
        pageColorArgb = resolvePageColorArgb(pageColorHex, isDark, themeFallbackArgb),
        followsWeekPager = settings.homePageBackdropFollowsWeekPager,
    )
}

/** 默认文件存在判据（与 Dart `_homePageFileExistsSync` 同口径：只看文件在不在）。 */
private fun defaultPathExists(path: String): Boolean = java.io.File(path).exists()
