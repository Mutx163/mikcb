package com.mutx163.qingyu.pages

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import kotlin.math.abs

/**
 * 弹层套件**观感刻度守卫**（2026-11-10，随「弹层套件观感专项」建立）。
 *
 * ## 钉的是什么
 *
 * `ComposeSheetGuardTest` 已经钉住了「不许绕开套件」与危险色写法（S1/S1D/S3/S4）。
 * 本条守卫钉的是**刻度**——一旦某个调用点自己传了本该由套件统一给的值，
 * 套件的口径就会被悄悄打回原形，而这四个值全都是「不编译报错、只有真机盯屏才看得出」：
 *
 * | 规则 | 判据 | 为什么 |
 * |---|---|---|
 * | K1 | 宿主不许给 `QingyuSheet` 传 `insideMargin` / `cornerRadius` / `backgroundColor` | 三个都是套件统一口径（16dp / 28dp / 主题底色），一个调用点自己传就会与邻居不一致 |
 * | K2 | 宿主不许传 `startAction` / `endAction` | 这两个参数 2026-11-10 已从套件删除：start 槽现在承载套件自绘的标题（发布版 17sp/w400/左对齐），再被人拿去放别的东西，标题就没了 |
 * | K3 | `maxHeightFraction` 的**字面量**必须是发布版出现过的档位 | 发布版最高档 0.88；随手写 0.9/0.95 会让面板顶到接近满屏、读起来像整页（套件默认已是 0.88，正常情况不用传） |
 * | K4 | 套件自己必须真的钉住 S3/S4/S5 | 防「套件被改回去了但没人发现」：源码层断言标题走 start 槽、圆角显式给、限高有默认值 |
 *
 * ## 哨兵（防空跑假绿）
 *
 * 扫描根失效时文件数为 0、调用点数为 0，所有判据都会「全绿」。所以先断言
 * 「扫到 ≥ 40 个源文件、≥ 40 个 `QingyuSheet(` 调用点」——与 `ComposeSheetGuardTest` 同口径。
 * 实测 2026-11-10：51 个调用点 / 34 个宿主文件。
 */
class QingyuSheetScaleGuardTest {

    @Test
    fun `扫描器必须真的扫到弹层调用点`() {
        val files = composeFiles()
        assertTrue(
            "composeP1 源文件数为 ${files.size}，扫描根疑似失效（门禁空跑会假绿）。" +
                "user.dir=${System.getProperty("user.dir")} root=${composeRoot().absolutePath}",
            files.size >= 40,
        )
        val calls = files.sumOf { sheetCallArguments(it.readText()).size }
        assertTrue("一个 QingyuSheet 调用点都没扫到（应为 50 上下），判据已失效", calls >= 40)
    }

    @Test
    fun `宿主不许自己传套件已有的刻度`() {
        val offenders = mutableListOf<String>()
        for (file in composeFiles()) {
            val relative = relativeName(file)
            if (relative == SHEET_SUITE_FILE) continue // 套件自己当然要传
            if (relative.startsWith(SHOWCASE_PREFIX)) continue // 展厅是故意展示官方裸默认值的地方
            violations(file.readText()).forEach { offenders += "$relative $it" }
        }
        assertEquals(
            "以下调用点自己传了本该由套件统一给的刻度（口径会被打回原形，且只有盯屏才看得出）：\n" +
                offenders.joinToString("\n") { "    $it" },
            emptyList<String>(),
            offenders,
        )
    }

    @Test
    fun `套件必须真的钉住标题槽与圆角与默认限高`() {
        val suite = File(composeRoot(), "com/mutx163/qingyu/$SHEET_SUITE_FILE")
        assertTrue("套件文件不存在：${suite.absolutePath}", suite.isFile)
        val code = stripKotlinComments(suite.readText())
        val expected = mapOf(
            "S3 标题走 start 槽（不再交给 miuix 的 title，那个槽画死 18sp/w500/居中）"
                to "startAction = titleAction",
            "S3 不许把标题交回 miuix 的 title 槽" to "title = null",
            "S4 圆角显式钉住（= 上游默认 = 发布版引用值）"
                to "cornerRadius = QingyuSheetDefaults.CornerRadius",
            "S5 默认不额外限高（发布版 46 个弹层就不设，交给窗口兜底）"
                to "if (maxHeightFraction != null) {",
            "S3 标题取官方 17sp 字阶（headline1）"
                to "MiuixTheme.textStyles.headline1",
        )
        val missing = expected.filterValues { it !in code }.keys.toList()
        assertTrue(
            "套件源码里找不到这些刻度，说明它们被改回去了：\n" + missing.joinToString("\n") { "    - $it" },
            missing.isEmpty(),
        )
    }

    @Test
    fun `判据必须剥掉注释——注释里写着刻度不算传了`() {
        val commentOnly = """
            QingyuSheet(
                show = true,
                // insideMargin = DpSize(16.dp, 16.dp) 的口径见套件文档
                onDismissRequest = {},
            ) { }
        """.trimIndent()
        assertTrue("注释里写 insideMargin 不算传（否则讲历史的注释会让守卫假红）", violations(commentOnly).isEmpty())

        val realPass = """
            QingyuSheet(
                show = true,
                insideMargin = DpSize(16.dp, 16.dp), // 老写法，现在套件统一给
                onDismissRequest = {},
            ) { }
        """.trimIndent()
        assertTrue("真传了 insideMargin 必须判红（剥注释不能把真账一起剥掉）", violations(realPass).isNotEmpty())
    }

    @Test
    fun `限高字面量只认发布版档位`() {
        assertTrue("0.95 不在发布版档位里，必须判红", violations(sheetWith("0.95f")).isNotEmpty())
        assertTrue("0.9 也不在（发布版最高 0.88）", violations(sheetWith("0.9f")).isNotEmpty())
        assertTrue("0.88 是发布版最高档，应放行", violations(sheetWith("0.88f")).isEmpty())
        assertTrue("0.62 是发布版档位（memory_stats）", violations(sheetWith("0.62f")).isEmpty())
        assertTrue(
            "常量 / 表达式放行（本仓大量用 `SHEET_MAX_HEIGHT_FRACTION` 这类命名常量）",
            violations(sheetWith("SHEET_MAX_HEIGHT_FRACTION")).isEmpty(),
        )
    }

    @Test
    fun `守卫的档位表必须与套件一致`() {
        // 守卫故意**不 import** `QingyuSheetDefaults`（composeP1 不在 L0 的 kotlinc classpath 里，
        // 带进一个 compose 依赖会让 `-Module pages` 的 L0 直接红）。所以档位表在这里留一份副本，
        // 由本条测试从套件源码里反解出来比对 —— 改一边忘另一边就红。
        val suite = stripKotlinComments(suiteSource())
        val block = Regex("""AllowedMaxHeightFractions: List<Float>\s*=\s*listOf\(([^)]*)\)""")
            .find(suite) ?: throw AssertionError("套件里找不到 `AllowedMaxHeightFractions = listOf(...)`")
        val fromSuite = Regex("""\d+(?:\.\d+)?[fF]?""")
            .findAll(block.groupValues[1])
            .map { it.value.removeSuffix("f").removeSuffix("F").toFloat() }
            .toList()
        assertEquals(
            "守卫里的档位表与套件不一致（改一边要同步另一边）：守卫=${ALLOWED_FRACTIONS} 套件=${fromSuite}",
            ALLOWED_FRACTIONS,
            fromSuite,
        )
    }

    @Test
    fun `标题必须锁在 17sp-w400-左对齐-行高1_2`() {
        // 评审 三-02：标题三件（字号 / 字重 / 对齐）2026-11-10 刚从 miuix 的居中 18sp/w500
        // 改回发布版口径，必须被钉住，否则下一次「顺手调大一点」就悄悄回去了。
        val code = stripKotlinComments(suiteSource())
        assertTrue(
            "标题样式必须取官方字阶 headline1（miuix 0.9.4 = 17sp = 发布版 preferenceTitleSize）",
            "MiuixTheme.textStyles.headline1" in code,
        )
        assertFalse(
            "不许写死 fontSize：字号必须来自官方字阶（写死会盖掉用户字号/系统设置）",
            "fontSize = " in code,
        )
        assertFalse(
            "不许写死 fontWeight：w400 由主题字阶平移给出（写死会盖掉用户字重与系统粗体）",
            "fontWeight = FontWeight" in code,
        )
        assertFalse(
            "标题必须左对齐（走 start 槽）：出现 TextAlign.Center 就退回发布版之前的居中形态了",
            "TextAlign.Center" in code,
        )
        val lineHeight = Regex("""TitleLineHeight:\s*TextUnit\s*=\s*(\d+(?:\.\d+)?)\.sp""")
            .find(code)
        assertNotNull("套件里找不到 `TitleLineHeight: TextUnit = ….sp`", lineHeight)
        assertEquals(
            "行高必须 = 17sp × 1.2 = 20.4sp（发布版 HyperosTypography.sheetTitle 的 height: 1.2）",
            20.4f,
            lineHeight!!.groupValues[1].toFloat(),
            0.001f,
        )
    }

    // ------------------------------------------------------------------
    // 判据
    // ------------------------------------------------------------------

    /** 单个调用点的违规说明（"第 N 行 …"）；空 = 合规。 */
    private fun violations(source: String): List<String> {
        val code = stripKotlinComments(source)
        val hits = mutableListOf<String>()
        for ((line, args) in sheetCallArguments(source)) {
            val lineNo = code.take(line).count { it == '\n' } + 1
            for ((param, reason) in FORBIDDEN_PARAMS) {
                if (namedArgument(args, param) != null) {
                    hits += "第 $lineNo 行传了 `$param`：$reason"
                }
            }
            val height = namedArgument(args, "maxHeightFraction") ?: continue
            val value = height.trim()
            val literal = LITERAL_FLOAT.matchEntire(value) ?: continue
            val fraction = literal.groupValues[1].toFloat()
            val allowed = ALLOWED_FRACTIONS.any { abs(it - fraction) < 1e-4f }
            if (!allowed) {
                hits += "第 $lineNo 行 `maxHeightFraction = $value` 不在发布版档位里" +
                    "（允许：${ALLOWED_FRACTIONS.joinToString("/")}）"
            }
        }
        return hits
    }

    /**
     * 取出所有 `QingyuSheet(` 调用的**实参文本**（剥注释后按括号配平）。
     *
     * 返回 (起始偏移, 实参文本)。偏移用于回报行号——所以剥注释必须保留换行
     *（否则行号会整体上漂，`ComposeSheetGuardTest` 在这条上踩过）。
     */
    private fun sheetCallArguments(source: String): List<Pair<Int, String>> {
        val code = stripKotlinComments(source)
        val result = mutableListOf<Pair<Int, String>>()
        var from = 0
        while (true) {
            val start = code.indexOf(CALL_NAME, from)
            if (start < 0) break
            // `XxxQingyuSheet(` 这类自定义名字的尾巴不是套件调用 —— 卡词边界。
            if (start > 0 && (code[start - 1].isLetterOrDigit() || code[start - 1] == '_')) {
                from = start + CALL_NAME.length
                continue
            }
            val openParen = start + CALL_NAME.length - 1
            val close = matchingParen(code, openParen)
            if (close < 0) break
            result += start to code.substring(openParen + 1, close)
            from = close
        }
        return result
    }

    /** 取**顶层**命名实参的值文本（到同层逗号为止）；没有则 null。 */
    private fun namedArgument(args: String, name: String): String? {
        val prefix = Regex("""^\s*$name\s*=""")
        var depth = 0
        var segmentStart = 0
        for (i in args.indices) {
            when (args[i]) {
                '(', '{', '[' -> depth++
                ')', '}', ']' -> depth--
                ',' -> if (depth == 0) {
                    segmentValue(args.substring(segmentStart, i), prefix)?.let { return it }
                    segmentStart = i + 1
                }
            }
        }
        return segmentValue(args.substring(segmentStart), prefix)
    }

    /** 一个顶层实参片段如果就是 `name = …`，返回 `=` 之后的值文本。 */
    private fun segmentValue(segment: String, prefix: Regex): String? {
        val match = prefix.find(segment) ?: return null
        return segment.substring(match.range.last + 1).trim()
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

    /**
     * 剥掉 Kotlin 注释（与 `ComposeSheetGuardTest.stripKotlinComments` 同一套状态机，
     * 独立一份避免守卫之间互相耦合）：行注释剥到行尾、块注释按可嵌套配平、
     * 字符串 / 字符字面量原样保留（`"https://…"` 里的 `//` 不当注释）。
     */
    private fun stripKotlinComments(source: String): String {
        val sb = StringBuilder(source.length)
        var i = 0
        var inLineComment = false
        var inBlockComment = false
        var blockDepth = 0
        var stringQuote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                inBlockComment -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        i += 2
                        if (blockDepth == 0) inBlockComment = false
                    } else {
                        if (ch == '\n') sb.append(ch)
                        i++
                    }
                }
                stringQuote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < source.length) {
                        sb.append(source[i + 1])
                        i += 2
                    } else {
                        if (ch == stringQuote) stringQuote = null
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    inLineComment = true
                    sb.append(' ')
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
                    sb.append(' ')
                    i += 2
                }
                ch == '"' || ch == '\'' -> {
                    stringQuote = ch
                    sb.append(ch)
                    i++
                }
                else -> {
                    sb.append(ch)
                    i++
                }
            }
        }
        return sb.toString()
    }

    private fun sheetWith(fraction: String): String = """
        QingyuSheet(
            show = true,
            onDismissRequest = {},
            maxHeightFraction = $fraction,
        ) { }
    """.trimIndent()

    private fun composeFiles(): List<File> =
        composeRoot().walkTopDown()
            .filter { it.isFile && it.name.endsWith(".kt") }
            .toList()

    private fun composeRoot(): File = File(androidSrc(), "composeP1/kotlin")

    private fun suiteSource(): String =
        File(composeRoot(), "com/mutx163/qingyu/$SHEET_SUITE_FILE").readText()

    private fun relativeName(file: File): String {
        val normalized = file.path.replace('\\', '/')
        val index = normalized.indexOf(REL_MARKER)
        return if (index >= 0) normalized.substring(index + REL_MARKER.length) else normalized
    }

    /** 与 `ComposeSheetGuardTest.androidSrc()` 同一口径：向上找 `android/app/src`。 */
    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private companion object {
        const val CALL_NAME = "QingyuSheet("
        const val REL_MARKER = "composeP1/kotlin/com/mutx163/qingyu/"
        const val SHEET_SUITE_FILE = "components/QingyuSheet.kt"
        const val SHOWCASE_PREFIX = "pages/showcase/"

        /** 字面量形态：`0.88` / `0.88f` / `1` / `1f`。 */
        val LITERAL_FLOAT = Regex("""(\d+(?:\.\d+)?)[fF]?""")

        /**
         * 发布版出现过的限高档位（`git grep -n "maxHeight" v2.1.4.1 -- lib/screens`）。
         *
         * 与 `QingyuSheetDefaults.AllowedMaxHeightFractions` 必须一致——由
         * `守卫的档位表必须与套件一致` 从套件源码反解比对（故意不 import，见那条测试的说明）。
         */
        val ALLOWED_FRACTIONS: List<Float> = listOf(
            0.5f, 0.52f, 0.55f, 0.56f, 0.6f, 0.62f, 0.64f, 0.65f, 0.68f, 0.72f,
            0.75f, 0.8f, 0.82f, 0.84f, 0.85f, 0.86f, 0.88f,
        )

        /**
         * 宿主不许自传的刻度。
         *
         * ⚠️ 2026-11-10 评审 三-05：原本还钉了 `startAction` / `endAction`，但这两个参数
         * 已从 `QingyuSheet` 签名里删除 —— **传了就编译不过**，文本判据永远不会触发，
         * 是死判据，已清理。要防「有人把它加回来」，靠的是套件源码断言（K4 那条
         * `startAction = titleAction`），不是这里。
         */
        val FORBIDDEN_PARAMS: Map<String, String> = mapOf(
            "insideMargin" to "左右内边距由套件统一给 16dp（S1）",
            "cornerRadius" to "圆角由套件统一钉 28dp（S4）",
            "backgroundColor" to "底色跟主题走（S4 同批口径），不要单点覆盖",
        )
    }
}
