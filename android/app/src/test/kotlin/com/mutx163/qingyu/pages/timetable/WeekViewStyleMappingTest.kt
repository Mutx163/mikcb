package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.app.CourseCardHorizontalAlign
import com.mutx163.qingyu.app.CourseCardSurfaceStyle
import com.mutx163.qingyu.app.CourseCardVerticalAlign
import com.mutx163.qingyu.app.SectionTimeDisplayMode
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableTimeColumnWidthMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `TimetableStyleMapping.weekViewStyle`（设置模型 → 周视图渲染风格）的单测。
 *
 * ## 为什么从 `app/TimetableHostLogicTest` 挪过来（2026-10-29）
 *
 * 这段映射原先住在 `app/TimetableHostLogic.kt`，测试也住在 `app/` 的测试包里。
 * 但 `app/` 不许 import `pages.<域>`（`AppLayerPurityTest` 的第一条不变量：
 * `app/` 是每个模块都收的共享目录，一旦反向依赖某个页面域，**除该域以外所有模块**的
 * L0 都会红）。映射搬到 [TimetableStyleMapping] 之后，测试跟着被测代码走。
 *
 * 期望值全部**手推**：照 Dart `lib/models/timetable_settings.dart` 的构造默认与读侧缺省
 * 一条条推出来，不从实现里抄。
 */
class WeekViewStyleMappingTest {

    @Test
    fun `默认存档推导出的周视图风格与 Dart 构造默认一致`() {
        val style = TimetableStyleMapping.weekViewStyle(TimetableSettingsModel())

        // Dart :1405-1413：内容七个开关，只有「显示时间/周次/简介」默认关。
        assertTrue(style.showName)
        assertTrue(style.showTeacher)
        assertTrue(style.showLocation)
        assertFalse(style.showTime)
        assertTrue(style.showTimeLabels)
        assertFalse(style.showWeeks)
        assertFalse(style.showDescription)
        // :1432 / :1386：课卡字号 9、紧凑字号 9。
        assertEquals(9f, style.cardTitleFontSize)
        assertEquals(9f, style.compactFontSize)
        // :1426/:1429：居中。
        assertEquals(WeekCardVerticalAlign.CENTER, style.verticalAlign)
        assertEquals(WeekCardHorizontalAlign.CENTER, style.horizontalAlign)
        // 材质默认实体；没开统一色 ⇒ 不覆盖课程自己的颜色。
        assertEquals(WeekCardSurface.SOLID, style.surfaceStyle)
        assertNull(style.unifiedCardColorHex)
        // :1400 + 默认冲突透明度 0.70。
        assertTrue(style.showConflictBadge)
        assertEquals(0.70f, style.conflictCourseOpacity)
        // 时间列读侧缺省 startAndEnd（NOT 第一项 hidden）。
        assertEquals(WeekSectionTimeMode.START_AND_END, style.sectionTimeMode)
        // :1385 sectionHeight=68；窄时间列 34；卡片内缩 = gap 1.25。
        assertEquals(68f, style.sectionHeightDp)
        assertFalse(style.autoFitSectionHeight)
        assertEquals(34f, style.timeColumnWidthDp)
        assertEquals(1.25f, style.cardInsetDp)
        // :1531 / :1416-1417 / :1541：非本周默认隐藏、考试日程默认显示、长按默认关。
        assertFalse(style.showNonCurrentWeekCourses)
        assertTrue(style.showWeekGridExams)
        assertTrue(style.showWeekGridSchedules)
        assertFalse(style.longPressEmptySlotToAddCourse)
        // BackToCurrentWeekButtonStyle 读侧恒 floating ⇒ 浮钮默认显示。
        assertTrue(style.showBackToCurrentWeek)
    }

    @Test
    fun `自定义存档逐键进入周视图风格（含枚举与 clamp）`() {
        val custom = TimetableSettingsModel().copy(
            courseCardShowTeacher = false,
            courseCardFontSize = 12.0,
            compactFontSize = 10.0,
            courseCardVerticalAlign = CourseCardVerticalAlign.TOP,
            courseCardHorizontalAlign = CourseCardHorizontalAlign.RIGHT,
            courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS,
            timetableUseUnifiedCardColor = true,
            timetableUnifiedCardColor = "#123456",
            showConflictBadgeOnTimetable = false,
            timetableConflictCourseOpacity = 0.5,
            timetableSectionTimeDisplayMode = SectionTimeDisplayMode.HIDDEN,
            sectionHeight = 72.0,
            timetableAutoFitSectionHeight = true,
            timetableTimeColumnWidthMode = TimetableTimeColumnWidthMode.WIDE,
            // 故意超上限：Dart `courseCardInset` 是 `gap.clamp(0, 3)`。
            timetableCourseCardGap = 5.0,
            timetableShowNonCurrentWeekCourses = true,
            weekGridShowExams = false,
            weekGridShowSchedules = false,
            longPressEmptySlotToAddCourseEnabled = true,
            weekdayBarFontColorLight = "#111111",
            weekdayBarAccentColorDark = "#222222",
            timeAxisFontColorDark = "#333333",
            timetableFloatingBackToCurrentWeekButtonOpacity = 0.8,
            weatherShowOnWeekCard = false,
        )
        val style = TimetableStyleMapping.weekViewStyle(custom)

        assertFalse(style.showTeacher)
        assertEquals(12f, style.cardTitleFontSize)
        assertEquals(10f, style.compactFontSize)
        assertEquals(WeekCardVerticalAlign.TOP, style.verticalAlign)
        assertEquals(WeekCardHorizontalAlign.RIGHT, style.horizontalAlign)
        // 无壁纸时 Dart 的折射档退化成半透明实体。
        assertEquals(WeekCardSurface.TRANSLUCENT, style.surfaceStyle)
        assertEquals("#123456", style.unifiedCardColorHex)
        assertFalse(style.showConflictBadge)
        assertEquals(0.5f, style.conflictCourseOpacity)
        assertEquals(WeekSectionTimeMode.HIDDEN, style.sectionTimeMode)
        assertEquals(72f, style.sectionHeightDp)
        assertTrue(style.autoFitSectionHeight)
        assertEquals(40f, style.timeColumnWidthDp)
        assertEquals(3f, style.cardInsetDp)
        assertTrue(style.showNonCurrentWeekCourses)
        assertFalse(style.showWeekGridExams)
        assertFalse(style.showWeekGridSchedules)
        assertTrue(style.longPressEmptySlotToAddCourse)
        assertEquals("#111111", style.weekdayFontColorLight)
        assertEquals("#222222", style.weekdayAccentColorDark)
        assertEquals("#333333", style.timeAxisColorDark)
        assertEquals(0.8f, style.backToCurrentWeekOpacity)
        assertFalse(style.showWeatherOnCard)
    }
}
