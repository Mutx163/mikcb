package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime

/**
 * 节假日展示判定领域服务（纯 Kotlin，无 Android / IO 依赖）。
 *
 * 移植自 lib/domain/holiday_resolver.dart。展示策略（解耦阶段 1 自
 * `TimetableProvider.isHoliday` 收口）：
 * 1. 调休上班日优先级最高——即使是假期覆盖模式也要显示课程；
 * 2. 假期覆盖模式开启时，所有假期都隐藏课程；
 * 3. 假期标记关闭时不隐藏；
 * 4. 其余按 [HolidayData] 判定；数据缺失视为无假期。
 *
 * 与原生侧已真机验证的读法（TodayWidgetSupport.kt / WidgetHolidayLogic.kt
 * 的 `widgetResolveIsHoliday`）对拍一致：
 *
 * | 场景                       | Dart HolidayResolver            | widgetResolveIsHoliday          |
 * |---------------------------|--------------------------------|--------------------------------|
 * | 调休上班（无自定义放假）      | `isHoliday=false`              | `return false`（hasAdjustedWorkday 分支） |
 * | 调休上班 + 自定义放假        | `isAdjustedWorkday=false` → 走 isHoliday → true | `hasCustomHide` 分支 → true |
 * | 覆盖模式（overrideEnabled） | true                           | `holidayOverrideEnabled` → true |
 * | 标记关闭                    | false                          | `!enableHolidayMarking` → false |
 *
 * 两份实现的输入形态不同（Dart 按日期对象比对、widget 按 `yyyy-MM-dd`
 * 字符串比对），判定序与结论完全同构。
 */
object HolidayResolver {

    /** [date] 是否为假期（应隐藏课程）。 */
    fun isHoliday(
        date: LocalDateTime,
        data: HolidayData?,
        overrideEnabled: Boolean,
        markingEnabled: Boolean,
    ): Boolean {
        if (data?.isAdjustedWorkday(date) == true) return false
        if (overrideEnabled) return true
        if (!markingEnabled) return false
        return data?.isHoliday(date) ?: false
    }

    /** [date] 是否为调休上班日（需要显示课程）。 */
    fun isAdjustedWorkday(date: LocalDateTime, data: HolidayData?): Boolean =
        data?.isAdjustedWorkday(date) ?: false
}

/**
 * 把一组假期日期先按日期升序，再切成"连续段"。
 *
 * 移植自 lib/domain/holiday_resolver.dart:40-69 `groupConsecutiveHolidayDates`。
 * 远程接口**不保证**按日期升序返回；乱序会把一段七天假拆成好几组（组名、
 * groupId、"调休挂到最近的一组"的距离全错）。排序是正确性的前置条件。
 * 去重并归一到"当天 00:00"：同一天重复出现（多源合并、接口重发、带时分秒）
 * 会被判成"不连续"从而**新起一组**。
 */
fun groupConsecutiveHolidayDates(dates: List<LocalDateTime>): List<List<LocalDateTime>> {
    if (dates.isEmpty()) return emptyList()
    // Dart 用 '${y}-${m}-${d}'（不补零）做键去重；Kotlin 同口径。
    val byDay = LinkedHashMap<String, LocalDateTime>()
    for (date in dates) {
        byDay.putIfAbsent(
            "${date.year}-${date.monthValue}-${date.dayOfMonth}",
            LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, 0, 0),
        )
    }
    val sorted = byDay.values.sorted()
    val groups = mutableListOf<List<LocalDateTime>>()
    var current: MutableList<LocalDateTime>? = null
    for (date in sorted) {
        val previous = current
        if (previous != null && WeekCalculator.daysBetween(previous.last(), date) == 1L) {
            previous.add(date)
        } else {
            if (previous != null) groups.add(previous)
            current = mutableListOf(date)
        }
    }
    current?.let { groups.add(it) }
    return groups
}

/**
 * 该加载哪几年的节假日数据。
 *
 * 移植自 lib/domain/holiday_resolver.dart:90-102 `holidayYearsToLoad`。
 * 判据：**当前这一周（周一起算）里出现过的年份都必须加载**（元旦、春节这类
 * 跨年假期整段挂在其中一年的响应里）；11 月之后预取下一年（学期横跨学年的
 * 既有意图）。
 */
fun holidayYearsToLoad(now: LocalDateTime): Set<Int> {
    // weekStart 的「dayOfWeek 回退」必须走日历日顺延（DartTime.dateTime 与 Dart
    // DateTime(y,m,d) 同语义）：跨年周如 2027-01-01（周五）会算出 day=-3，
    // LocalDateTime.of 直接抛 DayOfMonth，而 Dart 构造进位到 2026-12-28。
    val weekStart = DartTime.dateTime(
        now.year,
        now.monthValue,
        now.dayOfMonth - (now.dayOfWeek.value - 1),
    )
    val weekEnd = WeekCalculator.addDays(weekStart, 6)
    val years = linkedSetOf(now.year, weekStart.year, weekEnd.year)
    if (now.monthValue >= 11) {
        years.add(now.year + 1)
    }
    return years
}

/**
 * Built-in holiday names that Flutter persists as stable keys instead of
 * display text（移植自 lib/l10n/holiday_name_localizer.dart 的键集，
 * 与 WidgetHolidayLogic.kt `widgetHolidayLabel` / `WidgetHolidayLabel` 逐字一致）。
 */
enum class HolidayNameLabel {
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
 * holiday_name 归一化：把持久化的稳定键（或历史显示名）解析成内置标签。
 *
 * 键集与 Flutter `localizedHolidayName`（lib/l10n/holiday_name_localizer.dart）、
 * 原生 `widgetHolidayLabel`（WidgetHolidayLogic.kt:184-201）三方一致；
 * 非内置名（用户自定义假期）已就是显示文本，返回 null 让调用方原样保留。
 */
object HolidayNameNormalizer {

    private val byKey: Map<String, HolidayNameLabel> = mapOf(
        "holiday_name:new_year" to HolidayNameLabel.NewYear,
        "元旦" to HolidayNameLabel.NewYear,
        "holiday_name:labor_day" to HolidayNameLabel.LaborDay,
        "劳动节" to HolidayNameLabel.LaborDay,
        "holiday_name:national_day" to HolidayNameLabel.NationalDay,
        "国庆节" to HolidayNameLabel.NationalDay,
        "holiday_name:spring_festival" to HolidayNameLabel.SpringFestival,
        "春节" to HolidayNameLabel.SpringFestival,
        "holiday_name:qingming" to HolidayNameLabel.Qingming,
        "清明节" to HolidayNameLabel.Qingming,
        "holiday_name:dragon_boat" to HolidayNameLabel.DragonBoat,
        "端午节" to HolidayNameLabel.DragonBoat,
        "holiday_name:mid_autumn" to HolidayNameLabel.MidAutumn,
        "中秋节" to HolidayNameLabel.MidAutumn,
        "holiday_name:makeup_workday" to HolidayNameLabel.MakeupWorkday,
        "调休上班" to HolidayNameLabel.MakeupWorkday,
        "holiday_name:statutory" to HolidayNameLabel.Statutory,
        "法定假日" to HolidayNameLabel.Statutory,
        "法定节假日" to HolidayNameLabel.Statutory,
        "Public holiday" to HolidayNameLabel.Statutory,
        "Holiday" to HolidayNameLabel.Statutory,
    )

    /** [name] trim 后精确匹配；null / 空白 / 非内置名一律 null。 */
    fun labelOf(name: String?): HolidayNameLabel? {
        if (name == null) return null
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return null
        return byKey[trimmed]
    }
}

/**
 * HolidayService 侧随纯函数一起移植的常量与 key→name 映射
 * （移植自 lib/services/holiday_service.dart:99 与 _nameForGroup:545-574）。
 */
object HolidayServiceConstants {

    /** Dart `holidayNameMakeupWorkdayKey`：调休上班条目的稳定持久化名。 */
    const val HOLIDAY_NAME_MAKEUP_WORKDAY_KEY = "holiday_name:makeup_workday"

    /** Dart 命名别名，便于对拍。 */
    val holidayNameMakeupWorkdayKey: String get() = HOLIDAY_NAME_MAKEUP_WORKDAY_KEY

    /**
     * 内置标签 → 持久化 key（_nameForGroup 产出值的逆向表）。跨年元旦的
     * `holiday_name:new_year` 特判也在这里：12 月开始、1 月结束的组。
     */
    fun nameForKey(label: HolidayNameLabel): String = when (label) {
        HolidayNameLabel.NewYear -> "holiday_name:new_year"
        HolidayNameLabel.LaborDay -> "holiday_name:labor_day"
        HolidayNameLabel.NationalDay -> "holiday_name:national_day"
        HolidayNameLabel.SpringFestival -> "holiday_name:spring_festival"
        HolidayNameLabel.Qingming -> "holiday_name:qingming"
        HolidayNameLabel.DragonBoat -> "holiday_name:dragon_boat"
        HolidayNameLabel.MidAutumn -> "holiday_name:mid_autumn"
        HolidayNameLabel.MakeupWorkday -> HOLIDAY_NAME_MAKEUP_WORKDAY_KEY
        HolidayNameLabel.Statutory -> "holiday_name:statutory"
    }

    /**
     * Dart `_nameForGroup`：给一段连续假期组起稳定名。
     *
     * [group] 必须已是日期升序（groupConsecutiveHolidayDates 的产出满足）。
     * 判定序逐字对照 Dart 实现：固定日期 → 跨年 → 农历近似区间 → 法定兜底。
     */
    fun nameForGroup(group: List<LocalDateTime>): String {
        val first = group.first()
        val last = group.last()
        val spanDays = group.size

        // Fixed-date holidays
        if (first.monthValue == 1 && first.dayOfMonth <= 3) return "holiday_name:new_year"
        if (first.monthValue == 5 && first.dayOfMonth <= 5) return "holiday_name:labor_day"
        if (first.monthValue == 10 && first.dayOfMonth <= 7) return "holiday_name:national_day"

        // 跨年假期：12月31日开始，1月结束 → 元旦
        if (first.monthValue == 12 && last.monthValue == 1) return "holiday_name:new_year"

        // Lunar holidays by approximate date range
        if (first.monthValue in 1..2 && spanDays >= 5) {
            return "holiday_name:spring_festival"
        }
        if (first.monthValue in 1..3 && spanDays >= 7) {
            return "holiday_name:spring_festival"
        }
        if (first.monthValue == 4 && spanDays <= 4) return "holiday_name:qingming"
        if (first.monthValue in 5..6 && spanDays <= 4) {
            return "holiday_name:dragon_boat"
        }
        if (first.monthValue in 9..10 && spanDays <= 4) {
            return "holiday_name:mid_autumn"
        }

        return "holiday_name:statutory"
    }
}
