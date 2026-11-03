package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * I2-5：宏回放的纯逻辑（Dart `lib/domain/warehouse_macro_replay_logic.dart` 逐条对拍）。
 *
 * 回放引擎本身要真 WebView，JVM 测不了；但「元素算不算找到」「录制标签怎么换回下标」
 * 「navigate 等到了没有」「加速路径砍哪一段」这些判据一旦漂移，表现是**静默选错**
 * 或**白等十秒**，所以抽成纯函数钉住。
 */
class WarehouseMacroReplayLogicTest {

    @Test
    fun `录制标签换下标_同名取第一个_数字越界或读不懂回null`() {
        val options = listOf("周一", "周二", "周一")
        assertEquals(0, matchRecordedOptionIndex(options, "周一"))
        assertEquals(1, matchRecordedOptionIndex(options, "周二"))
        assertNull(matchRecordedOptionIndex(options, "周三"))
        assertEquals(1, matchRecordedOptionIndex(options, 1))
        assertEquals(2, matchRecordedOptionIndex(options, 2))
        assertNull(matchRecordedOptionIndex(options, 3))
        assertNull(matchRecordedOptionIndex(options, -1))
        assertNull(matchRecordedOptionIndex(options, null))
        assertNull(matchRecordedOptionIndex(emptyList(), "周一"))
    }

    @Test
    fun `选择器候选_只有纯id形态才派生name兜底`() {
        assertEquals(
            listOf("#userAccount", "input[name=\"userAccount\"]"),
            macroSelectorCandidates(" #userAccount "),
        )
        assertEquals(listOf("#a b"), macroSelectorCandidates("#a b"))
        assertEquals(listOf("#a > input"), macroSelectorCandidates("#a > input"))
        assertEquals(listOf("input[name=\"user\"]"), macroSelectorCandidates("input[name=\"user\"]"))
        assertEquals(emptyList<String>(), macroSelectorCandidates("   "))
    }

    @Test
    fun `navigate判据_旧页URL非空不能当成导航完成`() {
        val login = "https://school.example/login"
        val target = "https://school.example/home"
        assertFalse(isTargetDocumentLoaded(login, login, "complete", target))
        assertTrue(isTargetDocumentLoaded(login, target, "complete", target))
        assertTrue(isTargetDocumentLoaded(login, "https://school.example/home?x=1", "complete", target))
        assertFalse(isTargetDocumentLoaded(login, target, "interactive", target))
        assertFalse(isTargetDocumentLoaded(login, null, "complete", target))
        // 目标就是当前页（重载）：href 不会变，只要求文档加载完成。
        assertTrue(isTargetDocumentLoaded(target, target, "complete", target))
    }

    @Test
    fun `入口文档就绪_空白页与半截文档都不算`() {
        assertTrue(isEntryDocumentReady("https://school.example/login", "complete"))
        assertFalse(isEntryDocumentReady("about:blank", "complete"))
        assertFalse(isEntryDocumentReady("https://school.example/login", "loading"))
        assertFalse(isEntryDocumentReady("", "complete"))
        assertFalse(isEntryDocumentReady(null, "complete"))
    }

    @Test
    fun `旧宏的作废点击_三条同时成立才跳过`() {
        assertTrue(shouldSkipStaleClickStep(stepIsClick = true, elementNotFound = true, previousClickNavigated = true))
        assertFalse(shouldSkipStaleClickStep(stepIsClick = false, elementNotFound = true, previousClickNavigated = true))
        assertFalse(shouldSkipStaleClickStep(stepIsClick = true, elementNotFound = false, previousClickNavigated = true))
        assertFalse(shouldSkipStaleClickStep(stepIsClick = true, elementNotFound = true, previousClickNavigated = false))
    }

    @Test
    fun `加速步骤_保留登录前缀后直达落点页`() {
        val steps = listOf(
            WarehouseMacroStep.fillField("#username", "u"),
            WarehouseMacroStep.fillField("#password", "p"),
            WarehouseMacroStep.click("#login"),
            WarehouseMacroStep.delay(1000),
            WarehouseMacroStep.click("#menu"),
            WarehouseMacroStep.delay(500),
            WarehouseMacroStep.click("#submit"),
            WarehouseMacroStep.delay(500),
        )
        val accelerated = buildAcceleratedMacroSteps(
            originalSteps = steps,
            scriptPageUrl = "https://school.example/import",
            importUrl = "https://school.example/login",
        )
        // 登录前缀（4 步）+ navigate(落点页) + 1000ms 沉降。
        assertEquals(6, accelerated.size)
        assertEquals(
            listOf("#username", "#password", "#login"),
            accelerated.take(3).map { it.selector.orEmpty() },
        )
        assertEquals(WarehouseMacroStepType.DELAY, accelerated[3].type)
        assertEquals(WarehouseMacroStepType.NAVIGATE, accelerated[4].type)
        assertEquals("https://school.example/import", accelerated[4].value)
        assertEquals(WarehouseMacroStepType.DELAY, accelerated[5].type)
        assertEquals(1000, accelerated[5].waitMs)
    }

    @Test
    fun `加速步骤_落点就是入口页只留前缀_没有落点页也留前缀`() {
        val steps = listOf(
            WarehouseMacroStep.fillField("#username", "u"),
            WarehouseMacroStep.click("#login"),
            WarehouseMacroStep.delay(1000),
            WarehouseMacroStep.click("#menu"),
            WarehouseMacroStep.click("#submit"),
        )
        val prefixOnly = buildAcceleratedMacroSteps(
            originalSteps = steps,
            scriptPageUrl = "https://school.example/login",
            importUrl = "https://school.example/login",
        )
        assertEquals(
            listOf("#username", "#login", ""),
            prefixOnly.map { it.selector.orEmpty() },
        )

        val withoutScriptPage = buildAcceleratedMacroSteps(steps, null, "https://school.example/login")
        assertEquals(3, withoutScriptPage.size)
    }

    @Test
    fun `加速步骤_砍得太少或没有认证前缀时保持原样`() {
        // 只砍掉 1 步：加速没有意义，逐字保留（避免为了省一步反而丢掉关键动作）。
        val few = listOf(
            WarehouseMacroStep.fillField("#username", "u"),
            WarehouseMacroStep.click("#login"),
            WarehouseMacroStep.delay(1000),
        )
        assertEquals(few, buildAcceleratedMacroSteps(few, "https://school.example/import", "https://school.example/login"))

        val noAuth = listOf(
            WarehouseMacroStep.navigate("https://school.example/login"),
            WarehouseMacroStep.click("#menu"),
            WarehouseMacroStep.delay(1000),
        )
        assertEquals(noAuth, buildAcceleratedMacroSteps(noAuth, "https://school.example/import", "https://school.example/login"))
    }

    @Test
    fun `录制的学期配置_缺字段或坏值一律退回弹窗`() {
        val valid = parseRecordedSemesterConfig(
            mapOf("startDate" to "2026-09-01T00:00:00.000", "firstCourseWeek" to 1),
        )
        assertEquals(LocalDateTime.of(2026, 9, 1, 0, 0), valid?.semesterStartDate)
        assertEquals(1, valid?.firstCourseWeek)

        assertNull(parseRecordedSemesterConfig(null))
        assertNull(parseRecordedSemesterConfig("not-a-map"))
        assertNull(parseRecordedSemesterConfig(mapOf("firstCourseWeek" to 1)))
        assertNull(parseRecordedSemesterConfig(mapOf("startDate" to "2026-09-01T00:00:00.000")))
        assertNull(parseRecordedSemesterConfig(mapOf("startDate" to "not-a-date", "firstCourseWeek" to 1)))
        assertNull(parseRecordedSemesterConfig(mapOf("startDate" to "2026-09-01T00:00:00.000", "firstCourseWeek" to 0)))
    }
}
