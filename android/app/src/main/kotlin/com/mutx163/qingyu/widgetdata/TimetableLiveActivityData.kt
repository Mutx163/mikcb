package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import java.time.LocalDateTime

/**
 * 超级岛选课/今日课程管线（移植 lib/services/timetable_live_activity_service.dart
 * 的纯函数子集，宿主依赖收敛到 [LiveHostFace]）。
 *
 * 与真机 TodayWidgetSupport.buildSnapshotFromFlutterState 的状态判定/排序/兜底
 * 口径一致；不移植的部分（MethodChannel 推送、SharedPreferences、通知、Timer 心跳、
 * 锁）见交付说明的 IO 函数清单。
 */
object TimetableLiveActivityData {

    // ── 实时钟点解析 ─────────────────────────────────────────────

    /**
     * 课程在「今天」的真实钟点（resolveRealTime，timetable_live_activity_service.dart:111-131）：
     * 自检预设课故意带自由时钟，必须旁路作息模板群直接用自身钟点——否则预设课
     * 会被模板覆盖成不可选的时间。
     */
    fun resolveRealTime(host: LiveHostFace, course: Course, isStart: Boolean): String {
        if (host.isLiveTestingFixture(course)) {
            return if (isStart) course.startTime else course.endTime
        }
        return LiveActivityLogicData.resolveRealTimePure(
            course,
            isStart,
            host.resolveSectionsForCourse(course),
        )
    }

    /** 时间修正（_liveApplyTimeCorrection，:133-139）：按设置秒数平移。 */
    fun applyTimeCorrection(host: LiveHostFace, dateTime: LocalDateTime): LocalDateTime {
        val correctionSeconds = host.settings.liveTimeCorrectionSeconds
        if (correctionSeconds == 0) return dateTime
        return dateTime.plusSeconds(correctionSeconds.toLong())
    }

    /** 起止钟点落到 [date] 当天并应用修正（buildCorrectedCourseDateTime，:141-151）。 */
    fun buildCorrectedCourseDateTime(
        host: LiveHostFace,
        date: LocalDateTime,
        courseTime: String,
    ): LocalDateTime? {
        val base = WidgetDataClock.courseDateTimeOn(date, courseTime) ?: return null
        return applyTimeCorrection(host, base)
    }

    /**
     * 课前一窗被前一节课压住的截止时刻（_liveResolveBeforeClassBlockedUntil，:153-198）：
     * 第二节课的「上课前」文案不得在第一节课还挂着时抢屏，提前窗起点被推迟到
     * 前序课程里最晚的结束时刻。
     */
    private fun resolveBeforeClassBlockedUntil(
        host: LiveHostFace,
        todayCourses: List<Course>,
        courseIndex: Int,
        referenceDate: LocalDateTime,
    ): LocalDateTime? {
        if (courseIndex <= 0 || courseIndex >= todayCourses.size) return null
        val course = todayCourses[courseIndex]
        val courseStartTime = buildCorrectedCourseDateTime(
            host,
            referenceDate,
            resolveRealTime(host, course, true),
        ) ?: return null

        var blockedUntil: LocalDateTime? = null
        for (i in 0 until courseIndex) {
            val previousCourse = todayCourses[i]
            val previousStartTime = buildCorrectedCourseDateTime(
                host,
                referenceDate,
                resolveRealTime(host, previousCourse, true),
            ) ?: continue
            val previousEndTime = buildCorrectedCourseDateTime(
                host,
                referenceDate,
                resolveRealTime(host, previousCourse, false),
            ) ?: continue
            if (previousStartTime.isAfter(courseStartTime)) continue
            if (blockedUntil == null || previousEndTime.isAfter(blockedUntil)) {
                blockedUntil = previousEndTime
            }
        }
        return blockedUntil
    }

    /** 按「解析后的开始时间」排序（_liveCompareByResolvedStart，:321-344）。 */
    private fun compareByResolvedStart(
        host: LiveHostFace,
        referenceDate: LocalDateTime,
        a: Course,
        b: Course,
    ): Int {
        val aStart = buildCorrectedCourseDateTime(host, referenceDate, resolveRealTime(host, a, true))
        val bStart = buildCorrectedCourseDateTime(host, referenceDate, resolveRealTime(host, b, true))
        if (aStart == null && bStart == null) return a.startSection.compareTo(b.startSection)
        if (aStart == null) return 1
        if (bStart == null) return -1
        return aStart.compareTo(bStart)
    }

    // ── 选课 ─────────────────────────────────────────────────────

    /**
     * 超级岛选课（getActivityCourseSelection，:346-465）。
     *
     * 节假日直接不选课（不靠停岛分支兜底）；当天课程与自检预设课同场竞争
     * （按解析后的开始时间统一排序）；逐门判定阶段，第一门命中的返回；
     * 全部未命中时按 [allowUpcomingFallback] 走「上课前」回退（需开着
     * liveEnableBeforeClass，且不得被 blockedUntil 压住）。
     */
    fun getActivityCourseSelection(
        host: LiveHostFace,
        now: LocalDateTime,
        allowUpcomingFallback: Boolean = false,
        week: Int? = null,
    ): LiveActivityCourseSelection? {
        val currentTime = now
        if (host.isHoliday(currentTime)) return null
        val targetWeek = week ?: host.calculateCalendarWeekForDate(currentTime)
        var todayCourses = host.getActiveCoursesForDay(currentTime.dayOfWeek.value, targetWeek)
        val fixtureCourses = host.liveRuntime.fixtureOverlayCourses.filter { course ->
            course.dayOfWeek == currentTime.dayOfWeek.value && course.isActiveInWeek(targetWeek)
        }
        if (fixtureCourses.isNotEmpty()) {
            todayCourses = (todayCourses + fixtureCourses).sortedWith { a, b ->
                compareByResolvedStart(host, currentTime, a, b)
            }
        }
        if (todayCourses.isEmpty()) return null

        for (i in todayCourses.indices) {
            val course = todayCourses[i]
            val startTime = buildCorrectedCourseDateTime(host, currentTime, resolveRealTime(host, course, true))
                ?: continue
            val endTime = buildCorrectedCourseDateTime(host, currentTime, resolveRealTime(host, course, false))
                ?: continue

            val aheadTime = startTime.minusMinutes(host.settings.liveShowBeforeClassMinutes.toLong())
            val blockedUntil = resolveBeforeClassBlockedUntil(host, todayCourses, i, currentTime)
            val effectiveAheadTime = if (blockedUntil != null && blockedUntil.isAfter(aheadTime)) {
                blockedUntil
            } else {
                aheadTime
            }
            val stage = LiveActivityLogicData.resolveLiveActivityStage(
                currentTime = currentTime,
                startTime = startTime,
                endTime = endTime,
                aheadTime = effectiveAheadTime,
                settings = host.settings,
                endReminderWindowMinutes = LIVE_END_REMINDER_WINDOW_MINUTES,
            )
            if (stage != null) {
                val nextCourse = if (i + 1 < todayCourses.size) todayCourses[i + 1] else null
                return LiveActivityCourseSelection(
                    currentCourse = host.resolveCourseDisplayName(course),
                    nextCourse = nextCourse?.let { host.resolveCourseDisplayName(it) },
                    stage = stage,
                )
            }
        }

        if (!allowUpcomingFallback || !host.settings.liveEnableBeforeClass) return null

        for (i in todayCourses.indices) {
            val course = todayCourses[i]
            val startTime = buildCorrectedCourseDateTime(host, currentTime, resolveRealTime(host, course, true))
            if (startTime == null || !startTime.isAfter(currentTime)) continue
            val blockedUntil = resolveBeforeClassBlockedUntil(host, todayCourses, i, currentTime)
            if (blockedUntil != null && currentTime.isBefore(blockedUntil)) continue

            val nextCourse = if (i + 1 < todayCourses.size) todayCourses[i + 1] else null
            return LiveActivityCourseSelection(
                currentCourse = host.resolveCourseDisplayName(course),
                nextCourse = nextCourse?.let { host.resolveCourseDisplayName(it) },
                stage = LiveActivityStage.BEFORE_CLASS,
            )
        }
        return null
    }

    /**
     * 自检选课（getTestActivityCourseSelection，:467-554）：
     * 当天无活跃课程时扫描「今天起（含本周往后）最近一门还没开始的课」，
     * 全都没有时返回 null（测试入口显示「无课」提示）。
     */
    fun getTestActivityCourseSelection(host: LiveHostFace, now: LocalDateTime): LiveActivityCourseSelection? {
        val currentTime = now
        val targetWeek = host.calculateCalendarWeekForDate(currentTime)
        val immediate = getActivityCourseSelection(
            host,
            now = currentTime,
            allowUpcomingFallback = true,
            week = targetWeek,
        )
        if (immediate != null) return immediate

        val today = LocalDateTime.of(currentTime.year, currentTime.monthValue, currentTime.dayOfMonth, 0, 0)
        val courses = host.courses
        val maxWeek = if (courses.isEmpty()) {
            targetWeek
        } else {
            courses.maxOf { it.endWeek }
        }

        var bestCourse: Course? = null
        var bestStartTime: LocalDateTime? = null
        var bestWeek: Int? = null

        for (course in courses) {
            for (week in targetWeek..maxWeek) {
                if (!course.isInWeek(week)) continue
                val dayOffset = (week - targetWeek) * 7 + course.dayOfWeek - currentTime.dayOfWeek.value
                if (dayOffset < 0) continue
                val candidateDate = today.plusDays(dayOffset.toLong())
                val candidateStart = buildCorrectedCourseDateTime(
                    host,
                    candidateDate,
                    resolveRealTime(host, course, true),
                )
                if (candidateStart == null || !candidateStart.isAfter(currentTime)) continue
                if (bestStartTime == null || candidateStart.isBefore(bestStartTime)) {
                    bestCourse = course
                    bestStartTime = candidateStart
                    bestWeek = week
                }
                break
            }
        }

        val fallbackStage = LiveActivityLogicData.preferredTestStage(host.settings)
        if (bestCourse == null || bestWeek == null || fallbackStage == null) return null
        val resolvedWeek = bestWeek

        val sameDayCourses = courses
            .filter { it.dayOfWeek == bestCourse.dayOfWeek && it.isInWeek(resolvedWeek) }
            .sortedBy { it.startSection }
        val currentIndex = sameDayCourses.indexOfFirst { it.id == bestCourse.id }
        val nextCourse = if (currentIndex != -1 && currentIndex + 1 < sameDayCourses.size) {
            sameDayCourses[currentIndex + 1]
        } else {
            null
        }
        return LiveActivityCourseSelection(
            currentCourse = host.resolveCourseDisplayName(bestCourse),
            nextCourse = nextCourse?.let { host.resolveCourseDisplayName(it) },
            stage = fallbackStage,
        )
    }

    // ── 今日课程便利查询 ─────────────────────────────────────────

    /**
     * 今天的课（getTodayCourses，:1265-1274）：设了开学日用**真实日历周**，
     * 否则退回宿主的 currentDateWeek——学期结束后 UI 周次被钳进学期周数，
     * 用它会复活「最后一个教学周」的课。
     */
    fun getTodayCourses(host: LiveHostFace, now: LocalDateTime = LocalDateTime.now()): List<Course> {
        val targetWeek = if (host.settings.semesterStartDate == null) {
            host.currentDateWeek
        } else {
            host.calculateCalendarWeekForDate(now)
        }
        return host.getCoursesForDay(host.currentDayOfWeek, targetWeek)
    }

    /** 当前正在上的那节课（getCurrentCourse，:1277-1291），钟点按分钟数比。 */
    fun getCurrentCourse(host: LiveHostFace, now: LocalDateTime = LocalDateTime.now()): Course? =
        getCurrentCourseAt(host, now)

    /**
     * 与 [getCurrentCourse] 同判据的显式时间注入版本（Dart 用 DateTime.now()，
     * Kotlin 侧为可测性把「现在」作为参数收进来；调用方传 LocalDateTime.now()
     * 即与 Dart 完全同义）。
     */
    fun getCurrentCourseAt(host: LiveHostFace, now: LocalDateTime): Course? {
        val todayCourses = getTodayCourses(host, now)
        val currentTime = WidgetDataClock.formatClock(now)
        for (course in todayCourses) {
            if (WidgetDataClock.compareClockText(currentTime, course.startTime) >= 0 &&
                WidgetDataClock.compareClockText(currentTime, course.endTime) < 0
            ) {
                return course
            }
        }
        return null
    }

    /** 下一节还没开始的课（getNextCourse，:1294-1307）。 */
    fun getNextCourseAt(host: LiveHostFace, now: LocalDateTime): Course? {
        val todayCourses = getTodayCourses(host, now)
        val currentTime = WidgetDataClock.formatClock(now)
        for (course in todayCourses) {
            if (WidgetDataClock.compareClockText(currentTime, course.startTime) < 0) return course
        }
        return null
    }

    /** 正在上的第一节课（getCourseInProgress 便利包装，:1310-1323）。 */
    fun getCourseInProgress(
        host: LiveHostFace,
        dayOfWeek: Int,
        week: Int? = null,
        now: LocalDateTime = LocalDateTime.now(),
    ): Course? {
        val courses = getCoursesInProgress(host, dayOfWeek, week, now)
        return courses.firstOrNull()
    }

    /**
     * 正在上的课（getCoursesInProgress，:1329-1363）：与超级岛选课共用同一套
     * 实时时钟解析（resolveSectionsForCourse 应用当天作息覆盖）。
     */
    fun getCoursesInProgress(
        host: LiveHostFace,
        dayOfWeek: Int,
        week: Int? = null,
        now: LocalDateTime = LocalDateTime.now(),
    ): List<Course> {
        val reference = now
        val targetWeek = week ?: weekForDate(host, reference)
        val currentMinutes = reference.hour * 60 + reference.minute
        val matches = mutableListOf<Course>()
        for (course in host.getCoursesForDay(dayOfWeek, targetWeek)) {
            val startMinutes = LiveActivityLogicData.parseClockMinutes(
                LiveActivityLogicData.resolveRealTimePure(course, true, host.resolveSectionsForCourse(course)),
            ) ?: continue
            val endMinutes = LiveActivityLogicData.parseClockMinutes(
                LiveActivityLogicData.resolveRealTimePure(course, false, host.resolveSectionsForCourse(course)),
            ) ?: continue
            if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
                matches.add(host.resolveCourseDisplayName(course))
            }
        }
        return matches
    }

    /** 教学周（UI 口径，钳制学期周数；_weekForDate，:1365-1376）。 */
    private fun weekForDate(host: LiveHostFace, date: LocalDateTime, fallbackWeek: Int? = null): Int =
        com.mutx163.qingyu.core.WeekCalculator.weekForDate(
            date,
            host.settings.semesterStartDate,
            host.settings.semesterWeekCount,
            fallbackWeek ?: host.currentWeek,
        )

    // ── 自检预设课覆盖层 ─────────────────────────────────────────

    /** 注入自检预设课（整体替换上一批；空列表为 no-op，:1380-1389）。 */
    fun armFixtureCourses(host: LiveHostFace, courses: List<Course>) {
        if (courses.isEmpty()) return
        host.liveRuntime.fixtureOverlayCourses = courses.toList()
    }

    /** 摘除覆盖层（disarmFixtureCourses，:1392-1398）。 */
    fun disarmFixtureCourses(host: LiveHostFace) {
        if (host.liveRuntime.fixtureOverlayCourses.isEmpty()) return
        host.liveRuntime.fixtureOverlayCourses = emptyList()
    }

    /**
     * 预设课全部结束时摘除覆盖层（disarmFixtureCoursesIfFinished，:1405-1425）。
     * 未结束（含节假日等选课为空的场景）保持挂载。
     */
    fun disarmFixtureCoursesIfFinished(host: LiveHostFace, now: LocalDateTime): Boolean {
        val overlay = host.liveRuntime.fixtureOverlayCourses
        if (overlay.isEmpty()) return false
        for (course in overlay) {
            val endTime = buildCorrectedCourseDateTime(host, now, resolveRealTime(host, course, false))
            if (endTime == null || !endTime.isBefore(now)) return false
        }
        host.liveRuntime.fixtureOverlayCourses = emptyList()
        return true
    }

    // ── 挂起窗口 ─────────────────────────────────────────────────

    /** 临时暂停实时同步（suspendSyncFor，:1436-1441）。 */
    fun suspendSyncFor(host: LiveHostFace, durationMillis: Long) {
        host.liveRuntime.suspendedUntil = LocalDateTime.now().plusNanos(durationMillis * 1_000_000)
    }

    /** 清掉临时暂停（clearSyncSuspend，:1444-1446）。 */
    fun clearSyncSuspend(host: LiveHostFace) {
        host.liveRuntime.suspendedUntil = null
    }
}

/**
 * 超级岛/小组件管线的宿主依赖面（TimetableLiveActivityPort 的纯逻辑子集）。
 *
 * 只保留纯函数真正会读的成员；原生面（MethodChannel/通知/SharedPreferences/
 * Timer/锁）一律不进这个面——测试假端口碰到即抛错的老纪律由「面里根本没有
 * 这些成员」来保证。
 */
interface LiveHostFace {
    /** 运行态桶（心跳/签名/挂起窗口/覆盖层）——本族只有覆盖层与挂起窗口被消费。 */
    val liveRuntime: LiveRuntimeState

    val settings: WidgetSettingsFace
    val courses: List<Course>

    /** 当天属于哪个日历周（开学前可为 0）。 */
    fun calculateCalendarWeekForDate(now: LocalDateTime): Int

    fun isHoliday(date: LocalDateTime): Boolean

    /** 当前展示周（无开学日时「今天的课」的周次兜底）。 */
    val currentDateWeek: Int

    /** 当前星期（1=周一…7=周日）。 */
    val currentDayOfWeek: Int

    val currentWeek: Int

    fun getCoursesForDay(dayOfWeek: Int, week: Int): List<Course>

    fun getActiveCoursesForDay(dayOfWeek: Int, week: Int): List<Course>

    /** 展示名归一（别名/简称解析），宿主管线把它当纯转换用。 */
    fun resolveCourseDisplayName(course: Course): Course

    fun isLiveTestingFixture(course: Course): Boolean

    /** 课程节次对应的作息表（可按当天日期应用覆盖规则）。 */
    fun resolveSectionsForCourse(course: Course): List<SectionTimeData>?

    /** 当前课表档案（快照 active 路径的数据锚点；null = 无档案）。 */
    val activeProfileFace: ProfileFace?

    /** TA 课表档案（情侣合并路径用；未导入为 null）。 */
    val partnerProfileFace: ProfileFace?

    /** 伴侣绑定（情侣合并路径用；未绑定为 null）。 */
    val partnerBinding: PartnerTimetableBinding?

    /** 是否已绑伴侣（与 partnerBinding != null 分开给，端口可以只给数据不给开关）。 */
    val hasPartnerBinding: Boolean

    /** 下一场未过期考试（快照考试倒计时）。 */
    val nextExam: ExamFace?

    /** 全量假期日期键 `yyyy-MM-dd`（HolidayData.holidayDateKeysForSnapshot 同义）。 */
    val holidayDateKeys: Set<String>

    /** 全量调休补班日期键（HolidayData.adjustedWorkdayDateKeysForSnapshot 同义）。 */
    val adjustedWorkdayDateKeys: Set<String>

    /** 调休上班日判定（HolidayResolver.isAdjustedWorkday 的宿主口径）。 */
    fun isAdjustedWorkday(date: LocalDateTime): Boolean

    /** 假期显示名（getHolidayForDate 的宿主口径；无假期为 null）。 */
    fun holidayNameFor(date: LocalDateTime): String?
}

/** 运行态桶（LiveActivityRuntimeState 的纯逻辑子集，:74-96）。 */
class LiveRuntimeState {
    /** 自检预设课覆盖层：只注入超级岛选课与快照路径，绝不写入真实课表。 */
    var fixtureOverlayCourses: List<Course> = emptyList()

    /** 临时暂停实时同步的截止时间。 */
    var suspendedUntil: LocalDateTime? = null

    /** 最近一次已推给岛的活动阶段键（阶段切换去重）。 */
    var lastActivityStageKey: String? = null

    /** 最近一次成功推送的岛内容签名。 */
    var lastLiveSnapshotSignature: String? = null

    /** 最近一次成功推送的今日小组件快照签名。 */
    var lastHomeWidgetSnapshotSignature: String? = null

    /** 绑定卡片（appWidgetId → 专属快照内容签名）的推送去重。 */
    val widgetSnapshotSignatures: MutableMap<Int, String> = mutableMapOf()
}
