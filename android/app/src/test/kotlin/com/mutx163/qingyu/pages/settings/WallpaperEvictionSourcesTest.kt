package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「其它档案在用图」白名单来源的纯契约。
 *
 * 钉四件事：
 * 1. 扫描覆盖**每一份**档案的壁纸（含旧版背景图字段兜底）；
 * 2. 白名单 = 所有档案 + 当前/草稿 + 图库台账，别的档案正在用的图**不会被删**；
 * 3. 档案 JSON 读不懂时**一张都不删**（保守策略，不能把「读不到」当「没人用」）；
 * 4. 咬合对照：只护当前课表的旧口径确实会误删，新口径必须拦住。
 */
class WallpaperEvictionSourcesTest {

    private fun profilesJson(vararg settingsBlocks: String): String =
        settingsBlocks.mapIndexed { index, settings ->
            """{"id":"p$index","settings":$settings}"""
        }.joinToString(prefix = "[", postfix = "]")

    // ------------------------------------------------------------ 档案扫描

    @Test
    fun `扫描所有档案的壁纸路径`() {
        val scan = WallpaperEvictionSources.scanProfileBackdrops(
            profilesJson(
                """{"homePageWallpaperPath":"/w/a.jpg"}""",
                """{"homePageWallpaperPath":"/w/b.jpg"}""",
            ),
        )
        assertTrue(scan.readable)
        assertEquals(listOf("/w/a.jpg", "/w/b.jpg"), scan.backdropPaths)
    }

    @Test
    fun `同一张图被多份档案引用时只保留一次`() {
        val scan = WallpaperEvictionSources.scanProfileBackdrops(
            profilesJson(
                """{"homePageWallpaperPath":"/w/shared.jpg"}""",
                """{"homePageWallpaperPath":"/w/shared.jpg"}""",
            ),
        )
        assertTrue(scan.readable)
        assertEquals(listOf("/w/shared.jpg"), scan.backdropPaths)
    }

    @Test
    fun `壁纸为空或缺失时回退旧版背景图字段`() {
        val scan = WallpaperEvictionSources.scanProfileBackdrops(
            profilesJson(
                """{"homePageBackgroundImagePath":"/w/legacy.jpg"}""",
                """{"homePageWallpaperPath":"","homePageBackgroundImagePath":"/w/blank-wall.jpg"}""",
                """{"homePageWallpaperPath":"/w/new.jpg","homePageBackgroundImagePath":"/w/stale-old.jpg"}""",
            ),
        )
        assertTrue(scan.readable)
        // 第三份：壁纸优先，旧字段只是兜底，不重复进白名单
        assertEquals(
            listOf("/w/legacy.jpg", "/w/blank-wall.jpg", "/w/new.jpg"),
            scan.backdropPaths,
        )
    }

    @Test
    fun `空值 内置壁纸键 与坏条目不进入白名单`() {
        val scan = WallpaperEvictionSources.scanProfileBackdrops(
            """
            [
              {"id":"a","settings":{"homePageWallpaperPath":"   "}},
              {"id":"b","settings":{"homePageWallpaperPath":"builtin:og"}},
              {"id":"c","settings":{"homePageWallpaperPath":123}},
              {"id":"d","settings":{}},
              {"id":"e"},
              "junk"
            ]
            """.trimIndent(),
        )
        assertTrue(scan.readable)
        assertTrue(scan.backdropPaths.isEmpty())
    }

    @Test
    fun `还没有档案时是空集而不是不可读`() {
        val noKey = WallpaperEvictionSources.scanProfileBackdrops(null as String?)
        assertTrue(noKey.readable)
        assertTrue(noKey.backdropPaths.isEmpty())
        val emptyKey = WallpaperEvictionSources.scanProfileBackdrops("")
        assertTrue(emptyKey.readable)
        assertTrue(emptyKey.backdropPaths.isEmpty())
    }

    // ------------------------------------------------------------ 不可读判定

    @Test
    fun `档案 JSON 不是数组或解析失败时判为不可读`() {
        assertFalse(WallpaperEvictionSources.scanProfileBackdrops("not json").readable)
        assertFalse(WallpaperEvictionSources.scanProfileBackdrops("""{"a":1}""").readable)
        assertFalse(WallpaperEvictionSources.scanProfileBackdrops("""42""").readable)
    }

    @Test
    fun `某份档案的 settings 类型不对时判为不可读`() {
        val scan = WallpaperEvictionSources.scanProfileBackdrops(
            """[{"id":"a","settings":"broken"},{"id":"b","settings":{"homePageWallpaperPath":"/w/b.jpg"}}]""",
        )
        assertFalse(scan.readable)
        // 读得懂的那份仍被收下，但不能用于「确认没人在用」
        assertEquals(listOf("/w/b.jpg"), scan.backdropPaths)
    }

    // ------------------------------------------------------------ 删除判定

    @Test
    fun `其它档案正在用的图不会被删`() {
        val plan = WallpaperEvictionSources.planEviction(
            evictedPaths = listOf("/w/a.jpg", "/w/b.jpg", "/w/orphan.jpg"),
            profilesJson = profilesJson(
                """{"homePageWallpaperPath":"/w/a.jpg"}""",
                """{"homePageWallpaperPath":"/w/b.jpg"}""",
            ),
            currentPath = "/w/a.jpg",
            draftPath = "/w/a.jpg",
        )
        assertFalse(plan.profilesUnreadable)
        // /w/b.jpg 属于另一份档案：即使被历史淘汰 / 手动移除，也不许删文件
        assertEquals(listOf("/w/orphan.jpg"), plan.deletable)
    }

    @Test
    fun `草稿与图库台账也在白名单里`() {
        val plan = WallpaperEvictionSources.planEviction(
            evictedPaths = listOf(
                "/w/profile.jpg",
                "/w/draft.jpg",
                "/w/gallery.jpg",
                "/w/garbage.jpg",
            ),
            profilesJson = profilesJson("""{"homePageWallpaperPath":"/w/profile.jpg"}"""),
            currentPath = "/w/current.jpg",
            draftPath = "/w/draft.jpg",
            galleryLedgerPaths = listOf("/w/gallery.jpg"),
        )
        assertFalse(plan.profilesUnreadable)
        assertEquals(listOf("/w/garbage.jpg"), plan.deletable)
    }

    @Test
    fun `档案读不懂时一张都不删`() {
        val plan = WallpaperEvictionSources.planEviction(
            evictedPaths = listOf("/w/orphan.jpg"),
            profilesJson = """{"profiles":"broken"}""",
            currentPath = "/w/a.jpg",
            draftPath = "/w/a.jpg",
        )
        assertTrue(plan.profilesUnreadable)
        assertTrue(plan.deletable.isEmpty())
    }

    // ------------------------------------------------------------ 咬合对照

    @Test
    fun `咬合对照 旧口径只护当前课表确实会误删`() {
        // 旧口径（本批之前）：白名单里只有当前课表
        val oldWhitelist = WallpaperHistoryLedger.evictionWhitelist(
            allProfilesCurrentPaths = listOf("/w/a.jpg"),
            draftPath = "/w/a.jpg",
        )
        assertEquals(
            listOf("/w/b.jpg"),
            WallpaperHistoryLedger.deletable(listOf("/w/b.jpg"), oldWhitelist),
        )

        // 新口径：另一份档案正在用的 /w/b.jpg 必须被拦住
        val plan = WallpaperEvictionSources.planEviction(
            evictedPaths = listOf("/w/b.jpg"),
            profilesJson = profilesJson(
                """{"homePageWallpaperPath":"/w/a.jpg"}""",
                """{"homePageWallpaperPath":"/w/b.jpg"}""",
            ),
            currentPath = "/w/a.jpg",
            draftPath = "/w/a.jpg",
        )
        assertTrue(plan.deletable.isEmpty())
    }
}
