package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.course.CourseDomain

/**
 * 课卡左上角那行小字（Dart `resolveCompactOverlineText`，
 * `lib/domain/day_course_display_logic.dart:147`）。优先级：非本周 > 冲突。
 */
enum class WeekCardOverline { NON_CURRENT_WEEK, CONFLICT }

/** 课卡右上角角标（Dart `resolveCompactBadgeText`，`day_course_display_logic.dart:170`）。 */
enum class WeekCardBadge { CONFLICT }

/**
 * 周视图一张课卡的展示模型（纯数据，渲染层只管画）。
 *
 * 与 `day_course_display_logic.dart` 的 `DayCourseDisplayItem` 同义。
 *
 * ## 「正在上课」为什么不做（这是 Dart 的原样，不是缺口）
 *
 * 2026-10-29 二轮复核（反证）：Dart 的日列确实有 `isHighlighted: item.isCurrentCourse`
 * （`timetable_day_column.dart:148`），但**周网格**调 `buildDisplayItems` 时没有传
 * `currentCourseIds`（`timetable_week_grid.dart:130-136`），而形参默认是
 * `const <String>{}`（`timetable_screen.dart:1212`）⇒ 周视图的 `isCurrentCourse`
 * **恒为 false**。所以 Compose 周视图不高亮「正在上课」与 Dart 一致；
 * 一审把它记成 P1 是误判，已在报告「二轮验真」里改正。
 * 日视图那边是真的要标（
 * `timetable_day_view_part.dart:592-599` 传了 currentCourseIds）。
 */
data class WeekCardModel(
    val course: Course,
    val isCurrentWeek: Boolean,
    val isConflicting: Boolean,
    val isSuspended: Boolean,
    val overline: WeekCardOverline?,
    val badge: WeekCardBadge?,
    /** 卡面透明度（冲突 / 非本周压淡，Dart `courseDisplayOpacity`）。 */
    val opacity: Float,
    /** 统一课卡色（设置开了「统一卡片颜色」时非空；空则用课程自己的 color）。 */
    val colorHex: String?,
    /**
     * 这一周是否有作业（Dart `showHomeworkIndicator: item.course.hasHomeworkInWeek(week)`，
     * `timetable_day_column.dart:146-147`）⇒ 卡面左上角白底小红点。
     */
    val hasHomework: Boolean = false,
    /**
     * 这一节次的天气一行（Dart `weather: callbacks.weather(item, date)`，
     * `timetable_day_column.dart:164`）。天气没开 / 没数据时为 null。
     */
    val weatherText: String? = null,
) {
    val sectionSpan: Int get() = course.sectionCount
}

/**
 * 周视图的课程取数与排版（纯 Kotlin，零 UI 依赖）。
 *
 * ## 与 2026-10-27 旧实现的差别（这是重做的核心）
 *
 * 旧实现自己发明了一套「同天重叠课程按列平分宽度」（Interval Coloring），
 * 模型层与渲染层各写一份、且渲染层从不调用模型层。**Dart 侧根本不是这样**：
 * - 课程卡永远**占满整列宽度**（`timetable_day_column.dart:120-135`：
 *   `Positioned(left: 0, right: 0)`），重叠时后画的压住先画的；
 * - 冲突只体现在两处：卡面透明度（`timetableConflictCourseOpacity`）+ 左上角
 *   「冲突」小字 + 右上角「冲突」角标（`showConflictBadgeOnTimetable` 开关）；
 * - 非本周课：默认**不显示**；开了「显示非本周课程」后，被本周课压住的仍不显示，
 *   同一时段有多门非本周课时只留「离本周最近」的那一门。
 *
 * 所以本文件按 Dart 逐条重写，并删掉旧的列平分模型。
 */
object WeekGridCourseMapping {

    /** 非本周课的固定灰（Dart `kNonCurrentWeekCourseColorHex`）。 */
    const val NON_CURRENT_WEEK_COLOR_HEX = "#94A3B8"

    /** 非本周课的固定透明度（Dart `kNonCurrentWeekCourseOpacity`）。 */
    const val NON_CURRENT_WEEK_OPACITY = 0.62f

    /**
     * 本周冲突索引：课程 id → 与之在本周冲突的其它课程 id。
     *
     * 直接复用 `CourseDomain.buildConflictMap`（含「停课周不误报」「customWeeks
     * 优先」两条判据），不在渲染层重写。
     */
    fun conflictMap(courses: List<Course>, week: Int): Map<String, Set<String>> =
        CourseDomain.buildConflictMap(courses, week = week)
            .mapValues { (_, partners) -> partners.map { it.id }.toSet() }

    /**
     * 某一天参与排版的全部课程（Dart `getCoursesForDay`，`day_course_display_logic.dart:196`）。
     *
     * 过滤：星期匹配，且（本周有课 **或** 开了「显示非本周课程」且该课本周及以后
     * 仍有上课周——已结课的不再以「非本周」挂在网格上）。
     *
     * 排序：开始节次 → 本周课靠后（非本周先画，被本周压住）→ 结束节次 → id。
     */
    fun coursesForDay(
        allCourses: List<Course>,
        week: Int,
        dayOfWeek: Int,
        showNonCurrentWeekCourses: Boolean,
    ): List<Course> =
        allCourses
            .filter { course ->
                if (course.dayOfWeek != dayOfWeek) return@filter false
                if (course.isInWeek(week)) return@filter true
                showNonCurrentWeekCourses && course.hasActiveWeekOnOrAfter(week)
            }
            .sortedWith(dayCourseComparator(week))

    /**
     * 某一天**真正要画出来**的课程：先滤掉被本周课压住的非本周课，再按日课排序。
     *
     * Dart `buildDayCourseDisplayItems`（`day_course_display_logic.dart:68-101`）的
     * 剪枝那一步；周视图与日视图必须同一口径，否则「显示非本周课程」开着时，
     * 同一个坑位在两个视图里画不同的课。
     */
    fun visibleDayCourses(dayCourses: List<Course>, week: Int): List<Course> =
        dayCourses
            .filter { course ->
                if (course.isInWeek(week)) return@filter true
                if (hasCurrentWeekOverlap(dayCourses, course, week)) return@filter false
                isPreferredNonCurrentCourse(dayCourses, course, week)
            }
            .sortedWith(dayCourseComparator(week))

    /**
     * 把某一天的课程收成卡片模型（Dart `buildDayCourseDisplayItems`，
     * `day_course_display_logic.dart:96`）：先滤掉被本周课压住的非本周课，
     * 再排序、算透明度与角标。
     */
    fun displayCards(
        dayCourses: List<Course>,
        week: Int,
        style: WeekViewStyle,
        conflicts: Map<String, Set<String>>,
        weatherOf: ((Course) -> String?)? = null,
    ): List<WeekCardModel> {
        val visible = visibleDayCourses(dayCourses, week)

        return visible
            .map { course ->
                val isCurrentWeek = course.isInWeek(week)
                val isConflicting = conflicts[course.id]?.isNotEmpty() == true
                WeekCardModel(
                    course = course,
                    isCurrentWeek = isCurrentWeek,
                    isConflicting = isConflicting,
                    isSuspended = course.isSuspendedInWeek(week),
                    overline = resolveOverline(
                        isCurrentWeek = isCurrentWeek,
                        isConflicting = isConflicting,
                        showConflictBadge = style.showConflictBadge,
                    ),
                    badge = resolveBadge(
                        isConflicting = isConflicting,
                        showConflictBadge = style.showConflictBadge,
                    ),
                    opacity = courseDisplayOpacity(
                        isCurrentWeek = isCurrentWeek,
                        isConflicting = isConflicting,
                        conflictOpacity = style.conflictCourseOpacity,
                    ),
                    colorHex = style.unifiedCardColorHex,
                    hasHomework = course.hasHomeworkInWeek(week),
                    weatherText = weatherOf?.invoke(course),
                )
            }
    }

    /**
     * 整周排版（按星期分组）：`Map<dayOfWeek 1..7, List<WeekCardModel>>`。
     *
     * 冲突索引整周只算一次（Dart 的 `provider.courseConflictMapForWeek(week)`
     * 也是整份课表算一次，不给每一天重算）。
     */
    fun cardsForWeek(
        courses: List<Course>,
        week: Int,
        style: WeekViewStyle,
        visibleDays: List<Int> = (1..7).toList(),
        weatherOf: ((week: Int, dayOfWeek: Int, Course) -> String?)? = null,
    ): Map<Int, List<WeekCardModel>> {
        val conflicts = conflictMap(courses, week)
        return visibleDays.associateWith { dayOfWeek ->
            val dayCourses = coursesForDay(
                allCourses = courses,
                week = week,
                dayOfWeek = dayOfWeek,
                showNonCurrentWeekCourses = style.showNonCurrentWeekCourses,
            )
            displayCards(
                dayCourses = dayCourses,
                week = week,
                style = style,
                conflicts = conflicts,
                weatherOf = weatherOf?.let { resolve -> { course -> resolve(week, dayOfWeek, course) } },
            )
        }
    }

    /** 卡面透明度（Dart `courseDisplayOpacity`）。 */
    fun courseDisplayOpacity(
        isCurrentWeek: Boolean,
        isConflicting: Boolean,
        conflictOpacity: Float,
    ): Float = when {
        !isCurrentWeek -> NON_CURRENT_WEEK_OPACITY
        isConflicting -> conflictOpacity
        else -> 1f
    }

    /** 左上角小字（Dart `resolveCompactOverlineText`）。 */
    fun resolveOverline(
        isCurrentWeek: Boolean,
        isConflicting: Boolean,
        showConflictBadge: Boolean,
    ): WeekCardOverline? = when {
        !isCurrentWeek -> WeekCardOverline.NON_CURRENT_WEEK
        isConflicting && showConflictBadge -> WeekCardOverline.CONFLICT
        else -> null
    }

    /** 右上角角标（Dart `resolveCompactBadgeText`；周视图没有「正在上课」）。 */
    fun resolveBadge(
        isConflicting: Boolean,
        showConflictBadge: Boolean,
    ): WeekCardBadge? = if (isConflicting && showConflictBadge) WeekCardBadge.CONFLICT else null

    /** 当天是否有本周课与 [target] 节次重叠（有则压掉非本周的 [target]）。 */
    fun hasCurrentWeekOverlap(courses: List<Course>, target: Course, week: Int): Boolean =
        courses.any { course ->
            course.id != target.id &&
                course.isInWeek(week) &&
                !(course.endSection < target.startSection || target.endSection < course.startSection)
        }

    /**
     * 重叠的非本周课里只留「离本周最近」的那张（同距再比起止周与 id）。
     *
     * 判据逐条照 `isPreferredNonCurrentCourse`（`day_course_display_logic.dart:237`）。
     */
    fun isPreferredNonCurrentCourse(courses: List<Course>, target: Course, week: Int): Boolean {
        val overlapping = courses
            .filter { course ->
                !course.isInWeek(week) &&
                    !(course.endSection < target.startSection || target.endSection < course.startSection)
            }
            .sortedWith(
                compareBy<Course>(
                    { distanceToNearestActiveWeek(it, week) },
                    { it.startWeek },
                    { it.endWeek },
                    { it.id },
                ),
            )
        return overlapping.isNotEmpty() && overlapping.first().id == target.id
    }

    /** 从 [week] 出发到最近上课周的周距；60 周内找不到记 999（Dart 同口径）。 */
    fun distanceToNearestActiveWeek(course: Course, week: Int): Int {
        for (offset in 0..60) {
            val previousWeek = week - offset
            if (previousWeek >= 1 && course.isInWeek(previousWeek)) return offset
            val nextWeek = week + offset
            if (offset > 0 && course.isInWeek(nextWeek)) return offset
        }
        return 999
    }

    /** 当天课程的稳定排序（Dart `compareDayCourseDisplayItems`）。 */
    private fun dayCourseComparator(week: Int): Comparator<Course> =
        compareBy<Course>(
            { it.startSection },
            { if (it.isInWeek(week)) 1 else 0 },
            { it.endSection },
            { it.id },
        )
}
