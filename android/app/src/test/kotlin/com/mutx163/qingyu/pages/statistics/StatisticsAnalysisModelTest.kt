package com.mutx163.qingyu.pages.statistics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 深度分析二级页模型层测试。
 *
 * 期望值**从 Dart 源手推**（`lib/screens/statistics_analysis_screen.dart`），不是从实现里抄：
 *
 * - `_moduleTitle` 的 switch（:70-77）→ 六个模块标题；
 * - `hasData = courses.isNotEmpty`（:33）→ 空态判据；
 * - `_buildModuleContent` 的六个分支（:80-166）→ 每模块摆哪几块、哪里插分段间距；
 * - `standalone: true` 只出现在 TIME_UTIL / VENUE 两处（:99、:103），
 *   TEACHER / RANKING / COMPARE 都不带这个参数 → 默认 false。
 *
 * 这几条正是「渲染层不再自己写 when 分支」之后唯一能钉住六模块覆盖的地方：
 * 漏掉一个分支，这里立刻红，而不是等到真机上点开发现是空白页。
 */
class StatisticsAnalysisModelTest {

    // ── 1. 标题：六个模块各对应一条 ARB ──

    @Test
    fun `六个模块标题与 Dart _moduleTitle 逐字一致`() {
        assertEquals("每周课时趋势", StatisticsAnalysisModel.title(StatisticsAnalysisModule.TREND))
        assertEquals("时间利用", StatisticsAnalysisModel.title(StatisticsAnalysisModule.TIME_UTIL))
        assertEquals("教室与教学楼", StatisticsAnalysisModel.title(StatisticsAnalysisModule.VENUE))
        assertEquals("教师课时排行", StatisticsAnalysisModel.title(StatisticsAnalysisModule.TEACHER))
        assertEquals("课程排行", StatisticsAnalysisModel.title(StatisticsAnalysisModule.RANKING))
        assertEquals("课表对比", StatisticsAnalysisModel.title(StatisticsAnalysisModule.COMPARE))
    }

    @Test
    fun `每个卡片角色都有对的卡内标题`() {
        // 原先渲染层只映射了 TEACHER / RANKING，其余全回落成「暂无课程数据」：
        // 趋势页、热力图页的数据卡片顶部会写错标题。
        val expected = mapOf(
            StatisticsAnalysisModel.AnalysisCardRole.TREND_CHART to "每周课时趋势",
            StatisticsAnalysisModel.AnalysisCardRole.HEATMAP to "学期热力图",
            StatisticsAnalysisModel.AnalysisCardRole.TIME_UTILIZATION to "时间利用",
            StatisticsAnalysisModel.AnalysisCardRole.VENUE to "教室与教学楼",
            StatisticsAnalysisModel.AnalysisCardRole.TEACHER to "教师课时排行",
            StatisticsAnalysisModel.AnalysisCardRole.RANKING to "课程排行",
            StatisticsAnalysisModel.AnalysisCardRole.PROFILE_COMPARE to "课表对比",
        )
        for ((role, title) in expected) {
            assertEquals("$role 的卡内标题", title, StatisticsAnalysisModel.cardTitle(role))
        }
    }

    // ── 2. 空态判据 ──

    @Test
    fun `没有课程时走空态`() {
        assertFalse(StatisticsAnalysisModel.hasData(0))
    }

    @Test
    fun `有一门课就走列表`() {
        assertTrue(StatisticsAnalysisModel.hasData(1))
        assertTrue(StatisticsAnalysisModel.hasData(57))
    }

    @Test
    fun `空态两行文案取自 ARB`() {
        assertEquals("暂无课程数据", StatisticsAnalysisModel.emptyTitle)
        assertEquals("添加课程后即可查看统计", StatisticsAnalysisModel.emptySubtitle)
    }

    // ── 3. 每模块摆哪几块（Dart _buildModuleContent） ──

    @Test
    fun `趋势模块是折线加间距加热力图三格`() {
        val cells = StatisticsAnalysisModel.cells(StatisticsAnalysisModule.TREND)
        assertEquals("趋势页应有 3 格", 3, cells.size)
        assertEquals(
            StatisticsAnalysisModel.AnalysisCell.Card(StatisticsAnalysisModel.AnalysisCardRole.TREND_CHART),
            cells[0],
        )
        assertEquals(StatisticsAnalysisModel.AnalysisCell.Gap, cells[1])
        assertEquals(
            StatisticsAnalysisModel.AnalysisCell.Card(StatisticsAnalysisModel.AnalysisCardRole.HEATMAP),
            cells[2],
        )
    }

    @Test
    fun `时间利用与教室两页是独立卡（standalone 为 true）`() {
        // Dart：TimeUtilizationCard(stats: ..., standalone: true)、VenueStatsCard(..., standalone: true)
        val timeUtil = StatisticsAnalysisModel.cells(StatisticsAnalysisModule.TIME_UTIL)
        assertEquals(1, timeUtil.size)
        assertEquals(
            StatisticsAnalysisModel.AnalysisCell.Card(
                StatisticsAnalysisModel.AnalysisCardRole.TIME_UTILIZATION,
                standalone = true,
            ),
            timeUtil[0],
        )

        val venue = StatisticsAnalysisModel.cells(StatisticsAnalysisModule.VENUE)
        assertEquals(1, venue.size)
        assertEquals(
            StatisticsAnalysisModel.AnalysisCell.Card(
                StatisticsAnalysisModel.AnalysisCardRole.VENUE,
                standalone = true,
            ),
            venue[0],
        )
    }

    @Test
    fun `教师与排行两页不是 standalone（Dart 没传这个参数）`() {
        val teacher = StatisticsAnalysisModel.cells(StatisticsAnalysisModule.TEACHER)
        assertEquals(
            StatisticsAnalysisModel.AnalysisCell.Card(
                StatisticsAnalysisModel.AnalysisCardRole.TEACHER,
                standalone = false,
            ),
            teacher.single(),
        )

        val ranking = StatisticsAnalysisModel.cells(StatisticsAnalysisModule.RANKING)
        assertEquals(
            StatisticsAnalysisModel.AnalysisCell.Card(
                StatisticsAnalysisModel.AnalysisCardRole.RANKING,
                standalone = false,
            ),
            ranking.single(),
        )
    }

    @Test
    fun `对比页只有一张对比卡`() {
        val cells = StatisticsAnalysisModel.cells(StatisticsAnalysisModule.COMPARE)
        assertEquals(1, cells.size)
        val card = cells.single() as StatisticsAnalysisModel.AnalysisCell.Card
        assertEquals(StatisticsAnalysisModel.AnalysisCardRole.PROFILE_COMPARE, card.role)
    }

    @Test
    fun `没有别的课表时对比卡仍渲染但标 standalone`() {
        // 入口是否显示由统计主页 analysisEntries(hasOtherProfiles) 决定；
        // 一旦进来了，卡片本身照渲染（Dart 里 entries 列表恒含当前课表一条）。
        val withOthers = StatisticsAnalysisModel.cells(StatisticsAnalysisModule.COMPARE, hasOtherProfiles = true)
        val withoutOthers = StatisticsAnalysisModel.cells(StatisticsAnalysisModule.COMPARE, hasOtherProfiles = false)
        assertEquals(
            StatisticsAnalysisModel.AnalysisCell.Card(
                StatisticsAnalysisModel.AnalysisCardRole.PROFILE_COMPARE,
                standalone = false,
            ),
            withOthers.single(),
        )
        assertEquals(
            StatisticsAnalysisModel.AnalysisCell.Card(
                StatisticsAnalysisModel.AnalysisCardRole.PROFILE_COMPARE,
                standalone = true,
            ),
            withoutOthers.single(),
        )
    }

    @Test
    fun `六个模块都有非空卡片清单（没有空白页）`() {
        for (module in StatisticsAnalysisModule.entries) {
            val cells = StatisticsAnalysisModel.cells(module)
            assertTrue("模块 $module 的卡片清单不该为空", cells.isNotEmpty())
            assertTrue(
                "模块 $module 至少要有一张卡（不能只有间距）",
                cells.any { it is StatisticsAnalysisModel.AnalysisCell.Card },
            )
        }
    }

    @Test
    fun `只有趋势页带分段间距`() {
        // Dart 里 HyperosSectionGap 只出现在 TREND 分支；其余四页是单卡、对比页也是单卡。
        for (module in StatisticsAnalysisModule.entries) {
            val gaps = StatisticsAnalysisModel.cells(module).count {
                it is StatisticsAnalysisModel.AnalysisCell.Gap
            }
            if (module == StatisticsAnalysisModule.TREND) {
                assertEquals("趋势页应有 1 个分段间距", 1, gaps)
            } else {
                assertEquals("模块 $module 不该有分段间距", 0, gaps)
            }
        }
    }
}
