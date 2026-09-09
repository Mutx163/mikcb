package com.mutx163.qingyu

/**
 * 情侣课表（合并视图）的课程合并纯逻辑，与 Dart 侧 CoupleTimetableLogic 同口径：
 * - TA 课程按周偏移平移到「我的周次坐标」（TA 第 W_p 周 ↔ 我的第 W_p - offset 周），
 *   之后即可与我的课程走同一套「天 + 周次」过滤；
 * - 同行程（同一天、节次重叠、同名忽略大小写与首尾空白）按我的那份去重；
 * - 课程按情侣三色着色：我 / TA / 一起（与 App 内情侣覆盖层一致）。
 */
/** 纯逻辑对象内部实现细节（internal 类型参数），测试 sourceSet 仍可访问。 */
internal object WidgetCoupleMergeLogic {

    /** 与 Dart CoupleTimetableLogic 色板默认值一致。 */
    const val MINE_COLOR_DEFAULT = "#2196F3"
    const val PARTNER_COLOR_DEFAULT = "#E91E63"
    const val TOGETHER_COLOR_DEFAULT = "#9C27B0"

    /** 与 Dart clampWeekOffset 一致。 */
    const val MIN_WEEK_OFFSET = -15
    const val MAX_WEEK_OFFSET = 15

    fun clampWeekOffset(offset: Int): Int = offset.coerceIn(MIN_WEEK_OFFSET, MAX_WEEK_OFFSET)

    /** 情侣三色（已含默认值兜底）。 */
    data class CoupleColors(
        val mine: String = MINE_COLOR_DEFAULT,
        val partner: String = PARTNER_COLOR_DEFAULT,
        val together: String = TOGETHER_COLOR_DEFAULT,
    )

    /**
     * 把 TA 课程从「TA 周次坐标」平移到「我的周次坐标」。startWeek/endWeek 与
     * customWeeks/suspendedWeeks 整体平移 -offset；offset 为奇数时单双周奇偶互换
     * （TA 的单周课落在我方坐标的双周上）。
     */
    fun shiftPartnerCourseToMyWeeks(course: WidgetSourceCourse, offset: Int): WidgetSourceCourse {
        if (offset == 0) return course
        val parityFlip = offset % 2 != 0
        return course.copy(
            startWeek = course.startWeek - offset,
            endWeek = course.endWeek - offset,
            customWeeks = course.customWeeks?.map { it - offset },
            suspendedWeeks = course.suspendedWeeks?.map { it - offset },
            isOddWeek = if (parityFlip) course.isEvenWeek else course.isOddWeek,
            isEvenWeek = if (parityFlip) course.isOddWeek else course.isEvenWeek,
        )
    }

    /**
     * 同行程判定（对齐 Dart isTogetherClass 的可比部分）：同一天、节次重叠、
     * 同名（忽略大小写与首尾空白）。双方是否在各自周次有效由调用方的过滤保证。
     */
    fun isTogetherClass(mine: WidgetSourceCourse, partner: WidgetSourceCourse): Boolean {
        if (mine.dayOfWeek != partner.dayOfWeek) return false
        if (mine.endSection < partner.startSection || partner.endSection < mine.startSection) {
            return false
        }
        return mine.name.trim().lowercase() == partner.name.trim().lowercase()
    }

    /**
     * 合并我的与 TA（已平移到我的周次坐标）的课程全集：
     * - 我的课程：命中首个同行程 TA 课 → together 色，否则 mine 色；
     * - TA 课程：被同行程消费的丢弃（与 App 内覆盖层一样不再重复出现），
     *   其余以 partner 色追加；
     * - 天/周次过滤与排序仍由调用方（快照组装核心）统一处理。
     */
    fun mergeCoupleCourses(
        mine: List<WidgetSourceCourse>,
        partnerShifted: List<WidgetSourceCourse>,
        colors: CoupleColors = CoupleColors(),
    ): List<WidgetSourceCourse> {
        val usedPartnerIds = mutableSetOf<String>()
        val merged = mutableListOf<WidgetSourceCourse>()
        for (course in mine) {
            val togetherPartner = partnerShifted.firstOrNull { candidate ->
                isTogetherClass(course, candidate)
            }
            if (togetherPartner != null) {
                usedPartnerIds += togetherPartner.id
            }
            merged += course.copy(
                color = if (togetherPartner != null) colors.together else colors.mine,
            )
        }
        for (course in partnerShifted) {
            if (course.id in usedPartnerIds) continue
            merged += course.copy(color = colors.partner)
        }
        return merged
    }
}