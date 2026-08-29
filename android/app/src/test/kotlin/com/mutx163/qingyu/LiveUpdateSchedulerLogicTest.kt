package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class LiveUpdateSchedulerLogicTest {
    @Test
    fun legacyHolidayFlagActiveOnlyOnMatchingDate() {
        assertFalse(
            liveSchedulerIsLegacyHolidayFlagActive(
                isHoliday = false,
                isHolidayDate = "2026-04-13",
                year = 2026,
                month = 4,
                dayOfMonth = 13,
            ),
        )
        assertFalse(
            liveSchedulerIsLegacyHolidayFlagActive(
                isHoliday = true,
                isHolidayDate = null,
                year = 2026,
                month = 4,
                dayOfMonth = 13,
            ),
        )
        assertTrue(
            liveSchedulerIsLegacyHolidayFlagActive(
                isHoliday = true,
                isHolidayDate = "2026-04-13",
                year = 2026,
                month = 4,
                dayOfMonth = 13,
            ),
        )
        assertFalse(
            liveSchedulerIsLegacyHolidayFlagActive(
                isHoliday = true,
                isHolidayDate = "2026-04-13",
                year = 2026,
                month = 4,
                dayOfMonth = 14,
            ),
        )
    }

    @Test
    fun weekCalculationSurvivesDstTransitionInEuropeBerlin() {
        val previousTimeZone = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("Europe/Berlin"))
            val semesterStart = calendarOf(2026, Calendar.MARCH, 2, 8, 0).timeInMillis
            val week5Monday = calendarOf(2026, Calendar.MARCH, 30, 8, 0).timeInMillis

            assertEquals(
                5,
                liveSchedulerCalculateWeekForDate(
                    semesterStartMillis = semesterStart,
                    currentWeek = 1,
                    dateMillis = week5Monday,
                ),
            )
        } finally {
            TimeZone.setDefault(previousTimeZone)
        }
    }

    @Test
    fun findActiveSelectionHonorsBlockedUntilBetweenConsecutiveClasses() {
        val semesterStart = calendarOf(2026, Calendar.MARCH, 2, 8, 0).timeInMillis
        val snapshot = LiveSchedulerTestSnapshot(
            currentWeek = 5,
            semesterStartMillis = semesterStart,
            courses = listOf(
                LiveSchedulerTestCourse(
                    id = "course-a",
                    dayOfWeek = 1,
                    startSection = 1,
                    endSection = 2,
                    startTime = "08:00",
                    endTime = "09:40",
                    startWeek = 1,
                    endWeek = 16,
                ),
                LiveSchedulerTestCourse(
                    id = "course-b",
                    dayOfWeek = 1,
                    startSection = 3,
                    endSection = 4,
                    startTime = "09:50",
                    endTime = "11:30",
                    startWeek = 1,
                    endWeek = 16,
                ),
            ),
        )
        val mondayDuringFirstClass = calendarOf(2026, Calendar.MARCH, 30, 9, 0).timeInMillis
        val mondayBeforeSecondClass = calendarOf(2026, Calendar.MARCH, 30, 9, 45).timeInMillis

        assertEquals(
            LiveSchedulerActiveSelection("course-a", "duringClass"),
            liveSchedulerFindActiveSelection(snapshot, mondayDuringFirstClass),
        )
        assertEquals(
            LiveSchedulerActiveSelection("course-b", "beforeClass"),
            liveSchedulerFindActiveSelection(snapshot, mondayBeforeSecondClass),
        )
    }

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

    @Test
    fun calendarWeekDoesNotClampToSemesterWeekCount() {
        val semesterStart = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis
        val week17Monday = calendarOf(2026, Calendar.JUNE, 15, 8, 30).timeInMillis

        assertEquals(
            17,
            liveSchedulerCalculateCalendarWeekForDate(
                semesterStartMillis = semesterStart,
                currentWeek = 1,
                dateMillis = week17Monday,
            ),
        )
        assertEquals(
            16,
            liveSchedulerCalculateWeekForDate(
                semesterStartMillis = semesterStart,
                currentWeek = 1,
                dateMillis = week17Monday,
                semesterWeekCount = 16,
            ),
        )
    }

    @Test
    fun courseNotActiveAfterEndWeekOnCalendarWeek17() {
        assertFalse(
            liveSchedulerCourseIsInWeek(
                week = 17,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = false,
                customWeeks = null,
            ),
        )
        assertTrue(
            liveSchedulerCourseIsInWeek(
                week = 16,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = false,
                customWeeks = null,
            ),
        )
    }

    @Test
    fun weekBeforeSemesterReturnsZeroLikeFlutter() {
        val semesterStart = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis
        val beforeSemester = calendarOf(2026, Calendar.FEBRUARY, 16, 8, 30).timeInMillis

        assertEquals(
            0,
            liveSchedulerCalculateCalendarWeekForDate(
                semesterStartMillis = semesterStart,
                currentWeek = 1,
                dateMillis = beforeSemester,
            ),
        )
        assertFalse(
            liveSchedulerCourseIsInWeek(
                week = 0,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = false,
                customWeeks = null,
            ),
        )
    }

    @Test
    fun suspendedWeeksExcludeCourseFromActiveWeek() {
        assertFalse(
            liveSchedulerCourseIsActiveInWeek(
                week = 5,
                suspendedWeeks = listOf(5),
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = false,
                customWeeks = null,
            ),
        )
    }

    @Test
    fun holidayDateBlocksSelection() {
        assertTrue(
            liveSchedulerIsDateHoliday(
                holidayDates = setOf("2026-04-13"),
                holidayOverrideEnabled = false,
                enableHolidayMarking = true,
                year = 2026,
                month = 4,
                dayOfMonth = 13,
            ),
        )
    }

    @Test
    fun adjustedWorkdayBeatsHolidayOverride() {
        assertFalse(
            liveSchedulerIsDateHoliday(
                holidayDates = emptySet(),
                holidayOverrideEnabled = true,
                enableHolidayMarking = true,
                year = 2026,
                month = 7,
                dayOfMonth = 18,
                adjustedWorkdayDates = setOf("2026-07-18"),
            ),
        )
        assertTrue(
            liveSchedulerIsDateHoliday(
                holidayDates = emptySet(),
                holidayOverrideEnabled = true,
                enableHolidayMarking = true,
                year = 2026,
                month = 7,
                dayOfMonth = 19,
                adjustedWorkdayDates = setOf("2026-07-18"),
            ),
        )
    }

    @Test
    fun resolveStageHonorsBeforeClassWindowAndAfterClassEnd() {
        val startAtMillis = calendarOf(2026, Calendar.MARCH, 23, 8, 0).timeInMillis
        val endAtMillis = calendarOf(2026, Calendar.MARCH, 23, 9, 40).timeInMillis

        assertNull(
            liveSchedulerResolveStage(
                nowMillis = calendarOf(2026, Calendar.MARCH, 23, 7, 30).timeInMillis,
                startAtMillis = startAtMillis,
                endAtMillis = endAtMillis,
                blockedUntilMillis = null,
                liveShowBeforeClassMinutes = 20,
                liveClassReminderStartMinutes = 0,
                endReminderLeadMillis = 600_000L,
                liveEnableBeforeClass = true,
                liveEnableDuringClass = true,
                liveEnableBeforeEnd = true,
                livePromoteDuringClass = true,
                liveShowDuringClassNotification = true,
            ),
        )
        assertEquals(
            "beforeClass",
            liveSchedulerResolveStage(
                nowMillis = calendarOf(2026, Calendar.MARCH, 23, 7, 45).timeInMillis,
                startAtMillis = startAtMillis,
                endAtMillis = endAtMillis,
                blockedUntilMillis = null,
                liveShowBeforeClassMinutes = 20,
                liveClassReminderStartMinutes = 0,
                endReminderLeadMillis = 600_000L,
                liveEnableBeforeClass = true,
                liveEnableDuringClass = true,
                liveEnableBeforeEnd = true,
                livePromoteDuringClass = true,
                liveShowDuringClassNotification = true,
            ),
        )
        assertNull(
            liveSchedulerResolveStage(
                nowMillis = calendarOf(2026, Calendar.MARCH, 23, 10, 0).timeInMillis,
                startAtMillis = startAtMillis,
                endAtMillis = endAtMillis,
                blockedUntilMillis = null,
                liveShowBeforeClassMinutes = 20,
                liveClassReminderStartMinutes = 0,
                endReminderLeadMillis = 600_000L,
                liveEnableBeforeClass = true,
                liveEnableDuringClass = true,
                liveEnableBeforeEnd = true,
                livePromoteDuringClass = true,
                liveShowDuringClassNotification = true,
            ),
        )
    }

    @Test
    fun findActiveSelectionReturnsNullWithoutSemesterStart() {
        val snapshot = buildParitySnapshot(isOddWeek = true)
        val activeNow = calendarOf(2026, Calendar.MARCH, 23, 7, 45).timeInMillis

        assertNull(
            liveSchedulerFindActiveSelection(
                snapshot = snapshot.copy(semesterStartMillis = null),
                nowMillis = activeNow,
            ),
        )
    }

    @Test
    fun findActiveSelectionMatchesFlutterVectors() {
        val semesterStart = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis
        val snapshot = buildParitySnapshot(
            semesterStartMillis = semesterStart,
            isOddWeek = true,
        )

        val activeNow = calendarOf(2026, Calendar.MARCH, 23, 7, 45).timeInMillis
        val evenWeekNow = calendarOf(2026, Calendar.MARCH, 30, 8, 30).timeInMillis
        val afterEndWeekNow = calendarOf(2026, Calendar.JUNE, 15, 8, 30).timeInMillis
        val beforeWindowNow = calendarOf(2026, Calendar.MARCH, 23, 7, 30).timeInMillis
        val afterClassNow = calendarOf(2026, Calendar.MARCH, 23, 10, 0).timeInMillis

        assertEquals(
            LiveSchedulerActiveSelection("parity-course", "beforeClass"),
            liveSchedulerFindActiveSelection(snapshot, activeNow),
        )
        assertNull(liveSchedulerFindActiveSelection(snapshot, evenWeekNow))
        assertNull(liveSchedulerFindActiveSelection(snapshot, afterEndWeekNow))
        assertNull(liveSchedulerFindActiveSelection(snapshot, beforeWindowNow))
        assertNull(liveSchedulerFindActiveSelection(snapshot, afterClassNow))
    }

    @Test
    fun findActiveSelectionReturnsNullForCustomWeeksGap() {
        val semesterStart = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis
        val snapshot = buildParitySnapshot(
            semesterStartMillis = semesterStart,
            customWeeks = listOf(2, 4, 6),
        )
        val week5Monday = calendarOf(2026, Calendar.MARCH, 23, 8, 30).timeInMillis
        val week6Monday = calendarOf(2026, Calendar.MARCH, 30, 7, 45).timeInMillis

        assertNull(liveSchedulerFindActiveSelection(snapshot, week5Monday))
        assertEquals(
            LiveSchedulerActiveSelection("parity-course", "beforeClass"),
            liveSchedulerFindActiveSelection(snapshot, week6Monday),
        )
    }

    @Test
    fun findActiveSelectionReturnsNullOnHoliday() {
        val semesterStart = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis
        val snapshot = buildParitySnapshot(
            semesterStartMillis = semesterStart,
            holidayDates = setOf("2026-04-13"),
        )
        val holidayMonday = calendarOf(2026, Calendar.APRIL, 13, 8, 30).timeInMillis

        assertNull(liveSchedulerFindActiveSelection(snapshot, holidayMonday))
    }

    @Test
    fun findActiveSelectionReturnsNullForSuspendedWeek() {
        val semesterStart = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis
        val snapshot = buildParitySnapshot(
            semesterStartMillis = semesterStart,
            suspendedWeeks = listOf(5),
        )
        val week5Monday = calendarOf(2026, Calendar.MARCH, 23, 7, 45).timeInMillis

        assertNull(liveSchedulerFindActiveSelection(snapshot, week5Monday))
    }

    @Test
    fun findActiveSelectionReturnsNullOnEvenWeekWhenOddOnly() {
        val semesterStart = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis
        val snapshot = buildParitySnapshot(
            semesterStartMillis = semesterStart,
            isOddWeek = true,
        )
        val evenWeekMonday = calendarOf(2026, Calendar.MARCH, 30, 7, 45).timeInMillis

        assertNull(liveSchedulerFindActiveSelection(snapshot, evenWeekMonday))
    }

    @Test
    fun findActiveSelectionReturnsNullAfterCourseEndWeek() {
        val semesterStart = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis
        val snapshot = buildParitySnapshot(semesterStartMillis = semesterStart)
        val week17Monday = calendarOf(2026, Calendar.JUNE, 15, 7, 45).timeInMillis

        assertNull(liveSchedulerFindActiveSelection(snapshot, week17Monday))
    }

    @Test
    fun hasActiveSelectionHelperMatchesFindActiveSelection() {
        val semesterStart = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis
        val snapshot = buildParitySnapshot(
            semesterStartMillis = semesterStart,
            isOddWeek = true,
        )
        val activeNow = calendarOf(2026, Calendar.MARCH, 23, 7, 45).timeInMillis
        val evenWeekNow = calendarOf(2026, Calendar.MARCH, 30, 7, 45).timeInMillis

        assertTrue(liveSchedulerFindActiveSelection(snapshot, activeNow) != null)
        assertNull(liveSchedulerFindActiveSelection(snapshot, evenWeekNow))
        assertNull(
            liveSchedulerFindActiveSelection(
                snapshot.copy(semesterStartMillis = null),
                activeNow,
            ),
        )
    }

    private fun buildParitySnapshot(
        semesterStartMillis: Long? = calendarOf(2026, Calendar.FEBRUARY, 23, 8, 0).timeInMillis,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        holidayDates: Set<String> = emptySet(),
    ): LiveSchedulerTestSnapshot {
        return LiveSchedulerTestSnapshot(
            currentWeek = 5,
            semesterStartMillis = semesterStartMillis,
            holidayDates = holidayDates,
            courses = listOf(
                LiveSchedulerTestCourse(
                    id = "parity-course",
                    dayOfWeek = 1,
                    startSection = 1,
                    endSection = 2,
                    startTime = "08:00",
                    endTime = "09:40",
                    startWeek = 1,
                    endWeek = 16,
                    isOddWeek = isOddWeek,
                    isEvenWeek = isEvenWeek,
                    customWeeks = customWeeks,
                    suspendedWeeks = suspendedWeeks,
                ),
            ),
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

    @Test
    fun quickActionTriggerAtFiresLeadMinutesBeforeClass() {
        val startAtMillis = 1_000_000_000L
        assertEquals(
            startAtMillis - 15 * 60_000L,
            liveSchedulerQuickActionTriggerAt(
                autoMinutes = 15,
                action = "silent",
                startAtMillis = startAtMillis,
                blockedUntilMillis = null,
                nowMillis = startAtMillis - 20 * 60_000L,
            ),
        )
    }

    @Test
    fun quickActionTriggerAtDisabledForNoneOrZeroLead() {
        val startAtMillis = 1_000_000_000L
        assertNull(
            liveSchedulerQuickActionTriggerAt(
                autoMinutes = 0,
                action = "silent",
                startAtMillis = startAtMillis,
                blockedUntilMillis = null,
                nowMillis = startAtMillis - 20 * 60_000L,
            ),
        )
        assertNull(
            liveSchedulerQuickActionTriggerAt(
                autoMinutes = 15,
                action = "none",
                startAtMillis = startAtMillis,
                blockedUntilMillis = null,
                nowMillis = startAtMillis - 20 * 60_000L,
            ),
        )
    }

    @Test
    fun quickActionTriggerAtHonorsBlockedUntilOfPreviousClass() {
        val startAtMillis = 1_000_000_000L
        val previousEnd = startAtMillis - 5 * 60_000L
        // 提前 15 分钟的触发点落进上一节课，必须被推到上一节课结束
        assertEquals(
            previousEnd,
            liveSchedulerQuickActionTriggerAt(
                autoMinutes = 15,
                action = "both",
                startAtMillis = startAtMillis,
                blockedUntilMillis = previousEnd,
                nowMillis = startAtMillis - 20 * 60_000L,
            ),
        )
    }

    @Test
    fun quickActionTriggerAtNullOnceWindowStarted() {
        val startAtMillis = 1_000_000_000L
        val triggerAt = startAtMillis - 10 * 60_000L
        assertNull(
            liveSchedulerQuickActionTriggerAt(
                autoMinutes = 10,
                action = "silent",
                startAtMillis = startAtMillis,
                blockedUntilMillis = null,
                nowMillis = triggerAt,
            ),
        )
    }

    @Test
    fun quickActionIsDueOnlyInsideLeadWindow() {
        val startAtMillis = 1_000_000_000L
        // 课前 15 分钟窗口：提前 20 分钟未到点
        assertFalse(
            liveSchedulerQuickActionIsDue(
                autoMinutes = 15,
                action = "silent",
                startAtMillis = startAtMillis,
                blockedUntilMillis = null,
                nowMillis = startAtMillis - 20 * 60_000L,
            ),
        )
        // 提前 10 分钟（窗口内）已到点
        assertTrue(
            liveSchedulerQuickActionIsDue(
                autoMinutes = 15,
                action = "silent",
                startAtMillis = startAtMillis,
                blockedUntilMillis = null,
                nowMillis = startAtMillis - 10 * 60_000L,
            ),
        )
        // 上课开始后不再补执行
        assertFalse(
            liveSchedulerQuickActionIsDue(
                autoMinutes = 15,
                action = "silent",
                startAtMillis = startAtMillis,
                blockedUntilMillis = null,
                nowMillis = startAtMillis + 60_000L,
            ),
        )
        // 被上一节课挡住时未到点
        assertFalse(
            liveSchedulerQuickActionIsDue(
                autoMinutes = 15,
                action = "silent",
                startAtMillis = startAtMillis,
                blockedUntilMillis = startAtMillis - 5 * 60_000L,
                nowMillis = startAtMillis - 10 * 60_000L,
            ),
        )
    }
}
