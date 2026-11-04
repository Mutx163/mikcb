package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDateTime
import java.util.Locale

/**
 * 年度节假日数据集合（移植自 lib/models/holiday_entry.dart:87-255）。
 */
data class HolidayData(
    /** 数据年份 */
    val year: Int,

    /** 数据版本（用于远程更新比对） */
    val version: Int,

    /** 所有节假日条目 */
    val entries: List<HolidayEntry>,
) {
    /** 按日期索引查询（时间分量不参与比较，返回列表顺序里的第一条）。 */
    fun entryForDate(date: LocalDateTime): HolidayEntry? {
        val dateOnly = DartTime.dateTime(date.year, date.monthValue, date.dayOfMonth)
        return entries.firstOrNull { isSameDate(it.date, dateOnly) }
    }

    /**
     * 某日期是否为假期（应隐藏课程）。
     *
     * 调休上班日优先级高于假期——同一天既有假期又有调休上班时，按上班处理。
     * 但用户手动设置的自定义假期优先级最高，覆盖调休上班日。
     */
    fun isHoliday(date: LocalDateTime): Boolean {
        val dateOnly = DartTime.dateTime(date.year, date.monthValue, date.dayOfMonth)
        // 自定义假期优先级最高
        if (entries.any {
                isSameDate(it.date, dateOnly) && it.shouldHideCourses && isCustomEntry(it)
            }
        ) {
            return true
        }
        if (entries.any { isSameDate(it.date, dateOnly) && it.isAdjustedWorkday }) {
            return false
        }
        return entries.any { isSameDate(it.date, dateOnly) && it.shouldHideCourses }
    }

    /**
     * `yyyy-MM-dd` keys for native surfaces (island / widget schedule).
     *
     * Uses full [isHoliday] semantics so custom makeup workdays that cover a
     * statutory vacation are excluded, matching Flutter timetable UI.
     */
    fun holidayDateKeysForSnapshot(): List<String> {
        val dateKeys = LinkedHashSet<String>()
        for (entry in entries) {
            val dateOnly = DartTime.dateTime(
                entry.date.year,
                entry.date.monthValue,
                entry.date.dayOfMonth,
            )
            if (!isHoliday(dateOnly)) {
                continue
            }
            dateKeys.add(dateKey(dateOnly))
        }
        return dateKeys.sorted()
    }

    /**
     * Effective makeup/adjusted workdays for native holiday override punch-through.
     *
     * Mirrors [isAdjustedWorkday] (custom rest still wins over makeup).
     */
    fun adjustedWorkdayDateKeysForSnapshot(): List<String> {
        val dateKeys = LinkedHashSet<String>()
        for (entry in entries) {
            if (!entry.isAdjustedWorkday) {
                continue
            }
            val dateOnly = DartTime.dateTime(
                entry.date.year,
                entry.date.monthValue,
                entry.date.dayOfMonth,
            )
            if (!isAdjustedWorkday(dateOnly)) {
                continue
            }
            dateKeys.add(dateKey(dateOnly))
        }
        return dateKeys.sorted()
    }

    /** 某日期是否为调休上班日（排除被自定义假期覆盖的情况）。 */
    fun isAdjustedWorkday(date: LocalDateTime): Boolean {
        val dateOnly = DartTime.dateTime(date.year, date.monthValue, date.dayOfMonth)
        // 如果该日期有自定义假期覆盖，则不算调休上班日
        if (entries.any {
                isSameDate(it.date, dateOnly) && it.shouldHideCourses && isCustomEntry(it)
            }
        ) {
            return false
        }
        return entries.any { isSameDate(it.date, dateOnly) && it.isAdjustedWorkday }
    }

    /** 获取连续假期组（按日期升序）。 */
    fun entriesForGroup(groupId: String): List<HolidayEntry> =
        entries.filter { it.groupId == groupId }.sortedBy { it.date }

    fun toJson(): LinkedHashMap<String, Any?> = linkedMapOf(
        "year" to year,
        "version" to version,
        "entries" to entries.map { it.toJson() },
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        /** Dart `HolidayData._isSameDate`：只比 y/m/d。 */
        fun isSameDate(a: LocalDateTime, b: LocalDateTime): Boolean =
            a.year == b.year && a.monthValue == b.monthValue && a.dayOfMonth == b.dayOfMonth

        /** Dart `HolidayData._isCustomEntry`：groupId 以 `custom-` 开头视为用户自建。 */
        fun isCustomEntry(e: HolidayEntry): Boolean =
            e.groupId != null && e.groupId.startsWith("custom-")

        /** Dart `HolidayData._dateKey`：年份不补零、月日补零（逐字对齐）。 */
        internal fun dateKey(dateOnly: LocalDateTime): String =
            String.format(
                Locale.ROOT,
                "%d-%02d-%02d",
                dateOnly.year,
                dateOnly.monthValue,
                dateOnly.dayOfMonth,
            )

        /**
         * Dart `HolidayData.fromJson`：year 接受整数 / 小数（截断）/ 数字字符串；
         * version 缺省 1；entries 缺省空列表，单条坏条目跳过、好条目保留。
         */
        fun fromJson(json: Map<String, Any?>): HolidayData {
            val rawYear = json["year"]
            val year: Int = when (rawYear) {
                is Int -> rawYear
                is Long -> if (rawYear in Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong()) {
                    rawYear.toInt()
                } else {
                    throw DartFormatException("holiday year out of range: $rawYear")
                }
                is Double -> {
                    if (rawYear.isNaN() || rawYear.isInfinite()) {
                        throw DartFormatException("invalid holiday year: $rawYear")
                    }
                    rawYear.toInt()
                }
                is String -> rawYear.trim().toLongOrNull()
                    ?.takeIf { it in Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong() }
                    ?.toInt()
                    ?: throw DartFormatException("invalid holiday year: $rawYear")
                else -> throw DartFormatException("missing holiday year")
            }
            val rawVersion = json["version"]
            val version: Int = when (rawVersion) {
                null -> 1
                is Number -> {
                    if (rawVersion is Double && (rawVersion.isNaN() || rawVersion.isInfinite())) {
                        throw DartFormatException("invalid holiday version: $rawVersion")
                    }
                    rawVersion.toInt()
                }
                else -> throw DartFormatException("holiday version must be a number")
            }
            val rawEntries = if (json["entries"] is List<*>) {
                json["entries"] as List<*>
            } else {
                emptyList<Any?>()
            }
            val entries = mutableListOf<HolidayEntry>()
            for (e in rawEntries) {
                try {
                    if (e !is Map<*, *>) {
                        continue
                    }
                    @Suppress("UNCHECKED_CAST")
                    entries.add(HolidayEntry.fromJson(e as Map<String, Any?>))
                } catch (_: Exception) {
                    continue
                }
            }
            return HolidayData(year = year, version = version, entries = entries)
        }

        fun fromJsonString(jsonString: String): HolidayData {
            val decoded = MiniJson.parse(jsonString)
            if (decoded !is Map<*, *>) {
                throw DartFormatException("holiday data json must be an object")
            }
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }
    }
}
