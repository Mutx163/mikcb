package com.mutx163.qingyu.pages.settings

/**
 * 天气设置页（`lib/screens/settings/settings_weather.dart:30-233`）结构模型。
 *
 * ## 为什么「数据来源」排在第一个区块
 *
 * Dart :67-70 的注释说清了：没有城市就一条天气都取不到，先把「数据从哪来」
 * 这件事办完，后面那些显示开关才有意义。它管的不是元信息，而是这个功能的
 * **前置条件**。
 *
 * ## 一条容易做反的联动
 *
 * 总开关关掉时，**下面五个显示开关是禁用而不是隐藏**（:39-41）：
 * 「用户能看到原来还有这些选项，也知道为什么点不动」。
 * 所以模型里这些行恒存在，只是 `enabled = false`。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: weatherSettingsTitle)`（:63） | `titleKey/title` | `basic.TopAppBar` |
 * | `HyperosSectionLabel(weatherSectionSourceTitle)`（:71） | `SettingsLabel` | preference category |
 * | `MiuixSettingsPreference(使用当前位置)`（:76-96） | `weather.useCurrentLocation` | `MiuixArrowPreference` |
 * | `MiuixSettingsPreference(城市)`（:97-120） | `weather.city` | 同上 |
 * | `MiuixSettingsPreference(上次更新失败)`（:123-137） | `weather.retry` | 同上（仅失败态） |
 * | `HyperosSectionDescription(weatherAttribution)`（:141） | `SettingsDescription` | 整宽脚注（CC BY 4.0 条款） |
 * | `HyperosSectionLabel(weatherSectionDisplayTitle)`（:144） | `SettingsLabel` | preference category |
 * | `HyperosSwitchTile`×4（:147-187） | `weather.enable` / `showOnDayCard` / `showOnWeekCard` / `showOnSheet` | `MiuixSwitchPreference` |
 * | `HyperosSectionDescription(weatherCoverageNote)`（:192） | `SettingsDescription` | 整宽脚注 |
 * | `HyperosSectionLabel(weatherSectionContentTitle)`（:195） | `SettingsLabel` | preference category |
 * | `HyperosSwitchTile`×3（:198-226） | `weather.showPhenomenon` / `showTemperature` / `showProbability` | `MiuixSwitchPreference` |
 *
 * ## 不写进模型的三件事
 *
 * 1. **六个开关的写盘契约**（:46-59）：失败要弹提示，不能静默吞掉——
 *    原先 `unawaited(...)` 让失败既不提示也不回滚，重启后全部回到旧值；
 * 2. **开天气时主动定位一次**（:243-254）：只在「打开 + 没有城市」这一个组合下触发；
 * 3. 定位结果的两种提示（:258-277）：失败按 `WeatherLocationFailureLocalizer`
 *    翻译；按 IP 估算的位置要如实标注。
 */
object SettingsWeatherPage {

    const val ID = "settings-weather"

    const val ID_TITLE_KEY = "weatherSettingsTitle"

    /** 城市选择页的具名路由（:115-118）。 */
    const val ROUTE_CITY_PICKER = "/settings/weather/city"

    /**
     * 三枚行首徽章的底色，逐字取发布版 `HyperosIconColors`
     * （`lib/ui/hyperos/hyperos_tokens.dart:125-135`）。
     *
     * 2026-11-10 美学盘点的校正：此前这页写的是另一套近似色
     * （`#2F7CF6` / `#12B5A5` / `#F5A623`），其中 refresh 那枚直接错成了
     * 官方色板里的**黄**（`HyperosIconColors.yellow`）而不是橙——屏上「重试」
     * 的徽章和其余设置页的橙徽章（如 `alarm`）不同色，属于看得出的偏差。
     * 设置族其余页的徽章色都按这套官方值写（`grep SettingsRowIcon` 可验），
     * 所以这里只把本页三处改回官方值，不另立新色。
     *
     * 为什么用常量而不是就地写字符串：Dart 侧三处引用的是同一族常量
     * （`_settingsIconBadge(..., HyperosIconColors.blue/teal/orange)`），
     * 命名保留「蓝 / 青 / 橙」的语义，改色时不会在三个字面量之间漏改一个。
     */
    const val WEATHER_ICON_BLUE = "#3482FF"
    const val WEATHER_ICON_TEAL = "#14B8A6"
    const val WEATHER_ICON_ORANGE = "#FF6B00"

    fun spec(
        state: SettingsPageState,
        data: WeatherPageData = WeatherPageData(),
    ): SettingsPageSpec {
        val s = SettingsStringsExt3
        return SettingsPageSpec(
            id = ID,
            titleKey = s.weatherSettingsTitle.key,
            title = s.weatherSettingsTitle.text,
            nodes = listOf(
                // ── 区块 1：数据来源（:70-141）
                SettingsGap("weather.gap.source"),
                SettingsLabel(
                    id = "weather.section.source",
                    textKey = s.weatherSectionSourceTitle.key,
                    text = s.weatherSectionSourceTitle.text,
                ),
                SettingsGroup(
                    id = "weather.group.source",
                    children = sourceRows(data),
                ),
                SettingsDescription(
                    id = "weather.desc.attribution",
                    textKey = s.weatherAttribution.key,
                    text = s.weatherAttribution.text,
                ),

                // ── 区块 2：显示（:143-192）
                SettingsGap("weather.gap.display"),
                SettingsLabel(
                    id = "weather.section.display",
                    textKey = s.weatherSectionDisplayTitle.key,
                    text = s.weatherSectionDisplayTitle.text,
                ),
                SettingsGroup(
                    id = "weather.group.display",
                    children = displayRows(data),
                ),
                SettingsDescription(
                    id = "weather.desc.coverage",
                    textKey = s.weatherCoverageNote.key,
                    text = s.weatherCoverageNote.text,
                ),

                // ── 区块 3：显示内容（:194-228）
                SettingsGap("weather.gap.content"),
                SettingsLabel(
                    id = "weather.section.content",
                    textKey = s.weatherSectionContentTitle.key,
                    text = s.weatherSectionContentTitle.text,
                ),
                SettingsGroup(
                    id = "weather.group.content",
                    children = contentRows(data),
                ),
            ),
        )
    }

    /**
     * 数据来源组（:72-138）。
     *
     * 定位行在最前（:74-75 注释：它比手动搜索更常用），重试行**只在取数失败时**
     * 出现（:123 `if (weather?.status == WeatherStatus.failed)`）。
     */
    private fun sourceRows(data: WeatherPageData): List<SettingsNode> {
        val s = SettingsStringsExt3
        val rows = mutableListOf<SettingsNode>()

        rows += settingsRow(
            id = "weather.useCurrentLocation",
            component = MiuixRowComponent.ARROW,
            title = s.weatherUseCurrentLocation,
            icon = SettingsRowIcon("pin", WEATHER_ICON_BLUE),
            // :93 定位中、或 provider 缺席 → onClick 为 null
            enabled = data.providerAvailable && !data.locating,
            // :72-78 定位中在行尾给一颗 16dp 转圈——只有禁用没有转圈的话，
            // 用户点一下只看到「行变灰了」，会以为按坏了。
            trailingSpinner = data.locating,
            action = SettingsAction.RUN_NOW,
        )

        // :104-109 `weather?.location?.displayName ?? weatherCityNotSet`
        val city = data.cityDisplayName
        rows += settingsRow(
            id = "weather.city",
            component = MiuixRowComponent.ARROW,
            title = s.weatherCityLabel,
            icon = SettingsRowIcon("location", WEATHER_ICON_TEAL),
            // 有城市名时它是**运行时数据**（Dart `String?`），不来自 ARB：
            // 这里必须是 null 而不是空串——空串会被当成「有个键但键名是空的」，
            // 语义与 `null`（没有键）不是一回事，测试按 null 钉住了它。
            valueKey = if (city == null) s.weatherCityNotSet.key else null,
            value = city ?: s.weatherCityNotSet.text,
            // :111 `onClick: weather == null ? null : …`
            enabled = data.providerAvailable,
            action = SettingsAction.NAVIGATE,
            actionTarget = ROUTE_CITY_PICKER,
        )

        if (data.status == WeatherStatus.FAILED) {
            rows += settingsRow(
                id = "weather.retry",
                component = MiuixRowComponent.ARROW,
                title = s.weatherStatusFailed,
                icon = SettingsRowIcon("refresh", WEATHER_ICON_ORANGE),
                valueKey = s.weatherRetryAction.key,
                value = s.weatherRetryAction.text,
                action = SettingsAction.RUN_NOW,
            )
        }
        return rows
    }

    /**
     * 显示组四个开关（:145-188）。
     *
     * 总开关自己只看 provider 在不在（:151），下面三个还看**总开关是否开着**
     * （:161 / :174 / :183）——所以总开关关着时它自己仍可点，其余三个禁用。
     */
    private fun displayRows(data: WeatherPageData): List<SettingsNode> {
        val s = SettingsStringsExt3
        return listOf(
            settingsRow(
                id = "weather.enable",
                component = MiuixRowComponent.SWITCH,
                title = s.weatherEnableTitle,
                subtitle = s.weatherEnableSubtitle,
                switchValue = data.enabled,
                // :151 `onChanged: weather == null ? null : …`
                enabled = data.providerAvailable,
                action = SettingsAction.WRITE_SETTING,
            ),
            settingsRow(
                id = "weather.showOnDayCard",
                component = MiuixRowComponent.SWITCH,
                title = s.weatherShowOnDayCardTitle,
                switchValue = data.showOnDayCard,
                enabled = data.enabled,
                action = SettingsAction.WRITE_SETTING,
            ),
            settingsRow(
                id = "weather.showOnWeekCard",
                component = MiuixRowComponent.SWITCH,
                title = s.weatherShowOnWeekCardTitle,
                // :172 周网格格子窄，只放得下一项——这句话挂在行上而不是堆进脚注
                subtitle = s.weatherShowOnWeekCardSubtitle,
                switchValue = data.showOnWeekCard,
                enabled = data.enabled,
                action = SettingsAction.WRITE_SETTING,
            ),
            settingsRow(
                id = "weather.showOnSheet",
                component = MiuixRowComponent.SWITCH,
                title = s.weatherShowOnSheetTitle,
                switchValue = data.showOnSheet,
                enabled = data.enabled,
                action = SettingsAction.WRITE_SETTING,
            ),
        )
    }

    /** 显示内容组三个开关（:196-228）。 */
    private fun contentRows(data: WeatherPageData): List<SettingsNode> {
        val s = SettingsStringsExt3
        return listOf(
            settingsRow(
                id = "weather.showPhenomenon",
                component = MiuixRowComponent.SWITCH,
                title = s.weatherShowPhenomenonTitle,
                subtitle = s.weatherShowPhenomenonSubtitle,
                switchValue = data.showPhenomenon,
                enabled = data.enabled,
                action = SettingsAction.WRITE_SETTING,
            ),
            settingsRow(
                id = "weather.showTemperature",
                component = MiuixRowComponent.SWITCH,
                title = s.weatherShowTemperatureTitle,
                switchValue = data.showTemperature,
                enabled = data.enabled,
                action = SettingsAction.WRITE_SETTING,
            ),
            settingsRow(
                id = "weather.showProbability",
                component = MiuixRowComponent.SWITCH,
                title = s.weatherShowProbabilityTitle,
                subtitle = s.weatherShowProbabilitySubtitle,
                switchValue = data.showProbability,
                enabled = data.enabled,
                action = SettingsAction.WRITE_SETTING,
            ),
        )
    }
}

/**
 * 天气取数状态（`WeatherProvider.status` 的镜像）。
 *
 * 只有 [FAILED] 会改变本页结构（多出重试行），其余三态屏上完全一样。
 */
enum class WeatherStatus {
    IDLE,
    LOADING,
    LOADED,
    FAILED,
}

/**
 * 天气页的一份输入。
 *
 * 默认值分两类：
 * - **设备级天气开关**（[enabled] / [status] / [locating] / [cityDisplayName]）
 *   来自 `WeatherProvider`，默认关、未定位；
 * - **课表侧显示偏好**（后六个）照抄 `timetable_settings.dart:774-779` 的构造默认值。
 */
data class WeatherPageData(
    /** `weather?.enabled ?? false`（:41）。 */
    val enabled: Boolean = false,
    /** `WeatherProvider` 是否存在（Dart 侧可空，null = 天气功能整体不可用）。 */
    val providerAvailable: Boolean = true,
    val status: WeatherStatus = WeatherStatus.IDLE,
    /** `weather.isLocating`：定位中整行禁用（:93）。 */
    val locating: Boolean = false,
    /** `weather.location?.displayName`；null = 未设置城市。 */
    val cityDisplayName: String? = null,
    // timetable_settings.dart:774-776
    val showOnDayCard: Boolean = true,
    val showOnWeekCard: Boolean = true,
    val showOnSheet: Boolean = true,
    // timetable_settings.dart:777-779
    val showPhenomenon: Boolean = true,
    val showTemperature: Boolean = true,
    val showProbability: Boolean = false,
)
