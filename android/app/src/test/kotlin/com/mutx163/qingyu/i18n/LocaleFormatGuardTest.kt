package com.mutx163.qingyu.i18n

import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/**
 * **结构性守卫**：`android/app/src` 下所有 `String.format(...)` 调用都必须显式传 `Locale`。
 *
 * ## 为什么这是「数据正确性」而不是代码风格
 *
 * Java 的 `String.format("%02d", …)` **按默认 Locale 本地化数字字形**。实测
 * `ar-EG` / `fa-IR` / `th-TH-u-nu-thai` 下 `%d` 会输出 `٢٠٢٦` / `۲۰۲۶` / `๒๐๒๖` 这类非 ASCII
 * 数字；Dart 的 `padLeft` 恒输出 ASCII。后果不是「界面难看」，而是：
 *
 * 1. 落盘字节与 Dart 不一致（冻结格式区逐字节对拍直接破防）；
 * 2. 跨端哈希把「同一份数据」判成「内容被改过」，云同步/局域网同步会走冲突分支，
 *    极端情况下用本端算出的哈希覆盖另一端已有的正确数据。
 *
 * 因此本守卫**不做逐处修，而是把口径钉成结构约束**：新增代码一旦漏传 `Locale`，
 * 测试立即红；已在 [WHITELIST] 登记的例外必须写明理由（且文件必须仍然存在）。
 *
 * ## 白名单口径
 *
 * 只登记**本批作用域之外**（`pages/`、`transfer/`、`weather/` 三个目录）或**不参与落盘/哈希**
 * 的调用；`core/`、`app/`、`infra/`、`share/`、`widgetdata/` 一律不许登记。
 *
 * 探针：把 `calendar/ScheduleDateRuleLogic.formatIsoDate` 的 `Locale.ROOT` 去掉 → 本测试红。
 *
 * ## 剥离边界（写这条用例之前必读，2026-11-12 三次踩坑的结论）
 *
 * 1. **剥离统一走 `testutil.stripKotlinComments`，不自带一份**：本文件原有一个私有
 *    `maskComments`，它在块注释处「找第一个结束符」就收尾，于是注释里把起止符当例子写出来时，
 *    扫描提前结束、后面的注释正文被当代码（2026-11-12 全量 L2 唯一那条红即此）。
 *    共享实现本来就按**嵌套深度**配对，所以正解是删掉私有实现、改用共享的那份：
 *    一份实现、所有人都受益，也符合元守卫 `GuardSourceStrippingPolicyTest` 的要求。
 * 2. **注释里别写块注释起止符的原文**：要举例就描述它（「块注释起止符」）——KDoc 本身是块注释，
 *    写了裸的起止符会改变词法状态（共享剥离器能收尾，但人读代码时仍会被误导）。
 * 3. **字符串字面量内容保留**（本守卫要读 format 的首参），所以**本文件的用例样本里不能出现
 *    调用原文**——写进去会被自己扫成真调用。要构造样本请用拼接：`"String." + "format("`。
 */
class LocaleFormatGuardTest {

    @Test
    fun `src 下所有 String format 调用都显式传 Locale`() {
        val root = srcRoot()
        val offenders = ktFiles(root)
            .flatMap { file -> localeLessCalls(file) }
            .filterNot { isWhitelisted(it.relPath) }
            .map { "${it.relPath}:${it.line}  ${it.snippet}" }

        if (offenders.isNotEmpty()) {
            fail(
                buildString {
                    appendLine("以下 String.format 调用未显式传 Locale（会随设备 Locale 产出非 ASCII 数字）：")
                    offenders.forEach { appendLine("  - $it") }
                    appendLine("修法：首参传 Locale.ROOT（落盘/哈希）或 Locale.US（与 Dart 浮点文本对齐）。")
                    appendLine("确属作用域外或不参与落盘的，登记进 WHITELIST 并写理由。")
                },
            )
        }
    }

    @Test
    fun `白名单每一条都有理由且目录或文件仍然存在`() {
        assertTrue("白名单不能为空登记", WHITELIST.isNotEmpty())
        WHITELIST.forEach { entry ->
            assertTrue("白名单 [${entry.pathPrefix}] 必须写明理由", entry.reason.isNotBlank())
            val target = File(srcRoot(), entry.pathPrefix)
            assertTrue("白名单 [${entry.pathPrefix}] 指向的路径已不存在，请删掉该条", target.exists())
        }
    }

    /**
     * 回归：注释里出现行注释符、块注释起止符、原始字符串三引号、`String.format(...)` 示例时，
     * 剥离不能被打乱。
     *
     * 2026-11-12 L2 的唯一一条红就是这个形状：KDoc 把块注释起止符与三引号当例子写进说明 ⇒
     * 扁平扫描把内层收尾符当成真正的结束 ⇒ 后面的注释正文被当成代码 ⇒ 注释里的示例被扫成真调用。
     * 本用例把当时的形状钉住：注释里的示例一律不可见，真实代码一个字都不能被抹掉。
     *
     * 注：本段说明刻意不写出那两个符号的原文，因为它们出现在注释里就会改变词法状态。
     */
    @Test
    fun `注释里的注释符号与引号不会打乱剥离`() {
        // 注意：本用例的源码里不能出现「String.」「format(」拼在一起的原文——本守卫**连字符串
        // 字面量内容也保留**（要检查 format 的首参是否传 Locale），写进去会被自己扫成真调用。
        // 这是 canary 找出的第二类误报形态，所以这里用拼接构造样本。
        val call = "String." + "format("
        val ext = "." + "format("
        val sample = listOf(
            "/**",
            " * 例子：`/* */`、`\"\"\"`、`${call}\"%02d\", 1)`、`\"%02x\".${ext}1)`",
            " */",
            "fun real(): String = ${call}\"%d\", 1)",
        ).joinToString("\n")

        val masked = stripKotlinComments(sample)

        assertTrue(
            "注释里的示例不该被扫成真调用：\n$masked",
            !masked.contains(call + "\"%02d\"") && !masked.contains("\"%02x\"" + ext),
        )
        assertTrue(
            "真实代码不能被一起抹掉：\n$masked",
            masked.contains(call + "\"%d\", 1)"),
        )
        assertEquals(
            "剥离必须保留换行（行号不漂）",
            sample.count { it == '\n' },
            masked.count { it == '\n' },
        )
    }

    private fun isWhitelisted(relPath: String): Boolean =
        WHITELIST.any { relPath.startsWith(it.pathPrefix) }

    // -----------------------------------------------------------------------
    // 扫描
    // -----------------------------------------------------------------------

    private data class Offense(val relPath: String, val line: Int, val snippet: String)

    private fun ktFiles(root: File): List<File> =
        root.walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .sortedBy { it.absolutePath }
            .toList()

    private fun localeLessCalls(file: File): List<Offense> {
        val raw = file.readText()
        val text = stripKotlinComments(raw)
        val rel = file.absolutePath.removePrefix(srcRoot().absolutePath + File.separator)
            .replace('\\', '/')
        val out = mutableListOf<Offense>()
        for (regex in CALLS) {
            for (match in regex.findAll(text)) {
                val open = match.range.last
                val close = matchingClose(text, open) ?: continue
                val args = splitTopLevel(text, open + 1, close)
                val first = args.firstOrNull()?.trim() ?: continue
                if (LOCALE.containsMatchIn(first)) continue
                val line = text.substring(0, match.range.first).count { it == '\n' } + 1
                val snippet = text.substring(match.range.first, minOf(close + 1, match.range.first + 90))
                    .replace('\n', ' ')
                    .replace(Regex("\\s+"), " ")
                out += Offense(rel, line, snippet)
            }
        }
        return out
    }

    /** 从引号/三引号起始处跳到字面量之后；文本本身保留（参数里可能含格式串）。 */
    private fun skipLiteral(source: String, start: Int): Int {
        val quote = source[start]
        if (quote == '"' && source.startsWith("\"\"\"", start)) {
            val close = source.indexOf("\"\"\"", start + 3)
            return if (close < 0) source.length else close + 3
        }
        var i = start + 1
        while (i < source.length) {
            when {
                source[i] == '\\' -> i += 2
                source[i] == quote -> return i + 1
                source[i] == '\n' -> return i
                else -> i++
            }
        }
        return source.length
    }

    private fun matchingClose(text: String, open: Int): Int? {
        var depth = 0
        var i = open
        while (i < text.length) {
            when (text[i]) {
                '"', '\'' -> { i = skipLiteral(text, i); continue }
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return null
    }

    /** 按顶层逗号切参（忽略字面量与嵌套括号里的逗号）。 */
    private fun splitTopLevel(text: String, from: Int, to: Int): List<String> {
        val parts = mutableListOf<String>()
        var depth = 0
        var start = from
        var i = from
        while (i < to) {
            when (text[i]) {
                '"', '\'' -> { i = skipLiteral(text, i); continue }
                '(', '[', '{' -> depth++
                ')', ']', '}' -> depth--
                ',' -> if (depth == 0) {
                    parts += text.substring(start, i)
                    start = i + 1
                }
            }
            i++
        }
        parts += text.substring(start, to)
        return parts
    }

    private fun srcRoot(): File = File(repoRoot(), "android/app/src")

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "i18n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（未定位到 i18n/app_zh.arb）")
    }

    private companion object {
        /**
         * 两种会走默认 Locale 的写法：
         * 1. `String.format("%02d", …)` / `java.lang.String.format(…)`；
         * 2. `"…".format(…)` —— Kotlin 的 String 扩展最终也调 `String.format(默认 Locale, …)`，
         *    代码里大量 `"%02d:%02d".format(…)` 属于同一风险，漏扫等于守卫有洞。
         */
        val CALLS = listOf(
            Regex("""\bString\.format\s*\("""),
            Regex("\"\\s*\\.\\s*format\\s*\\("),
        )

        val LOCALE = Regex("""\bLocale\b""")

        /**
         * 作用域外 / 不参与落盘的已知例外。按**路径前缀**登记（目录可整段登记）。
         *
         * 不得把 `core/`、`app/`、`infra/`、`share/`、`widgetdata/` 加进来。
         *
         * 2026-11-03 全仓实扫：共 67 处未传 Locale。`core/app/infra/share/widgetdata` 内 15 处
         * 已逐处修（widgetdata 主源码 12 处快照/时间文本 + 3 处本域测试辅助），
         * 其余 52 处全部落在下列作用域外目录，按前缀登记。
         */
        val WHITELIST: List<WhitelistEntry> = listOf(
            // pages/import 的日期键、时刻键、课表指纹已改 Locale.ROOT（见 ImportLocaleFormatTest），
            // 因此不再整段登记 pages/，按仍有余量的包目录逐条收口。
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/pages/exam/",
                "作用域外（exam 线）。日期/时刻展示文本，待该线收口 Locale.ROOT。",
            ),
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/pages/live/",
                "作用域外（live 线）。倒计时/直播时长展示文本。",
            ),
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/pages/schedule/",
                "作用域外（schedule 线）。日期键与时刻键，需 Locale.ROOT，待该线收口。",
            ),
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/pages/settings/",
                "作用域外（settings 线）。假期编辑的日期键，需 Locale.ROOT，待该线收口。",
            ),
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/pages/sync/",
                "作用域外（sync 线）。备份文件名时间戳，需 Locale.ROOT，待该线收口。",
            ),
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/pages/time_scheme/",
                "作用域外（time_scheme 线）。作息时刻展示文本。",
            ),
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/pages/transfer/",
                "作用域外（transfer 线）。二维码传输倒计时文本。",
            ),
            WhitelistEntry(
                "composeP1/kotlin/com/mutx163/qingyu/pages/",
                "作用域外（composeP1 明令不碰）。日期选择器/数值滑块的展示文本。",
            ),
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/transfer/",
                "作用域外（transfer 目录明令不许动）。ICS 导出/导入的日期与时刻文本，" +
                    "待 transfer 线改成 Locale.US 后再删本条。",
            ),
            WhitelistEntry(
                "test/kotlin/com/mutx163/qingyu/transfer/",
                "作用域外（transfer 目录测试）。期望值复刻被测格式串，随被测代码一起改。",
            ),
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/weather/",
                "作用域外（weather 目录）。人类可读的体积文案，只进日志/诊断，不落盘。",
            ),
            WhitelistEntry(
                "main/kotlin/com/mutx163/qingyu/MemoryStatsCollector.kt",
                "根包诊断工具，只格式化日志里的人类可读字节数，不落盘、不参与哈希，" +
                    "且不在本批作用域（core/app/infra/share/widgetdata）。",
            ),
            // 同 main：pages/import 的测试辅助已改 Locale.ROOT，测试侧按包目录逐条收口。
            WhitelistEntry(
                "test/kotlin/com/mutx163/qingyu/pages/about/",
                "作用域外（about 线测试）。期望值复刻被测格式串，随被测代码一起改。",
            ),
            WhitelistEntry(
                "test/kotlin/com/mutx163/qingyu/pages/diagnostics/",
                "作用域外（diagnostics 线测试）。期望值复刻被测格式串，随被测代码一起改。",
            ),
            WhitelistEntry(
                "test/kotlin/com/mutx163/qingyu/pages/sync/",
                "作用域外（sync 线测试）。期望值复刻被测格式串，随被测代码一起改。",
            ),
            WhitelistEntry(
                "test/kotlin/com/mutx163/qingyu/pages/time_scheme/",
                "作用域外（time_scheme 线测试）。期望值复刻被测格式串，随被测代码一起改。",
            ),
        )
    }

    private data class WhitelistEntry(val pathPrefix: String, val reason: String)
}
