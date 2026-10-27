package com.mutx163.qingyu.pages.settings

/**
 * 「超级岛与通知」入口页（`lib/screens/settings/settings_live.dart:30-166`）结构模型。
 *
 * ## 这一页为什么只有三组七行
 *
 * 它是设置的**二级入口**，本身不含任何开关：真正的调节都在四个子页里
 * （提醒时段 / 上课前显示 / 课中与下课显示 / 后台保活）。2026 年的 IA 调整
 * （Dart :68-69 的注释）把原来一个无名大组拆成三个带标签组：
 * 「提醒 / 显示内容 / 维护与自检」——偏好、显示、诊断三种心智不该挤在一起。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: liveSettingsTitle)`（:49-52） | `titleKey/title` | `basic.TopAppBar` |
 * | `HyperosSectionLabel(liveGroupReminders)`（:74） | `SettingsLabel` | preference category |
 * | `HyperosListGroup` + `HyperosListTile(提醒时段)`（:75-91） | `live.reminderTiming` | `MiuixArrowPreference` |
 * | `HyperosSectionGap`（:92） | `SettingsGap` | `SizedBox(12dp)` |
 * | `HyperosSectionLabel(liveGroupDisplay)`（:93） | `SettingsLabel` | preference category |
 * | `HyperosListTile(上课前提醒显示, details: 摘要)`（:96-111） | `live.beforeClassDisplay` | `MiuixArrowPreference` |
 * | `HyperosListTile(课中与下课提醒显示, details: 摘要)`（:113-129） | `live.duringEndDisplay` | 同上 |
 * | `HyperosSectionGap`（:132） | `SettingsGap` | `SizedBox(12dp)` |
 * | `HyperosSectionLabel(liveGroupMaintenance)`（:133） | `SettingsLabel` | preference category |
 * | `HyperosListTile(后台保活)`（:136-148） | `live.keepAlive` | `MiuixArrowPreference` |
 * | `HyperosListTile(自检)`（:149-160） | `live.selfCheck` | 同上 |
 *
 * ## 不写进模型的三件事
 *
 * 1. **每次从子页返回都重读草稿**（:85-88 等六处 `_draft = context.read…settings`）——
 *    这是生命周期行为，模型只描述「点了去哪」；
 * 2. 四个子页自己的内容在 `live_settings_subpages.dart`，另有页码归属；
 * 3. **状态芯片的形状**（胶囊）不是本页的东西，见 [SettingsLiveSelfCheckPage] 的口径说明。
 */
object SettingsLivePage {

    const val ID = "settings-live"

    const val ID_TITLE_KEY = "liveSettingsTitle"

    /** 导航目标键（不是路由名：这几个子页由 Dart 直接 new 出来，没有具名路由）。 */
    const val TARGET_REMINDER_TIMING = "live/reminder-timing"
    const val TARGET_BEFORE_CLASS_DISPLAY = "live/display/before-class"
    const val TARGET_DURING_END_DISPLAY = "live/display/during-end"
    const val TARGET_KEEP_ALIVE = "live/keep-alive"

    /** 自检页有具名路由（:151-158 + `debug_deep_link_route_registry.dart:64`）。 */
    const val ROUTE_SELF_CHECK = "/settings/live/self-check"

    fun spec(state: SettingsPageState, data: LivePageData = LivePageData()): SettingsPageSpec {
        val s = SettingsStringsExt3
        return SettingsPageSpec(
            id = ID,
            titleKey = s.liveSettingsTitle.key,
            title = s.liveSettingsTitle.zh,
            nodes = listOf(
                SettingsLabel(
                    id = "live.section.reminders",
                    textKey = s.liveGroupReminders.key,
                    text = s.liveGroupReminders.zh,
                ),
                SettingsGroup(
                    id = "live.group.reminders",
                    children = listOf(
                        settingsRow(
                            id = "live.reminderTiming",
                            component = MiuixRowComponent.ARROW,
                            title = s.liveReminderTimingTitle,
                            action = SettingsAction.NAVIGATE,
                            actionTarget = TARGET_REMINDER_TIMING,
                        ),
                    ),
                ),
                SettingsGap("live.gap.display"),
                SettingsLabel(
                    id = "live.section.display",
                    textKey = s.liveGroupDisplay.key,
                    text = s.liveGroupDisplay.zh,
                ),
                SettingsGroup(
                    id = "live.group.display",
                    children = listOf(
                        displayRow(
                            id = "live.beforeClassDisplay",
                            title = s.beforeClassDisplaySettingsTitle,
                            summary = displaySummary(data.beforeClass),
                            target = TARGET_BEFORE_CLASS_DISPLAY,
                        ),
                        displayRow(
                            id = "live.duringEndDisplay",
                            title = s.duringEndDisplaySettingsTitle,
                            // :65-67 —— 跟随上课前时摘要直接就是那句「跟随上课前提醒」
                            summary = if (data.duringEndFollowBeforeClass) {
                                LiveSummary(s.followBeforeClassSetting.key, s.followBeforeClassSetting.zh)
                            } else {
                                displaySummary(data.duringEnd)
                            },
                            target = TARGET_DURING_END_DISPLAY,
                        ),
                    ),
                ),
                SettingsGap("live.gap.maintenance"),
                SettingsLabel(
                    id = "live.section.maintenance",
                    textKey = s.liveGroupMaintenance.key,
                    text = s.liveGroupMaintenance.zh,
                ),
                SettingsGroup(
                    id = "live.group.maintenance",
                    children = listOf(
                        settingsRow(
                            id = "live.keepAlive",
                            component = MiuixRowComponent.ARROW,
                            title = s.liveKeepAliveTitle,
                            action = SettingsAction.NAVIGATE,
                            actionTarget = TARGET_KEEP_ALIVE,
                        ),
                        settingsRow(
                            id = "live.selfCheck",
                            component = MiuixRowComponent.ARROW,
                            title = s.liveSelfCheckTitle,
                            action = SettingsAction.NAVIGATE,
                            actionTarget = ROUTE_SELF_CHECK,
                        ),
                    ),
                ),
            ),
        )
    }

    private fun displayRow(
        id: String,
        title: ArbText,
        summary: LiveSummary,
        target: String,
    ): SettingsRow = settingsRow(
        id = id,
        component = MiuixRowComponent.ARROW,
        title = title,
        valueKey = summary.key,
        value = summary.text,
        action = SettingsAction.NAVIGATE,
        actionTarget = target,
    )

    /**
     * 直播显示设置的摘要行文案（`settings_shared.dart:133-161`）。
     *
     * 口径逐字搬运：勾选项用 `·` 串联；0 项 → 「最简显示」；1~2 项 → 原样拼；
     * 3 项及以上 → 「{第一项} 等 {N} 项」。
     *
     * 倒计时与阶段文字**互斥**（`else if`）：两个都开时只算倒计时。
     */
    fun displaySummary(input: LiveDisplayInput): LiveSummary {
        val s = SettingsStringsExt3
        val parts = mutableListOf<ArbText>()
        if (input.showCourseName) {
            parts += if (input.useShortName) {
                s.liveDisplaySummaryShortName
            } else {
                s.liveDisplaySummaryCourseName
            }
        }
        if (input.showLocation) parts += s.liveDisplaySummaryLocation
        if (input.showCountdown) {
            parts += s.liveDisplaySummaryCountdownShort
        } else if (input.showStageText) {
            parts += s.liveDisplaySummaryStageText
        }
        if (input.enableMiuiIslandLabelImage) parts += s.liveDisplaySummaryLeftLabelImage

        if (parts.isEmpty()) {
            return LiveSummary(s.liveDisplaySummaryMinimal.key, s.liveDisplaySummaryMinimal.zh)
        }
        if (parts.size <= 2) {
            // 拼出来的串不是单条 ARB 文案，故 key 为 null
            return LiveSummary(null, parts.joinToString("·") { it.zh })
        }
        return LiveSummary(
            s.liveDisplaySummaryMore.key,
            s.liveDisplaySummaryMore.zh
                .replace("{first}", parts.first().zh)
                .replace("{count}", parts.size.toString()),
        )
    }
}

/**
 * 一段摘要的「已渲染文案 + 它的 ARB 键」。
 *
 * [key] 为 null 表示这段文字是拼出来的（`简称·地点`），不来自单条 ARB。
 */
data class LiveSummary(val key: String?, val text: String)

/**
 * 一份直播显示设置里**摘要用到的**那几个字段
 * （`LiveDisplaySettings` 的子集，`timetable_settings_live.dart:60-83`）。
 *
 * 只搬摘要要用的 6 个：完整 21 字段的展示设置属于显示子页，本页只需要回答
 * 「这一行尾巴上写什么」。默认值照抄 `TimetableSettings` 的构造默认值
 * （`timetable_settings.dart:825-849`）。
 */
data class LiveDisplayInput(
    val showCourseName: Boolean = true, // :825
    val showLocation: Boolean = true, // :826
    val showCountdown: Boolean = true, // :827
    val showStageText: Boolean = true, // :829
    val useShortName: Boolean = true, // :835
    val enableMiuiIslandLabelImage: Boolean = false, // :839
)

/**
 * 入口页的两行读数（`settings_live.dart:59-68`）。
 *
 * [duringEndFollowBeforeClass] 默认 true（`timetable_settings.dart:847`），
 * 此时「课中与下课」的摘要与上课前那份无关，直接写「跟随上课前提醒」。
 */
data class LivePageData(
    val beforeClass: LiveDisplayInput = LiveDisplayInput(),
    val duringEnd: LiveDisplayInput = LiveDisplayInput(),
    val duringEndFollowBeforeClass: Boolean = true,
)
