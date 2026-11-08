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
        file.readLines().sumOf { line -> cjkLiteralsIn(line).size }

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
        file.readLines().mapIndexedNotNull { index, line ->
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
