package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「课表页面」设置里截屏检测开关一行的**可见性判据**。
 *
 * 人推期望值（Dart `settings_timetable_page.dart:227` `if (_screenshotShareSupported)`）：
 * - 能力探测为 false（Android 14 以下 / 未知）→ 整行不出现，不是禁用态；
 * - 能力探测为 true → 行出现在「密度」组里，行 id 与分派器常量逐字一致
 *   （行 id 两处各写一份字符串，不同步就变死按钮，照 ControlsTest 同一条纪律比对）；
 * - 桥的**缺省值**保持 false（保守口径：能力没接线时宁可隐藏，不给一个永远无效的开关）。
 *
 * 真实 `ScreenCaptureWatcher.isSupported` 读 `Build.VERSION.SDK_INT`（Android 类），
 * JVM 单测碰不到；这里钉的是「判据怎么决定行出现不出现」，SDK 阈值 34 由
 * `ScreenCaptureWatchLogicTest` 那边钉。
 */
class ScreenshotShareRowVisibilityTest {

    private fun state(supported: Boolean): TimetablePageSettingsState =
        SettingsPageBridge.toTimetablePageState(
            TimetableSettingsModel(),
            screenshotShareSupported = supported,
        )

    @Test
    fun `桥的缺省能力值是 false 保守口径`() {
        val defaulted = SettingsPageBridge.toTimetablePageState(TimetableSettingsModel())
        assertFalse(defaulted.screenshotShareSupported)
    }

    @Test
    fun `能力为 true 时行出现在密度组且行 id 与分派器常量一致`() {
        val ids = SettingsTimetablePageSettingsPage.densityRowIds(state(supported = true))
        assertTrue(
            "支持的机型上应出现截屏检测开关行，实际 $ids",
            SettingsActionDispatcher.ROW_TP_SCREENSHOT in ids,
        )
        // 行 id 不是随便写的字符串：与分派器的写入口逐字一致才点得动。
        assertTrue(ids.contains("timetablePage.screenshotShare"))
        assertEquals("timetablePage.screenshotShare", SettingsActionDispatcher.ROW_TP_SCREENSHOT)
    }

    @Test
    fun `能力为 false 时整行不出现`() {
        val ids = SettingsTimetablePageSettingsPage.densityRowIds(state(supported = false))
        assertFalse(
            "不支持的机型上不该出现截屏检测开关行，实际 $ids",
            SettingsActionDispatcher.ROW_TP_SCREENSHOT in ids,
        )
    }

    @Test
    fun `开关写入口翻转的是 screenshotSharePromptEnabled`() {
        // 行可见性之外顺手钉一下：这一行的开关动作写对字段（可见性行接错字段就是死开关）。
        val base = TimetableSettingsModel()
        val dispatch = SettingsActionDispatcher.dispatch(
            kind = com.mutx163.qingyu.app.SettingsActionKind.WRITE_SETTING,
            target = null,
            rowId = SettingsActionDispatcher.ROW_TP_SCREENSHOT,
            model = base,
        )
        assertTrue("期望 Write，实际 $dispatch", dispatch is com.mutx163.qingyu.app.SettingsDispatch.Write)
        val next = (dispatch as com.mutx163.qingyu.app.SettingsDispatch.Write).model
        assertEquals(!base.screenshotSharePromptEnabled, next.screenshotSharePromptEnabled)
    }
}
