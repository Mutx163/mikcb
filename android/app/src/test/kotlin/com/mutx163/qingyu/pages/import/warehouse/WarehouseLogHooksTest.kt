package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日志钩子的**纯逻辑**用例（第 1 步 A 半：桥与 console 的采集）。
 *
 * ## 钉的是这四件事
 *
 * 1. `BRIDGE dir=req` **只带** `dir` / `requestId` / `type`：网页 payload 里的口令、账号、
 *    课表一个字都不许进日志（判据是「字段集合恰好三个」+「值里搜不到 payload 原文」）；
 * 2. `requestId` 是网页给的不可信输入：换行、空格、超长一律在入日志前归一（否则一条日志
 *    能被拆成两行、伪造出假字段）；
 * 3. console 单条**截 500 字符**（超出补省略号）、URL 只留 host、换行折成空格，
 *    截断不许把代理对切成半个；
 * 4. `error` 级 console **额外**落一条 `FAILURE`，其余级别只有一条 `SCRIPT`。
 *
 * 为什么不写「宿主真的调了这些函数」：那属于接线事实，读源码判（见
 * `WarehouseBridgeConsoleWiringGuardTest`）。两份用例的分工与仓库既有守卫一致。
 */
class WarehouseLogHooksTest {

    /** ① 网页桥请求：字段只有三样，payload 原文（口令 / 账号 / 课表）一个都搜不到。 */
    @Test
    fun `bridge request fields never carry the payload`() {
        val raw = """{"type":"prompt","requestId":"prompt_7_alpha","payload":"{\"password\":\"hunter2\",\"account\":\"A123456\"}","defaultValue":"hunter2","message":"math"}"""
        val fields = WarehouseBridgeLog.requestFields(raw)

        assertEquals(WarehouseBridgeLog.DIR_REQUEST, fields[WarehouseBridgeLog.DIR_FIELD])
        assertEquals("prompt_7_alpha", fields[WarehouseBridgeLog.REQUEST_ID_FIELD])
        assertEquals("prompt", fields[WarehouseBridgeLog.TYPE_FIELD])
        // 多一个字段就是漏 payload 的口子，所以判「恰好三个」而不是「包含这三个」。
        assertEquals(
            setOf(
                WarehouseBridgeLog.DIR_FIELD,
                WarehouseBridgeLog.REQUEST_ID_FIELD,
                WarehouseBridgeLog.TYPE_FIELD,
            ),
            fields.keys,
        )

        val joined = fields.values.joinToString(" ")
        assertTrue("log field values must not be blank", joined.isNotBlank())
        listOf("hunter2", "A123456", "payload", "defaultValue", "math").forEach { leaked ->
            assertFalse("payload text leaked into the BRIDGE event: $leaked -> $joined", joined.contains(leaked))
        }
    }

    /** 缺 requestId / 坏 JSON / type 不是字符串：都不许抛，也不许编一个请求号出来。 */
    @Test
    fun `bridge request tolerates missing request id and malformed json`() {
        val noId = WarehouseBridgeLog.requestFields("""{"type":"toast","message":"saved"}""")
        assertFalse(noId.containsKey(WarehouseBridgeLog.REQUEST_ID_FIELD))
        assertEquals("toast", noId[WarehouseBridgeLog.TYPE_FIELD])

        val broken = WarehouseBridgeLog.requestFields("not-json")
        assertEquals(WarehouseBridgeLog.UNKNOWN_TYPE, broken[WarehouseBridgeLog.TYPE_FIELD])
        assertEquals(WarehouseBridgeLog.DIR_REQUEST, broken[WarehouseBridgeLog.DIR_FIELD])
        assertFalse(broken.containsKey(WarehouseBridgeLog.REQUEST_ID_FIELD))

        val nonStringType = """{"type":42,"requestId":"x_1"}"""
        assertEquals(
            WarehouseBridgeLog.UNKNOWN_TYPE,
            WarehouseBridgeLog.requestFields(nonStringType)[WarehouseBridgeLog.TYPE_FIELD],
        )
        // 与门禁取类型同一口径：判不出类型时两侧都回 null（日志侧落 unknown）。
        assertNull(warehouseBridgeMessageType(nonStringType))
        assertEquals("toast", warehouseBridgeMessageType("""{"type":"toast"}"""))
    }

    /** ② requestId 归一：换行/空格换成 `_`，超长截到 128，空值不写字段。 */
    @Test
    fun `request id is normalized before it reaches the log`() {
        val withNewline = WarehouseBridgeLog.requestFields(
            "{\"type\":\"confirm\",\"requestId\":\"a\\nb c\"}",
        )
        val normalized = withNewline.getValue(WarehouseBridgeLog.REQUEST_ID_FIELD)
        assertEquals("a_b_c", normalized)
        assertFalse("newline survived: one event would be split into two log lines", normalized.contains("\n"))

        val long = "r".repeat(WarehouseBridgeLog.MAX_REQUEST_ID_CHARS + 40)
        val truncated = WarehouseBridgeLog.requestFields(
            "{\"type\":\"confirm\",\"requestId\":\"$long\"}",
        ).getValue(WarehouseBridgeLog.REQUEST_ID_FIELD)
        assertEquals(WarehouseBridgeLog.MAX_REQUEST_ID_CHARS, truncated.length)

        val blank = WarehouseBridgeLog.requestFields("""{"type":"confirm","requestId":"   "}""")
        assertFalse(blank.containsKey(WarehouseBridgeLog.REQUEST_ID_FIELD))
    }

    /** ③ 回话方向与两个状态位：正常 / 兜底 / 排空各记各的，不互相冒充。 */
    @Test
    fun `resolved fields mark direction and optional fallback or reason`() {
        val answered = WarehouseBridgeLog.resolvedFields("confirm_1_abc")
        assertEquals(WarehouseBridgeLog.DIR_RESOLVED, answered[WarehouseBridgeLog.DIR_FIELD])
        assertEquals("confirm_1_abc", answered[WarehouseBridgeLog.REQUEST_ID_FIELD])
        assertEquals(
            setOf(WarehouseBridgeLog.DIR_FIELD, WarehouseBridgeLog.REQUEST_ID_FIELD),
            answered.keys,
        )

        val fallback = WarehouseBridgeLog.resolvedFields("confirm_1_abc", fallback = true)
        assertEquals("true", fallback[WarehouseBridgeLog.FALLBACK_FIELD])
        assertFalse(fallback.containsKey(WarehouseBridgeLog.REASON_FIELD))

        // 排空原因带空格：值必须归一（导出层按 `key=value` 逐行拼，空格会切断可读性）。
        val drained = WarehouseBridgeLog.resolvedFields("confirm_1_abc", reason = "page navigation")
        assertEquals("page_navigation", drained[WarehouseBridgeLog.REASON_FIELD])
        assertFalse(drained.containsKey(WarehouseBridgeLog.FALLBACK_FIELD))

        // 超时排空走同一条（不需要新分支，也不需要新字段）。
        val timedOut = WarehouseBridgeLog.resolvedFields("confirm_1_abc", reason = "timeout")
        assertEquals("timeout", timedOut[WarehouseBridgeLog.REASON_FIELD])
    }

    /** ④ console：先脱敏再折行——URL 只留 `scheme://host`，查询串与凭据全丢。 */
    @Test
    fun `console message is redacted and folded into one line`() {
        val fields = WarehouseConsoleLog.fields(
            "ERROR",
            "failed at https://jw.example.edu/xskb/list?token=abc123\nsecond line",
        )
        assertEquals(WarehouseConsoleLog.ERROR_LEVEL, fields[WarehouseConsoleLog.LEVEL_FIELD])
        val text = fields.getValue(WarehouseConsoleLog.MESSAGE_FIELD)
        assertEquals("failed at https://jw.example.edu second line", text)
        listOf("xskb", "token=", "abc123", "\n").forEach { leaked ->
            assertFalse("redaction/folding did not apply: $leaked -> $text", text.contains(leaked))
        }
    }

    /** ⑤ console 截断：500 字以内原样；超过则前 500 字 + 省略号（恰好 501）。 */
    @Test
    fun `console message over the cap is truncated to 500 chars plus ellipsis`() {
        val exact = "z".repeat(WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS)
        assertEquals(exact, WarehouseConsoleLog.truncatedText(exact))

        val over = "y".repeat(WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS + 40)
        val truncated = WarehouseConsoleLog.truncatedText(over)
        assertEquals(WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS + 1, truncated.length)
        assertTrue(truncated.endsWith(WAREHOUSE_CONSOLE_MESSAGE_ELLIPSIS))
        assertEquals(
            over.take(WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS),
            truncated.dropLast(WAREHOUSE_CONSOLE_MESSAGE_ELLIPSIS.length),
        )
    }

    /** ⑥ 截断边界不许落在代理对中间（网页 console 里的 emoji）。 */
    @Test
    fun `truncation never splits a surrogate pair`() {
        val emoji = String(Character.toChars(0x1F600))
        val message = "a" + emoji.repeat(300) // 1 + 600 个码元，必然被截
        val truncated = WarehouseConsoleLog.truncatedText(message)
        assertTrue(truncated.endsWith(WAREHOUSE_CONSOLE_MESSAGE_ELLIPSIS))
        assertFalse(
            "truncation split a surrogate pair: the exported text would carry half a character",
            truncated[truncated.length - 2].isHighSurrogate(),
        )
    }

    /** ⑦ 入队：BRIDGE 记录落在 buffer 里，字段仍只有三样（脱敏那道不会补出 payload）。 */
    @Test
    fun `bridge request record lands in the buffer without payload`() {
        val log = WarehouseImportLogBuffer(nowMs = { FIXED_NOW })
        recordWarehouseBridgeRequest(
            """{"type":"courses","requestId":"courses_1_a","payload":"[{\"name\":\"math\"}]"}""",
            log,
        )
        val entry = log.snapshot().runs.single().entries.single()
        assertEquals(WarehouseLogCategory.BRIDGE, entry.category)
        assertEquals(
            setOf(
                WarehouseBridgeLog.DIR_FIELD,
                WarehouseBridgeLog.REQUEST_ID_FIELD,
                WarehouseBridgeLog.TYPE_FIELD,
            ),
            entry.fields.keys,
        )
        assertFalse(entry.fields.values.joinToString(" ").contains("math"))
    }

    /** ⑧ 三种回话各自入库：正常 / 兜底 / 排空（含 `reason=timeout`）。 */
    @Test
    fun `resolved records distinguish answered fallback and drained`() {
        val log = WarehouseImportLogBuffer(nowMs = { FIXED_NOW })
        recordWarehouseBridgeResolved("answered_1", log)
        recordWarehouseBridgeFallback("fallback_1", log)
        recordWarehouseBridgeDrain("drained_1", "timeout", log)

        val entries = log.snapshot().runs.single().entries
        assertEquals(3, entries.size)
        assertEquals(
            listOf(
                WarehouseBridgeLog.DIR_RESOLVED,
                WarehouseBridgeLog.DIR_RESOLVED,
                WarehouseBridgeLog.DIR_RESOLVED,
            ),
            entries.map { it.fields[WarehouseBridgeLog.DIR_FIELD] },
        )
        assertEquals("answered_1", entries[0].fields[WarehouseBridgeLog.REQUEST_ID_FIELD])
        assertFalse(entries[0].fields.containsKey(WarehouseBridgeLog.FALLBACK_FIELD))
        assertFalse(entries[0].fields.containsKey(WarehouseBridgeLog.REASON_FIELD))

        assertEquals("true", entries[1].fields[WarehouseBridgeLog.FALLBACK_FIELD])

        assertEquals("timeout", entries[2].fields[WarehouseBridgeLog.REASON_FIELD])
    }

    /** ⑨ console 入库：error 级 = SCRIPT + FAILURE 两条，其它级别只有 SCRIPT 一条。 */
    @Test
    fun `console error adds exactly one failure entry`() {
        val errorLog = WarehouseImportLogBuffer(nowMs = { FIXED_NOW })
        recordWarehouseConsoleMessage("error", "boom https://jw.example.edu/x?token=t", errorLog)
        val errorEntries = errorLog.snapshot().runs.single().entries
        assertEquals(2, errorEntries.size)
        assertEquals(WarehouseLogCategory.SCRIPT, errorEntries[0].category)
        assertEquals(WarehouseLogCategory.FAILURE, errorEntries[1].category)
        assertEquals(
            WarehouseConsoleLog.FAILURE_CODE,
            errorEntries[1].fields["code"],
        )
        // 两条 message 必须是同一份（已脱敏、已截断）文本，面板才能对照着看。
        assertEquals(
            errorEntries[0].fields[WarehouseConsoleLog.MESSAGE_FIELD],
            errorEntries[1].fields[WarehouseConsoleLog.MESSAGE_FIELD],
        )

        listOf("warning", "log", "debug").forEach { level ->
            val otherLog = WarehouseImportLogBuffer(nowMs = { FIXED_NOW })
            recordWarehouseConsoleMessage(level, "slow", otherLog)
            assertEquals(
                "$level must not escalate to FAILURE",
                listOf(WarehouseLogCategory.SCRIPT),
                otherLog.snapshot().runs.single().entries.map { it.category },
            )
        }
    }

    private companion object {
        /** 固定时钟：断言不依赖真实时间（buffer 只把它写进 tsMs）。 */
        const val FIXED_NOW = 1_700_000_000_000L
    }
}
