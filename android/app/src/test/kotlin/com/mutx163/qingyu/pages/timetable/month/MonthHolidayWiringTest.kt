package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayPreferences
import com.mutx163.qingyu.calendar.HolidayProvider
import com.mutx163.qingyu.calendar.HolidayRemoteGateway
import com.mutx163.qingyu.calendar.HolidayType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

/**
 * 月视图假期接线的纯逻辑契约。
 *
 * 覆盖两件事：
 * 1. 两个开关从 `timetable_settings` JSON 里的读取口径（缺键 / 坏值 / 显式值）；
 * 2. 后台初始化包装：成功拿到合并数据、provider 违约抛异常时落空态而不是崩、
 *    失败时保留调用方已有的旧数据。
 *
 * 期望值来源：Dart `lenientBool` 与 `timetable_settings.dart` 的读侧默认值，
 * 不从实现里抄。
 */
class MonthHolidayWiringTest {

    // 2026-10-01 是周四，那一周（09-28 ~ 10-04）只跨 2026 一年。
    private val clockAtNationalDay: () -> LocalDate = { LocalDate.of(2026, 10, 1) }
    private val timeNineSharp: () -> LocalTime = { LocalTime.of(9, 0, 12) }

    // ---------- 设置读取 ----------

    @Test
    fun `缺键时覆盖关闭 标记开启`() {
        val settings = MonthHolidaySettings.fromSettingsJson(emptyMap())

        assertEquals(false, settings.overrideEnabled)
        assertEquals(true, settings.markingEnabled)
    }

    @Test
    fun `键名与设置存档逐字一致`() {
        assertEquals("holidayOverrideEnabled", MonthHolidaySettings.KEY_OVERRIDE_ENABLED)
        assertEquals("enableHolidayMarking", MonthHolidaySettings.KEY_MARKING_ENABLED)
    }

    @Test
    fun `读到真实布尔值`() {
        val settings = MonthHolidaySettings.fromSettingsJson(
            mapOf(
                MonthHolidaySettings.KEY_OVERRIDE_ENABLED to true,
                MonthHolidaySettings.KEY_MARKING_ENABLED to false,
            ),
        )

        assertEquals(true, settings.overrideEnabled)
        assertEquals(false, settings.markingEnabled)
    }

    @Test
    fun `字符串布尔按 Dart lenientBool 口径解析`() {
        val settings = MonthHolidaySettings.fromSettingsJson(
            mapOf(
                MonthHolidaySettings.KEY_OVERRIDE_ENABLED to " TRUE ",
                MonthHolidaySettings.KEY_MARKING_ENABLED to "false",
            ),
        )

        assertEquals(true, settings.overrideEnabled)
        assertEquals(false, settings.markingEnabled)
    }

    @Test
    fun `坏值不猜 一律回落默认值`() {
        val settings = MonthHolidaySettings.fromSettingsJson(
            mapOf(
                MonthHolidaySettings.KEY_OVERRIDE_ENABLED to 1,
                MonthHolidaySettings.KEY_MARKING_ENABLED to "1",
            ),
        )

        assertEquals(false, settings.overrideEnabled)
        assertEquals(true, settings.markingEnabled)
    }

    // ---------- 后台初始化包装 ----------

    @Test
    fun `初始化成功后给出官方与自定义合并的数据`() {
        val provider = provider(
            gateway = RecordingGateway(
                mapOf(
                    2026 to HolidayData(
                        2026,
                        1,
                        listOf(entry(2026, 10, 1, "国庆节")),
                    ),
                ),
            ),
        )

        val data = initializeMonthHolidayData(provider)

        assertEquals(2026, data?.year)
        assertEquals(1, data?.entries?.size)
        assertEquals("国庆节", data?.entries?.first()?.name)
    }

    @Test
    fun `provider 违约抛异常时落空态而不是崩`() {
        val provider = provider(gateway = ThrowingGateway())

        val data = initializeMonthHolidayData(provider)

        assertNull("节假日是装饰性数据，取数失败必须是空态", data)
    }

    @Test
    fun `初始化失败时保留调用方已有的旧数据`() {
        val previous = HolidayData(2026, 1, listOf(entry(2026, 10, 1, "旧数据")))
        val provider = provider(gateway = ThrowingGateway())

        val data = initializeMonthHolidayData(provider, fallback = previous)

        assertSame("刷新失败不能把已经画出来的假期清掉", previous, data)
    }

    // ---------- 夹具 ----------

    private fun provider(gateway: HolidayRemoteGateway): HolidayProvider = HolidayProvider(
        service = gateway,
        preferences = HolidayPreferences(InMemoryKeyValueStore()),
        builtinJson = { null },
        clock = clockAtNationalDay,
        nowTime = timeNineSharp,
    )

    private class RecordingGateway(private val byYear: Map<Int, HolidayData?>) : HolidayRemoteGateway {
        override fun fetchYear(year: Int, log: (String) -> Unit): HolidayData? = byYear[year]
    }

    /** 违约网关：接口承诺「失败返回 null，绝不抛」，这里故意抛，验证包装的兜底。 */
    private class ThrowingGateway : HolidayRemoteGateway {
        override fun fetchYear(year: Int, log: (String) -> Unit): HolidayData? =
            throw IllegalStateException("gateway contract violated")
    }

    private fun entry(year: Int, month: Int, day: Int, name: String): HolidayEntry =
        HolidayEntry(
            date = LocalDateTime.of(year, month, day, 0, 0),
            name = name,
            type = HolidayType.Vacation,
            groupId = "group-$year-$month-$day",
        )
}
