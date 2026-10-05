package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 迷你列表卡「还剩 N 门」的基数（第 28 轮审查）。
 *
 * `TodayMiniListWidgetProvider.kt:132` 的旧写法是
 * `snapshot.visibleTodayCourses.size - rows.size`：`rows` 出自**按
 * [TodayWidgetSupport.miniListShouldListCourse] 过滤后**的列表（已下课被剔掉），
 * 而 `visibleTodayCourses` 在 `widgetHideCompletedCourses = false`（默认，
 * TodayWidgetSupport.kt:329）时就是全天课表。于是 5 节里 3 节已经上完、maxRows=2 时
 * 卡片显示「+3 门」，点进去其实一门都不剩。
 *
 * `WidgetMiniListTimeFilterTest` 钉住了行的过滤，但没钉计数 ——
 * :856-863 的注释当年恰恰把这种数字不一致当成旧 bug 的证据。
 */
class WidgetMiniListRemainingCountTest {
    private fun course(id: String, endTime: String) = TodayWidgetCourseInfo(
        id = id,
        name = "课程$id",
        shortName = null,
        location = "A101",
        startTime = "08:00",
        endTime = endTime,
    )

    @Test
    fun finishedCoursesDoNotInflateRemainingCount() {
        val day = listOf(
            course("c1", "09:00"),
            course("c2", "10:00"),
            course("c3", "11:00"),
            course("c4", "15:00"),
            course("c5", "17:00"),
        )
        // 12:30：前三节已经上完，只剩 c4、c5。
        val layout = TodayWidgetSupport.miniListLayout(
            courses = day,
            highlighted = null,
            nowMinutes = 12 * 60 + 30,
            maxRows = 2,
        )

        assertEquals(2, layout.first.size)
        assertEquals(
            "只剩 2 节、两行都排下 → 不该显示 +N",
            0,
            layout.second,
        )
    }

    @Test
    fun extraCountIsWhatIsLeftBeyondTheVisibleRows() {
        val day = listOf(
            course("c1", "14:00"),
            course("c2", "15:00"),
            course("c3", "16:00"),
            course("c4", "17:00"),
        )
        val layout = TodayWidgetSupport.miniListLayout(
            courses = day,
            highlighted = null,
            nowMinutes = 8 * 60,
            maxRows = 2,
        )

        assertEquals(listOf("c1", "c2"), layout.first.map { it.id })
        assertEquals(2, layout.second)
    }

    @Test
    fun highlightedCourseIsCountedOnceAndStaysFirst() {
        val day = listOf(course("c1", "14:00"), course("c2", "15:00"))
        val layout = TodayWidgetSupport.miniListLayout(
            courses = day,
            highlighted = course("c2", "15:00"),
            nowMinutes = 8 * 60,
            maxRows = 1,
        )

        assertEquals(listOf("c2"), layout.first.map { it.id })
        // ordered = [c2, c1]（c2 不因出现在全天列表里被数两遍），maxRows=1 → 还差 1 门
        assertEquals(1, layout.second)
    }

    @Test
    fun unparsableEndTimeKeepsTheCourseLikeTheRowFilterDoes() {
        val layout = TodayWidgetSupport.miniListLayout(
            courses = listOf(course("c1", "unknown")),
            highlighted = null,
            nowMinutes = 20 * 60,
            maxRows = 2,
        )

        assertEquals(1, layout.first.size)
        assertEquals(0, layout.second)
    }
}
