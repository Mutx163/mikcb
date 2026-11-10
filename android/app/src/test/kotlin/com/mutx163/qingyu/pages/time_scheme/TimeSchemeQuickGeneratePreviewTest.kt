package com.mutx163.qingyu.pages.time_scheme

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 快捷生成弹层的**实时预览**（2026-11-10 重做新增）。
 *
 * 预览文案 `quickGeneratePreviewSummary`（「共 {sections} 节 · 最后一节 {endTime} 结束」）
 * 由 [previewSummary] 现算：参数非法时返回 null（预览行整行不画），绝不抛异常——
 * 弹层里一个坏值把组合期炸掉，比「没显示预览」严重得多。
 */
class TimeSchemeQuickGeneratePreviewTest {

    private val defaultPreset = TimeSchemeQuickGeneratePreset(
        morningCount = 4,
        afternoonCount = 4,
        eveningCount = 2,
        morningStartTime = "08:00",
        afternoonStartTime = "14:00",
        eveningStartTime = "19:00",
        classDurationMinutes = 45,
        breakDurationMinutes = 10,
        breakOverrideRules = emptyList(),
    )

    @Test
    fun `预览句给出总节数与最后一节的结束时间`() {
        val summary = defaultPreset.previewSummary()
        assertNotNull("合法参数必须有预览", summary)

        val sections = defaultPreset.toSections()
        assertEquals("默认参数应生成 10 节（4+4+2）", 10, sections.size)
        assertTrue("预览要带节数：实际 $summary", summary!!.contains("10"))
        assertTrue(
            "预览要带最后一节的结束时间：实际 $summary",
            summary.contains(sections.last().endTime),
        )
        assertTrue("预览句要读完（以「结束」收尾）：实际 $summary", summary.trimEnd().endsWith("结束"))
        assertFalse("占位符没填上就是没做完：实际 $summary", summary.contains("{"))
    }

    @Test
    fun `数字非法时预览返回 null 而不是抛异常`() {
        assertNull(
            "时长为 0 时 core 会抛 DartFormatException，预览层必须折算成 null",
            defaultPreset.copy(classDurationMinutes = 0).previewSummary(),
        )
        assertNull(
            "三个时段都是 0 节时 core 同样会抛，预览层必须折算成 null",
            defaultPreset.copy(morningCount = 0, afternoonCount = 0, eveningCount = 0).previewSummary(),
        )
    }

    @Test
    fun `大课间规则影响最后一节的结束时间`() {
        val withRule = defaultPreset.copy(
            breakOverrideRules = listOf(
                com.mutx163.qingyu.core.BreakOverrideRule(
                    afterSection = 9,
                    breakDurationMinutes = 30,
                ),
            ),
        )
        val plain = defaultPreset.previewSummary()
        val adjusted = withRule.previewSummary()
        assertNotNull(plain)
        assertNotNull(adjusted)
        assertTrue(
            "大课间加长后最后一节应当更晚（否则预览没跟上规则）：$plain vs $adjusted",
            adjusted != plain,
        )
    }
}
