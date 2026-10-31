package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 设置族**路由落点守卫**：页面里出现的每个导航目标，都必须能在壳的
 * [shellPageIdForRoute] 里找到映射。
 *
 * ## 为什么要这条（2026-10-28 / 2026-10-31 两次真实缺陷）
 *
 * 设置族 20+ 页共用一个 `SettingsPageScreen(spec)` 渲染层，行上的导航目标写在
 * `actionTarget` 里——可能直接写字面量，也可能引用某个常量（如
 * `SettingsBackdropFlowPage.BING_GALLERY_TARGET`）。壳用一个映射表把路由串翻成页面 id。
 * 只要漏一条，那一行就是「点了没反应」——而这类缺陷**编译能过、单测能过、真机上才看得见**。
 *
 * 2026-10-31 又漏一次：`BING_GALLERY_TARGET = "bingWallpaperGallery"`。旧守卫只扫
 * `main/.../pages/settings/` 下的 `.kt` **单层**目录、只认 `const val ROUTE_*` 与
 * `actionTarget = "/..."`；这个常量名字是 `_TARGET` 后缀、值又**没有前导 `/`**，两刀都躲过。
 * 现在改成：两个源集（`main` / `composeP1`）下 `pages/` **递归**扫描，按名字与值双重判据收目标。
 *
 * ## 判据（宁可窄一点，也零误报）
 *
 * 一条常量被当作导航目标，必须**同时**满足：
 * 1. 名字按 `_` 切分后含 `ROUTE` / `TARGET` / `PAGE` / `SCREEN` / `DEST` / `NAV` 整段
 *    （整段匹配是为了不把 `UNAVAILABLE` 里的 `NAV`、`HOME_NAVIGATION` 里的 `NAV` 当信号）；
 * 2. 值形如导航 id：以 `/` 开头的路由串，或不含点号的 camelCase / kebab 串
 *    （`bingWallpaperGallery`、`app-logs`）。
 *
 * 值带点号的是**页内动作 id**（`appearanceEditor.wallpaper`、`gallery.retry`、
 * `backdrop.image.pick`），由页面自己的 dispatcher 处理，不进壳路由表；`RESET_SCOPE_*`
 * 是重置作用域、同样不是路由——这两类都显式排除，否则守卫会被大量合法常量打成噪音。
 * `actionTarget = "..."` 字面量也只收以 `/` 开头的：无前导 `/` 的字面量（`reset`、
 * `gallery.retry`）都是页内动作；跨页目标走常量，由上一条覆盖。
 *
 * ## 它读文件，所以守两条纪律
 *
 * 1. 路径从工作目录向上找 `android/app/src`，不写死盘符（CI 也能跑）；
 * 2. 找不到文件**失败而不是跳过**——跳过等于这条守卫不存在。
 */
class SettingsRouteWiringGuardTest {

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
            "Cannot locate android/app/src; the guard cannot verify anything. " +
                "Current working directory: ${System.getProperty("user.dir")}",
        )
    }

    /**
     * 页面源码：`main` 与 `composeP1` 两个源集下的 `pages/` 目录，**递归**收集 `.kt`。
     *
     * 壳的源集正在合并（`composeUi` → `main`），页面本体也分散在两个源集里；
     * 只扫单层或只扫一个源集就会留下「常量在，壳不认」的盲区。缺任一源集都判失败。
     */
    private fun pageSourceFiles(): List<File> {
        val roots = listOf("main", "composeP1").map { sourceSet ->
            File(androidSrc(), "$sourceSet/kotlin/com/mutx163/qingyu/pages")
        }
        val absent = roots.filterNot { it.isDirectory }
        assertTrue(
            "Page source roots are missing, refusing to scan a partial tree:\n" +
                absent.joinToString("\n") { "  ${it.path}" },
            absent.isEmpty(),
        )
        return roots.flatMap { root ->
            root.walkTopDown()
                .filter { it.isFile && it.extension == "kt" }
                .toList()
        }.sortedBy { it.path }
    }

    /**
     * 壳路由表的源码文本。
     *
     * 2026-10-29 起壳的源集正在合并：`composeUi/kotlin/.../pages/` 的文件被搬进
     * `main/kotlin/.../pages/`（同一份 `ShellWiring.kt` 两种布局下都可能存在）。
     * 所以这里按候选顺序找，**找到就用、都不在仍判失败**——守卫不许因为「路径变了」静默跳过。
     */
    private fun shellWiringSource(): String {
        val candidates = listOf(
            "main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
            "composeP1/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
            "composeUi/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
        )
        val file = candidates.map { File(androidSrc(), it) }.firstOrNull { it.isFile }
        assertTrue(
            "Shell route table is missing; tried:\n" +
                candidates.joinToString("\n") { "  android/app/src/$it" },
            file != null,
        )
        return file!!.readText()
    }

    /**
     * `shellPageIdForRoute` 的**函数体**（不含签名，也不含后面的兄弟函数）。
     *
     * 旧实现用 `substringAfter("fun shellPageIdForRoute")` 一直取到文件末尾，
     * 等于「范围没限定」：后面任何函数里出现 `"xxx" ->` 都会被误当成路由落点。
     * 这里从函数体的第一个 `{` 起做**大括号配对**，跳过行注释 / 块注释 / 字符串，
     * 配对归零即截断。
     */
    private fun shellRouteBody(source: String): String {
        val anchor = "fun shellPageIdForRoute"
        val start = source.indexOf(anchor)
        assertTrue("Cannot find shellPageIdForRoute in ShellWiring.kt", start >= 0)
        val open = source.indexOf('{', start)
        assertTrue("shellPageIdForRoute has no brace-delimited body", open >= 0)

        var depth = 0
        var i = open
        var inLineComment = false
        var inBlockComment = false
        var inString = false
        var escaped = false
        while (i < source.length) {
            val c = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else '\u0000'
            when {
                inLineComment -> if (c == '\n') inLineComment = false
                inBlockComment -> if (c == '*' && next == '/') {
                    inBlockComment = false
                    i++
                }
                inString -> when {
                    escaped -> escaped = false
                    c == '\\' -> escaped = true
                    c == '"' -> inString = false
                }
                c == '/' && next == '/' -> {
                    inLineComment = true
                    i++
                }
                c == '/' && next == '*' -> {
                    inBlockComment = true
                    i++
                }
                c == '"' -> inString = true
                c == '{' -> depth++
                c == '}' -> {
                    depth--
                    if (depth == 0) return source.substring(open + 1, i)
                }
            }
            i++
        }
        throw AssertionError("shellPageIdForRoute body never closes; brace matching broke")
    }

    /**
     * 去掉 `//` 行注释与 `/* */` 块注释，**字符串内容与换行原样保留**（行号仍可读）。
     *
     * 为什么必须多做这一步（2026-10-31 咬合探针实测的红灯漏洞）：
     * 守卫原先直接在原文里找 `"xxx" ->`，于是**把路由行整行注释掉**仍然算「已落点」——
     * 探针 `// "bingWallpaperGallery" -> "b.bingGallery"` 跑出来是 `OK (752 tests)`，
     * 只有把那一行**删掉**才会红。可运行时注释掉的行同样不存在，那一行照样点了没反应。
     *
     * 不用正则替换 `/\/\/.*$/` 图省事：字符串里的 `"https://a//b"` 会被误当注释切掉。
     */
    private fun stripComments(source: String): String {
        val out = StringBuilder(source.length)
        var i = 0
        var inString = false
        var escaped = false
        while (i < source.length) {
            val c = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else '\u0000'
            when {
                inString -> {
                    out.append(c)
                    when {
                        escaped -> escaped = false
                        c == '\\' -> escaped = true
                        c == '"' -> inString = false
                    }
                    i++
                }
                c == '"' -> {
                    inString = true
                    out.append(c)
                    i++
                }
                c == '/' && next == '/' -> {
                    while (i < source.length && source[i] != '\n') {
                        out.append(' ')
                        i++
                    }
                }
                c == '/' && next == '*' -> {
                    out.append("  ")
                    i += 2
                    while (i < source.length) {
                        if (source[i] == '*' && i + 1 < source.length && source[i + 1] == '/') {
                            out.append("  ")
                            i += 2
                            break
                        }
                        out.append(if (source[i] == '\n') '\n' else ' ')
                        i++
                    }
                }
                else -> {
                    out.append(c)
                    i++
                }
            }
        }
        return out.toString()
    }

    private data class NavTarget(val value: String, val origin: String)

    /** 整段匹配的名字信号；用 `_` 切分后比较，避免子串误伤（`UNAVAILABLE` / `NAVIGATION`）。 */
    private val routeNameTokens = setOf("ROUTE", "TARGET", "PAGE", "SCREEN", "DEST", "NAV")

    /**
     * `RESET_SCOPE_*` 是重置作用域（`timetablePage` / `homeWidget` …），由 SettingsHost
     * 的确认框消费，不是路由。`RESET_SCOPE_TIMETABLE_PAGE` 的 `PAGE` 段会命中名字规则，
     * 所以按前缀显式排除。
     */
    private val nonRouteNamePrefixes = listOf("RESET_SCOPE_")

    /** camelCase / kebab 的页面 id 形态；点号、冒号、下划线、空白、中文一律不算。 */
    private val targetIdShape = Regex("[a-z][A-Za-z0-9]*(-[a-z0-9]+)*")

    private fun nameLooksLikeRoute(name: String): Boolean {
        if (nonRouteNamePrefixes.any { name.startsWith(it) }) return false
        return name.split('_').any { it in routeNameTokens }
    }

    private fun valueLooksLikeTarget(value: String): Boolean =
        value.startsWith("/") || targetIdShape.matches(value)

    /**
     * 页面里声明的所有导航目标：
     * - `const val <任意名字> = "<字面量>"` 中名字与值都像路由的常量；
     * - 以 `/` 开头的 `actionTarget = "..."` 字面量。
     *
     * 返回带出处（相对路径:行号 + 常量名）的目标，失败信息里能直接定位。
     */
    private fun referencedTargets(): List<NavTarget> {
        val constDecl = Regex("const val ([A-Za-z_][A-Za-z0-9_]*) = \"([^\"]*)\"")
        val actionLiteral = Regex("actionTarget\\s*=\\s*\"(/[^\"]*)\"")
        val targets = mutableListOf<NavTarget>()
        for (file in pageSourceFiles()) {
            val text = file.readText()
            val origin = file.relativeTo(androidSrc()).path.replace('\\', '/')
            constDecl.findAll(text).forEach { match ->
                val name = match.groupValues[1]
                val value = match.groupValues[2]
                if (nameLooksLikeRoute(name) && valueLooksLikeTarget(value)) {
                    targets += NavTarget(value, "$origin:${lineNumber(text, match.range.first)} ($name)")
                }
            }
            actionLiteral.findAll(text).forEach { match ->
                targets += NavTarget(
                    match.groupValues[1],
                    "$origin:${lineNumber(text, match.range.first)} (actionTarget literal)",
                )
            }
        }
        return targets
    }

    private fun lineNumber(text: String, index: Int): Int =
        1 + text.take(index).count { it == '\n' }

    /**
     * 扫描器自检：判据收窄后必须仍然看得到三个已知形态，否则守卫会在「什么都没收」时假绿。
     * 三个样本分别覆盖 `/` 路由、无前导 `/` 的 camelCase 目标（2026-10-31 漏过的那类）、
     * 以及 kebab 形态（`app-logs`）。
     */
    @Test
    fun scannerCollectsKnownNavigationTargetShapes() {
        val values = referencedTargets().map { it.value }.toSet()
        assertTrue(
            "Scanner missed a slash route ('/settings/live'); the collection rule is too narrow.",
            "/settings/live" in values,
        )
        assertTrue(
            "Scanner missed 'bingWallpaperGallery' (the 2026-10-31 false negative); " +
                "constants named *_TARGET with no leading slash must be collected.",
            "bingWallpaperGallery" in values,
        )
        assertTrue(
            "Scanner missed 'app-logs'; kebab-case page ids must be collected.",
            "app-logs" in values,
        )
    }

    /** 截断自检：函数体必须停在 `shellPageIdForRoute` 的右括号，不能漏进后面的兄弟函数。 */
    @Test
    fun shellRouteBodyStopsAtEndOfFunction() {
        val body = shellRouteBody(shellWiringSource())
        assertTrue(
            "shellPageIdForRoute body has no route mapping; extraction is broken.",
            "\"/settings/live\" ->" in body,
        )
        assertTrue(
            "Body extraction overran the function: a sibling top-level 'fun ' leaked into it.",
            !Regex("^fun ", RegexOption.MULTILINE).containsMatchIn(body),
        )
    }

    /**
     * 注释掉的路由**不算落点**（2026-10-31 咬合探针实测的漏洞，详见 [stripComments]）。
     *
     * 这条不读真实源码，直接喂人造文本：真实文件里一旦有人注释掉一行，本类第一条测试
     * 就会红，这里守的是「判据本身不能把注释算进去」。
     */
    @Test
    fun commentedOutRouteDoesNotSatisfyTheMappingCheck() {
        val body = stripComments(
            """
            // "fakeLineRoute" -> "x"
            /* "fakeBlockRoute" -> "y" */
            "realBranch" -> "z"
            val url = "https://example.com//a"
            """.trimIndent(),
        )
        fun mapped(target: String): Boolean =
            Regex("\"${Regex.escape(target)}\"\\s*->").containsMatchIn(body)

        assertTrue("A real when-branch must survive comment stripping.", mapped("realBranch"))
        assertTrue(
            "A line-commented route must NOT count as wired; it does not exist at runtime.",
            !mapped("fakeLineRoute"),
        )
        assertTrue(
            "A block-commented route must NOT count as wired.",
            !mapped("fakeBlockRoute"),
        )
        assertTrue(
            "Comment stripping must not eat string contents ('//' inside a literal).",
            "https://example.com//a" in body,
        )
    }

    @Test
    fun everyReferencedNavigationTargetIsMappedByShell() {
        // 必须先去注释：注释掉的行在运行时同样不存在，算「已落点」就是假绿。
        val body = stripComments(shellRouteBody(shellWiringSource()))
        val targets = referencedTargets()
        assertTrue(
            "Guard collected zero navigation targets. The scanner is broken, not the code.",
            targets.isNotEmpty(),
        )

        val missing = targets
            .distinctBy { it.value }
            .filter { target ->
                !Regex("\"${Regex.escape(target.value)}\"\\s*->").containsMatchIn(body)
            }

        assertTrue(
            buildString {
                appendLine(
                    "These navigation targets have no shellPageIdForRoute entry; " +
                        "the row will do nothing when tapped:",
                )
                missing.forEach { appendLine("  ${it.value}  <-  ${it.origin}") }
                appendLine()
                appendLine(
                    "Fix: add `<target> -> \"<page id>\"` inside shellPageIdForRoute in ShellWiring.kt. " +
                        "Keep the string exactly as declared (no leading slash is added for page-id targets).",
                )
            },
            missing.isEmpty(),
        )
    }
}
