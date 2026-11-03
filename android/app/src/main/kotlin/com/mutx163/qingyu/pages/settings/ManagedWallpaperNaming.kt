package com.mutx163.qingyu.pages.settings

import java.io.File

/**
 * 「相册选图 → 受管壁纸目录」这条链的**命名口径**（纯 Kotlin，可在 L0 直测）。
 *
 * 受管目录是 App 私有的 `files/wallpapers/`（与 Dart `kHomePageWallpaperDirectoryName`
 * 同名）：卸载即清、不进相册、不随备份走。Dart 侧对应
 * `pickAndStoreManagedImage`（`settings_home_backdrop_flow.dart:1007-1019`）里的
 * 目录 / 前缀 / 扩展名三段。
 *
 * ## 为什么单独一层
 *
 * 真正落盘要 `Context.contentResolver`（Android 胶水，放在
 * `platform/ManagedWallpaperStore.kt`）。这里只留**不碰 Android 的部分**：
 * 文件名怎么拼、MIME 怎么折成扩展名、完整路径长什么样。这样「写进配置的那条路径」
 * 能在 JVM 单测里逐字断言，不必起设备。
 *
 * 扩展名认不出来时退回 `png`：解码只看文件内容、不看后缀，png 是安全兜底
 * （与 [ManagedWallpaperStore] 的既有口径一致）。
 */
object ManagedWallpaperNaming {

    /** 受管壁纸目录名（`File(context.filesDir, DIRECTORY_NAME)`）。 */
    const val DIRECTORY_NAME = "wallpapers"

    /** 文件名前缀：`wallpaper_<毫秒时间戳>.<ext>`。 */
    const val FILE_PREFIX = "wallpaper_"

    /** 兜底扩展名（MIME 与路径都认不出来时）。 */
    const val FALLBACK_EXTENSION = "png"

    /**
     * 一次选图落盘的文件名（Dart `pickAndStoreManagedImage` 的 `wallpaper_<ts>.<ext>`）。
     *
     * [nowMs] 由调用方注入，单测才能钉死结果。
     */
    fun fileName(nowMs: Long, extension: String): String =
        "$FILE_PREFIX$nowMs.${normalizeExtension(extension)}"

    /** 受管目录里的完整路径；取景页「完成」写进设置的就是这个串。 */
    fun targetPath(directoryPath: String, nowMs: Long, extension: String): String =
        File(directoryPath, fileName(nowMs, extension)).absolutePath

    /**
     * 相册 URI 的落盘扩展名：先看 MIME，再看路径后缀，最后退回 [FALLBACK_EXTENSION]。
     *
     * 读图只看内容、不看后缀，所以这里的值只影响文件名可读性；认错不会让图坏掉。
     */
    fun extensionForMime(mimeType: String?, lastPathSegment: String?): String {
        when (mimeType?.lowercase()) {
            "image/jpeg" -> return "jpg"
            "image/png" -> return "png"
            "image/webp" -> return "webp"
            "image/gif" -> return "gif"
            "image/heic", "image/heif" -> return "heic"
        }
        val fromPath = lastPathSegment
            ?.substringAfterLast('.', missingDelimiterValue = "")
            .orEmpty()
        return normalizeExtension(fromPath)
    }

    /** 小写、只留 1~5 位字母数字；不合规退回 [FALLBACK_EXTENSION]。 */
    fun normalizeExtension(raw: String): String {
        val value = raw.trim().lowercase()
        return if (value.length in 1..5 && value.all { it.isLetterOrDigit() }) {
            value
        } else {
            FALLBACK_EXTENSION
        }
    }
}
