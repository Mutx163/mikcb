package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** 情侣「共同空档」纯模型单测（B1 第二阶段，2026-11-06）。 */
class CoupleFreeSlotsTest {

    private fun course(
        id: String,
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
    ): Course = Course(
        id = id,
        name = "课程 $id",
        teacher = "任课教师",
        location = "教学楼 101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:35",
        startWeek = startWeek,
        endWeek = endWeek,
    )

    @Test
    fun `占用集合换算连续空档`() {
        assertEquals(listOf(1..1, 4..5), CoupleFreeSlots.freeRangesFromOccupied(setOf(2, 3), 5))
    }

    @Test
    fun `全空与全满`() {
        assertEquals(listOf(1..4), CoupleFreeSlots.freeRangesFromOccupied(emptySet(), 4))
        assertEquals(emptyList<IntRange>(), CoupleFreeSlots.freeRangesFromOccupied((1..4).toSet(), 4))
    }

    @Test
    fun `节次数不合法时返回空`() {
        assertEquals(emptyList<IntRange>(), CoupleFreeSlots.freeRangesFromOccupied(emptySet(), 0))
        assertTrue(CoupleFreeSlots.commonFreeRanges(emptyList(), emptyList(), 1, 0, 0).isEmpty())
    }

    @Test
    fun `共同空档要同时扣掉双方占用的节次`() {
        val mine = course("m1", dayOfWeek = 1, startSection = 1, endSection = 2)
        val partner = course("p1", dayOfWeek = 1, startSection = 2, endSection = 3)
        val free = CoupleFreeSlots.commonFreeRanges(
            myCourses = listOf(mine),
            partnerCourses = listOf(partner),
            week = 1,
            partnerWeekOffset = 0,
            sectionCount = 5,
        )
        // 占用 = 1,2,3 ⇒ 空档 4..5
        assertEquals(listOf(4..5), free.getValue(1))
    }

    @Test
    fun `对方课按其映射周过滤`() {
        val partnerWeekFive = course("p1", dayOfWeek = 1, startSection = 1, endSection = 2, startWeek = 5, endWeek = 5)
        // 看第 1 周、偏移 0：对方第 5 周的课不占位 ⇒ 全空。
        val week1 = CoupleFreeSlots.commonFreeRanges(
            myCourses = emptyList(),
            partnerCourses = listOf(partnerWeekFive),
            week = 1,
            partnerWeekOffset = 0,
            sectionCount = 4,
        )
        assertEquals(listOf(1..4), week1.getValue(1))

        // 看第 3 周、偏移 +2 ⇒ 对方第 5 周占住 1..2 ⇒ 空档 3..4。
        val shifted = CoupleFreeSlots.commonFreeRanges(
            myCourses = emptyList(),
            partnerCourses = listOf(partnerWeekFive),
            week = 3,
            partnerWeekOffset = 2,
            sectionCount = 4,
        )
        assertEquals(listOf(3..4), shifted.getValue(1))
    }
}
