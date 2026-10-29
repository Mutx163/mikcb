package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * `SemesterSettingsLogic` 的 JVM 单测：钉住 Dart `_SemesterSettingsScreen` 里那几条
 * **容易漏掉的分支**（改日期后自动同步、周数改小回拨、开学前算第 1 周、日期区间夹取）。
 *
 * 期望值都是**人按 `week_calculator.dart` 的规则手算**出来的（不是从实现里抄的）：
 *
 * ```
 * semesterStart = 2026-09-01（周二） ⇒ 学期第一周的周一是 2026-08-31
 *   2026-09-01（周二） → 同周          → 第 1 周
 *   2026-09-07（周一） → 差 7 天        → 第 2 周
 *   2026-09-20（周日） → 差 14 天       → 第 3 周
 *   2026-10-29（周四） → 差 56 天       → 第 9 周
 *   2026-08-20（周四） → 早于开学周     → null ⇒ 按第 1 周
 * ```
 */
class SemesterSettingsLogicTest {

    private fun dateTime(text: String): LocalDateTime = LocalDateTime.parse("${text}T00:00")

    // ------------------------------------------------------- 日期弹层初值与区间

    @Test
    fun `没设开学日期时弹层初值是今天`() {
        // Dart :764 `initialDate: provider.settings.semesterStartDate ?? DateTime.now()`
        assertEquals(
            LocalDate.of(2026, 10, 29),
            SemesterSettingsLogic.pickerInitialDate(
                startDate = null,
                today = LocalDate.of(2026, 10, 29),
            ),
        )
    }

    @Test
    fun `已设开学日期时弹层初值就是那天`() {
        assertEquals(
            LocalDate.of(2026, 9, 1),
            SemesterSettingsLogic.pickerInitialDate(
                startDate = LocalDate.of(2026, 9, 1),
                today = LocalDate.of(2026, 10, 29),
            ),
        )
    }

    @Test
    fun `弹层初值越界要夹进 2020 到 2035`() {
        // 存档里完全可能有 2019 / 2036（老版本手改、导入的备份）——
        // Dart 的 showMiuixDatePickerSheet 也先夹再挂日历（miuix_date_picker_sheet.dart:46-57）
        assertEquals(
            LocalDate.of(2020, 1, 1),
            SemesterSettingsLogic.pickerInitialDate(
                startDate = LocalDate.of(2019, 12, 31),
                today = LocalDate.of(2026, 10, 29),
            ),
        )
        assertEquals(
            LocalDate.of(2035, 12, 31),
            SemesterSettingsLogic.pickerInitialDate(
                startDate = LocalDate.of(2036, 1, 1),
                today = LocalDate.of(2026, 10, 29),
            ),
        )
        assertEquals(
            LocalDate.of(2035, 12, 31),
            SemesterSettingsLogic.clampPickerDate(LocalDate.of(2040, 6, 1)),
        )
    }

    // --------------------------------------------------------------- 周数弹层

    @Test
    fun `周数滚轮初值夹在 1 到 30`() {
        // showSemesterWeekCountPickerSheet: minValue = 1 / maxValue = 30
        assertEquals(1, SemesterSettingsLogic.pickerInitialWeekCount(0))
        assertEquals(1, SemesterSettingsLogic.pickerInitialWeekCount(-7))
        assertEquals(20, SemesterSettingsLogic.pickerInitialWeekCount(20))
        assertEquals(30, SemesterSettingsLogic.pickerInitialWeekCount(30))
        assertEquals(30, SemesterSettingsLogic.pickerInitialWeekCount(31))
    }

    @Test
    fun `每月天数按真实日历`() {
        assertEquals(29, SemesterSettingsLogic.daysInMonth(2024, 2))
        assertEquals(28, SemesterSettingsLogic.daysInMonth(2026, 2))
        assertEquals(30, SemesterSettingsLogic.daysInMonth(2026, 4))
        assertEquals(31, SemesterSettingsLogic.daysInMonth(2026, 1))
        assertEquals(31, SemesterSettingsLogic.daysInMonth(2026, 12))
    }

    // ------------------------------------------------------- 同步当前周（核心）

    @Test
    fun `同步当前周按周一对齐的日历周计算`() {
        val start = dateTime("2026-09-01")
        assertEquals(1, SemesterSettingsLogic.weekForNow(dateTime("2026-09-01"), start, 20))
        assertEquals(2, SemesterSettingsLogic.weekForNow(dateTime("2026-09-07"), start, 20))
        assertEquals(3, SemesterSettingsLogic.weekForNow(dateTime("2026-09-20"), start, 20))
        assertEquals(9, SemesterSettingsLogic.weekForNow(dateTime("2026-10-29"), start, 20))
    }

    @Test
    fun `开学前一律算第 1 周而不是 0 或负数`() {
        // timetable_provider.dart:3237-3241：getWeekIndex 返回 null ⇒ week = 0 ⇒ targetWeek = 1
        assertEquals(
            1,
            SemesterSettingsLogic.weekForNow(dateTime("2026-08-20"), dateTime("2026-09-01"), 20),
        )
    }

    @Test
    fun `超过学期周数钳到末周且不扩学期`() {
        // timetable_provider.dart:3244-3248：日历走出末周时**不**自动扩 semesterWeekCount
        assertEquals(
            5,
            SemesterSettingsLogic.weekForNow(dateTime("2026-10-29"), dateTime("2026-09-01"), 5),
        )
        // 学期周数非法（<1）时上限按 1（clampCurrentWeekToSettings 同口径）
        assertEquals(
            1,
            SemesterSettingsLogic.weekForNow(dateTime("2026-10-29"), dateTime("2026-09-01"), 0),
        )
    }

    @Test
    fun `周次钳制口径`() {
        assertEquals(1, SemesterSettingsLogic.clampWeekTo(0, 20))
        assertEquals(1, SemesterSettingsLogic.clampWeekTo(-3, 20))
        assertEquals(20, SemesterSettingsLogic.clampWeekTo(25, 20))
        assertEquals(20, SemesterSettingsLogic.clampWeekTo(20, 20))
        assertEquals(1, SemesterSettingsLogic.clampWeekTo(9, 0))
    }

    // --------------------------------------------------- 周数改小后的当前周回拨

    @Test
    fun `周数改小且当前周超出时才回拨`() {
        // Dart :859-861 `if (provider.currentWeek > selected) await provider.setCurrentWeek(selected)`
        assertEquals(8, SemesterSettingsLogic.weekToFollowAfterWeekCountChange(10, 8))
        assertEquals(1, SemesterSettingsLogic.weekToFollowAfterWeekCountChange(30, 1))
        // 当前周没超 ⇒ 不动
        assertNull(SemesterSettingsLogic.weekToFollowAfterWeekCountChange(5, 8))
        assertNull(SemesterSettingsLogic.weekToFollowAfterWeekCountChange(10, 10))
    }

    // ------------------------------------------------------------- 落盘与 state

    @Test
    fun `开学日期存的是本地零点`() {
        assertEquals(
            LocalDateTime.of(2026, 9, 1, 0, 0),
            SemesterSettingsLogic.startDateTime(LocalDate.of(2026, 9, 1)),
        )
    }

    @Test
    fun `仓储快照转页面输入`() {
        val state = SemesterSettingsLogic.stateOf(
            currentWeek = 9,
            semesterWeekCount = 20,
            startDate = LocalDate.of(2026, 9, 1),
        )
        assertEquals(9, state.currentWeek)
        assertEquals(20, state.semesterWeekCount)
        assertEquals(Triple(2026, 9, 1), state.semesterStartDate)

        val unset = SemesterSettingsLogic.stateOf(
            currentWeek = 1,
            semesterWeekCount = 20,
            startDate = null,
        )
        assertNull(unset.semesterStartDate)
    }

    @Test
    fun `三行的行 id 与渲染层分派约定逐字一致`() {
        // 宿主按 rowId 认动作（SettingsSemesterHost 的 when 分支）；
        // 这三条同时被页面 spec 的测试钉住，改一处必须两边一起改。
        assertEquals("timetable.semester.startDate", SemesterSettingsLogic.ROW_START_DATE)
        assertEquals("timetable.semester.weekCount", SemesterSettingsLogic.ROW_WEEK_COUNT)
        assertEquals("timetable.semester.syncWeek", SemesterSettingsLogic.ROW_SYNC_WEEK)
    }
}
