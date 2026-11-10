package com.mutx163.qingyu.pages.settings

/**
 * 玻璃坞底栏按钮编辑器（`lib/screens/settings/settings_glass_dock_editor.dart`）结构模型。
 *
 * ## 这一页在做什么
 *
 * 首页底栏（玻璃坞）那排按钮可以由用户自定义：最多 [MAX_SLOTS] 个，可拖动排序、
 * 可移除、可从首页入口目录里加。页面自上而下是：
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: glassDockCustomizeTitle)`（:87-89） | `titleKey/title` | `basic.TopAppBar` |
 * | 预览卡（:181-229） | `dock.preview`（CONTROL_CARD） | 官方无「图标坞预览」组件，见下 |
 * | `HyperosSectionDescription(hint)`（:96-98） | `dock.hint` | 整宽脚注（不受 11/17 口径约束） |
 * | `HyperosSectionLabel(已启用)`（:94） | `dock.enabled.label` | preference category |
 * | `ReorderableListView` 每行（:231-268） | `dock.enabled` 的各行 | `extra.SuperArrow` + 行尾移除按钮 |
 * | 视图切换伪分组（:122-148） | `dock.viewSwitch.*` | preference category + `SuperArrow` |
 * | 四个目录分类（:101-107） | `dock.catalog.<cat>.*` | 同上 |
 * | `HyperosListTile(恢复默认排列)`（:108-116） | `dock.reset` | `extra.SuperArrow` |
 *
 * ## 为什么预览卡是「数据块」而不是一行 Preference
 *
 * 它是一排「圆角图标 + 名称」的小格子，官方 preference 一族里没有对应物
 * （最接近的是行内的 icon badge，但那是单行单图标）。所以在模型里用
 * [InlineKind.CONTROL_CARD] 承载：标题位留空（Dart 侧这卡没有标题），
 * 内容位按当前排列逐个给出名称。渲染成什么形状由渲染层决定，模型只保证
 * **顺序与文案**正确。
 *
 * ## 提示句为什么排在「已启用」之上
 *
 * Dart 侧它压在启用列表下面（:96-98），用户得先把列表扫完才看到「按住条目可排序」。
 * Compose 侧已按用户要求提到列表之前（先给规则，再看图标），模型跟着改以保持两边说法一致。
 *
 * ## 两处不写进模型的接线行为
 *
 * 1. 每次改动都即时回调 `onChanged`（:50-55），由「首页与导航」页统一走草稿 + 自动保存；
 *    本模型只提供 [add]/[removeAt]/[move]/[reset] 四个**纯函数**变换。
 * 2. 拖动排序的 `newIndex` 语义：Dart 用 `onReorderItem`（框架已校正下移时的插入位，
 *    见 `settings_home_menu_editor.dart:53` 的注），所以 [move] 直接 `insert(newIndex)`，
 *    **不要**再减一。
 */
object SettingsGlassDockEditorPage {

    const val ID = "settings-glass-dock-editor"

    /** `HomeDockMenu.maxSlots`（`timetable_settings_enums.dart:217`）：底栏最多 5 个。 */
    const val MAX_SLOTS = 5

    /** `HomeDockMenu.defaultActions`（tag `v2.1.4.1` 同文件 `:216`）：出厂排列只有日/周。 */
    val DEFAULT_ACTIONS: List<String> = listOf("day", "week")

    /** `kGlassDockActionDay` / `kGlassDockActionWeek`（`home_menu_catalog.dart:534-535`）。 */
    const val ACTION_DAY = "day"
    const val ACTION_WEEK = "week"

    /** 恢复默认排列这一行的目标串（渲染层据此调 `_resetToDefault`）。 */
    const val RESET_TARGET = "glassDockEditor.reset"

    /** 视图切换伪分组里的两个动作（`home_menu_catalog.dart:560-570` 的 `glassDockActionLabel`）。 */
    val VIEW_SWITCH_ACTIONS: List<DockCatalogEntry> = listOf(
        DockCatalogEntry(ACTION_DAY, SettingsStringsExt4.glassDockTabDay, DockCategory.FEATURES),
        DockCatalogEntry(ACTION_WEEK, SettingsStringsExt4.glassDockTabWeek, DockCategory.FEATURES),
    )

    /**
     * 首页入口目录（`kHomeMenuCatalog`，`home_menu_catalog.dart:44-450`），**按 Dart 声明顺序**。
     *
     * 顺序即屏上顺序：编辑器按分类分组时保持这个相对次序，用户看到的候选列表
     * 与 Dart 侧逐项对得上。`debugOnly` 对应 Dart 的 `visible()` 门控
     * （目前只有 `memoryStats`，`:442-449`）。
     */
    val catalog: List<DockCatalogEntry> = listOf(
        // ── 功能入口 ──
        DockCatalogEntry("update", SettingsStringsExt4.homeMenuUpdateTitle, DockCategory.FEATURES),
        DockCatalogEntry("pickupCode", SettingsStringsExt4.pickupCodeEntryTitle, DockCategory.FEATURES),
        DockCatalogEntry("overview", SettingsStringsExt4.homeMenuOverviewTitle, DockCategory.FEATURES),
        DockCatalogEntry("statistics", SettingsStringsExt4.homeMenuStatisticsTitle, DockCategory.FEATURES),
        DockCatalogEntry("addCourse", SettingsStringsExt4.homeMenuAddCourseTitle, DockCategory.FEATURES),
        DockCatalogEntry("exams", SettingsStringsExt4.examListTitle, DockCategory.FEATURES),
        DockCatalogEntry("importCourses", SettingsStringsExt4.homeMenuImportTitle, DockCategory.FEATURES),
        DockCatalogEntry("courseRecolor", SettingsStringsExt4.courseRecolorTileTitle, DockCategory.FEATURES),
        DockCatalogEntry("shareTimetable", SettingsStringsExt4.homeMenuShareTimetableTitle, DockCategory.FEATURES),
        DockCatalogEntry("tasks", SettingsStringsExt4.homeMenuTasksTitle, DockCategory.FEATURES),
        DockCatalogEntry("addExam", SettingsStringsExt4.addExam, DockCategory.FEATURES),
        DockCatalogEntry("addTask", SettingsStringsExt4.addTask, DockCategory.FEATURES),
        DockCatalogEntry("addScheduleItem", SettingsStringsExt4.addScheduleTitle, DockCategory.FEATURES),
        DockCatalogEntry("scheduleList", SettingsStringsExt4.scheduleListTitle, DockCategory.FEATURES),
        DockCatalogEntry("courseConflict", SettingsStringsExt4.courseConflictDetailTitle, DockCategory.FEATURES),
        DockCatalogEntry("locationTimeMatch", SettingsStringsExt4.locationTimeMatchTitle, DockCategory.FEATURES),
        DockCatalogEntry("scheduleDateRule", SettingsStringsExt4.scheduleDateRuleSectionTitle, DockCategory.FEATURES),
        DockCatalogEntry("icsExport", SettingsStringsExt4.icsExportTitle, DockCategory.FEATURES),
        DockCatalogEntry("monthView", SettingsStringsExt4.monthViewTitle, DockCategory.FEATURES),
        DockCatalogEntry("timeSchemes", SettingsStringsExt4.timeSchemeTitle, DockCategory.FEATURES),
        DockCatalogEntry("profiles", SettingsStringsExt4.timetableProfilesTitle, DockCategory.FEATURES),
        DockCatalogEntry("quickSwitchTimetable", SettingsStringsExt4.switchTimetableTitle, DockCategory.FEATURES),
        DockCatalogEntry("more", SettingsStringsExt4.homeMenuMoreTitle, DockCategory.FEATURES),
        // ── 数据与同步 ──
        DockCatalogEntry("dataTransfer", SettingsStringsExt4.dataTransferEntryTitle, DockCategory.DATA),
        DockCatalogEntry("cloudSync", SettingsStringsExt4.cloudSyncTitle, DockCategory.DATA),
        DockCatalogEntry("lanEdit", SettingsStringsExt4.lanEditTitle, DockCategory.DATA),
        DockCatalogEntry("coupleTimetable", SettingsStringsExt4.coupleTimetableTitle, DockCategory.DATA),
        // ── 偏好设置 ──
        DockCatalogEntry("settings", SettingsStringsExt4.homeMenuSettingsTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("homeNavigation", SettingsStringsExt4.homeNavigationTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("generalSettings", SettingsStringsExt4.generalSettingsTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("appearanceSettings", SettingsStringsExt4.appearanceTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("appearanceEditor", SettingsStringsExt4.appearanceEditorTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("timetablePageSettings", SettingsStringsExt4.timetablePageSettingsTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("courseCardSettings", SettingsStringsExt4.courseCardSettingsTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("weatherSettings", SettingsStringsExt4.weatherSettingsEntryTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("liveSettings", SettingsStringsExt4.liveSettingsTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("holidaySettings", SettingsStringsExt4.holidaySettingsTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("homeWidgetSettings", SettingsStringsExt4.homeWidgetSettingsTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("diagnosticsSettings", SettingsStringsExt4.diagnosticsEntryTitle, DockCategory.PREFERENCES),
        DockCatalogEntry("statisticsSettings", SettingsStringsExt4.statisticsSettingsTitle, DockCategory.PREFERENCES),
        // ── 关于与支持 ──
        DockCatalogEntry("support", SettingsStringsExt4.homeMenuCoffeeTitle, DockCategory.ABOUT),
        DockCatalogEntry("aboutApp", SettingsStringsExt4.aboutTitle, DockCategory.ABOUT),
        DockCatalogEntry("changelog", SettingsStringsExt4.aboutChangelogTitle, DockCategory.ABOUT),
        DockCatalogEntry("userGuide", SettingsStringsExt4.userGuideEntryTitle, DockCategory.ABOUT),
        DockCatalogEntry("feedback", SettingsStringsExt4.feedbackTitle, DockCategory.ABOUT),
        DockCatalogEntry("openSourceLicenses", SettingsStringsExt4.aboutOpenSourceLicensesTitle, DockCategory.ABOUT),
        // 仅调试/性能版可见（Dart :442-449 的 `visible: () => MemoryStatsService.isDiagnosticsBuildCached`）
        DockCatalogEntry("memoryStats", SettingsStringsExt4.memoryStatsEntryTitle, DockCategory.ABOUT, debugOnly = true),
    )

    // ------------------------------------------------------------------ 页面

    fun spec(state: SettingsPageState, editor: GlassDockEditorState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()
        val enabled = editor.enabledIds
        val canAdd = enabled.size < MAX_SLOTS
        val canRemove = enabled.size > 1

        // 0. 预览卡：当前排列的图标 + 名称（Dart :181-229）。这卡在 Dart 里没有标题。
        nodes += SettingsInline(
            id = "dock.preview",
            kind = InlineKind.CONTROL_CARD,
            note = "底栏预览卡（settings_glass_dock_editor.dart:181-229）：官方 preference 一族" +
                "没有「图标坞预览」这种一排图标格，属于自绘白名单；模型只保证格子顺序与文案",
            texts = enabled.map { id ->
                val label = labelOf(id)
                SettingsInlineText(label.key, label.text)
            },
        )

        // 1. 整宽提示句（排在「已启用」之上：先给规则「按住条目可排序」，再看那一列图标）
        nodes += SettingsGap("dock.gap.afterPreview")
        nodes += SettingsDescription(
            id = "dock.hint",
            textKey = SettingsStringsExt4.homeGridEditorHintBody.key,
            text = SettingsStringsExt4.homeGridEditorHintBody.filled("max", MAX_SLOTS.toString()),
        )

        // 2. 已启用（可拖动排序 + 逐个移除）
        nodes += SettingsLabel(
            id = "dock.enabled.label",
            textKey = SettingsStringsExt4.homeGridEditorEnabledTitle.key,
            text = SettingsStringsExt4.homeGridEditorEnabledTitle.text,
        )
        nodes += SettingsGroup(
            id = "dock.enabled",
            children = enabled.map { id ->
                val label = labelOf(id)
                settingsRow(
                    id = "dock.slot.$id",
                    component = MiuixRowComponent.ARROW,
                    title = label,
                    // 每行右侧的移除按钮（:330-341）；只剩一个时禁用（:48）
                    enabled = canRemove,
                    action = SettingsAction.WRITE_SETTING,
                    actionTarget = REMOVE_TARGET_PREFIX + id,
                    trailingActionKey = SettingsStringsExt4.homeGridEditorRemoveTooltip.key,
                    trailingAction = SettingsStringsExt4.homeGridEditorRemoveTooltip.text,
                    trailingActionKind = SettingsAction.WRITE_SETTING,
                )
            },
        )
        // 3. 视图切换伪分组（日/周是动作不是页面，排在目录分类之前；两个都启用时整组消失）
        val viewSwitch = VIEW_SWITCH_ACTIONS.filter { it.id !in enabled }
        if (viewSwitch.isNotEmpty()) {
            nodes += SettingsGap("dock.viewSwitch.gap")
            nodes += SettingsLabel(
                id = "dock.viewSwitch.label",
                textKey = SettingsStringsExt4.homeDockEditorViewCategory.key,
                text = SettingsStringsExt4.homeDockEditorViewCategory.text,
            )
            nodes += SettingsGroup(
                id = "dock.viewSwitch",
                children = viewSwitch.map { candidateRow(it, canAdd, "dock.viewSwitch") },
            )
        }

        // 4. 四个目录分类
        DockCategory.entries.forEach { category ->
            val candidates = candidates(category, enabled, editor.debugBuild)
            nodes += SettingsGap("dock.catalog.${category.arg}.gap")
            nodes += SettingsLabel(
                id = "dock.catalog.${category.arg}.label",
                textKey = category.label.key,
                text = category.label.text,
            )
            if (candidates.isEmpty()) {
                // :163-165 该分类全部已启用时给一句说明，而不是留一张空卡
                nodes += SettingsDescription(
                    id = "dock.catalog.${category.arg}.empty",
                    textKey = SettingsStringsExt4.homeGridEditorAllAdded.key,
                    text = SettingsStringsExt4.homeGridEditorAllAdded.text,
                )
            } else {
                nodes += SettingsGroup(
                    id = "dock.catalog.${category.arg}",
                    children = candidates.map { candidateRow(it, canAdd, "dock.catalog.${category.arg}") },
                )
            }
        }

        // 5. 恢复默认排列
        nodes += SettingsGap("dock.gap.reset")
        nodes += SettingsGroup(
            id = "dock.reset",
            children = listOf(
                settingsRow(
                    id = "dock.reset.row",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt4.homeGridEditorResetAction,
                    // 恢复排列不是危险操作（它只是把底栏拨回出厂三格）
                    action = SettingsAction.RESET_SCOPE,
                    actionTarget = RESET_TARGET,
                ),
            ),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStringsExt4.glassDockCustomizeTitle.key,
            title = SettingsStringsExt4.glassDockCustomizeTitle.text,
            nodes = nodes,
        )
    }

    /** 候选行：满 5 个后行尾写「已达上限」并禁用（:142-143 / :173-174）。 */
    private fun candidateRow(entry: DockCatalogEntry, canAdd: Boolean, groupPrefix: String): SettingsRow =
        settingsRow(
            id = "$groupPrefix.${entry.id}",
            component = MiuixRowComponent.ARROW,
            title = entry.title,
            details = if (canAdd) null else SettingsStringsExt4.homeGridEditorMaxReached,
            enabled = canAdd,
            action = SettingsAction.WRITE_SETTING,
            actionTarget = ADD_TARGET_PREFIX + entry.id,
        )

    /** 某个分类里**尚未启用**且当前环境可见的条目（Dart :155-162）。 */
    fun candidates(
        category: DockCategory,
        enabledIds: List<String>,
        debugBuild: Boolean,
    ): List<DockCatalogEntry> = catalog.filter {
        it.category == category && it.id !in enabledIds && (debugBuild || !it.debugOnly)
    }

    /** 按钮 id → 展示名（Dart `glassDockActionLabel`，:560-570）。未知 id 原样返回。 */
    fun labelOf(id: String): ArbText {
        VIEW_SWITCH_ACTIONS.firstOrNull { it.id == id }?.let { return it.title }
        catalog.firstOrNull { it.id == id }?.let { return it.title }
        return ArbText(NON_ARB_TEXT, id)
    }

    // -------------------------------------------------------------- 排列变换

    /** 添加（:65-70）：满 5 个或已存在时原样返回。 */
    fun add(editor: GlassDockEditorState, id: String): GlassDockEditorState {
        if (editor.enabledIds.size >= MAX_SLOTS || id in editor.enabledIds) return editor
        return editor.copy(enabledIds = editor.enabledIds + id)
    }

    /** 移除（:72-78）：至少留一个，否则原样返回。 */
    fun removeAt(editor: GlassDockEditorState, index: Int): GlassDockEditorState {
        if (editor.enabledIds.size <= 1) return editor
        if (index !in editor.enabledIds.indices) return editor
        return editor.copy(enabledIds = editor.enabledIds.filterIndexed { i, _ -> i != index })
    }

    /**
     * 拖动排序（:57-63）：把 [from] 的元素搬到 [to]。
     *
     * Dart 用 `onReorderItem`，框架已经校正过「下移」时的插入位，所以这里
     * 直接 remove + insert，不再减一。越界原样返回。
     */
    fun move(editor: GlassDockEditorState, from: Int, to: Int): GlassDockEditorState {
        val ids = editor.enabledIds
        if (from !in ids.indices || to !in ids.indices) return editor
        val next = ids.toMutableList()
        val moved = next.removeAt(from)
        next.add(to, moved)
        return editor.copy(enabledIds = next)
    }

    /** 恢复默认排列（:80-82）。 */
    fun reset(editor: GlassDockEditorState): GlassDockEditorState =
        editor.copy(enabledIds = DEFAULT_ACTIONS)

    /**
     * 种子阶段过滤（:26-37）：丢弃未知 id 与当前环境不可见（正式包看不到调试项）的 id。
     *
     * 与 Dart 的 `_isAvailable` 同口径：日/周恒可用，其余查目录的 `visible()`。
     */
    fun sanitize(initialIds: List<String>, debugBuild: Boolean): List<String> = initialIds.filter { id ->
        if (id == ACTION_DAY || id == ACTION_WEEK) {
            true
        } else {
            val entry = catalog.firstOrNull { it.id == id }
            entry != null && (debugBuild || !entry.debugOnly)
        }
    }

    /** 行尾动作目标前缀：`add:<id>` / `remove:<id>`，渲染层按前缀分发。 */
    const val ADD_TARGET_PREFIX = "add:"
    const val REMOVE_TARGET_PREFIX = "remove:"
}

/**
 * 底栏编辑器的一次交互输入（页面草稿 + 当前构建类型）。
 *
 * [debugBuild] 对应 Dart 的 `HomeMenuEntry.visible()` 门控：正式包看不到
 * 「内存状态」这类调试入口。
 */
data class GlassDockEditorState(
    val enabledIds: List<String> = SettingsGlassDockEditorPage.DEFAULT_ACTIONS,
    val debugBuild: Boolean = false,
)

/** 目录条目（`HomeMenuEntry` 的可迁移子集：id / 标题 / 分类 / 可见性门控）。 */
data class DockCatalogEntry(
    val id: String,
    val title: ArbText,
    val category: DockCategory,
    val debugOnly: Boolean = false,
)

/**
 * 目录分类（`HomeMenuEntryCategory`，`home_top_menu.dart:10`）。
 *
 * 声明顺序即屏上分组顺序，别按字母重排。
 */
enum class DockCategory(val arg: String, val label: ArbText) {
    FEATURES("features", SettingsStringsExt4.homeMenuCategoryFeatures),
    DATA("data", SettingsStringsExt4.homeMenuCategoryData),
    PREFERENCES("preferences", SettingsStringsExt4.homeMenuCategoryPreferences),
    ABOUT("about", SettingsStringsExt4.homeMenuCategoryAbout),
}
