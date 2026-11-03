package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.pages.statistics.charts.ChartsStrings
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F12（半接收尾）· 统计页分享文本测试。
 *
 * ## 期望值来源（独立于实现）
 *
 * - Dart `statistics_share_service.dart:104-108`：分享 payload 的 subject 取
 *   `l10n.statisticsShareTitle`、text 取 `l10n.statisticsShareText`；
 * - ARB 直读对拍（`lib/l10n/app_zh.arb`），不手抄；
 * - 「无数据不许编数字」是清单 §一 1.2 的红线（假成功比没反应更糟），人推得出。
 */
class StatisticsShareTextTest {

    private fun metric(value: String, label: String) =
        StatisticsMetricView(value = value, label = label)

    private fun viewState(
        hasData: Boolean = true,
        semester: SemesterContent? = null,
        week: WeekContent? = null,
    ) = CourseStatisticsViewState(
        title = "统计",
        tabs = listOf("学期", "周"),
        selectedTabIndex = if (semester != null) 0 else 1,
        hasData = hasData,
        emptyTitle = "暂无数据",
        emptyHint = "先添加课程",
        showHeaderActions = hasData,
        analysisEntries = emptyList(),
        semester = semester,
        week = week,
        selectedWeek = 3,
        currentWeek = 3,
        semesterWeekCount = 20,
        widgetSnapshot = null,
    )

    private fun semesterContent(metrics: List<StatisticsMetricView>) = SemesterContent(
        overview = metrics,
        progress = SemesterProgressView(
            title = "学期进度",
            weekLabel = "第 3 周",
            rangeLabel = null,
            percent = 0.15,
            percentText = "15%",
            detailLabel = "已上 12 节",
            isBeforeStart = false,
            factLabel = null,
            remainingLabel = null,
        ),
        comparison = WeeklyComparisonView(
            title = "周对比",
            weekLabel = "第 3 周",
            weekSectionsValue = "12",
            weekSectionsLabel = "节",
            deltaValue = "+2",
            deltaLabel = "较上周",
            deltaTone = DeltaTone.UP,
            averageValue = "4",
            averageLabel = "日均",
            isFirstWeek = false,
            newSemesterHint = null,
        ),
        achievements = emptyList(),
        stories = emptyList(),
        dailyChart = null,
        nature = NatureRatioView(
            hasData = false,
            legend = emptyList(),
            missingLabel = null,
        ),
    )

    @Test
    fun `subject取ARB的statisticsShareTitle`() {
        val file = listOf(
            File("../lib/l10n/app_zh.arb"),
            File("../../lib/l10n/app_zh.arb"),
            File("lib/l10n/app_zh.arb"),
        ).firstOrNull { it.isFile } ?: error("找不到 app_zh.arb")
        @Suppress("UNCHECKED_CAST")
        val arb = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>

        assertEquals(arb["statisticsShareTitle"] as String, StatisticsShareText.subject())
        assertEquals(arb["statisticsShareText"] as String, ChartsStrings.statisticsShareText.zh)
    }

    @Test
    fun `学期视图_正文是标题加正文句加真指标`() {
        val state = viewState(
            semester = semesterContent(
                listOf(metric("12", "课程门数"), metric("40", "节课")),
            ),
        )

        val text = StatisticsShareText.build(state)
        val lines = text.split("\n")

        assertEquals(listOf("统计", ChartsStrings.statisticsShareText.zh, "课程门数：12", "节课：40"), lines)
    }

    @Test
    fun `周视图_周次与节数共用现成整句_不造新标签`() {
        val state = viewState(
            week = WeekContent(weekNumber = 3, courseCount = 5, sectionCount = 12, maxWeek = 20),
        )

        val lines = StatisticsShareText.build(state).split("\n")

        assertEquals("统计", lines[0])
        assertEquals(ChartsStrings.statisticsShareText.zh, lines[1])
        assertEquals("第 3 周 · 12 节", lines[2])
        assertEquals("${ChartsStrings.statisticsWeeklyCourses.zh}：5", lines[3])
    }

    @Test
    fun `无数据时只回两句_绝不编零门课`() {
        val state = viewState(hasData = false, semester = null, week = null)

        val lines = StatisticsShareText.build(state).split("\n")

        assertEquals(2, lines.size)
        assertFalse("无数据时不该出现任何指标数字", lines.any { it.contains("：") })
        assertTrue(StatisticsShareText.metricLines(state).isEmpty())
    }

    @Test
    fun `有数据但两个视图都为空_也只有两句`() {
        val state = viewState(semester = null, week = null)

        assertTrue(StatisticsShareText.metricLines(state).isEmpty())
        assertEquals(2, StatisticsShareText.build(state).split("\n").size)
    }

    @Test
    fun `学期视图优先_即使周视图也有数据`() {
        val state = viewState(
            semester = semesterContent(listOf(metric("7", "课程门数"))),
            week = WeekContent(weekNumber = 3, courseCount = 5, sectionCount = 12, maxWeek = 20),
        )

        assertEquals(listOf("课程门数：7"), StatisticsShareText.metricLines(state))
    }
}
