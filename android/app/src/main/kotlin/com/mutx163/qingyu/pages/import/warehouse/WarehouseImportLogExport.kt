package com.mutx163.qingyu.pages.import.warehouse

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** 宿主侧可读到的设备信息（**由 composeP1 宿主传入**，本模块不 import `android.*`）。 */
data class WarehouseDeviceInfo(
    /** `Build.MODEL`。 */
    val model: String,
    /** `Build.VERSION.RELEASE`。 */
    val androidVersion: String,
    /** `BuildConfig.VERSION_NAME`（dev 变体自带 `-debug` 后缀，正好用来分辨装的是哪一版）。 */
    val appVersion: String,
) {
    companion object {
        /** L0 测试与「拿不到字段」时的兜底（不参与生产路径）。 */
        val UNKNOWN = WarehouseDeviceInfo(model = "unknown", androidVersion = "unknown", appVersion = "unknown")
    }
}

/**
 * 把 buffer 快照编成**一份人能读、能贴给人看**的纯文本。
 *
 * ## 形状
 *
 * 头 10 行（顺序固定，缺值就留空，**不省略行**——用户报障时「哪一项是空的」本身就是信息）：
 * 前 9 行是 `key=value`，第 10 行是 `truncated: true|false`（这一行用 `: ` 分隔，取值只有
 * `true` / `false`，机器可读；不靠文末标记猜）。
 *
 * ```
 * time=2026-11-12T21:03:44.512+08:00
 * version=1.2.3-debug
 * model=Pixel 7
 * android=14
 * school=示例大学
 * adapter=cas-1
 * macroSteps=12
 * verdict=failure
 * endReason=timeout
 * truncated: false
 * ```
 *
 * 正文按 run 分组，每组先一行 `[run] id=… school=… adapter=… verdict=… end=…`，
 * 然后每条一行 `ts category key=value key=value`。
 *
 * ## 三道约束
 *
 * 1. **单份上限 [MAX_TEXT_BYTES]（256 KiB）**：超了截断，表头 `truncated` 置 `true`，
 *    并在文末写 [TRUNCATED_NOTE]。上限按 UTF-8 字节算（中文一个字符 3 字节，按字符数算会超）。
 * 2. **截断标记是 ASCII**：文件会落到用户可见的位置、还可能贴给客服比对，中文注记在
 *    非中文语言版本下既不可比也不可读；`[TRUNCATED]` + `truncated: true` 两处都给，
 *    一处给人看、一处给机读。
 * 3. **导出链路不直写明文**：每个条目的 fields 在写进文本前**再过一遍** [WarehouseLogRedaction]
 *    （buffer 入队时已经脱过一次，这一步是第二道，幂等）。源码守卫盯着这条：
 *    不许出现「把 fields 原样拼进文本」的调用形态。
 *
 * 纯 JVM：只用 `java.time`，不 import `android.*`；**本文件不含任何中文字符串字面量**
 * （CJK 棘轮对它是 0 条，测试与基线都可核对）。
 */
object WarehouseImportLogExport {
    /** 单份上限：256 KiB（UTF-8 字节）。 */
    const val MAX_TEXT_BYTES = 256 * 1024

    /** 超出上限时写在文末的标记（ASCII：跨语言可比、机器可读）。 */
    const val TRUNCATED_NOTE = "[TRUNCATED]"

    /** 表头里「这份日志是否被截断」的字段名（第 10 行，唯一用 `: ` 分隔的一行）。 */
    const val TRUNCATED_FIELD = "truncated"

    /** `truncated` 行的分隔符前缀（`truncated: true`），与其余 9 行的 `key=` 刻意不同。 */
    const val TRUNCATED_FIELD_PREFIX = "$TRUNCATED_FIELD: "

    /** 表头键名（顺序就是输出顺序，测试按这份清单比对；`truncated` 恒在最后一行）。 */
    val HEADER_KEYS = listOf(
        "time",
        "version",
        "model",
        "android",
        "school",
        "adapter",
        "macroSteps",
        "verdict",
        "endReason",
        TRUNCATED_FIELD,
    )

    private val HEADER_TIME_FORMAT: DateTimeFormatter =
        DateTimeFormatter.ISO_OFFSET_DATE_TIME.withZone(ZoneId.systemDefault())

    private val ENTRY_TIME_FORMAT: DateTimeFormatter =
        DateTimeFormatter.ofPattern("HH:mm:ss.SSS").withZone(ZoneId.systemDefault())

    /**
     * @param nowMs 表头 `time` 用的时间（默认系统当前毫秒；测试注入固定值）
     */
    fun buildText(
        snapshot: WarehouseImportLogSnapshot,
        deviceInfo: WarehouseDeviceInfo,
        nowMs: Long = System.currentTimeMillis(),
    ): String {
        // 两遍编：先按「没截断」编，超限才把表头改成 truncated: true 再真截。
        // `false` → `true` 少一个字节，重编不会继续变大。
        val plain = build(snapshot, deviceInfo, nowMs, truncated = false)
        if (plain.toByteArray(Charsets.UTF_8).size <= MAX_TEXT_BYTES) return plain
        return truncateToLimit(build(snapshot, deviceInfo, nowMs, truncated = true), force = true)
    }

    // ---------------------------------------------------------------------
    // 内部
    // ---------------------------------------------------------------------

    private fun build(
        snapshot: WarehouseImportLogSnapshot,
        deviceInfo: WarehouseDeviceInfo,
        nowMs: Long,
        truncated: Boolean,
    ): String {
        val builder = StringBuilder(4096)
        appendHeader(builder, snapshot, deviceInfo, nowMs, truncated)
        builder.append('\n')
        for (run in snapshot.runs) {
            builder.append("[run] id=").append(run.runId)
                .append(" school=").append(WarehouseLogRedaction.redactText(run.school))
                .append(" adapter=").append(WarehouseLogRedaction.redactText(run.adapterId))
                .append(" verdict=").append(runVerdict(run))
                .append(" end=").append(WarehouseLogRedaction.redactText(run.endReason.orEmpty()))
                .append('\n')
            for (entry in run.entries) {
                appendEntry(builder, entry)
            }
        }
        return builder.toString()
    }

    private fun appendHeader(
        builder: StringBuilder,
        snapshot: WarehouseImportLogSnapshot,
        deviceInfo: WarehouseDeviceInfo,
        nowMs: Long,
        truncated: Boolean,
    ) {
        val current = snapshot.currentRun
        val values = linkedMapOf(
            "time" to HEADER_TIME_FORMAT.format(Instant.ofEpochMilli(nowMs)),
            "version" to deviceInfo.appVersion,
            "model" to deviceInfo.model,
            "android" to deviceInfo.androidVersion,
            "school" to current?.school.orEmpty(),
            "adapter" to current?.adapterId.orEmpty(),
            "macroSteps" to snapshot.runs.sumOf { run ->
                run.entries.count { it.category == WarehouseLogCategory.MACRO_STEP }
            }.toString(),
            "verdict" to verdict(snapshot),
            "endReason" to (snapshot.lastFailureReason ?: current?.endReason.orEmpty()),
            TRUNCATED_FIELD to if (truncated) "true" else "false",
        )
        for (key in HEADER_KEYS) {
            val value = WarehouseLogRedaction.redactText(values[key].orEmpty())
            if (key == TRUNCATED_FIELD) {
                builder.append(TRUNCATED_FIELD_PREFIX).append(value).append('\n')
            } else {
                builder.append(key).append('=').append(value).append('\n')
            }
        }
    }

    private fun appendEntry(builder: StringBuilder, entry: WarehouseImportLogEntry) {
        builder.append(ENTRY_TIME_FORMAT.format(Instant.ofEpochMilli(entry.tsMs)))
            .append(' ')
            .append(entry.category.name)
        // 第二道脱敏：即使上游有人绕过 buffer 直接塞了 fields，这里也不会把明文写进文件。
        val redacted = WarehouseLogRedaction.redact(entry.fields)
        for ((key, value) in redacted) {
            builder.append(' ').append(key).append('=').append(value)
        }
        builder.append('\n')
    }

    /** 表头结论：有失败 run 就报 failure（失败优先），否则全收尾算 success，还在跑算 running。 */
    private fun verdict(snapshot: WarehouseImportLogSnapshot): String = when {
        snapshot.hasFailure -> "failure"
        snapshot.runs.isNotEmpty() && snapshot.runs.all { it.finished } -> "success"
        else -> "running"
    }

    private fun runVerdict(run: WarehouseImportLogRun): String = when {
        run.failed -> "failure"
        run.finished -> "success"
        else -> "running"
    }

    /**
     * 超过 [MAX_TEXT_BYTES] 就截断并加 [TRUNCATED_NOTE]。
     *
     * 按**字节**截（不是字符）：`String.toByteArray` 后回切，回切位置落在多字节字符中间时
     * 往左退到字符边界；再对齐到最后一个换行，避免最后一行只剩半个 `key=valu`。
     *
     * @param force true = 即使文本没超限也按截断处理（表头已经写了 `truncated: true`
     *   时必须走这条，否则文件头说截断了、正文却没有标记，两处自相矛盾）
     */
    private fun truncateToLimit(text: String, force: Boolean = false): String {
        val raw = text.toByteArray(Charsets.UTF_8)
        if (!force && raw.size <= MAX_TEXT_BYTES) return text
        val marker = "\n$TRUNCATED_NOTE\n"
        val markerBytes = marker.toByteArray(Charsets.UTF_8).size
        var cut = minOf(raw.size, MAX_TEXT_BYTES - markerBytes)
        if (cut <= 0) return TRUNCATED_NOTE
        while (cut > 0 && (raw[cut].toInt() and CONTINUATION_MASK) == CONTINUATION_BITS) {
            cut -= 1
        }
        var body = if (cut >= raw.size) text else String(raw, 0, cut, Charsets.UTF_8)
        val lastBreak = body.lastIndexOf('\n')
        if (lastBreak > 0) body = body.substring(0, lastBreak)
        return body + marker
    }

    /** UTF-8 续字节的高两位是 `10`。 */
    private const val CONTINUATION_MASK = 0xC0
    private const val CONTINUATION_BITS = 0x80
}
