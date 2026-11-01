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
 * 2026-11-01 起扩展模型覆盖到背景组（背景色 / 背景图 / 随周次滑动 / 模糊）与三根
 * 文字颜色；此前背景色板会被拦成 [SettingsActionDispatcher.ROW_TP_BG_CHIPS] 后 Ignored。
 * 这里钉住两件事：**真的写进了本页字段**，且**绝不会写到课卡统一色上**
 * （复用 rowId 是 2026-10 的历史坑）。
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
    fun `背景色板写进本页背景色 不会写成课卡统一色`() {
        val base = model()
        val next = written(write(SettingsActionDispatcher.ROW_TP_BG_CHIPS, "#123456", base))
        assertEquals("#123456", next.timetablePageBackgroundColor)
        // 关键：它绝不能变成「写课卡统一色」（复用了 ROW_CARD_COLOR_CHIPS 的历史坑）。
        assertEquals(base.timetableUnifiedCardColor, next.timetableUnifiedCardColor)
    }

    @Test
    fun `坏值一律不写`() {
        assertTrue(write(SettingsActionDispatcher.ROW_TP_SECTION_HEIGHT, "abc") is SettingsDispatch.Ignored)
        assertTrue(write(SettingsActionDispatcher.ROW_TP_TIME_DISPLAY, "bogus") is SettingsDispatch.Ignored)
        assertTrue(write(SettingsActionDispatcher.ROW_TP_TIME_WIDTH, "widee") is SettingsDispatch.Ignored)
    }
}
