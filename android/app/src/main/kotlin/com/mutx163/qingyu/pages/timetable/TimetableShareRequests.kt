package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableSettings
import java.time.LocalDate

/**
 * 宿主侧「分享哪张图」的组装入口（纯 Kotlin，JVM 可测）。
 *
 * ## 为什么单独一层
 *
 * 与 Dart `timetable_share_export.dart`（`shareTimetableImage`）同位：只有**页面**知道
 * 用户正看着哪一周、周视图还是日视图（Compose 侧由 `TimetableWeekPage` 的
 * `onShareScreenshot(week, dayOfWeek)` 回调给出），而**宿主**才有课表数据快照。
 * 本层把「数据快照 + 周次 + 视图」折成一张 [TimetableShareImageModel.Document]，
 * 渲染与分享层只消费它——谁拼文档、谁付依赖，Dart 的注释原话。
 *
 * **参数透传契约**：`dayOfWeek` 丢失会静默变成分享整周（Dart
 * `share_export_document_contract_test.dart` 点名的风险），所以组装结果里的
 * `dayOfWeek` / `dayRows` 必须有单测直接断言（见 `TimetableShareImageModelTest`）。
 */
object TimetableShareRequests {

    /**
     * 周图：整周网格。
     *
     * 排版复用 [WeekGridCourseMapping.cardsForWeek]（屏上周网格同一份域逻辑）；
     * 表头日期 / 今天高亮走 [TimetableDateLogic]（模型层唯一日期实现）。
     */
    fun weekDocument(
        courses: List<Course>,
        week: Int,
        settings: TimetableSettings,
        style: WeekViewStyle,
        visibleDays: List<Int>,
        today: LocalDate,
    ): TimetableShareImageModel.Document {
        val cards = WeekGridCourseMapping.cardsForWeek(
            courses = courses,
            week = week,
            style = style,
            visibleDays = visibleDays,
        )
        val semesterStart = settings.semesterStartDate?.toLocalDate()
        val weekdayDates = visibleDays.associateWith { dayOfWeek ->
            TimetableDateLogic.dateForWeekDay(semesterStart, week, dayOfWeek)
                ?.let(TimetableShareImageModel::weekdayDateText)
        }
        val todayDayOfWeek = visibleDays.firstOrNull { dayOfWeek ->
            TimetableDateLogic.dateForWeekDay(semesterStart, week, dayOfWeek) == today
        }
        val weekdayLabels = visibleDays.associateWith { dayOfWeek ->
            TimetableStrings.formatWeekday(dayOfWeek)
        }
        return TimetableShareImageModel.buildWeekDocument(
            week = week,
            cardsByDay = cards,
            sections = settings.sections,
            sectionTimeMode = style.sectionTimeMode,
            style = style,
            visibleDays = visibleDays,
            weekdayLabels = weekdayLabels,
            weekdayDates = weekdayDates,
            todayDayOfWeek = todayDayOfWeek,
            // 导出图恒浅色：强调色取亮色档（Dart 导出文档的固定浅色口径同源）。
            accentHex = style.weekdayAccentColorLight,
            title = TimetableStrings.timetableShareExportWeek(week),
            weekCompactLabel = TimetableStrings.formatCurrentWeekCompact(week),
            overlineLabels = mapOf(
                WeekCardOverline.NON_CURRENT_WEEK to TimetableStrings.nonCurrentWeekLabel.zh,
                WeekCardOverline.CONFLICT to TimetableStrings.conflictLabel.zh,
            ),
            shareText = TimetableStrings.timetableShareText.zh,
        )
    }

    /**
     * 日图：当天的课按时间排成列表（Dart `_buildDaySurface`）。
     *
     * 取数与周网格同一份域逻辑（[WeekGridCourseMapping.coursesForDay] +
     * [WeekGridCourseMapping.visibleDayCourses]），保证「显示非本周课程」开着时
     * 两个视图画同一门课。
     *
     * @param subtitle 副标题；null = 调用方算不出（开学日没配），不显示（Dart `_dateLabel` 同口径）。
     */
    fun dayDocument(
        courses: List<Course>,
        week: Int,
        dayOfWeek: Int,
        settings: TimetableSettings,
        showNonCurrentWeekCourses: Boolean = false,
    ): TimetableShareImageModel.Document {
        val subtitle = TimetableDateLogic
            .dateForWeekDay(settings.semesterStartDate?.toLocalDate(), week, dayOfWeek)
            ?.let(TimetableShareImageModel::daySubtitleText)
        val dayCourses = WeekGridCourseMapping.visibleDayCourses(
            WeekGridCourseMapping.coursesForDay(
                allCourses = courses,
                week = week,
                dayOfWeek = dayOfWeek,
                showNonCurrentWeekCourses = showNonCurrentWeekCourses,
            ),
            week = week,
        )
        return TimetableShareImageModel.buildDayDocument(
            week = week,
            dayOfWeek = dayOfWeek,
            dayCourses = dayCourses,
            title = TimetableStrings.timetableShareExportDay(
                week = week,
                weekday = TimetableStrings.formatWeekday(dayOfWeek),
            ),
            subtitle = subtitle,
            emptyDayText = TimetableStrings.timetableShareExportEmptyDay.zh,
            shareText = TimetableStrings.timetableShareText.zh,
        )
    }
}
