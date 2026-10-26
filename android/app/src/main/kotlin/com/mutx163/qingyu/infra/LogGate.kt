package com.mutx163.qingyu.infra

import java.time.LocalTime

/**
 * 日志门控与节流纯逻辑（源：lib/services/app_log_service.dart）。
 *
 * 只收录不碰盘/不碰网络的部分：
 * - [normalizeLogLevel]：未知级别回落 info（Dart `_normalizeLevel`）。
 * - [shouldRecordLog]：force 跳过的是「本地诊断日志」开关，不是隐私同意
 *   （Dart `_shouldRecord`，2026-09 注释语义）。
 * - [shouldAlertWriteFailure]：连续写失败每 N 次告警一次的取模节流。
 * - [retainedLogTail]：超限截断时保留后半段（Dart `_trimIfNeeded` 的纯计算核）。
 * - [injectSourceIntoSections]：给无 source 标记的段落打 source 标签。
 * - [buildLogEntryPayload]：单条落盘文本的组装（含脱敏出口）。
 * - [formatLogTimestamp] / [UpdateLogEntry.timeString]：`[HH:mm:ss.SSS]` 与 `HH:mm:ss`。
 *
 * 初始化并发去重、文件读写、轮询指纹、`watchMergedLogsText` 的流编排是 IO/平台
 * 行为，不在本层。
 */

const val maxLogChars = 512 * 1024

const val writeFailureAlertThreshold = 5

/** 未知级别回落 `info`，大小写/空白不敏感。 */
fun normalizeLogLevel(raw: String): String {
    val cleaned = raw.trim().lowercase()
    return if (cleaned == "error" || cleaned == "warn" || cleaned == "info" ||
        cleaned == "debug" || cleaned == "verbose"
    ) {
        cleaned
    } else {
        "info"
    }
}

/**
 * 是否允许记录一条日志。
 *
 * - force=true 只跳过 loggingEnabled 开关，隐私未同意时仍拒绝（写盘越界）。
 * - force=false 时两项开关缺一不可。
 */
fun shouldRecordLog(privacyAccepted: Boolean, loggingEnabled: Boolean, force: Boolean): Boolean {
    if (force) {
        return privacyAccepted
    }
    return privacyAccepted && loggingEnabled
}

/**
 * 连续写失败[thisFailures]（本次失败计入后）时是否应打出兜底告警。
 *
 * Dart 口径：`_consecutiveWriteFailures % _writeFailureAlertThreshold == 0`
 *（长磁盘满故障下每 N 次告警一次，而非第 5 次后永久静默；不清零、不递归 log）。
 */
fun shouldAlertWriteFailure(thisFailures: Int, threshold: Int = writeFailureAlertThreshold): Boolean {
    return thisFailures % threshold == 0
}

/**
 * 超限截断的纯计算核：未超限返回 null（调用方不动作）；超限返回应保留的尾部文本。
 *
 * Dart 口径：`_trimIfNeeded` 只在 `length > _maxLogBytes` 时动作，保留后
 * `retainLength = max/2` 个字符并 `trimLeft()`。字节/字符差异见 kdoc：
 * 真机日志以 ASCII 为主，字符数即字节数；含大量 CJK 时调用方应按字节重算。
 */
fun retainedLogTail(text: String, maxChars: Int = maxLogChars): String? {
    if (text.length <= maxChars) {
        return null
    }
    val retainLength = maxChars / 2
    val retained = if (text.length <= retainLength) text else text.substring(text.length - retainLength)
    return retained.trimStart()
}

/**
 * 把 [body] 按空行切段，无 `source=` 标记的段落打上 `source=[source]`。
 *
 * Dart 口径（`_injectSourceIntoSections`）：已有标记的段落不动；否则找到首个
 * `time=` 开头的行，在其后插入；没有 `time=` 行时整个段落前置标记。
 */
fun injectSourceIntoSections(body: String, source: String): String {
    val sectionSplit = Regex("\\r?\\n\\r?\\n")
    val sourceMarker = Regex("(^|\\n)source=")
    val lineSplit = Regex("\\r?\\n")
    val sections = body.split(sectionSplit)
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .map { section ->
            if (sourceMarker.containsMatchIn(section)) {
                return@map section
            }
            val lines = section.split(lineSplit).toMutableList()
            val insertIndex = lines.indexOfFirst { it.startsWith("time=") }
            if (insertIndex != -1) {
                lines.add(insertIndex + 1, "source=$source")
                lines.joinToString("\n")
            } else {
                "source=$source\n$section"
            }
        }
    return sections.joinToString("\n\n")
}

/** `update_check` 等流程日志的时间戳 `[HH:mm:ss.SSS]`（源：lib/utils/async_utils.dart）。 */
fun formatLogTimestamp(time: LocalTime = LocalTime.now()): String {
    fun two(value: Int) = value.toString().padStart(2, '0')
    val ms = (time.nano / 1_000_000).toString().padStart(3, '0')
    return "[${two(time.hour)}:${two(time.minute)}:${two(time.second)}.$ms]"
}

/** 更新流程日志条目（源：lib/services/app_update_service.dart `UpdateLogEntry`）。 */
data class UpdateLogEntry(val timestampMillis: Long, val hour: Int, val minute: Int, val second: Int, val message: String) {
    val timeString: String
        get() = "${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}"
}

/**
 * 单条落盘文本的纯组装（Dart `_buildEntryPayload`）。
 *
 * - message/error/stackTrace 走脱敏出口；extras 里命中个人字段表的键整值抹成 `**`；
 * - [timeMillis] 由调用方传入（代替 `DateTime.now()`，保持纯函数）。
 */
fun buildLogEntryPayload(
    level: String,
    category: String,
    message: String,
    extras: Map<String, Any?> = emptyMap(),
    error: String? = null,
    stackTrace: String? = null,
    timeMillis: Long,
): String {
    val buffer = StringBuilder()
    buffer.append("time=").append(timeMillis).append('\n')
    buffer.append("level=").append(level).append('\n')
    buffer.append("source=app\n")
    buffer.append("category=").append(category).append('\n')
    buffer.append("message=").append(redactPersonalFields(message)).append('\n')
    if (extras.isNotEmpty()) {
        buffer.append("extras=\n")
        for ((key, value) in extras) {
            if (isPersonalLogFieldKey(key)) {
                buffer.append("  ").append(key).append("=**\n")
                continue
            }
            buffer.append("  ").append(key).append("=").append(redactPersonalFieldValue(key, value)).append('\n')
        }
    }
    if (error != null) {
        buffer.append("error=").append(redactPersonalFields(error)).append('\n')
    }
    if (stackTrace != null) {
        buffer.append("stackTrace=\n")
        buffer.append(redactPersonalFields(stackTrace.trimEnd())).append('\n')
    }
    buffer.append('\n')
    return buffer.toString()
}
