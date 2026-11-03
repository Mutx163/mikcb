package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * I2-4：录制事件流 → 宏步骤的转换器（逐字对齐 Dart `MacroRecordingConverter.convert`）。
 *
 * 这些规则全是 Dart 侧踩出来的坑：连续按键合并、click+submit 同动作去重、
 * 敏感字段不落值、间隔转 delay。改任何一条，录出来的宏回放就会对不上。
 */
class WarehouseMacroRecordingConverterTest {

    private fun event(
        type: String,
        selector: String = "",
        value: String = "",
        fieldType: String? = null,
        timestamp: Long,
        formSelector: String? = null,
    ): Map<String, Any?> = buildMap {
        put("eventType", type)
        put("selector", selector)
        put("value", value)
        fieldType?.let { put("fieldType", it) }
        put("timestamp", timestamp)
        formSelector?.let { put("formSelector", it) }
    }

    @Test
    fun `空事件流转空步骤`() {
        assertTrue(WarehouseMacroRecordingConverter.convert(emptyList()).isEmpty())
    }

    @Test
    fun `同一输入框连续按键只留最终值`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("input", "#user", "2", "username", timestamp = 1000),
                event("input", "#user", "20", "username", timestamp = 1100),
                event("input", "#user", "2023", "username", timestamp = 1200),
            ),
        )
        assertEquals(1, steps.size)
        assertEquals(WarehouseMacroStepType.FILL_FIELD, steps[0].type)
        assertEquals("#user", steps[0].selector)
        assertEquals("2023", steps[0].value)
        assertEquals("username", steps[0].fieldType)
    }

    @Test
    fun `敏感字段不落值 转成一次性手动输入步骤`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("input", "#pwd", "", "password", timestamp = 1000),
                event("input", "#pwd", "", "password", timestamp = 1100),
            ),
        )
        assertEquals(1, steps.size)
        assertEquals(WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT, steps[0].type)
        assertEquals("manual_input_password", steps[0].value)
        assertEquals("password", steps[0].fieldType)
    }

    @Test
    fun `点击提交按钮后的表单 submit 是同一次动作 不重复生成点击`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("click", "#loginBtn", "登录", "button", timestamp = 1000, formSelector = "#Form1"),
                event("submit", "#Form1", fieldType = "form", timestamp = 1050),
            ),
        )
        // click + 800ms 等待 + 2500ms 提交等待；不再有第二个 click
        assertEquals(
            listOf(
                WarehouseMacroStepType.CLICK,
                WarehouseMacroStepType.DELAY,
                WarehouseMacroStepType.DELAY,
            ),
            steps.map { it.type },
        )
        assertEquals(1, steps.count { it.type == WarehouseMacroStepType.CLICK })
    }

    @Test
    fun `独立 submit（没有前置按钮点击）仍生成点击`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("submit", "#Form1", fieldType = "form", timestamp = 1000),
            ),
        )
        assertEquals(WarehouseMacroStepType.CLICK, steps[0].type)
        assertEquals("#Form1", steps[0].selector)
        assertEquals(WarehouseMacroStepType.DELAY, steps[1].type)
        assertEquals(2500, steps[1].waitMs)
    }

    @Test
    fun `间隔 1 点 5 到 5 秒按实际记 delay 超过 5 秒记标准 3 秒`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("click", "#a", timestamp = 0),
                event("click", "#b", timestamp = 3000),   // gap 3000 → delay(3000)
                event("click", "#c", timestamp = 12000),  // gap 9000 → delay(3000)
            ),
        )
        val delays = steps.filter { it.type == WarehouseMacroStepType.DELAY }.map { it.waitMs }
        // 每次 click 自带 800；gap 3000 记 3000；gap 9000 记 3000
        assertEquals(listOf(800, 3000, 800, 3000, 800), delays)
    }

    @Test
    fun `完全重复的事件被去重`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("click", "#a", timestamp = 1000),
                event("click", "#a", timestamp = 1000),
            ),
        )
        assertEquals(1, steps.count { it.type == WarehouseMacroStepType.CLICK })
    }

    @Test
    fun `不同字段的输入各自成步 不被合并`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("input", "#user", "u1", "username", timestamp = 1000),
                event("input", "#captcha", "ab", "other", timestamp = 1100),
                event("click", "#go", timestamp = 1200),
            ),
        )
        val fills = steps.filter { it.type == WarehouseMacroStepType.FILL_FIELD }
        assertEquals(2, fills.size)
        assertEquals(listOf("#user", "#captcha"), fills.map { it.selector })
    }
}
