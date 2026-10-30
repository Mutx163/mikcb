package com.mutx163.qingyu.pages.import.warehouse

/**
 * 极简 YAML 解析：从仓库文件里抠出「一个顶层键 → 一串映射」。
 *
 * ## 为什么自己写，而不是引 yaml 库
 *
 * 适配仓（`Mutx163/qingyu_warehouse`）里只有两种文件形状：
 * `index/root_index.yaml` 的 `schools:` 与 `resources/<学校>/adapters.yaml` 的 `adapters:`——
 * 都是「顶层键 + 两块缩进的 `- key: value`」。Dart 侧也是自己写的 60 行解析器
 * （`lib/services/warehouse_repository_service.dart` 的 `_parseYamlListMaps`），
 * 本文件是它的逐条移植。**不引第三方 YAML 库**的理由：仓库里零 YAML 依赖，
 * 为一个 60 行的子集拉一个解析库，会让 L0 单测多一份外部 jar 与一套版本兼容问题。
 *
 * ## 语义（与 Dart 逐条对齐，改动任何一条都要同步改 Dart 或写清理由）
 *
 * 1. 行按 `\n` 切，行尾 `\r` 剥掉（Dart 用 `RegExp(r'\r?\n')`）；
 * 2. 制表符先换成两个空格**再算缩进**（仓库文件是手写的，混入 tab 时不能把缩进算成 1）；
 * 3. 空行与 `#` 开头的行跳过；
 * 4. 找到与 [topLevelKey] **完全相等**的 `key:` 行之前一律不认；之后：
 *    - 缩进 0 且以 `:` 结尾 ⇒ 下一节开始，**停**（不能把后面的节读进来）；
 *    - 缩进 == 2 且以 `- ` 开头 ⇒ 新条目；
 *    - 缩进 >= 4 ⇒ 当前条目的一个键值对；
 * 5. `key: value` 的分隔是**冒号加空格**（`a:b` 不是键值对）；值会剥行内注释、剥成对引号、
 *    再解 `\n` `\r` `\t` 三个转义（Dart 的 `_decodeEscapedYamlText` 也只解这三个）；
 * 6. 空条目（一个键都没读到）**不产出**——Dart 的 `current.isNotEmpty()` 判断。
 *
 * 已知**不**支持（仓库文件里没出现，硬塞进来会解错而不是解不出）：多行标量 `|` / `>`、
 * 列表套列表、单引号里的 `''` 转义、无空格的 `key:value`。
 */
object WarehouseYamlList {

    /** 取 [topLevelKey] 这一节下的条目列表；键不存在或该节为空时回空列表。 */
    fun parse(content: String, topLevelKey: String): List<Map<String, String>> {
        val items = mutableListOf<Map<String, String>>()
        var inSection = false
        var current: MutableMap<String, String>? = null

        for (rawLine in content.split("\n")) {
            val normalizedLine = rawLine.removeSuffix("\r").replace("\t", "  ")
            val trimmed = normalizedLine.trim()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                continue
            }

            if (!inSection) {
                if (trimmed == "$topLevelKey:") {
                    inSection = true
                }
                continue
            }

            val indent = normalizedLine.length - normalizedLine.trimStart().length
            if (indent == 0 && trimmed.endsWith(":")) {
                break
            }

            if (indent == 2 && trimmed.startsWith("- ")) {
                // 上一条要落盘（空条目不产出，见 KDoc 第 6 条）。
                current?.let { previous ->
                    if (previous.isNotEmpty()) {
                        items.add(previous)
                    }
                }
                val fresh = mutableMapOf<String, String>()
                current = fresh
                val pairText = trimmed.substring(2).trim()
                if (pairText.isNotEmpty()) {
                    parsePair(pairText)?.let { (key, value) -> fresh[key] = value }
                }
                continue
            }

            if (indent >= 4) {
                val entry = current ?: continue
                parsePair(trimmed)?.let { (key, value) -> entry[key] = value }
            }
        }

        current?.let { last ->
            if (last.isNotEmpty()) {
                items.add(last)
            }
        }
        return items
    }

    /** `key: value` → 键值对；不是键值对（没冒号、冒号在行首）回 `null`。 */
    fun parsePair(line: String): Pair<String, String>? {
        val separatorIndex = line.indexOf(": ")
        if (separatorIndex <= 0) {
            return null
        }
        val key = line.substring(0, separatorIndex).trim()
        val value = line.substring(separatorIndex + 2).trim()
        return key to decodeEscaped(stripInlineComment(value))
    }

    /**
     * 剥行内注释：只有**不在引号里**的 `#` 才算注释起点。
     *
     * 例：`name: 正方#教务` 保留 `#`（没有空格前缀也照样算 URL/名字的一部分），
     * `name: 正方教务  # 备注` 剥成 `正方教务`。Dart 用的是「引号配对 + 遇 `#` 断」，
     * 与「`#` 前必须有空格」不同，**照抄它**以免两边解析结果分叉。
     */
    fun stripInlineComment(value: String): String {
        if (value.isEmpty() || !value.contains('#')) {
            return value
        }
        val buffer = StringBuilder()
        var inSingleQuote = false
        var inDoubleQuote = false
        for (char in value) {
            if (char == '\'' && !inDoubleQuote) {
                inSingleQuote = !inSingleQuote
            } else if (char == '"' && !inSingleQuote) {
                inDoubleQuote = !inDoubleQuote
            }
            if (char == '#' && !inSingleQuote && !inDoubleQuote) {
                break
            }
            buffer.append(char)
        }
        return buffer.toString().trimEnd()
    }

    /**
     * 剥成对引号 + 解三个转义。
     *
     * 长度判断 `>= 2` 是**故意加的护栏**：Dart 里 `value = "'"` 会走进 `substring(1, 0)` 抛
     * `RangeError`；仓库文件里不会出现，但解析器不该因为一行坏数据把整页打崩。
     */
    fun decodeEscaped(value: String): String {
        var text = value
        if (text.length >= 2) {
            val doubleQuoted = text.startsWith("\"") && text.endsWith("\"")
            val singleQuoted = text.startsWith("'") && text.endsWith("'")
            if (doubleQuoted || singleQuoted) {
                text = text.substring(1, text.length - 1)
            }
        }
        return text
            .replace("\\n", "\n")
            .replace("\\r", "\r")
            .replace("\\t", "\t")
            .trim()
    }
}
