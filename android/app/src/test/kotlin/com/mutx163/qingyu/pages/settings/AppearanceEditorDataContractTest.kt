package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.AppThemeMode
import com.mutx163.qingyu.app.BackToCurrentWeekButtonStyle
import com.mutx163.qingyu.app.CourseCardSurfaceStyle as AppCourseCardSurfaceStyle
import com.mutx163.qingyu.app.HomePageBackgroundFill
import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.LiquidGlassTuningModel
import com.mutx163.qingyu.app.SectionTimeDisplayMode
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.SettingsActionKind
import com.mutx163.qingyu.app.SettingsDispatch
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.app.TimetableTimeColumnWidthMode
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 外观编辑家族的数据层**契约**：
 * 「设置键 → 模型字段 → 序列化名 → 分派器落盘 / 恢复默认 → 桥接 state」逐环咬合。
 *
 * 与 `AppearanceEditorBridgeTest` 的分工：
 * - 那个文件钉的是「模型 → 页面状态」的逐键映射；
 * - 本文件钉的是**反方向**：磁盘键名、写回、恢复默认、以及桥接入口真的把传进来的
 *   state 带到了页面上。
 *
 * 现有单测的缺口（见审计 §4.1）：只断言「对象存在」「常量存在」，没有一条断言
 * 「dispatch 之后模型的字段变了」「传进去的 state 真的被页面用了」。本文件补的就是
 * TEST-POLICY 要求的「直接断言目标对象实例字段」。
 */
class AppearanceEditorDataContractTest {

    // ------------------------------------------------------------------ 工具

    private fun json(text: String): Map<String, Any?> = MiniJson.parse(text) as Map<String, Any?>

    private fun rawSettings(store: InMemoryKeyValueStore): Map<String, Any?> =
        json(store.getString("timetable_settings")!!)

    private fun write(
        target: String?,
        rowId: String,
        model: TimetableSettingsModel = TimetableSettingsModel(),
    ): SettingsDispatch = SettingsActionDispatcher.dispatch(
        SettingsActionKind.WRITE_SETTING,
        target,
        rowId,
        model,
    )

    private fun writeModel(
        target: String?,
        rowId: String,
        model: TimetableSettingsModel = TimetableSettingsModel(),
    ): TimetableSettingsModel {
        val dispatch = write(target, rowId, model)
        assertTrue("rowId=$rowId target=$target 应落成写设置，实际是 $dispatch",
            dispatch is SettingsDispatch.Write)
        return (dispatch as SettingsDispatch.Write).model
    }

    // ------------------------------------------------------------ 1. 背景键

    @Test
    fun `课表背景与时间列模糊四个键：默认值、序列化名、读侧默认逐字照 Dart`() {
        val defaults = TimetableSettingsModel()
        // `timetable_settings.dart:891` / `:892` / `:893` / `:938`
        assertEquals("#F8FAFC", defaults.timetablePageBackgroundColor)
        assertEquals(HomePageBackgroundFill.COLOR, defaults.homePageBackgroundFill)
        assertNull(defaults.homePageBackgroundImagePath)
        assertFalse(defaults.homePageTimeColumnBlurEnabled)

        // 缺键回落（`:1698-1699` / `:1700-1702` / `:1703-1704` / `:1847-1848`）
        val empty = TimetableSettingsModel.fromJson(emptyMap())
        assertEquals("#F8FAFC", empty.timetablePageBackgroundColor)
        assertEquals(HomePageBackgroundFill.COLOR, empty.homePageBackgroundFill)
        assertNull(empty.homePageBackgroundImagePath)
        assertFalse(empty.homePageTimeColumnBlurEnabled)

        // 值都在（含写侧键名：JSON 里必须逐字叫这些）
        val patch = TimetableSettingsModel(
            timetablePageBackgroundColor = "#123456",
            homePageBackgroundFill = HomePageBackgroundFill.IMAGE,
            homePageBackgroundImagePath = "/data/legacy.png",
            homePageTimeColumnBlurEnabled = true,
        ).toJsonPatch()
        assertEquals("#123456", patch["timetablePageBackgroundColor"])
        assertEquals("image", patch["homePageBackgroundFill"])
        assertEquals("/data/legacy.png", patch["homePageBackgroundImagePath"])
        assertEquals(true, patch["homePageTimeColumnBlurEnabled"])

        // 四个键都要进 OWNED_KEYS，否则合并写会漏（另一个结构守卫也要求两边一致）
        val owned = TimetableSettingsModel.OWNED_KEYS
        listOf(
            "timetablePageBackgroundColor",
            "homePageBackgroundFill",
            "homePageBackgroundImagePath",
            "homePageTimeColumnBlurEnabled",
        ).forEach { key ->
            assertTrue("OWNED_KEYS 缺少 $key", key in owned)
        }
    }

    @Test
    fun `未知背景填充串回落 color 与 Dart fromValue 同口径`() {
        assertEquals(
            HomePageBackgroundFill.COLOR,
            HomePageBackgroundFill.fromValue("gaussian"),
        )
        assertEquals(
            HomePageBackgroundFill.IMAGE,
            HomePageBackgroundFill.fromValue("image"),
        )
        assertEquals(
            HomePageBackgroundFill.IMAGE,
            TimetableSettingsModel
                .fromJson(mapOf("homePageBackgroundFill" to "image"))
                .homePageBackgroundFill,
        )
    }

    @Test
    fun `背景字段经合并写往返：盘上键名不变 别的键一个不少`() {
        val store = InMemoryKeyValueStore(
            mapOf(
                "timetable_settings" to """
                    {"semesterWeekCount":18,"someFutureKey":"keep-me"}
                """.trimIndent(),
            ),
        )
        val modelStore = TimetableSettingsModelStore(TimetableStore(store))
        modelStore.save(
            TimetableSettingsModel(
                timetablePageBackgroundColor = "#ECFDF5",
                homePageBackgroundFill = HomePageBackgroundFill.IMAGE,
                homePageBackgroundImagePath = "/data/legacy.png",
                homePageTimeColumnBlurEnabled = true,
            ),
        )

        val raw = rawSettings(store)
        // 1) 键名逐字一致，值是落盘串不是枚举名以外的东西
        assertEquals("#ECFDF5", raw["timetablePageBackgroundColor"])
        assertEquals("image", raw["homePageBackgroundFill"])
        assertEquals("/data/legacy.png", raw["homePageBackgroundImagePath"])
        assertEquals(true, raw["homePageTimeColumnBlurEnabled"])
        // 2) `homePageBackgroundScope` 已下线：Dart 不写（:1233），这边也不许写
        assertFalse("已下线的键不许重新落盘", raw.containsKey("homePageBackgroundScope"))
        // 3) 别人的键保留
        assertEquals(18L, (raw["semesterWeekCount"] as Number).toLong())
        assertEquals("keep-me", raw["someFutureKey"])

        // 4) 读回来等于写进去
        val reloaded = modelStore.load()
        assertEquals("#ECFDF5", reloaded.timetablePageBackgroundColor)
        assertEquals(HomePageBackgroundFill.IMAGE, reloaded.homePageBackgroundFill)
        assertEquals("/data/legacy.png", reloaded.homePageBackgroundImagePath)
        assertTrue(reloaded.homePageTimeColumnBlurEnabled)
        // 5) 读侧不看存档里的旧值（Dart :1725 恒默认）
        assertEquals(
            TimetableSettingsModel.DEFAULT_HOME_PAGE_BACKGROUND_SCOPE,
            TimetableSettingsModel
                .fromJson(mapOf("homePageBackgroundScope" to 1))
                .homePageBackgroundScope,
        )
    }

    // ------------------------------------------------- 2. 分派器：写盘键映射

    @Test
    fun `课表页背景与文字颜色每一个 rowId 都真的落到模型字段`() {
        // 背景色板（Dart `settings_timetable_page.dart:337-349`）
        assertEquals(
            "#123456",
            writeModel("#123456", SettingsActionDispatcher.ROW_TP_BG_CHIPS)
                .timetablePageBackgroundColor,
        )

        // 背景随周次滑动：与壁纸面板是同一个开关（取反）
        val followsOff = TimetableSettingsModel(homePageBackdropFollowsWeekPager = false)
        assertTrue(
            writeModel(null, SettingsActionDispatcher.ROW_TP_BG_FOLLOWS_WEEK, followsOff)
                .homePageBackdropFollowsWeekPager,
        )
        val followsOn = TimetableSettingsModel(homePageBackdropFollowsWeekPager = true)
        assertFalse(
            writeModel(null, SettingsActionDispatcher.ROW_TP_BG_FOLLOWS_WEEK, followsOn)
                .homePageBackdropFollowsWeekPager,
        )

        // 背景模糊：与壁纸面板同口径，0~24 收口
        assertEquals(
            12.0,
            writeModel("12", SettingsActionDispatcher.ROW_TP_BG_BLUR)
                .homePageWallpaperBlurSigma,
            0.0,
        )
        assertEquals(
            24.0,
            writeModel("99", SettingsActionDispatcher.ROW_TP_BG_BLUR)
                .homePageWallpaperBlurSigma,
            0.0,
        )

        // 三根文字颜色
        assertEquals(
            "#AABBCC",
            writeModel("#AABBCC", SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY)
                .weekdayBarFontColorLight,
        )
        assertEquals(
            "#112233",
            writeModel("#112233", SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY_ACCENT)
                .weekdayBarAccentColorLight,
        )
        assertEquals(
            "#445566",
            writeModel("#445566", SettingsActionDispatcher.ROW_TP_TEXT_TIME_AXIS)
                .timeAxisFontColorLight,
        )
    }

    @Test
    fun `非法色值与数字一律 Ignored 不改模型`() {
        val base = TimetableSettingsModel(timetablePageBackgroundColor = "#F8FAFC")
        val bad = write("not-a-color", SettingsActionDispatcher.ROW_TP_BG_CHIPS, base)
        assertTrue(bad is SettingsDispatch.Ignored)
        assertEquals("#F8FAFC", base.timetablePageBackgroundColor)

        assertTrue(
            write("not-a-number", SettingsActionDispatcher.ROW_TP_BG_BLUR, base)
                is SettingsDispatch.Ignored,
        )
        assertTrue(
            write("zzz", SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY, base)
                is SettingsDispatch.Ignored,
        )
    }

    @Test
    fun `清除图片只清两条路径 取景参数保留`() {
        val base = TimetableSettingsModel(
            homePageWallpaperPath = "/data/new.jpg",
            homePageBackgroundImagePath = "/data/legacy.jpg",
            homePageWallpaperAlignX = -0.5,
            homePageWallpaperAlignY = 0.5,
            homePageWallpaperScale = 2.0,
        )
        val cleared = writeModel(null, SettingsActionDispatcher.ROW_BACKDROP_IMAGE_CLEAR, base)
        assertNull(cleared.homePageWallpaperPath)
        assertNull(cleared.homePageBackgroundImagePath)
        // Dart 只清路径（:458-470），取景仍在，从历史切回来要能还原
        assertEquals(-0.5, cleared.homePageWallpaperAlignX, 0.0)
        assertEquals(0.5, cleared.homePageWallpaperAlignY, 0.0)
        assertEquals(2.0, cleared.homePageWallpaperScale, 0.0)
    }

    // ------------------------------------------------------ 3. 恢复默认作用域

    @Test
    fun `timetablePage 作用域逐字段回默认 并清掉两条背景路径`() {
        val dirty = TimetableSettingsModel(
            timetableAutoFitSectionHeight = true,
            timetableHideWeekends = true,
            timetableShowNonCurrentWeekCourses = true,
            longPressEmptySlotToAddCourseEnabled = true,
            weekGridShowExams = false,
            weekGridShowSchedules = false,
            screenshotSharePromptEnabled = false,
            timetableSectionTimeDisplayMode = SectionTimeDisplayMode.HIDDEN,
            timetableTimeColumnWidthMode = TimetableTimeColumnWidthMode.WIDE,
            sectionHeight = 90.0,
            timetableCourseCardGap = 3.0,
            timetableBackToCurrentWeekButtonStyle = BackToCurrentWeekButtonStyle.INLINE,
            timetableFloatingBackToCurrentWeekButtonOpacity = 0.6,
            timetablePageBackgroundColor = "#000000",
            homePageBackdropFollowsWeekPager = true,
            homePageWallpaperBlurSigma = 20.0,
            homePageBackgroundScope = 1,
            weekdayBarFontColorLight = "#111111",
            weekdayBarFontColorDark = "#222222",
            weekdayBarAccentColorLight = "#333333",
            weekdayBarAccentColorDark = "#444444",
            timeAxisFontColorLight = "#555555",
            timeAxisFontColorDark = "#666666",
            homePageWallpaperPath = "/data/wall.jpg",
            homePageBackgroundImagePath = "/data/legacy.jpg",
            // 不属于本作用域：一个都不许被顺手清掉
            appThemeMode = AppThemeMode.DARK,
            appFontWeight = 800,
            courseCardShowName = false,
            frostedBlurEnabled = false,
            liquidGlassPreset = "level3",
        )

        val reset = SettingsActionDispatcher.applyResetScope(
            dirty,
            SettingsActionDispatcher.SCOPE_TIMETABLE_PAGE,
        )
        assertTrue("timetablePage 作用域应被识别（2026-11-01 前这里返回 null）", reset != null)

        val expected = dirty.copy(
            timetableAutoFitSectionHeight = false,
            timetableHideWeekends = false,
            timetableShowNonCurrentWeekCourses = false,
            longPressEmptySlotToAddCourseEnabled = false,
            weekGridShowExams = true,
            weekGridShowSchedules = true,
            screenshotSharePromptEnabled = true,
            timetableSectionTimeDisplayMode = SectionTimeDisplayMode.START_AND_END,
            timetableTimeColumnWidthMode = TimetableTimeColumnWidthMode.NARROW,
            sectionHeight = 68.0,
            timetableCourseCardGap = TimetableSettingsModel.DEFAULT_COURSE_CARD_GAP,
            timetableBackToCurrentWeekButtonStyle = BackToCurrentWeekButtonStyle.FLOATING,
            timetableFloatingBackToCurrentWeekButtonOpacity = 0.96,
            timetablePageBackgroundColor =
            TimetableSettingsModel.DEFAULT_TIMETABLE_PAGE_BACKGROUND_COLOR,
            homePageBackdropFollowsWeekPager = false,
            homePageWallpaperBlurSigma = 0.0,
            homePageBackgroundScope =
            TimetableSettingsModel.DEFAULT_HOME_PAGE_BACKGROUND_SCOPE,
            weekdayBarFontColorLight = TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_FONT_LIGHT,
            weekdayBarFontColorDark = TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_FONT_DARK,
            weekdayBarAccentColorLight = TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_ACCENT_LIGHT,
            weekdayBarAccentColorDark = TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_ACCENT_DARK,
            timeAxisFontColorLight = TimetableSettingsModel.DEFAULT_TIME_AXIS_FONT_LIGHT,
            timeAxisFontColorDark = TimetableSettingsModel.DEFAULT_TIME_AXIS_FONT_DARK,
            homePageWallpaperPath = null,
            homePageBackgroundImagePath = null,
        )
        assertEquals(expected, reset)
        assertNotEquals(dirty, reset)

        // 与「恢复默认」页声明的字段表互相对齐：表里列的每个字段都真的被重置。
        val declared = SettingsResetScope.TIMETABLE_PAGE.fields
        assertTrue("timetablePage 声明里应有 timetablePageBackgroundColor",
            "timetablePageBackgroundColor" in declared)
        assertTrue("timetablePage 声明里应有 homePageBackgroundScope",
            "homePageBackgroundScope" in declared)
        assertEquals(
            "清空标记必须覆盖两条背景路径",
            setOf("clearHomePageWallpaperPath", "clearHomePageBackgroundImagePath"),
            SettingsResetScope.TIMETABLE_PAGE.clearFlags.toSet(),
        )
    }

    @Test
    fun `appearance 作用域把材质轴一起拨回默认 三个可空 tuning 必须清空`() {
        val tuning = LiquidGlassTuningModel(
            refraction = 7.0, refractionBand = 11.0, refractionEdgePow = 2.25,
            dispersion = 0.33, rimStrength = 0.22, rimWidth = 1.4,
            blurSigma = 12.0, tintAlpha = 0.6,
        )
        val dirty = TimetableSettingsModel(
            appThemeMode = AppThemeMode.DARK,
            appFontWeight = 900,
            themeSeedColor = "#EC003F",
            frostedBlurEnabled = false,
            liquidGlassPreset = "level7",
            liquidGlassTuning = tuning,
            liquidGlassTuningDark = tuning,
            courseCardGlassPreset = "level5",
            courseCardGlassTuning = tuning,
            linkLiquidGlassTuning = false,
            darkGlassBoostEnabled = false,
            liquidGlassDockEnabled = false,
            courseCardSurfaceStyle = AppCourseCardSurfaceStyle.LIQUID_GLASS,
            homeBandGlassMaterial = "solid",
            homePageTimeColumnBlurEnabled = true,
            // 不属于本作用域
            timetableHideWeekends = true,
            homePageWallpaperPath = "/data/wall.jpg",
            timetablePageBackgroundColor = "#000000",
        )

        val reset = SettingsActionDispatcher.applyResetScope(
            dirty,
            SettingsActionDispatcher.SCOPE_APPEARANCE,
        )!!

        val expected = dirty.copy(
            appThemeMode = AppThemeMode.SYSTEM,
            appFontMode = com.mutx163.qingyu.app.AppFontMode.SYSTEM,
            appFontWeight = TimetableSettingsModel.APP_FONT_WEIGHT_DEFAULT,
            appTextScale = TimetableSettingsModel.APP_TEXT_SCALE_DEFAULT,
            foruiTheme = com.mutx163.qingyu.app.ForuiTheme.MIUI,
            themeSeedColor = SettingsActionDispatcher.RESET_THEME_SEED_COLOR,
            frostedBlurEnabled = true,
            liquidGlassPreset = TimetableSettingsModel.LIQUID_GLASS_PRESET_STANDARD,
            liquidGlassTuning = null,
            liquidGlassTuningDark = null,
            courseCardGlassPreset = TimetableSettingsModel.LIQUID_GLASS_PRESET_STANDARD,
            courseCardGlassTuning = null,
            linkLiquidGlassTuning = true,
            darkGlassBoostEnabled = true,
            liquidGlassDockEnabled = true,
            courseCardSurfaceStyle = AppCourseCardSurfaceStyle.SOLID,
            homeBandGlassMaterial = TimetableSettingsModel.DEFAULT_HOME_BAND_GLASS_MATERIAL,
            homePageTimeColumnBlurEnabled = false,
        )
        assertEquals(expected, reset)

        // 声明表与实现对拍（表在 SettingsResetPage，实现在分派器）
        val declared = SettingsResetScope.APPEARANCE.fields
        listOf(
            "courseCardGlassPreset",
            "frostedBlurEnabled",
            "liquidGlassPreset",
            "linkLiquidGlassTuning",
            "darkGlassBoostEnabled",
            "liquidGlassDockEnabled",
            "courseCardSurfaceStyle",
            "homeBandGlassMaterial",
            "homePageTimeColumnBlurEnabled",
        ).forEach { field ->
            assertTrue("外观作用域声明缺少 $field", field in declared)
        }
        assertEquals(
            setOf(
                "clearLiquidGlassTuning",
                "clearLiquidGlassTuningDark",
                "clearCourseCardGlassTuning",
            ),
            SettingsResetScope.APPEARANCE.clearFlags.toSet(),
        )
    }

    // ---------------------------------------------------------- 4. 桥接真值

    @Test
    fun `课表页 state 读背景真值不是写死默认`() {
        val model = TimetableSettingsModel(
            timetablePageBackgroundColor = "#ECFDF5",
            homePageWallpaperPath = "/data/wall.jpg",
            homePageBackgroundImagePath = "/data/legacy.jpg",
            homePageBackdropFollowsWeekPager = true,
            homePageWallpaperBlurSigma = 9.0,
            weekdayBarFontColorLight = "#010203",
            weekdayBarAccentColorLight = "#040506",
            timeAxisFontColorLight = "#070809",
        )
        val state = SettingsPageBridge.toTimetablePageState(model)
        assertEquals("#ECFDF5", state.pageBackgroundColor)
        // 新壁纸优先
        assertEquals("/data/wall.jpg", state.imagePath)
        assertTrue(state.backdropFollowsWeekPager)
        assertEquals(9.0, state.wallpaperBlurSigma, 0.0)
        assertEquals("#010203", state.weekdayBarColor)
        assertEquals("#040506", state.weekdayBarAccentColor)
        assertEquals("#070809", state.timeAxisColor)
    }

    @Test
    fun `背景图解析：新壁纸优先 旧字段兜底 空串按没有`() {
        fun resolve(wallpaper: String?, legacy: String?) =
            SettingsPageBridge.resolveHomePageBackdropImagePath(
                TimetableSettingsModel(
                    homePageWallpaperPath = wallpaper,
                    homePageBackgroundImagePath = legacy,
                ),
            )

        assertEquals("/new.jpg", resolve("/new.jpg", "/old.jpg"))
        assertEquals("/old.jpg", resolve(null, "/old.jpg"))
        assertEquals("/old.jpg", resolve("", "/old.jpg"))
        assertNull(resolve("", ""))
        assertNull(resolve(null, null))
    }

    @Test
    fun `桥的五个外观家族页 id 都拿得到 spec 且传进去的 state 真被用上`() {
        val state = SettingsPageState()

        // 材质通用页：总闸两档跟着 MaterialPanelState 走
        val solid = SettingsPageBridge.specFor(
            SettingsMaterialGeneralPage.ID,
            state,
            material = MaterialPanelState(frostedBlurEnabled = false),
        )
        assertEquals(SettingsMaterialGeneralPage.ID, solid!!.id)
        assertEquals(
            "solid",
            solid.row("material.general.glassMode.row").selectedOptionId,
        )

        // 课程卡片页：卡片外观档来自 SettingsPageState
        val card = SettingsPageBridge.specFor(
            SettingsMaterialCourseCardPage.ID,
            SettingsPageState(courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS),
            material = MaterialPanelState(),
        )
        assertEquals(SettingsMaterialCourseCardPage.ID, card!!.id)
        assertEquals(
            "refraction",
            card.row("material.courseCard.surfaceStyle.row").selectedOptionId,
        )

        // 外观编辑整页
        val editor = SettingsPageBridge.specFor(SettingsAppearanceEditorPage.ID, state)
        assertEquals(SettingsAppearanceEditorPage.ID, editor!!.id)

        // 壁纸面板第一页：文件名来自传进去的 BackdropFlowState
        val picker = SettingsPageBridge.specFor(
            SettingsBackdropFlowPage.SELECTION_SPEC_ID,
            state,
            backdrop = BackdropFlowState(imagePath = "/data/wall.jpg"),
        )
        assertEquals("wall.jpg", picker!!.row("backdrop.image").subtitle)

        // 最近使用页：条目来自 RecentWallpaperState
        val recent = SettingsPageBridge.specFor(
            SettingsPageBridge.RECENT_WALLPAPER_SPEC_ID,
            state,
            recent = RecentWallpaperState(
                entries = listOf("/data/a.jpg", "/data/b.jpg"),
                selectedKey = "/data/a.jpg",
            ),
        )
        assertEquals(SettingsBridgeTestIds.RECENT, recent!!.id)
        assertTrue(recent.flattenedIds().contains("backdrop.recent.strip"))

        // 白名单与 specFor 不许两张表走散
        SettingsPageBridge.APPEARANCE_PAGE_IDS.forEach { id ->
            assertTrue("$id 在 APPEARANCE_PAGE_IDS 里但 specFor 拿不到", SettingsPageBridge.specFor(id, state) != null)
        }
    }

    @Test
    fun `最近使用页 id 常量与页面 spec 逐字一致`() {
        // SettingsRecentWallpaperPage 没有导出 ID 常量，桥里先抄一份；这条防两边漂。
        assertEquals(
            SettingsBridgeTestIds.RECENT,
            SettingsPageBridge.RECENT_WALLPAPER_SPEC_ID,
        )
        assertEquals(
            SettingsPageBridge.RECENT_WALLPAPER_SPEC_ID,
            SettingsRecentWallpaperSection.spec(RecentWallpaperState()).id,
        )
    }

    @Test
    fun `壁纸状态派生：面板状态到壁纸流程与最近使用页`() {
        val wallpaper = WallpaperPanelState(
            path = "/data/current.jpg",
            followsWeekPager = true,
            blurSigma = 6.0,
            history = listOf(
                WallpaperHistoryRow(key = "/data/current.jpg", label = "current.jpg"),
                WallpaperHistoryRow(key = "/data/old.jpg", label = "old.jpg"),
            ),
        )
        val backdrop = SettingsPageBridge.toBackdropFlowState(wallpaper)
        assertEquals("/data/current.jpg", backdrop.imagePath)
        assertEquals(listOf("/data/current.jpg", "/data/old.jpg"), backdrop.history)
        assertTrue(backdrop.followsWeekPager)
        assertEquals(6.0, backdrop.blurSigma, 0.0)
        assertFalse("图库台账不在设置模型里，不许伪造可用", backdrop.bingAutoApplyEnabled)

        val recent = SettingsPageBridge.toRecentWallpaperState(wallpaper)
        assertEquals(listOf("/data/current.jpg", "/data/old.jpg"), recent.entries)
        assertEquals("/data/current.jpg", recent.selectedKey)
    }

    // ------------------------------------------------- 5. 与 Dart 原件对拍

    @Test
    fun `四个背景与时间列键在 Dart 原件里逐字存在`() {
        val dart = dartModelSource()
        listOf(
            "'timetablePageBackgroundColor': timetablePageBackgroundColor",
            "'homePageBackgroundFill': homePageBackgroundFill.value",
            "'homePageBackgroundImagePath': homePageBackgroundImagePath",
            "'homePageTimeColumnBlurEnabled': homePageTimeColumnBlurEnabled",
        ).forEach { line ->
            assertTrue("Dart 写侧缺少 $line", line in dart)
        }
        listOf(
            "this.timetablePageBackgroundColor = '#F8FAFC'",
            "this.homePageBackgroundFill = HomePageBackgroundFill.color",
            "this.homePageTimeColumnBlurEnabled = false",
        ).forEach { line ->
            assertTrue("Dart 构造默认缺少 $line", line in dart)
        }
        assertTrue(
            "Dart 读侧默认必须是 #F8FAFC",
            "lenientString(json['timetablePageBackgroundColor']) ?? '#F8FAFC'" in dart,
        )
        assertTrue(
            "homePageBackgroundScope 必须仍是下线口径（恒默认、不写键）",
            "homePageBackgroundScope: HomePageBackgroundScope.defaultValue" in dart &&
                "// homePageBackgroundScope 已下线（壁纸整体透出），不再写入。" in dart,
        )
    }

    // ------------------------------------------------------------------ 工具

    private fun dartModelSource(): String {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "lib/models/timetable_settings.dart")
            if (candidate.isFile) return candidate.readText()
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 lib/models/timetable_settings.dart —— 对拍无法进行，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }

    /**
     * 页面里写死的 id 字面量（页面对象没有导出常量的那两处）。
     * 测试里集中一份，方便肉眼核对。
     */
    private object SettingsBridgeTestIds {
        const val RECENT = "settings-recent-wallpaper"
    }
}
