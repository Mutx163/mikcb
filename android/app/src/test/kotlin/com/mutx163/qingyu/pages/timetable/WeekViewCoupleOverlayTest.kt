package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.widgetdata.CoupleOverlay
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 周视图「情侣叠加」排版单测（`WeekGridCourseMapping.cardsForWeekWithCoupleOverlay`，B1 第二阶段）。
 *
 * 钉的口径：
 * - 对方课按周偏移映射到我的周次后追加，`isPartnerCourse=true`（渲染层据此画「TA的课」角标）；
 * - **情侣三色优先于统一卡片颜色**（Chief 2026-11-06 拍板）；
 * - 同行程（同天、节次重叠、同名）按我的那份去重，我的那张改着「一起上课」色；
 * - 对方课周有效性过滤：只在「周偏移映射后的那一周」有效的才出现。
 */
class WeekViewCoupleOverlayTest {

    private fun course(
        id: String,
        name: String = "课程 $id",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        startTime: String = "08:00",
        color: String = "#111111",
    ): Course = Course(
        id = id,
        name = name,
        teacher = "任课教师",
        location = "教学楼 101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = "09:35",
        color = color,
        startWeek = startWeek,
        endWeek = endWeek,
    )

    private fun overlay(
        partnerCourses: List<Course>,
        weekOffset: Int = 0,
    ): CoupleOverlay = CoupleOverlay(
        weekOffset = weekOffset,
        mineColorHex = "#2196F3",
        partnerColorHex = "#E91E63",
        togetherColorHex = "#9C27B0",
        partnerCourses = partnerCourses,
    )

    @Test
    fun `对方的课按周映射追加并打 TA 标记`() {
        val mine = course("m1", name = "高数", dayOfWeek = 1, startSection = 1, endSection = 2)
        val partner = course("p1", name = "英语", dayOfWeek = 1, startSection = 3, endSection = 4)
        val cards = WeekGridCourseMapping.cardsForWeekWithCoupleOverlay(
            courses = listOf(mine),
            week = 1,
            style = WeekViewStyle(),
            overlay = overlay(listOf(partner)),
        )
        val day1 = cards.getValue(1)
        assertEquals("我的 + 对方一共两张", 2, day1.size)
        val partnerCard = day1.single { it.course.id == "p1" }
        assertTrue("对方的课必须带 TA 标记", partnerCard.isPartnerCourse)
        assertEquals("对方课着 TA 色", "#E91E63", partnerCard.colorHex)
        val mineCard = day1.single { it.course.id == "m1" }
        assertFalse("我的课不带 TA 标记", mineCard.isPartnerCourse)
        assertEquals("我的课着我的色", "#2196F3", mineCard.colorHex)
    }

    @Test
    fun `情侣三色优先于统一卡片颜色`() {
        val mine = course("m1", name = "高数", dayOfWeek = 1, startSection = 1, endSection = 2)
        val partner = course("p1", name = "英语", dayOfWeek = 1, startSection = 3, endSection = 4)
        val cards = WeekGridCourseMapping.cardsForWeekWithCoupleOverlay(
            courses = listOf(mine),
            week = 1,
            style = WeekViewStyle(unifiedCardColorHex = "#123456"),
            overlay = overlay(listOf(partner)),
        )
        val day1 = cards.getValue(1)
        assertEquals(
            "开了叠加时我的课不能走统一色",
            "#2196F3",
            day1.single { it.course.id == "m1" }.colorHex,
        )
        assertEquals(
            "开了叠加时对方课不能走统一色",
            "#E91E63",
            day1.single { it.course.id == "p1" }.colorHex,
        )
    }

    @Test
    fun `同行程按我的去重并着一起上课色`() {
        val mine = course("m1", name = "高数", dayOfWeek = 2, startSection = 1, endSection = 2)
        val partner = course("p1", name = "高数", dayOfWeek = 2, startSection = 1, endSection = 2)
        val cards = WeekGridCourseMapping.cardsForWeekWithCoupleOverlay(
            courses = listOf(mine),
            week = 1,
            style = WeekViewStyle(),
            overlay = overlay(listOf(partner)),
        )
        val day2 = cards.getValue(2)
        assertEquals("同行程只留一张", 1, day2.size)
        val card = day2.single()
        assertFalse("留下的应该是我自己那张（不带 TA 标记）", card.isPartnerCourse)
        assertEquals("一起上课着一起色", "#9C27B0", card.colorHex)
    }

    @Test
    fun `对方课只在其映射周有效时出现`() {
        val partner = course("p1", name = "英语", dayOfWeek = 1, startSection = 1, endSection = 2, startWeek = 5, endWeek = 5)
        // 偏移 0、看第 3 周：对方第 5 周的课不该出现。
        val week3 = WeekGridCourseMapping.cardsForWeekWithCoupleOverlay(
            courses = emptyList(),
            week = 3,
            style = WeekViewStyle(),
            overlay = overlay(listOf(partner), weekOffset = 0),
        )
        assertTrue("第 3 周不该看到对方第 5 周的课", week3.getValue(1).isEmpty())

        // 偏移 +2、看第 3 周 ⇒ 对方第 5 周：应出现。
        val shifted = WeekGridCourseMapping.cardsForWeekWithCoupleOverlay(
            courses = emptyList(),
            week = 3,
            style = WeekViewStyle(),
            overlay = overlay(listOf(partner), weekOffset = 2),
        )
        assertTrue(
            "周偏移把第 5 周映射到我的第 3 周后应出现",
            shifted.getValue(1).any { it.course.id == "p1" && it.isPartnerCourse },
        )
    }
}
