package com.mutx163.qingyu.i18n

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * i18n 棘轮门禁（P3-2）：Compose 渲染层里不允许新增硬编码中文字面量。
 *
 * 背景：`*ParityTest` 只比对 `ArbText` 句柄集合，管不到"屏上直接写中文、根本没进 ArbText"的漏项，
 * Phase 3 的 `LiveSettingsPage` 10 条硬编码就是这么漏到收口的。本门禁补的是渲染层这一层。
 *
 * 判定方式：按文件统计中文字面量条数，与 `cjk-literal-baseline.txt` 比对。
 * - 新增文件或计数上调 → 失败（说明新代码绕过了 i18n）。
 * - 修复后计数下调 → 同样失败，提示下调基线（棘轮只许收不许放，避免"顺手加回去"）。
 *
 * 规则与 `scripts/i18n-cjk-baseline.py` 逐字一致；规则改动必须两侧同步并重生成基线。
 */
class CjkLiteralGateTest {

    private val literalRegex = Regex("\"((?:[^\"\\\\]|\\\\.)*)\"")

    @Test
    fun `扫描器必须真的扫到渲染层源文件`() {
        val files = renderFiles()
        assertTrue(
            "composeP1 渲染层源文件数为 ${files.size}，扫描根疑似失效（门禁空跑会假绿）",
            files.size >= 40,
        )
    }

    @Test
    fun `渲染层中文字面量不高于棘轮基线`() {
        val baseline = loadBaseline()
        assertTrue("基线文件为空，无法判定", baseline.isNotEmpty())

        val actual = linkedMapOf<String, Int>()
        for (file in renderFiles()) {
            val count = countCjkLiterals(file)
            if (count > 0) actual[relativeName(file)] = count
        }

        val regressions = mutableListOf<String>()
        for ((name, count) in actual) {
            val allowed = baseline[name]
            if (allowed == null) {
                regressions += "新增未登记文件 `$name`：$count 条中文字面量。文案应改走 ArbText，或走 i18n 层"
            } else if (count > allowed) {
                val offenders = cjkLiteralOffenders(renderFiles().first { relativeName(it) == name })
                regressions += "`$name` 由 $allowed 增至 $count 条。命中行：\n" +
                    offenders.joinToString("\n") { "    $it" }
            }
        }

        val staleDowns = baseline.filter { (name, allowed) ->
            val now = actual[name] ?: 0
            now < allowed
        }

        assertTrue(
            buildString {
                appendLine("渲染层出现 ${regressions.size} 处 i18n 回退：")
                regressions.forEach { appendLine("  - $it") }
                if (regressions.isNotEmpty()) {
                    appendLine()
                    appendLine("修复方向：屏上文案改走 `ArbText(\"<arbKey>\", \"<app_zh.arb 原文>\")`，")
                    appendLine("键值以 lib/l10n/app_zh.arb 为准，不得自拟说法。")
                }
            },
            regressions.isEmpty(),
        )

        assertTrue(
            buildString {
                appendLine("以下文件已修复但基线未下调（棘轮必须跟进，否则配额被永久占用）：")
                staleDowns.forEach { (name, allowed) ->
                    appendLine("  - `$name`：基线 $allowed，实际 ${actual[name] ?: 0}")
                }
                appendLine()
                appendLine("执行：python scripts/i18n-cjk-baseline.py --write")
            },
            staleDowns.isEmpty(),
        )
    }

    // ── 扫描规则（与 scripts/i18n-cjk-baseline.py 保持一致）──

    private fun renderFiles(): List<File> {
        val root = File(repoRoot(), "android/app/src/composeP1/kotlin")
        check(root.isDirectory) { "找不到渲染层源码根：${root.absolutePath}" }
        return root.walkTopDown().filter { it.isFile && it.name.endsWith(".kt") }.sorted().toList()
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
        return literalRegex.findAll(line)
            .map { it.groupValues[1] }
            .filter { text -> text.any { it in '\u4e00'..'\u9fff' } }
            .toList()
    }

    private fun cjkLiteralOffenders(file: File): List<String> =
        file.readLines().mapIndexedNotNull { index, line ->
            val hits = cjkLiteralsIn(line)
            if (hits.isEmpty()) null else "L${index + 1}: " + hits.joinToString(" | ") { "『$it』" }
        }

    private fun relativeName(file: File): String {
        val root = File(repoRoot(), "android/app/src/composeP1/kotlin").absolutePath
        return file.absolutePath.removePrefix(root).trimStart(File.separatorChar).replace('\\', '/')
    }

    private fun loadBaseline(): Map<String, Int> {
        val file = System.getenv("CJK_LITERAL_BASELINE")?.let(::File)
            ?: File(repoRoot(), "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt")
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
            if (File(dir, "lib/l10n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（未定位到 lib/l10n/app_zh.arb）")
    }
}
