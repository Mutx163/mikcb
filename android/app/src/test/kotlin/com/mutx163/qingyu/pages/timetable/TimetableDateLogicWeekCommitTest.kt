package com.mutx163.qingyu.pages.timetable

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 跨日写回「当前周」的学期末夹取（[TimetableDateLogic.weekToCommitOnDayChange] + clamp）。
 *
 * 接线点：`composeP1/…/TimetableHost.kt` 的分钟心跳跨日分支传入
 * `TimetableRepository::clampWeekToSettings`（只算不写），夹取发生在与快照
 * `currentWeek` 的比对**之前**。
 *
 * 锚点：开学日 2026-09-01（周二）⇒ 归一化周一 2026-08-31；
 * 第 21 周从 2027-01-18（周一）起。学期周数取 18。
 */
class TimetableDateLogicWeekCommitTest {

    private val semesterStart = LocalDate.of(2026, 9, 1)
    private val totalWeeks = 18

    /** 与 `TimetableRepository.clampWeekToSettings` 同口径（开学日/周数有效性已由调用方保证）。 */
    private val clampToSemester: (Int) -> Int = { it.coerceIn(1, totalWeeks) }

    private fun commit(today: LocalDate, currentWeek: Int): Int? =
        TimetableDateLogic.weekToCommitOnDayChange(
            semesterStart = semesterStart,
            totalWeeks = totalWeeks,
            today = today,
            currentWeek = currentWeek,
            clamp = clampToSemester,
        )

    @Test
    fun `学期内同周不写`() {
        // 2026-10-28 = 第 9 周周三。
        assertNull(commit(LocalDate.of(2026, 10, 28), 9))
    }

    @Test
    fun `学期内跨周写出真实周次`() {
        assertEquals(9, commit(LocalDate.of(2026, 10, 28), 8))
    }

    @Test
    fun `学期结束第21周夹到18才写`() {
        assertEquals(18, commit(LocalDate.of(2027, 1, 20), 17))
    }

    @Test
    fun `夹取后再比对_快照已是21仍写18`() {
        // 关键顺序断言：raw 21 == currentWeek 21，若不先夹会判「无需写」而停在 21。
        assertEquals(18, commit(LocalDate.of(2027, 1, 20), 21))
    }

    @Test
    fun `夹到18后幂等`() {
        assertNull(commit(LocalDate.of(2027, 1, 20), 18))
    }

    @Test
    fun `无开学日不写`() {
        assertNull(
            TimetableDateLogic.weekToCommitOnDayChange(
                semesterStart = null,
                totalWeeks = totalWeeks,
                today = LocalDate.of(2027, 1, 20),
                currentWeek = 17,
                clamp = clampToSemester,
            ),
        )
    }

    @Test
    fun `学期周数坏值不写`() {
        assertNull(
            TimetableDateLogic.weekToCommitOnDayChange(
                semesterStart = semesterStart,
                totalWeeks = 0,
                today = LocalDate.of(2026, 9, 16),
                currentWeek = 2,
                clamp = clampToSemester,
            ),
        )
    }

    @Test
    fun `开学前不写`() {
        // 2026-08-24 = 归一化周一（08-31）前 7 天 ⇒ 日历周 0。
        assertNull(commit(LocalDate.of(2026, 8, 24), 1))
    }
}
