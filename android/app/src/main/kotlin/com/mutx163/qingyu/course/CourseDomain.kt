package com.mutx163.qingyu.course

/**
 * 同名课程共享元数据键：去除首尾空白并转小写。
 *
 * 移植自 lib/domain/course_domain.dart `buildSharedCourseNameKey`。
 * Dart 与 Kotlin 的 trim/toLowerCase 均按 Unicode 空白/小写折叠，
 * 中文课程名不受影响；英文大小写归一（"Math " 与 " math" 同组）。
 */
fun buildSharedCourseNameKey(name: String): String = name.trim().lowercase()

/**
 * 课程冲突判定与共享字段领域服务（纯逻辑，无 IO）。
 *
 * 移植自 lib/domain/course_domain.dart（2026-10-26 快照，155 行）。
 * 已合入 core/ 的 Course 模型直接复用，不复制。
 *
 * 口径说明（与 Dart 逐条一致）：
 * - conflict：同 id 永不冲突（同一条目多课次不算冲突）。
 * - overlapInWeek：先比星期与节次区间；带 week 时按 isActiveInWeek（含停课），
 *   不带时在两侧候选周并集里找共同激活周；候选周经 weekCandidates（custom 优先）。
 * - applySharedFields：只传播课程级共享字段（name/shortName/color/textColor/
 *   courseNature/description，回落 legacy note）；teacher/location 按条目保留。
 * - editCourseClock：节次没动且原有时钟是适配脚本 pin 住的 → 原样保留；
 *   否则交回模板（hasCustomTime=false）。
 */
object CourseDomain {

    /** 两条课表项是否构成冲突（同一门课按 id 排除）。 */
    fun conflict(left: com.mutx163.qingyu.core.Course, right: com.mutx163.qingyu.core.Course, week: Int? = null): Boolean {
        if (left.id == right.id) return false
        return overlapInWeek(left, right, week = week)
    }

    /**
     * 两条课表项在同一周是否时段重叠（不含同 id 排除）。
     *
     * [week] 给定时只判定该周（优先 isActiveInWeek，停课周不误报）；
     * 未给定时在两课候选周的并集中寻找共同激活周。
     */
    fun overlapInWeek(
        left: com.mutx163.qingyu.core.Course,
        right: com.mutx163.qingyu.core.Course,
        week: Int? = null,
    ): Boolean {
        if (left.dayOfWeek != right.dayOfWeek) return false
        if (left.endSection < right.startSection || right.endSection < left.startSection) return false
        if (week != null) {
            return left.isActiveInWeek(week) && right.isActiveInWeek(week)
        }
        val candidates = weekCandidates(left) + weekCandidates(right)
        for (candidate in candidates) {
            if (left.isActiveInWeek(candidate) && right.isActiveInWeek(candidate)) return true
        }
        return false
    }

    /** 构建整份课表的冲突索引：课程 id → 与之冲突的其它课表项。 */
    fun buildConflictMap(
        courses: List<com.mutx163.qingyu.core.Course>,
        week: Int? = null,
    ): Map<String, List<com.mutx163.qingyu.core.Course>> {
        val conflictMap = mutableMapOf<String, MutableList<com.mutx163.qingyu.core.Course>>()
        for (i in courses.indices) {
            for (j in i + 1 until courses.size) {
                if (!conflict(courses[i], courses[j], week = week)) continue
                conflictMap.getOrPut(courses[i].id) { mutableListOf() }.add(courses[j])
                conflictMap.getOrPut(courses[j].id) { mutableListOf() }.add(courses[i])
            }
        }
        return conflictMap
    }

    /** 课程的候选周集合：customWeeks 优先，否则 startWeek..endWeek 区间。 */
    fun weekCandidates(course: com.mutx163.qingyu.core.Course): Set<Int> {
        val custom = course.normalizedCustomWeeks
        if (!custom.isNullOrEmpty()) return custom.toSet()
        val weeks = mutableSetOf<Int>()
        val start = if (course.startWeek < 1) 1 else course.startWeek
        val end = if (course.endWeek < start) start else course.endWeek
        for (week in start..end) weeks.add(week)
        return weeks
    }

    /**
     * 将 [source] 的课程级共享字段覆盖到 [target] 并返回新对象。
     *
     * teacher/location 按课表条目各自保留，不在此传播。
     */
    fun applySharedFields(
        target: com.mutx163.qingyu.core.Course,
        source: com.mutx163.qingyu.core.Course,
    ): com.mutx163.qingyu.core.Course {
        val sharedDescription = run {
            val description = source.description?.trim()
            if (!description.isNullOrEmpty()) return@run description
            val legacyNote = source.note?.trim()
            if (!legacyNote.isNullOrEmpty()) return@run legacyNote
            null
        }
        return target.copy(
            name = source.name,
            shortName = source.shortName,
            color = source.color,
            textColor = source.textColor,
            courseNature = source.courseNature,
            description = sharedDescription,
        )
    }

    /** [course] 名称对应的共享键。 */
    fun sharedKey(course: com.mutx163.qingyu.core.Course): String =
        buildSharedCourseNameKey(course.name)

    /**
     * 编辑一门课时它最终该用的钟点（course_domain.dart:126-154）。
     *
     * keepsPinnedClock = 原有时钟是适配脚本 pin 住的（hasCustomTime）且节次没动
     * → 原样保留；否则交回模板（hasCustomTime=false）。
     */
    data class EditCourseClockResult(
        val startTime: String,
        val endTime: String,
        val hasCustomTime: Boolean,
    )

    fun editCourseClock(
        original: com.mutx163.qingyu.core.Course?,
        startSection: Int,
        endSection: Int,
        templateStartTime: String,
        templateEndTime: String,
    ): EditCourseClockResult {
        val keepsPinnedClock = original != null &&
            original.hasCustomTime &&
            original.startSection == startSection &&
            original.endSection == endSection
        if (keepsPinnedClock) {
            return EditCourseClockResult(
                startTime = original.startTime,
                endTime = original.endTime,
                hasCustomTime = true,
            )
        }
        return EditCourseClockResult(
            startTime = templateStartTime,
            endTime = templateEndTime,
            hasCustomTime = false,
        )
    }
}
