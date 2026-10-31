package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayResolver
import java.time.LocalDate

/**
 * 周网格「这一天是不是假期」的判定（模型层，纯函数，可 JVM 测）。
 *
 * ## 为什么单独抽出来
 *
 * Dart 侧周视图的判据是 `timetable_day_column.dart:76`：
 * `final isDayHoliday = date != null && provider.isHoliday(date);`
 * ——`provider.isHoliday` 内部合并「官方数据 + 自定义条目」再套
 * `HolidayResolver`（`enableHolidayMarking` / `holidayOverrideEnabled` 两个开关）。
 *
 * 2026-10-29 二轮审核：Compose 的 `TimetableWeekGrid.holidayForDay` **全仓 0 调用方**
 *（恒 `{ false }`），于是「假期课卡压淡 0.3 + 右上角『假』角标」两条都不可能出现。
 *
 * 这里只做合并 + 判定，不碰存储；存储由宿主读好传进来（这样单测不需要 Context）。
 */
object WeekHolidayMarking {

    /**
     * 合并官方年度数据与自定义条目后判假期。
     *
     * 与 `IcsExportHost` 的导出过滤同一口径（官方 entries + 自定义 entries，
     * `version` 取官方值），区别只是这里按「日」判而不是按区间。
     *
     * @param official 该日期所在年份的官方数据（可能为 null：那年还没同步/没内置）
     * @param custom 用户自定义假期条目（可能跨年，全部传进来）
     * @param overrideEnabled 设置 `holidayOverrideEnabled`（一键「今天放假」）
     * @param markingEnabled 设置 `enableHolidayMarking`（关了就不标记）
     */
    fun isHoliday(
        date: LocalDate,
        official: HolidayData?,
        custom: List<HolidayEntry> = emptyList(),
        overrideEnabled: Boolean = false,
        markingEnabled: Boolean = true,
    ): Boolean {
        if (official == null && custom.isEmpty()) return false
        val merged = HolidayData(
            year = date.year,
            version = official?.version ?: 0,
            entries = (official?.entries ?: emptyList()) + custom,
        )
        return HolidayResolver.isHoliday(
            date = date.atStartOfDay(),
            data = merged,
            overrideEnabled = overrideEnabled,
            markingEnabled = markingEnabled,
        )
    }
}