package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDateTime

/**
 * `saveCourseConfig` 桥消息的**解析与落盘口径**（I2-2；逐字对齐 Dart
 * `lib/domain/warehouse_course_import_logic.dart` 的 `WarehouseCourseConfigLogic.resolve`）。
 *
 * ## 语义契约
 *
 * - 只提取 `semesterTotalWeeks` 与 `semesterStartDate` 两项；
 * - **无效值不覆盖用户已有设置**：周数 ≤0 或开学日不是真实日历日 ⇒ 那一项按「脚本没给」处理；
 * - 上游 184 个脚本还会下发 [WAREHOUSE_UNSUPPORTED_COURSE_CONFIG_KEYS]，本 App 没有对应
 *   设置可落：记日志（调用方做），不静默丢弃也不假装存了。
 */
val WAREHOUSE_UNSUPPORTED_COURSE_CONFIG_KEYS: List<String> = listOf(
    "firstDayOfWeek",
    "defaultClassDuration",
    "defaultBreakDuration",
)

/** 解析结果；某一项为 null 表示「脚本没给可用值」，调用方必须保留用户已有设置。 */
data class WarehouseCourseConfigResolution(
    val semesterWeekCount: Int? = null,
    val semesterStartDate: LocalDateTime? = null,
) {
    val hasAnything: Boolean get() = semesterWeekCount != null || semesterStartDate != null
}

/**
 * 把适配器下发的开学日解析成**本地零点**。
 *
 * 为什么归一：该字段持久化后每次周次计算都会重读；UTC 时刻或带钟点的值会把工作日
 * 挪偏，让第 1 周从错误的一天开始，所以只留日历日期、丢掉钟点。
 *
 * 越界日历日期**拒绝，不回滚**：`2026-13-45` 会被宽松解析器归一成 2027-02-14，
 * 而这个值是全 App「今天第几周」的唯一输入——静默接受会毁掉一整学期的周次。
 * 回 null 让调用方保留用户现有值（与不可解析字符串同一契约）。
 */
fun warehouseSemesterStartDate(raw: Any?): LocalDateTime? {
    val text = raw?.toString()?.trim().orEmpty()
    if (text.isEmpty()) return null
    // ISO 与 `2026-9-7 08:00` 回退走同一条校验：取前导日历段，必须是真实的一天。
    val match = Regex("^(\\d{4})-(\\d{1,2})-(\\d{1,2})").find(text) ?: return null
    val year = match.groupValues[1].toIntOrNull() ?: return null
    val month = match.groupValues[2].toIntOrNull() ?: return null
    val day = match.groupValues[3].toIntOrNull() ?: return null
    // LocalDate.of 对 2026-13-45 / 2026-02-30 直接抛——这正是我们要的「拒绝」。
    val date = runCatching { java.time.LocalDate.of(year, month, day) }.getOrNull() ?: return null
    return date.atStartOfDay()
}

/** 解析 `saveCourseConfig` 的载荷（已解码的 JSON 对象）。 */
fun resolveWarehouseCourseConfig(decoded: Map<*, *>): WarehouseCourseConfigResolution {
    // coerceInt 而不是裸转：适配器发 `semesterTotalWeeks: "20"` 不能抛。
    val weekCount = WarehouseCourseImportLogic.coerceInt(decoded["semesterTotalWeeks"])
    return WarehouseCourseConfigResolution(
        // 0 / 负数视为「没给」，不是字面 0 周学期。
        semesterWeekCount = weekCount?.takeIf { it > 0 },
        semesterStartDate = warehouseSemesterStartDate(decoded["semesterStartDate"]),
    )
}

/** `saveCourseConfig` / `savePresetTimeSlots` 桥消息的公共解包：requestId + payload。 */
data class WarehouseBridgeSaveRequest(val requestId: String, val payload: String)

/**
 * 解包 `saveCourseConfig` / `savePresetTimeSlots` 消息；requestId 不可信或形状不对回 null
 * （调用方据此「不注入任何 JS」，与 [warehouseBridgeFallbackAnswer] 的口径一致）。
 */
fun warehouseBridgeSaveRequest(raw: String?, expectedType: String): WarehouseBridgeSaveRequest? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parsed = MiniJson.tryParse(text) as? Map<*, *> ?: return null
    if (parsed["type"] as? String != expectedType) return null
    val requestId = (parsed["requestId"] as? String)?.trim().orEmpty()
    if (!isSafeWarehouseBridgeRequestId(requestId)) return null
    val payload = parsed["payload"] as? String ?: return null
    return WarehouseBridgeSaveRequest(requestId, payload)
}
