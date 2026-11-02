package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 「这节课闹钟」纯计算层测试。
 *
 * 期望值来源：`lib/services/system_alarm_service.dart:84-152`（SystemAlarmLogic）、
 * `lib/widgets/class_reminder_sheet.dart:75-167`（_addSystemAlarm 的拼装口径）、
 * `lib/widgets/course_action_sheet.dart:1145-1167`（_isAlarmAvailable）。
 */
class ClassAlarmPlanTest {

    private fun course(dayOfWeek: Int = 3, shortName: String? = null, name: String = "高等数学") = Course(
        id = "c1",
        name = name,
        shortName = shortName,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = 1,
        endWeek = 16,
    )

    // ---------- plan ----------

    @Test
    fun `每周计划 响点=开始减提前量 重复日=上课日`() {
        val plan = ClassAlarmPlanLogic.buildCourseWeeklyPlan(
            dayOfWeek = 3,
            startTime = "08:00",
            label = "高数",
            leadMinutes = 30,
        )
        // 周三课 08:00，提前 30 分钟 → 周三 07:30。
        assertEquals(7, plan!!.hour)
        assertEquals(30, plan.minute)
        // ISO 周三(3) → Calendar 周三 = 4。
        assertEquals(listOf(4), plan.repeatDays)
        assertEquals("高数", plan.label)
    }

    @Test
    fun `提前量越过午夜 重复日前移一天`() {
        // 周一 00:20 的课提前 30 分钟 → 响点 23:50，落在**周日**（Dart ringDay 逻辑）。
        val plan = ClassAlarmPlanLogic.buildCourseWeeklyPlan(
            dayOfWeek = 1,
            startTime = "00:20",
            label = "早课",
            leadMinutes = 30,
        )
        assertEquals(23, plan!!.hour)
        assertEquals(50, plan.minute)
        // Calendar 周日 = 1。
        assertEquals(listOf(1), plan.repeatDays)
    }

    @Test
    fun `提前量夹带 0到120 非法时间返回null`() {
        assertEquals(0, ClassAlarmPlanLogic.clampLeadMinutes(-5))
        assertEquals(120, ClassAlarmPlanLogic.clampLeadMinutes(999))
        assertEquals(30, ClassAlarmPlanLogic.clampLeadMinutes(30))

        assertNull(
            ClassAlarmPlanLogic.buildCourseWeeklyPlan(3, "25:00", "x", 30),
        )
        assertNull(
            ClassAlarmPlanLogic.buildCourseWeeklyPlan(9, "08:00", "x", 30),
        )
    }

    @Test
    fun `自选响点保留计划的重复日 钟点用自选值`() {
        // 周三 08:00 的课，用户自选 07:00 → 钟点 07:00，重复日仍来自提前量计划（周三）。
        val plan = ClassAlarmPlanLogic.planForPickedMinute(
            minuteOfDay = 7 * 60,
            course = course(dayOfWeek = 3),
            resolvedStartTime = "08:00",
            label = "高数",
            leadMinutes = 30,
            skipUi = false,
        )
        assertEquals(7, plan!!.hour)
        assertEquals(0, plan.minute)
        assertEquals(listOf(4), plan.repeatDays)
        assertFalse(plan.skipUi)

        // 自选点越过午夜为负 → 直接用每周计划（响点已前移到前一天）。
        val wrapped = ClassAlarmPlanLogic.planForPickedMinute(
            minuteOfDay = -10,
            course = course(dayOfWeek = 1),
            resolvedStartTime = "00:20",
            label = "早课",
            leadMinutes = 30,
            skipUi = true,
        )
        assertEquals(23, wrapped!!.hour)
        assertTrue(wrapped.skipUi)
    }

    // ---------- availability ----------

    private val wednesday = LocalDate.of(2026, 11, 4)

    @Test
    fun `入口判据 未来课可设 当天开课前可设`() {
        val now = LocalDateTime.of(2026, 11, 2, 10, 0)
        assertTrue(ClassAlarmPlanLogic.isAvailable(wednesday, 8 * 60, now))
        // 当天开课前。
        assertTrue(
            ClassAlarmPlanLogic.isAvailable(
                courseDate = wednesday,
                startMinutes = 8 * 60,
                now = LocalDateTime.of(2026, 11, 4, 7, 59),
            ),
        )
        // 当天开课那一刻起消失（Dart `now.isBefore(startAt)` 的严格口径）。
        assertFalse(
            ClassAlarmPlanLogic.isAvailable(
                courseDate = wednesday,
                startMinutes = 8 * 60,
                now = LocalDateTime.of(2026, 11, 4, 8, 0),
            ),
        )
    }

    @Test
    fun `入口判据 过去课 没日期 没钟点都不出现`() {
        val now = LocalDateTime.of(2026, 11, 4, 7, 30)
        assertFalse(ClassAlarmPlanLogic.isAvailable(LocalDate.of(2026, 11, 3), 8 * 60, now))
        assertFalse(ClassAlarmPlanLogic.isAvailable(null, 8 * 60, now))
        assertFalse(ClassAlarmPlanLogic.isAvailable(wednesday, null, now))
    }

    // ---------- 文案拼装的数字口径 ----------

    @Test
    fun `生效提前量与周次摘要`() {
        // 自选点与开始差 30 分钟 → effectiveLead=30；差超 120 夹回 120；负值夹 0。
        assertEquals(30, ClassAlarmPlanLogic.effectiveLead(7 * 60 + 30, 8 * 60, 45))
        assertEquals(120, ClassAlarmPlanLogic.effectiveLead(5 * 60, 8 * 60, 45))
        assertEquals(0, ClassAlarmPlanLogic.effectiveLead(9 * 60, 8 * 60, 45))
        // 负自选点（每周计划分支）→ 直接用设置提前量。
        assertEquals(45, ClassAlarmPlanLogic.effectiveLead(-1, 8 * 60, 45))

        assertEquals("1, 3, 5", ClassAlarmPlanLogic.weeksSummary(course().copy(customWeeks = listOf(1, 3, 5))))
        val many = (1..12).toList()
        assertEquals("1, 2, 3, 4, 5, 6, 7, 8…", ClassAlarmPlanLogic.weeksSummary(course().copy(customWeeks = many)))
    }

    @Test
    fun `设置键读取 缺键回落 Dart 默认值`() {
        // Dart parseClockMinutes 不要求两位宽度：`8:0` 也是合法的 480。
        assertEquals(480, ClassAlarmPlanLogic.parseClockMinutes("8:0"))
        assertEquals(480, ClassAlarmPlanLogic.parseClockMinutes("08:00"))
        assertNull(ClassAlarmPlanLogic.parseClockMinutes("0800"))
        assertNull(ClassAlarmPlanLogic.parseClockMinutes("24:00"))

        assertEquals(30, ClassAlarmPlanLogic.leadMinutesFromSettings(null))
        assertEquals(30, ClassAlarmPlanLogic.leadMinutesFromSettings(mapOf<String, Any?>()))
        assertEquals(15, ClassAlarmPlanLogic.leadMinutesFromSettings(mapOf<String, Any?>("classAlarmLeadMinutes" to 15)))
        assertEquals(30, ClassAlarmPlanLogic.leadMinutesFromSettings(mapOf<String, Any?>("classAlarmLeadMinutes" to "15")))

        assertFalse(ClassAlarmPlanLogic.skipUiFromSettings(null))
        assertTrue(ClassAlarmPlanLogic.skipUiFromSettings(mapOf<String, Any?>("classAlarmSkipUi" to true)))
        assertFalse(ClassAlarmPlanLogic.skipUiFromSettings(mapOf<String, Any?>("classAlarmSkipUi" to "true")))
    }
}
