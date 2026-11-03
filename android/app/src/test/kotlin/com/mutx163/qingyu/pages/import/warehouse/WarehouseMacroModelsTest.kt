package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 宏数据模型测试（P1 / N1 + N6 key）。
 *
 * 对拍参照：`lib/models/warehouse_macro_models.dart`（只读）。序列化脱敏与
 * 「认不出 type 抛异常」是本文件的隐私 / 正确性承诺，反例用例钉死。
 */
class WarehouseMacroModelsTest {

    // ---------------------------------------------------------------------
    // toJson 序列化脱敏
    // ---------------------------------------------------------------------

    @Test
    fun `敏感字段 fillField 序列化不写 value`() {
        val secret = "P@ssw0rd-泄露样本"
        val step = WarehouseMacroStep.fillField(selector = "#pwd", value = secret, fieldType = "password")
        val json = step.toJson()
        assertNull("password 的 value 不允许出现在序列化结果里", json["value"])
        val encoded = MiniJson.encode(json)
        assertFalse("编码后的文本也不允许出现敏感值", encoded.contains(secret))
        assertEquals("fillField", json["type"])
        assertEquals("#pwd", json["selector"])
        assertEquals("password", json["fieldType"])
    }

    @Test
    fun `captcha 字段同样不写 value 普通字段保留 value`() {
        val captcha = WarehouseMacroStep.fillField("#code", "8391", "captcha")
        assertNull(captcha.toJson()["value"])

        val normal = WarehouseMacroStep.fillField("#user", "20230001", "username")
        assertEquals("20230001", normal.toJson()["value"])
    }

    @Test
    fun `非 fillField 类型不受脱敏影响`() {
        val navigate = WarehouseMacroStep.navigate("http://jw.example.edu.cn/login")
        assertEquals("http://jw.example.edu.cn/login", navigate.toJson()["value"])
    }

    // ---------------------------------------------------------------------
    // fromJson 还原与坏数据
    // ---------------------------------------------------------------------

    @Test
    fun `敏感 fillField 读回归原成 waitForManualInput`() {
        val step = WarehouseMacroStep.fillField("#pwd", "whatever", "password")
        val restored = WarehouseMacroStep.fromJson(step.toJson())
        assertEquals(WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT, restored.type)
        assertEquals("manual_input_password", restored.value)
        assertEquals("#pwd", restored.selector)
        assertEquals("password", restored.fieldType)

        val captcha = WarehouseMacroStep.fillField("#code", "8391", "captcha")
        val restoredCaptcha = WarehouseMacroStep.fromJson(captcha.toJson())
        assertEquals("manual_input_captcha", restoredCaptcha.value)
    }

    @Test
    fun `waitForManualInput 缺 fieldType 时按 reason 反推`() {
        val step = WarehouseMacroStep(
            type = WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT,
            value = "manual_input_captcha",
        )
        val restored = WarehouseMacroStep.fromJson(
            MiniJson.tryParse(step.encode()) as Map<*, *>,
        )
        assertEquals("captcha", restored.fieldType)

        val passwordStep = WarehouseMacroStep.fromJson(
            MiniJson.tryParse(
                WarehouseMacroStep(
                    type = WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT,
                    value = "manual_input_password",
                ).encode(),
            ) as Map<*, *>,
        )
        assertEquals("password", passwordStep.fieldType)
    }

    @Test
    fun `认不出的 type 抛异常 绝不兜成 delay`() {
        val bad = linkedMapOf<String, Any?>("type" to "waitForStarPhase")
        try {
            WarehouseMacroStep.fromJson(bad)
            throw AssertionError("认不出的 type 必须抛 WarehouseMacroFormatException")
        } catch (_: WarehouseMacroFormatException) {
            // 预期
        }
    }

    @Test
    fun `坏条目诊断 丢弃计数正确 其余照常`() {
        val stepsJson = listOf(
            MiniJson.tryParse(WarehouseMacroStep.click("#ok").encode()),
            "not-a-map",
            MiniJson.tryParse("""{"type":"waitForStarPhase"}"""),
            MiniJson.tryParse(WarehouseMacroStep.delay(300).encode()),
        )
        val result = parseWarehouseMacroStepsWithDiagnostics(stepsJson)
        assertEquals(2, result.steps.size)
        assertEquals(2, result.droppedStepCount)
    }

    @Test
    fun `steps 不是数组时按空处理零丢弃`() {
        val result = parseWarehouseMacroStepsWithDiagnostics("garbage")
        assertEquals(0, result.steps.size)
        assertEquals(0, result.droppedStepCount)
    }

    // ---------------------------------------------------------------------
    // 记录 round-trip 与 Dart 兼容
    // ---------------------------------------------------------------------

    private fun sampleRecord(): WarehouseMacroRecord {
        val now = java.time.LocalDateTime.parse("2026-11-03T09:30:00")
        return WarehouseMacroRecord(
            schoolId = "school-a",
            adapterId = "zf-soft",
            schoolName = "示例大学",
            adapterName = "正方教务",
            importUrl = "http://jw.example.edu.cn/login",
            schoolResourceFolder = "school-a",
            adapterAssetJsPath = "resources/school-a/zf-soft.js",
            steps = listOf(
                WarehouseMacroStep.fillField("#user", "20230001", "username"),
                WarehouseMacroStep.waitForManualInput("manual_input_password", "#pwd", "password"),
                WarehouseMacroStep.click("#loginBtn"),
                WarehouseMacroStep.delay(2500),
            ),
            dialogResponses = linkedMapOf(
                "confirm|确认导入|" to true,
                "replaceExisting" to false,
                "semesterConfig" to linkedMapOf<String, Any?>(
                    "startDate" to "2026-09-01",
                    "firstCourseWeek" to 2,
                ),
            ),
            createdAt = now,
            updatedAt = now,
            successfulImportCount = 3,
            scriptPageUrl = "http://jw.example.edu.cn/xsMain.jsp",
            useDesktopMode = true,
        )
    }

    @Test
    fun `记录 encode 解码 round-trip 内容一致`() {
        val record = sampleRecord()
        val restored = WarehouseMacroRecord.fromJson(
            MiniJson.tryParse(record.encode()) as Map<*, *>,
        )
        assertEquals(record, restored)
        // 二次编码稳定（写盘幂等）
        assertEquals(record.encode(), restored.encode())
    }

    @Test
    fun `Dart 风格时间戳与可空字段兼容`() {
        // Dart toIso8601String 本地时间 + 微秒；scriptPageUrl / useDesktopMode 可缺省。
        val dartJson = """
            {"schoolId":"s1","adapterId":"a1","schoolName":"S","adapterName":"A",
             "importUrl":"http://jw.example.edu.cn/login?jsessionid=ABC",
             "schoolResourceFolder":"s1","adapterAssetJsPath":"a.js",
             "steps":[{"type":"click","selector":"#btn"}],
             "dialogResponses":{"confirm|x|y":true},
             "createdAt":"2026-11-03T09:30:00.123456",
             "updatedAt":"2026-11-03T09:30:00.123456",
             "successfulImportCount":1,
             "useDesktopMode":false}
        """.trimIndent()
        val record = WarehouseMacroRecord.fromJson(MiniJson.tryParse(dartJson) as Map<*, *>)
        assertEquals(java.time.LocalDateTime.parse("2026-11-03T09:30:00.123456"), record.createdAt)
        assertEquals(false, record.useDesktopMode)
        assertNull(record.scriptPageUrl)
        // importUrl 不脱敏（原样），scriptPageUrl 读入即脱敏
        assertEquals("http://jw.example.edu.cn/login?jsessionid=ABC", record.importUrl)
    }

    @Test
    fun `scriptPageUrl 读入即过脱敏`() {
        val record = sampleRecord()
            .copyWith(scriptPageUrl = "http://jw.example.edu.cn/xsMain.jsp?jsessionid=XYZ")
        val restored = WarehouseMacroRecord.fromJson(
            MiniJson.tryParse(record.encode()) as Map<*, *>,
        )
        assertEquals("http://jw.example.edu.cn/xsMain.jsp", restored.scriptPageUrl)
    }

    @Test
    fun `坏时间戳回退纪元不崩`() {
        val json = """
            {"schoolId":"s1","adapterId":"a1","schoolName":"S","adapterName":"A",
             "importUrl":"u","schoolResourceFolder":"s1","adapterAssetJsPath":"a",
             "steps":[],"createdAt":"not-a-date","updatedAt":null}
        """.trimIndent()
        val record = WarehouseMacroRecord.fromJson(MiniJson.tryParse(json) as Map<*, *>)
        assertEquals(WarehouseMacroRecord.DART_EPOCH, record.createdAt)
        assertEquals(WarehouseMacroRecord.DART_EPOCH, record.updatedAt)
    }

    // ---------------------------------------------------------------------
    // 存储键名（D1：与 Dart 逐字一致）
    // ---------------------------------------------------------------------

    @Test
    fun `存储键名与 Dart 逐字一致`() {
        assertEquals(
            "warehouse_macro_record_s1_a1",
            WarehouseMacroRecord.storageKey("s1", "a1"),
        )
        assertEquals(
            "warehouse_macro_record_",
            WarehouseMacroRecord.RECORD_KEY_PREFIX,
        )
        assertEquals(
            "warehouse_macro_record_index",
            WarehouseMacroRecord.INDEX_KEY,
        )
    }

    // ---------------------------------------------------------------------
    // 弹窗应答 key（N6）
    // ---------------------------------------------------------------------

    @Test
    fun `dialogId 优先于标题正文`() {
        val key = warehouseDialogResponseKey(
            "confirm",
            linkedMapOf(
                "dialogId" to "d-42",
                "title" to "T",
                "message" to "M",
            ),
        )
        assertEquals("confirm|id:d-42", key)
    }

    @Test
    fun `无 dialogId 用 标题竖线正文`() {
        assertEquals(
            "prompt|输入年份|请输入 4 位年份",
            warehouseDialogResponseKey(
                "prompt",
                linkedMapOf("title" to "输入年份", "message" to "请输入 4 位年份"),
            ),
        )
        // message 缺失回退 optionsJson
        assertEquals(
            "singleSelection|选择|选项A,选项B",
            warehouseDialogResponseKey(
                "singleSelection",
                linkedMapOf("title" to "选择", "optionsJson" to "选项A,选项B"),
            ),
        )
        // 全缺 → 尾随空段
        assertEquals("confirm||", warehouseDialogResponseKey("confirm", emptyMap<Any?, Any?>()))
    }

    @Test
    fun `非字符串字段一律当没给 不抛异常`() {
        // 脚本把 title / optionsJson 发成对象/数组时不能打断桥回调（Dart 修过的 TypeError）
        val key = warehouseDialogResponseKey(
            "singleSelection",
            linkedMapOf<String, Any?>(
                "title" to listOf("a", "b"),
                "optionsJson" to linkedMapOf("nested" to true),
            ),
        )
        assertEquals("singleSelection||", key)
    }

    // ---------------------------------------------------------------------
    // 索引条目
    // ---------------------------------------------------------------------

    @Test
    fun `索引条目 round-trip`() {
        val entry = WarehouseMacroIndexEntry(
            schoolId = "s1",
            adapterId = "a1",
            updatedAt = java.time.LocalDateTime.parse("2026-11-03T10:00:00"),
        )
        val restored = WarehouseMacroIndexEntry.fromJson(
            MiniJson.tryParse(MiniJson.encode(entry.toJson())) as Map<*, *>,
        )
        assertEquals(entry, restored)
        assertNotNull(restored)
    }
}
