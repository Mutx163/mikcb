package com.mutx163.qingyu.platform

import com.mutx163.qingyu.pages.settings.BingGalleryBinaryHttp
import com.mutx163.qingyu.pages.settings.BingGalleryBytes
import com.mutx163.qingyu.pages.settings.BingGalleryHttp
import com.mutx163.qingyu.pages.settings.BingGalleryProgress
import java.io.ByteArrayOutputStream

/**
 * Bing 壁纸两处接缝的 OkHttp 实现（2026-11-14「全部网络请求改走 OkHttp」）。
 *
 * ## 为什么实现放 `platform/`、接口留在 `pages/settings/`
 *
 * `pages/settings` 的 L0 是**纯 JVM** 面（目录里一旦出现 `android.*` 整个模块的 L0 会被
 * 静默跳过），而 L0 的 classpath 里也没有 okhttp jar。所以边界和 `OkHttpAboutHttp`、
 * `OkHttpHolidayHttp` 完全一致：接口留域内（可注入假件、可 JVM 单测），OkHttp 实现在这里。
 *
 * ## 语义与旧 JDK 实现逐条对齐
 *
 * - 只有 2xx 才交回正文；非 2xx / 传输失败一律按「这次没拿到」处理（上层把它与「解析不出
 *   条目」一视同仁，见 `BingGalleryDataSource.parse`）；
 * - 二进制那条保持**流式 + 进度回调**：`onProgress(received, total)`，服务端没给
 *   `Content-Length` 时 `total` 传 `-1`（与 `BingGalleryProgress` 的约定一致：`<= 0` 即未知）；
 * - 拿不到响应时 `statusCode = -1`，与 Dart 侧同一口径；
 * - UA 逐请求传：Bing 对没有 UA 的请求偶尔回 403。
 */
class OkHttpBingGalleryHttp(
    private val connectTimeoutMs: Long = DEFAULT_CONNECT_TIMEOUT_MS,
    private val readTimeoutMs: Long = DEFAULT_READ_TIMEOUT_MS,
) : BingGalleryHttp {

    override fun get(url: String): String? {
        val result = QingyuHttp.getText(
            QingyuHttp.HttpCallSpec(
                url = url,
                headers = mapOf("User-Agent" to USER_AGENT),
                connectTimeoutMs = connectTimeoutMs,
                readTimeoutMs = readTimeoutMs,
            ),
        )
        val status = result.status ?: return null
        return if (status in HTTP_OK_RANGE) result.body.orEmpty() else null
    }

    companion object {
        const val DEFAULT_CONNECT_TIMEOUT_MS: Long = 10_000L
        const val DEFAULT_READ_TIMEOUT_MS: Long = 15_000L
    }
}

/**
 * Bing 原图的 OkHttp 实现：**流式**读进内存缓冲，边读边报进度（壁纸原图几十 MB 上限，
 * 但下载链路要求进度可见、且不允许一次 `bytes()` 阻塞整段）。
 */
class OkHttpBingGalleryBinaryHttp(
    private val connectTimeoutMs: Long = OkHttpBingGalleryHttp.DEFAULT_CONNECT_TIMEOUT_MS,
    private val readTimeoutMs: Long = DEFAULT_READ_TIMEOUT_MS,
) : BingGalleryBinaryHttp {

    override fun get(url: String, progress: BingGalleryProgress): BingGalleryBytes {
        val out = ByteArrayOutputStream(INITIAL_BUFFER_BYTES)
        val (_, result) = QingyuHttp.stream(
            spec = QingyuHttp.HttpCallSpec(
                url = url,
                headers = mapOf("User-Agent" to USER_AGENT),
                connectTimeoutMs = connectTimeoutMs,
                readTimeoutMs = readTimeoutMs,
            ),
            onChunk = { chunk, length -> out.write(chunk, 0, length) },
            onProgress = { received, total -> progress.onProgress(received, total ?: UNKNOWN_TOTAL) },
        )
        // status 为 null = 传输层失败（断网 / 超时 / TLS）：按 Dart 口径回 -1。
        val status = result.status ?: return BingGalleryBytes(NO_RESPONSE, ByteArray(0))
        if (status !in HTTP_OK_RANGE) {
            return BingGalleryBytes(status, ByteArray(0))
        }
        return BingGalleryBytes(status, out.toByteArray())
    }

    companion object {
        /** 旧实现是 10s 连接 / 30s 读：壁纸原图比清单大一个量级，读超时给足。 */
        const val DEFAULT_READ_TIMEOUT_MS: Long = 30_000L

        /** 服务端没给 `Content-Length` 时的进度总量（`BingGalleryProgress` 约定 `<= 0` = 未知）。 */
        private const val UNKNOWN_TOTAL: Long = -1L

        /** 拿不到响应（断网 / 超时）：与 Dart 用 `-1` 表示同一件事。 */
        private const val NO_RESPONSE: Int = -1

        private const val INITIAL_BUFFER_BYTES: Int = 64 * 1024
    }
}

/** Bing 对没有 UA 的请求偶尔回 403；带一个能识别来源的串就够（与迁移前同值）。 */
private const val USER_AGENT: String = "qingyu-kb-compose/1.0"

/** 只要 2xx 才算拿到正文。 */
private val HTTP_OK_RANGE = 200..299
