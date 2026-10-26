package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartTime
import java.time.LocalDateTime

/**
 * A date-range rule that switches the profile default time scheme.
 *
 * Product semantics (not a continuous soft overlay):
 * - On the rule's start day (or the first app open after that day while the
 *   range is still active), bulk-apply [timeSchemeId] as the profile default
 *   and rewrite unlocked course clocks (same path as applying a time scheme).
 * - Afterwards users may manually edit courses; daily opens do not re-apply.
 * - Course override and location groups still win for individual courses.
 *
 * Product cap: at most 2 rules per device，**含停用的**（`maxRulesPerDevice`
 * 由 `validateRules` 与 `createScheduleDateRule` 按列表总长把关，UI 文案也是
 * "最多只能添加 2 条日期规则"）；日期区间不得重叠这一条只对启用中的规则检查。
 *
 * 移植自 lib/models/schedule_date_rule.dart：JSON 契约字段名逐字一致
 * （`id` / `name` / `timeSchemeId` / `enabled` / `startDate` / `endDate`）。
 */
data class ScheduleDateRule(
    val id: String,

    val name: String,

    val timeSchemeId: String,

    val enabled: Boolean = true,

    /** Inclusive start date as `yyyy-MM-dd` (local calendar). */
    val startDate: String,

    /** Inclusive end date as `yyyy-MM-dd` (local calendar). */
    val endDate: String,
) {
    fun toJson(): LinkedHashMap<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "timeSchemeId" to timeSchemeId,
        "enabled" to enabled,
        "startDate" to startDate,
        "endDate" to endDate,
    )

    fun toJsonString(): String = com.mutx163.qingyu.core.MiniJson.encode(toJson())

    /**
     * Dart copyWith：只覆盖显式传入的字段。Kotlin 侧用 `field ?: this.field`
     * 默认参数承载同一语义。
     */
    fun copy(
        id: String? = null,
        name: String? = null,
        timeSchemeId: String? = null,
        enabled: Boolean? = null,
        startDate: String? = null,
        endDate: String? = null,
    ): ScheduleDateRule = ScheduleDateRule(
        id = id ?: this.id,
        name = name ?: this.name,
        timeSchemeId = timeSchemeId ?: this.timeSchemeId,
        enabled = enabled ?: this.enabled,
        startDate = startDate ?: this.startDate,
        endDate = endDate ?: this.endDate,
    )

    companion object {
        /**
         * Dart `ScheduleDateRule.fromJson`：
         * - startDate / endDate 非字符串或 trim 后为空 → FormatException（本侧
         *   [IllegalArgumentException]，与 core 族 fromJson 的 DartFormatException
         *   同为 RuntimeException，但 Dart 侧这里抛的是裸 FormatException，文案逐字一致）；
         * - id / timeSchemeId 缺省 ''，name trim 后缺省 ''，enabled 缺省 true；
         * - startDate / endDate 落库前 trim。
         */
        fun fromJson(json: Map<String, Any?>): ScheduleDateRule {
            val rawStartDate = json["startDate"]
            val rawEndDate = json["endDate"]
            if (rawStartDate !is String || rawStartDate.trim().isEmpty()) {
                throw IllegalArgumentException("missing schedule date rule start date")
            }
            if (rawEndDate !is String || rawEndDate.trim().isEmpty()) {
                throw IllegalArgumentException("missing schedule date rule end date")
            }
            val rawName = json["name"]
            if (rawName != null && rawName !is String) {
                throw IllegalArgumentException("schedule date rule name must be a string")
            }
            val rawId = json["id"]
            if (rawId != null && rawId !is String) {
                throw IllegalArgumentException("schedule date rule id must be a string")
            }
            val rawSchemeId = json["timeSchemeId"]
            if (rawSchemeId != null && rawSchemeId !is String) {
                throw IllegalArgumentException("schedule date rule timeSchemeId must be a string")
            }
            return ScheduleDateRule(
                id = (rawId as String?) ?: "",
                name = ((rawName as String?) ?: "").trim(),
                timeSchemeId = (rawSchemeId as String?) ?: "",
                enabled = when (val rawEnabled = json["enabled"]) {
                    null -> true
                    is Boolean -> rawEnabled
                    // Dart `json['enabled'] as bool?` 遇非 bool 抛 TypeError → 上层整条拒收。
                    else -> throw IllegalArgumentException("schedule date rule enabled must be a bool")
                },
                startDate = rawStartDate.trim(),
                endDate = rawEndDate.trim(),
            )
        }

        fun fromJsonString(jsonString: String): ScheduleDateRule {
            val decoded = com.mutx163.qingyu.core.MiniJson.parse(jsonString)
            if (decoded !is Map<*, *>) {
                throw IllegalArgumentException("schedule date rule json must be an object")
            }
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }
    }
}
