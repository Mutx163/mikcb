package com.mutx163.qingyu.infra

import java.time.Instant
import java.time.ZoneId

/**
 * 诊断日志解析纯逻辑（源：lib/logging/diagnostics_log_parser.dart）。
 *
 * 与 Dart 逐行对齐：分隔符、缩进 kv 块、显式级别表、关键词推断顺序
 * （throwable/stackTrace/error → warn → verbose → debug → info）、
 * source 归属（显式 app/native 优先，否则 live_update/miui_live/diagnostics_
 * 开头归 native）。
 *
 * 时区说明：[DiagnosticsLogEntry.formattedTime] 与 Dart 同样走系统本地时区。
 */

enum class DiagnosticsLogLevel { ALL, ERROR, WARN, INFO, DEBUG, VERBOSE }

private val bodySeparatorRegex = Regex("\\n----\\n|\\r\\n----\\r\\n|\\n----\\r\\n|\\r\\n----\\n")
private val logLineSplitRegex = Regex("\\r?\\n")
private val logKvLineRegex = Regex("^([A-Za-z0-9_.-]+)=(.*)$")
private val logErrorHintRegex = Regex("\\b(error|exception|crash|fatal|failed|failure)\\b")
private val logWarnHintRegex = Regex("\\b(warn|warning|denied|blocked|invalid|missing)\\b")
private val logVerboseHintRegex = Regex("\\b(verbose|trace)\\b")
private val logDebugHintRegex = Regex("\\b(debug|diagnostic|snapshot|payload|test)\\b")

data class DiagnosticsLogEntry(
    val rawBlock: String,
    val fields: Map<String, String>,
    val level: DiagnosticsLogLevel,
    val isLevelInferred: Boolean,
) {
    val category: String get() = fields["category"]?.trim() ?: ""

    val message: String get() = fields["message"]?.trim() ?: rawBlock.trim()

    val sourceKey: String
        get() {
            val explicit = fields["source"]?.trim()
            if (explicit == "app" || explicit == "native") {
                return explicit
            }
            val categoryLower = category.lowercase()
            return if (categoryLower.startsWith("live_update") ||
                categoryLower.startsWith("miui_live") ||
                categoryLower.startsWith("diagnostics_")
            ) {
                "native"
            } else {
                "app"
            }
        }

    val isNativeSource: Boolean get() = sourceKey == "native"

    val formattedTime: String? get() = formatDiagnosticsMillis(fields["time"])

    val timeMillis: Long get() = fields["time"]?.toLongOrNull() ?: 0L

    val detailEntries: List<Map.Entry<String, String>>
        get() = fields.entries.filter {
            it.key != "time" && it.key != "category" && it.key != "message" &&
                it.key != "level" && it.key != "severity" && it.key != "source"
        }

    val stableId: String get() = "$timeMillis|${category.hashCode()}|${message.hashCode()}"
}

data class DiagnosticsLogSnapshot(
    val title: String,
    val rawHeader: String,
    val fullText: String,
    val headerEntries: Map<String, String>,
    val entries: List<DiagnosticsLogEntry>,
) {
    companion object {
        val EMPTY = DiagnosticsLogSnapshot(
            title = "",
            rawHeader = "",
            fullText = "",
            headerEntries = emptyMap(),
            entries = emptyList(),
        )
    }
}

fun parseDiagnosticsLog(rawLog: String, fallbackTitle: String = ""): DiagnosticsLogSnapshot {
    val normalizedText = rawLog.trim()
    if (normalizedText.isEmpty()) {
        return DiagnosticsLogSnapshot(
            title = fallbackTitle,
            rawHeader = "",
            fullText = "",
            headerEntries = emptyMap(),
            entries = emptyList(),
        )
    }
    val lines = normalizedText.split(logLineSplitRegex)
    val separatorIndex = lines.indexOfFirst { it.trim() == "----" }
    val headerLines = if (separatorIndex >= 0) lines.take(separatorIndex) else emptyList()
    val bodyLines = if (separatorIndex >= 0) lines.drop(separatorIndex + 1) else lines
    val headerEntries = parseIndentedKeyValueBlock(headerLines.drop(1))
    val rawSections = splitDiagnosticSections(bodyLines)
    val entries = rawSections.mapNotNull { parseDiagnosticsLogEntry(it) }
    return DiagnosticsLogSnapshot(
        title = if (headerLines.isNotEmpty()) {
            headerLines.first().trim()
        } else if (fallbackTitle.isNotEmpty()) {
            fallbackTitle
        } else {
            "Diagnostics Log"
        },
        rawHeader = headerLines.joinToString("\n").trim(),
        fullText = normalizedText,
        headerEntries = headerEntries,
        entries = entries,
    )
}

fun parseDiagnosticsLogSections(bodyText: String): List<DiagnosticsLogEntry> {
    val normalized = bodyText.trim()
    if (normalized.isEmpty()) {
        return emptyList()
    }
    val lines = normalized.split(logLineSplitRegex)
    return splitDiagnosticSections(lines).mapNotNull { parseDiagnosticsLogEntry(it) }
}

fun extractDiagnosticsLogBody(text: String): String {
    val normalized = text.trim()
    if (normalized.isEmpty()) {
        return ""
    }
    val parts = normalized.split(bodySeparatorRegex)
    if (parts.size <= 1) {
        return normalized
    }
    return parts.drop(1).joinToString("\n----\n").trim()
}

fun appendDiagnosticsLogBody(
    current: DiagnosticsLogSnapshot,
    appendedBody: String,
    mergedFullText: String,
): DiagnosticsLogSnapshot {
    if (appendedBody.trim().isEmpty()) {
        return current.copy(fullText = mergedFullText)
    }
    val newEntries = parseDiagnosticsLogSections(appendedBody)
    if (newEntries.isEmpty()) {
        return current.copy(fullText = mergedFullText)
    }
    return current.copy(fullText = mergedFullText, entries = current.entries + newEntries)
}

fun buildFilteredDiagnosticsRawText(
    parsed: DiagnosticsLogSnapshot,
    filteredEntries: List<DiagnosticsLogEntry>,
): String {
    val blocks = filteredEntries.map { it.rawBlock.trim() }.joinToString("\n\n")
    if (parsed.rawHeader.isEmpty()) {
        return blocks
    }
    if (blocks.isEmpty()) {
        return parsed.rawHeader
    }
    return "${parsed.rawHeader}\n----\n$blocks".trim()
}

fun filterDiagnosticsEntries(
    entries: List<DiagnosticsLogEntry>,
    level: DiagnosticsLogLevel,
): List<DiagnosticsLogEntry> {
    if (level == DiagnosticsLogLevel.ALL) {
        return entries
    }
    return entries.filter { it.level == level }
}

fun sortDiagnosticsEntries(
    entries: List<DiagnosticsLogEntry>,
    ascending: Boolean,
): List<DiagnosticsLogEntry> {
    val sorted = entries.toMutableList()
    sorted.sortWith { a, b ->
        val cmp = a.timeMillis.compareTo(b.timeMillis)
        if (ascending) cmp else -cmp
    }
    return sorted
}

fun countDiagnosticsLevels(entries: List<DiagnosticsLogEntry>): Map<DiagnosticsLogLevel, Int> {
    val counts = mutableMapOf(
        DiagnosticsLogLevel.ALL to entries.size,
        DiagnosticsLogLevel.ERROR to 0,
        DiagnosticsLogLevel.WARN to 0,
        DiagnosticsLogLevel.INFO to 0,
        DiagnosticsLogLevel.DEBUG to 0,
        DiagnosticsLogLevel.VERBOSE to 0,
    )
    for (entry in entries) {
        counts[entry.level] = (counts[entry.level] ?: 0) + 1
    }
    return counts
}

fun formatDiagnosticsMillis(raw: String?): String? {
    val millis = raw?.toLongOrNull() ?: return null
    val dateTime = Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDateTime()
    fun two(value: Int) = value.toString().padStart(2, '0')
    return "${dateTime.year}-${two(dateTime.monthValue)}-${two(dateTime.dayOfMonth)} " +
        "${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}"
}

internal fun splitDiagnosticSections(lines: List<String>): List<List<String>> {
    val sections = mutableListOf<List<String>>()
    var current = mutableListOf<String>()
    for (line in lines) {
        if (line.trim().isEmpty()) {
            if (current.isNotEmpty()) {
                sections.add(current)
                current = mutableListOf()
            }
            continue
        }
        current.add(line)
    }
    if (current.isNotEmpty()) {
        sections.add(current)
    }
    return sections
}

internal fun parseDiagnosticsLogEntry(lines: List<String>): DiagnosticsLogEntry? {
    val rawBlock = lines.joinToString("\n").trimEnd()
    if (rawBlock.isEmpty()) {
        return null
    }
    val fields = parseIndentedKeyValueBlock(lines)
    val normalizedFields = if (fields.isEmpty()) {
        mapOf("message" to rawBlock)
    } else {
        fields
    }
    val explicitLevel = parseDiagnosticsLogLevel(
        normalizedFields["level"] ?: normalizedFields["severity"],
    )
    val level = explicitLevel ?: inferDiagnosticsLogLevel(normalizedFields, rawBlock)
    return DiagnosticsLogEntry(
        rawBlock = rawBlock,
        fields = normalizedFields,
        level = level,
        isLevelInferred = explicitLevel == null,
    )
}

internal fun parseIndentedKeyValueBlock(lines: List<String>): Map<String, String> {
    val result = linkedMapOf<String, String>()
    var currentKey: String? = null
    val currentValue = StringBuilder()

    fun commit() {
        val key = currentKey ?: return
        result[key] = currentValue.toString().trimEnd()
        currentKey = null
        currentValue.setLength(0)
    }

    for (line in lines) {
        val match = logKvLineRegex.find(line)
        if (match != null && !line.startsWith("  ")) {
            commit()
            currentKey = match.groupValues[1]
            currentValue.append(match.groupValues[2].trimStart())
            continue
        }
        if (currentKey == null) {
            continue
        }
        val normalized = if (line.startsWith("  ")) line.substring(2) else line
        if (currentValue.isNotEmpty()) {
            currentValue.append('\n')
        }
        currentValue.append(normalized)
    }
    commit()
    return result
}

internal fun parseDiagnosticsLogLevel(raw: String?): DiagnosticsLogLevel? {
    return when ((raw ?: "").trim().lowercase()) {
        "error", "err", "fatal" -> DiagnosticsLogLevel.ERROR
        "warn", "warning" -> DiagnosticsLogLevel.WARN
        "info" -> DiagnosticsLogLevel.INFO
        "debug" -> DiagnosticsLogLevel.DEBUG
        "verbose", "trace" -> DiagnosticsLogLevel.VERBOSE
        "all" -> DiagnosticsLogLevel.ALL
        else -> null
    }
}

internal fun inferDiagnosticsLogLevel(
    fields: Map<String, String>,
    rawBlock: String,
): DiagnosticsLogLevel {
    val haystack = listOf(
        rawBlock,
        fields["category"],
        fields["message"],
        fields["throwable"],
        fields["stackTrace"],
        fields["truncatedHint"],
    ).filterNotNull().joinToString("\n").lowercase()
    if (fields.containsKey("throwable") ||
        fields.containsKey("stackTrace") ||
        logErrorHintRegex.containsMatchIn(haystack)
    ) {
        return DiagnosticsLogLevel.ERROR
    }
    if (logWarnHintRegex.containsMatchIn(haystack)) {
        return DiagnosticsLogLevel.WARN
    }
    if (logVerboseHintRegex.containsMatchIn(haystack)) {
        return DiagnosticsLogLevel.VERBOSE
    }
    if (logDebugHintRegex.containsMatchIn(haystack)) {
        return DiagnosticsLogLevel.DEBUG
    }
    return DiagnosticsLogLevel.INFO
}
