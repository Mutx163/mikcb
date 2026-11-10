package com.mutx163.qingyu.pages

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Compose 页面样式守卫（2026-10-28 建立；2026-11-03 收口为「4 个扫描器 + 例外清单」）。
 *
 * ## 它钉住的是什么
 *
 * 用户 2026-10-28 反馈：对比官方 miuix demo，「大部分页面还有什么毛病」。
 * 普查 60 个页面后定位到的**根因不是缺组件**，而是——共享套件（`QingyuPageScaffold` /
 * `QingyuPageList` / `QingyuCard` / `QingyuSectionTitle`）早就写好了，页面却还在直接调
 * miuix 裸组件。实测分布：42 页裸 `LazyColumn`、27 页裸 `Card(`、34 页写死 `fontSize`、
 * 23 页写死 `Color(0x…`、47 页自己拼分组标题。
 *
 * 这些**都不是编译错误**：编译过、测试绿、只有真机盯屏才看得出来。所以靠「写进文档请大家自觉」
 * 一定漏——本项目已经漏了一整轮。这里用**源码文本守卫**把七条规则钉死。
 *
 * ## 七条规则（详见 `docs/reference/compose-page-style-rules.md`）
 *
 * | 规则 | 要求 | 违规症状 |
 * |---|---|---|
 * | R1 | 页面骨架走 `QingyuPageScaffold` | 自己组合 `TopAppBar`，返回键/大标题各写各的 |
 * | R2 | 滚动容器走 `QingyuPageList` | 裸 `LazyColumn` 缺三件套与滚动条；`verticalScroll` 非惰性 |
 * | R3 | 卡片走 `QingyuCard` | 裸 `Card(` 无按压反馈、圆角被默认压小 |
 * | R4 | 字号走 `MiuixTheme.textStyles` | 写死 `fontSize = n.sp`，用户字重/字阶失效 |
 * | R5 | 颜色走主题语义槽 | 写死 `Color(0x…)`，深色模式必错 |
 * | R6 | 分组标题走 `QingyuSectionTitle` | 自己拼 13sp + padding，对不齐 28dp 轴线 |
 * | R7 | 字重走 `…textStyles.*.shiftWeight()` | 写死 `fontWeight = FontWeight.X`，盖掉用户字重/系统粗体的平移 |
 *
 * ## 2026-11-03 改版：债清到 0 之后，基线换成例外清单
 *
 * 旧模型是「7 条规则各写一段判据 + 每域一份棘轮基线」。债清到 0 以后，21 份基线里
 * 19 份只剩注释头，2 份合计 10 行且全是**永久例外**（与用户课程色绑定、不跟主题的固定色等）。
 * 继续保留这套机制有三个实际成本：
 *
 * 1. 修一处要同时改代码和基线两个文件；
 * 2. `scripts/compose-style-lint.ps1 -Write` 能把新违规直接洗进基线（守卫只比键，不看基线是否变长）；
 * 3. 空跑自检要求「基线至少 5 行」，与「把债清到 0」的目标直接打架。
 *
 * 现在：
 *
 * - 判据收敛成 **4 个扫描器**（结构 / 内容块 / 字体 / 颜色），规则编号 R1..R7 不变；
 * - **待修违规必须是 [EXPECTED_PENDING_VIOLATIONS] = 0**（写在常量里，不是「当前值」）；
 * - 真正需要保留的写法人工登记在 `tool/compose_style_exceptions/<域>.txt`，每条必须写明原因；
 * - 每条例外都必须命中一处真实违规（**过期即红**），修好就删那行；
 * - 脚本 `-Write` **只能删过期行、绝不能新增**——后门从命令层面关掉。
 *
 * ## 判定范围与「只看代码」
 *
 * 只扫 `composeP1/.../pages/` 下的 `.kt`。`components/` 是套件自身（它就该调裸组件），
 * `pages/shell/`（壳自带导航栏）与 `pages/showcase/`（展厅故意逐个展示官方裸组件）
 * 有域级豁免，见规则文档 §五。
 *
 * 判据前先做一遍 Kotlin 词法剥离：`//`、可嵌套的 `/* */`、字符串/字符字面量、`"""` 原始字符串
 * 都替换成空白（换行保留，行号不漂）。注释里讲的旧写法、字符串里的示例代码都不参与判定——
 * 这是旧版「行首判断 + `substringBefore("//")`」漏掉的假红/假绿来源。
 *
 * ## 它是源码文本守卫，不是行为测试
 *
 * 与 `PageScaffoldGuardTest`、`SettingsRowComponentGuardTest` 同一套路：真机观感要用户配合、
 * CI 里跑不了，但「有没有绕开共享套件」是文本可判的。文本守卫的代价是**容易被绕过**
 * （改个换行、换个写法），所以判据只钉「必须出现/不得出现的最小集合」，不当格式警察。
 *
 * 读文件所以纪律上要做两件事：路径从工作目录向上找（CI 与 IDE 都能跑）；
 * 找不到文件时**失败而不是跳过**——跳过等于守卫不存在。
 */
class ComposePageStyleGuardTest {

    // ───────────────────────── 路径 ─────────────────────────

    /** 从当前工作目录向上找 `android/app/src`，兼容 Gradle（在 android/ 跑）与 IDE。 */
    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
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

    /**
     * 仓库根：从 `android/app/src` 往上找到同时有 `i18n/app_zh.arb` 与 `android/app/build.gradle` 的那层。
     * 例外清单与规则文档都挂在仓库根下，找不到就失败，不静默跳过。
     * （Dart 层已由 P4-C `303220db1` 删除，锚点不再用 `lib/screens` / `pubspec.yaml`。）
     */
    private fun repoRoot(): File {
        var dir: File? = androidSrc().absoluteFile
        while (dir != null) {
            // 锚点改 Kotlin 侧：Dart 已删（P4-C），不能再要求 lib/screens 或 pubspec 存在。
            if (File(dir, "i18n/app_zh.arb").isFile && File(dir, "android/app/build.gradle").isFile) return dir
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（i18n/app_zh.arb 与 android/app/build.gradle）—— 守卫无法验证，按失败处理。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private val pagesRoot: File
        get() = File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/pages")

    private val exceptionsRoot: File
        get() = File(repoRoot(), "tool/compose_style_exceptions")

    private fun allPageFiles(): List<File> {
        val root = pagesRoot
        if (!root.isDirectory) {
            throw AssertionError("找不到页面源码目录：${root.path} —— 守卫无法验证，按失败处理。")
        }
        val files = root.walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .toList()
            .sortedBy { it.path }
        if (files.isEmpty()) {
            throw AssertionError("${root.path} 下一个 .kt 都没有，守卫会变成空跑，按失败处理。")
        }
        return files
    }

    private fun relOf(file: File): String =
        file.relativeTo(pagesRoot).path.replace(File.separatorChar, '/')

    // ───────────────────────── 判据 ─────────────────────────

    private data class CodeLine(val number: Int, val text: String)

    /** 一个页面文件剥完注释/字符串后的代码视图。 */
    private class SourceFile(val rel: String, val lines: List<CodeLine>) {
        val domain: String get() = rel.substringBefore('/')
        val code: String = lines.joinToString("\n") { it.text }

        fun first(re: Regex): Int =
            lines.firstOrNull { re.containsMatchIn(it.text) }?.number ?: 0

        fun count(re: Regex): Int =
            lines.count { re.containsMatchIn(it.text) }
    }

    /** 一处违规：`文件|规则` 是例外清单的比对键，说明文字只给人看。 */
    private data class Violation(val rel: String, val rule: String, val detail: String) {
        val key: String get() = "$rel|$rule"
    }

    /** 一条人工登记的例外。 */
    private data class ExceptionEntry(
        val key: String,
        val reason: String,
        /** 出处 `文件名:行号`，报错时直接指过去。 */
        val source: String,
    )

    /**
     * 一个扫描器 = 一组同源判据 + 一组哨兵样本。
     *
     * 2026-11-03 收敛：原来 7 条规则各一段 if，判据和报错散在一个大函数里。
     * 现在按「页面结构 / 内容块 / 字体 / 颜色」归成 4 个扫描器；规则编号仍逐个保留，
     * 报错能对号入座。每个扫描器自带 canary，空跑自检不依赖基线有没有内容。
     */
    private class Scanner(
        val id: String,
        val rules: List<String>,
        /** `样本代码 to 应该命中的规则`。 */
        val canaries: List<Pair<String, String>>,
        val scan: (SourceFile, Set<String>) -> List<Violation>,
    )

    /** 域级豁免：这些目录本来就该用裸组件（见规则文档 §五）。 */
    private val domainExempt: Map<String, Set<String>> = mapOf(
        "shell" to setOf("R1"), // 壳自带导航栏，不是子页
        "showcase" to setOf("R1", "R3", "R7"), // 展厅故意逐个展示官方裸组件与字重
    )

    // 注意：Kotlin 的尾随 lambda 可以写成 `Card {` 而**没有括号**，所以判据一律用
    // `\s*[({]` 同时接受两种写法。只写 `\(` 会留下一条绕过通道
    // （2026-10-28 咬合探针实测：`Card {` / `LazyColumn {` 写法当时被判据完全漏掉）。
    // R1 判据曾写成 `Small?TopAppBar`（= "Smal" + 可选 l），只匹配到 SmallTopAppBar、
    // 漏掉最常见的裸 TopAppBar —— 2026-10-28 自查抓到。现改为判「手搓顶栏行」：
    // 文件里有 `IconButton(onClick = onBack)` 却没有官方 TopAppBar / QingyuPageScaffold。
    private val reHasTopBar = Regex("""(?:Small)?TopAppBar\s*[({]|QingyuPageScaffold\s*[({]""")
    private val reBackButton = Regex("""IconButton\s*\(\s*onClick\s*=\s*onBack""")
    private val reLazyColumn = Regex("""(?<![A-Za-z])LazyColumn\s*[({]""")
    private val rePageList = Regex("""QingyuPageList\s*[({]""")
    private val reHaptic = Regex("""scrollEndHaptic""")
    private val reVerticalScroll = Regex("""verticalScroll\(rememberScrollState\(\)\)""")
    private val reRawCard = Regex("""(?<![A-Za-z])Card\s*[({]""")
    private val reFontSize = Regex("""fontSize\s*=\s*[0-9]+(\.[0-9]+)?\.sp""")
    private val reHardColor = Regex("""Color\(0x""")
    // R6 只判「未限定的调用/定义」：`QingyuTheme.sectionLabel(dark)` 是主题语义取色
    //（与 actionIcon 同值），不是自拼分组标题，裸子串会假红（2026-11-02 实测）。
    // 负向后顾排除标识符与 `.`：`sectionLabel("分组")` / `private fun sectionLabel(` 仍命中，
    // `QingyuTheme.sectionLabel(` / `obj.sectionLabel(` 不命中。
    private val reSectionLabel = Regex("""(?<![A-Za-z0-9_$.])sectionLabel\s*\(""")
    private val reSectionTitle = Regex("""QingyuSectionTitle\s*[({]""")

    // R7：写死绝对字重。只匹配 `fontWeight = FontWeight.X` 字面量；
    // `fontWeight = weight`（实时活动自己的功能设置）不算——那是用户选的绝对值，不是设计强调。
    private val reFontWeight = Regex("""fontWeight\s*=\s*FontWeight\.""")

    private val scanners: List<Scanner> = listOf(
        Scanner(
            id = "结构（顶栏 / 滚动）",
            rules = listOf("R1", "R2"),
            canaries = listOf(
                "IconButton(onClick = onBack) { }" to "R1",
                "LazyColumn { item { } }" to "R2",
                "Column(Modifier.verticalScroll(rememberScrollState())) { }" to "R2",
            ),
        ) { f, exempt ->
            val out = mutableListOf<Violation>()
            if ("R1" !in exempt && reBackButton.containsMatchIn(f.code) && !reHasTopBar.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R1",
                    "手搓顶栏行（返回键），未走官方 TopAppBar / QingyuPageScaffold（第 ${f.first(reBackButton)} 行）",
                )
            }
            if (reLazyColumn.containsMatchIn(f.code) &&
                !rePageList.containsMatchIn(f.code) &&
                !reHaptic.containsMatchIn(f.code)
            ) {
                out += Violation(
                    f.rel, "R2",
                    "裸 LazyColumn，缺滚动三件套与滚动条（第 ${f.first(reLazyColumn)} 行）",
                )
            }
            if (reVerticalScroll.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R2",
                    "用 Column+verticalScroll 当主滚动（非惰性，第 ${f.first(reVerticalScroll)} 行）",
                )
            }
            out
        },
        Scanner(
            id = "内容块（卡片 / 分组标题）",
            rules = listOf("R3", "R6"),
            canaries = listOf(
                "Card { }" to "R3",
                "private fun sectionLabel(text: String) { }" to "R6",
            ),
        ) { f, exempt ->
            val out = mutableListOf<Violation>()
            if ("R3" !in exempt && reRawCard.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R3",
                    "裸 Card，缺按压反馈与语义圆角（第 ${f.first(reRawCard)} 行）",
                )
            }
            if (reSectionLabel.containsMatchIn(f.code) && !reSectionTitle.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R6",
                    "自己拼分组标题，未走 QingyuSectionTitle（第 ${f.first(reSectionLabel)} 行）",
                )
            }
            out
        },
        Scanner(
            id = "字体（字号 / 字重）",
            rules = listOf("R4", "R7"),
            canaries = listOf(
                "Text(text = \"t\", fontSize = 15.sp)" to "R4",
                "fontWeight = FontWeight.SemiBold" to "R7",
            ),
        ) { f, exempt ->
            val out = mutableListOf<Violation>()
            if (reFontSize.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R4",
                    "写死字号 ${f.count(reFontSize)} 处，首处第 ${f.first(reFontSize)} 行（应用 MiuixTheme.textStyles）",
                )
            }
            if ("R7" !in exempt && reFontWeight.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R7",
                    "写死字重 ${f.count(reFontWeight)} 处，首处第 ${f.first(reFontWeight)} 行" +
                        "（应用 MiuixTheme.textStyles.*.shiftWeight）",
                )
            }
            out
        },
        Scanner(
            id = "颜色",
            rules = listOf("R5"),
            canaries = listOf("color = Color(0xFF999999)" to "R5"),
        ) { f, _ ->
            val out = mutableListOf<Violation>()
            if (reHardColor.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R5",
                    "写死颜色 ${f.count(reHardColor)} 处，首处第 ${f.first(reHardColor)} 行（应用主题语义槽）",
                )
            }
            out
        },
    )

    /**
     * 剥掉 Kotlin 注释与字符串内容，只留**代码形状**（换行保留，行号不漂）。
     *
     * 旧版按「行首是不是 `//` / `*`」判断，漏掉了两种真实形状：
     * 块注释里不以 `*` 开头的行、以及字符串里出现的代码片段；反过来
     * `substringBefore("//")` 又会把 URL 后面的真代码一起吃掉。这里按字符状态机做：
     *
     * - `//` 行注释：剥到行尾；
     * - `/* */` 块注释：按 Kotlin 语义**可嵌套**，逐层配平；
     * - `"…"` / `'…'`：内容替换成空格，转义不终结字面量；
     * - `"""…"""` 原始字符串：内容替换成空格，跨行保留换行。
     */
    private fun stripCommentsAndStrings(source: String): String {
        val out = StringBuilder(source.length)
        var i = 0
        var lineComment = false
        var blockDepth = 0
        var quote: Char? = null
        var raw = false
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else '\u0000'
            val third = if (i + 2 < source.length) source[i + 2] else '\u0000'
            when {
                lineComment -> {
                    if (ch == '\n') {
                        lineComment = false
                        out.append(ch)
                    }
                    i++
                }
                blockDepth > 0 -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        out.append("  ")
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        out.append("  ")
                        i += 2
                    } else {
                        if (ch == '\n') out.append('\n')
                        i++
                    }
                }
                raw -> {
                    if (ch == '"' && next == '"' && third == '"') {
                        raw = false
                        out.append("\"\"\"")
                        i += 3
                    } else {
                        if (ch == '\n') out.append('\n')
                        i++
                    }
                }
                quote != null -> {
                    if (ch == '\\') {
                        out.append("  ")
                        i += 2
                    } else if (ch == quote) {
                        out.append(ch)
                        quote = null
                        i++
                    } else {
                        if (ch == '\n') out.append('\n')
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    lineComment = true
                    out.append(' ')
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    blockDepth = 1
                    out.append(' ')
                    i += 2
                }
                ch == '"' && next == '"' && third == '"' -> {
                    raw = true
                    out.append("\"\"\"")
                    i += 3
                }
                ch == '"' || ch == '\'' -> {
                    quote = ch
                    out.append(ch)
                    i++
                }
                else -> {
                    out.append(ch)
                    i++
                }
            }
        }
        return out.toString()
    }

    private fun codeLinesOf(source: String): List<CodeLine> =
        stripCommentsAndStrings(source)
            .split('\n')
            .mapIndexed { index, line -> CodeLine(index + 1, line.removeSuffix("\r")) }
            .filterNot { it.text.trimStart().startsWith("import ") }

    private fun sourceOf(file: File): SourceFile =
        SourceFile(relOf(file), codeLinesOf(file.readText()))

    /** 全树违规，按 `文件|规则` 排序。 */
    private fun allViolations(): List<Violation> =
        allPageFiles().flatMap { file ->
            val source = sourceOf(file)
            val exempt = domainExempt[source.domain] ?: emptySet()
            scanners.flatMap { it.scan(source, exempt) }
        }.sortedBy { it.key }

    // ───────────────────────── 例外清单 ─────────────────────────

    private fun exceptionFiles(): List<File> {
        val root = exceptionsRoot
        if (!root.exists()) return emptyList()
        if (!root.isDirectory) {
            throw AssertionError("例外清单路径不是目录：${root.path}")
        }
        return root.listFiles { f -> f.isFile && f.name.endsWith(".txt") }
            ?.sortedBy { it.name }
            ?: emptyList()
    }

    /**
     * 读全部例外。行格式 `<相对路径>|<规则>|<原因>`；`#` 开头与空行跳过。
     *
     * 原因里允许再出现 `|`（取第一段路径、第二段规则，其余整段算原因）。
     * 同一 `文件|规则` 只允许登记一次——重复说明有人没删旧行。
     */
    private fun exceptionEntries(): Map<String, ExceptionEntry> {
        val result = linkedMapOf<String, ExceptionEntry>()
        exceptionFiles().forEach { file ->
            file.readLines().forEachIndexed { index, raw ->
                val line = raw.trim()
                if (line.isEmpty() || line.startsWith("#")) return@forEachIndexed
                val parts = line.split('|')
                if (parts.size < 3) {
                    throw AssertionError(
                        "例外行格式不对（应为 <相对路径>|<规则>|<原因>）：${file.name}:${index + 1} → $line",
                    )
                }
                val rel = parts[0].trim()
                val rule = parts[1].trim()
                val reason = parts.drop(2).joinToString("|").trim()
                if (rel.isEmpty() || rule.isEmpty() || reason.isEmpty()) {
                    throw AssertionError(
                        "例外行的路径/规则/原因都不能为空：${file.name}:${index + 1} → $line",
                    )
                }
                val key = "$rel|$rule"
                if (result.containsKey(key)) {
                    throw AssertionError(
                        "例外键重复：$key（${file.name}:${index + 1}）——同一处只登记一次，说明要合并进同一行",
                    )
                }
                result[key] = ExceptionEntry(key, reason, "${file.name}:${index + 1}")
            }
        }
        return result
    }

    // ───────────────────────── 0. 守卫自己不能空跑 ─────────────────────────

    @Test
    fun `守卫确实扫到了页面而且扫描器都有样本`() {
        // 反向自检：全树扫描或例外读取一旦失效（路径找错、源码集改名、目录被清），
        // 下面每一条都会「零违规」地静静变绿——那比没有守卫更糟。
        val pages = allPageFiles()
        assertTrue(
            "只扫到 ${pages.size} 个页面文件，明显不对——路径或源码集可能变了，守卫在空跑。",
            pages.size >= 30,
        )
        assertTrue(
            "扫描器数量应收敛在 3..5 个，实际 ${scanners.size} 个。",
            scanners.size in 3..5,
        )
        scanners.forEach { scanner ->
            assertTrue(
                "扫描器「${scanner.id}」没有任何哨兵样本，判据失效了也看不出来。",
                scanner.canaries.isNotEmpty(),
            )
            scanner.canaries.forEach { (sample, rule) ->
                val probe = SourceFile("__probe__/Probe.kt", codeLinesOf(sample))
                val hit = scanner.scan(probe, emptySet()).any { it.rule == rule }
                assertTrue(
                    "扫描器「${scanner.id}」漏掉了自己的样本（应命中 $rule）：$sample",
                    hit,
                )
            }
        }
    }

    @Test
    fun `判据只看代码：注释和字符串里的假调用不算`() {
        // 假红盲区：讲历史的注释、KDoc 示例、字符串里的示例代码都会被旧版的
        // 「行首判断 + substringBefore("//")」当成真调用。这里一次钉住四种形状。
        val sample = listOf(
            "// Card { }",
            "/*",
            "LazyColumn { }",
            "*/",
            "val url = \"https://example.com/Card(\"",
            "\"\"\"",
            "fontSize = 15.sp",
            "\"\"\"",
            "QingyuCard { }",
        ).joinToString("\n")
        val probe = SourceFile("__probe__/Probe.kt", codeLinesOf(sample))
        val hits = scanners.flatMap { it.scan(probe, emptySet()) }
        assertTrue(
            "注释与字符串里的假违规不应命中，实际命中：\n" +
                hits.joinToString("\n") { "  ${it.rule} ${it.detail}" },
            hits.isEmpty(),
        )
    }

    // ───────────────────────── 1. 待修违规必须是 0 ─────────────────────────

    @Test
    fun `待修样式违规必须为 0`() {
        // 这是守卫的核心：新页面/新代码绕开共享套件就会被拦下。
        // 存量债已经清完；真正需要保留的写法走例外清单，不算「待修」。
        val exceptions = exceptionEntries()
        val pending = allViolations().filter { it.key !in exceptions }
        assertEquals(
            "待修样式违规必须为 $EXPECTED_PENDING_VIOLATIONS 处，实际 ${pending.size} 处。\n" +
                "改代码走共享页面套件；确有正当理由要保留的，必须人工编辑 " +
                "tool/compose_style_exceptions/<域>.txt 并写明原因（脚本 -Write 不会帮你加）。\n" +
                pending.joinToString("\n") { "  ${it.rel}  ${it.rule}  ${it.detail}" } +
                "\n\n规则见 docs/reference/compose-page-style-rules.md：\n" +
                "  R1 页面骨架 → QingyuPageScaffold\n" +
                "  R2 滚动容器 → QingyuPageList（内含滚动三件套与滚动条）\n" +
                "  R3 卡片 → QingyuCard（内含按压反馈与语义圆角）\n" +
                "  R4 字号 → MiuixTheme.textStyles\n" +
                "  R5 颜色 → MiuixTheme.colorScheme / Color(QingyuTheme.*)\n" +
                "  R6 分组标题 → QingyuSectionTitle\n" +
                "  R7 字重 → MiuixTheme.textStyles.*.shiftWeight(QingyuWeightDelta.*)",
            EXPECTED_PENDING_VIOLATIONS,
            pending.size,
        )
    }

    // ───────────────────────── 2. 例外不许过期 ─────────────────────────

    @Test
    fun `例外清单里已经修好的行必须删掉`() {
        // 棘轮的另一半。没有这条，例外清单会退化成「永久豁免清单」——
        // 修好不删，下次扫描就不知道这行还有没有用，也让后来者以为它还在用。
        val current = allViolations().map { it.key }.toSet()
        val stale = exceptionEntries().values.filter { it.key !in current }.sortedBy { it.key }
        assertTrue(
            "以下例外对应的违规已经不存在了（说明修好了），请从例外清单里删掉：\n" +
                stale.joinToString("\n") { "  ${it.source}  ${it.key}  ${it.reason}" } +
                "\n\n删法：pwsh -File scripts/compose-style-lint.ps1 -Domain <域> -Write（只删过期行，不会新增）",
            stale.isEmpty(),
        )
    }

    // ───────────────────────── 3. 清单本身不许被绕过 ─────────────────────────

    @Test
    fun `例外清单必须落在仓库的例外目录里`() {
        // 防「把清单改到别处、或者塞个同名文件让守卫读空」这类绕过。
        val rel = exceptionsRoot.relativeTo(repoRoot()).path.replace(File.separatorChar, '/')
        assertEquals(
            "例外清单必须在仓库根的 tool/compose_style_exceptions 下，实际是：$rel",
            "tool/compose_style_exceptions",
            rel,
        )
        if (exceptionsRoot.isDirectory) {
            val nested = exceptionsRoot.walkTopDown()
                .filter { it.isDirectory && it != exceptionsRoot }
                .toList()
            assertTrue(
                "例外目录下不允许再建子目录（防止把清单藏到别处）：\n" +
                    nested.joinToString("\n") { "  ${it.path}" },
                nested.isEmpty(),
            )
        }
    }

    private companion object {
        /**
         * 规则常量：**待修违规必须为 0**。
         *
         * 这不是「当前值」而是判据本体。需要保留的写法走
         * `tool/compose_style_exceptions/<域>.txt`，登记为例外，不计入这个数。
         * 把这个常量改成非 0，等于公开允许 N 处违规——守卫就失去意义了。
         */
        const val EXPECTED_PENDING_VIOLATIONS = 0
    }
}
