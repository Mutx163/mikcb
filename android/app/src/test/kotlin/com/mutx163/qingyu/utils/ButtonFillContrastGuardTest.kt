package com.mutx163.qingyu.utils

import com.mutx163.qingyu.theme.QingyuTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「全库按钮都得看得出是按钮」守卫（2026-11-08）。
 *
 * ## 它防的是哪一类事故
 *
 * 用户 2026-11-08 实报：外观编辑页壁纸弹层里「调整位置 / 清除图片 / Bing 每日壁纸」
 * 三颗按钮**颜色跟背景一样**，看不出是可点的按钮。
 *
 * 根因不是某页写错，而是**调色板**：miuix 的 `ButtonDefaults.buttonColors()` /
 * `textButtonColors()` 的 `color` 默认值都是 `secondaryVariant`（`Button.kt:181` / `:217`），
 * 官方值是 `#F0F0F0`——配它自己的纯白弹层底是 demo 那块浅灰（对比比 ~1.14）。本仓
 * 把页底/弹层底换成设置页的 `#F2F2F2` 后，槽位没跟着动 ⇒ 对比比 ~1.02，整块融进背景。
 *
 * 同一类错误还有第二种写法：显式 `color = MiuixTheme.colorScheme.surfaceVariant`
 * ——该槽在本仓亮色下是**纯白**（未覆写，官方默认），落在白卡上对比比 1.0，完全隐形。
 *
 * ## 判据（三条，都是可复算的）
 *
 * 1. **数值**：`QingyuTheme.secondary`（#E6E6E6）落在 `scaffoldBackground`（#F2F2F2）上
 *    必须过 [ButtonContrastRules.isIndistinguishable] 这一关（实测 ~1.115，与 demo
 *    在纯白上的 1.14 同档）。
 * 2. **主题绑定**：亮色板必须把 `secondaryVariant` / `disabledSecondaryVariant` 显式绑到
 *    `secondary`；不绑就会静默回落到官方 `#F0F0F0` / `#F2F2F2`（后者与弹层底**完全同色**）。
 *    这条是源码文本判据——调色板是私有 `@Composable`，单测拿不到实例，只能钉绑定写法。
 * 3. **全库扫描**：`android/app/src` 下任何 `buttonColors(...)` 顶层实参都不得把 `color`
 *    写成 `MiuixTheme.colorScheme.surfaceVariant`。
 *
 * ⚠️ 文本判据对格式敏感，匹配前剥掉注释与字符串（Kotlin 块注释可嵌套），否则本文件的
 * KDoc 示例自己就会被判违规。哨兵用例保证扫描器真的扫到了东西，不会空跑假绿。
 */
class ButtonFillContrastGuardTest {

    // ---------------------------------------------------------------- 1. 数值

    @Test
    fun `亮色次要按钮灰落在页底上_必须是一眼能看出的浅灰而不是同色`() {
        val fill = QingyuTheme.secondary(dark = false)
        val background = QingyuTheme.scaffoldBackground(dark = false)
        val ratio = ButtonContrastRules.contrastRatio(fill, background)
        assertFalse(
            "secondary(#E6E6E6) 与页底 #F2F2F2 的对比比是 $ratio，被判「融进背景」——" +
                "次要按钮又会变成一行浮在背景上的字。",
            ButtonContrastRules.isIndistinguishable(fill, background),
        )
        // 官方 demo 里 #F0F0F0 落纯白是 1.14；本仓这档要落在同一个台阶上（±0.05）。
        assertEquals("与 demo 的 1.14 台阶不一致", 1.14, ratio, 0.05)
    }

    @Test
    fun `禁用态在与弹层底同色时必须被换掉`() {
        // miuix 官方亮色 disabledSecondaryVariant = #F2F2F2，与本仓弹层底**逐位同色**。
        val officialDisabled = 0xFFF2F2F2.toInt()
        assertTrue(
            "前提失效：官方禁用色已不再是 #F2F2F2，本用例要重新核一遍（不要直接删）",
            ButtonContrastRules.isIndistinguishable(
                officialDisabled,
                QingyuTheme.scaffoldBackground(dark = false),
            ),
        )
        // 本仓口径：常态色 60% 叠在底上（同 miuix MonetMapping 的做法）。
        val blended = blendOver(
            foreground = QingyuTheme.secondary(dark = false),
            background = QingyuTheme.scaffoldBackground(dark = false),
            alpha = 0.6,
        )
        assertFalse(
            "禁用态按钮（secondary@60%）与页底同色，禁用/可用两态只剩字色差别",
            ButtonContrastRules.isIndistinguishable(
                blended,
                QingyuTheme.scaffoldBackground(dark = false),
            ),
        )
    }

    // ---------------------------------------------------------- 2. 主题绑定

    @Test
    fun `亮色板必须把次要按钮槽显式绑到secondary`() {
        val path = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuPageTheme.kt"
        val file = File(repoRoot(), path)
        assertTrue("主题文件不存在：${file.absolutePath}，判据无法验证", file.isFile)
        val code = stripCommentsAndStrings(file.readText())
        assertTrue(
            "亮色板没有绑 `secondaryVariant`——它会静默回落到 miuix 官方 #F0F0F0，" +
                "而本仓页底是 #F2F2F2，对比比只有 ~1.02（2026-11-08 壁纸弹层实报）。",
            regex("secondaryVariant\\s*=\\s*Color\\(QingyuTheme\\.secondary\\(dark = false\\)\\)")
                .containsMatchIn(code),
        )
        assertTrue(
            "亮色板没有绑 `disabledSecondaryVariant`——官方默认 #F2F2F2 与弹层底完全同色，" +
                "禁用按钮会彻底消失。",
            regex("disabledSecondaryVariant\\s*=\\s*Color\\(QingyuTheme\\.secondary\\(dark = false\\)\\)\\.copy\\(alpha = 0\\.6f\\)")
                .containsMatchIn(code),
        )
    }

    // ------------------------------------------------------------ 3. 全库扫描

    @Test
    fun `扫描器必须真的扫到按钮配色调用`() {
        val files = sourceFiles()
        assertTrue("扫描根目录下没有 .kt 文件，判据已失效", files.size >= 50)
        val callCount = files.sumOf { colorsCalls(stripCommentsAndStrings(it.readText())).size }
        assertTrue("全库一个 buttonColors( 都没扫到，判据已失效（空跑会假绿）", callCount >= 50)
    }

    @Test
    fun `按钮底色不得写成surfaceVariant_该槽亮色是纯白`() {
        val violations = mutableListOf<String>()
        for (file in sourceFiles()) {
            val code = stripCommentsAndStrings(file.readText())
            for (call in colorsCalls(code)) {
                val color = topLevelArgument(call.arguments, "color") ?: continue
                if (!color.contains("surfaceVariant")) continue
                // `onSurfaceVariant*` 是墨色不是容器色，别误伤。
                if (regex("(?<![A-Za-z0-9_])surfaceVariant").find(color) == null) continue
                violations += "${relative(file)}:${call.line}"
            }
        }
        assertTrue(
            "按钮容器色写成 `colorScheme.surfaceVariant`：本仓亮色该槽未覆写 = 纯白，" +
                "落在白卡 / 白底上 WCAG 对比比 1.0，按钮完全隐形（2026-11-08 同批修复）。" +
                "次操作请用 `colorScheme.secondary`（#E6E6E6）+ `onSecondaryVariant` 墨。" +
                "违规位置：\n" + violations.joinToString("\n") { "    $it" },
            violations.isEmpty(),
        )
    }

    // ------------------------------------------------------------------ 工具

    /** 扫描范围：生产源码两处源集（composeP1 页面层 + main 宿主/主题层）。 */
    private fun sourceFiles(): List<File> {
        val root = repoRoot()
        return listOf("android/app/src/composeP1/kotlin", "android/app/src/main/kotlin")
            .map { File(root, it) }
            .filter { it.isDirectory }
            .flatMap { dir -> dir.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList() }
    }

    private fun relative(file: File): String {
        val root = File(repoRoot()).absolutePath
        return file.absolutePath.removePrefix(root).trimStart('\\', '/').replace('\\', '/')
    }

    private data class SourceCall(val line: Int, val arguments: String)

    private fun colorsCalls(text: String): List<SourceCall> =
        callsAt(text, "buttonColors(") + callsAt(text, "textButtonColors(")

    private fun callsAt(text: String, token: String): List<SourceCall> {
        val result = mutableListOf<SourceCall>()
        var from = 0
        while (true) {
            val start = text.indexOf(token, from)
            if (start < 0) break
            val prev = if (start == 0) ' ' else text[start - 1]
            if (prev.isLetterOrDigit() || prev == '_') {
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

    /** 取 `name = …` 的顶层实参文本；没有则 null。 */
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
                val beforeOk = !(before.isLetterOrDigit() || before == '_')
                val equals = args.indexOf('=', afterName)
                val afterOk = equals >= 0 && args.substring(afterName, equals).isBlank()
                if (beforeOk && afterOk) {
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

    /** 剥掉行注释、可嵌套块注释与字符串字面量（含 `"""`），保留换行以免行号漂移。 */
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
            val quoted = quotedLength(text, i)
            if (quoted > 0) {
                repeat(quoted) { out.append(' ') }
                i += quoted
                continue
            }
            out.append(text[i])
            i++
        }
        return out.toString()
    }

    /** `i` 处若是字符串开头，返回整串长度（含引号）；否则 0。 */
    private fun quotedLength(text: String, i: Int): Int {
        if (text.startsWith("\"\"\"", i)) {
            var j = i + 3
            while (j < text.length && !text.startsWith("\"\"\"", j)) j++
            return if (j >= text.length) text.length - i else j + 3 - i
        }
        if (text[i] != '"') return 0
        var j = i + 1
        while (j < text.length) {
            when {
                text[j] == '\\' -> j += 2
                text[j] == '\n' -> return j - i
                text[j] == '"' -> return j + 1 - i
                else -> j++
            }
        }
        return text.length - i
    }

    private fun regex(pattern: String) = Regex(pattern)

    /** 把 [foreground] 按 [alpha] 叠在 [background] 上，返回不透明 ARGB。 */
    private fun blendOver(foreground: Int, background: Int, alpha: Double): Int {
        fun channel(shift: Int): Int {
            val f = (foreground ushr shift) and 0xFF
            val b = (background ushr shift) and 0xFF
            return Math.round(f * alpha + b * (1 - alpha)).toInt()
        }
        return (0xFF shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
    }

    private fun repoRoot(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "android/app/src").isDirectory) return dir.path
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（android/app/src）—— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }
}
