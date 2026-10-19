package com.mutx163.qingyu

import java.net.URI
import java.util.Locale

/**
 * 系统下载器（DownloadManager）通道的 URL 信任根（2026-10-19 审计 #24）。
 *
 * 此前原生侧只判非空，任意 URL 都会被写进公共 Downloads 目录。信任根与
 * Dart 侧 `app_update_service.dart` 的 `isTrustedApkDownloadUrl` /
 * `isOfficialApkAssetUrl` 对齐：官方直连 GitHub / GitCode（含子域），外加
 * githubusercontent.com（GitHub release 资产 302 的真实落点域）。第三方加速
 * 镜像只服务应用内下载（`downloadAndInstallUpdate`，带 digest 校验），永远
 * 不该走到系统下载器通道，所以不在白名单里。
 *
 * 用 java.net.URI 而不是 android.net.Uri：本函数要在 JVM 单测里直接跑
 * （android.net.Uri 在 unit test 里是返回默认值的 stub）。
 */
internal fun isTrustedSystemDownloadUrl(url: String): Boolean {
    val uri = try {
        URI(url)
    } catch (_: Exception) {
        return false
    }
    val scheme = uri.scheme?.lowercase(Locale.US)
    if (scheme != "https") {
        return false
    }
    val host = uri.host?.lowercase(Locale.US) ?: return false
    return host == "github.com" ||
        host.endsWith(".github.com") ||
        host == "githubusercontent.com" ||
        host.endsWith(".githubusercontent.com") ||
        host == "gitcode.com" ||
        host.endsWith(".gitcode.com")
}
