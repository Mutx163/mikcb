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
     * - 同行程配对只在「双方在 [myWeek] 周都有效」的课程之间发生（与 Dart
     *   isTogetherClass 的周要求一致）：周窗口不重叠时我的课不会被
     *   误染成「一起」，我的停课周也不会把 TA 的同程课吞掉；
     * - 我的课程：命中（本周可配对的）TA 课 → together 色；本周有效但未命中
     *   → mine 色；不在本周有效的课保留原色（本周不显示，渲染层按周过滤）；
     * - TA 课程：被（本周配对）同行程消费的丢弃（与 App 内覆盖层一致），
     *   其余以 partner 色追加；
     * - 天/周次显示过滤仍由渲染层统一处理，这里始终返回完整列表（不丢任何
     *   一方课程），跨周边界也能正确渲染。
     */
    fun mergeCoupleCourses(
        mine: List<WidgetSourceCourse>,
        partnerShifted: List<WidgetSourceCourse>,
        colors: CoupleColors = CoupleColors(),
        myWeek: Int? = null,
    ): List<WidgetSourceCourse> {
        // 配对时的有效性：双方在 myWeek 各自周内有效（isInWeek 排除停课，
        // 与 Dart isActiveInWeek 语义一致）。
        val mineActive = if (myWeek != null) mine.filter { it.isInWeek(myWeek) } else mine
        val partnerActive =
            if (myWeek != null) partnerShifted.filter { it.isInWeek(myWeek) } else partnerShifted
        val usedPartnerIds = mutableSetOf<String>()
        val togetherMineIds = mutableSetOf<String>()
        // 第一步：在双方本周有效的子集内配对，得出消费集合。
        for (course in mineActive) {
            val togetherPartner = partnerActive.firstOrNull { candidate ->
                isTogetherClass(course, candidate)
            }
            if (togetherPartner != null) {
                usedPartnerIds += togetherPartner.id
                togetherMineIds += course.id
            }
        }
        // 第二步：渲染完整列表——本周有效的我的课着 mine/together 色，
        // 本周无效的课保留原色（本周不显示，避免误着色）。
        val merged = mutableListOf<WidgetSourceCourse>()
        for (course in mine) {
            val color = when {
                course.id in togetherMineIds -> colors.together
                myWeek == null || course.isInWeek(myWeek) -> colors.mine
                else -> course.color
            }
            merged += course.copy(color = color)
        }
        for (course in partnerShifted) {
            if (course.id in usedPartnerIds) continue
            merged += course.copy(color = colors.partner)
        }
        return merged
    }
}