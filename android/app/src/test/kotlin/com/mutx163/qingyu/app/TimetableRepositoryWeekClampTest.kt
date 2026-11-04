package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * `TimetableRepository.clampWeekToSettings`：按日历周把周次夹回学期范围（纯计算）。
 *
 * 对齐 Dart `syncTemporalContext`（`timetable_provider.dart:3259-3302`）里
 * `clampCurrentWeekToSettings`（`:3286`，定义 `timetable_profile.dart:27-38`）那一步。
 */
class TimetableRepositoryWeekClampTest {

    private val semesterStart: LocalDateTime = LocalDateTime.of(2026, 8, 31, 0, 0)

    @Test
    fun `学期内原样返回`() {
        assertEquals(5, repo().clampWeekToSettings(5))
    }

    @Test
    fun `第 0 周夹到第 1 周`() {
        // 开学前的日历周是 0（WeekCalculator.calendarWeekForDate），展示口径落第 1 周。
        assertEquals(1, repo().clampWeekToSettings(0))
    }

    @Test
    fun `超出学期周数夹到最后一击`() {
        // 学期结束后日历周会继续增长（如 21），展示口径停在 semesterWeekCount。
        assertEquals(18, repo().clampWeekToSettings(21))
    }

    @Test
    fun `节假日不参与夹取`() {
        val repository = repo()
        // 2026-10-01 是国庆假期，但教学周编号照常（假期只换课，不改周次）。
        val holidayWeek = WeekCalculator.calendarWeekForDate(
            LocalDateTime.of(2026, 10, 1, 0, 0),
            semesterStart,
            1,
        )
        assertEquals("国庆所在仍是第 5 教学周", 5, holidayWeek)
        assertEquals(5, repository.clampWeekToSettings(holidayWeek))
    }

    @Test
    fun `无开学日时原样返回`() {
        val repository = repo("""{"semesterWeekCount":18}""")
        assertEquals(25, repository.clampWeekToSettings(25))
        assertEquals(0, repository.clampWeekToSettings(0))
    }

    @Test
    fun `学期周数非正时不夹`() {
        // 周数缺失/坏值没有上限语义：夹到 1 会把用户当前周强行改成第 1 周。
        val repository = repo()
        repository.updateSettings(
            TimetableSettings(semesterWeekCount = 0, semesterStartDate = semesterStart),
        )
        assertEquals(25, repository.clampWeekToSettings(25))
        assertEquals(0, repository.clampWeekToSettings(0))
    }

    private fun repo(
        settingsJson: String = """{"semesterWeekCount":18,"semesterStartDateText":"2026-08-31"}""",
    ): TimetableRepository {
        val initial = LinkedHashMap<String, String>()
        initial[TimetableStore.KEY_SETTINGS] = settingsJson
        return TimetableRepository(TimetableStore(InMemoryKeyValueStore(initial)))
    }
}
