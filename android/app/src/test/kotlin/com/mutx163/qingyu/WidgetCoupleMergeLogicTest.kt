package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetCoupleMergeLogicTest {

    private fun course(
        id: String,
        name: String = "高数",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 20,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        color: String = "",
    ) = WidgetSourceCourse(
        id = id,
        name = name,
        shortName = null,
        location = "A101",
        startTime = "08:00",
        endTime = "09:40",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
        color = color,
    )

    @Test
    fun shiftMovesTaWeekWindowIntoMyWeekCoordinates() {
        // TA 第 5 周的课，offset=1 → 对应我的第 4 周。
        val shifted = WidgetCoupleMergeLogic.shiftPartnerCourseToMyWeeks(
            course("p", startWeek = 5, endWeek = 5),
            offset = 1,
        )
        assertTrue(shifted.isInWeek(4))
        assertFalse(shifted.isInWeek(5))

        // offset=0 恒等。
        val original = course("p", startWeek = 3, endWeek = 6)
        assertEquals(
            original,
            WidgetCoupleMergeLogic.shiftPartnerCourseToMyWeeks(original, 0),
        )
    }

    @Test
    fun shiftFlipsWeekParityOnlyForOddOffset() {
        val oddWeekOnly = course("p", isOddWeek = true)

        // offset=1（奇数）：TA 单周课落在我方坐标双周。
        val shiftedByOne = WidgetCoupleMergeLogic.shiftPartnerCourseToMyWeeks(oddWeekOnly, 1)
        assertTrue(shiftedByOne.isEvenWeek)
        assertFalse(shiftedByOne.isOddWeek)

        // offset=2（偶数）：奇偶保持。
        val shiftedByTwo = WidgetCoupleMergeLogic.shiftPartnerCourseToMyWeeks(oddWeekOnly, 2)
        assertTrue(shiftedByTwo.isOddWeek)
        assertFalse(shiftedByTwo.isEvenWeek)
    }

    @Test
    fun shiftMovesCustomAndSuspendedWeeks() {
        val shifted = WidgetCoupleMergeLogic.shiftPartnerCourseToMyWeeks(
            course("p", customWeeks = listOf(2, 5), suspendedWeeks = listOf(4)),
            offset = 1,
        )
        assertEquals(listOf(1, 4), shifted.customWeeks)
        assertEquals(listOf(3), shifted.suspendedWeeks)
    }

    @Test
    fun clampWeekOffsetMatchesDartBounds() {
        assertEquals(-15, WidgetCoupleMergeLogic.clampWeekOffset(-20))
        assertEquals(15, WidgetCoupleMergeLogic.clampWeekOffset(20))
        assertEquals(3, WidgetCoupleMergeLogic.clampWeekOffset(3))
    }

    @Test
    fun togetherClassRequiresSameDayOverlapAndName() {
        val mine = course("a", name = "高数", dayOfWeek = 1, startSection = 1, endSection = 2)
        assertTrue(
            WidgetCoupleMergeLogic.isTogetherClass(
                mine,
                course("p", name = "高数", dayOfWeek = 1, startSection = 1, endSection = 2),
            ),
        )
        // 同名同节次但不同天 → 非同行程。
        assertFalse(
            WidgetCoupleMergeLogic.isTogetherClass(
                mine,
                course("p", name = "高数", dayOfWeek = 2),
            ),
        )
        // 同天同节次但不同名 → 非同行程（各自保留、按 TA 色追加）。
        assertFalse(
            WidgetCoupleMergeLogic.isTogetherClass(
                mine,
                course("p", name = "线代", dayOfWeek = 1),
            ),
        )
        // 同名同天但节次不重叠 → 非同行程。
        assertFalse(
            WidgetCoupleMergeLogic.isTogetherClass(
                mine,
                course("p", name = "高数", dayOfWeek = 1, startSection = 3, endSection = 4),
            ),
        )
        // 名称忽略大小写与首尾空白。
        assertTrue(
            WidgetCoupleMergeLogic.isTogetherClass(
                course("a", name = " English "),
                course("p", name = "english", dayOfWeek = 1),
            ),
        )
    }

    @Test
    fun mergeColorsMinePartnerAndTogether() {
        val colors = WidgetCoupleMergeLogic.CoupleColors(
            mine = "#0000FF",
            partner = "#FF0000",
            together = "#FF00FF",
        )
        val mine = listOf(
            course("a", name = "高数", color = "#111111"),
            course("b", name = "体育", dayOfWeek = 2, startSection = 3, endSection = 4, color = "#222222"),
        )
        val partnerShifted = listOf(
            // 与我的高数同行程 → 一起课，TA 份丢弃。
            course("p1", name = "高数", color = "#333333"),
            // 与我的体育同名但不同天 → 不去重，追加为 TA 课。
            course("p2", name = "体育", dayOfWeek = 2, startSection = 1, endSection = 2),
        )

        val merged = WidgetCoupleMergeLogic.mergeCoupleCourses(mine, partnerShifted, colors)

        assertEquals(3, merged.size)
        // 我的课：同行程命中 → together 色（覆盖原课程色）。
        assertEquals("#FF00FF", merged.first { it.id == "a" }.color)
        // 我的课未命中 → 我方色。
        assertEquals("#0000FF", merged.first { it.id == "b" }.color)
        // 未消费的 TA 课 → partner 色；被消费的 p1 丢弃。
        assertEquals("#FF0000", merged.first { it.id == "p2" }.color)
        assertTrue(merged.none { it.id == "p1" })
    }

    @Test
    fun mergeMatchesTogetherCaseInsensitivelyAndKeepsMineOnce() {
        val mine = listOf(course("a", name = "English"))
        val partnerShifted = listOf(
            course("p1", name = "english"),
            course("p2", name = "english", startSection = 3, endSection = 4),
        )
        val merged = WidgetCoupleMergeLogic.mergeCoupleCourses(mine, partnerShifted)
        // 我的 ENGLISH 命中 p1（首个同名同行程）→ together 色；p2 节次不重叠，
        // 追加为 TA 课。
        assertEquals(WidgetCoupleMergeLogic.TOGETHER_COLOR_DEFAULT, merged.first { it.id == "a" }.color)
        assertEquals(WidgetCoupleMergeLogic.PARTNER_COLOR_DEFAULT, merged.first { it.id == "p2" }.color)
        assertTrue(merged.none { it.id == "p1" })
    }

    @Test
    fun mergeWithMyWeekKeepsCoursesSeparateWhenWeeksDoNotOverlap() {
        // 我的课 1-10 周，TA（已平移）5-15 周，同天同节同名。
        val mine = listOf(course("a", startWeek = 1, endWeek = 10))
        val partnerShifted = listOf(course("p", startWeek = 5, endWeek = 15))
        val colors = WidgetCoupleMergeLogic.CoupleColors(
            mine = "#0000FF",
            partner = "#FF0000",
            together = "#FF00FF",
        )

        // 第 3 周：我的课有效、TA 课不在该周 → 不配对，我的课保持我方色，
        // TA 课也保留（供 TA 独有的周次显示）。
        val mergedWeek3 = WidgetCoupleMergeLogic.mergeCoupleCourses(
            mine, partnerShifted, colors, myWeek = 3,
        )
        assertEquals("#0000FF", mergedWeek3.first { it.id == "a" }.color)
        assertEquals("#FF0000", mergedWeek3.first { it.id == "p" }.color)

        // 第 6 周：双方均有效 → 配对，我的课着一起色，TA 课被消费。
        val mergedWeek6 = WidgetCoupleMergeLogic.mergeCoupleCourses(
            mine, partnerShifted, colors, myWeek = 6,
        )
        assertEquals("#FF00FF", mergedWeek6.first { it.id == "a" }.color)
        assertTrue(mergedWeek6.none { it.id == "p" })

        // 第 12 周：我的课已结课、TA 课独有 → 双方都不参与，我的课（不在
        // 周内但列表保留）保留原色（渲染层按周过滤后不会显示它），TA 课保留
        // 以 partner 色供 TA 独有周次显示。
        val mergedWeek12 = WidgetCoupleMergeLogic.mergeCoupleCourses(
            mine, partnerShifted, colors, myWeek = 12,
        )
        assertEquals("", mergedWeek12.first { it.id == "a" }.color)
        assertEquals("#FF0000", mergedWeek12.first { it.id == "p" }.color)
    }

    @Test
    fun mergeDoesNotConsumePartnerWhenMyCourseSuspendedThatWeek() {
        // 我的课第 3 周停课，TA 同课不停。
        val mine = listOf(course("h", suspendedWeeks = listOf(3)))
        val partnerShifted = listOf(course("p"))
        val colors = WidgetCoupleMergeLogic.CoupleColors(
            mine = "#0000FF",
            partner = "#FF0000",
            together = "#FF00FF",
        )

        // 第 3 周：我的课停课 → 不参与配对，TA 课必须保留（粉色显示）。
        val week3 = WidgetCoupleMergeLogic.mergeCoupleCourses(
            mine, partnerShifted, colors, myWeek = 3,
        )
        assertEquals("#FF0000", week3.first { it.id == "p" }.color)
        assertTrue(week3.first { it.id == "p" }.isInWeek(3))

        // 第 4 周：我的课恢复 → 正常配对成一起课。
        val week4 = WidgetCoupleMergeLogic.mergeCoupleCourses(
            mine, partnerShifted, colors, myWeek = 4,
        )
        assertEquals("#FF00FF", week4.first { it.id == "h" }.color)
        assertTrue(week4.none { it.id == "p" })
    }
}