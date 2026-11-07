package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.calendar.HolidayLogLine

/**
 * 节假日数据更新页（`lib/screens/settings/settings_holiday.dart:663-817`）结构模型。
 *
 * ## 它不是「高级设置」，是「更新日志 + 手动刷新」
 *
 * 从主页面顶栏齿轮进来（`FHeaderAction`，:466-478），给爱折腾的用户看
 * 节假日数据是怎么来的：一张更新日志卡（可能很长）+ 一条固定底栏的「检查更新」。
 * 日志为空时显示「暂无日志」（:727-733）——注意这三字**是硬编码的**，
 * 不在 ARB 里（`'暂无日志'` 直接写在 Dart 源码里）。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: holidayAdvancedTitle)`（:707-709） | `titleKey/title` | `basic.TopAppBar` |
 * | `HyperosSectionLabel(holidayUpdateLog)`（:719） | `SettingsLabel` | preference category |
 * | `HyperosListGroup` 里的日志条目（:734-783） | `holidayAdvanced.logList` | `MiuixArrowPreference`（无箭头、不可点） |
 * | 空态 `Text('暂无日志')`（:727-733） | `holidayAdvanced.logEmpty` | 同上 |
 * | 底栏 `HyperosButton(检查更新)`（:792-812） | `footerNode` 里的 `SettingsInline(CONTROL_CARD)` | `basic.Card` + 官方 `Button` |
 *
 * ## 不写进模型的两件事
 *
 * 1. **底栏的固定方式**：模型只用 `SettingsPageSpec.footerNode` 声明「这块不在滚动区里」，
 *    真正把它钉在底部（+ 上边分割线 + SafeArea）由渲染层的 `QingyuPageScaffold(bottomBar=…)` 做；
 * 2. 日志正文的本地化（`HolidayLogLocalizer.localize`，:746-749）在
 *    `lib/l10n/holiday_log_localizer.dart`，属另一个文件；本模型只要求
 *    调用方把**已本地化**的正文传进来（[buildData] 只做搬运，不做翻译）。
 */
object SettingsHolidayAdvancedPage {

    const val ID = "settings-holiday-advanced"

    const val ID_TITLE_KEY = "holidayAdvancedTitle"

    fun spec(
        state: SettingsPageState,
        data: HolidayAdvancedData = HolidayAdvancedData(),
    ): SettingsPageSpec {
        val s = SettingsStringsExt3
        return SettingsPageSpec(
            id = ID,
            titleKey = s.holidayAdvancedTitle.key,
            title = s.holidayAdvancedTitle.text,
            nodes = listOf(
                SettingsLabel(
                    id = "holidayAdvanced.section.log",
                    textKey = s.holidayUpdateLog.key,
                    text = s.holidayUpdateLog.text,
                ),
                SettingsGroup(
                    id = "holidayAdvanced.group.log",
                    children = logRows(data),
                ),
            ),
            // 固定底栏（:792-812）：原版是页面 `Column` 的最后一个子项，**不随日志滚动**。
            // 放进 `nodes` 会跟着列表滚走（长日志时按钮被推出屏幕），所以走 footerNode。
            footerNode = refreshCard(refreshing = data.refreshing),
        )
    }

    /**
     * 「检查更新」按钮卡（:792-812）。
     *
     * 只有 `loading` 随 [HolidayAdvancedData.refreshing] 变，label 恒为
     * `holidayCheckUpdate`（:803-807）。`busy` 由渲染层翻成「按钮转圈 + 不可点」
     * （`SettingsInline.busy`），**文案不换**——Dart 的 label 是写死的。
     */
    private fun refreshCard(refreshing: Boolean): SettingsInline {
        val s = SettingsStringsExt3
        return SettingsInline(
            id = "holidayAdvanced.card.refresh",
            kind = InlineKind.CONTROL_CARD,
            note = "检查更新按钮（:792-812）：固定底栏里的整宽官方 Button，" +
                "与列表滚动区分离，故单独走 SettingsPageSpec.footerNode",
            labelKey = s.holidayCheckUpdate.key,
            label = s.holidayCheckUpdate.text,
            texts = listOf(
                SettingsInlineText(s.holidayCheckUpdate.key, s.holidayCheckUpdate.text),
            ),
            busy = refreshing,
        )
    }

    /**
     * 日志条目（:727-783）：空态一行占位，否则逐条。
     *
     * 每条日志在 Dart 里是「时刻（tabular 数字）+ 正文」两行一个 `Column`（:750-781）。
     * 模型用 `stacked = true` 表达这个上下排：`title` = 时刻（次要色小字）、
     * `subtitle` = 正文（主要色）。改成左右排会把长正文挤成一行省略号。
     */
    private fun logRows(data: HolidayAdvancedData): List<SettingsNode> {
        if (data.logs.isEmpty()) {
            return listOf(
                settingsRow(
                    id = "holidayAdvanced.logEmpty",
                    component = MiuixRowComponent.ARROW,
                    // 这三个字是 Dart 里硬编码的，ARB 没有对应键
                    title = ArbText(NON_ARB_TEXT, EMPTY_LOG_TEXT),
                    enabled = false,
                ),
            )
        }
        return data.logs.mapIndexed { index, entry ->
            settingsRow(
                id = "holidayAdvanced.log.$index",
                component = MiuixRowComponent.ARROW,
                title = ArbText(NON_ARB_TEXT, entry.time),
                subtitle = ArbText(NON_ARB_TEXT, entry.message),
                // 纯展示，不可点
                enabled = false,
                stacked = true,
            )
        }
    }

    /** `settings_holiday.dart:730` 直接写在源码里的三个字。 */
    const val EMPTY_LOG_TEXT = "暂无日志"

    // ---------------------------------------------------------------- 数据 → 入参

    /**
     * 把数据层的日志搬成高级页入参。
     *
     * 只做搬运，不做三件别处该做的事：
     * 1. **不排序、不截断**：最新在前、最多 50 条由数据层（`HolidayProvider`）保证，
     *    模型再排一次会让「谁负责顺序」变成两处口径；
     * 2. **不本地化**：[HolidayLogLine.message] 进来时已是中文（`HolidayLogLocalizer`），
     *    这里再查一次表会把未识别的键吞掉；
     * 3. **不格式化时间**：[HolidayLogLine.time] 已是 `HH:mm:ss` 定长串。
     *
     * @param refreshing `HolidaySnapshot.refreshing`；只影响底栏按钮的 loading 态，
     *   文案恒为「检查更新」（`:803-807`）。
     */
    fun buildData(logs: List<HolidayLogLine>, refreshing: Boolean): HolidayAdvancedData =
        HolidayAdvancedData(
            // 注意两个类型名只差一个词：calendar 的 HolidayLogLine（数据层）→
            // 本包的 HolidayLogEntry（页面词汇），字段逐一同形，故直接搬运。
            logs = logs.map { HolidayLogEntry(it.time, it.message) },
            refreshing = refreshing,
        )
}

/**
 * 高级页的输入。
 *
 * [logs] 里的正文要求**已本地化**（Dart 侧走 `HolidayLogLocalizer.localize`），
 * 时间要求**已格式化**（Dart 侧是 `log.timeString`）。
 */
data class HolidayAdvancedData(
    val logs: List<HolidayLogEntry> = emptyList(),
    /** 正在刷新（只影响按钮的 loading 态，不改文案——:803-807 的 label 是死的）。 */
    val refreshing: Boolean = false,
)

/** 一条更新日志（时刻 + 已本地化正文）。 */
data class HolidayLogEntry(val time: String, val message: String)
