package com.mutx163.qingyu.platform

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import com.mutx163.qingyu.app.imagecache.ImageCacheKey
import com.mutx163.qingyu.app.imagecache.ImageRetryBackoff
import com.mutx163.qingyu.app.imagecache.ImageSizeSelector
import com.mutx163.qingyu.app.imagecache.InFlightDeduplicator
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * 网络图片加载器（P35-B4 · 网络图片加载层）。
 *
 * 台账 §4.3 第 5 条：Bing 壁纸画廊、打赏二维码图此前没有任何图片加载层，界面空白/一直转圈。
 * 本类是那层的 Android 实现，**只用现有依赖**（`java.net` + `android.graphics` + `android.util`），
 * 不引入 Coil/Glide。
 *
 * 复用 `app/imagecache/` 的纯逻辑（JVM 单测覆盖）：
 * - [ImageCacheKey]：内存缓存键 = 规范化 URL + 尺寸桶；
 * - [InFlightDeduplicator]：同键并发请求收敛成一次加载（LEADER 下载，FOLLOWER 等待）；
 * - [ImageRetryBackoff]：失败有界指数退避重试；
 * - [ImageSizeSelector]：`BitmapFactory.inSampleSize` 的 2 的幂下采样值。
 *
 * 线程模型：网络与解码在 [executor] 的后台线程；回调统一 post 到主线程。
 * 回调在**主线程**触发（这是 UI 安全的前提）。
 *
 * 用法（本批不接线，调用点在 `pages/`，属别批写作用域）：
 * ```
 * AndroidImageLoader.shared.load(url, w, h) { bmp -> imageBitmap = bmp?.asImageBitmap() }
 * ```
 */
class AndroidImageLoader(
    private val maxCacheBytes: Int = DEFAULT_MAX_CACHE_BYTES,
    threadCount: Int = DEFAULT_THREAD_COUNT,
) {

    private val cache: LruCache<String, Bitmap> = object : LruCache<String, Bitmap>(maxCacheBytes) {
        override fun sizeOf(key: String, value: Bitmap): Int = value.byteCount
    }

    private val dedup = InFlightDeduplicator()
    private val executor: ExecutorService = Executors.newFixedThreadPool(threadCount)
    private val mainHandler = Handler(Looper.getMainLooper())

    /** key → 等待该 key 加载结果的回调列表。所有读写都在 [listenersLock] 下进行。 */
    private val listeners = ConcurrentHashMap<String, MutableList<(Bitmap?) -> Unit>>()
    private val listenersLock = Any()

    /**
     * 加载图片。命中内存缓存立即回调；否则发起/加入一次加载。
     * 回调在主线程触发，参数为解码后的 Bitmap，失败时为 null。
     */
    fun load(
        url: String,
        targetWidthPx: Int,
        targetHeightPx: Int,
        callback: (Bitmap?) -> Unit,
    ) {
        val key = ImageCacheKey.of(url, targetWidthPx, targetHeightPx)
        synchronized(listenersLock) {
            val cached = cache.get(key)
            if (cached != null) {
                postToMain(callback, cached)
                return
            }
            val role = dedup.begin(key)
            listeners.getOrPut(key) { mutableListOf() }.add(callback)
            if (role == InFlightDeduplicator.Role.LEADER) {
                executor.execute { runLoad(key, url, targetWidthPx, targetHeightPx) }
            }
        }
    }

    /** 清空内存缓存（内存吃紧 / 页面销毁时调用）。 */
    fun clear() {
        cache.evictAll()
    }

    /**
     * 内存缓存**当前占用**（字节）。
     *
     * 口径：`LruCache.size()` 返回的是 `sizeOf` 之和，而本类的 `sizeOf` 就是
     * `Bitmap.byteCount`，所以这里直接是字节数。
     */
    fun memoryCacheBytes(): Int = cache.size()

    /** 内存缓存条目数（`snapshot()` 是 LruCache 提供的一致性读快照）。 */
    fun memoryCacheEntryCount(): Int = cache.snapshot().size

    /** 内存缓存上限（字节），即构造时给的 [maxCacheBytes]。 */
    fun memoryCacheMaxBytes(): Int = maxCacheBytes

    /** 关闭后台线程池（宿主退出时调用）。 */
    fun shutdown() {
        executor.shutdown()
    }

    // ---- 内部：真正下载 + 解码 + 回发（后台线程） ----

    private fun runLoad(key: String, url: String, targetWidthPx: Int, targetHeightPx: Int) {
        var bitmap: Bitmap? = null
        try {
            var attempt = 1
            while (true) {
                bitmap = tryDownloadDecode(url, targetWidthPx, targetHeightPx)
                if (bitmap != null) break
                if (!ImageRetryBackoff.shouldRetry(attempt)) break
                try {
                    Thread.sleep(ImageRetryBackoff.delayMillis(attempt))
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    break
                }
                attempt++
            }
        } finally {
            val result = bitmap
            synchronized(listenersLock) {
                if (result != null) {
                    cache.put(key, result)
                    dedup.complete(key)
                } else {
                    dedup.fail(key)
                }
                val callbacks = listeners.remove(key)
                if (callbacks != null && callbacks.isNotEmpty()) {
                    mainHandler.post { callbacks.forEach { it(result) } }
                }
            }
        }
    }

    /** 一次下载 + 两遍解码（先量尺寸，再按 inSampleSize 解码）。失败返回 null。 */
    private fun tryDownloadDecode(url: String, targetWidthPx: Int, targetHeightPx: Int): Bitmap? {
        var conn: HttpURLConnection? = null
        return try {
            val connection = openConnection(url)
            conn = connection
            val code = connection.responseCode
            if (code !in 200..299) {
                null
            } else {
                val bytes = connection.inputStream.use { it.readBytes() }
                if (bytes.isEmpty()) {
                    null
                } else {
                    // 第一遍：只量尺寸，不解码像素
                    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                    val sample = ImageSizeSelector.inSampleSize(
                        bounds.outWidth, bounds.outHeight, targetWidthPx, targetHeightPx,
                    )
                    // 第二遍：按采样解码
                    val opts = BitmapFactory.Options().apply { inSampleSize = sample }
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
                }
            }
        } catch (e: Throwable) {
            null
        } finally {
            conn?.disconnect()
        }
    }

    private fun openConnection(url: String): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            instanceFollowRedirects = true
            requestMethod = "GET"
        }

    private fun postToMain(callback: (Bitmap?) -> Unit, bitmap: Bitmap?) {
        mainHandler.post { callback(bitmap) }
    }

    companion object {
        private const val DEFAULT_MAX_CACHE_BYTES = 16 * 1024 * 1024 // 16 MB
        private const val DEFAULT_THREAD_COUNT = 3
        private const val CONNECT_TIMEOUT_MS = 10_000
        private const val READ_TIMEOUT_MS = 15_000

        /** 进程级共享实例（调用点直接用，不必各自 new）。 */
        val shared: AndroidImageLoader by lazy { AndroidImageLoader() }
    }
}
