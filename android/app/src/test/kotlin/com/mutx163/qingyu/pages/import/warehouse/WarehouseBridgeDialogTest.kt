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
    // toast / error 的正文提取
    // ---------------------------------------------------------------------------

    @Test
    fun `toast 与 error 从消息里取 message 原文 空与坏载荷回 null`() {
        assertEquals(
            "正在获取课表…",
            warehouseBridgeMessageText("""{"type":"toast","message":"正在获取课表…"}"""),
        )
        assertEquals(
            // 两侧空格被 trim（脚本文案带空白不进轻提示）。
            "week table not found",
            warehouseBridgeMessageText("""{"type":"error","message":" week table not found "}"""),
        )
        // 空串 / 缺字段 / 坏 JSON：toast 丢掉、error 落兜底。
        assertNull(warehouseBridgeMessageText("""{"type":"toast","message":"   "}"""))
        assertNull(warehouseBridgeMessageText("""{"type":"error"}"""))
        assertNull(warehouseBridgeMessageText("not json"))
        assertNull(warehouseBridgeMessageText(null))
        // 非字符串 message 不当文本展示。
        assertNull(warehouseBridgeMessageText("""{"type":"toast","message":123}"""))
    }

    // ---------------------------------------------------------------------------
    // courses 写回：周次平移 + 学期周数扩容（对齐 Dart ImportWeekAlignmentService）
    // ---------------------------------------------------------------------------

    @Test
    fun `平移偏移为0时课程原样返回`() {
        val courses = listOf(testCourse(startWeek = 3, endWeek = 18))
        val shifted = warehouseShiftCoursesToFirstWeek(courses, firstCourseWeek = 1)
        assertEquals(3, shifted[0].startWeek)
        assertEquals(18, shifted[0].endWeek)
    }

    @Test
    fun `区间式周次整体平移 奇数偏移时单双周互换`() {
        val oddWeeks = testCourse(startWeek = 1, endWeek = 15, isOddWeek = true)
        val shiftedBy1 = warehouseShiftCoursesToFirstWeek(listOf(oddWeeks), firstCourseWeek = 2)[0]
        // 1,3,5…15 顺延一周变 2,4,…16：单周课变双周课。
        assertEquals(2, shiftedBy1.startWeek)
        assertEquals(16, shiftedBy1.endWeek)
        assertTrue(shiftedBy1.isEvenWeek)
        assertFalse(shiftedBy1.isOddWeek)

        val shiftedBy2 = warehouseShiftCoursesToFirstWeek(listOf(oddWeeks), firstCourseWeek = 3)[0]
        assertEquals(3, shiftedBy2.startWeek)
        assertTrue(shiftedBy2.isOddWeek)
        assertFalse(shiftedBy2.isEvenWeek)
    }

    @Test
    fun `自定义周次表逐周平移重排并清掉单双周标志`() {
        val custom = testCourse(startWeek = 1, endWeek = 5, customWeeks = listOf(1, 3, 5))
        val shifted = warehouseShiftCoursesToFirstWeek(listOf(custom), firstCourseWeek = 3)[0]
        assertEquals(listOf(3, 5, 7), shifted.customWeeks)
        assertEquals(3, shifted.startWeek)
        assertEquals(7, shifted.endWeek)
        assertFalse(shifted.isOddWeek)
        assertFalse(shifted.isEvenWeek)
    }

    @Test
    fun `学期周数取课程最靠后的一周 空表用现值 越界收进上限`() {
        assertEquals(20, warehouseMaxCourseWeek(emptyList(), fallbackWeekCount = 20))
        val courses = listOf(
            testCourse(startWeek = 1, endWeek = 16),
            testCourse(startWeek = 2, endWeek = 18, customWeeks = listOf(2, 6, 21)),
        )
        // 自定义周次表的末项（21）才是最靠后的周。
        assertEquals(21, warehouseMaxCourseWeek(courses, fallbackWeekCount = 20))
        assertEquals(30, warehouseMaxCourseWeek(courses, fallbackWeekCount = 20) + 9)
    }

    // ---------------------------------------------------------------------------
    // saveCourseConfig 收不下的键：记日志不静默（F32 顺手项）
    // ---------------------------------------------------------------------------

    @Test
    fun `不支持的配置键按名单识别 值为null视为没下发`() {
        val ignored = warehouseUnsupportedCourseConfigKeysIn(
            mapOf(
                "semesterTotalWeeks" to 20L,
                "firstDayOfWeek" to 1L,
                "defaultClassDuration" to 45L,
            ),
        )
        assertEquals(listOf("firstDayOfWeek", "defaultClassDuration"), ignored)
        assertTrue(warehouseUnsupportedCourseConfigKeysIn(mapOf("firstDayOfWeek" to null)).isEmpty())
        assertTrue(warehouseUnsupportedCourseConfigKeysIn(emptyMap<Any?, Any?>()).isEmpty())
    }

    // ---------------------------------------------------------------------------
    // 宿主接线守卫（composeP1 不在 L0 编译范围，接线事实按源码结构判）
    // ---------------------------------------------------------------------------

    private val hostSource: String by lazy { readSource("composeP1", "WarehouseWebLoginHost.kt") }
    private val dialogHostSource: String by lazy { readSource("composeP1", "WarehouseBridgeDialogHost.kt") }
    private val importDialogsSource: String by lazy { readSource("composeP1", "WarehouseCoursesImportDialogs.kt") }

    /** courses 收尾落盘层在 `main` 源集（扩节/周数自动扩随实现收进了模型层）。 */
    private val applySource: String by lazy { readSource("main", "WarehouseCoursesImportApply.kt") }

    @Test
    fun `courses 写回前必须问两步并按用户选择平移写回`() {
        assertTrue("必须持有待确认课程包状态", hostSource.contains("coursesSession"))
        assertTrue("必须问覆盖还是更新", hostSource.contains("WarehouseReplaceExistingDialog("))
        assertTrue("必须确认开学日与首周", hostSource.contains("WarehouseSemesterMappingSheet("))
        assertTrue("写回前必须按首周平移", hostSource.contains("warehouseShiftCoursesToFirstWeek("))
        assertTrue(
            "收尾落盘必须走 WarehouseCoursesImportApply（扩节与失败回滚在模型层收口）",
            hostSource.contains("WarehouseCoursesImportApply.apply("),
        )
        assertTrue(
            "周数不够必须自动扩（对齐旧版 importParsedCourses；判据随实现收在收尾层）",
            applySource.contains("warehouseMaxCourseWeek("),
        )
        assertTrue(
            "用户选择必须传给 requestedMode",
            applySource.contains("requestedMode = if (request.replaceExisting)"),
        )
        assertTrue(
            "取消必须结束导入执行期（interrupted 区分第三步取消落「导入已中断」）",
            hostSource.contains("fun cancelCoursesImport("),
        )
    }

    @Test
    fun `toast 与 error 必须消费脚本给的原文`() {
        assertTrue("toast 分支必须取 message 原文", hostSource.contains("warehouseBridgeMessageText(raw)"))
        assertTrue("error 缺省必须兜底固定文案", hostSource.contains("?: WarehouseStrings.courseImportScriptFailed.zh"))
    }

    @Test
    fun `对话框宿主必须常驻组合且 show 由请求驱动`() {
        assertTrue("弹层必须常驻组合（不许条件挂载）", dialogHostSource.contains("var shown by remember"))
        assertTrue("confirm 必须用官方 OverlayDialog", dialogHostSource.contains("OverlayDialog("))
        assertTrue("OverlayDialog 必须显式传本仓 insideMargin", dialogHostSource.contains("DpSize(16.dp, 16.dp)"))
        assertTrue("prompt 与单选必须走共享弹层套件", dialogHostSource.contains("QingyuSheet("))
        assertTrue("替换/合并弹窗必须显式 insideMargin", importDialogsSource.contains("DpSize(16.dp, 16.dp)"))
    }

    /** 课程构造的测试助手：只给周次相关的最小字段。 */
    private fun testCourse(
        startWeek: Int,
        endWeek: Int,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
    ) = com.mutx163.qingyu.core.Course(
        id = "course-test",
        name = "数学",
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startWeek = startWeek,
        endWeek = endWeek,
        startTime = "",
        endTime = "",
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
    )

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

    private fun readSource(sourceSet: String, fileName: String): String {
        val relative = "android/app/src/$sourceSet/kotlin/com/mutx163/qingyu/pages/import/warehouse/$fileName"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return stripKotlinComments(candidate.readText(Charsets.UTF_8))
            dir = dir?.parentFile
        }
        error("找不到源码 $relative（当前目录 ${File("").absolutePath}）")
    }

    /**
     * 剥掉行注释与斜杠星块注释再判（正本在 `ComposeSheetGuardTest.stripKotlinComments`）：
     * 把守卫判据那行注释掉不算还接着线（2026-11-03 宿主接线守卫咬合探针同款洞）；
     * 块注释按 Kotlin 语义可嵌套；字符串字面量（含转义）原样保留，
     * `"https://…"` 不会把行尾真参吃掉。
     */
    private fun stripKotlinComments(source: String): String {
        val sb = StringBuilder(source.length)
        var i = 0
        var inLineComment = false
        var inBlockComment = false
        var blockDepth = 0
        var stringQuote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                inBlockComment -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        i += 2
                        if (blockDepth == 0) inBlockComment = false
                    } else {
                        if (ch == '\n') sb.append(ch)
                        i++
                    }
                }
                stringQuote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < source.length) {
                        sb.append(source[i + 1])
                        i += 2
                    } else {
                        if (ch == stringQuote) stringQuote = null
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    inLineComment = true
                    sb.append(' ')
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
                    sb.append(' ')
                    i += 2
                }
                ch == '"' || ch == '\'' -> {
                    stringQuote = ch
                    sb.append(ch)
                    i++
                }
                else -> {
                    sb.append(ch)
                    i++
                }
            }
        }
        return sb.toString()
    }
}
