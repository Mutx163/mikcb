package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * I2-1：脚本对话框请求的解包（confirm / prompt / singleSelection）。
 *
 * 钉住与 Dart `_showScript*Dialog` 一致的字段口径：非字符串当没给、
 * optionsJson 解析失败按空选项、selectedIndex clamp、requestId 白名单。
 */
class WarehouseBridgeDialogRequestTest {

    @Test
    fun `confirm 全字段解包`() {
        val request = warehouseBridgeDialogRequest(
            """{"type":"confirm","requestId":"confirm_1_a","title":"提示","message":"继续？","confirmText":"继续"}""",
        )
        assertEquals(WarehouseBridgeDialogKind.CONFIRM, request?.kind)
        assertEquals("confirm_1_a", request?.requestId)
        assertEquals("提示", request?.title)
        assertEquals("继续？", request?.message)
        assertEquals("继续", request?.confirmText)
    }

    @Test
    fun `prompt 带默认值与校验器名`() {
        val request = warehouseBridgeDialogRequest(
            """{"type":"prompt","requestId":"prompt_1","title":"学年","defaultValue":"2026","validatorName":"validateYearInput"}""",
        )
        assertEquals(WarehouseBridgeDialogKind.PROMPT, request?.kind)
        assertEquals("2026", request?.defaultValue)
        assertEquals("validateYearInput", request?.validatorName)
    }

    @Test
    fun `singleSelection 解出选项列表并 clamp 下标`() {
        val request = warehouseBridgeDialogRequest(
            """{"type":"singleSelection","requestId":"ss_1","optionsJson":"[\"大一\",\"大二\"]","selectedIndex":7}""",
        )
        assertEquals(listOf("大一", "大二"), request?.options)
        assertEquals(1, request?.selectedIndex)
        assertEquals("大二", request?.optionTextAt(request.selectedIndex))
    }

    @Test
    fun `optionsJson 解析失败按空选项处理 不中断导入`() {
        val request = warehouseBridgeDialogRequest(
            """{"type":"singleSelection","requestId":"ss_2","optionsJson":"{bad","selectedIndex":3}""",
        )
        assertEquals(emptyList<String>(), request?.options)
        assertEquals(0, request?.selectedIndex)
    }

    @Test
    fun `非字符串字段按没给处理（Dart 的 TypeError 洞）`() {
        val request = warehouseBridgeDialogRequest(
            """{"type":"confirm","requestId":"c1","title":{"x":1},"message":["a"],"confirmText":true}""",
        )
        assertEquals("", request?.title)
        assertEquals("", request?.message)
        assertEquals("", request?.confirmText)
    }

    @Test
    fun `保存类消息不走弹窗解包（走 saveRequest）`() {
        assertNull(
            warehouseBridgeDialogRequest(
                """{"type":"saveCourseConfig","requestId":"a","payload":"{}"}""",
            ),
        )
    }

    @Test
    fun `requestId 不可信一律拒绝（防脚本注入）`() {
        assertNull(
            warehouseBridgeDialogRequest(
                """{"type":"confirm","requestId":"x');alert(1)//"}""",
            ),
        )
        assertNull(warehouseBridgeDialogRequest("""{"type":"confirm"}"""))
        assertNull(warehouseBridgeDialogRequest("not json"))
        assertNull(warehouseBridgeDialogRequest(null))
    }

    @Test
    fun `应答匹配键与 Dart 口径一致（dialogId 优先）`() {
        val withId = warehouseBridgeDialogRequest(
            """{"type":"confirm","requestId":"c1","dialogId":"term","title":"t","message":"m"}""",
        )
        assertEquals("confirm|id:term", withId?.responseKey())

        val noId = warehouseBridgeDialogRequest(
            """{"type":"prompt","requestId":"p1","title":"学年","message":"输入"}""",
        )
        assertEquals("prompt|学年|输入", noId?.responseKey())

        // singleSelection 的正文位用 optionsJson 原文（不是解析后重拼的）。
        val single = warehouseBridgeDialogRequest(
            """{"type":"singleSelection","requestId":"s1","title":"学期","optionsJson":"[ \"上\", \"下\" ]"}""",
        )
        assertEquals("singleSelection|学期|[ \"上\", \"下\" ]", single?.responseKey())
    }
}
