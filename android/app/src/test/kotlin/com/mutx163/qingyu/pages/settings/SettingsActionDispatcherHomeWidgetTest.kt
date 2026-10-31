package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.SettingsActionKind
import com.mutx163.qingyu.app.SettingsDispatch
import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 桌面小组件页的**写路径 / 重置路径**（F20-A）。
 *
 * 期望值手推自 Dart：
 * - 行 id：`lib/screens/settings/settings_home_widget.dart` 的控件与 `SettingsHomeWidgetPage.kt` 的 spec；
 * - 落盘字段与合法串：`lib/models/timetable_settings.dart:1103-1112` / `:1444-1461`；
 * - 高度滑杆是**相对默认档（-11）的偏移**：`settings_home_widget.dart:344-359`；
 * - 圆角滑杆是绝对值、默认 22 ±14：`:366-372`；
 * - 提前量十档（0 + 9 档）：`:306-319`；
 * - 恢复默认作用域：`settings_reset.dart:175-189`。
 *
 * ⚠️ 本文件的 package 是 `pages.settings`（L0 只收这个测试目录），
 * 而分派器在 `app/`，所以这里 import 它——方向是「测试 → app」，与生产代码的
 * 「app 不依赖 pages.settings」边界不冲突。
 */
class SettingsActionDispatcherHomeWidgetTest {

    private val defaults = TimetableSettingsModel()

    private fun dispatch(
        target: String?,
        rowId: String,
        model: TimetableSettingsModel = defaults,
    ): SettingsDispatch =
        SettingsActionDispatcher.dispatch(SettingsActionKind.WRITE_SETTING, target, rowId, model)

    /** 写一行并取出新模型（不是 Write 就说明接线错了，直接失败）。 */
    private fun writeModel(
        target: String?,
        rowId: String,
        model: TimetableSettingsModel = defaults,
    ): TimetableSettingsModel {
        val result = dispatch(target, rowId, model)
        assertTrue("$rowId 应该是 Write，实际是 $result", result is SettingsDispatch.Write)
        return (result as SettingsDispatch.Write).model
    }

    private fun assertIgnored(target: String?, rowId: String, reasonPart: String? = null) {
        val result = dispatch(target, rowId)
        assertTrue("$rowId/$target 应该 Ignored，实际是 $result", result is SettingsDispatch.Ignored)
        val ignored = result as SettingsDispatch.Ignored
        assertEquals(SettingsActionKind.WRITE_SETTING, ignored.kind)
        assertEquals(rowId, ignored.rowId)
        if (reasonPart != null) {
            assertTrue(
                "理由里应包含 `$reasonPart`，实际：${ignored.reason}",
                ignored.reason.contains(reasonPart),
            )
        }
    }

    // ------------------------------------------------------ 常量与页面逐字一致

    @Test
    fun `10 个 rowId 常量与页面 spec 的行 id 逐字一致`() {
        val ids = SettingsHomeWidgetPage.spec(SettingsHomeWidgetState()).rows().map { it.id }

        assertEquals(
            listOf(
                SettingsActionDispatcher.ROW_HOME_WIDGET_BACKGROUND_STYLE,
                SettingsActionDispatcher.ROW_HOME_WIDGET_COURSE_ACCENT,
                SettingsActionDispatcher.ROW_HOME_WIDGET_SHOW_LOCATION,
                SettingsActionDispatcher.ROW_HOME_WIDGET_SHOW_COUNTDOWN,
                SettingsActionDispatcher.ROW_HOME_WIDGET_HIDE_COMPLETED,
                SettingsActionDispatcher.ROW_HOME_WIDGET_SHOW_TOMORROW,
                SettingsActionDispatcher.ROW_HOME_WIDGET_COUNTDOWN_LEAD,
                SettingsActionDispatcher.ROW_HOME_WIDGET_COUNTDOWN_STYLE,
                SettingsActionDispatcher.ROW_HOME_WIDGET_HEIGHT_ADJUST,
                SettingsActionDispatcher.ROW_HOME_WIDGET_CORNER_RADIUS,
            ).filterNot { it in ids },
            emptyList<String>(),
        )
    }

    @Test
    fun `两个 RUN_NOW 行的常量指向页面上的预览块与权限引导条`() {
        // 权限引导条只在「精确闹钟未授权」时出现（`settings_home_widget.dart:212`），
        // 所以要给它 false 才能看到那个 inline 块。
        val ids = SettingsHomeWidgetPage
            .spec(SettingsHomeWidgetState(exactAlarmGranted = false))
            .flattenedIds()

        // 权限引导条是独立的 inline 块，id 就是分派器常量（`:493-496`）。
        assertTrue(SettingsActionDispatcher.ROW_HOME_WIDGET_ALARM_GRANT in ids)
        // 「添加到桌面」当前是预览 inline 内部的按钮文案（渲染层还没有独立 rowId）；
        // 分派器常量是宿主执行 RUN_NOW 时用的 id，页面容器 id 是 homeWidget.preview。
        assertTrue("homeWidget.preview" in ids)
    }

    // ---------------------------------------------------------- 每个可写行

    @Test
    fun `背景样式三档都写进 widgetBackgroundStyle`() {
        listOf("glass", "solid", "gradient").forEach { value ->
            val model = writeModel(value, SettingsActionDispatcher.ROW_HOME_WIDGET_BACKGROUND_STYLE)
            assertEquals(value, model.widgetBackgroundStyle)
        }
    }

    @Test
    fun `课程颜色三档都写进 widgetCourseAccentMode`() {
        listOf("off", "bar", "bar_and_text").forEach { value ->
            val model = writeModel(value, SettingsActionDispatcher.ROW_HOME_WIDGET_COURSE_ACCENT)
            assertEquals(value, model.widgetCourseAccentMode)
        }
    }

    @Test
    fun `四个开关 target 为空时取反当前值`() {
        val off = TimetableSettingsModel(
            widgetShowLocation = true,
            widgetShowCountdown = true,
            widgetHideCompletedCourses = false,
            widgetShowTomorrowCourses = true,
        )

        assertFalse(
            writeModel(null, SettingsActionDispatcher.ROW_HOME_WIDGET_SHOW_LOCATION, off)
                .widgetShowLocation,
        )
        assertFalse(
            writeModel(null, SettingsActionDispatcher.ROW_HOME_WIDGET_SHOW_COUNTDOWN, off)
                .widgetShowCountdown,
        )
        assertTrue(
            writeModel(null, SettingsActionDispatcher.ROW_HOME_WIDGET_HIDE_COMPLETED, off)
                .widgetHideCompletedCourses,
        )
        assertFalse(
            writeModel(null, SettingsActionDispatcher.ROW_HOME_WIDGET_SHOW_TOMORROW, off)
                .widgetShowTomorrowCourses,
        )

        // 再点一次 = 回到原值（取反是幂等的两次操作）
        val once = writeModel(null, SettingsActionDispatcher.ROW_HOME_WIDGET_SHOW_LOCATION, off)
        assertTrue(
            writeModel(null, SettingsActionDispatcher.ROW_HOME_WIDGET_SHOW_LOCATION, once)
                .widgetShowLocation,
        )
    }

    @Test
    fun `倒计时提前量 0 与九档都能写`() {
        val allowed = listOf(0, 1, 5, 10, 15, 20, 30, 40, 50, 60)
        assertEquals(10, allowed.size)
        allowed.forEach { minutes ->
            val model = writeModel(
                minutes.toString(),
                SettingsActionDispatcher.ROW_HOME_WIDGET_COUNTDOWN_LEAD,
            )
            assertEquals(minutes, model.widgetCountdownLeadMinutes)
        }
    }

    @Test
    fun `倒计时样式十二档都能写`() {
        TimetableSettingsModel.WIDGET_COUNTDOWN_TEXT_STYLES.forEach { value ->
            val model = writeModel(value, SettingsActionDispatcher.ROW_HOME_WIDGET_COUNTDOWN_STYLE)
            assertEquals(value, model.widgetCountdownTextStyle)
        }
    }

    @Test
    fun `高度滑杆读数是偏移 存储值等于 -11 加偏移`() {
        // 0 = 默认档
        assertEquals(
            -11.0,
            writeModel("0", SettingsActionDispatcher.ROW_HOME_WIDGET_HEIGHT_ADJUST)
                .widgetHeightAdjustment,
            0.0,
        )
        assertEquals(
            -6.0,
            writeModel("5", SettingsActionDispatcher.ROW_HOME_WIDGET_HEIGHT_ADJUST)
                .widgetHeightAdjustment,
            0.0,
        )
        assertEquals(
            -27.0,
            writeModel("-16", SettingsActionDispatcher.ROW_HOME_WIDGET_HEIGHT_ADJUST)
                .widgetHeightAdjustment,
            0.0,
        )
    }

    @Test
    fun `高度偏移越界被夹到 -16 到 16`() {
        assertEquals(
            5.0,
            writeModel("40", SettingsActionDispatcher.ROW_HOME_WIDGET_HEIGHT_ADJUST)
                .widgetHeightAdjustment,
            0.0,
        )
        assertEquals(
            -27.0,
            writeModel("-40", SettingsActionDispatcher.ROW_HOME_WIDGET_HEIGHT_ADJUST)
                .widgetHeightAdjustment,
            0.0,
        )
    }

    @Test
    fun `圆角是绝对值 越界被夹到 8 到 36`() {
        assertEquals(
            30.0,
            writeModel("30", SettingsActionDispatcher.ROW_HOME_WIDGET_CORNER_RADIUS)
                .widgetCornerRadius,
            0.0,
        )
        assertEquals(
            36.0,
            writeModel("100", SettingsActionDispatcher.ROW_HOME_WIDGET_CORNER_RADIUS)
                .widgetCornerRadius,
            0.0,
        )
        assertEquals(
            8.0,
            writeModel("0", SettingsActionDispatcher.ROW_HOME_WIDGET_CORNER_RADIUS)
                .widgetCornerRadius,
            0.0,
        )
    }

    // ------------------------------------------------------------- 非法值

    @Test
    fun `非法下拉串与越界档位一律 Ignored 不改模型`() {
        assertIgnored("neon", SettingsActionDispatcher.ROW_HOME_WIDGET_BACKGROUND_STYLE)
        // gradient 是背景的合法档，但不是课程颜色的合法档（颜色只有 off/bar/bar_and_text）
        assertIgnored("gradient", SettingsActionDispatcher.ROW_HOME_WIDGET_COURSE_ACCENT)
        assertIgnored("smart_xx", SettingsActionDispatcher.ROW_HOME_WIDGET_COUNTDOWN_STYLE)
        // 7 不在九档里；-1/61 同理
        assertIgnored("7", SettingsActionDispatcher.ROW_HOME_WIDGET_COUNTDOWN_LEAD)
        assertIgnored("61", SettingsActionDispatcher.ROW_HOME_WIDGET_COUNTDOWN_LEAD)
        assertIgnored("abc", SettingsActionDispatcher.ROW_HOME_WIDGET_COUNTDOWN_LEAD)
        assertIgnored("abc", SettingsActionDispatcher.ROW_HOME_WIDGET_HEIGHT_ADJUST)
        assertIgnored("abc", SettingsActionDispatcher.ROW_HOME_WIDGET_CORNER_RADIUS)
        // 下拉少了 target 也算非法（这一行不是开关，不能「取反」）
        assertIgnored(null, SettingsActionDispatcher.ROW_HOME_WIDGET_BACKGROUND_STYLE)
        assertIgnored(null, SettingsActionDispatcher.ROW_HOME_WIDGET_COURSE_ACCENT)
        assertIgnored(null, SettingsActionDispatcher.ROW_HOME_WIDGET_COUNTDOWN_STYLE)
    }

    // --------------------------------------------------------------- RUN_NOW

    @Test
    fun `RUN_NOW 两行当设置写时 Ignored 且理由写明由宿主执行`() {
        listOf(
            SettingsActionDispatcher.ROW_HOME_WIDGET_PREVIEW_ADD,
            SettingsActionDispatcher.ROW_HOME_WIDGET_ALARM_GRANT,
        ).forEach { rowId ->
            assertIgnored(null, rowId, "宿主")
        }
    }

    @Test
    fun `RUN_NOW 动作本身仍交给宿主 不被分派器吞掉`() {
        assertEquals(
            SettingsDispatch.RunNow(SettingsActionDispatcher.ROW_HOME_WIDGET_PREVIEW_ADD),
            SettingsActionDispatcher.dispatch(
                SettingsActionKind.RUN_NOW,
                null,
                SettingsActionDispatcher.ROW_HOME_WIDGET_PREVIEW_ADD,
                defaults,
            ),
        )
        assertEquals(
            SettingsDispatch.RunNow(SettingsActionDispatcher.ROW_HOME_WIDGET_ALARM_GRANT),
            SettingsActionDispatcher.dispatch(
                SettingsActionKind.RUN_NOW,
                null,
                SettingsActionDispatcher.ROW_HOME_WIDGET_ALARM_GRANT,
                defaults,
            ),
        )
    }

    // ------------------------------------------------------------ 恢复默认

    @Test
    fun `reset scope homeWidget 只把这 10 个字段拨回默认`() {
        val modified = TimetableSettingsModel(
            widgetBackgroundStyle = "gradient",
            widgetCourseAccentMode = "off",
            widgetShowLocation = false,
            widgetShowCountdown = false,
            widgetHideCompletedCourses = true,
            widgetShowTomorrowCourses = false,
            widgetHeightAdjustment = 5.0,
            widgetCornerRadius = 36.0,
            widgetCountdownLeadMinutes = 60,
            widgetCountdownTextStyle = "second_only_slash",
            // 不属于本作用域的字段（一个都不能被顺手清掉）
            enableHaptics = false,
            appTextScale = 1.3,
            courseCardShowName = false,
            glassDockShowAddButton = true,
            timetableHideWeekends = true,
        )

        val reset = SettingsActionDispatcher.applyResetScope(
            modified,
            SettingsActionDispatcher.SCOPE_HOME_WIDGET,
        )

        assertTrue("homeWidget 作用域应被识别", reset != null)
        assertEquals(SettingsActionDispatcher.SCOPE_HOME_WIDGET, "homeWidget")
        assertEquals(
            modified.copy(
                widgetBackgroundStyle = "solid",
                widgetCourseAccentMode = "bar_and_text",
                widgetShowLocation = true,
                widgetShowCountdown = true,
                widgetHideCompletedCourses = false,
                widgetShowTomorrowCourses = true,
                widgetCountdownLeadMinutes = 20,
                widgetCountdownTextStyle = "smart",
                widgetHeightAdjustment = -11.0,
                widgetCornerRadius = 22.0,
            ),
            reset,
        )
        assertNotEquals(modified, reset)
    }

    @Test
    fun `未知作用域仍返回 null`() {
        assertEquals(null, SettingsActionDispatcher.applyResetScope(defaults, "nope"))
    }
}
