package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F32：网页对话框的降级回答（原生对话框未移植前，保证脚本不永久挂起）。
 *
 * 每种回答都必须是**确定的**；requestId 不可信时一律拒绝，防止脚本注入。
 */
class WarehouseBridgeFallbackTest {

    @Test
    fun `confirm 返回确定的 true`() {
        val answer = warehouseBridgeFallbackAnswer(
            """{"type":"confirm","requestId":"confirm_1_abc","title":"提示","message":"是否继续？"}""",
        )

        assertEquals(WarehouseBridgeDialogKind.CONFIRM, answer?.kind)
        assertEquals("confirm_1_abc", answer?.requestId)
        assertEquals("true", answer?.jsonValue)
    }

    @Test
    fun `prompt 用脚本自带默认值回答 字符串被正确转义`() {
        val answer = warehouseBridgeFallbackAnswer(
            """{"type":"prompt","requestId":"prompt_1","defaultValue":"2026"}""",
        )

        assertEquals(WarehouseBridgeDialogKind.PROMPT, answer?.kind)
        assertEquals("\"2026\"", answer?.jsonValue)

        val withQuote = warehouseBridgeFallbackAnswer(
            """{"type":"prompt","requestId":"prompt_2","defaultValue":"a\"b"}""",
        )
        assertEquals("\"a\\\"b\"", withQuote?.jsonValue)
    }

    @Test
    fun `prompt 没有默认值时回答空字符串`() {
        val answer = warehouseBridgeFallbackAnswer("""{"type":"prompt","requestId":"prompt_3"}""")

        assertEquals("\"\"", answer?.jsonValue)
    }

    @Test
    fun `singleSelection 用脚本给的 selectedIndex 回答`() {
        val answer = warehouseBridgeFallbackAnswer(
            """{"type":"singleSelection","requestId":"single_selection_1","optionsJson":"[\"a\",\"b\"]","selectedIndex":1}""",
        )

        assertEquals(WarehouseBridgeDialogKind.SINGLE_SELECTION, answer?.kind)
        assertEquals("1", answer?.jsonValue)
    }

    @Test
    fun `singleSelection 缺 selectedIndex 时回 0`() {
        val answer = warehouseBridgeFallbackAnswer(
            """{"type":"singleSelection","requestId":"single_selection_2"}""",
        )

        assertEquals("0", answer?.jsonValue)
    }

    @Test
    fun `saveCourseConfig 与 savePresetTimeSlots 诚实回 false`() {
        assertEquals(
            "false",
            warehouseBridgeFallbackAnswer("""{"type":"saveCourseConfig","requestId":"cfg_1","payload":"{}"}""")?.jsonValue,
        )
        assertEquals(
            "false",
            warehouseBridgeFallbackAnswer("""{"type":"savePresetTimeSlots","requestId":"slots_1","payload":"[]"}""")?.jsonValue,
        )
    }

    @Test
    fun `非对话框消息与坏 JSON 一律不回答`() {
        assertNull(warehouseBridgeFallbackAnswer(null))
        assertNull(warehouseBridgeFallbackAnswer(""))
        assertNull(warehouseBridgeFallbackAnswer("not json"))
        assertNull(warehouseBridgeFallbackAnswer("""{"type":"courses","requestId":"c1"}"""))
        assertNull(warehouseBridgeFallbackAnswer("""{"type":"toast","requestId":"t1"}"""))
    }

    @Test
    fun `不可信 requestId 拒绝回答 防止脚本注入`() {
        listOf(
            """"a'b"""",
            """"a');alert(1);//"""",
            """"a b"""",
            "\"${"x".repeat(129)}\"",
        ).forEach { rawId ->
            val raw = """{"type":"confirm","requestId":$rawId}"""
            assertNull("id=$rawId 应被拒绝", warehouseBridgeFallbackAnswer(raw))
        }
    }

    @Test
    fun `缺少 requestId 时不回答`() {
        assertNull(warehouseBridgeFallbackAnswer("""{"type":"confirm"}"""))
        assertNull(warehouseBridgeFallbackAnswer("""{"type":"confirm","requestId":123}"""))
    }

    @Test
    fun `courses 载荷只从 courses 消息里取`() {
        val payload = """[{"name":"数学"}]"""
        assertEquals(
            payload,
            warehouseBridgeCoursesPayload("""{"type":"courses","payload":"[{\"name\":\"数学\"}]"}"""),
        )
        assertNull(warehouseBridgeCoursesPayload("""{"type":"confirm","payload":"[]"}"""))
        assertNull(warehouseBridgeCoursesPayload("""{"type":"courses","payload":[]}"""))
        assertNull(warehouseBridgeCoursesPayload("not json"))
    }

    @Test
    fun `降级回答生成的 JS 指向合法 requestId`() {
        val answer = warehouseBridgeFallbackAnswer("""{"type":"confirm","requestId":"confirm_9_xyz"}""")
        val script = warehouseBridgeResolveScript(answer!!.requestId, answer.jsonValue)

        assertTrue(script.contains("window.__qingyuResolvers['confirm_9_xyz'](true)"))
    }
}
