package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetHolidayLogicTest {
    @Test
    fun customVacationMarksDayAsHoliday() {
        val entries = listOf(
            WidgetHolidayEntry(
                date = "2026-04-13",
                name = "测试假期",
                type = "vacation",
                groupId = "custom-123",
            ),
        )

        assertTrue(
            widgetResolveIsHoliday(
                entries = entries,
                dateStr = "2026-04-13",
                enableHolidayMarking = true,
                holidayOverrideEnabled = false,
            ),
        )
        assertEquals(
            "测试假期",
            widgetResolveHolidayName(entries, "2026-04-13"),
        )
        assertFalse(
            widgetResolveIsHoliday(
                entries = entries,
                dateStr = "2026-04-14",
                enableHolidayMarking = true,
                holidayOverrideEnabled = false,
            ),
        )
    }

    @Test
    fun adjustedWorkdayIsNotHolidayUnlessCustomOverride() {
        val makeupOnly = listOf(
            WidgetHolidayEntry(
                date = "2026-10-10",
                name = "调休上班",
                type = "adjusted_workday",
                groupId = "holiday-2026-1",
            ),
        )
        assertFalse(
            widgetResolveIsHoliday(
                entries = makeupOnly,
                dateStr = "2026-10-10",
                enableHolidayMarking = true,
                holidayOverrideEnabled = false,
            ),
        )

        val customOnMakeupDay = makeupOnly + WidgetHolidayEntry(
            date = "2026-10-10",
            name = "我要休息",
            type = "vacation",
            groupId = "custom-999",
        )
        assertTrue(
            widgetResolveIsHoliday(
                entries = customOnMakeupDay,
                dateStr = "2026-10-10",
                enableHolidayMarking = true,
                holidayOverrideEnabled = false,
            ),
        )
        assertEquals(
            "我要休息",
            widgetResolveHolidayName(customOnMakeupDay, "2026-10-10"),
        )
    }

    @Test
    fun markingDisabledIgnoresHolidayEntries() {
        val entries = listOf(
            WidgetHolidayEntry(
                date = "2026-05-01",
                name = "劳动节",
                type = "vacation",
                groupId = "holiday-2026-labor",
            ),
        )
        assertFalse(
            widgetResolveIsHoliday(
                entries = entries,
                dateStr = "2026-05-01",
                enableHolidayMarking = false,
                holidayOverrideEnabled = false,
            ),
        )
        assertTrue(
            widgetResolveIsHoliday(
                entries = entries,
                dateStr = "2026-05-01",
                enableHolidayMarking = false,
                holidayOverrideEnabled = true,
            ),
        )
    }

    @Test
    fun blankHolidayJsonReturnsEmptyWithoutCrashing() {
        // org.json is stubbed on pure JVM Android unit tests, so only exercise the
        // null/blank short-circuit paths that do not touch JSONObject/JSONArray.
        assertTrue(widgetParseHolidayEntriesFromHolidayDataJson(null).isEmpty())
        assertTrue(widgetParseHolidayEntriesFromHolidayDataJson("").isEmpty())
        assertTrue(widgetParseHolidayEntriesFromHolidayDataJson("   ").isEmpty())
        assertTrue(widgetParseHolidayEntriesFromCustomJson(null).isEmpty())
        assertTrue(widgetParseHolidayEntriesFromCustomJson("").isEmpty())
    }

    @Test
    fun formatDatePadsYearMonthDay() {
        assertEquals("2026-04-13", widgetFormatDate(2026, 4, 13))
        assertEquals("2026-10-01", widgetFormatDate(2026, 10, 1))
    }

    @Test
    fun builtInHolidayKeysResolveToLabels() {
        // These are the keys Flutter persists; the widget used to render them
        // verbatim (e.g. "holiday_name:mid_autumn" on Mid-Autumn Festival).
        assertEquals(WidgetHolidayLabel.NewYear, widgetHolidayLabel("holiday_name:new_year"))
        assertEquals(WidgetHolidayLabel.LaborDay, widgetHolidayLabel("holiday_name:labor_day"))
        assertEquals(WidgetHolidayLabel.NationalDay, widgetHolidayLabel("holiday_name:national_day"))
        assertEquals(WidgetHolidayLabel.SpringFestival, widgetHolidayLabel("holiday_name:spring_festival"))
        assertEquals(WidgetHolidayLabel.Qingming, widgetHolidayLabel("holiday_name:qingming"))
        assertEquals(WidgetHolidayLabel.DragonBoat, widgetHolidayLabel("holiday_name:dragon_boat"))
        assertEquals(WidgetHolidayLabel.MidAutumn, widgetHolidayLabel("holiday_name:mid_autumn"))
        assertEquals(WidgetHolidayLabel.MakeupWorkday, widgetHolidayLabel("holiday_name:makeup_workday"))
        assertEquals(WidgetHolidayLabel.Statutory, widgetHolidayLabel("holiday_name:statutory"))
    }

    @Test
    fun legacyDisplayNamesResolveToTheSameLabels() {
        // Older data (and Flutter's own localizer) also accept plain names.
        assertEquals(WidgetHolidayLabel.MidAutumn, widgetHolidayLabel("中秋节"))
        assertEquals(WidgetHolidayLabel.NewYear, widgetHolidayLabel("元旦"))
        assertEquals(WidgetHolidayLabel.MakeupWorkday, widgetHolidayLabel("调休上班"))
        assertEquals(WidgetHolidayLabel.Statutory, widgetHolidayLabel("Public holiday"))
        assertEquals(WidgetHolidayLabel.Statutory, widgetHolidayLabel("Holiday"))
        assertEquals(WidgetHolidayLabel.MidAutumn, widgetHolidayLabel("  holiday_name:mid_autumn  "))
    }

    @Test
    fun customHolidayNamesHaveNoLabelSoTheyStayVerbatim() {
        assertNull(widgetHolidayLabel("学校运动会"))
        assertNull(widgetHolidayLabel("公司年会"))
        assertNull(widgetHolidayLabel(""))
        assertNull(widgetHolidayLabel("   "))
        assertNull(widgetHolidayLabel(null))
    }

    @Test
    fun adjustedWorkdayResolutionFollowsCustomRestOverride() {
        val makeupOnly = listOf(
            WidgetHolidayEntry(
                date = "2026-10-10",
                name = "调休上班",
                type = "adjusted_workday",
                groupId = "holiday-2026-1",
            ),
        )
        assertTrue(widgetResolveIsAdjustedWorkday(makeupOnly, "2026-10-10"))
        assertFalse(widgetResolveIsAdjustedWorkday(makeupOnly, "2026-10-11"))

        val customRestOnMakeupDay = makeupOnly + WidgetHolidayEntry(
            date = "2026-10-10",
            name = "我要休息",
            type = "vacation",
            groupId = "custom-999",
        )
        assertFalse(widgetResolveIsAdjustedWorkday(customRestOnMakeupDay, "2026-10-10"))
    }

    @Test
    fun weekendMoodParsingFallsBackToNoneForUnknownValues() {
        assertEquals(WidgetWeekendMood.NONE, WidgetWeekendMood.fromValue("none"))
        assertEquals(WidgetWeekendMood.REST, WidgetWeekendMood.fromValue("rest"))
        assertEquals(WidgetWeekendMood.AHEAD, WidgetWeekendMood.fromValue("ahead"))
        // 老快照没有这个键 / Flutter 塞了脏值：一律按「没有周末文案」处理。
        assertEquals(WidgetWeekendMood.NONE, WidgetWeekendMood.fromValue(null))
        assertEquals(WidgetWeekendMood.NONE, WidgetWeekendMood.fromValue(""))
        assertEquals(WidgetWeekendMood.NONE, WidgetWeekendMood.fromValue("holiday"))
        assertEquals("none", WidgetWeekendMood.NONE.value)
        assertEquals("rest", WidgetWeekendMood.REST.value)
        assertEquals("ahead", WidgetWeekendMood.AHEAD.value)
    }

    /** 与 Dart `resolveWeekendMood` 逐条同口径：周末文案只在确实没课的那天出现。 */
    private fun mood(
        dayOfWeek: Int,
        hasAnyCourse: Boolean = false,
        hasRemainingCourse: Boolean = false,
        isHolidayToday: Boolean = false,
        isAdjustedWorkdayToday: Boolean = false,
        isAdjustedWorkdayTomorrow: Boolean = false,
    ) = widgetResolveWeekendMood(
        dayOfWeek = dayOfWeek,
        hasAnyCourse = hasAnyCourse,
        hasRemainingCourse = hasRemainingCourse,
        isHolidayToday = isHolidayToday,
        isAdjustedWorkdayToday = isAdjustedWorkdayToday,
        isAdjustedWorkdayTomorrow = isAdjustedWorkdayTomorrow,
    )

    @Test
    fun weekendWithoutCoursesGetsRestMood() {
        assertEquals(WidgetWeekendMood.REST, mood(dayOfWeek = 6))
        assertEquals(WidgetWeekendMood.REST, mood(dayOfWeek = 7))
    }

    @Test
    fun weekendWithCoursesNeverClaimsTheWeekend() {
        // 还有课要上 / 课都上完了 / 课全被停课：三种都算「那天有课」。
        assertEquals(WidgetWeekendMood.NONE, mood(dayOfWeek = 6, hasAnyCourse = true, hasRemainingCourse = true))
        assertEquals(WidgetWeekendMood.NONE, mood(dayOfWeek = 6, hasAnyCourse = true))
        assertEquals(WidgetWeekendMood.NONE, mood(dayOfWeek = 7, hasAnyCourse = true))
    }

    @Test
    fun makeupWorkdayOnWeekendIsNotTheWeekend() {
        assertEquals(WidgetWeekendMood.NONE, mood(dayOfWeek = 6, isAdjustedWorkdayToday = true))
        assertEquals(WidgetWeekendMood.NONE, mood(dayOfWeek = 7, isAdjustedWorkdayToday = true))
    }

    @Test
    fun statutoryHolidayOnWeekendWinsOverWeekendMood() {
        assertEquals(WidgetWeekendMood.NONE, mood(dayOfWeek = 6, isHolidayToday = true))
        assertEquals(WidgetWeekendMood.NONE, mood(dayOfWeek = 7, isHolidayToday = true))
    }

    @Test
    fun fridayAfterLastClassAnnouncesTheWeekend() {
        assertEquals(
            WidgetWeekendMood.AHEAD,
            mood(dayOfWeek = 5, hasAnyCourse = true, hasRemainingCourse = false),
        )
        // 周五整天没排课：从零点就该显示，不等到下课。
        assertEquals(WidgetWeekendMood.AHEAD, mood(dayOfWeek = 5))
    }

    @Test
    fun fridayWithRemainingClassesKeepsShowingCourses() {
        assertEquals(
            WidgetWeekendMood.NONE,
            mood(dayOfWeek = 5, hasAnyCourse = true, hasRemainingCourse = true),
        )
    }

    @Test
    fun fridayBeforeAMakeupSaturdayIsNotTheWeekend() {
        assertEquals(
            WidgetWeekendMood.NONE,
            mood(dayOfWeek = 5, hasAnyCourse = true, isAdjustedWorkdayTomorrow = true),
        )
    }

    @Test
    fun weekdaysMondayToThursdayNeverClaimTheWeekend() {
        for (dayOfWeek in 1..4) {
            assertEquals(
                WidgetWeekendMood.NONE,
                mood(dayOfWeek = dayOfWeek),
            )
        }
    }
}
