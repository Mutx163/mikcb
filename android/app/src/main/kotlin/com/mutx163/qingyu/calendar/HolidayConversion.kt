package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime

/**
 * 节假日远程数据的**纯转换**部分（移植自 lib/services/holiday_service.dart:364-535
 * `_convertApiEntries` / `_convertAilccEntries`，不含 HTTP / prefs / 日志）。
 *
 * 输入形态说明：
 * - xiaoai 格式：`{"code":0,"data":[{"date":"2026-10-01","daytype":1,"rest":1},...]}`
 *   的 `data` 列表。daytype：1=假期、2=补班、3=周末、4=工作日；只有 daytype==1
 *   （假期）与 daytype==3 且 rest==0（调休上班）参与转换，其余条目跳过。
 * - ailcc 格式：`{"code":0,"holiday":{"01-01":{"holiday":true,"name":"元旦节（休）","date":"2026-01-01"},...}}`
 *   的 `holiday` 映射。holiday=true 进假期；holiday=false 且 name 含「班」进调休上班。
 *
 * 转换语义（与 Dart 逐条一致）：
 * 1. 坏条目（缺日期、日期不可解析、缺 daytype）**静默跳过**，好条目照常保留
 *    （1cc9aca 起的容错口径：单条坏数据不许毒化整年假期）；
 * 2. 假期日期先排序再切连续段（远程不保证升序）；
 * 3. groupId 形如 `holiday-<year>-<组序号>`；
 * 4. 调休上班日挂到**最近**的假期组（距组首、组尾的日历日差取较小者，
 *    21 天内才有组可挂；超出 21 天 groupId 为 null）；
 * 5. 调休上班条目的 name 固定为 [HolidayServiceConstants.HOLIDAY_NAME_MAKEUP_WORKDAY_KEY]。
 */
object HolidayApiConverter {

    /** 解析后的单条远程输入：daytype/rest（xiaoai）或 holiday/name（ailcc）的统一中间形。 */
    private sealed interface RemoteDay

    private data class XiaoaiDay(val date: LocalDateTime, val daytype: Long, val rest: Long) : RemoteDay
    private data class AilccDay(val date: LocalDateTime, val isHoliday: Boolean, val name: String) : RemoteDay

    /** Dart `_convertApiEntries`（xiaoai）。[list] 为 `data` 数组的解码产物。 */
    fun convertApiEntries(list: List<Any?>, year: Int): List<HolidayEntry> {
        val days = mutableListOf<XiaoaiDay>()
        for (item in list) {
            try {
                if (item !is Map<*, *>) continue
                val rawDaytype = item["daytype"]
                val daytype = when (rawDaytype) {
                    is Long -> rawDaytype
                    is Int -> rawDaytype.toLong()
                    is Double -> rawDaytype.toLong()
                    else -> continue
                }
                val rest = when (val rawRest = item["rest"]) {
                    is Long -> rawRest
                    is Int -> rawRest.toLong()
                    is Double -> rawRest.toLong()
                    null -> 1L // Dart: (map['rest'] as num?)?.toInt() ?? 1
                    else -> continue
                }
                val rawDate = item["date"]
                if (rawDate !is String || rawDate.trim().isEmpty()) continue
                val date = DartTime.tryParseIso(rawDate) ?: continue
                days.add(XiaoaiDay(date, daytype, rest))
            } catch (_: Exception) {
                continue
            }
        }
        val holidayDates = days.filter { it.daytype == 1L }.map { it.date } // 假期
        val makeupDates = days.filter { it.daytype == 3L && it.rest == 0L }.map { it.date } // 调休上班
        return buildEntries(holidayDates, makeupDates, year)
    }

    /** Dart `_convertAilccEntries`（ailcc）。[holidayMap] 为 `holiday` 对象的解码产物。 */
    fun convertAilccEntries(holidayMap: Map<String, Any?>, year: Int): List<HolidayEntry> {
        val days = mutableListOf<AilccDay>()
        for ((_, rawVal) in holidayMap) {
            try {
                if (rawVal !is Map<*, *>) continue
                val rawDate = rawVal["date"]
                if (rawDate !is String || rawDate.trim().isEmpty()) continue
                val date = DartTime.tryParseIso(rawDate) ?: continue
                val isHoliday = parseAilccHolidayFlag(rawVal["holiday"]) ?: continue
                val name = (rawVal["name"] as? String) ?: ""
                days.add(AilccDay(date, isHoliday, name))
            } catch (_: Exception) {
                continue
            }
        }
        val holidayDates = days.filter { it.isHoliday }.map { it.date }
        // holiday=false 且名称含「班」才视为调休上班（Dart: name.contains('班')）。
        val makeupDates = days.filter { !it.isHoliday && it.name.contains("班") }.map { it.date }
        return buildEntries(holidayDates, makeupDates, year)
    }

    /**
     * Dart ailcc `holiday` 字段的三形态：bool / 数字（1 真 0 假）/ 字符串
     * （true/1/yes 真、false/0/no 假，trim + 小写后比较）；解析不出 → 条目跳过。
     */
    private fun parseAilccHolidayFlag(raw: Any?): Boolean? = when (raw) {
        is Boolean -> raw
        is Long -> when (raw) {
            1L -> true
            0L -> false
            else -> null
        }
        is Int -> when (raw) {
            1 -> true
            0 -> false
            else -> null
        }
        is Double -> when (raw) {
            1.0 -> true
            0.0 -> false
            else -> null
        }
        is String -> when (raw.trim().lowercase()) {
            "true", "1", "yes" -> true
            "false", "0", "no" -> false
            else -> null
        }
        else -> null
    }

    /** 两条转换线共享的「切组 → 造条目 → 挂调休」尾部（Dart 两处相同代码）。 */
    private fun buildEntries(
        holidayDates: List<LocalDateTime>,
        makeupDates: List<LocalDateTime>,
        year: Int,
    ): List<HolidayEntry> {
        // 先按日期升序再切"连续段"：远程不保证升序，乱序会把一段假拆成多组。
        val groups = groupConsecutiveHolidayDates(holidayDates)

        val entries = mutableListOf<HolidayEntry>()
        val groupIds = mutableListOf<String>()
        for ((index, group) in groups.withIndex()) {
            val name = HolidayServiceConstants.nameForGroup(group)
            val groupId = "holiday-$year-$index"
            groupIds.add(groupId)
            for (date in group) {
                entries.add(
                    HolidayEntry(
                        date = date,
                        name = name,
                        type = HolidayType.Vacation,
                        groupId = groupId,
                    ),
                )
            }
        }
        for (date in makeupDates) {
            // Find the nearest holiday group (within 21 days).
            var nearestGroupId: String? = null
            var minDist = 22L
            for ((index, group) in groups.withIndex()) {
                val dist = absDays(date, group.first())
                val distEnd = absDays(date, group.last())
                val d = if (dist < distEnd) dist else distEnd
                if (d < minDist) {
                    minDist = d
                    nearestGroupId = groupIds[index]
                }
            }
            entries.add(
                HolidayEntry(
                    date = date,
                    name = HolidayServiceConstants.HOLIDAY_NAME_MAKEUP_WORKDAY_KEY,
                    type = HolidayType.AdjustedWorkday,
                    groupId = nearestGroupId,
                ),
            )
        }
        return entries
    }

    /** Dart `_absDays(a, b) == WeekCalculator.daysBetween(b, a).abs()`。 */
    private fun absDays(a: LocalDateTime, b: LocalDateTime): Long =
        kotlin.math.abs(WeekCalculator.daysBetween(b, a))
}

/**
 * 自定义假期持久化失败/数据损坏异常（移植自 holiday_service.dart:728-738）。
 *
 * 携带 cause 便于上层归因；错误信息不含用户数据，可直接展示或上报。
 */
class HolidayCustomSaveException(
    message: String,
    cause: Throwable? = null,
) : RuntimeException(message, cause)

/**
 * 自定义假期列表的**纯增删改**（移植自 holiday_service.dart:680-722 的
 * load → mutate → save 形状；读写 prefs 由宿主完成，本层只给纯变换）。
 *
 * 关键纪律（Issue #52 审核钉住）：`load` 返回 null 表示持久化数据**损坏**，
 * 绝不能当空列表 append 写回——否则一次保存会把真实数据覆盖清零。
 */
object CustomHolidayListOps {

    /**
     * 纯变换入口：[existing] 为当前持久化列表（null = 损坏态）。
     * 返回 null 表示损坏态下拒绝变换（调用方不得写回）。
     */
    fun mutate(
        existing: List<HolidayEntry>?,
        operation: Operation,
    ): List<HolidayEntry>? {
        if (existing == null) {
            return null // 损坏态：拒绝写回，调用方应抛 HolidayCustomSaveException
        }
        val mutable = existing.toMutableList()
        when (operation) {
            is Operation.Add -> mutable.add(operation.entry)
            is Operation.AddMany -> mutable.addAll(operation.entries)
            is Operation.Remove ->
                mutable.removeAll { it.groupId == operation.groupId }
            is Operation.Update -> {
                mutable.removeAll { it.groupId == operation.groupId }
                mutable.addAll(operation.newEntries)
            }
        }
        return mutable
    }

    /** Dart addCustomHoliday / addCustomHolidays / removeCustomHoliday / updateCustomHoliday 的操作形。 */
    sealed interface Operation {
        data class Add(val entry: HolidayEntry) : Operation
        data class AddMany(val entries: List<HolidayEntry>) : Operation
        data class Remove(val groupId: String) : Operation
        data class Update(val groupId: String, val newEntries: List<HolidayEntry>) : Operation
    }

    /**
     * Dart `saveCustomHolidays` 的 JSON 序列化形状：`List<HolidayEntry.toJson()>`。
     * 供宿主写 prefs 前调用；读回用 [parsePersistedList]。
     */
    fun encodePersistedList(entries: List<HolidayEntry>): String =
        MiniJson.encode(entries.map { it.toJson() })

    /**
     * Dart `loadCustomHolidays` 的解析形状：整体解析失败 → null（损坏态）；
     * 单条坏条目跳过；`raw == null` → 空列表（合法的「没有数据」）。
     */
    fun parsePersistedList(raw: String?): List<HolidayEntry>? {
        if (raw == null) return emptyList()
        val decoded = try {
            MiniJson.parse(raw)
        } catch (_: Exception) {
            return null
        }
        if (decoded !is List<*>) {
            return null
        }
        val out = mutableListOf<HolidayEntry>()
        for (e in decoded) {
            try {
                if (e !is Map<*, *>) continue
                @Suppress("UNCHECKED_CAST")
                out.add(HolidayEntry.fromJson(e as Map<String, Any?>))
            } catch (_: Exception) {
                continue
            }
        }
        return out
    }
}
