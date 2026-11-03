package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 加速回放测试（P2 / N2 后半）。口径机械抄 Dart `buildAcceleratedMacroSteps`
 * （只读参照）：无前缀不加速、登录后 <2 步不加速、缺 scriptPageUrl 只留前缀、
 * 入口即脚本页只留前缀、正常 = 前缀 + navigate(脱敏脚本页) + delay(1000)。
 */
class WarehouseMacroAcceleratedTest {

    /** 标准登录录制：填账号 → 点提交 → 等 → 进菜单点两下 → 到课表页。 */
    private fun fullSteps(): List<WarehouseMacroStep> = listOf(
        WarehouseMacroStep.fillField("#user", "20230001", "username"),
        WarehouseMacroStep.click("#btnLogin"),
        WarehouseMacroStep.delay(2500),
        WarehouseMacroStep.click("#menuKb"),
        WarehouseMacroStep.delay(800),
        WarehouseMacroStep.waitForUrl("xsMain.jsp"),
    )

    @Test
    fun `正常加速 = 登录前缀加脱敏脚本页导航`() {
        val accelerated = buildWarehouseAcceleratedMacroSteps(
            fullSteps(),
            scriptPageUrl = "http://jw.example.edu.cn/xsMain.jsp?jsessionid=ABC",
            importUrl = "http://jw.example.edu.cn/login",
        )
        // 前缀 = fill + click + 紧随 delay（lastAuth 后 3 步内的 click，含其 delay）
        assertEquals(5, accelerated.size)
        assertEquals(WarehouseMacroStepType.FILL_FIELD, accelerated[0].type)
        assertEquals(WarehouseMacroStepType.CLICK, accelerated[1].type)
        assertEquals(WarehouseMacroStepType.DELAY, accelerated[2].type)
        assertEquals(WarehouseMacroStepType.NAVIGATE, accelerated[3].type)
        assertEquals("http://jw.example.edu.cn/xsMain.jsp", accelerated[3].value)
        assertEquals(WarehouseMacroStepType.DELAY, accelerated[4].type)
        assertEquals(1000, accelerated[4].waitMs)
    }

    @Test
    fun `无登录前缀不加速`() {
        val steps = listOf(
            WarehouseMacroStep.click("#menu"),
            WarehouseMacroStep.delay(800),
            WarehouseMacroStep.waitForUrl("kb.jsp"),
        )
        assertSame(steps, buildWarehouseAcceleratedMacroSteps(steps, "http://x/main", "http://x/login"))
    }

    @Test
    fun `登录后不足两步不加速`() {
        val steps = listOf(
            WarehouseMacroStep.fillField("#user", "u", "username"),
            WarehouseMacroStep.click("#btn"),
            WarehouseMacroStep.delay(2500),
        )
        // lastAuth=fill(0)，click(1)→end=1，紧随 delay(2)→end=2；prefix 全量 → 不加速
        assertSame(steps, buildWarehouseAcceleratedMacroSteps(steps, "http://x/main", "http://x/login"))
    }

    @Test
    fun `缺 scriptPageUrl 只保留登录前缀 丢弃其后菜单点击`() {
        val accelerated = buildWarehouseAcceleratedMacroSteps(
            fullSteps(),
            scriptPageUrl = null,
            importUrl = "http://jw.example.edu.cn/login",
        )
        assertEquals(listOf(WarehouseMacroStepType.FILL_FIELD, WarehouseMacroStepType.CLICK, WarehouseMacroStepType.DELAY), accelerated.map { it.type })
    }

    @Test
    fun `入口页即脚本页时只留前缀`() {
        val accelerated = buildWarehouseAcceleratedMacroSteps(
            fullSteps(),
            scriptPageUrl = "http://jw.example.edu.cn/login?token=x",
            importUrl = "http://jw.example.edu.cn/login?jsessionid=1",
        )
        assertEquals(3, accelerated.size)
        assertTrue(accelerated.all { it.type != WarehouseMacroStepType.NAVIGATE })
    }

    @Test
    fun `空步骤原样返回`() {
        val steps = emptyList<WarehouseMacroStep>()
        assertSame(steps, buildWarehouseAcceleratedMacroSteps(steps, "http://x/main", "http://x/login"))
    }
}
