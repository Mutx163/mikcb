package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 录制事件 → 宏步骤转换矩阵（P1 / N4）。
 *
 * 用例口径机械抄 Dart `MacroRecordingConverter.convert`（只读参照），
 * 边界值（1499/1500/5000/5001ms）逐个钉死。
 */
class WarehouseMacroRecordingConverterTest {

    private fun event(
        eventType: String,
        selector: String,
        timestamp: Long,
        value: String = "",
        fieldType: String? = null,
        formSelector: String? = null,
    ): Map<String, Any?> {
        val out = linkedMapOf<String, Any?>(
            "eventType" to eventType,
            "selector" to selector,
            "value" to value,
            "timestamp" to timestamp,
        )
        if (fieldType != null) out["fieldType"] = fieldType
        if (formSelector != null) out["formSelector"] = formSelector
        return out
    }

    // ---------------------------------------------------------------------
    // 连续按键合并
    // ---------------------------------------------------------------------

    @Test
    fun `同一选择器连续按键只保留最终值`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("input", "#user", 0, "2", "username"),
                event("input", "#user", 120, "20", "username"),
                event("input", "#user", 300, "2023", "username"),
            ),
        )
        assertEquals(1, steps.size)
        assertEquals(WarehouseMacroStepType.FILL_FIELD, steps[0].type)
        assertEquals("2023", steps[0].value)
        assertEquals("#user", steps[0].selector)
    }

    @Test
    fun `结尾未 flush 的输入也要落盘`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(event("input", "#user", 0, "abc", "username")),
        )
        assertEquals(1, steps.size)
        assertEquals("abc", steps[0].value)
    }

    // ---------------------------------------------------------------------
    // delay 插入边界（>1500 且 <60000 才插；≤5000 记精确值，>5000 记 3s）
    // ---------------------------------------------------------------------

    @Test
    fun `delay 边界 1499 与 1500 不插`() {
        for (gap in longArrayOf(1499, 1500)) {
            val steps = convertTwoInputs(gap)
            assertTrue("间隔 $gap 不该插 delay", steps.none { it.type == WarehouseMacroStepType.DELAY })
        }
    }

    @Test
    fun `delay 边界 1501 与 5000 记精确值`() {
        val s1501 = convertTwoInputs(1501)
        // 插 delay 前先 flush 已缓存输入：顺序是 fill(#a) → delay → fill(#b)。
        assertEquals(
            listOf(WarehouseMacroStepType.FILL_FIELD, WarehouseMacroStepType.DELAY, WarehouseMacroStepType.FILL_FIELD),
            s1501.map { it.type },
        )
        assertEquals(1501, s1501[1].waitMs)

        val s5000 = convertTwoInputs(5000)
        assertEquals(5000, s5000[1].waitMs)
    }

    @Test
    fun `delay 边界 5001 与 59999 记 3 秒标准等待`() {
        assertEquals(3000, convertTwoInputs(5001)[1].waitMs)
        assertEquals(3000, convertTwoInputs(59999)[1].waitMs)
    }

    @Test
    fun `delay 边界 60000 及以上不插`() {
        for (gap in longArrayOf(60000, 61000)) {
            val steps = convertTwoInputs(gap)
            assertTrue("间隔 $gap 不该插 delay", steps.none { it.type == WarehouseMacroStepType.DELAY })
        }
    }

    private fun convertTwoInputs(gapMs: Long): List<WarehouseMacroStep> =
        WarehouseMacroRecordingConverter.convert(
            listOf(
                event("input", "#a", 0, "1", "username"),
                event("input", "#b", gapMs, "2", "username"),
            ),
        )

    // ---------------------------------------------------------------------
    // 敏感字段 → waitForManualInput（每个选择器只记一次）
    // ---------------------------------------------------------------------

    @Test
    fun `密码字段转等待手动输入且不重复`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("input", "#pwd", 0, "", "password"),
                event("input", "#pwd", 200, "", "password"),
                event("change", "#pwd", 400, "", "password"),
            ),
        )
        assertEquals(1, steps.size)
        assertEquals(WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT, steps[0].type)
        assertEquals("manual_input_password", steps[0].value)
        assertEquals("password", steps[0].fieldType)
    }

    @Test
    fun `敏感值从源头就是空串 转换后步骤链无值可泄`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("input", "#code", 0, "", "captcha"),
                event("click", "#login", 1000, "登录", "button", "#Form1"),
            ),
        )
        assertTrue(steps.any { it.type == WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT })
        assertTrue(
            "转换产物不允许出现敏感值载荷",
            steps.none { it.type == WarehouseMacroStepType.FILL_FIELD },
        )
    }

    // ---------------------------------------------------------------------
    // click / submit
    // ---------------------------------------------------------------------

    @Test
    fun `click 生成点击加 800ms 等待`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(event("click", "#menu", 0, "课表", "link")),
        )
        assertEquals(2, steps.size)
        assertEquals(WarehouseMacroStepType.CLICK, steps[0].type)
        assertEquals("#menu", steps[0].selector)
        assertEquals(800, steps[1].waitMs)
    }

    @Test
    fun `普通 submit 生成表单点击加 2500ms 等待`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(event("submit", "#Form1", 0)),
        )
        assertEquals(2, steps.size)
        assertEquals(WarehouseMacroStepType.CLICK, steps[0].type)
        assertEquals("#Form1", steps[0].selector)
        assertEquals(2500, steps[1].waitMs)
    }

    @Test
    fun `冗余 submit 丢弃 点按钮后的表单 submit 不再生成点击`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("input", "#user", 0, "20230001", "username"),
                event("click", "#btnLogin", 1000, "登录", "button", "#Form1"),
                event("submit", "#Form1", 1300),
            ),
        )
        // 期望：fill(user) + click(#btnLogin) + delay(800) + delay(2500)
        // 冗余的 submit 不生成 click(#Form1)，但保留 2500 等待。
        // （间隔都压在 1.5s 内，不触发 delay 插入，形状更干净。）
        assertEquals(4, steps.size)
        assertEquals(WarehouseMacroStepType.FILL_FIELD, steps[0].type)
        assertEquals("#btnLogin", steps[1].selector)
        assertTrue(steps.none { it.selector == "#Form1" && it.type == WarehouseMacroStepType.CLICK })
        assertEquals(2500, steps[3].waitMs)
    }

    @Test
    fun `非冗余 submit 保留表单点击`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("click", "#btnLogin", 0, "登录", "button", "#Form1"),
                event("submit", "#Form1", 3000),
            ),
        )
        // 间隔 3s > 2s 窗口：不算同一次动作，submit 照常生成 click(#Form1)。
        assertTrue(steps.any { it.type == WarehouseMacroStepType.CLICK && it.selector == "#Form1" })
    }

    @Test
    fun `冗余判定三条件缺一不可`() {
        // 上一条不是 click
        assertFalse(
            WarehouseMacroRecordingConverter.isRedundantSubmitAfterClick(
                previousEventType = "input",
                previousFieldType = "button",
                previousFormSelector = "#F",
                currentSelector = "#F",
                gapMs = 100,
            ),
        )
        // 上一条不是提交按钮
        assertFalse(
            WarehouseMacroRecordingConverter.isRedundantSubmitAfterClick(
                previousEventType = "click",
                previousFieldType = "link",
                previousFormSelector = "#F",
                currentSelector = "#F",
                gapMs = 100,
            ),
        )
        // 没带表单选择器
        assertFalse(
            WarehouseMacroRecordingConverter.isRedundantSubmitAfterClick(
                previousEventType = "click",
                previousFieldType = "button",
                previousFormSelector = "",
                currentSelector = "#F",
                gapMs = 100,
            ),
        )
        // 超出 2s 窗口
        assertFalse(
            WarehouseMacroRecordingConverter.isRedundantSubmitAfterClick(
                previousEventType = "click",
                previousFieldType = "button",
                previousFormSelector = "#F",
                currentSelector = "#F",
                gapMs = 2001,
            ),
        )
        // 当前选择器不是那张表单
        assertFalse(
            WarehouseMacroRecordingConverter.isRedundantSubmitAfterClick(
                previousEventType = "click",
                previousFieldType = "button",
                previousFormSelector = "#F",
                currentSelector = "#Other",
                gapMs = 100,
            ),
        )
        // 全部条件满足
        assertTrue(
            WarehouseMacroRecordingConverter.isRedundantSubmitAfterClick(
                previousEventType = "click",
                previousFieldType = "button",
                previousFormSelector = "#F",
                currentSelector = "#F",
                gapMs = 2000,
            ),
        )
    }

    // ---------------------------------------------------------------------
    // 去重与压缩
    // ---------------------------------------------------------------------

    @Test
    fun `完全相同的事件只留一条`() {
        val duplicate = event("input", "#user", 1000, "a", "username")
        val steps = WarehouseMacroRecordingConverter.convert(listOf(duplicate, duplicate, duplicate))
        assertEquals(1, steps.size)
    }

    @Test
    fun `compact 合并跳过中间 delay 的相邻同选择器 fill`() {
        val compacted = WarehouseMacroRecordingConverter.compactMacroFillSteps(
            listOf(
                WarehouseMacroStep.fillField("#a", "1", "username"),
                WarehouseMacroStep.delay(300),
                WarehouseMacroStep.fillField("#a", "12", "username"),
            ),
        )
        assertEquals(1, compacted.size)
        assertEquals("12", compacted[0].value)
    }

    @Test
    fun `compact 不合并不同选择器`() {
        val compacted = WarehouseMacroRecordingConverter.compactMacroFillSteps(
            listOf(
                WarehouseMacroStep.fillField("#a", "1", "username"),
                WarehouseMacroStep.fillField("#b", "2", "username"),
            ),
        )
        assertEquals(2, compacted.size)
    }

    @Test
    fun `空事件流转出空步骤`() {
        assertTrue(WarehouseMacroRecordingConverter.convert(emptyList()).isEmpty())
    }

    // ---------------------------------------------------------------------
    // 整场形态：登录一次的标准形状
    // ---------------------------------------------------------------------

    @Test
    fun `登录场形态对拍`() {
        val steps = WarehouseMacroRecordingConverter.convert(
            listOf(
                event("input", "#userAccount", 0, "2", "username"),
                event("input", "#userAccount", 150, "20", "username"),
                event("input", "#userAccount", 400, "20230001", "username"),
                event("input", "#userAccount", 900, "2023000112", "username"),
                event("input", "#userPassword", 1200, "", "password"),
                event("click", "#btnLogin", 4000, "登 录", "button", "#Form1"),
                event("submit", "#Form1", 4200),
            ),
        )
        // 期望：fill(#userAccount, 2023000112) + waitForManualInput(#userPassword)
        //       + delay(2800)（输密码到点按钮的自然停顿）
        //       + click(#btnLogin) + delay(800) + delay(2500)
        // （password 敏感转等待；submit 冗余丢弃但保留等待）
        assertEquals(6, steps.size)
        assertEquals(WarehouseMacroStepType.FILL_FIELD, steps[0].type)
        assertEquals("2023000112", steps[0].value)
        assertEquals(WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT, steps[1].type)
        assertEquals(2800, steps[2].waitMs)
        assertEquals("#btnLogin", steps[3].selector)
        assertEquals(800, steps[4].waitMs)
        assertEquals(2500, steps[5].waitMs)
    }
}
