package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayLogLine
import com.mutx163.qingyu.calendar.HolidayType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * [SettingsHolidayPage.buildPageData] —— 「真数据 → spec 入参」的判据测试。
 *
 * 期望值一律照 Dart 源推出来，不从 Kotlin 实现倒推：
 * - 官方列表构造：`lib/screens/settings/settings_holiday.dart:421-462`；
 * - 自定义假期归并：同文件 `:396-412`。
 *
 * ## 与既有 `SettingsHolidayPageTest` 的分工
 *
 * 那个文件钉的是**渲染结构**（区块顺序、三态、区间文案格式、名称本地化表、年份文案），
 * 这个文件只钉**从数据构造时的判断**：归并与排序、代表项选择、isPast 边界、
 * `custom-` 前缀排除、补班单日项、跨年、损坏态优先、年份缺失、空数据。
 * 两者不重叠，别把区间格式那几条搬到这里。
 */
class SettingsHolidayPageDataTest {

    // -------------------------------------------------------------- 构造助手

    private fun entry(
        date: String,
        name: String,
        type: HolidayType = HolidayType.Vacation,
        groupId: String? = null,
    ): HolidayEntry = HolidayEntry(
        date = LocalDate.parse(date).atStartOfDay(),
        name = name,
        type = type,
        groupId = groupId,
    )

    private fun official(year: Int, vararg entries: HolidayEntry): HolidayData =
        HolidayData(year = year, version = 1, entries = entries.toList())

    private fun data(
        official: HolidayData?,
        custom: List<HolidayEntry> = emptyList(),
        corrupted: Boolean = false,
        today: String,
        enabled: Boolean = true,
    ): HolidayPageData = SettingsHolidayPage.buildPageData(
        enableHolidayMarking = enabled,
        official = official,
        customHolidays = custom,
        customCorrupted = corrupted,
        today = LocalDate.parse(today),
    )

    // ============================================================ 官方列表构造

    @Test
    fun `同组多条归并成一项 组内首尾是起止 全部按开始日期升序`() {
        // :425-458 遍历 entries、`seenGroups.add(groupId)` 每组只出一项；:462 按开始日期排序
        val d = data(
            official = official(
                2026,
                entry("2026-10-01", "国庆节", groupId = "national-day-2026"),
                entry("2026-10-07", "国庆节", groupId = "national-day-2026"),
                entry("2026-01-01", "元旦", groupId = "new-year-2026"),
                entry("2026-10-10", "补班", HolidayType.AdjustedWorkday),
                entry("2026-09-27", "补班", HolidayType.AdjustedWorkday),
            ),
            today = "2026-06-01",
        )
        assertEquals(
            listOf(
                // 元旦（已过去）
                "2026-01-01",
                // 9-27 补班
                "2026-09-27",
                // 国庆整组：起 10-01、止 10-07
                "2026-10-01",
                // 10-10 补班
                "2026-10-10",
            ),
            d.officialHolidays.map { it.startDate },
        )
        val nationalDay = d.officialHolidays[2]
        assertEquals("2026-10-07", nationalDay.endDate)
        assertEquals(HolidayKind.VACATION, nationalDay.type)
        assertEquals("holidayNameNationalDay", nationalDay.nameKey)
        assertEquals("国庆节", nationalDay.name)
        assertEquals(listOf(true, false, false, false), d.officialHolidays.map { it.isPast })
    }

    @Test
    fun `组里有假期时代表项取第一条假期 名称起止都跟着它`() {
        // :431-445 `vacationEntries.isNotEmpty() ? vacationEntries : groupEntries`
        val d = data(
            official = official(
                2026,
                entry("2026-05-01", "调休上班", HolidayType.AdjustedWorkday, groupId = "labor-2026"),
                entry("2026-05-02", "劳动节", groupId = "labor-2026"),
                entry("2026-05-03", "劳动节", groupId = "labor-2026"),
            ),
            today = "2026-03-01",
        )
        val item = d.officialHolidays.single()
        // 代表项是「第一条 vacation」⇒ 从 05-02 起，不是组内第一条的 05-01
        assertEquals("2026-05-02", item.startDate)
        assertEquals("2026-05-03", item.endDate)
        assertEquals("劳动节", item.name)
        assertEquals("holidayNameLaborDay", item.nameKey)
        assertEquals(HolidayKind.VACATION, item.type)
    }

    @Test
    fun `组里没有假期时代表项取组内第一条 类型照实`() {
        // :434-436 没有 vacation ⇒ representative = groupEntries；:442 `type: representative.first.type`
        val d = data(
            official = official(
                2026,
                entry("2026-09-27", "holiday_name:makeup_workday", HolidayType.AdjustedWorkday, "swap-2026"),
                entry("2026-09-28", "holiday_name:makeup_workday", HolidayType.AdjustedWorkday, "swap-2026"),
            ),
            today = "2026-09-01",
        )
        val item = d.officialHolidays.single()
        assertEquals("2026-09-27", item.startDate)
        assertEquals("2026-09-28", item.endDate)
        assertEquals("补班", item.name)
        assertEquals("holidayMakeupWorkday", item.nameKey)
        assertEquals(HolidayKind.ADJUSTED_WORKDAY, item.type)
    }

    @Test
    fun `isPast 看组内最后一天 等于 today 不算过去`() {
        // :443 `isPast: representative.last.date.isBefore(now)`。
        // **边界口径与 Dart 有意不同**（见 buildPageData KDoc）：Dart 的 now 带时刻，
        // 假期最后一天恰好是今天时会判成「已过去」；这里按日期比日期，等于 today 不算过去。
        val d = data(
            official = official(
                2026,
                entry("2026-09-29", "国庆节", groupId = "ends-today"),
                entry("2026-10-07", "国庆节", groupId = "ends-today"),
                entry("2026-09-20", "中秋节", groupId = "ended-yesterday"),
                entry("2026-10-06", "中秋节", groupId = "ended-yesterday"),
                entry("2026-10-08", "元旦", groupId = "tomorrow"),
            ),
            today = "2026-10-07",
        )
        val byStart = d.officialHolidays.associateBy { it.startDate }
        assertFalse("最后一天就是今天 ⇒ 还没过去", byStart.getValue("2026-09-29").isPast)
        assertTrue("最后一天是昨天 ⇒ 已经过去", byStart.getValue("2026-09-20").isPast)
        assertFalse("还没开始 ⇒ 未过去", byStart.getValue("2026-10-08").isPast)
    }

    @Test
    fun `补班日单日成项 名称固定补班 起止同日`() {
        // :446-457 无 groupId 且 type == adjustedWorkday
        val d = data(
            official = official(2026, entry("2026-10-11", "随便什么名字", HolidayType.AdjustedWorkday)),
            today = "2026-10-01",
        )
        val item = d.officialHolidays.single()
        assertEquals("2026-10-11", item.startDate)
        assertEquals("2026-10-11", item.endDate)
        // 名字不用数据里的，固定成 ARB 的「补班」
        assertEquals("补班", item.name)
        assertEquals("holidayMakeupWorkday", item.nameKey)
        assertEquals(HolidayKind.ADJUSTED_WORKDAY, item.type)
    }

    @Test
    fun `custom 前缀的条目不算法定节假日`() {
        // :426-428 `entry.groupId!.startsWith('custom-')` ⇒ continue
        val d = data(
            official = official(
                2026,
                entry("2026-10-01", "校庆", groupId = "custom-abc"),
                entry("2026-10-02", "国庆节", groupId = "national-day-2026"),
            ),
            today = "2026-01-01",
        )
        assertEquals(listOf("2026-10-02"), d.officialHolidays.map { it.startDate })
        assertEquals(listOf("国庆节"), d.officialHolidays.map { it.name })
    }

    @Test
    fun `跨年数据不截年份 起止各自保留自己的年份`() {
        // 邻年合并后的数据（`HolidayData` 可以跨年），排序按完整 yyyy-MM-dd
        val d = data(
            official = official(
                2026,
                entry("2027-01-02", "元旦", groupId = "new-year-2027"),
                entry("2026-12-31", "元旦", groupId = "new-year-2027"),
                entry("2026-01-01", "元旦", groupId = "new-year-2026"),
            ),
            today = "2026-11-01",
        )
        val rows = d.officialHolidays
        assertEquals(listOf("2026-01-01", "2026-12-31"), rows.map { it.startDate })
        assertEquals("2027-01-02", rows[1].endDate)
        assertEquals(listOf(true, false), rows.map { it.isPast })
    }

    // ======================================================== 自定义假期归并

    @Test
    fun `自定义假期按 groupId 归并 组内按日期排序 组间按开始日期升序`() {
        // :396-412：组内 `sort(date)`，组间 `sort(startDate)`
        val d = data(
            official = null,
            custom = listOf(
                entry("2026-11-08", "补课", HolidayType.AdjustedWorkday, "g2"),
                // 故意把组内后一天放前面：组内排序必须自己纠正顺序
                entry("2026-10-03", "校庆", groupId = "g1"),
                entry("2026-10-01", "校庆", groupId = "g1"),
                entry("2026-12-01", "个人事务", groupId = null),
            ),
            today = "2026-01-01",
        )
        assertEquals(listOf("g1", "g2", "ungrouped"), d.customHolidays.map { it.groupId })
        val g1 = d.customHolidays[0]
        assertEquals("校庆", g1.name)
        assertEquals("2026-10-01", g1.startDate)
        assertEquals("2026-10-03", g1.endDate)
        assertEquals(HolidayKind.VACATION, g1.type)
        val g2 = d.customHolidays[1]
        assertEquals("2026-11-08", g2.startDate)
        assertEquals(HolidayKind.ADJUSTED_WORKDAY, g2.type)
        // 无 groupId 的条目归到 'ungrouped'（Dart `entry.groupId ?? 'ungrouped'`）
        assertEquals("ungrouped", d.customHolidays[2].groupId)
        assertEquals("2026-12-01", d.customHolidays[2].startDate)
    }

    @Test
    fun `自定义假期损坏态优先于列表`() {
        // :528 损坏判断排在最前；这里更进一步：损坏时不把旧条目带进模型
        val d = data(
            official = official(2026, entry("2026-10-01", "国庆节", groupId = "g")),
            custom = listOf(entry("2026-10-01", "校庆", groupId = "g1")),
            corrupted = true,
            today = "2026-01-01",
        )
        assertTrue(d.customHolidaysCorrupted)
        assertTrue("损坏态下不再带旧条目", d.customHolidays.isEmpty())
        // 官方数据不受影响
        assertEquals(1, d.officialHolidays.size)
    }

    // ============================================================ 缺失与空数据

    @Test
    fun `官方数据未加载时年份留空 法定节假日为空`() {
        // :601 `holidayData?.year ?? ''`；:423 `if (holidayData != null)`
        val d = data(official = null, today = "2026-01-01")
        assertEquals("", d.year)
        assertTrue(d.officialHolidays.isEmpty())
        assertEquals(" 年法定节假日", SettingsStringsExt3.holidayDataYearLabel.filled("year", d.year))
    }

    @Test
    fun `年份取自官方数据的 year`() {
        val d = data(official = official(2027), today = "2026-01-01")
        assertEquals("2027", d.year)
    }

    @Test
    fun `空数据不会造出任何节假日行`() {
        val d = data(official = official(2026), custom = emptyList(), today = "2026-10-01")
        assertTrue(d.officialHolidays.isEmpty())
        assertTrue(d.customHolidays.isEmpty())
        assertFalse(d.customHolidaysCorrupted)
        // 开关值原样带过来（默认值不是模型的判断，是设置项的真值）
        assertEquals(true, d.enableHolidayMarking)
        assertEquals(false, data(official = null, today = "2026-10-01", enabled = false).enableHolidayMarking)
    }

    @Test
    fun `构造出的数据能直接喂给 spec 并上屏`() {
        // 咬合探针：buildPageData 的产物必须是 spec 真的认得的东西
        val d = data(
            official = official(
                2026,
                entry("2026-01-01", "元旦", groupId = "new-year-2026"),
                entry("2026-10-01", "国庆节", groupId = "national-day-2026"),
                entry("2026-10-07", "国庆节", groupId = "national-day-2026"),
            ),
            today = "2026-06-01",
        )
        val rows = SettingsHolidayPage.spec(SettingsPageState(), d)
            .group("holiday.group.official")
            .children.filterIsInstance<SettingsRow>()
        assertEquals(listOf("元旦", "国庆节"), rows.map { it.title })
        assertEquals(listOf("1 月 1 日", "10 月 1 日～7 日"), rows.map { it.value })
        // 已过去的元旦整行降透明度（:613-614）
        assertEquals(listOf(true, false), rows.map { it.dimmed })
    }

    // ================================================== 高级页的日志搬入参

    @Test
    fun `日志搬运不排序不截断 顺序就是数据层给的顺序`() {
        // 顺序口径只在数据层一处（最新在前、最多 50 条）：
        // 模型再排一次，就会出现「两个地方都说自己负责顺序」的隐患。
        val logs = listOf(
            HolidayLogLine("09:03:10", "远端拉取成功"),
            HolidayLogLine("09:00:00", "已从内置数据加载"),
        )
        val out = SettingsHolidayAdvancedPage.buildData(logs, refreshing = false)
        assertEquals(listOf("09:03:10", "09:00:00"), out.logs.map { it.time })
        assertEquals(listOf("远端拉取成功", "已从内置数据加载"), out.logs.map { it.message })
        assertFalse(out.refreshing)
    }

    @Test
    fun `刷新态原样透传 文案不随刷新变`() {
        val out = SettingsHolidayAdvancedPage.buildData(
            logs = listOf(HolidayLogLine("23:05:07", "网络不可用，已用内置数据")),
            refreshing = true,
        )
        assertTrue(out.refreshing)
        // :803-807 label 是死的，刷新只影响 loading
        val card = SettingsHolidayAdvancedPage.spec(SettingsPageState(), out).footerNode as SettingsInline
        assertEquals(listOf("检查更新"), card.texts.map { it.text })
    }

    @Test
    fun `空日志走空态 有条目时逐行上下排`() {
        val emptySpec = SettingsHolidayAdvancedPage
            .spec(SettingsPageState(), SettingsHolidayAdvancedPage.buildData(emptyList(), false))
        val emptyRow = emptySpec.flatten().filterIsInstance<SettingsRow>()
            .single { it.id == "holidayAdvanced.logEmpty" }
        assertEquals("暂无日志", emptyRow.title)

        val spec = SettingsHolidayAdvancedPage.spec(
            SettingsPageState(),
            SettingsHolidayAdvancedPage.buildData(
                listOf(HolidayLogLine("09:00:12", "已从内置数据加载")),
                refreshing = false,
            ),
        )
        val row = spec.row("holidayAdvanced.log.0")
        // 时刻在上（title）、正文在下（subtitle），上下排
        assertEquals("09:00:12", row.title)
        assertEquals("已从内置数据加载", row.subtitle)
        assertTrue(row.stacked)
    }
}
