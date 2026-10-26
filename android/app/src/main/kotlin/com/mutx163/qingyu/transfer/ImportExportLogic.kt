package com.mutx163.qingyu.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableSettings

/**
 * 导入导出纯逻辑（移植自 lib/domain/import_export_logic.dart，2026-10-26 快照，
 * 616 行全部为纯函数）。
 *
 * 依赖的 core 资产与 Dart 的对应关系：
 * - [Course] / [CourseSessionNote]：lib/models/course.dart；
 * - [SectionTime] / [TimetableSettings.DEFAULT_SECTIONS]：
 *   lib/models/timetable_settings.dart 的 SectionTime 与 defaults()；
 * - 时钟解析：Dart `ClockTime.tryParse(value, allowEndOfDay: true)`，本文件
 *   内联同一份实现（Dart 侧 import_export_logic 也是内联调用）。
 *
 * **copyWith 的坑**：Dart 的 `copyWith(x: null)` 能把字段清空，而 Dart 课程
 * 合并里对可空字段的写法是「从 existing/imported 显式取值」，Kotlin 侧没有
 * _unset 哨兵，等价翻译为 `copy(x = 值)` 的 data class copy——所有传入值
 * 都按 Dart copyWith 的**实参语义**逐条对齐（传 null 即 null）。
 */

/** 导入同步结果（import_export_logic.dart:9-32）。 */
data class ImportedCourseSyncResult(
    val mergedCourses: List<Course>,
    /** 新增条数。 */
    val addedCount: Int,
    /** 更新条数。 */
    val updatedCount: Int,
    /**
     * 导入侧课程 id → 合并后实际留下的本地 id。
     *
     * 存在的理由是**作业引用**：合并时按「同名 / 同时间」软匹配到已有课次后，
     * 留下的是**本地** id（[mergeImportedCourseWithExisting] 里 id 取 existing 的），
     * 导入侧那个 id 直接被丢掉。而随同一份包传过来的作业仍指着导入侧的 id，
     * 于是 `task_course_missing` 一抛、整次导入作废。调用方拿这份映射把作业的
     * courseId 改写过去即可。
     *
     * 新增（没匹配上任何已有课次）的课程是恒等映射——它们的 id 就是导入侧 id。
     * 被去重丢掉的重复条目也在表里，指向保留下来的那一条。
     */
    val importedIdToLocalId: Map<String, String> = emptyMap(),
)

/** 导入需要补节时学期周数上限（import_export_logic.dart:39）。 */
const val MAX_ALLOWED_SEMESTER_WEEK_COUNT: Int = 30

/** 一天的分钟数；`24:00` == 1440 == 当天结束（与 ClockTime allowEndOfDay 同口径）。 */
const val MINUTES_PER_DAY: Int = 24 * 60

/** 导入课程需要的最大节数（import_export_logic.dart:44-55）。 */
fun previewImportedCourseRequiredSectionCount(
    importedCourses: List<Course>,
    currentSectionCount: Int,
): Int {
    if (importedCourses.isEmpty()) {
        return currentSectionCount
    }
    return importedCourses.maxOf { it.endSection }
}

/** 课程的最大周次（import_export_logic.dart:57-69）。 */
fun maxCourseWeek(courses: List<Course>, fallbackWeekCount: Int): Int {
    if (courses.isEmpty()) {
        return fallbackWeekCount.coerceIn(1, MAX_ALLOWED_SEMESTER_WEEK_COUNT)
    }
    val raw = courses.maxOf { it.normalizedCustomWeeks?.last() ?: it.endWeek }
    return raw.coerceIn(1, MAX_ALLOWED_SEMESTER_WEEK_COUNT)
}

/**
 * 补齐节次表（import_export_logic.dart:71-109）。
 *
 * 锚点必须是**能解析**的结束时间：畸形串按 -1 当锚点会补出
 * 「-1 + 课间 10 = 00:09」这种凌晨节次。一条都解析不出来时停止补节；
 * 补到超过当天结束（1440）也停——继续会造出绕回凌晨的节次，
 * 排在已有节次之前，导入侧烤出来的钟点整段错位。
 */
fun buildExpandedSections(
    sections: List<SectionTime>,
    requiredSectionCount: Int,
): List<SectionTime> {
    val expanded = (if (sections.isEmpty()) TimetableSettings.DEFAULT_SECTIONS else sections)
        .toMutableList()

    val defaultDuration = inferSectionDurationMinutes(expanded)
    val defaultBreak = inferBreakDurationMinutes(expanded)
    while (expanded.size < requiredSectionCount) {
        val lastEndMinutes = lastParseableEndMinutes(expanded) ?: break
        val nextStartMinutes = lastEndMinutes + defaultBreak
        val nextEndMinutes = nextStartMinutes + defaultDuration
        if (nextEndMinutes > MINUTES_PER_DAY) {
            break
        }
        expanded.add(
            SectionTime(
                startTime = formatClockMinutes(nextStartMinutes),
                endTime = formatClockMinutes(nextEndMinutes),
            ),
        )
    }
    return expanded
}

/** 节长推断：从后往前取第一条 duration > 0 的；一条没有按 45（:111-121）。 */
private fun inferSectionDurationMinutes(sections: List<SectionTime>): Int {
    for (index in sections.indices.reversed()) {
        val start = parseClockToMinutes(sections[index].startTime)
        val end = parseClockToMinutes(sections[index].endTime)
        val duration = end - start
        if (duration > 0) return duration
    }
    return 45
}

/** 课间推断：相邻两条的 gap > 0；一条没有按 10（:123-137）。 */
private fun inferBreakDurationMinutes(sections: List<SectionTime>): Int {
    if (sections.size < 2) return 10
    for (index in sections.size - 1 downTo 1) {
        val previousEnd = parseClockToMinutes(sections[index - 1].endTime)
        val currentStart = parseClockToMinutes(sections[index].startTime)
        val gap = currentStart - previousEnd
        if (gap > 0) return gap
    }
    return 10
}

/** 从后往前取第一条能解析的结束时间（分钟）。全都不合法时返回 null（:139-148）。 */
private fun lastParseableEndMinutes(sections: List<SectionTime>): Int? {
    for (index in sections.indices.reversed()) {
        val minutes = parseClockToMinutes(sections[index].endTime)
        if (minutes >= 0) return minutes
    }
    return null
}

/**
 * 时钟解析（import_export_logic.dart:150-156，与 lib/utils/clock_time.dart 同一份
 * 实现）：`allowEndOfDay` 只额外放行恰好 `24:00`（记为 1440）；`24:30`/`25:00`/
 * `08:75` 一律拒绝——它们会被 DateTime 静默归一到别的日子。失败返回 -1。
 */
private fun parseClockToMinutes(value: String): Int {
    val text = value.trim()
    if (text.isEmpty()) return -1
    val parts = text.split(":")
    if (parts.size != 2) return -1
    val hour = parts[0].trim().toIntOrNull() ?: return -1
    val minute = parts[1].trim().toIntOrNull() ?: return -1
    if (minute < 0 || minute > 59) return -1
    if (hour == 24 && minute == 0) return 24 * 60
    if (hour < 0 || hour > 23) return -1
    return hour * 60 + minute
}

/**
 * 分钟数 → `HH:mm`（import_export_logic.dart:158-173）。1440 必须写成 `24:00`：
 * 它是本仓认可的「当天结束」，只是 `% 1440` 归一的话会回绕成 `00:00`，
 * 补出来的节次结束时间小于开始时间。
 */
private fun formatClockMinutes(minutes: Int): String {
    if (minutes == MINUTES_PER_DAY) return "24:00"
    val normalized = minutes % MINUTES_PER_DAY
    val hour = normalized / 60
    val minute = normalized % 60
    return "%02d:%02d".format(hour, minute)
}

/** 导入去重键（import_export_logic.dart:177-188）。 */
fun buildImportedCourseDedupKey(course: Course): String {
    val weeks = course.activeWeeks.sorted()
    return listOf(
        dartTrim(course.name).lowercase(),
        dartTrim(course.teacher).lowercase(),
        dartTrim(course.location).lowercase(),
        course.dayOfWeek.toString(),
        course.startSection.toString(),
        course.endSection.toString(),
        weeks.joinToString(","),
    ).joinToString("|")
}

/**
 * 导入去重（import_export_logic.dart:190-203）：先按 existing 的键占坑，
 * 再逐条 add——导入包内互重的条目与撞上 existing 的条目一并被丢。
 */
fun dedupeImportedCourses(
    importedCourses: List<Course>,
    existingCourses: List<Course> = emptyList(),
): List<Course> {
    val keys = existingCourses.map { buildImportedCourseDedupKey(it) }.toMutableSet()
    val result = mutableListOf<Course>()
    for (course in importedCourses) {
        val key = buildImportedCourseDedupKey(course)
        if (keys.add(key)) {
            result.add(course)
        }
    }
    return result
}

/**
 * 更新合并（import_export_logic.dart:206-236）：以 imported 为基底，
 * 本地共享字段（简称/颜色/性质/简介/备注/每周作业/时间模板）全保留；
 * 停课周是用户在编辑课程页加的本地标注，导入真带得动停课周时才以导入为准。
 */
fun mergeImportedCourseWithExisting(
    existing: Course,
    imported: Course,
    preserveLocalColors: Boolean = true,
): Course {
    return imported.copy(
        id = existing.id,
        name = if (imported.name.trim().isEmpty()) existing.name else imported.name,
        teacher = if (imported.teacher.trim().isEmpty()) existing.teacher else imported.teacher,
        location = if (imported.location.trim().isEmpty()) existing.location else imported.location,
        shortName = existing.shortName,
        color = if (preserveLocalColors) existing.color else imported.color,
        textColor = if (preserveLocalColors) existing.textColor else imported.textColor,
        courseNature = existing.courseNature,
        description = existing.description,
        note = existing.note,
        sessionNotes = existing.sessionNotes,
        timeSchemeIdOverride = existing.timeSchemeIdOverride,
        suspendedWeeks = if (!imported.suspendedWeeks.isNullOrEmpty()) {
            imported.suspendedWeeks
        } else {
            existing.suspendedWeeks
        },
    )
}

/**
 * 覆盖导入的按名复用（import_export_logic.dart:239-267）：与
 * [mergeImportedCourseWithExisting] 同口径，但不改 id（保持导入侧 id，
 * 整表替换时由调用方决定去留）。漏 timeSchemeIdOverride 会让课程钟点
 * 回落到全局作息模板，用户按错误的时间去教室。
 */
fun preserveImportedCourseLocalSharedFields(
    existing: Course,
    imported: Course,
    preserveLocalColors: Boolean = true,
): Course {
    return imported.copy(
        name = if (imported.name.trim().isEmpty()) existing.name else imported.name,
        teacher = if (imported.teacher.trim().isEmpty()) existing.teacher else imported.teacher,
        location = if (imported.location.trim().isEmpty()) existing.location else imported.location,
        shortName = existing.shortName,
        color = if (preserveLocalColors) existing.color else imported.color,
        textColor = if (preserveLocalColors) existing.textColor else imported.textColor,
        courseNature = existing.courseNature,
        description = existing.description,
        note = existing.note,
        sessionNotes = existing.sessionNotes,
        timeSchemeIdOverride = existing.timeSchemeIdOverride,
        suspendedWeeks = if (!imported.suspendedWeeks.isNullOrEmpty()) {
            imported.suspendedWeeks
        } else {
            existing.suspendedWeeks
        },
    )
}

/**
 * 同名多课次的共享字段分发（import_export_logic.dart:270-292）：以**本地**课次
 * 为基底（保留本地时间与周次），只把导入的名称/教师/教室灌进去。
 */
fun mergeImportedSharedFieldsIntoExistingSchedule(
    existing: Course,
    imported: Course,
    preserveLocalColors: Boolean = true,
): Course {
    return existing.copy(
        name = if (imported.name.trim().isEmpty()) existing.name else imported.name,
        teacher = if (imported.teacher.trim().isEmpty()) existing.teacher else imported.teacher,
        location = if (imported.location.trim().isEmpty()) existing.location else imported.location,
        shortName = existing.shortName,
        color = if (preserveLocalColors) existing.color else imported.color,
        textColor = if (preserveLocalColors) existing.textColor else imported.textColor,
        courseNature = existing.courseNature,
        description = existing.description,
        note = existing.note,
        sessionNotes = existing.sessionNotes,
        timeSchemeIdOverride = existing.timeSchemeIdOverride,
    )
}

/**
 * 整表替换（import_export_logic.dart:294-369）：导入前先去重；同名课
 * （共享字段键）先灌本地共享字段；再按「组匹配 → 精确匹配 → 软匹配」
 * 找本地课次落 id 与元数据。没匹配上的按导入侧原样保留。
 */
fun replaceImportedCoursesPreservingLocalFields(
    existingCourses: List<Course>,
    importedCourses: List<Course>,
    preserveLocalColors: Boolean = true,
): List<Course> {
    val dedupedImported = dedupeImportedCourses(importedCourses)
    val existingSharedCoursesByName = LinkedHashMap<String, Course>()
    for (existing in existingCourses) {
        existingSharedCoursesByName.putIfAbsent(
            buildSharedCourseNameKey(existing.name),
            existing,
        )
    }

    val matchedExistingIds = mutableSetOf<String>()
    val replacedCourses = mutableListOf<Course>()

    for (imported in dedupedImported) {
        var rebuilt = imported
        val sharedExisting = existingSharedCoursesByName[buildSharedCourseNameKey(imported.name)]
        if (sharedExisting != null) {
            rebuilt = preserveImportedCourseLocalSharedFields(
                sharedExisting,
                rebuilt,
                preserveLocalColors,
            )
        }

        val groupedMatchIndices = findGroupedImportedCourseMatchIndices(
            existingCourses,
            imported,
            matchedExistingIds,
        )
        if (groupedMatchIndices.isNotEmpty()) {
            val existing = existingCourses[groupedMatchIndices.first()]
            for (index in groupedMatchIndices) {
                matchedExistingIds.add(existingCourses[index].id)
            }
            rebuilt = mergeImportedCourseWithExisting(existing, rebuilt, preserveLocalColors)
            replacedCourses.add(rebuilt)
            continue
        }

        var matchedIndex = findExactImportedCourseMatchIndex(
            existingCourses, imported, matchedExistingIds,
        )
        if (matchedIndex == -1) {
            matchedIndex = findSoftImportedCourseMatchIndex(
                existingCourses, imported, matchedExistingIds,
            )
        }

        if (matchedIndex != -1) {
            val existing = existingCourses[matchedIndex]
            matchedExistingIds.add(existing.id)
            rebuilt = mergeImportedCourseWithExisting(existing, rebuilt, preserveLocalColors)
        }

        replacedCourses.add(rebuilt)
    }

    return replacedCourses
}

/**
 * 导入同步（import_export_logic.dart:371-456）：existing 全保留，逐条
 * 匹配的更新（留本地 id），没匹配的新增（留导入侧 id）。
 */
fun syncImportedCourses(
    existingCourses: List<Course>,
    importedCourses: List<Course>,
    preserveLocalColors: Boolean = true,
): ImportedCourseSyncResult {
    val dedupedImported = dedupeImportedCourses(importedCourses)
    val merged = existingCourses.toMutableList()
    val matchedExistingIds = mutableSetOf<String>()
    var addedCount = 0
    var updatedCount = 0

    // 导入侧 id → 合并后留下的本地 id。先按去重键记下「被去重丢掉的 id 归到谁」，
    // 再在下面逐条记录幸存者的去向。
    val importedIdToLocalId = LinkedHashMap<String, String>()
    val survivorByDedupKey = LinkedHashMap<String, String>()
    for (course in dedupedImported) {
        survivorByDedupKey[buildImportedCourseDedupKey(course)] = course.id
    }
    for (course in importedCourses) {
        val survivorId = survivorByDedupKey[buildImportedCourseDedupKey(course)] ?: course.id
        importedIdToLocalId[course.id] = survivorId
    }

    for (imported in dedupedImported) {
        val groupedMatchIndices = findGroupedImportedCourseMatchIndices(
            merged,
            imported,
            matchedExistingIds,
        )
        if (groupedMatchIndices.isNotEmpty()) {
            for (index in groupedMatchIndices) {
                val existing = merged[index]
                matchedExistingIds.add(existing.id)
                merged[index] = mergeImportedSharedFieldsIntoExistingSchedule(
                    existing,
                    imported,
                    preserveLocalColors,
                )
                updatedCount++
            }
            // 一组同名课次匹配到多条本地记录时，作业无法判断该指哪一条；
            // 保留第一条之外的映射仍指向第一条，避免出现「映射到 null」。
            importedIdToLocalId[imported.id] = merged[groupedMatchIndices.first()].id
            continue
        }

        var matchedIndex = findExactImportedCourseMatchIndex(merged, imported, matchedExistingIds)
        if (matchedIndex == -1) {
            matchedIndex = findSoftImportedCourseMatchIndex(merged, imported, matchedExistingIds)
        }

        if (matchedIndex != -1) {
            val existing = merged[matchedIndex]
            matchedExistingIds.add(existing.id)
            merged[matchedIndex] = mergeImportedCourseWithExisting(
                existing,
                imported,
                preserveLocalColors,
            )
            updatedCount++
            // 关键一条：软匹配保留了本地 id，作业必须跟着改写。
            importedIdToLocalId[imported.id] = existing.id
        } else {
            merged.add(imported)
            addedCount++
            // 新增课程沿用导入侧 id，映射是恒等。
            importedIdToLocalId[imported.id] = imported.id
        }
    }

    return ImportedCourseSyncResult(
        mergedCourses = merged,
        addedCount = addedCount,
        updatedCount = updatedCount,
        importedIdToLocalId = importedIdToLocalId,
    )
}

/**
 * 课程列表等价（import_export_logic.dart:458-471）：逐条比 JSON 串。
 * Kotlin 侧课程没有 toJsonString，这里用 [com.mutx163.qingyu.core.MiniJson]
 * 编码 toJson（键序一致），等价性相同。
 */
fun courseListsEqual(left: List<Course>, right: List<Course>): Boolean {
    if (left === right) return true
    if (left.size != right.size) return false
    for (index in left.indices) {
        if (MiniJson.encode(left[index].toJson()) != MiniJson.encode(right[index].toJson())) {
            return false
        }
    }
    return true
}

/** 共享字段键（import_export_logic.dart:473）：trim + lowercase 的课程名。 */
private fun buildSharedCourseNameKey(name: String): String = name.trim().lowercase()

/** 精确匹配键（import_export_logic.dart:546-555）：名|日|起止节|周次。 */
private fun buildImportedCourseExactMatchKey(course: Course): String {
    val weeks = course.activeWeeks.sorted()
    return listOf(
        course.name.trim().lowercase(),
        course.dayOfWeek.toString(),
        course.startSection.toString(),
        course.endSection.toString(),
        weeks.joinToString(","),
    ).joinToString("|")
}

private fun findExactImportedCourseMatchIndex(
    existingCourses: List<Course>,
    imported: Course,
    matchedExistingIds: Set<String>,
): Int {
    val importedKey = buildImportedCourseExactMatchKey(imported)
    for ((index, existing) in existingCourses.withIndex()) {
        if (existing.id in matchedExistingIds) continue
        if (buildImportedCourseExactMatchKey(existing) == importedKey) return index
    }
    return -1
}

/**
 * 软匹配（import_export_logic.dart:493-544）：同名 + 同星期 + 同节数才能配；
 * 周次重合率 ≥ 0.5 打底，教师相同 +0.2、教室相同 +0.1，取最高分。
 */
private fun findSoftImportedCourseMatchIndex(
    existingCourses: List<Course>,
    imported: Course,
    matchedExistingIds: Set<String>,
): Int {
    var bestIndex = -1
    var bestScore = 0.0
    for ((index, existing) in existingCourses.withIndex()) {
        if (existing.id in matchedExistingIds) continue
        if (existing.name.trim().lowercase() != imported.name.trim().lowercase()) continue
        // 同星期才允许软匹配，同名多时段的课不会被并成一条。
        if (existing.dayOfWeek != imported.dayOfWeek) continue
        if (existing.sectionCount != imported.sectionCount) continue
        val overlapScore = weekOverlapScore(existing.activeWeeks, imported.activeWeeks)
        if (overlapScore < 0.5) continue
        val teacherBonus = if (
            existing.teacher.trim().isNotEmpty() &&
            imported.teacher.trim().isNotEmpty() &&
            existing.teacher.trim().lowercase() == imported.teacher.trim().lowercase()
        ) 0.2 else 0.0
        val locationBonus = if (
            existing.location.trim().isNotEmpty() &&
            imported.location.trim().isNotEmpty() &&
            existing.location.trim().lowercase() == imported.location.trim().lowercase()
        ) 0.1 else 0.0
        val score = overlapScore + teacherBonus + locationBonus
        if (score > bestScore) {
            bestScore = score
            bestIndex = index
        }
    }
    return bestIndex
}

/**
 * 组匹配（import_export_logic.dart:557-596）：本地多条「拆开记」的课次
 * （同名同节次、周次互不重叠）能被一条导入的组合周次完整覆盖时，
 * 把共享字段分发到每一条本地记录上。
 */
private fun findGroupedImportedCourseMatchIndices(
    existingCourses: List<Course>,
    imported: Course,
    matchedExistingIds: Set<String>,
): List<Int> {
    val importedWeeks = imported.activeWeeks.filter { it >= 1 }.toMutableSet()
    if (importedWeeks.isEmpty()) return emptyList()
    val indices = mutableListOf<Int>()
    val coveredWeeks = mutableSetOf<Int>()
    for ((index, existing) in existingCourses.withIndex()) {
        if (existing.id in matchedExistingIds) continue
        if (!hasSameStructuralKey(existing, imported)) continue
        val existingWeeks = existing.activeWeeks.filter { it >= 1 }.toMutableSet()
        if (existingWeeks.isEmpty()) continue
        if (!importedWeeks.containsAll(existingWeeks)) continue
        indices.add(index)
        coveredWeeks.addAll(existingWeeks)
    }
    if (indices.size <= 1) return emptyList()
    if (coveredWeeks.size != importedWeeks.size || !coveredWeeks.containsAll(importedWeeks)) {
        return emptyList()
    }
    return indices
}

/** 结构键（import_export_logic.dart:598-603）：名|日|起止节。 */
private fun hasSameStructuralKey(left: Course, right: Course): Boolean =
    left.name.trim().lowercase() == right.name.trim().lowercase() &&
        left.dayOfWeek == right.dayOfWeek &&
        left.startSection == right.startSection &&
        left.endSection == right.endSection

/** 周次重合率（import_export_logic.dart:605-616）：交集 / 较大者。 */
private fun weekOverlapScore(left: List<Int>, right: List<Int>): Double {
    if (left.isEmpty() || right.isEmpty()) return 0.0
    val leftSet = left.toSet()
    val rightSet = right.toSet()
    val intersection = leftSet.intersect(rightSet).size
    val base = maxOf(leftSet.size, rightSet.size)
    return if (base == 0) 0.0 else intersection.toDouble() / base
}
