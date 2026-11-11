package com.mutx163.qingyu.i18n

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * i18n 棘轮门禁（P3-2）：Kotlin 源码里不允许新增硬编码中文字面量。
 *
 * 背景：`*ParityTest` 只比对 `ArbText` 句柄集合，管不到"屏上直接写中文、根本没进 ArbText"的漏项，
 * Phase 3 的 `LiveSettingsPage` 10 条硬编码就是这么漏到收口的。本门禁补的是这一层。
 *
 * ## 扫描范围（每个源集一份基线）
 *
 * - `composeP1`：Compose 渲染层 → `cjk-literal-baseline.txt`
 * - `main`：Android 壳与页面模型 → `cjk-literal-baseline-main.txt`
 *
 * 分两份而不是合并：两个源集的相对路径可能重名，分开存不用给键加前缀；
 * 也能各自 `--source-set <名字> --write` 独立重生成，并行改不同源集的人不会互相改到对方基线。
 *
 * ## 排除规则（与 `scripts/i18n-cjk-baseline.py` 逐字一致）
 *
 * - **i18n 文案表整文件跳过**：文件名含 `Strings` / `Arb`，或以
 *   `ServiceMessages.kt` / `LogMessages.kt` / `Localizer.kt` 结尾。它们的键值对本来就该是中文，
 *   且由 `*ParityTest` 与 ARB 逐字对拍。
 * - **生成代码跳过**：路径含 `build/` / `generated/` 目录，或文件名以 `Generated.kt` 结尾。
 *   （测试代码不在两个扫描根下，天然不在范围内。）
 * - **`Log.*(...)` 行整行跳过**：与 composeP1 一致。日志是给开发者看的，永远不上屏。
 *
 * 为什么按**文件名**而不是按内容排除：按构造函数名（`ArbText(`）排除会误伤 Compose 的
 * `Text("中文")`，按内容判断又没法在 Python / Kotlin 两侧写成逐字一致的判据。
 * 代价是夹在普通模型文件里的文案表（如 `ChangelogModel.kt` 末尾的 `ChangelogStrings`）
 * 仍被计入基线——这是**保守面**，不是漏判；等它们拆成独立 `*Strings.kt` 再自然退出基线。
 *
 * ## 判定方式
 *
 * 按文件统计中文字面量条数，与对应基线比对。
 * - 新增文件或计数上调 → 失败（说明新代码绕过了 i18n）。
 * - 修复后计数下调 → 同样失败，提示下调基线（棘轮只许收不许放，避免"顺手加回去"）。
 *
 * ## `@Preview` 参数与预览函数体不算「屏上文案」（2026-11-11 与 EmptyState 守卫统一口径）
 *
 * `@Preview` 的参数（`name = "1 有数据"`、假课程名）和预览函数体里的构造数据**永远不上屏**：
 * 只出现在 Android Studio 的预览面板里，用户看不到，也与六语文案无关。
 * `EmptyStateUnificationGuardTest` 从 2026-11-10 起就这么判（它的 `blankPreviewSpans`：
 * 只抹 `@Preview(...)` 的参数与被注解函数体，**抹完不外溢**）。本棘轮当时没跟上，于是同一份源码
 * 在两套守卫下判出两种结论——预览名被算成 i18n 债务，逼人把预览名改成英文（`33a5c6e15`）。
 *
 * 现在两侧对齐：**豁免只放开预览块，不放开水位**。预览之外任何中文字面量照旧计数，
 * 因此「预览之外零新增」的判定力与原规则完全一致（自检 `previewSpansAreNotCountedAsScreenCopy`）。
 *
 * 实现：先把整个文件抹一遍空白再按行数（换行保留、字符偏移不变），抹的范围严格是两段——
 * 1. `@Preview` 之后紧跟的 `(...)` 参数列表；
 * 2. 该注解之后**第一个** `fun` 的函数体（花括号配对）。
 * 配对失败（未闭合）时**宁可不豁免**：多抹会盖住真违规，少抹只会多报，多报是安全方向。
 *
 * 只认**行首**（允许前导空白）的 `@Preview`：KDoc 的 ` * @Preview`、`// @Preview`、
 * 字符串里的 `"@Preview"` 都不算。比 `EmptyStateUnificationGuardTest` 的全文 `indexOf` 更窄，
 * 因为那套写法遇到注释里的 `@Preview` 会一路抹到下一个 `fun`，把真代码一起盖掉。
 * 与 `scripts/i18n-cjk-baseline.py` 的 `PREVIEW_ANNOTATION` / `blankPreviewSpans` /
 * `matching_delimiter` **逐字一致**。
 */
class CjkLiteralGateTest {

    private val literalRegex = Regex("\"((?:[^\"\\\\]|\\\\.)*)\"")

    /**
     * 「这一行是日志调用」的判据：`android.util.Log` 的六个级别方法。
     *
     * 与 `scripts/i18n-cjk-baseline.py` 的 `LOG_CALL` **逐字一致**（两侧不同步基线会漂移）。
     * 只认 `Log.x(` 形态，不误伤 `SampleLog`、`dialog.`、字符串里的 `"Log.w("`——
     * 后面这条靠 `\bLog\.` 的词边界挡住。
     */
    private val LOG_CALL = Regex("\\bLog\\.[vdiwe]\\s*\\(")

    /**
     * 「行首的 `@Preview`」判据：`(?m)` 让 `^` 匹配每行行首，只允许前导空白。
     *
     * 与 `scripts/i18n-cjk-baseline.py` 的 `PREVIEW_ANNOTATION` **逐字一致**。
     * 注释里的 ` * @Preview` / `// @Preview` 因为行首不是 `@` 而不命中——
     * 这条收窄是安全方向（见类注释「为什么只认行首」）。
     */
    private val PREVIEW_ANNOTATION = Regex("(?m)^[ \t]*(@Preview\\b)")

    // 与 scripts/i18n-cjk-baseline.py 的 COPY_TABLE_* / GENERATED_* 逐字一致。
    private val COPY_TABLE_NAME_MARKERS = listOf("Strings", "Arb")
    private val COPY_TABLE_SUFFIXES = listOf("ServiceMessages.kt", "LogMessages.kt", "Localizer.kt")
    private val GENERATED_DIRS = listOf("build", "generated")
    private val GENERATED_SUFFIX = "Generated.kt"

    private data class SourceSet(
        val name: String,
        val relativeRoot: String,
        val relativeBaseline: String,
        val minScannedFiles: Int,
        val minCjkFiles: Int,
    )

    private val sourceSets = listOf(
        SourceSet(
            name = "composeP1",
            relativeRoot = "android/app/src/composeP1/kotlin",
            relativeBaseline =
                "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt",
            minScannedFiles = 40,
            minCjkFiles = 10,
        ),
        SourceSet(
            name = "main",
            relativeRoot = "android/app/src/main/kotlin",
            relativeBaseline =
                "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline-main.txt",
            minScannedFiles = 380,
            minCjkFiles = 50,
        ),
    )

    @Test
    fun `扫描器必须真的扫到两个源集的源文件`() {
        for (ss in sourceSets) {
            val files = scanFiles(ss)
            assertTrue(
                "${ss.name} 扫描到 ${files.size} 个源文件，低于下限 ${ss.minScannedFiles}；" +
                    "扫描根疑似失效（门禁空跑会假绿）",
                files.size >= ss.minScannedFiles,
            )
            val withCjk = files.count { countCjkLiterals(it) > 0 }
            assertTrue(
                "${ss.name} 只有 $withCjk 个文件命中中文字面量，低于下限 ${ss.minCjkFiles}；" +
                    "判据疑似失效",
                withCjk >= ss.minCjkFiles,
            )
        }
    }

    /** 判据自检：排除规则必须真的把 i18n 文案表挡在扫描之外，不能变成空转。 */
    @Test
    fun `排除规则真的排除了 i18n 文案表`() {
        // 规则本身：既有的每种文案表命名都要命中，普通页面 / 模型文件不能命中。
        listOf(
            "SettingsStrings.kt",
            "SettingsStringsExt2.kt",
            "CommonUiStrings.kt",
            "SomeArb.kt",
            "ImportServiceMessages.kt",
            "DiagnosticLogMessages.kt",
            "HolidayLogLocalizer.kt",
        ).forEach { assertTrue("`$it` 应被判为 i18n 文案表", isCopyTable(it)) }

        listOf(
            "ShellPageIndexScreen.kt",
            "MemoryStatsModel.kt",
            "DataTransferPackageLogic.kt",
        ).forEach { assertFalse("`$it` 不应被判为 i18n 文案表", isCopyTable(it)) }

        // 真实文件：main 源集里这几份含中文的文案表必须不在扫描结果中。
        val main = sourceSets.first { it.name == "main" }
        val scanned = scanFiles(main).map { relativeName(main, it) }.toSet()
        val samples = listOf(
            "com/mutx163/qingyu/pages/settings/SettingsStrings.kt",
            "com/mutx163/qingyu/pages/guide/GuideStrings.kt",
            "com/mutx163/qingyu/pages/import/warehouse/WarehouseStrings.kt",
            "com/mutx163/qingyu/DiagnosticLogMessages.kt",
            "com/mutx163/qingyu/pages/import/ImportServiceMessages.kt",
            "com/mutx163/qingyu/calendar/HolidayLogLocalizer.kt",
        )
        for (rel in samples) {
            val file = File(repoRoot(), main.relativeRoot).resolve(rel)
            assertTrue("自检样本不存在：$rel", file.isFile)
            assertTrue(
                "自检样本不含中文，排除测试会空跑：$rel",
                file.readText().any { it in '一'..'鿿' },
            )
            assertTrue("排除规则失效：$rel 仍在扫描结果里", rel !in scanned)
        }
    }

    @Test
    fun `中文字面量不高于棘轮基线`() {
        val problems = sourceSets.flatMap { checkRatchet(it) }
        assertTrue(
            buildString {
                appendLine("i18n 棘轮门禁失败（${problems.size} 处）：")
                problems.forEach { appendLine("  - $it") }
                appendLine()
                appendLine("新增 / 上调：屏上文案改走 `ArbText(\"<arbKey>\", \"<app_zh.arb 原文>\")`，")
                appendLine("键值以 i18n/app_zh.arb 为准，不得自拟说法。")
                appendLine("已修复但基线未下调：执行 `python scripts/i18n-cjk-baseline.py --write`。")
            },
            problems.isEmpty(),
        )
    }

    /** 判据自检：日志行的中文不算，屏上文案照数。 */
    @Test
    fun logMessagesAreNotCountedAsScreenCopy() {
        assertTrue(
            "Log 里的中文是开发者日志，不该算成 i18n 债务",
            cjkLiteralsIn("""        Log.w(LOG_TAG, "分享图落盘失败")""").isEmpty(),
        )
        assertTrue(
            "Log 出现在 lambda 里（`{ Log.w(...) }`）也要认出来",
            cjkLiteralsIn("""        .onFailure { Log.w(LOG_TAG, "删不掉被淘汰的壁纸") }""").isEmpty(),
        )
        assertTrue(
            "Toast / Text 上的中文仍然必须被数到，日志豁免不能顺带放宽判据",
            cjkLiteralsIn(
                """        Toast.makeText(context, "保存失败", Toast.LENGTH_SHORT)""",
            ).isNotEmpty(),
        )
    }

    /** 判据自检用：按真实口径（先抹 `@Preview` 段，再逐行数）统计一段源码里的中文字面量。 */
    private fun cjkLiteralsInText(text: String): Int =
        previewBlanked(text).lines().sumOf { line -> cjkLiteralsIn(line).size }

    /**
     * 判据自检：`@Preview` 参数与预览函数体里的中文不算，**预览之外照数**。
     *
     * 两条一起才说明「收窄」而不是「放水」：只测第一条的话，把整份文件都豁免掉也能通过。
     * 第二条把同一条中文从预览块挪到普通代码，必须仍然被数到——水位一点没降。
     */
    @Test
    fun previewSpansAreNotCountedAsScreenCopy() {
        val previewOnly = """
            |@Preview(name = "1 有数据")
            |@Composable
            |private fun DemoScreenPreview() {
            |    DemoScreen(
            |        title = "假标题",
            |        tags = listOf("语文", "数学"),
            |    )
            |}
        """.trimMargin()
        assertTrue(
            "预览参数与预览函数体里的中文不该算成 i18n 债务（那是 IDE 预览标签与假数据）",
            cjkLiteralsInText(previewOnly) == 0,
        )

        // 同一条中文从预览块**挪到普通代码**：必须判红。
        val movedOut = """
            |val screenTitle = "1 有数据"
            |
            |@Preview(name = "预览")
            |@Composable
            |private fun DemoScreenPreview() {
            |    DemoScreen(title = screenTitle)
            |}
        """.trimMargin()
        assertTrue(
            "预览之外的中文仍然必须被数到（豁免只放开预览块，不放开水位），" +
                "实际 ${cjkLiteralsInText(movedOut)} 条",
            cjkLiteralsInText(movedOut) == 1,
        )

        // 注释里的 @Preview 不是注解：不能因为它在，就把后面真函数体一起豁免掉。
        val commented = """
            |// @Preview(name = "旧写法")
            |val toolbarTitle = "全部功能"
            |
            |fun demoToolbar() {
            |    val label = "编辑"
            |}
        """.trimMargin()
        assertTrue(
            "注释里的 @Preview 不算注解，后面的真代码必须照旧计数" +
                "（期望 2 条：「全部功能」+「编辑」，实际 ${cjkLiteralsInText(commented)} 条）",
            cjkLiteralsInText(commented) == 2,
        )
    }

    private fun checkRatchet(ss: SourceSet): List<String> {
        val problems = mutableListOf<String>()
        val baseline = loadBaseline(ss)
        if (baseline.isEmpty()) {
            problems += "[${ss.name}] 基线文件为空，无法判定"
            return problems
        }

        val files = scanFiles(ss)
        val byName = files.associateBy { relativeName(ss, it) }
        val actual = linkedMapOf<String, Int>()
        for (file in files) {
            val count = countCjkLiterals(file)
            if (count > 0) actual[relativeName(ss, file)] = count
        }

        for ((name, count) in actual) {
            val allowed = baseline[name]
            if (allowed == null) {
                problems += "[${ss.name}] 新增未登记文件 `$name`：$count 条中文字面量。" +
                    "文案应改走 ArbText，或走 i18n 层"
            } else if (count > allowed) {
                val offenders = cjkLiteralOffenders(byName.getValue(name))
                problems += "[${ss.name}] `$name` 由 $allowed 增至 $count 条。命中行：\n" +
                    offenders.joinToString("\n") { "    $it" }
            }
        }

        baseline.forEach { (name, allowed) ->
            val now = actual[name] ?: 0
            if (now < allowed) {
                problems += "[${ss.name}] `$name` 已修复但基线未下调：基线 $allowed，实际 $now"
            }
        }
        return problems
    }

    // ── 扫描规则（与 scripts/i18n-cjk-baseline.py 保持一致）──

    private fun scanFiles(ss: SourceSet): List<File> {
        val root = File(repoRoot(), ss.relativeRoot)
        check(root.isDirectory) { "找不到 ${ss.name} 源码根：${root.absolutePath}" }
        return root.walkTopDown()
            .filter { it.isFile && it.name.endsWith(".kt") }
            .filterNot { isGenerated(ss, it) || isCopyTable(it.name) }
            .sorted()
            .toList()
    }

    private fun isCopyTable(fileName: String): Boolean =
        COPY_TABLE_NAME_MARKERS.any { it in fileName } ||
            COPY_TABLE_SUFFIXES.any { fileName.endsWith(it) }

    private fun isGenerated(ss: SourceSet, file: File): Boolean {
        if (file.name.endsWith(GENERATED_SUFFIX)) return true
        return relativeName(ss, file)
            .split('/')
            .dropLast(1)
            .any { segment -> GENERATED_DIRS.any { it.equals(segment, ignoreCase = true) } }
    }

    private fun countCjkLiterals(file: File): Int =
        previewBlanked(file.readText()).lines().sumOf { line -> cjkLiteralsIn(line).size }

    /** 文件文本先过一遍 `@Preview` 豁免，再交给按行计数 / 报命中行。 */
    private fun previewBlanked(text: String): String = blankPreviewSpans(text)

    /**
     * `@Preview` 豁免：只把 `@Preview(...)` 的参数、以及被它标注的那个函数体抹成空格（换行保留）。
     *
     * 与 `scripts/i18n-cjk-baseline.py` 的 `blankPreviewSpans` **逐字一致**——两侧算不出同一份
     * 文本，基线就会在脚本与守卫之间漂移。定位方式与 `EmptyStateUnificationGuardTest` 同构，
     * 但只认**行首**的 `@Preview`（见类注释「为什么只认行首」）。
     *
     * 除这两段以外的源码原样返回——豁免**不外溢**：预览之外任何中文字面量照旧被抓。
     */
    private fun blankPreviewSpans(code: String): String {
        val chars = code.toCharArray()
        fun blank(from: Int, toExclusive: Int) {
            for (i in from until toExclusive.coerceAtMost(chars.size)) {
                if (chars[i] != '\n') chars[i] = ' '
            }
        }
        var pos = 0
        while (true) {
            val m = PREVIEW_ANNOTATION.find(code, pos) ?: break
            val at = m.groups[1]!!.range.first
            pos = m.groups[1]!!.range.last + 1
            var cursor = pos
            var j = pos
            while (j < code.length && (code[j] == ' ' || code[j] == '\t')) j++
            if (j < code.length && code[j] == '(') {
                val close = matchingDelimiter(code, j, '(', ')')
                if (close < 0) continue // 配对失败 ⇒ 不豁免，绝不靠猜
                blank(at, close + 1)
                cursor = close + 1
            }
            val funAt = code.indexOf("fun ", cursor)
            if (funAt >= 0) {
                val bodyOpen = code.indexOf('{', funAt)
                if (bodyOpen >= 0) {
                    val bodyClose = matchingDelimiter(code, bodyOpen, '{', '}')
                    if (bodyClose > 0) blank(bodyOpen, bodyClose + 1)
                }
            }
        }
        return String(chars)
    }

    /** 成对标点的配对位置（`(`…`)` / `{`…`}`）；未闭合返回 -1。 */
    private fun matchingDelimiter(code: String, openIndex: Int, openCh: Char, closeCh: Char): Int {
        var depth = 0
        var i = openIndex
        while (i < code.length) {
            when (code[i]) {
                openCh -> depth++
                closeCh -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
    }

    private fun cjkLiteralsIn(line: String): List<String> {
        if (line.trimStart().startsWith("*") ||
            line.trimStart().startsWith("//") ||
            line.trimStart().startsWith("/*")
        ) {
            return emptyList()
        }
        // `Log.*(...)` 的中文是**给开发者看的日志**，永远不上屏，不需要走 i18n。
        // 2026-10-31：本门禁原先连它一起数，导致 `BingGalleryHost.kt`（2 条 `Log.e/Log.w`）
        // 与 `StatisticsShareIntent.kt`（4 条 `Log.w`）被判成「i18n 回退」而长期红着，
        // 逼人去把日志文案塞进 ARB —— 那是把工具用反了。判据改成「日志行整行跳过」。
        if (LOG_CALL.containsMatchIn(line)) {
            return emptyList()
        }
        return literalRegex.findAll(line)
            .map { it.groupValues[1] }
            .filter { text -> text.any { it in '一'..'鿿' } }
            .toList()
    }

    private fun cjkLiteralOffenders(file: File): List<String> =
        previewBlanked(file.readText()).lines().mapIndexedNotNull { index, line ->
            val hits = cjkLiteralsIn(line)
            if (hits.isEmpty()) null else "L${index + 1}: " + hits.joinToString(" | ") { "『$it』" }
        }

    private fun relativeName(ss: SourceSet, file: File): String {
        val root = File(repoRoot(), ss.relativeRoot).absolutePath
        return file.absolutePath.removePrefix(root).trimStart(File.separatorChar).replace('\\', '/')
    }

    private fun loadBaseline(ss: SourceSet): Map<String, Int> {
        val envName =
            if (ss.name == "composeP1") "CJK_LITERAL_BASELINE" else "CJK_LITERAL_BASELINE_MAIN"
        val file = System.getenv(envName)?.let(::File) ?: File(repoRoot(), ss.relativeBaseline)
        check(file.isFile) { "找不到 i18n 基线文件：${file.absolutePath}" }
        val result = LinkedHashMap<String, Int>()
        file.readLines().forEach { raw ->
            val line = raw.trim()
            if (line.isEmpty() || line.startsWith("#")) return@forEach
            val sep = line.lastIndexOf(':')
            require(sep > 0) { "基线行格式非法：$raw" }
            result[line.substring(0, sep)] = line.substring(sep + 1).trim().toInt()
        }
        return result
    }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "i18n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（未定位到 i18n/app_zh.arb）")
    }
}
