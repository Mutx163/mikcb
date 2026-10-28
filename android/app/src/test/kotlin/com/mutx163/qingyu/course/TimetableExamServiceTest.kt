package com.mutx163.qingyu.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * [TimetableExamService] 契约测试。期望值人推，移植自
 * `lib/services/timetable_exam_service.dart` 的语义（有一处 Dart 原注释点名过的坑，见 hasExamOnDate）。
 */
class TimetableExamServiceTest {

    private val fixedNow: LocalDateTime = LocalDateTime.of(2026, 3, 10, 12, 0)

    private class FakePort(
        courses: List<Course> = emptyList(),
        exams: List<Exam> = emptyList(),
        profiles: List<TimetableProfile> = emptyList(),
    ) : TimetableExamPort {
        override var exams: List<Exam> = ArrayList(exams)
        override var profiles: List<TimetableProfile> = ArrayList(profiles)
        val courseList: List<Course> = ArrayList(courses)
        var initializeCalls = 0
        var notifyCalls = 0
        var persistCalls = 0
        var syncReminderCalls = 0
        var invalidateWidgetCalls = 0
        var syncWidgetCalls = 0
        val loggedEvents = mutableListOf<String>()
        var failPersist = false
        override fun initialize() { initializeCalls++ }
        override fun notifyStateChanged() { notifyCalls++ }
        override fun courseForExam(exam: Exam): Course? = courseList.firstOrNull { it.id == exam.courseId }
        override fun persistActiveProfileState() {
            persistCalls++
            if (failPersist) throw IllegalStateException("disk down")
        }
        override fun syncExamReminders() { syncReminderCalls++ }
        override fun invalidateHomeWidgetSnapshot() { invalidateWidgetCalls++ }
        override fun syncHomeWidgetSnapshot() { syncWidgetCalls++ }
        override fun logExamEvent(name: String, parameters: Map<String, Any>) { loggedEvents.add(name) }
    }

    private fun course(id: String): Course = Course(
        id = id, name = "课程$id", teacher = "", location = "",
        dayOfWeek = 1, startSection = 1, endSection = 2,
        startTime = "08:00", endTime = "09:45",
        startWeek = 1, endWeek = 16,
        shortName = null, description = null, note = null,
        timeSchemeIdOverride = null, sessionNotes = emptyMap(),
    )

    private fun profile(id: String): TimetableProfile = TimetableProfile(
        id = id, name = "课表$id", courses = emptyList(),
        settings = TimetableSettings.defaults(), currentWeek = 1L,
        createdAt = fixedNow, lastUsedAt = fixedNow,
    )

    private fun exam(
        id: String,
        courseId: String = "c1",
        name: String = "期末考试",
        date: LocalDate = LocalDate.of(2026, 3, 12),
        startTime: String = "09:00",
        endTime: String = "11:00",
    ): Exam = Exam(
        id = id, courseId = courseId, name = name,
        dateTime = date.atStartOfDay(), startTime = startTime, endTime = endTime,
        createdAt = fixedNow, updatedAt = fixedNow,
    )

    private fun port(): FakePort = FakePort(
        courses = listOf(course("c1"), course("c2")),
        exams = listOf(
            exam("eExpired", date = LocalDate.of(2026, 3, 10), startTime = "08:00", endTime = "09:00"), // 今天已考完
            exam("eToday", date = LocalDate.of(2026, 3, 10), startTime = "14:00", endTime = "16:00"),   // 今天未开始完
            exam("eSoon", date = LocalDate.of(2026, 3, 11)),
            exam("eLater", courseId = "c2", date = LocalDate.of(2026, 3, 12)),
        ),
        profiles = listOf(profile("p1")),
    )

    @Test
    fun upcomingExcludesExpiredAndSortsByStart() {
        val service = TimetableExamService(port(), clock = { fixedNow })
        val upcoming = service.getUpcomingExams()
        assertEquals(listOf("eToday", "eSoon", "eLater"), upcoming.map { it.id })
    }

    @Test
    fun nextExamIsEarliestUpcoming() {
        val service = TimetableExamService(port(), clock = { fixedNow })
        assertEquals("eToday", service.getNextExam()?.id)
    }

    @Test
    fun hasExamOnDateIgnoresExpiredSameDayExam() {
        // 今天只有 eExpired（已考完）+ eToday（未开始）⇒ 有未过期的，应为 true
        val service = TimetableExamService(port(), clock = { fixedNow })
        assertTrue(service.hasExamOnDate(LocalDate.of(2026, 3, 10)))
        // 若当天只剩已考完的那场，则应为 false（考完即消失）
        val onlyExpired = FakePort(
            courses = listOf(course("c1")),
            exams = listOf(exam("eExpired", date = LocalDate.of(2026, 3, 10), startTime = "08:00", endTime = "09:00")),
        )
        val service2 = TimetableExamService(onlyExpired, clock = { fixedNow })
        assertFalse(service2.hasExamOnDate(LocalDate.of(2026, 3, 10)))
    }

    @Test
    fun getExamsForCourseFiltersAndSorts() {
        val service = TimetableExamService(port(), clock = { fixedNow })
        assertEquals(listOf("eLater"), service.getExamsForCourse("c2").map { it.id })
        assertEquals(listOf("eExpired", "eToday", "eSoon"), service.getExamsForCourse("c1").map { it.id })
    }

    @Test
    fun addExamRejectsMissingLinkedCourse() {
        val p = port()
        val service = TimetableExamService(p, clock = { fixedNow })
        val before = p.exams.size
        try {
            service.addExam(exam("ghost", courseId = "nope"))
            fail("应抛 linked_course_not_found")
        } catch (e: IllegalArgumentException) {
            assertEquals("linked_course_not_found", e.message)
        }
        assertEquals("拒绝后考试列表不应变化", before, p.exams.size)
        assertEquals("拒绝时不应落盘", 0, p.persistCalls)
    }

    @Test
    fun addExamAppendsPersistsAndLogs() {
        val p = port()
        val service = TimetableExamService(p, clock = { fixedNow })
        service.addExam(exam("eNew", courseId = "c1"))
        assertTrue(p.exams.any { it.id == "eNew" })
        assertTrue(p.notifyCalls > 0)
        assertTrue(p.syncReminderCalls > 0)
        assertTrue(p.loggedEvents.contains("exam_created"))
    }

    @Test
    fun updateExamMissingIsIdempotentNoop() {
        val p = port()
        val service = TimetableExamService(p, clock = { fixedNow })
        val before = p.exams
        service.updateExam(exam("nope"))
        assertEquals(before, p.exams)
        assertEquals(0, p.persistCalls)
    }

    @Test
    fun updateExamReplacesInPlace() {
        val p = port()
        val service = TimetableExamService(p, clock = { fixedNow })
        service.updateExam(exam("eSoon", name = "改后"))
        assertEquals("改后", p.exams.first { it.id == "eSoon" }.name)
        assertTrue(p.loggedEvents.contains("exam_updated"))
    }

    @Test
    fun updateExamRollsBackOnPersistFailure() {
        val p = port()
        p.failPersist = true
        val service = TimetableExamService(p, clock = { fixedNow })
        val before = p.exams.toList()
        try {
            service.updateExam(exam("eSoon", name = "改后"))
            fail("落盘失败应上抛")
        } catch (e: IllegalStateException) {
            assertEquals("memory rollback：考试列表应退回原样", before, p.exams)
        }
    }

    @Test
    fun deleteExamRemovesAndLogs() {
        val p = port()
        val service = TimetableExamService(p, clock = { fixedNow })
        service.deleteExam("eSoon")
        assertFalse(p.exams.any { it.id == "eSoon" })
        assertTrue(p.loggedEvents.contains("exam_deleted"))
    }

    @Test
    fun deleteExamRollsBackOnPersistFailure() {
        val p = port()
        p.failPersist = true
        val service = TimetableExamService(p, clock = { fixedNow })
        val before = p.exams.toList()
        try {
            service.deleteExam("eSoon")
            fail("落盘失败应上抛")
        } catch (e: IllegalStateException) {
            assertEquals("删除失败应把考试列表整体退回", before, p.exams)
        }
    }
}
