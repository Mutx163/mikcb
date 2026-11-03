package com.mutx163.qingyu.transfer.lan

/**
 * 局域网编辑控制台的**静态资源分发**（移植自 Dart `LanEditServerService._serveStatic` /
 * `_mapAssetPath`）。
 *
 * ## 为什么需要它
 *
 * `LanEditHttpServer` 只路由 API 前缀（`/api/v1/`）。客户端（电脑浏览器）打开
 * `http://<ip>:<port>/` 时请求的是页面本身，不是 API —— 没有这一层，浏览器拿到的是
 * 404，用户看到「地址能打开但一片空白」，会认定功能坏了。
 *
 * ## 为什么是**固定映射表**而不是任意文件服务
 *
 * Dart 侧同样是一张硬编码表。这样做顺带把路径穿越关在门外：请求路径只能落到表里那
 * 九个键上，`../../` 什么的连门都没有。**不要**为了方便改成「拼目录 + 读文件」——
 * 那等于在一个同网段谁都能连的端口上开了文件读取。
 *
 * ## 为什么 `open` 是注入的函数
 *
 * 读 asset 要 `android.content.res.AssetManager`，而 `transfer/lan` 必须保持纯 Kotlin：
 * `scripts/test-kotlin-module.ps1` 判定「整目录只要有一个 .kt 引 android.* 就跳过整个目录」，
 * 一旦这里混进 android import，**全队**每次 L0 都会静默丢掉 `transfer/` 这一层。
 * 所以 Android 侧只提供一个 `(assetPath) -> ByteArray?` 的 lambda。
 *
 * ## 与 Dart 的差异（有意）
 *
 * 1. **只服务 GET**：浏览器的页面与子资源请求都是 GET。HEAD 会落到路由层的 404
 *    （Dart 的 `HttpServer` 会自动应答 HEAD）。本服务不做 SEO / 代理，这条用不上。
 * 2. **缺资源回 404 空体**（Dart 同样 404，但会带 Flutter 的默认错误页）。
 */
class LanEditStaticAssets(
    /** 读一个 Dart 风格的资源路径（`assets/lan_edit/index.html`）；读不到返回 null。 */
    private val open: (String) -> ByteArray?,
) {

    /** 处理一个 GET 请求；路径不在表里或资源读不出来时回 404。 */
    fun serve(path: String): LanEditHttpResponse {
        val assetPath = mapAssetPath(path) ?: return notFound()
        val bytes = runCatching { open(assetPath) }.getOrNull() ?: return notFound()
        return LanEditHttpResponse(
            status = 200,
            headers = listOf(
                "Content-Type" to contentTypeFor(assetPath),
                // 与 Dart 一致：控制台每次都要拿最新的，缓存住会让用户对着旧界面改课表。
                "Cache-Control" to "no-store",
                "Content-Security-Policy" to CONTENT_SECURITY_POLICY,
                // 指定了 Content-Type 就不要再让浏览器自己嗅探（与 Dart 一致）。
                "X-Content-Type-Options" to "nosniff",
            ),
            body = bytes,
        )
    }

    /** 请求路径 → 资源路径（Dart `_mapAssetPath` 逐条对照，**前缀已去 `assets/`**）。
     *
     *  2026-11-03 修：AssetManager 的路径相对 APK assets 根，照抄 Dart 的
     *  `assets/lan_edit/…` 会找成 `assets/assets/…`，整表必 FileNotFound、
     *  控制台整个 404（迁移 8af8d74d 同款路径病）。落点见仓库
     *  `android/app/src/main/assets/lan_edit|branding/`（裸路径）。 */
    fun mapAssetPath(path: String): String? = when (path) {
        "/", "/index.html" -> "lan_edit/index.html"
        "/assets/app.js" -> "lan_edit/app.js"
        "/assets/i18n.js" -> "lan_edit/i18n.js"
        "/assets/style.css", "/assets/lan-timetable.css" -> "lan_edit/lan-timetable.css"
        // 图标以 data: URI 内联在这个文件里，页面不依赖任何第三方 CDN：
        // 手机或访客设备离线时图标不会整体消失（Dart 原文，`@latest` 还带供应链风险）。
        "/assets/tabler-icons-subset.css" -> "lan_edit/tabler-icons-subset.css"
        // 登录页与浏览器标签页图标。
        "/assets/logo.png", "/favicon.ico" -> "branding/launcher_icon.png"
        else -> null
    }

    /** 资源路径 → `Content-Type`（Dart `_contentTypeFor`）。 */
    fun contentTypeFor(assetPath: String): String = when {
        assetPath.endsWith(".html") -> "text/html; charset=utf-8"
        assetPath.endsWith(".js") -> "application/javascript; charset=utf-8"
        assetPath.endsWith(".css") -> "text/css; charset=utf-8"
        assetPath.endsWith(".png") -> "image/png"
        else -> "application/json"
    }

    private fun notFound(): LanEditHttpResponse =
        LanEditHttpResponse.error(404, "not_found", "Resource not found")

    companion object {
        /**
         * 与 Dart `_lanEditContentSecurityPolicy` 逐字一致。
         *
         * 注意 `style-src` / `font-src` 里那个 `cdn.jsdelivr.net`：图标文件已经改成内联
         * data URI，正常加载不会用到它；保留这一项是因为移植期不排除页面里还有残留引用，
         * 收紧它属于单独一批（去掉后若页面真有 CDN 引用，图标会静默消失）。
         */
        const val CONTENT_SECURITY_POLICY: String =
            "default-src 'self'; " +
                "script-src 'self'; " +
                "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; " +
                "font-src 'self' https://cdn.jsdelivr.net; " +
                "img-src 'self' data:; " +
                "connect-src 'self'; " +
                "object-src 'none'; " +
                "base-uri 'none'; " +
                "frame-ancestors 'none'; " +
                "form-action 'self'"
    }
}

/**
 * 判断一个请求该不该走静态资源：只接 GET，且路径不属于 `/api/`。
 *
 * 抽成顶层函数而不是写在 [LanEditHttpServer] 的 `if` 里，是为了让「哪些请求算页面、
 * 哪些算接口」这条规则能被单测直接钉住——它写错的表现是「API 全 404」或
 * 「接口路径被当成页面」（很隐蔽）。
 */
fun isStaticAssetRequest(method: String, path: String): Boolean =
    method == "GET" && !path.startsWith("/api/")