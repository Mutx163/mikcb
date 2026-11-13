package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson

/**
 * 导入日志的**采集侧钩子**：把网页桥与 console 的事件写进 [WarehouseImportLogBuffer]。
 *
 * 本文件只负责「采证据」：网页桥收到了什么 / 回答了谁（[WarehouseLogCategory.BRIDGE]），
 * 网页 console 说了什么（[WarehouseLogCategory.SCRIPT]，`error` 级另记一条 FAILURE）。
 * 落盘见 `WarehouseImportLogFileWriter`，读取与展示见 `WarehouseImportLogPage`。
 *
 * ## 硬约束一：BRIDGE 事件不带 payload
 *
 * 只记 `dir` + `requestId` + `type`（以及 `fallback` / `reason` 两个状态位）。网页正文
 * 里可能有口令、账号、整份课表，一律不进日志：`payload` 在这里只被**解析**、从不被搬运。
 * `requestId` 是网页给的不可信输入，入日志前过 [WarehouseBridgeLog.logRequestId] 归一
 * （只留 `[A-Za-z0-9_-]`，长度 ≤ [WarehouseBridgeLog.MAX_REQUEST_ID_CHARS]）——
 * 不归一的话一个 `\n` 就能把一条日志拆成两行，给日志里注入假字段（导出层按
 * ` key=value` 逐行拼，没有转义）。
 *
 * ## 硬约束二：console 单条截断 500 字符
 *
 * 网页 console 一次就能吐一整段堆栈；全量入 buffer 会把失败那一轮的开头（最有用的首条）
 * 挤掉。所以单条截到 [WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS] 字符（超出末尾补
 * [WAREHOUSE_CONSOLE_MESSAGE_ELLIPSIS]），先过 [WarehouseLogRedaction.redactText]
 * （URL 只留 `scheme://host`、内联凭据遮掉），再把换行折成空格（一条日志只占一行）。
 * `error` 级额外落一条 [WarehouseLogCategory.FAILURE]：面板只看 FAILURE 那一列也不会漏掉
 * 网页自己报的错。
 *
 * 纯 JVM：不 import `android.*`，L0 直接可测。所有 record 都走 buffer 的 `record`，
 * **脱敏仍在入队时跑**（见 [WarehouseImportLogBuffer.record]），这是第二道。
 */

/** 单条 console 消息入日志的字符上限（UTF-16 码元，含代理对按 2 计）。 */
const val WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS: Int = 500

/** console 消息被截断时补在末尾的省略号（超出上限才出现）。 */
const val WAREHOUSE_CONSOLE_MESSAGE_ELLIPSIS: String = "…"

/** 网页桥事件（`QingyuBridge.postMessage`）的日志字段：方向 + requestId + 类型。 */
object WarehouseBridgeLog {

    /** 方向字段名（`req` = 网页发来，`resolved` = 原生回话）。 */
    const val DIR_FIELD: String = "dir"

    /** 网页 → 原生。 */
    const val DIR_REQUEST: String = "req"

    /** 原生 → 网页（把 Promise resolve 掉）。 */
    const val DIR_RESOLVED: String = "resolved"

    const val REQUEST_ID_FIELD: String = "requestId"
    const val TYPE_FIELD: String = "type"

    /** 兜底自动回答的标记（`fallback=true` = 没有原生界面/坏载荷，按默认值回答）。 */
    const val FALLBACK_FIELD: String = "fallback"

    /** 排空原因（脚本窗口结束 / 超时时排空挂起弹层）。 */
    const val REASON_FIELD: String = "reason"

    /** 判不出 `type` 时的占位（不空着：空字段在导出里看不出来是被谁吃的）。 */
    const val UNKNOWN_TYPE: String = "unknown"

    /** requestId 入日志的最大长度（与 JS 侧 resolve 脚本的 128 上限同值）。 */
    const val MAX_REQUEST_ID_CHARS: Int = 128

    /** reason 入日志的最大长度（现在是内部常量，留余量即可）。 */
    const val MAX_REASON_CHARS: Int = 32

    /**
     * 网页发来的桥消息 → 一条 `BRIDGE dir=req` 的字段。
     *
     * @param raw `QingyuBridge.postMessage(...)` 的原始文本（**含 payload，但不会被搬运**）
     */
    fun requestFields(raw: String?): Map<String, String> {
        val text = raw?.trim().orEmpty()
        val parsed = if (text.isEmpty()) null else MiniJson.tryParse(text) as? Map<*, *>
        val fields = LinkedHashMap<String, String>(4)
        fields[DIR_FIELD] = DIR_REQUEST
        logRequestId(parsed?.get(REQUEST_ID_FIELD) as? String)?.let { fields[REQUEST_ID_FIELD] = it }
        // 与 warehouseBridgeMessageType 同一口径（非对象 / type 非字符串 ⇒ 判不出类型）：
        // WarehouseWebViewLogicTest 与这里的用例一起钉着两侧不许漂。
        fields[TYPE_FIELD] = (parsed?.get(TYPE_FIELD) as? String)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: UNKNOWN_TYPE
        return fields
    }

    /**
     * 原生回话 → 一条 `BRIDGE dir=resolved` 的字段。
     *
     * @param fallback true = 兜底自动回答（不是用户选的）
     * @param reason 非 null = 排空挂起弹层的原因（`complete` / `error` / `page navigation` /
     *   `re-execute`；`timeout` 若将来再排空也走同一条，不需要新分支）
     */
    fun resolvedFields(
        requestId: String?,
        fallback: Boolean = false,
        reason: String? = null,
    ): Map<String, String> {
        val fields = LinkedHashMap<String, String>(4)
        fields[DIR_FIELD] = DIR_RESOLVED
        logRequestId(requestId)?.let { fields[REQUEST_ID_FIELD] = it }
        if (fallback) fields[FALLBACK_FIELD] = "true"
        logValue(reason, MAX_REASON_CHARS)?.let { fields[REASON_FIELD] = it }
        return fields
    }

    /** requestId 入日志前的归一：只留 `[A-Za-z0-9_-]`，其余字符逐个换成 `_`，超长截断。 */
    fun logRequestId(raw: String?): String? = logValue(raw, MAX_REQUEST_ID_CHARS)

    /**
     * 字段值归一（`k=v` 单行、可安全写进导出文本）。
     *
     * @return null = 空值（调用方据此不写这个字段，而不是写一个空串）
     */
    private fun logValue(raw: String?, maxChars: Int): String? {
        val text = raw?.trim().orEmpty()
        if (text.isEmpty()) return null
        val out = StringBuilder(minOf(text.length, maxChars))
        for (ch in text) {
            if (out.length >= maxChars) break
            out.append(if (isSafeLogChar(ch)) ch else '_')
        }
        return out.toString().ifEmpty { null }
    }

    /** 与 [isSafeWarehouseBridgeRequestId] 同一字符集：字母 / 数字 / `_` / `-`。 */
    private fun isSafeLogChar(ch: Char): Boolean =
        ch in 'a'..'z' || ch in 'A'..'Z' || ch in '0'..'9' || ch == '_' || ch == '-'
}

/** 网页 console 消息的日志字段（`SCRIPT` 用这一份；`error` 另有一条 `FAILURE`）。 */
object WarehouseConsoleLog {

    const val LEVEL_FIELD: String = "level"
    const val MESSAGE_FIELD: String = "message"

    /** Android `ConsoleMessage.MessageLevel.ERROR` 的小写形态（宿主传的已经是小写）。 */
    const val ERROR_LEVEL: String = "error"

    /** `FAILURE` 条目的来源标记（与 `WarehouseMacroReplayer` 的 `code=` 同一列）。 */
    const val FAILURE_CODE: String = "console.error"

    /** `level` + 已脱敏、已折行、已截断的 `message`。 */
    fun fields(level: String, message: String): Map<String, String> = linkedMapOf(
        LEVEL_FIELD to level.trim().lowercase(),
        MESSAGE_FIELD to truncatedText(message),
    )

    /**
     * console 原文 → 一条日志能安全承载的单行文本。
     *
     * 顺序是刻意的：**先脱敏再截断**。反过来的话，一个恰好被切在中间的 `token=…`
     * 会漏网（正则认不出半个凭据）；先脱敏只多花一次正则，截断永远作用在安全文本上。
     */
    fun truncatedText(message: String): String {
        val redacted = WarehouseLogRedaction.redactText(message)
        val singleLine = redacted.replace('\r', ' ').replace('\n', ' ')
        return truncateChars(singleLine, WAREHOUSE_CONSOLE_MESSAGE_MAX_CHARS)
    }

    /**
     * 按字符截断并补省略号；**不从代理对中间切开**（网页 console 里 emoji 很常见，
     * 切一半会留下一个孤立高位代理，导出文本里就是一个坏字符）。
     */
    private fun truncateChars(text: String, limit: Int): String {
        if (text.length <= limit) return text
        var end = limit
        if (end > 0 && text[end - 1].isHighSurrogate()) end -= 1
        return text.substring(0, end) + WAREHOUSE_CONSOLE_MESSAGE_ELLIPSIS
    }
}

/**
 * 记一条 `BRIDGE dir=req`（网页 → 原生）。
 *
 * ⚠️ **主线程调用**：`postMessage` 在 JavaBridge 线程上，宿主已把记录投回主线程
 * （见 `WarehouseWebViewHost` 的 `postMessage` 接线）——JavaBridge 线程上不跑解析/脱敏。
 */
fun recordWarehouseBridgeRequest(
    raw: String?,
    log: WarehouseImportLogBuffer = WarehouseImportLog.buffer,
) {
    log.record(WarehouseLogCategory.BRIDGE, WarehouseBridgeLog.requestFields(raw))
}

/** 记一条 `BRIDGE dir=resolved`（正常回话：用户作答 / 表单保存 / 作息落盘）。 */
fun recordWarehouseBridgeResolved(
    requestId: String?,
    log: WarehouseImportLogBuffer = WarehouseImportLog.buffer,
) {
    log.record(WarehouseLogCategory.BRIDGE, WarehouseBridgeLog.resolvedFields(requestId))
}

/** 记一条 `BRIDGE dir=resolved fallback=true`（没有原生界面/坏载荷时的确定性兜底回答）。 */
fun recordWarehouseBridgeFallback(
    requestId: String?,
    log: WarehouseImportLogBuffer = WarehouseImportLog.buffer,
) {
    log.record(
        WarehouseLogCategory.BRIDGE,
        WarehouseBridgeLog.resolvedFields(requestId, fallback = true),
    )
}

/** 记一条 `BRIDGE dir=resolved reason=…`（脚本窗口结束 / 超时时排空挂起弹层）。 */
fun recordWarehouseBridgeDrain(
    requestId: String?,
    reason: String?,
    log: WarehouseImportLogBuffer = WarehouseImportLog.buffer,
) {
    log.record(
        WarehouseLogCategory.BRIDGE,
        WarehouseBridgeLog.resolvedFields(requestId, reason = reason),
    )
}

/** 记一条 console 消息：`SCRIPT` 一条；`error` 级再加一条 `FAILURE`。 */
fun recordWarehouseConsoleMessage(
    level: String,
    message: String,
    log: WarehouseImportLogBuffer = WarehouseImportLog.buffer,
) {
    val fields = WarehouseConsoleLog.fields(level, message)
    log.record(WarehouseLogCategory.SCRIPT, fields)
    if (fields[WarehouseConsoleLog.LEVEL_FIELD] == WarehouseConsoleLog.ERROR_LEVEL) {
        log.record(
            WarehouseLogCategory.FAILURE,
            linkedMapOf(
                "code" to WarehouseConsoleLog.FAILURE_CODE,
                WarehouseConsoleLog.MESSAGE_FIELD to
                    fields.getValue(WarehouseConsoleLog.MESSAGE_FIELD),
            ),
        )
    }
}
