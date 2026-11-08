package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.pages.statistics.charts.BarEmphasis
import com.mutx163.qingyu.statistics.Achievement
import com.mutx163.qingyu.statistics.CourseNatureStats
import com.mutx163.qingyu.statistics.DailyAverageStats
import com.mutx163.qingyu.statistics.DataStory
import com.mutx163.qingyu.statistics.SemesterProgress
import com.mutx163.qingyu.statistics.SemesterProgressPhase
import com.mutx163.qingyu.statistics.SemesterStats
import com.mutx163.qingyu.statistics.StoryType
import com.mutx163.qingyu.statistics.WeeklyComparison
import java.time.LocalDate
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程统计主页（`lib/screens/course_statistics_screen.dart`）模型层测试。
 *
 * 期望值从 Dart 源**手推**，来源分三处：
 * 1. 屏层装配规则 —— 学期/周分段、选中周越界回正、顶栏动作随有无数据开关、
 *    深度分析入口顺序（含「存在其他课表才显示课表对比」）；
 * 2. 各图表件的文案与格式化口径 —— `overview_section.dart`（4 格指标）、
 *    `semester_progress_card.dart`（进度卡）、`weekly_comparison_card.dart`（本周小结）、
 *    `daily_chart.dart`（每日柱状，最大/最小高亮）、`nature_ratio.dart`（必修选修环 + 缺失提示）、
 *    `achievement_badge.dart`（进度文案）、`data_story_card.dart`（故事正文）；
 * 3. `i18n/app_zh.arb` 的原文字面量。
 *
 * 这里刻意**不**重算学期统计数值（那是 Phase 2 已交付的 `StatisticsService`），
 * 而是把已算好的 `SemesterStats` / `SemesterProgress` / `WeeklyComparison` 等当输入，
 * 只验「屏层怎么摆、怎么格式化」。
 */
class CourseStatisticsModelTest {

    // ── 0. 构造夹具 ──

    private fun semesterStats(
        courses: Int = 2,
        sections: Int = 64,
        weeks: Int = 16,
        streak: Int = 5,
        daily: List<DailyAverageStats> = emptyList(),
        nature: CourseNatureStats = CourseNatureStats(1, 1, 32, 32),
    ) = SemesterStats(
        totalCourses = courses,
        totalSections = sections,
        totalWeeks = weeks,
        longestStreak = streak,
        dailyAverages = daily,
        natureStats = nature,
        courseRanking = emptyList(),
    )

    private fun progress(
        start: LocalDate? = LocalDate.of(2026, 9, 1),
        current: LocalDate? = LocalDate.of(2026, 10, 27),
        end: LocalDate? = LocalDate.of(2027, 1, 10),
        weeksElapsed: Int = 8,
        totalWeeks: Int = 16,
        done: Int = 96,
        total: Int = 192,
        remaining: Int = 96,
        phase: SemesterProgressPhase = SemesterProgressPhase.IN_PROGRESS,
    ) = SemesterProgress(
        semesterStartDate = start,
        currentDate = current,
        semesterEndDate = end,
        weeksElapsed = weeksElapsed,
        totalWeeks = totalWeeks,
        sectionsDone = done,
        sectionsTotal = total,
        remainingSections = remaining,
        phase = phase,
    )

    private fun course(
        id: String,
        name: String,
        teacher: String = "张老师",
        location: String = "A101",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        nature: CourseNature = CourseNature.REQUIRED,
    ) = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = 1,
        endWeek = 16,
        courseNature = nature,
    )

    // ── 1. 选中周越界回正（屏层 `_selectedWeek` 规则） ──

    @Test
    fun `选中周在范围内时保持不动`() {
        assertEquals(3, CourseStatisticsLogic.resolveSelectedWeek(3, currentWeek = 5, semesterWeekCount = 16))
        assertEquals(1, CourseStatisticsLogic.resolveSelectedWeek(1, 1, 16))
        assertEquals(16, CourseStatisticsLogic.resolveSelectedWeek(16, 5, 16))
    }

    @Test
    fun `选中周越界时回到当前周`() {
        // Dart: if (_selectedWeek < 1 || _selectedWeek > semesterWeekCount) =>
        //   _selectedWeek = currentWeek.clamp(1, semesterWeekCount)
        assertEquals(5, CourseStatisticsLogic.resolveSelectedWeek(0, 5, 16))
        assertEquals(5, CourseStatisticsLogic.resolveSelectedWeek(17, 5, 16))
    }

    @Test
    fun `当前周本身越界时夹到学期范围内`() {
        // currentWeek=20 / 学期 16 周 → 夹到 16；currentWeek=0 → 夹到 1
        assertEquals(16, CourseStatisticsLogic.resolveSelectedWeek(0, 20, 16))
        assertEquals(1, CourseStatisticsLogic.resolveSelectedWeek(99, 0, 16))
    }

    // ── 2. 分段控制器 ──

    @Test
    fun `学期与周两个分段按学期态决定选中项`() {
        assertEquals(listOf("学期", "周"), CourseStatisticsLogic.tabLabels())
        assertEquals(0, CourseStatisticsLogic.selectedTabIndex(semesterView = true))
        assertEquals(1, CourseStatisticsLogic.selectedTabIndex(semesterView = false))
    }

    // ── 3. 顶栏动作与空态 ──

    @Test
    fun `没有课程时不显示设置与分享动作、并给出空态文案`() {
        val state = CourseStatisticsLogic.buildViewState(
            courses = emptyList(),
            currentWeek = 1,
            semesterWeekCount = 16,
            semesterStartDate = null,
            selectedWeek = 1,
            semesterView = true,
            hasOtherProfiles = false,
        )
        assertEquals("课程统计", state.title)          // statisticsTitle
        assertEquals("暂无课程数据", state.emptyTitle)  // statisticsNoData
        assertEquals("添加课程后即可查看统计", state.emptyHint) // statisticsNoDataHint
        assertFalse(state.hasData)
        assertFalse("Dart: suffixes: hasData ? [...] : const []", state.showHeaderActions)
        assertNull(state.semester)
        assertTrue("无数据时学期内容里的入口组不渲染", state.analysisEntries.isEmpty())
        assertNull(state.widgetSnapshot)
    }

    @Test
    fun `有课程时显示设置与分享动作并装配学期内容`() {
        val state = CourseStatisticsLogic.buildViewState(
            courses = listOf(course("c1", "高数")),
            currentWeek = 2,
            semesterWeekCount = 16,
            semesterStartDate = LocalDate.of(2026, 9, 1),
            selectedWeek = 2,
            semesterView = true,
            hasOtherProfiles = false,
        )
        assertTrue(state.hasData)
        assertTrue(state.showHeaderActions)
        assertNotNull(state.semester)
        assertEquals("16", state.semester!!.overview[2].value) // totalWeeks
    }

    // ── 4. 深度分析入口（顺序 + 课表对比仅在存在其他课表时） ──

    @Test
    fun `没有其他课表时入口是六条且单节课明细排第一`() {
        val entries = CourseStatisticsLogic.analysisEntries(hasOtherProfiles = false)
        assertEquals(
            listOf("单节课明细", "每周课时趋势", "时间利用", "教室与教学楼", "教师课时排行", "课程排行"),
            entries.map { it.title },
        )
    }

    @Test
    fun `存在其他课表时课表对比并入末位`() {
        val entries = CourseStatisticsLogic.analysisEntries(hasOtherProfiles = true)
        assertEquals(7, entries.size)
        assertEquals("课表对比", entries.last().title)
        // 其余六条顺序不变
        assertEquals(
            listOf("单节课明细", "每周课时趋势", "时间利用", "教室与教学楼", "教师课时排行", "课程排行"),
            entries.dropLast(1).map { it.title },
        )
    }

    // ── 5. 学期总览四格（overview_section.dart） ──

    @Test
    fun `总览四格是门数课时周数连续天数且首格高亮`() {
        val cells = CourseStatisticsLogic.buildOverview(semesterStats(courses = 3, sections = 48, weeks = 16, streak = 5))
        assertEquals(listOf("3", "48", "16", "5"), cells.map { it.value })
        assertEquals(listOf("门课程", "节课", "周", "天连续"), cells.map { it.label })
        assertEquals(listOf(true, false, false, false), cells.map { it.highlight })
    }

    @Test
    fun `门数为零时不渲染总览`() {
        assertTrue(CourseStatisticsLogic.buildOverview(semesterStats(courses = 0)).isEmpty())
    }

    // ── 6. 学期进度卡（semester_progress_card.dart） ──

    @Test
    fun `进度卡按日期口径渲染周数百分比与剩余`() {
        val view = CourseStatisticsLogic.buildProgress(progress())
        assertEquals("学期进度", view.title)
        assertEquals("8/16", view.weekLabel)                                   // '{weeks}/{total}'
        assertEquals("学期 2026年9月1日 - 2027年1月10日", view.rangeLabel)      // yMMMd 区间
        assertEquals("50%", view.percentText)                                   // 96/192
        assertEquals("截至第 8 周，已上 96 节 / 共 192 节", view.detailLabel)
        assertEquals("今天 10月27日", view.factLabel)                           // statisticsSemesterProgressAsOf
        assertEquals("剩余 96 节", view.remainingLabel)
        assertFalse(view.isBeforeStart)
    }

    @Test
    fun `未设置开学日期时按周估算且没有日期区间`() {
        val view = CourseStatisticsLogic.buildProgress(
            progress(
                start = null,
                current = null,
                end = null,
                phase = SemesterProgressPhase.ESTIMATED,
            ),
        )
        assertNull(view.rangeLabel)
        assertEquals("按周估算", view.factLabel)   // statisticsSemesterProgressEstimated
    }

    @Test
    fun `开学前只显示未开学文案、不显示剩余课时`() {
        val view = CourseStatisticsLogic.buildProgress(
            progress(
                weeksElapsed = 0,
                done = 0,
                remaining = 192,
                phase = SemesterProgressPhase.BEFORE_START,
            ),
        )
        assertTrue(view.isBeforeStart)
        assertEquals("还未开学，尚未上课", view.detailLabel) // statisticsSemesterProgressNotStarted
        // Dart: if (!isBeforeStart) ... 第二格整块不渲染
        assertNull(view.factLabel)
        assertNull(view.remainingLabel)
    }

    @Test
    fun `百分比按四舍五入取整`() {
        val view = CourseStatisticsLogic.buildProgress(progress(done = 1, total = 3, remaining = 2, weeksElapsed = 1))
        assertEquals("33%", view.percentText) // 33.33 → 33
    }

    @Test
    fun `超过计划的进度也钳到一百`() {
        // 与图表侧共用 semesterProgressRatio：156/100 → 100%，不印 156%
        val view = CourseStatisticsLogic.buildProgress(progress(done = 156, total = 100, remaining = 0))
        assertEquals(1.0, view.percent, 1e-9)
        assertEquals("100%", view.percentText)
    }

    // ── 7. 本周小结（weekly_comparison_card.dart） ──

    @Test
    fun `本周小结给出本周上周差值与学期周均`() {
        val comparison = WeeklyComparison(
            weekSections = 8,
            lastWeekSections = 5,
            semesterAverageSections = 6.0,
            deltaVsLastWeek = 3,
            deltaVsAverage = 2.0,
        )
        val view = CourseStatisticsLogic.buildComparison(comparison, currentWeek = 2)
        assertEquals("本周小结", view.title)
        assertEquals("第 2 周", view.weekLabel)        // statisticsWeekSelector
        assertEquals("8", view.weekSectionsValue)
        assertEquals("本周课时", view.weekSectionsLabel) // statisticsSectionCount
        assertEquals("+3", view.deltaValue)
        assertEquals("较上周 +3 节", view.deltaLabel)
        assertEquals(DeltaTone.UP, view.deltaTone)
        assertEquals("6.0", view.averageValue)          // toStringAsFixed(1)
        assertEquals("学期周均", view.averageLabel)
        assertNull(view.newSemesterHint)
    }

    @Test
    fun `差值零与负值分别落到平与降`() {
        val flat = CourseStatisticsLogic.buildComparison(
            WeeklyComparison(8, 8, 8.0, 0, 0.0),
            currentWeek = 3,
        )
        assertEquals("0", flat.deltaValue)
        assertEquals("较上周 0 节", flat.deltaLabel)
        assertEquals(DeltaTone.FLAT, flat.deltaTone)

        val down = CourseStatisticsLogic.buildComparison(
            WeeklyComparison(6, 8, 7.0, -2, -1.0),
            currentWeek = 3,
        )
        assertEquals("-2", down.deltaValue)
        assertEquals("较上周 -2 节", down.deltaLabel)
        assertEquals(DeltaTone.DOWN, down.deltaTone)
    }

    @Test
    fun `第一周没有上周可比起、改显新学期提示`() {
        val view = CourseStatisticsLogic.buildComparison(
            WeeklyComparison(8, 0, 8.0, 8, 0.0),
            currentWeek = 1,
        )
        assertEquals("—", view.deltaValue)
        assertEquals("较上周 — 节", view.deltaLabel)
        assertEquals("新学期第一周", view.newSemesterHint) // statisticsComparisonNew
        assertTrue(view.isFirstWeek)
    }

    // ── 8. 成就徽章（achievement_badge.dart） ──

    @Test
    fun `成就名与进度文案`() {
        val unlocked = CourseStatisticsLogic.buildAchievement(
            Achievement(id = "scholar", isUnlocked = true, progressCurrent = 120, progressTarget = 100),
        )
        assertEquals("学霸", unlocked.name)
        assertEquals("总课时 ≥ 100", unlocked.description)
        assertEquals("已达成", unlocked.progressLabel)  // statisticsAchievementDone
        assertEquals("解锁条件：学期累计课时达到 100 节。", unlocked.detail)
        assertTrue(unlocked.hasProgress)
        assertEquals(120, unlocked.progressCurrent)
        assertEquals(100, unlocked.progressTarget)
        assertEquals(1.0f, unlocked.progressRatio, 0.0001f)
        assertEquals("已达成", unlocked.statusLabel)
        assertEquals("知道了", unlocked.confirmLabel)

        val locked = CourseStatisticsLogic.buildAchievement(
            Achievement(id = "scholar", isUnlocked = false, progressCurrent = 86, progressTarget = 100),
        )
        assertEquals("86/100", locked.progressLabel)    // statisticsAchievementProgress
        assertFalse(locked.isUnlocked)
        assertEquals("解锁条件：学期累计课时达到 100 节。", locked.detail)
        assertTrue(locked.hasProgress)
        assertEquals(86, locked.progressCurrent)
        assertEquals(100, locked.progressTarget)
        assertEquals(0.86f, locked.progressRatio, 0.0001f)
        assertEquals("未达成", locked.statusLabel)
        assertEquals("知道了", locked.confirmLabel)

        val noProgress = CourseStatisticsLogic.buildAchievement(
            Achievement(id = "weekend_warrior", isUnlocked = false),
        )
        assertNull("无进度信息的徽章不显示进度", noProgress.progressLabel)
        assertFalse(noProgress.hasProgress)
        assertEquals("解锁条件：周六或周日有课。", noProgress.detail)
        assertEquals("未达成", noProgress.statusLabel)
    }

    @Test
    fun `越小越好的成就未解锁时不显示反向前进`() {
        // balanced / gap_master 的 progressCurrent 是「当前空档数」、target 是上限。
        // 6/2 不是 300% 完成度，未解锁时宁可只显示「未达成」。
        for (id in listOf("balanced", "gap_master")) {
            val locked = CourseStatisticsLogic.buildAchievement(
                Achievement(id = id, isUnlocked = false, progressCurrent = 6, progressTarget = 2),
            )
            assertNull("$id 未解锁时不应显示 6/2", locked.progressLabel)
            assertFalse("$id 未解锁时不应画进度条", locked.hasProgress)
            assertNull(locked.progressCurrent)
            assertNull(locked.progressTarget)
            assertEquals(0f, locked.progressRatio, 0.0001f)
            assertEquals("未达成", locked.statusLabel)

            val unlocked = CourseStatisticsLogic.buildAchievement(
                Achievement(id = id, isUnlocked = true, progressCurrent = 2, progressTarget = 2),
            )
            assertEquals("已达成", unlocked.progressLabel)
            assertTrue(unlocked.hasProgress)
            assertEquals(1f, unlocked.progressRatio, 0.0001f)
        }
    }

    @Test
    fun `周视图携带完整的WeeklyStats与WeeklyComparison与TimeUtilization`() {
        val c1 = course("c1", "高数", dayOfWeek = 1, startSection = 1, endSection = 2)
        val state = CourseStatisticsLogic.buildViewState(
            courses = listOf(c1),
            currentWeek = 2,
            semesterWeekCount = 16,
            semesterStartDate = LocalDate.of(2026, 9, 1),
            selectedWeek = 2,
            semesterView = false,
            hasOtherProfiles = false,
        )
        val week = state.week
        assertNotNull(week)
        assertNotNull(week!!.weeklyStats)
        assertEquals(2, week.weeklyStats!!.weekNumber)
        assertNotNull(week.comparison)
        assertNotNull(week.timeUtilization)
    }

    // ── 9. 数据故事（data_story_card.dart，`**` 由渲染层解析） ──

    @Test
    fun `故事正文按类型套模板、加粗标记原样保留`() {
        val busiest = CourseStatisticsLogic.buildStory(
            DataStory(StoryType.BUSIEST_DAY, dayOfWeek = 5, weekNumber = 8, averageSections = 6.0),
        )
        assertEquals("最忙的一天", busiest.title)
        assertEquals("截至第 8 周，这学期你最忙的一天是 **周五**，平均 **6.0** 节课", busiest.content)

        val lightest = CourseStatisticsLogic.buildStory(
            DataStory(StoryType.LIGHTEST_DAY, dayOfWeek = 1, weekNumber = 8, averageSections = 2.0),
        )
        assertEquals("截至第 8 周，你最轻松的一天是 **周一**，只有 **2.0** 节课", lightest.content)

        val room = CourseStatisticsLogic.buildStory(
            DataStory(StoryType.FAVORITE_ROOM, weekNumber = 8, room = "A101", visitCount = 12),
        )
        assertEquals("最常去的教室", room.title)
        assertEquals("截至第 8 周，你最常去的教室是 **A101**，共去了 **12** 次", room.content)

        val buildings = CourseStatisticsLogic.buildStory(
            DataStory(StoryType.BUILDING_COUNT, weekNumber = 8, buildingCount = 4),
        )
        assertEquals("教学楼探险", buildings.title)
        assertEquals("截至第 8 周，你的课程分布在 **4** 栋不同的教学楼", buildings.content)

        val timeRange = CourseStatisticsLogic.buildStory(
            DataStory(StoryType.TIME_RANGE, earliestTime = "08:00", latestTime = "20:30"),
        )
        assertEquals("时间跨度", timeRange.title)
        assertEquals("你最早的课是 **08:00**，最晚的课是 **20:30**", timeRange.content)
    }

    // ── 10. 每日课时分布（daily_chart.dart） ──

    @Test
    fun `每日柱状标出最大值与最小值、零课时两天都不标`() {
        val daily = listOf(
            DailyAverageStats(1, 2.0, 32, 1),
            DailyAverageStats(2, 0.0, 0, 0),
            DailyAverageStats(3, 3.5, 56, 2),
            DailyAverageStats(4, 0.0, 0, 0),
            DailyAverageStats(5, 1.0, 16, 1),
            DailyAverageStats(6, 0.0, 0, 0),
            DailyAverageStats(7, 0.0, 0, 0),
        )
        val spec = CourseStatisticsLogic.buildDailyChart(daily)!!

        assertEquals(listOf("一", "二", "三", "四", "五", "六", "日"), spec.bars.map { it.label })
        assertEquals(3.5, spec.maxValue, 0.0001)
        assertEquals(4.5, spec.maxY, 0.0001)             // maxY = maxAverage + 1
        assertEquals(
            listOf(
                BarEmphasis.NORMAL,
                BarEmphasis.NORMAL,
                BarEmphasis.MAX,
                BarEmphasis.NORMAL,
                BarEmphasis.MIN,
                BarEmphasis.NORMAL,
                BarEmphasis.NORMAL,
            ),
            spec.bars.map { it.emphasis },
        )
    }

    @Test
    fun `整周无课时不标任何最大最小`() {
        val daily = (1..7).map { DailyAverageStats(it, 0.0, 0, 0) }
        val spec = CourseStatisticsLogic.buildDailyChart(daily)!!
        assertTrue(spec.bars.all { it.emphasis == BarEmphasis.NORMAL })
        assertEquals(0.0, spec.maxValue, 0.0001)
    }

    // ── 11. 必修 / 选修（nature_ratio.dart） ──

    @Test
    fun `必修选修给出门数课时与百分比`() {
        val view = CourseStatisticsLogic.buildNature(CourseNatureStats(3, 2, 12, 8))
        assertTrue(view.hasData)
        assertEquals(listOf("必修", "选修"), view.legend.map { it.label })
        assertEquals(listOf("3 门 · 12 节", "2 门 · 8 节"), view.legend.map { it.detail })
        assertEquals(listOf("60%", "40%"), view.legend.map { it.ratioText })
        assertNull(view.missingLabel)
        // 环图按门数算弧长，不再从 60%/40% 这种已取整的显示文案反解。
        assertEquals(3, view.requiredCount)
        assertEquals(2, view.electiveCount)
    }

    @Test
    fun `单侧为零时环心给缺失提示`() {
        assertEquals("暂无必修", CourseStatisticsLogic.buildNature(CourseNatureStats(0, 2, 0, 8)).missingLabel)
        assertEquals("暂无选修", CourseStatisticsLogic.buildNature(CourseNatureStats(3, 0, 12, 0)).missingLabel)
        // 两侧都有课 → 环心不放提示
        assertNull(CourseStatisticsLogic.buildNature(CourseNatureStats(3, 2, 12, 8)).missingLabel)
    }

    @Test
    fun `两侧都为零时连环图都不渲染、也就没有缺失提示`() {
        // Dart nature_ratio.dart: hasData = totalCount > 0；false 时整块换成 statisticsNoData 文本，
        // 那个「暂无必修 / 暂无选修」的环心提示属于环图的内部（_buildDonutChart），不会执行。
        val view = CourseStatisticsLogic.buildNature(CourseNatureStats(0, 0, 0, 0))
        assertFalse(view.hasData)
        assertTrue("无数据时不装配图例", view.legend.isEmpty())
        assertNull("环图不渲染，缺失提示必须为空", view.missingLabel)
    }

    @Test
    fun `没有任何课程时不渲染环图`() {
        assertFalse(CourseStatisticsLogic.buildNature(CourseNatureStats(0, 0, 0, 0)).hasData)
    }

    // ── 12. 有故事才显示故事分组 ──

    @Test
    fun `空故事列表时不渲染故事分组`() {
        val state = CourseStatisticsLogic.buildViewState(
            courses = listOf(course("c1", "高数")),
            currentWeek = 2,
            semesterWeekCount = 16,
            semesterStartDate = null,
            selectedWeek = 2,
            semesterView = true,
            hasOtherProfiles = false,
        )
        val semester = state.semester!!
        assertEquals(semester.stories.isNotEmpty(), semester.showStoriesSection)
    }
}
