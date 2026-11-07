package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.calendar.ScheduleDateRuleApplyOutcome
import com.mutx163.qingyu.calendar.ScheduleDateRuleApplyResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日期规则「保存后的四态提示」判据（2026-11-05）。
 *
 * ## 防的是什么
 *
 * 发布版保存规则后按四态出提示（`schedule_date_rule_screen.dart:395-404`）：
 * `failedWhileDue` → 「已保存，但今日自动套用失败…」（警示）／`didApply` → 「…今天已更新…」／
 * `willApplyLater`（启用且今天早于开始日）→ 「…将在开始日期更新…」／其余 → 「已保存」。
 *
 * 我们仓里这三条复合键早在 ARB 里逐字对好了，却**零消费**——因为保存流程把 `applyDue` 的
 * 返回值直接丢了。于是「今天该套但套失败」被说成「已保存」，作息没变也没有任何解释。
 *
 * 本测试钉住的是**判据本身**（纯 Kotlin，L0 可跑），包括最容易写反的那两条：
 * 1. 失败优先于「已套用 / 将来生效」——顺序反了就把失败说成成功；
 * 2. `willApplyLater` 必须同时满足「启用」和「今天早于开始日」——只看一边会把停用规则说成「将来会生效」。
 */
class ScheduleDateRuleSavedFeedbackTest {

    // ───────────────────────── 1. 四态各一 ─────────────────────────

    @Test
    fun `今天该套却套失败要出失败档并带警示`() {
        // 模板节数不够（今天命中规则，套用失败）。
        val overflow = ScheduleDateRuleApplyResult(
            outcome = ScheduleDateRuleApplyOutcome.SectionOverflow,
            requiredMaxSection = 12,
            schemeSectionCount = 10,
        )
        val feedback = resolve(rule = ruleToday(), applyResult = overflow)
        assertEquals(ScheduleDateRuleSavedFeedback.FAILED_WHILE_DUE, feedback)
        assertTrue("失败档必须走警示样式", feedback.isWarning)
        assertEquals(ScheduleStrings.scheduleDateRuleSavedButApplyFailed.zh, feedback.message)

        // 模板不存在，同样属于「今天该套却套不成」。
        val missing = ScheduleDateRuleApplyResult(outcome = ScheduleDateRuleApplyOutcome.SchemeMissing)
        assertEquals(ScheduleDateRuleSavedFeedback.FAILED_WHILE_DUE, resolve(rule = ruleToday(), applyResult = missing))
    }

    @Test
    fun `今天已套用出已套用档`() {
        val feedback = resolve(
            rule = ruleToday(),
            applyResult = ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.Applied),
        )
        assertEquals(ScheduleDateRuleSavedFeedback.APPLIED, feedback)
        assertFalse(feedback.isWarning)
        assertEquals(ScheduleStrings.scheduleDateRuleSavedAndApplied.zh, feedback.message)
    }

    @Test
    fun `还没到开始日且规则启用出将来生效档`() {
        val feedback = resolve(
            rule = ruleStartingOn("2099-01-01"),
            applyResult = ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.NotDue),
        )
        assertEquals(ScheduleDateRuleSavedFeedback.WILL_APPLY_LATER, feedback)
        assertFalse(feedback.isWarning)
        assertEquals(ScheduleStrings.scheduleDateRuleSavedForFuture.zh, feedback.message)
    }

    @Test
    fun `其余情形出兜底已保存档`() {
        // 今天就是开始日、但今天已经套过一次（签名一致 ⇒ NotDue）。
        val alreadyApplied = resolve(
            rule = ruleToday(),
            applyResult = ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.NotDue),
        )
        assertEquals(ScheduleDateRuleSavedFeedback.SAVED, alreadyApplied)
        assertEquals(ScheduleStrings.scheduleDateRuleSaved.zh, alreadyApplied.message)

        // 停用的规则即便开始日在将来，也不该说「将在开始日期更新」。
        val disabledFuture = resolve(
            rule = ruleStartingOn("2099-01-01").copy(enabled = false),
            applyResult = ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.NotDue),
        )
        assertEquals(ScheduleDateRuleSavedFeedback.SAVED, disabledFuture)

        // 区间已经过去的规则同理。
        val past = resolve(
            rule = ruleStartingOn("2020-01-01").copy(endDate = "2020-01-31"),
            applyResult = ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.NotDue),
        )
        assertEquals(ScheduleDateRuleSavedFeedback.SAVED, past)
    }

    // ───────────────────────── 2. 判据顺序与文案来源 ─────────────────────────

    @Test
    fun `失败优先于已套用与将来生效`() {
        // 即便将来才生效，只要这次 applyDue 报失败，提示也必须是失败档（不许说成「将来会生效」）。
        val feedback = resolve(
            rule = ruleStartingOn("2099-01-01"),
            applyResult = ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.SchemeMissing),
        )
        assertEquals(ScheduleDateRuleSavedFeedback.FAILED_WHILE_DUE, feedback)
    }

    @Test
    fun `四档文案各自取自对应的 ARB 键`() {
        // 四档不许共用一句话：共用就说明有分支被合并掉了。
        val messages = ScheduleDateRuleSavedFeedback.entries.map { it.message }
        assertTrue("四档文案必须互不相同", messages.toSet().size == messages.size)
        assertTrue(
            "已套用档应使用 scheduleDateRuleSavedAndApplied",
            messages.contains(ScheduleStrings.scheduleDateRuleSavedAndApplied.zh),
        )
        assertTrue(
            "将来生效档应使用 scheduleDateRuleSavedForFuture",
            messages.contains(ScheduleStrings.scheduleDateRuleSavedForFuture.zh),
        )
        assertTrue(
            "失败档应使用 scheduleDateRuleSavedButApplyFailed",
            messages.contains(ScheduleStrings.scheduleDateRuleSavedButApplyFailed.zh),
        )
        assertTrue(
            "兜底档应使用 scheduleDateRuleSaved",
            messages.contains(ScheduleStrings.scheduleDateRuleSaved.zh),
        )
        // 只有失败档是警示。
        assertEquals(
            listOf(ScheduleDateRuleSavedFeedback.FAILED_WHILE_DUE),
            ScheduleDateRuleSavedFeedback.entries.filter { it.isWarning },
        )
    }

    // ------------------------------------------------------------------
    // 夹具
    // ------------------------------------------------------------------

    private fun resolve(
        rule: ScheduleDateRuleData,
        applyResult: ScheduleDateRuleApplyResult,
    ): ScheduleDateRuleSavedFeedback =
        ScheduleDateRuleSavedFeedbackLogic.resolve(rule = rule, applyResult = applyResult, todayIso = TODAY)

    private fun ruleToday(): ScheduleDateRuleData = ScheduleDateRuleData(
        id = "rule-1",
        name = "国庆切换",
        timeSchemeId = "scheme-1",
        startDate = TODAY,
        endDate = "2099-12-31",
    )

    private fun ruleStartingOn(startDate: String): ScheduleDateRuleData = ScheduleDateRuleData(
        id = "rule-2",
        name = "下月切换",
        timeSchemeId = "scheme-1",
        startDate = startDate,
        endDate = "2099-12-31",
    )

    private companion object {
        const val TODAY = "2026-11-05"
    }
}
