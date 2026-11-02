package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「删档案后回收独占用图」的纯契约（触发点在
 * `pages/timetable/TimetableProfilesController.deleteProfile`）。
 *
 * 钉四件事：
 * 1. 被删档案**独占**的那张图，删除后不再被任何来源引用 ⇒ 可删；
 * 2. 仍被另一份档案（含旧版 `homePageBackgroundImagePath` 兜底字段）引用的图 ⇒ 不可删；
 * 3. 任一引用来源读不到 / 读不懂 ⇒ [WallpaperEvictionSources.ProfileReclaimPlan.referencesKnown]
 *    为 false 且一张都不删（宁可留图，不误删）；
 * 4. 被删档案本来就没壁纸 ⇒ 无候选，也不算「引用未知」。
 */
class WallpaperProfileReclaimTest {

    private fun profile(id: String, settings: String): String =
        """{"id":"$id","settings":$settings}"""

    private fun profilesJson(vararg profiles: String): String =
        profiles.joinToString(prefix = "[", postfix = "]")

    private fun settingsOf(backdrop: String?): String =
        if (backdrop == null) "{}" else """{"homePageWallpaperPath":"$backdrop"}"""

    private fun ledgerOf(vararg paths: String): String =
        paths.joinToString(prefix = "[", postfix = "]") { path ->
            """{"dateKey":"20261031","path":"$path"}"""
        }

    // ------------------------------------------------------------ 回收边界

    @Test
    fun `删掉档案后 只被它用过的图可删`() {
        val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
            deletedProfileId = "a",
            profilesJsonBefore = profilesJson(
                profile("a", settingsOf("/w/exclusive.jpg")),
                profile("b", settingsOf("/w/keep.jpg")),
            ),
            profilesJsonAfter = profilesJson(profile("b", settingsOf("/w/keep.jpg"))),
            settingsJson = "{}",
            ledgerJson = "[]",
        )
        assertTrue(plan.referencesKnown)
        assertEquals(listOf("/w/exclusive.jpg"), plan.candidatePaths)
        assertEquals(listOf("/w/exclusive.jpg"), plan.deletablePaths)
    }

    @Test
    fun `仍被另一份档案引用的图不可删`() {
        val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
            deletedProfileId = "a",
            profilesJsonBefore = profilesJson(
                profile("a", settingsOf("/w/shared.jpg")),
                profile("b", settingsOf("/w/shared.jpg")),
            ),
            profilesJsonAfter = profilesJson(profile("b", settingsOf("/w/shared.jpg"))),
            settingsJson = "{}",
            ledgerJson = "[]",
        )
        assertTrue(plan.referencesKnown)
        assertEquals(listOf("/w/shared.jpg"), plan.candidatePaths)
        assertEquals(emptyList<String>(), plan.deletablePaths)
    }

    @Test
    fun `另一份档案只用旧版背景图兜底字段也算引用`() {
        val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
            deletedProfileId = "a",
            profilesJsonBefore = profilesJson(
                profile("a", settingsOf("/w/shared.jpg")),
                profile("b", """{"homePageBackgroundImagePath":"/w/shared.jpg"}"""),
            ),
            profilesJsonAfter = profilesJson(
                profile("b", """{"homePageBackgroundImagePath":"/w/shared.jpg"}"""),
            ),
            settingsJson = "{}",
            ledgerJson = "[]",
        )
        assertTrue(plan.referencesKnown)
        assertEquals(emptyList<String>(), plan.deletablePaths)
    }

    @Test
    fun `当前设置里的背景图也护住回收候选`() {
        val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
            deletedProfileId = "a",
            profilesJsonBefore = profilesJson(
                profile("a", settingsOf("/w/candidate.jpg")),
                profile("b", settingsOf("/w/keep.jpg")),
            ),
            profilesJsonAfter = profilesJson(profile("b", settingsOf("/w/keep.jpg"))),
            // 顶层设置还没有合并进档案（刚切过壁纸、防抖写盘未落地）
            settingsJson = """{"homePageWallpaperPath":"/w/candidate.jpg"}""",
            ledgerJson = "[]",
        )
        assertTrue(plan.referencesKnown)
        assertEquals(emptyList<String>(), plan.deletablePaths)
    }

    @Test
    fun `图库台账里还记着的图不删`() {
        val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
            deletedProfileId = "a",
            profilesJsonBefore = profilesJson(
                profile("a", settingsOf("/w/cached.jpg")),
                profile("b", settingsOf("/w/keep.jpg")),
            ),
            profilesJsonAfter = profilesJson(profile("b", settingsOf("/w/keep.jpg"))),
            settingsJson = "{}",
            ledgerJson = ledgerOf("/w/cached.jpg"),
        )
        assertTrue(plan.referencesKnown)
        assertEquals(emptyList<String>(), plan.deletablePaths)
    }

    @Test
    fun `被删档案没有壁纸时无候选`() {
        val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
            deletedProfileId = "a",
            profilesJsonBefore = profilesJson(
                profile("a", "{}"),
                profile("b", settingsOf("/w/keep.jpg")),
            ),
            profilesJsonAfter = profilesJson(profile("b", settingsOf("/w/keep.jpg"))),
            settingsJson = "{}",
            ledgerJson = "[]",
        )
        assertTrue(plan.referencesKnown)
        assertTrue(plan.candidatePaths.isEmpty())
        assertTrue(plan.deletablePaths.isEmpty())
    }

    // ------------------------------------------------------------ fail-safe

    @Test
    fun `删除前的档案 JSON 读不懂时不删`() {
        val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
            deletedProfileId = "a",
            profilesJsonBefore = """{"profiles":"broken"}""",
            profilesJsonAfter = "[]",
            settingsJson = "{}",
            ledgerJson = "[]",
        )
        assertFalse(plan.referencesKnown)
        assertTrue(plan.deletablePaths.isEmpty())
    }

    @Test
    fun `删除后的档案 JSON 读不懂时不删`() {
        val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
            deletedProfileId = "a",
            profilesJsonBefore = profilesJson(
                profile("a", settingsOf("/w/exclusive.jpg")),
                profile("b", settingsOf("/w/keep.jpg")),
            ),
            profilesJsonAfter = """[{"id":"b","settings":"oops"}]""",
            settingsJson = "{}",
            ledgerJson = "[]",
        )
        assertFalse(plan.referencesKnown)
        assertEquals(listOf("/w/exclusive.jpg"), plan.candidatePaths)
        assertTrue(plan.deletablePaths.isEmpty())
    }

    @Test
    fun `设置 JSON 读不懂时不删`() {
        for (broken in listOf("not json", "42")) {
            val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
                deletedProfileId = "a",
                profilesJsonBefore = profilesJson(
                    profile("a", settingsOf("/w/exclusive.jpg")),
                    profile("b", settingsOf("/w/keep.jpg")),
                ),
                profilesJsonAfter = profilesJson(profile("b", settingsOf("/w/keep.jpg"))),
                settingsJson = broken,
                ledgerJson = "[]",
            )
            assertFalse("设置 JSON=$broken 时应判为引用未知", plan.referencesKnown)
            assertTrue(plan.deletablePaths.isEmpty())
        }
    }

    @Test
    fun `台账读不懂时不删`() {
        for (broken in listOf("not json", """{"a":1}""", """[{"path":123}]""")) {
            val plan = WallpaperEvictionSources.planProfileDeletionReclaim(
                deletedProfileId = "a",
                profilesJsonBefore = profilesJson(
                    profile("a", settingsOf("/w/exclusive.jpg")),
                    profile("b", settingsOf("/w/keep.jpg")),
                ),
                profilesJsonAfter = profilesJson(profile("b", settingsOf("/w/keep.jpg"))),
                settingsJson = "{}",
                ledgerJson = broken,
            )
            assertFalse("台账 JSON=$broken 时应判为引用未知", plan.referencesKnown)
            assertTrue(plan.deletablePaths.isEmpty())
        }
    }
}
