package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.SettingsActionKind
import com.mutx163.qingyu.app.SettingsDispatch
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.app.TimetableStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「课表页面」背景区 / 三行文字色 / 恢复默认的**读写契约**（2026-11-01 补口）。
 *
 * ## 这一批在钉什么
 *
 * 2026-11-01 之前这一页有 8 个「看得见、点不动」的控件：宿主只接 `WRITE_SETTING` /
 * `NAVIGATE`，色板被显式丢弃，背景色 / 壁纸 / 模糊是桥里写死的假值。现在逐个接上后，
 * 本文件钉住四件事（全部是**人推期望值**，不从实现倒推）：
 *
 * 1. **行 id = 分派器常量**：页面模型与分派器各写一份字符串，只要一边改了没同步，
 *    控件就重新变成死按钮——所以逐字比对，而不是只测「点了有回调」；
 * 2. **写对字段**：色板写 `timetablePageBackgroundColor`，**不是**课卡统一色
 *    （渲染层复用了 `ROW_CARD_COLOR_CHIPS`，这是本页最容易写错的一处）；
 * 3. **读回同源**：写回后的模型经 [SettingsPageBridge.toTimetablePageState] 读出来，
 *    必须就是页面上该显示的新值；
 * 4. **落盘**：合并写之后重新 `load()` 仍是新值。
 *
 * ## 不钉什么
 *
 * 宿主里的选色弹窗 / 恢复默认确认框是 Compose 层，JVM 单测看不到；这里只钉它们
 * 依赖的纯逻辑（动作 → 分派器 → 字段）。弹窗接线由 L1 编译与真机验收。
 *
 * ## 仍诚实不可用的两项
 *
 * 「壁纸」「最近使用」两行是 `SHEET`，面板宿主在 `b.backdropFlow` / `b.recentWallpaper`，
 * 但壳路由表还没有这两条出站路由（ShellWiring 属 Lead 写作用域）。宿主现在会明确提示
 * 不可用；**不要把这两条断言改成「已接」**，除非路由表真的补上并在真机上验过。
 */
class SettingsTimetablePageControlsTest {

    private fun page() = SettingsTimetablePageSettingsPage.spec(
        TimetablePageSettingsState(screenshotShareSupported = true),
    )

    private fun model() = TimetableSettingsModel()

    private fun write(
        rowId: String,
        target: String? = null,
        m: TimetableSettingsModel = model(),
    ): SettingsDispatch = SettingsActionDispatcher.dispatch(
        kind = SettingsActionKind.WRITE_SETTING,
        target = target,
        rowId = rowId,
        model = m,
    )

    private fun written(dispatch: SettingsDispatch): TimetableSettingsModel {
        assertTrue("期望 Write，实际是 $dispatch", dispatch is SettingsDispatch.Write)
        return (dispatch as SettingsDispatch.Write).model
    }

    // ------------------------------------------------------------------ 行 id

    @Test
    fun `背景区行 id 与分派器常量逐字一致`() {
        val page = page()
        val chips = page.flatten().filterIsInstance<SettingsInline>()
            .first { it.id == "timetablePage.background.colorChips" }
        // 色板不是 SettingsRow，单独比对。
        assertEquals(SettingsActionDispatcher.ROW_TP_BG_CHIPS, chips.id)
        assertEquals(
            SettingsActionDispatcher.ROW_TP_BG_IMAGE,
            page.row("timetablePage.background.image").id,
        )
        assertEquals(
            SettingsActionDispatcher.ROW_TP_BG_RECENT,
            page.row("timetablePage.background.recent").id,
        )
        assertEquals(
            SettingsActionDispatcher.ROW_TP_BG_FOLLOWS_WEEK,
            page.row("timetablePage.background.followsWeek").id,
        )
        assertEquals(
            SettingsActionDispatcher.ROW_TP_BG_BLUR,
            page.row("timetablePage.background.blur").id,
        )
    }

    @Test
    fun `三行文字色 id 与分派器常量逐字一致且动作是选色器`() {
        val page = page()
        assertEquals(
            SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY,
            page.row("timetablePage.textColors.weekday").id,
        )
        assertEquals(
            SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY_ACCENT,
            page.row("timetablePage.textColors.weekdayAccent").id,
        )
        assertEquals(
            SettingsActionDispatcher.ROW_TP_TEXT_TIME_AXIS,
            page.row("timetablePage.textColors.timeAxis").id,
        )
        listOf(
            "timetablePage.textColors.weekday",
            "timetablePage.textColors.weekdayAccent",
            "timetablePage.textColors.timeAxis",
        ).forEach { id ->
            assertEquals("$id 必须走官方选色器", SettingsAction.COLOR_PICKER, page.row(id).action)
        }
        // 2026-11-01：深色档三行（Dart `_ModeColorSettings` 的第二组）。
        listOf(
            SettingsTimetablePageSettingsPage.ROW_TEXT_WEEKDAY_DARK,
            SettingsTimetablePageSettingsPage.ROW_TEXT_WEEKDAY_ACCENT_DARK,
            SettingsTimetablePageSettingsPage.ROW_TEXT_TIME_AXIS_DARK,
        ).forEach { id ->
            assertEquals("$id 必须走官方选色器", SettingsAction.COLOR_PICKER, page.row(id).action)
        }
    }

    // --------------------------------------------------------------- 背景色板

    @Test
    fun `背景色板写的是课表背景色而不是课卡统一色`() {
        val base = model()
        val next = written(write(SettingsActionDispatcher.ROW_TP_BG_CHIPS, "#FDF6EC", base))
        assertEquals("#FDF6EC", next.timetablePageBackgroundColor)
        // 复用了课卡色板的 rowId，最怕的就是顺手写错字段。
        assertEquals(base.timetableUnifiedCardColor, next.timetableUnifiedCardColor)
        // 读回：页面状态里选中的就是它（色板会有选中环）。
        assertEquals(
            "#FDF6EC",
            SettingsPageBridge.toTimetablePageState(next).pageBackgroundColor,
        )
    }

    @Test
    fun `背景色板拒绝非法色值`() {
        assertTrue(
            "非法色值必须 Ignored，不能塞进存档",
            write(SettingsActionDispatcher.ROW_TP_BG_CHIPS, "red") is SettingsDispatch.Ignored,
        )
    }

    // ------------------------------------------------------------ 随周滑动 / 模糊

    @Test
    fun `背景随周滑动开关取反且读写同源`() {
        val row = page().row("timetablePage.background.followsWeek")
        assertEquals(MiuixRowComponent.SWITCH, row.component)
        assertEquals(SettingsAction.WRITE_SETTING, row.action)

        val base = model()
        val next = written(write(row.id, null, base))
        assertEquals(
            !base.homePageBackdropFollowsWeekPager,
            next.homePageBackdropFollowsWeekPager,
        )
        assertEquals(
            next.homePageBackdropFollowsWeekPager,
            SettingsPageBridge.toTimetablePageState(next).backdropFollowsWeekPager,
        )
    }

    @Test
    fun `壁纸模糊滑杆收口到 0 到 24 且读回同一值`() {
        val row = page().row("timetablePage.background.blur")
        assertEquals(MiuixRowComponent.SLIDER, row.component)
        assertEquals(SettingsAction.WRITE_SETTING, row.action)
        assertEquals(0.0, row.slider!!.min, 0.0)
        assertEquals(24.0, row.slider!!.max, 0.0)

        assertEquals(
            12.0,
            written(write(row.id, "12.0")).homePageWallpaperBlurSigma,
            0.0,
        )
        assertEquals(
            "上界收口（Dart copyWith 同口径）",
            24.0,
            written(write(row.id, "99")).homePageWallpaperBlurSigma,
            0.0,
        )
        assertEquals(
            "下界收口",
            0.0,
            written(write(row.id, "-3")).homePageWallpaperBlurSigma,
            0.0,
        )
        val next = written(write(row.id, "12.0"))
        assertEquals(
            12.0,
            SettingsPageBridge.toTimetablePageState(next).wallpaperBlurSigma,
            0.0,
        )
    }

    // ------------------------------------------------------------------ 文字色

    @Test
    fun `三行文字色都有可读初值且写回对应字段`() {
        val base = model()
        val cases = listOf(
            SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY to { m: TimetableSettingsModel ->
                m.weekdayBarFontColorLight
            },
            SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY_ACCENT to { m: TimetableSettingsModel ->
                m.weekdayBarAccentColorLight
            },
            SettingsActionDispatcher.ROW_TP_TEXT_TIME_AXIS to { m: TimetableSettingsModel ->
                m.timeAxisFontColorLight
            },
        )
        for ((rowId, read) in cases) {
            // ① 选色器要初值；null 就意味着弹出来的是空/默认色。
            assertNotNull("$rowId 没有可读的当前色", SettingsPageBridge.currentColorHex(base, rowId))
            // ② 确认后走同一条 WRITE_SETTING，写回对应字段。
            val next = written(write(rowId, "#112233", base))
            assertEquals("$rowId 写错了字段", "#112233", read(next))
        }
    }

    @Test
    fun `文字色写回后页面读到的就是新色`() {
        val next = written(write(SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY, "#A1B2C3"))
        val state = SettingsPageBridge.toTimetablePageState(next)
        assertEquals("#A1B2C3", state.weekdayBarColor)
        // 三行互不串味：另两行仍是出厂值。
        assertEquals(
            TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_ACCENT_LIGHT,
            state.weekdayBarAccentColor,
        )
        assertEquals(
            TimetableSettingsModel.DEFAULT_TIME_AXIS_FONT_LIGHT,
            state.timeAxisColor,
        )
    }

    @Test
    fun `文字色拒绝非法色值`() {
        assertTrue(
            write(SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY, "not-a-color")
                is SettingsDispatch.Ignored,
        )
    }

    // ------------------------------------------------------------------ 恢复默认

    @Test
    fun `恢复默认行指向课表页面作用域且分派器真的能恢复`() {
        val row = page().row("timetablePage.reset.row")
        assertEquals(SettingsAction.RESET_SCOPE, row.action)
        assertEquals(
            SettingsResetScope.TIMETABLE_PAGE,
            SettingsResetScope.fromArg(row.actionTarget!!),
        )

        // 2026-11-01 前 applyResetScope 没有 timetablePage 分支：确认框点了确认也一个
        // 字段都不写。现在必须真的返回新模型，并覆盖这一页声明的作用域。
        val changed = model().copy(
            timetableHideWeekends = true,
            timetablePageBackgroundColor = "#ECFDF5",
            homePageWallpaperPath = "/files/a.jpg",
            homePageBackdropFollowsWeekPager = true,
            homePageWallpaperBlurSigma = 18.0,
            weekdayBarFontColorLight = "#112233",
        )
        val reset = SettingsActionDispatcher.applyResetScope(
            changed,
            SettingsTimetablePageSettingsPage.RESET_SCOPE_TIMETABLE_PAGE,
        )
        assertNotNull("恢复默认作用域未实现 = 确认框是假的", reset)
        reset!!

        assertEquals(false, reset.timetableHideWeekends)
        assertEquals(
            TimetableSettingsModel.DEFAULT_TIMETABLE_PAGE_BACKGROUND_COLOR,
            reset.timetablePageBackgroundColor,
        )
        assertEquals(false, reset.homePageBackdropFollowsWeekPager)
        assertEquals(0.0, reset.homePageWallpaperBlurSigma, 0.0)
        assertEquals(
            TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_FONT_LIGHT,
            reset.weekdayBarFontColorLight,
        )
        // 壁纸指针必须真的清：只改状态不清路径就是「背景还在」。
        assertNull(reset.homePageWallpaperPath)
        assertNull(reset.homePageBackgroundImagePath)
    }

    // ------------------------------------------------------------- 落盘 / 读回

    @Test
    fun `写回后合并落盘再加载仍是新值`() {
        val raw = InMemoryKeyValueStore(mapOf("timetable_settings" to "{}"))
        val store = TimetableSettingsModelStore(TimetableStore(raw))
        val seeded = store.load()

        val next = written(
            write(SettingsActionDispatcher.ROW_TP_BG_FOLLOWS_WEEK, null, seeded),
        )
        store.save(next)

        val reloaded = store.load()
        assertEquals(
            next.homePageBackdropFollowsWeekPager,
            reloaded.homePageBackdropFollowsWeekPager,
        )
        assertEquals(
            next.homePageBackdropFollowsWeekPager,
            SettingsPageBridge.toTimetablePageState(reloaded).backdropFollowsWeekPager,
        )
    }

    // ------------------------------------------------------- 诚实的未接线项

    @Test
    fun `壁纸与最近使用仍是 SHEET 且没有被伪装成已接`() {
        // 面板宿主（b.backdropFlow / b.recentWallpaper）已存在，但壳路由表还没有这两条
        // 出站路由；宿主遇到 SHEET 会明确提示不可用。等 Lead 补路由后，这两条断言应改成
        // 「action == NAVIGATE 且 target 有落点」。
        assertEquals(
            SettingsAction.SHEET,
            page().row("timetablePage.background.image").action,
        )
        assertEquals(
            SettingsAction.SHEET,
            page().row("timetablePage.background.recent").action,
        )
    }
}
