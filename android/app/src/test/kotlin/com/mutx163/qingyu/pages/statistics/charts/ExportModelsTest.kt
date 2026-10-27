package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.statistics.CourseSemesterStat
import com.mutx163.qingyu.statistics.CourseSlot
import com.mutx163.qingyu.statistics.StatisticsExportModule
import com.mutx163.qingyu.statistics.StatisticsExportOptions
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导出四件套的纯逻辑。
 *
 * 期望值全部按 Dart 源码手推（`statistics_export_document.dart` /
 * `statistics_export_sheet.dart` / `statistics_export_brand_footer.dart` /
 * `statistics_export_course_ranking.dart`），**不是**从 Kotlin 实现里反抄的。
 */
class ExportDocumentModelTest {

    private fun options(vararg modules: StatisticsExportModule) =
        StatisticsExportOptions(modules = modules.toSet())

    private fun kinds(sections: List<ExportSection>) = sections.map { it.kind }

    @Test
    fun `默认勾选导出五段且排行不在其中`() {
        val sections = ExportDocumentModel.sections(
            options = StatisticsExportOptions.defaults(),
            achievementCount = 12,
            storyCount = 5,
        )
        assertEquals(
            listOf(
                ExportSectionKind.OVERVIEW,
                ExportSectionKind.ACHIEVEMENTS,
                ExportSectionKind.STORIES,
                ExportSectionKind.DAILY_DISTRIBUTION,
                ExportSectionKind.NATURE_RATIO,
            ),
            kinds(sections),
        )
    }

    @Test
    fun `全选时排行排在最后一段`() {
        val sections = ExportDocumentModel.sections(
            options = options(*StatisticsExportModule.entries.toTypedArray()),
            achievementCount = 3,
            storyCount = 2,
        )
        assertEquals(6, sections.size)
        assertEquals(ExportSectionKind.RANKING, sections.last().kind)
    }

    @Test
    fun `成就和故事没有数据时即使勾了也不出现`() {
        val sections = ExportDocumentModel.sections(
            options = options(
                StatisticsExportModule.ACHIEVEMENTS,
                StatisticsExportModule.STORIES,
            ),
            achievementCount = 0,
            storyCount = 0,
        )
        assertEquals(emptyList<ExportSection>(), sections)
    }

    @Test
    fun `总览不看课程数 没课时开关照样保留`() {
        val sections = ExportDocumentModel.sections(
            options = options(StatisticsExportModule.OVERVIEW),
            achievementCount = 0,
            storyCount = 0,
        )
        assertEquals(listOf(ExportSectionKind.OVERVIEW), kinds(sections))
    }

    @Test
    fun `总览段不套块标题 其余四段各用自己的标题`() {
        val sections = ExportDocumentModel.sections(
            options = StatisticsExportOptions.defaults(),
            achievementCount = 1,
            storyCount = 1,
        )
        assertEquals("", sections.first { it.kind == ExportSectionKind.OVERVIEW }.title)
        assertEquals(
            "成就徽章",
            sections.first { it.kind == ExportSectionKind.ACHIEVEMENTS }.title,
        )
        assertEquals("数据故事", sections.first { it.kind == ExportSectionKind.STORIES }.title)
        assertEquals(
            "每日课时分布",
            sections.first { it.kind == ExportSectionKind.DAILY_DISTRIBUTION }.title,
        )
        assertEquals(
            "必修 / 选修",
            sections.first { it.kind == ExportSectionKind.NATURE_RATIO }.title,
        )
        val withRanking = ExportDocumentModel.sections(
            options = StatisticsExportOptions(
                modules = StatisticsExportOptions.defaultModules +
                    StatisticsExportModule.RANKING,
            ),
            achievementCount = 1,
            storyCount = 1,
        )
        assertEquals(
            "课程排行",
            withRanking.first { it.kind == ExportSectionKind.RANKING }.title,
        )
    }

    @Test
    fun `段落顺序与弹层勾选顺序无关 只看固定次序`() {
        val sections = ExportDocumentModel.sections(
            options = options(
                StatisticsExportModule.NATURE_RATIO,
                StatisticsExportModule.OVERVIEW,
                StatisticsExportModule.RANKING,
            ),
            achievementCount = 0,
            storyCount = 0,
        )
        assertEquals(
            listOf(
                ExportSectionKind.OVERVIEW,
                ExportSectionKind.NATURE_RATIO,
                ExportSectionKind.RANKING,
            ),
            kinds(sections),
        )
    }

    @Test
    fun `文档标题与段间距照抄 Dart`() {
        assertEquals("我的学期统计", ExportDocumentModel.title)
        assertEquals(12, ExportDocumentModel.SECTION_GAP_DP)
        assertEquals(16, ExportDocumentModel.PADDING_START_DP)
        assertEquals(20, ExportDocumentModel.PADDING_BOTTOM_DP)
        assertEquals(10, ExportDocumentModel.BRAND_TO_TITLE_GAP_DP)
    }
}

class ExportSheetModelTest {

    @Test
    fun `有成就和故事时六个模块全列 顺序固定`() {
        assertEquals(
            listOf(
                StatisticsExportModule.OVERVIEW,
                StatisticsExportModule.ACHIEVEMENTS,
                StatisticsExportModule.STORIES,
                StatisticsExportModule.DAILY_DISTRIBUTION,
                StatisticsExportModule.NATURE_RATIO,
                StatisticsExportModule.RANKING,
            ),
            ExportSheetModel.availableModules(hasAchievements = true, hasStories = true),
        )
    }

    @Test
    fun `没有成就和故事时这两项连勾选框都不出现`() {
        assertEquals(
            listOf(
                StatisticsExportModule.OVERVIEW,
                StatisticsExportModule.DAILY_DISTRIBUTION,
                StatisticsExportModule.NATURE_RATIO,
                StatisticsExportModule.RANKING,
            ),
            ExportSheetModel.availableModules(hasAchievements = false, hasStories = false),
        )
    }

    @Test
    fun `初始勾选等于默认值再去掉没有数据的模块`() {
        assertEquals(
            StatisticsExportOptions.defaultModules,
            ExportSheetModel.initialSelection(hasAchievements = true, hasStories = true),
        )
        assertEquals(
            setOf(
                StatisticsExportModule.OVERVIEW,
                StatisticsExportModule.DAILY_DISTRIBUTION,
                StatisticsExportModule.NATURE_RATIO,
            ),
            ExportSheetModel.initialSelection(hasAchievements = false, hasStories = false),
        )
    }

    @Test
    fun `勾上排行后初始勾选仍然不含它 除非用户自己点`() {
        val initial = ExportSheetModel.initialSelection(hasAchievements = true, hasStories = true)
        assertFalse(StatisticsExportModule.RANKING in initial)
        val after = ExportSheetModel.toggle(initial, StatisticsExportModule.RANKING, true)
        assertTrue(StatisticsExportModule.RANKING in after)
        // 原集合不变（Dart 每次都新建一个 Set）
        assertFalse(StatisticsExportModule.RANKING in initial)
    }

    @Test
    fun `取消勾选把模块摘掉 重复取消不报错`() {
        val start = StatisticsExportOptions.defaultModules
        val once = ExportSheetModel.toggle(start, StatisticsExportModule.STORIES, false)
        assertFalse(StatisticsExportModule.STORIES in once)
        val twice = ExportSheetModel.toggle(once, StatisticsExportModule.STORIES, false)
        assertEquals(once, twice)
    }

    @Test
    fun `一个都没勾时不给导出 只弹提示`() {
        val empty = emptySet<StatisticsExportModule>()
        assertEquals("请至少选择一个模块", ExportSheetModel.submitHintOrNull(empty))
        assertNull(ExportSheetModel.submit(empty))
        assertNull(ExportSheetModel.submitHintOrNull(setOf(StatisticsExportModule.OVERVIEW)))
        assertNotNull(ExportSheetModel.submit(setOf(StatisticsExportModule.OVERVIEW)))
    }

    @Test
    fun `模块名与弹层文案逐字对齐 ARB`() {
        assertEquals("学期总览", ExportSheetModel.moduleTitle(StatisticsExportModule.OVERVIEW))
        assertEquals("成就徽章", ExportSheetModel.moduleTitle(StatisticsExportModule.ACHIEVEMENTS))
        assertEquals("数据故事", ExportSheetModel.moduleTitle(StatisticsExportModule.STORIES))
        assertEquals(
            "每日课时分布",
            ExportSheetModel.moduleTitle(StatisticsExportModule.DAILY_DISTRIBUTION),
        )
        assertEquals("必修 / 选修", ExportSheetModel.moduleTitle(StatisticsExportModule.NATURE_RATIO))
        assertEquals("课程排行", ExportSheetModel.moduleTitle(StatisticsExportModule.RANKING))
        assertEquals("导出统计", ExportSheetModel.sheetTitle)
        assertEquals("包含模块", ExportSheetModel.modulesSectionLabel)
        assertEquals("开始导出", ExportSheetModel.actionLabel)
    }
}

class ExportBrandModelTest {

    @Test
    fun `文字块高度是标题加两行说明再加两个空隙`() {
        // 17 × 1.1 = 18.7，13 × 1.15 = 14.95
        // 18.7 + 1 + 14.95 + 2 + 14.95 = 51.6
        assertEquals(51.6f, ExportBrandModel.textBlockHeight(), 0.001f)
        assertEquals(18.7f, ExportBrandModel.titleLineHeight(), 0.001f)
        assertEquals(14.95f, ExportBrandModel.detailLineHeight(), 0.001f)
    }

    @Test
    fun `二维码边长跟着文字块走 但夹在48到72之间`() {
        assertEquals(51.6f, ExportBrandModel.qrSize(51.6f), 0.001f)
        assertEquals(48f, ExportBrandModel.qrSize(20f), 0.001f)
        assertEquals(48f, ExportBrandModel.qrSize(48f), 0.001f)
        assertEquals(72f, ExportBrandModel.qrSize(72f), 0.001f)
        assertEquals(72f, ExportBrandModel.qrSize(200f), 0.001f)
    }

    @Test
    fun `字号缺失时用17和13兜底`() {
        assertEquals(18.7f, ExportBrandModel.titleLineHeight(null, null), 0.001f)
        assertEquals(20f * 1.4f, ExportBrandModel.titleLineHeight(20f, 1.4f), 0.001f)
        assertEquals(16f * 1.5f, ExportBrandModel.detailLineHeight(16f, 1.5f), 0.001f)
    }

    @Test
    fun `品牌条文案与网址照抄`() {
        assertEquals("轻屿课表", ExportBrandModel.appName)
        assertEquals("把课程信息做成系统体验", ExportBrandModel.tagline)
        assertEquals("163366.xyz", ExportBrandModel.websiteDisplay)
        assertEquals("https://163366.xyz/", ExportBrandModel.websiteUrl)
        assertEquals(40, ExportBrandModel.LOGO_SIZE_DP)
        assertEquals(11, ExportBrandModel.LOGO_RADIUS_DP)
    }
}

class ExportRankingModelTest {

    private fun stat(name: String, sections: Int, slots: List<CourseSlot>) = CourseSemesterStat(
        name = name,
        teacher = "张老师",
        nature = CourseNature.REQUIRED,
        totalSections = sections,
        slots = slots,
    )

    private fun slot(day: Int, start: Int, end: Int) =
        CourseSlot(dayOfWeek = day, startSection = start, endSection = end, location = "A101")

    @Test
    fun `最多画20门 超出的门数走未展示提示`() {
        val ranking = (1..25).map { stat("课程$it", it, emptyList()) }
        val visible = ExportRankingModel.visible(ranking)
        assertEquals(20, visible.size)
        assertEquals("课程1", visible.first().name)
        assertEquals("课程20", visible.last().name)
        assertEquals(5, ExportRankingModel.remaining(ranking.size, visible.size))
        assertEquals(
            "另有 5 门课程未展示",
            ExportRankingModel.remainingLabel(ranking.size, visible.size),
        )
    }

    @Test
    fun `正好20门时不显示未展示提示`() {
        val ranking = (1..20).map { stat("课程$it", it, emptyList()) }
        assertEquals(20, ExportRankingModel.visible(ranking).size)
        assertNull(ExportRankingModel.remainingLabel(20, 20))
        assertEquals(0, ExportRankingModel.remaining(20, 20))
    }

    @Test
    fun `节次区间单节只写一个数字 用半角连字符`() {
        assertEquals("3", ExportRankingModel.sectionRange(3, 3))
        assertEquals("1-2", ExportRankingModel.sectionRange(1, 2))
        assertEquals("5-6", ExportRankingModel.sectionRange(5, 6))
    }

    @Test
    fun `时间摘要最多三段 多了补省略号`() {
        val three = listOf(slot(1, 1, 2), slot(3, 3, 3), slot(4, 5, 6))
        assertEquals("一 1-2节 · 三 3节 · 四 5-6节", ExportRankingModel.scheduleSummary(three))
        val four = three + slot(5, 7, 8)
        assertEquals(
            "一 1-2节 · 三 3节 · 四 5-6节 · …",
            ExportRankingModel.scheduleSummary(four),
        )
        assertEquals("", ExportRankingModel.scheduleSummary(emptyList()))
    }

    @Test
    fun `星期越界直接显示数字 不吞成空串`() {
        assertEquals("一", ExportRankingModel.weekdayShortLabel(1))
        assertEquals("日", ExportRankingModel.weekdayShortLabel(7))
        assertEquals("0", ExportRankingModel.weekdayShortLabel(0))
        assertEquals("8", ExportRankingModel.weekdayShortLabel(8))
    }

    @Test
    fun `前三名是奖杯 第四名起是数字`() {
        assertTrue(ExportRankingModel.showsTrophy(1))
        assertTrue(ExportRankingModel.showsTrophy(3))
        assertFalse(ExportRankingModel.showsTrophy(4))
        assertFalse(ExportRankingModel.showsTrophy(0))
        assertEquals("4", ExportRankingModel.badgeText(4))
        assertNull(ExportRankingModel.badgeText(1))
        assertEquals(ExportRankTone.GOLD, ExportRankingModel.rankTone(1))
        assertEquals(ExportRankTone.SILVER, ExportRankingModel.rankTone(2))
        assertEquals(ExportRankTone.ORANGE, ExportRankingModel.rankTone(3))
        assertEquals(ExportRankTone.PLAIN, ExportRankingModel.rankTone(4))
        assertEquals(0.18f, ExportRankingModel.badgeAlpha(1), 0.0001f)
        assertEquals(0.14f, ExportRankingModel.badgeAlpha(2), 0.0001f)
        assertEquals(0.16f, ExportRankingModel.badgeAlpha(3), 0.0001f)
        assertEquals(0.10f, ExportRankingModel.badgeAlpha(4), 0.0001f)
    }

    @Test
    fun `空态与单位文案照抄`() {
        assertEquals("暂无课程数据", ExportRankingModel.emptyMessage)
        assertEquals("节", ExportRankingModel.sectionUnit)
        assertEquals("必修", ExportRankingModel.natureLabel(true))
        assertEquals("选修", ExportRankingModel.natureLabel(false))
        assertEquals(36, ExportRankingModel.BADGE_SIZE_DP)
        assertEquals(10, ExportRankingModel.BADGE_RADIUS_DP)
    }
}
