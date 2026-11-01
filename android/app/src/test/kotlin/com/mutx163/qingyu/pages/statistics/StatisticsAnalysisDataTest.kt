package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 深度分析六张卡的**真实读数**接线测试（P0：六张卡恒空）。
 *
 * ## 这些用例在钉什么
 *
 * 端点 `e.analysis` 以前只给 `StatisticsAnalysisModel.viewState` 传 `module` 与
 * `courseCount`，其余读数参数全是默认空表 ⇒ 六张卡永远空。
 * [StatisticsAnalysisModel.analysisViewState] 把「课表 → 各卡读数」接上，
 * 本测试逐模块断言**读数确实来自那门课**，而不是空列表。
 *
 * 期望值由固定夹具人算得出，不看实现：一门「高等数学」第 3 周卡、周一 1～2 节、
 * 08:00–09:40、第 1～16 周、当前第 6 周 ⇒ 活跃 6 周、课时 2×6=12 节。
 * 不用 `LocalDate.now()`，避免日期老化。
 */
class StatisticsAnalysisDataTest {

    // ── 1. 趋势 / 热力图 ──

    @Test
    fun `趋势模块给出每周课时点与热力图峰值`() {
        val state = StatisticsAnalysisModel.analysisViewState(
            module = StatisticsAnalysisModule.TREND,
            courses = listOf(course()),
            currentWeek = 6,
            semesterWeekCount = 16,
        )

        assertTrue("有课就必须有数据", state.hasData)
        assertEquals("趋势点覆盖整个学期 16 周", 16, state.trend.size)
        assertEquals("第 1 周计划课时 = 2 节", 2, state.trend.first().sections)
        assertTrue("热力图峰值应大于 0（否则卡片仍画空态）", state.heatmapMax > 0)
        assertTrue("热力图有数据时给一句既有 ARB 提示", state.heatmapSummary.isNotBlank())
    }

    // ── 2. 时间利用 ──

    @Test
    fun `时间利用模块给出七行真实读数`() {
        val state = StatisticsAnalysisModel.analysisViewState(
            module = StatisticsAnalysisModule.TIME_UTIL,
            courses = listOf(course()),
            currentWeek = 6,
            semesterWeekCount = 16,
        )

        assertEquals("时间利用固定 7 行", 7, state.timeUtilRows.size)
        assertEquals("最早课 = 08:00", "08:00", state.timeUtilRows[0].second)
        assertTrue("行标签来自既有 ARB", state.timeUtilRows[0].first.isNotBlank())
    }

    // ── 3. 教室与教学楼 ──

    @Test
    fun `教室模块给出分组标题与教室读数`() {
        val state = StatisticsAnalysisModel.analysisViewState(
            module = StatisticsAnalysisModule.VENUE,
            courses = listOf(course()),
            currentWeek = 6,
            semesterWeekCount = 16,
        )

        assertTrue("教室读数不应为空", state.venueRows.isNotEmpty())
        assertTrue(
            "应出现「常去教室」分组与那间教室",
            state.venueRows.any { it.first == "教三 201" },
        )
    }

    // ── 4. 教师排行 ──

    @Test
    fun `教师模块给出教师读数`() {
        val state = StatisticsAnalysisModel.analysisViewState(
            module = StatisticsAnalysisModule.TEACHER,
            courses = listOf(course()),
            currentWeek = 6,
            semesterWeekCount = 16,
        )

        assertEquals(1, state.teacherRows.size)
        assertTrue("教师名应出现在行标签里", state.teacherRows[0].first.contains("张老师"))
        assertTrue("课时读数应为 12 节", state.teacherRows[0].second.contains("12"))
    }

    // ── 5. 课程排行 ──

    @Test
    fun `排行模块给出课程与课时`() {
        val state = StatisticsAnalysisModel.analysisViewState(
            module = StatisticsAnalysisModule.RANKING,
            courses = listOf(course()),
            currentWeek = 6,
            semesterWeekCount = 16,
        )

        assertEquals(1, state.rankingRows.size)
        assertEquals("排行第一行是课名", "高等数学", state.rankingRows[0].first)
        assertTrue("课时读数应为 12 节", state.rankingRows[0].second.contains("12"))
    }

    // ── 6. 课表对比 ──

    @Test
    fun `对比模块给出当前课表与其它课表读数`() {
        val other = StatisticsAnalysisModel.ProfileAnalysisInput(
            name = "课表 B",
            courses = listOf(course(id = "c2", name = "大学物理")),
            currentWeek = 6,
            semesterWeekCount = 16,
        )
        val state = StatisticsAnalysisModel.analysisViewState(
            module = StatisticsAnalysisModule.COMPARE,
            courses = listOf(course()),
            currentWeek = 6,
            semesterWeekCount = 16,
            hasOtherProfiles = true,
            activeProfileName = "课表 A",
            otherProfiles = listOf(other),
        )

        assertEquals("当前课表 + 一份其它课表 = 2 行", 2, state.compareRows.size)
        assertEquals("第一行是当前课表名", "课表 A", state.compareRows[0].first)
        assertEquals("第二行是另一份课表名", "课表 B", state.compareRows[1].first)
    }

    // ── 7. 空课表：仍然空态，不补假读数 ──

    @Test
    fun `空课表仍是空态且各卡读数为空`() {
        for (module in StatisticsAnalysisModule.entries) {
            val state = StatisticsAnalysisModel.analysisViewState(
                module = module,
                courses = emptyList(),
                currentWeek = 1,
                semesterWeekCount = 16,
            )
            assertFalse("空课表不该有数据：$module", state.hasData)
            assertTrue("空课表不该有趋势：$module", state.trend.isEmpty())
            // 时间利用/对比的模型各自固定返回若干行（0 值），页面在 hasData=false 时
            // 走空态、根本不画它们，所以这里只钉「不会画出内容的那几类读数」。
            assertTrue("空课表不该有教室读数：$module", state.venueRows.isEmpty())
            assertTrue("空课表不该有教师读数：$module", state.teacherRows.isEmpty())
            assertTrue("空课表不该有排行读数：$module", state.rankingRows.isEmpty())
        }
    }

    // ── 夹具 ──

    /** 一门课：第 3 天（周三）1～2 节、08:00–09:40、第 1～16 周；当前第 6 周 ⇒ 12 节。 */
    private fun course(
        id: String = "c1",
        name: String = "高等数学",
    ): Course = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "教三 201",
        dayOfWeek = 3,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = 1,
        endWeek = 16,
        isOddWeek = false,
        isEvenWeek = false,
        suspendedWeeks = null,
        courseNature = CourseNature.REQUIRED,
    )
}
