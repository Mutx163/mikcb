package com.mutx163.qingyu.widgetdata

/**
 * 情侣课表（合并视图）纯逻辑（移植 lib/domain/couple_timetable_logic.dart
 * 的快照消费子集）。
 *
 * - TA 课程按周偏移平移到「我的周次坐标」后走同一套「天 + 周次」过滤；
 * - 同行程（同一天、节次重叠、同名忽略大小写与首尾空白）按我的那份去重；
 * - 三色：我 / TA / 一起。
 *
 * 周偏移钳制与默认色板与 Kotlin 既有 WidgetCoupleMergeLogic 同值（真机口径）。
 */
object CoupleTimetableData {

    fun clampWeekOffset(offset: Int): Int =
        offset.coerceIn(PartnerTimetableBinding.MIN_WEEK_OFFSET, PartnerTimetableBinding.MAX_WEEK_OFFSET)

    /** 我的第 [myWeek] 周 ↔ TA 的第几周（couple_timetable_logic.dart:46-48）。 */
    fun partnerWeekForMyWeek(myWeek: Int, weekOffset: Int): Int =
        myWeek + clampWeekOffset(weekOffset)

    /**
     * 同行程判定（isTogetherClass，:71-86）：同一天、节次重叠、同名
     * （忽略大小写与首尾空白）；双方在各自周次有效由调用方过滤后传入。
     */
    fun isTogetherClass(
        mine: com.mutx163.qingyu.core.Course,
        partner: com.mutx163.qingyu.core.Course,
        week: Int,
        partnerWeekOffset: Int,
    ): Boolean {
        if (mine.dayOfWeek != partner.dayOfWeek) return false
        if (mine.endSection < partner.startSection || partner.endSection < mine.startSection) return false
        val partnerWeek = partnerWeekForMyWeek(week, partnerWeekOffset)
        if (!mine.isActiveInWeek(week)) return false
        if (!partner.isActiveInWeek(partnerWeek)) return false
        return mine.name.trim().lowercase() == partner.name.trim().lowercase()
    }

    /** 三色取值（colorHexForKind，:126-137）。 */
    fun colorHexForKind(
        kind: CoupleCourseKind,
        mineColorHex: String?,
        partnerColorHex: String?,
        togetherColorHex: String?,
    ): String = when (kind) {
        CoupleCourseKind.MINE -> mineColorHex ?: PartnerTimetableBinding.MINE_COLOR_DEFAULT
        CoupleCourseKind.PARTNER -> partnerColorHex ?: PartnerTimetableBinding.PARTNER_COLOR_DEFAULT
        CoupleCourseKind.TOGETHER -> togetherColorHex ?: PartnerTimetableBinding.TOGETHER_COLOR_DEFAULT
    }
}

/**
 * 情侣合并视图某一天的课程（timetable_live_activity_service.dart:715-782
 * `_liveCoupleMergedDayCourses` 的纯内核）。
 *
 * 我方课程为主表（沿用 active 路径的解析与展示名，由调用方预处理），叠加 TA
 * 课程按周偏移映射后的同天课程；同行程按我的那份去重，其余 TA 课程追加，
 * 着情侣三色后按起始节次排序——同节次内按钟点分钟数比（`9:00` 不补零也正确）。
 *
 * B1 第一阶段（2026-11-06）起实现下沉到 [coupleMergedDayCoursesTagged]：
 * 本函数改薄包装（剥标记、吐纯 Course），旧签名与全部旧单测原样保留。
 */
fun coupleMergedDayCourses(
    mineCourses: List<com.mutx163.qingyu.core.Course>,
    partnerCourses: List<com.mutx163.qingyu.core.Course>,
    week: Int,
    partnerWeekOffset: Int,
    mineColorHex: String? = null,
    partnerColorHex: String? = null,
    togetherColorHex: String? = null,
): List<com.mutx163.qingyu.core.Course> =
    coupleMergedDayCoursesTagged(
        mineCourses = mineCourses,
        partnerCourses = partnerCourses,
        week = week,
        partnerWeekOffset = partnerWeekOffset,
        mineColorHex = mineColorHex,
        partnerColorHex = partnerColorHex,
        togetherColorHex = togetherColorHex,
    ).map { it.course }

/** 合并结果里一门课 + 它的情侣身份（我 / TA / 一起）。 */
data class CoupleTaggedCourse(
    val course: com.mutx163.qingyu.core.Course,
    val kind: CoupleCourseKind,
)

/**
 * [coupleMergedDayCourses] 的带标记变体：排序、去重、着色与原实现逐字同口径，
 * 只是不把身份丢掉——日视图装配要用它给 TA 条目打 `isPartnerCourse=true`
 *（`DayViewCourseCard` 的「TA的课」徽标，B1 第一阶段）。
 *
 * 合并 / 排序的判据注释见原函数（上一屏），这里不重复。
 */
fun coupleMergedDayCoursesTagged(
    mineCourses: List<com.mutx163.qingyu.core.Course>,
    partnerCourses: List<com.mutx163.qingyu.core.Course>,
    week: Int,
    partnerWeekOffset: Int,
    mineColorHex: String? = null,
    partnerColorHex: String? = null,
    togetherColorHex: String? = null,
): List<CoupleTaggedCourse> {
    val mineSorted = mineCourses.sortedBy { it.startSection }
    val partnerSorted = partnerCourses.sortedBy { it.startSection }
    val merged = mutableListOf<CoupleTaggedCourse>()
    val usedPartnerIds = mutableSetOf<String>()
    for (course in mineSorted) {
        var hasTogetherPartner = false
        for (candidate in partnerSorted) {
            if (CoupleTimetableData.isTogetherClass(course, candidate, week, partnerWeekOffset)) {
                hasTogetherPartner = true
                usedPartnerIds.add(candidate.id)
                break
            }
        }
        val kind = if (hasTogetherPartner) CoupleCourseKind.TOGETHER else CoupleCourseKind.MINE
        val color = CoupleTimetableData.colorHexForKind(
            kind,
            mineColorHex, partnerColorHex, togetherColorHex,
        )
        merged.add(CoupleTaggedCourse(course.copy(color = color), kind))
    }
    for (course in partnerSorted) {
        if (usedPartnerIds.contains(course.id)) continue
        merged.add(
            CoupleTaggedCourse(
                course.copy(
                    color = CoupleTimetableData.colorHexForKind(
                        CoupleCourseKind.PARTNER, mineColorHex, partnerColorHex, togetherColorHex,
                    ),
                ),
                CoupleCourseKind.PARTNER,
            ),
        )
    }
    return merged.sortedWith { a, b ->
        val bySection = a.course.startSection.compareTo(b.course.startSection)
        if (bySection != 0) {
            bySection
        } else {
            // 同一节次内的次序按分钟数比：钟点串可能来自外来存档（`9:00` 不补零），
            // 字典序下 '10:00' < '9:00' 会把合并后的同节次课程排反（:773-781）。
            WidgetDataClock.compareClockText(a.course.startTime, b.course.startTime)
        }
    }
}
