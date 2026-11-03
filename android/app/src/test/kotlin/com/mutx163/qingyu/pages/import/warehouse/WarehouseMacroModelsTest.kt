package com.mutx163.qingyu.pages.import.warehouse

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * I2-4：宏数据模型（逐字对齐 Dart `warehouse_macro_models.dart`）的契约测试。
 *
 * 钉住的是**与 Dart 共享存档的兼容性**：键名、缺省、脱敏、未知类型抛错，
 * 任何一条改了，Flutter/Compose 两个界面就会写出互不相认的宏。
 */
class WarehouseMacroModelsTest {

    // ---------- WarehouseMacroStep ----------

    @Test
    fun `步骤 toJson 省略空字段与零 waitMs`() {
        val step = WarehouseMacroStep.click("#login")
        assertEquals(
            mapOf("type" to "click", "selector" to "#login"),
            step.toJson(),
        )
    }

    @Test
    fun `敏感 fillField 的 value 不落盘`() {
        val step = WarehouseMacroStep.fillField("#pwd", "secret123", fieldType = "password")
        val json = step.toJson()
        assertFalse(json.containsKey("value"))
        assertEquals("fillField", json["type"])
        assertEquals("password", json["fieldType"])
    }

    @Test
    fun `fromJson 把敏感 fillField 修复成 waitForManualInput`() {
        val step = WarehouseMacroStep.fromJson(
            mapOf(
                "type" to "fillField",
                "selector" to "#pwd",
                "fieldType" to "password",
                "value" to "secret123",
            ),
        )
        assertEquals(WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT, step.type)
        assertEquals("manual_input_password", step.value)
        assertEquals("#pwd", step.selector)
        assertEquals("password", step.fieldType)
    }

    @Test
    fun `fromJson 对认不出的 type 抛异常（不许兜成 delay）`() {
        val error = runCatching {
            WarehouseMacroStep.fromJson(mapOf("type" to "hover", "selector" to "#x"))
        }.exceptionOrNull()
        assertTrue(error is IllegalArgumentException)
        assertEquals("macro_step_type_unrecognized", error?.message)
    }

    @Test
    fun `fromJson 修复旧宏 waitForManualInput 缺失的 fieldType`() {
        val captcha = WarehouseMacroStep.fromJson(
            mapOf("type" to "waitForManualInput", "value" to "manual_input_captcha"),
        )
        assertEquals("captcha", captcha.fieldType)

        val password = WarehouseMacroStep.fromJson(
            mapOf("type" to "waitForManualInput", "value" to "manual_input_password"),
        )
        assertEquals("password", password.fieldType)
    }

    @Test
    fun `步骤 round trip 保持类型与字段`() {
        val original = WarehouseMacroStep.waitForUrl("**/xsMain**")
        val restored = WarehouseMacroStep.fromJson(original.toJson())
        assertEquals(original, restored)
    }

    // ---------- 步骤列表解析（坏条目整条丢弃） ----------

    @Test
    fun `parseWithDiagnostics 丢弃坏条目并报数`() {
        val parsed = parseWarehouseMacroStepsWithDiagnostics(
            listOf(
                mapOf("type" to "click", "selector" to "#a"),
                "not-a-map",
                mapOf("type" to "nonsense"),
                mapOf("type" to "delay", "waitMs" to 300),
            ),
        )
        assertEquals(2, parsed.steps.size)
        assertEquals(2, parsed.droppedStepCount)
    }

    // ---------- WarehouseMacroRecord ----------

    @Test
    fun `记录 toJson 键与 Dart 逐字一致 且可逆`() {
        val record = WarehouseMacroRecord(
            schoolId = "cqu",
            adapterId = "cqu-jwxt",
            schoolName = "示例大学",
            adapterName = "教务系统",
            importUrl = "https://jw.example.edu.cn/",
            schoolResourceFolder = "cqu",
            adapterAssetJsPath = "cqu.js",
            steps = listOf(
                WarehouseMacroStep.fillField("#user", "20230001", fieldType = "username"),
                WarehouseMacroStep.click("#login"),
            ),
            dialogResponses = mapOf("replaceExisting" to true),
            createdAt = LocalDateTime.of(2026, 11, 3, 14, 22, 31),
            updatedAt = LocalDateTime.of(2026, 11, 3, 14, 30, 0),
            successfulImportCount = 2,
            scriptPageUrl = "https://jw.example.edu.cn/xsMain",
            useDesktopMode = true,
        )
        val json = record.toJson()
        assertEquals("cqu", json["schoolId"])
        assertEquals("cqu-jwxt", json["adapterId"])
        assertEquals("cqu", json["schoolResourceFolder"])
        assertEquals("cqu.js", json["adapterAssetJsPath"])
        assertEquals(2, json["successfulImportCount"])
        assertEquals("https://jw.example.edu.cn/xsMain", json["scriptPageUrl"])
        assertEquals(true, json["useDesktopMode"])

        val restored = WarehouseMacroRecord.fromJson(json)
        assertEquals(record, restored)
    }

    @Test
    fun `记录缺省字段按 Dart 口径回填`() {
        val restored = WarehouseMacroRecord.fromJson(
            mapOf("schoolId" to "cqu", "adapterId" to "a1"),
        )
        // Dart：schoolResourceFolder 缺键回落 schoolId
        assertEquals("cqu", restored.schoolResourceFolder)
        assertEquals(0, restored.successfulImportCount)
        assertNull(restored.scriptPageUrl)
        assertNull(restored.useDesktopMode)
        assertEquals(LocalDateTime.of(1970, 1, 1, 0, 0), restored.createdAt)
    }

    @Test
    fun `存储键名与 Dart 逐字一致`() {
        assertEquals(
            "warehouse_macro_record_cqu_cqu-jwxt",
            WarehouseMacroRecord.storageKey("cqu", "cqu-jwxt"),
        )
        assertEquals("warehouse_macro_record_", WarehouseMacroRecord.RECORD_KEY_PREFIX)
        assertEquals("warehouse_macro_record_index", WarehouseMacroRecord.INDEX_KEY)
    }

    // ---------- 对话框应答匹配键 ----------

    @Test
    fun `应答键优先用 dialogId`() {
        val key = warehouseDialogResponseKey(
            "confirm",
            mapOf("dialogId" to "termPicker", "title" to "会被忽略"),
        )
        assertEquals("confirm|id:termPicker", key)
    }

    @Test
    fun `应答键无 dialogId 时按 type+title+正文 拼`() {
        val key = warehouseDialogResponseKey(
            "prompt",
            mapOf("title" to "学年", "message" to "请输入学年"),
        )
        assertEquals("prompt|学年|请输入学年", key)
    }

    @Test
    fun `应答键对非字符串字段按没给处理（Dart 的 TypeError 洞）`() {
        val key = warehouseDialogResponseKey(
            "confirm",
            mapOf("title" to mapOf("x" to 1), "message" to listOf("a")),
        )
        assertEquals("confirm||", key)
    }

    // ---------- scriptPageUrl 脱敏 ----------

    @Test
    fun `sanitize 剥掉一次性 query 参数`() {
        assertEquals(
            "https://jw.example.edu.cn/xsMain?xh=20230001",
            sanitizeWarehouseScriptPageUrl(
                "https://jw.example.edu.cn/xsMain?ticket=ST-123&xh=20230001&JSESSIONID=abc",
            ),
        )
    }

    @Test
    fun `sanitize 剥掉路径里的 jsessionid 矩阵参数`() {
        assertEquals(
            "https://jw.example.edu.cn/xsMain",
            sanitizeWarehouseScriptPageUrl("https://jw.example.edu.cn/xsMain;jsessionid=abc123"),
        )
    }

    @Test
    fun `sanitize 处理 host 内嵌 jsessionid（ROOT 应用空路径形态）`() {
        assertEquals(
            "https://jw.example.edu.cn/",
            sanitizeWarehouseScriptPageUrl("https://jw.example.edu.cn;jsessionid=abc123def"),
        )
    }

    @Test
    fun `sanitize 保留 hash 路由但丢弃夹带凭据的 fragment`() {
        assertEquals(
            "https://jw.example.edu.cn/app/#/schedule/semester",
            sanitizeWarehouseScriptPageUrl("https://jw.example.edu.cn/app/#/schedule/semester"),
        )
        assertEquals(
            "https://jw.example.edu.cn/callback",
            sanitizeWarehouseScriptPageUrl("https://jw.example.edu.cn/callback#access_token=tok&state=x"),
        )
    }

    @Test
    fun `sanitize 拒绝非 http(s) 与坏地址`() {
        assertNull(sanitizeWarehouseScriptPageUrl("ftp://jw.example.edu.cn/x"))
        assertNull(sanitizeWarehouseScriptPageUrl("not a url"))
        assertNull(sanitizeWarehouseScriptPageUrl(""))
        assertNull(sanitizeWarehouseScriptPageUrl(null))
    }

    @Test
    fun `volatile 参数名的子串口径（PHP 与 ASP NET 会话键）`() {
        assertTrue(isWarehouseVolatileUrlParamKey("PHPSESSID"))
        assertTrue(isWarehouseVolatileUrlParamKey("ASP.NET_SessionId"))
        assertTrue(isWarehouseVolatileUrlParamKey("oauth_token"))
        assertFalse(isWarehouseVolatileUrlParamKey("xh"))
        assertFalse(isWarehouseVolatileUrlParamKey("week"))
    }
}
