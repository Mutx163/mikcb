package com.mutx163.qingyu

import java.util.Calendar

/**
 * 统计小组件实时计算：镜像 Flutter [StatisticsService] 的口径，
 * 用 Flutter SharedPreferences 里的课表数据在 Kotlin 侧直算统计快照，
 * 消除「课表变更后若未启动 App 统计卡最多陈旧 15 分钟」的窗口。
 *
 * 与 TodayWidgetSupport.buildSnapshotFromFlutterState 同一数据源。
 * 除 dayStartOf 的时间归一化外全部是纯函数；JSON 解析由 StatsWidgetSupport
 * 承担（见 [buildSnapshot] 重载），核心计算入口只接收已解析的值类型参数，
 * JVM 单测无需触碰 org.json / android.jar stub。
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
     * 当前周只累计开学日及之后、今天及之前的上课日。
     *
     * 周锚点与 Flutter `_countSectionsDoneByDate` 完全一致：周一是每周第一天，
     * [semesterStartDayStartMillis] 先归一化到当周周一再展开（原实现直接锚定
     * 开学日，开学日非周一时星期匹配会整体错位——评审问题 1）。
     * 无开学日期时退回按 [viewWeek] 整周估算的旧口径。
     */
    internal fun calculateSectionsDone(
        courses: List<WidgetSourceCourse>,
        calendarWeek: Int?,
        semesterStartDayStartMillis: Long?,
        todayDayStartMillis: Long,
        viewWeek: Int,
    ): Int {
        if (calendarWeek != null && calendarWeek < 1) {
            // 开学前整段短路，对齐 statistics_service.dart calculateSemesterProgress。
            return 0
        }
        var done = 0
        for (course in courses) {
            if (course.sectionCount <= 0) continue
            if (semesterStartDayStartMillis == null || calendarWeek == null) {
                done += course.sectionCount * countActiveWeeks(course, viewWeek)
                continue
            }
            done += course.sectionCount * countActiveWeeks(course, calendarWeek - 1)
            if (!course.isInWeek(calendarWeek)) continue
            val weekStartMillis = semesterStartMondayMillis(
                semesterStartDayStartMillis,
            ) + (calendarWeek - 1) * 7L * 86_400_000L
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
     * 归一化到开学日所在周的周一零点（与 Flutter `_weekStart`、
     * LiveUpdateScheduler 的周一锚定一致）。
     * 输入须是当天零点的 millis（用 [dayStartOf] 归一化）；DST 切换由
     * Calendar 的日期运算吸收，避免 23h/25h 天把整条周链平移一天。
     */
    internal fun semesterStartMondayMillis(semesterStartDayStartMillis: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = semesterStartDayStartMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(
                Calendar.DAY_OF_YEAR,
                -(when (get(Calendar.DAY_OF_WEEK)) {
                    Calendar.MONDAY -> 1
                    Calendar.TUESDAY -> 2
                    Calendar.WEDNESDAY -> 3
                    Calendar.THURSDAY -> 4
                    Calendar.FRIDAY -> 5
                    Calendar.SATURDAY -> 6
                    else -> 7
                } - 1),
            )
        }
        return cal.timeInMillis
    }


    /**
     * 直算统计快照（供测试与显式传入场景使用）：接收已解析的课程与配置，
     * 不触碰 org.json。课程为空返回 null（对齐 StatsWidgetSnapshot.fromCourses）。
     *
     * 周数口径：有开学日期时为日历周并 clamp 到学期周数（开学前按第 1 周展示），
     * 无开学日期时用 Flutter 持久化的 currentWeek——与 TodayWidgetSupport 的 UI clamp 一致。
     */
    internal fun buildSnapshot(
        courses: List<WidgetSourceCourse>,
        profileName: String,
        persistedWeek: Int,
        semesterWeekCount: Int,
        semesterStartMillis: Long?,
        nowMillis: Long,
    ): StatsWidgetSnapshot? {
        if (courses.isEmpty()) return null
        val weeks = semesterWeekCount.coerceAtLeast(1)
        val week = persistedWeek.coerceAtLeast(1)

        val calendarWeek = if (semesterStartMillis != null) {
            liveSchedulerCalculateCalendarWeekForDate(
                semesterStartMillis = semesterStartMillis,
                currentWeek = week,
                dateMillis = nowMillis,
            )
        } else {
            null
        }
        // 展示周次与 TodayWidgetSupport 的 UI clamp 一致：开学前按第 1 周展示。
        val labelWeek = when {
            calendarWeek == null -> week.coerceIn(1, weeks)
            calendarWeek < 1 -> 1
            else -> calendarWeek.coerceIn(1, weeks)
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

        // 学期进度：按天精确（校历对齐，周一锚定），无开学日期退回整周估算。
        val todayDayStartMillis = dayStartOf(nowMillis)
        val semesterStartDayStartMillis = semesterStartMillis?.let { dayStartOf(it) }
        val effectiveCalendarWeek = if (calendarWeek != null && semesterStartDayStartMillis != null) {
            if (calendarWeek > weeks) weeks else calendarWeek
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
            profileName = profileName,
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

    /** 当天零点（本地时区），与 Flutter `DateTime(y,m,d)` 的日界一致。 */
    internal fun dayStartOf(millis: Long): Long {
        return Calendar.getInstance().apply {
            timeInMillis = millis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    /**
     * 从已解析的 profile JSON 对象构建快照（生产入口）。
     * org.json 解析集中在这里，核心计算走纯函数重载。
     */
    internal fun buildSnapshot(
        profileJson: org.json.JSONObject,
        nowMillis: Long = System.currentTimeMillis(),
    ): StatsWidgetSnapshot? {
        val courses = TodayWidgetSupport.parseSourceCourses(profileJson.optJSONArray("courses"))
        val settings = profileJson.optJSONObject("settings") ?: org.json.JSONObject()
        return buildSnapshot(
            courses = courses,
            profileName = profileJson.optString("name", ""),
            persistedWeek = profileJson.optInt("currentWeek", 1),
            semesterWeekCount = settings.optInt("semesterWeekCount", 20),
            semesterStartMillis = settings.optLong("semesterStartDate").takeIf { it > 0L },
            nowMillis = nowMillis,
        )
    }
}
