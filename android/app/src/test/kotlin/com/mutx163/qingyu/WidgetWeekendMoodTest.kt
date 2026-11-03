package com.mutx163.qingyu

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「周末文案」档位落到卡片展示层的两处关键规则（2026-10 周末空态）。
 *
 * 纯逻辑判据在 `WidgetHolidayLogicTest` 里逐条钉住；这里只测展示侧的两条
 * 容易回退的契约：
 * 1. `isShowingTomorrowCourses` 必须让位给周末文案——它是唯一正源，
 *    `test/architecture/widget_tomorrow_gate_single_source_test.dart` 盯着
 *    六个 Provider 不许自己内联一份，所以规则只能落在这里。
 * 2. `dayOffKind` 把「假期 / 周末 / 即将周末」合成一个谓词，六张卡片共用。
 */
class WidgetWeekendMoodTest {
    private fun snapshot(
        state: String = "no_course",
        weekendMood: WidgetWeekendMood = WidgetWeekendMood.NONE,
        tomorrowCourseCount: Int = 0,
        examName: String? = null,
        heightAdjustment: Double = 0.0,
        cornerRadius: Double = 16.0,
    ) = TodayWidgetSnapshotInfo(
        profileName = "默认课表",
        currentWeek = 6,
        state = state,
        backgroundStyle = "solid",
        showLocation = true,
        showCountdown = true,
        countdownTextStyle = "smart",
        hideCompletedCourses = false,
        heightAdjustment = heightAdjustment,
        cornerRadius = cornerRadius,
        totalTodayCourseCount = 0,
        todayCourses = emptyList(),
        visibleTodayCourses = emptyList(),
        nextExamName = examName,
        highlightedCourse = null,
        nextCourse = null,
        nextExamDate = null,
        nextExamDaysUntil = null,
        nextExamLocation = null,
        nextExamStartTime = null,
        nextExamEndTime = null,
        tomorrowCourses = List(tomorrowCourseCount) { index ->
            TodayWidgetCourseInfo(
                id = "tomorrow-$index",
                name = "线性代数",
                shortName = null,
                location = "C305",
                startTime = "08:00",
                endTime = "09:40",
            )
        },
        weekendMood = weekendMood,
    )

    @Test
    fun dayOffKindCoversHolidayAndBothWeekendMoods() {
        assertEquals(TodayWidgetSupport.DayOffKind.NONE, TodayWidgetSupport.dayOffKind(null))
        assertEquals(
            TodayWidgetSupport.DayOffKind.HOLIDAY,
            TodayWidgetSupport.dayOffKind(snapshot(state = "holiday")),
        )
        assertEquals(
            TodayWidgetSupport.DayOffKind.WEEKEND,
            TodayWidgetSupport.dayOffKind(snapshot(weekendMood = WidgetWeekendMood.REST)),
        )
        assertEquals(
            TodayWidgetSupport.DayOffKind.WEEKEND_AHEAD,
            TodayWidgetSupport.dayOffKind(snapshot(weekendMood = WidgetWeekendMood.AHEAD)),
        )
        assertEquals(
            TodayWidgetSupport.DayOffKind.NONE,
            TodayWidgetSupport.dayOffKind(snapshot()),
        )
    }

    @Test
    fun isDayOffIsTrueForHolidayAndWeekendMoods() {
        assertFalse(TodayWidgetSupport.isDayOff(snapshot(state = "ongoing")))
        assertTrue(TodayWidgetSupport.isDayOff(snapshot(state = "holiday")))
        assertTrue(TodayWidgetSupport.isDayOff(snapshot(weekendMood = WidgetWeekendMood.REST)))
        assertTrue(TodayWidgetSupport.isDayOff(snapshot(weekendMood = WidgetWeekendMood.AHEAD)))
    }

    @Test
    fun appearanceValuesEncodeAsDoubleWithDecimalPoint() {
        // Dart `HomeWidgetSnapshot.heightAdjustment/cornerRadius` 是 double：
        // `jsonEncode` 输出 `8.0`/`16.0`；Kotlin 若用 Int 会落成 `8`/`16`，跨端字节与哈希都对不上。
        val snapshot = snapshot(heightAdjustment = 8.0, cornerRadius = 16.0)
        val json = MiniJson.encode(
            linkedMapOf(
                "heightAdjustment" to snapshot.heightAdjustment,
                "cornerRadius" to snapshot.cornerRadius,
            ),
        )
        assertTrue(json, json.contains("\"heightAdjustment\":8.0"))
        assertTrue(json, json.contains("\"cornerRadius\":16.0"))
    }

    @Test
    fun tomorrowPreviewYieldsToWeekendCopy() {
        // 周六没课、明天（周日/周一）有课：卡片该说「周末愉快」，不是明天的列表。
        assertFalse(
            TodayWidgetSupport.isShowingTomorrowCourses(
                snapshot(weekendMood = WidgetWeekendMood.REST, tomorrowCourseCount = 3),
            ),
        )
        assertFalse(
            TodayWidgetSupport.isShowingTomorrowCourses(
                snapshot(state = "completed", weekendMood = WidgetWeekendMood.AHEAD, tomorrowCourseCount = 3),
            ),
        )
    }

    @Test
    fun tomorrowPreviewStillWorksWithoutWeekendMood() {
        // 工作日上完课 / 没课时照旧切到明天，这条不能跟着一起改坏。
        assertTrue(
            TodayWidgetSupport.isShowingTomorrowCourses(
                snapshot(state = "completed", tomorrowCourseCount = 2),
            ),
        )
        assertTrue(
            TodayWidgetSupport.isShowingTomorrowCourses(
                snapshot(state = "no_course", tomorrowCourseCount = 1),
            ),
        )
        // 周末没课 + 明天也没课：仍然不切。
        assertFalse(
            TodayWidgetSupport.isShowingTomorrowCourses(
                snapshot(weekendMood = WidgetWeekendMood.REST, tomorrowCourseCount = 0),
            ),
        )
    }

    @Test
    fun liveExamStillBeatsWeekendCopy() {
        // 周末撞上正在进行的考试：考试信息优先，周末文案让位。
        val examOngoing = snapshot(
            weekendMood = WidgetWeekendMood.REST,
            tomorrowCourseCount = 2,
            examName = "期末考试",
        ).copy(
            nextExamDaysUntil = 0,
            nextExamStartTime = "00:00",
            nextExamEndTime = "23:59",
        )
        assertTrue(TodayWidgetSupport.isExamOngoing(examOngoing))
        assertFalse(TodayWidgetSupport.isShowingTomorrowCourses(examOngoing))
    }
}
