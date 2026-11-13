package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 脱敏规则（纯 JVM）。
 *
 * 为什么单独钉：`WarehouseLogRedaction` 是**入队时**跑的那一道（buffer 里从此没有明文），
 * 规则一旦放宽，「日志能不能发给别人看」就直接失守。这里钉三件事：
 * ① 四类明文（手机号 / 账号 / cookie 值 / 查询串）逐条搜不到；
 * ② URL 只留 `scheme://host`（路径与查询串全丢，另记 `endpoint` 标签）；
 * ③ 掩码形态逐字（`1**********0` / `***` / `cookie(n=1)`）——形态变了就说明规则被动过。
 */
class WarehouseLogRedactionTest {

    private val phone = "13800138000"
    private val account = "Abc123456"
    private val cookie = "JSESSIONID=abcd"
    private val rawUrl = "https://jw.example.edu/xskb/list?token=xyz"

    /** ① 一条含四类明文的记录：脱敏后**逐条**都搜不到。 */
    @Test
    fun `脱敏后逐条搜不到手机号账号cookie值与查询串`() {
        val redacted = WarehouseLogRedaction.redact(
            linkedMapOf(
                "phone" to phone,
                "account" to account,
                "Cookie" to cookie,
                "url" to rawUrl,
            ),
        )
        // 否定式断言先判非空：空串上恒真，会把「规则整个没跑」判成通过。
        assertFalse("脱敏结果为空，后面四条否定断言都会假绿", redacted.isEmpty())
        val text = redacted.entries.joinToString(" ") { "${it.key}=${it.value}" }
        assertTrue("脱敏后的文本居然是空串", text.isNotBlank())
        for (raw in listOf(phone, account, cookie, "abcd", "token=xyz", "xyz")) {
            assertFalse("脱敏后仍能搜到 <$raw>：$text", text.contains(raw))
        }
        // 正向一侧：字段没被整段吃掉（不是靠「什么都不记」蒙混过去）。
        // 注意星号个数：`13800138000` 是 11 位，保留首尾 ⇒ **9 颗星**（长度不变）。
        assertTrue("手机号字段应保留掩码形态：$text", text.contains("1*********0"))
        assertTrue("账号字段应保留掩码形态：$text", text.contains("A*******6"))
        assertTrue("cookie 应折成条数：$text", text.contains("cookie(n=1)"))
    }

    /** ② URL 只留 `scheme://host`：不含 `?`、不含路径片段，另记 endpoint 标签。 */
    @Test
    fun `URL只保留scheme与host并记endpoint标签`() {
        val redacted = WarehouseLogRedaction.redact(mapOf("url" to rawUrl))
        val value = redacted.getValue("url")
        assertEquals("https://jw.example.edu", value)
        assertFalse("URL 里还留着查询串：$value", value.contains("?"))
        assertFalse("URL 里还留着路径：$value", value.contains("/xskb/"))
        assertEquals(WarehouseLogRedaction.ENDPOINT_TIMETABLE, redacted[WarehouseLogRedaction.ENDPOINT_FIELD])
    }

    /** endpoint 三分类：登录页 / 课表接口 / 其它。 */
    @Test
    fun `endpoint三分类按路径判`() {
        assertEquals(
            WarehouseLogRedaction.ENDPOINT_LOGIN,
            WarehouseLogRedaction.endpointLabel("https://jw.example.edu/cas/login?service=x"),
        )
        assertEquals(
            WarehouseLogRedaction.ENDPOINT_TIMETABLE,
            WarehouseLogRedaction.endpointLabel("https://jw.example.edu/xskb/list.do"),
        )
        assertEquals(
            WarehouseLogRedaction.ENDPOINT_OTHER,
            WarehouseLogRedaction.endpointLabel("https://jw.example.edu/a/b"),
        )
    }

    /** ③ 掩码形态逐字：手机号保首尾、口令整遮、cookie 折条数、账号 ≤5 位全遮。 */
    @Test
    fun `掩码形态逐字`() {
        // `13800138000` = 11 位 → 首 1 + 中间 9 颗星 + 尾 0（长度不变，不信可以数）。
        assertEquals(
            "1*********0",
            WarehouseLogRedaction.redact(mapOf("phone" to phone))["phone"],
        )
        assertEquals(
            WarehouseLogRedaction.MASK,
            WarehouseLogRedaction.redact(mapOf("password" to "Abc123456"))["password"],
        )
        assertEquals(
            "cookie(n=1)",
            WarehouseLogRedaction.redact(mapOf("Set-Cookie" to cookie))["Set-Cookie"],
        )
        assertEquals(
            "cookie(n=2)",
            WarehouseLogRedaction.redact(mapOf("Cookie" to "a=1; b=2"))["Cookie"],
        )
        // ≤5 位整遮（太短保首尾等于把值说出来）。
        assertEquals(
            WarehouseLogRedaction.MASK,
            WarehouseLogRedaction.redact(mapOf("account" to "a1234"))["account"],
        )
    }

    /** 自由文本：内联凭据遮掉、内嵌 URL 只留 host、userinfo 一并丢掉。 */
    @Test
    fun `redactText遮内联凭据并只留host`() {
        val text = WarehouseLogRedaction.redactText(
            "failed JSESSIONID=abcd at https://user:pass@jw.example.edu/xskb/list?token=xyz",
        )
        assertTrue(text.isNotBlank())
        for (raw in listOf("abcd", "xyz", "user:pass", "/xskb/")) {
            assertFalse("redactText 没遮住 <$raw>：$text", text.contains(raw))
        }
        assertTrue("host 应当留着（否则等于没信息）：$text", text.contains("https://jw.example.edu"))
    }
}
