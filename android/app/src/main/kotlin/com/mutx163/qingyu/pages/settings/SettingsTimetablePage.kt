package com.mutx163.qingyu.pages.settings

import java.util.Locale

/**
 * 设置首页 / 课表设置 hub（`lib/screens/timetable_settings_screen.dart`，1156 行）
 * 结构模型。
 *
 * 同一个 Dart 文件里有两页，本对象各给一个 `spec`：
 *
 * | Dart 类 | 本模型 | 说明 |
 * |---|---|---|
 * | `TimetableSettingsScreen`（:68-673） | [spec] | 设置 hub，8 个 section |
 * | `_SemesterSettingsScreen`（:679-863） | [semesterSpec] | 学期设置子页，1 组 3 行 |
 *
 * ## 逐项对照（设置 hub）
 *
 * | Flutter | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: settingsTitle)`（:321-325） | `titleKey/title` | `basic.TopAppBar` |
 * | `HyperosSummaryCard`（:379-397） | `timetable.summary` | `basic.Card` + 箭头 |
 * | `HyperosSectionLabel(课表)`（:404） | `timetable.section.timetable.label` | preference category |
 * | `MiuixSettingsPreference`×3（:407-455） | `timetable.profiles/timeScheme/holiday` | `MiuixArrowPreference` |
 * | `HyperosSectionLabel(课表显示)`（:466） | `timetable.section.display.label` | preference category |
 * | `MiuixSettingsPreference`×3（:469-498） | `timetable.courseCard/pageSettings/weather` | `MiuixArrowPreference` |
 * | `HyperosSectionLabel(提醒与桌面)`（:513） | `timetable.section.reminder.label` | preference category |
 * | `_LiveEntryTile` + 小组件（:516-524） | `timetable.live/homeWidget` | `MiuixArrowPreference` |
 * | `HyperosSectionLabel(应用)`（:537） | `timetable.section.app.label` | preference category |
 * | `MiuixSettingsPreference`×3（:540-563） | `timetable.appearance/homeNavigation/general` | `MiuixArrowPreference` |
 * | `HyperosSectionLabel(数据与共享)`（:574） | `timetable.section.dataShare.label` | preference category |
 * | `MiuixSettingsPreference`×4（:577-609） | `timetable.*` | `MiuixArrowPreference` |
 * | `HyperosSectionLabel(关于)`（:620） | `timetable.section.about.label` | preference category |
 * | `MiuixSettingsPreference`×3（:623-652） | `timetable.*` | `MiuixArrowPreference` |
 * | `_SettingsDeveloperListGroup`（:658-670） | `timetable.section.developer` | preference category + 组 |
 *
 * ## 五个「行尾取值」是本页的核心逻辑，各有一个纯函数
 *
 * | 行 | Dart | 模型 |
 * |---|---|---|
 * | 时间模板 | :432-436 | 未选择 → `timeSchemeEntryNotSelected` |
 * | 节假日 | :447-451 | 开关 → 已开启/已关闭 |
 * | 天气 | :493 | 城市名 or `weatherCityNotSet` |
 * | 超级岛 | :919-926 | [LiveTrailing]：**权限缺口优先于开关状态** |
 * | 云同步 | :998-1007 | [CloudSyncTrailing]：四态，配置未读完时**留白** |
 *
 * ## 未纳入本模型（都是行为，不是结构）
 *
 * 1. 每一项的 `HyperosNavigation.push` 目标已在模型里记成 `actionTarget`，
 *    真正的跳转由接线层做；
 * 2. 三个入口的**异步状态刷新**：超级岛权限（`_LiveEntryTileState`，:878-940）、
 *    云同步配置与 coordinator 状态（`_CloudSyncEntryTileState`，:958-1029）、
 *    开发者工具的诊断构建判定（`MemoryStatsService.isDiagnosticsBuild()`，:1056-1058）；
 *    本模型把它们收成本页输入 state 的三个字段；
 * 3. 学期设置里的三个弹层（日期选择 / 周数选择）与两次落盘后的提示（:758-862）。
 */
object SettingsTimetablePage {

    const val ID = "settings-timetable"

    /** 学期设置子页的 spec id。 */
    const val SEMESTER_ID = "settings-timetable-semester"

    /** 全部入口路由（Dart 侧 `RouteSettings(name: ...)` 常量，:92-266）。 */
    const val ROUTE_SEMESTER = "/settings/semester"
    const val ROUTE_PROFILES = "/profiles"
    const val ROUTE_TIME_SCHEMES = "/settings/time-schemes"
    const val ROUTE_HOLIDAY = "/settings/holiday"
    const val ROUTE_COURSE_CARD = "/settings/course-card"
    const val ROUTE_TIMETABLE_PAGE = "/settings/timetable-page"
    const val ROUTE_WEATHER = "/settings/weather"
    const val ROUTE_LIVE = "/settings/live"
    const val ROUTE_HOME_WIDGET = "/settings/home-widget"
    const val ROUTE_APPEARANCE = "/settings/appearance"
    const val ROUTE_HOME_NAVIGATION = "/settings/home-navigation"
    const val ROUTE_GENERAL = "/settings/general"
    const val ROUTE_DATA_TRANSFER = "/settings/data-transfer"
    const val ROUTE_CLOUD_SYNC = "/settings/cloud-sync"
    const val ROUTE_LAN_EDIT = "/settings/lan-edit"
    const val ROUTE_COUPLE_TIMETABLE = "/settings/couple-timetable"
    const val ROUTE_ABOUT = "/about"
    const val ROUTE_USER_GUIDE = "/user-guide"
    const val ROUTE_DIAGNOSTICS = "/settings/diagnostics"
    const val ROUTE_MEMORY_STATS = "/settings/memory-stats"
    const val ROUTE_LIVE_FIXTURE = "/settings/live-testing-fixture"
    const val ROUTE_HYPEROS_SHOWCASE = "/settings/hyperos-showcase"
    const val ROUTE_MIUIX_SHOWCASE = "/settings/miuix-showcase"

    // ------------------------------------------------------------------ 设置 hub

    fun spec(state: SettingsTimetableState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()

        // 0 — 学期摘要卡（无前导空档）
        nodes += summaryRow(state)

        // 1 — 课表
        nodes += sectionHeader("timetable", SettingsStringsExt2.settingsTimetableSectionTitle)
        nodes += SettingsGroup(
            id = "timetable.section.timetable",
            children = listOf(
                settingsRow(
                    id = "timetable.profiles",
                    icon = SettingsRowIcon("layers", "#3482FF"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.timetableManagement,
                    // 没有激活课表时不给行尾（:413-421）；名字是用户数据，键留空
                    details = state.activeProfileName?.let { ArbText(NON_ARB_TEXT, it) },
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_PROFILES,
                ),
                settingsRow(
                    id = "timetable.timeScheme",
                    icon = SettingsRowIcon("timer", "#14B8A6"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.timeSchemeEntryTitle,
                    // 未选择时行尾是 ARB 文案，选了就是模板名（用户数据，键留空）
                    details = state.activeTimeSchemeName?.let { ArbText(NON_ARB_TEXT, it) }
                        ?: SettingsStringsExt2.timeSchemeEntryNotSelected,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_TIME_SCHEMES,
                ),
                settingsRow(
                    id = "timetable.holiday",
                    icon = SettingsRowIcon("favorites", "#F5A623"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.holidaySettingsEntryTitle,
                    details = if (state.holidayMarkingEnabled) {
                        SettingsStringsExt2.liveIslandLabelEntryEnabled
                    } else {
                        SettingsStringsExt2.liveIslandLabelEntryDisabled
                    },
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_HOLIDAY,
                ),
            ),
        )

        // 2 — 课表显示
        nodes += sectionHeader("timetableDisplay", SettingsStringsExt2.settingsDisplayAppearanceSectionTitle)
        nodes += SettingsGroup(
            id = "timetable.section.display",
            children = listOf(
                settingsRow(
                    id = "timetable.courseCard",
                    icon = SettingsRowIcon("gridView", "#8B5CF6"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.courseCardSettingsTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_COURSE_CARD,
                ),
                settingsRow(
                    id = "timetable.pageSettings",
                    icon = SettingsRowIcon("months", "#FF6B00"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.timetablePageSettingsTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_TIMETABLE_PAGE,
                ),
                settingsRow(
                    id = "timetable.weather",
                    icon = SettingsRowIcon("cloudFill", "#3482FF"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.weatherSettingsEntryTitle,
                    // 城市名是用户数据（键留空），未设置时给 ARB 文案
                    details = state.weatherCityName?.let { ArbText(NON_ARB_TEXT, it) }
                        ?: SettingsStringsExt2.weatherCityNotSet,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_WEATHER,
                ),
            ),
        )

        // 3 — 提醒与桌面
        nodes += sectionHeader("timetableReminder", SettingsStringsExt2.settingsReminderDesktopSectionTitle)
        nodes += SettingsGroup(
            id = "timetable.section.reminder",
            children = listOf(
                settingsRow(
                    id = "timetable.live",
                    icon = SettingsRowIcon("alarm", "#FF6B00"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.liveSettingsTitle,
                    details = liveTrailingOf(
                        state.notificationPermissionGranted,
                        state.liveReminderEnabled,
                    ).text,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_LIVE,
                ),
                settingsRow(
                    id = "timetable.homeWidget",
                    icon = SettingsRowIcon("home", "#10C550"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.homeWidgetEntryTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_HOME_WIDGET,
                ),
            ),
        )

        // 4 — 应用
        nodes += sectionHeader("timetableApp", SettingsStringsExt2.settingsAppSectionTitle)
        nodes += SettingsGroup(
            id = "timetable.section.app",
            children = listOf(
                settingsRow(
                    id = "timetable.appearance",
                    icon = SettingsRowIcon("theme", "#3482FF"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.appearanceEntryTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_APPEARANCE,
                ),
                settingsRow(
                    id = "timetable.homeNavigation",
                    icon = SettingsRowIcon("sidebar", "#14B8A6"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.homeNavigationTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_HOME_NAVIGATION,
                ),
                settingsRow(
                    id = "timetable.general",
                    icon = SettingsRowIcon("tune", "#6366F1"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.generalSettingsTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_GENERAL,
                ),
            ),
        )

        // 5 — 数据与共享
        nodes += sectionHeader("timetableDataShare", SettingsStringsExt2.settingsDataShareSectionTitle)
        nodes += SettingsGroup(
            id = "timetable.section.dataShare",
            children = listOf(
                settingsRow(
                    id = "timetable.dataTransfer",
                    icon = SettingsRowIcon("convertFile", "#10C550"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.dataTransferEntryTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_DATA_TRANSFER,
                ),
                settingsRow(
                    id = "timetable.cloudSync",
                    icon = SettingsRowIcon("backup", "#06B6D4"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.cloudSyncEntryTitle,
                    // 云同步行尾是算出来的状态串（键来自枚举，见 CloudSyncTrailing）
                    details = cloudSyncTrailingOf(state).text,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_CLOUD_SYNC,
                ),
                settingsRow(
                    id = "timetable.lanEdit",
                    icon = SettingsRowIcon("link", "#6366F1"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.lanEditEntryTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_LAN_EDIT,
                ),
                settingsRow(
                    id = "timetable.coupleTimetable",
                    icon = SettingsRowIcon("favoritesFill", "#8B5CF6"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.coupleTimetableEntryTitle,
                    details = if (state.partnerBound) {
                        SettingsStringsExt2.coupleTimetableEntryBound
                    } else {
                        SettingsStringsExt2.coupleTimetableEntryUnboundLabel
                    },
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_COUPLE_TIMETABLE,
                ),
            ),
        )

        // 6 — 关于
        nodes += sectionHeader("timetableAbout", SettingsStringsExt2.settingsAboutSectionTitle)
        nodes += SettingsGroup(
            id = "timetable.section.about",
            children = listOf(
                settingsRow(
                    id = "timetable.about",
                    icon = SettingsRowIcon("info", "#3482FF"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.aboutEntryTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_ABOUT,
                ),
                settingsRow(
                    id = "timetable.userGuide",
                    icon = SettingsRowIcon("notes", "#06B6D4"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.userGuideEntryTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_USER_GUIDE,
                ),
                settingsRow(
                    id = "timetable.diagnostics",
                    icon = SettingsRowIcon("report", "#14B8A6"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.diagnosticsEntryTitle,
                    details = SettingsStringsExt2.diagnosticsEntrySubtitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_DIAGNOSTICS,
                ),
            ),
        )

        // 7 — 开发者工具 + 页尾空档
        appendDeveloperSection(nodes, state)
        nodes += SettingsGap("timetable.gap.bottom")

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStringsExt2.settingsTitle.key,
            title = SettingsStringsExt2.settingsTitle.text,
            nodes = nodes,
        )
    }

    // --------------------------------------------------------------- 学期设置子页

    /**
     * 学期设置子页（`:SemesterSettingsScreen`，:679-863）。
     *
     * 三行：开学日期 / 学期周数 / 同步当前周。最后一行在没设开学日期时**禁用**
     * 并把原因写进行尾（:736-747）——不是灰掉不给理由。
     */
    fun semesterSpec(state: SettingsTimetableState): SettingsPageSpec {
        val hasStart = state.semesterStartDate != null
        val nodes = mutableListOf<SettingsNode>()
        nodes += SettingsGroup(
            id = "timetable.semester.main",
            children = listOf(
                settingsRow(
                    id = "timetable.semester.startDate",
                    icon = SettingsRowIcon("months", "#3482FF"),
                    component = MiuixRowComponent.ARROW,
                    // 没设过 → 「设置开学日期」；设过 → 「开学日期」（:701-703）
                    title = if (hasStart) {
                        SettingsStringsExt2.semesterStartDateAction
                    } else {
                        SettingsStringsExt2.setSemesterStartDateAction
                    },
                    // 日期是算出来的取值（键留空），不来自 ARB
                    details = state.semesterStartDate?.let {
                        ArbText(NON_ARB_TEXT, formatDate(it.first, it.second, it.third))
                    },
                    action = SettingsAction.SHEET,
                ),
                settingsRow(
                    id = "timetable.semester.weekCount",
                    icon = SettingsRowIcon("weeks", "#6366F1"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.selectSemesterWeekCountTitle,
                    details = weekCountLabel(state.semesterWeekCount),
                    action = SettingsAction.SHEET,
                ),
                settingsRow(
                    id = "timetable.semester.syncWeek",
                    icon = SettingsRowIcon("refresh", "#14B8A6"),
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.syncCurrentWeekAction,
                    details = if (hasStart) null else SettingsStringsExt2.syncCurrentWeekNeedsStartDate,
                    // 没有开学日期时不可点（:745-747）
                    enabled = hasStart,
                    action = SettingsAction.RUN_NOW,
                ),
            ),
        )
        return SettingsPageSpec(
            id = SEMESTER_ID,
            titleKey = SettingsStringsExt2.settingsSemesterScreenTitle.key,
            title = SettingsStringsExt2.settingsSemesterScreenTitle.text,
            nodes = nodes,
        )
    }

    // ------------------------------------------------------------- 行尾取值逻辑

    /** 超级岛入口行尾的四态（`_LiveEntryTileState.build`，:919-926）。 */
    enum class LiveTrailing(val text: ArbText?) {
        /** 权限还没查到 → 留白，避免首帧闪错（:64-66 的思路同源）。 */
        HIDDEN(null),
        /** 权限缺失优先于开关状态：用户看到的第一件事是「为什么没生效」。 */
        PERMISSION_MISSING(SettingsStringsExt2.liveNotificationPermissionMissing),
        ENABLED(SettingsStringsExt2.liveIslandLabelEntryEnabled),
        DISABLED(SettingsStringsExt2.liveIslandLabelEntryDisabled),
    }

    /**
     * `_hasPermission == false ? 缺权限 : _hasPermission == true ? (开/关) : null`
     * （:920-926）。
     */
    fun liveTrailingOf(hasPermission: Boolean?, reminderEnabled: Boolean): LiveTrailing = when {
        hasPermission == null -> LiveTrailing.HIDDEN
        !hasPermission -> LiveTrailing.PERMISSION_MISSING
        reminderEnabled -> LiveTrailing.ENABLED
        else -> LiveTrailing.DISABLED
    }

    /** 云同步入口行尾的五态（`_CloudSyncEntryTileState.build`，:999-1007）。 */
    enum class CloudSyncTrailing(val text: ArbText?) {
        /** 配置还没读完 → 留白，避免先闪一帧「未开启」（:998）。 */
        LOADING(null),
        DISABLED(SettingsStringsExt2.cloudSyncEntryDisabled),
        /** 同步中优先于「上次失败」：正在跑就别吓人（:1003-1006 的嵌套三元）。 */
        SYNCING(SettingsStringsExt2.cloudSyncEntrySyncing),
        ERROR(SettingsStringsExt2.cloudSyncEntryError),
        ENABLED(SettingsStringsExt2.cloudSyncEntryEnabled),
    }

    /**
     * 云同步行尾判定（:999-1007 的嵌套三元，逐分支照搬）：
     *
     * ```
     * !loaded              → null      （留白）
     * else !enabled        → 已关闭
     * else syncing         → 同步中
     * else hasError        → 上次同步失败
     * else                 → 已开启
     * ```
     */
    fun cloudSyncTrailingOf(
        loaded: Boolean,
        enabled: Boolean,
        syncing: Boolean,
        hasError: Boolean,
    ): CloudSyncTrailing {
        if (!loaded) return CloudSyncTrailing.LOADING
        if (!enabled) return CloudSyncTrailing.DISABLED
        if (syncing) return CloudSyncTrailing.SYNCING
        if (hasError) return CloudSyncTrailing.ERROR
        return CloudSyncTrailing.ENABLED
    }

    /** 把本页 state 的云同步字符串收成 [cloudSyncTrailingOf] 的四个布尔。 */
    fun cloudSyncTrailingOf(state: SettingsTimetableState): CloudSyncTrailing =
        cloudSyncTrailingOf(
            loaded = state.cloudSyncState != "loading",
            enabled = state.cloudSyncState != "loading" && state.cloudSyncState != "disabled",
            syncing = state.cloudSyncState == "syncing",
            hasError = state.cloudSyncState == "error",
        )

    /** 开发者工具组的三种可见性（:1065-1144）。 */
    enum class DeveloperToolsVisibility {
        /** 正式发布版且非诊断构建：整组返回 `SizedBox.shrink()`（:1066-1068）。 */
        HIDDEN,

        /** 调试版：只留组件展示与调试叠层四行（:1095-1144）。 */
        DEBUG_ONLY,

        /** 诊断构建：全部六行（:1077-1094 再加四行）。 */
        FULL,
    }

    fun developerToolsVisibility(releaseBuild: Boolean, diagnosticsBuild: Boolean): DeveloperToolsVisibility = when {
        diagnosticsBuild -> DeveloperToolsVisibility.FULL
        releaseBuild -> DeveloperToolsVisibility.HIDDEN
        else -> DeveloperToolsVisibility.DEBUG_ONLY
    }

    /** `_formatDate`（:1154-1156）：年不补零，月日补零。 */
    fun formatDate(year: Int, month: Int, day: Int): String =
        "%d-%02d-%02d".format(Locale.ROOT, year, month, day)

    /** 周数读数（`semesterWeekCountAction` = `{count} 周`）。 */
    fun weekCountLabel(count: Int): ArbText =
        SettingsStringsExt2.semesterWeekCountAction.withArguments("count", count.toString())

    // ----------------------------------------------------------------- 私有构造

    /** 区块头 = 空档 + 小标题（`const HyperosSectionGap()` + `HyperosSectionLabel`）。 */
    private fun sectionHeader(key: String, title: ArbText): List<SettingsNode> = listOf(
        SettingsGap("timetable.gap.$key"),
        SettingsLabel(
            id = "timetable.section.$key.label",
            textKey = title.key,
            text = title.text,
        ),
    )

    /**
     * 学期摘要卡（:379-397）。
     *
     * 标题按「当前第 N 周 / 共 M 周」拼；副标题是开学日期，未设置时另一句。
     */
    private fun summaryRow(state: SettingsTimetableState): SettingsRow {
        // 模板有两个占位符：filled 只换一个就返回 String，所以直接连做两次 replace
        val titleText = SettingsStringsExt2.semesterOverviewCurrentWeek.text
            .replace("{current}", state.currentWeek.toString())
            .replace("{total}", state.semesterWeekCount.toString())
        val start = state.semesterStartDate
        val subtitle = if (start == null) {
            SettingsStringsExt2.semesterStartUnset
        } else {
            SettingsStringsExt2.semesterStartSet.withArguments(
                "date",
                formatDate(start.first, start.second, start.third),
            )
        }
        return settingsRow(
            id = "timetable.summary",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt2.semesterOverviewCurrentWeek.copy(resolved = titleText),
            subtitle = subtitle,
            action = SettingsAction.NAVIGATE,
            actionTarget = ROUTE_SEMESTER,
            // Flutter 这里是一张独立摘要卡（`HyperosSummaryCard`：应用图标 + 第N周/共M周 +
            // 开学日期 + 右箭头），不是普通设置行。标记出来让渲染层画成卡。
            standaloneSummaryCard = true,
            leadingAppIcon = true,
        )
    }

    /**
     * 开发者工具组（:658-670 + :1036-1152）。
     *
     * 可见性由 [developerToolsVisibility] 决定；`HIDDEN` 时**连区块头与空档都不加**，
     * 但页尾那个 `HyperosSectionGap` 照旧（它在 `_SettingsDeveloperListGroup` 之外）。
     */
    private fun appendDeveloperSection(
        nodes: MutableList<SettingsNode>,
        state: SettingsTimetableState,
    ) {
        val visibility = developerToolsVisibility(state.releaseBuild, state.diagnosticsBuild)
        if (visibility == DeveloperToolsVisibility.HIDDEN) return
        nodes += sectionHeader("developer", SettingsStringsExt2.developerSectionTitle)

        val rows = mutableListOf<SettingsRow>()
        if (visibility == DeveloperToolsVisibility.FULL) {
            rows += settingsRow(
                id = "timetable.memoryStats",
                icon = SettingsRowIcon("background", "#FF6B00"),
                component = MiuixRowComponent.ARROW,
                title = SettingsStringsExt2.memoryStatsEntryTitle,
                action = SettingsAction.NAVIGATE,
                actionTarget = ROUTE_MEMORY_STATS,
            )
            rows += settingsRow(
                id = "timetable.liveTestingFixture",
                icon = SettingsRowIcon("stopwatch", "#6366F1"),
                component = MiuixRowComponent.ARROW,
                title = SettingsStringsExt2.liveTestingFixtureEntryTitle,
                action = SettingsAction.NAVIGATE,
                actionTarget = ROUTE_LIVE_FIXTURE,
            )
        }
        // 发布版顺序（`timetable_settings_screen.dart:1216-1245`）：HyperOS 组件展示在前、
        // Miuix 组件展示在后。重构版此前只有后者，前者整行缺失（`hyperosShowcaseEntryTitle`
        // / `hyperosShowcaseEntrySubtitle` 两个键在 ARB 里有、界面上无处渲染）。
        // 落点已就绪：`ROUTE_HYPEROS_SHOWCASE` → 壳映射 `"i.hyperosShowcase"`
        // （`ShellWiring.kt` 的设置路由表）→ `HyperosShowcasePage`。
        rows += settingsRow(
            id = "timetable.hyperosShowcase",
            icon = SettingsRowIcon("all", "#8B5CF6"),
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt2.hyperosShowcaseEntryTitle,
            details = SettingsStringsExt2.hyperosShowcaseEntrySubtitle,
            action = SettingsAction.NAVIGATE,
            actionTarget = ROUTE_HYPEROS_SHOWCASE,
        )
        rows += settingsRow(
            id = "timetable.miuixShowcase",
            icon = SettingsRowIcon("listView", "#06B6D4"),
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt2.miuixShowcaseEntryTitle,
            details = SettingsStringsExt2.miuixShowcaseEntrySubtitle,
            action = SettingsAction.NAVIGATE,
            actionTarget = ROUTE_MIUIX_SHOWCASE,
        )
        // 发布版这里还有「调试 UI 叠层」开关与「调试面板」两行
        // （`timetable_settings_screen.dart:1248-1265`）。重构版**没有任何实现**：
        // `BlackBoxOverlayPreferences` 不存在、面板也没有落点，宿主只处理 NAVIGATE，
        // 开关值恒 false 且没有写入点。按仓内「不留点了必无效的入口」口径先整行藏起，
        // 等叠层/面板真移植回来再一起放出来（文案键保留在 ARB 里，不删）。
        nodes += SettingsGroup(id = "timetable.section.developer", children = rows)
    }
}
