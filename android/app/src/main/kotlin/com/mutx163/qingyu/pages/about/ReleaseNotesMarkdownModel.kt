package com.mutx163.qingyu.pages.about

/**
 * 发布说明正文的 **Markdown 轻量解析**（纯逻辑，JVM 可测）。
 *
 * 移植 `lib/widgets/release_notes_markdown.dart` 的行为，但不引入 Markdown 依赖
 * （Kotlin 侧没有 flutter_markdown_plus 的等价物，也不想为一段兜底渲染加依赖）：
 * 只覆盖发布说明里真实出现的语法——标题、无序/有序列表、段落、分隔线，
 * 行内的粗体 / 斜体 / 行内代码 / 链接。
 *
 * 目的是给「版本更新页」的更新说明**兜底分支**（解析不出结构化条目时）一个比纯文本更接近
 * 原版的渲染：粗体标签不再退化成纯字符、链接不再和正文一个样、`---` 不再显示成一行横杠。
 */
enum class MdBlockKind { PARAGRAPH, HEADING1, HEADING2, HEADING3, HEADING4, BULLET, NUMBERED, RULE }

/** 一个行内片段（同一行内的样式单位）。 */
data class MdSpan(
    val text: String,
    val bold: Boolean = false,
    val italic: Boolean = false,
    val code: Boolean = false,
    val linkUrl: String? = null,
)

/** 一个块级元素。[marker] 只对 [MdBlockKind.NUMBERED] 有意义（原始序号如 "1"）。 */
data class MdBlock(
    val kind: MdBlockKind,
    val spans: List<MdSpan> = emptyList(),
    val marker: String? = null,
)

/** Dart `_versionHeadingPattern = ^#\s+v[\d.\-a-zA-Z]+`（`:29-32`）。 */
private val versionHeadingPattern = Regex("""^#\s+v[\d.\-a-zA-Z]+""", RegexOption.IGNORE_CASE)
private val rulePattern = Regex("""^\s*([-*_])\1{2,}\s*$""")
private val headingPattern = Regex("""^(#{1,6})\s+(.*)$""")
private val bulletPattern = Regex("""^\s*[-*+]\s+(.*)$""")
private val numberedPattern = Regex("""^\s*(\d+)[.)]\s+(.*)$""")
private val blockquotePattern = Regex("""^\s*>\s?(.*)$""")

/**
 * 把一段发布说明正文解析成块列表。[stripVersionHeading] 对应 Dart 的
 * `plainTypography = true`（更新页/更新日志页都用它）：去掉开头那行 `# v1.2.3` 版本标题。
 */
fun buildReleaseNotesMarkdownBlocks(
    data: String,
    stripVersionHeading: Boolean = true,
): List<MdBlock> {
    if (data.isBlank()) return emptyList()
    var lines = data.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    if (stripVersionHeading && lines.isNotEmpty() &&
        versionHeadingPattern.containsMatchIn(lines.first().trim())
    ) {
        var start = 1
        while (start < lines.size && lines[start].trim().isEmpty()) start++
        lines = lines.subList(start, lines.size)
    }

    val blocks = ArrayList<MdBlock>()
    val paragraph = ArrayList<String>()

    fun flushParagraph() {
        if (paragraph.isEmpty()) return
        val joined = paragraph.joinToString(" ").trim()
        paragraph.clear()
        if (joined.isNotEmpty()) blocks.add(MdBlock(MdBlockKind.PARAGRAPH, parseInline(joined)))
    }

    for (raw in lines) {
        val line = raw
        val trimmed = line.trim()
        if (trimmed.isEmpty()) {
            flushParagraph()
            continue
        }
        if (rulePattern.matches(line)) {
            flushParagraph()
            blocks.add(MdBlock(MdBlockKind.RULE))
            continue
        }
        val heading = headingPattern.matchEntire(trimmed)
        if (heading != null) {
            flushParagraph()
            val level = heading.groupValues[1].length
            val kind = when (level) {
                1 -> MdBlockKind.HEADING1
                2 -> MdBlockKind.HEADING2
                3 -> MdBlockKind.HEADING3
                else -> MdBlockKind.HEADING4
            }
            blocks.add(MdBlock(kind, parseInline(heading.groupValues[2].trim())))
            continue
        }
        val bullet = bulletPattern.matchEntire(line)
        if (bullet != null) {
            flushParagraph()
            blocks.add(MdBlock(MdBlockKind.BULLET, parseInline(bullet.groupValues[1].trim())))
            continue
        }
        val numbered = numberedPattern.matchEntire(line)
        if (numbered != null) {
            flushParagraph()
            blocks.add(
                MdBlock(
                    MdBlockKind.NUMBERED,
                    parseInline(numbered.groupValues[2].trim()),
                    marker = numbered.groupValues[1],
                ),
            )
            continue
        }
        val quote = blockquotePattern.matchEntire(line)
        if (quote != null) {
            // 引用块按普通段落画（Dart 的 blockquote 也是复用 body 样式，只多左缩进）。
            paragraph.add(quote.groupValues[1].trim())
            continue
        }
        paragraph.add(trimmed)
    }
    flushParagraph()
    return blocks
}

/** 行内解析：粗体 / 斜体 / 行内代码 / 链接（单层，不做嵌套）。 */
fun parseInline(text: String): List<MdSpan> {
    val spans = ArrayList<MdSpan>()
    val buffer = StringBuilder()
    fun flush() {
        if (buffer.isNotEmpty()) {
            spans.add(MdSpan(buffer.toString()))
            buffer.setLength(0)
        }
    }
    var i = 0
    while (i < text.length) {
        val ch = text[i]
        // **bold** / __bold__
        if (text.startsWith("**", i)) {
            val end = text.indexOf("**", i + 2)
            if (end > i + 2) {
                flush(); spans.add(MdSpan(text.substring(i + 2, end), bold = true)); i = end + 2; continue
            }
        }
        if (text.startsWith("__", i)) {
            val end = text.indexOf("__", i + 2)
            if (end > i + 2) {
                flush(); spans.add(MdSpan(text.substring(i + 2, end), bold = true)); i = end + 2; continue
            }
        }
        // `code`
        if (ch == '`') {
            val end = text.indexOf('`', i + 1)
            if (end > i + 1) {
                flush(); spans.add(MdSpan(text.substring(i + 1, end), code = true)); i = end + 1; continue
            }
        }
        // [text](url)
        if (ch == '[') {
            val close = text.indexOf(']', i + 1)
            if (close > 0 && close + 1 < text.length && text[close + 1] == '(') {
                val urlEnd = text.indexOf(')', close + 2)
                if (urlEnd > close + 2) {
                    flush()
                    spans.add(
                        MdSpan(
                            text = text.substring(i + 1, close),
                            linkUrl = text.substring(close + 2, urlEnd),
                        ),
                    )
                    i = urlEnd + 1
                    continue
                }
            }
        }
        // *italic* / _italic_
        if (ch == '*') {
            val end = text.indexOf('*', i + 1)
            if (end > i + 1) {
                flush(); spans.add(MdSpan(text.substring(i + 1, end), italic = true)); i = end + 1; continue
            }
        }
        if (ch == '_') {
            val end = text.indexOf('_', i + 1)
            if (end > i + 1) {
                flush(); spans.add(MdSpan(text.substring(i + 1, end), italic = true)); i = end + 1; continue
            }
        }
        buffer.append(ch)
        i++
    }
    flush()
    if (spans.isEmpty()) spans.add(MdSpan(""))
    return spans
}
