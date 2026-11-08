package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 关于页静态区模型测试。
 *
 * 期望值来源（独立于实现）：
 * - 分组/顺序：逐行对照 `about_screen.dart:297 / 369 / 414` 三个分组的排列；
 * - 文案：直读 `i18n/app_zh.arb` 逐字对拍（不手抄）；
 * - 结构不变量：说明弹层只出现在该有的两行上（人推：Dart 只有两处 `_showInfoSheet`）。
 */
class AboutInfoModelTest {

    private fun arbString(key: String): String {
        val candidates = listOf(
            File("../../i18n/app_zh.arb"),
            File("../i18n/app_zh.arb"),
            File("i18n/app_zh.arb"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 i18n/app_zh.arb，工作目录=${File(".").absolutePath}")
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 $key")
    }

    // ---------- 分组与顺序 ----------

    @Test
    fun `三个分组按支持更新_产品_社区排列`() {
        val sections = aboutInfoSections()
        assertEquals(3, sections.size)
        assertEquals(AboutInfoStrings.supportUpdatesSectionTitle, sections[0].label)
        assertEquals(AboutInfoStrings.productSectionTitle, sections[1].label)
        assertEquals(AboutInfoStrings.communitySectionTitle, sections[2].label)
    }

    @Test
    fun `支持与更新组五行顺序固定`() {
        val kinds = aboutInfoSections()[0].entries.map { it.kind }
        assertEquals(
            listOf(
                AboutEntryKind.COFFEE,
                AboutEntryKind.FEEDBACK,
                AboutEntryKind.UPDATES,
                AboutEntryKind.CHANGELOG,
                AboutEntryKind.APP_LOGS,
            ),
            kinds,
        )
    }

    @Test
    fun `产品组两行与社区组三行顺序固定`() {
        assertEquals(
            listOf(AboutEntryKind.POSITIONING, AboutEntryKind.IMPORT_MIGRATION),
            aboutInfoSections()[1].entries.map { it.kind },
        )
        assertEquals(
            listOf(
                AboutEntryKind.CONTRIBUTORS,
                AboutEntryKind.REPOSITORY,
                AboutEntryKind.OPEN_SOURCE_LICENSES,
            ),
            aboutInfoSections()[2].entries.map { it.kind },
        )
    }

    // ---------- 结构不变量 ----------

    @Test
    fun `只有定位与导入迁移两行带说明弹层条目`() {
        val withBullets = aboutInfoSections()
            .flatMap { it.entries }
            .filter { it.bullets.isNotEmpty() }
            .map { it.kind }
        // Dart 里 _showInfoSheet 的调用点只有两处（:378 / :397）。
        assertEquals(listOf(AboutEntryKind.POSITIONING, AboutEntryKind.IMPORT_MIGRATION), withBullets)
    }

    @Test
    fun `两处说明弹层各四条`() {
        val entries = aboutInfoSections().flatMap { it.entries }
        val positioning = entries.first { it.kind == AboutEntryKind.POSITIONING }
        val importMigration = entries.first { it.kind == AboutEntryKind.IMPORT_MIGRATION }
        assertEquals(4, positioning.bullets.size)
        assertEquals(4, importMigration.bullets.size)
    }

    @Test
    fun `每行标题与副标题都非空`() {
        val entries = aboutInfoSections().flatMap { it.entries }
        assertEquals(10, entries.size)
        assertTrue(entries.all { it.title.isNotBlank() })
        assertTrue(entries.all { it.subtitle.isNotBlank() })
    }

    @Test
    fun `开源许可行与许可页文案同源`() {
        val entry = aboutInfoSections()[2].entries.first { it.kind == AboutEntryKind.OPEN_SOURCE_LICENSES }
        assertEquals(OpenSourceLicensesStrings.title, entry.title)
        assertEquals(OpenSourceLicensesStrings.subtitle, entry.subtitle)
    }

    @Test
    fun `请喝咖啡的副标题与支持作者页标题同源`() {
        val entry = aboutInfoSections()[0].entries.first { it.kind == AboutEntryKind.COFFEE }
        // Dart :304 —— 副标题直接用了 supportHeroTitle。
        assertEquals(SupportCreatorStrings.heroTitle, entry.subtitle)
        assertEquals(entry.subtitle, AboutInfoStrings.coffeeSubtitle)
    }

    // ---------- 文案与 ARB 对拍 ----------

    @Test
    fun `arbStringsMatchModel`() {
        val pairs = listOf(
            "aboutSupportUpdatesSectionTitle" to AboutInfoStrings.supportUpdatesSectionTitle,
            "homeMenuCoffeeTitle" to AboutInfoStrings.coffeeTitle,
            "supportHeroTitle" to AboutInfoStrings.coffeeSubtitle,
            "feedbackEntryTitle" to AboutInfoStrings.feedbackTitle,
            "feedbackEntrySubtitle" to AboutInfoStrings.feedbackSubtitle,
            "aboutUpdatesTitle" to AboutInfoStrings.updatesTitle,
            "aboutUpdatesSubtitle" to AboutInfoStrings.updatesSubtitle,
            "aboutChangelogTitle" to AboutInfoStrings.changelogTitle,
            "aboutChangelogSubtitle" to AboutInfoStrings.changelogSubtitle,
            "aboutAppLogsTitle" to AboutInfoStrings.appLogsTitle,
            "aboutAppLogsSubtitle" to AboutInfoStrings.appLogsSubtitle,
            "aboutProductSectionTitle" to AboutInfoStrings.productSectionTitle,
            "aboutPositioningTitle" to AboutInfoStrings.positioningTitle,
            "aboutPositioningSubtitle" to AboutInfoStrings.positioningSubtitle,
            "aboutImportMigrationTitle" to AboutInfoStrings.importMigrationTitle,
            "aboutImportMigrationSubtitle" to AboutInfoStrings.importMigrationSubtitle,
            "aboutCommunitySectionTitle" to AboutInfoStrings.communitySectionTitle,
            "aboutContributorsTitle" to AboutInfoStrings.contributorsTitle,
            "aboutContributorsSubtitle" to AboutInfoStrings.contributorsSubtitle,
            "aboutRepositoryTitle" to AboutInfoStrings.repositoryTitle,
            "aboutRepositorySubtitle" to AboutInfoStrings.repositorySubtitle,
            "thirdPartyDisclaimer" to AboutInfoStrings.thirdPartyDisclaimer,
        )
        for ((key, value) in pairs) {
            assertEquals("ARB 键 $key 与模型不一致", arbString(key), value)
        }
    }

    @Test
    fun `说明弹层条目逐条与ARB一致`() {
        val bulletKeys = listOf(
            "aboutPositioningBullet1",
            "aboutPositioningBullet2",
            "aboutPositioningBullet3",
            "aboutPositioningBullet4",
        )
        assertEquals(bulletKeys.map { arbString(it) }, AboutInfoStrings.positioningBullets)

        val importKeys = listOf(
            "aboutImportMigrationBullet1",
            "aboutImportMigrationBullet2",
            "aboutImportMigrationBullet3",
            "aboutImportMigrationBullet4",
        )
        assertEquals(importKeys.map { arbString(it) }, AboutInfoStrings.importMigrationBullets)
    }
}
