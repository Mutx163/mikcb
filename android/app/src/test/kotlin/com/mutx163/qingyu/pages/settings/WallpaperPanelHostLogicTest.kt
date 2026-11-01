package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壁纸面板三条写入的落盘契约（宿主执行的纯运算部分）。
 *
 * 对应 Dart：
 * * 选图 → 收进受管目录后 **记一条历史 + 写路径 / 居中取景**（`settings_home_backdrop_flow.dart:1007-1019`）；
 * * 切回历史 → **连 alignX / alignY / scale 三件一起还原**（`:294-316`）；
 * * 确认删除 → 摘条目并把旧历史当撤销凭据（`:325-354`）。
 *
 * IO（复制 URI、删文件）在宿主，不在本层；这里只钉「宿主该写什么」。
 */
class WallpaperPanelHostLogicTest {

    private fun modelRow(
        key: String,
        alignX: Double = 0.0,
        alignY: Double = 0.0,
        scale: Double = 1.0,
        usedAt: Long = 0L,
    ) = WallpaperHistoryRowModel(
        key = key,
        alignX = alignX,
        alignY = alignY,
        scale = scale,
        usedAt = usedAt,
    )

    // ------------------------------------------------------------ 相册选图

    @Test
    fun `选图落盘写路径 居中取景 并记进历史最前`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/w/old.png",
            homePageWallpaperAlignX = 0.6,
            homePageWallpaperAlignY = -0.4,
            homePageWallpaperScale = 2.5,
            wallpaperHistory = listOf(modelRow("/w/old.png")),
        )

        val result = WallpaperHistoryLedger.applyPicked(current, "/w/new.png", usedAt = 9L)

        assertNotNull(result)
        val settings = result!!.settings
        assertEquals("/w/new.png", settings.homePageWallpaperPath)
        // 新图从居中、不缩放起步（Dart 同口径）。
        assertEquals(0.0, settings.homePageWallpaperAlignX, 0.0)
        assertEquals(0.0, settings.homePageWallpaperAlignY, 0.0)
        assertEquals(1.0, settings.homePageWallpaperScale, 0.0)
        assertEquals("/w/new.png", settings.wallpaperHistory.first().key)
        assertEquals(listOf("/w/new.png", "/w/old.png"), settings.wallpaperHistory.map { it.key })
        assertTrue(result.evictedPaths.isEmpty())
    }

    @Test
    fun `选图让历史超过十条时把最旧一条交出来待删`() {
        // 历史按「最新在前」存：10 → 1，最旧的是 1。
        val history = (WallpaperHistoryLedger.MAX_ENTRIES downTo 1).map { modelRow("/w/$it.png") }
        val current = TimetableSettingsModel(wallpaperHistory = history)

        val result = WallpaperHistoryLedger.applyPicked(current, "/w/new.png", usedAt = 99L)

        assertNotNull(result)
        assertEquals(WallpaperHistoryLedger.MAX_ENTRIES, result!!.settings.wallpaperHistory.size)
        assertEquals("/w/new.png", result.settings.wallpaperHistory.first().key)
        assertEquals(listOf("/w/1.png"), result.evictedPaths)
    }

    @Test
    fun `空路径不写设置`() {
        assertNull(WallpaperHistoryLedger.applyPicked(TimetableSettingsModel(), "  "))
    }

    // ---------------------------------------------------------- 切回历史

    @Test
    fun `按 key 切回历史 连缩放一起还原 旧图与新图都补进历史`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/w/a.png",
            homePageWallpaperAlignX = 0.1,
            homePageWallpaperAlignY = 0.2,
            homePageWallpaperScale = 1.0,
            wallpaperHistory = listOf(
                modelRow("/w/a.png", alignX = 0.1, alignY = 0.2, scale = 1.0),
                modelRow("/w/b.png", alignX = -0.2, alignY = 0.3, scale = 2.5),
            ),
        )

        val result = WallpaperHistoryLedger.select(current, "/w/b.png", usedAt = 5L)

        assertNotNull(result)
        val settings = result!!.settings
        assertEquals("/w/b.png", settings.homePageWallpaperPath)
        assertEquals(-0.2, settings.homePageWallpaperAlignX, 0.0)
        assertEquals(0.3, settings.homePageWallpaperAlignY, 0.0)
        // ⚠️ 只还原位置不还原缩放 = 取景被还原了一半（旧图放大过的那张会被静默缩回 1）。
        assertEquals(2.5, settings.homePageWallpaperScale, 0.0)
        assertEquals(listOf("/w/b.png", "/w/a.png"), settings.wallpaperHistory.map { it.key })
    }

    @Test
    fun `切回历史里没有的 key 时什么都不做`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/w/a.png",
            wallpaperHistory = listOf(modelRow("/w/a.png")),
        )
        assertNull(WallpaperHistoryLedger.select(current, "/w/missing.png"))
    }

    // ---------------------------------------------------------- 删除与撤销

    @Test
    fun `确认删除给出待删路径 撤销把整份旧历史放回`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/w/a.png",
            wallpaperHistory = listOf(
                modelRow("/w/a.png"),
                modelRow("/w/b.png", scale = 2.0),
                modelRow("/w/c.png"),
            ),
        )
        val removal = WallpaperHistoryLedger.remove(current, "/w/b.png")

        assertNotNull(removal)
        assertEquals("/w/b.png", removal!!.removedPath)
        assertEquals(listOf("/w/a.png", "/w/c.png"), removal.settings.wallpaperHistory.map { it.key })

        val restored = WallpaperHistoryLedger.undo(removal.settings, removal.previousHistory)
        assertEquals(listOf("/w/a.png", "/w/b.png", "/w/c.png"), restored.wallpaperHistory.map { it.key })
        // 旧条目连取景一起回来（整份列表替换，不是只塞回 key）。
        assertEquals(2.0, restored.wallpaperHistory[1].scale, 0.0)
    }
}
