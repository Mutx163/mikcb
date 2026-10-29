package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.app.BackToCurrentWeekButtonStyle
import com.mutx163.qingyu.app.CourseCardHorizontalAlign
import com.mutx163.qingyu.app.CourseCardSurfaceStyle
import com.mutx163.qingyu.app.CourseCardVerticalAlign
import com.mutx163.qingyu.app.SectionTimeDisplayMode
import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableTimeColumnWidthMode

/**
 * 设置模型 → 周视图渲染风格的**唯一映射点**。
 *
 * ## 为什么单独一个文件（2026-10-29 从 `app/TimetableHostLogic.kt` 挪出来）
 *
 * 这段映射原先写在 `app/TimetableHostLogic.kt` 里，于是 `app/` import 了 `pages.timetable.*`。
 * `app/` 是 L0 的**共享模型目录**（`scripts/test-kotlin-module.ps1` 的 `sharedModelDirs`，
 * **每个模块都无条件收录**），而 `AppLayerPurityTest` 钉着「`app/` 不许 import 任何
 * `pages.<域>`」。违反的后果不是「某个模块红」，是**除 `pages/timetable` 以外的每个模块
 * 跑 L0 都红**，报错文件却在 `app/` 里，别人根本查不到是谁弄的：
 * `a3902f85`（周视图复刻）之后 `-Module "pages/course"` 直接 kotlinc 失败
 * （`unresolved reference 'WeekViewStyle'` 一族，共 5 处）。
 *
 * 挪出来之后依赖方向是 **pages → app**（允许）；反向那一半由守卫机器阻断。
 */
object TimetableStyleMapping {

    /**
     * 从**用户存档**推导周视图渲染风格。
     *
     * 未映射前，渲染层自造了一套值：卡面字段全开、字号 13sp（`footnote2`）、
     * 星期标签「一/二」、今天用蓝胶囊……设置里改哪一项都没反应。这里逐键对上：
     *
     * | 设置键（`lib/models/timetable_settings.dart`） | 本函数去处 |
     * |---|---|
     * | `courseCardShowName/Teacher/Location/Time/TimeLabels/Weeks/Description` | 同名字段 |
     * | `courseCardFontSize`（默认 9）/ `compactFontSize`（9） | `cardTitleFontSize` / `compactFontSize` |
     * | `courseCardVerticalAlign` / `HorizontalAlign` | 同名枚举（页面本地枚举） |
     * | `courseCardSurfaceStyle`：`solid`/`gaussian`/`refraction` | `SOLID`/`GAUSSIAN`/`TRANSLUCENT`（无壁纸时折射档在 Dart 也退化成半透明） |
     * | `timetableUseUnifiedCardColor` + `timetableUnifiedCardColor` | `unifiedCardColorHex`（未开 = null） |
     * | `showConflictBadgeOnTimetable` / `timetableConflictCourseOpacity` | `showConflictBadge` / `conflictCourseOpacity` |
     * | `timetableSectionTimeDisplayMode` | `sectionTimeMode`（**未知值回落 `startAndEnd`**，不是第一项） |
     * | `sectionHeight` / `timetableAutoFitSectionHeight` | `sectionHeightDp` / `autoFitSectionHeight` |
     * | `timetableTimeColumnWidthMode` | `timeColumnWidthDp`（宽 40 / 窄 34） |
     * | `timetableCourseCardGap`（默认 1.25，clamp 0..3） | `cardInsetDp`（Dart `courseCardInset`） |
     * | `timetableShowNonCurrentWeekCourses` / `weekGridShowExams` / `weekGridShowSchedules` | 同名字段 |
     * | `longPressEmptySlotToAddCourseEnabled` / `enableHolidayMarking` | 同名字段 |
     * | `weekdayBarFontColor*` / `weekdayBarAccentColor*` / `timeAxisFontColor*` | 同名字段 |
     * | `courseCardTitleColor*` / `courseCardDetailColor*` | 同名字段 |
     * | `timetableBackToCurrentWeekButtonStyle` | `showBackToCurrentWeek`（读侧恒 `floating`，见枚举 KDoc） |
     * | `timetableFloatingBackToCurrentWeekButtonOpacity` | `backToCurrentWeekOpacity` |
     * | `weatherShowOnWeekCard` | `showWeatherOnCard`（本批未接线，仅保留口径） |
     */
    fun weekViewStyle(model: TimetableSettingsModel): WeekViewStyle = WeekViewStyle(
        showName = model.courseCardShowName,
        showTeacher = model.courseCardShowTeacher,
        showLocation = model.courseCardShowLocation,
        showTime = model.courseCardShowTime,
        showTimeLabels = model.courseCardShowTimeLabels,
        showWeeks = model.courseCardShowWeeks,
        showDescription = model.courseCardShowDescription,
        cardTitleFontSize = model.courseCardFontSize.toFloat(),
        compactFontSize = model.compactFontSize.toFloat(),
        verticalAlign = when (model.courseCardVerticalAlign) {
            CourseCardVerticalAlign.TOP -> WeekCardVerticalAlign.TOP
            CourseCardVerticalAlign.CENTER -> WeekCardVerticalAlign.CENTER
            CourseCardVerticalAlign.BOTTOM -> WeekCardVerticalAlign.BOTTOM
            CourseCardVerticalAlign.SPACE_EVENLY -> WeekCardVerticalAlign.SPACE_EVENLY
        },
        horizontalAlign = when (model.courseCardHorizontalAlign) {
            CourseCardHorizontalAlign.LEFT -> WeekCardHorizontalAlign.LEFT
            CourseCardHorizontalAlign.CENTER -> WeekCardHorizontalAlign.CENTER
            CourseCardHorizontalAlign.RIGHT -> WeekCardHorizontalAlign.RIGHT
        },
        surfaceStyle = when (model.courseCardSurfaceStyle) {
            CourseCardSurfaceStyle.SOLID -> WeekCardSurface.SOLID
            CourseCardSurfaceStyle.GAUSSIAN -> WeekCardSurface.GAUSSIAN
            // 无壁纸/无模糊管线时 Dart 的折射档同样退化成半透明实体。
            CourseCardSurfaceStyle.LIQUID_GLASS -> WeekCardSurface.TRANSLUCENT
        },
        unifiedCardColorHex =
            if (model.timetableUseUnifiedCardColor) model.timetableUnifiedCardColor else null,
        cardTitleColorLight = model.courseCardTitleColorLight,
        cardTitleColorDark = model.courseCardTitleColorDark,
        cardDetailColorLight = model.courseCardDetailColorLight,
        cardDetailColorDark = model.courseCardDetailColorDark,
        showConflictBadge = model.showConflictBadgeOnTimetable,
        conflictCourseOpacity = model.timetableConflictCourseOpacity.toFloat(),
        sectionTimeMode = when (model.timetableSectionTimeDisplayMode) {
            SectionTimeDisplayMode.HIDDEN -> WeekSectionTimeMode.HIDDEN
            SectionTimeDisplayMode.START_ONLY -> WeekSectionTimeMode.START_ONLY
            SectionTimeDisplayMode.START_AND_END -> WeekSectionTimeMode.START_AND_END
        },
        sectionHeightDp = model.sectionHeight.toFloat(),
        autoFitSectionHeight = model.timetableAutoFitSectionHeight,
        timeColumnWidthDp = TimetableHostLogic.timeColumnWidthDp(
            model.timetableTimeColumnWidthMode == TimetableTimeColumnWidthMode.WIDE,
        ),
        // Dart `courseCardInset`：`timetableCourseCardGap.clamp(0, 3)`。
        cardInsetDp = model.timetableCourseCardGap.toFloat().coerceIn(0f, 3f),
        showNonCurrentWeekCourses = model.timetableShowNonCurrentWeekCourses,
        showWeekGridExams = model.weekGridShowExams,
        showWeekGridSchedules = model.weekGridShowSchedules,
        longPressEmptySlotToAddCourse = model.longPressEmptySlotToAddCourseEnabled,
        holidayMarkingEnabled = model.enableHolidayMarking,
        weekdayFontColorLight = model.weekdayBarFontColorLight,
        weekdayFontColorDark = model.weekdayBarFontColorDark,
        weekdayAccentColorLight = model.weekdayBarAccentColorLight,
        weekdayAccentColorDark = model.weekdayBarAccentColorDark,
        timeAxisColorLight = model.timeAxisFontColorLight,
        timeAxisColorDark = model.timeAxisFontColorDark,
        showBackToCurrentWeek =
            model.timetableBackToCurrentWeekButtonStyle == BackToCurrentWeekButtonStyle.FLOATING,
        backToCurrentWeekOpacity =
            model.timetableFloatingBackToCurrentWeekButtonOpacity.toFloat(),
        showWeatherOnCard = model.weatherShowOnWeekCard,
    )
}
