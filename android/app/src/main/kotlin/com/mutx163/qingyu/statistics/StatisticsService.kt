package com.mutx163.qingyu.statistics

import com.mutx163.qingyu.core.CourseNature
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import kotlin.math.roundToInt

/**
 * 课程统计计算服务（源：lib/services/statistics_service.dart，纯计算部分逐行移植）。
 *
 * 该文件 1247 行全部为纯计算（无 SharedPreferences / 文件 / 网络 IO），故整文件移植；
 * 函数名与 Dart 静态方法一一对应，私有函数降为 private。
 *
 * 与 Dart 的两处已知实现差异（排序稳定性）：
 * Dart 的 List.sort **不保证稳定**，本移植统一用 Kotlin 的 sortedWith（稳定排序）。
 * 对全部既有 Dart 测试（无一条钉住并列时的相对顺序）结果一致；并列时的取值在
 * Dart 侧本就是实现细节（快排），移植侧选择「保持插入顺序」这一确定性规则。
 */
object StatisticsService {

    // ========== calculate：指定周的完整统计（service:13-48） ==========

    fun calculate(allCourses: List<CourseStub>, week: Int): WeeklyStats {
        // 过滤当前周有效课程
        val activeCourses = allCourses.filter { it.isActiveInWeek(week) }

        // 按课程名称分组
        val grouped = groupByCourseName(activeCourses)

        // 计算每日分布
        val dailyStats = calculateDailyStats(activeCourses)

        // 计算必修/选修比例
        val natureStats = calculateNatureStats(activeCourses)

        // 计算各课程统计
        val courseStats = calculateCourseStats(grouped, week)

        // 总课时
        val totalSections = activeCourses.sumOf { it.sectionCount }

        return WeeklyStats(
            weekNumber = week,
            totalCourses = grouped.size,
            totalSections = totalSections,
            dailyStats = dailyStats,
            natureStats = natureStats,
            courseStats = courseStats,
        )
    }

    // ========== calculateSemester：整个学期（账单式，service:51-104） ==========

    fun calculateSemester(
        allCourses: List<CourseStub>,
        currentWeek: Int,
        semesterWeekCount: Int,
    ): SemesterStats {
        if (allCourses.isEmpty() || currentWeek < 1) {
            return SemesterStats(
                totalCourses = 0,
                totalSections = 0,
                totalWeeks = 0,
                longestStreak = 0,
                dailyAverages = emptyList(),
                natureStats = CourseNatureStats(0, 0, 0, 0),
                courseRanking = emptyList(),
            )
        }

        // 按课程名称分组（去重）
        val grouped = groupByCourseName(allCourses)

        // 计算整个学期的总课时
        var totalSections = 0
        for (course in allCourses) {
            val activeWeeks = countActiveWeeks(course, currentWeek)
            totalSections += course.sectionCount * activeWeeks
        }

        // 计算每日平均课时
        val dailyAverages = calculateDailyAverages(allCourses, currentWeek)

        // 计算最长连续上课天数
        val longestStreak = calculateLongestStreak(allCourses, currentWeek)

        // 计算必修/选修比例（整个学期）
        val natureStats = calculateSemesterNatureStats(allCourses, currentWeek)

        // 计算课程排行（按整个学期课时排序）
        val courseRanking = calculateCourseRanking(allCourses, currentWeek)

        return SemesterStats(
            totalCourses = grouped.size,
            totalSections = totalSections,
            totalWeeks = semesterWeekCount,
            longestStreak = longestStreak,
            dailyAverages = dailyAverages,
            natureStats = natureStats,
            courseRanking = courseRanking,
        )
    }

    // ========== calculateAchievements：成就系统（service:107-269） ==========

    fun calculateAchievements(allCourses: List<CourseStub>, currentWeek: Int): List<Achievement> {
        if (allCourses.isEmpty()) {
            return emptyList()
        }

        // 计算整个学期的总课时
        var totalSections = 0
        for (course in allCourses) {
            val activeWeeks = countActiveWeeks(course, currentWeek)
            totalSections += course.sectionCount * activeWeeks
        }

        // 本周已开课的课（口径与时间利用卡同源），成就/故事卡全部用它。
        val activeWeeklyCourses = allCourses.filter { countActiveWeeks(it, currentWeek) > 0 }

        // 计算每日最大课时
        val dailyMaxSections = calculateDailyMaxSections(activeWeeklyCourses)

        // 收集所有教室
        // 空地点不是「一间教室」：`AddCourseFormModel` 默认 location = ""，线上课/自习课
        // 也经常不填。原先把空串收进集合，4 间真实教室 + 1 门无地点课就会假解锁
        // 「教室探索家」（5/5）。同文件其它教室口径（:287 / :626 / :757）都过滤了空值。
        val allRooms = allCourses.map { it.location.trim() }.filter { it.isNotEmpty() }.toSet()

        // 全勤课程数（周排课口径）
        val perfectAttendanceCount = allCourses.count { hasPerfectAttendance(it, currentWeek) }

        // 早八 / 晚间 / 周末 课时（周排课口径）
        //
        // 按**分钟数**比，不按字符串比：`''.compareTo('08:00') <= 0` 恒成立，作息按位
        // 补空出来的空钟点课会被算进早八；而未补零的 `8:00`（'8' > '0'）反而不算早八。
        // 口径必须与 calculateDailyStats（时间利用卡）同源：先过滤本周还没开课的课。
        val earlyBirdSections = activeWeeklyCourses
            .filter { startMinutes(it)?.let { m -> m <= 8 * 60 } == true }
            .sumOf { it.sectionCount }
        val eveningSections = activeWeeklyCourses
            .filter { endMinutes(it)?.let { m -> m > 18 * 60 } == true }
            .sumOf { it.sectionCount }
        val weekendSections = activeWeeklyCourses
            .filter { it.dayOfWeek >= 6 }
            .sumOf { it.sectionCount }

        // 每日课时差（均衡度）
        val balanceGap = calculateDailyBalanceGap(activeWeeklyCourses)

        // 单日跨教学楼最大值
        val dailyMaxBuildings = calculateDailyMaxBuildings(activeWeeklyCourses)

        // 早间课时占比（周排课口径，12:00 前开始）
        val totalWeeklySections = activeWeeklyCourses.sumOf { it.sectionCount }
        val morningRatio = calculateMorningRatio(activeWeeklyCourses, totalWeeklySections)

        // 单日最长课间空档（节）
        val maxDailyGap = calculateMaxDailyGap(activeWeeklyCourses)

        return listOf(
            Achievement(
                id = "early_bird",
                isUnlocked = earlyBirdSections > 0,
                progressCurrent = earlyBirdSections,
                progressTarget = 1,
            ),
            Achievement(
                id = "perfect_attendance",
                isUnlocked = perfectAttendanceCount > 0,
                progressCurrent = perfectAttendanceCount,
                progressTarget = allCourses.size,
            ),
            Achievement(
                id = "weekend_warrior",
                isUnlocked = weekendSections > 0,
                progressCurrent = weekendSections,
                progressTarget = 1,
            ),
            Achievement(
                id = "class_king",
                isUnlocked = dailyMaxSections >= 6,
                progressCurrent = dailyMaxSections,
                progressTarget = 6,
            ),
            Achievement(
                id = "scholar",
                isUnlocked = totalSections >= 100,
                progressCurrent = totalSections,
                progressTarget = 100,
            ),
            Achievement(
                id = "balanced",
                isUnlocked = balanceGap <= 2,
                progressCurrent = balanceGap,
                progressTarget = 2,
            ),
            Achievement(
                id = "night_owl",
                isUnlocked = eveningSections > 0,
                progressCurrent = eveningSections,
                progressTarget = 1,
            ),
            Achievement(
                id = "explorer",
                isUnlocked = allRooms.size >= 5,
                progressCurrent = allRooms.size,
                progressTarget = 5,
            ),
            Achievement(
                id = "full_day_king",
                isUnlocked = dailyMaxSections >= 8,
                progressCurrent = dailyMaxSections,
                progressTarget = 8,
            ),
            Achievement(
                id = "building_hopper",
                isUnlocked = dailyMaxBuildings >= 3,
                progressCurrent = dailyMaxBuildings,
                progressTarget = 3,
            ),
            Achievement(
                id = "morning_person",
                isUnlocked = morningRatio >= 0.5,
                // Dart round()：.5 及以上进位（非负数域，与 Kotlin roundToInt 同语义）
                progressCurrent = (morningRatio * 100).roundToInt(),
                progressTarget = 50,
            ),
            Achievement(
                id = "gap_master",
                isUnlocked = maxDailyGap <= 2,
                progressCurrent = maxDailyGap,
                progressTarget = 2,
            ),
        )
    }

    // ========== generateDataStories：数据故事（service:272-417） ==========

    fun generateDataStories(allCourses: List<CourseStub>, currentWeek: Int): List<DataStory> {
        if (allCourses.isEmpty()) {
            return emptyList()
        }

        val stories = mutableListOf<DataStory>()

        // 计算每日总课时
        val dailySections = calculateDailyTotalSections(allCourses, currentWeek)
        val activeDays = dailySections.filter { it > 0 }

        if (activeDays.isNotEmpty()) {
            // 最忙的一天
            val maxSections = activeDays.reduce { a, b -> if (a > b) a else b }
            val busiestDayIndex = dailySections.indexOf(maxSections)
            val busiestAvg = maxSections.toDouble() / currentWeek

            stories.add(
                DataStory(
                    type = StoryType.BUSIEST_DAY,
                    dayOfWeek = busiestDayIndex + 1,
                    weekNumber = currentWeek,
                    averageSections = busiestAvg,
                ),
            )

            // 最轻松的一天（排除无课天）
            val minSections = activeDays.reduce { a, b -> if (a < b) a else b }
            val lightestDayIndex = dailySections.indexOf(minSections)
            if (lightestDayIndex != busiestDayIndex) {
                val lightestAvg = minSections.toDouble() / currentWeek
                stories.add(
                    DataStory(
                        type = StoryType.LIGHTEST_DAY,
                        dayOfWeek = lightestDayIndex + 1,
                        weekNumber = currentWeek,
                        averageSections = lightestAvg,
                    ),
                )
            }
        }

        // 最常去的教室（口径：排课条目数 × 各条目 activeWeeks 之和）
        //
        // 与 calculateVenueStats 的 `if (activeWeeks == 0) continue` 同一条过滤：
        // 本周还没开课的课到访次数是 0，进候选集会让卡片写着「你最常去的教室是
        // B101，共去了 0 次」。
        val roomCounts = linkedMapOf<String, Int>()
        for (course in allCourses) {
            if (course.location.isEmpty()) {
                continue
            }
            val activeWeeks = countActiveWeeks(course, currentWeek)
            if (activeWeeks == 0) {
                continue
            }
            roomCounts[course.location] = (roomCounts[course.location] ?: 0) + activeWeeks
        }
        if (roomCounts.isNotEmpty()) {
            val sortedRooms = roomCounts.entries.sortedWith(compareByDescending { it.value })
            val favorite = sortedRooms.first()
            stories.add(
                DataStory(
                    type = StoryType.FAVORITE_ROOM,
                    room = favorite.key,
                    visitCount = favorite.value,
                    weekNumber = currentWeek,
                ),
            )

            // 教学楼数量。与 calculateAchievements 用**同一个**提取口径（buildingOf）
            val buildings = roomCounts.keys.map { buildingOf(it) }.toSet()
            if (buildings.size > 1) {
                stories.add(
                    DataStory(
                        type = StoryType.BUILDING_COUNT,
                        buildingCount = buildings.size,
                        weekNumber = currentWeek,
                    ),
                )
            }
        }

        // 时间跨度：按**分钟数**取最早/最晚，不再排钟点串的字典序。
        // 与 calculateTimeUtilization 同一规则：只比较，不回写存储值。
        var earliestStart: String? = null
        var latestEnd: String? = null
        var earliestMinutes: Int? = null
        var latestMinutes: Int? = null
        // 与 calculateAchievements 的 activeWeeklyCourses 同口径：故事卡「时间跨度」
        // 也只统计本周已开课的课，否则一门「第 12 周才开始」的晚课会把「最晚下课」
        // 拉到 24:00，与成就页互相矛盾。
        for (course in allCourses) {
            if (countActiveWeeks(course, currentWeek) == 0) {
                continue
            }
            val startMinutes = ClockTime.tryParse(course.startTime)?.totalMinutes
            // 末节课 / 晚自习写 `24:00` 是本仓认可的「当天结束」，允许它参与比较。
            val endMinutes = ClockTime.tryParse(course.endTime, allowEndOfDay = true)?.totalMinutes
            if (startMinutes != null && (earliestMinutes == null || startMinutes < earliestMinutes)) {
                earliestMinutes = startMinutes
                earliestStart = course.startTime
            }
            if (endMinutes != null && (latestMinutes == null || endMinutes > latestMinutes)) {
                latestMinutes = endMinutes
                latestEnd = course.endTime
            }
        }
        if (earliestStart != null && latestEnd != null) {
            stories.add(
                DataStory(
                    type = StoryType.TIME_RANGE,
                    earliestTime = earliestStart,
                    latestTime = latestEnd,
                ),
            )
        }

        return stories
    }

    // ========== calculateWeeklyTrend：每周课时趋势（service:420-457） ==========

    fun calculateWeeklyTrend(allCourses: List<CourseStub>, semesterWeekCount: Int): List<WeeklyTrendPoint> {
        if (allCourses.isEmpty() || semesterWeekCount < 1) {
            return emptyList()
        }

        return List(semesterWeekCount) { index ->
            val week = index + 1
            val active = allCourses.filter { it.isActiveInWeek(week) }

            var sections = 0
            var requiredSections = 0
            var electiveSections = 0
            val names = mutableSetOf<String>()
            val days = mutableSetOf<Int>()
            for (course in active) {
                sections += course.sectionCount
                days.add(course.dayOfWeek)
                names.add(course.name)
                if (course.courseNature == CourseNature.REQUIRED) {
                    requiredSections += course.sectionCount
                } else {
                    electiveSections += course.sectionCount
                }
            }

            WeeklyTrendPoint(
                weekNumber = week,
                sections = sections,
                courseCount = names.size,
                requiredSections = requiredSections,
                electiveSections = electiveSections,
                activeDayCount = days.size,
            )
        }
    }

    // ========== calculateSemesterProgress：学期进度（service:464-540） ==========

    fun calculateSemesterProgress(
        allCourses: List<CourseStub>,
        currentWeek: Int,
        semesterWeekCount: Int,
        semesterStartDate: LocalDate? = null,
        now: LocalDateTime? = null,
    ): SemesterProgress {
        val reference = now ?: LocalDateTime.now()
        val totalWeeks = if (semesterWeekCount < 1) 0 else semesterWeekCount
        val hasCalendar = semesterStartDate != null && totalWeeks > 0

        var sectionsTotal = 0
        // 课程周次可能超出学期总周数（AI 导入未裁剪、或用户把学期从 20 周改小）。
        // 总览/周视图都按 `semesterWeekCount` 截止，进度卡的「共 N 节」也必须同口径，
        // 否则会出现「总览 32 节、进度卡共 40 节、100% 提前到来」。
        val weekCap = if (totalWeeks > 0) totalWeeks else Int.MAX_VALUE
        for (course in allCourses) {
            sectionsTotal += course.sectionCount * countScheduledWeeks(course, weekCap)
        }

        var sectionsDone = 0
        var weeksElapsed = if (currentWeek < 1) 0 else currentWeek
        var phase = SemesterProgressPhase.ESTIMATED

        if (hasCalendar) {
            val calendarWeek = calendarWeekForDate(reference, semesterStartDate)
            // 开学日不是周一时，开学日之前的几天仍落在「第 1 周」里
            // （`calendarWeekForDate` 按周一归周，会返回 1）。必须显式比较日期，
            // 否则开学前一两天会显示「进行中」而不是「还未开学」。
            val beforeStart = reference.toLocalDate().isBefore(semesterStartDate)
            if (beforeStart || calendarWeek < 1) {
                sectionsDone = 0
                weeksElapsed = 0
                phase = SemesterProgressPhase.BEFORE_START
            } else if (calendarWeek > totalWeeks) {
                sectionsDone = sectionsTotal
                weeksElapsed = totalWeeks
                phase = SemesterProgressPhase.ENDED
            } else {
                sectionsDone = countSectionsDoneByDate(
                    allCourses,
                    calendarWeek = calendarWeek,
                    semesterStart = semesterStartDate,
                    today = reference,
                )
                weeksElapsed = calendarWeek
                phase = SemesterProgressPhase.IN_PROGRESS
            }
        } else {
            for (course in allCourses) {
                sectionsDone += course.sectionCount * countActiveWeeks(course, currentWeek)
            }
        }

        val remaining = if (sectionsTotal > sectionsDone) sectionsTotal - sectionsDone else 0

        return SemesterProgress(
            semesterStartDate = semesterStartDate,
            currentDate = if (hasCalendar) reference.toLocalDate() else null,
            // 与周次判定同一口径：先对齐到本周周一再数 totalWeeks 周。原先从**原始
            // 开学日**数 totalWeeks*7-1 天，开学日不是周一时就比最后一个教学周的
            // 周日多出 weekday-1 天：卡片会出现「phase 已经是 ended、印着的结束日
            // 却还在未来」这种自相矛盾。
            semesterEndDate = if (hasCalendar) {
                weekStart(semesterStartDate).plusDays(totalWeeks * 7L - 1)
            } else {
                null
            },
            weeksElapsed = weeksElapsed,
            totalWeeks = totalWeeks,
            sectionsDone = sectionsDone,
            sectionsTotal = sectionsTotal,
            remainingSections = remaining,
            phase = phase,
        )
    }

    /** 真实日历周（周一为每周起始），开学前返回 0，不按总周数截断（service:543-553）。 */
    private fun calendarWeekForDate(date: LocalDateTime, semesterStart: LocalDate): Int {
        val start = weekStart(semesterStart)
        val target = weekStart(date.toLocalDate())
        val diffDays = ChronoUnit.DAYS.between(start, target)
        if (diffDays < 0) return 0
        return (diffDays / 7).toInt() + 1
    }

    private fun weekStart(date: LocalDate): LocalDate =
        date.minusDays((date.dayOfWeek.value - 1).toLong())

    /**
     * 截至今天实际发生的课时：第 1..week-1 完整周整周计，
     * 当前周只累计开学日及之后、今天及之前的上课日（service:562-594）。
     */
    private fun countSectionsDoneByDate(
        allCourses: List<CourseStub>,
        calendarWeek: Int,
        semesterStart: LocalDate,
        today: LocalDateTime,
    ): Int {
        val startDay = semesterStart
        val todayDay = today.toLocalDate()
        val weekStartDay = weekStart(semesterStart).plusDays((calendarWeek - 1) * 7L)

        var done = 0
        for (course in allCourses) {
            if (course.sectionCount <= 0) continue
            done += course.sectionCount * countActiveWeeks(course, calendarWeek - 1)
            // 第 1 周的「整周」里，开学日之前的上课日并没有发生。开学日不是周一时
            // （很常见），`countActiveWeeks(course, calendarWeek - 1)` 会把它们算进来；
            // 只有 calendarWeek >= 2 时第 1 周才在该累加范围内。
            if (calendarWeek > 1 &&
                course.isActiveInWeek(1) &&
                course.dayOfWeek < semesterStart.dayOfWeek.value
            ) {
                done -= course.sectionCount
            }
            if (!course.isActiveInWeek(calendarWeek)) continue
            for (offset in 0 until 7) {
                val day = weekStartDay.plusDays(offset.toLong())
                if (day.isAfter(todayDay)) break
                if (day.isBefore(startDay)) continue
                if (course.dayOfWeek == offset + 1) {
                    done += course.sectionCount
                }
            }
        }
        return done
    }

    // ========== calculateHeatmap：学期热力图（service:597-624） ==========

    fun calculateHeatmap(allCourses: List<CourseStub>, semesterWeekCount: Int): SemesterHeatmap {
        val rows = List(7) { MutableList(semesterWeekCount) { 0 } }
        var maxSections = 0

        for (course in allCourses) {
            val day = course.dayOfWeek - 1
            if (day < 0 || day >= 7) continue
            for (week in 1..semesterWeekCount) {
                if (course.isActiveInWeek(week)) {
                    val value = rows[day][week - 1] + course.sectionCount
                    rows[day][week - 1] = value
                    if (value > maxSections) maxSections = value
                }
            }
        }

        return SemesterHeatmap(
            weekCount = semesterWeekCount,
            maxSections = maxSections,
            rows = rows,
        )
    }

    // ========== calculateTimeUtilization：时间利用（service:627-721） ==========

    fun calculateTimeUtilization(allCourses: List<CourseStub>, currentWeek: Int): TimeUtilizationStats {
        var earliest: String? = null
        var latest: String? = null
        var earliestMinutes: Int? = null
        var latestMinutes: Int? = null
        var morningSections = 0
        var noonSections = 0
        var eveningSections = 0
        var weekendSections = 0

        // 单日最大课间空档（节）
        val gapsByDay = linkedMapOf<Int, MutableList<Int>>()
        val slotsByDay = linkedMapOf<Int, MutableList<CourseStub>>()

        for (course in allCourses) {
            if (countActiveWeeks(course, currentWeek) == 0) continue
            val start = course.startTime
            val end = course.endTime
            // 一律按**分钟数**比，不用 String.compareTo：空串比任何值都小（作息按位
            // 补空的洞）、未补零的 `8:00` 比 `12:00` 大（早八被算进晚间）、`26:00`
            // 这类畸形串还能赢下「最晚下课」。
            val startMinutes = startMinutes(course)
            // 末节课 / 晚自习写 `24:00` 是本仓认可的「当天结束」，允许它参与比较，
            // 否则晚间课时与最晚下课会少算。
            val endMinutes = ClockTime.tryParse(end, allowEndOfDay = true)?.totalMinutes
            if (startMinutes != null && (earliestMinutes == null || startMinutes < earliestMinutes)) {
                earliestMinutes = startMinutes
                earliest = start
            }
            if (endMinutes != null && (latestMinutes == null || endMinutes > latestMinutes)) {
                latestMinutes = endMinutes
                latest = end
            }
            if (startMinutes != null && startMinutes < 12 * 60) {
                morningSections += course.sectionCount
            }
            if (startMinutes != null && endMinutes != null &&
                startMinutes < 14 * 60 && endMinutes > 12 * 60
            ) {
                noonSections += course.sectionCount
            }
            if (endMinutes != null && endMinutes > 18 * 60) {
                eveningSections += course.sectionCount
            }
            if (course.dayOfWeek >= 6) {
                weekendSections += course.sectionCount
            }
            slotsByDay.getOrPut(course.dayOfWeek) { mutableListOf() }.add(course)
        }

        for (slots in slotsByDay.values) {
            val sorted = slots.sortedBy { it.startSection }
            for (i in 1 until sorted.size) {
                val gap = sorted[i].startSection - sorted[i - 1].endSection - 1
                if (gap > 0) {
                    gapsByDay.getOrPut(sorted[i].dayOfWeek) { mutableListOf() }.add(gap)
                }
            }
        }

        var maxGap = 0
        for (gaps in gapsByDay.values) {
            for (gap in gaps) {
                if (gap > maxGap) maxGap = gap
            }
        }

        return TimeUtilizationStats(
            earliestStart = earliest ?: "",
            latestEnd = latest ?: "",
            morningSections = morningSections,
            noonSections = noonSections,
            eveningSections = eveningSections,
            weekendSections = weekendSections,
            maxDailyGapSections = maxGap,
            activeCourseCount = slotsByDay.values.sumOf { it.size },
        )
    }

    // ========== calculateVenueStats：教室与教学楼（service:724-760） ==========

    fun calculateVenueStats(allCourses: List<CourseStub>, currentWeek: Int): VenueStats {
        val roomCounts = linkedMapOf<String, Int>()
        // 楼栋行是**课时**（卡面单位是「节」，模型字段也叫 sections），不能拿教室行的
        // 到访周数往上累：两节大课连上 16 周，到访 16 次会被显示成「16 节」，正确值
        // 是 32。口径与教师行/课程行一致：sectionCount × activeWeeks。
        val buildingSections = linkedMapOf<String, Int>()
        for (course in allCourses) {
            if (course.location.isEmpty()) continue
            val activeWeeks = countActiveWeeks(course, currentWeek)
            if (activeWeeks == 0) continue
            roomCounts[course.location] = (roomCounts[course.location] ?: 0) + activeWeeks
            val building = buildingOf(course.location)
            buildingSections[building] =
                (buildingSections[building] ?: 0) + course.sectionCount * activeWeeks
        }

        val topRooms = roomCounts.entries
            .map { RoomVisitStat(name = it.key, visits = it.value) }
            .sortedWith(compareByDescending { it.visits })

        val buildings = buildingSections.entries
            .map { BuildingStat(name = it.key, sections = it.value) }
            .sortedWith(compareByDescending { it.sections })

        return VenueStats(
            topRooms = topRooms.take(5),
            buildings = buildings,
        )
    }

    // ========== calculateTeacherStats：教师课时排行（service:763-791） ==========

    fun calculateTeacherStats(allCourses: List<CourseStub>, currentWeek: Int): List<TeacherStat> {
        val byTeacher = linkedMapOf<String, MutableList<CourseStub>>()
        for (course in allCourses) {
            val teacher = course.teacher.trim()
            if (teacher.isEmpty()) continue
            if (countActiveWeeks(course, currentWeek) == 0) continue
            byTeacher.getOrPut(teacher) { mutableListOf() }.add(course)
        }

        val stats = byTeacher.entries.map { entry ->
            var sections = 0
            val names = mutableSetOf<String>()
            for (course in entry.value) {
                sections += course.sectionCount * countActiveWeeks(course, currentWeek)
                names.add(course.name)
            }
            TeacherStat(
                name = entry.key,
                sections = sections,
                courseCount = names.size,
            )
        }.sortedWith(compareByDescending { it.sections })

        return stats.take(10)
    }

    // ========== calculateWeeklyComparison：周对比（service:794-822） ==========

    fun calculateWeeklyComparison(
        allCourses: List<CourseStub>,
        currentWeek: Int,
        semesterWeekCount: Int,
    ): WeeklyComparison {
        val weekSections = if (currentWeek in 1..semesterWeekCount) {
            calculate(allCourses, currentWeek).totalSections
        } else {
            0
        }
        val lastWeekSections = if (currentWeek > 1) {
            calculate(allCourses, currentWeek - 1).totalSections
        } else {
            0
        }

        val semester = calculateSemester(
            allCourses = allCourses,
            currentWeek = currentWeek,
            semesterWeekCount = semesterWeekCount,
        )
        val average = if (currentWeek > 0) semester.totalSections.toDouble() / currentWeek else 0.0

        return WeeklyComparison(
            weekSections = weekSections,
            lastWeekSections = lastWeekSections,
            semesterAverageSections = average,
            deltaVsLastWeek = weekSections - lastWeekSections,
            deltaVsAverage = weekSections - average,
        )
    }

    // ========== 私有工具（service:824-1246，Dart 静态私有 → Kotlin private） ==========

    /**
     * 提取教学楼前缀，无前缀则原样返回（service:824-875）。
     *
     * 三个分支的门槛各不相同：
     * 1. 字母前缀（A101 / B203）无条件认——「A 座」那套命名没有歧义。
     * 2. 数字前缀**只有**后面跟着楼栋词（3号楼）或分隔符（3-201）才认。
     * 3. 中文楼名（第一教学楼-201 / 教三 401）认整段开头中文。
     * 三条都不命中时返回房间名本身：它没有可依据的楼栋名，但**绝不**折进一个
     * 共用的数字键里。
     *
     * 已知残留：非楼栋的中文名也认整段中文，所以 `自习室301` 与 `自习室402`
     * 仍会并成「自习室」一栋。要把「这是楼还是房间」彻底分清，得引入楼栋词词典。
     */
    private fun buildingOf(room: String): String {
        val trimmed = room.trim()
        if (trimmed.isEmpty()) {
            return room
        }
        val match = BUILDING_REGEX.find(trimmed)?.value
        if (match == null || match.isEmpty()) {
            return room
        }
        return match
    }

    // 字符区写作 \u 转义（「一-鿿」= U+4E00..U+9FFF；「号栋楼馆舍区教」=
    // \u53f7\u680b\u697c\u9986\u820d\u533a\u6559）：与 Dart 源同一正则。
    private val BUILDING_REGEX = Regex(
        "^(?:[A-Za-z]+|[\\u4e00-\\u9fff]+|\\d+(?:[ \\t]*[\\u53f7\\u680b\\u697c\\u9986\\u820d\\u533a\\u6559]+|(?=[ \\t]*[-/])))",
    )

    /** 上课开始的分钟数；钟点缺失或畸形时返回 null（service:848-849）。 */
    private fun startMinutes(course: CourseStub): Int? =
        ClockTime.tryParse(course.startTime)?.totalMinutes

    /** 结束钟点的分钟数；缺失或畸形时返回 null（service:857-858）。 */
    private fun endMinutes(course: CourseStub): Int? =
        ClockTime.tryParse(course.endTime, allowEndOfDay = true)?.totalMinutes

    /** 单日最大跨教学楼数（service:878-893）。 */
    private fun calculateDailyMaxBuildings(allCourses: List<CourseStub>): Int {
        val byDay = linkedMapOf<Int, MutableSet<String>>()
        for (course in allCourses) {
            // 无教室（线上/自习）不是一栋楼：不过滤会让 building_hopper 提前解锁。
            if (course.location.trim().isEmpty()) continue
            byDay.getOrPut(course.dayOfWeek) { mutableSetOf() }.add(buildingOf(course.location))
        }
        var max = 0
        for (buildings in byDay.values) {
            if (buildings.size > max) max = buildings.size
        }
        return max
    }

    /** 早间课时占比（12:00 前开始的课时 / 总课时，周排课口径，service:896-905）。 */
    private fun calculateMorningRatio(allCourses: List<CourseStub>, totalWeeklySections: Int): Double {
        if (totalWeeklySections <= 0) return 0.0
        val morning = allCourses
            .filter { (startMinutes(it) ?: 24 * 60) < 12 * 60 }
            .sumOf { it.sectionCount }
        return morning.toDouble() / totalWeeklySections
    }

    /** 单日最长课间空档（节，service:908-923）。 */
    private fun calculateMaxDailyGap(allCourses: List<CourseStub>): Int {
        val slotsByDay = linkedMapOf<Int, MutableList<CourseStub>>()
        for (course in allCourses) {
            slotsByDay.getOrPut(course.dayOfWeek) { mutableListOf() }.add(course)
        }
        var maxGap = 0
        for (slots in slotsByDay.values) {
            val sorted = slots.sortedBy { it.startSection }
            for (i in 1 until sorted.size) {
                val gap = sorted[i].startSection - sorted[i - 1].endSection - 1
                if (gap > maxGap) maxGap = gap
            }
        }
        return maxGap
    }

    /** 每日课时最大差值（均衡度，service:926-937）。 */
    private fun calculateDailyBalanceGap(allCourses: List<CourseStub>): Int {
        val dailySections = linkedMapOf<Int, Int>()
        for (course in allCourses) {
            val day = course.dayOfWeek
            dailySections[day] = (dailySections[day] ?: 0) + course.sectionCount
        }
        if (dailySections.isEmpty()) return 0
        val values = dailySections.values
        val maxValue = values.max()
        val minValue = values.min()
        return maxValue - minValue
    }

    /** 按课程名称分组（service:940-946）。 */
    private fun groupByCourseName(courses: List<CourseStub>): Map<String, List<CourseStub>> {
        val map = linkedMapOf<String, MutableList<CourseStub>>()
        for (course in courses) {
            map.getOrPut(course.name) { mutableListOf() }.add(course)
        }
        return map
    }

    /** 计算每日课时分布（周一至周日，service:949-967）。 */
    private fun calculateDailyStats(courses: List<CourseStub>): List<DailyStats> {
        val sectionMap = linkedMapOf<Int, Int>()
        val courseMap = linkedMapOf<Int, MutableSet<String>>()

        for (course in courses) {
            val day = course.dayOfWeek
            sectionMap[day] = (sectionMap[day] ?: 0) + course.sectionCount
            courseMap.getOrPut(day) { mutableSetOf() }.add(course.name)
        }

        return List(7) { index ->
            val day = index + 1
            DailyStats(
                dayOfWeek = day,
                sectionCount = sectionMap[day] ?: 0,
                courseCount = courseMap[day]?.size ?: 0,
            )
        }
    }

    /** 计算必修/选修比例（service:970-1001）。 */
    private fun calculateNatureStats(courses: List<CourseStub>): CourseNatureStats {
        var requiredCount = 0
        var electiveCount = 0
        var requiredSections = 0
        var electiveSections = 0

        // 按名称去重统计门数
        val seenRequired = mutableSetOf<String>()
        val seenElective = mutableSetOf<String>()

        for (course in courses) {
            val isRequired = course.courseNature == CourseNature.REQUIRED
            if (isRequired) {
                requiredSections += course.sectionCount
                if (seenRequired.add(course.name)) {
                    requiredCount++
                }
            } else {
                electiveSections += course.sectionCount
                if (seenElective.add(course.name)) {
                    electiveCount++
                }
            }
        }

        return CourseNatureStats(
            requiredCount = requiredCount,
            electiveCount = electiveCount,
            requiredSections = requiredSections,
            electiveSections = electiveSections,
        )
    }

    /** 计算各课程统计（service:1004-1042）。 */
    private fun calculateCourseStats(
        grouped: Map<String, List<CourseStub>>,
        week: Int,
    ): List<CourseStat> {
        @Suppress("UNUSED_PARAMETER")
        val unusedWeek = week // Dart 签名保留（_week 参数在原实现中未使用）

        return grouped.entries.map { entry ->
            val name = entry.key
            val courses = entry.value
            val first = courses.first()

            val slots = courses.map {
                CourseSlot(
                    dayOfWeek = it.dayOfWeek,
                    startSection = it.startSection,
                    endSection = it.endSection,
                    location = it.location,
                )
            }.sortedWith(compareBy({ it.dayOfWeek }, { it.startSection }))

            val weeklySections = courses.sumOf { it.sectionCount }

            CourseStat(
                name = name,
                teacher = first.teacher,
                nature = first.courseNature,
                weeklySections = weeklySections,
                slots = slots,
            )
        }.sortedWith(compareByDescending { it.weeklySections })
    }

    /** 计算课程在指定周次前的有效周数（service:1045-1053）。 */
    private fun countActiveWeeks(course: CourseStub, currentWeek: Int): Int {
        var count = 0
        for (week in 1..currentWeek) {
            if (course.isActiveInWeek(week)) {
                count++
            }
        }
        return count
    }

    /** 计算每日平均课时（整个学期，service:1056-1094）。 */
    private fun calculateDailyAverages(allCourses: List<CourseStub>, currentWeek: Int): List<DailyAverageStats> {
        // 按星期几分组
        val dayMap = linkedMapOf<Int, MutableList<CourseStub>>()
        for (course in allCourses) {
            dayMap.getOrPut(course.dayOfWeek) { mutableListOf() }.add(course)
        }

        return List(7) { index ->
            val day = index + 1
            val dayCourses = dayMap[day] ?: emptyList()

            // 计算该天在整个学期的总课时
            var totalSections = 0
            var courseCount = 0
            val seenNames = mutableSetOf<String>()

            for (course in dayCourses) {
                val activeWeeks = countActiveWeeks(course, currentWeek)
                totalSections += course.sectionCount * activeWeeks
                if (seenNames.add(course.name)) {
                    courseCount++
                }
            }

            val averageSections = if (currentWeek > 0) totalSections.toDouble() / currentWeek else 0.0

            DailyAverageStats(
                dayOfWeek = day,
                averageSections = averageSections,
                totalSections = totalSections,
                courseCount = courseCount,
            )
        }
    }

    /** 计算每日总课时（整个学期，service:1097-1108）。 */
    private fun calculateDailyTotalSections(allCourses: List<CourseStub>, currentWeek: Int): List<Int> {
        val result = MutableList(7) { 0 }
        for (course in allCourses) {
            val dayIndex = course.dayOfWeek - 1
            val activeWeeks = countActiveWeeks(course, currentWeek)
            result[dayIndex] += course.sectionCount * activeWeeks
        }
        return result
    }

    /** 计算每日最大课时（用于成就判定，service:1111-1119）。 */
    private fun calculateDailyMaxSections(allCourses: List<CourseStub>): Int {
        val dailySections = linkedMapOf<Int, Int>()
        for (course in allCourses) {
            val day = course.dayOfWeek
            dailySections[day] = (dailySections[day] ?: 0) + course.sectionCount
        }
        if (dailySections.isEmpty()) return 0
        return dailySections.values.max()
    }

    /**
     * 计算最长连续上课天数（service:1122-1146）。
     *
     * **算法本体在 [LongestStreakLogic]**（P1-12）：桌面统计小组件（`WidgetStatsLogic`）
     * 此前有一份逐行相同的副本，两侧各算各的。这里只负责把课程折成
     * 「本周哪几天有课」的 7 天布尔向量，再交给唯一实现。
     */
    private fun calculateLongestStreak(allCourses: List<CourseStub>, currentWeek: Int): Int {
        val hasClassDay = BooleanArray(LongestStreakLogic.DAYS_IN_WEEK)
        for (course in allCourses) {
            if (countActiveWeeks(course, currentWeek) > 0) {
                hasClassDay[course.dayOfWeek - 1] = true
            }
        }
        return LongestStreakLogic.longestStreak(hasClassDay)
    }

    /**
     * 课程完整开课周期内的计划周数（含单双周/自定义周次，不含停课，service:1149-1155）。
     *
     * @param maxWeek 学期总周数上限。进度卡按它截止；全勤判据仍用默认值
     *   （全勤看的是课程自己的完整周期，不该被学期设置截断）。
     */
    private fun countScheduledWeeks(course: CourseStub, maxWeek: Int = Int.MAX_VALUE): Int {
        var count = 0
        for (week in course.startWeek..minOf(course.endWeek, maxWeek)) {
            if (course.isActiveInWeek(week)) count++
        }
        return count
    }

    /** 全勤：有效周数 == 完整开课周期的计划周数（service:1158-1163）。 */
    private fun hasPerfectAttendance(course: CourseStub, currentWeek: Int): Boolean {
        val scheduled = countScheduledWeeks(course)
        if (scheduled == 0) return false
        val active = countActiveWeeks(course, currentWeek)
        return active == scheduled
    }

    /** 计算整个学期的必修/选修比例（service:1166-1202）。 */
    private fun calculateSemesterNatureStats(allCourses: List<CourseStub>, currentWeek: Int): CourseNatureStats {
        var requiredCount = 0
        var electiveCount = 0
        var requiredSections = 0
        var electiveSections = 0

        val seenRequired = mutableSetOf<String>()
        val seenElective = mutableSetOf<String>()

        for (course in allCourses) {
            val activeWeeks = countActiveWeeks(course, currentWeek)
            val semesterSections = course.sectionCount * activeWeeks

            val isRequired = course.courseNature == CourseNature.REQUIRED
            if (isRequired) {
                requiredSections += semesterSections
                if (seenRequired.add(course.name)) {
                    requiredCount++
                }
            } else {
                electiveSections += semesterSections
                if (seenElective.add(course.name)) {
                    electiveCount++
                }
            }
        }

        return CourseNatureStats(
            requiredCount = requiredCount,
            electiveCount = electiveCount,
            requiredSections = requiredSections,
            electiveSections = electiveSections,
        )
    }

    /** 计算课程排行（按整个学期课时排序，service:1205-1246）。 */
    private fun calculateCourseRanking(allCourses: List<CourseStub>, currentWeek: Int): List<CourseSemesterStat> {
        val grouped = groupByCourseName(allCourses)

        return grouped.entries.map { entry ->
            val name = entry.key
            val courses = entry.value
            val first = courses.first()

            var totalSections = 0
            for (course in courses) {
                val activeWeeks = countActiveWeeks(course, currentWeek)
                totalSections += course.sectionCount * activeWeeks
            }

            val slots = courses.map {
                CourseSlot(
                    dayOfWeek = it.dayOfWeek,
                    startSection = it.startSection,
                    endSection = it.endSection,
                    location = it.location,
                )
            }.sortedWith(compareBy({ it.dayOfWeek }, { it.startSection }))

            CourseSemesterStat(
                name = name,
                teacher = first.teacher,
                nature = first.courseNature,
                totalSections = totalSections,
                slots = slots,
            )
        }.sortedWith(compareByDescending { it.totalSections })
    }
}
