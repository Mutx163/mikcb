package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayType
import java.time.LocalDate
import java.time.LocalDateTime

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
 * | 顶栏齿轮 `FHeaderAction`（:466-478） | `topBarAction` ( [ROUTE_ADVANCED] ) | `TopAppBar` 的 action 槽 |
 * | `HyperosSwitchTile(启用节假日标记)`（:508-516） | `holiday.enable` | `MiuixSwitchPreference` |
 * | `HyperosSectionLabel(customHolidayTitle)`（:525） | `SettingsLabel` | preference category |
 * | `HyperosNavTile(三态之一)`（:528-571） | `holiday.custom.*` | `MiuixArrowPreference` |
 * | `HyperosControlCard` + `HyperosButton(添加假期)`（:576-592） | `SettingsInline(CONTROL_CARD)` | `basic.Card` + 官方 `Button` |
 * | `HyperosSectionLabel(holidayDataYearLabel)`（:600-602） | `SettingsLabel` | preference category |
 * | `HyperosNavTile(法定节假日)`（:604-627） | `holiday.official.*` | `MiuixArrowPreference`（无箭头） |
 *
 * ## 数据 → 入参：[buildPageData]
 *
 * 页面要显示的东西全在 Dart 的 `build` 里现算（`:396-462`）：官方条目归并成「一个假期一行」、
 * 挑代表项、判「已过去」、自定义假期按组归并排序。这些判断不能留在渲染层（渲染层没有
 * 数据层类型、也没法在 JVM 里单测），所以集中在一个纯函数里：[buildPageData]。
 *
 * 与 Dart 的**有意**差异有两条（isPast 的当天边界、损坏态不带旧列表），
 * 逐条写在 [buildPageData] 的 KDoc 上。
 *
 * ## 不写进模型的两件事
 *
 * 1. **写盘队列**（:53-83）：`_updateDraft` → `_enqueuePersist` 是串行队列，
 *    而且写入前要用真源回灌节次表（`withLiveScheduleFieldsFrom`）——草稿可能比真源旧；
 * 2. **新增/编辑弹层的完整字段**（:85-315）：名字输入、起止日期两个日历、
 *    类型分段控件、删除按钮。模型只保留它用到的文案（[SettingsStringsExt3]）
 *    与「点了/长按了打开什么」（`action = SHEET` = 编辑，`longPressAction = DIALOG` = 删除确认）。
 */
object SettingsHolidayPage {

    const val ID = "settings-holiday"

    const val ID_TITLE_KEY = "holidaySettingsTitle"

    /** 高级页的具名路由（:473）。 */
    const val ROUTE_ADVANCED = "/settings/holiday/advanced"

    /**
     * 进高级页入口的稳定 rowId。
     *
     * 原版入口是顶栏右上角齿轮（`FHeaderAction`，:466-478），屏上没有行；Compose 里
     * 顶栏 action 槽由渲染层提供 [SettingsPageSpec.topBarAction]，同一个目标还有一条
     * **兜底行**（[spec] 的 `showAdvancedEntryFallback`）。两处共用这个 id/常量，
     * 宿主与渲染层按 id 认入口，**不要按文案匹配**。
     */
    const val ADVANCED_ENTRY_ROW_ID = "holiday.advancedEntry"

    /** 进高级页的文案（`FHeaderAction.semanticsLabel`，:469 用的是 `holidayAdvancedTitle`）。 */
    val ADVANCED_ENTRY_LABEL: ArbText = SettingsStringsExt3.holidayAdvancedTitle

    /** 用户自建假期的 groupId 前缀（`:426`，这类条目不属于「法定节假日」）。 */
    const val CUSTOM_GROUP_PREFIX = "custom-"

    /** 自定义假期里没有 groupId 的条目归到哪一组（Dart `:399` `entry.groupId ?? 'ungrouped'`）。 */
    const val UNGROUPED_CUSTOM_GROUP = "ungrouped"

    fun spec(
        state: SettingsPageState,
        data: HolidayPageData = HolidayPageData(),
        /**
         * 是否在列表末尾（法定节假日区块之后）附一行「[ADVANCED_ENTRY_LABEL]」导航行。
         *
         * 默认 `false`：原版没有这一行（入口只在顶栏），既有的渲染行为与既有测试因此
         * 完全不变；渲染层的顶栏 action 槽不可用时由宿主开成 `true` 兜底。
         */
        showAdvancedEntryFallback: Boolean = false,
    ): SettingsPageSpec {
        val s = SettingsStringsExt3
        return SettingsPageSpec(
            id = ID,
            titleKey = s.holidaySettingsTitle.key,
            title = s.holidaySettingsTitle.text,
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
                    text = s.customHolidayTitle.text,
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
                    label = s.customHolidayAdd.text,
                    texts = listOf(SettingsInlineText(s.customHolidayAdd.key, s.customHolidayAdd.text)),
                ),
                SettingsGap("holiday.gap.custom"),

                // ── 区块 3：法定节假日（:596-629）
                SettingsLabel(
                    id = "holiday.section.official",
                    textKey = officialSectionLabel(data).key,
                    // :601 `holidayDataYearLabel(holidayData?.year ?? '')`——年份缺失时
                    // Dart 会渲染成「 年法定节假日」（前导空格 + 空年份）。加载中 / 没数据
                    // 的时候直接退回不带年份的那句「法定节假日」，别把半个模板摆上屏。
                    text = officialSectionLabel(data).text,
                ),
                SettingsGroup(
                    id = "holiday.group.official",
                    children = officialHolidayRows(data),
                ),
            ) + advancedEntryFallbackNodes(showAdvancedEntryFallback),
            // 顶栏右上角齿轮（:466-478）：原版是 `suffixes: [FHeaderAction(...)]`，
            // 这里表达成渲染层的 action 槽（点击等价一次 NAVIGATE 到 ROUTE_ADVANCED）。
            topBarAction = SettingsTopAction(
                route = ROUTE_ADVANCED,
                semanticsLabel = s.holidayAdvancedTitle.text,
            ),
        )
    }

    /**
     * 兜底入口行（仅 `showAdvancedEntryFallback = true` 时出现）。
     *
     * 为什么需要：Flutter 原版进高级页的**唯一**入口是顶栏齿轮（`:466-478`）。
     * 渲染层的顶栏 action 槽若还没接上，高级页在 Compose 里就是完全进不去的死页
     * （壳有 `b.holidayAdvanced` 分派，页面里却没有出口）。这一行把同一目标再暴露一次，
     * 位置照设置族「行式入口」惯例排在列表末尾。
     */
    private fun advancedEntryFallbackNodes(enabled: Boolean): List<SettingsNode> {
        if (!enabled) return emptyList()
        return listOf(
            SettingsGroup(
                id = "holiday.group.advancedEntry",
                children = listOf(
                    settingsRow(
                        id = ADVANCED_ENTRY_ROW_ID,
                        component = MiuixRowComponent.ARROW,
                        title = ADVANCED_ENTRY_LABEL,
                        action = SettingsAction.NAVIGATE,
                        actionTarget = ROUTE_ADVANCED,
                    ),
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
            // 加载中不摆「暂无自定义假期」：列表还没读出来，说「没有」是假的。
            if (data.isLoading) return emptyList()
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
                // :568-570 `onLongPress: () => _confirmDeleteCustomHoliday(group.groupId)`
                //
                // **DIALOG 在这里表示「删除确认」这个界面意图，不是 OverlayDialog 的字面语义**：
                // 渲染层只把 action 原样转给宿主，宿主靠 (action, rowId) 两个维度分辨弹哪个层
                // —— `SHEET` + `holiday.custom.*` = 编辑弹层，`DIALOG` + `holiday.custom.*` = 删除确认。
                longPressAction = SettingsAction.DIALOG,
            )
        }
    }

    /**
     * 法定节假日区块的小标题。
     *
     * - **加载中且还没有年份**：用不带年份的「法定节假日」。这是 Dart 没有的状态
     *   （Dart 没有加载态），不这么做会渲染成「 年法定节假日」——半个模板摆上屏；
     * - **其余情况**：保持 Dart 逐字口径 `holidayDataYearLabel(holidayData?.year ?? '')`，
     *   包括年份缺失时那个前导空格（`SettingsHolidayPageTest` 钉着它，改了口径就是要改对拍）。
     */
    internal fun officialSectionLabel(data: HolidayPageData): ArbText {
        val s = SettingsStringsExt3
        return if (data.year.isEmpty() && data.isLoading) {
            s.holidayStatutoryLabel
        } else {
            s.holidayDataYearLabel.withArguments("year", data.year)
        }
    }

    /** 法定节假日：加载态一行、空态一行，否则逐条（:603-627）。 */
    private fun officialHolidayRows(data: HolidayPageData): List<SettingsNode> {
        val s = SettingsStringsExt3
        // 加载中优先于空态：远端超时 8 秒（`HolidayService.TIMEOUT_MILLIS`），这段时间
        // 显示「近期没有节假日」等于告诉用户一件假事（他确实可能在放假）。
        // 只在**没有条目**时顶掉空态：真拿到了就先显示条目，不拿加载行盖住真数据。
        if (data.isLoading && data.officialHolidays.isEmpty()) {
            return listOf(
                settingsRow(
                    id = "holiday.loading",
                    component = MiuixRowComponent.ARROW,
                    title = s.holidayDataLoading,
                    enabled = false,
                ),
            )
        }
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
                // :613-614 `Opacity(opacity: holiday.isPast ? 0.55 : 1)`：
                // 已经过去的节假日变淡但仍显示（与 enabled 不同，不是禁用语义）
                dimmed = item.isPast,
            )
        }
    }

    /** 类型标签（:542-544）。 */
    fun typeLabel(type: HolidayKind): ArbText = when (type) {
        HolidayKind.VACATION -> SettingsStringsExt3.customHolidayTypeVacation
        HolidayKind.ADJUSTED_WORKDAY -> SettingsStringsExt3.customHolidayTypeWorkday
    }

    // ---------------------------------------------------------------- 数据 → 入参

    /**
     * 把「真数据」转成 [HolidayPageData]——本页唯一需要业务判断的地方。
     *
     * 逐条对齐 Dart：
     * - 官方列表：`settings_holiday.dart:421-462`（跳过 `custom-` 组 → 按 groupId 归并 →
     *   每组取代表项 → 按开始日期升序）；
     * - 自定义假期：`:396-412`（按 groupId 归并 → 组内按日期升序 → 组间按开始日期升序）。
     *
     * ## 与 Dart 的两处**有意**差异
     *
     * 1. **isPast 的边界**：Dart 是 `last.date.isBefore(DateTime.now())`（`:443`），
     *    `now` 带时刻而条目日期是零点 ⇒ 假期最后一天**就是今天**时 Dart 判「已过去」
     *    （当天节假日一进页面就变淡，明显不对）。本实现按「日期比日期」：
     *    `endDate < today` 才算过去，`endDate == today` 不算过去。
     * 2. **损坏态不带旧列表**：Dart 在损坏态只是不渲染列表（`:528`），`_customHolidays`
     *    里的残留值仍留在 state 里。这里索性不把它们带进模型——写入链路遇损坏会抛
     *    `HolidayCustomSaveException`，显示旧条目会让人以为还能改。
     *
     * @param official 官方数据；`null` = 还没加载（法定节假日出空态、年份留空串）。
     * @param customCorrupted 自定义假期的存储损坏态：**优先**于列表，见上。
     * @param today 「今天」，由调用方注入（不要在模型层读系统时钟，否则测试钉不住边界）。
     */
    fun buildPageData(
        enableHolidayMarking: Boolean,
        official: HolidayData?,
        customHolidays: List<HolidayEntry>,
        customCorrupted: Boolean,
        today: LocalDate,
        /**
         * 首屏是否还在加载（`HolidayProvider.initialize` 还没跑完）。
         *
         * 缺省 `false` ⇒ 既有调用点与既有测试的行为完全不变；宿主传
         * `初始化为 true && snapshot.data == null`，于是「远端超时 8 秒」这段时间
         * 显示的是加载态而不是「近期没有节假日」的假空态。
         */
        loading: Boolean = false,
    ): HolidayPageData = HolidayPageData(
        enableHolidayMarking = enableHolidayMarking,
        customHolidaysCorrupted = customCorrupted,
        customHolidays = if (customCorrupted) emptyList() else groupCustomHolidays(customHolidays),
        // :601 `holidayData?.year ?? ''`
        year = official?.year?.toString() ?: "",
        officialHolidays = if (official == null) emptyList() else buildOfficialItems(official, today),
        isLoading = loading,
    )

    /** `_groupCustomHolidays`（:396-412）。 */
    private fun groupCustomHolidays(entries: List<HolidayEntry>): List<HolidayGroupRow> {
        // Dart 用 Map 保序（首次出现顺序），组内顺序随后由 sort 定，组间由 :411 定
        val grouped = LinkedHashMap<String, MutableList<HolidayEntry>>()
        for (entry in entries) {
            grouped.getOrPut(entry.groupId ?: UNGROUPED_CUSTOM_GROUP) { mutableListOf() }.add(entry)
        }
        return grouped.map { (groupId, group) ->
            // 组内按日期升序（:403）：起止取首尾，名字/类型取第一条
            val sorted = group.sortedBy { it.date }
            HolidayGroupRow(
                groupId = groupId,
                name = sorted.first().name,
                startDate = isoDate(sorted.first().date),
                endDate = isoDate(sorted.last().date),
                type = displayKind(sorted.first().type),
            )
        }.sortedBy { it.startDate }  // :411 组间按开始日期升序
    }

    /** 官方列表构造（:421-462）。 */
    private fun buildOfficialItems(official: HolidayData, today: LocalDate): List<HolidayItem> {
        val s = SettingsStringsExt3
        val items = mutableListOf<HolidayItem>()
        // `seenGroups`（:424）：每组只出一项，代表项取**该组第一次出现**时的归并结果
        val seenGroups = mutableSetOf<String>()
        for (entry in official.entries) {
            val groupId = entry.groupId
            // :426-428 用户自建的假期（custom- 前缀）属于「自定义假期」区块，这里跳过
            if (groupId != null && groupId.startsWith(CUSTOM_GROUP_PREFIX)) continue
            if (groupId != null) {
                if (!seenGroups.add(groupId)) continue
                val groupEntries = official.entriesForGroup(groupId)  // 已按日期升序
                val vacationEntries = groupEntries.filter { it.type == HolidayType.Vacation }
                // :431-436 代表项：优先该组第一条 vacation，没有则组内第一条
                val representative =
                    if (vacationEntries.isNotEmpty()) vacationEntries else groupEntries
                val name = localizeHolidayName(representative.first().name, s.holidayStatutoryLabel)
                items += HolidayItem(
                    name = name.text,
                    startDate = isoDate(representative.first().date),
                    endDate = isoDate(representative.last().date),
                    // 类型照实给（:442）；三值 HolidayType → 两档 HolidayKind 的映射见 [displayKind]
                    type = displayKind(representative.first().type),
                    // :443 isPast 看组内**最后一条**，不是代表项那一条
                    isPast = isPast(representative.last().date, today),
                    nameKey = name.key,
                )
            } else if (entry.type == HolidayType.AdjustedWorkday) {
                // :446-457 无组的补班日单独成项：名称固定「补班」、起止同日
                items += HolidayItem(
                    name = s.holidayMakeupWorkday.text,
                    startDate = isoDate(entry.date),
                    endDate = isoDate(entry.date),
                    type = HolidayKind.ADJUSTED_WORKDAY,
                    isPast = isPast(entry.date, today),
                    nameKey = s.holidayMakeupWorkday.key,
                )
            }
        }
        // :462 全部按开始日期升序（`yyyy-MM-dd` 的字典序与时间序一致，sortedBy 稳定）
        return items.sortedBy { it.startDate }
    }

    /**
     * Dart 的 `HolidayType` 三值 → 本模型的 [HolidayKind] 两档。
     *
     * 丢掉的那一档是 `AdjustedRestday`（调休休息日）。模型只有「假期 / 调休上班」两档，
     * 因为**法定节假日那一行根本不渲染类型**（:610-627 只给 title + details），
     * 唯一会显示类型的是自定义假期行，而自定义假期只有 vacation / adjustedWorkday 两种
     * （新增弹层的分段控件就两档，:85-315）。调休休息日在语义上是「放假」，归到假期一档。
     */
    private fun displayKind(type: HolidayType): HolidayKind = when (type) {
        HolidayType.Vacation -> HolidayKind.VACATION
        HolidayType.AdjustedWorkday -> HolidayKind.ADJUSTED_WORKDAY
        HolidayType.AdjustedRestday -> HolidayKind.VACATION
    }

    /** `yyyy-MM-dd`（补零）——补零后字典序才等于时间序，排序与区间文案都靠它。 */
    private fun isoDate(date: LocalDateTime): String =
        "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)

    /** 日期比日期：`today` 当天不算过去（与 Dart 的 `isBefore(now)` 差异见 [buildPageData]）。 */
    private fun isPast(date: LocalDateTime, today: LocalDate): Boolean =
        date.toLocalDate().isBefore(today)

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
                s.holidayDateSameDay.text
                    .replace("{month}", startDate.month.toString())
                    .replace("{day}", startDate.day.toString()),
            )

            startDate.month == endDate.month -> RangeText(
                s.holidayDateSameMonth.key,
                s.holidayDateSameMonth.text
                    .replace("{month}", startDate.month.toString())
                    .replace("{start}", startDate.day.toString())
                    .replace("{end}", endDate.day.toString()),
            )

            else -> RangeText(
                s.holidayDateDiffMonth.key,
                s.holidayDateDiffMonth.text
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
    /**
     * 首屏加载中：两个区块都不出「没有」的空态，法定节假日区块显示一行加载提示。
     *
     * 与 [customHolidaysCorrupted] 不冲突：损坏态是**读到了**但解不出来，优先于加载态显示。
     */
    val isLoading: Boolean = false,
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
