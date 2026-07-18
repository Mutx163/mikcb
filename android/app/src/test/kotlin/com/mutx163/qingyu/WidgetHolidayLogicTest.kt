package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
}
