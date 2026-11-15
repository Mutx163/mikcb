package com.mutx163.qingyu.platform

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import coil3.BitmapImage
import coil3.DrawableImage
import coil3.ImageLoader
import coil3.memory.MemoryCache
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import coil3.request.ImageRequest
import com.mutx163.qingyu.app.imagecache.ImageRetryBackoff

/**
 * 网络图片加载器（P35-B4 网络图片加载层）。
 *
 * ## 2026-11-14：内部换 Coil 3，对外面不变
 *
 * 原来这里是自己写的 LruCache + 线程池 + 在途去重 + `BitmapFactory` 两次解码（183 行，
 * **零测试**）。用户拍板后换成 Coil 3（Apache-2.0）：缓存、在途去重、按尺寸采样都是它的
 * 标准职责，我们只为它提供「唯一那个 OkHttp 客户端」。
 *
 * **对外契约一点没动**，`BingGalleryHost` / `MemoryStatsCollector` 一行不用改：
 * - [shared] 进程级单例；[load] 回调在主线程、失败给 null；
 * - [memoryCacheBytes] / [memoryCacheEntryCount] / [memoryCacheMaxBytes] 三个口径保留；
 * - [clear] / [shutdown] 保留。
 *
 * 两个刻意的决定（改之前先看）：
 * - **`diskCache(null)`**：我们已有壁纸受管目录与 `filesDir/logs` 两处磁盘数据，再叠一层
 *   Coil 磁盘缓存等于多一份用户数据、多一条清理路径。
 * - **内存上限仍按构造参数（默认 16 MB）**：Coil 默认按可用内存百分比算 `maxSize`，
 *   那会让诊断页「已用 / 上限」的分母跳一档、历史数值不可比。这里显式钉回固定上限。
 *
 * ## 为什么需要 [install]
 *
 * Coil 的 `ImageLoader` 必须拿到 `Context`，而本类原本是无参单例。组合根
 * （`ShellWiring.init`）在壳构造时调一次 `AndroidImageLoader.shared.install(context)`；
 * 没装就调 [load] 会立刻报错——宁可当场红，也不要静默显示空白图。
 */
class AndroidImageLoader(
    private val maxCacheBytes: Int = DEFAULT_MAX_CACHE_BYTES,
) {

    @Volatile
    private var imageLoader: ImageLoader? = null

    /** install 时记下的 applicationContext（`ImageRequest` 需要它）。 */
    @Volatile
    private var appContext: Context? = null

    private val mainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }

    /**
     * 组合根安装：用**唯一那个 OkHttp 客户端**（[QingyuHttp.client]）做网络层，不另建 client。
     *
     * 幂等：已安装则只更新 context，不重建加载器（避免把内存缓存清掉）。
     */
    fun install(context: Context) {
        appContext = context.applicationContext
        if (imageLoader != null) return
        imageLoader = ImageLoader.Builder(context.applicationContext)
            .components {
                // 3.6.3 的 Kotlin 入口是 OkHttpNetworkFetcherFactory(...)；JVM 字节码里它落在
                // OkHttpNetworkFetcher.factory(...)（从 coil-network-okhttp-3.6.3 的 aar 里查的）。
                add(OkHttpNetworkFetcherFactory(callFactory = { QingyuHttp.client }))
            }
            .diskCache(null)
            .memoryCache(
                MemoryCache.Builder()
                    .maxSizeBytes(maxCacheBytes.toLong())
                    .build(),
            )
            .build()
    }

    /**
     * 加载图片。命中内存缓存立即回调；否则交给 Coil。回调在主线程触发，
     * 参数为解码后的 Bitmap，失败时为 null。
     */
    fun load(
        url: String,
        targetWidthPx: Int,
        targetHeightPx: Int,
        callback: (Bitmap?) -> Unit,
    ) {
        val loader = imageLoader ?: error(NOT_INSTALLED)
        val context = appContext ?: error(NOT_INSTALLED)
        enqueueWithRetry(loader, context, url, targetWidthPx, targetHeightPx, attempt = 1, callback)
    }

    /** 清空内存缓存（内存吃紧 / 页面销毁时调用）。 */
    fun clear() {
        imageLoader?.memoryCache?.clear()
    }

    /** 内存缓存**当前占用**（字节）。 */
    fun memoryCacheBytes(): Int = MemoryCacheStats.bytes(imageLoader?.memoryCache)

    /** 内存缓存条目数。 */
    fun memoryCacheEntryCount(): Int = MemoryCacheStats.entries(imageLoader?.memoryCache)

    /** 内存缓存上限（字节），即构造时给的 [maxCacheBytes]。 */
    fun memoryCacheMaxBytes(): Int =
        MemoryCacheStats.maxBytes(imageLoader?.memoryCache, maxCacheBytes)

    /** 关闭加载器（宿主退出时调用）：清内存缓存；Coil 没有需要手动关的后台线程池。 */
    fun shutdown() {
        clear()
    }

    // ---------- 内部 ----------

    private fun enqueueWithRetry(
        loader: ImageLoader,
        context: Context,
        url: String,
        targetWidthPx: Int,
        targetHeightPx: Int,
        attempt: Int,
        callback: (Bitmap?) -> Unit,
    ) {
        val request = ImageRequest.Builder(context)
            .data(url)
            .size(targetWidthPx, targetHeightPx)
            .target(
                // 3.6.3 的 target 成功回调收的是 coil3.Image（不是 SuccessResult）。
                onSuccess = { image ->
                    val bitmap = image.toBitmapOrNull()
                    mainHandler.post { callback(bitmap) }
                },
                onError = {
                    if (ImageRetryBackoff.shouldRetry(attempt)) {
                        mainHandler.postDelayed(
                            {
                                enqueueWithRetry(
                                    loader = loader,
                                    context = context,
                                    url = url,
                                    targetWidthPx = targetWidthPx,
                                    targetHeightPx = targetHeightPx,
                                    attempt = attempt + 1,
                                    callback = callback,
                                )
                            },
                            ImageRetryBackoff.delayMillis(attempt),
                        )
                    } else {
                        mainHandler.post { callback(null) }
                    }
                },
            )
            .build()
        loader.enqueue(request)
    }

    companion object {
        private const val DEFAULT_MAX_CACHE_BYTES = 16 * 1024 * 1024 // 16 MB

        // 提示语用英文：CJK 字面量棘轮只降不升，屏上文案一律走 ArbText。
        private const val NOT_INSTALLED =
            "AndroidImageLoader is not installed: composition root should call shared.install(context)"

        /** 进程级共享实例（调用点直接用，不必各自 new）。 */
        val shared: AndroidImageLoader by lazy { AndroidImageLoader() }
    }
}

/** Coil 的 `Image` 两种形态都收成 Bitmap；拿不到就返回 null（回调按失败处理）。 */
private fun coil3.Image.toBitmapOrNull(): Bitmap? = when (this) {
    is BitmapImage -> bitmap
    is DrawableImage -> drawable.toBitmapOrNull()
    else -> null
}

/** Drawable → Bitmap：不引额外依赖（androidx.core 的 `toBitmap` 不在 classpath 保证内）。 */
private fun Drawable.toBitmapOrNull(): Bitmap? {
    if (this is BitmapDrawable) {
        val existing = bitmap ?: return null
        return if (existing.isMutable) existing else existing.copy(Bitmap.Config.ARGB_8888, false)
    }
    val width = intrinsicWidth
    val height = intrinsicHeight
    if (width <= 0 || height <= 0) return null
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    setBounds(0, 0, canvas.width, canvas.height)
    draw(canvas)
    return bitmap
}

/**
 * 内存口径映射：Coil 的 [MemoryCache] → 诊断页的三个数（占用 / 上限 / 条目数）。
 *
 * 单独抽出来是为了能在 JVM 单测里用假 cache 断言「这三个数就是 size / maxSize / keys.size」，
 * 而不是靠“我觉得对”。[maxBytes] 在没有 cache（未安装）时回落到构造参数（默认 16MB），
 * 这也是「上限钉死、不随 Coil 默认百分比跳档」那条契约的落点。
 */
internal object MemoryCacheStats {

    fun bytes(cache: MemoryCache?): Int = cache?.size?.toInt() ?: 0

    fun maxBytes(cache: MemoryCache?, fallback: Int): Int = cache?.maxSize?.toInt() ?: fallback

    fun entries(cache: MemoryCache?): Int = cache?.keys?.size ?: 0
}

