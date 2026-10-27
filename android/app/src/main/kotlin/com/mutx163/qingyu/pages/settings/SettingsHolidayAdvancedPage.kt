package com.mutx163.qingyu.pages.settings

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
 * | 底栏 `HyperosButton(检查更新)`（:792-812） | `SettingsInline(CONTROL_CARD)` | `basic.Card` + 官方 `Button` |
 *
 * ## 不写进模型的两件事
 *
 * 1. **底栏是固定的**（`Column` 的最后一个子项，不随列表滚动）：官方壳里由
 *    渲染层把 `holidayAdvanced.card.refresh` 放在滚动区之外；
 * 2. 日志正文的本地化（`HolidayLogLocalizer.localize`，:746-749）在
 *    `lib/l10n/holiday_log_localizer.dart`，属另一个文件；本模型只要求
 *    调用方把**已本地化**的正文传进来。
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
            title = s.holidayAdvancedTitle.zh,
            nodes = listOf(
                SettingsLabel(
                    id = "holidayAdvanced.section.log",
                    textKey = s.holidayUpdateLog.key,
                    text = s.holidayUpdateLog.zh,
                ),
                SettingsGroup(
                    id = "holidayAdvanced.group.log",
                    children = logRows(data),
                ),
                SettingsInline(
                    id = "holidayAdvanced.card.refresh",
                    kind = InlineKind.CONTROL_CARD,
                    note = "检查更新按钮（:792-812）：固定底栏里的整宽官方 Button，" +
                        "与列表滚动区分离，故单独成节点",
                    labelKey = s.holidayCheckUpdate.key,
                    label = s.holidayCheckUpdate.zh,
                    texts = listOf(
                        SettingsInlineText(s.holidayCheckUpdate.key, s.holidayCheckUpdate.zh),
                    ),
                ),
            ),
        )
    }

    /**
     * 日志条目（:727-783）：空态一行占位，否则逐条。
     *
     * 每条日志在 Dart 里是「时刻（tabular 数字）+ 正文」两行一个 `Column`；
     * 模型把时刻落在 [SettingsRow.title]、正文落在 [SettingsRow.value]，
     * 由渲染层决定是上下排还是左右排（Dart 是上下排，:750-781）。
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
                valueKey = NON_ARB_TEXT,
                value = entry.message,
                // 纯展示，不可点
                enabled = false,
            )
        }
    }

    /** `settings_holiday.dart:730` 直接写在源码里的三个字。 */
    const val EMPTY_LOG_TEXT = "暂无日志"
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
