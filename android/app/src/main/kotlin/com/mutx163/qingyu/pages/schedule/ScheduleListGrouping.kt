package com.mutx163.qingyu.pages.schedule

import java.time.LocalDate

/**
 * 日程列表页的一行状态：条目 + 解析后的时间状态（移植 `lib/domain/schedule_list_grouping.dart`）。
 */
data class ScheduleListEntry(
    val item: ScheduleItemData,
    val nextDate: String?,
    val ongoing: Boolean = false,
) {
    val isExpired: Boolean
        get() = nextDate == null
}

/**
 * 日程列表页的三组条目：即将到来 / 已过期 / 已暂停。
 */
data class ScheduleListGroups(
    val upcoming: List<ScheduleListEntry>,
    val past: List<ScheduleListEntry>,
    val paused: List<ScheduleListEntry>,
) {
    val isEmpty: Boolean
        get() = upcoming.isEmpty() && past.isEmpty() && paused.isEmpty()
}

/**
 * 日程列表分组服务（纯 Kotlin，移植自 `lib/domain/schedule_list_grouping.dart` 的 `ScheduleListGrouper`）。
 */
object ScheduleListGrouper {

    /**
     * 按启用/暂停与下次发生日是否不早于今日 [todayIso] 分成三组并排序。
     */
    fun group(items: List<ScheduleItemData>, todayIso: String): ScheduleListGroups {
        val upcoming = ArrayList<ScheduleListEntry>()
        val past = ArrayList<ScheduleListEntry>()
        val paused = ArrayList<ScheduleListEntry>()

        for (item in items) {
            // 单次覆盖是重复日程的实例级数据，列表只收系列根
            if (item.seriesId != null) {
                continue
            }
            val entry = resolveEntry(item, todayIso)
            if (!item.enabled) {
                paused.add(entry)
            } else if (entry.isExpired) {
                past.add(entry)
            } else {
                upcoming.add(entry)
            }
        }

        return ScheduleListGroups(
            upcoming = sortUpcoming(upcoming),
            past = sortPast(past),
            paused = sortPaused(paused),
        )
    }

    private fun resolveEntry(item: ScheduleItemData, todayIso: String): ScheduleListEntry {
        val startIso = item.startDate
        val endIso = item.endDate

        if (item.isRecurring) {
            val todayDate = ScheduleDateUtils.parseDate(todayIso)
            val startDate = ScheduleDateUtils.parseDate(startIso)
            val endDate = ScheduleDateUtils.parseDate(endIso)

            if (todayDate == null || startDate == null || endDate == null) {
                return ScheduleListEntry(item = item, nextDate = null)
            }

            var cursor = if (startDate.isAfter(todayDate)) startDate else todayDate
            while (!cursor.isAfter(endDate)) {
                val cursorIso = ScheduleDateUtils.formatDate(cursor)
                if (item.occursOn(cursorIso)) {
                    return ScheduleListEntry(item = item, nextDate = cursorIso)
                }
                cursor = cursor.plusDays(1)
            }
            return ScheduleListEntry(item = item, nextDate = null)
        }

        if (startIso >= todayIso) {
            return ScheduleListEntry(item = item, nextDate = startIso)
        }
        if (todayIso <= endIso) {
            // 跨天进行中的单次日程：开始日早于今天但区间仍覆盖今天
            return ScheduleListEntry(item = item, nextDate = startIso, ongoing = true)
        }
        return ScheduleListEntry(item = item, nextDate = null)
    }

    /**
     * 即将到来：下次发生日 → 开始时间 → 结束时间 → id。
     */
    private fun sortUpcoming(entries: List<ScheduleListEntry>): List<ScheduleListEntry> {
        return entries.sortedWith { left, right ->
            val dateCompare = (left.nextDate ?: "").compareTo(right.nextDate ?: "")
            if (dateCompare != 0) return@sortedWith dateCompare

            val startCompare = ScheduleDateUtils.compareClockText(
                left.item.startTime,
                right.item.startTime,
            )
            if (startCompare != 0) return@sortedWith startCompare

            val endCompare = ScheduleDateUtils.compareClockText(
                left.item.endTime,
                right.item.endTime,
            )
            if (endCompare != 0) return@sortedWith endCompare

            left.item.id.compareTo(right.item.id)
        }
    }

    /**
     * 已过期：结束日期新的在前，同日按开始时间倒序，id 兜底。
     */
    private fun sortPast(entries: List<ScheduleListEntry>): List<ScheduleListEntry> {
        return entries.sortedWith { left, right ->
            val endCompare = right.item.endDate.compareTo(left.item.endDate)
            if (endCompare != 0) return@sortedWith endCompare

            val startCompare = ScheduleDateUtils.compareClockText(
                right.item.startTime,
                left.item.startTime,
            )
            if (startCompare != 0) return@sortedWith startCompare

            left.item.id.compareTo(right.item.id)
        }
    }

    /**
     * 已暂停：按时间性下次发生日（无则退回开始日）新的在前，id 兜底。
     */
    private fun sortPaused(entries: List<ScheduleListEntry>): List<ScheduleListEntry> {
        return entries.sortedWith { left, right ->
            val leftKey = left.nextDate ?: left.item.startDate
            val rightKey = right.nextDate ?: right.item.startDate
            val keyCompare = rightKey.compareTo(leftKey)
            if (keyCompare != 0) return@sortedWith keyCompare

            left.item.id.compareTo(right.item.id)
        }
    }
}
