package com.mutx163.qingyu

import org.json.JSONArray
import org.json.JSONObject

/**
 * Mirrors Flutter [HolidayEntry] / [HolidayData] / [TimetableProvider.isHoliday]
 * so the home widget can resolve holidays offline from Flutter SharedPreferences.
 */
internal data class WidgetHolidayEntry(
    val date: String,
    val name: String,
    val type: String,
    val groupId: String?,
)

internal fun widgetHolidayShouldHideCourses(type: String): Boolean {
    return type == "vacation" || type == "adjusted_restday"
}

internal fun widgetHolidayIsAdjustedWorkday(type: String): Boolean {
    return type == "adjusted_workday"
}

internal fun widgetHolidayIsCustomEntry(groupId: String?): Boolean {
    return groupId != null && groupId.startsWith("custom-")
}

/**
 * Same semantics as Flutter [TimetableProvider.isHoliday]:
 * 1. Adjusted workday (not overridden by custom rest) → not holiday
 * 2. holidayOverrideEnabled → holiday
 * 3. enableHolidayMarking off → not holiday
 * 4. Else hide-course entries (custom rest beats adjusted workday)
 */
internal fun widgetResolveIsHoliday(
    entries: List<WidgetHolidayEntry>,
    dateStr: String,
    enableHolidayMarking: Boolean,
    holidayOverrideEnabled: Boolean,
): Boolean {
    val dayEntries = entries.filter { it.date == dateStr }
    val hasCustomHide = dayEntries.any {
        widgetHolidayShouldHideCourses(it.type) && widgetHolidayIsCustomEntry(it.groupId)
    }
    val hasAdjustedWorkday = dayEntries.any { widgetHolidayIsAdjustedWorkday(it.type) }

    if (!hasCustomHide && hasAdjustedWorkday) {
        return false
    }
    if (holidayOverrideEnabled) {
        return true
    }
    if (!enableHolidayMarking) {
        return false
    }
    if (hasCustomHide) {
        return true
    }
    if (hasAdjustedWorkday) {
        return false
    }
    return dayEntries.any { widgetHolidayShouldHideCourses(it.type) }
}

internal fun widgetResolveHolidayName(
    entries: List<WidgetHolidayEntry>,
    dateStr: String,
): String? {
    val dayEntries = entries.filter { it.date == dateStr }
    val customHide = dayEntries.firstOrNull {
        widgetHolidayShouldHideCourses(it.type) && widgetHolidayIsCustomEntry(it.groupId)
    }
    if (customHide != null) {
        return customHide.name.takeIf { it.isNotBlank() }
    }
    return dayEntries
        .firstOrNull { widgetHolidayShouldHideCourses(it.type) }
        ?.name
        ?.takeIf { it.isNotBlank() }
}

internal fun widgetParseHolidayEntriesFromHolidayDataJson(raw: String?): List<WidgetHolidayEntry> {
    if (raw.isNullOrBlank()) {
        return emptyList()
    }
    return try {
        val root = JSONObject(raw)
        val entriesArray = root.optJSONArray("entries") ?: return emptyList()
        parseHolidayEntryArray(entriesArray)
    } catch (_: Exception) {
        emptyList()
    }
}

internal fun widgetParseHolidayEntriesFromCustomJson(raw: String?): List<WidgetHolidayEntry> {
    if (raw.isNullOrBlank()) {
        return emptyList()
    }
    return try {
        parseHolidayEntryArray(JSONArray(raw))
    } catch (_: Exception) {
        emptyList()
    }
}

internal fun widgetFormatDate(year: Int, month: Int, dayOfMonth: Int): String {
    return String.format("%04d-%02d-%02d", year, month, dayOfMonth)
}

private fun parseHolidayEntryArray(array: JSONArray): List<WidgetHolidayEntry> {
    return buildList {
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            val date = item.optString("date").take(10)
            if (date.length != 10) {
                continue
            }
            val name = item.optString("name")
            val type = item.optString("type", "vacation").ifBlank { "vacation" }
            val groupId = item.optString("groupId").takeIf { it.isNotBlank() }
            add(
                WidgetHolidayEntry(
                    date = date,
                    name = name,
                    type = type,
                    groupId = groupId,
                ),
            )
        }
    }
}
