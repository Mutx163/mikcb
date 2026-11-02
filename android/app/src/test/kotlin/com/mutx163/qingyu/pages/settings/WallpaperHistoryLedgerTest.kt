package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壁纸「最近使用」台账的纯契约（Dart `lib/utils/wallpaper_history.dart` +
 * `settings_home_backdrop_flow.dart:234-417`、`:793-940`）。
 *
 * 四条核心断言，全部来自用户可见行为：
 * 1. 全局上限 10 条，挤出那条进待删清单；
 * 2. 当前这张补在最前（历史里没有时），并带上当前取景；
 * 3. 切回历史**连 alignX / alignY / scale 三件一起**还原；
 * 4. 淘汰文件的白名单是「所有课表 + 草稿 + 图库台账」三路并集。
 */
class WallpaperHistoryLedgerTest {

    private fun row(
        key: String,
        alignX: Double = 0.0,
        alignY: Double = 0.0,
        scale: Double = 1.0,
        usedAt: Long = 0L,
    ) = WallpaperHistoryRow(
        key = key,
        label = key.substringAfterLast('/'),
        alignX = alignX,
        alignY = alignY,
        scale = scale,
        usedAt = usedAt,
    )

    private fun modelRow(key: String) = WallpaperHistoryRowModel(key = key)

    // ------------------------------------------------------------ 10 条上限

    @Test
    fun `记满十条后第十一条把最旧的挤出并进待删清单`() {
        var history = emptyList<WallpaperHistoryRow>()
        repeat(WallpaperHistoryLedger.MAX_ENTRIES) { i ->
            history = WallpaperHistoryLedger.remember(history, "/img/$i.png", usedAt = i.toLong()).history
        }
        val result = WallpaperHistoryLedger.remember(history, "/img/new.png", usedAt = 99L)
        assertEquals(WallpaperHistoryLedger.MAX_ENTRIES, result.history.size)
        assertEquals("/img/new.png", result.history.first().key)
        assertEquals("/img/1.png", result.history.last().key)
        assertEquals(listOf("/img/0.png"), result.evictedPaths)
    }

    @Test
    fun `同 key 去重置顶并更新取景`() {
        val history = listOf(row("/a.png"), row("/b.png"))
        val result = WallpaperHistoryLedger.remember(
            history = history,
            key = "/b.png",
            alignX = 0.5,
            alignY = -0.3,
            scale = 2.0,
            usedAt = 7L,
        )
        assertEquals(listOf("/b.png", "/a.png"), result.history.map { it.key })
        assertEquals(0.5, result.history[0].alignX, 0.0)
        assertEquals(-0.3, result.history[0].alignY, 0.0)
        assertEquals(2.0, result.history[0].scale, 0.0)
        assertEquals(7L, result.history[0].usedAt)
        assertTrue(result.evictedPaths.isEmpty())
    }

    // -------------------------------------------------------- 当前这张补最前

    @Test
    fun `当前这张补在最前并带上当前取景`() {
        val visible = WallpaperHistoryLedger.visibleEntries(
            history = listOf(row("/old1.png"), row("/old2.png")),
            currentPath = "/now.png",
            currentFraming = WallpaperFraming(alignX = 0.25, alignY = -0.5, scale = 1.75),
        )
        assertEquals(listOf("/now.png", "/old1.png", "/old2.png"), visible.map { it.key })
        assertEquals(0.25, visible[0].alignX, 0.0)
        assertEquals(-0.5, visible[0].alignY, 0.0)
        assertEquals(1.75, visible[0].scale, 0.0)
    }

    @Test
    fun `历史里已有当前这张时不重复补`() {
        val visible = WallpaperHistoryLedger.visibleEntries(
            history = listOf(row("/now.png"), row("/old.png")),
            currentPath = "/now.png",
        )
        assertEquals(listOf("/now.png", "/old.png"), visible.map { it.key })
    }

    @Test
    fun `展示列表过滤空 key 与已下线的内置壁纸`() {
        val visible = WallpaperHistoryLedger.visibleEntries(
            history = listOf(
                row("   "),
                row("builtin:og"),
                row("/ok.png"),
            ),
            currentPath = null,
        )
        assertEquals(listOf("/ok.png"), visible.map { it.key })
    }

    @Test
    fun `展示列表允许比存储上限多一条`() {
        // 存储 10 条 + 当前这张不在历史里 = 11 条（Dart `_wallpaperHistory` 上限只管存储）
        val history = (0 until WallpaperHistoryLedger.MAX_ENTRIES).map { row("/img/$it.png") }
        val visible = WallpaperHistoryLedger.visibleEntries(history, "/now.png")
        assertEquals(WallpaperHistoryLedger.MAX_ENTRIES + 1, visible.size)
    }

    // ------------------------------------------------------ 切回连取景一起还原

    @Test
    fun `切回历史还原对齐与缩放三件`() {
        val entry = row("/clip.png", alignX = 0.4, alignY = -0.6, scale = 2.5)
        val framing = WallpaperHistoryLedger.framingOf(entry)
        assertEquals(0.4, framing.alignX, 0.0)
        assertEquals(-0.6, framing.alignY, 0.0)
        assertEquals(2.5, framing.scale, 0.0)
    }

    @Test
    fun `切回一条历史写路径三件取景并把旧新两张记进历史`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/new.png",
            homePageWallpaperAlignX = 0.1,
            homePageWallpaperAlignY = 0.2,
            homePageWallpaperScale = 3.0,
            wallpaperHistory = listOf(modelRow("/old1.png"), modelRow("/old2.png")),
        )
        val entry = row("/old2.png", alignX = 0.4, alignY = -0.6, scale = 2.5)
        val result = WallpaperHistoryLedger.applySelection(current, entry, usedAt = 42L)

        assertNotNull(result)
        val settings = result!!.settings
        assertEquals("/old2.png", settings.homePageWallpaperPath)
        // 三件一起还原：只还原位置不还原缩放，用户放大过的那张会静默缩回 1
        assertEquals(0.4, settings.homePageWallpaperAlignX, 0.0)
        assertEquals(-0.6, settings.homePageWallpaperAlignY, 0.0)
        assertEquals(2.5, settings.homePageWallpaperScale, 0.0)
        // 旧 → 新补记：刚被换下的 /new 在前，切回的 /old2 最终置顶
        assertEquals(
            listOf("/old2.png", "/new.png", "/old1.png"),
            settings.wallpaperHistory.map { it.key },
        )
        assertEquals(2.5, settings.wallpaperHistory.first().scale, 0.0)
    }

    @Test
    fun `切回已下线或空 key 的条目返回 null`() {
        val current = TimetableSettingsModel()
        assertNull(WallpaperHistoryLedger.applySelection(current, row("builtin:og")))
        assertNull(WallpaperHistoryLedger.applySelection(current, row(" ")))
    }

    // ---------------------------------------------------------- 删除与撤销

    @Test
    fun `正在用的那张不给删`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/a.png",
            wallpaperHistory = listOf(modelRow("/a.png"), modelRow("/b.png")),
        )
        assertNull(WallpaperHistoryLedger.remove(current, "/a.png"))
        assertEquals(2, current.wallpaperHistory.size)
    }

    @Test
    fun `确认删除摘掉条目并留下整份旧历史作撤销凭据`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/a.png",
            wallpaperHistory = listOf(modelRow("/a.png"), modelRow("/b.png"), modelRow("/c.png")),
        )
        val removal = WallpaperHistoryLedger.remove(current, "/b.png")
        assertNotNull(removal)
        assertEquals("/b.png", removal!!.removedPath)
        assertEquals(listOf("/a.png", "/c.png"), removal.settings.wallpaperHistory.map { it.key })
        assertEquals(
            listOf("/a.png", "/b.png", "/c.png"),
            removal.previousHistory.map { it.key },
        )
    }

    @Test
    fun `撤销把整份旧历史原样放回`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/a.png",
            wallpaperHistory = listOf(modelRow("/a.png"), modelRow("/c.png")),
        )
        val previous = listOf(
            modelRow("/a.png"),
            modelRow("/b.png"),
            modelRow("/c.png"),
        )
        val restored = WallpaperHistoryLedger.undo(current, previous)
        assertEquals(listOf("/a.png", "/b.png", "/c.png"), restored.wallpaperHistory.map { it.key })
        // 其余设置原样
        assertEquals("/a.png", restored.homePageWallpaperPath)
    }

    @Test
    fun `删除不存在的条目返回 null`() {
        val current = TimetableSettingsModel(wallpaperHistory = listOf(modelRow("/a.png")))
        assertNull(WallpaperHistoryLedger.remove(current, "/missing.png"))
    }

    // ---------------------------------------------------------- 三路白名单

    @Test
    fun `淘汰白名单是三路并集`() {
        val whitelist = WallpaperHistoryLedger.evictionWhitelist(
            allProfilesCurrentPaths = listOf("/profile1.png", null, "", "/shared.png"),
            draftPath = "/draft.png",
            galleryLedgerPaths = listOf("/gallery.png", "/shared.png", "  "),
        )
        assertEquals(
            setOf("/profile1.png", "/shared.png", "/draft.png", "/gallery.png"),
            whitelist.paths,
        )
        assertTrue(whitelist.profileReferencesKnown)
    }

    @Test
    fun `没拿到档案引用时白名单判定为未知且一律不可删`() {
        // 不传（null）/ 传空表 / 只传空白项：三种「没交代档案引用」的写法都必须退回 fail-safe
        for (profiles in listOf<Iterable<String?>?>(null, emptyList(), listOf(null, "", "  "))) {
            val whitelist = WallpaperHistoryLedger.evictionWhitelist(
                allProfilesCurrentPaths = profiles,
                draftPath = "/draft.png",
                galleryLedgerPaths = listOf("/gallery.png"),
            )
            assertFalse(whitelist.profileReferencesKnown)
            assertEquals(emptyList<String>(), WallpaperHistoryLedger.deletable(listOf("/garbage.png"), whitelist))
        }
    }

    @Test
    fun `删除清单豁免空串 内置壁纸键 与白名单里的图`() {
        val deletable = WallpaperHistoryLedger.deletable(
            evictedPaths = listOf("", "builtin:og", "/in-use.png", "/garbage.png"),
            whitelist = EvictionWhitelist(setOf("/in-use.png"), profileReferencesKnown = true),
        )
        assertEquals(listOf("/garbage.png"), deletable)
    }

    @Test
    fun `可移除判据只看是不是当前这张`() {
        assertTrue(WallpaperHistoryLedger.isRemovable("/b.png", "/a.png"))
        assertFalse(WallpaperHistoryLedger.isRemovable("/a.png", "/a.png"))
    }
}
