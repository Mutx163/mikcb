package com.mutx163.qingyu.pages

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Compose 页面样式守卫（2026-10-28 建立）。
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
 * 一定漏——本项目已经漏了一整轮。这里用**源码文本守卫 + 棘轮基线**把七条规则钉死。
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
 * ## 棘轮怎么工作（这是本守卫能落地为「规则」的关键）
 *
 * 存量 151 处债**不要求一次清完**（那会把一次提交变成一次重构），而是冻结在
 * `tool/compose_style_baseline/<域>.txt` 里。三条判据：
 *
 * 1. **新增必红**：代码里的违规如果不在基线里 ⇒ 测试失败。⇒ 新页面无法退回旧写法。
 * 2. **过期必红**：基线里的行如果代码已经不违规了 ⇒ 测试失败，要求把那行删掉。
 *    ⇒ 逼着人还债，不许只进不出（否则基线会变成永久豁免清单）。
 * 3. **域自检**：每个域都必须有基线文件，且基线键（`文件|规则`）与代码实际违规一一对应。
 *
 * 比较只按 `相对路径|规则` 这个**键**，不比较说明文字——说明里带行号，代码一挪就变，
 * 拿它比对会造出一堆假红（`PageScaffoldGuardTest` 在注释判定上踩过同类坑）。
 *
 * ## 判定范围
 *
 * 只扫 `composeP1/.../pages/` 下的 `.kt`。`components/` 是套件自身（它就该调裸组件），
 * `pages/shell/`（壳自带导航栏）与 `pages/showcase/`（展厅故意逐个展示官方裸组件）
 * 有域级豁免，见规则文档 §五。
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
     * 仓库根：从 `android/app/src` 往上找到同时有 `lib/screens` 与 `pubspec.yaml` 的那层。
     * 基线文件与规则文档都挂在仓库根下，找不到就失败，不静默跳过。
     */
    private fun repoRoot(): File {
        var dir: File? = androidSrc().absoluteFile
        while (dir != null) {
            if (File(dir, "lib/screens").isDirectory && File(dir, "pubspec.yaml").isFile) return dir
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（lib/screens 与 pubspec.yaml）—— 守卫无法验证，按失败处理。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private val pagesRoot: File
        get() = File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/pages")

    /** 共享套件层（2026-11-04 起与 lint 同口径纳入扫描，基线键前缀 `components/`）。 */
    private val componentsRoot: File
        get() = File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/components")

    private val baselineRoot: File
        get() = File(repoRoot(), "tool/compose_style_baseline")

    private fun allPageFiles(): List<File> {
        val root = pagesRoot
        if (!root.isDirectory) {
            throw AssertionError("找不到页面源码目录：${root.path} —— 守卫无法验证，按失败处理。")
        }
        val roots = listOf(root, componentsRoot).filter { it.isDirectory }
        val files = roots.flatMap { r ->
            r.walkTopDown()
                .filter { it.isFile && it.extension == "kt" }
                .sortedBy { it.path }
                .toList()
        }.sortedBy { it.path }
        if (files.isEmpty()) {
            throw AssertionError("${root.path} 下一个 .kt 都没有，守卫会变成空跑，按失败处理。")
        }
        return files
    }

    private fun relOf(file: File): String {
        val abs = file.absoluteFile
        val comp = componentsRoot.absoluteFile
        if (abs.path.startsWith(comp.path + File.separator)) {
            return "components/" + abs.relativeTo(comp).path.replace(File.separatorChar, '/')
        }
        return abs.relativeTo(pagesRoot.absoluteFile).path.replace(File.separatorChar, '/')
    }

    /** 域 = 相对路径的第一段（about / course / statistics …）。 */
    private fun domainOf(rel: String): String = rel.substringBefore('/')

    // ───────────────────────── 判据 ─────────────────────────

    /**
     * 取一个文件的**代码行**（行号 + 去掉行内注释的正文）。
     *
     * 注释行（行首 `//`、`*`）与 `import` 行都不参与：文档注释里常摆着示例代码
     * （`about/PagesCommon.kt` 的历史注释里就有 `TopAppBar` 示例），
     * 用子串判会把它们当成真调用，造出假红（2026-10-28 在 `statusBarsPadding` 上实测过：
     * 真调用 0 处、注释提及 16 处）。
     */
    private fun codeLines(file: File): List<Pair<Int, String>> =
        file.readLines().mapIndexedNotNull { index, line ->
            val trimmed = line.trimStart()
            val commented = trimmed.startsWith("//") ||
                trimmed.startsWith("*") ||
                trimmed.startsWith("/*") ||
                trimmed.startsWith("import ")
            if (commented) null else (index + 1) to line.substringBefore("//")
        }

    /** 域级豁免：这些目录本来就该用裸组件（见规则文档 §五）。 */
    private val domainExempt: Map<String, Set<String>> = mapOf(
        "shell" to setOf("R1"), // 壳自带导航栏，不是子页
        "showcase" to setOf("R1", "R3", "R7"), // 展厅故意逐个展示官方裸组件与字重
    )

    /**
     * 文件级豁免（与 lint 的 `$fileExempt` 同口径）：套件本体就是「被用来绕开裸组件」
     * 的那一层，规则文档 §二 R3 明文豁免 `components/QingyuCard.kt` 自身。
     */
    private val fileExempt: Map<String, Set<String>> = mapOf(
        "components/QingyuCard.kt" to setOf("R3"),
    )

    /** 一处违规：`文件|规则` 是比对键，说明文字只给人看。 */
    private data class Violation(val rel: String, val rule: String, val detail: String) {
        val key: String get() = "$rel|$rule"
    }

    // 注意：Kotlin 的尾随 lambda 可以写成 `Card {` 而**没有括号**，所以判据一律用
    // `\s*[({]` 同时接受两种写法。只写 `\(` 会留下一条绕过通道
    // （2026-10-28 咬合探针实测：`Card {` / `LazyColumn {` 写法当时被判据完全漏掉）。
    // R1 判据曾写成 `Small?TopAppBar`（= "Smal" + 可选 l），只匹配 SmallTopAppBar、
    // 漏掉最常见的裸 TopAppBar（2026-10-28 自查抓到）。现改为判「手搓顶栏行」：
    // 有 IconButton(onClick = onBack) 却没有任何官方 TopAppBar / QingyuPageScaffold。
    // 裸 TopAppBar / SmallTopAppBar 都是官方组件、输出正确，不再视为违规。
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

    private fun violationsOf(file: File): List<Violation> {
        val rel = relOf(file)
        val domain = domainOf(rel)
        val exempt = domainExempt[domain] ?: emptySet()
        // 文件级豁免：套件本体就是「被用来绕开裸组件」的那一层（规则文档 §二 R3）。
        val fx = fileExempt[rel] ?: emptySet()
        val lines = codeLines(file)
        val all = lines.joinToString("\n") { it.second }
        val out = mutableListOf<Violation>()

        fun first(re: Regex): Int = lines.firstOrNull { re.containsMatchIn(it.second) }?.first ?: 0
        fun count(re: Regex): Int = lines.count { re.containsMatchIn(it.second) }

        // R1 页面骨架与顶栏 → 不许手搓顶栏行（官方 TopAppBar / QingyuPageScaffold 都行）
        if ("R1" !in exempt && reBackButton.containsMatchIn(all) && !reHasTopBar.containsMatchIn(all)) {
            out += Violation(rel, "R1", "手搓顶栏行（返回键），未走官方 TopAppBar / QingyuPageScaffold（第 ${first(reBackButton)} 行）")
        }

        // R2 滚动容器 → QingyuPageList
        if (reLazyColumn.containsMatchIn(all) && !rePageList.containsMatchIn(all) && !reHaptic.containsMatchIn(all)) {
            out += Violation(rel, "R2", "裸 LazyColumn，缺滚动三件套与滚动条（第 ${first(reLazyColumn)} 行）")
        }
        if (reVerticalScroll.containsMatchIn(all)) {
            out += Violation(rel, "R2", "用 Column+verticalScroll 当主滚动（非惰性，第 ${first(reVerticalScroll)} 行）")
        }

        // R3 卡片 → QingyuCard
        if ("R3" !in exempt && "R3" !in fx && reRawCard.containsMatchIn(all)) {
            out += Violation(rel, "R3", "裸 Card，缺按压反馈与语义圆角（第 ${first(reRawCard)} 行）")
        }

        // R4 字号 → MiuixTheme.textStyles
        if (reFontSize.containsMatchIn(all)) {
            out += Violation(
                rel, "R4",
                "写死字号 ${count(reFontSize)} 处，首处第 ${first(reFontSize)} 行（应用 MiuixTheme.textStyles）",
            )
        }

        // R5 颜色 → 主题取色
        if (reHardColor.containsMatchIn(all)) {
            out += Violation(
                rel, "R5",
                "写死颜色 ${count(reHardColor)} 处，首处第 ${first(reHardColor)} 行（应用主题语义槽）",
            )
        }

        // R6 分组标题 → QingyuSectionTitle
        if (reSectionLabel.containsMatchIn(all) && !reSectionTitle.containsMatchIn(all)) {
            out += Violation(rel, "R6", "自己拼分组标题，未走 QingyuSectionTitle（第 ${first(reSectionLabel)} 行）")
        }

        // R7 字重 → 主题字阶上的 shiftWeight
        if ("R7" !in exempt && reFontWeight.containsMatchIn(all)) {
            out += Violation(
                rel, "R7",
                "写死字重 ${count(reFontWeight)} 处，首处第 ${first(reFontWeight)} 行" +
                    "（应用 MiuixTheme.textStyles.*.shiftWeight）",
            )
        }

        return out
    }

    /** 全树违规，按 `文件|规则` 去重排序。 */
    private fun allViolations(): List<Violation> =
        allPageFiles().flatMap { violationsOf(it) }.sortedBy { it.key }

    // ───────────────────────── 基线 ─────────────────────────

    /**
     * 读基线目录下全部 `<域>.txt`，返回 `键 → 说明`。
     *
     * 行格式 `<相对路径>|<规则>|<说明>`；`#` 开头与空行跳过。
     * 键只取前两段（说明里带行号，代码一挪就变，拿它比对必然假红）。
     */
    private fun baselineKeys(): Map<String, String> {
        val root = baselineRoot
        if (!root.isDirectory) {
            throw AssertionError(
                "找不到基线目录：${root.path} —— 守卫无法验证，按失败处理。" +
                    "首次建立请跑 scripts/compose-style-lint.ps1 -Domain all -Write。",
            )
        }
        val files = root.listFiles { f -> f.isFile && f.name.endsWith(".txt") }?.sortedBy { it.name }
        if (files.isNullOrEmpty()) {
            throw AssertionError("${root.path} 下一个基线文件都没有，守卫会变成空跑，按失败处理。")
        }
        val map = mutableMapOf<String, String>()
        files.forEach { f ->
            f.readLines().forEach { raw ->
                val line = raw.trim()
                if (line.isEmpty() || line.startsWith("#")) return@forEach
                val parts = line.split('|')
                if (parts.size < 2) {
                    throw AssertionError("基线行格式不对（应为 <相对路径>|<规则>|<说明>）：${f.name} → $line")
                }
                val key = "${parts[0]}|${parts[1]}"
                map[key] = parts.getOrElse(2) { "" }
            }
        }
        return map
    }

    /** 每个域都必须有自己的基线文件，否则那个域等于没人看着。 */
    private fun baselineFilesByDomain(): Map<String, File> =
        baselineRoot.listFiles { f -> f.isFile && f.name.endsWith(".txt") }
            ?.associateBy { it.nameWithoutExtension }
            ?: emptyMap()

    // ───────────────────────── 0. 守卫自己不能空跑 ─────────────────────────

    @Test
    fun `守卫确实扫到了页面与基线而不是空跑`() {
        // 反向自检：全树扫描或基线读取一旦失效（路径找错、源码集改名、目录被清），
        // 下面每一条都会「零违规」地静静变绿——那比没有守卫更糟。
        val pages = allPageFiles()
        val baseline = baselineKeys()
        assertTrue(
            "只扫到 ${pages.size} 个页面文件，明显不对——路径或源码集可能变了，守卫在空跑。",
            pages.size >= 30,
        )
        assertTrue(
            // 阈值取 5 而不是更大：把债清到接近 0 正是本守卫的目标，不是异常。
            // 5 条仍足以识别「基线目录被清空/读错」这种空跑（当前刻意保留的例外有十几条）。
            "只读到 ${baseline.size} 条基线，明显不对——基线目录可能被清空了，守卫在空跑。",
            baseline.size >= 5,
        )
    }

    @Test
    fun `每个页面域都必须有基线文件`() {
        // 没有基线文件的域 = 那个域的债没被登记，新增违规会被当成「基线里没有」而红，
        // 但更糟的情况是整域漏扫。这里要求「代码里出现过的域」都有基线文件。
        val domainsInCode = allPageFiles().map { domainOf(relOf(it)) }.toSortedSet()
        val domainsWithBaseline = baselineFilesByDomain().keys
        val missing = domainsInCode.filter { it !in domainsWithBaseline }
        assertTrue(
            "以下域有页面源码但没有基线文件（请跑 scripts/compose-style-lint.ps1 -Domain <域> -Write）：\n" +
                missing.joinToString("\n") { "  $it" },
            missing.isEmpty(),
        )
    }

    // ───────────────────────── 1. 棘轮：只拦新增 ─────────────────────────

    @Test
    fun `不允许新增未登记的样式违规`() {
        // 这是守卫的核心：新页面/新代码绕开共享套件就会被拦下。
        // 存量债已冻结在基线里，不会误伤。
        val baseline = baselineKeys()
        val current = allViolations()
        val offenders = current.filter { it.key !in baseline }
        assertTrue(
            "以下位置绕开了共享页面套件，且不在基线里（新增违规）：\n" +
                offenders.joinToString("\n") { "  ${it.rel}  ${it.rule}  ${it.detail}" } +
                "\n\n规则见 docs/reference/compose-page-style-rules.md：\n" +
                "  R1 页面骨架 → QingyuPageScaffold\n" +
                "  R2 滚动容器 → QingyuPageList（内含滚动三件套与滚动条）\n" +
                "  R3 卡片 → QingyuCard（内含按压反馈与语义圆角）\n" +
                "  R4 字号 → MiuixTheme.textStyles\n" +
                "  R5 颜色 → MiuixTheme.colorScheme / Color(QingyuTheme.*)\n" +
                "  R6 分组标题 → QingyuSectionTitle\n" +
                "  R7 字重 → MiuixTheme.textStyles.*.shiftWeight(QingyuWeightDelta.*)\n" +
                "确实需要保留的（如与主题无关的固定语义色），请跑 " +
                "scripts/compose-style-lint.ps1 -Domain <域> -Write 登记进基线，并在基线行里写明原因。",
            offenders.isEmpty(),
        )
    }

    // ───────────────────────── 2. 棘轮：不许只进不出 ─────────────────────────

    @Test
    fun `基线里已经修好的行必须删掉`() {
        // 棘轮的另一半。没有这条，基线会退化成「永久豁免清单」——
        // 修好不删，下次扫描就把已上屏的字当成待办，也让后来者以为它还在用。
        val baseline = baselineKeys()
        val current = allViolations().map { it.key }.toSet()
        val stale = baseline.keys.filter { it !in current }.sorted()
        assertTrue(
            "以下基线行对应的违规已经不存在了（说明修好了），请从基线里删掉：\n" +
                stale.joinToString("\n") { "  $it" } +
                "\n\n删法：跑 scripts/compose-style-lint.ps1 -Domain <域> -Write 重新生成该域基线。",
            stale.isEmpty(),
        )
    }

    // ───────────────────────── 3. 基线目录本身不许被绕过 ─────────────────────────

    @Test
    fun `基线必须落在仓库的基线目录里`() {
        // 防「把基线改到别处、或者塞个同名文件让守卫读空」这类绕过。
        val root = baselineRoot
        assertTrue(
            "基线目录不存在：${root.path}（首次建立请跑 scripts/compose-style-lint.ps1 -Domain all -Write）",
            root.isDirectory,
        )
        val rel = root.relativeTo(repoRoot()).path.replace(File.separatorChar, '/')
        assertTrue(
            "基线目录必须在仓库根的 tool/compose_style_baseline 下，实际是：$rel",
            rel == "tool/compose_style_baseline",
        )
    }
}
