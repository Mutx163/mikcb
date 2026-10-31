package com.mutx163.qingyu.pages.settings

import java.util.Locale

/**
 * 外观与配色页 + 主题管理页结构模型。
 *
 * 两页同在 `lib/screens/settings/settings_appearance.dart`：
 * `AppearanceSettingsScreen`（:18-429，5 个区块）与 `ThemeManageScreen`（:431-869，4 个区块）。
 *
 * ## 逐项对照（外观页）
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: appearanceTitle)`（:99-101） | `titleKey/title` | `basic.TopAppBar` |
 * | 区块 0 主题预览卡（:116-193） | `SettingsInline(PREVIEW_CARD)` | 官方无对应物：微缩预览是应用自绘 |
 * | 区块 1 `HyperosListTile(appearanceEditorTitle)`（:208-223） | `appearance.editor.entry` | `MiuixArrowPreference` |
 * | `HyperosSettingsBlock(主题与显示)`（:227-321） | `SettingsLabel` + `SettingsGroup` | preference category |
 * | `HyperosSelectTile<AppThemeMode>`（:231-241） | `appearance.themeMode` | `MiuixOverlayDropdownPreference` |
 * | `HyperosSelectTile<AppFontMode>`（:242-263） | `appearance.fontMode` | 同上（弹层 `useSheetForPopup`） |
 * | `HyperosSliderTile(字重)`（:266-279） | `appearance.fontWeight` | `MiuixSliderPreference` |
 * | `HyperosSliderTile(字号)`（:280-295） | `appearance.fontSize` | `MiuixSliderPreference` |
 * | 字号实时预览（:297-318） | `SettingsInline(FONT_PREVIEW)` | 官方无对应物：样例句预览 |
 * | `HyperosListTile(主题管理)`（:328-338） | `appearance.themeManage` | `MiuixArrowPreference` |
 * | `HyperosSelectTile<ForuiTheme>`（:339-357） | `appearance.themePreset` | `MiuixOverlayDropdownPreference` |
 * | `SettingsResetTile(appearance)`（:361-364） | `appearance.reset.row` | `MiuixArrowPreference`（危险色） |
 *
 * ## 逐项对照（主题管理页）
 *
 * | Flutter | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosControlCard(当前主题)`（:471-504） | `SettingsInline(CONTROL_CARD)` | `basic.Card` + 官方 `Button` |
 * | `HyperosActionTile`×3（:515-529） | `theme.export/import/save` | `MiuixArrowPreference`（前两行带分隔线） |
 * | `HyperosChoiceTile`×11（:545-553） | `theme.preset.*` | `MiuixRadioButtonPreference`（行首色点） |
 * | `HyperosChoiceTile(savedThemes)`（:574-602） | `theme.saved.*` | `MiuixRadioButtonPreference` + 行尾更多按钮 |
 *
 * ## 两处「忠实搬运的连续空档」
 *
 * `_buildAppearanceSection` 给每个非首块前插一个 `HyperosSectionGap`（:373），
 * 而 `SettingsResetTile` 自带一个（`settings_reset.dart:209`）→ 恢复默认前是
 * **两个 12dp 空档**（合计 24dp）。本模型照搬不合并：合并属于改外观，
 * 不在「像素对齐」的范围内偷偷做。
 *
 * ## 未纳入本模型的两件事（都在别的文件、不属本泳道三个 Dart 源）
 *
 * 1. `FrostedAppearanceScope`（:97-98）把草稿材质喂给整棵子树——渲染层接线；
 * 2. 主题管理页的动作弹层（重命名/复制/删除、预览/确认）在
 *    `lib/widgets/theme_manage_sheets.dart`，属另一个文件，本模型只保留
 *    「更多操作」这个入口的 tooltip 文案（`themeMoreActions`）。
 */
object SettingsAppearancePage {

    const val ID = "settings-appearance"

    /** 与 Dart 常量同值（`timetable_settings_enums.dart:29-37`）。 */
    private const val WEIGHT_MIN = 100.0
    private const val WEIGHT_MAX = 900.0
    private const val WEIGHT_DIVISIONS = 16
    private const val TEXT_SCALE_MIN = 0.85
    private const val TEXT_SCALE_MAX = 1.6
    private const val TEXT_SCALE_DIVISIONS = 15
    private const val TEXT_SCALE_DEFAULT = 1.0

    fun spec(state: SettingsPageState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()

        // 区块 0：主题预览（无前导空档）
        nodes += SettingsInline(
            id = "appearance.preview",
            kind = InlineKind.PREVIEW_CARD,
            note = "主题/字体档位的微缩预览（settings_appearance.dart:116-193）：官方没有预览卡，" +
                "两块 72dp 色块与文字由应用自绘，颜色走 theme/ 桥",
            labelKey = SettingsStrings.previewTitle.key,
            label = SettingsStrings.previewTitle.zh,
            texts = listOf(
                inlineText(state.appThemeMode.label),
                inlineText(state.appFontMode.label),
                inlineText(SettingsStrings.frostedSheetSectionTitle),
            ),
        )

        // 区块 1：外观编辑固定入口
        nodes += SettingsGap("appearance.gap.editor")
        nodes += SettingsGroup(
            id = "appearance.editor",
            children = listOf(
                settingsRow(
                    id = "appearance.editor.entry",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.appearanceEditorTitle,
                    // 只留标题：用户 2026-09-22 明确「灰字描述不符合软件标准，去掉」（:200-203）
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_APPEARANCE_EDITOR,
                ),
            ),
        )

        // 区块 2：主题与显示
        nodes += SettingsGap("appearance.gap.themeDisplay")
        nodes += SettingsLabel(
            id = "appearance.themeDisplay.label",
            textKey = SettingsStrings.appearanceThemeDisplaySectionTitle.key,
            text = SettingsStrings.appearanceThemeDisplaySectionTitle.zh,
        )
        nodes += SettingsGroup(
            id = "appearance.themeDisplay",
            children = listOf(
                settingsRow(
                    id = "appearance.themeMode",
                    component = MiuixRowComponent.DROPDOWN,
                    title = SettingsStrings.themeModeLabel,
                    options = AppThemeMode.entries.map { option(it.value, it.label) },
                    selectedOptionId = state.appThemeMode.value,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "appearance.fontMode",
                    component = MiuixRowComponent.DROPDOWN,
                    title = SettingsStrings.fontModeLabel,
                    options = AppFontMode.entries.map { option(it.value, it.label) },
                    selectedOptionId = state.appFontMode.value,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "appearance.fontWeight",
                    component = MiuixRowComponent.SLIDER,
                    title = SettingsStrings.fontWeightLabel,
                    value = "w${state.appFontWeight}",
                    slider = SettingsSliderSpec(
                        min = WEIGHT_MIN,
                        max = WEIGHT_MAX,
                        divisions = WEIGHT_DIVISIONS,
                        defaultValue = 400.0,
                    ),
                    sliderValue = state.appFontWeight.toDouble(),
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "appearance.fontSize",
                    component = MiuixRowComponent.SLIDER,
                    title = SettingsStrings.fontSizeLabel,
                    // 默认档给「默认」而不是 1.00（:286-288）
                    valueKey = if (state.appTextScale == TEXT_SCALE_DEFAULT) {
                        SettingsStrings.fontSizeDefault.key
                    } else {
                        null
                    },
                    value = if (state.appTextScale == TEXT_SCALE_DEFAULT) {
                        SettingsStrings.fontSizeDefault.zh
                    } else {
                        "%.2f".format(Locale.ROOT, state.appTextScale)
                    },
                    slider = SettingsSliderSpec(
                        min = TEXT_SCALE_MIN,
                        max = TEXT_SCALE_MAX,
                        divisions = TEXT_SCALE_DIVISIONS,
                        defaultValue = TEXT_SCALE_DEFAULT,
                    ),
                    sliderValue = state.appTextScale,
                    action = SettingsAction.WRITE_SETTING,
                ),
                SettingsInline(
                    id = "appearance.fontPreview",
                    kind = InlineKind.FONT_PREVIEW,
                    note = "字号/字重/字族的所见即所得样例句（:297-318）：在分组卡内，" +
                        "官方没有样例句控件",
                    texts = listOf(inlineText(SettingsStrings.fontPreviewSample)),
                ),
            ),
        )

        // 区块 3：应用主题色
        nodes += SettingsGap("appearance.gap.themeSeed")
        nodes += SettingsLabel(
            id = "appearance.themeSeed.label",
            textKey = SettingsStrings.themeSeedSectionTitle.key,
            text = SettingsStrings.themeSeedSectionTitle.zh,
        )
        nodes += SettingsGroup(
            id = "appearance.themeSeed",
            children = listOf(
                settingsRow(
                    id = "appearance.themeManage",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.themeManageTitle,
                    details = SettingsStrings.themeManageSubtitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = ROUTE_THEME_MANAGE,
                ),
                settingsRow(
                    id = "appearance.themePreset",
                    component = MiuixRowComponent.DROPDOWN,
                    title = SettingsStrings.themePreset,
                    subtitle = SettingsStrings.themeSeedSectionSubtitle,
                    options = ForuiTheme.entries.map { option(it.value, it.label, it.seedHex) },
                    selectedOptionId = state.foruiTheme.value,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        // 区块 4：恢复默认（忠实搬运：外层 gap + SettingsResetTile 自带 gap）
        nodes += SettingsGap("appearance.gap.resetOuter")
        nodes += SettingsGap("appearance.gap.reset")
        nodes += SettingsGroup(
            id = "appearance.reset",
            children = listOf(
                settingsRow(
                    id = "appearance.reset.row",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.settingsResetDefaultsTitle,
                    subtitle = SettingsStrings.settingsResetScopeNoticeAppearance,
                    destructive = true,
                    action = SettingsAction.RESET_SCOPE,
                    actionTarget = RESET_SCOPE_APPEARANCE,
                ),
            ),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStrings.appearanceTitle.key,
            title = SettingsStrings.appearanceTitle.zh,
            nodes = nodes,
        )
    }

    /** 路由名（`settings_appearance.dart:216,334`）。 */
    const val ROUTE_APPEARANCE_EDITOR = "/settings/appearance-editor"
    const val ROUTE_THEME_MANAGE = "/settings/theme"

    /** `SettingsResetScope.appearance`（`settings_reset.dart:22-23`）。 */
    const val RESET_SCOPE_APPEARANCE = "appearance"

    private fun inlineText(text: ArbText) = SettingsInlineText(text.key, text.zh)
}

/**
 * 主题管理页（`settings_appearance.dart:431-869`）结构模型。
 *
 * 四个区块都是条件渲染的：0 无主题存档 → 不渲染；3 无已存主题 → 不渲染。
 */
object SettingsThemeManagePage {

    const val ID = "settings-theme"

    /**
     * 「我的主题」区块里那三行的行 id（导出 / 导入 / 保存当前主题）。
     *
     * 2026-10-29 补口：宿主 `SettingsHost.handleIntent` 要按 rowId 认「保存当前主题」这一行
     * 该弹哪个对话框，所以 id 必须有唯一出处——页面模型定义、宿主引用，不许两边各写一串字面量。
     */
    const val ROW_EXPORT = "theme.export"
    const val ROW_IMPORT = "theme.import"
    const val ROW_SAVE_CURRENT = "theme.save"

    fun spec(state: SettingsPageState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()

        // 区块 0：当前主题（有存档才渲染）
        val checkpoint = state.themeCheckpointName
        if (checkpoint != null) {
            nodes += SettingsInline(
                id = "theme.current",
                kind = InlineKind.CONTROL_CARD,
                note = "控制卡头（settings_appearance.dart:471-504）：有未保存改动时挂两个官方 Button",
                labelKey = SettingsStrings.themeCurrentTheme.key,
                label = SettingsStrings.themeCurrentTheme.zh,
                valueKey = if (state.themeHasModifications) {
                    SettingsStrings.themeBasedOnModified.key
                } else {
                    null
                },
                value = if (state.themeHasModifications) {
                    SettingsStrings.themeBasedOnModified.filled("baseName", checkpoint)
                } else {
                    checkpoint
                },
                texts = if (state.themeHasModifications) {
                    listOf(
                        SettingsInlineText(
                            SettingsStrings.themeResetToPreset.key,
                            SettingsStrings.themeResetToPreset.zh,
                        ),
                        SettingsInlineText(
                            SettingsStrings.themeSaveCurrent.key,
                            SettingsStrings.themeSaveCurrent.zh,
                        ),
                    )
                } else {
                    emptyList()
                },
            )
        }

        // 区块 1：导出 / 导入 / 保存当前主题
        nodes += SettingsGap("theme.gap.actions")
        nodes += SettingsLabel(
            id = "theme.actions.label",
            textKey = SettingsStrings.themeManageSubtitle.key,
            text = SettingsStrings.themeManageSubtitle.zh,
        )
        nodes += SettingsGroup(
            id = "theme.actions",
            children = listOf(
                settingsRow(
                    id = ROW_EXPORT,
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.themeExport,
                    action = SettingsAction.CLIPBOARD_EXPORT,
                ),
                settingsRow(
                    id = ROW_IMPORT,
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.themeImport,
                    action = SettingsAction.CLIPBOARD_IMPORT,
                ),
                settingsRow(
                    id = ROW_SAVE_CURRENT,
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.themeSaveCurrent,
                    action = SettingsAction.DIALOG,
                ),
            ),
        )

        // 区块 2：预设主题（十一档，单选）
        nodes += SettingsGap("theme.gap.presets")
        nodes += SettingsLabel(
            id = "theme.presets.label",
            textKey = SettingsStrings.themePreset.key,
            text = SettingsStrings.themePreset.zh,
        )
        nodes += SettingsGroup(
            id = "theme.presets",
            children = ForuiTheme.entries.map { theme ->
                settingsRow(
                    id = "theme.preset.${theme.value}",
                    component = MiuixRowComponent.RADIO,
                    title = theme.label,
                    options = listOf(option(theme.value, theme.label, theme.seedHex)),
                    selectedOptionId = theme.value.takeIf { it == state.foruiTheme.value },
                    action = SettingsAction.WRITE_SETTING,
                )
            },
        )

        // 区块 3：我的主题（有存档主题才渲染）
        if (state.savedThemes.isNotEmpty()) {
            nodes += SettingsGap("theme.gap.saved")
            nodes += SettingsLabel(
                id = "theme.saved.label",
                textKey = SettingsStrings.themeSaved.key,
                text = SettingsStrings.themeSaved.zh,
            )
            nodes += SettingsGroup(
                id = "theme.saved",
                children = state.savedThemes.map { saved ->
                    settingsRow(
                        id = "theme.saved.${saved.id}",
                        component = MiuixRowComponent.RADIO,
                        // 主题名是用户数据，不来自 ARB（NON_ARB_TEXT 让对照测试跳过）
                        title = ArbText(NON_ARB_TEXT, saved.name),
                        options = listOf(nativeOption(saved.id, saved.name)),
                        selectedOptionId = saved.id.takeIf { saved.selected },
                        previewColors = saved.previewColors,
                        action = SettingsAction.SHEET,
                        trailingActionKey = SettingsStrings.themeMoreActions.key,
                        trailingAction = SettingsStrings.themeMoreActions.zh,
                        trailingActionKind = SettingsAction.SHEET,
                    )
                },
            )
        }

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStrings.themeManageTitle.key,
            title = SettingsStrings.themeManageTitle.zh,
            nodes = nodes,
        )
    }
}
