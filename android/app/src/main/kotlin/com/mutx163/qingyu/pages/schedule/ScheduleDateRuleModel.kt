package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.calendar.ScheduleDateRuleApplyResult

/**
 * 作息时间表自动切换日期规则模型（移植 `lib/models/schedule_date_rule.dart` 与 `ScheduleDateRuleLogic`）。
 */
data class ScheduleDateRuleData(
    val id: String,
    val name: String,
    val timeSchemeId: String,
    val startDate: String,
    val endDate: String,
    val enabled: Boolean = true,
)

sealed class ScheduleDateRuleValidationResult {
    data object Valid : ScheduleDateRuleValidationResult()
    data class Invalid(val errorText: String) : ScheduleDateRuleValidationResult()
}

/**
 * 规则卡片展示层数据。
 */
data class ScheduleDateRuleItemView(
    val rule: ScheduleDateRuleData,
    val schemeName: String,
    val isActiveToday: Boolean,
)

/**
 * 作息日期规则领域逻辑助手（纯 Kotlin，无 UI 依赖）。
 */
object ScheduleDateRuleDomain {

    const val MAX_RULES_PER_DEVICE = 2

    /**
     * 判断规则在 [dateIso] 当天是否生效（启用且落入闭区间 [startDate, endDate]）。
     */
    fun isActiveOn(rule: ScheduleDateRuleData, dateIso: String): Boolean {
        if (!rule.enabled) return false
        return dateIso >= rule.startDate && dateIso <= rule.endDate
    }

    /**
     * 校验两条日期规则的闭区间是否重叠。
     */
    fun dateRangesOverlap(
        startA: String,
        endA: String,
        startB: String,
        endB: String,
    ): Boolean {
        return !(endA < startB || startA > endB)
    }

    /**
     * 表单提交前校验规则合法性。
     */
    fun validateRule(
        draft: ScheduleDateRuleData,
        existingRules: List<ScheduleDateRuleData>,
        isEditing: Boolean = false,
    ): ScheduleDateRuleValidationResult {
        if (draft.name.trim().isEmpty()) {
            return ScheduleDateRuleValidationResult.Invalid(
                ScheduleStrings.scheduleDateRuleErrorNameRequired.text,
            )
        }
        if (draft.timeSchemeId.trim().isEmpty()) {
            return ScheduleDateRuleValidationResult.Invalid(
                ScheduleStrings.scheduleDateRuleErrorSchemeRequired.text,
            )
        }
        if (!ScheduleDateUtils.isValidIsoDate(draft.startDate) ||
            !ScheduleDateUtils.isValidIsoDate(draft.endDate)
        ) {
            return ScheduleDateRuleValidationResult.Invalid(
                ScheduleStrings.scheduleDateRuleErrorInvalidDate.text,
            )
        }
        if (draft.endDate < draft.startDate) {
            return ScheduleDateRuleValidationResult.Invalid(
                ScheduleStrings.scheduleDateRuleErrorEndBeforeStart.text,
            )
        }

        // 设备上限校验（只在新增时拦截，含停用的）
        if (!isEditing && existingRules.size >= MAX_RULES_PER_DEVICE) {
            return ScheduleDateRuleValidationResult.Invalid(
                ScheduleStrings.scheduleDateRuleErrorMax.text,
            )
        }

        // 区间重叠校验：只检查双方都在启用状态的规则
        if (draft.enabled) {
            val otherEnabledRules = existingRules.filter {
                it.enabled && (!isEditing || it.id != draft.id)
            }
            for (other in otherEnabledRules) {
                if (dateRangesOverlap(draft.startDate, draft.endDate, other.startDate, other.endDate)) {
                    return ScheduleDateRuleValidationResult.Invalid(
                        ScheduleStrings.scheduleDateRuleErrorOverlap.text,
                    )
                }
            }
        }

        return ScheduleDateRuleValidationResult.Valid
    }
}

/**
 * 日期规则**保存成功后**要弹哪一档提示（发布版 `schedule_date_rule_screen.dart:394-404` 的四态）。
 *
 * ## 为什么单独一个类型
 *
 * 保存成败其实是三件事叠出来的：①规则本身写没写进盘（宿主负责，写失败根本走不到这里）；
 * ②今天的 `applyDue` 有没有套用（[ScheduleDateRuleApplyResult]）；③今天是不是还没到开始日。
 * 在调用点用嵌套三元表达式串起来，必然漏掉「今天该套但套失败了」这一类——那正是**必须警示**的一档。
 *
 * 文案三条复合键（`scheduleDateRuleSavedAndApplied` / `…SavedForFuture` / `…SavedButApplyFailed`）
 * 早在 ARB 里逐字对好发布版，本批只是第一次真正消费它们（零 ARB 改动）。
 */
enum class ScheduleDateRuleSavedFeedback {

    /** 今天命中了这条规则，且已把所有课表的默认作息换成模板（`didApply`）。 */
    APPLIED,

    /** 规则启用、但今天还没到开始日：到那天才套（`willApplyLater`）。 */
    WILL_APPLY_LATER,

    /** 今天该套却套不成（模板缺失 / 节数不够 / 落盘失败）——**必须警示**。 */
    FAILED_WHILE_DUE,

    /** 其余：日期区间已过、规则停用、今天已经套过一次（签名一致）等。 */
    SAVED,
    ;

    /** 该档对应的提示文案（逐字取 ARB 键，不在这里重写中文）。 */
    val message: String
        get() = when (this) {
            APPLIED -> ScheduleStrings.scheduleDateRuleSavedAndApplied.text
            WILL_APPLY_LATER -> ScheduleStrings.scheduleDateRuleSavedForFuture.text
            FAILED_WHILE_DUE -> ScheduleStrings.scheduleDateRuleSavedButApplyFailed.text
            SAVED -> ScheduleStrings.scheduleDateRuleSaved.text
        }

    /** 失败档要警示样式（发布版 `AppToastKind.warning` 的对位）。 */
    val isWarning: Boolean
        get() = this == FAILED_WHILE_DUE
}

/**
 * 四态判据（唯一一份）。
 *
 * 顺序照抄发布版 `:395-404`：**先判失败**，再判已套用，最后才判「将来才生效」——
 * 顺序反了会把「今天该套却失败」说成「已保存」，用户就永远不知道为什么作息没变。
 */
object ScheduleDateRuleSavedFeedbackLogic {

    /**
     * @param rule 刚保存下来的那条规则（用它的 `enabled` 与 `startDate`）
     * @param applyResult 保存后这次 `applyDue` 的返回值（**不许丢**：`failedWhileDue` 全靠它）
     * @param todayIso 今天（`yyyy-MM-dd`），宿主传入便于 JVM 测试注入
     */
    fun resolve(
        rule: ScheduleDateRuleData,
        applyResult: ScheduleDateRuleApplyResult,
        todayIso: String,
    ): ScheduleDateRuleSavedFeedback {
        val today = todayIso.trim()
        val startDate = rule.startDate.trim()
        val willApplyLater = rule.enabled &&
            ScheduleDateUtils.isValidIsoDate(today) &&
            ScheduleDateUtils.isValidIsoDate(startDate) &&
            today < startDate
        return when {
            applyResult.failedWhileDue -> ScheduleDateRuleSavedFeedback.FAILED_WHILE_DUE
            applyResult.didApply -> ScheduleDateRuleSavedFeedback.APPLIED
            willApplyLater -> ScheduleDateRuleSavedFeedback.WILL_APPLY_LATER
            else -> ScheduleDateRuleSavedFeedback.SAVED
        }
    }
}
