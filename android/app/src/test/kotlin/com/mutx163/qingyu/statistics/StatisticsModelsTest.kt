package com.mutx163.qingyu.statistics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 统计模型移植测试（源：lib/models/statistics_models.dart、
 * lib/models/statistics_export_options.dart）。
 *
 * 期望值来源标注：
 * - 「Dart 测试抄录」= test/services/statistics_service_test.dart、
 *   test/models/statistics_export_options_test.dart 的既有用例；
 * - 「Dart 逐行」= 按 models 源码逐行推演；
 * - 「人推边界」= 独立推导。
 */
class StatisticsModelsTest {

    // ---------- CourseNatureStats（Dart 测试抄录 service_test:409-433） ----------

    @Test
    fun `nature stats ratio`() {
        val stats = CourseNatureStats(
            requiredCount = 3, electiveCount = 1,
            requiredSections = 6, electiveSections = 2,
        )
        assertEquals(4, stats.totalCount)
        assertEquals(8, stats.totalSections)
        assertEquals(0.75, stats.requiredRatio, 1e-9)
        assertEquals(0.25, stats.electiveRatio, 1e-9)
    }

    @Test
    fun `nature stats zero total gives zero ratio`() {
        val stats = CourseNatureStats(0, 0, 0, 0)
        assertEquals(0.0, stats.requiredRatio, 0.0)
        assertEquals(0.0, stats.electiveRatio, 0.0)
    }

    // ---------- Achievement.hasProgress（Dart 逐行 models:61-62 + 人推边界） ----------

    @Test
    fun `achievement hasProgress requires positive target`() {
        // 人推边界：hasProgress = current!=null && target!=null && target>0
        assertFalse(Achievement("a", null, false, null, null).hasProgress)
        assertFalse(Achievement("a", null, true, 86, null).hasProgress)
        assertFalse(Achievement("a", null, true, null, 100).hasProgress)
        // target=0 不算进度（除零防护，Dart 逐行）
        assertFalse(Achievement("a", null, false, 0, 0).hasProgress)
        // 已解锁仍保留进度值（models:43-44 注释语义）
        assertTrue(Achievement("a", null, true, 86, 100).hasProgress)
    }

    // ---------- SemesterProgress.percent（Dart 逐行 models:272） ----------

    @Test
    fun `progress percent`() {
        val p = SemesterProgress(
            semesterStartDate = null, currentDate = null, semesterEndDate = null,
            weeksElapsed = 10, totalWeeks = 16,
            sectionsDone = 20, sectionsTotal = 32,
            remainingSections = 12, phase = SemesterProgressPhase.ESTIMATED,
        )
        // Dart 测试抄录：20/32 = 62.5%
        assertEquals(0.625, p.percent, 1e-9)
        // 人推边界：total 为 0 → 0（models:272 三元守卫）
        assertEquals(
            0.0,
            SemesterProgress(null, null, null, 0, 0, 0, 0, 0, SemesterProgressPhase.ESTIMATED).percent,
            0.0,
        )
    }

    // ---------- SemesterHeatmap.clippedToWeek（Dart 测试抄录 service_test:638-651） ----------

    @Test
    fun `heatmap clippedToWeek zeroes future weeks`() {
        val heatmap = SemesterHeatmap(
            weekCount = 4,
            maxSections = 2,
            rows = List(7) { day -> List(4) { if (day == 0 && it < 2) 2 else 0 } },
        )
        val clipped = heatmap.clippedToWeek(2)
        assertEquals(2, clipped.rows[0][0])
        assertEquals(2, clipped.rows[0][1])
        assertEquals(0, clipped.rows[0][2])
        assertEquals(0, clipped.rows[0][3])
        assertEquals(2, clipped.maxSections)
        // 人推边界：原实例不被修改（Dart 返回新实例）
        assertEquals(0, heatmap.rows[0][2])
    }

    @Test
    fun `heatmap clippedToWeek recomputes max`() {
        // 人推边界：未来周是全表最大值时，裁剪后 max 必须跟着缩
        val rows = List(7) { day -> List(3) { week -> if (day == 3 && week == 2) 9 else 0 } }
        val clipped = SemesterHeatmap(3, 9, rows).clippedToWeek(2)
        assertEquals(0, clipped.maxSections)
    }

    // ---------- WeeklyStats.busiestDay（Dart 逐行 models:136-145，人推边界） ----------

    @Test
    fun `busiestDay picks first max among nonzero days`() {
        val stats = WeeklyStats(
            weekNumber = 1, totalCourses = 0, totalSections = 0,
            dailyStats = listOf(
                DailyStats(1, 2, 1), DailyStats(2, 4, 1), DailyStats(3, 4, 1),
                DailyStats(4, 0, 0), DailyStats(5, 1, 1), DailyStats(6, 0, 0), DailyStats(7, 0, 0),
            ),
            natureStats = CourseNatureStats(0, 0, 0, 0),
            courseStats = emptyList(),
        )
        // 并列最大取先出现者（Dart 逐行：严格大于才替换）
        assertEquals(2, stats.busiestDay)
    }

    @Test
    fun `busiestDay null when all days empty`() {
        val stats = WeeklyStats(
            weekNumber = 1, totalCourses = 0, totalSections = 0,
            dailyStats = List(7) { DailyStats(it + 1, 0, 0) },
            natureStats = CourseNatureStats(0, 0, 0, 0),
            courseStats = emptyList(),
        )
        assertNull(stats.busiestDay)
    }

    // ---------- isEmpty 派生（Dart 逐行 models:345、371） ----------

    @Test
    fun `time utilization and venue isEmpty`() {
        assertTrue(TimeUtilizationStats("", "", 0, 0, 0, 0, 0, 0).isEmpty)
        assertFalse(TimeUtilizationStats("08:00", "09:40", 1, 0, 0, 0, 0, 3).isEmpty)
        assertTrue(VenueStats(emptyList(), emptyList()).isEmpty)
        assertFalse(VenueStats(listOf(RoomVisitStat("A101", 3)), emptyList()).isEmpty)
        assertFalse(VenueStats(emptyList(), listOf(BuildingStat("教一", 12))).isEmpty)
    }

    // ---------- StatisticsExportOptions（Dart 测试抄录 export_options_test 全 4 例） ----------

    @Test
    fun `export defaults exclude ranking and include the rest`() {
        val options = StatisticsExportOptions.defaults()
        assertEquals(StatisticsExportOptions.defaultModules, options.modules)
        assertFalse(options.modules.contains(StatisticsExportModule.RANKING))
        assertTrue(options.modules.contains(StatisticsExportModule.OVERVIEW))
        assertTrue(options.hasModules)
    }

    @Test
    fun `export allModules contains every enum value`() {
        assertEquals(StatisticsExportModule.entries.toSet(), StatisticsExportOptions.allModules)
    }

    @Test
    fun `export hasModules false for empty selection`() {
        assertFalse(StatisticsExportOptions(emptySet()).hasModules)
    }

    @Test
    fun `export copyWith replaces modules set`() {
        val original = StatisticsExportOptions.defaults()
        val updated = original.copy(modules = setOf(StatisticsExportModule.RANKING))
        assertEquals(setOf(StatisticsExportModule.RANKING), updated.modules)
        assertTrue(original.modules != updated.modules)
    }

    // ---------- StatisticsExportBrand（Dart 测试抄录 export_options_test:38-45） ----------

    @Test
    fun `export brand urls`() {
        assertTrue(StatisticsExportBrand.WEBSITE_URL.contains("163366.xyz"))
        assertEquals("163366.xyz", StatisticsExportBrand.WEBSITE_DISPLAY)
        assertTrue(StatisticsExportBrand.GITHUB_URL.contains("Mutx163/mikcb"))
        assertEquals("github.com/Mutx163/mikcb", StatisticsExportBrand.GITHUB_DISPLAY)
    }

    // ---------- 枚举完整性（人推边界：迁移期钉住序列化可见的名字集合） ----------

    @Test
    fun `story type enum names`() {
        assertEquals(
            listOf("busiestDay", "lightestDay", "favoriteRoom", "buildingCount", "timeRange"),
            StoryType.entries.map { it.dartName },
        )
    }

    @Test
    fun `export module enum names`() {
        assertEquals(
            listOf(
                "overview", "achievements", "stories", "dailyDistribution",
                "natureRatio", "ranking",
            ),
            StatisticsExportModule.entries.map { it.dartName },
        )
    }

    @Test
    fun `semester progress phase enum names`() {
        assertEquals(
            listOf("beforeStart", "inProgress", "ended", "estimated"),
            SemesterProgressPhase.entries.map { it.dartName },
        )
    }
}
