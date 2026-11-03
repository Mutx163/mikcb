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
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.IntSize
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
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
 * //    onInkBands 可省（= 不算亮度）；要给顶栏/字色翻墨就传：
 * var bands by remember { mutableStateOf<HomeBackgroundModel.InkBands?>(null) }
 * val inkPolarity = HomeBackgroundModel.chromeInkPolarity(bands?.top)
 * HomeWallpaperBackdrop(
 *     snapshot = snapshot,
 *     modifier = Modifier.fillMaxSize(),
 *     onInkBands = { bands = it },
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
 *    位图（滚动时只贴图）；这里用 **miuix-blur** 的实时高斯管线（`layerBackdrop` 采样 +
 *    `drawBackdrop` 模糊）。观感接近，但首帧要等解码，且整屏每帧都要重录一遍采样层再糊一次。
 *    性能未在真机上量过（Dart 就是为了这个才改成烤图的）。
 * 2. **sigma → 半径换了单位**：Dart 的 sigma 是高斯标准差（逻辑像素），miuix-blur 吃的是
 *    半径（像素，内部 `sigma = radius × 0.45`）。换算写在
 *    [HomeBackgroundModel.blurRadiusPxForSigma]；**没有真机逐档对照过**，若用户觉得模糊强弱
 *    与设置页读数对不上，先动这一个函数。
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
 * @param onInkBands 壁纸三档亮度带（顶栏 / 星期栏 / 正文，0…1）回调，供顶栏、星期栏、
 *   时间列、日视图空态决定浅墨还是深墨（判据在本组件的调用方 / 模型层，本组件只回原始亮度）。
 *   无壁纸 / 解码失败时回 `null`（= 亮度未知，调用方按主题墨色处理）。
 *   **传 `null`（默认）= 完全不算**：不额外解一次图、不额外扫一遍像素，行为与没有这个参数时一致。
 * @param content 叠在壁纸上的内容（周/日/月视图、顶栏等）。
 */
@Composable
fun HomeWallpaperBackdrop(
    snapshot: HomeBackdropSnapshot,
    modifier: Modifier = Modifier,
    weekPageOffset: Float = 0f,
    onInkBands: ((HomeBackgroundModel.InkBands?) -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit = {},
) {
    val path = snapshot.wallpaperPath
    // gaplessPlayback 等价物：produceState 的 state 不随 key 重建，换壁纸时旧图先留着，
    // 新图解好再换上去（Dart `home_page_background.dart:544` 的同一件事）。
    //
    // ⚠️ 初值先**同步**查一次位图缓存（2026-11-01 修「进外观编辑页闪一下白」）：
    // 同一张壁纸在首页早就解过、就躺在 [wallpaperBitmapCache] 里，但 `produceState` 的初值
    // 是 null ⇒ 这一帧画的是 [HomeBackdropSnapshot.pageColorArgb]（浅色主题下就是近白），
    // 解码结果要等一次 IO 往返才上来。外观编辑页的入场是「整屏缩成卡片」，
    // 这一帧正好落在缩放过程中，读起来就是「页面一下子闪白」。
    // 缓存命中时同步取到同一张图，首帧直接是壁纸，闪白消失；未命中时行为与原来一致。
    val cachedWallpaper = remember(path, snapshot.decodeWidthPx) {
        wallpaperFromCache(path, snapshot.decodeWidthPx)
    }
    val wallpaper: ImageBitmap? by produceState<ImageBitmap?>(
        initialValue = cachedWallpaper,
        key1 = path,
        key2 = snapshot.decodeWidthPx,
    ) {
        value = if (path.isNullOrEmpty()) {
            null
        } else {
            withContext(Dispatchers.IO) { decodeWallpaper(path, snapshot.decodeWidthPx) }
        }
    }

    // 墨色带只在「解码结果变了」时算一次（路径 / 解码宽 / 取景变了才会变），
    // **不进每帧绘制路径**；回调为 null 时整段直接返回，一个像素都不扫。
    // 用 rememberUpdatedState 接回调，避免调用方每帧换 lambda 导致重复量测。
    val inkCallback = rememberUpdatedState(onInkBands)
    val wantsInkBands = onInkBands != null
    // 取景（倍数 / 对齐）决定「屏幕上看得到原图哪一块」，量亮度必须按它折算（见
    // [HomeBackgroundModel.visibleSourceRect]）；视口尺寸与 `snapshotOf` 同源。
    val viewportWidthPx = with(LocalDensity.current) {
        LocalConfiguration.current.screenWidthDp.dp.roundToPx()
    }
    val viewportHeightPx = with(LocalDensity.current) {
        LocalConfiguration.current.screenHeightDp.dp.roundToPx()
    }
    LaunchedEffect(wallpaper, wantsInkBands, viewportWidthPx, viewportHeightPx) {
        val callback = inkCallback.value ?: return@LaunchedEffect
        // ① 缓存命中就别再扫一遍（切换视图时位图与墨色带通常都在缓存里）。
        val cached = cachedWallpaperInkBands(
            path = path,
            decodeWidthPx = snapshot.decodeWidthPx,
            viewportWidthPx = viewportWidthPx,
            viewportHeightPx = viewportHeightPx,
            scale = snapshot.scale,
            alignX = snapshot.alignX,
            alignY = snapshot.alignY,
        )
        if (cached != null) {
            callback(cached)
            return@LaunchedEffect
        }
        val image = wallpaper
        // ② 位图被 48MB 缓存淘汰、但墨色带还在时，**不能**拿 null 去覆盖已量好的值
        //（否则又会先翻一次面再等解码，正是本次要修的那一闪）。
        val bands = if (image == null) {
            cachedWallpaperInkBands(
                path = path,
                decodeWidthPx = snapshot.decodeWidthPx,
                viewportWidthPx = viewportWidthPx,
                viewportHeightPx = viewportHeightPx,
                scale = snapshot.scale,
                alignX = snapshot.alignX,
                alignY = snapshot.alignY,
            )
        } else {
            withContext(Dispatchers.IO) {
                measureInkBands(
                    image = image,
                    scale = snapshot.scale,
                    alignX = snapshot.alignX,
                    alignY = snapshot.alignY,
                    viewportWidthPx = viewportWidthPx,
                    viewportHeightPx = viewportHeightPx,
                )
            }
        }
        if (bands != null && !path.isNullOrEmpty()) {
            wallpaperInkBandsCache.put(
                wallpaperInkBandsCacheKey(
                    path = path,
                    decodeWidthPx = snapshot.decodeWidthPx,
                    viewportWidthPx = viewportWidthPx,
                    viewportHeightPx = viewportHeightPx,
                    scale = snapshot.scale,
                    alignX = snapshot.alignX,
                    alignY = snapshot.alignY,
                ),
                bands,
            )
        }
        callback(bands)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(color = Color(color = snapshot.pageColorArgb)),
    ) {
        val image = wallpaper
        if (image != null) {
            // 跟周翻页滑动时，左右各补一份同一张图：只平移不补画，滑到一半会露底色
            // （Dart `:657-707` 把整屏壁纸当一条长条平移，每页画同一张）。
            // 偏移表在组合期算好，别放进每帧的 draw 里再分配一次 List。
            val pageOffsets = snapshot.stripPageOffsets(weekPageOffset)
            // 模糊量是「屏幕上的像素」（Dart `home_page_background.dart:547-566`）：半径按 sigma
            // 直接算成 px，**不**乘取景倍数——用户把缩放拖到 4 倍也不会跟着变糊。
            val blurRadiusPx =
                HomeBackgroundModel.blurRadiusPxForSigma(snapshot.blurSigma, LocalDensity.current.density)
            if (blurRadiusPx > 0.0) {
                // 模糊走 **miuix-blur**（MIUIX-FIRST 铁律：模糊用官方能力，不自己造效果）。
                // 官方管线是两件套：
                //   ① `Modifier.layerBackdrop` 把「要糊的东西」（壁纸条）录进一张采样层；
                //   ② `Modifier.drawBackdrop` 把采样层按 miuix 的高斯链糊出来、铺在自己的位置。
                // ① 那一格只负责录制、**不上屏**（空内容 + 那个 modifier），屏幕上看到的是 ②。
                // 底栏玻璃（`GlassDockNavigationBar`）用的是同一条管线。
                val sampleLayer = rememberGraphicsLayer()
                val sampleBackdrop = rememberLayerBackdrop(graphicsLayer = sampleLayer) {
                    drawWallpaperStrip(image, snapshot, pageOffsets)
                }
                Box(modifier = Modifier.fillMaxSize().layerBackdrop(sampleBackdrop))
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .drawBackdrop(
                            backdrop = sampleBackdrop,
                            shape = { RectangleShape },
                            effects = { blur(blurRadiusPx.toFloat()) },
                        ),
                )
            } else {
                // 0 档 = 不模糊：原图直出，别让 miuix 白跑一趟采样 + 高斯链。
                Canvas(modifier = Modifier.fillMaxSize()) {
                    drawWallpaperStrip(image, snapshot, pageOffsets)
                }
            }
        }
        content()
    }
}

/**
 * 把壁纸条画进当前 [DrawScope]。
 *
 * 屏幕直画（0 档）与采样层录制（模糊档）用的是**同一份画法**：写两遍必然漂
 * （改了一处忘了另一处，模糊档和清晰档的取景就不一样了）。
 *
 * `cover` 矩形与取景对齐由 [HomeBackgroundModel.drawRect] 算，这里只负责落笔；
 * [pageOffsets] 是跟周翻页时的水平平移量（只有 0 时 = 静止）。
 */
private fun DrawScope.drawWallpaperStrip(
    image: ImageBitmap,
    snapshot: HomeBackdropSnapshot,
    pageOffsets: List<Float>,
) {
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
    ) ?: return
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

/**
 * 位图缓存键：**同一张壁纸 + 同一个解码宽**才复用（见 [WALLPAPER_CACHE_BYTES]）。
 *
 * 组合期（[wallpaperFromCache]）与 IO 期（[decodeWallpaper]）都要用，抽成一处，
 * 免得两边各拼一遍字符串、改了一处另一处就对不上。
 */
private fun wallpaperCacheKey(path: String, decodeWidthPx: Int): String = "$path|$decodeWidthPx"

/**
 * **同步**查一次位图缓存，命中就返回。
 *
 * 只给 [HomeWallpaperBackdrop] 的 `produceState` 当**初值**用：同一张壁纸在首页已经解过时，
 * 首帧就能拿到图，不会先画一帧页底色（浅色主题下那一下就是「闪白」）。
 * 未命中返回 null，走原来的异步解码路径。这里不碰磁盘，不会卡主线程。
 */
private fun wallpaperFromCache(path: String?, decodeWidthPx: Int): ImageBitmap? {
    if (path.isNullOrEmpty()) return null
    return wallpaperBitmapCache.get(wallpaperCacheKey(path, decodeWidthPx))?.asImageBitmap()
}

/**
 * 壁纸三档亮度带的缓存。键 = 路径 + 解码宽 + 视口 + 取景（倍数 / 对齐）
 * （见 [wallpaperInkBandsCacheKey]）。
 *
 * 为什么要有（2026-11-01 真机：切日/周视图时**所有字黑白闪一下**）：
 * 顶栏墨色（以及压在壁纸上的星期栏 / 时间列字色）都由这些亮度推出。以前新组合里初值
 * 恒为 null ⇒ 首帧按主题墨色画、等异步量完再翻面。切视图/进外观编辑页都是新建整棵树，
 * 于是每次都能看到那一翻。有了这份缓存，新组合首帧就同步拿到同一张壁纸的三档亮度。
 */
private val wallpaperInkBandsCache = LruCache<String, HomeBackgroundModel.InkBands>(64)

/**
 * 墨色带的缓存键：**路径 + 解码宽 + 视口 + 取景**。
 *
 * 取景（倍数 / 对齐）必须进键：同一张图放大 2 倍居中后，屏幕顶部看到的是原图中部，
 * 三档亮度会完全不同（Dart 的缓存键同样含 viewport / align / scale，`:600-611`）。
 */
private fun wallpaperInkBandsCacheKey(
    path: String,
    decodeWidthPx: Int,
    viewportWidthPx: Int,
    viewportHeightPx: Int,
    scale: Double,
    alignX: Double,
    alignY: Double,
): String = "$path|$decodeWidthPx|$viewportWidthPx|$viewportHeightPx|$scale|$alignX|$alignY"

/**
 * **同步**取三档亮度带：缓存命中直接返回；位图已在进程缓存里就顺手量一次并写回缓存；
 * 位图还没解出来返回 null（调用方按主题墨色兜底）。
 *
 * 同步路径只在「位图已缓存、墨色带还没量过」这种少数情况下走到（换壁纸后、异步量完前）；
 * 量的是**可见区域**、抽样步长随尺寸放大，实测为几毫秒级（见 [measureInkBands]）。
 */
fun cachedWallpaperInkBands(
    path: String?,
    decodeWidthPx: Int,
    viewportWidthPx: Int,
    viewportHeightPx: Int,
    scale: Double,
    alignX: Double,
    alignY: Double,
): HomeBackgroundModel.InkBands? {
    if (path.isNullOrEmpty() || decodeWidthPx <= 0) return null
    val key = wallpaperInkBandsCacheKey(
        path = path,
        decodeWidthPx = decodeWidthPx,
        viewportWidthPx = viewportWidthPx,
        viewportHeightPx = viewportHeightPx,
        scale = scale,
        alignX = alignX,
        alignY = alignY,
    )
    wallpaperInkBandsCache.get(key)?.let { return it }
    val bitmap = wallpaperBitmapCache.get(wallpaperCacheKey(path, decodeWidthPx)) ?: return null
    val bands = measureInkBands(
        image = bitmap.asImageBitmap(),
        scale = scale,
        alignX = alignX,
        alignY = alignY,
        viewportWidthPx = viewportWidthPx,
        viewportHeightPx = viewportHeightPx,
    ) ?: return null
    wallpaperInkBandsCache.put(key, bands)
    return bands
}

/**
 * 壁纸解码（后台线程调用）：先读尺寸算 2 的幂采样值，再按 EXIF 摆正。
 *
 * 命中缓存直接返回，不重复解码——首页每次重组都会走到这里，重解一张 1440 宽的 JPEG
 * 在主线程上是几百毫秒的卡顿。
 */
private fun decodeWallpaper(path: String, decodeWidthPx: Int): ImageBitmap? = runCatching {
    if (path.isEmpty()) return@runCatching null
    val cacheKey = wallpaperCacheKey(path, decodeWidthPx)
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
 * 量壁纸的**三档亮度带**（顶栏 / 星期栏 / 正文），给 `onInkBands` 用。
 *
 * * **按可见区域取比例**：先按 cover + 取景倍数 / 对齐算出「屏幕上看得到原图哪一块」
 *   （[HomeBackgroundModel.visibleSourceRect]，Dart `homePageWallpaperVisibleSourceRect`），
 *   三档比例作用在这块矩形上，而不是整张原图的行号 —— 否则用户放大 / 移动取景后，
 *   量到的是画外像素（2026-11-01 审计发现）。
 * * **列也只取可见列**（Dart 同口径）。
 * * **抽样步长**随区域放大（目标每档约 400×400 个样本）：平均亮度不需要逐像素，
 *   而同步路径跑在组合线程上，必须把最坏情况压住。
 * * 只读一次 `getPixels`，三档在同一份像素上求平均（分三次读会读三遍位图）。
 */
private fun measureInkBands(
    image: ImageBitmap,
    scale: Double,
    alignX: Double,
    alignY: Double,
    viewportWidthPx: Int,
    viewportHeightPx: Int,
): HomeBackgroundModel.InkBands? = runCatching {
    val bitmap = image.asAndroidBitmap()
    val width = bitmap.width
    val height = bitmap.height
    if (width <= 0 || height <= 0) return@runCatching null
    val source = HomeBackgroundModel.visibleSourceRect(
        imageWidth = width,
        imageHeight = height,
        viewportWidth = viewportWidthPx,
        viewportHeight = viewportHeightPx,
        scale = scale,
        alignX = alignX,
        alignY = alignY,
    )
    val left = source?.leftFraction ?: 0.0
    val top = source?.topFraction ?: 0.0
    val sourceWidth = source?.widthFraction ?: 1.0
    val sourceHeight = source?.heightFraction ?: 1.0

    val fromColumn = (width * left).toInt().coerceIn(0, width - 1)
    val toColumn = (width * (left + sourceWidth)).toInt().coerceIn(fromColumn + 1, width)
    val firstRow = ((top + sourceHeight * HomeBackgroundModel.CHROME_TOP_BAND_FROM) * height)
        .toInt().coerceIn(0, height - 1)
    // 扫到最低那条带的底：正文带止于 0.72，玻璃坞带要一直读到 0.96
    //（坞的墨色判据用它，见 `HomeBackgroundModel.DOCK_BAND_FROM`）。
    val lastRow = ((top + sourceHeight * maxOf(
        HomeBackgroundModel.BODY_BAND_TO,
        HomeBackgroundModel.DOCK_BAND_TO,
    )) * height)
        .toInt().coerceIn(firstRow + 1, height)
    val pixels = IntArray(width * lastRow)
    bitmap.getPixels(pixels, 0, width, 0, 0, width, lastRow)

    fun rowRange(fromFraction: Double, toFraction: Double): IntRange {
        val from = ((top + sourceHeight * fromFraction) * height).toInt()
            .coerceIn(0, height - 1)
        val to = ((top + sourceHeight * toFraction) * height).toInt()
            .coerceIn(from + 1, height)
        return from until to
    }

    val rowStep = maxOf(1, (lastRow - firstRow) / 400)
    val columnStep = maxOf(1, (toColumn - fromColumn) / 400)
    fun band(fromFraction: Double, toFraction: Double): Double? {
        val rows = rowRange(fromFraction, toFraction)
        if (rows.isEmpty()) return null
        return HomeBackgroundModel.meanRelativeLuminance(
            argbPixels = pixels,
            width = width,
            fromRow = rows.first,
            toRow = rows.last + 1,
            fromColumn = fromColumn,
            toColumn = toColumn,
            rowStep = rowStep,
            columnStep = columnStep,
        )
    }
    HomeBackgroundModel.InkBands(
        top = band(
            HomeBackgroundModel.CHROME_TOP_BAND_FROM,
            HomeBackgroundModel.CHROME_TOP_BAND_TO,
        ),
        weekday = band(
            HomeBackgroundModel.WEEKDAY_BAND_FROM,
            HomeBackgroundModel.WEEKDAY_BAND_TO,
        ),
        body = band(
            HomeBackgroundModel.BODY_BAND_FROM,
            HomeBackgroundModel.BODY_BAND_TO,
        ),
        dock = band(
            HomeBackgroundModel.DOCK_BAND_FROM,
            HomeBackgroundModel.DOCK_BAND_TO,
        ),
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
