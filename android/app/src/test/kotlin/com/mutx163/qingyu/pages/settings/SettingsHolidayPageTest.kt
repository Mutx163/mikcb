package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 节假日标记两页（`lib/screens/settings/settings_holiday.dart`）结构测试。
 *
 * 期望值来源：Dart 源（区块顺序 / 三个分支 / 日期区间格式）+ ARB（文案），
 * 不从 Kotlin 实现倒推。
 *
 * 覆盖两个屏：
 * 1. `HolidaySettingsScreen`（:17-661）= 主页面，三个定长区块；
 * 2. `HolidayAdvancedSettingsScreen`（:663-817）= 顶栏齿轮进的高级页。
 */
class SettingsHolidayPageTest {

    private fun page(data: HolidayPageData = HolidayPageData()) =
        SettingsHolidayPage.spec(SettingsPageState(), data)

    private fun advanced(logs: List<HolidayLogEntry> = emptyList()) =
        SettingsHolidayAdvancedPage.spec(SettingsPageState(), HolidayAdvancedData(logs = logs))

    // ==================================================== 节假日标记（主页面）

    @Test
    fun `主页面标题取自 holidaySettingsTitle`() {
        // settings_holiday.dart:479
        val spec = page()
        assertEquals("settings-holiday", spec.id)
        assertEquals("holidaySettingsTitle", spec.titleKey)
        assertEquals("节假日标记", spec.title)
    }

    @Test
    fun `主页面三个区块按开关 自定义 法定排列`() {
        // settings_holiday.dart:493 `_holidaySectionCount = 3`；:502-631 的三个分支。
        // 注意区块 1 的顺序：Label → Group → SizedBox(12) → 添加按钮卡 → SectionGap
        // （:525-593），中间那个 SizedBox 与段后 SectionGap 是**两个**独立空档，
        // 忠实搬运不合并。
        assertEquals(
            listOf(
                "holiday.group.enable",
                "holiday.gap.enable",
                "holiday.section.custom",
                "holiday.group.custom",
                "holiday.gap.customAdd",
                "holiday.card.add",
                "holiday.gap.custom",
                "holiday.section.official",
                "holiday.group.official",
            ),
            page().topLevelIds(),
        )
    }

    @Test
    fun `启用节假日标记开关的文案与默认值`() {
        // settings_holiday.dart:508-516；默认 true 见 timetable_settings.dart:760
        val row = page().row("holiday.enable")
        assertEquals("holidayEnableTitle", row.titleKey)
        assertEquals("启用节假日标记", row.title)
        assertEquals("holidayEnableSubtitle", row.subtitleKey)
        assertEquals("标记法定节假日和调休补班日", row.subtitle)
        assertEquals(MiuixRowComponent.SWITCH, row.component)
        assertEquals(true, row.switchValue)
        assertEquals(SettingsAction.WRITE_SETTING, row.action)
    }

    @Test
    fun `关闭节假日标记时开关值随状态走`() {
        assertEquals(false, page(HolidayPageData(enableHolidayMarking = false)).row("holiday.enable").switchValue)
    }

    @Test
    fun `自定义假期区块小标题`() {
        // settings_holiday.dart:525
        val label = page().flatten().filterIsInstance<SettingsLabel>()
            .single { it.id == "holiday.section.custom" }
        assertEquals("customHolidayTitle", label.textKey)
        assertEquals("自定义假期", label.text)
    }

    @Test
    fun `自定义假期为空时是一行禁用的暂无`() {
        // settings_holiday.dart:534-539：enabled: false, showChevron: false
        val rows = page(HolidayPageData(customHolidays = emptyList(), customHolidaysCorrupted = false))
            .group("holiday.group.custom").children.filterIsInstance<SettingsRow>()
        assertEquals(1, rows.size)
        val row = rows.single()
        assertEquals("customHolidayEmpty", row.titleKey)
        assertEquals("暂无自定义假期", row.title)
        assertFalse(row.enabled)
        assertEquals(MiuixRowComponent.ARROW, row.component)
        assertNull(row.action)
    }

    @Test
    fun `存储损坏时是读取异常而不是暂无`() {
        // settings_holiday.dart:528-533：两态互斥，损坏优先
        val row = page(
            HolidayPageData(customHolidays = emptyList(), customHolidaysCorrupted = true),
        ).group("holiday.group.custom").children.filterIsInstance<SettingsRow>().single()
        assertEquals("customHolidayCorrupted", row.titleKey)
        assertEquals("读取异常，暂停读写防丢", row.title)
        assertFalse(row.enabled)
    }

    @Test
    fun `损坏态优先于已有条目`() {
        // :528 `if (_customHolidaysCorrupted)` 排在最前，列表非空也是损坏行
        val row = page(
            HolidayPageData(
                customHolidaysCorrupted = true,
                customHolidays = listOf(
                    HolidayGroupRow(
                        groupId = "g1",
                        name = "校庆",
                        startDate = "2026-10-01",
                        endDate = "2026-10-03",
                        type = HolidayKind.VACATION,
                    ),
                ),
            ),
        ).group("holiday.group.custom").children.filterIsInstance<SettingsRow>().single()
        assertEquals("customHolidayCorrupted", row.titleKey)
    }

    @Test
    fun `每个自定义假期一行 标题是名字 副标题是类型 行尾是区间`() {
        // settings_holiday.dart:541-571
        val data = HolidayPageData(
            customHolidays = listOf(
                HolidayGroupRow("g1", "校庆", "2026-10-01", "2026-10-03", HolidayKind.VACATION),
                HolidayGroupRow("g2", "补课", "2026-11-08", "2026-11-08", HolidayKind.ADJUSTED_WORKDAY),
            ),
        )
        val rows = page(data).group("holiday.group.custom").children.filterIsInstance<SettingsRow>()
        assertEquals(listOf("holiday.custom.g1", "holiday.custom.g2"), rows.map { it.id })
        assertEquals(listOf("校庆", "补课"), rows.map { it.title })
        // 假期名是用户数据，不来自 ARB
        assertEquals(NON_ARB_TEXT, rows.first().titleKey)
        assertEquals("customHolidayTypeVacation", rows[0].subtitleKey)
        assertEquals("假期", rows[0].subtitle)
        assertEquals("customHolidayTypeWorkday", rows[1].subtitleKey)
        assertEquals("调休上班", rows[1].subtitle)
        // 区间是算出来的，放在 details（静态行尾文案槽位以外的动态读数）
        assertEquals("10 月 1 日～3 日", rows[0].value)
        assertEquals("11 月 8 日", rows[1].value)
        assertEquals(SettingsAction.SHEET, rows[0].action)
    }

    @Test
    fun `自定义假期区间的三种格式`() {
        // settings_holiday.dart:633-650
        val sameDay = SettingsHolidayPage.formatRange("2026-10-01", "2026-10-01")
        assertEquals("10 月 1 日", sameDay.text)
        assertEquals("holidayDateSameDay", sameDay.key)

        val sameMonth = SettingsHolidayPage.formatRange("2026-10-01", "2026-10-03")
        assertEquals("10 月 1 日～3 日", sameMonth.text)
        assertEquals("holidayDateSameMonth", sameMonth.key)

        val diffMonth = SettingsHolidayPage.formatRange("2026-10-30", "2026-11-02")
        assertEquals("10 月 30 日～11 月 2 日", diffMonth.text)
        assertEquals("holidayDateDiffMonth", diffMonth.key)
    }

    @Test
    fun `区间格式对跨年同月同日也走同一天分支`() {
        // :652-653 `_isSameDate` 比年月日；同月同日必然同年同月
        assertEquals("1 月 1 日", SettingsHolidayPage.formatRange("2026-01-01", "2026-01-01").text)
        // 跨年但同月 → 同月分支（Dart 只比 month，不比 year）
        assertEquals("12 月 30 日～31 日", SettingsHolidayPage.formatRange("2026-12-30", "2027-12-31").text)
    }

    @Test
    fun `添加假期按钮是独立控制卡`() {
        // settings_holiday.dart:576-592
        val card = page().flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "holiday.card.add" }
        assertEquals(InlineKind.CONTROL_CARD, card.kind)
        assertEquals("customHolidayAdd", card.labelKey)
        assertEquals("添加假期", card.label)
        assertEquals(listOf("customHolidayAdd"), card.texts.map { it.key })
        assertEquals(listOf("添加假期"), card.texts.map { it.text })
    }

    @Test
    fun `法定节假日区块小标题带年份`() {
        // settings_holiday.dart:600-602 `holidayDataYearLabel(holidayData?.year ?? '')`
        val label = page(HolidayPageData(year = "2026"))
            .flatten().filterIsInstance<SettingsLabel>()
            .single { it.id == "holiday.section.official" }
        assertEquals("holidayDataYearLabel", label.textKey)
        assertEquals("2026 年法定节假日", label.text)
    }

    @Test
    fun `年份缺失时标题是空年份模板`() {
        // `holidayData?.year ?? ''` → 「` 年法定节假日`」
        val label = page(HolidayPageData(year = ""))
            .flatten().filterIsInstance<SettingsLabel>()
            .single { it.id == "holiday.section.official" }
        assertEquals(" 年法定节假日", label.text)
    }

    @Test
    fun `没有法定节假日时是一行禁用的近期没有`() {
        // settings_holiday.dart:603-608
        val rows = page(HolidayPageData(officialHolidays = emptyList()))
            .group("holiday.group.official").children.filterIsInstance<SettingsRow>()
        assertEquals(1, rows.size)
        assertEquals("holidayNoUpcoming", rows.single().titleKey)
        assertEquals("近期没有节假日", rows.single().title)
        assertFalse(rows.single().enabled)
    }

    @Test
    fun `法定节假日一行一个 行尾是区间 且不可点`() {
        // settings_holiday.dart:610-627：showChevron: false + 无 onTap
        val data = HolidayPageData(
            year = "2026",
            officialHolidays = listOf(
                HolidayItem(
                    "国庆节", "2026-10-01", "2026-10-07", HolidayKind.VACATION,
                    isPast = false, nameKey = "holidayNameNationalDay",
                ),
                HolidayItem(
                    "元旦", "2026-01-01", "2026-01-01", HolidayKind.VACATION,
                    isPast = true, nameKey = "holidayNameNewYear",
                ),
            ),
        )
        val rows = page(data).group("holiday.group.official").children.filterIsInstance<SettingsRow>()
        assertEquals(listOf("国庆节", "元旦"), rows.map { it.title })
        assertEquals(
            listOf("holidayNameNationalDay", "holidayNameNewYear"),
            rows.map { it.titleKey },
        )
        assertEquals(listOf("10 月 1 日～7 日", "1 月 1 日"), rows.map { it.value })
        rows.forEach {
            assertNull("法定节假日行不可点（showChevron: false）", it.action)
            assertTrue(it.enabled)
        }
    }

    @Test
    fun `已过去的节假日输入仍带着 isPast 标记`() {
        // settings_holiday.dart:613-614 `Opacity(opacity: holiday.isPast ? 0.55 : 1)`
        //
        // **已知口径缺口**：`SettingsRow` 没有「降透明度」槽位，所以 isPast 只能
        // 停留在输入数据上、无法进 spec；渲染层要复刻这一档需要新增节点能力。
        // 已在汇报里报给 Lead，不在本泳道私改共享模型。
        val data = HolidayPageData(
            officialHolidays = listOf(
                HolidayItem("国庆节", "2026-10-01", "2026-10-07", HolidayKind.VACATION, isPast = false),
                HolidayItem("元旦", "2026-01-01", "2026-01-01", HolidayKind.VACATION, isPast = true),
            ),
        )
        assertEquals(listOf(false, true), data.officialHolidays.map { it.isPast })
    }

    @Test
    fun `调休补班日单日名称是补班`() {
        // settings_holiday.dart:446-457 + holiday_name_localizer.dart 的 makeup_workday 分支
        val name = SettingsHolidayPage.localizeHolidayName(
            "holiday_name:makeup_workday",
            SettingsStringsExt3.holidayMakeupWorkday,
        )
        assertEquals("补班", name.zh)
        assertEquals("holidayMakeupWorkday", name.key)
    }

    @Test
    fun `节假日名的本地化表覆盖八种已知名`() {
        // holiday_name_localizer.dart:4-17
        val cases = mapOf(
            "holiday_name:new_year" to "元旦",
            "holiday_name:labor_day" to "劳动节",
            "holiday_name:national_day" to "国庆节",
            "holiday_name:spring_festival" to "春节",
            "holiday_name:qingming" to "清明节",
            "holiday_name:dragon_boat" to "端午节",
            "holiday_name:mid_autumn" to "中秋节",
            "法定假日" to "法定节假日",
        )
        cases.forEach { (raw, expected) ->
            assertEquals(
                "「$raw」应本地化成「$expected」",
                expected,
                SettingsHolidayPage.localizeHolidayName(raw, SettingsStringsExt3.holidayStatutoryLabel).zh,
            )
        }
    }

    @Test
    fun `未收录的假期名原样返回且不带 ARB 键`() {
        // holiday_name_localizer.dart:16 `_ => name`
        val out = SettingsHolidayPage.localizeHolidayName(
            "校庆",
            SettingsStringsExt3.holidayStatutoryLabel,
        )
        assertEquals("校庆", out.zh)
        assertEquals(NON_ARB_TEXT, out.key)
    }

    @Test
    fun `顶栏齿轮进高级页的法语文案`() {
        // settings_holiday.dart:466-477（semanticsLabel 用 holidayAdvancedTitle）
        assertEquals("节假日数据更新", SettingsStringsExt3.holidayAdvancedTitle.zh)
        assertEquals("/settings/holiday/advanced", SettingsHolidayPage.ROUTE_ADVANCED)
    }

    // ============================================== 节假日数据更新（高级页）

    @Test
    fun `高级页标题与区块`() {
        // settings_holiday.dart:707-720
        val spec = advanced()
        assertEquals("settings-holiday-advanced", spec.id)
        assertEquals("holidayAdvancedTitle", spec.titleKey)
        assertEquals("节假日数据更新", spec.title)
        assertEquals(
            listOf("holidayAdvanced.section.log", "holidayAdvanced.group.log", "holidayAdvanced.card.refresh"),
            spec.topLevelIds(),
        )
    }

    @Test
    fun `更新日志小标题与检查更新按钮`() {
        // settings_holiday.dart:719 / :803-807
        val spec = advanced(logs = listOf(HolidayLogEntry("09:00", "已从内置数据加载")))
        val label = spec.flatten().filterIsInstance<SettingsLabel>().single()
        assertEquals("holidayUpdateLog", label.textKey)
        assertEquals("更新日志", label.text)
        val card = spec.flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "holidayAdvanced.card.refresh" }
        assertEquals(listOf("检查更新"), card.texts.map { it.text })
        assertEquals(listOf("holidayCheckUpdate"), card.texts.map { it.key })
    }

    @Test
    fun `更新日志逐行上屏且空态有占位`() {
        // settings_holiday.dart:727-733 `logs.isEmpty ? '暂无日志' : ListView`
        val empty = advanced(logs = emptyList())
            .flatten().filterIsInstance<SettingsRow>()
            .single { it.id == "holidayAdvanced.logEmpty" }
        assertEquals("暂无日志", empty.title)
        assertEquals(NON_ARB_TEXT, empty.titleKey)

        val filled = advanced(
            logs = listOf(
                HolidayLogEntry("09:00", "已从内置数据加载"),
                HolidayLogEntry("09:01", "远端拉取成功"),
            ),
        )
        val rows = filled.group("holidayAdvanced.group.log").children.filterIsInstance<SettingsRow>()
        // 时刻上行、正文下行（:754-779 的两层 Text）
        assertEquals(listOf("09:00", "09:01"), rows.map { it.title })
        assertEquals(listOf("已从内置数据加载", "远端拉取成功"), rows.map { it.value })
        // 时刻与正文都是运行时数据，不来自 ARB
        rows.forEach {
            assertEquals(NON_ARB_TEXT, it.titleKey)
            assertEquals(NON_ARB_TEXT, it.valueKey)
        }
    }

    @Test
    fun `刷新中的按钮文案仍是检查更新`() {
        // settings_holiday.dart:803-807：label 恒为 holidayCheckUpdate，只有 loading 变
        val card = SettingsHolidayAdvancedPage
            .spec(SettingsPageState(), HolidayAdvancedData(refreshing = true))
            .flatten().filterIsInstance<SettingsInline>()
            .single { it.id == "holidayAdvanced.card.refresh" }
        assertEquals(listOf("检查更新"), card.texts.map { it.text })
    }
}
