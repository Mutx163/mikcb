package com.mutx163.qingyu.pages.about

/**
 * 更新日志的「分块」纯逻辑（移植 `lib/screens/about_screen.dart:128-205`，
 * 2026-10-26 快照）。
 *
 * ## 为什么要把一段 Markdown 切开
 *
 * Dart 源码注释写得很清楚：`MarkdownBody` 会把**整段输入**一次解析、一次建完整棵
 * widget 树。短段落没问题，但一份长更新公告可能有几百行列表项，整棵树一起建就是
 * 卡顿来源。把「标题」与「顶层列表项」各自切成一独立块，列表就能按视口只挂载
 * 附近那几块。
 *
 * 因此这个函数的产物是**渲染层的输入契约**：块数、块内容、块边界只要漂移，
 * 长日志页的挂载行为就跟着变。这里把规则逐条钉住。
 */

/** Dart `_releaseNotesVersionHeadingPattern`：`^#\s+v[\d.\-a-zA-Z]+$`（大小写不敏感）。 */
private val releaseNotesVersionHeadingPattern =
    Regex("^#\\s+v[\\d.\\-a-zA-Z]+$", RegexOption.IGNORE_CASE)

/** Dart `_releaseNotesHeadingPattern`：`^#{1,6}\s+`。 */
private val releaseNotesHeadingPattern = Regex("^#{1,6}\\s+")

/** Dart `_releaseNotesTopLevelBulletPattern`：`^(?:[-+*]|\d+[.)])\s+`。 */
private val releaseNotesTopLevelBulletPattern = Regex("^(?:[-+*]|\\d+[.)])\\s+")

/**
 * 把更新公告切成可懒加载的 Markdown 块。规则（与 Dart 逐条对齐）：
 *
 * 1. `\r\n` 与 `\r` 先归一成 `\n`；归一后 `trim` 为空 → 空列表；
 * 2. 跳过开头所有空行；若第一个有内容的行是**版本标题**（`# v1.2.3` 形态），
 *    这一行被丢掉（标题由界面自己画，不重复渲染）；
 * 3. 逐行扫描，命中下面任一条就**结块**：
 *    - 标题行（`#{1,6}` + 空白，且不在代码围栏内）；
 *    - **顶层**列表项（`-`/`+`/`*` 或 `1.`/`1)` 开头 + 空白，且不在围栏内）——
 *      注意缩进的嵌套项不匹配，因此会留在父项那块里；
 *    - 空行（不在围栏内）：只结块、不保留空行（Markdown 渲染自己会加段距）；
 * 4. 代码围栏：以 ` ``` ` 或 `~~~` 开头的行**切换**围栏状态。围栏内的标题、列表项、
 *    空行一律不结块——代码块里的 `# 注释` 不该被当成标题切开；
 * 5. 每块内容做 `trim`，空块不入列。
 */
fun splitReleaseNotesIntoBlocks(data: String): List<String> {
    val normalized = data.replace("\r\n", "\n").replace("\r", "\n")
    if (normalized.trim().isEmpty()) {
        return emptyList()
    }

    val lines = normalized.split("\n")
    var firstContentLine = 0
    while (firstContentLine < lines.size && lines[firstContentLine].trim().isEmpty()) {
        firstContentLine++
    }
    if (firstContentLine < lines.size &&
        releaseNotesVersionHeadingPattern.matches(lines[firstContentLine].trim())
    ) {
        firstContentLine++
    }

    val blocks = mutableListOf<String>()
    val currentLines = mutableListOf<String>()
    var insideCodeFence = false

    fun flushCurrentBlock() {
        val block = currentLines.joinToString("\n").trim()
        if (block.isNotEmpty()) {
            blocks.add(block)
        }
        currentLines.clear()
    }

    for (index in firstContentLine until lines.size) {
        val line = lines[index]
        val trimmedLine = line.trim()
        val isCodeFenceMarker = trimmedLine.startsWith("```") || trimmedLine.startsWith("~~~")
        // 注意：标题/列表项判据打在**原始行**上（不是 trim 后的），缩进即不匹配。
        val startsHeading = !insideCodeFence && releaseNotesHeadingPattern.containsMatchIn(line)
        val startsTopLevelBullet = !insideCodeFence && releaseNotesTopLevelBulletPattern.containsMatchIn(line)

        if (startsHeading || startsTopLevelBullet) {
            flushCurrentBlock()
            currentLines.add(line)
        } else if (trimmedLine.isEmpty() && !insideCodeFence) {
            flushCurrentBlock()
        } else {
            currentLines.add(line)
        }

        // 围栏切换在块处理**之后**：围栏那一行本身仍会进入当前块。
        if (isCodeFenceMarker) {
            insideCodeFence = !insideCodeFence
        }
    }
    flushCurrentBlock()
    return blocks
}
