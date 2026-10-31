package com.mutx163.qingyu.pages

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 页面顶栏骨架守卫（2026-10-27 建立 → 2026-10-28 **升级为全树**）。
 *
 * ## 它钉住的是什么
 *
 * 用户 2026-10-28 反馈：一批页面「上下拉，一直显示的都是大标题」——大标题根本收不起来。
 * 根因是官方 `TopAppBar` 的两个默认值，都是**静默**的（编译过、测试绿、只有真机盯屏才看得出来）：
 *
 * - `largeTitle: String = title`：不传 = 白送一个 32sp 大标题，永远占着那 ~60dp；
 * - `scrollBehavior: ScrollBehavior? = null`：不传 = **永不折叠**，往上滑也只把内容顶上去。
 *
 * 官方 demo 的做法（`docs/reference/miuix-demo/docs/zh_CN/components/topappbar.md`）是三件齐：
 * 一个 `ScrollBehavior` 实例 → 顶栏 `scrollBehavior = …` → 页面**唯一的滚动容器**挂
 * `Modifier.nestedScroll(behavior.nestedScrollConnection)`。少任何一件都表现为「大标题不动」。
 *
 * 另外三条历史坑（同属本守卫）：
 *
 * 1. **顶栏不许塞在内容里**：塞进 `Column { TopAppBar(); content() }` 时，官方顶栏自带的
 *    `WindowInsets.systemBars` 顶部内边距（`TopAppBar.kt:806`）会和 `Scaffold` 在 `topBar`
 *    为空时补的那份算两遍，标题整体下移一个状态栏高度。必须放进 `Scaffold` 的 `topBar` 槽。
 * 2. **不许再手写 `statusBarsPadding()`**：同上，顶栏已经自己吃了状态栏。
 *    判据是「真的调用」而非「文本里出现这个名字」——页面上留着一批
 *    「不手写 statusBarsPadding()，Scaffold 已经给过一次」的说明注释，
 *    子串判定会把它们全判成违规（2026-10-28 实测：真调用 0 处、注释提及 16 处，
 *    用子串判定会出 10 条假红）。
 * 3. **底部内边距要算手势条**：只取 `innerPadding.calculateTopPadding()` 时，
 *    列表最后一行会钻到系统手势条下面。
 * 4. **`nestedScroll` 必须写在滚动修饰符外层**：`.verticalScroll(…).nestedScroll(…)`
 *    看着该做的都做了，实际把连接放到了滚动节点里面，手势不上抛、大标题照旧不收起
 *    （2026-10-28 在 `schedule/AddScheduleItemPage.kt` 抓到一例）。
 *
 * ## 判定范围（为什么不是「全仓每个文件」）
 *
 * 只有**自己组合了可折叠 `TopAppBar(` 的页面文件**才可能出现「大标题永不收起」这个病：
 * 用 `SmallTopAppBar` 的页面、和压根没有顶栏的文件（时间轴内容块、共用行组件……）都在范围外。
 * 范围外文件里的写法不归本守卫管，免得「一次提交变成一次重构」。
 * （`statusBarsPadding()` 这批债 2026-10-28 已被另一条泳道清完，`pages/` 下真调用 0 处。）
 *
 * ## 它是源码文本守卫，不是行为测试
 *
 * 和 `SettingsRowComponentGuardTest` 同一套路：真机截图要用户配合、CI 里跑不了，
 * 但「有没有写这几个必要参数 / 有没有挂上」是文本可判的。文本守卫的代价是**容易被绕过**
 * （改个换行、换个写法），所以断言刻意只钉「必须出现的最小集合」，不规定书写格式。
 *
 * 读文件所以纪律上要做两件事：路径从工作目录向上找（CI 与 IDE 都能跑）；
 * 找不到文件时**失败而不是跳过**——跳过等于守卫不存在。
 */
class PageScaffoldGuardTest {

    // ───────────────────────── 走文件系统 ─────────────────────────

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

    private val pagesRoot: File
        get() = File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/pages")

    /** composeP1 下全部页面源码（递归）。空结果与目录缺失都按失败处理，避免守卫空跑。 */
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

    private fun relOf(file: File): String = file.relativeTo(pagesRoot).path.replace(File.separatorChar, '/')

    /**
     * 仓库根：从 `android/app/src` 往上找到同时有 `lib/screens` 与 `pubspec.yaml` 的那层。
     *
     * 有它才能把 Dart 原版当**前提**来钉（见下面那条变体一致性判据）。
     * 找不到就失败，不静默跳过——跳过等于判据不存在。
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

    /**
     * 返回**代码行**里提到顶栏组件名的行号（从 1 开始）。
     *
     * 用途是「判据覆盖自检」：范围 S 靠一条要求括号紧邻的正则认顶栏，
     * Kotlin 却允许 `TopAppBar` 与左括号之间留空白，写成那样整页会**悄无声息地**
     * 从 S 里消失（守卫与离线脚本同时瞎）。这里改用最松的判据——代码行里提到就认，
     * 再去要求它落进 S，于是「括号前多一个空格」这种写法跑不掉。
     *
     * 两个变体名：`SmallTopAppBar` 里也含 `TopAppBar`，所以整行先看有没有前者。
     * 注释（行首星号、行首双斜杠、行内双斜杠之后）与 `import` 行都不算：
     * 2026-10-28 实测 `about/PagesCommon.kt` 的文档注释里就摆着示例代码，
     * 用子串判会把注释当成真顶栏，造出假红。
     */
    private fun barMentionLines(text: String): List<Int> =
        text.lineSequence()
            .mapIndexedNotNull { index, line ->
                val code = line.substringBefore("//").trimStart()
                val isComment = code.startsWith("*") || code.startsWith("/*")
                val mentionsBar = "TopAppBar" in code && "SmallTopAppBar" !in code
                if (!isComment && !code.startsWith("import ") && mentionsBar) index + 1 else null
            }
            .toList()

    private fun pageFile(relative: String): File = File(pagesRoot, relative)

    private fun read(relative: String): String {
        val file = pageFile(relative)
        assertTrue("受管页面文件不存在：${file.path}", file.isFile)
        return file.readText()
    }

    // ───────────────────────── 判据 ─────────────────────────

    /** 可折叠顶栏：`TopAppBar(`，但**不算** `SmallTopAppBar(`（后者是大标题的正面变体）。 */
    private val collapsibleTopAppBarRegex = Regex("(?<![A-Za-z])TopAppBar\\(")

    /** 页面里能承接折叠手势的滚动容器（列表组件 `QingyuPageList` 内部自己就是 LazyColumn）。 */
    private val scrollableTokens = listOf("LazyColumn(", "verticalScroll(", "QingyuPageList(")

    /**
     * 顺序写反：`.verticalScroll(…)` 之后紧跟 `.nestedScroll(…)`。
     *
     * 修饰符链里**写在前面的是外层**，而 `NestedScrollConnection` 只接收
     * 「滚动子节点」派发上来的事件（AndroidX 原文：receiving events when scrollable
     * **descendant** is being scrolled）⇒ 连接必须待在滚动节点的祖先一侧。
     * 写成 `.verticalScroll().nestedScroll()` 时连接成了滚动节点的**后代**，
     * 永远收不到事件，表现就是「参数都传了，大标题还是不收起」。
     *
     * 2026-10-28 在 `schedule/AddScheduleItemPage.kt` 上抓到过一例——它是本仓唯一一例，
     * 也是「明明写了 nestedScroll 却没效果」的典型：文本上有、语义上没有。
     */
    private val inversedNestedScroll =
        Regex("""\.verticalScroll\([^\n]*\)[\s\S]{0,160}?\.nestedScroll\(""")

    /**
     * 真的**调用** `statusBarsPadding()` 才算违规。
     *
     * 不能写成 `"statusBarsPadding" in text`：2026-10-28 清完这批债之后，页面里留下的
     * 恰好是**说明性的注释**——「不手写 statusBarsPadding()，miuix Scaffold 的
     * contentWindowInsets 已经给过一次」。那是解释为什么**不**这么写，子串一搜全中，
     * 全树 16 处注释会造出 10 条假红，守卫就此变成噪音、下次真红了没人看。
     *
     * 所以按行判：以 `//` 或 `*` 开头的注释行里的提及不算，只有代码里真的调用了才算。
     *
     * ⚠️ 这段 KDoc 里**不许再出现**「斜杠 + 星号」或「星号 + 斜杠」这种两字符连写
     * （本文档的上一版就写了前者，结果把整段注释吃掉、`src/test` 一编就报 `Unclosed comment`）。
     * 原因是 **Kotlin 的块注释会嵌套**（与 C/Java 不同）：注释正文里开一层，后面的收尾
     * 只关掉内层，外层一直吃到文件尾。反过来的那种连写更隐蔽——它**提前关掉**本段注释，
     * 后面几行中文瞬间变代码，报出来的错是「Expecting member declaration」，跟注释八竿子打不着。
     * L1 只编主源码、**不编 `src/test`**，所以这类错在 L1 全绿时依然藏着，只有 L2 才炸 —
     * `.agents/diag/check-kotlin-lex.py` 就是为此写的离线检查（两种连写都查）。
     * 实测 `.agents/diag/scan-status-bars-padding.py`：真调用 0 处、注释提及 16 处。
     */
    private val statusBarsPaddingCall = Regex("""(?<![A-Za-z])statusBarsPadding\s*\(""")

    /** 返回真调用所在的行号（从 1 开始），注释行一律不算。 */
    private fun statusBarsPaddingCallLines(text: String): List<Int> =
        text.lineSequence()
            .mapIndexedNotNull { index, line ->
                val trimmed = line.trimStart()
                val commented = trimmed.startsWith("//") ||
                    trimmed.startsWith("*") ||
                    trimmed.startsWith("/*")
                if (!commented && statusBarsPaddingCall.containsMatchIn(line)) index + 1 else null
            }
            .toList()

    /**
     * 「共用骨架」：它们自己组合顶栏、自己持有 `ScrollBehavior`，但**列表在调用方手里**，
     * 所以不能用「本文件里有没有 nestedScroll」来判它——它们由 `content(innerPadding, scrollBehavior)`
     * 把行为交给每个调用页，接线责任在调用页。这两个文件因此豁免「本页必须能滚动」这条。
     */
    private val sharedScaffolds = setOf(
        "about/PagesCommon.kt",
        "import/ImportCommon.kt",
    )

    /** 本次受管的 9 个页面（P3-A 三页 + P3-D2 五页 + 共用骨架），钉历史那三条坑。 */
    private val guardedPages = listOf(
        "about/PagesCommon.kt",
        "about/AboutStaticPage.kt",
        "about/OpenSourceLicensesPage.kt",
        "about/SupportCreatorPage.kt",
        "schedule/AddScheduleItemPage.kt",
        "schedule/ScheduleDateRulePage.kt",
        "schedule/ScheduleListPage.kt",
        "task/AddTaskPage.kt",
        "task/TaskListPage.kt",
    )

    /** 范围 S：自己组合了可折叠顶栏的页面（相对路径 → 源码文本）。 */
    private fun collapsibleBarPages(): List<Pair<String, String>> =
        allPageFiles()
            .map { relOf(it) to it.readText() }
            .filter { (_, text) -> collapsibleTopAppBarRegex.containsMatchIn(text) }

    /**
     * 该文件有没有把滚动手势接上：挂 `nestedScroll(`，或把行为交给 `QingyuPageList`
     * （调用参数窗口里出现 `scrollBehavior`；窗口取 600 字符，够跨多行实参）。
     */
    private fun wiringTokens(text: String): Boolean =
        "nestedScroll(" in text || Regex("QingyuPageList\\([\\s\\S]{0,600}?scrollBehavior").containsMatchIn(text)

    private fun hasScrollable(text: String): Boolean = scrollableTokens.any { it in text }

    // ───────────────────────── 0. 守卫自己不能空跑 ─────────────────────────

    @Test
    fun `守卫确实扫到了页面而不是空跑`() {
        // 反向自检：全树扫描一旦失效（路径找错、源码集改名、walk 失效），
        // 下面每一条都会「零违规」地静静变绿——那比没有守卫更糟。
        val all = allPageFiles()
        val barPages = collapsibleBarPages()
        assertTrue(
            "只扫到 ${all.size} 个页面文件，明显不对——路径或源码集可能变了，守卫在空跑。",
            all.size >= 30,
        )
        assertTrue(
            "只扫到 ${barPages.size} 个有可折叠顶栏的页面，明显不对——判据可能写坏了，守卫在空跑。",
            barPages.size >= 15,
        )
    }

    // ───────────────────────── 1. 大标题必须能折叠 ─────────────────────────

    @Test
    fun `有可折叠顶栏的页面必须传 largeTitle 与 scrollBehavior`() {
        // 官方 TopAppBar 的 largeTitle 默认等于 title、scrollBehavior 默认 null：
        // 不传 = 常驻一个 32sp 大标题且永不折叠，与 Dart 侧 HyperosSubpage
        // （overlayHeader=true + collapsibleLargeTitle=true）的可折叠行为不符。
        val offenders = collapsibleBarPages().filter { (_, text) ->
            "largeTitle" !in text || "scrollBehavior" !in text
        }.map { it.first }
        assertTrue(
            "以下页面用了可折叠 TopAppBar 却没传 largeTitle / scrollBehavior（大标题永不收起）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `有可折叠顶栏的页面必须把滚动手势接到折叠行为上`() {
        // 只把 scrollBehavior 传给顶栏还不够：手势要能传到它那里，必须由滚动容器挂
        // nestedScroll（或把行为交给 QingyuPageList）。漏这一步就是
        // 「参数传了、行为没接」，真机上看起来和完全没做一样。
        val offenders = collapsibleBarPages()
            .filter { (rel, text) -> rel !in sharedScaffolds && !wiringTokens(text) }
            .map { it.first }
        assertTrue(
            "以下页面有可折叠顶栏，却没把滚动手势接上（缺 nestedScroll(，QingyuPageList 也没传 scrollBehavior）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `有可折叠顶栏的页面必须把顶栏放进 Scaffold 的 topBar 槽`() {
        // 顶栏塞在内容 Column 里时，官方顶栏自带的系统栏内边距会和 Scaffold 补的那份
        // 算两遍，标题整体下移一个状态栏高度（2026-10-27 返工过一版）。
        val offenders = collapsibleBarPages().filter { (_, text) ->
            "topBar" !in text
        }.map { it.first }
        assertTrue(
            "以下页面有可折叠顶栏，但顶栏不在 Scaffold 的 topBar 槽里（标题会被系统栏内边距顶下去）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `有可折叠顶栏的页面必须真的有滚动容器`() {
        // 一页挂着可折叠大标题、页内却没有任何纵向滚动容器 = 大标题永远没机会收起。
        // 这种页面要么改成可滚动，要么按 Dart 侧 collapsibleLargeTitle:false 换成 SmallTopAppBar。
        // 共用骨架豁免：列表在调用页手里，它自己注定没有滚动容器。
        val offenders = collapsibleBarPages()
            .filter { (rel, text) -> rel !in sharedScaffolds && !hasScrollable(text) }
            .map { it.first }
        assertTrue(
            "以下页面挂着可折叠大标题却没有滚动容器（大标题永远收不起来）：\n" +
                offenders.joinToString("\n") { "  $it" } +
                "\n如果 Dart 侧这页本来就是 collapsibleLargeTitle:false，请改用 SmallTopAppBar。",
            offenders.isEmpty(),
        )
    }

    // ───────────────────────── 2. 历史三条坑（受管页 + 范围 S） ─────────────────────────

    // ───────────── 1.5 Dart 变体一致性与判据覆盖自检（2026-10-28 独立复核新增） ─────────────

    /**
     * Dart 侧明确关掉折叠大标题的页面，Compose 侧不许再出现大标题。
     *
     * 2026-10-28 独立复核抓到一例：`diagnostics/LiveDiagnosticsLogPage.kt` 的注释写着
     * 「Dart 侧走 HyperosSubpage，collapsibleLargeTitle 默认 true ⇒ 可折叠大标题」，
     * 于是照可折叠大标题接了线。但 Dart 那页是**显式**关掉的：
     * `lib/screens/live_diagnostics_log_viewer_screen.dart` 里写着 false，
     * 上面还留了一段说明——大标题收起后 body 顶部 inset 仍按展开态保持，长列表 delta=0 不重测，
     * 大标题区会变成一条永久死区，筛选条底下跟一条空白。工具页要的是固定小标题栏。
     *
     * 这类错**原判据一条都拦不住**：只查「有 largeTitle + 有 scrollBehavior」的写法，
     * 参数齐全、方向反了照样绿。所以这里把「Dart 说了 false」的页面逐个钉住，
     * 并顺手盯住 Dart 那一行还在不在——前提变了要重新对照，不能默默放过。
     */
    @Test
    fun `Dart 侧关掉折叠大标题的页面不许再出现大标题`() {
        val entries = listOf(
            "lib/screens/live_diagnostics_log_viewer_screen.dart" to
                "diagnostics/LiveDiagnosticsLogPage.kt",
            "lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart" to
                "import/warehouse/WarehouseWebLoginPage.kt",
        )
        val root = repoRoot()
        entries.forEach { (dartRel, composeRel) ->
            val dart = File(root, dartRel)
            assertTrue("Dart 原版文件不存在：$dartRel", dart.isFile)
            assertTrue(
                "$dartRel 里已经不再写 collapsibleLargeTitle: false —— 前提变了，" +
                    "请重新对照 Dart 与 Compose 的页面壳变体，再决定这条判据的去留。",
                "collapsibleLargeTitle: false" in dart.readText(),
            )
            assertTrue(
                "$composeRel 用了大标题，但 Dart 原版 $dartRel 明确写了 " +
                    "collapsibleLargeTitle: false（这页不该有大标题）：请改用 SmallTopAppBar，" +
                    "照 settings/SettingsPageRenderers.kt 的写法。",
                "largeTitle" !in read(composeRel),
            )
        }
    }

    /**
     * 判据覆盖自检：代码里出现顶栏组件名的页面，都必须落进范围 S。
     *
     * 范围 S 用一条要求括号紧邻的正则认顶栏，于是「组件名与左括号之间留个空白」
     * 这种合法排版会让整页从守卫里消失；注释里的提及反过来会造出假红。
     * 这里按 [barMentionLines] 的结论反查一遍，把两个方向都堵上。
     */
    @Test
    fun `代码里出现的顶栏组件名都必须落进判据范围`() {
        val scope = collapsibleBarPages().map { it.first }.toSet()
        val offenders = allPageFiles().mapNotNull { file ->
            val rel = relOf(file)
            when {
                rel in scope -> null
                barMentionLines(file.readText()).isEmpty() -> null
                else -> rel
            }
        }
        assertTrue(
            "以下页面在代码里组合了顶栏，却没被范围 S 认出来（判据可能写坏了，" +
                "会让整页从守卫里消失）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    /**
     * 取每个骨架调用的实参表文本：从组件名起，到「后面跟左花括号」的那个右括号为止
     * （也就是尾随 lambda 的开始处）。这样多行实参、实参里嵌函数调用都切不断。
     */
    private fun skeletonCallTexts(text: String): List<String> {
        val names = listOf("QingyuPageScaffold(", "ImportPageScaffold(")
        val calls = mutableListOf<String>()
        for (name in names) {
            var from = text.indexOf(name)
            while (from >= 0) {
                var end = -1
                var i = from + name.length
                while (i < text.length) {
                    if (text[i] == ')') {
                        var j = i + 1
                        while (j < text.length && text[j].isWhitespace()) j++
                        if (j < text.length && text[j] == '{') {
                            end = i + 1
                            break
                        }
                    }
                    i++
                }
                calls += text.substring(from, if (end < 0) text.length else end)
                from = text.indexOf(name, from + name.length)
            }
        }
        return calls
    }

    /**
     * 这个文件有没有「真有大标题」的骨架调用：骨架里 `smallTopBar = true` 走的是官方
     * SmallTopAppBar，单行小标题、压根没有大标题可以收，不该被下面的接线判据要求。
     */
    private fun hasCollapsibleSkeletonCall(text: String): Boolean =
        skeletonCallTexts(text).any { "smallTopBar = true" !in it }

    /**
     * 用共用骨架的页面必须自己把滚动手势接上（2026-10-28 复核补的盲区）。
     *
     * 范围 S 只认「自己组合了顶栏」的文件，于是用骨架的页面**一个都不在守卫里**：
     * 顶栏在骨架里、列表在调用页手里，接线责任落在调用页，却没有任何测试看着它。
     * 现状可折叠的那些都接对了，这条是把「零防护」补上——以后谁改这些页、或改骨架
     * `content(innerPadding, scrollBehavior)` 的契约，都会有测试红。
     *
     * 只要求「可折叠大标题」的调用页（`smallTopBar` 缺省 false 或显式 false）；
     * `smallTopBar = true` 的页面渲染单行小标题，没有大标题可收，豁免。
     */
    @Test
    fun `用共用骨架的页面必须自己把滚动手势接上`() {
        val callers = allPageFiles()
            .map { relOf(it) to it.readText() }
            .filter { (rel, text) -> rel !in sharedScaffolds && hasCollapsibleSkeletonCall(text) }
        assertTrue(
            "只找到 ${callers.size} 个用骨架渲染可折叠大标题的调用页，明显不对——判据可能写坏了，守卫在空跑。",
            callers.size >= 6,
        )
        val offenders = callers.filter { (_, text) -> !wiringTokens(text) }.map { it.first }
        assertTrue(
            "以下页面用共用骨架渲染列表，却没把滚动手势接上（大标题收不起来）：\n" +
                offenders.joinToString("\n") { "  $it" } +
                "\n骨架把行为交给调用页，调用页要在自己的滚动容器上写 " +
                "Modifier.nestedScroll(scrollBehavior.nestedScrollConnection)。",
            offenders.isEmpty(),
        )
    }

    @Test
    fun `nestedScroll 必须写在滚动修饰符外层`() {
        // 文本上有 nestedScroll、语义上没接上——这是最阴的一种「不收起」：
        // 代码看着全做对了，人眼 review 也容易放过。
        // 修饰符链里写在前面的是外层，而连接只收「滚动子节点」派发的事件，
        // 所以 .verticalScroll(…) 后面再跟 .nestedScroll(…) 等于把连接放到了滚动节点里面。
        val scope = (guardedPages + collapsibleBarPages().map { it.first }).distinct().sorted()
        val offenders = scope.filter { inversedNestedScroll.containsMatchIn(read(it)) }
        assertTrue(
            "以下页面把 nestedScroll 写在了 verticalScroll 之后（顺序反了，滚动手势不会向上抛，大标题永不折叠）：\n" +
                offenders.joinToString("\n") { "  $it" } +
                "\n正确写法是 .nestedScroll(…) 在前、.verticalScroll(…) 在后。",
            offenders.isEmpty(),
        )
    }

    @Test
    fun `不允许再手写状态栏内边距`() {
        // 顶栏进 Scaffold 的 topBar 槽位后，状态栏由官方组件自己吃。
        // 再手加一次就是重复计算，标题会整体下移一个状态栏高度。
        //
        // 注意判据是「真的调用」，不是「文本里出现这个名字」：页面里现在有一批
        // 「不手写 statusBarsPadding()，Scaffold 已经给过一次」的说明注释，
        // 子串判定会把它们全判成违规（实测 16 处注释 → 10 条假红）。
        val scope = (guardedPages + collapsibleBarPages().map { it.first }).distinct().sorted()
        val offenders = scope.mapNotNull { rel ->
            val lines = statusBarsPaddingCallLines(read(rel))
            if (lines.isEmpty()) null else "$rel（第 ${lines.joinToString("、")} 行）"
        }
        assertTrue(
            "以下页面还在手写 statusBarsPadding（顶栏已自带系统栏内边距，会算两遍）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `受管页面一个都不能少`() {
        // 防止有人删页/改名后守卫静默变成空跑。
        val missing = guardedPages.filter { !pageFile(it).isFile }
        assertTrue("以下受管页面文件不见了：$missing", missing.isEmpty())
    }

    @Test
    fun `底部内边距必须包含手势条高度`() {
        // 页面底色延伸到手势条下方是 Edge-to-Edge 的正确行为，
        // 但内容必须给自己留出那一段，否则最后一行钻到小白条底下。
        //
        // 骨架 PagesCommon 只把 innerPadding 转发给内容、自身不持有列表，
        // 所以不受这条约束（它由各页负责用对）。
        val offenders = guardedPages.filter { rel ->
            if (rel.startsWith("about/PagesCommon")) return@filter false
            val text = read(rel)
            if ("innerPadding" !in text) return@filter false
            // 把 `innerPadding` 原样转发给共享列表组件的页面**不该**再自己加一次：
            // `QingyuPageList` 内部已经算过手势条高度
            // （`components/QingyuPageList.kt:85`：`innerPadding.calculateBottomPadding()
            // + contentPadding.calculateBottomPadding()`），再相加就是重复。
            // 2026-10-30 实测误报：`task/TaskListPage.kt` 只把 innerPadding 传给
            // `QingyuPageList`，守卫却判它「没把手势条算进去」，会把正确写法逼成错误写法。
            val delegatesToSharedList =
                "QingyuPageList(" in text && "innerPadding = innerPadding" in text
            if (delegatesToSharedList) return@filter false
            "calculateBottomPadding()" !in text
        }
        assertTrue(
            "以下页面取了 innerPadding 却没把底部手势条高度算进去：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `受管页面必须走页面主题桥`() {
        // 两个壳用的是无参 MiuixTheme{ }（配色恒亮），页面侧必须自己兜住深色，
        // 否则深色下卡片是白的、正文也取白 → 内容不可读。
        // about 三页共用骨架，所以只要求 PagesCommon 里有；
        // 其余 5 页各自包一层。
        //
        // 判据只认组件名出现，不钉调用写法（`QingyuPageTheme { … }` 与
        // `QingyuPageTheme(content = …)` 都算），避免守卫变成格式警察。
        assertTrue(
            "about/PagesCommon.kt 没有包 QingyuPageTheme，关于域三页在深色下会白字白底",
            "QingyuPageTheme" in read("about/PagesCommon.kt"),
        )
        val standalone = listOf(
            "schedule/AddScheduleItemPage.kt",
            "schedule/ScheduleDateRulePage.kt",
            "schedule/ScheduleListPage.kt",
            "task/AddTaskPage.kt",
            "task/TaskListPage.kt",
        )
        val offenders = standalone.filter { "QingyuPageTheme" !in read(it) }
        assertTrue(
            "以下页面没有包 QingyuPageTheme（深色下白字白底）：\n" +
                offenders.joinToString("\n") { "  $it" },
            offenders.isEmpty(),
        )
    }
}