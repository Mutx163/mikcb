package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.infra.AppUpdateCheckResult
import java.net.URI
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.Locale

/**
 * 「版本更新页」的纯判据/格式化层（移植 `lib/screens/about_screen.dart` 的
 * `_AboutUpdateScreenState` 里不碰 IO 的那几段）。
 *
 * 渲染层只负责「按这里算出来的结果画」，所有分支判断、字符串化、去重都在这里，
 * 以便在 JVM 单测里逐条钉死（与关于域其它页同一纪律）。
 */

/** 页面主体当前该画哪一屏。 */
enum class AboutUpdatePagePhase {
    /** 没有包信息或检查进行中：居中「正在检查更新……」。 */
    CHECKING,

    /** 拿不到 release（result 为空，或 hasRelease=false）：失败卡 + 重新检查。 */
    CHECK_FAILED,

    /** 拿到了 release：状态卡 + 本次更新说明。 */
    READY,
}

/**
 * Dart `_buildUpdateList`（`:689-752`）与 `_buildStatusCard`（`:788-838`）的合流判据：
 * - 检查中（无包信息 / waiting）→ [AboutUpdatePagePhase.CHECKING]；
 * - 结果为空，或 `result.hasRelease == false` → [AboutUpdatePagePhase.CHECK_FAILED]；
 * - 其余 → [AboutUpdatePagePhase.READY]。
 *
 * 注意 `hasUpdate` 为真但 `hasRelease` 为假的自相矛盾态，按 Dart 口径**一律当失败**，
 * 不画成「发现新版本」（`resolveAboutUpdateCardState` 已单独钉过这条，这里复述口径）。
 */
fun resolveAboutUpdatePagePhase(
    packageInfoAvailable: Boolean,
    checking: Boolean,
    result: AppUpdateCheckResult?,
): AboutUpdatePagePhase {
    if (!packageInfoAvailable || checking) {
        return AboutUpdatePagePhase.CHECKING
    }
    if (result == null || !result.hasRelease) {
        return AboutUpdatePagePhase.CHECK_FAILED
    }
    return AboutUpdatePagePhase.READY
}

/**
 * Dart `_debugPreviousVersion`（`:1004-1014`）：把版本号最后一段数字减一，仅非 release 构建的
 * 调试预览用。段数 < 2、末段无数字或 ≤ 0 时回落 `0.0.0`。
 */
fun debugPreviousVersion(latest: String?): String {
    val parts = (latest ?: "").split(".")
    if (parts.size < 2) return "0.0.0"
    val digits = parts.last().replace(Regex("[^0-9]"), "")
    val last = digits.toIntOrNull()
    if (last == null || last <= 0) return "0.0.0"
    return (parts.dropLast(1) + (last - 1).toString()).joinToString(".")
}

/**
 * Dart `_formatBytes`（`:1711-1719`）：<1KiB 用 `B`，<1MiB 用一位小数 `KB`，否则一位小数 `MB`。
 * 用 [Locale.US] 保证小数点是 `.`（不受系统区域设置影响，与 Dart `toStringAsFixed` 一致）。
 */
fun formatBytes(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    if (bytes < 1024 * 1024) return String.format(Locale.US, "%.1f KB", bytes / 1024.0)
    return String.format(Locale.US, "%.1f MB", bytes / (1024.0 * 1024.0))
}

/**
 * Dart `_formatDateTime`（`:1614-1621`）：`yyyy-MM-dd HH:mm`。
 *
 * Dart 侧 `updatedAt` 是 `DateTime.tryParse(ISO)` 得到的 **UTC** 时刻，格式化取的是它自身的
 * `.year/.hour`（即 UTC 字段）。为逐字对齐，默认用 [ZoneOffset.UTC]；调用方需要本地时间可显式传 zone。
 */
fun formatUpdateDateTime(millis: Long, zone: ZoneId = ZoneOffset.UTC): String {
    val dt = Instant.ofEpochMilli(millis).atZone(zone)
    return String.format(
        Locale.US,
        "%04d-%02d-%02d %02d:%02d",
        dt.year, dt.monthValue, dt.dayOfMonth, dt.hour, dt.minute,
    )
}

/**
 * Dart `_normalizeMirrorUrlPrefix`（`:1623-1636`）：去空白；空 → null；必须能解析出
 * scheme 与 host；末尾补 `/`。非法（无 scheme / 无 host）→ null。
 */
fun normalizeMirrorUrlPrefix(input: String?): String? {
    val value = (input ?: "").trim()
    if (value.isEmpty()) return null
    val uri = try {
        URI(value)
    } catch (_: Exception) {
        return null
    }
    if (uri.scheme.isNullOrEmpty() || uri.host.isNullOrEmpty()) return null
    return if (value.endsWith("/")) value else "$value/"
}

/**
 * Dart `_buildMirrorPresetCandidates`（`:1365-1407`）：固定四个内置镜像 +
 * （自定义前缀合法时）一个 `custom`。返回 `预设 to 前缀`，顺序与 Dart 一致。
 */
fun buildMirrorPresetCandidates(customMirrorUrlPrefix: String?): List<Pair<MirrorPreset, String>> {
    val custom = customMirrorUrlPrefix ?: ""
    val result = mutableListOf(
        MirrorPreset.GHFAST to resolveMirrorUrlPrefix(MirrorPreset.GHFAST, custom),
        MirrorPreset.GH_LLKK to resolveMirrorUrlPrefix(MirrorPreset.GH_LLKK, custom),
        MirrorPreset.GH_PROXY_COM to resolveMirrorUrlPrefix(MirrorPreset.GH_PROXY_COM, custom),
        MirrorPreset.GH_PROXY_NET to resolveMirrorUrlPrefix(MirrorPreset.GH_PROXY_NET, custom),
    )
    val normalizedCustom = normalizeMirrorUrlPrefix(custom)
    if (normalizedCustom != null) {
        result.add(MirrorPreset.CUSTOM to normalizedCustom)
    }
    return result
}

/** 下载进度：`fraction == null` 表示总大小未知（镜像不给 Content-Length 时）。 */
data class DownloadProgressModel(
    val downloadedBytes: Long,
    val totalBytes: Long?,
    val fraction: Double?,
) {
    val totalKnown: Boolean get() = fraction != null
}

/**
 * Dart `_buildDownloadProgressBar`（`:1638-1709`）的进度判据：
 * 总字节为空或 ≤ 0 → 进度未知（画不确定进度条）；否则按比例。
 */
fun resolveDownloadProgress(downloadedBytes: Long, totalBytes: Long?): DownloadProgressModel {
    val fraction = if (totalBytes == null || totalBytes <= 0L) {
        null
    } else {
        (downloadedBytes.toDouble() / totalBytes.toDouble()).coerceIn(0.0, 1.0)
    }
    return DownloadProgressModel(
        downloadedBytes = downloadedBytes,
        totalBytes = totalBytes,
        fraction = fraction,
    )
}
