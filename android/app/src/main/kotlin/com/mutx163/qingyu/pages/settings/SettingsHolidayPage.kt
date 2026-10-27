package com.mutx163.qingyu.pages.settings

/**
 * 节假日标记两页（`lib/screens/settings/settings_holiday.dart`）结构模型。
 *
 * ## 主页面 = 三个定长区块（`_holidaySectionCount = 3`，:493）
 *
 * 1. **总开关**（:503-519）：一个白卡一行；
 * 2. **自定义假期**（:521-594）：标签 + 列表（三态）+ 添加按钮；
 * 3. **法定节假日**（:596-629）：标签（带年份）+ 列表（空态一行）。
 *
 * 区块数写死成 3 而不是按数据长度算，是 Dart 的原样：数据为空时那些区块
 * 只是内容变成「暂无」，位置照旧在线。模型保留这个性质——节点恒定存在，
 * 三态由 [HolidayPageData] 决定里面的行。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: holidaySettingsTitle)`（:479） | `titleKey/title` | `basic.TopAppBar` |
 * | 顶栏齿轮 `FHeaderAction`（:466-478） | [ROUTE_ADVANCED] | `TopAppBar` 的 action 槽 |
 * | `HyperosSwitchTile(启用节假日标记)`（:508-516） | `holiday.enable` | `MiuixSwitchPreference` |
 * | `HyperosSectionLabel(customHolidayTitle)`（:525） | `SettingsLabel` | preference category |
 * | `HyperosNavTile(三态之一)`（:528-571） | `holiday.custom.*` | `MiuixArrowPreference` |
 * | `HyperosControlCard` + `HyperosButton(添加假期)`（:576-592） | `SettingsInline(CONTROL_CARD)` | `basic.Card` + 官方 `Button` |
 * | `HyperosSectionLabel(holidayDataYearLabel)`（:600-602） | `SettingsLabel` | preference category |
 * | `HyperosNavTile(法定节假日)`（:604-627） | `holiday.official.*` | `MiuixArrowPreference`（无箭头） |
 *
 * ## 不写进模型的两件事
 *
 * 1. **写盘队列**（:53-83）：`_updateDraft` → `_enqueuePersist` 是串行队列，
 *    而且写入前要用真源回灌节次表（`withLiveScheduleFieldsFrom`）——草稿可能比真源旧；
 * 2. **新增/编辑弹层的完整字段**（:85-315）：名字输入、起止日期两个日历、
 *    类型分段控件、删除按钮。模型只保留它用到的文案（[SettingsStringsExt3]）
 *    与「点了打开什么」（`SettingsAction.SHEET`）。
 */
object SettingsHolidayPage {

    const val ID = "settings-holiday"

    const val ID_TITLE_KEY = "holidaySettingsTitle"

    /** 高级页的具名路由（:473）。 */
    const val ROUTE_ADVANCED = "/settings/holiday/advanced"

    fun spec(
        state: SettingsPageState,
        data: HolidayPageData = HolidayPageData(),
    ): SettingsPageSpec {
        val s = SettingsStringsExt3
        return SettingsPageSpec(
            id = ID,
            titleKey = s.holidaySettingsTitle.key,
            title = s.holidaySettingsTitle.zh,
            nodes = listOf(
                // ── 区块 1：总开关（:503-519）
                SettingsGroup(
                    id = "holiday.group.enable",
                    children = listOf(
                        settingsRow(
                            id = "holiday.enable",
                            component = MiuixRowComponent.SWITCH,
                            title = s.holidayEnableTitle,
                            subtitle = s.holidayEnableSubtitle,
                            switchValue = data.enableHolidayMarking,
                            action = SettingsAction.WRITE_SETTING,
                        ),
                    ),
                ),
                SettingsGap("holiday.gap.enable"),

                // ── 区块 2：自定义假期（:521-594）
                SettingsLabel(
                    id = "holiday.section.custom",
                    textKey = s.customHolidayTitle.key,
                    text = s.customHolidayTitle.zh,
                ),
                SettingsGroup(
                    id = "holiday.group.custom",
                    children = customHolidayRows(data),
                ),
                // Dart 这里是一个裸 `SizedBox(height: 12)`（:574），
                // 与区块末尾的 `HyperosSectionGap`（:593）是两个独立空档，不合并。
                SettingsGap("holiday.gap.customAdd"),
                SettingsInline(
                    id = "holiday.card.add",
                    kind = InlineKind.CONTROL_CARD,
                    note = "添加假期按钮（:576-592）：整宽官方 Button 装在控制卡里，" +
                        "与数据迁移页的空态按钮同一写法",
                    labelKey = s.customHolidayAdd.key,
                    label = s.customHolidayAdd.zh,
                    texts = listOf(SettingsInlineText(s.customHolidayAdd.key, s.customHolidayAdd.zh)),
                ),
                SettingsGap("holiday.gap.custom"),

                // ── 区块 3：法定节假日（:596-629）
                SettingsLabel(
                    id = "holiday.section.official",
                    textKey = s.holidayDataYearLabel.key,
                    // :601 `holidayDataYearLabel(holidayData?.year ?? '')`——年份缺失就留空
                    text = s.holidayDataYearLabel.filled("year", data.year),
                ),
                SettingsGroup(
                    id = "holiday.group.official",
                    children = officialHolidayRows(data),
                ),
            ),
        )
    }

    /**
     * 自定义假期的三态（:528-571），优先级与 Dart 的 `if / else if / else` 一致：
     * **存储损坏 > 列表为空 > 逐条列出**。损坏态优先是刻意的——写入链路遇损坏
     * 会抛 `HolidayCustomSaveException`，列表里还显示旧条目会让人以为能改。
     */
    private fun customHolidayRows(data: HolidayPageData): List<SettingsNode> {
        val s = SettingsStringsExt3
        if (data.customHolidaysCorrupted) {
            return listOf(
                settingsRow(
                    id = "holiday.customCorrupted",
                    component = MiuixRowComponent.ARROW,
                    title = s.customHolidayCorrupted,
                    // :529-533 `enabled: false, showChevron: false`
                    enabled = false,
                ),
            )
        }
        if (data.customHolidays.isEmpty()) {
            return listOf(
                settingsRow(
                    id = "holiday.customEmpty",
                    component = MiuixRowComponent.ARROW,
                    title = s.customHolidayEmpty,
                    enabled = false,
                ),
            )
        }
        return data.customHolidays.map { group ->
            val range = formatRange(group.startDate, group.endDate)
            settingsRow(
                id = "holiday.custom.${group.groupId}",
                component = MiuixRowComponent.ARROW,
                // 假期名是用户数据，不来自 ARB
                title = ArbText(NON_ARB_TEXT, group.name),
                subtitle = typeLabel(group.type),
                valueKey = range.key,
                value = range.text,
                action = SettingsAction.SHEET,
            )
        }
    }

    /** 法定节假日：空态一行，否则逐条（:603-627）。 */
    private fun officialHolidayRows(data: HolidayPageData): List<SettingsNode> {
        val s = SettingsStringsExt3
        if (data.officialHolidays.isEmpty()) {
            return listOf(
                settingsRow(
                    id = "holiday.officialEmpty",
                    component = MiuixRowComponent.ARROW,
                    title = s.holidayNoUpcoming,
                    // :606 `HyperosNavTile(title: …, enabled: false)`
                    enabled = false,
                ),
            )
        }
        return data.officialHolidays.mapIndexed { index, item ->
            val range = formatRange(item.startDate, item.endDate)
            settingsRow(
                id = "holiday.official.$index",
                component = MiuixRowComponent.ARROW,
                // 节日名走本地化表（`holiday_name_localizer.dart:3-18`）：已收录的
                // 带自己的 ARB 键，未收录的原样显示（`NON_ARB_TEXT`，对拍时跳过）
                title = ArbText(item.nameKey, item.name),
                valueKey = range.key,
                value = range.text,
                // :615-624 `showChevron: false` 且没有 onTap —— 纯展示
                action = null,
            )
        }
    }

    /** 类型标签（:542-544）。 */
    fun typeLabel(type: HolidayKind): ArbText = when (type) {
        HolidayKind.VACATION -> SettingsStringsExt3.customHolidayTypeVacation
        HolidayKind.ADJUSTED_WORKDAY -> SettingsStringsExt3.customHolidayTypeWorkday
    }

    /**
     * 节假日区间文案（:633-650）。
     *
     * 三分支：同一天 → 「M 月 D 日」；同月 → 「M 月 S 日～E 日」；
     * 否则 → 「SM 月 SD 日～EM 月 ED 日」。
     *
     * **同月分支只比 `month`，不比 `year`**——Dart 就是这么写的（:641），
     * 跨年同月（12-30 → 次年 12-31）会走这一支。忠实搬运，不"顺手修正"。
     */
    fun formatRange(start: String, end: String): RangeText {
        val s = SettingsStringsExt3
        val startDate = parseDate(start)
        val endDate = parseDate(end)
        return when {
            startDate == endDate -> RangeText(
                s.holidayDateSameDay.key,
                s.holidayDateSameDay.zh
                    .replace("{month}", startDate.month.toString())
                    .replace("{day}", startDate.day.toString()),
            )

            startDate.month == endDate.month -> RangeText(
                s.holidayDateSameMonth.key,
                s.holidayDateSameMonth.zh
                    .replace("{month}", startDate.month.toString())
                    .replace("{start}", startDate.day.toString())
                    .replace("{end}", endDate.day.toString()),
            )

            else -> RangeText(
                s.holidayDateDiffMonth.key,
                s.holidayDateDiffMonth.zh
                    .replace("{startMonth}", startDate.month.toString())
                    .replace("{startDay}", startDate.day.toString())
                    .replace("{endMonth}", endDate.month.toString())
                    .replace("{endDay}", endDate.day.toString()),
            )
        }
    }

    /**
     * 节假日名本地化（`lib/l10n/holiday_name_localizer.dart:3-18`）。
     *
     * 持久化的名字有两种形态：新的 `holiday_name:<code>` 与老的中文原文。
     * 两者都映射到 ARB 文案，未收录的原样返回（`_ => name`）。
     *
     * 用 [fallback] 作为「法定假日」那一档的落地文案（Dart 传
     * `l10n.holidayStatutoryLabel`）。
     */
    fun localizeHolidayName(raw: String, fallback: ArbText): ArbText {
        val s = SettingsStringsExt3
        return when (raw) {
            "holiday_name:makeup_workday", "调休上班" -> s.holidayMakeupWorkday
            "holiday_name:new_year", "元旦" -> s.holidayNameNewYear
            "holiday_name:labor_day", "劳动节" -> s.holidayNameLaborDay
            "holiday_name:national_day", "国庆节" -> s.holidayNameNationalDay
            "holiday_name:spring_festival", "春节" -> s.holidayNameSpringFestival
            "holiday_name:qingming", "清明节" -> s.holidayNameQingming
            "holiday_name:dragon_boat", "端午节" -> s.holidayNameDragonBoat
            "holiday_name:mid_autumn", "中秋节" -> s.holidayNameMidAutumn
            "holiday_name:statutory", "法定假日", "Public holiday", "Holiday" -> fallback
            else -> ArbText(NON_ARB_TEXT, raw)
        }
    }

    /** `yyyy-MM-dd` → (year, month, day)；解析不了抛 [IllegalArgumentException]。 */    private fun parseDate(value: String): SimpleDate {
        val parts = value.split("-")
        require(parts.size == 3) { "日期必须形如 yyyy-MM-dd：$value" }
        return SimpleDate(
            year = parts[0].toIntOrNull() ?: error("年份不是数字：$value"),
            month = parts[1].toIntOrNull() ?: error("月份不是数字：$value"),
            day = parts[2].toIntOrNull() ?: error("日期不是数字：$value"),
        )
    }

    /** 只装年月日的最小日期值（纯 Kotlin，不引 `java.time` 以免拉高 API 地板）。 */
    internal data class SimpleDate(val year: Int, val month: Int, val day: Int)
}

/** 节假日类型（`lib/models/holiday_entry.dart` 的 `HolidayType`）。 */
enum class HolidayKind {
    /** `HolidayType.vacation` */
    VACATION,

    /** `HolidayType.adjustedWorkday` */
    ADJUSTED_WORKDAY,
}

/**
 * 一段日期区间的「已渲染文案 + 它的 ARB 模板键」。
 *
 * 键随身带着的意义：对拍测试能验证「区间是**用 ARB 模板拼的**」，
 * 而不只是「拼出来的字看起来对」——后者在模板改动时不会响。
 */
data class RangeText(val key: String, val text: String)

/**
 * 主页面的一份输入。
 *
 * 日期一律用 `yyyy-MM-dd` 字符串：Dart 侧 `HolidayEntry.date` 是 `DateTime`，
 * 但落到模型层只需要「哪年哪月哪日」（时区/时刻都不参与显示），
 * 用字符串可以让单测毫不含糊地钉住输入输出。
 */
data class HolidayPageData(
    /** `enableHolidayMarking` 默认 true（`timetable_settings.dart:760`）。 */
    val enableHolidayMarking: Boolean = true,
    /** 存储损坏：只显示「读取异常」，不显示旧条目（:528-533）。 */
    val customHolidaysCorrupted: Boolean = false,
    /** 已按 groupId 归并、按开始日期排好序的自定义假期。 */
    val customHolidays: List<HolidayGroupRow> = emptyList(),
    /** `holidayData?.year`；空串表示数据还没加载（:601 `?? ''`）。 */
    val year: String = "",
    /** 已按开始日期排序的法定节假日。 */
    val officialHolidays: List<HolidayItem> = emptyList(),
)

/** 一条已归并的自定义假期（Dart `_CustomHolidayGroup`，:835-849）。 */
data class HolidayGroupRow(
    val groupId: String,
    val name: String,
    val startDate: String,
    val endDate: String,
    val type: HolidayKind,
)

/** 法定节假日的一条显示项（Dart `_HolidayDisplayItem`，:819-833）。 */
data class HolidayItem(
    /** 屏上节日名（已过 `localizeHolidayName` 本地化）。 */
    val name: String,
    val startDate: String,
    val endDate: String,
    val type: HolidayKind,
    /** 已经过去的节假日渲染时降到 55% 透明度（:613-614）。 */
    val isPast: Boolean = false,
    /** [name] 的 ARB 键；未收录的节日名用 [NON_ARB_TEXT]。 */
    val nameKey: String = NON_ARB_TEXT,
)
