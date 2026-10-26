package com.mutx163.qingyu.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.CourseTaskSource
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime
import java.util.UUID

/**
 * 课程、课程组与课程作业（任务）族的读写实现 —— 唯一一份定义。
 *
 * 移植自 lib/services/timetable_course_service.dart（978 行，2026-10-26 快照）。
 * 已合入 core/ 的 Course/CourseTask/Exam/TimetableProfile/TimeScheme 等模型直接复用。
 *
 * ## 同步语义（与 Dart 逐条一致）
 * - add/addGroup：改的就是用户刚填的那些，刻意不回滚；
 * - update/delete/deleteGroup/updateGroup/clear/addTask/updateTask/deleteTask：
 *   内存里被改掉的是用户确认的那一条之外的连带（同组广播/考试/作业/镜像），
 *   落盘失败整体退回并上抛原错；失败路径不 notify、不清 liveId；
 * - recordTeacher/recordLocation 纳入保护区（幂等、无需补偿）；
 * - syncHomeworkTasksWithCourses：用户接管（isUserEdited）原样保留，既不覆盖也不摘除；
 *   手写作业已占的周不再按备注生成第二条；只有字段真变才刷新 updatedAt。
 *
 * ## Dart→Kotlin 映射
 * - Dart Future<void>/Future<bool> → 同步调用/返回 Boolean（纯逻辑层阻塞语义）；
 * - Dart ArgumentError(message) → IllegalArgumentException(message)；
 *   Dart StateError（落盘失败）→ IllegalStateException（调用方原样上抛）；
 * - Dart Uuid().v4() → UUID.randomUUID().toString()；
 * - Dart jsonEncode(tasks.map(toJson)) 的 changed 判据 → MiniJson.encode 同口径；
 * - Dart DateTime.now() → LocalDateTime.now()（墙上时刻语义由 DartTime 承载）。
 *
 * 不读写真机盘：persist/record 等经由 [TimetableCoursePort] 注入，单测用假端口。
 */
object TimetableCourseService {

    /** 未绑方案时仍然要拦的硬上限：节次编号超过它就是脏数据。 */
    const val MAX_UNBOUND_END_SECTION = 30

    /** 课程归一：trim 文本、把历史遗留单条备注提升成共享描述、周次夹到学期内。 */
    fun normalize(course: Course, semesterWeekCount: Int): Course {
        val trimmedDescription = course.description?.trim()
        val trimmedNote = course.note?.trim()
        val resolvedDescription = if (!trimmedDescription.isNullOrEmpty()) {
            trimmedDescription
        } else if (!trimmedNote.isNullOrEmpty()) {
            // Promote legacy per-entry note into the shared course description.
            trimmedNote
        } else {
            null
        }
        val (startWeek, endWeek) = Course.normalizeWeeks(
            startWeek = course.startWeek,
            endWeek = course.endWeek,
            maxWeek = semesterWeekCount,
        )
        return course.copy(
            name = course.name.trim(),
            shortName = course.shortName?.trim().takeIf { !it.isNullOrEmpty() },
            teacher = course.teacher.trim(),
            location = course.location.trim(),
            description = resolvedDescription,
            note = trimmedNote.takeIf { !it.isNullOrEmpty() },
            startWeek = startWeek,
            endWeek = endWeek,
        )
    }

    /**
     * 未绑定时间方案时的最小健全性：只拦写不进的脏数据，不拦超作息。
     * 超作息由地点规则计数报告，不在写入时拒绝。
     */
    fun validateUnboundSections(startSection: Int, endSection: Int): String? {
        if (startSection < 1 || endSection < startSection) return "course_sections_invalid"
        if (endSection > MAX_UNBOUND_END_SECTION) return "course_sections_invalid"
        return null
    }

    /** 加一门课：改的就是用户刚填的那条，刻意不回滚。 */
    fun add(port: TimetableCoursePort, course: Course) {
        validateSections(port, course)
        val normalized = normalize(course, semesterWeekCount = port.semesterWeekCount)
        val normalizedCourse = if (port.isLiveTestingFixture(normalized)) {
            normalized
        } else {
            port.syncCourseWithEffectiveTimeScheme(normalized)
        }
        val existingSharedCourse = port.courses.firstOrNull { item ->
            CourseDomain.sharedKey(item) == CourseDomain.sharedKey(normalizedCourse)
        }
        val preparedCourse = if (existingSharedCourse == null) {
            normalizedCourse
        } else {
            CourseDomain.applySharedFields(normalizedCourse, existingSharedCourse)
        }
        port.courses = port.courses + preparedCourse
        syncHomeworkTasksWithCourses(port)
        port.persistActiveProfileState()
        port.recordTeacher(preparedCourse.teacher)
        port.recordLocation(preparedCourse.location)
        port.clearCurrentLiveCourseId()
        port.notifyStateChanged()
        port.logEvent(
            "course_created",
            mapOf(
                "day_of_week" to preparedCourse.dayOfWeek,
                "section_count" to preparedCourse.sectionCount,
                "has_short_name" to if (!preparedCourse.shortName.isNullOrEmpty()) 1 else 0,
            ),
        )
        port.updateLiveActivity()
    }

    /** 改一门课：广播同组共享字段并重算作业，落盘失败三份快照整体退回。 */
    fun update(port: TimetableCoursePort, course: Course, previousSharedName: String? = null) {
        val currentCourses = port.courses.toList()
        val index = currentCourses.indexOfFirst { it.id == course.id }
        if (index == -1) return
        validateSections(port, course)
        val normalized = normalize(course, semesterWeekCount = port.semesterWeekCount)
        val normalizedCourse = if (port.isLiveTestingFixture(normalized)) {
            normalized
        } else {
            port.syncCourseWithEffectiveTimeScheme(normalized)
        }
        val originalCourse = currentCourses[index]
        val previousKey = buildSharedCourseNameKey(previousSharedName ?: originalCourse.name)
        val newKey = CourseDomain.sharedKey(normalizedCourse)

        val snapshotCourses = currentCourses.toList()
        val snapshotTasks = port.tasks.toList()
        val snapshotProfiles = port.profiles.toList()
        try {
            val nextCourses = currentCourses.toMutableList()
            nextCourses[index] = normalizedCourse
            for (i in nextCourses.indices) {
                if (i == index) continue
                val current = nextCourses[i]
                val currentKey = CourseDomain.sharedKey(current)
                if (currentKey == previousKey || currentKey == newKey) {
                    nextCourses[i] = CourseDomain.applySharedFields(current, normalizedCourse)
                }
            }
            port.courses = nextCourses.toList()
            port.recordTeacher(normalizedCourse.teacher)
            port.recordLocation(normalizedCourse.location)
            syncHomeworkTasksWithCourses(port)
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.courses = snapshotCourses
            port.tasks = snapshotTasks
            port.profiles = snapshotProfiles
            throw e
        }
        port.clearCurrentLiveCourseId()
        port.notifyStateChanged()
        port.syncExamReminders()
        port.logEvent(
            "course_updated",
            mapOf(
                "day_of_week" to normalizedCourse.dayOfWeek,
                "section_count" to normalizedCourse.sectionCount,
                "has_short_name" to if (!normalizedCourse.shortName.isNullOrEmpty()) 1 else 0,
            ),
        )
        port.updateLiveActivity()
    }

    /** 删一门课：连带摘掉记在其名下的考试与作业，四份列表可退回。 */
    fun delete(port: TimetableCoursePort, courseId: String) {
        val snapshotCourses = port.courses.toList()
        val snapshotExams = port.exams.toList()
        val snapshotTasks = port.tasks.toList()
        val snapshotProfiles = port.profiles.toList()
        port.courses = port.courses.filter { it.id != courseId }
        port.exams = port.exams.filter { it.courseId != courseId }
        port.tasks = port.tasks.filter { it.courseId != courseId }
        try {
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.courses = snapshotCourses
            port.exams = snapshotExams
            port.tasks = snapshotTasks
            port.profiles = snapshotProfiles
            throw e
        }
        port.clearCurrentLiveCourseId()
        port.notifyStateChanged()
        port.syncExamReminders()
        port.logEvent("course_deleted", mapOf("remaining_course_count" to port.courses.size))
        port.updateLiveActivity()
    }

    /** 删掉一个课程组（同名多课次），连同挂在这组课上的考试与作业一起摘掉。 */
    fun deleteGroup(port: TimetableCoursePort, name: String) {
        val key = buildSharedCourseNameKey(name)
        val deletedCourseIds = port.courses
            .filter { buildSharedCourseNameKey(it.name) == key }
            .map { it.id }
            .toSet()
        val snapshotCourses = port.courses.toList()
        val snapshotExams = port.exams.toList()
        val snapshotTasks = port.tasks.toList()
        val snapshotProfiles = port.profiles.toList()
        port.courses = port.courses.filter { !deletedCourseIds.contains(it.id) }
        port.exams = port.exams.filter { !deletedCourseIds.contains(it.courseId) }
        port.tasks = port.tasks.filter { !deletedCourseIds.contains(it.courseId) }
        try {
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.courses = snapshotCourses
            port.exams = snapshotExams
            port.tasks = snapshotTasks
            port.profiles = snapshotProfiles
            throw e
        }
        port.clearCurrentLiveCourseId()
        port.notifyStateChanged()
        port.syncExamReminders()
        port.logEvent("course_group_deleted", mapOf("remaining_course_count" to port.courses.size))
        port.updateLiveActivity()
    }

    /**
     * 整组替换（同一门课的多条课次一起改）。
     * 空集合是 no-op（挡在摘除旧课次之前，避免整组消失）。
     */
    fun updateGroup(port: TimetableCoursePort, originalName: String, updatedCourses: List<Course>) {
        val key = buildSharedCourseNameKey(originalName)
        if (updatedCourses.isEmpty()) return
        val snapshotCourses = port.courses.toList()
        val snapshotTasks = port.tasks.toList()
        val snapshotProfiles = port.profiles.toList()
        try {
            val nextCourses = port.courses
                .filter { buildSharedCourseNameKey(it.name) != key }
                .toMutableList()
            val shared = updatedCourses.first()
            for (course in updatedCourses) {
                val normalized = normalize(
                    CourseDomain.applySharedFields(course, shared),
                    semesterWeekCount = port.semesterWeekCount,
                )
                nextCourses.add(normalized)
                port.recordTeacher(normalized.teacher)
                port.recordLocation(normalized.location)
            }
            port.courses = nextCourses.toList()
            val courseIds = nextCourses.map { it.id }.toSet()
            port.tasks = port.tasks.filter { it.courseId == null || courseIds.contains(it.courseId) }
            syncHomeworkTasksWithCourses(port)
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.courses = snapshotCourses
            port.tasks = snapshotTasks
            port.profiles = snapshotProfiles
            throw e
        }
        port.clearCurrentLiveCourseId()
        port.notifyStateChanged()
        port.syncExamReminders()
        port.logEvent(
            "course_group_updated",
            mapOf("schedule_count" to updatedCourses.size, "remaining_course_count" to port.courses.size),
        )
        port.updateLiveActivity()
    }

    /** 加一组课次（新建一门课的多条课次，只落一次盘），不回滚。 */
    fun addGroup(port: TimetableCoursePort, courses: List<Course>) {
        if (courses.isEmpty()) return
        val shared = courses.first()
        val normalizedCourses = mutableListOf<Course>()
        val teachers = linkedSetOf<String>()
        val locations = linkedSetOf<String>()
        for (course in courses) {
            validateSections(port, course)
            val normalized = port.syncCourseWithEffectiveTimeScheme(
                normalize(
                    CourseDomain.applySharedFields(course, shared),
                    semesterWeekCount = port.semesterWeekCount,
                ),
            )
            normalizedCourses.add(normalized)
            if (normalized.teacher.isNotEmpty()) teachers.add(normalized.teacher)
            if (normalized.location.isNotEmpty()) locations.add(normalized.location)
        }
        port.courses = port.courses + normalizedCourses
        syncHomeworkTasksWithCourses(port)
        for (teacher in teachers) port.recordTeacher(teacher)
        for (location in locations) port.recordLocation(location)
        port.persistActiveProfileState()
        port.clearCurrentLiveCourseId()
        port.notifyStateChanged()
        port.logEvent(
            "course_group_created",
            mapOf("schedule_count" to courses.size, "remaining_course_count" to port.courses.size),
        )
        port.updateLiveActivity()
    }

    /**
     * 「清空当前课表」：一次清掉整份课表与挂在课程上的作业。
     * 考试刻意不跟着清（清空后往往马上重导，考试留着才接得上）。
     */
    fun clearActiveProfileCourses(port: TimetableCoursePort): Boolean {
        port.initialize()
        val clearedCourseCount = port.courses.size
        if (clearedCourseCount == 0) return false
        val snapshotCourses = port.courses.toList()
        val snapshotTasks = port.tasks.toList()
        val snapshotProfiles = port.profiles.toList()
        port.courses = emptyList()
        port.tasks = port.tasks.filter { it.courseId == null }
        try {
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.courses = snapshotCourses
            port.tasks = snapshotTasks
            port.profiles = snapshotProfiles
            throw e
        }
        port.clearCurrentLiveCourseId()
        port.notifyStateChanged()
        port.logEvent("courses_cleared", mapOf("cleared_course_count" to clearedCourseCount))
        port.updateLiveActivity()
        return true
    }

    /** 按 id 取一条作业。 */
    fun taskById(port: TimetableCoursePort, id: String): CourseTask? =
        port.tasks.firstOrNull { it.id == id }

    /** 作业挂在哪门课上；没挂课（手写作业）返回 null。 */
    fun courseForTask(port: TimetableCoursePort, task: CourseTask): Course? {
        val courseId = task.courseId ?: return null
        return port.getCourseById(courseId)
    }

    /** 某门课名下的作业，按到期日排序（[sourceWeek] 非空时只取那一周的）。 */
    fun tasksForCourse(port: TimetableCoursePort, courseId: String, sourceWeek: Long? = null): List<CourseTask> =
        port.tasks
            .filter { it.courseId == courseId && (sourceWeek == null || it.sourceWeek == sourceWeek) }
            .sortedWith { a, b -> CourseTask.compareByDueDate(a, b) }

    /**
     * 加一条作业。挂课程时顺手把该课程该周的"有作业"标记置 true。
     * 落盘失败把课程一起退回（标记是本条作业的副作用）。
     */
    fun addTask(port: TimetableCoursePort, task: CourseTask) {
        val normalized = normalizeTask(task)
        validateTask(port, normalized)
        val snapshotTasks = port.tasks.toList()
        val snapshotCourses = port.courses.toList()
        val snapshotProfiles = port.profiles.toList()
        port.tasks = sortTasks((port.tasks + normalized).toMutableList())
        markHomework(port, courseId = normalized.courseId, week = normalized.sourceWeek)
        try {
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.tasks = snapshotTasks
            port.courses = snapshotCourses
            port.profiles = snapshotProfiles
            throw e
        }
        port.notifyStateChanged()
        port.logEvent(
            "task_created",
            mapOf(
                "has_course" to if (normalized.courseId == null) 0 else 1,
                "has_due_date" to if (normalized.dueDate == null) 0 else 1,
            ),
        )
    }

    /** 把某门课某周的"有作业"标记置 true（课程/周次/备注任一不存在时幂等跳过）。 */
    private fun markHomework(port: TimetableCoursePort, courseId: String?, week: Long?) {
        if (courseId == null || week == null) return
        val weekInt = week.toInt()
        val courses = port.courses.toMutableList()
        val index = courses.indexOfFirst { it.id == courseId }
        if (index == -1) return
        val course = courses[index]
        val existing = course.sessionNoteForWeek(weekInt)
        if (existing?.hasHomework == true) return
        courses[index] = course.copy(
            sessionNotes = course.withSessionNote(
                weekInt,
                (existing ?: CourseSessionNote()).copy(hasHomework = true),
            ),
        )
        port.courses = courses.toList()
    }

    /**
     * 改一条作业：改的是用户点名那条。homeworkMark 被改过可推导三字段时盖 isUserEdited；
     * 挪到另一门课时顺手清掉原课程那周的标记。落盘失败连同课程一起退回。
     */
    fun updateTask(port: TimetableCoursePort, task: CourseTask) {
        val items = port.tasks.toMutableList()
        val index = items.indexOfFirst { it.id == task.id }
        if (index == -1) return
        val previous = items[index]
        val normalized = normalizeTask(task).copy(createdAt = previous.createdAt, updatedAt = LocalDateTime.now())
        validateTask(port, normalized)
        val derivedFieldsChanged = normalized.title != previous.title ||
            normalized.dueDate != previous.dueDate ||
            normalized.courseId != previous.courseId

        val snapshotTasks = port.tasks.toList()
        val snapshotCourses = port.courses.toList()
        val snapshotProfiles = port.profiles.toList()

        items[index] = if (derivedFieldsChanged || normalized.isUserEdited) {
            normalized.copy(isUserEdited = true)
        } else {
            normalized
        }
        if (previous.source == CourseTaskSource.HOMEWORK_MARK && normalized.courseId != previous.courseId) {
            clearHomeworkMark(port, courseId = previous.courseId, week = previous.sourceWeek)
        }
        port.tasks = sortTasks(items)
        try {
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.tasks = snapshotTasks
            port.courses = snapshotCourses
            port.profiles = snapshotProfiles
            throw e
        }
        port.notifyStateChanged()
    }

    /** 把某门课某周的"有作业"标记置回 false；课程或备注不存在时静默幂等。 */
    private fun clearHomeworkMark(port: TimetableCoursePort, courseId: String?, week: Long?) {
        if (courseId == null || week == null) return
        val weekInt = week.toInt()
        val courses = port.courses.toMutableList()
        val index = courses.indexOfFirst { it.id == courseId }
        if (index == -1) return
        val course = courses[index]
        val note = course.sessionNoteForWeek(weekInt)
        if (note == null || !note.hasHomework) return
        courses[index] = course.copy(
            sessionNotes = course.withSessionNote(weekInt, note.copy(hasHomework = false)),
        )
        port.courses = courses.toList()
    }

    /** 勾选/取消勾选一条作业：只改用户点名那条。 */
    fun toggleTaskCompleted(port: TimetableCoursePort, taskId: String) {
        val items = port.tasks.toMutableList()
        val index = items.indexOfFirst { it.id == taskId }
        if (index == -1) return
        val current = items[index]
        items[index] = current.copy(isCompleted = !current.isCompleted, updatedAt = LocalDateTime.now())
        port.tasks = sortTasks(items)
        port.persistActiveProfileState()
        port.notifyStateChanged()
    }

    /**
     * 删一条作业：会顺手把那门课对应周的 hasHomework 改成 false，
     * 落盘失败整体退回。
     */
    fun deleteTask(port: TimetableCoursePort, taskId: String) {
        val items = port.tasks.toMutableList()
        val index = items.indexOfFirst { it.id == taskId }
        if (index == -1) return
        val snapshotTasks = items.toList()
        val snapshotCourses = port.courses.toList()
        val snapshotProfiles = port.profiles.toList()
        val task = items[index]
        if (task.source == CourseTaskSource.HOMEWORK_MARK) {
            clearHomeworkMark(port, courseId = task.courseId, week = task.sourceWeek)
        }
        items.removeAt(index)
        port.tasks = items.toList()
        try {
            port.persistActiveProfileState()
        } catch (e: Exception) {
            port.tasks = snapshotTasks
            port.courses = snapshotCourses
            port.profiles = snapshotProfiles
            throw e
        }
        port.notifyStateChanged()
        port.logEvent("task_deleted", mapOf("remaining_task_count" to port.tasks.size))
    }

    /**
     * 按"课程周次备注里的作业标记"重算作业列表。
     * 用户接管过的原样保留；手写作业已占的周不再按备注生成第二条；
     * 只有字段真变才写新时间戳。返回作业列表是否变化。
     */
    fun syncHomeworkTasksWithCourses(port: TimetableCoursePort, persist: Boolean = false): Boolean {
        val before = MiniJson.encode(port.tasks.map { it.toJson() })

        val preservedEdited = mutableListOf<CourseTask>()
        val unmatchedDerived = mutableMapOf<String, CourseTask>()
        val next = mutableListOf<CourseTask>()
        val weeksWithManualTask = mutableSetOf<String>()
        for (task in port.tasks) {
            if (task.source == CourseTaskSource.MANUAL) {
                homeworkKey(task.courseId, task.sourceWeek)?.let { weeksWithManualTask.add(it) }
            }
        }
        for (task in port.tasks) {
            if (task.source != CourseTaskSource.HOMEWORK_MARK) {
                next.add(task)
                continue
            }
            if (task.isUserEdited) {
                preservedEdited.add(task)
                continue
            }
            val key = homeworkKey(task.courseId, task.sourceWeek) ?: continue
            unmatchedDerived[key] = task
        }
        val now = LocalDateTime.now()

        for (course in port.courses) {
            val notes = course.normalizedSessionNotesMap ?: continue
            for ((week, note) in notes.entries) {
                if (!note.hasHomework) continue
                val key = homeworkKey(course.id, week.toLong()) ?: continue
                if (weeksWithManualTask.contains(key)) {
                    unmatchedDerived.remove(key)
                    continue
                }
                val claimed = preservedEdited.any { it.courseId == course.id && it.sourceWeek == week.toLong() }
                if (claimed) {
                    unmatchedDerived.remove(key)
                    continue
                }
                val existing = unmatchedDerived.remove(key)
                val noteTitle = note.trimmedText
                if (noteTitle.isEmpty() && existing == null) continue
                val title = if (noteTitle.isEmpty()) existing!!.title else noteTitle
                val dueDate = port.dateForCourseOccurrence(course, week)
                if (existing != null &&
                    existing.title == title &&
                    existing.courseId == course.id &&
                    existing.sourceWeek == week.toLong() &&
                    existing.dueDate == dueDate
                ) {
                    next.add(existing)
                    continue
                }
                next.add(
                    (existing ?: CourseTask(
                        id = UUID.randomUUID().toString(),
                        title = title,
                        courseId = course.id,
                        sourceWeek = week.toLong(),
                        source = CourseTaskSource.HOMEWORK_MARK,
                        createdAt = now,
                        updatedAt = now,
                    )).copy(
                        title = title,
                        courseId = course.id,
                        sourceWeek = week.toLong(),
                        dueDate = dueDate,
                        source = CourseTaskSource.HOMEWORK_MARK,
                        updatedAt = now,
                    ),
                )
            }
        }

        next.addAll(preservedEdited)
        port.tasks = sortTasks(next.toMutableList())
        val after = MiniJson.encode(port.tasks.map { it.toJson() })
        val changed = before != after
        if (changed && persist) port.persistActiveProfileState()
        return changed
    }

    /** 推导作业的匹配键：课程 + 周次。任一为空时无键（不参与匹配）。 */
    fun homeworkKey(courseId: String?, week: Long?): String? {
        if (courseId == null || week == null) return null
        return "$courseId|$week"
    }

    private fun validateSections(port: TimetableCoursePort, course: Course) {
        if (course.timeSchemeIdOverride != null) {
            val message = port.validateCourseTimeSchemeOverride(
                timeSchemeId = course.timeSchemeIdOverride,
                startSection = course.startSection,
                endSection = course.endSection,
            )
            if (message != null) throw IllegalArgumentException(message)
            return
        }
        val minimalMessage = validateUnboundSections(
            startSection = course.startSection,
            endSection = course.endSection,
        )
        if (minimalMessage != null) throw IllegalArgumentException(minimalMessage)
    }

    private fun normalizeTask(task: CourseTask): CourseTask {
        val title = task.title.trim()
        val note = task.note?.trim()
        val courseId = task.courseId?.trim()
        val sourceWeek = if (task.sourceWeek != null && task.sourceWeek!! > 0) task.sourceWeek else null
        return task.copy(
            title = title,
            courseId = if (courseId.isNullOrEmpty()) null else courseId,
            sourceWeek = sourceWeek,
            dueDate = task.dueDate?.let { CourseTask.dateOnly(it) },
            note = if (note.isNullOrEmpty()) null else note,
            updatedAt = LocalDateTime.now(),
        )
    }

    private fun validateTask(port: TimetableCoursePort, task: CourseTask) {
        if (task.title.isEmpty()) throw IllegalArgumentException("task_title_required")
        if (task.courseId != null && port.getCourseById(task.courseId!!) == null) {
            throw IllegalArgumentException("task_course_not_found")
        }
    }

    /** 作业排序的唯一一份规则（读盘装配与写入口共用）。 */
    fun sortTasks(source: MutableList<CourseTask>): MutableList<CourseTask> {
        source.sortWith { a, b -> CourseTask.compareByDueDate(a, b) }
        return source
    }

    /**
     * 课程在第 [week] 周那次上课的日历日期（作业到期日取它）。
     * "课次 → 日历"的唯一规则；学期未配置或 week<1 返回 null。
     */
    fun courseOccurrenceDate(
        semesterStart: LocalDateTime?,
        course: Course,
        week: Int,
    ): LocalDateTime? {
        if (semesterStart == null || week < 1) return null
        val startOfSemesterWeek = WeekCalculator.startOfWeek(semesterStart)
        return WeekCalculator.addDays(startOfSemesterWeek, (week - 1) * 7 + course.dayOfWeek - 1)
    }
}
