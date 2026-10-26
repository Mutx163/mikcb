package com.mutx163.qingyu.infra

/**
 * 日志脱敏纯逻辑（源：lib/logging/app_debug_log.dart）。
 *
 * 与 Dart 逐行对齐：
 * - [personalLogFieldKeys] 是唯一来源表；查表一律大小写不敏感
 *   （[isPersonalLogFieldKey]，extras 与 message 两条出口同口径）。
 * - [redactPersonalFields]：一次遍历 + 懒惰标量匹配；列表型字段按 key 决定
 *   吃到空白 / `]` / 行尾（Dart 注释的三种形态）。
 * - [redactPersonalFieldValue]：结构化值的查表 + JSON 文本容器的先解析后脱敏。
 * - [redactedLiveDebugSnapshot]：超级岛调试快照的两层脱敏。
 *
 * 注意：同步改这份表时必须同步 Kotlin 侧 `UmengDiagnosticReporter` 的
 * `personalLogFieldKeysLower`（Dart 源码注释要求，两边各维护一份）。
 */

val personalLogFieldKeys: Set<String> = setOf(
    "course",
    "courseName",
    "name",
    "shortName",
    "teacher",
    "loc",
    "location",
    "groupName",
    "group",
    "keyword",
    "keywords",
    "className",
    "studentName",
    "overflowNames",
    "changeSamples",
    "sampleOverrides",
    "profileName",
    "originalName",
    "clientIp",
)

private val listValuedPersonalFieldKeys: Set<String> = setOf(
    "overflownames",
    "changesamples",
    "sampleoverrides",
    "keywords",
)

private val commaListValuedPersonalFieldKeys: Set<String> = setOf(
    "overflownames",
    "keywords",
)

private val personalFieldPattern = Regex(
    "(^|[\\s&|])([A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*([^\\s&|]*)",
    setOf(RegexOption.IGNORE_CASE, RegexOption.MULTILINE),
)

private val personalFieldKeysLower: Set<String> = personalLogFieldKeys.map { it.lowercase() }.toSet()

/** 这个键是不是可识别到人的字段（大小写不敏感）。 */
fun isPersonalLogFieldKey(key: String): Boolean =
    personalFieldKeysLower.contains(key.lowercase())

/** 超级岛调试快照里内容全部派生自课程数据的自由文本子树（导出时整棵置 `**`）。 */
val liveSnapshotCourseDerivedSubtrees: List<String> = listOf("notification", "summary")

/**
 * 把个人信息字段改成 `key=**`，其余文本原样保留。
 *
 * Dart 口径：一次遍历；非个人字段不动（cursor 也不动）；已被前面的列表型字段
 * 整段吃掉的匹配跳过；列表型按逗号列表（吃到空白或 `]`）与行尾两类停。
 */
fun redactPersonalFields(message: String): String {
    val out = StringBuilder()
    var cursor = 0
    for (match in personalFieldPattern.findAll(message)) {
        val boundary = match.groupValues[1]
        val key = match.groupValues[2]
        val lowered = key.lowercase()
        if (!personalFieldKeysLower.contains(lowered)) {
            continue
        }
        if (match.range.first < cursor) {
            continue
        }
        out.append(message.substring(cursor, match.range.first))
        if (listValuedPersonalFieldKeys.contains(lowered)) {
            val newline = message.indexOf('\n', match.range.first)
            val lineEnd = if (newline == -1) message.length else newline
            var stopAt = lineEnd
            if (commaListValuedPersonalFieldKeys.contains(lowered)) {
                val closeBracket = message.indexOf(']', match.range.last + 1)
                if (closeBracket != -1 && closeBracket < lineEnd) {
                    stopAt = closeBracket + 1
                } else {
                    for (i in (match.range.last + 1) until lineEnd) {
                        val c = message[i]
                        if (c == ' ' || c == '\t' || c == '\r') {
                            stopAt = i
                            break
                        }
                    }
                }
            }
            out.append(boundary).append(key).append("=**")
            cursor = stopAt
        } else {
            out.append(boundary).append(key).append("=**")
            cursor = match.range.last + 1
        }
    }
    out.append(message.substring(cursor))
    return out.toString()
}

/**
 * 单个结构化诊断字段的脱敏（Dart `redactPersonalFieldValue`）。
 *
 * 个人键整值抹 `**`；Map/Iterable 递归；JSON 文本容器先解析后脱敏；
 * 普通文本走 [redactPersonalFields]。
 */
fun redactPersonalFieldValue(key: String, value: Any?): Any? {
    if (isPersonalLogFieldKey(key)) {
        return "**"
    }
    if (value is Map<*, *>) {
        @Suppress("UNCHECKED_CAST")
        return redactPersonalFieldMap(value as Map<Any?, Any?>)
    }
    if (value is Iterable<*>) {
        return redactPersonalFieldList(value)
    }
    val text = value.toString()
    val decoded = tryDecodeJsonContainer(text)
    if (decoded is Map<*, *>) {
        @Suppress("UNCHECKED_CAST")
        return redactPersonalFieldMap(decoded as Map<Any?, Any?>)
    }
    if (decoded is Iterable<*>) {
        return redactPersonalFieldList(decoded)
    }
    return redactPersonalFields(text)
}

/** 只在看起来确实是 JSON 容器时才解析（空/超长/首尾不符直接返回 null）。 */
internal fun tryDecodeJsonContainer(text: String): Any? {
    val trimmed = text.trim()
    if (trimmed.isEmpty() || trimmed.length > 200000) {
        return null
    }
    val startsLikeJson = (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))
    if (!startsLikeJson) {
        return null
    }
    return InfraJson.tryParse(trimmed)
}

/** 整份 extras 过一遍查表；键原样保留、值可能变短。 */
fun redactPersonalFieldMap(source: Map<Any?, Any?>): Map<String, Any?> {
    val out = linkedMapOf<String, Any?>()
    for ((key, value) in source) {
        val name = key.toString()
        out[name] = redactPersonalFieldValue(name, value)
    }
    return out
}

/** 列表每项脱敏后按 Dart `List.toString()` 形态（`[a, b]`，空为 `[]`）输出。 */
fun redactPersonalFieldList(source: Iterable<Any?>): String {
    val items = arrayListOf<Any?>()
    for (item in source) {
        if (item is Map<*, *>) {
            @Suppress("UNCHECKED_CAST")
            items.add(redactPersonalFieldMap(item as Map<Any?, Any?>))
        } else if (item is Iterable<*>) {
            items.add(redactPersonalFieldList(item))
        } else {
            items.add(redactPersonalFields(item?.toString() ?: "null"))
        }
    }
    return if (items.isEmpty()) "[]" else items.toString()
}

/**
 * 超级岛调试快照的两层脱敏（Dart `redactedLiveDebugSnapshot`）：
 * 1. 递归查表；2. 名单内子树整棵置 `**`。
 */
fun redactedLiveDebugSnapshot(snapshot: Map<Any?, Any?>): Map<String, Any?> {
    val redacted = redactPersonalFieldMap(snapshot).toMutableMap()
    for (key in liveSnapshotCourseDerivedSubtrees) {
        if (redacted.containsKey(key)) {
            redacted[key] = "**"
        }
    }
    return redacted
}
