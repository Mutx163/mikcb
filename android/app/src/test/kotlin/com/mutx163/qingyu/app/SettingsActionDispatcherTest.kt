package com.mutx163.qingyu.app

import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsAppearancePage
import com.mutx163.qingyu.pages.settings.SettingsCourseCardPage
import com.mutx163.qingyu.pages.settings.SettingsGeneralPage
import com.mutx163.qingyu.pages.settings.SettingsGroup
import com.mutx163.qingyu.pages.settings.SettingsInline
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
import java.io.File

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

    @Test
    fun `节假日标记开关取反`() {
        // 2026-10-29 补：这个键从第一批模型起就有（enableHolidayMarking），但分派器一直没有分支，
        // 于是「点了不落盘」。默认值是 true（timetable_settings.dart:760）⇒ 先点一下必须变 false。
        val off = write(SettingsActionDispatcher.ROW_HOLIDAY_ENABLE, null)
        assertFalse("默认开 ⇒ 点一下关", off.enableHolidayMarking)
        // 取反是幂等的两态：再点一次回到 true（不是「点一次关、再点还是关」）。
        val backOn = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            null,
            SettingsActionDispatcher.ROW_HOLIDAY_ENABLE,
            off,
        )
        assertTrue(backOn is SettingsDispatch.Write)
        assertTrue((backOn as SettingsDispatch.Write).model.enableHolidayMarking)
        // rowId 与页面模型逐字一致（模型改了这里要跟着红，而不是等真机点不动）。
        assertEquals("holiday.enable", SettingsActionDispatcher.ROW_HOLIDAY_ENABLE)
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
        assertFalse(write(SettingsActionDispatcher.ROW_CARD_DAY_VIEW_COLOR, null).dayViewUseCourseColor)
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
        assertTrue(dispatch(SettingsActionKind.WRITE_SETTING, "1", "someOtherPage.unknownRow") is SettingsDispatch.Ignored)
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
            dayViewUseCourseColor = false,
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
        assertEquals(true, reset.dayViewUseCourseColor)
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
    // 9. task-15：渲染层两处死控件（色板 / 控制卡按钮）的接线
    // ================================================================

    @Test
    fun `色板点一个色块把值写进模型并落盘`() {
        val store = TimetableStore(InMemoryKeyValueStore())
        val modelStore = TimetableSettingsModelStore(store)
        val before = modelStore.load()
        assertEquals(
            TimetableSettingsModel.DEFAULT_UNIFIED_CARD_COLOR,
            before.timetableUnifiedCardColor,
        )

        // 渲染层点色块的产出：WRITE_SETTING + target = 该色值 + rowId = 色板 id
        val write = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            "#7C3AED",
            SettingsActionDispatcher.ROW_CARD_COLOR_CHIPS,
            before,
        ) as SettingsDispatch.Write
        assertEquals("#7C3AED", write.model.timetableUnifiedCardColor)

        // 宿主落盘 → 盘上值真的变了（这就是「用户改得了统一课卡色」的证据）
        modelStore.save(write.model)
        assertEquals("#7C3AED", store.loadSettingsJson()["timetableUnifiedCardColor"])
        assertEquals("#7C3AED", modelStore.load().timetableUnifiedCardColor)
    }

    @Test
    fun `色板色值非法记 Ignored 不写脏数据`() {
        for (bad in listOf(null, "", "purple", "#12345", "#GGGGGG")) {
            assertTrue(
                "色板值 $bad 应当被拒",
                dispatch(
                    SettingsActionKind.WRITE_SETTING,
                    bad,
                    SettingsActionDispatcher.ROW_CARD_COLOR_CHIPS,
                ) is SettingsDispatch.Ignored,
            )
        }
    }

    @Test
    fun `重置为预设把主题快照按 Dart 短键写回模型`() {
        // 快照键名逐字对照 Dart ThemeConfig.toJson（timetable_settings.dart:123-144）
        val model = TimetableSettingsModel(
            themeCheckpointConfig = mapOf(
                "v" to 2,
                "seed" to "#5EA500",
                "uc" to "#DC2626",
                "ucOn" to true,
                "mode" to "dark",
                "ccl" to "#111111",
                "ccd" to "#222222",
                "cdl" to "#333333",
                "cdd" to "#444444",
                "wbl" to "#555555",
                "wal" to "#666666",
                "tal" to "#777777",
                "link" to false,
                "hideWeekend" to true,
                "spacing" to "wide",
                "timeDisplay" to "start_only",
                // 本模型不拥有的键（材质/玻璃那一刀的范围）必须被安静忽略
                "bg" to "#000000",
                "不存在的键" to "x",
            ),
        )

        val reset = write(SettingsActionDispatcher.ROW_THEME_CURRENT_RESET, null, model)

        assertEquals("#5EA500", reset.themeSeedColor)
        assertEquals("#DC2626", reset.timetableUnifiedCardColor)
        assertTrue(reset.timetableUseUnifiedCardColor)
        assertEquals(AppThemeMode.DARK, reset.appThemeMode)
        assertEquals("#111111", reset.courseCardTitleColorLight)
        assertEquals("#222222", reset.courseCardTitleColorDark)
        assertEquals("#333333", reset.courseCardDetailColorLight)
        assertEquals("#444444", reset.courseCardDetailColorDark)
        assertEquals("#555555", reset.weekdayBarFontColorLight)
        assertEquals("#666666", reset.weekdayBarAccentColorLight)
        assertEquals("#777777", reset.timeAxisFontColorLight)
        assertFalse(reset.linkCourseCardColors)
        assertTrue(reset.timetableHideWeekends)
        assertEquals(TimetableCourseSpacingMode.WIDE, reset.timetableCourseSpacingMode)
        assertEquals(
            SectionTimeDisplayMode.START_ONLY,
            reset.timetableSectionTimeDisplayMode,
        )
    }

    @Test
    fun `重置为预设遇到坏值保持原值 不崩`() {
        val model = TimetableSettingsModel(
            themeSeedColor = "#123456",
            courseCardTitleColorLight = "#ABCDEF",
            themeCheckpointConfig = mapOf(
                "seed" to "not-a-color",
                "ccl" to 42,
                "link" to "yes",
                "mode" to "zzz",
            ),
        )
        val reset = write(SettingsActionDispatcher.ROW_THEME_CURRENT_RESET, null, model)
        assertEquals("#123456", reset.themeSeedColor)
        assertEquals("#ABCDEF", reset.courseCardTitleColorLight)
        // 类型不符的布尔保持原值（默认真）
        assertTrue(reset.linkCourseCardColors)
        // 不认识的档位回落 system（Dart X.fromValue 口径）
        assertEquals(AppThemeMode.SYSTEM, reset.appThemeMode)
    }

    @Test
    fun `没有主题快照时重置为预设记 Ignored`() {
        // Dart：`if (settings.themeCheckpointConfig != null)` 才动手，否则什么都不做。
        val ignored = dispatch(
            SettingsActionKind.WRITE_SETTING,
            null,
            SettingsActionDispatcher.ROW_THEME_CURRENT_RESET,
            TimetableSettingsModel(themeCheckpointConfig = null),
        ) as SettingsDispatch.Ignored
        assertTrue(ignored.reason.contains("themeCheckpointConfig"))
    }

    @Test
    fun `保存当前主题走 DIALOG 意图`() {
        assertEquals(
            SettingsDispatch.ShowDialog(null, SettingsActionDispatcher.ROW_THEME_CURRENT_SAVE),
            dispatch(
                SettingsActionKind.DIALOG,
                null,
                SettingsActionDispatcher.ROW_THEME_CURRENT_SAVE,
            ),
        )
    }

    @Test
    fun `死控件接线的 rowId 约定逐字一致`() {
        assertEquals("courseCard.colorChips", SettingsActionDispatcher.ROW_CARD_COLOR_CHIPS)
        assertEquals("theme.current", SettingsActionDispatcher.ROW_THEME_CURRENT)
        assertEquals(
            "theme.current.resetToPreset",
            SettingsActionDispatcher.ROW_THEME_CURRENT_RESET,
        )
        assertEquals("theme.current.saveCurrent", SettingsActionDispatcher.ROW_THEME_CURRENT_SAVE)
        // 两个按钮行 id 必须是控制卡 id 的后缀（渲染层按这个约定拼）
        for (rowId in listOf(
            SettingsActionDispatcher.ROW_THEME_CURRENT_RESET,
            SettingsActionDispatcher.ROW_THEME_CURRENT_SAVE,
        )) {
            assertTrue(
                "`$rowId` 应当以 `${SettingsActionDispatcher.ROW_THEME_CURRENT}.` 开头",
                rowId.startsWith("${SettingsActionDispatcher.ROW_THEME_CURRENT}."),
            )
        }
    }

    @Test
    fun `渲染层两处死控件的接线不许再被改空`() {
        // 渲染层没有 Compose 测试设施（全仓 createComposeRule 0 命中），所以这里用
        // 「源码守卫」钉住接线：把 clickable 去掉 / 把 onClick 改回空 lambda 都会红。
        val source = rendererSource()
        val chips = functionBody(source, "private fun ColorChipGroup(")
        val controlCard = functionBody(source, "private fun ControlCard(")

        assertTrue("色板色块必须可点（clickable）", chips.contains("clickable"))
        assertTrue(
            // 2026-11-01 F25：色板不再写死课卡色 rowId，改为回传**这一组**的 `node.id`。
            // 写死会让课表页背景色板也写成「课卡统一色」（真机实测），所以判据跟着改成
            // 「必须经 onAction 且 rowId 来自节点」。
            "色块点击必须走 onAction 通路并带上所在色板组的 rowId",
            chips.contains("onAction(") && chips.contains("node.id"),
        )
        assertFalse("色板里不许自己写业务判据（比如直接改状态）", chips.contains("timetableUnifiedCardColor"))

        assertTrue(
            "控制卡按钮必须经 controlCardWiring 翻译成动作",
            controlCard.contains("controlCardWiring(action.key)"),
        )
        assertTrue(controlCard.contains("onAction("))
        // 「还有没有空 lambda」只看**代码行**：注释里提到旧实现不算（与 CjkLiteralGateTest
        // 跳过注释行同一套口径）。
        val codeOnly = source.lines()
            .filterNot { line ->
                val t = line.trimStart()
                t.startsWith("*") || t.startsWith("//") || t.startsWith("/*")
            }
            .joinToString("\n")
        assertFalse("渲染层不许再有空的 onClick = { }", codeOnly.contains("onClick = { }"))

        // 翻译表本身：两个按钮各自的 rowId 与 ARB 键
        val wiring = functionBody(source, "private fun controlCardWiring(")
        assertTrue(wiring.contains("SettingsActionDispatcher.ROW_THEME_CURRENT_RESET"))
        assertTrue(wiring.contains("SettingsActionDispatcher.ROW_THEME_CURRENT_SAVE"))
        assertTrue(wiring.contains("\"themeResetToPreset\""))
        assertTrue(wiring.contains("\"themeSaveCurrent\""))
    }

    // ================================================================
    // 10. task-16：hasThemeModifications（决定主题管理页两个按钮渲不渲染）
    // ================================================================

    @Test
    fun `没有检查点时不算有改动`() {
        // Dart :2483 `if (themeCheckpointConfig == null) return false;`
        assertFalse(
            SettingsActionDispatcher.hasThemeModifications(
                TimetableSettingsModel(themeCheckpointConfig = null),
            ),
        )
    }

    @Test
    fun `检查点里非 null 的字段与当前一致时不算有改动`() {
        val model = TimetableSettingsModel(
            themeSeedColor = "#2563EB",
            courseCardTitleColorLight = "#FFFFFF",
            themeCheckpointConfig = mapOf(
                "seed" to "#2563EB",
                "ccl" to "#FFFFFF",
                "v" to 2,
            ),
        )
        assertFalse(SettingsActionDispatcher.hasThemeModifications(model))
    }

    @Test
    fun `检查点里任一非 null 字段与当前不同就算有改动`() {
        val model = TimetableSettingsModel(
            themeSeedColor = "#123456",
            themeCheckpointConfig = mapOf("seed" to "#2563EB"),
        )
        assertTrue(SettingsActionDispatcher.hasThemeModifications(model))
    }

    @Test
    fun `只改一个检查点里是 null 的字段 仍不算有改动`() {
        // **本条的语义核心**（Dart :2488-2492「检查点未设置的字段不比较」）：
        // 检查点只记了 seed，用户去改 ccl / 字号 / 周末显示……都不算「基于该主题的改动」，
        // 否则按钮会在用户根本没碰主题时冒出来。
        val model = TimetableSettingsModel(
            themeSeedColor = "#2563EB",
            courseCardTitleColorLight = "#ABCDEF",
            courseCardFontSize = 12.0,
            timetableHideWeekends = true,
            themeCheckpointConfig = mapOf("seed" to "#2563EB"),
        )
        assertFalse(SettingsActionDispatcher.hasThemeModifications(model))

        // 反证：一旦动的是检查点**记过**的那个字段，就立刻为真
        assertTrue(
            SettingsActionDispatcher.hasThemeModifications(
                model.copy(themeSeedColor = "#000000"),
            ),
        )
    }

    @Test
    fun `检查点里的字段为 null 或类型不符时按 Dart 宽松读处理`() {
        // ① 全 null / 缺键 ⇒ 全部跳过 ⇒ false
        val allNull = TimetableSettingsModel(
            themeSeedColor = "#000000",
            themeCheckpointConfig = mapOf("v" to 2, "seed" to null),
        )
        assertFalse(SettingsActionDispatcher.hasThemeModifications(allNull))

        // ② 布尔键拿到非布尔（1）⇒ Dart `lenientBool` 不猜，按「没记过」跳过 ⇒ false
        //    （lenient_json_readers.dart:41-47）
        val badBool = TimetableSettingsModel(
            linkCourseCardColors = false,
            themeCheckpointConfig = mapOf("link" to 1),
        )
        assertFalse(SettingsActionDispatcher.hasThemeModifications(badBool))

        // ③ ⚠️ 但字符串键拿到非字符串**不是**「没记过」：Dart `lenientString` 会
        //    `v?.toString()`（lenient_json_readers.dart:39）⇒ `ccl: 42` 变成 "42"，
        //    与当前 "#FFFFFF" 不同 ⇒ true。这条差异必须钉住，否则很容易想当然。
        val stringified = TimetableSettingsModel(
            courseCardTitleColorLight = "#FFFFFF",
            themeCheckpointConfig = mapOf("ccl" to 42),
        )
        assertTrue(SettingsActionDispatcher.hasThemeModifications(stringified))
    }

    @Test
    fun `颜色按原始字符串逐字比 不归一大小写`() {
        // Dart `differs` 直接比 `getter(current) != checkpointVal`：大小写不同就是不同。
        val model = TimetableSettingsModel(
            courseCardTitleColorLight = "#FFFFFF",
            themeCheckpointConfig = mapOf("ccl" to "#ffffff"),
        )
        assertTrue(SettingsActionDispatcher.hasThemeModifications(model))

        assertFalse(
            SettingsActionDispatcher.hasThemeModifications(
                model.copy(themeCheckpointConfig = mapOf("ccl" to "#FFFFFF")),
            ),
        )
    }

    @Test
    fun `枚举与布尔按值比较`() {
        val model = TimetableSettingsModel(
            appThemeMode = AppThemeMode.DARK,
            linkCourseCardColors = false,
            // 枚举值逐字用 Dart 的：`start_only`（不是 startOnly）
            timetableSectionTimeDisplayMode = SectionTimeDisplayMode.START_ONLY,
            themeCheckpointConfig = mapOf(
                "mode" to "dark",
                "link" to false,
                "timeDisplay" to "start_only",
            ),
        )
        assertFalse(SettingsActionDispatcher.hasThemeModifications(model))

        assertTrue(
            SettingsActionDispatcher.hasThemeModifications(
                model.copy(appThemeMode = AppThemeMode.LIGHT),
            ),
        )
        assertTrue(
            SettingsActionDispatcher.hasThemeModifications(
                model.copy(linkCourseCardColors = true),
            ),
        )
        assertTrue(
            SettingsActionDispatcher.hasThemeModifications(
                model.copy(timetableSectionTimeDisplayMode = SectionTimeDisplayMode.HIDDEN),
            ),
        )
    }

    @Test
    fun `端到端 有改动时主题管理页真的渲染出两个按钮`() {
        // 这条把「修好了」与「用户看得见」连起来：task-15 修的是「一旦出现就点得动」，
        // task-16 让它真的出现——控制卡的 texts 非空才渲染按钮（页面 spec 决定）。
        val clean = TimetableSettingsModel(
            themeCheckpointName = "冬季配色",
            themeSeedColor = "#2563EB",
            themeCheckpointConfig = mapOf("seed" to "#2563EB"),
        )
        assertEquals("无改动时不该出按钮", 0, themeCurrentCard(clean).texts.size)

        val dirty = clean.copy(themeSeedColor = "#000000")
        val dirtyCard = themeCurrentCard(dirty)
        assertEquals("有改动时应当出两个按钮", 2, dirtyCard.texts.size)
        assertEquals(
            listOf("themeResetToPreset", "themeSaveCurrent"),
            dirtyCard.texts.map { it.key },
        )
    }

    @Test
    fun `已存主题的选中态要同时看名字与有没有改动`() {
        // Dart isSavedThemeSelected（theme_manage_sheets.dart:315-318）：
        // 名字对上但用户改过主题 ⇒ 不算选中。
        val saved = mapOf(
            "id" to "t1",
            "name" to "冬季配色",
            "themeData" to mapOf("seedColor" to "#3482FF"),
        )
        val clean = TimetableSettingsModel(
            themeCheckpointName = "冬季配色",
            themeSeedColor = "#2563EB",
            savedThemes = listOf(saved),
            themeCheckpointConfig = mapOf("seed" to "#2563EB"),
        )
        assertTrue(SettingsPageBridge.toSettingsPageState(clean).savedThemes.single().selected)

        val dirty = clean.copy(themeSeedColor = "#000000")
        assertFalse(SettingsPageBridge.toSettingsPageState(dirty).savedThemes.single().selected)
    }

    // ================================================================
    // 11. 首页与导航 + 底栏/八宫格编辑器（writeSetting 新分支）
    // ================================================================

    @Test
    fun `首页导航形态 页面词汇 glassDock 要写成枚举 GLASS_DOCK`() {
        // 渲染层下拉 option id 是 "classic"/"glassDock"；枚举磁盘值却是 "glass_dock"。
        // 这条钉住「选了玻璃坞真的进玻璃坞」，不能回落经典。
        assertEquals(
            HomeNavigationForm.GLASS_DOCK,
            write(SettingsActionDispatcher.ROW_HOME_NAV_FORM, "glassDock").homeNavigationForm,
        )
        assertEquals(
            HomeNavigationForm.CLASSIC,
            write(SettingsActionDispatcher.ROW_HOME_NAV_FORM, "classic").homeNavigationForm,
        )
        // 未知值一律 Ignored（不猜）
        assertTrue(
            dispatch(
                SettingsActionKind.WRITE_SETTING,
                "zzz",
                SettingsActionDispatcher.ROW_HOME_NAV_FORM,
            ) is SettingsDispatch.Ignored,
        )
    }

    @Test
    fun `菜单形态与首页标题样式按值写 未知值 Ignored`() {
        assertEquals(
            HomeMenuStyle.GRID,
            write(SettingsActionDispatcher.ROW_HOME_NAV_MENU_STYLE, "grid").homeMenuStyle,
        )
        assertEquals(
            HomeMenuStyle.LIST,
            write(SettingsActionDispatcher.ROW_HOME_NAV_MENU_STYLE, "list").homeMenuStyle,
        )
        assertEquals(
            HomeTitleStyle.BRAND,
            write(SettingsActionDispatcher.ROW_HOME_NAV_HOME_TITLE_STYLE, "brand").homeTitleStyle,
        )
        assertEquals(
            HomeTitleStyle.CLASSIC,
            write(SettingsActionDispatcher.ROW_HOME_NAV_HOME_TITLE_STYLE, "classic").homeTitleStyle,
        )
        assertTrue(
            dispatch(
                SettingsActionKind.WRITE_SETTING,
                "zzz",
                SettingsActionDispatcher.ROW_HOME_NAV_MENU_STYLE,
            ) is SettingsDispatch.Ignored,
        )
        assertTrue(
            dispatch(
                SettingsActionKind.WRITE_SETTING,
                "zzz",
                SettingsActionDispatcher.ROW_HOME_NAV_HOME_TITLE_STYLE,
            ) is SettingsDispatch.Ignored,
        )
    }

    @Test
    fun `圆钮开关取反 圆钮功能缺省回 addCourse`() {
        assertTrue(write(SettingsActionDispatcher.ROW_HOME_NAV_SHOW_ADD_BUTTON, null).glassDockShowAddButton)
        assertEquals(
            "overview",
            write(SettingsActionDispatcher.ROW_HOME_NAV_DOCK_BUTTON_ENTRY, "overview").glassDockButtonEntryId,
        )
        // null / 空串 → addCourse（Dart `_effectiveGlassDockButtonEntryId` 同口径）
        assertEquals(
            TimetableSettingsModel.DEFAULT_GLASS_DOCK_BUTTON_ENTRY_ID,
            write(SettingsActionDispatcher.ROW_HOME_NAV_DOCK_BUTTON_ENTRY, null).glassDockButtonEntryId,
        )
        assertEquals(
            "addCourse",
            write(SettingsActionDispatcher.ROW_HOME_NAV_DOCK_BUTTON_ENTRY, "").glassDockButtonEntryId,
        )
    }

    @Test
    fun `底栏添加守上限与去重`() {
        val two = TimetableSettingsModel(glassDockActions = listOf("day", "week"))
        assertEquals(
            listOf("day", "week", "tasks"),
            write(SettingsActionDispatcher.ROW_DOCK_ADD, "tasks", two).glassDockActions,
        )
        // 已存在 → 原样
        assertEquals(
            listOf("day", "week"),
            write(SettingsActionDispatcher.ROW_DOCK_ADD, "day", two).glassDockActions,
        )
        // 满 5 → 原样
        val five = TimetableSettingsModel(
            glassDockActions = listOf("day", "week", "tasks", "exams", "overview"),
        )
        assertEquals(
            five.glassDockActions,
            write(SettingsActionDispatcher.ROW_DOCK_ADD, "monthView", five).glassDockActions,
        )
        // 空 target → Ignored
        assertTrue(
            dispatch(SettingsActionKind.WRITE_SETTING, "", SettingsActionDispatcher.ROW_DOCK_ADD, two)
                is SettingsDispatch.Ignored,
        )
    }

    @Test
    fun `底栏移除至少留一个`() {
        val three = TimetableSettingsModel(glassDockActions = listOf("day", "week", "tasks"))
        assertEquals(
            listOf("day", "tasks"),
            write(SettingsActionDispatcher.ROW_DOCK_REMOVE, "week", three).glassDockActions,
        )
        // 只剩一个 → 原样，不允许清空
        val one = TimetableSettingsModel(glassDockActions = listOf("day"))
        assertEquals(
            listOf("day"),
            write(SettingsActionDispatcher.ROW_DOCK_REMOVE, "day", one).glassDockActions,
        )
        // 不在表里 → 原样
        assertEquals(
            three.glassDockActions,
            write(SettingsActionDispatcher.ROW_DOCK_REMOVE, "none", three).glassDockActions,
        )
    }

    @Test
    fun `底栏排序 冒号两个整数 长度不变`() {
        val three = TimetableSettingsModel(glassDockActions = listOf("day", "week", "tasks"))
        // Dart onReorder 语义：removeAt(from) 后插到 to
        assertEquals(
            listOf("week", "tasks", "day"),
            write(SettingsActionDispatcher.ROW_DOCK_MOVE, "0:2", three).glassDockActions,
        )
        assertEquals(
            listOf("tasks", "day", "week"),
            write(SettingsActionDispatcher.ROW_DOCK_MOVE, "2:0", three).glassDockActions,
        )
        // 坏 target → Ignored
        for (bad in listOf(null, "", "abc", "0", "0:", "0:x", "1:2:3")) {
            assertTrue(
                "底栏排序 $bad 应当被拒",
                dispatch(
                    SettingsActionKind.WRITE_SETTING,
                    bad,
                    SettingsActionDispatcher.ROW_DOCK_MOVE,
                    three,
                ) is SettingsDispatch.Ignored,
            )
        }
        // 越界 → Ignored
        assertTrue(
            dispatch(
                SettingsActionKind.WRITE_SETTING,
                "0:9",
                SettingsActionDispatcher.ROW_DOCK_MOVE,
                three,
            ) is SettingsDispatch.Ignored,
        )
    }

    @Test
    fun `底栏恢复默认回到 day week tasks`() {
        assertEquals(
            listOf("day", "week", "tasks"),
            write(
                SettingsActionDispatcher.ROW_DOCK_RESET,
                null,
                TimetableSettingsModel(glassDockActions = listOf("exams")),
            ).glassDockActions,
        )
    }

    @Test
    fun `八宫格添加保留钉住项并守上限`() {
        val base = TimetableSettingsModel(homeGridMenuActions = listOf("overview", "settings"))
        assertEquals(
            listOf("overview", "settings", "exams"),
            write(SettingsActionDispatcher.ROW_MENU_ADD, "exams", base).homeGridMenuActions,
        )
        // 已存在 → 原样
        assertEquals(
            base.homeGridMenuActions,
            write(SettingsActionDispatcher.ROW_MENU_ADD, "overview", base).homeGridMenuActions,
        )
        // 满 8 → 原样
        val full = TimetableSettingsModel(
            homeGridMenuActions = listOf(
                "overview", "statistics", "addCourse", "exams",
                "tasks", "importCourses", "settings", "support",
            ),
        )
        assertEquals(
            full.homeGridMenuActions,
            write(SettingsActionDispatcher.ROW_MENU_ADD, "monthView", full).homeGridMenuActions,
        )
    }

    @Test
    fun `八宫格添加即使从空表开始也会补回钉住项`() {
        // normalizeHomeGridMenuActions 语义：缺 settings 时补上，保证能回到编辑器
        assertEquals(
            listOf("overview", "settings"),
            write(
                SettingsActionDispatcher.ROW_MENU_ADD,
                "overview",
                TimetableSettingsModel(),
            ).homeGridMenuActions,
        )
    }

    @Test
    fun `八宫格移除不动钉住项 且至少留一个`() {
        val base = TimetableSettingsModel(homeGridMenuActions = listOf("overview", "settings"))
        assertEquals(
            listOf("settings"),
            write(SettingsActionDispatcher.ROW_MENU_REMOVE, "overview", base).homeGridMenuActions,
        )
        // 钉住项 settings 不可移除
        assertEquals(
            base.homeGridMenuActions,
            write(SettingsActionDispatcher.ROW_MENU_REMOVE, "settings", base).homeGridMenuActions,
        )
        // 只剩一个 → 原样
        val one = TimetableSettingsModel(homeGridMenuActions = listOf("settings"))
        assertEquals(
            one.homeGridMenuActions,
            write(SettingsActionDispatcher.ROW_MENU_REMOVE, "settings", one).homeGridMenuActions,
        )
    }

    @Test
    fun `八宫格排序与恢复默认`() {
        val three = TimetableSettingsModel(homeGridMenuActions = listOf("overview", "settings", "exams"))
        assertEquals(
            listOf("settings", "exams", "overview"),
            write(SettingsActionDispatcher.ROW_MENU_MOVE, "0:2", three).homeGridMenuActions,
        )
        // 恢复默认完整 8 项
        assertEquals(
            listOf(
                "overview", "statistics", "addCourse", "exams",
                "tasks", "importCourses", "settings", "support",
            ),
            write(SettingsActionDispatcher.ROW_MENU_RESET, null).homeGridMenuActions,
        )
        // 坏 target → Ignored
        assertTrue(
            dispatch(
                SettingsActionKind.WRITE_SETTING,
                "x",
                SettingsActionDispatcher.ROW_MENU_MOVE,
                three,
            ) is SettingsDispatch.Ignored,
        )
    }

    @Test
    fun `首页与导航作用域恢复默认`() {
        val dirty = TimetableSettingsModel(
            homeNavigationForm = HomeNavigationForm.GLASS_DOCK,
            homeMenuStyle = HomeMenuStyle.GRID,
            homeTitleStyle = HomeTitleStyle.BRAND,
            glassDockActions = listOf("day", "week"),
            glassDockShowAddButton = true,
            glassDockButtonEntryId = "overview",
            glassDockButtonIconName = "star",
            glassDockShowDayTab = false,
            glassDockShowSettingsTab = false,
            glassDockShowWeekTab = false,
            homeGridMenuActions = listOf("overview", "settings"),
        )
        val reset = SettingsActionDispatcher.applyResetScope(
            dirty,
            SettingsActionDispatcher.SCOPE_HOME_NAVIGATION,
        )!!
        assertEquals(HomeNavigationForm.CLASSIC, reset.homeNavigationForm)
        assertEquals(HomeTitleStyle.CLASSIC, reset.homeTitleStyle)
        assertEquals(emptyList<String>(), reset.glassDockActions)
        assertFalse(reset.glassDockShowAddButton)
        assertEquals(
            TimetableSettingsModel.DEFAULT_GLASS_DOCK_BUTTON_ENTRY_ID,
            reset.glassDockButtonEntryId,
        )
        assertNull(reset.glassDockButtonIconName)
        // 以下四项 **不纳入** 本作用域（Dart `settings_reset.dart:162-174` 明确排除）：
        // 多清它们就是「按声明的范围多清」——确认框只写「底栏与首页标题」。
        assertEquals(HomeMenuStyle.GRID, reset.homeMenuStyle)
        assertFalse(reset.glassDockShowDayTab)
        assertFalse(reset.glassDockShowSettingsTab)
        assertFalse(reset.glassDockShowWeekTab)
        assertEquals(listOf("overview", "settings"), reset.homeGridMenuActions)
    }

    @Test
    fun `bridge 把模型映射成三个页面状态 含 glassDock 词汇翻译`() {
        val model = TimetableSettingsModel(
            homeNavigationForm = HomeNavigationForm.GLASS_DOCK,
            homeMenuStyle = HomeMenuStyle.GRID,
            homeTitleStyle = HomeTitleStyle.BRAND,
            glassDockActions = listOf("day", "tasks"),
            glassDockShowAddButton = true,
            glassDockButtonEntryId = "overview",
            glassDockButtonIconName = "star",
            homeGridMenuActions = listOf("overview", "settings"),
        )
        val nav = SettingsPageBridge.toHomeNavigationState(model)
        // ⚠️ 关键：磁盘的 glass_dock 必须翻译成页面词汇 glassDock，否则底栏区块不渲染
        assertEquals("glassDock", nav.navigationForm)
        assertEquals("grid", nav.menuStyle)
        assertEquals("brand", nav.titleStyle)
        assertEquals(listOf("day", "tasks"), nav.dockActionIds)
        assertEquals(true, nav.showAddButton)
        assertEquals("overview", nav.dockButtonEntryId)
        assertEquals("star", nav.dockButtonIconName)
        assertEquals(listOf("overview", "settings"), nav.gridMenuActions)

        // classic 形态翻译回 classic
        assertEquals(
            "classic",
            SettingsPageBridge.toHomeNavigationState(TimetableSettingsModel()).navigationForm,
        )

        // 两个编辑器状态：原始 list 直接给，不做 resolve
        val dock = SettingsPageBridge.toGlassDockEditorState(model, debugBuild = true)
        assertEquals(listOf("day", "tasks"), dock.enabledIds)
        assertEquals(true, dock.debugBuild)
        assertEquals(
            listOf("overview", "settings"),
            SettingsPageBridge.toHomeMenuEditorState(model).enabledIds,
        )
    }

    // ================================================================
    // 夹具
    // ================================================================

    /** 取主题管理页控制卡（`theme.current` 那个 inline 节点）。 */
    private fun themeCurrentCard(model: TimetableSettingsModel): SettingsInline =
        SettingsThemeManagePage
            .spec(SettingsPageBridge.toSettingsPageState(model))
            .nodes
            .filterIsInstance<SettingsInline>()
            .first { it.id == "theme.current" }

    private fun dispatch(
        kind: SettingsActionKind,
        target: String?,
        rowId: String,
        model: TimetableSettingsModel = defaults,
    ): SettingsDispatch = SettingsActionDispatcher.dispatch(kind, target, rowId, model)

    private fun write(
        rowId: String,
        target: String?,
        model: TimetableSettingsModel = defaults,
    ): TimetableSettingsModel =
        (dispatch(SettingsActionKind.WRITE_SETTING, target, rowId, model) as SettingsDispatch.Write).model

    private fun specFor(pageId: String, model: TimetableSettingsModel): SettingsPageSpec =
        SettingsPageBridge.specFor(pageId, SettingsPageBridge.toSettingsPageState(model))!!

    /** 在 spec 的所有分组里按 id 找一行。 */
    private fun rowValue(spec: SettingsPageSpec, rowId: String): SettingsRow? =
        spec.nodes
            .filterIsInstance<SettingsGroup>()
            .flatMap { it.children }
            .filterIsInstance<SettingsRow>()
            .firstOrNull { it.id == rowId }

    // ---- 源码守卫用的读取工具（与 CjkLiteralGateTest 同一套定位法）----

    private fun rendererSource(): String =
        File(
            repoRoot(),
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt",
        ).readText(Charsets.UTF_8)

    /** 从 [signature] 起截出函数体（按花括号配平，含签名行本身）。 */
    private fun functionBody(source: String, signature: String): String {
        val start = source.indexOf(signature)
        require(start >= 0) { "渲染层里找不到 `$signature`" }
        val braceStart = source.indexOf('{', start)
        require(braceStart >= 0) { "`$signature` 后面没有函数体" }
        var depth = 0
        for (index in braceStart until source.length) {
            when (source[index]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(start, index + 1)
                }
            }
        }
        error("`$signature` 的花括号没有闭合")
    }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "i18n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（未定位到 i18n/app_zh.arb）")
    }
}
