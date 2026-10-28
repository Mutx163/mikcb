package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.SectionTimeDisplayMode
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.SettingsActionKind
import com.mutx163.qingyu.app.SettingsDispatch
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableTimeColumnWidthMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课表页面设置（settings-timetable-page）的**写路径**：分派器认得这一页的 rowId。
 *
 * 这一批只接「本模型已拥有」的字段（密度组 + 浮钮不透明度）；背景/壁纸/字色待扩模型，
 * 背景色板会被宿主拦成 [SettingsActionDispatcher.ROW_TP_BG_CHIPS] 后 Ignored ——
 * 这里钉住「它绝不会写到课卡统一色上」（那是复用 rowId 的历史坑）。
 */
class SettingsTimetablePageWiringTest {

    private fun model() = TimetableSettingsModel.fromJson(emptyMap())

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

    @Test
    fun `自动充满高度开关取反`() {
        val base = model()
        val next = written(write(SettingsActionDispatcher.ROW_TP_AUTO_FIT, null, base))
        assertEquals(!base.timetableAutoFitSectionHeight, next.timetableAutoFitSectionHeight)
    }

    @Test
    fun `节次高度写入并夹在 48 到 92`() {
        assertEquals(
            70.0,
            written(write(SettingsActionDispatcher.ROW_TP_SECTION_HEIGHT, "70")).sectionHeight,
            0.0,
        )
        assertEquals(
            92.0,
            written(write(SettingsActionDispatcher.ROW_TP_SECTION_HEIGHT, "999")).sectionHeight,
            0.0,
        )
        assertEquals(
            48.0,
            written(write(SettingsActionDispatcher.ROW_TP_SECTION_HEIGHT, "1")).sectionHeight,
            0.0,
        )
    }

    @Test
    fun `时间显示方式：页面词映射到磁盘值`() {
        assertEquals(
            SectionTimeDisplayMode.START_ONLY,
            written(write(SettingsActionDispatcher.ROW_TP_TIME_DISPLAY, "startOnly"))
                .timetableSectionTimeDisplayMode,
        )
        assertEquals(
            SectionTimeDisplayMode.START_AND_END,
            written(write(SettingsActionDispatcher.ROW_TP_TIME_DISPLAY, "startAndEnd"))
                .timetableSectionTimeDisplayMode,
        )
        assertEquals(
            SectionTimeDisplayMode.HIDDEN,
            written(write(SettingsActionDispatcher.ROW_TP_TIME_DISPLAY, "hidden"))
                .timetableSectionTimeDisplayMode,
        )
    }

    @Test
    fun `时间栏宽度与课程卡间距`() {
        assertEquals(
            TimetableTimeColumnWidthMode.WIDE,
            written(write(SettingsActionDispatcher.ROW_TP_TIME_WIDTH, "wide"))
                .timetableTimeColumnWidthMode,
        )
        assertEquals(
            1.5,
            written(write(SettingsActionDispatcher.ROW_TP_CARD_GAP, "1.5")).timetableCourseCardGap,
            0.0,
        )
    }

    @Test
    fun `背景色板被拦成本页常量后 Ignored，不会写成课卡统一色`() {
        val base = model()
        val d = write(SettingsActionDispatcher.ROW_TP_BG_CHIPS, "#123456", base)
        assertTrue("背景色板应 Ignored，实际是 $d", d is SettingsDispatch.Ignored)
        // 关键：它绝不能变成「写课卡统一色」（复用了 ROW_CARD_COLOR_CHIPS 的历史坑）。
        assertTrue(d !is SettingsDispatch.Write)
    }

    @Test
    fun `坏值一律不写`() {
        assertTrue(write(SettingsActionDispatcher.ROW_TP_SECTION_HEIGHT, "abc") is SettingsDispatch.Ignored)
        assertTrue(write(SettingsActionDispatcher.ROW_TP_TIME_DISPLAY, "bogus") is SettingsDispatch.Ignored)
        assertTrue(write(SettingsActionDispatcher.ROW_TP_TIME_WIDTH, "widee") is SettingsDispatch.Ignored)
    }
}
