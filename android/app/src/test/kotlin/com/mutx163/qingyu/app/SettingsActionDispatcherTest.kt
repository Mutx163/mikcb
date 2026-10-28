package com.mutx163.qingyu.app

import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsAppearancePage
import com.mutx163.qingyu.pages.settings.SettingsCourseCardPage
import com.mutx163.qingyu.pages.settings.SettingsGeneralPage
import com.mutx163.qingyu.pages.settings.SettingsGroup
import com.mutx163.qingyu.pages.settings.SettingsPageBridge
import com.mutx163.qingyu.pages.settings.SettingsPageSpec
import com.mutx163.qingyu.pages.settings.SettingsRow
import com.mutx163.qingyu.pages.settings.SettingsThemeManagePage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 设置族动作分派器单测（Phase 3.5 · 设置族竖切第一刀）。
 *
 * 期望值全部**手推**（照 Dart 出处一条条推），不从实现里抄：
 * - 主题预设联动：`lib/screens/settings/settings_appearance.dart:352-353` / `:721-722`
 * - 文字颜色联动：`lib/widgets/timetable_text_color_settings.dart:67-81` / `:101-111`
 * - 恢复默认作用域：`lib/screens/settings/settings_reset.dart:50-73` / `:128-157`
 * - 读侧默认与规范化：`lib/models/timetable_settings.dart`（键的行号写在模型字段上）
 */
class SettingsActionDispatcherTest {

    private val defaults = TimetableSettingsModel()

    // ================================================================
    // 1. 每条 SettingsAction 至少一例
    // ================================================================

    @Test
    fun `NAVIGATE 带路由时推页 缺路由时记 Ignored`() {
        assertEquals(
            SettingsDispatch.Navigate(SettingsAppearancePage.ROUTE_APPEARANCE_EDITOR, "appearance.editor.entry"),
            dispatch(SettingsActionKind.NAVIGATE, SettingsAppearancePage.ROUTE_APPEARANCE_EDITOR, "appearance.editor.entry"),
        )
        val ignored = dispatch(SettingsActionKind.NAVIGATE, null, "some.row") as SettingsDispatch.Ignored
        assertTrue(ignored.reason.contains("缺少路由"))
    }

    @Test
    fun `SHEET 与 DIALOG 原样转成意图`() {
        assertEquals(
            SettingsDispatch.ShowSheet(null, "theme.saved.t1"),
            dispatch(SettingsActionKind.SHEET, null, "theme.saved.t1"),
        )
        assertEquals(
            SettingsDispatch.ShowDialog(null, "theme.save"),
            dispatch(SettingsActionKind.DIALOG, null, "theme.save"),
        )
    }

    @Test
    fun `RESET_SCOPE 先出确认意图 缺作用域记 Ignored`() {
        assertEquals(
            SettingsDispatch.ConfirmReset(SettingsCourseCardPage.RESET_SCOPE_COURSE_CARD, "courseCard.reset.row"),
            dispatch(SettingsActionKind.RESET_SCOPE, SettingsCourseCardPage.RESET_SCOPE_COURSE_CARD, "courseCard.reset.row"),
        )
        val ignored = dispatch(SettingsActionKind.RESET_SCOPE, null, "x") as SettingsDispatch.Ignored
        assertTrue(ignored.reason.contains("缺少作用域"))
    }

    @Test
    fun `剪贴板与立刻执行三件套`() {
        assertEquals(SettingsDispatch.ClipboardExport("theme.export"), dispatch(SettingsActionKind.CLIPBOARD_EXPORT, null, "theme.export"))
        assertEquals(SettingsDispatch.ClipboardImport("theme.import"), dispatch(SettingsActionKind.CLIPBOARD_IMPORT, null, "theme.import"))
        assertEquals(SettingsDispatch.RunNow("general.autoRefresh.tryNow"), dispatch(SettingsActionKind.RUN_NOW, null, "general.autoRefresh.tryNow"))
    }

    @Test
    fun `选色器 材质面板 重新配色三种弹层`() {
        assertEquals(
            SettingsDispatch.ShowColorPicker(SettingsActionDispatcher.ROW_CARD_TEXT_LIGHT_TITLE),
            dispatch(SettingsActionKind.COLOR_PICKER, null, SettingsActionDispatcher.ROW_CARD_TEXT_LIGHT_TITLE),
        )
        assertEquals(
            SettingsDispatch.ShowMaterialPanel(SettingsAppearancePage.ROUTE_APPEARANCE_EDITOR, "courseCard.surfaceStyle"),
            dispatch(SettingsActionKind.MATERIAL_PANEL, SettingsAppearancePage.ROUTE_APPEARANCE_EDITOR, "courseCard.surfaceStyle"),
        )
        assertEquals(
            SettingsDispatch.ShowRecolorSheet("courseCard.recolor"),
            dispatch(SettingsActionKind.RECOLOR_SHEET, null, "courseCard.recolor"),
        )
        val ignored = dispatch(SettingsActionKind.MATERIAL_PANEL, null, "courseCard.surfaceStyle") as SettingsDispatch.Ignored
        assertTrue(ignored.reason.contains("缺少面板路由"))
    }

    @Test
    fun `页面枚举的 11 个值全部有映射 一个都不漏`() {
        // 镜像枚举的风险是「加了新动作忘了映射」：这里逐个走一遍，漏一个就红。
        val mapped = SettingsAction.entries.map { SettingsPageBridge.toKind(it) }
        assertEquals(SettingsAction.entries.size, mapped.size)
        assertEquals(mapped.size, mapped.toSet().size)
        assertEquals(
            setOf(
                SettingsActionKind.NAVIGATE,
                SettingsActionKind.SHEET,
                SettingsActionKind.DIALOG,
                SettingsActionKind.WRITE_SETTING,
                SettingsActionKind.RESET_SCOPE,
                SettingsActionKind.CLIPBOARD_EXPORT,
                SettingsActionKind.CLIPBOARD_IMPORT,
                SettingsActionKind.RUN_NOW,
                SettingsActionKind.COLOR_PICKER,
                SettingsActionKind.MATERIAL_PANEL,
                SettingsActionKind.RECOLOR_SHEET,
            ),
            mapped.toSet(),
        )
    }

    // ================================================================
    // 2. WRITE_SETTING：通用页
    // ================================================================

    @Test
    fun `语言下拉写归一后的 tag`() {
        assertEquals("en", write(SettingsActionDispatcher.ROW_LOCALE, "en_US").appLocaleTag)
        // 「跟随系统」那一项的 id 是空串
        assertEquals("", write(SettingsActionDispatcher.ROW_LOCALE, "").appLocaleTag)
        // Dart normalizeAppLocaleTag：system 也归空串
        assertEquals("", write(SettingsActionDispatcher.ROW_LOCALE, "system").appLocaleTag)
    }

    @Test
    fun `转场速度按 0_5 到 2_5 钳制 非数字记 Ignored`() {
        assertEquals(2.0, write(SettingsActionDispatcher.ROW_TRANSITION_SPEED, "2.0").pageTransitionSpeed, 0.0)
        assertEquals(0.5, write(SettingsActionDispatcher.ROW_TRANSITION_SPEED, "0.1").pageTransitionSpeed, 0.0)
        assertEquals(2.5, write(SettingsActionDispatcher.ROW_TRANSITION_SPEED, "9.9").pageTransitionSpeed, 0.0)
        assertTrue(dispatch(SettingsActionKind.WRITE_SETTING, "abc", SettingsActionDispatcher.ROW_TRANSITION_SPEED) is SettingsDispatch.Ignored)
    }

    @Test
    fun `两个开关行取反`() {
        assertFalse(write(SettingsActionDispatcher.ROW_HAPTICS, null).enableHaptics)
        assertTrue(write(SettingsActionDispatcher.ROW_HOME_PULL_IMPORT, null).homePullQuickImportEnabled)
    }

    // ================================================================
    // 3. WRITE_SETTING：外观与主题管理页
    // ================================================================

    @Test
    fun `主题模式与字体模式按枚举值写`() {
        assertEquals(AppThemeMode.DARK, write(SettingsActionDispatcher.ROW_THEME_MODE, "dark").appThemeMode)
        assertEquals(AppFontMode.SERIF, write(SettingsActionDispatcher.ROW_FONT_MODE, "serif").appFontMode)
        // 不认识的值回落 SYSTEM（Dart X.fromValue 口径）
        assertEquals(AppThemeMode.SYSTEM, write(SettingsActionDispatcher.ROW_THEME_MODE, "zzz").appThemeMode)
    }

    @Test
    fun `字重与字号缩放走规范化`() {
        assertEquals(900, write(SettingsActionDispatcher.ROW_FONT_WEIGHT, "950").appFontWeight)
        assertEquals(100, write(SettingsActionDispatcher.ROW_FONT_WEIGHT, "10").appFontWeight)
        assertEquals(1.6, write(SettingsActionDispatcher.ROW_FONT_SIZE, "2.0").appTextScale, 0.0)
        assertEquals(0.85, write(SettingsActionDispatcher.ROW_FONT_SIZE, "0.1").appTextScale, 0.0)
    }

    @Test
    fun `选主题预设同时写 foruiTheme 与种子色`() {
        // Dart settings_appearance.dart:352-353：两件事一起写。
        val next = write(SettingsActionDispatcher.ROW_THEME_PRESET, "orange")
        assertEquals(ForuiTheme.ORANGE, next.foruiTheme)
        assertEquals("#F54A00", next.themeSeedColor)
    }

    @Test
    fun `主题管理页的预设是单选 值从 rowId 后缀取`() {
        // RADIO 行渲染层不给 target（onAction 传的是 actionTarget，通常为 null），
        // 所以值只能从 rowId 认。Dart :721-722 同样是「档 + 种子色」一起写。
        val next = write("theme.preset.violet", null)
        assertEquals(ForuiTheme.VIOLET, next.foruiTheme)
        assertEquals("#7F22FE", next.themeSeedColor)
    }

    @Test
    fun `不认识的预设值记 Ignored`() {
        assertTrue(dispatch(SettingsActionKind.WRITE_SETTING, "zzz", SettingsActionDispatcher.ROW_THEME_PRESET) is SettingsDispatch.Ignored)
        assertTrue(dispatch(SettingsActionKind.WRITE_SETTING, null, "theme.preset.zzz") is SettingsDispatch.Ignored)
    }

    // ================================================================
    // 4. WRITE_SETTING：课程卡片页
    // ================================================================

    @Test
    fun `七个显示字段开关取反`() {
        assertFalse(write(SettingsActionDispatcher.ROW_CARD_SHOW_NAME, null).courseCardShowName)
        assertFalse(write(SettingsActionDispatcher.ROW_CARD_SHOW_TEACHER, null).courseCardShowTeacher)
        assertFalse(write(SettingsActionDispatcher.ROW_CARD_SHOW_LOCATION, null).courseCardShowLocation)
        assertTrue(write(SettingsActionDispatcher.ROW_CARD_SHOW_TIME, null).courseCardShowTime)
        assertFalse(write(SettingsActionDispatcher.ROW_CARD_SHOW_TIME_LABELS, null).courseCardShowTimeLabels)
        assertTrue(write(SettingsActionDispatcher.ROW_CARD_SHOW_WEEKS, null).courseCardShowWeeks)
        assertTrue(write(SettingsActionDispatcher.ROW_CARD_SHOW_DESCRIPTION, null).courseCardShowDescription)
    }

    @Test
    fun `对齐方式与字号按值写`() {
        assertEquals(
            CourseCardVerticalAlign.BOTTOM,
            write(SettingsActionDispatcher.ROW_CARD_VERTICAL_ALIGN, "bottom").courseCardVerticalAlign,
        )
        assertEquals(
            CourseCardHorizontalAlign.LEFT,
            write(SettingsActionDispatcher.ROW_CARD_HORIZONTAL_ALIGN, "left").courseCardHorizontalAlign,
        )
        assertEquals(12.0, write(SettingsActionDispatcher.ROW_CARD_FONT_SIZE, "20").courseCardFontSize, 0.0)
        assertEquals(7.0, write(SettingsActionDispatcher.ROW_CARD_COMPACT_FONT_SIZE, "1").compactFontSize, 0.0)
    }

    @Test
    fun `统一色与冲突徽标开关 透明度钳制`() {
        assertTrue(write(SettingsActionDispatcher.ROW_CARD_UNIFIED_COLOR, null).timetableUseUnifiedCardColor)
        assertFalse(write(SettingsActionDispatcher.ROW_CARD_CONFLICT_BADGE, null).showConflictBadgeOnTimetable)
        assertEquals(1.0, write(SettingsActionDispatcher.ROW_CARD_CONFLICT_OPACITY, "2").timetableConflictCourseOpacity, 0.0)
        assertEquals(0.2, write(SettingsActionDispatcher.ROW_CARD_CONFLICT_OPACITY, "0").timetableConflictCourseOpacity, 0.0)
    }

    @Test
    fun `关掉独立设置 联动打开时详情色跟随标题色`() {
        // 行上显示的是「独立设置详情颜色」= !link；默认 link=true（行显示关闭），
        // 点一下 = 打开独立设置 ⇒ link=false，只改开关。
        val independent = write(SettingsActionDispatcher.ROW_CARD_TEXT_LINK, null)
        assertFalse(independent.linkCourseCardColors)
        assertEquals(
            defaults.courseCardDetailColorLight,
            independent.courseCardDetailColorLight,
        )

        // 反向：link=false 时点一下 = 关掉独立设置 ⇒ link=true，且详情色跟随标题色
        // （Dart timetable_text_color_settings.dart:67-81）。
        val unlinked = TimetableSettingsModel(
            linkCourseCardColors = false,
            courseCardTitleColorLight = "#112233",
            courseCardTitleColorDark = "#445566",
            courseCardDetailColorLight = "#AABBCC",
            courseCardDetailColorDark = "#DDEEFF",
        )
        val linked = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            null,
            SettingsActionDispatcher.ROW_CARD_TEXT_LINK,
            unlinked,
        ) as SettingsDispatch.Write
        assertTrue(linked.model.linkCourseCardColors)
        assertEquals("#112233", linked.model.courseCardDetailColorLight)
        assertEquals("#445566", linked.model.courseCardDetailColorDark)
    }

    @Test
    fun `联动时改标题色会带上详情色 独立时只改标题色`() {
        val linked = write(SettingsActionDispatcher.ROW_CARD_TEXT_LIGHT_TITLE, "#A1B2C3")
        assertEquals("#A1B2C3", linked.courseCardTitleColorLight)
        assertEquals("#A1B2C3", linked.courseCardDetailColorLight)

        val independentModel = TimetableSettingsModel(
            linkCourseCardColors = false,
            courseCardDetailColorLight = "#AABBCC",
        )
        val onlyTitle = (SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            "#A1B2C3",
            SettingsActionDispatcher.ROW_CARD_TEXT_LIGHT_TITLE,
            independentModel,
        ) as SettingsDispatch.Write).model
        assertEquals("#A1B2C3", onlyTitle.courseCardTitleColorLight)
        assertEquals("#AABBCC", onlyTitle.courseCardDetailColorLight)
    }

    @Test
    fun `详情色行只改详情色`() {
        val next = write(SettingsActionDispatcher.ROW_CARD_TEXT_DARK_DETAIL, "#010203")
        assertEquals("#010203", next.courseCardDetailColorDark)
        assertEquals(defaults.courseCardTitleColorDark, next.courseCardTitleColorDark)
    }

    @Test
    fun `色值非法记 Ignored 不写脏数据`() {
        for (bad in listOf(null, "", "red", "#12345", "#GGGGGG", "112233")) {
            assertTrue(
                "色值 $bad 应当被拒",
                dispatch(
                    SettingsActionKind.WRITE_SETTING,
                    bad,
                    SettingsActionDispatcher.ROW_CARD_TEXT_LIGHT_TITLE,
                ) is SettingsDispatch.Ignored,
            )
        }
    }

    @Test
    fun `未识别的 rowId 是 no-op 带理由 不崩`() {
        val ignored = dispatch(SettingsActionKind.WRITE_SETTING, "1", "someUnknown.row") as SettingsDispatch.Ignored
        assertEquals("someUnknown.row", ignored.rowId)
        assertTrue(ignored.reason.contains("未识别的 rowId"))
        // 别的页（各自私有 state）也一样：本刀不写、不崩。
        assertTrue(dispatch(SettingsActionKind.WRITE_SETTING, "1", "timetablePage.sectionHeight") is SettingsDispatch.Ignored)
    }

    // ================================================================
    // 5. 恢复默认
    // ================================================================

    @Test
    fun `课卡作用域恢复 20 个字段 但不动材质档`() {
        val dirty = TimetableSettingsModel(
            courseCardShowName = false,
            courseCardShowTime = true,
            courseCardVerticalAlign = CourseCardVerticalAlign.BOTTOM,
            courseCardHorizontalAlign = CourseCardHorizontalAlign.RIGHT,
            courseCardFontSize = 12.0,
            compactFontSize = 7.0,
            timetableUseUnifiedCardColor = true,
            timetableUnifiedCardColor = "#123456",
            showConflictBadgeOnTimetable = false,
            timetableConflictCourseOpacity = 0.2,
            linkCourseCardColors = false,
            courseCardTitleColorLight = "#111111",
            courseCardTitleColorDark = "#222222",
            courseCardDetailColorLight = "#333333",
            courseCardDetailColorDark = "#444444",
            courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS,
        )
        val reset = SettingsActionDispatcher.applyResetScope(
            dirty,
            SettingsActionDispatcher.SCOPE_COURSE_CARD,
        )!!
        assertEquals(true, reset.courseCardShowName)
        assertEquals(false, reset.courseCardShowTime)
        assertEquals(CourseCardVerticalAlign.CENTER, reset.courseCardVerticalAlign)
        assertEquals(CourseCardHorizontalAlign.CENTER, reset.courseCardHorizontalAlign)
        assertEquals(9.0, reset.courseCardFontSize, 0.0)
        assertEquals(9.0, reset.compactFontSize, 0.0)
        assertEquals(false, reset.timetableUseUnifiedCardColor)
        assertEquals(TimetableSettingsModel.DEFAULT_UNIFIED_CARD_COLOR, reset.timetableUnifiedCardColor)
        assertEquals(true, reset.showConflictBadgeOnTimetable)
        assertEquals(0.70, reset.timetableConflictCourseOpacity, 0.0)
        assertEquals(true, reset.linkCourseCardColors)
        assertEquals(TimetableSettingsModel.DEFAULT_CARD_TITLE_COLOR, reset.courseCardTitleColorLight)
        assertEquals(TimetableSettingsModel.DEFAULT_CARD_DETAIL_COLOR, reset.courseCardDetailColorDark)
        // 材质档归「外观」作用域（Dart settings_reset.dart:51-52），本作用域不碰它
        assertEquals(CourseCardSurfaceStyle.LIQUID_GLASS, reset.courseCardSurfaceStyle)
    }

    @Test
    fun `外观作用域恢复主题字段与材质档 种子色回到构造默认`() {
        val dirty = TimetableSettingsModel(
            appThemeMode = AppThemeMode.DARK,
            appFontMode = AppFontMode.SERIF,
            appFontWeight = 900,
            appTextScale = 1.6,
            foruiTheme = ForuiTheme.ROSE,
            themeSeedColor = "#EC003F",
            courseCardSurfaceStyle = CourseCardSurfaceStyle.GAUSSIAN,
        )
        val reset = SettingsActionDispatcher.applyResetScope(
            dirty,
            SettingsActionDispatcher.SCOPE_APPEARANCE,
        )!!
        assertEquals(AppThemeMode.SYSTEM, reset.appThemeMode)
        assertEquals(AppFontMode.SYSTEM, reset.appFontMode)
        assertEquals(400, reset.appFontWeight)
        assertEquals(1.0, reset.appTextScale, 0.0)
        assertEquals(ForuiTheme.MIUI, reset.foruiTheme)
        // ⚠️ 构造默认 #3482FF，不是读侧缺键默认 #2563EB
        assertEquals("#3482FF", reset.themeSeedColor)
        assertEquals(CourseCardSurfaceStyle.SOLID, reset.courseCardSurfaceStyle)
    }

    @Test
    fun `未知作用域返回 null 不猜`() {
        assertNull(SettingsActionDispatcher.applyResetScope(defaults, "nope"))
        assertNull(SettingsActionDispatcher.applyResetScope(defaults, ""))
    }

    // ================================================================
    // 6. 端到端：改开关 → 状态变 → 盘上值变 → 重建 spec 后 switchValue 真翻了
    // ================================================================

    @Test
    fun `端到端 课卡显示课程名开关：模型 盘 与 spec 三处都翻了`() {
        val store = TimetableStore(InMemoryKeyValueStore())
        val modelStore = TimetableSettingsModelStore(store)
        val rowId = SettingsActionDispatcher.ROW_CARD_SHOW_NAME

        // 起点：默认 true（模型层读侧默认）
        val before = modelStore.load()
        assertTrue(before.courseCardShowName)
        assertTrue(rowValue(specFor(SettingsCourseCardPage.ID, before), rowId)!!.switchValue!!)

        // ① 分派一次写（渲染层对开关不给新值 ⇒ target = null）
        val dispatch = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            null,
            rowId,
            before,
        )
        val write = dispatch as SettingsDispatch.Write
        assertFalse("模型状态要变", write.model.courseCardShowName)

        // ② 宿主落盘（合并写）
        modelStore.save(write.model)

        // ③ 盘上值真的变了
        val diskJson = store.loadSettingsJson()
        assertEquals(false, diskJson["courseCardShowName"])

        // ④ 重新从盘上读，用新状态重建 spec，那一行的 switchValue 真的翻了
        val reloaded = modelStore.load()
        assertFalse("盘上读回来也要是 false", reloaded.courseCardShowName)
        val spec = specFor(SettingsCourseCardPage.ID, reloaded)
        assertFalse("spec 里那一行必须跟着翻", rowValue(spec, rowId)!!.switchValue!!)
    }

    @Test
    fun `端到端 改主题预设后外观页与主题管理页两处都跟着变`() {
        val store = TimetableStore(InMemoryKeyValueStore())
        val modelStore = TimetableSettingsModelStore(store)

        val write = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            "green",
            SettingsActionDispatcher.ROW_THEME_PRESET,
            modelStore.load(),
        ) as SettingsDispatch.Write
        modelStore.save(write.model)

        val reloaded = modelStore.load()
        assertEquals(ForuiTheme.GREEN, reloaded.foruiTheme)
        assertEquals("#5EA500", reloaded.themeSeedColor)

        // 外观页下拉的选中项
        val appearance = SettingsPageBridge.toSettingsPageState(reloaded)
        assertEquals(
            "green",
            rowValue(SettingsAppearancePage.spec(appearance), SettingsActionDispatcher.ROW_THEME_PRESET)!!.selectedOptionId,
        )
        // 主题管理页的单选行
        val themeRow = rowValue(SettingsThemeManagePage.spec(appearance), "theme.preset.green")!!
        assertEquals("green", themeRow.selectedOptionId)
        assertNull(
            "其它档不该被选中",
            rowValue(SettingsThemeManagePage.spec(appearance), "theme.preset.rose")!!.selectedOptionId,
        )
    }

    @Test
    fun `只认本刀 4 页 别的页 id 返回 null`() {
        val state = SettingsPageBridge.toSettingsPageState(defaults)
        for (id in SettingsPageBridge.SUPPORTED_PAGE_IDS) {
            assertNotNull("$id 应当有 spec", SettingsPageBridge.specFor(id, state))
        }
        assertNull(SettingsPageBridge.specFor("settings-timetable-page", state))
        assertNull(SettingsPageBridge.specFor("", state))
        assertEquals(4, SettingsPageBridge.SUPPORTED_PAGE_IDS.size)
        assertEquals(
            listOf(
                SettingsGeneralPage.ID,
                SettingsAppearancePage.ID,
                SettingsThemeManagePage.ID,
                SettingsCourseCardPage.ID,
            ),
            SettingsPageBridge.SUPPORTED_PAGE_IDS,
        )
    }

    // ================================================================
    // 夹具
    // ================================================================

    private fun dispatch(
        kind: SettingsActionKind,
        target: String?,
        rowId: String,
        model: TimetableSettingsModel = defaults,
    ): SettingsDispatch = SettingsActionDispatcher.dispatch(kind, target, rowId, model)

    private fun write(rowId: String, target: String?): TimetableSettingsModel =
        (dispatch(SettingsActionKind.WRITE_SETTING, target, rowId) as SettingsDispatch.Write).model

    private fun specFor(pageId: String, model: TimetableSettingsModel): SettingsPageSpec =
        SettingsPageBridge.specFor(pageId, SettingsPageBridge.toSettingsPageState(model))!!

    /** 在 spec 的所有分组里按 id 找一行。 */
    private fun rowValue(spec: SettingsPageSpec, rowId: String): SettingsRow? =
        spec.nodes
            .filterIsInstance<SettingsGroup>()
            .flatMap { it.children }
            .filterIsInstance<SettingsRow>()
            .firstOrNull { it.id == rowId }
}
