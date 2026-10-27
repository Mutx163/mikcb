package com.mutx163.qingyu.pages.guide

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class StartupFlowModelTest {

    @Test
    fun `日期合法性校验`() {
        assertTrue(SemesterDateCalculator.isValidDateFormat("2026-09-01"))
        assertTrue(SemesterDateCalculator.isValidDateFormat("2024-02-29")) // 2024 闰年
        assertFalse(SemesterDateCalculator.isValidDateFormat("2023-02-29")) // 2023 平年
        assertFalse(SemesterDateCalculator.isValidDateFormat("2026/09/01"))
        assertFalse(SemesterDateCalculator.isValidDateFormat("invalid"))
        assertFalse(SemesterDateCalculator.isValidDateFormat(null))
        assertFalse(SemesterDateCalculator.isValidDateFormat(""))
        assertFalse(SemesterDateCalculator.isValidDateFormat("1999-12-31")) // 超出合理年份
    }

    @Test
    fun `开学周周一计算与周次推导`() {
        // 2026-09-01 是周二，所在周周一是 2026-08-31
        val semesterStart = LocalDate.of(2026, 9, 1)
        val monday = SemesterDateCalculator.startOfWeek(semesterStart)
        assertEquals(LocalDate.of(2026, 8, 31), monday)

        // 开学当周的周日仍然是第 1 周
        val sundayWeek1 = LocalDate.of(2026, 9, 6)
        assertEquals(1, SemesterDateCalculator.calculateWeek(semesterStart, sundayWeek1, totalWeeks = 20))

        // 下周一为第 2 周
        val mondayWeek2 = LocalDate.of(2026, 9, 7)
        assertEquals(2, SemesterDateCalculator.calculateWeek(semesterStart, mondayWeek2, totalWeeks = 20))

        // 开学前一律归为第 1 周
        val beforeSemester = LocalDate.of(2026, 8, 15)
        assertEquals(1, SemesterDateCalculator.calculateWeek(semesterStart, beforeSemester, totalWeeks = 20))

        // 超过学期总周数钳制到最后一班
        val farFuture = LocalDate.of(2027, 3, 1)
        assertEquals(18, SemesterDateCalculator.calculateWeek(semesterStart, farFuture, totalWeeks = 18))
    }

    @Test
    fun `状态机初始化与旧版包名检测`() {
        val machine = StartupFlowStateMachine()
        assertEquals(StartupStep.DATE_SETUP, machine.state.currentStep)
        assertNull(machine.state.legacyPackageName)

        // 检测到旧版应用包名
        machine.onDetectLegacyPackage("com.example.university_timetable")
        assertEquals(StartupStep.MIGRATION_CHECK, machine.state.currentStep)
        assertEquals("com.example.university_timetable", machine.state.legacyPackageName)

        // 跳过迁移
        machine.onMigrationAction(MigrationFlowAction.SKIP)
        assertEquals(StartupStep.DATE_SETUP, machine.state.currentStep)
    }

    @Test
    fun `状态机开学日期设置与周次自动联动`() {
        val machine = StartupFlowStateMachine()
        machine.onDetectLegacyPackage(null)

        // 输入非法日期被拦截
        val badResult = machine.onUpdateSemesterStartDate("not-a-date")
        assertFalse(badResult)
        assertNull(machine.state.semesterStartDate)

        // 输入合法日期，周次自动计算
        val okResult = machine.onUpdateSemesterStartDate("2026-09-01")
        assertTrue(okResult)
        assertEquals("2026-09-01", machine.state.semesterStartDate)
        assertTrue(machine.state.currentWeek >= 1)

        // 修改总周数超限被拦截
        assertFalse(machine.onUpdateTotalWeeks(0))
        assertFalse(machine.onUpdateTotalWeeks(45))

        // 合法总周数更新
        assertTrue(machine.onUpdateTotalWeeks(16))
        assertEquals(16, machine.state.totalWeeks)
    }

    @Test
    fun `状态机完成流程流转与隐私门控`() {
        val machine = StartupFlowStateMachine()
        assertFalse("未设置有效日期时不应允许进入下一步", machine.onCompleteDateSetup())

        machine.onUpdateSemesterStartDate("2026-09-01")
        assertTrue("设置有效日期后允许进入引导页", machine.onCompleteDateSetup())
        assertEquals(StartupStep.GUIDE_TOUR, machine.state.currentStep)

        // 未同意隐私时不允许完成
        assertFalse(machine.onCompleteGuide(requirePrivacyConsent = true))
        assertFalse(machine.state.isCompleted)

        // 同意隐私后顺利完成
        machine.onPrivacyConsentChanged(true)
        assertTrue(machine.onCompleteGuide(requirePrivacyConsent = true))
        assertEquals(StartupStep.COMPLETED, machine.state.currentStep)
        assertTrue(machine.state.isCompleted)
    }
}
