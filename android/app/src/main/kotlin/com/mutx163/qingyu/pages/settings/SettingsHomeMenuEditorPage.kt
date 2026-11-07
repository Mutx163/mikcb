package com.mutx163.qingyu.pages.settings

/**
 * 八宫格按钮自定义编辑器（`lib/screens/settings/settings_home_menu_editor.dart`，
 * 328 行）结构模型。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: homeMenuCustomizeTitle)`（:84-86） | `titleKey/title` | `basic.TopAppBar` |
 * | `_buildPreviewCard`（:149-200） | `SettingsInline(PREVIEW_CARD)` | 官方无对应物：瓷贴预览 |
 * | `HyperosSectionLabel(已启用)`（:91） | `homeMenuEditor.enabled.label` | preference category |
 * | `ReorderableListView`（:202-246） | `homeMenuEditor.enabled.<id>` | 官方无 `Super*` 拖动排序行，见下 |
 * | `HyperosSectionDescription(homeGridEditorHintBody)`（:93-95） | `homeMenuEditor.hint` | 整宽说明 |
 * | 每个分类 `HyperosListGroup`（:134-146） | `homeMenuEditor.category.<cat>` | preference category + 组 |
 * | `HyperosListTile(恢复默认排列)`（:104-111） | `homeMenuEditor.reset.row` | `MiuixArrowPreference` |
 *
 * ## 一处「官方没有对应物」，评审要看这里
 *
 * 「已启用」列表是**可拖动排序 + 行尾移除按钮**的行（`_GridSlotRow`，:252-327：
 * 56dp 行高、行首拖动手柄、行中图标徽章、行尾红色移除按钮）。官方 0.8.8 的
 * `extra.Super*` 家族里没有任何可拖动排序的偏好行，所以模型里用
 * [MiuixRowComponent.ARROW] 承担「行体 + 行首徽章 + 行尾动作」，拖动能力由渲染层
 * 用官方 `ReorderableListView`-等价的 Compose 机制补；行尾那个「移除」图标按钮
 * 通过 [SettingsRow.trailingActionKind] 接线。**这是本页唯一的自绘白名单项**。
 *
 * ## 三条最容易写反的
 *
 * 1. **钉住的 `settings` 不可移除，但仍显示在列表里**（:229-243）：不可移除 ≠ 看不见；
 * 2. **只剩一个入口时全列不可移除**（`_canRemove => _ids.length > 1`，:44）：
 *    此时提示文案仍是「移除」（不可移除的原因不是「钉住」）；
 * 3. **某分类候选全启用时给一句说明而不是空组**（:131-133）。
 *
 * ## 本页不持业务状态
 *
 * 它是纯草稿视图：每次改动都 `widget.onChanged(List.of(next))` 交给宿主页落盘
 * （:8-11 / :46-51），本模型只描述「此刻屏上有哪些行」。
 */
object SettingsHomeMenuEditorPage {

    const val ID = "settings-home-menu-editor"

    /** `HomeGridMenu.maxSlots`（`timetable_settings_enums.dart:162`）。 */
    const val MAX_SLOTS = 8

    /** `HomeGridMenu.pinnedActionId`（`timetable_settings_enums.dart:170`）。 */
    const val PINNED_ACTION_ID = "settings"

    /** `HomeGridMenu.defaultActions`（`timetable_settings_enums.dart:173-182`）。 */
    val DEFAULT_ACTIONS: List<String> = listOf(
        "overview", "statistics", "addCourse", "exams",
        "tasks", "importCourses", "settings", "support",
    )

    /** 分类顺序（`HomeMenuEntryCategory`，`home_top_menu.dart:10`）。 */
    val CATEGORIES: List<String> = listOf("features", "data", "preferences", "about")

    /** 分类小标题的 ARB 文案（`homeMenuEntryCategoryLabel`，`home_top_menu.dart:12-20`）。 */
    private fun categoryLabel(category: String): ArbText = when (category) {
        "features" -> SettingsStringsExt2.homeMenuCategoryFeatures
        "data" -> SettingsStringsExt2.homeMenuCategoryData
        "preferences" -> SettingsStringsExt2.homeMenuCategoryPreferences
        else -> SettingsStringsExt2.homeMenuCategoryAbout
    }

    fun spec(state: SettingsHomeMenuEditorState): SettingsPageSpec {
        val enabledIds = sanitizeSeed(state.enabledIds, state.diagnosticsBuild)
        val nodes = mutableListOf<SettingsNode>()

        // 预览卡（:89）
        nodes += SettingsInline(
            id = "homeMenuEditor.preview",
            kind = InlineKind.PREVIEW_CARD,
            note = "八宫格瓷贴预览（:149-200）：官方没有「图标 + 名称的瓷贴行」，" +
                "瓷贴底色取主题 seed 的强调色、由应用自绘",
            texts = enabledIds.map { id ->
                val label = entryLabel(id)
                SettingsInlineText(label.key, label.text)
            },
        )

        // 「已启用」标题 + 可排序列表（:90-92）
        nodes += SettingsGap("homeMenuEditor.gap.preview")
        nodes += SettingsLabel(
            id = "homeMenuEditor.enabled.label",
            textKey = SettingsStringsExt2.homeGridEditorEnabledTitle.key,
            text = SettingsStringsExt2.homeGridEditorEnabledTitle.text,
        )
        nodes += SettingsGroup(
            id = "homeMenuEditor.enabled",
            children = enabledIds.map { id -> enabledRow(id, enabledIds) },
        )

        // 槽位上限说明（:93-95）
        nodes += SettingsDescription(
            id = "homeMenuEditor.hint",
            textKey = SettingsStringsExt2.homeGridEditorHintBody.key,
            text = SettingsStringsExt2.homeGridEditorHintBody.filled("max", MAX_SLOTS.toString()),
        )

        // 各分类候选（:96-102）
        CATEGORIES.forEach { category ->
            nodes += SettingsGap("homeMenuEditor.gap.category.$category")
            nodes += SettingsLabel(
                id = "homeMenuEditor.category.$category.label",
                textKey = categoryLabel(category).key,
                text = categoryLabel(category).text,
            )
            val candidates = candidatesFor(category, enabledIds, state.diagnosticsBuild)
            if (candidates.isEmpty()) {
                // 全部启用时给一句说明，而不是空白组（:131-133）
                nodes += SettingsDescription(
                    id = "homeMenuEditor.category.$category.empty",
                    textKey = SettingsStringsExt2.homeGridEditorAllAdded.key,
                    text = SettingsStringsExt2.homeGridEditorAllAdded.text,
                )
            } else {
                val canAdd = enabledIds.size < MAX_SLOTS
                nodes += SettingsGroup(
                    id = "homeMenuEditor.category.$category",
                    children = candidates.map { entry ->
                        settingsRow(
                            id = "homeMenuEditor.candidate.${entry.id}",
                            component = MiuixRowComponent.ARROW,
                            title = entry.label,
                            // 满格时行尾写「已达上限」并禁用（:141-142）
                            details = if (canAdd) null else SettingsStringsExt2.homeGridEditorMaxReached,
                            enabled = canAdd,
                            action = SettingsAction.WRITE_SETTING,
                            actionTarget = entry.id,
                        )
                    },
                )
            }
        }

        // 恢复默认排列（:103-111）
        nodes += SettingsGap("homeMenuEditor.gap.reset")
        nodes += SettingsGroup(
            id = "homeMenuEditor.reset",
            children = listOf(
                settingsRow(
                    id = "homeMenuEditor.reset.row",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt2.homeGridEditorResetAction,
                    action = SettingsAction.WRITE_SETTING,
                    actionTarget = "reset",
                ),
            ),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStringsExt2.homeMenuCustomizeTitle.key,
            title = SettingsStringsExt2.homeMenuCustomizeTitle.text,
            nodes = nodes,
        )
    }

    // ------------------------------------------------------------------- 行构造

    /**
     * 「已启用」里的一行（:226-244）。
     *
     * [enabled] 同时承担两件事：行是否可点（这里恒为「不可点」，因为整行的动作是
     * 拖动排序，不是点击），以及行尾移除按钮是否可用。模型用 `enabled` 表达后者
     * ——渲染层读到的就是「这一行的移除按钮能不能按」。
     */
    private fun enabledRow(id: String, enabledIds: List<String>): SettingsRow {
        val canRemove = enabledIds.size > 1
        val pinned = id == PINNED_ACTION_ID
        val removeEnabled = canRemove && !pinned
        return settingsRow(
            id = "homeMenuEditor.enabled.$id",
            component = MiuixRowComponent.ARROW,
            title = entryLabel(id),
            // 行本身不导航：整行是拖动排序的抓取区（:282-298）
            enabled = removeEnabled,
            action = null,
            trailingActionKey = if (pinned) {
                SettingsStringsExt2.homeGridEditorPinnedTooltip.key
            } else {
                SettingsStringsExt2.homeGridEditorRemoveTooltip.key
            },
            trailingAction = if (pinned) {
                SettingsStringsExt2.homeGridEditorPinnedTooltip.text
            } else {
                SettingsStringsExt2.homeGridEditorRemoveTooltip.text
            },
            trailingActionKind = SettingsAction.DIALOG,
            actionTarget = id,
        )
    }

    // --------------------------------------------------------------- 纯函数行为

    /**
     * 种子清洗（:33-38）。
     *
     * 进来时的排列可能是旧版本/别的构建写下的：丢掉解析不到的 id、丢掉当前构建
     * 不可见的条目，去重保序。Dart 侧还会在解析时再丢一次（`resolveHomeGridMenuEntries`），
     * 这里一次做完。
     */
    fun sanitizeSeed(raw: List<String>, diagnosticsBuild: Boolean): List<String> {
        val visible = SettingsHomeNavigationPage.catalog(diagnosticsBuild)
            .filter { it.visible(diagnosticsBuild) }
            .associateBy { it.id }
        val out = mutableListOf<String>()
        raw.forEach { id ->
            if (visible.containsKey(id) && id !in out) out += id
        }
        return out
    }

    /** 某分类下**尚未启用**的候选（:123-130）。 */
    fun candidatesFor(
        category: String,
        enabledIds: List<String>,
        diagnosticsBuild: Boolean,
    ): List<SettingsHomeNavigationPage.CatalogEntry> =
        SettingsHomeNavigationPage.catalog(diagnosticsBuild)
            .filter { it.category == category && it.visible(diagnosticsBuild) && it.id !in enabledIds }

    /** 目录标题（:188 `homeMenuEntryById(id)?.title(l10n) ?? id`）。 */
    private fun entryLabel(id: String): ArbText =
        SettingsHomeNavigationPage.catalog(false).firstOrNull { it.id == id }?.label
            ?: ArbText(NON_ARB_TEXT, id)
}
