package com.mutx163.qingyu.core

/**
 * 作息日期规则模型（**唯一真源**）——换档用的日期区间规则。
 *
 * ## 产品语义（不是连续软覆盖）
 *
 * - 规则区间内的**首次打开**（或当天首开）会把 [timeSchemeId] 批量套用成档案默认作息、
 *   并重写未锁定的课程钟点（走「应用时间模板」同一条路径）；
 * - 之后用户可以手工改课程，日常打开**不再重复套用**；
 * - 课程手动覆盖与地点分组仍然优先。
 *
 * 产品上限：单机最多 2 条规则，**含停用的**（`ScheduleDateRuleLogic.MAX_RULES_PER_DEVICE`）；
 * 日期区间不得重叠这一条只对启用中的规则检查。
 *
 * ## JSON 契约（与 Dart `lib/models/schedule_date_rule.dart` 逐字一致）
 *
 * 字段名固定：`id` / `name` / `timeSchemeId` / `enabled` / `startDate` / `endDate`；
 * [toJson] 的键序也按这个顺序落盘（两代实现逐字节一致的顺序，别改）。
 *
 * ## P1-11：为什么在这里（2026-11-11）
 *
 * 此前这份模型有三份副本：`calendar/ScheduleDateRule`（日历逻辑入参）、
 * `core/TimeSchemeLogic.ScheduleDateRule`（落盘真源）、`pages/schedule/ScheduleDateRuleData`
 * （日程页 UI）。三处字段同名同序、靠 `toCalendarDateRule` / `toCoreDateRule` /
 * `toUiRule` 三个转换函数来回搬。现在真源收到这里，另外两处只剩 `typealias`，转换函数删除。
 *
 * **字段顺序是冻结的**：仓库里还有位置参数构造（`ScheduleDateRule(id, name, timeSchemeId,
 * startDate, endDate[, enabled])`），调换顺序会静默错位而不是编译失败。
 *
 * ## 解析口径：Dart 严格，不再"宽松兜底"
 *
 * 真源统一后 [fromJson] 收紧到 Dart 口径：`startDate`/`endDate` 缺失或空串、
 * 各字符串字段类型不符、`enabled` 非布尔都抛 [DartFormatException]（消息逐字沿用）。
 * 落盘读取侧（`TimetableStore.loadScheduleDateRules` / `LegacyBackupPackage`）本来就是
 * **逐条 catch 丢弃**，所以收紧只影响坏条目的接受度，不动已落盘的好数据。
 */
data class ScheduleDateRule(
    val id: String,
    val name: String,
    val timeSchemeId: String,
    /** 含头，`yyyy-MM-dd`（本地日历日）。 */
    val startDate: String,
    /** 含尾，`yyyy-MM-dd`（本地日历日）。 */
    val endDate: String,
    val enabled: Boolean = true,
) {
    fun toJson(): LinkedHashMap<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "timeSchemeId" to timeSchemeId,
        "enabled" to enabled,
        "startDate" to startDate,
        "endDate" to endDate,
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        /**
         * Dart `ScheduleDateRule.fromJson`（严格版）：
         * - `startDate` / `endDate` 非字符串或 trim 后为空 → [DartFormatException]（文案逐字）；
         * - `id` / `timeSchemeId` 缺省 `''`；`name` trim 后缺省 `''`；`enabled` 缺省 `true`；
         * - 出现却类型不符的 `id` / `name` / `timeSchemeId` / `enabled` → [DartFormatException]
         *   （对齐 Dart 里 `as String?` / `as bool?` 抛 TypeError、上层整条拒收的行为）；
         * - `startDate` / `endDate` 落库前 trim。
         */
        fun fromJson(json: Map<String, Any?>): ScheduleDateRule {
            val rawStartDate = json["startDate"]
            val rawEndDate = json["endDate"]
            if (rawStartDate !is String || rawStartDate.trim().isEmpty()) {
                throw DartFormatException("missing schedule date rule start date")
            }
            if (rawEndDate !is String || rawEndDate.trim().isEmpty()) {
                throw DartFormatException("missing schedule date rule end date")
            }
            val rawName = json["name"]
            if (rawName != null && rawName !is String) {
                throw DartFormatException("schedule date rule name must be a string")
            }
            val rawId = json["id"]
            if (rawId != null && rawId !is String) {
                throw DartFormatException("schedule date rule id must be a string")
            }
            val rawSchemeId = json["timeSchemeId"]
            if (rawSchemeId != null && rawSchemeId !is String) {
                throw DartFormatException("schedule date rule timeSchemeId must be a string")
            }
            val enabled = when (val rawEnabled = json["enabled"]) {
                null -> true
                is Boolean -> rawEnabled
                else -> throw DartFormatException("schedule date rule enabled must be a bool")
            }
            return ScheduleDateRule(
                id = rawId as String? ?: "",
                name = ((rawName as String?) ?: "").trim(),
                timeSchemeId = rawSchemeId as String? ?: "",
                startDate = rawStartDate.trim(),
                endDate = rawEndDate.trim(),
                enabled = enabled,
            )
        }

        fun fromJsonString(jsonString: String): ScheduleDateRule {
            val decoded = MiniJson.parse(jsonString)
            if (decoded !is Map<*, *>) {
                throw DartFormatException("schedule date rule json must be an object")
            }
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }
    }
}
