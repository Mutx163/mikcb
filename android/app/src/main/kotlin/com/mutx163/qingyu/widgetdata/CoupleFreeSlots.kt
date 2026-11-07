package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course

/**
 * 情侣「共同空档」纯模型（B1 第二阶段，2026-11-06）。
 *
 * 给的是**纯函数**：某一天里，我和 TA 两边都没课的连续节次段。没有任何 UI / 落盘副作用，
 * 未来「共同空档」的展示（周视图提示 / 设置页）直接消费这里的结果。
 *
 * 口径：
 * - 我方课按**我的周次**（[week]）过滤有效周；对方课按「周偏移映射后的那一周」
 *   （[CoupleTimetableData.partnerWeekForMyWeek]）过滤——与合并内核同一套周次坐标；
 * - 一门课占用 `startSection..endSection`（含首尾，中间不断开）；
 * - 空档 = `1..sectionCount` 里没被任一方占用的节次，按**连续段**合并；
 * - 不看「非本周课程」开关：空档只按当周真实上课情况算（停了课就是空）。
 */
object CoupleFreeSlots {

    /**
     * 整周每天的共同空档：`Map<dayOfWeek 1..7, List<IntRange>>`。
     *
     * [sectionCount] <= 0（节次表没配好）时返回空表——不伪造「全天空」。
     */
    fun commonFreeRanges(
        myCourses: List<Course>,
        partnerCourses: List<Course>,
        week: Int,
        partnerWeekOffset: Int,
        sectionCount: Int,
        visibleDays: List<Int> = (1..7).toList(),
    ): Map<Int, List<IntRange>> {
        if (sectionCount <= 0) return emptyMap()
        val partnerWeek = CoupleTimetableData.partnerWeekForMyWeek(week, partnerWeekOffset)
        return visibleDays.associateWith { day ->
            val mineOccupied = myCourses
                .filter { it.dayOfWeek == day && it.isActiveInWeek(week) }
                .flatMap { it.startSection..it.endSection }
            val partnerOccupied = partnerCourses
                .filter { it.dayOfWeek == day && it.isActiveInWeek(partnerWeek) }
                .flatMap { it.startSection..it.endSection }
            freeRangesFromOccupied((mineOccupied + partnerOccupied).toSet(), sectionCount)
        }
    }

    /** 单天：给定被占用节次集合，算出 `1..sectionCount` 里的连续空档段。 */
    fun freeRangesFromOccupied(occupied: Set<Int>, sectionCount: Int): List<IntRange> {
        if (sectionCount <= 0) return emptyList()
        val ranges = mutableListOf<IntRange>()
        var start: Int? = null
        for (section in 1..sectionCount) {
            val free = section !in occupied
            if (free && start == null) start = section
            if (start != null && (!free || section == sectionCount)) {
                val end = if (free) section else section - 1
                ranges.add(start..end)
                start = null
            }
        }
        return ranges
    }
}
