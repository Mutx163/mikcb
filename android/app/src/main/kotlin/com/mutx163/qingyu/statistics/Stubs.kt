package com.mutx163.qingyu.statistics

// 泳道 A 已把 CourseNature 落进 core 包（Course.kt）——桩改用真定义，
// 不再自带（Lead 合并时统一，2026-10-26）。
import com.mutx163.qingyu.core.CourseNature

/**
 * 桩，待泳道 A 的 core 模型合入后替换。
 *
 * 这里的 [CourseStub] 按 `lib/models/course.dart` 的**字段与周次判定语义**逐行翻译，
 * 只保留统计计算实际消费的字段（name/teacher/location/dayOfWeek/startSection/
 * endSection/startTime/endTime/startWeek/endWeek/isOddWeek/isEvenWeek/customWeeks/
 * suspendedWeeks/courseNature）。course.dart 里其余字段（id/color/sessionNotes/
 * 时间模板覆盖等）与统计无关，桩不含。
 *
 * 语义契约（合并进 core 模型后必须保持一致，见对应 Dart 行号）：
 * - normalizeWeekList（course.dart:200-216）：null/空/超过 512 条 → null；
 *   逐条钳 1..maxWeek 去重后升序返回；全被钳掉 → null。
 * - isInWeek（course.dart:608-617）：customWeeks 非空时按「归一化后的周列表包含」
 *   判定，startWeek/endWeek 与单双周标志**全部失效**；否则按区间 + 单双周奇偶过滤。
 * - isActiveInWeek（course.dart:620-623）：先查停课周（用**原始**列表 contains，
 *   不走 normalizeWeekList），再走 isInWeek。
 * - sectionCount（course.dart:505）：endSection - startSection + 1（可为负，不钳）。
 */
data class CourseStub(
    val name: String,
    val teacher: String,
    val location: String,
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    val startTime: String,
    val endTime: String,
    val startWeek: Int = 1,
    val endWeek: Int = 16,
    val isOddWeek: Boolean = false,
    val isEvenWeek: Boolean = false,
    val customWeeks: List<Int>? = null,
    val suspendedWeeks: List<Int>? = null,
    val courseNature: CourseNature = CourseNature.REQUIRED,
) {
    /** course.dart:505 `int get sectionCount => endSection - startSection + 1;` */
    val sectionCount: Int
        get() = endSection - startSection + 1

    /** course.dart:574 归一化自定义周列表（1..30，≤512 条，去重升序）。 */
    val normalizedCustomWeeks: List<Int>?
        get() = normalizeWeekList(customWeeks)

    /** course.dart:578 归一化停课周列表（同一钳制口径）。 */
    val normalizedSuspendedWeeks: List<Int>?
        get() = normalizeWeekList(suspendedWeeks)

    /** course.dart:608-617 */
    fun isInWeek(week: Int): Boolean {
        val custom = normalizedCustomWeeks
        if (custom != null) {
            return custom.contains(week)
        }
        if (week < startWeek || week > endWeek) return false
        if (isOddWeek && week % 2 == 0) return false
        if (isEvenWeek && week % 2 != 0) return false
        return true
    }

    /** course.dart:620-623：先查原始停课列表，再走 isInWeek。 */
    fun isActiveInWeek(week: Int): Boolean {
        if (suspendedWeeks?.contains(week) == true) return false
        return isInWeek(week)
    }

    companion object {
        const val MAX_WEEK_LIST_ENTRIES = 512

        /** course.dart:200-216 */
        fun normalizeWeekList(weeks: List<Int>?, maxWeek: Int = 30): List<Int>? {
            if (weeks == null || weeks.isEmpty() || weeks.size > MAX_WEEK_LIST_ENTRIES) {
                return null
            }
            val safeMaxWeek = if (maxWeek < 1) 1 else maxWeek
            val normalized = sortedSetOf<Int>()
            for (week in weeks) {
                if (week < 1 || week > safeMaxWeek) continue
                normalized.add(week)
            }
            if (normalized.isEmpty()) return null
            return normalized.toList()
        }
    }
}
