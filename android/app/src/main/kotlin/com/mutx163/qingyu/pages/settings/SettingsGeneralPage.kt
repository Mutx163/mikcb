package com.mutx163.qingyu.pages.settings

import java.util.Locale

/**
 * 通用设置页（`lib/screens/settings/settings_general.dart`）结构模型。
 *
 * ## 逐项对照（Flutter → 本模型）
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: generalSettingsTitle)`（:50-52） | `titleKey/title` | `basic.TopAppBar` |
 * | `HyperosListGroup`（:56） | `SettingsGroup("general.main")` | `basic.Card` |
 * | ~~`HyperosSelectTile`（:58-66）~~ | ~~`general.language`~~（2026-11-05 起隐藏，见下） | — |
 * | `HyperosSliderTile`（:67-81） | `general.transitionSpeed` | `MiuixSliderPreference` |
 * | `HyperosSwitchTile`（:82-89） | `general.haptics` | `MiuixSwitchPreference` |
 * | ~~`HyperosSwitchTile`（:90-99）~~ | ~~`general.homePullImport`~~（2026-11-05 起隐藏，见下） | — |
 * | `HyperosSectionGap`（:102） | `SettingsGap("general.gap.autoRefresh")` | `SizedBox(12dp)` |
 * | `CourseAutoRefreshSettingsSection`（:103） | `general.autoRefresh.*` | 见下 |
 * | `HyperosSectionLabel`（widgets/course_auto_refresh_settings.dart:104） | `SettingsLabel` | preference category 文案 |
 * | `HyperosSwitchTile`（:107-114） | `general.autoRefresh.switch` | `MiuixSwitchPreference` |
 * | `HyperosSelectTile`（:116-130） | `general.autoRefresh.mode` | `MiuixOverlayDropdownPreference` |
 * | `HyperosSliderTile`（:131-147） | `general.autoRefresh.interval` | `MiuixSliderPreference` |
 * | `HyperosNavTile`（:148-153） | `general.autoRefresh.dailyTime` | `MiuixArrowPreference` |
 * | `HyperosNavTile`（:154-158） | `general.autoRefresh.tryNow` | `MiuixArrowPreference` |
 * | `HyperosSectionDescription`（:162） | `SettingsDescription` | 整宽脚注（不受 11/17 口径约束） |
 *
 * ## 暂时隐藏的一行：`general.homePullImport`
 *
 * 「首页下拉快捷导入」开关**已从渲染里去掉**（2026-11-05）：它承诺「在首页下拉时自动执行教务
 * 快捷导入」，而后台回放引擎（`WarehouseBackgroundImportEngine`）还没落地、首页也没有读
 * `homePullQuickImportEnabled` 的地方 —— 用户照说明做一定落空，等于一个假开关。
 * 按「不许留点了必无效的入口」口径先隐藏；模型字段与写盘逻辑保留，引擎接上后这一行原样回来。
 * `SettingsGeneralPageTest` 里有一条 `下拉快捷导入开关暂时隐藏` 钉住这条，别在接引擎之前悄悄加回。
 *
 * ## 暂时隐藏的一行：`general.language`
 *
 * 「语言选择」下拉**已从渲染里去掉**（2026-11-05）：它写 `appLocaleTag`，但 composeP1 的界面文字
 * 没有外语版（`.zh` 引用上千处、`.en` 零处），生效点自己也注明「不会把界面文字换成外语」——
 * 副标题「可跟随系统，或手动切换到已适配语言」在页面上写了一句不成立的话，而且它给出 6 个选项、
 * 没有一个真的换掉界面文字。按「不许留点了必无效的入口」口径先隐藏（比下拉导入那个开关更该藏：
 * 那个是「还没实现」，这个是「给了选项但每个都没效果」）。
 * 模型字段 `appLocaleTag`、写盘分支 `SettingsActionDispatcher.ROW_LOCALE`、`SettingsStrings` 键
 * 全部保留，用户旧值不丢；等 locale 真切换落地（界面文字有外语版）后这一行原样回来。
 * `SettingsGeneralPageTest` 里有一条 `语言行暂时隐藏` 钉住这条。
 *
 * ## 两条「不写进模型」的行为，接线层必须照做
 *
 * 1. 每行改动后走 `_updateDraft` → `_enqueuePersist`（:109-155），落盘失败要提示
 *    并把草稿拉回真值（`settings_shared.dart:45-59`）——这是行为，不是结构；
 * 2. 转场速度改动要**先**调 `HyperosNavigation.applyUserTransitionSpeed`（:75），
 *    再做防抖落盘（250ms，:115-119）。模型只标了 `WRITE_SETTING`。
 */
object SettingsGeneralPage {

    const val ID = "settings-general"

    /** `HyperosTokens`/Dart 常量的镜像：转场速度上下限与档数（settings_general.dart:70-72）。 */
    private const val TRANSITION_MIN = 0.5
    private const val TRANSITION_MAX = 2.5
    private const val TRANSITION_DIVISIONS = 20

    fun spec(state: SettingsPageState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()

        nodes += SettingsGroup(
            id = "general.main",
            children = listOf(
                // 2026-11-05 起**暂时隐藏**「语言选择」这一行（`general.language`）。
                // 它写 `appLocaleTag`，但 composeP1 的界面文字没有外语版（`.zh` 引用上千处、`.en` 零处），
                // 生效点自己也注明「不会把界面文字换成外语」——副标题写着「可跟随系统，或手动切换到
                // 已适配语言」，等于在页面上写一句不成立的话；而且它提供 6 个选项、没有一个真的换掉界面语言。
                // 按「不许留点了必无效的入口」口径先藏起来；**模型字段 `appLocaleTag`、写盘分支
                // `SettingsActionDispatcher.ROW_LOCALE`、`SettingsStrings` 键全部保留**，
                // 用户旧值不丢。等 locale 真切换落地（界面文字有外语版）后，把这段
                // `settingsRow(id = "general.language", …)` 原样加回来。
                settingsRow(
                    id = "general.transitionSpeed",
                    component = MiuixRowComponent.SLIDER,
                    title = SettingsStrings.pageTransitionSpeedTitle,
                    value = "${format1(state.pageTransitionSpeed)}×",
                    slider = SettingsSliderSpec(
                        min = TRANSITION_MIN,
                        max = TRANSITION_MAX,
                        divisions = TRANSITION_DIVISIONS,
                        defaultValue = 1.0,
                    ),
                    sliderValue = state.pageTransitionSpeed,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "general.haptics",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStrings.layoutEnableHapticsTitle,
                    subtitle = SettingsStrings.layoutEnableHapticsSubtitle,
                    switchValue = state.enableHaptics,
                    action = SettingsAction.WRITE_SETTING,
                ),
                // 2026-11-05 起**暂时隐藏**「首页下拉快捷导入」这一行（`general.homePullImport`）。
                // 它承诺「在首页下拉时自动执行教务快捷导入」，但后台回放引擎
                // （`WarehouseBackgroundImportEngine`）还没落地，首页也没有任何一处读
                // `homePullQuickImportEnabled` —— 用户照说明做一定落空。
                // 按「不许留点了必无效的入口」口径先藏起来；**模型字段与写盘逻辑原样保留**
                // （`TimetableSettingsModel.homePullQuickImportEnabled` +
                // `SettingsActionDispatcher.ROW_HOME_PULL_IMPORT`），引擎接上后把这段
                // `settingsRow(id = "general.homePullImport", …)` 原样加回来即可，旧设置值不会丢。
            ),
        )

        val auto = state.autoRefresh
        if (auto != null) {
            nodes += SettingsGap("general.gap.autoRefresh")
            nodes += SettingsLabel(
                id = "general.autoRefresh.label",
                textKey = SettingsStrings.courseAutoRefreshSectionTitle.key,
                text = SettingsStrings.courseAutoRefreshSectionTitle.zh,
            )
            nodes += SettingsGroup(
                id = "general.autoRefresh",
                children = autoRefreshRows(auto),
            )
            val summary = autoRefreshSummary(auto)
            nodes += SettingsDescription(
                id = "general.autoRefresh.summary",
                textKey = autoRefreshSummaryKey(auto),
                text = summary,
            )
        }

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStrings.generalSettingsTitle.key,
            title = SettingsStrings.generalSettingsTitle.zh,
            nodes = nodes,
        )
    }

    /**
     * 自动更新组的行（`widgets/course_auto_refresh_settings.dart:105-161`）。
     *
     * 关闭时只剩开关行；开启后按档位插入间隔滑杆或定时行（互斥）。
     */
    private fun autoRefreshRows(auto: AutoRefreshState): List<SettingsNode> {
        val rows = mutableListOf<SettingsNode>()
        rows += settingsRow(
            id = "general.autoRefresh.switch",
            component = MiuixRowComponent.SWITCH,
            title = SettingsStrings.courseAutoRefreshTitle,
            subtitle = SettingsStrings.courseAutoRefreshSubtitle,
            switchValue = auto.enabled,
            action = SettingsAction.WRITE_SETTING,
        )
        if (!auto.enabled) return rows

        rows += settingsRow(
            id = "general.autoRefresh.mode",
            component = MiuixRowComponent.DROPDOWN,
            title = SettingsStrings.courseAutoRefreshModeLabel,
            options = CourseAutoRefreshMode.entries.map { option(it.value, it.label) },
            selectedOptionId = auto.mode.value,
            action = SettingsAction.WRITE_SETTING,
        )
        if (auto.mode == CourseAutoRefreshMode.INTERVAL_HOURS) {
            rows += settingsRow(
                id = "general.autoRefresh.interval",
                component = MiuixRowComponent.SLIDER,
                title = SettingsStrings.courseAutoRefreshIntervalTitle,
                value = "${auto.intervalHours}h",
                slider = SettingsSliderSpec(
                    min = MIN_INTERVAL_HOURS.toDouble(),
                    max = MAX_INTERVAL_HOURS.toDouble(),
                    // 1..168 小时逐档可调；档数跟着上下限走，不写死（:137-140）
                    divisions = MAX_INTERVAL_HOURS - MIN_INTERVAL_HOURS,
                    defaultValue = DEFAULT_INTERVAL_HOURS.toDouble(),
                ),
                sliderValue = auto.intervalHours.toDouble(),
                action = SettingsAction.WRITE_SETTING,
            )
        }
        if (auto.mode == CourseAutoRefreshMode.DAILY_AT) {
            rows += settingsRow(
                id = "general.autoRefresh.dailyTime",
                component = MiuixRowComponent.ARROW,
                title = SettingsStrings.courseAutoRefreshDailyTimeTitle,
                value = formatMinuteOfDay(auto.dailyMinuteOfDay),
                action = SettingsAction.SHEET,
            )
        }
        rows += settingsRow(
            id = "general.autoRefresh.tryNow",
            component = MiuixRowComponent.ARROW,
            title = SettingsStrings.courseAutoRefreshTryNowTitle,
            subtitle = SettingsStrings.courseAutoRefreshTryNowSubtitle,
            action = SettingsAction.RUN_NOW,
        )
        return rows
    }

    /**
     * 底部整宽灰字（`course_auto_refresh_settings.dart:226-240`）。
     *
     * 关闭 → 副标题那句；从没成功过 → 「还没成功更新过」；否则「上次 X」，
     * 有下次计划再拼 ` · 下次约 Y`。
     */
    fun autoRefreshSummary(auto: AutoRefreshState): String {
        if (!auto.enabled) return SettingsStrings.courseAutoRefreshSubtitle.zh
        val last = auto.lastSuccessLabel
            ?: return SettingsStrings.courseAutoRefreshSummaryNever.zh
        val lastLine = SettingsStrings.courseAutoRefreshSummaryLast.filled("time", last)
        val next = auto.nextRunLabel ?: return lastLine
        return "$lastLine · ${SettingsStrings.courseAutoRefreshSummaryNext.filled("time", next)}"
    }

    /** 灰字主键（拼接第二段时以「上次」那条为主键，见 [autoRefreshSummary]）。 */
    private fun autoRefreshSummaryKey(auto: AutoRefreshState): String = when {
        !auto.enabled -> SettingsStrings.courseAutoRefreshSubtitle.key
        auto.lastSuccessLabel == null -> SettingsStrings.courseAutoRefreshSummaryNever.key
        else -> SettingsStrings.courseAutoRefreshSummaryLast.key
    }

    /**
     * 语言下拉的选项表（`settings_shared.dart:111-125` 的 `buildLocaleMenuMap`）。
     *
     * 第一项是「跟随系统」（空 tag），其余按 `AppLocalizations.supportedLocales`
     * 的声明顺序（`lib/l10n/app_localizations.dart:98-105`：en / ja / ko / zh /
     * zh_HK / zh_TW），以各语言的自称显示（`locale_utils.dart:11-31` 的
     * `nativeNameFor`，**不来自 ARB**，故这些项的 `labelKey` 为 null）。
     */
    fun localeOptions(): List<SettingsOption> = listOf(
        option("", SettingsStrings.languageModeSystem),
        nativeOption("en", "English"),
        nativeOption("ja", "日本語"),
        nativeOption("ko", "한국어"),
        nativeOption("zh", "简体中文"),
        nativeOption("zh_HK", "繁體中文（香港）"),
        nativeOption("zh_TW", "繁體中文（台灣）"),
    )

    /**
     * locale 标签归一（`settings_shared.dart:84-105` 的
     * `normalizeLocaleTagForDropdown`）。
     *
     * 口径逐字搬运：去空白 → `-` 换 `_` → 命中支持表就返回；否则取第一段语言码
     * 再试一次（所以 `en_US_POSIX` 会落到 `en`）；都不命中返回空串（= 跟随系统）。
     */
    fun normalizeLocaleTag(tag: String): String {
        val normalized = tag.trim()
        if (normalized.isEmpty()) return ""
        val canonical = normalized.replace('-', '_')
        if (SUPPORTED_TAGS.contains(canonical)) return canonical
        val languageCode = canonical.substringBefore('_')
        if (SUPPORTED_TAGS.contains(languageCode)) return languageCode
        return ""
    }

    /**
     * 短日期（`course_auto_refresh_settings.dart:246-252`）：月**不**补零、日补零，
     * 「9-21 07:30」。刻意不走本地化格式：这行每次重建都要输出同一串字符。
     */
    fun shortDateTime(month: Int, day: Int, hour: Int, minute: Int): String =
        "%d-%02d %02d:%02d".format(Locale.ROOT, month, day, hour, minute)

    /** 分钟数 → `07:30`（`course_auto_refresh_settings.dart:216-220`）。 */
    fun formatMinuteOfDay(minuteOfDay: Int): String {
        val hour = minuteOfDay / 60
        val minute = minuteOfDay % 60
        return "%02d:%02d".format(Locale.ROOT, hour, minute)
    }

    /** `kCourseAutoRefreshMinIntervalHours`（course_auto_refresh_decision.dart:47）。 */
    const val MIN_INTERVAL_HOURS = 1

    /** `kCourseAutoRefreshMaxIntervalHours`（同文件 :48）。 */
    const val MAX_INTERVAL_HOURS = 168

    /** `kCourseAutoRefreshDefaultIntervalHours`（同文件 :49）。 */
    const val DEFAULT_INTERVAL_HOURS = 24

    /** `AppLocalizations.supportedLocales` 的 tag 集合（app_localizations.dart:98-105）。 */
    private val SUPPORTED_TAGS = setOf("en", "ja", "ko", "zh", "zh_HK", "zh_TW")

    /** Dart `toStringAsFixed(1)` 的等价物（定点一位小数，Locale 无关）。 */
    internal fun format1(value: Double): String = "%.1f".format(Locale.ROOT, value)
}
