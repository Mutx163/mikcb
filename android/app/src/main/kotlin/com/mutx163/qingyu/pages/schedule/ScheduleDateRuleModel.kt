package com.mutx163.qingyu.pages.schedule

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
                ScheduleStrings.scheduleDateRuleErrorNameRequired.zh,
            )
        }
        if (draft.timeSchemeId.trim().isEmpty()) {
            return ScheduleDateRuleValidationResult.Invalid(
                ScheduleStrings.scheduleDateRuleErrorSchemeRequired.zh,
            )
        }
        if (!ScheduleDateUtils.isValidIsoDate(draft.startDate) ||
            !ScheduleDateUtils.isValidIsoDate(draft.endDate)
        ) {
            return ScheduleDateRuleValidationResult.Invalid(
                ScheduleStrings.scheduleDateRuleErrorInvalidDate.zh,
            )
        }
        if (draft.endDate < draft.startDate) {
            return ScheduleDateRuleValidationResult.Invalid(
                ScheduleStrings.scheduleDateRuleErrorEndBeforeStart.zh,
            )
        }

        // 设备上限校验（只在新增时拦截，含停用的）
        if (!isEditing && existingRules.size >= MAX_RULES_PER_DEVICE) {
            return ScheduleDateRuleValidationResult.Invalid(
                ScheduleStrings.scheduleDateRuleErrorMax.zh,
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
                        ScheduleStrings.scheduleDateRuleErrorOverlap.zh,
                    )
                }
            }
        }

        return ScheduleDateRuleValidationResult.Valid
    }
}
