package com.mutx163.qingyu.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.TimetableProfile
import java.time.LocalDateTime

/**
 * 课程与作业写入口需要的最小宿主面（纯逻辑端口，无 IO）。
 *
 * 移植自 lib/services/timetable_course_service.dart `TimetableCoursePort`
 *（含其继承的 TimetableCoreStatePort 三成员：notifyStateChanged / profiles / initialize）。
 *
 * Dart Future → Kotlin 同步调用（纯逻辑层阻塞语义）：
 * 落盘/记录/提醒等在真实 store 由协程或 IO 实现时再包一层，
 * 本族只保证"调了什么、失败时退回什么"的顺序与快照语义。
 */
interface TimetableCoursePort {
    var courses: List<Course>
    var tasks: List<CourseTask>
    var exams: List<Exam>
    var profiles: List<TimetableProfile>

    /** 当前学期周数：课程周次归一用它夹上下界。 */
    val semesterWeekCount: Int

    fun getCourseById(id: String): Course?

    /** 课程在第 [week] 周那次上课的日历日期（作业到期日取它）。 */
    fun dateForCourseOccurrence(course: Course, week: Int): LocalDateTime?

    /**
     * 课程显式绑定时间方案时的节次校验：绑定方案缺节次是"写不进"的硬错误。
     * 返回非空字符串即校验信息，调用方抛 IllegalArgumentException。
     */
    fun validateCourseTimeSchemeOverride(
        timeSchemeId: String?,
        startSection: Int,
        endSection: Int,
    ): String?

    /** 把课程钟点按"生效方案"补齐（未绑定时课程自带钟点是唯一真源）。 */
    fun syncCourseWithEffectiveTimeScheme(course: Course): Course

    /** 实时活动测试夹具：这类记录不走方案补齐，写入路径原样放行。 */
    fun isLiveTestingFixture(course: Course): Boolean

    /** 教师/地点历史各是一条落盘，纳进写入口保护区（幂等）。 */
    fun recordTeacher(teacher: String)
    fun recordLocation(location: String)

    /** 把当前设置与活动课表落盘；失败时抛错，由服务回滚。 */
    fun persistActiveProfileState()
    fun clearCurrentLiveCourseId()
    fun logEvent(name: String, parameters: Map<String, Any>)
    fun syncExamReminders()
    fun updateLiveActivity()

    // ---- TimetableCoreStatePort 三成员 ----
    fun notifyStateChanged()
    fun initialize()
}
