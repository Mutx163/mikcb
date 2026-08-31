package com.mutx163.qingyu

/**
 * 统计小组件实时计算：镜像 Flutter [StatisticsService] 的口径，
 * 用 Flutter SharedPreferences 里的课表数据在 Kotlin 侧直算统计快照，
 * 消除「课表变更后若未启动 App 统计卡最多陈旧 15 分钟」的窗口。
 *
 * 与 TodayWidgetSupport.buildSnapshotFromFlutterState 同一数据源，
 * 所有函数都是纯函数（不触碰 Android API），可本地单测。
 */
internal object WidgetStatsLogic {

    /** 学期计划总课时（计划口径，与 _countScheduledWeeks 一致：含单双周/自定义周，不含停课）。 */
    internal fun countScheduledWeeks(course: WidgetSourceCourse): Int {
        var count = 0
        for (week in course.startWeek..course.endWeek) {
            if (course.isInWeek(week)) count++
        }
        return count
    }

    /** 课程在 [currentWeek] 及之前的有效周数（含停课排除），对应 _countActiveWeeks。 */
    internal fun countActiveWeeks(course: WidgetSourceCourse, currentWeek: Int): Int {
        if (currentWeek < 1) return 0
        var count = 0
        for (week in 1..currentWeek) {
            if (course.isInWeek(week)) count++
        }
        return count
    }

    /** 指定周的有效课程（排除停课）。 */
    internal fun activeCoursesInWeek(
        courses: List<WidgetSourceCourse>,
        week: Int,
    ): List<WidgetSourceCourse> = courses.filter { it.isInWeek(week) }

    /**
     * 最长连续上课天数（周排课口径，与 _calculateLongestStreak 一致）：
     * 只看本周排课覆盖了星期几，展开两轮（14 天）单趟扫描，上限 7 天。
     */
    internal fun calculateLongestStreak(
        courses: List<WidgetSourceCourse>,
        currentWeek: Int,
    ): Int {
        if (courses.isEmpty()) return 0
        val hasClassDay = BooleanArray(7)
        for (course in courses) {
            val day = course.dayOfWeek
            if (day < 1 || day > 7) continue
            if (countActiveWeeks(course, currentWeek) > 0) {
                hasClassDay[day - 1] = true
            }
        }
        val expanded = hasClassDay + hasClassDay
        var maxStreak = 0
        var currentStreak = 0
        for (has in expanded) {
            if (has) {
                currentStreak++
                if (currentStreak > maxStreak) maxStreak = currentStreak
            } else {
                currentStreak = 0
            }
        }
        return maxStreak.coerceIn(0, 7)
    }

    /**
     * 周课时（本周 vs 上周差值口径）：第 1..week-1 周整周计，
     * 当前周只累计开学日及之后、今天及之前的上课日；
     * 无开学日期时退回按 [viewWeek] 整周估算的旧口径。
     * 对齐 StatisticsService.calculateSemesterProgress 的 sectionsDone。
     */
    internal fun calculateSectionsDone(
        courses: List<WidgetSourceCourse>,
        calendarWeek: Int?,
        semesterStartDayStartMillis: Long?,
        todayDayStartMillis: Long,
        viewWeek: Int,
    ): Int {
        var done = 0
        for (course in courses) {
            if (course.sectionCount <= 0) continue
            if (semesterStartDayStartMillis == null || calendarWeek == null) {
                done += course.sectionCount * countActiveWeeks(course, viewWeek)
                continue
            }
            if (calendarWeek < 1) continue
            done += course.sectionCount * countActiveWeeks(course, calendarWeek - 1)
            if (!course.isInWeek(calendarWeek)) continue
            val weekStartMillis = semesterStartDayStartMillis + (calendarWeek - 1) * 7L * 86_400_000L
            for (offset in 0 until 7) {
                val dayMillis = weekStartMillis + offset * 86_400_000L
                if (dayMillis > todayDayStartMillis) break
                if (dayMillis < semesterStartDayStartMillis) continue
                if (course.dayOfWeek == offset + 1) {
                    done += course.sectionCount
                }
            }
        }
        return done
    }

    /** 学期计划总课时（sectionsTotal）。 */
    internal fun calculateSectionsTotal(courses: List<WidgetSourceCourse>): Int {
        var total = 0
        for (course in courses) {
            total += course.sectionCount * countScheduledWeeks(course)
        }
        return total
    }

    /**
     * 直算统计快照。课程为空返回 null（对齐 StatsWidgetSnapshot.fromCourses）。
     *
     * 周数口径：有开学日期时为日历周并 clamp 到学期周数（开学前按第 1 周展示），
     * 无开学日期时用 Flutter 持久化的 currentWeek——与 TodayWidgetSupport 的 UI clamp 一致。
     */
    fun buildSnapshot(
        profileJson: org.json.JSONObject,
        nowMillis: Long = System.currentTimeMillis(),
    ): StatsWidgetSnapshot? {
        val courses = TodayWidgetSupport.parseSourceCourses(profileJson.optJSONArray("courses"))
        if (courses.isEmpty()) return null

        val settings = profileJson.optJSONObject("settings") ?: org.json.JSONObject()
        val semesterWeekCount = settings.optInt("semesterWeekCount", 20).coerceAtLeast(1)
        val semesterStartMillis = settings.optLong("semesterStartDate").takeIf { it > 0L }
        val persistedWeek = profileJson.optInt("currentWeek", 1).coerceAtLeast(1)

        val calendarWeek = if (semesterStartMillis != null) {
            liveSchedulerCalculateCalendarWeekForDate(
                semesterStartMillis = semesterStartMillis,
                currentWeek = persistedWeek,
                dateMillis = nowMillis,
            )
        } else {
            null
        }
        // 展示周次与 TodayWidgetSupport 的 UI clamp 一致：开学前按第 1 周展示。
        val labelWeek = when {
            calendarWeek == null -> persistedWeek.coerceIn(1, semesterWeekCount)
            calendarWeek < 1 -> 1
            else -> calendarWeek.coerceIn(1, semesterWeekCount)
        }
        // 周课时口径与 Flutter 统计页一致：用 clamp 后的展示周
        // （开学前显示第 1 周、学期结束后停在最后一周，不复活/不空窗）。
        val weekCourses = activeCoursesInWeek(courses, labelWeek)
        val lastWeekCourses = if (labelWeek > 1) {
            activeCoursesInWeek(courses, labelWeek - 1)
        } else {
            emptyList()
        }
        val weekSections = weekCourses.sumOf { it.sectionCount }
        val lastWeekSections = lastWeekCourses.sumOf { it.sectionCount }
        val weekCourseCount = weekCourses.map { it.name }.distinct().size

        // 学期进度：按天精确（校历对齐），无开学日期退回整周估算。
        val todayCal = java.util.Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val todayDayStartMillis = todayCal.timeInMillis
        val semesterStartDayStartMillis = semesterStartMillis?.let { start ->
            java.util.Calendar.getInstance().apply {
                timeInMillis = start
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }.timeInMillis
        }
        val effectiveCalendarWeek = if (calendarWeek != null && semesterStartDayStartMillis != null) {
            if (calendarWeek > semesterWeekCount) semesterWeekCount else calendarWeek
        } else {
            null
        }
        val semesterDone = calculateSectionsDone(
            courses = courses,
            calendarWeek = effectiveCalendarWeek,
            semesterStartDayStartMillis = semesterStartDayStartMillis,
            todayDayStartMillis = todayDayStartMillis,
            viewWeek = labelWeek,
        )
        val semesterTotal = calculateSectionsTotal(courses)

        // 必修/选修门数（按名称去重，整学期口径；未出现的字段视为必修）。
        val seenRequired = HashSet<String>()
        val seenElective = HashSet<String>()
        for (course in courses) {
            if (course.courseNature == "elective") {
                seenElective.add(course.name)
            } else {
                seenRequired.add(course.name)
            }
        }

        return StatsWidgetSnapshot(
            profileName = profileJson.optString("name", ""),
            currentWeek = labelWeek,
            weekSections = weekSections,
            weekCourseCount = weekCourseCount,
            deltaVsLastWeek = weekSections - lastWeekSections,
            semesterDone = semesterDone,
            semesterTotal = semesterTotal,
            requiredCount = seenRequired.size,
            electiveCount = seenElective.size,
            longestStreak = calculateLongestStreak(courses, labelWeek),
        )
    }
}
