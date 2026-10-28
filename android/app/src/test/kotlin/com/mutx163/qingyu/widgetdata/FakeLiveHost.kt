package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime

/**
 * 测试假端口（移植 Dart 测试的 _FakePort，timetable_live_activity_service_test.dart:78-213）。
 *
 * 只实现被测路径真正会读的成员；缺省成员按测试需要显式给值。原生面在接口里就
 * 不存在——「测试没覆盖到原生推送」由类型系统保证。
 */
class FakeLiveHost(
    sections: List<SectionTimeData> = listOf(SectionTimeData("08:00", "09:40")),
    liveEnableBeforeClass: Boolean = true,
    showBeforeClassMinutes: Int = 20,
    timeCorrectionSeconds: Int = 0,
    semesterStartDate: LocalDateTime? = null,
    courses: List<Course> = emptyList(),
    holidayDates: Set<String> = emptySet(),
) : LiveHostFace {

    private val sectionsRef: List<SectionTimeData> = sections

    override val liveRuntime: LiveRuntimeState = LiveRuntimeState()

    override var settings: WidgetSettingsFace = WidgetSettingsFace().copy(
        semesterStartDate = semesterStartDate,
        liveEnableBeforeClass = liveEnableBeforeClass,
        liveShowBeforeClassMinutes = showBeforeClassMinutes,
        liveTimeCorrectionSeconds = timeCorrectionSeconds,
    )

    override var courses: List<Course> = courses

    /** 假端口返回的「今天属于哪个日历周」。 */
    var calendarWeek: Int = 1

    override fun calculateCalendarWeekForDate(now: LocalDateTime): Int = calendarWeek

    private val holidayKeySet: Set<String> = holidayDates

    override fun isHoliday(date: LocalDateTime): Boolean {
        val key = "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)
        return holidayKeySet.contains(key)
    }

    override var currentDateWeek: Int = 1

    // 固定星期一（对齐用例的 day=2026-03-02 与 course() 默认 dayOfWeek=1）。
    // 不能用 LocalDateTime.now()：真时钟会让这批用例「只在周一绿」——
    // 2026-10-26（周一）提交当日 4 例绿，次日（周二）同 4 例红的实证。TEST-POLICY 日期老化条。
    override var currentDayOfWeek: Int = 1

    override val currentWeek: Int get() = 1

    override fun getCoursesForDay(dayOfWeek: Int, week: Int): List<Course> = courses
        .filter { it.dayOfWeek == dayOfWeek }
        .filter { it.isActiveInWeek(week) }

    override fun getActiveCoursesForDay(dayOfWeek: Int, week: Int): List<Course> =
        getCoursesForDay(dayOfWeek, week)

    var resolveDisplayNameCalls: Int = 0
        private set

    /** 模拟展示名归一：加个后缀，断言服务返回的是**归一后**的课。 */
    override fun resolveCourseDisplayName(course: Course): Course {
        resolveDisplayNameCalls++
        return course.copy(name = "${course.name}(归一名)")
    }

    override fun isLiveTestingFixture(course: Course): Boolean = course.id.startsWith("live_test_")

    override fun resolveSectionsForCourse(course: Course): List<SectionTimeData> = sectionsRef

    private var _activeProfileFace: ProfileFace? = null
    override val activeProfileFace: ProfileFace?
        get() = _activeProfileFace

    private var _partnerProfileFace: ProfileFace? = null
    override val partnerProfileFace: ProfileFace?
        get() = _partnerProfileFace

    override var partnerBinding: PartnerTimetableBinding? = null

    override var hasPartnerBinding: Boolean = false

    override val nextExam: ExamFace? get() = null

    override val holidayDateKeys: Set<String> = holidayDates

    override val adjustedWorkdayDateKeys: Set<String> = emptySet()

    override fun isAdjustedWorkday(date: LocalDateTime): Boolean = false

    override fun holidayNameFor(date: LocalDateTime): String? =
        if (isHoliday(date)) "测试假" else null

    /** 测试侧注入档案。 */
    fun setActiveProfile(profile: ProfileFace?) {
        _activeProfileFace = profile
    }

    /** 测试侧注入 TA 档案（顺带置绑定开关，模拟「已绑定」）。 */
    fun setPartnerProfile(profile: ProfileFace?) {
        _partnerProfileFace = profile
        hasPartnerBinding = profile != null
    }

    companion object {
        /** 供测试直接算日历周（与 core.WeekCalculator 同口径）。 */
        fun weekOf(date: LocalDateTime, semesterStart: LocalDateTime?, fallback: Int): Int =
            WeekCalculator.calendarWeekForDate(date, semesterStart, fallback)
    }
}
