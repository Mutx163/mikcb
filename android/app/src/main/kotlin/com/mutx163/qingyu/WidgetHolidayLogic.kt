package com.mutx163.qingyu

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

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

/**
 * 与 Flutter [HolidayData.isAdjustedWorkday] 同语义：当天若有自定义放假条目，
 * 调休补班让位（自定义放假优先）；否则只要有 `adjusted_workday` 条目就算补班。
 */
internal fun widgetResolveIsAdjustedWorkday(
    entries: List<WidgetHolidayEntry>,
    dateStr: String,
): Boolean {
    val dayEntries = entries.filter { it.date == dateStr }
    val hasCustomHide = dayEntries.any {
        widgetHolidayShouldHideCourses(it.type) && widgetHolidayIsCustomEntry(it.groupId)
    }
    if (hasCustomHide) {
        return false
    }
    return dayEntries.any { widgetHolidayIsAdjustedWorkday(it.type) }
}

/**
 * 「周末文案」档位，与 Dart `WeekendMood` 同取值、同判据。
 *
 * 刻意**不新增 snapshot state**：`state == "holiday"` 放假态会连带清空刷新触发点
 * （见 `findNextRefreshAtMillis`），周五下课那一刻就没有闹钟把文案翻过来了；
 * 而且 `state` 一改，原生侧二十余处 `"holiday"` 比较全部要重新对齐。
 * 周末更**不能**进 `isHoliday` 体系——那会让「周末有课」被整段抹掉。
 */
enum class WidgetWeekendMood(val value: String) {
    NONE("none"),
    REST("rest"),
    AHEAD("ahead"),
    ;

    companion object {
        /** 老快照没有这个键、或原生塞了脏值时一律回落 NONE。 */
        fun fromValue(raw: String?): WidgetWeekendMood = when (raw?.trim()) {
            REST.value -> REST
            AHEAD.value -> AHEAD
            else -> NONE
        }
    }
}

/**
 * 与 Dart `resolveWeekendMood` 逐条同口径的纯函数（入参全是基本类型，方便单测）。
 *
 * [dayOfWeek] 1=周一 … 7=周日（与 `calendarDayToWeekday` 一致）。
 *
 * 「有课」含**停课当天**：那天确实排了课（只是全停了），不该冒出一句
 * 「周末愉快」把停课这件事盖掉。
 */
internal fun widgetResolveWeekendMood(
    dayOfWeek: Int,
    hasAnyCourse: Boolean,
    hasRemainingCourse: Boolean,
    isHolidayToday: Boolean,
    isAdjustedWorkdayToday: Boolean,
    isAdjustedWorkdayTomorrow: Boolean,
): WidgetWeekendMood {
    if (isHolidayToday) {
        return WidgetWeekendMood.NONE
    }
    val isWeekend = dayOfWeek == 6 || dayOfWeek == 7
    if (isWeekend) {
        if (isAdjustedWorkdayToday || hasAnyCourse) {
            return WidgetWeekendMood.NONE
        }
        return WidgetWeekendMood.REST
    }
    if (dayOfWeek == 5) {
        if (isAdjustedWorkdayTomorrow || hasRemainingCourse) {
            return WidgetWeekendMood.NONE
        }
        return WidgetWeekendMood.AHEAD
    }
    return WidgetWeekendMood.NONE
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

/** Built-in holiday names that Flutter persists as stable keys instead of display text. */
internal enum class WidgetHolidayLabel {
    NewYear,
    LaborDay,
    NationalDay,
    SpringFestival,
    Qingming,
    DragonBoat,
    MidAutumn,
    MakeupWorkday,
    Statutory,
}

/**
 * Resolves a persisted holiday name to the built-in label it stands for.
 *
 * The key set mirrors Flutter's `localizedHolidayName` in
 * `lib/l10n/holiday_name_localizer.dart` so the app and the widgets name the
 * same holiday the same way. Names that are not built-in (user-defined
 * holidays) are already display text and return null so callers keep them
 * verbatim.
 */
internal fun widgetHolidayLabel(name: String?): WidgetHolidayLabel? {
    return when (name?.trim()) {
        "holiday_name:new_year", "元旦" -> WidgetHolidayLabel.NewYear
        "holiday_name:labor_day", "劳动节" -> WidgetHolidayLabel.LaborDay
        "holiday_name:national_day", "国庆节" -> WidgetHolidayLabel.NationalDay
        "holiday_name:spring_festival", "春节" -> WidgetHolidayLabel.SpringFestival
        "holiday_name:qingming", "清明节" -> WidgetHolidayLabel.Qingming
        "holiday_name:dragon_boat", "端午节" -> WidgetHolidayLabel.DragonBoat
        "holiday_name:mid_autumn", "中秋节" -> WidgetHolidayLabel.MidAutumn
        "holiday_name:makeup_workday", "调休上班" -> WidgetHolidayLabel.MakeupWorkday
        "holiday_name:statutory",
        "法定假日",
        "法定节假日",
        "Public holiday",
        "Holiday",
        -> WidgetHolidayLabel.Statutory
        else -> null
    }
}

/**
 * Turns a persisted holiday name into text a widget can display.
 *
 * The widget snapshot is produced by two independent paths — pushed by Flutter
 * and rebuilt offline from SharedPreferences when the app has not run — and
 * both carry the raw `holiday_name:*` key. Translating here covers both, and
 * keeps widget text on the system language like every other widget string.
 */
internal fun widgetLocalizeHolidayName(context: Context, name: String?): String? {
    if (name.isNullOrBlank()) return name
    val label = widgetHolidayLabel(name) ?: return name
    val resId = when (label) {
        WidgetHolidayLabel.NewYear -> R.string.widget_holiday_new_year
        WidgetHolidayLabel.LaborDay -> R.string.widget_holiday_labor_day
        WidgetHolidayLabel.NationalDay -> R.string.widget_holiday_national_day
        WidgetHolidayLabel.SpringFestival -> R.string.widget_holiday_spring_festival
        WidgetHolidayLabel.Qingming -> R.string.widget_holiday_qingming
        WidgetHolidayLabel.DragonBoat -> R.string.widget_holiday_dragon_boat
        WidgetHolidayLabel.MidAutumn -> R.string.widget_holiday_mid_autumn
        WidgetHolidayLabel.MakeupWorkday -> R.string.widget_holiday_makeup_workday
        WidgetHolidayLabel.Statutory -> R.string.widget_holiday_statutory
    }
    return context.getString(resId)
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
    // Locale.US：假期键要和 Flutter 下发的 ASCII `yyyy-MM-dd` 逐字比对，默认 Locale
    // 在阿语/波斯语设备上会产出非 ASCII 数字，比对永不成立 → 小组件假期标记失效。
    return String.format(
        Locale.US,
        "%04d-%02d-%02d",
        year,
        month,
        dayOfMonth,
    )
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
