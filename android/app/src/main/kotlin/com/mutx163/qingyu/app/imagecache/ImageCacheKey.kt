package com.mutx163.qingyu.app.imagecache

/**
 * 网络图片内存缓存的键（纯逻辑，JVM 可测，禁 android 导入）。
 *
 * 为什么要有这一层：[AndroidImageLoader] 的内存缓存是「同一张图只解一次」。但同一 URL 以
 * 不同尺寸请求时，解码结果是不同 Bitmap —— 若只按 URL 做键，小图会被大图顶替（或反之）。
 * 所以键 = **规范化后的 URL + 尺寸桶**。
 *
 * ## URL 规范化（`normalizeUrl`）
 * 目标只做「语义等价、不会误合并」的归一，不做激进重写：
 * 1. 去掉首尾空白；
 * 2. scheme 与 authority（host[:port]）转小写（HTTP/HTTPS 主机名大小写不敏感）；
 * 3. path / query / fragment **原样保留**（路径可能大小写敏感，不能动）。
 *
 * ## 尺寸桶（`sizeBucket`）
 * 把目标宽高各自**向上取到最近的 2 的幂**（最小 1，最大 [MAX_BUCKET]）。
 * 向上取整（而不是就近）是保守选择：解码只会比目标大一点，绝不会糊。
 * 用 2 的幂是因为 `BitmapFactory.inSampleSize` 本身就是 2 的幂，桶与解码粒度对齐。
 *
 * @see ImageSizeSelector
 */
object ImageCacheKey {

    /** 尺寸桶上限：超过它的目标视为同一档（超大屏/异常值不无限细分键空间）。 */
    const val MAX_BUCKET: Int = 4096

    fun of(url: String, targetWidthPx: Int, targetHeightPx: Int): String {
        val normalized = normalizeUrl(url)
        val w = sizeBucket(targetWidthPx)
        val h = sizeBucket(targetHeightPx)
        return "$normalized|${w}x$h"
    }

    /**
     * 规范化 URL：trim → scheme/authority 小写，其余原样。
     * 不含 scheme 分隔符（"://"）的字符串只做 trim（无法可靠区分 host）。
     */
    fun normalizeUrl(url: String): String {
        val trimmed = url.trim()
        val sep = trimmed.indexOf("://")
        if (sep <= 0) return trimmed
        val scheme = trimmed.substring(0, sep).lowercase()
        val rest = trimmed.substring(sep + 3)
        // authority 到第一个 '/', '?' 或 '#' 为止
        val authEnd = rest.indexOfFirst { it == '/' || it == '?' || it == '#' }
        if (authEnd < 0) {
            return "$scheme://${rest.lowercase()}"
        }
        val authority = rest.substring(0, authEnd).lowercase()
        val tail = rest.substring(authEnd)
        return "$scheme://$authority$tail"
    }

    /** 把单维度向上取到最近的 2 的幂；<=0 视为 0；超过 [MAX_BUCKET] 钳到 [MAX_BUCKET]。 */
    fun sizeBucket(px: Int): Int {
        if (px <= 0) return 0
        if (px >= MAX_BUCKET) return MAX_BUCKET
        var bucket = 1
        while (bucket < px) {
            bucket = bucket shl 1
        }
        return bucket // 此时 bucket 是第一个 >= px 的 2 的幂
    }
}
