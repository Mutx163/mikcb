package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.sync.isLiveTestingFixtureCourseId
import com.mutx163.qingyu.widgetdata.ExamFace
import com.mutx163.qingyu.widgetdata.LiveActivityLogicData
import com.mutx163.qingyu.widgetdata.LiveHostFace
import com.mutx163.qingyu.widgetdata.LiveRuntimeState
import com.mutx163.qingyu.widgetdata.PartnerTimetableBinding
import com.mutx163.qingyu.widgetdata.ProfileFace
import com.mutx163.qingyu.widgetdata.SectionTimeData
import com.mutx163.qingyu.widgetdata.TimetableLiveActivityData
import com.mutx163.qingyu.widgetdata.WidgetSettingsFace
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 预览数据源的一次解析结果。
 *
 * [startTime] / [endTime] 是**按作息模板解析后的真实钟面**（不是课程存档里的原始串）；
 * [startMillis] / [endMillis] 是同一天的实际毫秒边界，供预览倒计时按真实窗口走。
 * 任一项解析不出来时保持 null，渲染层按空值处理，不编造。
 */
data class LiveCurrentCourseSnapshot(
    val moment: LivePreviewMoment,
    val course: Course? = null,
    val startTime: String? = null,
    val endTime: String? = null,
    val startMillis: Long? = null,
    val endMillis: Long? = null,
    val nextCourseName: String? = null,
    /** 用户没设开学日 ⇒ 周次无从谈起，只能给空态。 */
    val semesterStartMissing: Boolean = false,
) {
    companion object {
        fun empty(semesterStartMissing: Boolean = false): LiveCurrentCourseSnapshot =
            LiveCurrentCourseSnapshot(
                moment = LivePreviewMoment.NO_COURSE,
                semesterStartMissing = semesterStartMissing,
            )
    }
}

/**
 * 设置页预览的真实课程来源。
 *
 * ## 为什么不自己写第二套选课
 *
 * 「当前正在上的课」直接调 [TimetableLiveActivityData.getCoursesInProgress]——
 * 它已经是超级岛/小组件共用的入口，内部会按课程所属作息模板解析节次钟点。
 * 本文件只做三件它不管的事：
 * 1. 从 [TimetableSnapshot] 造一个只读的 [LiveHostFace]（Kotlin 侧目前没有生产实现）；
 * 2. 没有当前课时，找**今天**下一节还没开始的课（仍用同一套作息解析）；
 * 3. 把结果折算成预览需要的钟面/毫秒边界。
 *
 * ## 边界
 *
 * - 快照里没有节假日数据，[LiveHostFace.isHoliday] 恒 false：节假日当天预览仍会显示
 *   当天课程。真机岛在节假日不弹，这一差异留给后续把节假日接进快照时补。
 * - 没设开学日直接返回空态（[LiveCurrentCourseSnapshot.semesterStartMissing]），
 *   不拿 `currentWeek` 猜「今天属于第几周」。
 * - 跨天课程（24:00 结束）按当晚零点处理，不把结束时刻算到前一天。
 */
object LiveCurrentCourseSource {

    fun resolve(
        snapshot: TimetableSnapshot,
        now: LocalDateTime,
    ): LiveCurrentCourseSnapshot {
        val semesterStart = semesterStartOf(snapshot)
            ?: return LiveCurrentCourseSnapshot.empty(semesterStartMissing = true)

        val host = SnapshotLiveHost(snapshot = snapshot, semesterStart = semesterStart, now = now)
        // 日历周而不是钳制后的教学周：学期结束后不能把最后一教学周的课复活。
        val week = host.calculateCalendarWeekForDate(now)
        if (week <= 0) return LiveCurrentCourseSnapshot.empty()

        val todayCourses = TimetableLiveActivityData.getTodayCourses(host, now)
        if (todayCourses.isEmpty()) return LiveCurrentCourseSnapshot.empty()

        val ordered = todayCourses.sortedWith { left, right ->
            val leftStart = resolveClockMinutes(host, left)
            val rightStart = resolveClockMinutes(host, right)
            when {
                leftStart == null && rightStart == null ->
                    left.startSection.compareTo(right.startSection)
                leftStart == null -> 1
                rightStart == null -> -1
                else -> leftStart.compareTo(rightStart)
            }
        }

        // 当前课程：同一套「超级岛选课」入口，不另算。
        val current = TimetableLiveActivityData
            .getCoursesInProgress(host, now.dayOfWeek.value, week, now)
            .firstOrNull()

        val subject = current ?: ordered.firstOrNull { course ->
            val startMinutes = resolveClockMinutes(host, course) ?: return@firstOrNull false
            startMinutes > now.hour * 60 + now.minute
        } ?: return LiveCurrentCourseSnapshot.empty()

        val moment = if (current != null) {
            LivePreviewMoment.IN_CLASS
        } else {
            LivePreviewMoment.BETWEEN_CLASSES
        }

        val startTime = TimetableLiveActivityData.resolveRealTime(host, subject, isStart = true)
        val endTime = TimetableLiveActivityData.resolveRealTime(host, subject, isStart = false)
        val subjectIndex = ordered.indexOfFirst { it.id == subject.id }
        val nextCourseName = ordered.getOrNull(subjectIndex + 1)?.name

        return LiveCurrentCourseSnapshot(
            moment = moment,
            course = subject,
            startTime = startTime,
            endTime = endTime,
            startMillis = clockMillis(now.toLocalDate(), startTime),
            endMillis = clockMillis(now.toLocalDate(), endTime),
            nextCourseName = nextCourseName,
        )
    }

    /** 开学日双键口径：天序优先（仓储写盘时归一过的日历日），其次设置里的毫秒。 */
    private fun semesterStartOf(snapshot: TimetableSnapshot): LocalDateTime? =
        snapshot.semesterStartEpochDay?.let { LocalDate.ofEpochDay(it).atStartOfDay() }
            ?: snapshot.settings.semesterStartDate

    private fun resolveClockMinutes(host: LiveHostFace, course: Course): Int? =
        LiveActivityLogicData.parseClockMinutes(
            TimetableLiveActivityData.resolveRealTime(host, course, isStart = true),
        )

    /** `HH:mm` → 当天该时刻的本地毫秒；`24:00` 自然落到次日零点。 */
    private fun clockMillis(date: LocalDate, clock: String): Long? {
        val minutes = LiveActivityLogicData.parseClockMinutes(clock) ?: return null
        return date.atStartOfDay()
            .plusMinutes(minutes.toLong())
            .atZone(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()
    }
}

/**
 * 把解析结果折成预览卡数据；没有课时返回 null，由页面渲染诚实空态。
 *
 * [Course.liveNote] 与岛下发同源（`note` 优先、回落 `description`），
 * 让预览的备注行与真机一致。
 */
fun LiveCurrentCourseSnapshot.toIslandPreviewInfo(): LiveIslandPreviewInfo? {
    val course = course ?: return null
    val start = startTime ?: return null
    val end = endTime ?: return null
    return LiveIslandPreviewInfo(
        courseName = course.name,
        courseShortName = course.shortName,
        location = course.location,
        teacher = course.teacher,
        startTime = start,
        endTime = end,
        note = course.liveNote,
        nextCourseName = nextCourseName,
        startMillis = startMillis,
        endMillis = endMillis,
        moment = moment,
    )
}

/**
 * 用仓储快照实现 [LiveHostFace] 的只读适配层。
 *
 * 只覆盖预览需要的成员：选课入口真正读的 `courses` / `settings` / `getCoursesForDay` /
 * `resolveSectionsForCourse`。情侣、考试、节假日都没有快照数据，一律给「没有」，
 * 不拿别的域的数据猜。
 */
private class SnapshotLiveHost(
    private val snapshot: TimetableSnapshot,
    private val semesterStart: LocalDateTime,
    private val now: LocalDateTime,
) : LiveHostFace {

    override val liveRuntime: LiveRuntimeState = LiveRuntimeState()

    override val settings: WidgetSettingsFace = WidgetSettingsFace(
        semesterStartDate = semesterStart,
        semesterWeekCount = snapshot.settings.semesterWeekCount,
    )

    override val courses: List<Course> = snapshot.courses

    override fun calculateCalendarWeekForDate(now: LocalDateTime): Int =
        WeekCalculator.calendarWeekForDate(now, semesterStart, snapshot.currentWeek)

    /** 快照里没有节假日；预览不因此伪造放假。 */
    override fun isHoliday(date: LocalDateTime): Boolean = false

    override val currentDateWeek: Int = snapshot.currentWeek

    override val currentDayOfWeek: Int = now.dayOfWeek.value

    override val currentWeek: Int = snapshot.currentWeek

    override fun getCoursesForDay(dayOfWeek: Int, week: Int): List<Course> =
        snapshot.courses.filter { course ->
            course.dayOfWeek == dayOfWeek && course.isActiveInWeek(week)
        }

    override fun getActiveCoursesForDay(dayOfWeek: Int, week: Int): List<Course> =
        getCoursesForDay(dayOfWeek, week)

    override fun resolveCourseDisplayName(course: Course): Course = course

    override fun isLiveTestingFixture(course: Course): Boolean =
        isLiveTestingFixtureCourseId(course.id)

    /**
     * 逐门课解析作息：手动覆盖 → 地点分组 → 档案默认，与 `TimeSchemeLogic` 同一优先级。
     * 找不到模板时回落全局节次表；仍为空则返回 null，让调用方用课程自带钟点。
     */
    override fun resolveSectionsForCourse(course: Course): List<SectionTimeData>? {
        val scheme = TimeSchemeLogic.resolveCourseTimeScheme(
            schemes = snapshot.timeSchemes,
            settings = snapshot.settings,
            course = course,
            locationTimeGroups = snapshot.locationTimeGroups,
        )
        val sections = scheme?.sections?.takeIf { it.isNotEmpty() }
            ?: snapshot.settings.sections
        return sections
            .takeIf { it.isNotEmpty() }
            ?.map { SectionTimeData(startTime = it.startTime, endTime = it.endTime) }
    }

    override val activeProfileFace: ProfileFace? = null

    override val partnerProfileFace: ProfileFace? = null

    override val partnerBinding: PartnerTimetableBinding? = null

    override val hasPartnerBinding: Boolean = false

    override val nextExam: ExamFace? = null

    override val holidayDateKeys: Set<String> = emptySet()

    override val adjustedWorkdayDateKeys: Set<String> = emptySet()

    override fun isAdjustedWorkday(date: LocalDateTime): Boolean = false

    override fun holidayNameFor(date: LocalDateTime): String? = null
}
