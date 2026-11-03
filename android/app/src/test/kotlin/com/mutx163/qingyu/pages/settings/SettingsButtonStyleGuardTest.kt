package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 设置域「按钮看得出来」守卫（2026-11-03）。
 *
 * ## 它防的是哪一类事故
 *
 * 2026-11-03 用户实报桌面小组件设置页两处按钮问题：
 * 1. 「添加到桌面」按钮容器走官方 `buttonColors()` 默认值（`secondaryVariant` 亮 #F0F0F0），
 *    与设置页底 #F2F2F2 的 WCAG 对比比 ~1.02，整个融进背景；
 * 2. `ControlCard` 引导条按钮（精确闹钟「去授权」等）无宽度约束，缩成左上「一小块」。
 *
 * 判据是**源码文本**（同 [ButtonContrastGuardTest] 的家法），两条：
 * - **配色**：受守文件里 `buttonColors(...)` / `textButtonColors(...)` 的顶层实参
 *   不得出现 `Color(0x…)` 写死色（R5）；页面级 `Button(`/`TextButton(` 调用必须显式传
 *   `colors =`（弹层内的默认灰是官方正统用法，不在此守卫范围——受守文件清单里只放
 *   页面级文件）。
 * - **宽度**：`ControlCard` 里的按钮必须带 `fillMaxWidth` / `weight(` 整宽约束。
 *
 * 数值判据（给定两色算不算「融」）在 `com.mutx163.qingyu.utils.ButtonContrastRules`。
 *
 * ⚠️ 文本判据对格式敏感；受守文件若重命名/移动，`GUARDED_FILES` 必须同步，否则空跑假绿
 * （哨兵用例会先红）。匹配前剥掉行注释、块注释（Kotlin 块注释**可嵌套**）与字符串字面量，
 * 防注释里的示例代码误报——`注释里的关键字不触发判据` 用例钉住这一点。
 */
class SettingsButtonStyleGuardTest {

    @Test
    fun `受守文件必须存在且扫得到按钮与配色调用`() {
        val texts = GUARDED_FILES.map { path ->
            val file = File(repoRoot(), path)
            assertTrue(
                "守卫目标文件不存在：${file.absolutePath}。文件改名/移动后必须同步更新本守卫。",
                file.isFile,
            )
            file.readText()
        }
        val buttonCount = texts.sumOf { buttonCalls(it).size }
        val colorsCount = texts.sumOf { colorsCalls(it).size }
        assertTrue("受守文件里一个 Button( 都没有，判据已失效（空跑假绿）", buttonCount >= 1)
        assertTrue("受守文件里一个 buttonColors( 都没有，判据已失效（空跑假绿）", colorsCount >= 1)
    }

    @Test
    fun `按钮配色不得写死ARGB字面量`() {
        val violations = mutableListOf<String>()
        for (entry in GUARDED_FILES) {
            val stripped = stripCommentsAndStrings(File(repoRoot(), entry).readText())
            for (call in colorsCalls(stripped)) {
                if (call.arguments.contains(COLOR_LITERAL)) {
                    violations += "${entry.replace('\\', '/')}:${call.line} ${call.arguments.take(60)}"
                }
            }
            // 容器色直接写死（不经过 buttonColors）同样不行。
            stripped.lineSequence().forEachIndexed { index, line ->
                if (line.contains("containerColor") && line.contains(COLOR_LITERAL)) {
                    violations += "${entry.replace('\\', '/')}:${index + 1} $line"
                }
            }
        }
        assertTrue(
            "按钮/容器配色禁止写死 Color(0x…)（R5）：换主题色/深色模式必然错。" +
                "主操作用 ButtonDefaults.buttonColorsPrimary()，次操作用 " +
                "buttonColors(color = colorScheme.secondary, contentColor = onSecondaryVariant)。" +
                "违规位置：\n" + violations.joinToString("\n") { "    $it" },
            violations.isEmpty(),
        )
    }

    @Test
    fun `页面级按钮必须显式传colors`() {
        val entry = GUARDED_FILES.first { it.endsWith("HomeWidgetPreviewCarousel.kt") }
        val stripped = stripCommentsAndStrings(File(repoRoot(), entry).readText())
        val violations = buttonCalls(stripped)
            .filter { topLevelArgument(it.arguments, "colors") == null }
            .map { "${entry.replace('\\', '/')}:${it.line}" }
        assertTrue(
            "设置页页面级 Button/TextButton 落在页底 #F2F2F2 上，官方默认容器色" +
                "（secondaryVariant #F0F0F0）对比比 ~1.02 会融进背景，必须显式传 colors。" +
                "违规位置：\n" + violations.joinToString("\n") { "    $it" },
            violations.isEmpty(),
        )
    }

    @Test
    fun `控制卡按钮必须整宽`() {
        val entry = GUARDED_FILES.first { it.endsWith("SettingsPageRenderers.kt") }
        val stripped = stripCommentsAndStrings(File(repoRoot(), entry).readText())
        val body = functionBody(stripped, "private fun ControlCard(")
        assertTrue("SettingsPageRenderers.kt 里找不到 ControlCard(，判据已失效", body != null)
        val buttons = buttonCalls(body!!)
        assertTrue("ControlCard 体内扫不到 Button(，判据已失效", buttons.isNotEmpty())
        val violations = buttons
            .filter { call ->
                !call.arguments.contains("fillMaxWidth") && !call.arguments.contains("weight(")
            }
            .map { "${entry.replace('\\', '/')}:${it.line}" }
        assertTrue(
            "ControlCard 的按钮必须有整宽约束（单按钮 fillMaxWidth，多按钮 weight 平分），" +
                "裸 Button( 会缩成左上一小块。违规位置：\n" +
                violations.joinToString("\n") { "    $it" },
            violations.isEmpty(),
        )
    }

    @Test
    fun `注释与字符串里的关键字不触发判据`() {
        val code = """
            class Sample {
                // Button(onClick = {}) 这行是注释，不算页面级裸按钮
                /* buttonColors(color = Color(0xFF123456)) 块注释也不算 */
                val doc = "buttonColors(color = ${'$'}{Color(0xFF123456)})"
                fun render() {
                    Button(
                        onClick = {},
                        colors = ButtonDefaults.buttonColors(
                            color = MiuixTheme.colorScheme.secondary,
                            contentColor = MiuixTheme.colorScheme.onSecondaryVariant,
                        ),
                    ) { Text(text = "ok") }
                }
            }
        """.trimIndent()
        val stripped = stripCommentsAndStrings(code)
        // 注释/字符串剥离后，只剩一处真实的 buttonColors( 且不带写死色。
        val colorCalls = colorsCalls(stripped)
        assertTrue("剥离后应恰好剩 1 处真实 buttonColors(，实际 ${colorCalls.size}", colorCalls.size == 1)
        assertTrue(
            "剥离失败：注释/字符串里的写死色仍然参与了匹配",
            colorCalls.none { it.arguments.contains(COLOR_LITERAL) },
        )
        // 真实按钮带了 colors ⇒ 页面级判据应放行。
        val bareButtons = buttonCalls(stripped)
            .filter { topLevelArgument(it.arguments, "colors") == null }
        assertTrue("带 colors 的按钮不应被判违规", bareButtons.isEmpty())
    }

    // ------------------------------------------------------------------
    // 判据工具（源码文本 → 剥注释/字符串 → 按括号配平取调用）
    // ------------------------------------------------------------------

    private data class SourceCall(val line: Int, val arguments: String)

    /**
     * 剥掉行注释、**可嵌套**块注释与字符串字面量（普通 + `"""` 原始串），
     * 防注释示例代码 / 文案里的符号绕过或误报。Kotlin 块注释支持嵌套（`/* /* */ */`）。
     */
    private fun stripCommentsAndStrings(text: String): String {
        val out = StringBuilder(text.length)
        var i = 0
        var blockDepth = 0
        while (i < text.length) {
            if (blockDepth > 0) {
                if (text.startsWith("/*", i)) {
                    blockDepth++
                    i += 2
                } else if (text.startsWith("*/", i)) {
                    blockDepth--
                    i += 2
                } else {
                    if (text[i] == '\n') out.append('\n')
                    i++
                }
                continue
            }
            if (text.startsWith("//", i)) {
                while (i < text.length && text[i] != '\n') i++
                continue
            }
            if (text.startsWith("/*", i)) {
                blockDepth = 1
                i += 2
                continue
            }
            val quote = rawStringLength(text, i)
            if (quote > 0) {
                // 字符串整体替换成等长空白（保留引号位便于占位，行号不漂移）。
                repeat(quote) { out.append(' ') }
                i += quote
                continue
            }
            if (text[i] == '\'') {
                // 字符字面量：跳过转义。
                out.append(' ')
                i++
                while (i < text.length && text[i] != '\'') {
                    if (text[i] == '\\' && i + 1 < text.length) i++
                    i++
                }
                if (i < text.length) {
                    out.append(' ')
                    i++
                }
                continue
            }
            out.append(text[i])
            i++
        }
        return out.toString()
    }

    /** `i` 处若是字符串开头，返回整串长度（含引号）；否则 0。支持 `"""` 原始串。 */
    private fun rawStringLength(text: String, i: Int): Int {
        if (text.startsWith("\"\"\"", i)) {
            var j = i + 3
            while (j < text.length && !text.startsWith("\"\"\"", j)) j++
            return if (j >= text.length) text.length - i else j + 3 - i
        }
        if (i < text.length && text[i] == '"') {
            var j = i + 1
            while (j < text.length) {
                when {
                    text[j] == '\\' -> j += 2
                    text[j] == '\n' -> return j - i // 未闭合按到行尾，别吞整个文件
                    text[j] == '"' -> return j + 1 - i
                    else -> j++
                }
            }
            return text.length - i
        }
        return 0
    }

    /** 取所有 `Button(`/`TextButton(` 调用（词边界排除 `ButtonDefaults` 等前缀同名）。 */
    private fun buttonCalls(text: String): List<SourceCall> = callsAt(text, "Button(")

    /** 取所有 `buttonColors(`/`textButtonColors(` 调用。 */
    private fun colorsCalls(text: String): List<SourceCall> =
        callsAt(text, "buttonColors(") + callsAt(text, "textButtonColors(")

    private fun callsAt(text: String, token: String): List<SourceCall> {
        val result = mutableListOf<SourceCall>()
        var from = 0
        while (true) {
            val start = text.indexOf(token, from)
            if (start < 0) break
            val prevOk = start == 0 || !(text[start - 1].isLetterOrDigit() || text[start - 1] == '_')
            if (!prevOk) {
                from = start + token.length
                continue
            }
            val openParen = start + token.length - 1
            val close = matching(text, openParen, '(', ')')
            if (close < 0) break
            result += SourceCall(
                line = text.take(start).count { it == '\n' } + 1,
                arguments = text.substring(openParen + 1, close),
            )
            from = close
        }
        return result
    }

    /** 配平取 [openIndex] 对应闭括号下标；找不到返回 -1。 */
    private fun matching(text: String, openIndex: Int, open: Char, close: Char): Int {
        var depth = 0
        var i = openIndex
        while (i < text.length) {
            when (text[i]) {
                open -> depth++
                close -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
    }

    /** 取 `name = …` 的**顶层**实参文本；没有则 null（同 ButtonContrastGuardTest 口径）。 */
    private fun topLevelArgument(args: String, name: String): String? {
        var depth = 0
        var i = 0
        while (i < args.length) {
            when (args[i]) {
                '(', '[', '{' -> depth++
                ')', ']', '}' -> depth--
            }
            if (depth == 0 && args.startsWith(name, i)) {
                val before = if (i == 0) ' ' else args[i - 1]
                val afterName = i + name.length
                val boundaryBefore = !(before.isLetterOrDigit() || before == '_')
                val equals = args.indexOf('=', afterName)
                val boundaryAfter = equals >= 0 && args.substring(afterName, equals).isBlank()
                if (boundaryBefore && boundaryAfter) {
                    var end = equals + 1
                    var inner = 0
                    while (end < args.length) {
                        when (args[end]) {
                            '(', '[', '{' -> inner++
                            ')', ']', '}' -> inner--
                            ',' -> if (inner == 0) return args.substring(equals + 1, end)
                        }
                        end++
                    }
                    return args.substring(equals + 1, end)
                }
            }
            i++
        }
        return null
    }

    /** 取 [signature] 之后第一个 `{` 配平的函数体；找不到返回 null。 */
    private fun functionBody(text: String, signature: String): String? {
        val start = text.indexOf(signature)
        if (start < 0) return null
        val openBrace = text.indexOf('{', start + signature.length)
        if (openBrace < 0) return null
        val closeBrace = matching(text, openBrace, '{', '}')
        if (closeBrace < 0) return null
        return text.substring(openBrace, closeBrace + 1)
    }

    private fun repoRoot(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "android/app/src").isDirectory) {
                var up: File? = dir
                while (up != null) {
                    if (File(up, "lib/screens").isDirectory && File(up, "pubspec.yaml").isFile) {
                        return up.path
                    }
                    up = up.parentFile
                }
                return dir.path
            }
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（android/app/src）—— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private companion object {
        /**
         * 只守本批改过的两个设置域文件（多 Agent 并行，别把别人在途的文件记进来）。
         * HomeWidgetPreviewCarousel = 页面级按钮；SettingsPageRenderers = ControlCard 共享渲染层。
         */
        val GUARDED_FILES = listOf(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/HomeWidgetPreviewCarousel.kt",
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt",
        )

        const val COLOR_LITERAL = "Color(0x"
    }
}
