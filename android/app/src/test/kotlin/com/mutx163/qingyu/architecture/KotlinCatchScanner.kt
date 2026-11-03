package com.mutx163.qingyu.architecture

/**
 * 供 `SilentFailureCatchGuardTest` 使用的极简 Kotlin 词法器。
 *
 * 只做一件事：找出「catch 体为空」的位置。注释与字符串会被跳过，
 * 因此注释里的 `catch { }` 或字符串里的同名字样不会误判；花括号靠配对判断，
 * 所以 `catch (e: Exception) { /* 只有注释 */ }` 会被判为空。
 */
internal object KotlinCatchScanner {

    private data class Token(val text: String, val line: Int)

    private class EmptyCatchFound(val line: Int)

    @Suppress("TooGenericExceptionCaught")
    fun findEmptyCatchLines(source: String): List<Int> {
        val tokens = tokenize(source)
        val hits = mutableListOf<Int>()
        var i = 0
        while (i < tokens.size) {
            if (tokens[i].text == "catch") {
                var j = i + 1
                // 可选的 catch 参数：catch (...) 或 catch { }。
                if (j < tokens.size && tokens[j].text == "(") {
                    var depth = 0
                    while (j < tokens.size) {
                        if (tokens[j].text == "(") depth++
                        if (tokens[j].text == ")") {
                            depth--
                            if (depth == 0) {
                                j++
                                break
                            }
                        }
                        j++
                    }
                }
                if (j < tokens.size && tokens[j].text == "{") {
                    if (j + 1 < tokens.size && tokens[j + 1].text == "}") {
                        hits += tokens[i].line
                        i = j + 1
                        continue
                    }
                }
            }
            i++
        }
        return hits
    }

    private fun tokenize(source: String): List<Token> {
        val tokens = mutableListOf<Token>()
        var i = 0
        var line = 1
        while (i < source.length) {
            val c = source[i]
            when {
                c == '\n' -> {
                    line++
                    i++
                }
                c.isWhitespace() -> i++
                c == '/' && i + 1 < source.length && source[i + 1] == '/' -> {
                    while (i < source.length && source[i] != '\n') i++
                }
                c == '/' && i + 1 < source.length && source[i + 1] == '*' -> {
                    i += 2
                    while (i < source.length) {
                        if (source[i] == '\n') line++
                        if (source[i] == '*' && i + 1 < source.length && source[i + 1] == '/') {
                            i += 2
                            break
                        }
                        i++
                    }
                }
                c == '"' && i + 2 < source.length && source[i + 1] == '"' && source[i + 2] == '"' -> {
                    i += 3
                    while (i < source.length) {
                        if (source[i] == '\n') line++
                        if (source[i] == '"' && i + 2 < source.length &&
                            source[i + 1] == '"' && source[i + 2] == '"'
                        ) {
                            i += 3
                            break
                        }
                        i++
                    }
                }
                c == '"' || c == '\'' -> {
                    val quote = c
                    i++
                    while (i < source.length) {
                        val ch = source[i]
                        if (ch == '\n') line++
                        if (ch == '\\' && i + 1 < source.length) {
                            if (source[i + 1] == '\n') line++
                            i += 2
                            continue
                        }
                        i++
                        if (ch == quote) break
                    }
                }
                c.isLetter() || c == '_' -> {
                    val start = i
                    while (i < source.length && (source[i].isLetterOrDigit() || source[i] == '_')) i++
                    tokens += Token(source.substring(start, i), line)
                }
                c == '{' || c == '}' || c == '(' || c == ')' -> {
                    tokens += Token(c.toString(), line)
                    i++
                }
                else -> i++
            }
        }
        return tokens
    }
}
