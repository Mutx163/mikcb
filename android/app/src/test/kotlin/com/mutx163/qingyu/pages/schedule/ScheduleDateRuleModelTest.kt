package com.mutx163.qingyu.pages.schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 作息日期规则模型与领域校验单元测试（移植 `test/services/schedule_date_rule_logic_test.dart`）。
 */
class ScheduleDateRuleModelTest {

    @Test
    fun `规则在闭区间内且启用时判定为生效`() {
        val rule = ScheduleDateRuleData(
            id = "r1",
            name = "夏令时",
            timeSchemeId = "scheme1",
            startDate = "2026-05-01",
            endDate = "2026-09-30",
            enabled = true,
        )

        assertTrue(ScheduleDateRuleDomain.isActiveOn(rule, "2026-05-01"))
        assertTrue(ScheduleDateRuleDomain.isActiveOn(rule, "2026-07-15"))
        assertTrue(ScheduleDateRuleDomain.isActiveOn(rule, "2026-09-30"))
        assertFalse(ScheduleDateRuleDomain.isActiveOn(rule, "2026-04-30"))
        assertFalse(ScheduleDateRuleDomain.isActiveOn(rule, "2026-10-01"))

        val disabledRule = rule.copy(enabled = false)
        assertFalse(ScheduleDateRuleDomain.isActiveOn(disabledRule, "2026-07-15"))
    }

    @Test
    fun `规则校验：名称必填与方案必填`() {
        val noName = ScheduleDateRuleData(
            id = "r1",
            name = "   ",
            timeSchemeId = "s1",
            startDate = "2026-05-01",
            endDate = "2026-09-30",
        )
        val resName = ScheduleDateRuleDomain.validateRule(noName, emptyList())
        assertTrue(resName is ScheduleDateRuleValidationResult.Invalid)
        assertEquals(
            ScheduleStrings.scheduleDateRuleErrorNameRequired.zh,
            (resName as ScheduleDateRuleValidationResult.Invalid).errorText,
        )

        val noScheme = noName.copy(name = "夏令时", timeSchemeId = "")
        val resScheme = ScheduleDateRuleDomain.validateRule(noScheme, emptyList())
        assertTrue(resScheme is ScheduleDateRuleValidationResult.Invalid)
        assertEquals(
            ScheduleStrings.scheduleDateRuleErrorSchemeRequired.zh,
            (resScheme as ScheduleDateRuleValidationResult.Invalid).errorText,
        )
    }

    @Test
    fun `规则校验：日期格式与起止顺序`() {
        val invalidDate = ScheduleDateRuleData(
            id = "r1",
            name = "夏令时",
            timeSchemeId = "s1",
            startDate = "2026-02-31", // 非法日期
            endDate = "2026-09-30",
        )
        val resInvalid = ScheduleDateRuleDomain.validateRule(invalidDate, emptyList())
        assertTrue(resInvalid is ScheduleDateRuleValidationResult.Invalid)
        assertEquals(
            ScheduleStrings.scheduleDateRuleErrorInvalidDate.zh,
            (resInvalid as ScheduleDateRuleValidationResult.Invalid).errorText,
        )

        val endBeforeStart = ScheduleDateRuleData(
            id = "r1",
            name = "夏令时",
            timeSchemeId = "s1",
            startDate = "2026-09-30",
            endDate = "2026-05-01",
        )
        val resOrder = ScheduleDateRuleDomain.validateRule(endBeforeStart, emptyList())
        assertTrue(resOrder is ScheduleDateRuleValidationResult.Invalid)
        assertEquals(
            ScheduleStrings.scheduleDateRuleErrorEndBeforeStart.zh,
            (resOrder as ScheduleDateRuleValidationResult.Invalid).errorText,
        )
    }

    @Test
    fun `规则校验：单机最多 2 条规则（含停用的）`() {
        val existing = listOf(
            ScheduleDateRuleData("r1", "冬令时", "s1", "2026-10-01", "2027-04-30"),
            ScheduleDateRuleData("r2", "夏令时", "s2", "2026-05-01", "2026-09-30", enabled = false),
        )
        val draft = ScheduleDateRuleData("r3", "春季特规", "s1", "2026-03-01", "2026-03-15")

        // 新增第 3 条报错
        val resAdd = ScheduleDateRuleDomain.validateRule(draft, existing, isEditing = false)
        assertTrue(resAdd is ScheduleDateRuleValidationResult.Invalid)
        assertEquals(
            ScheduleStrings.scheduleDateRuleErrorMax.zh,
            (resAdd as ScheduleDateRuleValidationResult.Invalid).errorText,
        )

        // 编辑已有条目不受 2 条上限拦截
        val resEdit = ScheduleDateRuleDomain.validateRule(existing[0], existing, isEditing = true)
        assertTrue(resEdit is ScheduleDateRuleValidationResult.Valid)
    }

    @Test
    fun `规则校验：启用中的规则日期区间不得重叠，停用的不参与重叠检测`() {
        val rule1 = ScheduleDateRuleData("r1", "冬令时", "s1", "2026-10-01", "2026-12-31", enabled = true)
        val overlapDraft = ScheduleDateRuleData("r2", "特规", "s2", "2026-12-31", "2027-01-15", enabled = true)

        // 12-31 边界闭区间重叠
        val resOverlap = ScheduleDateRuleDomain.validateRule(overlapDraft, listOf(rule1))
        assertTrue(resOverlap is ScheduleDateRuleValidationResult.Invalid)
        assertEquals(
            ScheduleStrings.scheduleDateRuleErrorOverlap.zh,
            (resOverlap as ScheduleDateRuleValidationResult.Invalid).errorText,
        )

        // 当新规则或已有规则为停用状态时，允许重叠
        val disabledDraft = overlapDraft.copy(enabled = false)
        assertTrue(ScheduleDateRuleDomain.validateRule(disabledDraft, listOf(rule1)) is ScheduleDateRuleValidationResult.Valid)

        val disabledRule1 = rule1.copy(enabled = false)
        assertTrue(ScheduleDateRuleDomain.validateRule(overlapDraft, listOf(disabledRule1)) is ScheduleDateRuleValidationResult.Valid)
    }
}
