package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 外观与配色页 + 主题管理页结构测试。
 *
 * 两页都在 `lib/screens/settings/settings_appearance.dart` 里：
 * `AppearanceSettingsScreen`（:18-429，5 个区块）与 `ThemeManageScreen`（:431-869，4 个区块）。
 * 期望值来源：Dart 源 + ARB。
 */
class SettingsAppearancePageTest {

    private fun spec(state: SettingsPageState = SettingsPageState()) =
        SettingsAppearancePage.spec(state)

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题取自 appearanceTitle`() {
        val page = spec()
        assertEquals("settings-appearance", page.id)
        assertEquals("appearanceTitle", page.titleKey)
        assertEquals("外观与配色", page.title)
        // settings_appearance.dart:101
    }

    @Test
    fun `五个区块的节点顺序`() {
        // settings_appearance.dart:110-375：预览 → 外观编辑入口 → 主题与显示 →
        // 应用主题色 → 恢复默认；除首块外每块前插一个 HyperosSectionGap
        assertEquals(
            listOf(
                "appearance.preview",
                "appearance.gap.editor",
                "appearance.editor",
                "appearance.gap.themeDisplay",
                "appearance.themeDisplay.label",
                "appearance.themeDisplay",
                "appearance.gap.themeSeed",
                "appearance.themeSeed.label",
                "appearance.themeSeed",
                "appearance.gap.resetOuter",
                "appearance.gap.reset",
                "appearance.reset",
            ),
            spec().topLevelIds(),
        )
    }

    @Test
    fun `恢复默认前有两个连续空档`() {
        // 忠实搬运：_buildAppearanceSection 给 index>0 插一个 gap（:373），
        // SettingsResetTile 自己又带一个（settings_reset.dart:209）→ 12+12dp。
        val ids = spec().topLevelIds()
        val resetIdx = ids.indexOf("appearance.reset")
        assertEquals("appearance.gap.resetOuter", ids[resetIdx - 2])
        assertEquals("appearance.gap.reset", ids[resetIdx - 1])
    }

    // -------------------------------------------------------------- 预览区

    @Test
    fun `预览卡三处文案`() {
        // settings_appearance.dart:116-193
        val preview = spec().flatten().filterIsInstance<SettingsInline>()
            .first { it.id == "appearance.preview" }
        assertEquals(InlineKind.PREVIEW_CARD, preview.kind)
        assertEquals("previewTitle", preview.labelKey)
        assertEquals("预览", preview.label)
        assertEquals(
            listOf("themeModeSystem", "fontModeSystem", "frostedSheetSectionTitle"),
            preview.texts.map { it.key },
        )
        assertEquals(listOf("跟随系统", "应用默认", "玻璃材质"), preview.texts.map { it.text })
    }

    @Test
    fun `预览卡随草稿跟随主题与字体档位`() {
        // :155 appThemeModeLabel / :162 appFontModeLabel
        val preview = spec(
            SettingsPageState(appThemeMode = AppThemeMode.DARK, appFontMode = AppFontMode.MI_SANS),
        ).flatten().filterIsInstance<SettingsInline>().first { it.id == "appearance.preview" }
        assertEquals(listOf("themeModeDark", "fontModeMiSans", "frostedSheetSectionTitle"), preview.texts.map { it.key })
        assertEquals(listOf("深色模式", "MiSans", "玻璃材质"), preview.texts.map { it.text })
    }

    // -------------------------------------------------------- 外观编辑入口

    @Test
    fun `外观编辑入口只留标题不带灰字`() {
        // :208-222（用户 2026-09-22 要求去掉灰字描述）
        val row = spec().row("appearance.editor.entry")
        assertEquals("appearanceEditorTitle", row.titleKey)
        assertEquals("外观编辑", row.title)
        assertNull("入口行不挂副标题", row.subtitle)
        assertNull(row.details)
        assertEquals(SettingsAction.NAVIGATE, row.action)
        assertEquals("/settings/appearance-editor", row.actionTarget)
    }

    // ---------------------------------------------------------- 主题与显示

    @Test
    fun `主题与显示组四行加实时预览`() {
        // :227-321（HyperosSettingsBlock 标题 + 四行 + 组内字号预览）
        assertEquals("appearanceThemeDisplaySectionTitle", spec().flatten()
            .filterIsInstance<SettingsLabel>().first { it.id == "appearance.themeDisplay.label" }.textKey)
        assertEquals(
            listOf(
                "appearance.themeMode",
                "appearance.fontMode",
                "appearance.fontWeight",
                "appearance.fontSize",
                "appearance.fontPreview",
            ),
            spec().group("appearance.themeDisplay").childIds(),
        )
    }

    @Test
    fun `主题模式三档顺序与选中值`() {
        // :231-241；枚举顺序 timetable_settings_enums.dart:12
        val row = spec(SettingsPageState(appThemeMode = AppThemeMode.LIGHT)).row("appearance.themeMode")
        assertEquals("主题模式", row.title)
        assertEquals(listOf("跟随系统", "浅色模式", "深色模式"), row.options.map { it.label })
        assertEquals(listOf("system", "light", "dark"), row.options.map { it.id })
        assertEquals("light", row.selectedOptionId)
    }

    @Test
    fun `字体选择十档顺序`() {
        // :242-263；枚举顺序 timetable_settings_enums.dart:14-25
        val row = spec().row("appearance.fontMode")
        assertEquals("字体选择", row.title)
        assertEquals(
            listOf("应用默认", "系统无衬线", "MiSans", "鸿蒙黑体", "OPPO Sans", "苹方", "Noto Sans", "衬线体", "宋体", "等宽体"),
            row.options.map { it.label },
        )
        assertEquals(
            listOf("system", "sansSerif", "miSans", "harmonyOS", "oppoSans", "pingFang", "notoSans", "serif", "songti", "monospace"),
            row.options.map { it.id },
        )
    }

    @Test
    fun `字重滑杆上下限与档数`() {
        // :266-279；kAppFontWeightMin/Max/Divisions 见 timetable_settings_enums.dart:29-31
        val row = spec(SettingsPageState(appFontWeight = 500)).row("appearance.fontWeight")
        assertEquals("字重", row.title)
        assertEquals(100.0, row.slider!!.min, 0.0)
        assertEquals(900.0, row.slider!!.max, 0.0)
        assertEquals(16, row.slider!!.divisions)
        assertEquals("w500", row.value)
    }

    @Test
    fun `字号滑杆上下限与默认读数`() {
        // :280-295；kAppTextScale* 见 timetable_settings_enums.dart:34-37
        val row = spec().row("appearance.fontSize")
        assertEquals("字号", row.title)
        assertEquals(0.85, row.slider!!.min, 0.0)
        assertEquals(1.6, row.slider!!.max, 0.0)
        assertEquals(15, row.slider!!.divisions)
        // 默认档给 ARB 的「默认」而不是 1.00（:286-288）
        assertEquals("默认", row.value)
        assertEquals("fontSizeDefault", row.valueKey)
        val scaled = spec(SettingsPageState(appTextScale = 1.2)).row("appearance.fontSize")
        assertEquals("1.20", scaled.value)
        assertNull(scaled.valueKey)
    }

    @Test
    fun `字重与字号滑杆的当前值`() {
        assertEquals(400.0, spec().row("appearance.fontWeight").sliderValue!!, 0.0)
        assertEquals(500.0, spec(SettingsPageState(appFontWeight = 500)).row("appearance.fontWeight").sliderValue!!, 0.0)
        assertEquals(1.0, spec().row("appearance.fontSize").sliderValue!!, 0.0)
        assertEquals(1.2, spec(SettingsPageState(appTextScale = 1.2)).row("appearance.fontSize").sliderValue!!, 0.0)
    }

    @Test
    fun `字号实时预览用样例句`() {
        // :297-318
        val preview = spec().flatten().filterIsInstance<SettingsInline>()
            .first { it.id == "appearance.fontPreview" }
        assertEquals(InlineKind.FONT_PREVIEW, preview.kind)
        assertEquals("fontPreviewSample", preview.texts.single().key)
        assertEquals("永 Aa Bb 0123 — 课表预览", preview.texts.single().text)
    }

    // ---------------------------------------------------------- 应用主题色

    @Test
    fun `主题管理入口带副标题并跳主题页`() {
        // :328-338
        val row = spec().row("appearance.themeManage")
        assertEquals("themeManageTitle", row.titleKey)
        assertEquals("主题管理", row.title)
        assertEquals("themeManageSubtitle", row.detailsKey)
        assertEquals("导出、导入和切换主题", row.details)
        assertEquals(SettingsAction.NAVIGATE, row.action)
        assertEquals("/settings/theme", row.actionTarget)
    }

    @Test
    fun `预设主题十一档带种子色`() {
        // :339-357；种子色 timetable_settings_enums.dart:73-85
        val row = spec(SettingsPageState(foruiTheme = ForuiTheme.VIOLET)).row("appearance.themePreset")
        assertEquals("预设主题", row.title)
        assertEquals("themeSeedSectionSubtitle", row.subtitleKey)
        assertEquals("影响顶部栏、强调色和全局主色调", row.subtitle)
        assertEquals(11, row.options.size)
        assertEquals(
            listOf("miui", "neutral", "zinc", "slate", "blue", "green", "orange", "red", "rose", "violet", "yellow"),
            row.options.map { it.id },
        )
        assertEquals(
            listOf("#3482FF", "#171717", "#18181B", "#0F172B", "#1447E6", "#5EA500", "#F54A00", "#E7000B", "#EC003F", "#7F22FE", "#FCC800"),
            row.options.map { it.seedHex },
        )
        assertEquals("violet", row.selectedOptionId)
    }

    // ------------------------------------------------------------ 恢复默认

    @Test
    fun `外观页恢复默认行带作用域说明`() {
        // :361-364 + settings_reset.dart:213-232（appearance 作用域有 _scopeNote）
        val row = spec().row("appearance.reset.row")
        assertEquals("settingsResetDefaultsTitle", row.titleKey)
        assertEquals("恢复默认设置", row.title)
        assertEquals("settingsResetScopeNoticeAppearance", row.subtitleKey)
        assertEquals("主题、字体与玻璃质感", row.subtitle)
        assertEquals(SettingsAction.RESET_SCOPE, row.action)
        assertEquals("appearance", row.actionTarget)
        assertTrue("恢复默认是不可撤销的批量写入，行要按危险色渲染", row.destructive)
    }

    // ------------------------------------------------------------ 主题管理页

    private fun themeSpec(state: SettingsPageState) = SettingsThemeManagePage.spec(state)

    @Test
    fun `主题管理页标题与区块顺序`() {
        // :450 `title: Text(l10n.themeManageTitle)`
        val page = themeSpec(SettingsPageState())
        assertEquals("settings-theme", page.id)
        assertEquals("themeManageTitle", page.titleKey)
        assertEquals("主题管理", page.title)
        // :462-609：0 当前主题（无存档 → 不渲染）· 1 动作 · 2 预设 · 3 我的主题（空 → 不渲染）
        assertEquals(
            listOf(
                "theme.gap.actions",
                "theme.actions.label",
                "theme.actions",
                "theme.gap.presets",
                "theme.presets.label",
                "theme.presets",
            ),
            page.topLevelIds(),
        )
    }

    @Test
    fun `当前主题卡在有存档时才出现`() {
        // :466-505（checkpointName == null → SizedBox.shrink）
        val none = themeSpec(SettingsPageState())
        assertFalse(none.topLevelIds().contains("theme.current"))

        val card = themeSpec(SettingsPageState(themeCheckpointName = "小米"))
            .flatten().filterIsInstance<SettingsInline>().single { it.id == "theme.current" }
        assertEquals(InlineKind.CONTROL_CARD, card.kind)
        assertEquals("themeCurrentTheme", card.labelKey)
        assertEquals("当前主题", card.label)
        assertEquals("小米", card.value)
        assertNull("未修改时不显示两个按钮", card.valueKey)
        assertTrue(card.texts.isEmpty())
    }

    @Test
    fun `当前主题被改过时显示基于某主题已修改与两个按钮`() {
        // :473-475 subtitle = themeBasedOnModified(checkpointName)，:476-502 两个按钮
        val card = themeSpec(
            SettingsPageState(themeCheckpointName = "小米", themeHasModifications = true),
        ).flatten().filterIsInstance<SettingsInline>().single { it.id == "theme.current" }
        assertEquals("themeBasedOnModified", card.valueKey)
        assertEquals("基于 小米 已修改", card.value)
        assertEquals(listOf("themeResetToPreset", "themeSaveCurrent"), card.texts.map { it.key })
        assertEquals(listOf("重置", "保存当前主题"), card.texts.map { it.text })
    }

    @Test
    fun `主题管理三个动作行`() {
        // :512-530
        val page = themeSpec(SettingsPageState())
        assertEquals(
            listOf("theme.export", "theme.import", "theme.save"),
            page.group("theme.actions").childRowIds(),
        )
        assertEquals(listOf("导出主题", "导入主题", "保存当前主题"), listOf(
            page.row("theme.export").title,
            page.row("theme.import").title,
            page.row("theme.save").title,
        ))
        assertEquals(SettingsAction.CLIPBOARD_EXPORT, page.row("theme.export").action)
        assertEquals(SettingsAction.CLIPBOARD_IMPORT, page.row("theme.import").action)
        assertEquals(SettingsAction.DIALOG, page.row("theme.save").action)
    }

    @Test
    fun `预设主题十一行单选`() {
        // :533-558
        val page = themeSpec(SettingsPageState(foruiTheme = ForuiTheme.GREEN))
        val rows = page.group("theme.presets").children.filterIsInstance<SettingsRow>()
        assertEquals(11, rows.size)
        assertTrue("预设行用单选组件", rows.all { it.component == MiuixRowComponent.RADIO })
        assertEquals(1, rows.count { it.selectedOptionId == "green" })
        assertEquals(
            listOf("#3482FF", "#171717", "#18181B", "#0F172B", "#1447E6", "#5EA500", "#F54A00", "#E7000B", "#EC003F", "#7F22FE", "#FCC800"),
            rows.map { it.options.single().seedHex },
        )
    }

    @Test
    fun `我的主题区块只在有存档主题时出现`() {
        // :560-607
        assertFalse(themeSpec(SettingsPageState()).topLevelIds().contains("theme.saved"))
        val page = themeSpec(
            SettingsPageState(
                savedThemes = listOf(
                    SavedThemeRow(id = "t1", name = "冬季配色", selected = true, previewColors = listOf("#3482FF", "#0E8043")),
                    SavedThemeRow(id = "t2", name = "夏季配色", selected = false),
                ),
            ),
        )
        assertEquals("themeSaved", page.flatten().filterIsInstance<SettingsLabel>()
            .first { it.id == "theme.saved.label" }.textKey)
        assertEquals(listOf("theme.saved.t1", "theme.saved.t2"), page.group("theme.saved").childRowIds())
        assertEquals(listOf("冬季配色", "夏季配色"), page.group("theme.saved").children
            .filterIsInstance<SettingsRow>().map { it.title })
        assertEquals("themeMoreActions", page.row("theme.saved.t1").trailingActionKey)
        assertEquals("更多操作", page.row("theme.saved.t1").trailingAction)
        assertEquals(SettingsAction.SHEET, page.row("theme.saved.t1").trailingActionKind)
        assertEquals(listOf("#3482FF", "#0E8043"), page.row("theme.saved.t1").previewColors)
        assertEquals("t1", page.group("theme.saved").children.filterIsInstance<SettingsRow>()
            .first { it.selectedOptionId != null }.selectedOptionId)
    }
}
