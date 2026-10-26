package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartTime
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 节假日展示判定领域服务（移植自 lib/domain/holiday_resolver.dart）与
 *holiday 名归一化（对应 Dart `localizedHolidayName` 键集，与
 * TodayWidgetSupport.kt / WidgetHolidayLogic.kt 已真机验证的口径对拍）。
 *
 * 期望值来源：
 * - [Dart抄录-测试]：test/services/timetable_holiday_service.dart:249-269；
 * - [Dart抄录]：lib/domain/holiday_resolver.dart 判定序；
 * - [对拍]：WidgetHolidayLogic.kt widgetResolveIsHoliday 同输入同输出。
 */
class HolidayResolverTest {

    private fun entry(
        date: String,
        name: String = "国庆节",
        type: HolidayType = HolidayType.Vacation,
        groupId: String? = null,
    ) = HolidayEntry(
        date = DartTime.tryParseIso(date)!!,
        name = name,
        type = type,
        groupId = groupId,
    )

    private fun data(vararg entries: HolidayEntry) =
        HolidayData(year = 2026, version = 1, entries = entries.toList())

    // ---------- HolidayResolver.isHoliday ----------

    @Test
    fun `vacation day is holiday with defaults`() { // [Dart抄录-测试] timetable_holiday_service_test.dart:261
        val data = data(entry("2026-10-01"))
        assertTrue(
            HolidayResolver.isHoliday(
                date = DartTime.dateTime(2026, 10, 1),
                data = data,
                overrideEnabled = false,
                markingEnabled = true,
            ),
        )
    }

    @Test
    fun `makeup workday is not holiday even with override`() { // [Dart抄录] holiday_resolver.dart:21 调休上班日优先级最高
        val data = data(entry("2026-10-11", "调休上班", HolidayType.AdjustedWorkday))
        assertFalse(
            HolidayResolver.isHoliday(
                date = DartTime.dateTime(2026, 10, 11),
                data = data,
                overrideEnabled = true,
                markingEnabled = true,
            ),
        )
    }

    @Test
    fun `override mode hides all holidays`() { // [Dart抄录] holiday_resolver.dart:22
        val data = data(entry("2026-10-01"))
        assertTrue(
            HolidayResolver.isHoliday(
                date = DartTime.dateTime(2026, 10, 1),
                data = data,
                overrideEnabled = true,
                markingEnabled = false,
            ),
        )
        // 覆盖模式下连数据里没有的日子也算假期（整段隐藏）。
        assertTrue(
            HolidayResolver.isHoliday(
                date = DartTime.dateTime(2026, 3, 2),
                data = data,
                overrideEnabled = true,
                markingEnabled = false,
            ),
        )
    }

    @Test
    fun `marking disabled means no holiday unless override`() { // [Dart抄录] holiday_resolver.dart:23
        val data = data(entry("2026-10-01"))
        assertFalse(
            HolidayResolver.isHoliday(
                date = DartTime.dateTime(2026, 10, 1),
                data = data,
                overrideEnabled = false,
                markingEnabled = false,
            ),
        )
        assertTrue(
            HolidayResolver.isHoliday(
                date = DartTime.dateTime(2026, 10, 1),
                data = data,
                overrideEnabled = true,
                markingEnabled = false,
            ),
        )
    }

    @Test
    fun `missing data means no holiday unless override`() { // [Dart抄录] holiday_resolver.dart:24 数据缺失视为无假期
        assertFalse(
            HolidayResolver.isHoliday(
                date = DartTime.dateTime(2026, 10, 1),
                data = null,
                overrideEnabled = false,
                markingEnabled = true,
            ),
        )
        assertTrue(
            HolidayResolver.isHoliday(
                date = DartTime.dateTime(2026, 10, 1),
                data = null,
                overrideEnabled = true,
                markingEnabled = true,
            ),
        )
    }

    // ---------- HolidayResolver.isAdjustedWorkday ----------

    @Test
    fun `adjusted workday resolution follows data`() { // [Dart抄录-测试] timetable_holiday_service_test.dart:262-263
        val data = data(
            entry("2026-10-01"),
            entry("2026-10-11", "调休上班", HolidayType.AdjustedWorkday),
        )
        assertTrue(
            HolidayResolver.isAdjustedWorkday(DartTime.dateTime(2026, 10, 11), data),
        )
        assertFalse(
            HolidayResolver.isAdjustedWorkday(DartTime.dateTime(2026, 10, 1), data),
        )
        // 数据缺失一律 false。
        assertFalse(
            HolidayResolver.isAdjustedWorkday(DartTime.dateTime(2026, 10, 11), null),
        )
    }

    // ---------- 假期日期分组（groupConsecutiveHolidayDates） ----------

    @Test
    fun `empty input yields no groups`() { // [Dart抄录] holiday_resolver.dart:41
        assertEquals(emptyList<List<LocalDateTime>>(), groupConsecutiveHolidayDates(emptyList()))
    }

    @Test
    fun `consecutive dates form one group`() { // [Dart抄录] holiday_resolver.dart:40-69
        val groups = groupConsecutiveHolidayDates(
            listOf(
                DartTime.dateTime(2026, 10, 1),
                DartTime.dateTime(2026, 10, 2),
                DartTime.dateTime(2026, 10, 3),
            ),
        )
        assertEquals(1, groups.size)
        assertEquals(
            listOf("2026-10-01", "2026-10-02", "2026-10-03"),
            groups[0].map { HolidayData.dateKey(it) },
        )
    }

    @Test
    fun `gap splits groups`() { // [Dart抄录] holiday_resolver.dart:40-69
        val groups = groupConsecutiveHolidayDates(
            listOf(
                DartTime.dateTime(2026, 10, 1),
                DartTime.dateTime(2026, 10, 2),
                DartTime.dateTime(2026, 10, 5),
            ),
        )
        assertEquals(2, groups.size)
        assertEquals(listOf("2026-10-01", "2026-10-02"), groups[0].map { HolidayData.dateKey(it) })
        assertEquals(listOf("2026-10-05"), groups[1].map { HolidayData.dateKey(it) })
    }

    @Test
    fun `unsorted input is sorted before grouping`() { // [Dart抄录] holiday_resolver.dart:35-39 乱序会把一段假拆成多组
        val groups = groupConsecutiveHolidayDates(
            listOf(
                DartTime.dateTime(2026, 10, 3),
                DartTime.dateTime(2026, 10, 1),
                DartTime.dateTime(2026, 10, 2),
            ),
        )
        assertEquals(1, groups.size)
        assertEquals(
            listOf("2026-10-01", "2026-10-02", "2026-10-03"),
            groups[0].map { HolidayData.dateKey(it) },
        )
    }

    @Test
    fun `duplicate days collapse to one entry`() { // [Dart抄录] holiday_resolver.dart:42-51 重复值天数差 0 会被误判不连续
        val groups = groupConsecutiveHolidayDates(
            listOf(
                DartTime.dateTime(2026, 10, 1),
                DartTime.dateTime(2026, 10, 1, 9, 30), // 同一天不同时刻
                DartTime.dateTime(2026, 10, 2),
            ),
        )
        assertEquals(1, groups.size)
        assertEquals(2, groups[0].size)
    }

    @Test
    fun `cross year run stays one group`() { // [Dart抄录-测试] holiday_service_test.dart:633-648 元旦 2026-12-31..2027-01-02
        val groups = groupConsecutiveHolidayDates(
            listOf(
                DartTime.dateTime(2026, 12, 31),
                DartTime.dateTime(2027, 1, 1),
                DartTime.dateTime(2027, 1, 2),
            ),
        )
        assertEquals(1, groups.size)
        assertEquals(
            listOf("2026-12-31", "2027-01-01", "2027-01-02"),
            groups[0].map { HolidayData.dateKey(it) },
        )
    }

    // ---------- 跨年取数年份（holidayYearsToLoad） ----------

    @Test
    fun `normal week loads only current year`() { // [Dart抄录] holiday_resolver.dart:90-102
        assertEquals(
            setOf(2026),
            holidayYearsToLoad(DartTime.dateTime(2026, 10, 19)),
        )
    }

    @Test
    fun `cross year week loads both years`() { // [Dart抄录] holiday_resolver.dart:71-83 元旦整段挂在某一年响应里
        // 2026-12-30 是周三，本周 12-28..01-03 横跨两年。
        assertEquals(
            setOf(2026, 2027),
            holidayYearsToLoad(DartTime.dateTime(2026, 12, 30)),
        )
        // 2027-01-01 是周五，本周 12-28(2026)..01-03(2027)。
        assertEquals(
            setOf(2026, 2027),
            holidayYearsToLoad(DartTime.dateTime(2027, 1, 1)),
        )
    }

    @Test
    fun `november onward prefetches next year`() { // [Dart抄录] holiday_resolver.dart:98-100 学期横跨学年的既有意图
        assertEquals(
            setOf(2026, 2027),
            holidayYearsToLoad(DartTime.dateTime(2026, 11, 2)),
        )
        // 11 月之后且周尾跨到后年：三年齐取（超集，不缺）。
        // 2027-12-29 是周三：本周 2027-12-27..2028-01-02，加上 11 月预取 → {2027, 2028}。
        assertEquals(
            setOf(2027, 2028),
            holidayYearsToLoad(DartTime.dateTime(2027, 12, 29)),
        )
    }

    @Test
    fun `year boundary sunday week tail belongs to next year`() { // [Dart抄录] holiday_resolver.dart:84-89 周尾按日历日
        // 2029-12-30 是周日：本周 12-24(周一)..12-30(周日) 全在 2029；
        // 但 12 月已触发下一年预取 → {2029, 2030}。
        assertEquals(
            setOf(2029, 2030),
            holidayYearsToLoad(DartTime.dateTime(2029, 12, 30)),
        )
        // 2029-12-31 是周一：本周落在 2029-12-31..2030-01-06。
        assertEquals(
            setOf(2029, 2030),
            holidayYearsToLoad(DartTime.dateTime(2029, 12, 31)),
        )
    }

    // ---------- holiday 名归一化（对拍 WidgetHolidayLogic.widgetHolidayLabel） ----------

    @Test
    fun `builtin holiday name keys map to labels`() { // [对拍] WidgetHolidayLogic.kt:184-201 与 holiday_name_localizer.dart 键集一致
        assertEquals(HolidayNameLabel.NewYear, HolidayNameNormalizer.labelOf("holiday_name:new_year"))
        assertEquals(HolidayNameLabel.LaborDay, HolidayNameNormalizer.labelOf("holiday_name:labor_day"))
        assertEquals(HolidayNameLabel.NationalDay, HolidayNameNormalizer.labelOf("holiday_name:national_day"))
        assertEquals(HolidayNameLabel.SpringFestival, HolidayNameNormalizer.labelOf("holiday_name:spring_festival"))
        assertEquals(HolidayNameLabel.Qingming, HolidayNameNormalizer.labelOf("holiday_name:qingming"))
        assertEquals(HolidayNameLabel.DragonBoat, HolidayNameNormalizer.labelOf("holiday_name:dragon_boat"))
        assertEquals(HolidayNameLabel.MidAutumn, HolidayNameNormalizer.labelOf("holiday_name:mid_autumn"))
        assertEquals(HolidayNameLabel.MakeupWorkday, HolidayNameNormalizer.labelOf("holiday_name:makeup_workday"))
        assertEquals(HolidayNameLabel.Statutory, HolidayNameNormalizer.labelOf("holiday_name:statutory"))
    }

    @Test
    fun `legacy display names map to same labels`() { // [对拍] WidgetHolidayLogicTest.kt:143-151
        assertEquals(HolidayNameLabel.NewYear, HolidayNameNormalizer.labelOf("元旦"))
        assertEquals(HolidayNameLabel.LaborDay, HolidayNameNormalizer.labelOf("劳动节"))
        assertEquals(HolidayNameLabel.NationalDay, HolidayNameNormalizer.labelOf("国庆节"))
        assertEquals(HolidayNameLabel.SpringFestival, HolidayNameNormalizer.labelOf("春节"))
        assertEquals(HolidayNameLabel.Qingming, HolidayNameNormalizer.labelOf("清明节"))
        assertEquals(HolidayNameLabel.DragonBoat, HolidayNameNormalizer.labelOf("端午节"))
        assertEquals(HolidayNameLabel.MidAutumn, HolidayNameNormalizer.labelOf("中秋节"))
        assertEquals(HolidayNameLabel.MakeupWorkday, HolidayNameNormalizer.labelOf("调休上班"))
        assertEquals(HolidayNameLabel.Statutory, HolidayNameNormalizer.labelOf("法定假日"))
        assertEquals(HolidayNameLabel.Statutory, HolidayNameNormalizer.labelOf("法定节假日"))
        assertEquals(HolidayNameLabel.Statutory, HolidayNameNormalizer.labelOf("Public holiday"))
        assertEquals(HolidayNameLabel.Statutory, HolidayNameNormalizer.labelOf("Holiday"))
        // 前后空白容忍（trim 后匹配）。
        assertEquals(HolidayNameLabel.MidAutumn, HolidayNameNormalizer.labelOf("  holiday_name:mid_autumn  "))
    }

    @Test
    fun `custom names stay verbatim`() { // [对拍] WidgetHolidayLogicTest.kt:154-160
        assertNull(HolidayNameNormalizer.labelOf("学校运动会"))
        assertNull(HolidayNameNormalizer.labelOf("公司年会"))
        assertNull(HolidayNameNormalizer.labelOf(""))
        assertNull(HolidayNameNormalizer.labelOf("   "))
        assertNull(HolidayNameNormalizer.labelOf(null))
    }

    @Test
    fun `makeup workday name constant matches dart key`() { // [Dart抄录] holiday_service.dart:99
        assertEquals("holiday_name:makeup_workday", HolidayServiceConstants.holidayNameMakeupWorkdayKey)
        assertEquals(
            HolidayServiceConstants.holidayNameMakeupWorkdayKey,
            HolidayServiceConstants.nameForKey(HolidayNameLabel.MakeupWorkday),
        )
        assertEquals("holiday_name:national_day", HolidayServiceConstants.nameForKey(HolidayNameLabel.NationalDay))
        assertEquals("holiday_name:statutory", HolidayServiceConstants.nameForKey(HolidayNameLabel.Statutory))
    }
}
