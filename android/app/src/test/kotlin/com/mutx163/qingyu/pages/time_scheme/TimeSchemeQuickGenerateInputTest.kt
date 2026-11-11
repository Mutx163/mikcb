package com.mutx163.qingyu.pages.time_scheme

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 快捷生成表单的**判据同源**（2026-11-11 评审 T-06）。
 *
 * `submit()`（点生成）与实时预览原来各写一份「数字/规则是否合法」的判据，
 * 漂移的典型表现是「预览显示共 12 节，点生成却报请把节数和时长填写为数字」。
 * 现在两份都从 [TimeSchemeQuickGenerateInput.parse] 派生，测试逐条钉住判据本身，
 * 再用一条源码断言钉住「两处调用点都真的走 parse」。
 */
class TimeSchemeQuickGenerateInputTest {

    private fun input(
        morning: String = "4",
        afternoon: String = "4",
        evening: String = "2",
        duration: String = "45",
        breakMinutes: String = "10",
        rules: List<Pair<String, String>> = emptyList(),
    ) = QuickGenerateInputText(
        morningCount = morning,
        afternoonCount = afternoon,
        eveningCount = evening,
        classDuration = duration,
        breakDuration = breakMinutes,
        breakRules = rules,
        morningStartTime = "08:00",
        afternoonStartTime = "14:00",
        eveningStartTime = "19:00",
    )

    @Test
    fun `全填对时生成 10 节并带上三个起始时间`() {
        val result = TimeSchemeQuickGenerateInput.parse(input())
        assertTrue("期望 Ready，实际 $result", result is QuickGenerateParseResult.Ready)
        val preset = (result as QuickGenerateParseResult.Ready).preset
        assertEquals(4, preset.morningCount)
        assertEquals(2, preset.eveningCount)
        assertEquals("08:00", preset.morningStartTime)
        assertEquals(45, preset.classDurationMinutes)
        assertEquals(10, preset.toSections().size)
    }

    @Test
    fun `按出现顺序指出第一格没填好的数字`() {
        assertEquals(
            QuickGenerateParseResult.MissingNumbers(QuickGenerateField.MORNING),
            TimeSchemeQuickGenerateInput.parse(input(morning = "")),
        )
        assertEquals(
            QuickGenerateParseResult.MissingNumbers(QuickGenerateField.AFTERNOON),
            TimeSchemeQuickGenerateInput.parse(input(afternoon = "x")),
        )
        assertEquals(
            QuickGenerateParseResult.MissingNumbers(QuickGenerateField.EVENING),
            TimeSchemeQuickGenerateInput.parse(input(evening = " ")),
        )
        assertEquals(
            QuickGenerateParseResult.MissingNumbers(QuickGenerateField.RHYTHM),
            TimeSchemeQuickGenerateInput.parse(input(duration = "")),
        )
        assertEquals(
            QuickGenerateParseResult.MissingNumbers(QuickGenerateField.RHYTHM),
            TimeSchemeQuickGenerateInput.parse(input(breakMinutes = "十")),
        )
    }

    @Test
    fun `大课间规则的三类非法都判 InvalidBreakRule`() {
        assertEquals(
            "解析不出节次",
            QuickGenerateParseResult.InvalidBreakRule,
            TimeSchemeQuickGenerateInput.parse(input(rules = listOf("" to "20"))),
        )
        assertEquals(
            "节次小于 1",
            QuickGenerateParseResult.InvalidBreakRule,
            TimeSchemeQuickGenerateInput.parse(input(rules = listOf("0" to "20"))),
        )
        assertEquals(
            "时长为负",
            QuickGenerateParseResult.InvalidBreakRule,
            TimeSchemeQuickGenerateInput.parse(input(rules = listOf("2" to "-1"))),
        )
    }

    @Test
    fun `合法规则进 preset`() {
        val result = TimeSchemeQuickGenerateInput.parse(input(rules = listOf("9" to "30")))
        assertTrue(result is QuickGenerateParseResult.Ready)
        val preset = (result as QuickGenerateParseResult.Ready).preset
        assertEquals(1, preset.breakOverrideRules.size)
        assertEquals(9, preset.breakOverrideRules.first().afterSection)
        assertEquals(30, preset.breakOverrideRules.first().breakDurationMinutes)
    }

    @Test
    fun `预览取值与 submit 判据同源（源码断言）`() {
        // 两处调用点都必须走 parse：一处漏掉就会又出现「预览说能、生成说不能」。
        val sheet = readSheet()
        val calls = Regex("""TimeSchemeQuickGenerateInput\.parse\(""").findAll(sheet).count()
        assertTrue("弹层里对 parse( 的调用点是 $calls 个（应 ≥2：submit + 预览）", calls >= 2)
    }

    private fun readSheet(): String {
        val relative =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeQuickGenerateSheet.kt"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative")
    }
}
