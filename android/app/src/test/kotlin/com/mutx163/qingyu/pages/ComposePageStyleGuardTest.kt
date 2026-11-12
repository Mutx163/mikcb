package com.mutx163.qingyu.pages

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.security.MessageDigest
import java.util.Locale

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
 * ## 2026-11-11 改版：例外从「整文件」收窄到「行级锚」
 *
 * 上一版的例外键是 `文件|规则`：登记一处 = **整文件整条规则**免检。于是洗白通道还在——
 * 在同一个已登记的文件里再写一处同类违规，那条规则整体不判，脚本和守卫都是绿的；
 * 反过来也不成立：例外只因「键还在」就算命中，跟当初登记的那行代码有没有被删、被改毫无关系。
 *
 * 现在每条例外的第三段是**行级锚**，一行一个短哈希：
 *
 * - 锚 = 被判定的那行代码（剥注释与字符串内容、`trim` 之后）的 SHA-256 前 8 位小写十六进制。
 *   **不用行号**：行号随无关改动（上方插一行 import、删一行空行）上下漂移，一漂整片例外假红，
 *   人就会「顺手重跑一遍把锚刷掉」，棘轮随之失效。锚只跟这行代码本身走。
 * - 一条例外可以登记多个锚（同文件同规则多处命中），逗号分隔；
 * - 同文件同规则下出现**未登记的锚** ⇒ 待修（= 新增违规）；
 * - 登记了但当前**不再命中**的锚 ⇒ 过期（那一行改过内容 / 挪到别的文件 / 或已修好）；
 * - 同一行里重复登记同一个锚 ⇒ 直接判错；三段式旧格式 ⇒ 直接判错。
 *
 * 与 `scripts/compose-style-lint.ps1` 的 `Get-LineAnchor` / `ConvertFrom-ExceptionLine`
 * **逐字对偶**：两侧算出的哈希必须一致，改一边就同步改另一边。
 *
 * ## 2026-11-12 改版：锚列从「集合」改成「多重集」，并堵掉零锚命中
 *
 * 上一版把锚当 `Set` 用，于是留了两个洞：
 *
 * 1. **同文本免检**（H1）：`anchorHits` 按 hash 去重，同文件再粘一行**完全相同的**违规，
 *    借旧锚就免检了。实测 `showcase/ColorBlendToken.kt` 82 处命中只有 76 个锚。
 *    现在锚是**多重集**：同一个锚登记 N 次 = 该文件该规则下同文本必须命中 N 处；
 *    命中次数 > 登记次数 ⇒ 盈余部分待修。**行号不掺进哈希**——掺进去就变成「挪一下行号
 *    失去豁免」，人就会去重刷锚，棘轮随之失效。
 * 2. **跨行命中假绿**（H2）：判据在整文件拼接文本上匹配，`\s` 允许跨行，于是
 *    `IconButton(` 换行后 `onClick = onBack` 能命中，却没有任何单独一行匹配得上，锚算不出来；
 *    上一版 `containsAll(空集)` 恒真 ⇒ 只要该键有例外行，这种命中就白放过。
 *    现在**零锚命中一律判待修**，并且**故意不回退**成「该键有例外 ⇒ 放过」——
 *    那等于把 2026-11-11 刚堵掉的整文件免检通道重新打开。
 *
 * 过期口径同步收紧：**任一登记锚失效即过期**（登记次数 > 命中次数就报），不是「全部失效才过期」。
 * 后者会让陈旧锚无限期留着，「只进不出」的口子重新打开。
 *
 * 键的规则名两侧都 `ToUpperInvariant` 归一（路径原样，避免引入新的平台大小写差异）。
 * 脚本侧的字典是大小写不敏感的（`[ordered]@{}`），守卫侧是敏感的（`linkedMapOf`），
 * 不归一就会出现「脚本绿、守卫找不到键」的各说各话。
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

    /**
     * 行级锚：`hash` 是那一行代码的短哈希（参与比对），`line` 只给人看（**不参与**比对）。
     *
     * 不绑行号是刻意的：见类注释「2026-11-11 改版」。
     */
    private data class Anchor(val hash: String, val line: Int)

    /** 一个页面文件剥完注释/字符串后的代码视图。 */
    private class SourceFile(val rel: String, val lines: List<CodeLine>) {
        val domain: String get() = rel.substringBefore('/')
        val code: String = lines.joinToString("\n") { it.text }

        fun first(re: Regex): Int =
            lines.firstOrNull { re.containsMatchIn(it.text) }?.number ?: 0

        fun count(re: Regex): Int =
            lines.count { re.containsMatchIn(it.text) }

        /**
         * 命中 `re` 的行及其行级锚（**不去重**）。
         *
         * 同一段代码出现两次就是两个同值锚（2026-11-12 多重集语义：登记 N 次只免检 N 处）。
         * 上一版在这里 `distinctBy { it.hash }`，同文件再粘一行完全相同的违规就借旧锚免检了。
         */
        fun anchorHits(re: Regex): List<Anchor> =
            lines.filter { re.containsMatchIn(it.text) }
                .map { Anchor(lineAnchor(it.text), it.number) }
                .sortedBy { it.line }

        /**
         * 跨行未计命中数 = 整文件拼接文本里的匹配数 − Σ(逐行匹配数)。
         *
         * 判据在拼接文本上匹配、`\s` 允许跨行，于是 `IconButton(` 换行后 `onClick = onBack`
         * 能在拼接文本里命中，却没有任何单独一行匹配得上 ⇒ 行级锚一个都算不出来。
         * 这个数 > 0 就说明有匹配只活在换行处：一律判待修，且**不可登记**。
         * 与 `compose-style-lint.ps1` 的 `Get-UnaccountedMatches` 逐字对偶。
         */
        fun unaccounted(re: Regex): Int =
            re.findAll(code).count() - lines.sumOf { re.findAll(it.text).count() }
    }

    /** 一处违规：`文件|规则` 是例外清单的比对键，说明文字只给人看。 */
    private data class Violation(
        val rel: String,
        val rule: String,
        val detail: String,
        /** 这一条违规**实际被判到的那几行**（行级锚，允许同值重复）；例外必须逐处登记。 */
        val anchors: List<Anchor>,
        /** 只活在换行处的命中数（算不出行级锚，一律待修、不可登记）。 */
        val crossLine: Int,
    ) {
        val key: String get() = "$rel|$rule"
        val anchorHashes: Set<String> get() = anchors.map { it.hash }.toSet()
    }

    /** 一条人工登记的例外。 */
    private data class ExceptionEntry(
        val key: String,
        val rel: String,
        val rule: String,
        /**
         * 登记的锚，**按出现次数计**：同一个锚登 N 次只免检 N 处命中（多重集，不是集合）。
         * 顺序保留（`-Write` 裁过期时按顺序裁尾）。
         */
        val anchors: List<String>,
        val reason: String,
        /** 出处 `文件名:行号`，报错时直接指过去。 */
        val source: String,
        /** 出处文件名（`<域>.txt`）——判「整条例外失效」时按它认域。 */
        val sourceFile: String,
    ) {
        /** 锚 → 需要几处命中。 */
        val anchorCounts: Map<String, Int> get() = anchors.groupingBy { it }.eachCount()
    }

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
                    f.anchorHits(reBackButton),
                    f.unaccounted(reBackButton),
                )
            }
            if (reLazyColumn.containsMatchIn(f.code) &&
                !rePageList.containsMatchIn(f.code) &&
                !reHaptic.containsMatchIn(f.code)
            ) {
                out += Violation(
                    f.rel, "R2",
                    "裸 LazyColumn，缺滚动三件套与滚动条（第 ${f.first(reLazyColumn)} 行）",
                    f.anchorHits(reLazyColumn),
                    f.unaccounted(reLazyColumn),
                )
            }
            if (reVerticalScroll.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R2",
                    "用 Column+verticalScroll 当主滚动（非惰性，第 ${f.first(reVerticalScroll)} 行）",
                    f.anchorHits(reVerticalScroll),
                    f.unaccounted(reVerticalScroll),
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
                    f.anchorHits(reRawCard),
                    f.unaccounted(reRawCard),
                )
            }
            if (reSectionLabel.containsMatchIn(f.code) && !reSectionTitle.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R6",
                    "自己拼分组标题，未走 QingyuSectionTitle（第 ${f.first(reSectionLabel)} 行）",
                    f.anchorHits(reSectionLabel),
                    f.unaccounted(reSectionLabel),
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
                    f.anchorHits(reFontSize),
                    f.unaccounted(reFontSize),
                )
            }
            if ("R7" !in exempt && reFontWeight.containsMatchIn(f.code)) {
                out += Violation(
                    f.rel, "R7",
                    "写死字重 ${f.count(reFontWeight)} 处，首处第 ${f.first(reFontWeight)} 行" +
                        "（应用 MiuixTheme.textStyles.*.shiftWeight）",
                    f.anchorHits(reFontWeight),
                    f.unaccounted(reFontWeight),
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
                    f.anchorHits(reHardColor),
                    f.unaccounted(reHardColor),
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

    // ─────────────────── 判定层：多重集 + 零锚（与脚本对偶） ───────────────────

    /**
     * 全树违规折成判定用的视图：**按 `文件|规则` 合并**（R2 的两种形态是同一个键），
     * 锚保留成多重集（不去重）。
     *
     * 合并这一步是 M1 的修法：上一版把违规按 key `associate` 成 Set，同键的两条违规
     * 后者覆盖前者，于是「R2 双形态都登记」在脚本那边是绿的、在这边却报过期。
     */
    private class ScanResult(
        /** `文件|规则` → 该键下所有命中行的锚（按行号升序，**允许同值重复**）。 */
        val anchorsByKey: Map<String, List<Anchor>>,
        /** `文件|规则` → 只活在换行处、算不出行级锚的命中数。 */
        val crossLineByKey: Map<String, Int>,
        /** `文件|规则` → 人看的说明（多条同键违规合并）。 */
        val detailsByKey: Map<String, String>,
    )

    private fun mergeViolations(violations: List<Violation>): ScanResult {
        val anchors = LinkedHashMap<String, MutableList<Anchor>>()
        val cross = LinkedHashMap<String, Int>()
        violations.forEach { v ->
            anchors.getOrPut(v.key) { mutableListOf() }.addAll(v.anchors)
            cross[v.key] = (cross[v.key] ?: 0) + v.crossLine
        }
        return ScanResult(
            anchorsByKey = anchors.mapValues { (_, list) -> list.sortedBy { it.line } },
            crossLineByKey = cross.filterValues { it > 0 },
            detailsByKey = violations.groupBy { it.key }
                .mapValues { (_, vs) -> vs.map { it.detail }.distinct().joinToString("；") },
        )
    }

    private fun scanAll(): ScanResult = mergeViolations(allViolations())

    /** 一处待修：多算出来的命中。跨行命中没有锚 ⇒ `hash == null`。 */
    private data class PendingHit(
        val key: String,
        val rel: String,
        val rule: String,
        val detail: String,
        val hash: String?,
        val registered: Int,
        val hit: Int,
        val need: Int,
        val surplusLines: List<Int>,
        val crossLine: Int,
    )

    /** 一处过期：登记了但没命中（按次数算盈余）。 */
    private data class StaleHit(
        val source: String,
        val key: String,
        val rel: String,
        val rule: String,
        val hash: String,
        val registered: Int,
        val hit: Int,
        val reason: String,
    )

    private class Judgement(val pending: List<PendingHit>, val stale: List<StaleHit>)

    /**
     * 判定一次：命中（多重集）vs 登记（多重集）。
     *
     * - **待修** = 每个锚「命中次数 − 登记次数 > 0」的盈余，加上跨行命中（零行级锚，不可登记）；
     *   零锚命中**一律**待修，**不回退**成「该键有例外 ⇒ 放过」（那等于退回整文件免检）。
     * - **过期** = 每个锚「登记次数 − 命中次数 > 0」的盈余。**任一登记锚失效即过期**，
     *   不是「全部失效才过期」——后者会让陈旧锚无限期留着，「只进不出」的口子重新打开。
     *   整条键已无任何违规时，该行全部锚都算过期。
     */
    private fun judge(scan: ScanResult, entries: Map<String, ExceptionEntry>): Judgement {
        val pending = mutableListOf<PendingHit>()
        val stale = mutableListOf<StaleHit>()
        val keys = (scan.anchorsByKey.keys + scan.crossLineByKey.keys).toSortedSet()

        keys.forEach { key ->
            val rel = key.substringBefore('|')
            val rule = key.substringAfter('|')
            val anchors = scan.anchorsByKey[key].orEmpty()
            val crossLine = scan.crossLineByKey[key] ?: 0
            val entry = entries[key]
            val detail = scan.detailsByKey[key].orEmpty()
            val hitCounts = anchors.groupingBy { it.hash }.eachCount()
            val regCounts = entry?.anchorCounts.orEmpty()

            hitCounts.forEach { (hash, hit) ->
                val registered = regCounts[hash] ?: 0
                if (hit <= registered) return@forEach
                pending += PendingHit(
                    key, rel, rule, detail, hash, registered, hit, hit - registered,
                    anchors.filter { it.hash == hash }.drop(registered).map { it.line },
                    0,
                )
            }
            if (crossLine > 0) {
                pending += PendingHit(key, rel, rule, detail, null, 0, crossLine, crossLine, emptyList(), crossLine)
            }

            regCounts.forEach { (hash, registered) ->
                val hit = hitCounts[hash] ?: 0
                if (registered <= hit) return@forEach
                stale += StaleHit(entry!!.source, key, rel, rule, hash, registered, hit, entry.reason)
            }
        }

        // 整条键已经一条违规都没有的例外（keys 里没有它）——单独走一遍，不能漏。
        entries.values.sortedBy { it.key }.forEach { e ->
            if (e.key in keys) return@forEach
            e.anchorCounts.forEach { (hash, registered) ->
                stale += StaleHit(e.source, e.key, e.rel, e.rule, hash, registered, 0, e.reason)
            }
        }
        return Judgement(pending, stale)
    }

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

    /** 锚的字面形状：8 位小写十六进制。与 `compose-style-lint.ps1` 的 `$reAnchor` 一致。 */
    private val anchorRegex = Regex("""^[0-9a-f]{8}$""")

    /**
     * 解析一行例外：`<相对路径>|<规则>|<锚列表>|<原因>`。
     *
     * 原因里允许再出现 `|`（前两段路径/规则、第三段锚，其余整段算原因）。
     * 锚列表**允许重复**：同一个锚写 N 次 = 该文件该规则下同文本必须命中 N 处。
     * 改造前（2026-11-11）的清单里每个锚各出现 1 次，在本解析器下仍然完全兼容——
     * 有回归测试钉着（`改造前的例外清单仍然解析成「每个锚 1 次」`）。
     * 三段式旧格式 `<路径>|<规则>|<原因>` **直接判错**：那等于整文件整规则免检，
     * 正是本轮要堵的洗白通道，绝不能当兼容形态悄悄放行。
     */
    private fun parseExceptionLine(line: String, fileName: String, lineNumber: Int): ExceptionEntry {
        val where = "$fileName:$lineNumber"
        val parts = line.split('|')
        if (parts.size < 4) {
            throw AssertionError(
                "例外行格式不对（应为 <相对路径>|<规则>|<锚>[,<锚>…]|<原因>）：$where → $line\n" +
                    "三段式旧格式已作废——它等于整文件整规则免检。请按行级锚重新登记" +
                    "（跑一次 scripts/compose-style-lint.ps1，[待修] 下面会打印「登记用锚：<hash>」）。",
            )
        }
        val rel = parts[0].trim()
        // 规则名统一大写后再拼键（与脚本的 ToUpperInvariant 对偶）。
        // 两侧不归一就会各说各话：脚本侧的字典大小写不敏感、这边的 linkedMapOf 敏感，
        // 规则列写成 r2 时一边判命中、另一边判「找不到键」。
        val rule = parts[1].trim().uppercase(Locale.ROOT)
        val anchors = parts[2].split(',').map { it.trim().lowercase(Locale.ROOT) }.filter { it.isNotEmpty() }
        val reason = parts.drop(3).joinToString("|").trim()
        if (rel.isEmpty() || rule.isEmpty() || reason.isEmpty()) {
            throw AssertionError("例外行的路径/规则/原因都不能为空：$where → $line")
        }
        if (anchors.isEmpty()) {
            throw AssertionError("例外行没有登记任何锚（第三段为空）：$where → $line")
        }
        // 同一个锚重复出现是**合法**的：登记 N 次 = 该文件该规则下同文本必须命中 N 处。
        // 2026-11-11 那版把重复当用法错，会把多重集语义直接挡死。
        anchors.firstOrNull { !anchorRegex.matches(it) }?.let {
            throw AssertionError("锚不是 8 位小写十六进制：'$it'（$where）→ $line")
        }
        return ExceptionEntry(
            key = "$rel|$rule",
            rel = rel,
            rule = rule,
            anchors = anchors,
            reason = reason,
            source = where,
            sourceFile = fileName,
        )
    }

    /**
     * 读全部例外；`#` 开头与空行跳过。
     *
     * 同一 `文件|规则` 只允许登记一次——多个锚合并进同一行，重复说明有人没删旧行。
     */
    private fun exceptionEntries(): Map<String, ExceptionEntry> {
        val result = linkedMapOf<String, ExceptionEntry>()
        exceptionFiles().forEach { file ->
            file.readLines().forEachIndexed { index, raw ->
                val line = raw.trim()
                if (line.isEmpty() || line.startsWith("#")) return@forEachIndexed
                val entry = parseExceptionLine(line, file.name, index + 1)
                if (result.containsKey(entry.key)) {
                    throw AssertionError(
                        "例外键重复：${entry.key}（${file.name}:${index + 1}）" +
                            "——同一处只登记一次，多个锚合并进同一行",
                    )
                }
                result[entry.key] = entry
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

    // ───────────────────────── 0.5 例外必须按「行级锚」判定 ─────────────────────────

    @Test
    fun `例外只覆盖登记过的那一行：整文件免检这条后门已关`() {
        // 上一版的例外键是「文件|规则」，登记一处 = 整文件整条规则免检。这里把三条
        // 性质钉住，防止有人把判据改回「比较 文件|规则 就完事」。
        //
        // ① 锚只跟这一行的代码走：trim 不影响，内容一改就换锚。
        assertEquals(
            "同一行代码 trim 前后必须是同一个锚",
            lineAnchor("""    Text(text = "", fontSize = 15.sp)  """),
            lineAnchor("""Text(text = "", fontSize = 15.sp)"""),
        )
        assertNotEquals(
            "行内容改了必须是另一个锚（否则「登记行被改掉」永远判不出来）",
            lineAnchor("""color = Color(0xFF2196F3)"""),
            lineAnchor("""color = Color(0xFF2196F4)"""),
        )

        // ② 三段式旧格式必须判错，不能被当成「原因里带 | 」的合法行放过去。
        val legacyRejected = runCatching {
            parseExceptionLine("showcase/ColorBlendToken.kt|R5|官方 demo 固定配色", "showcase.txt", 1)
        }.exceptionOrNull()
        assertTrue(
            "三段式旧格式（<路径>|<规则>|<原因>）必须被拒，实际没拒：$legacyRejected",
            legacyRejected is AssertionError,
        )

        // ③ 登记了 A 行的锚，顺带免检 B 行是**不允许**的：未登记的锚必须留在待修里。
        val probe = SourceFile(
            "showcase/Probe.kt",
            codeLinesOf(
                listOf(
                    "color = Color(0xFF111111)",
                    "color = Color(0xFF222222)",
                ).joinToString("\n"),
            ),
        )
        val hits = scanners.flatMap { it.scan(probe, emptySet()) }.first { it.rule == "R5" }
        assertEquals("两行写死色值应产生两个锚", 2, hits.anchorHashes.size)
        val entry = parseExceptionLine(
            hits.anchors.first().let { "showcase/Probe.kt|R5|${it.hash}|固定色" },
            "showcase.txt",
            1,
        )
        assertTrue(
            "登记过的锚应被认成例外",
            hits.anchors.first().hash in entry.anchors,
        )
        assertFalse(
            "没登记的另一行不能被别人的例外兜住",
            hits.anchors.last().hash in entry.anchors,
        )
    }

    // ─────────────────── 0.6 多重集语义 / 零锚（2026-11-12 契约） ───────────────────

    @Test
    fun `零锚命中一律待修：跨行 IconButton 不能靠该键的例外放行`() {
        // H2 回归。判据在整文件拼接文本上匹配，`\s` 允许跨行，于是
        //     IconButton(
        //         onClick = onBack,
        //     )
        // 能在拼接文本里命中，却没有任何单独一行匹配得上 ⇒ 行级锚一个都算不出来。
        // 上一版 `containsAll(空集)` 恒真：只要该键有例外行，这种命中就被白放过。
        val mixed = listOf(
            "fun p() {",
            "    IconButton(onClick = onBack) { }",
            "    IconButton(",
            "        onClick = onBack,",
            "    ) { }",
            "}",
        ).joinToString("\n")
        val hits = scanners.flatMap { it.scan(SourceFile("about/Probe.kt", codeLinesOf(mixed)), emptySet()) }
        val r1 = hits.first { it.rule == "R1" }
        assertEquals("单行那处有行级锚", 1, r1.anchors.size)
        assertEquals("跨行那处没有行级锚，必须单独计出来", 1, r1.crossLine)

        // 把单行那处登记成例外：不许因此把跨行命中一起放过（那等于退回整文件免检）。
        val entry = parseExceptionLine(
            "about/Probe.kt|R1|${r1.anchors.single().hash}|探针",
            "about.txt",
            1,
        )
        val judged = judge(mergeViolations(hits), mapOf(entry.key to entry))
        assertEquals("跨行命中必须留在待修里", 1, judged.pending.size)
        assertEquals("待修的正是那条零锚命中", null, judged.pending.single().hash)
        assertTrue("也不许把它记成过期（那是另一回事）", judged.stale.isEmpty())

        // 整个文件只有跨行写法时同样判待修（锚列表为空，连可登记的哈希都没有）。
        val onlyCrossLine = listOf("fun p() {", "    IconButton(", "        onClick = onBack,", "    ) { }", "}").joinToString("\n")
        val alone = scanners.flatMap { it.scan(SourceFile("about/Probe2.kt", codeLinesOf(onlyCrossLine)), emptySet()) }
            .first { it.rule == "R1" }
        assertTrue("零锚命中的锚列表必须是空的", alone.anchors.isEmpty())
        assertEquals("一处跨行命中", 1, judge(mergeViolations(listOf(alone)), emptyMap()).pending.size)
    }

    @Test
    fun `同一个锚按次数消费：登记 1 次只免检 1 处命中`() {
        // H1 回归：同文件再粘一行**完全相同的**违规。上一版锚按 hash 去重，
        // 于是这种复制粘贴借旧锚就免检了（实测 ColorBlendToken.kt 82 处命中只有 76 个锚）。
        val before = listOf(
            "fun p() {",
            "    val c = Color(0xFF123456)",
            "}",
        ).joinToString("\n")
        val after = listOf(
            "fun p() {",
            "    val c = Color(0xFF123456)",
            "    val c = Color(0xFF123456)",
            "}",
        ).joinToString("\n")

        fun hitsOf(sample: String): List<Violation> =
            scanners.flatMap { it.scan(SourceFile("showcase/Probe.kt", codeLinesOf(sample)), emptySet()) }

        fun judgeWith(sample: String, anchors: String): Judgement {
            val entry = parseExceptionLine("showcase/Probe.kt|R5|$anchors|探针值得保留", "showcase.txt", 1)
            return judge(mergeViolations(hitsOf(sample)), mapOf(entry.key to entry))
        }

        val twice = hitsOf(after).first { it.rule == "R5" }
        assertEquals("两行文本完全一致 ⇒ 两个锚", 2, twice.anchors.size)
        assertEquals("但值是同一个（锚只跟这行代码的文本走）", 1, twice.anchors.map { it.hash }.toSet().size)
        val hash = twice.anchors.first().hash

        val once = judgeWith(after, hash)
        assertEquals("登记 1 次只能免检 1 处，第 2 处仍是待修", 1, once.pending.size)
        assertEquals("还差 1 处没登记", 1, once.pending.single().need)
        assertEquals("未登记的正是第 2 处（样板的第 3 行）", listOf(3), once.pending.single().surplusLines)
        assertTrue("登记次数没超过命中次数，不该报过期", once.stale.isEmpty())

        val twiceRegistered = judgeWith(after, "$hash,$hash")
        assertTrue("同一行登两次同一个锚 = 需要 2 处命中，这时应绿", twiceRegistered.pending.isEmpty())
        assertTrue(twiceRegistered.stale.isEmpty())

        val shrunk = judgeWith(before, "$hash,$hash")
        assertTrue("只剩一处命中、没有新违规", shrunk.pending.isEmpty())
        assertEquals("登记 2 次 / 命中 1 处 ⇒ 多登的那 1 次必须过期", 1, shrunk.stale.size)
        assertEquals("登记 2 次", 2, shrunk.stale.single().registered)
        assertEquals("命中 1 处", 1, shrunk.stale.single().hit)
    }

    @Test
    fun `R2 双形态：任一登记锚失效即过期`() {
        // M1 回归 + 过期边界。R2 的两种形态（裸 LazyColumn / Column+verticalScroll）是**同一个键**，
        // 上一版按 key `associate` 成 Set，同键后一条覆盖前一条：脚本那边合并着是绿的，
        // 这边却把先出现的锚当成过期。现在按多重集合并。
        // 过期边界就一句：**任一登记锚失效即过期**（不是「全部失效才过期」）。
        val both = listOf(
            "fun p() {",
            "    LazyColumn {",
            "    }",
            "    Column(Modifier.verticalScroll(rememberScrollState())) {",
            "    }",
            "}",
        ).joinToString("\n")
        val onlyScroll = listOf(
            "fun p() {",
            "    Column(Modifier.verticalScroll(rememberScrollState())) {",
            "    }",
            "}",
        ).joinToString("\n")

        fun hitsOf(sample: String): List<Violation> =
            scanners.flatMap { it.scan(SourceFile("import/Probe.kt", codeLinesOf(sample)), emptySet()) }

        val hits = hitsOf(both)
        assertEquals("两条违规是同一个键", 1, hits.map { it.key }.toSet().size)
        val hashes = hits.flatMap { it.anchors }.map { it.hash }
        assertEquals("双形态各一处命中", 2, hashes.size)

        val entry = parseExceptionLine("import/Probe.kt|R2|${hashes.joinToString(",")}|探针双形态", "import.txt", 1)
        val entries = mapOf(entry.key to entry)

        val green = judge(mergeViolations(hits), entries)
        assertTrue("两种形态都登记 ⇒ 绿", green.pending.isEmpty())
        assertTrue("都命中，没有过期", green.stale.isEmpty())

        // 修掉其中一处（LazyColumn 那行删掉），另一个锚还命中。
        val after = judge(mergeViolations(hitsOf(onlyScroll)), entries)
        assertTrue("剩下那处已登记，不该待修", after.pending.isEmpty())
        assertEquals("任一登记锚失效即过期（不是等全部失效）", 1, after.stale.size)
        assertEquals("过期的正是 LazyColumn 那个锚", hashes.first(), after.stale.single().hash)
    }

    @Test
    fun `规则名统一大写后比较：例外里写 r5 与 R5 是同一把键`() {
        // M2 回归：脚本侧字典大小写不敏感、守卫侧 linkedMapOf 敏感，规则列写 r5 时
        // 两边会各说各话。现在两侧都先 ToUpperInvariant 再拼键（路径保持原样）。
        val entry = parseExceptionLine("showcase/Probe.kt|r5|deadbeef|探针", "showcase.txt", 1)
        assertEquals("规则名必须归一成大写", "showcase/Probe.kt|R5", entry.key)
        assertEquals("归一只动规则列", "R5", entry.rule)
        assertEquals("路径保持原样（小写路径不许被一起大写）", "showcase/Probe.kt", entry.rel)

        // 判定层也要认：写 r5 的例外能覆盖 R5 的命中，写 R5 的也能。
        val sample = "fun p() { val c = Color(0xFF123456) }"
        val hits = scanners.flatMap { it.scan(SourceFile("showcase/Probe.kt", codeLinesOf(sample)), emptySet()) }
        val hash = hits.first { it.rule == "R5" }.anchors.single().hash
        listOf("r5", "R5").forEach { spelling ->
            val lower = parseExceptionLine("showcase/Probe.kt|$spelling|$hash|探针", "showcase.txt", 1)
            val judged = judge(mergeViolations(hits), mapOf(lower.key to lower))
            assertTrue("规则列写 $spelling 时应认作例外", judged.pending.isEmpty())
            assertTrue("规则列写 $spelling 时不该报过期", judged.stale.isEmpty())
        }
    }

    @Test
    fun `改造前的例外清单仍然解析成「每个锚 1 次」`() {
        // 契约从「集合」改成「多重集」以后，旧清单（每个锚各 1 次）必须仍然完全兼容：
        // 解析层不报格式错、每个锚解析出来的次数都是 1。
        //
        // fixture 是改造前 `tool/compose_style_exceptions/` 的**逐字快照**（共 87 个锚），
        // 故意入库而不是运行时 `git show`：测试不该依赖 git 状态，也不该随工作区改动漂。
        val dir = File(repoRoot(), "android/app/src/test/resources/style-exceptions-legacy")
        assertTrue("找不到旧例外清单 fixture：${dir.path}", dir.isDirectory)
        val files = dir.listFiles { f -> f.isFile && f.name.endsWith(".txt") }
            ?.sortedBy { it.name }
            ?: emptyList()
        assertEquals("fixture 应该是 4 份域清单", 4, files.size)

        var total = 0
        files.forEach { file ->
            file.readLines().forEachIndexed { index, raw ->
                val line = raw.trim()
                if (line.isEmpty() || line.startsWith("#")) return@forEachIndexed
                // 能解析出来（不抛 AssertionError）本身就是「格式兼容」的断言。
                val entry = parseExceptionLine(line, file.name, index + 1)
                val repeated = entry.anchorCounts.filterValues { it > 1 }
                assertTrue(
                    "旧清单里每个锚只出现 1 次，实际多出：${repeated.keys}（${file.name}:${index + 1}）",
                    repeated.isEmpty(),
                )
                assertEquals(
                    "旧清单的规则列本来就写的是大写，归一后不该变：${file.name}:${index + 1}",
                    line.split('|')[1].trim(),
                    entry.rule,
                )
                total += entry.anchors.size
            }
        }
        assertEquals("改造前的例外清单共 87 个锚（旧值不许漂）", 87, total)
    }

    // ───────────────────────── 1. 待修违规必须是 0 ─────────────────────────

    @Test
    fun `待修样式违规必须为 0`() {
        // 这是守卫的核心：新页面/新代码绕开共享套件就会被拦下。
        // 存量债已经清完；真正需要保留的写法走例外清单，不算「待修」。
        //
        // 2026-11-11 起「走例外清单」是**逐行**的；2026-11-12 起再收一次：锚是**多重集**，
        // 同一个锚登记 N 次只免检 N 处命中；跨行命中算不出锚 ⇒ 一律待修（不可登记）。
        val pending = judge(scanAll(), exceptionEntries()).pending
        val detail = pending.joinToString("\n") { p ->
            val anchorLine = if (p.hash == null) {
                "\n        跨行命中 ${p.crossLine} 处（零行级锚）：不可登记，必须改回单行或改代码"
            } else {
                "\n        锚 ${p.hash} 还需再登记 ${p.need} 次" +
                    "（当前已登记 ${p.registered} 次 / 当前命中 ${p.hit} 处" +
                    (if (p.surplusLines.isEmpty()) "" else "，未登记的是第 ${p.surplusLines.joinToString("、")} 行") +
                    "）"
            }
            "  ${p.rel}  ${p.rule}  ${p.detail}$anchorLine"
        }
        assertEquals(
            "待修样式违规必须为 $EXPECTED_PENDING_VIOLATIONS 处，实际 ${pending.size} 处。\n" +
                "改代码走共享页面套件；确有正当理由要保留的，必须人工编辑 " +
                "tool/compose_style_exceptions/<域>.txt 并写明原因（脚本 -Write 不会帮你加）。\n" +
                detail +
                "\n\n例外只覆盖登记过锚的那几处：同一个锚登记 N 次只免检 N 处命中，" +
                "同文件同规则新增违规仍然是待修，不许靠扩例外放行。\n" +
                "规则见 docs/reference/compose-page-style-rules.md：\n" +
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
        //
        // 2026-11-11 起按**锚**判过期；2026-11-12 起按**次数**判：
        // 登记次数 > 命中次数的那部分就算过期（**任一登记锚失效即过期**，不等全部失效）。
        // 整条键都匹配不上时按「整条例外失效」报。
        val stale = judge(scanAll(), exceptionEntries()).stale
        assertTrue(
            "以下例外对应的违规行已经不存在了（改过内容、挪走了，或者修好了），请从例外清单里删掉：\n" +
                stale.joinToString("\n") { s ->
                    if (s.hit == 0) {
                        "  ${s.source}  ${s.key}  整条例外失效：该文件该规则已无违规（锚 ${s.hash}）  ${s.reason}"
                    } else {
                        "  ${s.source}  ${s.key}  锚 ${s.hash} 登记 ${s.registered} 次、命中 ${s.hit} 处：" +
                            "多登 ${s.registered - s.hit} 次（那一行改过内容 / 挪到别的文件 / 或已修好）"
                    }
                } +
                "\n\n删法：pwsh -File scripts/compose-style-lint.ps1 -Domain <域> -Write" +
                "（只删过期行与过期锚，不会新增）",
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

/**
 * 行级锚：剥完注释与字符串内容、`trim` 之后，取该行代码 UTF-8 的 SHA-256 前 4 字节。
 *
 * 放在**文件级**而不是成员函数：`SourceFile.anchorHits` 是嵌套类（非 inner），
 * 拿不到外层实例，只能调文件级私有函数。
 *
 * 与 `scripts/compose-style-lint.ps1` 的 `Get-LineAnchor` **逐字对偶**：
 * 同样的 `trim` → UTF-8 → SHA-256 → 前 8 位小写十六进制。两侧算不出同一个值，
 * 守卫与脚本就会各说各话（一边说过期、一边说待修），所以改一边必须同步改另一边。
 *
 * 取 8 位（32 bit）是刻意的取舍：目前登记的锚不到 90 个，生日碰撞概率约 1e-6；
 * 碰撞的后果也只是「多认一个锚」，不是漏判——要放行还得那行代码真的被登记。
 */
private fun lineAnchor(code: String): String {
    val digest = MessageDigest.getInstance("SHA-256")
        .digest(code.trim().toByteArray(Charsets.UTF_8))
    // 锚是**机器签名**，必须显式 Locale.ROOT —— 理由是结构判据：`LocaleFormatGuardTest`
    // 要求 `android/app/src` 下所有 `.format(…)` 调用一律显式传 Locale，漏传即红。
    //
    // 2026-11-12 实测（OpenJDK 17，逐个 Locale 跑 `String.format(locale, "%02x", 0..255)`）：
    // **`%02x` 的输出与 Locale 无关**，ar-EG / fa-IR / ar-EG-u-nu-arab / tr-TR / hi-IN / ROOT
    // 全部输出 ASCII 十六进制（同批实测 `%d` 在 ar-EG、fa-IR 下才变成阿拉伯/波斯数字）。
    // 所以「默认 Locale 下锚会跨机漂移」这个说法**不成立**，别拿它当理由；
    // 保留 Locale.ROOT 是为了守住结构判据，不是因为它改变了输出。
    return (0 until 4).joinToString("") {
        "%02x".format(Locale.ROOT, digest[it].toInt() and 0xFF)
    }
}
