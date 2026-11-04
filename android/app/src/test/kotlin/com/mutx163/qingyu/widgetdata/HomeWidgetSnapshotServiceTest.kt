package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.util.Locale

/**
 * 快照组装纯逻辑的端口测试（移植 lib/services/home_widget_snapshot_service.dart）。
 *
 * 期望值来源：test/services/home_widget_snapshot_service_test.dart 既有用例
 * （[Dart抄录]，日期/课程/断言逐条对齐），少数边界按注释规则推演（[Dart推演]）。
 */
class HomeWidgetSnapshotServiceTest {

    private val service = HomeWidgetSnapshotService()

    private val now: LocalDateTime = LocalDateTime.of(2026, 3, 27, 14, 30) // 周五

    private fun course(
        id: String,
        name: String,
        startSection: Int = 1,
        endSection: Int = 2,
        startTime: String,
        endTime: String,
        color: String = "#2196F3",
    ): Course = Course(
        id = id, name = name, teacher = "张老师", location = "A101",
        dayOfWeek = now.dayOfWeek.value, startSection = startSection,
        endSection = endSection, startTime = startTime, endTime = endTime, color = color,
    )

    private val finished = course("finished", "高等数学", startTime = "08:00", endTime = "09:35")
    private val ongoing = course("ongoing", "大学英语", startSection = 5, endSection = 6, startTime = "14:00", endTime = "15:35")
    private val upcoming = course("upcoming", "程序设计", startSection = 7, endSection = 8, startTime = "16:00", endTime = "17:35")

    @Test
    fun hideCompletedCoursesKeepsDailyState() { // [Dart抄录] hide completed 用例
        val settings = WidgetSettingsFace().copy(
            widgetHideCompletedCourses = true,
            widgetHeightAdjustment = 8.0,
            widgetCornerRadius = 16.0,
        )
        val snapshot = service.build(
            profileId = "profile-1",
            profileName = "默认课表",
            currentWeek = 6,
            settings = settings,
            todayCourses = listOf(finished, ongoing, upcoming),
            now = now,
        )
        assertEquals(HomeWidgetSnapshotState.ONGOING, snapshot.state)
        assertEquals(3, snapshot.totalTodayCourseCount)
        assertEquals(8.0, snapshot.heightAdjustment, 0.0)
        assertEquals(16.0, snapshot.cornerRadius, 0.0)
        // Dart `HomeWidgetSnapshot.heightAdjustment/cornerRadius` 是 double，
        // `jsonEncode` 输出 `8.0`/`16.0`；Kotlin 若用 Int 会落成 `8`/`16`，跨端字节与哈希都对不上。
        val json = MiniJson.encode(snapshot.toJson())
        assertTrue(json, json.contains("\"heightAdjustment\":8.0"))
        assertTrue(json, json.contains("\"cornerRadius\":16.0"))
        assertEquals(3, snapshot.todayCourses.size)
        assertEquals(listOf("ongoing", "upcoming"), snapshot.visibleTodayCourses.map { it.id })
        assertEquals("ongoing", snapshot.highlightedCourse?.id)
    }

    @Test
    fun exactEndTimeCountsAsFinished() { // [Dart抄录] 09:40 整点 = 已结束
        val settings = WidgetSettingsFace()
        val testNow = LocalDateTime.of(2026, 3, 27, 9, 40)
        val snapshot = service.build(
            profileId = "profile-1",
            profileName = "默认课表",
            currentWeek = 6,
            settings = settings,
            todayCourses = listOf(
                course("finished-now", "高等数学", startTime = "08:00", endTime = "09:40"),
                course("next-course", "大学英语", startSection = 3, endSection = 4, startTime = "10:10", endTime = "11:50"),
            ),
            now = testNow,
        )
        assertEquals(HomeWidgetSnapshotState.UPCOMING, snapshot.state)
        assertEquals("next-course", snapshot.highlightedCourse?.id)
        assertEquals("next-course", snapshot.nextCourseSummary?.id)
    }

    @Test
    fun refreshTriggersIncludeExactEndBoundary() { // [Dart抄录] 09:40 边界必须进触发点
        val triggers = service.buildRefreshTriggers(
            todayCourses = listOf(course("course-1", "高等数学", startTime = "08:00", endTime = "09:40")),
            now = LocalDateTime.of(2026, 3, 27, 8, 30),
        )
        val expected = WidgetDataClock.toEpochMillis(LocalDateTime.of(2026, 3, 27, 9, 40))
        assertTrue(triggers.contains(expected))
    }

    @Test
    fun dedupJsonExcludesGeneratedAtMillis() { // [Dart抄录] 内容相同则去重签名相同
        val settings = WidgetSettingsFace()
        val courses = listOf(
            Course(
                id = "course-1", name = "高等数学", teacher = "张老师", location = "A101",
                dayOfWeek = 1, startSection = 1, endSection = 2, startTime = "08:00", endTime = "09:40",
            ),
        )
        val first = service.build(
            profileId = "profile-1", profileName = "默认课表", currentWeek = 6,
            settings = settings, todayCourses = courses,
            now = LocalDateTime.of(2026, 3, 27, 8, 0),
        )
        val second = service.build(
            profileId = "profile-1", profileName = "默认课表", currentWeek = 6,
            settings = settings, todayCourses = courses,
            now = LocalDateTime.of(2026, 3, 27, 8, 1),
        )
        assertTrue(first.generatedAtMillis != second.generatedAtMillis)
        assertTrue(first.toJson().containsKey("generatedAtMillis"))
        assertFalse(first.toDedupJson().containsKey("generatedAtMillis"))
        assertEquals(MiniJson.encode(second.toDedupJson()), MiniJson.encode(first.toDedupJson()))
    }

    @Test
    fun accentModeAndColorCarryThrough() { // [Dart抄录] 档位与颜色键名不能漂
        val modes = listOf(WidgetCourseAccentModeData.OFF, WidgetCourseAccentModeData.BAR, WidgetCourseAccentModeData.BAR_AND_TEXT)
        for (mode in modes) {
            val settings = WidgetSettingsFace().copy(widgetCourseAccentMode = mode)
            val snapshot = service.build(
                profileId = "profile-1", profileName = "默认课表", currentWeek = 6,
                settings = settings,
                todayCourses = listOf(course("first", "高等数学", startTime = "08:00", endTime = "09:35", color = "#22C55E")),
                now = LocalDateTime.of(2026, 3, 27, 8, 0),
            )
            assertEquals(mode, snapshot.courseAccentMode)
            assertEquals(mode.value, snapshot.toJson()["courseAccentMode"])
            assertEquals("#22C55E", snapshot.todayCourses.single().color)
            val firstCourse = (snapshot.toJson()["todayCourses"] as List<*>).first() as Map<*, *>
            assertEquals("#22C55E", firstCourse["color"])
        }
        // 假期分支同样带档位
        val holiday = service.build(
            profileId = "profile-1", profileName = "默认课表", currentWeek = 6,
            settings = WidgetSettingsFace().copy(widgetCourseAccentMode = WidgetCourseAccentModeData.BAR),
            todayCourses = emptyList(),
            now = LocalDateTime.of(2026, 3, 27, 8, 0),
            isHoliday = true,
            holidayName = "清明",
        )
        assertEquals(WidgetCourseAccentModeData.BAR, holiday.courseAccentMode)
        assertEquals("bar", holiday.toJson()["courseAccentMode"])
    }

    @Test
    fun holidayStateClearsCoursesButKeepsExamCountdown() { // [Dart抄录/推演] 假期态自转
        val exam = ExamFace(
            id = "e1", name = "期末考试",
            dateTime = LocalDateTime.of(2026, 4, 2, 0, 0),
            startTime = "09:00", endTime = "11:00", location = "S101",
        )
        val snapshot = service.build(
            profileId = "profile-1", profileName = "默认课表", currentWeek = 6,
            settings = WidgetSettingsFace(),
            todayCourses = listOf(ongoing),
            now = now,
            nextExam = exam,
            isHoliday = true,
            holidayName = "清明",
        )
        assertEquals(HomeWidgetSnapshotState.HOLIDAY, snapshot.state)
        assertEquals(0, snapshot.totalTodayCourseCount)
        assertTrue(snapshot.todayCourses.isEmpty())
        assertEquals("期末考试", snapshot.nextExamFace?.name)
        assertEquals("2026-04-02", snapshot.nextExamDate)
        assertEquals("S101", snapshot.nextExamFace?.location)
        assertEquals("09:00", snapshot.nextExamFace?.startTime)
        assertFalse(snapshot.showCountdown) // 假期态强制关倒计时
        assertEquals("清明", snapshot.holidayName)
    }

    @Test
    fun holidayWithoutNameFallsBackToPlaceholder() { // [Dart抄录] holidayName ?? 'Holiday'
        val snapshot = service.build(
            profileId = "profile-1", profileName = "默认课表", currentWeek = 6,
            settings = WidgetSettingsFace(), todayCourses = emptyList(),
            now = now, isHoliday = true,
        )
        assertEquals("Holiday", snapshot.holidayName)
    }

    // —— 周末文案档位（对应 Dart「周末文案档位」group）——

    private fun fridayCourse(id: String, startTime: String, endTime: String): Course =
        Course(
            id = id, name = "高等数学", teacher = "张老师", location = "A101",
            dayOfWeek = 5, startSection = 1, endSection = 2, startTime = startTime, endTime = endTime,
        )

    private fun buildOn(
        now: LocalDateTime,
        todayCourses: List<Course> = emptyList(),
        tomorrowCourses: List<Course> = emptyList(),
        originalTodayCourseCount: Int = 0,
        tomorrowDayOfWeek: Int = 0,
        isHoliday: Boolean = false,
        isAdjustedWorkdayToday: Boolean = false,
        isAdjustedWorkdayTomorrow: Boolean = false,
    ): HomeWidgetSnapshot = service.build(
        profileId = "profile-1",
        profileName = "默认课表",
        currentWeek = 6,
        settings = WidgetSettingsFace(),
        todayCourses = todayCourses,
        tomorrowCourses = tomorrowCourses,
        tomorrowDayOfWeek = tomorrowDayOfWeek,
        originalTodayCourseCount = originalTodayCourseCount,
        now = now,
        isHoliday = isHoliday,
        isAdjustedWorkdayToday = isAdjustedWorkdayToday,
        isAdjustedWorkdayTomorrow = isAdjustedWorkdayTomorrow,
    )

    @Test
    fun saturdayNoCoursesRestButNotHolidayState() { // [Dart抄录] 2026-03-28 周六
        val snapshot = buildOn(LocalDateTime.of(2026, 3, 28, 10, 0))
        assertEquals(WeekendMoodData.REST, snapshot.weekendMood)
        assertEquals(HomeWidgetSnapshotState.NO_COURSE, snapshot.state)
        assertNull(snapshot.holidayName)
        assertEquals("no_course", snapshot.toJson()["state"])
        assertEquals("rest", snapshot.toJson()["weekendMood"])
    }

    @Test
    fun sundayNoCoursesRest() { // [Dart抄录] 03-29 周日
        val snapshot = buildOn(LocalDateTime.of(2026, 3, 29, 21, 0))
        assertEquals(WeekendMoodData.REST, snapshot.weekendMood)
    }

    @Test
    fun saturdayWithCoursesNone() { // [Dart抄录]
        val snapshot = buildOn(
            LocalDateTime.of(2026, 3, 28, 10, 0),
            todayCourses = listOf(fridayCourse("sat", "09:00", "11:00")),
        )
        assertEquals(WeekendMoodData.NONE, snapshot.weekendMood)
        assertEquals(HomeWidgetSnapshotState.ONGOING, snapshot.state)
        assertEquals("sat", snapshot.highlightedCourse?.id)
    }

    @Test
    fun saturdayAllSuspendedNone() { // [Dart抄录] 周六课全停 → completed + none
        val snapshot = buildOn(
            LocalDateTime.of(2026, 3, 28, 10, 0),
            originalTodayCourseCount = 2,
        )
        assertEquals(WeekendMoodData.NONE, snapshot.weekendMood)
        assertEquals(HomeWidgetSnapshotState.COMPLETED, snapshot.state)
    }

    @Test
    fun adjustedWorkdaySaturdayNone() { // [Dart抄录] 2026-05-09 周六补班
        val snapshot = buildOn(
            LocalDateTime.of(2026, 5, 9, 10, 0),
            isAdjustedWorkdayToday = true,
        )
        assertEquals(WeekendMoodData.NONE, snapshot.weekendMood)
    }

    @Test
    fun fridayLastMinuteAhead() { // [Dart抄录] 最后一节课下课那一分钟
        val snapshot = buildOn(
            LocalDateTime.of(2026, 3, 27, 17, 35),
            todayCourses = listOf(fridayCourse("last", "14:00", "17:35")),
        )
        assertEquals(WeekendMoodData.AHEAD, snapshot.weekendMood)
        assertEquals(HomeWidgetSnapshotState.COMPLETED, snapshot.state)
    }

    @Test
    fun fridayWithRemainingNone() { // [Dart抄录]
        val snapshot = buildOn(
            LocalDateTime.of(2026, 3, 27, 15, 50),
            todayCourses = listOf(fridayCourse("last", "16:00", "17:35")),
        )
        assertEquals(WeekendMoodData.NONE, snapshot.weekendMood)
        assertEquals(HomeWidgetSnapshotState.UPCOMING, snapshot.state)
        assertEquals("last", snapshot.highlightedCourse?.id)
    }

    @Test
    fun fridayAdjustedTomorrowNone() { // [Dart抄录] 明天补班
        val snapshot = buildOn(
            LocalDateTime.of(2026, 3, 27, 18, 0),
            todayCourses = listOf(fridayCourse("last", "14:00", "17:35")),
            isAdjustedWorkdayTomorrow = true,
        )
        assertEquals(WeekendMoodData.NONE, snapshot.weekendMood)
    }

    @Test
    fun holidayBeatsWeekendMood() { // [Dart抄录] 2026-10-01 法定假期
        val snapshot = buildOn(LocalDateTime.of(2026, 10, 1, 10, 0), isHoliday = true)
        assertEquals(WeekendMoodData.NONE, snapshot.weekendMood)
        assertEquals(HomeWidgetSnapshotState.HOLIDAY, snapshot.state)
        assertEquals("none", snapshot.toJson()["weekendMood"])
    }

    @Test
    fun weekendNoCoursesStillCarriesTomorrow() { // [Dart抄录] 明天课程随快照下发
        val snapshot = buildOn(
            LocalDateTime.of(2026, 3, 28, 10, 0),
            tomorrowDayOfWeek = 1,
            tomorrowCourses = listOf(
                Course(
                    id = "mon", name = "线性代数", teacher = "王老师", location = "C305",
                    dayOfWeek = 1, startSection = 3, endSection = 4, startTime = "10:10", endTime = "11:50",
                ),
            ),
        )
        assertEquals(WeekendMoodData.REST, snapshot.weekendMood)
        assertEquals("mon", snapshot.tomorrowCourses.single().id)
        assertEquals(1, snapshot.tomorrowDayOfWeek)
    }

    @Test
    fun weekendMoodEntersDedupJson() { // [Dart抄录] 档位变了必须重推
        val friday = listOf(fridayCourse("last", "14:00", "17:35"))
        val before = buildOn(LocalDateTime.of(2026, 3, 27, 17, 34), todayCourses = friday)
        val after = buildOn(LocalDateTime.of(2026, 3, 27, 17, 35), todayCourses = friday)
        assertEquals(WeekendMoodData.NONE, before.weekendMood)
        assertEquals(WeekendMoodData.AHEAD, after.weekendMood)
        assertEquals("none", before.toDedupJson()["weekendMood"])
        assertEquals("ahead", after.toDedupJson()["weekendMood"])
        assertTrue(
            MiniJson.encode(before.toDedupJson()) != MiniJson.encode(after.toDedupJson()),
        )
    }

    @Test
    fun showTomorrowFalseStripsTomorrowCourses() { // [Dart推演] showTomorrowCourses=false → 空列表
        val snapshot = service.build(
            profileId = "profile-1", profileName = "默认课表", currentWeek = 6,
            settings = WidgetSettingsFace(),
            todayCourses = emptyList(),
            tomorrowCourses = listOf(fridayCourse("mon", "08:00", "09:40")),
            tomorrowDayOfWeek = 6,
            showTomorrowCourses = false,
            now = LocalDateTime.of(2026, 3, 27, 18, 0),
        )
        assertTrue(snapshot.tomorrowCourses.isEmpty())
        assertEquals(6, snapshot.tomorrowDayOfWeek) // 星期号照带，列表为空
    }

    @Test
    fun countdownLeadGate() { // [Dart推演] upcoming + lead 分钟内才开倒计时
        // 07:50（08:00 课前 10 分钟，threshold=07:40）：已进入 lead=20 窗口 → 开
        val settings = WidgetSettingsFace().copy(widgetShowCountdown = true, widgetCountdownLeadMinutes = 20)
        val early = service.build(
            profileId = "p", profileName = "n", currentWeek = 6, settings = settings,
            todayCourses = listOf(course("c", "高数", startTime = "08:00", endTime = "09:40")),
            now = LocalDateTime.of(2026, 3, 27, 7, 50),
        )
        assertEquals(HomeWidgetSnapshotState.UPCOMING, early.state)
        assertTrue(early.showCountdown)
        // 07:30（threshold=07:40 之前）：窗口外 → 关
        val outside = service.build(
            profileId = "p", profileName = "n", currentWeek = 6, settings = settings,
            todayCourses = listOf(course("c", "高数", startTime = "08:00", endTime = "09:40")),
            now = LocalDateTime.of(2026, 3, 27, 7, 30),
        )
        assertEquals(HomeWidgetSnapshotState.UPCOMING, outside.state)
        assertFalse(outside.showCountdown)
        // 07:45：08:00 前最后 15 分钟 → 已进入 lead 窗口
        val within = service.build(
            profileId = "p", profileName = "n", currentWeek = 6, settings = settings,
            todayCourses = listOf(course("c", "高数", startTime = "08:00", endTime = "09:40")),
            now = LocalDateTime.of(2026, 3, 27, 7, 45),
        )
        assertTrue(within.showCountdown)
        // lead = 0 → 恒开（upcoming 态）。lead 是显式入参（宿主把设置值传进来），
        // 与 Dart build(countdownLeadMinutes: host.settings.widgetCountdownLeadMinutes) 同形。
        val leadZero = service.build(
            profileId = "p", profileName = "n", currentWeek = 6,
            settings = WidgetSettingsFace(),
            todayCourses = listOf(course("c", "高数", startTime = "08:00", endTime = "09:40")),
            now = LocalDateTime.of(2026, 3, 27, 6, 0),
            countdownLeadMinutes = 0,
        )
        assertTrue(leadZero.showCountdown)
    }

    @Test
    fun refreshTriggerNextMinuteDuringCountdown() { // [Dart抄录] ongoing/upcoming + showCountdown → +60s
        val triggers = service.buildRefreshTriggers(
            todayCourses = listOf(course("c", "高数", startTime = "09:00", endTime = "10:00")),
            now = LocalDateTime.of(2026, 3, 27, 9, 30),
            showCountdown = true,
            state = "ongoing",
            countdownLeadMinutes = 20,
        )
        val expected = WidgetDataClock.toEpochMillis(LocalDateTime.of(2026, 3, 27, 9, 30)) + 60_000L
        assertTrue(triggers.contains(expected))
    }

    @Test
    fun refreshTriggerMidnightAlwaysPresent() { // [Dart推演] 跨天翻面
        val triggers = service.buildRefreshTriggers(
            todayCourses = emptyList(),
            now = LocalDateTime.of(2026, 3, 27, 9, 30),
        )
        val midnight = WidgetDataClock.toEpochMillis(LocalDateTime.of(2026, 3, 28, 0, 0))
        assertTrue(triggers.contains(midnight))
    }

    @Test
    fun malformedClockExcludedFromVisibilityAndTriggers() { // [Dart抄录] 25:00 必须解析失败
        val settings = WidgetSettingsFace().copy(widgetHideCompletedCourses = true)
        // 课挂在 25:00-26:00：解析失败 → 视为已结束被隐藏，且不产触发点
        val snapshot = service.build(
            profileId = "p", profileName = "n", currentWeek = 6, settings = settings,
            todayCourses = listOf(course("bad", "坏课", startTime = "25:00", endTime = "26:00")),
            now = now,
        )
        assertTrue(snapshot.visibleTodayCourses.isEmpty())
        val triggers = service.buildRefreshTriggers(
            todayCourses = listOf(course("bad", "坏课", startTime = "25:00", endTime = "26:00")),
            now = now,
        )
        // 只剩午夜触发点
        assertEquals(listOf(WidgetDataClock.toEpochMillis(LocalDateTime.of(2026, 3, 28, 0, 0))), triggers)
    }

    @Test
    fun nextExamDaysUntilUsesSnapshotNow() { // [Dart抄录] daysUntil 按 build 传入的 now 计，不读蛇形时钟
        val exam = ExamFace(
            id = "e1", name = "期末考试",
            dateTime = LocalDateTime.of(2026, 4, 2, 0, 0),
            startTime = "09:00", endTime = "11:00", location = "S101",
        )
        val snapshot = service.build(
            profileId = "p", profileName = "n", currentWeek = 6,
            settings = WidgetSettingsFace(), todayCourses = emptyList(),
            now = LocalDateTime.of(2026, 3, 27, 14, 30),
            nextExam = exam,
        )
        // 2026-03-27 → 2026-04-02 = 6 天；若误用 LocalDateTime.now()（2026-11-04）会得到负数。
        assertEquals(6, snapshot.toJson()["nextExamDaysUntil"])
    }

    @Test
    fun examTextStableUnderArabicLocale() { // [Dart抄录] padLeft 无 Locale，Kotlin 必须钉 Locale.ROOT
        val previous = Locale.getDefault()
        Locale.setDefault(Locale.forLanguageTag("ar-EG"))
        try {
            val exam = ExamFace(
                id = "e1", name = "期末考试",
                dateTime = LocalDateTime.of(2026, 4, 2, 0, 0),
                startTime = "09:00", endTime = "11:00", location = "S101",
            )
            val snapshot = service.build(
                profileId = "p", profileName = "n", currentWeek = 6,
                settings = WidgetSettingsFace(), todayCourses = emptyList(),
                now = now, nextExam = exam,
            )
            assertEquals("2026-04-02", snapshot.toJson()["nextExamDate"])
            assertEquals("09:05", WidgetDataClock.formatClock(LocalDateTime.of(2026, 4, 2, 9, 5)))
        } finally {
            Locale.setDefault(previous)
        }
    }
}
