package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.BreakOverrideRule

/**
 * 快捷生成弹层的**输入判据**（2026-11-11 评审 T-06：`submit()` 与实时预览必须同源）。
 *
 * ## 为什么单独抽出来
 *
 * 弹层里原来有**两份**判据：`submit()` 自己解析五个数字 + 逐条查大课间规则，
 * `parsedPresetOrNull()` 又照着写一遍（预览用）。两份判据今天一样、明天就会漂：
 * 最典型的事故是「预览显示共 12 节，点生成却报『请把节数和时长填写为数字』」，
 * 而两边代码各自看着都「对」。
 *
 * 现在只有这一个 [parse]，`submit` 与预览都从它的结果派生，测试可以逐条钉住
 * 「什么输入算 Ready / 缺哪一格 / 哪条规则非法」。
 *
 * ## 判据顺序（与 Dart `_submit:365-412` 一致）
 *
 * 1. 五个数字**按出现顺序**找第一格没填好的：上午 → 下午 → 晚上 → 节奏（时长/小课间）；
 * 2. 再逐条查大课间规则（解析失败、节次 < 1、时长 < 0 都算非法）；
 * 3. 全通过才算 [QuickGenerateParseResult.Ready]。
 */
data class QuickGenerateInputText(
    val morningCount: String,
    val afternoonCount: String,
    val eveningCount: String,
    val classDuration: String,
    val breakDuration: String,
    /** 大课间规则草稿：`afterSection` / `minutes` 两格原始文本（故意保留非法值）。 */
    val breakRules: List<Pair<String, String>> = emptyList(),
    val morningStartTime: String? = null,
    val afternoonStartTime: String? = null,
    val eveningStartTime: String? = null,
)

/** 数字没填好的那**一组**（用于把提示挂到对应卡片上）。 */
enum class QuickGenerateField { MORNING, AFTERNOON, EVENING, RHYTHM }

sealed interface QuickGenerateParseResult {
    data class Ready(val preset: TimeSchemeQuickGeneratePreset) : QuickGenerateParseResult

    data class MissingNumbers(val field: QuickGenerateField) : QuickGenerateParseResult

    /** 大课间规则非法（解析失败 / 节次 < 1 / 时长 < 0）。 */
    data object InvalidBreakRule : QuickGenerateParseResult
}

object TimeSchemeQuickGenerateInput {

    fun parse(input: QuickGenerateInputText): QuickGenerateParseResult {
        val morning = input.morningCount.trim().toIntOrNull()
        val afternoon = input.afternoonCount.trim().toIntOrNull()
        val evening = input.eveningCount.trim().toIntOrNull()
        val duration = input.classDuration.trim().toIntOrNull()
        val breakMinutes = input.breakDuration.trim().toIntOrNull()

        val missing = when {
            morning == null -> QuickGenerateField.MORNING
            afternoon == null -> QuickGenerateField.AFTERNOON
            evening == null -> QuickGenerateField.EVENING
            duration == null || breakMinutes == null -> QuickGenerateField.RHYTHM
            else -> null
        }
        if (missing != null) return QuickGenerateParseResult.MissingNumbers(missing)

        val rules = mutableListOf<BreakOverrideRule>()
        for ((rawAfter, rawMinutes) in input.breakRules) {
            val afterSection = rawAfter.trim().toIntOrNull()
            val minutes = rawMinutes.trim().toIntOrNull()
            if (afterSection == null || afterSection < 1 || minutes == null || minutes < 0) {
                return QuickGenerateParseResult.InvalidBreakRule
            }
            rules += BreakOverrideRule(afterSection = afterSection, breakDurationMinutes = minutes)
        }

        return QuickGenerateParseResult.Ready(
            TimeSchemeQuickGeneratePreset(
                morningCount = morning!!,
                afternoonCount = afternoon!!,
                eveningCount = evening!!,
                morningStartTime = input.morningStartTime,
                afternoonStartTime = input.afternoonStartTime,
                eveningStartTime = input.eveningStartTime,
                classDurationMinutes = duration!!,
                breakDurationMinutes = breakMinutes!!,
                breakOverrideRules = rules,
            ),
        )
    }
}
