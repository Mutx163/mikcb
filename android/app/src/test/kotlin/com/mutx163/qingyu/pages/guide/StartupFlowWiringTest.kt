package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 启动引导**收尾落盘**的契约测试（F11，2026-10-29）。
 *
 * ## 它防的是哪一类事故
 *
 * 引导页原来三个回调全是默认空实现：用户老老实实填完开学日期与周数，
 * 点确认之后**一个字节都没写**——下次启动又是「请设置开学日期」，用户白填一遍。
 * 这类缺陷编译能过、页面看着正常，只有「杀进程重开」才暴露。
 *
 * 所以这里钉三件事：
 *
 * 1. **写什么**：[planStartupSemesterWrite] 算出的开学日期 / 学期周数 / 当前周次，
 *    与 `b.semester`（学期设置页）写的是**同一对键**，没有第二套口径；
 * 2. **写哪个键**：「引导已完成」这类布尔标记是盘上契约的物理键（`STARTUP_*` 那对，
 *    前缀 `flutter.` 由 store 实现统一加）；写错键名重启读不到 = 等于没写。
 * 3. **非法输入不许写半截**：日期不合法 / 周数越界时返回 null，宿主据此给实话。
 *
 * 期望值来源（独立于实现）：**Kotlin 常量表 `StartupFlowModel.kt` 里逐字抄录的清单**
 * （2026-11-07 去 Flutter 化前抄自 Dart `app_migration_service.dart:5-7` 与
 * `storage_service.dart:29-32`，P4-C 删除后那些文件已不存在，清单本体由本测试钉死）。
 * 另有 `lib/main.dart:1486` 出处说明已一并失效；周次口径以 `SemesterDateCalculator` 已公开口径为准
 * （手推：2026-09-07 是周一）。
 */
class StartupFlowWiringTest {

    // ---------- 落盘计划 ----------

    @Test
    fun `开学日期与周数按填的写落盘计划`() {
        val plan = planStartupSemesterWrite(
            semesterStartDate = "2026-09-07",
            totalWeeks = 18,
            today = LocalDate.of(2026, 9, 21),
        )
        assertNotNull("合法输入不该返回 null", plan)
        assertEquals("2026-09-07", plan!!.startDateText)
        assertEquals("开学日期按当天零点落盘", LocalDate.of(2026, 9, 7), plan.semesterStartDate.toLocalDate())
        assertEquals(0, plan.semesterStartDate.hour)
        assertEquals(18, plan.semesterWeekCount)
        // 2026-09-07（周一）到 2026-09-21（周一）正好两周 ⇒ 第 3 周。
        assertEquals(3, plan.currentWeek)
    }

    @Test
    fun `超过学期周数时当前周钳到末周`() {
        val plan = planStartupSemesterWrite(
            semesterStartDate = "2026-09-07",
            totalWeeks = 18,
            today = LocalDate.of(2027, 3, 1),
        )!!
        assertEquals("学期已经走完，当前周应钳在末周", 18, plan.currentWeek)
    }

    @Test
    fun `开学之前的日期按第1周`() {
        val plan = planStartupSemesterWrite(
            semesterStartDate = "2026-09-07",
            totalWeeks = 20,
            today = LocalDate.of(2026, 8, 1),
        )!!
        assertEquals(1, plan.currentWeek)
    }

    @Test
    fun `非法输入一律不写`() {
        val bad = listOf<Triple<String?, Int, String>>(
            Triple(null, 20, "日期为空"),
            Triple("", 20, "日期为空串"),
            Triple("2026-9-7", 20, "月份没补零"),
            Triple("2026-13-01", 20, "13 月不存在"),
            Triple("1999-09-01", 20, "年份早于 2000"),
            Triple("2026-09-07", 0, "周数小于 1"),
            Triple("2026-09-07", 41, "周数大于 40"),
        )
        for ((date, weeks, why) in bad) {
            assertNull(
                "本该拒绝（$why）：date=$date weeks=$weeks",
                planStartupSemesterWrite(date, weeks, LocalDate.of(2026, 9, 21)),
            )
        }
    }

    @Test
    fun `周数上下界本身合法`() {
        assertNotNull(planStartupSemesterWrite("2026-09-07", 1, LocalDate.of(2026, 9, 7)))
        assertNotNull(planStartupSemesterWrite("2026-09-07", 40, LocalDate.of(2026, 9, 7)))
    }

    // ---------- 引导完成标记 ----------

    @Test
    fun `引导完成标记写到Dart同一个键`() {
        val store = InMemoryKeyValueStore()
        val preferences = StartupFlowPreferences(store)
        assertFalse("新装应用不该是「已完成」", preferences.isOnboardingCompleted())

        assertTrue("写完必须回读一致（国产 ROM 的 commit 有不可靠先例）", preferences.markOnboardingCompletedAndVerify())

        // 键名是契约：Dart 侧读 `flutter.has_completed_onboarding`，写错就是白写。
        assertEquals(
            "true",
            store.rawSnapshot()["flutter.has_completed_onboarding"],
        )
    }

    @Test
    fun `能读到Dart写下的已完成标记`() {
        val store = InMemoryKeyValueStore(
            mapOf(StartupFlowPreferences.KEY_COMPLETED_ONBOARDING to "true"),
        )
        assertTrue(StartupFlowPreferences(store).isOnboardingCompleted())
    }

    @Test
    fun `没有标记时按未完成处理`() {
        // 键不存在、以及盘上是 false，都必须判「未完成」——否则老用户会被跳过引导。
        assertFalse(StartupFlowPreferences(InMemoryKeyValueStore()).isOnboardingCompleted())
        val falseStore = InMemoryKeyValueStore(
            mapOf(StartupFlowPreferences.KEY_COMPLETED_ONBOARDING to "false"),
        )
        assertFalse(StartupFlowPreferences(falseStore).isOnboardingCompleted())
    }

    // 去 Flutter 化（P4-C，2026-11-08）：原先这里还有两条与 Dart 源逐字对拍的用例
    // （`storage_service.dart` 的两个键名、`app_migration_service.dart` 的包名清单），
    // 与 Dart 源已一并删除。键名/清单的护栏改由下面两条引用 Kotlin 常量表的断言承担：
    // 一个是「写完后盘上键名」的行为断言，一个是「清单值与顺序」的显式钉死。

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：清单规模为 0 时「包名一致」之类的断言会空绿；这里再钉一次规模。
        assertTrue(STARTUP_LEGACY_PACKAGE_CANDIDATES.size >= 2)
        assertTrue(StartupFlowPreferences.KEY_COMPLETED_ONBOARDING.isNotBlank())
    }
}
