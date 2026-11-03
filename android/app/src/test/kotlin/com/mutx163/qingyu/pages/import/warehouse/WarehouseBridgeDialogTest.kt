package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * F32 收口：网页对话框的原生界面（模型层契约 + 宿主接线守卫）。
 *
 * 回传结构逐字对齐 Dart `_resolveJavaScriptRequest(requestId, jsonEncode(value))`；
 * 「取消」语义对齐 Dart 各对话框的返回值（confirm=false、prompt/单选=null、save=false）。
 */
class WarehouseBridgeDialogTest {

    // ---------------------------------------------------------------------------
    // 请求解析：字段从网页端来什么就解析什么
    // ---------------------------------------------------------------------------

    @Test
    fun `confirm 请求解析出标题 正文与确认按钮文字`() {
        val request = warehouseBridgeDialogRequest(
            """{"type":"confirm","requestId":"confirm_1_a","title":"提示","message":"是否继续？","confirmText":"继续"}""",
        )

        val confirm = request as WarehouseBridgeDialogRequest.Confirm
        assertEquals("confirm_1_a", confirm.requestId)
        assertEquals("提示", confirm.title)
        assertEquals("是否继续？", confirm.message)
        assertEquals("继续", confirm.confirmText)
    }

    @Test
    fun `prompt 请求解析出默认值与校验器 年份校验按四位数字判`() {
        val request = warehouseBridgeDialogRequest(
            """{"type":"prompt","requestId":"prompt_1_a","title":"学年","message":"请输入入学年份","defaultValue":"2026","validatorName":"validateYearInput"}""",
        ) as WarehouseBridgeDialogRequest.Prompt

        assertEquals("2026", request.defaultValue)
        assertTrue(request.validate("2026"))
        assertFalse(request.validate("26"))
        assertFalse(request.validate("abcd"))
        // 其他校验器一律放行（对齐 Dart：只认 validateYearInput）。
        assertTrue(request.copy(validatorName = "").validate("任意"))
    }

    @Test
    fun `单选请求解析选项并钳住初值 optionsJson 坏了按空列表`() {
        val ok = warehouseBridgeDialogRequest(
            """{"type":"singleSelection","requestId":"sel_1_a","title":"学期","optionsJson":"[\"春\",\"秋\"]","selectedIndex":5}""",
        ) as WarehouseBridgeDialogRequest.SingleSelection
        assertEquals(listOf("春", "秋"), ok.options)
        // 越界初值钳到最后一个（对齐 Dart currentSelection 的 clamp）。
        assertEquals(1, ok.selectedIndex)

        val bad = warehouseBridgeDialogRequest(
            """{"type":"singleSelection","requestId":"sel_2_a","optionsJson":"not-json"}""",
        ) as WarehouseBridgeDialogRequest.SingleSelection
        assertTrue(bad.options.isEmpty())
        assertEquals(0, bad.selectedIndex)
    }

    @Test
    fun `saveCourseConfig 载荷解析成字段表 键名原样 类型按值归类`() {
        val request = warehouseBridgeDialogRequest(
            """{"type":"saveCourseConfig","requestId":"cfg_1_a","payload":""" +
                """"{\"semesterTotalWeeks\":20,\"semesterStartDate\":\"2026-09-07\",\"firstDayOfWeek\":1,\"autoMerge\":true,\"note\":null}"}""",
        ) as WarehouseBridgeDialogRequest.SaveConfig

        assertEquals(
            listOf("semesterTotalWeeks", "semesterStartDate", "firstDayOfWeek", "autoMerge", "note"),
            request.fields.map { it.key },
        )
        assertEquals(
            listOf(
                WarehouseBridgeFormFieldKind.NUMBER,
                WarehouseBridgeFormFieldKind.TEXT,
                WarehouseBridgeFormFieldKind.NUMBER,
                WarehouseBridgeFormFieldKind.FLAG,
                WarehouseBridgeFormFieldKind.READONLY,
            ),
            request.fields.map { it.kind },
        )
    }

    @Test
    fun `savePresetTimeSlots 数组载荷解析不出界面 回 null 走降级`() {
        assertNull(
            warehouseBridgeDialogRequest(
                """{"type":"savePresetTimeSlots","requestId":"slots_1_a","payload":"[{\"name\":\"第1节\",\"startTime\":\"08:00\",\"endTime\":\"08:45\"}]"}""",
            ),
        )
    }

    @Test
    fun `坏 JSON 与不可信 requestId 解析不出界面`() {
        assertNull(warehouseBridgeDialogRequest("not json"))
        assertNull(warehouseBridgeDialogRequest(null))
        assertNull(warehouseBridgeDialogRequest("""{"type":"confirm","requestId":"bad id"}"""))
        assertNull(warehouseBridgeDialogRequest("""{"type":"toast","requestId":"t_1"}"""))
    }

    // ---------------------------------------------------------------------------
    // 回应矩阵：确认 / 取消 / 超时（= 脚本窗口结束的取消回话）
    // ---------------------------------------------------------------------------

    @Test
    fun `confirm 确认回 true 取消回 false`() {
        assertEquals("true", warehouseBridgeConfirmAnswer("c1", confirmed = true).jsonValue)
        assertEquals("false", warehouseBridgeConfirmAnswer("c1", confirmed = false).jsonValue)
    }

    @Test
    fun `prompt 保存回带引号字符串 取消回 null`() {
        assertEquals("\"2026\"", warehouseBridgePromptAnswer("p1", "2026").jsonValue)
        assertEquals("\"a\\\"b\"", warehouseBridgePromptAnswer("p1", "a\"b").jsonValue)
        assertEquals("null", warehouseBridgePromptAnswer("p1", null).jsonValue)
    }

    @Test
    fun `单选保存回下标数字 取消回 null`() {
        assertEquals("1", warehouseBridgeSelectionAnswer("s1", 1).jsonValue)
        assertEquals("null", warehouseBridgeSelectionAnswer("s1", null).jsonValue)
    }

    @Test
    fun `保存配置落盘成功回 true 取消回 false`() {
        assertEquals("true", warehouseBridgeSaveConfigAnswer("f1", saved = true).jsonValue)
        assertEquals("false", warehouseBridgeSaveConfigAnswer("f1", saved = false).jsonValue)
    }

    @Test
    fun `超时与脚本窗口结束时挂起请求按取消值回话`() {
        // 四种交互的「超时回话」都必须与旧版「用户取消」的回传结构完全一致：
        // cancelPendingDialog 用的就是这个工厂（宿主接线由下方守卫钉住）。
        val confirm = warehouseBridgeDialogRequest("""{"type":"confirm","requestId":"c_t"}""")!!
        assertEquals("false", warehouseBridgeDialogCancelAnswer(confirm).jsonValue)

        val prompt = warehouseBridgeDialogRequest("""{"type":"prompt","requestId":"p_t"}""")!!
        assertEquals("null", warehouseBridgeDialogCancelAnswer(prompt).jsonValue)

        val selection = warehouseBridgeDialogRequest("""{"type":"singleSelection","requestId":"s_t"}""")!!
        assertEquals("null", warehouseBridgeDialogCancelAnswer(selection).jsonValue)

        val config = warehouseBridgeDialogRequest(
            """{"type":"saveCourseConfig","requestId":"f_t","payload":"{}"}""",
        )!!
        assertEquals("false", warehouseBridgeDialogCancelAnswer(config).jsonValue)
    }

    // ---------------------------------------------------------------------------
    // 多字段表单：编辑 → 重组值树
    // ---------------------------------------------------------------------------

    @Test
    fun `表单编辑初值来自网页 重组后保持字段序`() {
        val request = warehouseBridgeDialogRequest(
            """{"type":"saveCourseConfig","requestId":"cfg_2_a","payload":""" +
                """"{\"semesterTotalWeeks\":20,\"semesterStartDate\":\"2026-09-07\",\"autoMerge\":true,\"extra\":{\"nested\":1}}"}""",
        ) as WarehouseBridgeDialogRequest.SaveConfig

        val edits = warehouseBridgeFormFieldEdits(request.fields)
        // 初值 = 网页原值（文本字段进输入框、数字字段可编辑）。
        assertEquals("20", edits.first { it.key == "semesterTotalWeeks" }.text)
        assertEquals("2026-09-07", edits.first { it.key == "semesterStartDate" }.text)
        assertEquals(true, edits.first { it.key == "autoMerge" }.flagValue)

        // 用户改了周数、切了开关、日期没动、嵌套对象原样保留。
        val edited = edits.map {
            when (it.key) {
                "semesterTotalWeeks" -> it.copy(text = "18")
                "autoMerge" -> it.withFlagValue(false)
                else -> it
            }
        }
        val values = warehouseBridgeFormValues(edited)
        assertEquals(18L, values["semesterTotalWeeks"])
        assertEquals("2026-09-07", values["semesterStartDate"])
        assertEquals(false, values["autoMerge"])
        // LinkedHashMap 保持网页字段序（回传与落盘都按原序读）。
        assertEquals(
            listOf("semesterTotalWeeks", "semesterStartDate", "autoMerge", "extra"),
            values.keys.toList(),
        )
    }

    @Test
    fun `表单数字输坏回原值 不把配置悄悄改没`() {
        val edits = warehouseBridgeFormFieldEdits(
            listOf(WarehouseBridgeFormField("semesterTotalWeeks", 20L)),
        )
        val broken = listOf(edits.first().copy(text = "abc"))
        assertEquals(20L, warehouseBridgeFormValues(broken)["semesterTotalWeeks"])

        // 小数输入按 Double 收（对齐脚本可能下发 1.5 这类值）。
        val decimal = listOf(edits.first().copy(text = "18.5"))
        assertEquals(18.5, warehouseBridgeFormValues(decimal)["semesterTotalWeeks"])
    }

    // ---------------------------------------------------------------------------
    // 落盘白名单（对齐 Dart WarehouseCourseConfigLogic.resolve）
    // ---------------------------------------------------------------------------

    @Test
    fun `落盘只收白名单字段且非法值不覆盖`() {
        val ok = warehouseCourseConfigResolution(
            mapOf(
                "semesterTotalWeeks" to 20L,
                "semesterStartDate" to "2026-09-07",
                "firstDayOfWeek" to 1L,
            ),
        )
        assertEquals(20, ok.semesterWeekCount)
        assertEquals(9, ok.semesterStartDate?.monthValue)
        assertEquals(7, ok.semesterStartDate?.dayOfMonth)

        // 0 / 负数 / 字符串小数 = 「脚本没下发」，保持用户现值（null）。
        assertNull(warehouseCourseConfigResolution(mapOf("semesterTotalWeeks" to 0L)).semesterWeekCount)
        assertNull(warehouseCourseConfigResolution(mapOf("semesterTotalWeeks" to -3L)).semesterWeekCount)
        assertNull(warehouseCourseConfigResolution(mapOf("semesterTotalWeeks" to "20.5")).semesterWeekCount)
        // 字符串数字宽容收下（对齐 coerceInt）。
        assertEquals(20, warehouseCourseConfigResolution(mapOf("semesterTotalWeeks" to "20")).semesterWeekCount)

        // 溢出日期拒绝（2026-13-45 不许滚动成 2027），非日期拒绝。
        assertNull(warehouseCourseConfigResolution(mapOf("semesterStartDate" to "2026-13-45")).semesterStartDate)
        assertNull(warehouseCourseConfigResolution(mapOf("semesterStartDate" to "2026-02-30")).semesterStartDate)
        assertNull(warehouseCourseConfigResolution(mapOf("semesterStartDate" to "not-a-date")).semesterStartDate)
        // 空字段 = 什么都不写。
        assertFalse(warehouseCourseConfigResolution(emptyMap<Any?, Any?>()).hasAnything)
    }

    // ---------------------------------------------------------------------------
    // 降级路径仍在（真拿不到 UI 时的确定兜底）
    // ---------------------------------------------------------------------------

    @Test
    fun `降级默认值口径不变`() {
        assertEquals("true", warehouseBridgeFallbackAnswer("""{"type":"confirm","requestId":"c_d"}""")?.jsonValue)
        assertEquals("\"2026\"", warehouseBridgeFallbackAnswer(
            """{"type":"prompt","requestId":"p_d","defaultValue":"2026"}""",
        )?.jsonValue)
        assertEquals("0", warehouseBridgeFallbackAnswer("""{"type":"singleSelection","requestId":"s_d"}""")?.jsonValue)
        // savePresetTimeSlots 与没接仓储的 saveCourseConfig 都靠这条回 false。
        assertEquals(
            "false",
            warehouseBridgeFallbackAnswer("""{"type":"savePresetTimeSlots","requestId":"x_d","payload":"[]"}""")?.jsonValue,
        )
        assertEquals(
            "false",
            warehouseBridgeFallbackAnswer("""{"type":"saveCourseConfig","requestId":"y_d","payload":"{}"}""")?.jsonValue,
        )
    }

    // ---------------------------------------------------------------------------
    // 宿主接线守卫（composeP1 不在 L0 编译范围，接线事实按源码结构判）
    // ---------------------------------------------------------------------------

    private val hostSource: String by lazy { readSource("WarehouseWebLoginHost.kt") }
    private val dialogHostSource: String by lazy { readSource("WarehouseBridgeDialogHost.kt") }

    @Test
    fun `宿主必须在脚本窗口结束时排空挂起弹层`() {
        // complete / error / 新导航 / 重新执行四个窗口结束点都要 drain，
        // 少任何一处，脚本 Promise 就会在那一种情形下悬死。
        listOf(
            "cancelPendingDialog(\"complete\")",
            "cancelPendingDialog(\"error\")",
            "cancelPendingDialog(\"page navigation\")",
            "cancelPendingDialog(\"re-execute\")",
        ).forEach { marker ->
            assertTrue("脚本窗口结束点缺排空：$marker", hostSource.contains(marker))
        }
    }

    @Test
    fun `宿主必须挂原生对话框宿主并按用户动作回话`() {
        assertTrue("必须挂 WarehouseBridgeDialogHost", hostSource.contains("WarehouseBridgeDialogHost("))
        assertTrue("对话框消息必须先尝试解析成原生请求", hostSource.contains("warehouseBridgeDialogRequest(raw)"))
        assertTrue("保存配置必须走白名单落盘解析", hostSource.contains("warehouseCourseConfigResolution("))
        assertTrue("回话必须经 resolve 脚本注入", hostSource.contains("warehouseBridgeResolveScript("))
        // 降级路径不许删：解析不出界面时仍要按默认值回话。
        assertTrue("降级路径必须保留", hostSource.contains("handleDialogFallback(raw)"))
    }

    @Test
    fun `对话框宿主必须常驻组合且 show 由请求驱动`() {
        assertTrue("弹层必须常驻组合（不许条件挂载）", dialogHostSource.contains("var shown by remember"))
        assertTrue("confirm 必须用官方 OverlayDialog", dialogHostSource.contains("OverlayDialog("))
        assertTrue("OverlayDialog 必须显式传本仓 insideMargin", dialogHostSource.contains("DpSize(16.dp, 16.dp)"))
        assertTrue("prompt 与单选必须走共享弹层套件", dialogHostSource.contains("QingyuSheet("))
    }

    private fun readSource(fileName: String): String {
        val relative = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/$fileName"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到源码 $relative（当前目录 ${File("").absolutePath}）")
    }
}
