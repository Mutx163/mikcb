package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.statistics.BuildingStat
import com.mutx163.qingyu.statistics.CourseSemesterStat
import com.mutx163.qingyu.statistics.CourseSlot
import com.mutx163.qingyu.statistics.CourseStat
import com.mutx163.qingyu.statistics.RoomVisitStat
import com.mutx163.qingyu.statistics.SemesterProgress
import com.mutx163.qingyu.statistics.SemesterProgressPhase
import com.mutx163.qingyu.statistics.TeacherStat
import com.mutx163.qingyu.statistics.TimeUtilizationStats
import com.mutx163.qingyu.statistics.VenueStats
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

private fun semesterCourse(
    name: String,
    sections: Int,
    nature: CourseNature = CourseNature.REQUIRED,
    teacher: String = "张老师",
    slots: List<CourseSlot> = emptyList(),
) = CourseSemesterStat(
    name = name,
    teacher = teacher,
    nature = nature,
    totalSections = sections,
    slots = slots,
)

class CourseRankingModelTest {

    @Test
    fun `排行按课时比例画条 榜首满格`() {
        val rows = CourseRankingModel.build(
            listOf(
                semesterCourse("高数", 40),
                semesterCourse("英语", 36, CourseNature.ELECTIVE),
                semesterCourse("体育", 20),
            ),
        )
        assertEquals(3, rows.size)
        // 名次 1、2、3（Dart index + 1，并列不处理）
        assertEquals(listOf(1, 2, 3), rows.map { it.rank })
        // 比例 = 课时 / 榜首课时：40/40、36/40、20/40
        assertEquals(1.0, rows[0].barFraction, 1e-9)
        assertEquals(0.9, rows[1].barFraction, 1e-9)
        assertEquals(0.5, rows[2].barFraction, 1e-9)
        // 必修 / 选修标签
        assertEquals("必修", rows[0].natureLabel)
        assertEquals("选修", rows[1].natureLabel)
        assertTrue(rows[0].isRequired)
        assertEquals(false, rows[1].isRequired)
        // 前三名亮色徽章
        assertTrue(rows[0].showsTrophy)
        assertTrue(rows[2].showsTrophy)
        assertEquals(false, CourseRankingModel.build(listOf(semesterCourse("x", 50)))[0].let { it.rank == 4 })
    }

    @Test
    fun `课时全为零时不除零`() {
        val rows = CourseRankingModel.build(listOf(semesterCourse("空", 0), semesterCourse("空2", 0)))
        // 榜首也是 0：归一化分母 <= 0 时比例取 0，不产生 NaN
        assertEquals(0.0, rows[0].barFraction, 1e-9)
        assertEquals(0.0, rows[1].barFraction, 1e-9)
    }

    @Test
    fun `空列表返回空行`() {
        assertEquals(0, CourseRankingModel.build(emptyList()).size)
        assertEquals("暂无课程数据", CourseRankingModel.emptyMessage)
    }

    @Test
    fun `时间槽两种写法`() {
        val slot = CourseSlot(dayOfWeek = 3, startSection = 3, endSection = 4, location = "A101")
        val labels = CourseRankingModel.slotLabels(slot)
        // 行内胶囊：星期短名 + 节次区间 + 单位
        assertEquals("三 3-4节", labels.short)
        // 展开详情：星期全名 + 「第 a～b 节」
        assertEquals("周三 第 3～4 节", labels.detail)

        // 单节课不写区间
        assertEquals(
            "五 2节",
            CourseRankingModel.shortSlotLabel(5, 2, 2),
        )
        assertEquals(
            "周五 第 2～2 节",
            CourseRankingModel.detailSlotLabel(5, 2, 2),
        )
    }

    @Test
    fun `星期越界时短名留空 与 Dart 兜底一致`() {
        // Dart `_weekdayShortLabel` 的 default 分支返回数字字符串，而 l10n 的短名越界返回空串；
        // 这里跟 l10n 口径走（空串），标签会出现前导空格
        assertEquals(" 3节", CourseRankingModel.shortSlotLabel(0, 3, 3))
        // 全名越界回退成数字
        assertEquals("8 第 3～4 节", CourseRankingModel.detailSlotLabel(8, 3, 4))
    }

    @Test
    fun `必修选修文字来自 ARB`() {
        assertEquals("必修", CourseRankingModel.natureLabel(CourseNature.REQUIRED))
        assertEquals("选修", CourseRankingModel.natureLabel(CourseNature.ELECTIVE))
    }
}

class WeekStatsModelTest {
    @Test
    fun `周选择器文案与当前周判定`() {
        assertEquals("第 5 周", WeekStatsModel.weekSelectorLabel(5))
        assertEquals("第 1 周", WeekStatsModel.weekSelectorLabel(1))
        assertTrue(WeekStatsModel.isCurrentWeek(5, 5))
        assertEquals(false, WeekStatsModel.isCurrentWeek(5, 4))
        // 没设置当前周时，任何周都不是"本周"
        assertEquals(false, WeekStatsModel.isCurrentWeek(5, null))
        assertEquals("本周", WeekStatsModel.currentWeekHint)
    }

    @Test
    fun `周次选项是 1 到最大周`() {
        assertEquals(listOf(1, 2, 3), WeekStatsModel.weekOptions(3))
        assertEquals(listOf(1), WeekStatsModel.weekOptions(1))
        assertEquals(0, WeekStatsModel.weekOptions(0).size)
        assertEquals(0, WeekStatsModel.weekOptions(-2).size)
    }

    @Test
    fun `课程行用周课时而不是学期总课时`() {
        val stat = CourseStat(
            name = "高数",
            teacher = "张老师",
            nature = CourseNature.ELECTIVE,
            weeklySections = 4,
            slots = listOf(CourseSlot(1, 1, 2, "A101")),
        )
        val row = WeekStatsModel.courseRow(stat)
        assertEquals("高数", row.name)
        assertEquals(4, row.weeklySections)
        assertEquals(false, row.isRequired)
        assertEquals("选修", row.natureLabel)
        assertEquals(listOf("一 1-2节"), row.slots.map { it.short })
    }
}

class StatsInfoModelsTest {

    private fun timeStats(
        earliest: String = "08:00",
        latest: String = "18:30",
        morning: Int = 3,
        noon: Int = 2,
        evening: Int = 1,
        weekend: Int = 2,
        gap: Int = 2,
        active: Int = 8,
    ) = TimeUtilizationStats(
        earliestStart = earliest,
        latestEnd = latest,
        morningSections = morning,
        noonSections = noon,
        eveningSections = evening,
        weekendSections = weekend,
        maxDailyGapSections = gap,
        activeCourseCount = active,
    )

    @Test
    fun `时间利用七项读数的顺序与单位`() {
        val facts = TimeUtilizationModel.facts(timeStats())
        assertEquals(7, facts.size)
        assertEquals(
            listOf("最早课", "最晚课", "早间课时", "午间课时", "晚间课时", "周末课时", "最长课间空档"),
            facts.map { it.label },
        )
        assertEquals(
            listOf("08:00", "18:30", "3 节", "2 节", "1 节", "2 节", "2 节"),
            facts.map { it.value },
        )
        // 语义色顺序照 Dart：橙、靛、黄、青、紫、蓝、红
        assertEquals(
            listOf(
                TimeAccent.ORANGE, TimeAccent.INDIGO, TimeAccent.YELLOW,
                TimeAccent.TEAL, TimeAccent.PURPLE, TimeAccent.BLUE, TimeAccent.RED,
            ),
            facts.map { it.accent },
        )
    }

    @Test
    fun `时间读数为空串时回退到暂无课程数据`() {
        val facts = TimeUtilizationModel.facts(timeStats(earliest = "", latest = ""))
        assertEquals("暂无课程数据", facts[0].value)
        assertEquals("暂无课程数据", facts[1].value)
    }

    @Test
    fun `教室与教学楼的条形比例按榜首归一`() {
        val bars = VenueStatsModel.bars(
            VenueStats(
                topRooms = listOf(RoomVisitStat("A101", 5), RoomVisitStat("B202", 3)),
                buildings = listOf(BuildingStat("一教", 10), BuildingStat("二教", 4)),
            ),
        )
        assertEquals(listOf("5 次", "3 次"), bars.rooms.map { it.value })
        assertEquals(1.0, bars.rooms[0].fraction, 1e-9)
        assertEquals(0.6, bars.rooms[1].fraction, 1e-9)
        assertEquals(listOf("10 节", "4 节"), bars.buildings.map { it.value })
        assertEquals(1.0, bars.buildings[0].fraction, 1e-9)
        assertEquals(0.4, bars.buildings[1].fraction, 1e-9)
    }

    @Test
    fun `榜首为零时比例取零不产生 NaN`() {
        val bars = VenueStatsModel.bars(
            VenueStats(topRooms = listOf(RoomVisitStat("A", 0)), buildings = emptyList()),
        )
        assertEquals(0.0, bars.rooms[0].fraction, 1e-9)
        assertEquals(false, bars.isEmpty)
        // 两边都空才是空
        assertTrue(VenueStatsModel.bars(VenueStats(emptyList(), emptyList())).isEmpty)
    }

    @Test
    fun `教师排行名次与前三名标记`() {
        val rows = TeacherStatsModel.rows(
            listOf(
                TeacherStat("张老师", 12, 2),
                TeacherStat("李老师", 8, 1),
                TeacherStat("王老师", 6, 1),
                TeacherStat("赵老师", 4, 1),
            ),
        )
        assertEquals(listOf(1, 2, 3, 4), rows.map { it.rank })
        assertEquals(listOf(true, true, true, false), rows.map { it.topThree })
        assertEquals("2 门课", rows[0].courseCountLabel)
        assertEquals("12 节", rows[0].sectionsLabel)
        assertEquals("4 节", rows[3].sectionsLabel)
    }

    @Test
    fun `学前进度卡的日期与文案`() {
        val spec = SemesterProgressModel.build(
            SemesterProgress(
                semesterStartDate = LocalDate.of(2026, 9, 1),
                currentDate = LocalDate.of(2026, 10, 27),
                semesterEndDate = LocalDate.of(2027, 1, 10),
                weeksElapsed = 8,
                totalWeeks = 20,
                sectionsDone = 96,
                sectionsTotal = 192,
                remainingSections = 96,
                phase = SemesterProgressPhase.IN_PROGRESS,
            ),
        )
        assertEquals("8/20", spec.weekRatioLabel)
        assertEquals("学期 2026年9月1日 - 2027年1月10日", spec.dateRangeLabel)
        assertEquals(0.5, spec.percent, 1e-9)
        assertEquals("50%", spec.percentLabel)
        assertEquals("截至第 8 周，已上 96 节 / 共 192 节", spec.detailLabel)
        assertEquals("今天 10月27日", spec.sideLabel)
        assertEquals("剩余 96 节", spec.remainingLabel)
        assertEquals(false, spec.beforeStart)
    }

    @Test
    fun `还没开学时右侧整列不显示`() {
        val spec = SemesterProgressModel.build(
            SemesterProgress(
                semesterStartDate = LocalDate.of(2026, 9, 1),
                currentDate = LocalDate.of(2026, 8, 20),
                semesterEndDate = LocalDate.of(2027, 1, 10),
                weeksElapsed = 0,
                totalWeeks = 20,
                sectionsDone = 0,
                sectionsTotal = 192,
                remainingSections = 192,
                phase = SemesterProgressPhase.BEFORE_START,
            ),
        )
        assertEquals(true, spec.beforeStart)
        assertEquals("还未开学，尚未上课", spec.detailLabel)
        assertEquals("0%", spec.percentLabel)
        // 右侧两格都不出
        assertNull(spec.sideLabel)
        assertNull(spec.remainingLabel)
    }

    @Test
    fun `没有开学日期时按周估算`() {
        val spec = SemesterProgressModel.build(
            SemesterProgress(
                semesterStartDate = null,
                currentDate = null,
                semesterEndDate = null,
                weeksElapsed = 5,
                totalWeeks = 20,
                sectionsDone = 40,
                sectionsTotal = 200,
                remainingSections = 160,
                phase = SemesterProgressPhase.ESTIMATED,
            ),
        )
        assertNull(spec.dateRangeLabel)
        assertEquals("按周估算", spec.sideLabel)
        assertEquals("20%", spec.percentLabel)
        assertEquals("剩余 160 节", spec.remainingLabel)
    }

    @Test
    fun `进度比例钳在零到一之间`() {
        // 已上节数超过计划（换课/加课导致）：钳到 100%，不出现 156%
        val spec = SemesterProgressModel.build(
            SemesterProgress(
                semesterStartDate = LocalDate.of(2026, 9, 1),
                currentDate = LocalDate.of(2027, 1, 5),
                semesterEndDate = LocalDate.of(2027, 1, 10),
                weeksElapsed = 19,
                totalWeeks = 20,
                sectionsDone = 300,
                sectionsTotal = 192,
                remainingSections = 0,
                phase = SemesterProgressPhase.IN_PROGRESS,
            ),
        )
        assertEquals(1.0, spec.percent, 1e-9)
        assertEquals("100%", spec.percentLabel)
    }

    @Test
    fun `中文日期格式`() {
        assertEquals("2026年9月1日", SemesterProgressModel.formatYmd(LocalDate.of(2026, 9, 1)))
        assertEquals("2027年1月10日", SemesterProgressModel.formatYmd(LocalDate.of(2027, 1, 10)))
        assertEquals("9月1日", SemesterProgressModel.formatMd(LocalDate.of(2026, 9, 1)))
        assertEquals("12月31日", SemesterProgressModel.formatMd(LocalDate.of(2026, 12, 31)))
    }
}

class ProfileCompareModelTest {

    private fun entry(
        name: String,
        isActive: Boolean = false,
        week: Int = 5,
        sections: Int = 40,
        courses: Int = 8,
        ratio: Double = 0.5,
        streak: Int = 3,
        delta: Int? = null,
    ) = ProfileCompareEntry(
        name = name,
        isActive = isActive,
        currentWeek = week,
        totalSections = sections,
        totalCourses = courses,
        requiredRatio = ratio,
        longestStreak = streak,
        deltaSections = delta,
    )

    @Test
    fun `四列读数按 课程门数 节课 必修占比 天连续 排列`() {
        val rows = ProfileCompareModel.rows(
            listOf(entry("主课表", isActive = true, courses = 8, sections = 40, ratio = 0.5, streak = 3)),
        )
        assertEquals(1, rows.size)
        assertEquals(listOf("8", "40", "50%", "3"), rows[0].columns)
    }

    @Test
    fun `当前课表显示当前课表标记 其它课表显示较当前差`() {
        val rows = ProfileCompareModel.rows(
            listOf(
                entry("主课表", isActive = true),
                entry("副课表", isActive = false, delta = 3),
                entry("旧课表", isActive = false, delta = -2),
                entry("持平", isActive = false, delta = 0),
                entry("未知", isActive = false, delta = null),
            ),
        )
        // 当前课表：有「当前课表」标记，没有差值
        assertEquals("当前课表", rows[0].activeLabel)
        assertNull(rows[0].deltaLabel)
        // 差值 3 → "较当前 +3 节"，红色语义（变多）
        assertEquals("较当前 +3 节", rows[1].deltaLabel)
        assertEquals(ChartMath.DeltaTone.UP, rows[1].deltaTone)
        assertNull(rows[1].activeLabel)
        // 差值 -2 → 绿色语义
        assertEquals("较当前 -2 节", rows[2].deltaLabel)
        assertEquals(ChartMath.DeltaTone.DOWN, rows[2].deltaTone)
        // 持平 → 灰色，文案仍是「较当前 0 节」
        assertEquals("较当前 0 节", rows[3].deltaLabel)
        assertEquals(ChartMath.DeltaTone.FLAT, rows[3].deltaTone)
        // 没给差值：两个都空（渲染层不占位）
        assertNull(rows[4].deltaLabel)
        assertNull(rows[4].deltaTone)
    }

    @Test
    fun `周次文案与表头同口径`() {
        val rows = ProfileCompareModel.rows(listOf(entry("主课表", week = 7)))
        assertEquals("第 7 周", rows[0].weekLabel)
        assertEquals(
            listOf("课程门数", "节课", "必修 / 选修", "天连续"),
            ProfileCompareModel.headers(),
        )
        // 列宽：48 / 40 / 64 / 36，间距 8（宽度改了下表头就会错位）
        assertEquals(listOf(48f, 40f, 64f, 36f), ProfileCompareModel.headerWidths())
        assertEquals(8f, ProfileCompareModel.COL_GAP_DP, 1e-4f)
    }

    @Test
    fun `必修占比四舍五入并钳在零到一百`() {
        assertEquals("50%", ProfileCompareModel.percentLabel(0.5))
        // 1/3 → 33.33% → 33%
        assertEquals("33%", ProfileCompareModel.percentLabel(1.0 / 3.0))
        assertEquals("67%", ProfileCompareModel.percentLabel(2.0 / 3.0))
        assertEquals("100%", ProfileCompareModel.percentLabel(1.0))
        assertEquals("0%", ProfileCompareModel.percentLabel(0.0))
        // 越界钳制，不出现 150%
        assertEquals("100%", ProfileCompareModel.percentLabel(1.5))
        assertEquals("0%", ProfileCompareModel.percentLabel(-0.2))
    }

    @Test
    fun `空课表列表不产生行`() {
        assertEquals(0, ProfileCompareModel.rows(emptyList()).size)
    }
}
