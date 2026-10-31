package com.mutx163.qingyu.pages.shell

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.util.LruCache
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

/**
 * 首页壁纸背景层（全屏底图 + 模糊 + 取景，内容画在它上面）。
 *
 * ## 这是补哪一块缺口
 *
 * Flutter 首页早就有壁纸背景（`lib/utils/home_page_background.dart` 一整条链），
 * Compose 壳这边**一行都没有**，所以首页看上去永远是纯色底。本文件是那层的渲染实现，
 * 几何 / 解码 / 墨色的所有数值都在 [HomeBackgroundModel] 里（JVM 单测钉住），这里只负责
 * 「读图 → 按算好的矩形画 → 套模糊 → 把内容叠上去」。
 *
 * ## 调用方怎么接（Lead 统一接线，本文件不碰 `PagesShellActivity`）
 *
 * ```kotlin
 * // 1. 在壳里拿一次「视口物理宽」：设置里存的是物理像素口径（Dart 按宽解码）。
 * val density = LocalDensity.current.density
 * val viewportWidthPx = (LocalConfiguration.current.screenWidthDp * density).roundToInt()
 *
 * // 2. 建快照（唯一入口）：themeFallbackArgb 必须来自主题语义槽，不要写颜色字面量。
 * val snapshot = remember(settings, isDark, viewportWidthPx) {
 *     HomeBackgroundModel.snapshotOf(
 *         settings = settings,
 *         isDark = isDark,
 *         viewportWidthPx = viewportWidthPx,
 *         themeFallbackArgb = QingyuTheme.scaffoldBackground(isDark),
 *     )
 * }
 *
 * // 3. 挂在首页最外层：底图在下面，周/日/月视图与顶栏当内容叠上来。
 * //    onInkLuminance 可省（= 不算亮度）；要给顶栏翻墨色就传：
 * var wallLuminance by remember { mutableStateOf<Double?>(null) }   // 0..1，null = 未知
 * val inkPolarity = HomeBackgroundModel.chromeInkPolarity(wallLuminance)
 * HomeWallpaperBackdrop(
 *     snapshot = snapshot,
 *     modifier = Modifier.fillMaxSize(),
 *     onInkLuminance = { wallLuminance = it },
 * ) {
 *     // 首页内容（用 snapshot.regionPaint(...) 决定各区域透不透，顶栏墨色用 inkPolarity）
 * }
 * ```
 *
 * `homePageBackdropFollowsWeekPager`（背景跟周翻页滑动）需要把当前周分页的浮点偏移传进
 * [weekPageOffset]（Dart 是 `controller.page`，Compose 侧就是 `PagerState.currentPage +
 * currentPageOffsetFraction` 的小数部分）。不传 = 背景静止。
 *
 * ## 与 Dart 的差异（诚实清单）
 *
 * 1. **模糊是实时算的，不是烤图**：Dart 用 `PreblurredWallpaperBackdrop` 预先把模糊烤成
 *    位图（滚动时只贴图）；这里用 `Modifier.blur`（`RenderEffect`，minSdk 33 可用）。
 *    观感接近，但首帧要等解码、且大图每帧都要过一遍 GPU 模糊。性能未在真机上量过。
 * 2. **sigma → 半径换了单位**：Dart 的 sigma 是高斯标准差（逻辑像素），Compose 吃的是
 *    `RenderEffect` 半径。换算写在 [HomeBackgroundModel.blurRadiusDpForSigma]，公式依据
 *    是 Android 的 `ConvertRadiusToSigma`；**没有真机逐档对照过**，若用户觉得模糊强弱与
 *    设置页读数对不上，先动这一个函数。
 * 3. **镜像档 EXIF 方向没处理**（2/4/5/7 按不旋转画）；旋转档 3/6/8 已补。
 * 4. **玻璃卡片看到的「屏幕上那张壁纸」还没接**：Dart 会把壁纸的模糊量折进卡片/玻璃带的
 *    预模糊，这里没有预模糊管线，所以玻璃下面的模糊是各自算的。属另一批。
 * 5. 没有做 Dart 的 `PreblurredWallpaperScope` 那套「同一张壁纸全局共用」的采样缓存。
 *
 * ## 样式守卫
 *
 * 本文件不写死字号、不写 `Color(0x…)`、不含任何中文字面量（`CjkLiteralGateTest` 只认
 * 引号里的中文，注释不受限）：底色来自 [HomeBackdropSnapshot.pageColorArgb]，字号一处没有。
 */

/**
 * 同一张壁纸最多缓存几版像素（48 MB ≈ 2 张 1440 宽的手机壁纸）。
 *
 * 「同一路径只解一次」靠这个缓存：Lru 的键是「路径 + 解码宽」，路径或视口变了才重解。
 * 背景切走再切回（进设置页再回来）也能直接命中，不会重解。
 */
private const val WALLPAPER_CACHE_BYTES = 48 * 1024 * 1024

/** 壁纸位图缓存（进程内、按字节淘汰；只放最终要画的那一版，不含旋转前的临时图）。 */
private val wallpaperBitmapCache: LruCache<String, Bitmap> =
    object : LruCache<String, Bitmap>(WALLPAPER_CACHE_BYTES) {
        override fun sizeOf(key: String, value: Bitmap): Int = value.byteCount
    }

/**
 * 首页壁纸背景容器。
 *
 * - 没有壁纸（`snapshot.hasWallpaper == false`）时只铺 [HomeBackdropSnapshot.pageColorArgb]；
 * - 有壁纸时先铺底色、再画底图（`cover` × 取景倍数 × 对齐），最后把 [content] 叠在上面；
 * - 解码在后台线程，主线程只做绘制；同一路径同宽只解一次（见 [wallpaperBitmapCache]）。
 *
 * @param snapshot 由 [HomeBackgroundModel.snapshotOf] 建出来的不可变快照。
 * @param weekPageOffset 当前周分页的浮点页偏移（-1…1，`currentPage` 的小数部分）；
 *   仅 `snapshot.followsWeekPager` 为真时生效，0 = 背景不跟手。
 * @param onInkLuminance 壁纸「顶部那条带」的平均相对亮度（0…1）回调，供顶栏/星期栏决定
 *   浅墨还是深墨（判据用 [HomeBackgroundModel.chromeInkPolarity]，本组件只回原始亮度）。
 *   无壁纸 / 解码失败时回 `null`（= 亮度未知，调用方按主题墨色处理）。
 *   **传 `null`（默认）= 完全不算**：不额外解一次图、不额外扫一遍像素，行为与没有这个参数时一致。
 * @param content 叠在壁纸上的内容（周/日/月视图、顶栏等）。
 */
@Composable
fun HomeWallpaperBackdrop(
    snapshot: HomeBackdropSnapshot,
    modifier: Modifier = Modifier,
    weekPageOffset: Float = 0f,
    onInkLuminance: ((Double?) -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit = {},
) {
    val path = snapshot.wallpaperPath
    // gaplessPlayback 等价物：produceState 的 state 不随 key 重建，换壁纸时旧图先留着，
    // 新图解好再换上去（Dart `home_page_background.dart:544` 的同一件事）。
    val wallpaper: ImageBitmap? by produceState<ImageBitmap?>(
        initialValue = null,
        key1 = path,
        key2 = snapshot.decodeWidthPx,
    ) {
        value = if (path.isNullOrEmpty()) {
            null
        } else {
            withContext(Dispatchers.IO) { decodeWallpaper(path, snapshot.decodeWidthPx) }
        }
    }

    // 亮度只在「解码结果变了」时算一次（路径 / 解码宽变了才会变），**不进每帧绘制路径**；
    // 回调为 null 时整段直接返回，一个像素都不扫。用 rememberUpdatedState 接回调，
    // 避免调用方每帧换 lambda 导致重复量测。
    val inkCallback = rememberUpdatedState(onInkLuminance)
    val wantsInkLuminance = onInkLuminance != null
    LaunchedEffect(wallpaper, wantsInkLuminance) {
        val callback = inkCallback.value ?: return@LaunchedEffect
        val image = wallpaper
        val luminance = if (image == null) {
            null
        } else {
            withContext(Dispatchers.IO) { measureChromeBandLuminance(image) }
        }
        callback(luminance)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(color = Color(color = snapshot.pageColorArgb)),
    ) {
        val image = wallpaper
        if (image != null) {
            // 模糊包在**绘制之外**（Dart 同口径：`home_page_background.dart:547-566` 的注释
            // 说模糊量是「屏幕上的像素」，包在里面的话放大到 4 倍时糊度会跟着放大）。
            val blurDp = HomeBackgroundModel.blurRadiusDpForSigma(snapshot.blurSigma)
            val blurModifier = if (blurDp > 0.0) {
                Modifier.blur(
                    radius = blurDp.toFloat().dp,
                    edgeTreatment = BlurredEdgeTreatment.Unbounded,
                )
            } else {
                Modifier
            }
            // 跟周翻页滑动时，左右各补一份同一张图：只平移不补画，滑到一半会露底色
            // （Dart `:657-707` 把整屏壁纸当一条长条平移，每页画同一张）。
            // 偏移表在组合期算好，别放进每帧的 draw 里再分配一次 List。
            val pageOffsets = snapshot.stripPageOffsets(weekPageOffset)
            Canvas(modifier = Modifier.fillMaxSize().then(blurModifier)) {
                val viewportWidth = size.width.roundToInt()
                val viewportHeight = size.height.roundToInt()
                val rect = HomeBackgroundModel.drawRect(
                    imageWidth = image.width,
                    imageHeight = image.height,
                    viewportWidth = viewportWidth,
                    viewportHeight = viewportHeight,
                    scale = snapshot.scale,
                    alignX = snapshot.alignX,
                    alignY = snapshot.alignY,
                ) ?: return@Canvas
                val dstSize = IntSize(
                    width = rect.width.roundToInt().coerceAtLeast(1),
                    height = rect.height.roundToInt().coerceAtLeast(1),
                )
                val baseLeft = rect.left.roundToInt()
                val baseTop = rect.top.roundToInt()
                for (pageOffset in pageOffsets) {
                    drawImage(
                        image = image,
                        dstOffset = IntOffset(
                            x = (baseLeft + pageOffset * viewportWidth).roundToInt(),
                            y = baseTop,
                        ),
                        dstSize = dstSize,
                        filterQuality = FilterQuality.Medium,
                    )
                }
            }
        }
        content()
    }
}

/**
 * 壁纸解码（后台线程调用）：先读尺寸算 2 的幂采样值，再按 EXIF 摆正。
 *
 * 命中缓存直接返回，不重复解码——首页每次重组都会走到这里，重解一张 1440 宽的 JPEG
 * 在主线程上是几百毫秒的卡顿。
 */
private fun decodeWallpaper(path: String, decodeWidthPx: Int): ImageBitmap? = runCatching {
    if (path.isEmpty()) return@runCatching null
    val cacheKey = "$path|$decodeWidthPx"
    wallpaperBitmapCache.get(cacheKey)?.let { return@runCatching it.asImageBitmap() }

    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    val plan = HomeBackgroundModel.decodePlan(bounds.outWidth, bounds.outHeight, decodeWidthPx)
        ?: return@runCatching null
    val options = BitmapFactory.Options().apply { inSampleSize = plan.inSampleSize }
    val decoded = BitmapFactory.decodeFile(path, options) ?: return@runCatching null

    val rotation = HomeBackgroundModel.exifRotationDegrees(readExifOrientation(path))
    val oriented = if (rotation == 0) decoded else decoded.rotated(rotation)
    wallpaperBitmapCache.put(cacheKey, oriented)
    oriented.asImageBitmap()
}.getOrNull()

/**
 * 量「顶栏 / 状态栏那条带」的平均相对亮度（0…1），给 `onInkLuminance` 用。
 *
 * 只读顶部 9% 的行（[HomeBackgroundModel.CHROME_TOP_BAND_TO]，Dart `:1355` 的
 * `band(0, 0.09)`）——不是整张图，也不是顶部 1/3：那一段才是顶栏标题真正压着的壁纸，
 * 取太宽会把屏幕中段混进来、把深色壁纸平均成中灰（于是深墨压深底）。
 *
 * 相对亮度在模型层按 WCAG 的 sRGB 线性化逐像素算，不是把 RGB 通道直接平均。
 * 像素在 IO 线程读，一次分配「宽 × 带高」的 int 数组（1440 宽约 1.3 MB），算完即丢。
 *
 * 与 Dart 的已知差异：Dart 采样还把列裁到 cover 的**可见列**，这里按整行平均
 * （取景对齐偏移会带来一点偏差；方向上安全——可见列只是整行的子集）。
 */
private fun measureChromeBandLuminance(image: ImageBitmap): Double? = runCatching {
    val bitmap = image.asAndroidBitmap()
    val width = bitmap.width
    val height = bitmap.height
    val rows = HomeBackgroundModel.bandRows(
        height = height,
        fromFraction = HomeBackgroundModel.CHROME_TOP_BAND_FROM,
        toFraction = HomeBackgroundModel.CHROME_TOP_BAND_TO,
    )
    if (width <= 0 || rows.isEmpty()) return@runCatching null
    val bandHeight = rows.last + 1
    val pixels = IntArray(width * bandHeight)
    bitmap.getPixels(pixels, 0, width, 0, 0, width, bandHeight)
    HomeBackgroundModel.meanRelativeLuminance(
        argbPixels = pixels,
        width = width,
        fromRow = rows.first,
        toRow = rows.last + 1,
    )
}.getOrNull()

/** 读 EXIF 方向；读不到 / 文件没有 EXIF 时按「正常」处理（不抛）。 */private fun readExifOrientation(path: String): Int = runCatching {
    ExifInterface(path).getAttributeInt(
        ExifInterface.TAG_ORIENTATION,
        ExifInterface.ORIENTATION_NORMAL,
    )
}.getOrDefault(ExifInterface.ORIENTATION_NORMAL)

/**
 * 把解码好的位图按 EXIF 角度摆正。
 *
 * 旋转会产出一张新位图，原图**立刻释放**（不释放就相当于解码后同时占两份内存，
 * 1440 宽的手机壁纸一份约 17 MB）。`result === this` 时不动它——`createBitmap` 对
 * 90 度的整数倍可能直接返回原对象。
 */
private fun Bitmap.rotated(degrees: Int): Bitmap {
    val matrix = Matrix().apply { postRotate(degrees.toFloat()) }
    val result = Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
    if (result !== this) recycle()
    return result
}
