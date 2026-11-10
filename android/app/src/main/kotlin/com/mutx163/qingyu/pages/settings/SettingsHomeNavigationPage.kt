package com.mutx163.qingyu.pages.settings

/**
 * 首页与导航设置页（`lib/screens/settings/settings_home_navigation.dart`，380 行）
 * 结构模型。
 *
 * 从「外观」迁出的结构性设置（设置 IA 重构，:17-20）：首页导航形态、玻璃坞
 * 独立圆钮显隐与功能/图标、底栏按钮编排、右上角菜单形态与八宫格自定义、首页标题样式。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: homeNavigationTitle)`（:71-78） | `titleKey/title` | `basic.TopAppBar` |
 * | `HyperosSettingsBlock(应用形态)`（:92-119） | `homeNavigation.form.*` | preference category + 组 |
 * | `HyperosSelectTile<HomeNavigationForm>`（:96-113） | `homeNavigation.form` | `MiuixOverlayDropdownPreference` |
 * | `if (isGlassDock)` 底栏编排（:128-229） | `homeNavigation.dock.*` | 仅玻璃坞形态出现 |
 * | `HyperosSwitchTile(显示圆钮)`（:137-146） | `homeNavigation.showAddButton` | `MiuixSwitchPreference` |
 * | `HyperosListTile(自定义底栏按钮)`（:147-173） | `homeNavigation.dockCustomize` | `MiuixArrowPreference` |
 * | `HyperosSelectTile<String>(圆钮功能)`（:175-188） | `homeNavigation.dockButtonEntry` | `MiuixOverlayDropdownPreference` |
 * | `HyperosListTile(圆钮图标)`（:189-224） | `homeNavigation.dockButtonIcon` | `MiuixArrowPreference` |
 * | `HyperosSettingsBlock(右上角菜单)`（:231-287） | `homeNavigation.menu.*` | preference category + 组 |
 * | `HyperosSelectTile<HomeMenuStyle>`（:238-248） | `homeNavigation.menuStyle` | `MiuixOverlayDropdownPreference` |
 * | `HyperosListTile(自定义菜单按钮)`（:251-284） | `homeNavigation.menuCustomize` | `MiuixArrowPreference` |
 * | `HyperosSettingsBlock(首页标题)`（:296-317） | `homeNavigation.homeTitle.*` | preference category + 组 |
 * | `HomeTitleStylePreview`（:300-303） | `SettingsInline(PREVIEW_CARD)` | 官方无对应物：标题微缩预览 |
 * | `HyperosSelectTile<HomeTitleStyle>`（:304-314） | `homeNavigation.homeTitleStyle` | `MiuixOverlayDropdownPreference` |
 * | `SettingsResetTile(homeNavigation)`（:320-323） | `homeNavigation.reset.row` | `MiuixArrowPreference`（危险色） |
 *
 * ## 三条最容易写反的
 *
 * 1. **右上角菜单区块不属于玻璃坞判断**：它在 `if (isGlassDock)` 之外（:230-287），
 *    经典形态下也必须在；
 * 2. **形态行的副标题跟随当前形态**，不是固定一句（:98-103 的 switch）：
 *    选经典时说的是「保持现有的页面与导航方式」，选玻璃坞时说的是「悬浮玻璃底栏」；
 * 3. **圆钮功能的当前值走兜底**（`_effectiveGlassDockButtonEntryId`，:40-47）：
 *    空串 / `addCourse` / 未知 id / 当前不可见的条目，一律显示「添加」。
 *
 * ## 未纳入本模型
 *
 * 1. 三个子页跳转后**重读草稿**（:168-172 / :219-223 / :279-283）：返回时必须用
 *    provider 真值覆盖，否则下一次改动把子页里的选择写回旧值；
 * 2. 落盘的串行队列（`_saveQueue`，:343-345）与「实况展开图未选时跳过落盘」的
 *    守卫（:348-353）；
 * 3. 底栏材质选择器已在 93bed6b 下线（:134-136）：现在跟随全局材质，本页不再有。
 */
object SettingsHomeNavigationPage {

    const val ID = "settings-home-navigation"

    /** `SettingsResetScope.homeNavigation`（`settings_reset.dart:29-30`）。 */
    const val RESET_SCOPE_HOME_NAVIGATION = "homeNavigation"

    /** 子页路由（Dart 侧 `RouteSettings(name: ...)`，:156/:198/:261）。 */
    const val ROUTE_GLASS_DOCK = "/settings/glass-dock"
    const val ROUTE_GLASS_DOCK_ICON = "/settings/glass-dock-icon"
    const val ROUTE_HOME_MENU = "/settings/home-menu"

    /** `HomeDockMenu.maxSlots`（`timetable_settings_enums.dart:217`）。 */
    const val DOCK_MAX_SLOTS = 5

    /** `HomeGridMenu.maxSlots`（`timetable_settings_enums.dart:162`）。 */
    const val GRID_MAX_SLOTS = 8

    /** 底栏的两个视图切换动作 id（`home_menu_catalog.dart:534-535`）。 */
    const val DOCK_ACTION_DAY = "day"
    const val DOCK_ACTION_WEEK = "week"

    /**
     * `HomeDockMenu.defaultActions`（tag `v2.1.4.1`
     * `lib/models/settings/timetable_settings_enums.dart:216`）：出厂只有日/周。
     */
    val DOCK_DEFAULT_ACTIONS: List<String> = listOf("day", "week")

    /**
     * `HomeGridMenu.defaultActions`（tag `v2.1.4.1`
     * `lib/models/settings/timetable_settings_enums.dart:170-178`）：首项 `update`、
     * **不含** `tasks`（2026-11-10 用户拍板「默认就跟旧版本一致」）。
     */
    val GRID_DEFAULT_ACTIONS: List<String> = listOf(
        "update", "overview", "statistics", "addCourse",
        "exams", "importCourses", "settings", "support",
    )

    /** 八宫格候选目录的四个分类（`HomeMenuEntryCategory`，`home_top_menu.dart:10`）。 */
    val CATEGORIES: List<String> = listOf("features", "data", "preferences", "about")

    fun spec(state: SettingsHomeNavigationState): SettingsPageSpec {
        val isGlassDock = state.navigationForm == "glassDock"
        val nodes = mutableListOf<SettingsNode>()

        // 区块 0：应用形态（HyperosSettingsBlock：label + 组，无前导空档）
        nodes += SettingsLabel(
            id = "homeNavigation.form.label",
            textKey = SettingsStringsExt2.homeNavigationFormLabel.key,
            text = SettingsStringsExt2.homeNavigationFormLabel.text,
        )
        nodes += SettingsGroup(
            id = "homeNavigation.form",
            children = listOf(formRow(state)),
        )

        // 区块 1：底栏编排（仅玻璃坞；自带前导空档，:129）
        if (isGlassDock) {
            nodes += SettingsGap("homeNavigation.gap.chrome")
            nodes += SettingsLabel(
                id = "homeNavigation.dock.label",
                textKey = SettingsStringsExt2.glassDockCustomizeSectionTitle.key,
                text = SettingsStringsExt2.glassDockCustomizeSectionTitle.text,
            )
            nodes += SettingsGroup(
                id = "homeNavigation.dock",
                children = dockRows(state),
            )
        }

        // 区块 2：右上角菜单（两种形态都在，:230-287）
        nodes += SettingsGap("homeNavigation.gap.menu")
        nodes += SettingsLabel(
            id = "homeNavigation.menu.label",
            textKey = SettingsStringsExt2.homeMenuCustomizeSectionTitle.key,
            text = SettingsStringsExt2.homeMenuCustomizeSectionTitle.text,
        )
        nodes += SettingsGroup(
            id = "homeNavigation.menu",
            children = listOf(
                settingsRow(
                    id = "homeNavigation.menuStyle",
                    component = MiuixRowComponent.DROPDOWN,
                    title = SettingsStringsExt2.homeMenuStyleLabel,
                    options = listOf(
                        option("list", SettingsStringsExt2.homeMenuStyleList),
                        option("grid", SettingsStringsExt2.homeMenuStyleGrid),
                    ),
                    selectedOptionId = state.menuStyle,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "homeNavigation.menuCustomize",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.homeMenuCustomizeTitle,
                    details = customizeDetails(
                        resolveGridEntryIds(state.gridMenuActions, state.diagnosticsBuild).size,
                        GRID_MAX_SLOTS,
                    ),
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_HOME_MENU,
                ),
            ),
        )

        // 区块 3：首页标题（:291-319，自带前导空档）
        nodes += SettingsGap("homeNavigation.gap.homeTitle")
        nodes += SettingsLabel(
            id = "homeNavigation.homeTitle.label",
            textKey = SettingsStringsExt2.homeTitleSectionTitle.key,
            text = SettingsStringsExt2.homeTitleSectionTitle.text,
        )
        nodes += SettingsGroup(
            id = "homeNavigation.homeTitle",
            children = listOf(
                titleStylePreview(state),
                settingsRow(
                    id = "homeNavigation.homeTitleStyle",
                    component = MiuixRowComponent.DROPDOWN,
                    title = SettingsStringsExt2.homeTitleStyleLabel,
                    options = homeTitleStyleOptions(),
                    selectedOptionId = state.titleStyle,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        // 区块 4：恢复默认（SettingsResetTile 自带一个空档，settings_reset.dart:209）
        nodes += SettingsGap("homeNavigation.gap.reset")
        nodes += SettingsGroup(
            id = "homeNavigation.reset",
            children = listOf(
                settingsRow(
                    id = "homeNavigation.reset.row",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.settingsResetDefaultsTitle,
                    // 本页作用域与页面标题不重合，但 settings_reset.dart:226-233
                    // 只给 appearance / timetablePage 两句说明，homeNavigation 不加
                    destructive = true,
                    action = SettingsAction.RESET_SCOPE,
                    actionTarget = RESET_SCOPE_HOME_NAVIGATION,
                ),
            ),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStringsExt2.homeNavigationTitle.key,
            title = SettingsStringsExt2.homeNavigationTitle.text,
            nodes = nodes,
        )
    }

    // ------------------------------------------------------------------ 形态行

    /**
     * 应用形态（:96-113）。
     *
     * 副标题是**当前形态**的说明，不是固定一句（:98-103）。
     */
    private fun formRow(state: SettingsHomeNavigationState): SettingsRow {
        val glass = state.navigationForm == "glassDock"
        return settingsRow(
            id = "homeNavigation.form",
            component = MiuixRowComponent.DROPDOWN,
            title = SettingsStringsExt2.homeNavigationFormLabel,
            subtitle = if (glass) {
                SettingsStringsExt2.homeNavigationFormGlassDockSubtitle
            } else {
                SettingsStringsExt2.homeNavigationFormClassicSubtitle
            },
            options = listOf(
                option("classic", SettingsStringsExt2.homeNavigationFormClassic),
                option("glassDock", SettingsStringsExt2.homeNavigationFormGlassDock),
            ),
            selectedOptionId = state.navigationForm,
            action = SettingsAction.WRITE_SETTING,
        )
    }

    // --------------------------------------------------------------- 底栏编排

    /**
     * 底栏编排的四行（:130-227）。
     *
     * 「圆钮功能」与「圆钮图标」只在「显示圆钮」开着时出现（:174 的 `if`）。
     */
    private fun dockRows(state: SettingsHomeNavigationState): List<SettingsRow> {
        val rows = mutableListOf<SettingsRow>()
        rows += settingsRow(
            id = "homeNavigation.showAddButton",
            component = MiuixRowComponent.SWITCH,
            title = SettingsStringsExt2.glassDockShowAddButtonTitle,
            subtitle = SettingsStringsExt2.glassDockShowAddButtonSubtitle,
            switchValue = state.showAddButton,
            action = SettingsAction.WRITE_SETTING,
        )
        val dockIds = resolveDockActionIds(state.dockActionIds)
        rows += settingsRow(
            id = "homeNavigation.dockCustomize",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt2.glassDockCustomizeTitle,
            details = customizeDetails(dockIds.size, DOCK_MAX_SLOTS),
            action = SettingsAction.NAVIGATE,
            actionTarget = ROUTE_GLASS_DOCK,
        )
        if (!state.showAddButton) return rows

        rows += settingsRow(
            id = "homeNavigation.dockButtonEntry",
            component = MiuixRowComponent.DROPDOWN,
            title = SettingsStringsExt2.glassDockRoundActionLabel,
            options = dockButtonEntryOptions(state.diagnosticsBuild),
            selectedOptionId = effectiveDockButtonEntryId(
                state.dockButtonEntryId,
                state.diagnosticsBuild,
            ),
            action = SettingsAction.WRITE_SETTING,
        )
        rows += settingsRow(
            id = "homeNavigation.dockButtonIcon",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt2.glassDockButtonIconTitle,
            // 图标名是用户选择值，不来自 ARB（键留空 → 对照测试跳过）
            details = state.dockButtonIconName?.let { ArbText(NON_ARB_TEXT, it) }
                ?: SettingsStringsExt2.glassDockButtonIconDefault,
            action = SettingsAction.NAVIGATE,
            actionTarget = ROUTE_GLASS_DOCK_ICON,
        )
        return rows
    }

    /**
     * 圆钮功能下拉（:175-188）：显式给出「添加」→ `addCourse`，再接整个目录。
     *
     * Dart 侧用 `{文案: 值}` 的 Map 构造，目录里 `addCourse` 的文案与显式首项同名，
     * 所以**只会出现一次**——本模型按 id 去重保持同一行为。
     */
    fun dockButtonEntryOptions(diagnosticsBuild: Boolean): List<SettingsOption> {
        val out = mutableListOf(
            option("addCourse", SettingsStringsExt2.homeMenuAddCourseTitle),
        )
        catalog(diagnosticsBuild).forEach { entry ->
            if (entry.id == "addCourse") return@forEach
            out += option(entry.id, entry.label)
        }
        return out
    }

    /**
     * `_effectiveGlassDockButtonEntryId`（:40-47）。
     *
     * 空串 / `addCourse` → `addCourse`；目录里找不到或当前不可见 → `addCourse`。
     */
    fun effectiveDockButtonEntryId(stored: String?, diagnosticsBuild: Boolean): String {
        if (stored.isNullOrEmpty() || stored == "addCourse") return "addCourse"
        val entry = catalog(diagnosticsBuild).firstOrNull { it.id == stored }
        return if (entry == null || !entry.visible(diagnosticsBuild)) "addCourse" else stored
    }

    /** 首页标题样式的两档（`HomeTitleStyle`，`enum_localizations.dart:79-83`）。 */
    fun homeTitleStyleOptions(): List<SettingsOption> = listOf(
        option("classic", SettingsStringsExt2.homeTitleStyleClassicLabel),
        option("brand", SettingsStringsExt2.homeTitleStyleBrandLabel),
    )

    /**
     * 首页标题微缩预览（`HomeTitleStylePreview`，`settings_appearance.dart:871-909`）。
     *
     * classic 只显示应用标题；brand 是「大 Logo + 小课表名」，第二行取
     * `defaultTimetablePreviewName`（**不是**用户当前的课表名——预览是固定的示意值）。
     */
    private fun titleStylePreview(state: SettingsHomeNavigationState): SettingsInline =
        if (state.titleStyle == "brand") {
            SettingsInline(
                id = "homeNavigation.homeTitle.preview",
                kind = InlineKind.PREVIEW_CARD,
                note = "首页标题微缩预览（settings_appearance.dart:871-909）：官方没有标题样式预览，" +
                    "两行文字由应用自绘；第二行固定取 defaultTimetablePreviewName",
                texts = listOf(
                    SettingsInlineText(SettingsStringsExt2.appTitle.key, SettingsStringsExt2.appTitle.text),
                    SettingsInlineText(
                        SettingsStringsExt2.defaultTimetablePreviewName.key,
                        SettingsStringsExt2.defaultTimetablePreviewName.text,
                    ),
                ),
            )
        } else {
            SettingsInline(
                id = "homeNavigation.homeTitle.preview",
                kind = InlineKind.PREVIEW_CARD,
                note = "首页标题微缩预览（settings_appearance.dart:871-909）：官方没有标题样式预览，" +
                    "classic 只有一行应用标题",
                texts = listOf(
                    SettingsInlineText(SettingsStringsExt2.appTitle.key, SettingsStringsExt2.appTitle.text),
                ),
            )
        }

    // ------------------------------------------------------------- 纯函数行为

    /** 「已启用 N/M 个」（`homeGridCustomizeDetails` 模板）。 */
    fun customizeDetails(count: Int, maxSlots: Int): ArbText {
        val template = SettingsStringsExt2.homeGridCustomizeDetails
        return template.withArguments(
            "count" to count.toString(),
            "max" to maxSlots.toString(),
        )
    }

    /**
     * 底栏排列解析（`home_menu_catalog.dart:539-556` 的 `resolveGlassDockActionIds`）。
     *
     * 只留 `day`/`week` 与目录里可见的条目，去重保序；空排列回退
     * `HomeDockMenu.defaultActions`。
     */
    fun resolveDockActionIds(
        raw: List<String>,
        diagnosticsBuild: Boolean = false,
    ): List<String> {
        val catalogIds = catalog(diagnosticsBuild)
            .filter { it.visible(diagnosticsBuild) }
            .map { it.id }
            .toSet()
        val out = mutableListOf<String>()
        raw.forEach { id ->
            val keep = id == DOCK_ACTION_DAY || id == DOCK_ACTION_WEEK || id in catalogIds
            if (keep && id !in out) out += id
        }
        return if (out.isEmpty()) DOCK_DEFAULT_ACTIONS else out
    }

    /**
     * 八宫格排列解析（`home_menu_catalog.dart:509-531` 的 `resolveHomeGridMenuEntries`）。
     *
     * 丢弃未知/不可见 id、去重保序；空表或「只剩下钉住项」都回退
     * `HomeGridMenu.defaultActions`（自愈：历史版本把空排列固化成单入口）。
     */
    fun resolveGridEntryIds(
        raw: List<String>,
        diagnosticsBuild: Boolean = false,
    ): List<String> {
        val visible = catalog(diagnosticsBuild).filter { it.visible(diagnosticsBuild) }
        val visibleIds = visible.map { it.id }.toSet()
        val resolved = mutableListOf<String>()
        raw.forEach { id ->
            if (id in visibleIds && id !in resolved) resolved += id
        }
        val degenerate = resolved.size == 1 && resolved.single() == "settings"
        if (resolved.isEmpty() || degenerate) {
            return GRID_DEFAULT_ACTIONS.filter { it in visibleIds }
        }
        return resolved
    }

    // ---------------------------------------------------------- 候选目录（镜像）

    /** 目录里的一个入口（`HomeMenuEntry`，`home_top_menu.dart:30-53`）。 */
    data class CatalogEntry(
        val id: String,
        val label: ArbText,
        val category: String,
        /** `visible()`：调试/性能版专属条目在正式版返回 false（`home_menu_catalog.dart:448`）。 */
        val diagnosticsOnly: Boolean = false,
    ) {
        fun visible(diagnosticsBuild: Boolean): Boolean = !diagnosticsOnly || diagnosticsBuild
    }

    /**
     * 八宫格候选目录（`kHomeMenuCatalog`，`lib/widgets/home_menu_catalog.dart`）。
     *
     * 返回**全部**条目（含当前构建不可见的那几个）；要看「此刻可用的」请自己用
     * [CatalogEntry.visible] 过滤 —— 因为 `homeMenuEntryById` 本身是全表查找，
     * 而 `resolve*` 才是负责门控的地方（`home_menu_catalog.dart:509-531`）。
     *
     * 顺序与分类逐项照抄 Dart 目录的声明顺序 —— 编辑器按分类分组展示时，
     * 组内顺序就是这个顺序，所以它属于「屏上顺序」，必须钉住。
     */
    fun catalog(diagnosticsBuild: Boolean): List<CatalogEntry> = ALL_ENTRIES

    private val ALL_ENTRIES: List<CatalogEntry> = listOf(
        // ── 功能入口（features）────────────────────────────────────
        CatalogEntry("update", SettingsStringsExt2.homeMenuUpdateTitle, "features"),
        CatalogEntry("pickupCode", SettingsStringsExt2.pickupCodeEntryTitle, "features"),
        CatalogEntry("overview", SettingsStringsExt2.homeMenuOverviewTitle, "features"),
        CatalogEntry("statistics", SettingsStringsExt2.homeMenuStatisticsTitle, "features"),
        CatalogEntry("addCourse", SettingsStringsExt2.homeMenuAddCourseTitle, "features"),
        CatalogEntry("exams", SettingsStringsExt2.examListTitle, "features"),
        CatalogEntry("importCourses", SettingsStringsExt2.homeMenuImportTitle, "features"),
        CatalogEntry("courseRecolor", SettingsStrings.courseRecolorTileTitle, "features"),
        CatalogEntry("shareTimetable", SettingsStringsExt2.homeMenuShareTimetableTitle, "features"),
        CatalogEntry("tasks", SettingsStringsExt2.homeMenuTasksTitle, "features"),
        CatalogEntry("addExam", SettingsStringsExt2.addExam, "features"),
        CatalogEntry("addTask", SettingsStringsExt2.addTask, "features"),
        CatalogEntry("addScheduleItem", SettingsStringsExt2.addScheduleTitle, "features"),
        CatalogEntry("scheduleList", SettingsStringsExt2.scheduleListTitle, "features"),
        CatalogEntry("courseConflict", SettingsStringsExt2.courseConflictDetailTitle, "features"),
        CatalogEntry("locationTimeMatch", SettingsStringsExt2.locationTimeMatchTitle, "features"),
        CatalogEntry("scheduleDateRule", SettingsStringsExt2.scheduleDateRuleSectionTitle, "features"),
        CatalogEntry("icsExport", SettingsStringsExt2.icsExportTitle, "features"),
        CatalogEntry("monthView", SettingsStringsExt2.monthViewTitle, "features"),
        CatalogEntry("timeSchemes", SettingsStringsExt2.timeSchemeTitle, "features"),
        CatalogEntry("profiles", SettingsStringsExt2.timetableProfilesTitle, "features"),
        CatalogEntry("quickSwitchTimetable", SettingsStringsExt2.switchTimetableTitle, "features"),
        CatalogEntry("more", SettingsStringsExt2.homeMenuMoreTitle, "features"),
        // ── 数据与同步（data）──────────────────────────────────────
        CatalogEntry("dataTransfer", SettingsStringsExt2.dataTransferEntryTitle, "data"),
        CatalogEntry("cloudSync", SettingsStringsExt2.cloudSyncTitle, "data"),
        CatalogEntry("lanEdit", SettingsStringsExt2.lanEditTitle, "data"),
        CatalogEntry("coupleTimetable", SettingsStringsExt2.coupleTimetableTitle, "data"),
        // ── 偏好设置（preferences）─────────────────────────────────
        // 13 条，与 `SettingsGlassDockEditorPage.catalog` 的 preferences 段逐条一致
        // （都镜像 Dart `home_menu_catalog.dart:327-384`）。顺序即 Dart 声明顺序。
        CatalogEntry("settings", SettingsStringsExt2.homeMenuSettingsTitle, "preferences"),
        CatalogEntry("homeNavigation", SettingsStringsExt2.homeNavigationTitle, "preferences"),
        CatalogEntry("generalSettings", SettingsStringsExt4.generalSettingsTitle, "preferences"),
        CatalogEntry("appearanceSettings", SettingsStringsExt4.appearanceTitle, "preferences"),
        CatalogEntry("appearanceEditor", SettingsStringsExt4.appearanceEditorTitle, "preferences"),
        CatalogEntry(
            "timetablePageSettings",
            SettingsStringsExt4.timetablePageSettingsTitle,
            "preferences",
        ),
        CatalogEntry("courseCardSettings", SettingsStringsExt4.courseCardSettingsTitle, "preferences"),
        CatalogEntry("weatherSettings", SettingsStringsExt4.weatherSettingsEntryTitle, "preferences"),
        CatalogEntry("liveSettings", SettingsStringsExt4.liveSettingsTitle, "preferences"),
        CatalogEntry("holidaySettings", SettingsStringsExt4.holidaySettingsTitle, "preferences"),
        CatalogEntry("homeWidgetSettings", SettingsStringsExt4.homeWidgetSettingsTitle, "preferences"),
        CatalogEntry("diagnosticsSettings", SettingsStringsExt4.diagnosticsEntryTitle, "preferences"),
        CatalogEntry("statisticsSettings", SettingsStringsExt2.statisticsSettingsTitle, "preferences"),
        // ── 关于与支持（about）─────────────────────────────────────
        CatalogEntry("support", SettingsStringsExt2.homeMenuCoffeeTitle, "about"),
        CatalogEntry("aboutApp", SettingsStringsExt2.aboutTitle, "about"),
        CatalogEntry("changelog", SettingsStringsExt2.aboutChangelogTitle, "about"),
        CatalogEntry("userGuide", SettingsStringsExt2.userGuideEntryTitle, "about"),
        CatalogEntry("feedback", SettingsStringsExt2.feedbackTitle, "about"),
        CatalogEntry("openSourceLicenses", SettingsStringsExt2.aboutOpenSourceLicensesTitle, "about"),
        CatalogEntry(
            "memoryStats",
            SettingsStringsExt2.memoryStatsEntryTitle,
            "about",
            // home_menu_catalog.dart:448 `visible: () => MemoryStatsService.isDiagnosticsBuildCached`
            diagnosticsOnly = true,
        ),
    )
}
