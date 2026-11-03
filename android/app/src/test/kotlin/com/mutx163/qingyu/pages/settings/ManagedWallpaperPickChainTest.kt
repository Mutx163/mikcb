package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 取景页「换壁纸」这条链的契约测试（R14，Dart
 * `wallpaper_position_picker_sheet.dart:429-465` + `settings_home_backdrop_flow.dart:1007-1091`）。
 *
 * 覆盖三段：
 * 1. 相册 URI → 受管目录的**路径口径**（目录名 / 前缀 / 扩展名）；
 * 2. 这条路径**逐字**写进设置（不是「页面能打开」那种弱断言）；
 * 3. 本次选图里哪些算「没人引用、可以删」。
 *
 * Android 的复制动作（`ManagedWallpaperStore.storePickedImage`）要 `ContentResolver`，
 * 不在 JVM 单测范围；这里钉的是它必须产出的那三样纯数据。
 */
class ManagedWallpaperPickChainTest {

    // ------------------------------------------------------- 路径口径

    @Test
    fun `选图文件名是 wallpaper 前缀加时间戳与扩展名`() {
        assertEquals(
            "wallpaper_1700000000000.jpg",
            ManagedWallpaperNaming.fileName(1_700_000_000_000L, "jpg"),
        )
        // 逐字复用 Dart `pickAndStoreManagedImage` 的命名形态（目录名也要一致，
        // 否则历史里的旧路径与新手选的图落在两个目录，删文件白名单会漏）。
        assertEquals("wallpapers", ManagedWallpaperNaming.DIRECTORY_NAME)
    }

    @Test
    fun `完整路径落在受管目录里且与平台分隔符一致`() {
        val directory = File("/data/user/0/app/files/wallpapers")
        val expected = File(directory, "wallpaper_1700000000000.webp").absolutePath
        assertEquals(
            expected,
            ManagedWallpaperNaming.targetPath(
                directoryPath = directory.path,
                nowMs = 1_700_000_000_000L,
                extension = "webp",
            ),
        )
    }

    @Test
    fun `扩展名先看 MIME 再看路径后缀最后退回 png`() {
        assertEquals("jpg", ManagedWallpaperNaming.extensionForMime("image/jpeg", "a.png"))
        assertEquals("png", ManagedWallpaperNaming.extensionForMime("image/png", null))
        // MIME 大小写不敏感（系统 provider 不保证小写）。
        assertEquals("heic", ManagedWallpaperNaming.extensionForMime("IMAGE/HEIC", null))
        // MIME 缺失时退回路径后缀。
        assertEquals("webp", ManagedWallpaperNaming.extensionForMime(null, "photo.WEBP"))
        // 没后缀 / 后缀过长 / 含非字母数字 -> png。
        assertEquals("png", ManagedWallpaperNaming.extensionForMime(null, "noextension"))
        assertEquals("png", ManagedWallpaperNaming.extensionForMime(null, "a.verylongext"))
        assertEquals("png", ManagedWallpaperNaming.extensionForMime(null, null))
    }

    // ------------------------------------------------------- 写进配置的路径值

    @Test
    fun `换壁纸后完成，写进设置的是受管目录里的新路径`() {
        val directory = File("/data/user/0/app/files/wallpapers")
        val pickedPath = ManagedWallpaperNaming.targetPath(
            directoryPath = directory.path,
            nowMs = 1_700_000_000_000L,
            extension = "jpg",
        )
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/w/old.jpg",
            homePageWallpaperAlignX = 0.4,
            homePageWallpaperAlignY = -0.3,
            homePageWallpaperScale = 2.0,
            wallpaperHistory = listOf(
                WallpaperHistoryRowModel(
                    key = "/w/old.jpg",
                    alignX = 0.4,
                    alignY = -0.3,
                    scale = 2.0,
                    usedAt = 10L,
                ),
            ),
        )

        // 取景页换图后取景回默认（Dart `_switchWallpaper`，`:441-450`）。
        val next = SettingsWallpaperPositionPage.settingsAfterConfirm(
            current = current,
            path = pickedPath,
            alignX = WallpaperFraming.DEFAULT.alignX,
            alignY = WallpaperFraming.DEFAULT.alignY,
            scale = WallpaperFraming.DEFAULT.scale,
            usedAtMs = 1_700_000_000_001L,
        ) ?: throw AssertionError("有路径时必须返回新模型")

        // 直接断言配置字段，而不是「页面渲染出来了」。
        assertEquals(pickedPath, next.homePageWallpaperPath)
        assertEquals(0.0, next.homePageWallpaperAlignX, 0.0)
        assertEquals(0.0, next.homePageWallpaperAlignY, 0.0)
        assertEquals(1.0, next.homePageWallpaperScale, 0.0)
        // 补历史：新图置顶，旧图仍在（Dart 先记旧条目、再记新条目）。
        assertEquals(pickedPath, next.wallpaperHistory.first().key)
        assertTrue(
            "换下来的旧壁纸必须留在最近使用里",
            next.wallpaperHistory.any { it.key == "/w/old.jpg" },
        )
        assertEquals(1, next.wallpaperHistory.count { it.key == pickedPath })
    }

    // ------------------------------------------------------- 清理判据

    @Test
    fun `只清本次选过且没有任何设置引用的图`() {
        val settings = TimetableSettingsModel(
            homePageWallpaperPath = "/w/new.jpg",
            wallpaperHistory = listOf(WallpaperHistoryRowModel(key = "/w/old.jpg")),
        )
        val victims = SettingsWallpaperPositionPage.unreferencedPicked(
            pickedPaths = listOf(
                "/w/new.jpg", // 当前壁纸：留着
                "/w/old.jpg", // 最近使用：留着
                "/w/stale.jpg", // 连选两张只确认后一张：删
                "/w/stale.jpg", // 重复项去重
                "", // 空路径不碰
            ),
            settings = settings,
        )
        assertEquals(listOf("/w/stale.jpg"), victims)
    }

    @Test
    fun `还没落盘任何设置时，本次选的全算未引用`() {
        assertEquals(
            listOf("/w/a.jpg", "/w/b.jpg"),
            SettingsWallpaperPositionPage.unreferencedPicked(
                pickedPaths = listOf("/w/a.jpg", "/w/b.jpg"),
                settings = TimetableSettingsModel(),
            ),
        )
        assertTrue(
            SettingsWallpaperPositionPage.unreferencedPicked(emptyList(), null).isEmpty(),
        )
    }
}
