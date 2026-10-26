package com.mutx163.qingyu.widgetdata

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 情侣合并 / 伴侣绑定纯逻辑的端口测试（移植 couple_timetable_logic.dart 的
 * 消费子集与 PartnerTimetableBinding.fromJson 解析口径）。
 *
 * 期望值来源：Dart 侧注释规则推演（[Dart推演]）+ TodayWidgetSupport.kt /
 * WidgetCoupleMergeLogic.kt 真机实现同口径（[Kotlin抄录]）。
 */
class CoupleMergeAndBindingTest {

    @Test
    fun bindingClampsWeekOffsetAndFallsBackColors() { // [Kotlin抄录] WidgetCoupleMergeLogic 同款
        val binding = PartnerTimetableBinding.fromJson(
            mapOf(
                "partnerProfileId" to "partner-imported",
                "weekOffset" to 99,
                "mineColorHex" to "#111111",
            ),
        )
        assertEquals(15, binding.weekOffset) // clampWeekOffset(99) = 15
        assertEquals("#111111", binding.mineColorHex)
        assertEquals("#E91E63", binding.partnerColorHex) // 缺省回落
        assertEquals("#9C27B0", binding.togetherColorHex)
        assertEquals("partner-imported", binding.partnerProfileId)
        assertEquals("TA的课表", binding.partnerName) // 缺省名
    }

    @Test
    fun bindingParsesNegativeOffset() { // [Dart推演]
        val binding = PartnerTimetableBinding.fromJson(mapOf("weekOffset" to -20))
        assertEquals(-15, binding.weekOffset)
    }

    @Test
    fun bindingToleratesNonNumericOffset() { // [Dart推演] (as num?)? 失败 → 0
        val binding = PartnerTimetableBinding.fromJson(mapOf("weekOffset" to "abc"))
        assertEquals(0, binding.weekOffset)
    }

    @Test
    fun partnerWeekMappingShiftsByOffset() { // [Dart抄录] partnerWeekForMyWeek
        assertEquals(3, CoupleTimetableData.partnerWeekForMyWeek(1, 2))
        assertEquals(0, CoupleTimetableData.partnerWeekForMyWeek(1, -1))
        assertEquals(-14, CoupleTimetableData.partnerWeekForMyWeek(1, -15))
    }

    @Test
    fun togetherClassRequiresSameDayOverlapAndName() { // [Dart抄录] isTogetherClass
        fun c(id: String, day: Int, s: Int, e: Int, name: String) = mapOf(
            "id" to id, "name" to name, "teacher" to "", "location" to "",
            "dayOfWeek" to day, "startSection" to s, "endSection" to e,
            "startTime" to "08:00", "endTime" to "09:40",
        )
        val mine = com.mutx163.qingyu.core.Course.fromJson(c("m", 1, 1, 2, "英语"))
        val partner = com.mutx163.qingyu.core.Course.fromJson(c("p", 1, 2, 3, "  英语 "))
        // 同天、节次重叠（1-2 与 2-3 重叠在节 2）、同名忽略首尾空白
        assertTrue(CoupleTimetableData.isTogetherClass(mine, partner, week = 1, partnerWeekOffset = 0))
        // 不同天
        val otherDay = com.mutx163.qingyu.core.Course.fromJson(c("p2", 2, 1, 2, "英语"))
        assertFalse(CoupleTimetableData.isTogetherClass(mine, otherDay, week = 1, partnerWeekOffset = 0))
        // 不同名
        val diffName = com.mutx163.qingyu.core.Course.fromJson(c("p3", 1, 1, 2, "数学"))
        assertFalse(CoupleTimetableData.isTogetherClass(mine, diffName, week = 1, partnerWeekOffset = 0))
    }

    @Test
    fun colorHexForKindFallsBackToDefaults() { // [Dart抄录] 三色默认值
        assertEquals("#2196F3", CoupleTimetableData.colorHexForKind(CoupleCourseKind.MINE, null, null, null))
        assertEquals("#E91E63", CoupleTimetableData.colorHexForKind(CoupleCourseKind.PARTNER, null, null, null))
        assertEquals("#9C27B0", CoupleTimetableData.colorHexForKind(CoupleCourseKind.TOGETHER, null, null, null))
        assertEquals("#AA", CoupleTimetableData.colorHexForKind(CoupleCourseKind.MINE, "#AA", null, null))
    }
}
