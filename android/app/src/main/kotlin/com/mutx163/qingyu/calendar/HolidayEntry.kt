package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDateTime

/**
 * 节假日类型（移植自 lib/models/holiday_entry.dart:3-28，枚举取值逐字一致）。
 *
 * - [Vacation]   ↔ Dart `HolidayType.vacation`，JSON 值 `vacation`
 * - [AdjustedWorkday] ↔ Dart `HolidayType.adjustedWorkday`，JSON 值 `adjusted_workday`
 * - [AdjustedRestday] ↔ Dart `HolidayType.adjustedRestday`，JSON 值 `adjusted_restday`
 */
enum class HolidayType(val value: String) {
    /** 法定假期（国庆、清明等），课表灰显/隐藏 */
    Vacation("vacation"),

    /** 调休上班日（周末但需要上课） */
    AdjustedWorkday("adjusted_workday"),

    /** 调休休息日（工作日但放假） */
    AdjustedRestday("adjusted_restday"),
    ;

    companion object {
        /**
         * Dart `HolidayTypeX.fromValue`：未知 / 缺失一律回落 [Vacation]
         * （firstWhere orElse 语义）。
         */
        fun fromValue(value: String?): HolidayType =
            values().firstOrNull { it.value == value } ?: Vacation
    }
}

/**
 * 单日节假日条目（移植自 lib/models/holiday_entry.dart:31-85）。
 *
 * JSON 契约与 Dart 逐字一致：键为 `date` / `name` / `type` / `groupId`，
 * `groupId` 为 null 时**保留键**输出 `null`（Dart jsonEncode 同口径）。
 */
data class HolidayEntry(
    /** 日期。Dart 侧注释为「仅日期部分，时间归零」；匹配时只比 y/m/d。 */
    val date: LocalDateTime,

    /** 显示名称，如"国庆节"、"调休上班" */
    val name: String,

    /** 节假日类型 */
    val type: HolidayType,

    /** 所属假期组 ID（如"national-day-2026"），用于合并显示横幅 */
    val groupId: String? = null,
) {
    /** 该日期是否应该隐藏/灰显课程 */
    val shouldHideCourses: Boolean
        get() = type == HolidayType.Vacation || type == HolidayType.AdjustedRestday

    /** 该日期是否为调休上班日（需要显示课程） */
    val isAdjustedWorkday: Boolean
        get() = type == HolidayType.AdjustedWorkday

    fun toJson(): LinkedHashMap<String, Any?> = linkedMapOf(
        // Dart: date.toIso8601String().substring(0, 10) → `yyyy-MM-dd`
        "date" to DartTime.toIso(date).substring(0, 10),
        "name" to name,
        "type" to type.value,
        "groupId" to groupId,
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        /**
         * Dart `HolidayEntry.fromJson`：结构性缺失（date/name 非字符串或空白、
         * date 解析失败）抛 FormatException，由上层按「坏条目跳过」消化。
         * Kotlin 侧用 [DartFormatException] 承载同一契约。
         */
        fun fromJson(json: Map<String, Any?>): HolidayEntry {
            val rawDate = json["date"]
            if (rawDate !is String || rawDate.trim().isEmpty()) {
                throw DartFormatException("missing holiday date")
            }
            // Dart DateTime.tryParse 的宽容子集（见 core/DartTime.tryParseIso）：
            // `yyyy-MM-dd`、`yyyy-M-d H:m:s`、ISO datetime。
            val parsedDate = DartTime.tryParseIso(rawDate)
                ?: throw DartFormatException("invalid holiday date: $rawDate")
            val rawName = json["name"]
            if (rawName !is String || rawName.trim().isEmpty()) {
                throw DartFormatException("missing holiday name")
            }
            val rawType = json["type"]
            if (rawType != null && rawType !is String) {
                // Dart `json['type'] as String?` 遇非字符串抛 TypeError → 上层整条跳过。
                throw DartFormatException("holiday type must be a string")
            }
            val rawGroupId = json["groupId"]
            if (rawGroupId != null && rawGroupId !is String) {
                throw DartFormatException("holiday groupId must be a string")
            }
            return HolidayEntry(
                date = parsedDate,
                name = rawName,
                type = HolidayType.fromValue(rawType as String?),
                groupId = rawGroupId as String?,
            )
        }
    }
}
