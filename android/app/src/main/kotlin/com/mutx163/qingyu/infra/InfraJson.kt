package com.mutx163.qingyu.infra

/**
 * 本族自持的最小 JSON 编解码（仅 Kotlin stdlib，零第三方依赖）。
 *
 * 不复用 `core/MiniJson`：core 是第一团队在途改动区，跨泳道依赖会把两个族的
 * 合入顺序绑死；本族只需要「对象/数组/字符串/数/布尔/null」往返，自持一份
 * 更小的实现，待 Lead 合入时统一替换。
 *
 * 口径：解码产物 Map=LinkedHashMap（保序）、List=ArrayList、String、Long（整数）、
 * Double（小数/指数）、Boolean、null；编码非 ASCII 不转义、控制字符转义。
 */
internal object InfraJson {

    fun tryParse(text: String?): Any? {
        if (text == null) {
            return null
        }
        return try {
            parse(text)
        } catch (_: Exception) {
            null
        }
    }

    fun parse(text: String): Any? {
        val parser = Parser(text)
        val value = parser.parseValue()
        parser.skipWhitespace()
        if (!parser.atEnd()) {
            throw IllegalArgumentException("trailing characters in JSON at ${parser.pos}")
        }
        return value
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
            is Long -> sb.append(value.toString())
            is Int -> sb.append(value.toString())
            is Double -> sb.append(value.toString())
            is Float -> sb.append(value.toDouble().toString())
            is Map<*, *> -> {
                sb.append('{')
                var first = true
                for ((k, v) in value) {
                    if (!first) {
                        sb.append(',')
                    }
                    first = false
                    writeString(sb, k.toString())
                    sb.append(':')
                    writeValue(sb, v)
                }
                sb.append('}')
            }
            is Iterable<*> -> {
                sb.append('[')
                var first = true
                for (item in value) {
                    if (!first) {
                        sb.append(',')
                    }
                    first = false
                    writeValue(sb, item)
                }
                sb.append(']')
            }
            else -> writeString(sb, value.toString())
        }
    }

    private fun writeString(sb: StringBuilder, value: String) {
        sb.append('"')
        for (c in value) {
            when (c.code) {
                0x22 -> sb.append("\\\"")
                0x5C -> sb.append("\\\\")
                0x0A -> sb.append("\\n")
                0x0D -> sb.append("\\r")
                0x09 -> sb.append("\\t")
                0x08 -> sb.append("\\b")
                0x0C -> sb.append("\\f")
                else -> if (c.code < 0x20) {
                    sb.append("\\u").append(c.code.toString(16).padStart(4, '0'))
                } else {
                    sb.append(c)
                }
            }
        }
        sb.append('"')
    }

    private class Parser(val text: String) {
        var pos = 0

        fun atEnd(): Boolean = pos >= text.length

        fun skipWhitespace() {
            while (pos < text.length && text[pos].isWhitespace()) {
                pos++
            }
        }

        fun parseValue(): Any? {
            skipWhitespace()
            if (pos >= text.length) {
                throw IllegalArgumentException("unexpected end of JSON")
            }
            return when (text[pos]) {
                '{' -> parseObject()
                '[' -> parseArray()
                '"' -> parseString()
                't' -> expectLiteral("true", true)
                'f' -> expectLiteral("false", false)
                'n' -> expectLiteral("null", null)
                else -> parseNumber()
            }
        }

        private fun expectLiteral(literal: String, value: Any?): Any? {
            if (!text.startsWith(literal, pos)) {
                throw IllegalArgumentException("invalid literal at $pos")
            }
            pos += literal.length
            return value
        }

        private fun parseObject(): Map<String, Any?> {
            pos++
            val result = linkedMapOf<String, Any?>()
            skipWhitespace()
            if (pos < text.length && text[pos] == '}') {
                pos++
                return result
            }
            while (true) {
                skipWhitespace()
                if (pos >= text.length || text[pos] != '"') {
                    throw IllegalArgumentException("expected string key at $pos")
                }
                val key = parseString()
                skipWhitespace()
                if (pos >= text.length || text[pos] != ':') {
                    throw IllegalArgumentException("expected ':' at $pos")
                }
                pos++
                result[key] = parseValue()
                skipWhitespace()
                if (pos >= text.length) {
                    throw IllegalArgumentException("unterminated object")
                }
                if (text[pos] == '}') {
                    pos++
                    return result
                }
                if (text[pos] != ',') {
                    throw IllegalArgumentException("expected ',' at $pos")
                }
                pos++
            }
        }

        private fun parseArray(): List<Any?> {
            pos++
            val result = arrayListOf<Any?>()
            skipWhitespace()
            if (pos < text.length && text[pos] == ']') {
                pos++
                return result
            }
            while (true) {
                result.add(parseValue())
                skipWhitespace()
                if (pos >= text.length) {
                    throw IllegalArgumentException("unterminated array")
                }
                if (text[pos] == ']') {
                    pos++
                    return result
                }
                if (text[pos] != ',') {
                    throw IllegalArgumentException("expected ',' at $pos")
                }
                pos++
            }
        }

        private fun parseString(): String {
            pos++
            val sb = StringBuilder()
            while (true) {
                if (pos >= text.length) {
                    throw IllegalArgumentException("unterminated string")
                }
                val c = text[pos++]
                if (c == '"') {
                    return sb.toString()
                }
                if (c != '\\') {
                    sb.append(c)
                    continue
                }
                if (pos >= text.length) {
                    throw IllegalArgumentException("unterminated escape")
                }
                val e = text[pos++]
                when (e) {
                    '"', '\\', '/' -> sb.append(e)
                    'b' -> sb.append('\b')
                    'n' -> sb.append('\n')
                    'r' -> sb.append('\r')
                    't' -> sb.append('\t')
                    'u' -> {
                        if (pos + 4 > text.length) {
                            throw IllegalArgumentException("bad unicode escape at $pos")
                        }
                        val hex = text.substring(pos, pos + 4)
                        sb.append(hex.toInt(16).toChar())
                        pos += 4
                    }
                    else -> if (e == 'f') {
                        sb.append(0x0C.toChar())
                    } else {
                        throw IllegalArgumentException("bad escape at $pos")
                    }
                }
            }
        }

        private fun parseNumber(): Any {
            val start = pos
            if (pos < text.length && (text[pos] == '-' || text[pos] == '+')) {
                pos++
            }
            while (pos < text.length && (text[pos].isDigit() || text[pos] == '.' ||
                    text[pos] == 'e' || text[pos] == 'E' || text[pos] == '+' || text[pos] == '-')
            ) {
                pos++
            }
            val token = text.substring(start, pos)
            if (token.isEmpty()) {
                throw IllegalArgumentException("invalid number at $start")
            }
            return if (token.contains('.') || token.contains('e') || token.contains('E')) {
                token.toDouble()
            } else {
                token.toLong()
            }
        }
    }
}
