package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime
import java.util.Locale

/** Dart `ScheduleDateRuleApplyOutcome`（schedule_date_rule_logic.dart:8-20）。 */
enum class ScheduleDateRuleApplyOutcome {
    /** No matching enabled rule for today, or already applied (signature match). */
    NotDue,

    /** Bulk-apply rewrote profile defaults and course clocks. */
    Applied,

    /** Matched rule points at a missing time scheme. */
    SchemeMissing,

    /** Some course endSection exceeds the target scheme section count. */
    SectionOverflow,
}

/**
 * Dart `ScheduleDateRuleApplyResult`（schedule_date_rule_logic.dart:22-38）。
 * 纯数据壳：落盘/通知等副作用由宿主（provider/service）完成，本层不碰。
 */
data class ScheduleDateRuleApplyResult(
    val outcome: ScheduleDateRuleApplyOutcome,
    val requiredMaxSection: Int? = null,
    val schemeSectionCount: Int? = null,
) {
    val didApply: Boolean
        get() = outcome == ScheduleDateRuleApplyOutcome.Applied

    val failedWhileDue: Boolean
        get() = outcome == ScheduleDateRuleApplyOutcome.SchemeMissing ||
            outcome == ScheduleDateRuleApplyOutcome.SectionOverflow
}

/**
 * Pure helpers for [ScheduleDateRule] matching and validation.
 *
 * 移植自 lib/domain/schedule_date_rule_logic.dart（纯计算部分）；签名计算
 * `appliedSignature` 对应 Dart 键 `schedule_date_rule_last_applied_signature`
 * 的纯计算部分——只算签名，读写 prefs 由宿主自理。
 */
object ScheduleDateRuleLogic {

    const val MAX_RULES_PER_DEVICE = 2

    /** Dart `^\\d{4}-\\d{2}-\\d{2}$`：严格 4-2-2 位数字。 */
    private val isoDatePattern = Regex("""^\d{4}-\d{2}-\d{2}$""")

    /** Dart `maxRulesPerDevice` 同名常量入口（保留 Dart 命名便于对拍）。 */
    val maxRulesPerDevice: Int get() = MAX_RULES_PER_DEVICE

    /**
     * Parses `yyyy-MM-dd` into a local date-only [LocalDateTime], or null.
     *
     * 与 Dart 一致：先过 4-2-2 形状正则，再验字段范围，最后**拒绝溢出日期**
     * （2026-02-31 → 三月，Dart 靠 DateTime 构造回读比对，Kotlin 靠
     * [java.time.LocalDate] 自身不接受的越界输入）。
     */
    fun parseIsoDate(raw: String?): LocalDateTime? {
        val value = (raw ?: "").trim()
        if (!isoDatePattern.matches(value)) {
            return null
        }
        val parts = value.split("-")
        val year = parts[0].toIntOrNull() ?: return null
        val month = parts[1].toIntOrNull() ?: return null
        val day = parts[2].toIntOrNull() ?: return null
        if (month < 1 || month > 12 || day < 1 || day > 31) {
            return null
        }
        // Dart `DateTime(y, m, d)` 对 0..99 的年份按 1900+y 解释，回读比对 `parsed.year != y`
        // 必然失败 → 该区间一律 null；LocalDate 会老实造出 0028 年，需显式对齐。
        if (year in 0..99) {
            return null
        }
        // Dart DateTime(y, m, d) 会把越界日滚进下个月；LocalDate 直接拒绝。
        // 两种实现都保证「解析结果就是输入的 y/m/d」这一契约。
        return try {
            val parsed = DartTime.dateTime(year, month, day)
            if (parsed.year != year || parsed.monthValue != month || parsed.dayOfMonth != day) {
                null
            } else {
                parsed
            }
        } catch (_: Exception) {
            null
        }
    }

    fun formatIsoDate(date: LocalDateTime): String =
        String.format(Locale.ROOT, "%04d-%02d-%02d", date.year, date.monthValue, date.dayOfMonth)

    fun dateOnly(date: LocalDateTime): LocalDateTime =
        DartTime.dateTime(date.year, date.monthValue, date.dayOfMonth)

    /** Whether [date] is inside the closed [start]–[end] range. */
    fun containsDate(
        date: LocalDateTime,
        start: LocalDateTime,
        end: LocalDateTime,
    ): Boolean {
        val day = dateOnly(date)
        val rangeStart = dateOnly(start)
        val rangeEnd = dateOnly(end)
        return !day.isBefore(rangeStart) && !day.isAfter(rangeEnd)
    }

    fun rangesOverlap(
        leftStart: LocalDateTime,
        leftEnd: LocalDateTime,
        rightStart: LocalDateTime,
        rightEnd: LocalDateTime,
    ): Boolean {
        val a0 = dateOnly(leftStart)
        val a1 = dateOnly(leftEnd)
        val b0 = dateOnly(rightStart)
        val b1 = dateOnly(rightEnd)
        return !a1.isBefore(b0) && !b1.isBefore(a0)
    }

    /** Validates a single rule. Returns a stable error code or null if ok. */
    fun validateRule(rule: ScheduleDateRule): String? {
        if (rule.id.isEmpty()) {
            return "schedule_date_rule_id_required"
        }
        if (rule.name.trim().isEmpty()) {
            return "schedule_date_rule_name_required"
        }
        if (rule.timeSchemeId.isEmpty()) {
            return "schedule_date_rule_scheme_required"
        }
        val start = parseIsoDate(rule.startDate)
        val end = parseIsoDate(rule.endDate)
        if (start == null || end == null) {
            return "schedule_date_rule_invalid_date"
        }
        if (end.isBefore(start)) {
            return "schedule_date_rule_end_before_start"
        }
        return null
    }

    /** Validates the full list (cap + pairwise overlap for enabled rules). */
    fun validateRules(rules: List<ScheduleDateRule>): String? {
        if (rules.size > MAX_RULES_PER_DEVICE) {
            return "schedule_date_rule_max_exceeded"
        }
        for (rule in rules) {
            val message = validateRule(rule)
            if (message != null) {
                return message
            }
        }
        val enabled = rules.filter { it.enabled }
        for (leftIndex in enabled.indices) {
            val left = enabled[leftIndex]
            val leftStart = parseIsoDate(left.startDate) ?: continue
            val leftEnd = parseIsoDate(left.endDate) ?: continue
            for (rightIndex in leftIndex + 1 until enabled.size) {
                val right = enabled[rightIndex]
                val rightStart = parseIsoDate(right.startDate) ?: continue
                val rightEnd = parseIsoDate(right.endDate) ?: continue
                if (rangesOverlap(
                        leftStart = leftStart,
                        leftEnd = leftEnd,
                        rightStart = rightStart,
                        rightEnd = rightEnd,
                    )
                ) {
                    return "schedule_date_rule_overlap"
                }
            }
        }
        return null
    }

    /**
     * Picks the enabled rule containing [date], or null.
     *
     * When multiple match (legacy dirty data), prefer later start, then narrower
     * span, then smaller id.
     */
    fun match(date: LocalDateTime, rules: List<ScheduleDateRule>): ScheduleDateRule? {
        val hits = mutableListOf<ScheduleDateRule>()
        for (rule in rules) {
            if (!rule.enabled || rule.timeSchemeId.isEmpty()) {
                continue
            }
            val start = parseIsoDate(rule.startDate)
            val end = parseIsoDate(rule.endDate)
            if (start == null || end == null) {
                continue
            }
            if (containsDate(date = date, start = start, end = end)) {
                hits.add(rule)
            }
        }
        if (hits.isEmpty()) {
            return null
        }
        if (hits.size == 1) {
            return hits.first()
        }
        // Dart 排序序：起始更晚者优先（rightStart.compareTo(leftStart)）→
        // 起始相同比跨度（窄者优先）→ 跨度相同比 id（小者优先）。
        // Dart 侧 sort 稳定；Kotlin sortedWith 同为稳定排序。
        // 进入此分支的 hits 必然 start/end 都可解析（containsDate 的前置条件）。
        return hits.sortedWith(
            compareByDescending<ScheduleDateRule> { parseIsoDate(it.startDate)!! }
                .thenBy { rule ->
                    val start = parseIsoDate(rule.startDate)!!
                    val end = parseIsoDate(rule.endDate)!!
                    WeekCalculator.daysBetween(start, end)
                }
                .thenBy { it.id },
        ).first()
    }

    /**
     * Stable signature for a bulk-apply event.
     *
     * When the signature changes (new rule, new scheme, new range), the default
     * time scheme is re-applied once. While it stays the same, daily opens do
     * not rewrite clocks so manual edits remain.
     */
    fun appliedSignature(rule: ScheduleDateRule): String =
        "${rule.id}|${rule.timeSchemeId}|${rule.startDate}|${rule.endDate}"

    /** Whether [today] should trigger a one-shot bulk apply of [matchedRule]. */
    fun shouldBulkApply(
        matchedRule: ScheduleDateRule?,
        lastAppliedSignature: String?,
    ): Boolean {
        if (matchedRule == null || !matchedRule.enabled) {
            return false
        }
        if (matchedRule.timeSchemeId.isEmpty()) {
            return false
        }
        val signature = appliedSignature(matchedRule)
        return signature != lastAppliedSignature
    }
}
