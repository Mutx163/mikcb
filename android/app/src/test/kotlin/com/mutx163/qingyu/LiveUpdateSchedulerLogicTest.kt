package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class LiveUpdateSchedulerLogicTest {
    @Test
    fun customWeeksOverrideRangeAndParity() {
        assertFalse(
            liveSchedulerCourseIsInWeek(
                week = 3,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = true,
                customWeeks = listOf(2, 4, 6),
            )
        )

        assertTrue(
            liveSchedulerCourseIsInWeek(
                week = 3,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = true,
                customWeeks = listOf(1, 3, 5),
            )
        )
    }

    @Test
    fun weekCalculationUsesMondayAnchorLikeFlutter() {
        val semesterStart = calendarOf(2026, Calendar.MARCH, 25, 8, 0).timeInMillis
        val mondayNextWeek = calendarOf(2026, Calendar.MARCH, 30, 8, 0).timeInMillis

        assertEquals(
            2,
            liveSchedulerCalculateWeekForDate(
                semesterStartMillis = semesterStart,
                currentWeek = 1,
                dateMillis = mondayNextWeek,
            )
        )
    }

    @Test
    fun weekCalculationFallsBackToCurrentWeekWithoutSemesterStart() {
        assertEquals(
            7,
            liveSchedulerCalculateWeekForDate(
                semesterStartMillis = null,
                currentWeek = 7,
                dateMillis = calendarOf(2026, Calendar.APRIL, 4, 10, 0).timeInMillis,
            )
        )
    }

    @Test
    fun weekCalculationClampsToSemesterWeekCount() {
        val semesterStart = calendarOf(2026, Calendar.MARCH, 2, 8, 0).timeInMillis
        val afterSemester = calendarOf(2026, Calendar.JUNE, 1, 8, 0).timeInMillis

        assertEquals(
            12,
            liveSchedulerCalculateWeekForDate(
                semesterStartMillis = semesterStart,
                currentWeek = 1,
                dateMillis = afterSemester,
                semesterWeekCount = 12,
            )
        )
    }

    private fun calendarOf(
        year: Int,
        month: Int,
        dayOfMonth: Int,
        hour: Int,
        minute: Int,
    ): Calendar {
        return Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month)
            set(Calendar.DAY_OF_MONTH, dayOfMonth)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }
}
