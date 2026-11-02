package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「同色底 + 同色字」按钮守卫（2026-11-02 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 2026-11-02 的弹窗审核（`docs/plans/2026-11-02-compose-dialog-full-audit.md` P1）发现：
 * 情侣课表设置页与坚果云连接弹层里，几处按钮写成
 *
 * ```kotlin
 * ButtonDefaults.buttonColors(
 *     color = Color(QingyuTheme.primarySurface(dark = dark)),
 *     contentColor = Color(QingyuTheme.primary(dark = dark)),
 * )
 * ```
 *
 * 作者的本意是「浅色主色底 + 主色字」的 tonal 次级按钮，但
 * `QingyuTheme.primarySurface(seedHex = null)` 在没有自定义种子色时**直接返回 `PRIMARY`**
 * ——于是底色和字色是同一个值，按钮标签完全看不见。代码能编译、单测全绿，
 * 只有真机（且默认主题色）盯屏才看得出来。
 *
 * ## 口径
 *
 * - 主操作：`ButtonDefaults.buttonColorsPrimary()`（强调色实心）；
 * - 次操作：`ButtonDefaults.buttonColors()`（`secondaryVariant` 灰底 + `onSecondaryVariant` 深字）。
 *
 * 判据是源码文本：在同一个 `buttonColors(...)` 的**顶层**实参里，`color` 与 `contentColor`
 * 一个是 `primarySurface`、另一个是 `primary` ⇒ 失败。按括号配平等价取实参，
 * 避免嵌套括号把 `Color(...)` 截断（`ComposeSheetGuardTest` 踩过这个坑）。
 *
 * ⚠️ 文本判据对格式敏感，且范围**只限于这两个文件**（多 Agent 并行，别把别人的在途代码
 * 记到本守卫头上）。文件里将来若一个 `buttonColors(` 都不剩，空跑哨兵会先红——
 * 那是提醒更新判据，不是静默失效。
 */
class ButtonContrastGuardTest {

    @Test
    fun `扫描器必须真的扫到按钮配色调用`() {
        val scanned = GUARDED_FILES.map { path ->
            val file = File(repoRoot(), path)
            assertTrue(
                "守卫目标文件不存在：${file.absolutePath}（user.dir=${System.getProperty("user.dir")}）。" +
                    "文件改名/移动后必须同步更新本守卫，否则它会空跑假绿。",
                file.isFile,
            )
            file.readText()
        }
        val callCount = scanned.sumOf { callArguments(it).size }
        assertTrue(
            "两个目标文件里一个 `buttonColors(` 调用都没扫到，判据已失效（门禁空跑会假绿）",
            callCount >= 1,
        )
    }

    @Test
    fun `不允许 primarySurface 底配 primary 字`() {
        val violations = mutableListOf<String>()
        for (path in GUARDED_FILES) {
            val text = File(repoRoot(), path).readText()
            for (call in callArguments(text)) {
                val color = topLevelArgument(call.arguments, "color")
                val contentColor = topLevelArgument(call.arguments, "contentColor")
                if (color == null || contentColor == null) continue
                val sameColorPair =
                    (color.contains(PRIMARY_SURFACE) && PRIMARY_TOKEN.containsMatchIn(contentColor)) ||
                        (contentColor.contains(PRIMARY_SURFACE) && PRIMARY_TOKEN.containsMatchIn(color))
                if (sameColorPair) {
                    violations += "${path.replace('\\', '/')}:${call.line}"
                }
            }
        }
        assertTrue(
            "`primarySurface` + `primary` 在无 seed 时是同一颜色，按钮文字不可见；" +
                "主操作用 `ButtonDefaults.buttonColorsPrimary()`，次操作用 `ButtonDefaults.buttonColors()`。" +
                "违规位置：\n" + violations.joinToString("\n") { "    $it" },
            violations.isEmpty(),
        )
    }

    // ------------------------------------------------------------------
    // 判据
    // ------------------------------------------------------------------

    private data class ButtonColorsCall(val line: Int, val arguments: String)

    /** 取出所有 `buttonColors(...)` 的实参文本与起始行号（排除 `textButtonColors(`）。 */
    private fun callArguments(text: String): List<ButtonColorsCall> {
        val result = mutableListOf<ButtonColorsCall>()
        var from = 0
        while (true) {
            val start = text.indexOf(CALL, from)
            if (start < 0) break
            // `textButtonColors(` 的尾巴也是 `buttonColors(` —— 卡词边界排除。
            if (start > 0 && (text[start - 1].isLetterOrDigit() || text[start - 1] == '_')) {
                from = start + CALL.length
                continue
            }
            val openParen = start + CALL.length - 1
            val close = matchingParen(text, openParen)
            if (close < 0) break
            result += ButtonColorsCall(
                line = text.take(start).count { it == '\n' } + 1,
                arguments = text.substring(openParen + 1, close),
            )
            from = close
        }
        return result
    }

    private fun matchingParen(text: String, openIndex: Int): Int {
        var depth = 0
        var i = openIndex
        while (i < text.length) {
            when (text[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
    }

    /** 取**顶层** `name = …` 的实参文本（到同层逗号为止）；没有则 null。 */
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
                // `colors` / `colorXxx` 不算：名字后面必须只剩空白再接 `=`。
                val equals = args.indexOf('=', afterName)
                val boundaryAfter = equals >= 0 && args.substring(afterName, equals).isBlank()
                if (boundaryBefore && boundaryAfter) {
                    var end = equals + 1
                    var inner = 0
                    while (end < args.length) {
                        val ch = args[end]
                        when (ch) {
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
        /** 只守这两处（多 Agent 并行时别把别人在途的代码记到本守卫头上）。 */
        val GUARDED_FILES = listOf(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CoupleTimetableSettingsPage.kt",
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CoupleWebdavConnectSheet.kt",
        )

        const val CALL = "buttonColors("
        const val PRIMARY_SURFACE = "primarySurface"

        /** 只认 `primary(` / `primary =`，别把 `primarySurface` / `primaryText` 也算成 primary。 */
        val PRIMARY_TOKEN = Regex("""\bprimary\s*[\(.]""")
    }
}
