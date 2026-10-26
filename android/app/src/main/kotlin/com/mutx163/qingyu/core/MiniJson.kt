package com.mutx163.qingyu.core

/**
 * DartFormatException：Dart 侧 `throw FormatException(...)` 的对应物。
 *
 * Course/Exam/CourseTask/ScheduleItem/TimeScheme/SavedTheme 的 fromJson 靠
 * 「结构性缺失抛错」接入「坏条目留档、不写回」的自愈机制
 * （storage_service_profiles_integrity_test.dart:104 钉着），
 * Kotlin 侧用同一个异常类型承载这条契约。
 */
class DartFormatException(message: String) : RuntimeException(message)

/**
 * 手写最小 JSON 编解码（仅 Kotlin stdlib，零第三方依赖）。
 *
 * ## 为什么不用 org.json
 *
 * `org.json` 在 JVM 单测下被 `testOptions.unitTests.returnDefaultValues = true`
 * 兜底：所有方法返回默认值（null/0/false），JSONObject 不可用；kotlinx-serialization
 * 不在依赖里。本族是纯逻辑层，JSON 编解码按任务书允许由本层自持——后续数据族若引入
 * 真正的 JSON 依赖，可用它整体替换（API 只有两个入口 [parse] / [encode]）。
 *
 * ## 与 Dart jsonEncode/jsonDecode 的口径
 *
 * - 解码产物：Map=LinkedHashMap（保序）、List=ArrayList、String、Long（整数）、
 *   Double（带小数/指数）、Boolean、null。Dart int 是 64 位 → Long。
 * - 编码：Map 按迭代序输出（Dart Map 字面量同样是插入序）；Double 整数值输出 `x.0`
 *   （jsonEncode(1.0) == "1.0"）；非 ASCII 不转义（Dart 同样输出原始字符）。
 * - 编码失败不可能发生（树本身来自解析或纯数据），Dart 侧 catch 后回退
 *   `"${item.toString()}"` 的分支由调用方自理。
 */
object MiniJson {

    fun parse(text: String): Any? {
        val p = Parser(text)
        val value = p.parseValue()
        p.skipWhitespace()
        if (!p.atEnd()) {
            throw DartFormatException("trailing characters in JSON at ${p.pos}")
        }
        return value
    }

    /** 解析失败返回 null（对应 Dart `jsonDecode` 会抛，这里给调用方一个宽松入口）。 */
    fun tryParse(text: String?): Any? {
        if (text == null) return null
        return try {
            parse(text)
        } catch (_: Exception) {
            null
        }
    }

    fun encode(value: Any?): String {
        val sb = StringBuilder()
        writeValue(sb, value)
        return sb.toString()
    }

    private fun writeValue(sb: StringBuilder, value: Any?) {
        when (value) {
            null -> sb.append("null")
            is String -> writeString(sb, value)
            is Boolean -> sb.append(if (value) "true" else "false")
            is Int, is Long -> sb.append(value.toString())
            is Double -> sb.append(formatDouble(value))
            is Float -> sb.append(formatDouble(value.toDouble()))
            is Map<*, *> -> {
                sb.append('{')
                var first = true
                for ((k, v) in value) {
                    if (!first) sb.append(',')
                    first = false
                    writeString(sb, k.toString())
                    sb.append(':')
                    writeValue(sb, v)
                }
                sb.append('}')
            }
            is List<*> -> {
                sb.append('[')
                var first = true
                for (item in value) {
                    if (!first) sb.append(',')
                    first = false
                    writeValue(sb, item)
                }
                sb.append(']')
            }
            else -> writeString(sb, value.toString())
        }
    }

    private fun formatDouble(d: Double): String {
        if (d.isNaN() || d.isInfinite()) return "null"
        // 整数值（含 -0.0 之外的一切 x.0）必须带 .0，Dart jsonEncode 同口径。
        return if (d == Math.floor(d) && !d.isInfinite() && Math.abs(d) < 1e15) {
            d.toLong().toString() + ".0"
        } else {
            d.toString()
        }
    }

    private fun writeString(sb: StringBuilder, s: String) {
        sb.append('"')
        for (ch in s) {
            when {
                ch == '"' -> sb.append("\\\"")
                ch == '\\' -> sb.append("\\\\")
                ch == '\b' -> sb.append("\\b")
                ch == '' -> sb.append("\\f")
                ch == '\n' -> sb.append("\\n")
                ch == '\r' -> sb.append("\\r")
                ch == '\t' -> sb.append("\\t")
                ch < ' ' -> sb.append("\\u").append(String.format("%04x", ch.code))
                else -> sb.append(ch)
            }
        }
        sb.append('"')
    }

    private class Parser(val text: String) {
        var pos = 0

        fun atEnd(): Boolean = pos >= text.length

        fun skipWhitespace() {
            while (pos < text.length) {
                val c = text[pos]
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r') pos++ else break
            }
        }

        fun parseValue(): Any? {
            skipWhitespace()
            if (atEnd()) throw DartFormatException("unexpected end of JSON")
            return when (val c = text[pos]) {
                '{' -> parseObject()
                '[' -> parseArray()
                '"' -> parseString()
                't' -> parseKeyword("true", true)
                'f' -> parseKeyword("false", false)
                'n' -> parseKeyword("null", null)
                else -> {
                    if (c == '-' || c in '0'..'9') parseNumber()
                    else throw DartFormatException("unexpected character '$c' at $pos")
                }
            }
        }

        private fun parseKeyword(word: String, value: Any?): Any? {
            if (!text.startsWith(word, pos)) {
                throw DartFormatException("invalid literal at $pos")
            }
            pos += word.length
            return value
        }

        private fun parseObject(): LinkedHashMap<String, Any?> {
            val map = LinkedHashMap<String, Any?>()
            pos++ // '{'
            skipWhitespace()
            if (!atEnd() && text[pos] == '}') {
                pos++
                return map
            }
            while (true) {
                skipWhitespace()
                if (atEnd() || text[pos] != '"') {
                    throw DartFormatException("expected string key at $pos")
                }
                val key = parseString()
                skipWhitespace()
                if (atEnd() || text[pos] != ':') {
                    throw DartFormatException("expected ':' at $pos")
                }
                pos++
                map[key] = parseValue()
                skipWhitespace()
                if (atEnd()) throw DartFormatException("unterminated object")
                when (text[pos]) {
                    ',' -> pos++
                    '}' -> {
                        pos++
                        return map
                    }
                    else -> throw DartFormatException("expected ',' or '}' at $pos")
                }
            }
        }

        private fun parseArray(): ArrayList<Any?> {
            val list = ArrayList<Any?>()
            pos++ // '['
            skipWhitespace()
            if (!atEnd() && text[pos] == ']') {
                pos++
                return list
            }
            while (true) {
                list.add(parseValue())
                skipWhitespace()
                if (atEnd()) throw DartFormatException("unterminated array")
                when (text[pos]) {
                    ',' -> pos++
                    ']' -> {
                        pos++
                        return list
                    }
                    else -> throw DartFormatException("expected ',' or ']' at $pos")
                }
            }
        }

        private fun parseString(): String {
            pos++ // '"'
            val sb = StringBuilder()
            while (true) {
                if (atEnd()) throw DartFormatException("unterminated string")
                when (val c = text[pos]) {
                    '"' -> {
                        pos++
                        return sb.toString()
                    }
                    '\\' -> {
                        pos++
                        if (atEnd()) throw DartFormatException("unterminated escape")
                        when (val e = text[pos]) {
                            '"' -> sb.append('"')
                            '\\' -> sb.append('\\')
                            '/' -> sb.append('/')
                            'b' -> sb.append('\b')
                            'f' -> sb.append('')
                            'n' -> sb.append('\n')
                            'r' -> sb.append('\r')
                            't' -> sb.append('\t')
                            'u' -> {
                                if (pos + 4 >= text.length) {
                                    throw DartFormatException("bad unicode escape at $pos")
                                }
                                val hex = text.substring(pos + 1, pos + 5)
                                sb.append(hex.toInt(16).toChar())
                                pos += 4
                            }
                            else -> throw DartFormatException("bad escape '\\$e' at $pos")
                        }
                        pos++
                    }
                    else -> {
                        sb.append(c)
                        pos++
                    }
                }
            }
        }

        private fun parseNumber(): Any {
            val start = pos
            if (text[pos] == '-') pos++
            while (pos < text.length && text[pos] in '0'..'9') pos++
            var isDouble = false
            if (pos < text.length && text[pos] == '.') {
                isDouble = true
                pos++
                while (pos < text.length && text[pos] in '0'..'9') pos++
            }
            if (pos < text.length && (text[pos] == 'e' || text[pos] == 'E')) {
                isDouble = true
                pos++
                if (pos < text.length && (text[pos] == '+' || text[pos] == '-')) pos++
                while (pos < text.length && text[pos] in '0'..'9') pos++
            }
            val raw = text.substring(start, pos)
            return if (isDouble) {
                raw.toDoubleOrNull() ?: throw DartFormatException("bad number '$raw'")
            } else {
                raw.toLongOrNull() ?: raw.toDoubleOrNull()
                ?: throw DartFormatException("bad number '$raw'")
            }
        }
    }
}
