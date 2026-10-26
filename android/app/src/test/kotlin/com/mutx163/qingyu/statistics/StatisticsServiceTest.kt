package com.mutx163.qingyu.statistics

import com.mutx163.qingyu.core.CourseNature
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * StatisticsService 纯计算移植测试。
 *
 * 期望值来源标注：
 * - 「Dart 测试抄录」= test/services/statistics_service_test.dart（含行号）及
 *   statistics_metric_scope_test / statistics_night_owl_end_of_day_test /
 *   statistics_time_utilization_clock_test / statistics_story_time_range_clock_test /
 *   statistics_favorite_room_active_weeks_test 的既有用例；
 * - 「Dart 逐行」= 按 lib/services/statistics_service.dart 逐行推演；
 * - 「人推边界」= 独立推导（非实现抄录）。
 */
class StatisticsServiceTest {

    private fun course(
        id: String,
        name: String,
        dayOfWeek: Int,
        startSection: Int,
        endSection: Int,
        nature: CourseNature = CourseNature.REQUIRED,
        startTime: String = "08:00",
        endTime: String = "09:40",
        location: String = "教室",
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
    ) = CourseStub(
        name = name, teacher = "老师", location = location,
        dayOfWeek = dayOfWeek, startSection = startSection, endSection = endSection,
        startTime = startTime, endTime = endTime,
        startWeek = startWeek, endWeek = endWeek,
        isOddWeek = isOddWeek, isEvenWeek = isEvenWeek,
        customWeeks = customWeeks, suspendedWeeks = suspendedWeeks,
        courseNature = nature,
    )

    private fun achievement(list: List<Achievement>, id: String) =
        list.first { it.id == id }

    // ========== calculate（周统计，Dart 测试抄录 service_test:9-70） ==========

    @Test
    fun `weekly stats basic`() {
        val courses = listOf(
            course("1", "数学", 1, 1, 2),
            course("2", "数学", 3, 3, 4),
            course("3", "英语", 2, 1, 2, CourseNature.ELECTIVE),
        )
        val stats = StatisticsService.calculate(courses, week = 1)
        assertEquals(1, stats.weekNumber)
        assertEquals(2, stats.totalCourses) // 数学 + 英语（同名去重）
        assertEquals(6, stats.totalSections) // 2 + 2 + 2
        assertEquals(7, stats.dailyStats.size)
    }

    @Test
    fun `weekly stats odd week course`() {
        val courses = listOf(course("1", "单周课", 1, 1, 2, isOddWeek = true))
        val week1 = StatisticsService.calculate(courses, week = 1)
        assertEquals(1, week1.totalCourses)
        assertEquals(2, week1.totalSections)
        val week2 = StatisticsService.calculate(courses, week = 2)
        assertEquals(0, week2.totalCourses)
        assertEquals(0, week2.totalSections)
    }

    @Test
    fun `weekly stats empty`() {
        val stats = StatisticsService.calculate(emptyList(), week = 1)
        assertEquals(0, stats.totalCourses)
        assertEquals(0, stats.totalSections)
        assertEquals(7, stats.dailyStats.size)
        stats.dailyStats.forEach {
            assertEquals(0, it.sectionCount)
            assertEquals(0, it.courseCount)
        }
        assertEquals(0, stats.natureStats.requiredCount)
        assertEquals(0, stats.natureStats.electiveCount)
        assertTrue(stats.courseStats.isEmpty())
    }

    // ========== calculateSemester（Dart 测试抄录 service_test:74-221） ==========

    @Test
    fun `semester stats basic`() {
        val courses = listOf(
            course("1", "数学", 1, 1, 2),
            course("2", "英语", 2, 1, 2, CourseNature.ELECTIVE),
        )
        val stats = StatisticsService.calculateSemester(courses, currentWeek = 16, semesterWeekCount = 16)
        assertEquals(2, stats.totalCourses)
        assertEquals(16, stats.totalWeeks)
        assertEquals(64, stats.totalSections) // 2×16 + 2×16
        assertEquals(7, stats.dailyAverages.size)
        assertEquals(2, stats.courseRanking.size)
    }

    @Test
    fun `semester stats empty`() {
        val stats = StatisticsService.calculateSemester(emptyList(), currentWeek = 16, semesterWeekCount = 16)
        assertEquals(0, stats.totalCourses)
        assertEquals(0, stats.totalSections)
        assertEquals(0, stats.totalWeeks)
        assertEquals(0, stats.longestStreak)
        assertTrue(stats.dailyAverages.isEmpty())
        assertTrue(stats.courseRanking.isEmpty())
    }

    @Test
    fun `semester stats odd week`() {
        // 单周 16 周里第 1,3..15 周有课，共 8 周
        val courses = listOf(course("1", "单周课", 1, 1, 2, isOddWeek = true))
        val stats = StatisticsService.calculateSemester(courses, currentWeek = 16, semesterWeekCount = 16)
        assertEquals(1, stats.totalCourses)
        assertEquals(16, stats.totalSections)
    }

    @Test
    fun `semester stats suspended weeks`() {
        // 16 周 - 2 停课周 = 14 周
        val courses = listOf(course("1", "停课测试", 1, 1, 2, suspendedWeeks = listOf(3, 5)))
        val stats = StatisticsService.calculateSemester(courses, currentWeek = 16, semesterWeekCount = 16)
        assertEquals(1, stats.totalCourses)
        assertEquals(28, stats.totalSections)
    }

    @Test
    fun `longest streak mon to fri`() {
        val courses = (1..5).map { course("$it", "课程$it", it, 1, 2) }
        val stats = StatisticsService.calculateSemester(courses, currentWeek = 16, semesterWeekCount = 16)
        assertEquals(5, stats.longestStreak)
    }

    @Test
    fun `longest streak capped at seven`() {
        val courses = (1..7).map { course("$it", "课程$it", it, 1, 2) }
        val stats = StatisticsService.calculateSemester(courses, currentWeek = 16, semesterWeekCount = 16)
        assertEquals(7, stats.longestStreak)
    }

    @Test
    fun `longest streak crosses week boundary`() {
        // 周六、周日、周一 → 跨周边界连续 3 天
        val courses = listOf(
            course("1", "数学", 6, 1, 2),
            course("2", "英语", 7, 1, 2),
            course("3", "物理", 1, 1, 2),
        )
        val stats = StatisticsService.calculateSemester(courses, currentWeek = 16, semesterWeekCount = 16)
        assertEquals(3, stats.longestStreak)
    }

    // ========== calculateAchievements（Dart 测试抄录 service_test:225-341 等） ==========

    @Test
    fun `early bird unlocked for 8 oclock class`() {
        val courses = listOf(course("1", "早课", 1, 1, 2, startTime = "08:00", endTime = "09:40"))
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        assertTrue(achievement(list, "early_bird").isUnlocked)
    }

    @Test
    fun `weekend warrior unlocked for weekend class`() {
        val courses = listOf(course("1", "周末课", 6, 1, 2))
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        assertTrue(achievement(list, "weekend_warrior").isUnlocked)
    }

    @Test
    fun `scholar unlocked at 100+ sections`() {
        // 10 门 × 2 节 × 16 周 = 320 节
        val courses = (0..9).map { course("$it", "课程$it", (it % 7) + 1, 1, 2) }
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        assertTrue(achievement(list, "scholar").isUnlocked)
    }

    @Test
    fun `achievements empty for no courses`() {
        assertTrue(StatisticsService.calculateAchievements(emptyList(), currentWeek = 16).isEmpty())
    }

    @Test
    fun `perfect attendance excludes suspended weeks`() {
        // endWeek 4、停课第 2 周：计划 3 周，第 4 周时活跃 3 周 → 全勤
        val courses = listOf(
            course("s", "停课课程", 1, 1, 2, endWeek = 4, suspendedWeeks = listOf(2)),
        )
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 4)
        val perfect = achievement(list, "perfect_attendance")
        assertTrue(perfect.isUnlocked)
        assertEquals(1, perfect.progressCurrent)
    }

    @Test
    fun `perfect attendance not unlocked mid semester`() {
        // startWeek 3：第 5 周时活跃 3 周 < 计划 14 周
        val courses = listOf(course("1", "数学", 1, 1, 2, startWeek = 3))
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 5)
        assertFalse(achievement(list, "perfect_attendance").isUnlocked)
    }

    @Test
    fun `scholar progress attached`() {
        // Dart 测试抄录 service_test:777-790：10 门 × 2 节 × 16 周 = 320
        val courses = (0..9).map { course("$it", "课程$it", (it % 7) + 1, 1, 2) }
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        val scholar = achievement(list, "scholar")
        assertTrue(scholar.hasProgress)
        assertEquals(320, scholar.progressCurrent)
        assertEquals(100, scholar.progressTarget)
    }

    @Test
    fun `full day king at 8 sections`() {
        // 周一 4 门 × 2 节 = 8 节
        val courses = (0..3).map { course("$it", "课程$it", 1, it * 2 + 1, it * 2 + 2) }
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        val king = achievement(list, "full_day_king")
        assertTrue(king.isUnlocked)
        assertEquals(8, king.progressCurrent)
        assertEquals(8, king.progressTarget)
    }

    @Test
    fun `morning person at 50 percent`() {
        // 2 门早课（08:00 / 10:00）+ 1 门晚课 → 早间 4/6 ≈ 67%
        val courses = listOf(
            course("1", "早课A", 1, 1, 2, startTime = "08:00", endTime = "09:40", location = "A101"),
            course("2", "早课B", 2, 3, 4, CourseNature.ELECTIVE, startTime = "10:00", endTime = "11:40", location = "B201"),
            course("3", "晚课", 3, 9, 10, CourseNature.ELECTIVE, startTime = "18:30", endTime = "20:10", location = "C301"),
        )
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        val morning = achievement(list, "morning_person")
        assertTrue(morning.isUnlocked)
        assertEquals(67, morning.progressCurrent)
        assertEquals(50, morning.progressTarget)
    }

    @Test
    fun `gap master compact schedule`() {
        // 同一天 1-2 节 + 3-4 节 → 空档 0
        val courses = listOf(
            course("1", "课A", 1, 1, 2),
            course("2", "课B", 1, 3, 4, CourseNature.ELECTIVE),
        )
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        val gapMaster = achievement(list, "gap_master")
        assertTrue(gapMaster.isUnlocked)
        assertEquals(0, gapMaster.progressCurrent)
    }

    @Test
    fun `gap master not unlocked with long break`() {
        // 第 2 节结束 → 第 9 节开始：空档 = 9 - 2 - 1 = 6
        val courses = listOf(
            course("1", "早课", 1, 1, 2),
            course("2", "晚课", 1, 9, 10, CourseNature.ELECTIVE),
        )
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        val gapMaster = achievement(list, "gap_master")
        assertFalse(gapMaster.isUnlocked)
        assertEquals(6, gapMaster.progressCurrent)
    }

    @Test
    fun `building hopper with 3 buildings in a day`() {
        val courses = listOf(
            course("1", "课A", 1, 1, 2, location = "A101", startTime = "08:00", endTime = "09:40"),
            course("2", "课B", 1, 3, 4, location = "B201", startTime = "10:00", endTime = "11:40"),
            course("3", "课C", 1, 5, 6, CourseNature.ELECTIVE, location = "C301", startTime = "14:00", endTime = "15:40"),
        )
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        val hopper = achievement(list, "building_hopper")
        assertTrue(hopper.isUnlocked)
        assertEquals(3, hopper.progressCurrent)
    }

    @Test
    fun `building hopper chinese room names`() {
        // Dart 测试抄录 service_test:932-959（回归钉：`^[A-Za-z]+` 只认字母）
        fun at(id: String, location: String) = course(id, "课$id", 1, 1, 2, location = location)
        val list = StatisticsService.calculateAchievements(
            listOf(at("1", "第一教学楼-101"), at("2", "第一教学楼-202"), at("3", "第二教学楼-101")),
            currentWeek = 16,
        )
        assertEquals(2, achievement(list, "building_hopper").progressCurrent)
    }

    @Test
    fun `building hopper letter and digit prefixed rooms`() {
        // Dart 测试抄录 service_test:961-986：A101/A202 → A；3号楼-101/202 → 3号楼
        fun at(id: String, location: String) = course(id, "课$id", 1, 1, 2, location = location)
        val list = StatisticsService.calculateAchievements(
            listOf(at("1", "A101"), at("2", "A202"), at("3", "3号楼-101"), at("4", "3号楼-202")),
            currentWeek = 16,
        )
        assertEquals(2, achievement(list, "building_hopper").progressCurrent)
    }

    @Test
    fun `distinct numeric rooms never folded into one building`() {
        // Dart 测试抄录 service_test:988-1035（回归钉：裸数字前缀不当楼栋键）
        fun at(id: String, location: String) = course(id, "课$id", 1, 1, 2, location = location)

        val bare = StatisticsService.calculateVenueStats(listOf(at("1", "3101"), at("2", "3201")), 16)
        assertEquals(setOf("3101", "3201"), bare.buildings.map { it.name }.toSet())

        val mixed = StatisticsService.calculateVenueStats(listOf(at("3", "1号楼"), at("4", "1024")), 16)
        assertEquals(setOf("1号楼", "1024"), mixed.buildings.map { it.name }.toSet())

        val real = StatisticsService.calculateVenueStats(
            listOf(at("5", "3号楼-101"), at("6", "3号楼-202"), at("7", "A101")),
            16,
        )
        assertEquals(setOf("3号楼", "A"), real.buildings.map { it.name }.toSet())
    }

    // ========== 口径回归钉（Dart 测试抄录 statistics_metric_scope_test） ==========

    @Test
    fun `building sections counted as sections not visits`() {
        // 楼栋行 = 2 节 × 16 周 = 32 节；教室行 = 16 次
        val courses = listOf(course("a", "课程a", 1, 1, 2, location = "教A-101"))
        val stats = StatisticsService.calculateVenueStats(courses, currentWeek = 16)
        assertEquals(16, stats.topRooms.single().visits)
        assertEquals(32, stats.buildings.single().sections)
    }

    @Test
    fun `blank clock string not early bird but unpadded 8 is`() {
        val courses = listOf(
            course("blank", "课程blank", 1, 1, 2, startTime = "", endTime = "", location = "教A-101"),
            course("early", "课程early", 2, 1, 1, startTime = "8:00", endTime = "8:45", location = "教A-102"),
        )
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        assertEquals(1, achievement(list, "early_bird").progressCurrent)
    }

    @Test
    fun `blank clock string does not inflate morning ratio`() {
        // 分子 2、分母 4（分母含无钟点的课）→ 50%
        val courses = listOf(
            course("morning", "课程morning", 1, 1, 2, startTime = "08:00", endTime = "09:40", location = "教A-101"),
            course("blank", "课程blank", 3, 5, 6, startTime = "", endTime = "", location = "教B-101"),
        )
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        assertEquals(50, achievement(list, "morning_person").progressCurrent)
    }

    @Test
    fun `online course without room is not a building`() {
        val courses = listOf(
            course("a", "课程a", 3, 1, 1, location = "A-101", startTime = "08:00", endTime = "08:45"),
            course("b", "课程b", 3, 3, 3, location = "B-203", startTime = "10:00", endTime = "10:45"),
            course("online", "课程online", 3, 5, 5, location = "", startTime = "14:00", endTime = "14:45"),
        )
        val list = StatisticsService.calculateAchievements(courses, currentWeek = 16)
        assertEquals(2, achievement(list, "building_hopper").progressCurrent)
    }

    // ========== 夜猫子与 24:00（Dart 测试抄录 statistics_night_owl_end_of_day_test） ==========

    private fun lesson(id: String, endTime: String, startSection: Int = 1, endSection: Int = 2) =
        course(id, "课程$id", 1, startSection, endSection, startTime = "19:00", endTime = endTime, location = "A101")

    @Test
    fun `night owl counts 24 oclock end of day`() {
        val courses = listOf(lesson("owl", "24:00"))
        val nightOwl = achievement(StatisticsService.calculateAchievements(courses, currentWeek = 1), "night_owl")
        assertTrue(nightOwl.isUnlocked)
        assertEquals(2, nightOwl.progressCurrent)
    }

    @Test
    fun `night owl and utilization evening agree`() {
        val courses = listOf(lesson("owl", "24:00"), lesson("normal", "21:30"), lesson("morning", "08:45"))
        val utilization = StatisticsService.calculateTimeUtilization(courses, currentWeek = 1)
        assertEquals(
            utilization.eveningSections,
            achievement(StatisticsService.calculateAchievements(courses, currentWeek = 1), "night_owl").progressCurrent,
        )
    }

    @Test
    fun `night owl malformed clock still rejected`() {
        // allowEndOfDay 只放行 24:00；26:00 一律不算
        val courses = listOf(lesson("bad", "26:00"))
        val nightOwl = achievement(StatisticsService.calculateAchievements(courses, currentWeek = 1), "night_owl")
        assertEquals(0, nightOwl.progressCurrent)
        assertFalse(nightOwl.isUnlocked)
    }

    // ========== generateDataStories（Dart 测试抄录 service_test:344-406 等） ==========

    @Test
    fun `stories for valid data`() {
        val courses = listOf(course("1", "数学", 1, 1, 2), course("2", "英语", 2, 1, 2, CourseNature.ELECTIVE))
        val stories = StatisticsService.generateDataStories(courses, currentWeek = 16)
        assertTrue(stories.isNotEmpty())
        assertTrue(stories.any { it.type == StoryType.BUSIEST_DAY })
    }

    @Test
    fun `stories empty for no courses`() {
        assertTrue(StatisticsService.generateDataStories(emptyList(), currentWeek = 16).isEmpty())
    }

    @Test
    fun `room visits are entries times active weeks`() {
        // 同一教室 2 条 × 12 周 = 24 次
        val courses = listOf(
            course("1", "数学", 1, 1, 2, location = "A301"),
            course("2", "数学", 3, 3, 4, location = "A301", startTime = "10:00", endTime = "11:40"),
        )
        val stories = StatisticsService.generateDataStories(courses, currentWeek = 12)
        val roomStory = stories.first { it.type == StoryType.FAVORITE_ROOM }
        assertEquals(24, roomStory.visitCount)
    }

    @Test
    fun `building count story uses same extraction`() {
        // Dart 测试抄录 service_test:1037-1063
        fun at(id: String, location: String) = course(id, "课$id", 1, 1, 2, location = location)
        val stories = StatisticsService.generateDataStories(
            listOf(at("1", "第一教学楼-101"), at("2", "第一教学楼-202"), at("3", "第二教学楼-101")),
            currentWeek = 16,
        )
        assertEquals(2, stories.first { it.type == StoryType.BUILDING_COUNT }.buildingCount)
    }

    @Test
    fun `favorite room skipped when course not started`() {
        // Dart 测试抄录 statistics_favorite_room_active_weeks_test:56-89
        val earlyOnly = StatisticsService.generateDataStories(
            listOf(course("late", "课late", 1, 1, 2, location = "B101", startWeek = 10, endWeek = 16)),
            currentWeek = 3,
        )
        assertTrue(earlyOnly.none { it.type == StoryType.FAVORITE_ROOM })

        val mixed = StatisticsService.generateDataStories(
            listOf(
                course("active", "课active", 1, 1, 2, location = "A101", startWeek = 1, endWeek = 4),
                course("late", "课late", 1, 1, 2, location = "B101", startWeek = 10, endWeek = 16),
            ),
            currentWeek = 3,
        )
        val favorite = mixed.single { it.type == StoryType.FAVORITE_ROOM }
        assertEquals("A101", favorite.room)
        assertEquals(3, favorite.visitCount)
        assertTrue(mixed.none { it.room == "B101" })
    }

    // ========== 时间跨度故事卡（Dart 测试抄录 statistics_story_time_range_clock_test） ==========

    private fun timeRangeStory(courses: List<CourseStub>): DataStory =
        StatisticsService.generateDataStories(courses, currentWeek = 1)
            .first { it.type == StoryType.TIME_RANGE }

    @Test
    fun `story unpadded 8 oclock is earliest not latest`() {
        val story = timeRangeStory(
            listOf(
                course("a", "课a", 1, 1, 1, startTime = "09:00", endTime = "09:45"),
                course("b", "课b", 2, 1, 1, startTime = "8:00", endTime = "8:45"),
            ),
        )
        assertEquals("8:00", story.earliestTime)
        assertEquals("09:45", story.latestTime)
    }

    @Test
    fun `story 10 oclock end beats 9 40`() {
        val story = timeRangeStory(
            listOf(
                course("a", "课a", 1, 1, 1, startTime = "8:00", endTime = "8:45"),
                course("b", "课b", 2, 1, 1, startTime = "9:00", endTime = "9:40"),
                course("c", "课c", 3, 1, 1, startTime = "10:00", endTime = "10:00"),
            ),
        )
        assertEquals("8:00", story.earliestTime)
        assertEquals("10:00", story.latestTime)
    }

    @Test
    fun `story blank clock does not blank earliest`() {
        val story = timeRangeStory(
            listOf(
                course("hole", "课hole", 1, 1, 1, startTime = "", endTime = ""),
                course("a", "课a", 2, 1, 1, startTime = "10:00", endTime = "11:40"),
            ),
        )
        assertEquals("10:00", story.earliestTime)
        assertEquals("11:40", story.latestTime)
    }

    @Test
    fun `story malformed clock not latest`() {
        val story = timeRangeStory(
            listOf(
                course("bad", "课bad", 1, 1, 1, startTime = "08:00", endTime = "26:00"),
                course("a", "课a", 2, 1, 1, startTime = "09:00", endTime = "09:40"),
            ),
        )
        assertEquals("08:00", story.earliestTime)
        assertEquals("09:40", story.latestTime)
    }

    @Test
    fun `story 24 oclock counts as end of day`() {
        val story = timeRangeStory(
            listOf(
                course("evening", "课evening", 1, 1, 1, startTime = "22:00", endTime = "24:00"),
                course("a", "课a", 2, 1, 1, startTime = "08:00", endTime = "09:40"),
            ),
        )
        assertEquals("08:00", story.earliestTime)
        assertEquals("24:00", story.latestTime)
    }

    @Test
    fun `story all unreadable clocks produce no time range story`() {
        val stories = StatisticsService.generateDataStories(
            listOf(course("hole", "课hole", 1, 1, 1, startTime = "", endTime = "")),
            currentWeek = 1,
        )
        assertTrue(stories.none { it.type == StoryType.TIME_RANGE })
    }

    // ========== calculateWeeklyTrend（Dart 测试抄录 service_test:435-477） ==========

    @Test
    fun `trend one point per week`() {
        val courses = listOf(course("1", "数学", 1, 1, 2), course("2", "英语", 2, 1, 2, CourseNature.ELECTIVE))
        val trend = StatisticsService.calculateWeeklyTrend(courses, semesterWeekCount = 16)
        assertEquals(16, trend.size)
        assertEquals(4, trend[0].sections)
        assertEquals(2, trend[0].courseCount)
        assertEquals(2, trend[0].requiredSections)
        assertEquals(2, trend[0].electiveSections)
        assertEquals(2, trend[0].activeDayCount)
    }

    @Test
    fun `trend respects odd weeks`() {
        val courses = listOf(course("1", "单周课", 1, 1, 2, endWeek = 4, isOddWeek = true))
        val trend = StatisticsService.calculateWeeklyTrend(courses, semesterWeekCount = 4)
        assertEquals(2, trend[0].sections)
        assertEquals(0, trend[1].sections)
        assertEquals(2, trend[2].sections)
    }

    @Test
    fun `trend empty inputs`() {
        // Dart 逐行 service:424-426
        assertTrue(StatisticsService.calculateWeeklyTrend(emptyList(), semesterWeekCount = 16).isEmpty())
        assertTrue(StatisticsService.calculateWeeklyTrend(listOf(course("1", "数学", 1, 1, 2)), semesterWeekCount = 0).isEmpty())
    }

    // ========== calculateSemesterProgress（Dart 测试抄录 service_test:479-617） ==========

    @Test
    fun `progress by week without start date`() {
        val courses = listOf(course("1", "数学", 1, 1, 2))
        val progress = StatisticsService.calculateSemesterProgress(courses, currentWeek = 10, semesterWeekCount = 16)
        assertEquals(20, progress.sectionsDone)
        assertEquals(32, progress.sectionsTotal)
        assertEquals(12, progress.remainingSections)
        assertEquals(10, progress.weeksElapsed)
        assertEquals(63, Math.round(progress.percent * 100)) // 20/32 = 62.5%（Dart 原测试用 .round()，抄录修正 toInt→round）
        assertEquals(SemesterProgressPhase.ESTIMATED, progress.phase)
        assertNull(progress.currentDate)
    }

    @Test
    fun `progress resolves calendar dates from semester start`() {
        // 2026-09-07 周一开学；9-16 周三 = 第 2 周
        val start = java.time.LocalDate.of(2026, 9, 7)
        val now = java.time.LocalDateTime.of(2026, 9, 16, 15, 30)
        val courses = listOf(course("1", "数学", 1, 1, 2))
        val progress = StatisticsService.calculateSemesterProgress(
            courses, currentWeek = 2, semesterWeekCount = 16, semesterStartDate = start, now = now,
        )
        assertEquals(start, progress.semesterStartDate)
        assertEquals(java.time.LocalDate.of(2026, 9, 16), progress.currentDate)
        // 结束日 = 本周一对齐后 + 16*7-1 天 = 2026-09-07 + 111 天 = 2026-12-27
        assertEquals(start.plusDays(111), progress.semesterEndDate)
        assertEquals(SemesterProgressPhase.IN_PROGRESS, progress.phase)
        assertEquals(2, progress.weeksElapsed)
        assertEquals(4, progress.sectionsDone) // 第 1 周整周 2 节 + 第 2 周周一 2 节
    }

    @Test
    fun `progress counts only elapsed days in current week`() {
        val start = java.time.LocalDate.of(2026, 9, 7)
        val courses = listOf(
            course("1", "数学", 1, 1, 2),
            course("2", "语文", 3, 1, 2),
            course("3", "英语", 5, 1, 2, CourseNature.ELECTIVE),
        )
        val progress = StatisticsService.calculateSemesterProgress(
            courses, currentWeek = 2, semesterWeekCount = 16,
            semesterStartDate = start, now = java.time.LocalDateTime.of(2026, 9, 16, 0, 0),
        )
        // 第 1 周整周 6 节 + 第 2 周周一/周三已上 4 节（周五未到）
        assertEquals(10, progress.sectionsDone)
        assertEquals(96, progress.sectionsTotal)
        assertEquals(86, progress.remainingSections)
    }

    @Test
    fun `progress zero before semester start`() {
        val start = java.time.LocalDate.of(2026, 9, 7)
        val progress = StatisticsService.calculateSemesterProgress(
            listOf(course("1", "数学", 1, 1, 2)), currentWeek = 1, semesterWeekCount = 16,
            semesterStartDate = start, now = java.time.LocalDateTime.of(2026, 9, 5, 0, 0),
        )
        assertEquals(SemesterProgressPhase.BEFORE_START, progress.phase)
        assertEquals(0, progress.sectionsDone)
        assertEquals(32, progress.sectionsTotal)
        assertEquals(32, progress.remainingSections)
        assertEquals(0, progress.weeksElapsed)
        assertEquals(0.0, progress.percent, 0.0)
    }

    @Test
    fun `progress week1 days before start date not counted`() {
        // 周三开学（9-9），算到周五（9-11）：周一早于开学日不计，周三已上
        val start = java.time.LocalDate.of(2026, 9, 9)
        val progress = StatisticsService.calculateSemesterProgress(
            listOf(course("1", "数学", 1, 1, 2), course("2", "语文", 3, 1, 2)),
            currentWeek = 1, semesterWeekCount = 16,
            semesterStartDate = start, now = java.time.LocalDateTime.of(2026, 9, 11, 0, 0),
        )
        assertEquals(SemesterProgressPhase.IN_PROGRESS, progress.phase)
        assertEquals(2, progress.sectionsDone)
    }

    @Test
    fun `progress clamps to full after semester ends`() {
        val start = java.time.LocalDate.of(2026, 9, 7)
        val courses = listOf(course("1", "数学", 1, 1, 2))

        val lastDay = StatisticsService.calculateSemesterProgress(
            courses, currentWeek = 16, semesterWeekCount = 16,
            semesterStartDate = start, now = java.time.LocalDateTime.of(2026, 9, 7, 0, 0).plusDays((16 * 7 - 1).toLong()),
        )
        assertEquals(SemesterProgressPhase.IN_PROGRESS, lastDay.phase)
        assertEquals(32, lastDay.sectionsDone)
        assertEquals(100, (lastDay.percent * 100).toInt())

        val afterEnd = StatisticsService.calculateSemesterProgress(
            courses, currentWeek = 16, semesterWeekCount = 16,
            semesterStartDate = start, now = java.time.LocalDateTime.of(2026, 9, 7, 0, 0).plusDays((16 * 7 + 1).toLong()),
        )
        assertEquals(SemesterProgressPhase.ENDED, afterEnd.phase)
        assertEquals(16, afterEnd.weeksElapsed)
        assertEquals(32, afterEnd.sectionsDone)
        assertEquals(0, afterEnd.remainingSections)
        assertEquals(1.0, afterEnd.percent, 1e-9)
    }

    @Test
    fun `progress empty courses`() {
        val progress = StatisticsService.calculateSemesterProgress(emptyList(), currentWeek = 5, semesterWeekCount = 16)
        assertEquals(0, progress.sectionsDone)
        assertEquals(0, progress.sectionsTotal)
        assertEquals(0, progress.remainingSections)
        assertEquals(0.0, progress.percent, 0.0)
        assertEquals(SemesterProgressPhase.ESTIMATED, progress.phase)
    }

    // ========== calculateHeatmap（Dart 测试抄录 service_test:620-651） ==========

    @Test
    fun `heatmap fills week by day grid`() {
        val courses = listOf(course("1", "数学", 1, 1, 2), course("2", "英语", 3, 3, 4, CourseNature.ELECTIVE))
        val heatmap = StatisticsService.calculateHeatmap(courses, semesterWeekCount = 4)
        assertEquals(4, heatmap.weekCount)
        assertEquals(7, heatmap.rows.size)
        assertEquals(2, heatmap.rows[0][0])
        assertEquals(2, heatmap.rows[2][0])
        assertEquals(0, heatmap.rows[1][0])
        assertEquals(2, heatmap.maxSections)
    }

    @Test
    fun `heatmap invalid dayOfWeek ignored`() {
        // 人推边界：dayOfWeek 0/8 越界直接跳过（Dart 逐行 service:608-609）
        val heatmap = StatisticsService.calculateHeatmap(
            listOf(course("1", "数学", 0, 1, 2), course("2", "英语", 8, 1, 2)),
            semesterWeekCount = 4,
        )
        assertEquals(0, heatmap.maxSections)
        heatmap.rows.forEach { row -> row.forEach { assertEquals(0, it) } }
    }

    // ========== calculateTimeUtilization（Dart 测试抄录 service_test:654-717 + clock_test） ==========

    @Test
    fun `utilization ranges and segments`() {
        val courses = listOf(
            course("1", "早课", 1, 1, 2, startTime = "08:00", endTime = "09:40", location = "A101"),
            course("2", "晚课", 2, 9, 10, CourseNature.ELECTIVE, startTime = "18:30", endTime = "20:10", location = "B201"),
            course("3", "周末课", 6, 3, 4, CourseNature.ELECTIVE, startTime = "10:00", endTime = "11:40", location = "C301"),
        )
        val stats = StatisticsService.calculateTimeUtilization(courses, currentWeek = 16)
        assertEquals("08:00", stats.earliestStart)
        assertEquals("20:10", stats.latestEnd)
        assertEquals(4, stats.morningSections) // 早课 2 + 周末课 2
        assertEquals(2, stats.eveningSections)
        assertEquals(2, stats.weekendSections)
        assertEquals(0, stats.noonSections)
        assertEquals(3, stats.activeCourseCount)
    }

    @Test
    fun `utilization max daily gap`() {
        val courses = listOf(course("1", "早课", 1, 1, 2), course("2", "晚课", 1, 9, 10, CourseNature.ELECTIVE))
        val stats = StatisticsService.calculateTimeUtilization(courses, currentWeek = 16)
        assertEquals(6, stats.maxDailyGapSections) // 9 - 2 - 1
    }

    @Test
    fun `utilization unpadded 8 oclock is morning not evening`() {
        val stats = StatisticsService.calculateTimeUtilization(
            listOf(course("a", "课a", 1, 1, 1, startTime = "8:00", endTime = "8:45")),
            currentWeek = 1,
        )
        assertEquals(1, stats.morningSections)
        assertEquals(0, stats.eveningSections)
        assertEquals(0, stats.noonSections)
    }

    @Test
    fun `utilization earliest by minutes not lexicographic`() {
        val stats = StatisticsService.calculateTimeUtilization(
            listOf(
                course("a", "课a", 1, 1, 1, startTime = "09:00", endTime = "09:45"),
                course("b", "课b", 2, 1, 1, startTime = "8:00", endTime = "8:45"),
            ),
            currentWeek = 1,
        )
        assertEquals("8:00", stats.earliestStart)
        assertEquals("09:45", stats.latestEnd)
    }

    @Test
    fun `utilization blank clock enters no bucket`() {
        val stats = StatisticsService.calculateTimeUtilization(
            listOf(
                course("hole", "课hole", 1, 1, 1, startTime = "", endTime = "", location = "B202"),
                course("a", "课a", 2, 1, 1, startTime = "10:00", endTime = "11:40"),
            ),
            currentWeek = 1,
        )
        assertEquals(1, stats.morningSections)
        assertEquals("10:00", stats.earliestStart)
        assertEquals("11:40", stats.latestEnd)
    }

    @Test
    fun `utilization 24 oclock counts as evening and latest`() {
        val stats = StatisticsService.calculateTimeUtilization(
            listOf(course("evening", "课evening", 1, 9, 10, startTime = "22:00", endTime = "24:00")),
            currentWeek = 1,
        )
        assertEquals(2, stats.eveningSections)
        assertEquals("24:00", stats.latestEnd)
        assertEquals(0, stats.morningSections)
    }

    @Test
    fun `utilization noon counted once for class crossing 12`() {
        val stats = StatisticsService.calculateTimeUtilization(
            listOf(course("a", "课a", 1, 1, 1, startTime = "11:00", endTime = "12:40")),
            currentWeek = 1,
        )
        assertEquals(1, stats.morningSections)
        assertEquals(1, stats.noonSections)
        assertEquals(0, stats.eveningSections)
    }

    @Test
    fun `utilization malformed clock ignored entirely`() {
        val stats = StatisticsService.calculateTimeUtilization(
            listOf(
                course("bad", "课bad", 1, 1, 1, startTime = "25:00", endTime = "26:00"),
                course("a", "课a", 2, 1, 1, startTime = "08:00", endTime = "09:40"),
            ),
            currentWeek = 1,
        )
        assertEquals("08:00", stats.earliestStart)
        assertEquals("09:40", stats.latestEnd)
        assertEquals(1, stats.morningSections)
        assertEquals(0, stats.eveningSections)
    }

    // ========== calculateVenueStats（Dart 测试抄录 service_test:720-737） ==========

    @Test
    fun `venue ranks rooms and buildings`() {
        val courses = listOf(course("1", "数学", 1, 1, 2), course("2", "英语", 2, 1, 2, CourseNature.ELECTIVE))
        val stats = StatisticsService.calculateVenueStats(courses, currentWeek = 16)
        assertTrue(stats.topRooms.isNotEmpty())
        assertEquals(32, stats.topRooms.first().visits) // 同一教室 2 条 × 16 周
        assertTrue(stats.buildings.isNotEmpty())
        assertEquals("教室", stats.buildings.first().name) // 无前缀 → 原样
    }

    // ========== calculateTeacherStats（Dart 测试抄录 service_test:739-754） ==========

    @Test
    fun `teacher stats aggregate sections`() {
        val courses = listOf(
            course("1", "数学", 1, 1, 2),
            course("2", "物理", 2, 1, 2),
            course("3", "英语", 3, 1, 2, CourseNature.ELECTIVE),
        )
        val stats = StatisticsService.calculateTeacherStats(courses, currentWeek = 16)
        assertEquals(1, stats.size)
        assertEquals(96, stats[0].sections) // 3 门 × 2 节 × 16 周
        assertEquals(3, stats[0].courseCount)
    }

    @Test
    fun `teacher stats skips blank teacher and inactive courses`() {
        // 人推边界：teacher.trim() 为空跳过；activeWeeks==0 跳过（Dart 逐行 service:768-772）
        val courses = listOf(
            course("1", "数学", 1, 1, 2).copy(teacher = "  "),
            course("2", "物理", 2, 1, 2, startWeek = 10),
        )
        assertTrue(StatisticsService.calculateTeacherStats(courses, currentWeek = 5).isEmpty())
    }

    // ========== calculateWeeklyComparison（Dart 测试抄录 service_test:756-773） ==========

    @Test
    fun `comparison across weeks`() {
        val courses = listOf(course("1", "数学", 1, 1, 2), course("2", "英语", 2, 1, 2, CourseNature.ELECTIVE))
        val cmp = StatisticsService.calculateWeeklyComparison(courses, currentWeek = 10, semesterWeekCount = 16)
        assertEquals(4, cmp.weekSections)
        assertEquals(4, cmp.lastWeekSections)
        assertEquals(0, cmp.deltaVsLastWeek)
        assertEquals(4.0, cmp.semesterAverageSections, 0.001) // 2 门 × 2 节 × 10 周 / 10 = 4.0
        assertEquals(0.0, cmp.deltaVsAverage, 0.001)
    }

    @Test
    fun `comparison current week out of range`() {
        // 人推边界：currentWeek > semesterWeekCount → weekSections = 0（Dart 逐行 service:799-801），
        // 但 lastWeek（第 16 周）仍按 calculate 正常计算。
        val courses = listOf(course("1", "数学", 1, 1, 2))
        val cmp = StatisticsService.calculateWeeklyComparison(courses, currentWeek = 17, semesterWeekCount = 16)
        assertEquals(0, cmp.weekSections)
        assertEquals(2, cmp.lastWeekSections)
        assertEquals(-2, cmp.deltaVsLastWeek)
    }
}
