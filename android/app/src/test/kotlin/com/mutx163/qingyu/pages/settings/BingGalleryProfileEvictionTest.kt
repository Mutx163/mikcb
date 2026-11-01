package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 图库下载溢出回收的**跨档案**保护（F29）。
 *
 * ## 钉住的风险
 *
 * 「最近使用」只有 10 条，下新图会把最旧的一条挤出历史。溢出回收按白名单删文件；
 * 白名单若只含本份设置，而那张被挤出的图恰好是**另一个课表档案**正在用的壁纸，
 * 文件就被删了 —— 切到那个课表，首页当场裂图，且没有恢复入口。
 *
 * 白名单的第二层来自盘上 `timetable_profiles` 原始 JSON（[WallpaperEvictionSources]）。
 * 本测试同时钉住保守策略：档案读不懂 ⇒ 一张都不删。
 */
class BingGalleryProfileEvictionTest {

    /** 10 条历史会把最旧的一条挤出去（`/p/10.jpg`）。 */
    private fun fullHistory(): List<WallpaperHistoryRowModel> =
        (1..10).map { i -> WallpaperHistoryRowModel(key = "/p/$i.jpg", usedAt = i.toLong()) }

    private fun profilesJson(vararg settingsBlocks: String): String =
        settingsBlocks.mapIndexed { index, settings ->
            """{"id":"p$index","settings":$settings}"""
        }.joinToString(prefix = "[", postfix = "]")

    // ------------------------------------------------------------ 跨档案保护

    @Test
    fun `别的课表正在用的图不会被溢出回收删掉`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/p/1.jpg",
            wallpaperHistory = fullHistory(),
        )
        val outcome = BingGalleryApplyPlanner.settingsAfterApply(
            current = current,
            path = "/p/new.jpg",
            nowMs = 1000L,
            profilesJson = profilesJson(
                """{"homePageWallpaperPath":"/p/1.jpg"}""",
                """{"homePageWallpaperPath":"/p/10.jpg"}""",
            ),
        )
        // 旧口径（只看本份设置）会把 /p/10.jpg 当垃圾：这就是被修掉的误删场景
        assertFalse(
            BingGalleryApplyPlanner.deletionWhitelist(outcome.settings, keep = "/p/new.jpg")
                .contains("/p/10.jpg"),
        )
        // 新口径：另一份档案在用 ⇒ 文件必须留下
        assertFalse(outcome.profilesUnreadable)
        assertEquals(emptyList<String>(), outcome.filesToDelete)
    }

    @Test
    fun `旧版背景图字段也可能被别的课表在用`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/p/1.jpg",
            wallpaperHistory = fullHistory(),
        )
        val outcome = BingGalleryApplyPlanner.settingsAfterApply(
            current = current,
            path = "/p/new.jpg",
            profilesJson = profilesJson(
                """{"homePageWallpaperPath":"/p/1.jpg"}""",
                """{"homePageBackgroundImagePath":"/p/10.jpg"}""",
            ),
        )
        assertEquals(emptyList<String>(), outcome.filesToDelete)
    }

    @Test
    fun `读得懂档案时没人在用的淘汰图照常删`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/p/1.jpg",
            wallpaperHistory = fullHistory(),
        )
        val outcome = BingGalleryApplyPlanner.settingsAfterApply(
            current = current,
            path = "/p/new.jpg",
            profilesJson = profilesJson(
                """{"homePageWallpaperPath":"/p/1.jpg"}""",
                """{"homePageWallpaperPath":"/p/9.jpg"}""",
            ),
        )
        // /p/10.jpg 没有任何档案在用：回收照常（保护不能退化成「永远不删」）
        assertEquals(listOf("/p/10.jpg"), outcome.filesToDelete)
    }

    // ------------------------------------------------------------ 保守策略

    @Test
    fun `档案 JSON 读不懂时一张都不删`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/p/1.jpg",
            wallpaperHistory = fullHistory(),
        )
        val outcome = BingGalleryApplyPlanner.settingsAfterApply(
            current = current,
            path = "/p/new.jpg",
            profilesJson = """{"profiles":"broken"}""",
        )
        assertTrue(outcome.profilesUnreadable)
        assertEquals(emptyList<String>(), outcome.filesToDelete)
    }

    @Test
    fun `档案条目 settings 不是对象时也按读不懂处理`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/p/1.jpg",
            wallpaperHistory = fullHistory(),
        )
        val outcome = BingGalleryApplyPlanner.settingsAfterApply(
            current = current,
            path = "/p/new.jpg",
            profilesJson = """[{"id":"a","settings":"oops"}]""",
        )
        assertTrue(outcome.profilesUnreadable)
        assertEquals(emptyList<String>(), outcome.filesToDelete)
    }

    @Test
    fun `盘上没有档案 key 时维持原口径`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/p/1.jpg",
            wallpaperHistory = fullHistory(),
        )
        // null = 还没有多档案（没有东西可护），不是「读不到」
        val none = BingGalleryApplyPlanner.settingsAfterApply(
            current = current,
            path = "/p/new.jpg",
            profilesJson = null,
        )
        assertFalse(none.profilesUnreadable)
        assertEquals(listOf("/p/10.jpg"), none.filesToDelete)

        val empty = BingGalleryApplyPlanner.settingsAfterApply(
            current = current,
            path = "/p/new.jpg",
            profilesJson = "",
        )
        assertFalse(empty.profilesUnreadable)
        assertEquals(listOf("/p/10.jpg"), empty.filesToDelete)
    }

    @Test
    fun `同一张图被多份档案引用也只算一次保护`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/p/1.jpg",
            wallpaperHistory = fullHistory(),
        )
        val outcome = BingGalleryApplyPlanner.settingsAfterApply(
            current = current,
            path = "/p/new.jpg",
            profilesJson = profilesJson(
                """{"homePageWallpaperPath":"/p/10.jpg"}""",
                """{"homePageWallpaperPath":"/p/10.jpg"}""",
            ),
        )
        assertEquals(emptyList<String>(), outcome.filesToDelete)
    }
}
