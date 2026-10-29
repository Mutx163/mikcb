package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 周视图渲染风格（`WeekViewStyle` / [weekSectionHeight]）单测。
 *
 * 期望值全部由 Dart 真源人推，**不抄 Kotlin 实现**：
 * - 节高公式：`lib/domain/timetable_layout.dart:38-50`（`gridSectionHeight`）——
 *   未开「自动充满」或节数 ≤ 0 时返回设置里的节高；否则
 *   `(可用高 - 星期栏高 - 玻璃缝隙) / 节数`，先 clamp 到 ≥ 0（`chromeSeam` 传 0 时即本函数口径）；
 * - 构造默认值：`lib/models/timetable_settings.dart:754-784`、`:760-780`、`:813-815`、
 *   `:914-915`、`:927`、`:283`，以及 `timetable_layout.dart:12-17`（时间列窄档 34）。
 */
class WeekViewStyleTest {

    // ------------------------------------------------------------------
    // 节高：未开自动充满
    // ------------------------------------------------------------------

    @Test
    fun `未开自动充满时节高直接用设置值`() {
        val style = WeekViewStyle(sectionHeightDp = 72f, autoFitSectionHeight = false)
        assertEquals(
            "设置节高是唯一来源，不随可用高变化",
            72f,
            weekSectionHeight(style, availableHeightDp = 900f, weekdayHeaderHeightDp = 40f, sectionCount = 12),
            0.001f,
        )
        assertEquals(
            72f,
            weekSectionHeight(style, availableHeightDp = 120f, weekdayHeaderHeightDp = 40f, sectionCount = 3),
            0.001f,
        )
    }

    // ------------------------------------------------------------------
    // 节高：开了自动充满
    // ------------------------------------------------------------------

    @Test
    fun `开自动充满时按可用高减去星期栏再按节数均分`() {
        val style = WeekViewStyle(autoFitSectionHeight = true)
        // (800 - 40) / 10 = 76
        assertEquals(
            76f,
            weekSectionHeight(style, availableHeightDp = 800f, weekdayHeaderHeightDp = 40f, sectionCount = 10),
            0.001f,
        )
        // (740 - 40) / 10 = 70，验证是「逐项算」而不是拍了固定值
        assertEquals(
            70f,
            weekSectionHeight(style, availableHeightDp = 740f, weekdayHeaderHeightDp = 40f, sectionCount = 10),
            0.001f,
        )
        // (800 - 40) / 12 ≈ 63.333（Dart 侧同样不做上限 clamp）
        assertEquals(
            760f / 12f,
            weekSectionHeight(style, availableHeightDp = 800f, weekdayHeaderHeightDp = 40f, sectionCount = 12),
            0.001f,
        )
    }

    @Test
    fun `节数为零或负数时回落设置节高`() {
        val style = WeekViewStyle(autoFitSectionHeight = true, sectionHeightDp = 68f)
        assertEquals(
            "节数 0 无从均分，Dart :44 回落 settings.sectionHeight",
            68f,
            weekSectionHeight(style, availableHeightDp = 800f, weekdayHeaderHeightDp = 40f, sectionCount = 0),
            0.001f,
        )
        assertEquals(
            68f,
            weekSectionHeight(style, availableHeightDp = 800f, weekdayHeaderHeightDp = 40f, sectionCount = -3),
            0.001f,
        )
    }

    @Test
    fun `可用高不足时给 0 而不是负数`() {
        val style = WeekViewStyle(autoFitSectionHeight = true)
        // 可用高 100 减星期栏 200 ⇒ body clamp 到 0 ⇒ 0 / 10 = 0（Dart :47-49 的 clamp）
        assertEquals(
            0f,
            weekSectionHeight(style, availableHeightDp = 100f, weekdayHeaderHeightDp = 200f, sectionCount = 10),
            0.001f,
        )
        assertEquals(
            "正好相等 ⇒ 0",
            0f,
            weekSectionHeight(style, availableHeightDp = 200f, weekdayHeaderHeightDp = 200f, sectionCount = 10),
            0.001f,
        )
        assertTrue(
            "任何输入都不返回负数",
            weekSectionHeight(style, availableHeightDp = -50f, weekdayHeaderHeightDp = 40f, sectionCount = 8) >= 0f,
        )
    }

    // ------------------------------------------------------------------
    // 构造默认值逐项对齐 Dart
    // ------------------------------------------------------------------

    @Test
    fun `课卡内容开关默认与 Dart 构造默认一致`() {
        val style = WeekViewStyle()
        // timetable_settings.dart:765-771
        assertTrue("courseCardShowName = true", style.showName)
        assertTrue("courseCardShowTeacher = true", style.showTeacher)
        assertTrue("courseCardShowLocation = true", style.showLocation)
        assertFalse("courseCardShowTime = false", style.showTime)
        assertTrue("courseCardShowTimeLabels = true", style.showTimeLabels)
        assertFalse("courseCardShowWeeks = false", style.showWeeks)
        assertFalse("courseCardShowDescription = false", style.showDescription)
    }

    @Test
    fun `课卡排版默认字号 9 与居中对齐`() {
        val style = WeekViewStyle()
        // timetable_settings.dart:782 courseCardFontSize = 9 / :755 compactFontSize = 9
        assertEquals(9f, style.cardTitleFontSize, 0.001f)
        assertEquals(9f, style.compactFontSize, 0.001f)
        // :780 courseCardVerticalAlign = center / :781 courseCardHorizontalAlign = center
        assertEquals(WeekCardVerticalAlign.CENTER, style.verticalAlign)
        assertEquals(WeekCardHorizontalAlign.CENTER, style.horizontalAlign)
        // :927 courseCardSurfaceStyle = solid
        assertEquals(WeekCardSurface.SOLID, style.surfaceStyle)
        // :914-915 / :283 defaultCourseCardTitleColor = '#FFFFFF'
        assertEquals("#FFFFFF", style.cardTitleColorLight)
        assertEquals("#FFFFFF", style.cardTitleColorDark)
        assertEquals("#FFFFFF", style.cardDetailColorLight)
        assertEquals("#FFFFFF", style.cardDetailColorDark)
        assertNull("未开「统一卡片颜色」", style.unifiedCardColorHex)
    }

    @Test
    fun `密度与时间列默认值对齐 Dart`() {
        val style = WeekViewStyle()
        // timetable_settings.dart:754 sectionHeight = 68
        assertEquals(68f, style.sectionHeightDp, 0.001f)
        // :756 timetableAutoFitSectionHeight = false
        assertFalse(style.autoFitSectionHeight)
        // timetable_layout.dart:12-17：narrow 档 = 34
        assertEquals(34f, style.timeColumnWidthDp, 0.001f)
        // :784 timetableCourseCardGap = 1.25
        assertEquals(1.25f, style.cardInsetDp, 0.001f)
        // 时间列读侧缺省 startAndEnd（SectionTimeDisplayMode）
        assertEquals(WeekSectionTimeMode.START_AND_END, style.sectionTimeMode)
    }

    @Test
    fun `冲突与非本周开关默认值对齐 Dart`() {
        val style = WeekViewStyle()
        // :763 showConflictBadgeOnTimetable = true
        assertTrue(style.showConflictBadge)
        // :764 timetableConflictCourseOpacity = 0.70
        assertEquals(0.70f, style.conflictCourseOpacity, 0.001f)
        // :762 timetableShowNonCurrentWeekCourses = false
        assertFalse(style.showNonCurrentWeekCourses)
    }

    @Test
    fun `周网格内容开关默认值对齐 Dart`() {
        val style = WeekViewStyle()
        // :772 weekGridShowExams = true / :773 weekGridShowSchedules = true
        assertTrue(style.showWeekGridExams)
        assertTrue(style.showWeekGridSchedules)
        // :824 longPressEmptySlotToAddCourseEnabled = false
        assertFalse(style.longPressEmptySlotToAddCourse)
        // :760 enableHolidayMarking = true
        assertTrue(style.holidayMarkingEnabled)
        // :775 weatherShowOnWeekCard = true
        assertTrue(style.showWeatherOnCard)
        // :813-815 回本周浮钮：读侧恒 floating、默认不透明 0.96
        assertTrue(style.showBackToCurrentWeek)
        assertEquals(0.96f, style.backToCurrentWeekOpacity, 0.001f)
    }

    @Test
    fun `墨色默认值对齐 Dart`() {
        val style = WeekViewStyle()
        assertEquals("#000000", style.weekdayFontColorLight)
        assertEquals("#FFFFFF", style.weekdayFontColorDark)
        assertEquals("#2563EB", style.weekdayAccentColorLight)
        assertEquals("#93C5FD", style.weekdayAccentColorDark)
        assertEquals("#757575", style.timeAxisColorLight)
        assertEquals("#FFFFFF", style.timeAxisColorDark)
    }

    @Test
    fun `默认风格的节高走设置值，开了自动充满才均分`() {
        // 把「默认值」与「节高公式」串起来：默认 autoFit=false ⇒ 68dp 原样返回。
        assertEquals(
            68f,
            weekSectionHeight(WeekViewStyle(), availableHeightDp = 900f, weekdayHeaderHeightDp = 40f, sectionCount = 12),
            0.001f,
        )
        assertEquals(
            (900f - 40f) / 12f,
            weekSectionHeight(
                WeekViewStyle(autoFitSectionHeight = true),
                availableHeightDp = 900f,
                weekdayHeaderHeightDp = 40f,
                sectionCount = 12,
            ),
            0.001f,
        )
    }
}
