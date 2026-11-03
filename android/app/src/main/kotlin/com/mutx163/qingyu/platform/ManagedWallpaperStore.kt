package com.mutx163.qingyu.platform

import android.content.Context
import android.net.Uri
import com.mutx163.qingyu.pages.settings.ManagedWallpaperNaming
import java.io.File

/**
 * 「相册 URI → 受管壁纸目录」的唯一落盘入口（Dart `pickAndStoreManagedImage`）。
 *
 * ## 为什么要有这个共享件
 *
 * 这条链原先只藏在外观编辑页宿主里（`AppearanceEditorHost.importPickedWallpaper`，
 * 私有函数）；取景页想就地「换壁纸」时没有任何公共入口，只能承认「做不到」。
 * 现在收成一处：外观编辑页与取景页选图走**同一个**目录、同一套文件名、同一份
 * 扩展名规则，不会一边写 `files/wallpapers/`、另一边写别处。
 *
 * 目录是 App 私有的（`files/wallpapers/`）：卸载即清、不进相册、不随设置同步走。
 * 历史保留靠 `WallpaperHistoryLedger` 的 10 条上限，不在这里「选新图就清空旧图」。
 *
 * 纯命名规则在 [ManagedWallpaperNaming]（JVM 可测）；本文件只做 Android IO。
 */
object ManagedWallpaperStore {

    /** 受管壁纸目录（不保证存在；写入前 [storePickedImage] 会 `mkdirs()`）。 */
    fun directory(context: Context): File =
        File(context.filesDir, ManagedWallpaperNaming.DIRECTORY_NAME)

    /**
     * 把相册选中的 URI 复制进受管目录，返回**写进设置的那条绝对路径**。
     *
     * 取消 / 无读权限 / 空文件 / 写盘失败一律返回 null：调用方据此提示「保存失败」，
     * 不会把一条不存在的路径写进设置。挂起调用请放在 IO 线程。
     *
     * @param nowMs 文件名时间戳；单测/诊断可注入，运行时用当前时间。
     */
    fun storePickedImage(
        context: Context,
        uri: Uri,
        nowMs: Long = System.currentTimeMillis(),
    ): String? {
        val bytes = runCatching {
            context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        }.getOrNull()
        if (bytes == null || bytes.isEmpty()) return null
        val mime = runCatching { context.contentResolver.getType(uri) }.getOrNull()
        val extension = ManagedWallpaperNaming.extensionForMime(mime, uri.lastPathSegment)
        val target = File(
            directory(context).apply { mkdirs() },
            ManagedWallpaperNaming.fileName(nowMs, extension),
        )
        return runCatching {
            target.writeBytes(bytes)
            target.absolutePath
        }.getOrNull()
    }
}
