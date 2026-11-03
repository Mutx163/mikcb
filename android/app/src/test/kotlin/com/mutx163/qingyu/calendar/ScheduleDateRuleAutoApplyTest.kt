package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule as CoreScheduleDateRule
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.util.Locale

/**
 * 日期规则自动套用测试。
 *
 * 期望值来源：`test/services/timetable_schedule_date_rule_service_test.dart` 逐条对照
 * 与 `lib/services/timetable_schedule_date_rule_service.dart:45-213`。
 */
class ScheduleDateRuleAutoApplyTest {

    private val now = LocalDateTime.of(2026, 3, 10, 0, 0)

    private fun sections(count: Int): List<SectionTime> = List(count) { index ->
        val hour = 8 + index
        SectionTime(
            startTime = String.format(Locale.ROOT, "%02d:00", hour),
            endTime = String.format(Locale.ROOT, "%02d:45", hour),
        )
    }

    private fun scheme(id: String = "s1", sectionCount: Int = 8) = TimeScheme(
        id = id,
        name = "作息$id",
        sections = sections(sectionCount),
        createdAt = LocalDateTime.of(2026, 3, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 3, 1, 0, 0),
    )

    private fun course(id: String, endSection: Int = 2, startTime: String = "07:30") = Course(
        id = id,
        name = "数学",
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = endSection,
        startTime = startTime,
        endTime = "09:45",
    )

    private fun profile(id: String) = TimetableProfile(
        id = id,
        name = "课表$id",
        courses = listOf(course("c_$id")),
        settings = TimetableSettings.defaults().copy(
            activeTimeSchemeId = "old",
            sections = sections(4),
        ),
        currentWeek = 1,
        createdAt = LocalDateTime.of(2026, 3, 1, 0, 0),
        lastUsedAt = LocalDateTime.of(2026, 3, 1, 0, 0),
    )

    private fun dueRule(id: String = "r1", schemeId: String = "s1") = CoreScheduleDateRule(
        id = id,
        name = "春季作息",
        timeSchemeId = schemeId,
        startDate = "2026-03-01",
        endDate = "2026-04-30",
    )

    private class FakePort(
        override var scheduleDateRules: List<CoreScheduleDateRule> = emptyList(),
        override var timeSchemes: List<TimeScheme> = emptyList(),
        override var profiles: List<TimetableProfile> = emptyList(),
        override var courses: List<Course> = emptyList(),
        override var settings: TimetableSettings = TimetableSettings.defaults(),
        val activeProfileIdValue: String? = null,
        override var scheduleDateRuleLastAppliedSignature: String? = null,
    ) : ScheduleDateRuleAutoApplyPort {
        override val activeProfileId: String? get() = activeProfileIdValue
        override var locationTimeGroups: List<LocationTimeGroup> = emptyList()

        var persistCalls = 0
        var saveSignatureCalls = 0
        var notifySyncCalls = 0
        var notifyCalls = 0
        var clearLiveCalls = 0
        var failPersist = false
        var failSaveSignature = false

        override fun persistTimetableState(
            profiles: List<TimetableProfile>,
            settings: TimetableSettings,
        ) {
            persistCalls++
            if (failPersist) {
                throw IllegalStateException("profiles disk down")
            }
            this.profiles = profiles
            this.settings = settings
            // 仓储的 courses 由活动档案派生；假端照此同步，便于断言「课表跟着重排」。
            val active = profiles.firstOrNull { it.id == activeProfileIdValue }
            if (active != null) {
                courses = active.courses
            }
        }

        override fun saveScheduleDateRuleLastAppliedSignature(signature: String) {
            saveSignatureCalls++
            if (failSaveSignature) {
                throw IllegalStateException("signature disk down")
            }
        }

        override fun notifySyncDataChanged() {
            notifySyncCalls++
        }

        override fun notifyStateChanged() {
            notifyCalls++
        }

        override fun clearCurrentLiveCourseId() {
            clearLiveCalls++
        }
    }

    @Test
    fun `no due rule is notDue and touches nothing`() {
        val port = FakePort(
            scheduleDateRules = listOf(
                CoreScheduleDateRule(
                    id = "r2",
                    name = "暑期作息",
                    timeSchemeId = "s1",
                    startDate = "2026-06-01",
                    endDate = "2026-07-31",
                ),
            ),
            timeSchemes = listOf(scheme()),
        )

        val result = ScheduleDateRuleAutoApply.applyDue(port, now)

        assertEquals(ScheduleDateRuleApplyOutcome.NotDue, result.outcome)
        assertEquals(0, port.persistCalls)
        assertEquals(0, port.notifyCalls)
    }

    @Test
    fun `same signature means already applied`() {
        val rule = dueRule()
        val port = FakePort(
            scheduleDateRules = listOf(rule),
            timeSchemes = listOf(scheme()),
            scheduleDateRuleLastAppliedSignature = ScheduleDateRuleLogic.appliedSignature(
                rule.toCalendarDateRule(),
            ),
        )

        val result = ScheduleDateRuleAutoApply.applyDue(port, now)

        assertEquals(ScheduleDateRuleApplyOutcome.NotDue, result.outcome)
        assertEquals(0, port.persistCalls)
    }

    @Test
    fun `missing time scheme reports SchemeMissing without persisting`() {
        val port = FakePort(scheduleDateRules = listOf(dueRule()))

        val result = ScheduleDateRuleAutoApply.applyDue(port, now)

        assertEquals(ScheduleDateRuleApplyOutcome.SchemeMissing, result.outcome)
        assertEquals(0, port.persistCalls)
        assertEquals(0, port.notifyCalls)
    }

    @Test
    fun `section overflow reports both counts without persisting`() {
        val port = FakePort(
            scheduleDateRules = listOf(dueRule()),
            timeSchemes = listOf(scheme(sectionCount = 4)),
            courses = listOf(course("c1", endSection = 6)),
        )

        val result = ScheduleDateRuleAutoApply.applyDue(port, now)

        assertEquals(ScheduleDateRuleApplyOutcome.SectionOverflow, result.outcome)
        assertEquals(6, result.requiredMaxSection)
        assertEquals(4, result.schemeSectionCount)
        assertEquals(0, port.persistCalls)
    }

    @Test
    fun `apply rewrites every profile scheme and clocks then persists signature last`() {
        val rule = dueRule()
        val port = FakePort(
            scheduleDateRules = listOf(rule),
            timeSchemes = listOf(scheme()),
            profiles = listOf(profile("p1"), profile("p2")),
            courses = listOf(course("c1")),
            activeProfileIdValue = "p1",
        )

        val result = ScheduleDateRuleAutoApply.applyDue(port, now)

        assertEquals(ScheduleDateRuleApplyOutcome.Applied, result.outcome)
        assertEquals(listOf("s1", "s1"), port.profiles.map { it.settings.activeTimeSchemeId })
        assertEquals(listOf(8, 8), port.profiles.map { it.settings.sections.size })
        // 活动档案的课：节次 1..2 → 模板前两节的钟点。
        assertEquals("08:00", port.courses.single().startTime)
        assertEquals("09:45", port.courses.single().endTime)
        assertEquals(1, port.persistCalls)
        assertEquals(1, port.notifySyncCalls)
        assertEquals(1, port.clearLiveCalls)
        assertEquals(1, port.notifyCalls)
        assertEquals(1, port.saveSignatureCalls)
        assertEquals("s1", port.settings.activeTimeSchemeId)
        assertEquals(
            ScheduleDateRuleLogic.appliedSignature(rule.toCalendarDateRule()),
            port.scheduleDateRuleLastAppliedSignature,
        )
    }

    @Test
    fun `no active profile applies scheme to global settings`() {
        val port = FakePort(
            scheduleDateRules = listOf(dueRule()),
            timeSchemes = listOf(scheme()),
            courses = listOf(course("c1")),
        )

        val result = ScheduleDateRuleAutoApply.applyDue(port, now)

        assertEquals(ScheduleDateRuleApplyOutcome.Applied, result.outcome)
        assertEquals("s1", port.settings.activeTimeSchemeId)
        assertEquals(8, port.settings.sections.size)
    }

    @Test
    fun `profile persist failure leaves memory untouched and does not write signature`() {
        val port = FakePort(
            scheduleDateRules = listOf(dueRule()),
            timeSchemes = listOf(scheme()),
            profiles = listOf(profile("p1")),
            courses = listOf(course("c1")),
            activeProfileIdValue = "p1",
        )
        port.failPersist = true

        assertThrows(IllegalStateException::class.java) {
            ScheduleDateRuleAutoApply.applyDue(port, now)
        }

        assertEquals("old", port.profiles.single().settings.activeTimeSchemeId)
        assertEquals(0, port.notifyCalls)
        assertEquals(0, port.saveSignatureCalls)
        assertNull(port.scheduleDateRuleLastAppliedSignature)
    }

    @Test
    fun `signature save failure does not record the signature in memory`() {
        val port = FakePort(
            scheduleDateRules = listOf(dueRule()),
            timeSchemes = listOf(scheme()),
            profiles = listOf(profile("p1")),
            activeProfileIdValue = "p1",
        )
        port.failSaveSignature = true

        assertThrows(IllegalStateException::class.java) {
            ScheduleDateRuleAutoApply.applyDue(port, now)
        }

        assertNull(port.scheduleDateRuleLastAppliedSignature)
        assertEquals(1, port.notifyCalls)
        assertTrue("课表已落盘，界面必须先看到新作息", port.profiles.single().settings.activeTimeSchemeId == "s1")
    }

    @Test
    fun `core and calendar rule conversions are lossless`() {
        val core = CoreScheduleDateRule(
            id = "r9",
            name = " 冬令时 ",
            timeSchemeId = "s9",
            enabled = false,
            startDate = "2026-11-01",
            endDate = "2027-03-01",
        )
        val calendar = core.toCalendarDateRule()

        assertEquals(core.id, calendar.id)
        assertEquals(core.name, calendar.name)
        assertEquals(core.timeSchemeId, calendar.timeSchemeId)
        assertEquals(core.enabled, calendar.enabled)
        assertEquals(core.startDate, calendar.startDate)
        assertEquals(core.endDate, calendar.endDate)
        assertEquals(core, calendar.toCoreDateRule())
    }
}
