package com.mutx163.qingyu.pages.diagnostics

import java.util.Locale

/**
 * 与 Dart `const JsonEncoder.withIndent('  ').convert(snapshot)` **逐字符对齐**的 JSON 输出。
 *
 * 为什么自己写而不用 `org.json`：
 * * `org.json` 在 Android 上是 `android.jar` 的实现，JVM 单测拿不到（会抛 "not mocked"），
 *   而这一份输出是「复制 JSON 快照」按钮与导出文件的**唯一内容**，必须能在单测里逐字钉住；
 * * `org.json` 会把 `120.0` 输出成 `120`、把键序交给 `JSONObject`（HashMap 顺序），
 *   差分脚本按行对比两个版本的快照时会读到「字段抖动」而不是「这一页变慢了」。
 *
 * 因此这里按 Dart 的规则复刻：
 * * 缩进 2 空格、每层一行，`[]` / `{}` 空容器写在一行；
 * * 键序 = 传入 Map 的迭代顺序（本仓一律用 `linkedMapOf` 构造快照）；
 * * `int/long` 不带小数点，`double` 即使是整数值也带 `.0`（Dart 的 `60.0`）；
 * * 字符串只转义 `"`、`\` 与控制字符，非 ASCII 原样输出（Dart 的默认行为）。
 *
 * 已知的边界差异（不追求完全一致，且当前快照不会出现）：Dart 对极大/极小 double 用
 * `1e+21` 形态，Java 用 `1.0E21`。快照里的数都是毫秒、百分比、刷新率，不会触到。
 */
internal fun dartJsonEncodePretty(value: Any?): String {
    val builder = StringBuilder()
    writeValue(builder, value, 0)
    return builder.toString()
}

/** 顶层入口（页面与导出共用），非 internal 供宿主调用。 */
fun perfSnapshotJsonText(value: Any?): String = dartJsonEncodePretty(value)

private fun writeValue(out: StringBuilder, value: Any?, depth: Int) {
    when (value) {
        null -> out.append("null")
        is String -> writeString(out, value)
        is Boolean -> out.append(if (value) "true" else "false")
        is Double -> writeDouble(out, value)
        is Float -> writeDouble(out, value.toDouble())
        is Int, is Long, is Short, is Byte -> out.append(value.toString())
        is Map<*, *> -> writeMap(out, value, depth)
        is Iterable<*> -> writeList(out, value, depth)
        is Array<*> -> writeList(out, value.toList(), depth)
        else -> writeString(out, value.toString())
    }
}

private fun writeMap(out: StringBuilder, map: Map<*, *>, depth: Int) {
    if (map.isEmpty()) {
        out.append("{}")
        return
    }
    out.append("{\n")
    var first = true
    for ((key, value) in map) {
        if (!first) out.append(",\n")
        first = false
        indent(out, depth + 1)
        writeString(out, key.toString())
        out.append(": ")
        writeValue(out, value, depth + 1)
    }
    out.append('\n')
    indent(out, depth)
    out.append('}')
}

private fun writeList(out: StringBuilder, list: Iterable<*>, depth: Int) {
    val iterator = list.iterator()
    if (!iterator.hasNext()) {
        out.append("[]")
        return
    }
    out.append("[\n")
    var first = true
    for (item in list) {
        if (!first) out.append(",\n")
        first = false
        indent(out, depth + 1)
        writeValue(out, item, depth + 1)
    }
    out.append('\n')
    indent(out, depth)
    out.append(']')
}

private fun indent(out: StringBuilder, depth: Int) {
    for (i in 0 until depth) out.append("  ")
}

private fun writeDouble(out: StringBuilder, value: Double) {
    if (!value.isFinite()) {
        // Dart 的 JSON 编码器对 NaN / Infinity 会抛错；这里退化成字符串，
        // 至少不会让「复制快照」整条路径挂掉，也不会伪造一个数字。
        writeString(out, value.toString())
        return
    }
    if (value == Math.floor(value) && Math.abs(value) < 1e15) {
        out.append(String.format(Locale.US, "%.0f", value)).append(".0")
        return
    }
    out.append(value.toString())
}

private fun writeString(out: StringBuilder, raw: String) {
    out.append('"')
    for (ch in raw) {
        when (ch) {
            '"' -> out.append("\\\"")
            '\\' -> out.append("\\\\")
            '\n' -> out.append("\\n")
            '\r' -> out.append("\\r")
            '\t' -> out.append("\\t")
            '\b' -> out.append("\\b")
            '\u000C' -> out.append("\\f")
            else -> if (ch < ' ') {
                out.append(String.format(Locale.US, "\\u%04x", ch.code))
            } else {
                out.append(ch)
            }
        }
    }
    out.append('"')
}
