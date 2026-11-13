package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课卡副信息行「不许再被省略号截断」的约定（2026-11-12，真机反馈教室号与降水概率看不全）。
 *
 * 两处约定都不写成守卫，就会在三个月后被一次重构静默改回单行：
 * 1. 周卡（`CourseGridCard`）单列只有 40–50dp：教室行 `span >= 2` 时给 2 行，字号再降 1sp；
 * 2. 日卡（`DayViewCourseCard`）地点与天气行传 `maxLines = 2`（`DayAgendaInfoRow` 默认仍是 1）。
 */
class CardTextTruncationGuardTest {

    @Test
    fun `周卡教室行 span 2 以上允许两行且字号更小`() {
        val source = readKotlinSourceNormalized(WEEK_CARD)
        assertSourceContains(source, "val locationMaxLines = if (span >= 2) 2 else 1", WEEK_CARD)
        assertSourceContains(source, "maxLines = locationMaxLines,", WEEK_CARD)
        assertSourceContains(
            source,
            "val locationFontSize = (detailFontSize - 1f).coerceAtLeast(7f)",
            WEEK_CARD,
        )
    }

    @Test
    fun `日卡地点与天气行各有一处 maxLines 2`() {
        val common = readKotlinSourceNormalized(DAY_COMMON)
        assertSourceContains(common, "maxLines: Int = 1,", DAY_COMMON)
        assertSourceContains(common, "maxLines = maxLines,", DAY_COMMON)

        val card = readKotlinSourceNormalized(DAY_CARD)
        // 锚到具体那一行调用，别只数 `maxLines = 2,` 的出现次数——
        // 课程名那一行本来就是 maxLines = 2，数次数会把「注释掉天气行」放过去（本守卫第一版就是这么漏的）。
        // 窗口按实测 636 字符留余量（textModifier 里那段 flightAnchor 很长）。
        assertTrue(
            "日卡地点行必须传 maxLines = 2",
            Regex("(?s)text = locationLabel,.{0,900}?maxLines = 2,").containsMatchIn(card),
        )
        assertTrue(
            "日卡天气行必须传 maxLines = 2",
            Regex("(?s)text = weatherText\\.orEmpty\\(\\),.{0,900}?maxLines = 2,").containsMatchIn(card),
        )
    }

    private companion object {
        const val WEEK_CARD =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/CourseGridCard.kt"
        const val DAY_COMMON =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewCommon.kt"
        const val DAY_CARD =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewCourseCard.kt"
    }
}
