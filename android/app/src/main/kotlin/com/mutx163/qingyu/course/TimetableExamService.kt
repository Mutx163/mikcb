package com.mutx163.qingyu.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.TimetableProfile
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 考试写入口需要的最小宿主面（纯逻辑端口，无 IO）。
 *
 * 逐条移植自 `lib/services/timetable_exam_service.dart:11-22` 的 `TimetableExamPort`
 * （已去掉 Dart 侧的 `runMutation` 互斥包装——Kotlin 纯逻辑层同步单线程调用，不引入协程）。
 * 生产实现由 [CoursePortExamAdapter] 把已有 [TimetableCoursePort] 适配过来；测试用假端口。
 */
interface TimetableExamPort {
    var exams: List<Exam>
    var profiles: List<TimetableProfile>

    fun initialize()
    fun notifyStateChanged()

    /** 考试关联的课程（不存在返回 null ⇒ add 时按"关联课程不存在"拒绝）。 */
    fun courseForExam(exam: Exam): Course?

    /** 把当前档案状态落盘；失败时抛错，由服务整体回滚。 */
    fun persistActiveProfileState()
    fun syncExamReminders()

    /** 原生小组件快照刷新（重推考试行）；接线属 W1，纯逻辑层可空实现。 */
    fun invalidateHomeWidgetSnapshot()
    fun syncHomeWidgetSnapshot()

    fun logExamEvent(name: String, parameters: Map<String, Any>)
}

/**
 * 考试域用例：查询（按课程 / 待考 / 下一场 / 当天有没有）+ 增删改。
 *
 * 移植自 `lib/services/timetable_exam_service.dart`。写入纪律与 Dart 完全一致：
 * - **add 失败不回滚**（内存里这条正是用户刚填完的内容，回滚等于清空表单，比留下更糟）；
 * - **update / delete 失败整体退出并上抛**：考试列表**与档案列表一起**退回——
 *   因为 `persistActiveProfileState` 的第一步就把活动档案并进档案列表（早于磁盘写入），
 *   只退考试列表会留下幻影（`timetable_exam_service.dart:126-133`）。
 *
 * 时间判断用注入的 [clock]，保证 JVM 可测（"是否过期"依赖当前时刻）。
 */
class TimetableExamService(
    private val port: TimetableExamPort,
    private val clock: () -> LocalDateTime = { LocalDateTime.now() },
) {

    /** 某门课的全部考试，按开始时刻排序。 */
    fun getExamsForCourse(courseId: String): List<Exam> =
        port.exams.filter { it.courseId == courseId }
            .sortedWith(Comparator { a, b -> Exam.compareByStart(a, b) })

    /** 未过期的考试，按开始时刻排序；`limit` 非空时截断。 */
    fun getUpcomingExams(limit: Int? = null): List<Exam> {
        val upcoming = port.exams.filter { !isExpired(it) }.sortedWith(Comparator(Exam::compareByStart))
        return if (limit != null && upcoming.size > limit) upcoming.subList(0, limit) else upcoming
    }

    /** 下一场考试（最早的未过期考试），没有则 null。 */
    fun getNextExam(): Exam? = getUpcomingExams(limit = 1).firstOrNull()

    /**
     * 当天是否有**未过期**的考试（考完即消失，用户 2026-10-20 拍板口径）。
     * 三处（星期栏红点 / 日视图议程 / 周网格考试卡）必须同一条判据。
     */
    fun hasExamOnDate(date: LocalDate): Boolean = port.exams.any { exam ->
        if (isExpired(exam)) {
            false
        } else {
            LocalDate.of(exam.dateTime.year, exam.dateTime.monthValue, exam.dateTime.dayOfMonth) == date
        }
    }

    /** 新增考试：关联课程不存在则拒绝；落盘失败**不回滚**（保留用户输入）。 */
    fun addExam(exam: Exam) {
        port.initialize()
        if (port.courseForExam(exam) == null) {
            throw IllegalArgumentException("linked_course_not_found")
        }
        port.exams = port.exams + exam
        port.persistActiveProfileState()
        port.notifyStateChanged()
        port.syncExamReminders()
        port.invalidateHomeWidgetSnapshot()
        port.syncHomeWidgetSnapshot()
        port.logExamEvent(
            "exam_created",
            mapOf(
                "has_location" to if (!exam.location.isNullOrEmpty()) 1 else 0,
                "has_seat" to if (!exam.seatNumber.isNullOrEmpty()) 1 else 0,
            ),
        )
    }

    /** 改考试：不存在则幂等返回；落盘失败连考试列表与档案列表一起回滚并上抛。 */
    fun updateExam(exam: Exam) {
        port.initialize()
        val index = port.exams.indexOfFirst { it.id == exam.id }
        if (index == -1) return
        val snapshotExams = port.exams.toList()
        val snapshotProfiles = port.profiles.toList()
        val updated = port.exams.toMutableList()
        updated[index] = exam
        port.exams = updated
        try {
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.exams = snapshotExams
            port.profiles = snapshotProfiles
            throw e
        }
        port.notifyStateChanged()
        port.syncExamReminders()
        port.invalidateHomeWidgetSnapshot()
        port.syncHomeWidgetSnapshot()
        port.logExamEvent("exam_updated", mapOf("exam_id" to exam.id))
    }

    /** 删考试：落盘失败整体退回并上抛（不能"内存删了、界面还在"）。 */
    fun deleteExam(examId: String) {
        port.initialize()
        val snapshotExams = port.exams.toList()
        val snapshotProfiles = port.profiles.toList()
        port.exams = port.exams.filter { it.id != examId }
        try {
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.exams = snapshotExams
            port.profiles = snapshotProfiles
            throw e
        }
        port.notifyStateChanged()
        port.syncExamReminders()
        port.invalidateHomeWidgetSnapshot()
        port.syncHomeWidgetSnapshot()
        port.logExamEvent("exam_deleted", mapOf("remaining_exam_count" to port.exams.size))
    }

    /** 考试是否已过：当前时刻晚于「考试日 + 结束时刻」（Dart `Exam.isExpired`，fallback 23:59）。 */
    private fun isExpired(exam: Exam): Boolean {
        val (h, m) = Exam.parseTimeOfDayParts(exam.endTime, fallbackHour = 23, fallbackMinute = 59)
        val end = LocalDateTime.of(
            exam.dateTime.year, exam.dateTime.monthValue, exam.dateTime.dayOfMonth, h, m,
        )
        return clock().isAfter(end)
    }
}

/**
 * 把已有 [TimetableCoursePort] 适配成 [TimetableExamPort]（生产用）。
 *
 * 两者高度重叠（`exams` / `profiles` / `initialize` / `notifyStateChanged` /
 * `persistActiveProfileState` / `syncExamReminders` / `logEvent` 都在）；
 * 只补 `courseForExam`（用 `getCourseById` 派生）与两个小组件快照口。
 * **小组件快照刷新属于 W1（桌面小组件接线），本适配器先空实现，不假装会刷新。**
 */
class CoursePortExamAdapter(private val port: TimetableCoursePort) : TimetableExamPort {
    override var exams: List<Exam>
        get() = port.exams
        set(value) { port.exams = value }

    override var profiles: List<TimetableProfile>
        get() = port.profiles
        set(value) { port.profiles = value }

    override fun initialize() { port.initialize() }

    override fun notifyStateChanged() { port.notifyStateChanged() }

    override fun courseForExam(exam: Exam): Course? = port.getCourseById(exam.courseId)

    override fun persistActiveProfileState() { port.persistActiveProfileState() }

    override fun syncExamReminders() { port.syncExamReminders() }

    override fun invalidateHomeWidgetSnapshot() { /* W1 小组件接线时补 */ }

    override fun syncHomeWidgetSnapshot() { /* W1 小组件接线时补 */ }

    override fun logExamEvent(name: String, parameters: Map<String, Any>) { port.logEvent(name, parameters) }
}
