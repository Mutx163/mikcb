package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * CourseSessionStats 移植测试。
 *
 * 期望值来源：
 * - [Dart抄录]：test/domain/course_session_stats_test.dart（学期开始 2026-09-07
 *   周一；第 1/2/3 周周三 = 09-09/09-16/09-23 是文件头手工推的锚点，逐条翻成 Kotlin）；
 * - [Dart推演]：对照 lib/domain/course_session_stats.dart 实现逐行推演；
 * - [人推]：空列表/第 0 周/负数周次边界。
 */
class CourseSessionStatsTest {

    /** 学期开始日：2026-09-07 是周一（Dart 测试同款锚点）。 */
    private val semesterStart: LocalDateTime = DartTime.dateTime(2026, 9, 7)

    private fun course(
        id: String = "c1",
        name: String = "线性代数",
        dayOfWeek: Int = 3,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 3,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        sessionNotes: Map<Int, CourseSessionNote>? = null,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
        sessionNotes = sessionNotes,
    )

    private fun settings(semesterStart: LocalDateTime?): TimetableSettings =
        TimetableSettings(semesterStartDate = semesterStart)

    private fun build(
        courses: List<Course>,
        settings: TimetableSettings = settings(semesterStart),
        tasks: List<CourseTask> = emptyList(),
        exams: List<Exam> = emptyList(),
        now: LocalDateTime = DartTime.dateTime(2026, 9, 20),
        isHoliday: ((LocalDateTime) -> Boolean)? = null,
        reminderKeys: Set<String> = emptySet(),
    ): CourseSessionStats = CourseSessionStatsCalculator.build(
        courseName = if (courses.isEmpty()) "" else courses.first().name,
        courses = courses,
        settings = settings,
        tasks = tasks,
        exams = exams,
        now = now,
        isHoliday = isHoliday,
        reminderKeys = reminderKeys,
    )

    // ---------- 课次展开 [Dart抄录] ----------

    @Test
    fun expand_weeklyCourseDatesAreRealCalendarDates() { // [Dart抄录]
        val stats = build(courses = listOf(course()))
        assertEquals(3, stats.sessions.size)
        assertEquals(
            listOf(
                DartTime.dateTime(2026, 9, 9),
                DartTime.dateTime(2026, 9, 16),
                DartTime.dateTime(2026, 9, 23),
            ),
            stats.sessions.map { it.date },
        )
        assertEquals(listOf(1, 2, 3), stats.sessions.map { it.week })
    }

    @Test
    fun expand_oddAndEvenWeekSplit() { // [Dart抄录]
        val odd = build(courses = listOf(course(endWeek = 6, isOddWeek = true)))
        val even = build(courses = listOf(course(endWeek = 6, isEvenWeek = true)))
        assertEquals(listOf(1, 3, 5), odd.sessions.map { it.week })
        assertEquals(listOf(2, 4, 6), even.sessions.map { it.week })
    }

    @Test
    fun expand_customWeeksWin() { // [Dart抄录]
        val stats = build(courses = listOf(course(endWeek = 16, customWeeks = listOf(2, 7, 11))))
        assertEquals(listOf(2, 7, 11), stats.sessions.map { it.week })
    }

    @Test
    fun expand_suspendedWeekListedButNotPlanned() { // [Dart抄录]
        val stats = build(courses = listOf(course(suspendedWeeks = listOf(2))))
        assertEquals(3, stats.sessions.size) // 停课周也要让用户看见
        assertEquals(1, stats.suspendedSessions)
        assertEquals(2, stats.plannedSessions) // 计划口径不含停课
        assertEquals(
            CourseSessionPhase.SUSPENDED,
            stats.sessions.first { it.week == 2 }.phase,
        )
    }

    @Test
    fun expand_multipleEntriesMergeAndSectionsAccumulate() { // [Dart抄录]
        val stats = build(
            courses = listOf(
                course(dayOfWeek = 1),
                course(id = "c2", startSection = 5, endSection = 6),
            ),
        )
        assertEquals(6, stats.sessions.size)
        assertEquals(setOf("c1", "c2"), stats.sessions.map { it.courseId }.toSet())
        assertEquals(12, stats.plannedSections)
    }

    // ---------- 阶段判定 [Dart抄录] ----------

    @Test
    fun phase_doneTodayUpcoming() { // [Dart抄录]
        val stats = build(courses = listOf(course()), now = DartTime.dateTime(2026, 9, 16, 14, 30))
        assertEquals(CourseSessionPhase.DONE, stats.sessions[0].phase) // 09-09
        assertEquals(CourseSessionPhase.TODAY, stats.sessions[1].phase) // 09-16
        assertEquals(CourseSessionPhase.UPCOMING, stats.sessions[2].phase) // 09-23
        assertEquals(1, stats.doneSessions)
        assertEquals(1, stats.todaySessions)
        assertEquals(1, stats.upcomingSessions)
    }

    @Test
    fun phase_timeOfDayIgnored_sameDayIsToday() { // [Dart抄录] 23:59 也算当天
        val stats = build(courses = listOf(course()), now = DartTime.dateTime(2026, 9, 16, 23, 59))
        assertEquals(CourseSessionPhase.TODAY, stats.sessions.first { it.week == 2 }.phase)
    }

    @Test
    fun phase_holidayBeatsDoneAndUpcoming_notPlanned() { // [Dart抄录]
        val stats = build(
            courses = listOf(course()),
            now = DartTime.dateTime(2026, 9, 20),
            isHoliday = { it == DartTime.dateTime(2026, 9, 16) },
        )
        assertEquals(CourseSessionPhase.HOLIDAY, stats.sessions.first { it.week == 2 }.phase)
        assertEquals(1, stats.holidaySessions)
        assertEquals(2, stats.plannedSessions)
    }

    @Test
    fun phase_suspendedBeatsHoliday() { // [Dart抄录]
        val stats = build(
            courses = listOf(course(suspendedWeeks = listOf(2))),
            isHoliday = { it == DartTime.dateTime(2026, 9, 16) },
        )
        assertEquals(CourseSessionPhase.SUSPENDED, stats.sessions.first { it.week == 2 }.phase)
    }

    @Test
    fun phase_noSemesterStart_allUndated() { // [Dart抄录]
        val stats = build(courses = listOf(course()), settings = settings(null))
        assertFalse(stats.hasCalendar)
        assertEquals(3, stats.undatedSessions)
        assertTrue(stats.sessions.all { it.date == null })
        assertEquals(0, stats.doneSessions) // 没有日期轴就不能假装「上过了」
        assertEquals(3, stats.plannedSessions) // 仍算 3 次排课
    }

    // ---------- 已有记录的对齐 [Dart抄录] ----------

    @Test
    fun notes_byWeek() { // [Dart抄录]
        val stats = build(
            courses = listOf(
                course(
                    sessionNotes = mapOf(
                        1 to CourseSessionNote(text = "第一章"),
                        3 to CourseSessionNote(text = "第三章"),
                    ),
                ),
            ),
        )
        assertEquals("第一章", stats.sessions[0].noteText)
        assertNull(stats.sessions[1].noteText)
        assertEquals("第三章", stats.sessions[2].noteText)
        assertEquals(2, stats.notedSessions)
    }

    @Test
    fun homework_flagWithoutText() { // [Dart抄录]
        val stats = build(
            courses = listOf(
                course(sessionNotes = mapOf(2 to CourseSessionNote(hasHomework = true))),
            ),
        )
        val week2 = stats.sessions.first { it.week == 2 }
        assertTrue(week2.hasHomework)
        assertFalse(week2.hasNote)
        assertEquals(1, stats.homeworkSessions)
        assertEquals(0, stats.notedSessions)
    }

    @Test
    fun homework_taskCountsTowardHomework() { // [Dart抄录]
        val stats = build(
            courses = listOf(course()),
            tasks = listOf(
                CourseTask(
                    id = "t1",
                    title = "第三章习题",
                    courseId = "c1",
                    sourceWeek = 3,
                    createdAt = DartTime.dateTime(2026, 9, 1),
                    updatedAt = DartTime.dateTime(2026, 9, 1),
                ),
            ),
        )
        val week3 = stats.sessions.first { it.week == 3 }
        assertEquals(1, week3.taskCount)
        assertTrue(week3.hasHomework)
        assertEquals(1, stats.homeworkSessions)
    }

    @Test
    fun homework_otherCourseTaskIgnored() { // [Dart抄录]
        val stats = build(
            courses = listOf(course()),
            tasks = listOf(
                CourseTask(
                    id = "t1",
                    title = "别的课作业",
                    courseId = "other",
                    sourceWeek = 1,
                    createdAt = DartTime.dateTime(2026, 9, 1),
                    updatedAt = DartTime.dateTime(2026, 9, 1),
                ),
            ),
        )
        assertEquals(0, stats.homeworkSessions)
    }

    @Test
    fun exam_countedByCourseAndCalendarDate() { // [Dart抄录]
        val stats = build(
            courses = listOf(course()),
            exams = listOf(
                Exam(
                    id = "e1",
                    courseId = "c1",
                    name = "期中",
                    dateTime = DartTime.dateTime(2026, 9, 16, 10),
                    startTime = "10:00",
                    endTime = "11:40",
                    createdAt = DartTime.dateTime(2026, 9, 1),
                    updatedAt = DartTime.dateTime(2026, 9, 1),
                ),
            ),
        )
        assertEquals(1, stats.sessions.first { it.week == 2 }.examCount)
        assertEquals(0, stats.sessions.first { it.week == 1 }.examCount)
    }

    @Test
    fun reminder_keyedByCourseAndDate() { // [Dart抄录]
        val stats = build(courses = listOf(course()), reminderKeys = setOf("c1|2026-09-16"))
        assertTrue(stats.sessions.first { it.week == 2 }.hasReminder)
        assertFalse(stats.sessions.first { it.week == 1 }.hasReminder)
        assertEquals(1, stats.reminderSessions)
    }

    @Test
    fun reminder_otherCourseKeyIgnored() { // [Dart抄录]
        val stats = build(courses = listOf(course()), reminderKeys = setOf("other|2026-09-16"))
        assertEquals(0, stats.reminderSessions)
    }

    @Test
    fun reminder_noCalendarNeverLit() { // [Dart抄录]
        val stats = build(
            courses = listOf(course()),
            settings = settings(null),
            reminderKeys = setOf("c1|2026-09-16"),
        )
        assertEquals(0, stats.reminderSessions)
    }

    // ---------- 覆盖口径 [Dart抄录] ----------

    @Test
    fun coverage_suspendedWeekWithNote_countsTowardNoted() { // [Dart抄录]
        val stats = build(
            courses = listOf(
                course(
                    endWeek = 2,
                    suspendedWeeks = listOf(2),
                    sessionNotes = mapOf(
                        1 to CourseSessionNote(text = "第一章"),
                        2 to CourseSessionNote(text = "停课前写的"),
                    ),
                ),
            ),
        )
        assertEquals(1, stats.plannedSessions) // 计划口径仍不含停课
        assertEquals(2, stats.sessions.size) // 覆盖分母 = 全部课次
        assertTrue(stats.sessions.first { it.week == 2 }.hasNote)
        assertEquals(2, stats.notedSessions)
        assertTrue(stats.notedSessions <= stats.sessions.size)
    }

    @Test
    fun coverage_allSuspendedNoted_2of2Not2of0() { // [Dart抄录] 旧口径会得到「2/0」假象
        val stats = build(
            courses = listOf(
                course(
                    endWeek = 2,
                    suspendedWeeks = listOf(1, 2),
                    sessionNotes = mapOf(
                        1 to CourseSessionNote(text = "a"),
                        2 to CourseSessionNote(text = "b"),
                    ),
                ),
            ),
        )
        assertEquals(0, stats.plannedSessions)
        assertEquals(2, stats.notedSessions)
        assertEquals(2, stats.sessions.size)
    }

    @Test
    fun coverage_holidayHomeworkCounts() { // [Dart抄录]
        val stats = build(
            courses = listOf(
                course(
                    endWeek = 2,
                    sessionNotes = mapOf(
                        1 to CourseSessionNote(hasHomework = true),
                        2 to CourseSessionNote(hasHomework = true),
                    ),
                ),
            ),
            isHoliday = { it == DartTime.dateTime(2026, 9, 16) },
        )
        assertEquals(1, stats.plannedSessions)
        assertEquals(2, stats.homeworkSessions) // 假期那次的标记同样真实存在
    }

    // ---------- 计划课时（多条目不得翻倍）[Dart抄录] ----------

    @Test
    fun plannedSections_twoEntriesPerWeek_notDoubled() { // [Dart抄录] 旧公式 5×6=30 是错的
        val stats = build(
            courses = listOf(
                course(dayOfWeek = 1), // 周一 1-2 节
                course(id = "c2", startSection = 5, endSection = 7), // 周三 5-7 节
            ),
        )
        assertEquals(6, stats.plannedSessions) // 2 个条目 × 3 周
        assertEquals(15, stats.plannedSections)
    }

    // ---------- 排序与汇总 [Dart抄录] ----------

    @Test
    fun sort_sessionsByDateAscending() { // [Dart抄录]
        val stats = build(
            courses = listOf(
                course(id = "c2", dayOfWeek = 5, startSection = 3, endSection = 4),
                course(dayOfWeek = 1),
            ),
        )
        val dates = stats.sessions.map { it.date }
        assertEquals(dates, dates.sortedBy { it })
    }

    @Test
    fun doneSections_onlyPastOnes() { // [Dart抄录]
        val stats = build(
            courses = listOf(course(endSection = 3)), // 每次 3 节
            now = DartTime.dateTime(2026, 9, 17),
        )
        assertEquals(2, stats.doneSessions) // 09-09、09-16 已过
        assertEquals(6, stats.doneSections)
    }

    @Test
    fun plannedSections_simple() { // [Dart抄录]
        val stats = build(courses = listOf(course()))
        assertEquals(2 * 3, stats.plannedSections)
    }

    @Test
    fun emptyCourses_zeroTeacherAndName() { // [Dart推演 :265] courses.isEmpty → teacher ''
        val stats = build(courses = emptyList())
        assertEquals("", stats.teacher)
        assertTrue(stats.isEmpty)
        assertEquals(0, stats.plannedSessions)
    }

    // ---------- courseOccurrenceDate [Dart抄录] ----------

    @Test
    fun occurrenceDate_firstMondayIsSemesterMonday() { // [Dart抄录]
        val date = courseOccurrenceDate(semesterStart, course(dayOfWeek = 1), 1)
        assertEquals(DartTime.dateTime(2026, 9, 7), date)
    }

    @Test
    fun occurrenceDate_midweekStartAlignsToMonday() { // [Dart抄录] 2026-09-09 是周三
        val date = courseOccurrenceDate(DartTime.dateTime(2026, 9, 9), course(dayOfWeek = 1), 1)
        assertEquals(DartTime.dateTime(2026, 9, 7), date)
    }

    @Test
    fun occurrenceDate_nullStartOrWeek0ReturnsNull() { // [Dart抄录]
        assertNull(courseOccurrenceDate(null, course(), 1))
        assertNull(courseOccurrenceDate(semesterStart, course(), 0))
        // 负周次 [人推]
        assertNull(courseOccurrenceDate(semesterStart, course(), -2))
    }

    @Test
    fun occurrenceDate_sundayIsMondayPlus6() { // [Dart抄录]
        val date = courseOccurrenceDate(semesterStart, course(dayOfWeek = 7), 1)
        assertEquals(DartTime.dateTime(2026, 9, 13), date)
    }

    @Test
    fun occurrenceDate_crossYearWeek() { // [人推] 2025-12-29 是周一：第 1 周周日 = 2026-01-04，
        // 第 2 周周日 = 2026-01-11（跨年日历顺延）
        val start = DartTime.dateTime(2025, 12, 29)
        assertEquals(DartTime.dateTime(2026, 1, 4), courseOccurrenceDate(start, course(dayOfWeek = 7), 1))
        assertEquals(DartTime.dateTime(2026, 1, 11), courseOccurrenceDate(start, course(dayOfWeek = 7), 2))
    }
}
