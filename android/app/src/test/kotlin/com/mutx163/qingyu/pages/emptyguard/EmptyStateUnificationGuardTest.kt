package com.mutx163.qingyu.pages.emptyguard

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 空态统一（C 区 34 项）守卫 —— 防回退。
 *
 * 规格：`.agents/notes/proposed/2026-11-10-empty-state-unification.md` §5A.2（4 条断言）与 §7.3（T3 特例登记）。
 * 套件：`composeP1/.../components/QingyuEmptyState.kt`（本轮由美化二落地，别人只调不改）。
 *
 * ## 它防的是哪一类事故
 *
 * 改造前全仓 33 处空态各写各的图标与文案：图标 40/48/56 三种直径、标题 16 Medium / 17 Normal /
 * body1 三种字阶、外边距 24/32/48 混着来，还有 6 处把「没有数据」画成了一张空卡片。
 * 这类偏差**编译得过、单测全绿**，只有把每一页切到空数据、真机逐页看才发现——所以只能靠源码守卫钉住。
 *
 * ## 为什么只扫「已收编的 14 个 T1 调用点」，不扫全仓
 *
 * 本轮 34 项里只有 14 项（C01-C05、C07-C09、C15-C18、C20、C37）是页面级空态，必须套 `QingyuEmptyState`；
 * 另外 11 项是 T3 特例（卡内一行提示、错误态说明卡、沉浸取景页文字），形态**刻意不同**，
 * 硬扫全仓只会把这些特例判成违规、天天假红。T3 的判据是「登记过、理由在、文件还在」，
 * 不拦新增页面自写空态——本轮不做全量棘轮，等 34 项全部收口再议。
 *
 * ## 为什么放在 `pages/emptyguard` 这个只有测试的目录
 *
 * 与 `pages/loading/QingyuLoadingUsageGuardTest.kt` 同一处境：`scripts/test-kotlin-module.ps1`
 * 按 `pages/<域>` 找源码与测试目录，本守卫是全仓扫描器、不属于任何页面域，所以单独开一个
 * **只有测试目录**的域，`-Module pages/emptyguard` 就能跑，不必等整包 L2。
 * 方案 §5A.2 原定路径是 `test/.../components/EmptyStateUnificationGuardTest.kt`，
 * 但 `components` 在 L0 里没有对应域目录（跑不到），故照 loading 守卫的先例挪到这里；
 * 判据与类名不变，只是搬了目录。
 *
 * ## 中文文案与 i18n 棘轮
 *
 * 本文件里的中文全部是**断言信息与注释**，不上屏：`CjkLiteralGateTest.kt:69-86` 的扫描根只有
 * `android/app/src/main/kotlin` 与 `android/app/src/composeP1/kotlin`，测试源码天然不在棘轮范围内，
 * 因此不登记 `cjk-literal-baseline*.txt`（给测试登记反而会因「实际计数为 0 < 基线」而把门禁判红）。
 * 断言 4 守的是**组件源码**零中文字面量：空态的文案必须由调用方传 ARB 句柄。
 *
 * ## 咬合探针（2026-11-10 已做，红→还原→绿，原文见空态批次回报）
 *
 * 1. 把 `EmptyStateSpec.IconSize` 的 48.dp 改成 40.dp ⇒ 断言 1 红；还原后绿。
 * 2. 把 `TaskListPage.kt` 的 `QingyuEmptyState(` 调用注释掉 ⇒ 断言 2 红；还原后绿。
 * 3. **断言 4 收窄**（同日，预览豁免）：组件里补三档 `@Preview`（中文预览名 + 中文假数据）⇒ 仍绿，
 *    证明豁免生效；再往**预览区之外**塞一句中文字面量 ⇒ 红，证明是收窄不是放水；两处均还原。
 */
class EmptyStateUnificationGuardTest {

    @Test
    fun `扫描器必须真的扫到源码`() {
        val files = sourceFiles()
        assertTrue(
            "只扫到 ${files.size} 个 .kt（预期 >= $MIN_EXPECTED_FILES）—— 仓库根判定或目录名已变，" +
                "判据会空跑假绿。user.dir=${System.getProperty("user.dir")}",
            files.size >= MIN_EXPECTED_FILES,
        )
        assertTrue(
            "找不到空态套件 $COMPONENT_PATH —— 文件改名/移动后必须同步更新本守卫",
            files.any { it.relativePath == COMPONENT_PATH },
        )
        assertTrue(
            "找不到判墨规格件 $INK_SPEC_PATH —— 判墨拆件后路径变了，断言 3 会空跑",
            files.any { it.relativePath == INK_SPEC_PATH },
        )
        // 断言 2 依赖「T1 调用点真的 import 了套件」；import 数不足说明调用点被批量回退。
        val importers = files.count { importsComponent(it.file.readText()) }
        assertTrue(
            "只有 $importers 个文件 import 了空态套件（预期 >= $MIN_EXPECTED_IMPORTERS）——" +
                "套件被架空或批量回退，断言 2 只能测到空跑。",
            importers >= MIN_EXPECTED_IMPORTERS,
        )
    }

    /**
     * 断言 1：套件的六个几何常量一个都不许改。
     *
     * 几何来自发布版 `hyperos_empty_state.dart:27-49`（外边距 32/48、图标 48、图标→标题 16、
     * 标题→说明 8、说明→动作 20）。这六个数就是「空态统一」本身——改一个，全仓空态一起偏，
     * 所以钉成精确值 + 名字，并要求 `EmptyStateSpec` 里不夹带第七个 `.dp` 字面量。
     */
    @Test
    fun `断言 1 几何常量不许改`() {
        val code = stripComments(File(repoRoot(), COMPONENT_PATH).readText())
        val body = objectBody(code, "object EmptyStateSpec")
            ?: throw AssertionError("在 $COMPONENT_PATH 里找不到 `object EmptyStateSpec` —— 套件结构变了，请同步本守卫")

        val actual = LinkedHashMap<String, Int>()
        Regex("""val\s+(\w+)\s*:\s*Dp\s*=\s*(\d+)\.dp""").findAll(body).forEach { match ->
            actual[match.groupValues[1]] = match.groupValues[2].toInt()
        }
        assertEquals(
            "EmptyStateSpec 的几何常量被改动了（依据：发布版 hyperos_empty_state.dart:27-49；改一个全仓空态一起偏）：\n" +
                "实际 $actual\n预期 $EXPECTED_GEOMETRY",
            EXPECTED_GEOMETRY,
            actual,
        )
        assertEquals(
            "EmptyStateSpec 里应当只有 ${EXPECTED_GEOMETRY.size} 个 `.dp` 字面量（多出来的是没登记的第七个刻度）：\n" +
                Regex("""\d+\.dp""").findAll(body).joinToString("\n") { "    ${it.value}" },
            EXPECTED_GEOMETRY.size,
            Regex("""\d+\.dp""").findAll(body).count(),
        )
    }

    /**
     * 断言 2：14 个 T1 调用点必须走共享组件。
     *
     * 逐路径断言源码里 `QingyuEmptyState(` 的出现次数 —— 不等号写成 `>=` 是因为**同一页允许加第二处**
     * （日志页空列表/筛选无匹配两处、云备份失败态/纯空态两支就是活例）；少一处就是回退。
     * 同时钉「已被收编的自写空态件不许复活」：那五个私有 `fun` 是手搓几何的入口，回来就等于绕开套件。
     */
    @Test
    fun `断言 2 14 个 T1 调用点必须走组件`() {
        val problems = mutableListOf<String>()
        var counted = 0
        for (site in T1_CALL_SITES) {
            val file = File(repoRoot(), site.path)
            if (!file.isFile) {
                problems += "${site.item} 找不到文件 ${site.path}（改路径必须同步本守卫）"
                continue
            }
            val text = stripComments(file.readText())
            val calls = Regex("""QingyuEmptyState\s*\(""").findAll(text).count()
            counted += calls
            if (calls < site.minCalls) {
                problems += "${site.item} ${site.path}：只有 $calls 处 `QingyuEmptyState(`，要求 >= ${site.minCalls}" +
                    "（回退成自写空态/内联 Column？改法见方案 §5A.1）"
            }
        }
        assertTrue(
            buildString {
                appendLine("14 个 T1 页面级空态必须调共享组件 `QingyuEmptyState`（方案 §5A.1）：")
                problems.forEach { appendLine("  - $it") }
            },
            problems.isEmpty(),
        )
        assertTrue(
            "T1 调用点合计只数到 $counted 处 `QingyuEmptyState(`（要求 >= $EXPECTED_T1_CALLS）——" +
                "组件的调用面被批量改小，本断言已近空跑。",
            counted >= EXPECTED_T1_CALLS,
        )

        // 已被收编的自写空态件不许复活（名字只在注释/文档里出现是允许的）。
        val revived = sourceFiles().filter { source ->
            REVIVED_PRIVATE_FUNS.any { needle -> stripComments(source.file.readText()).contains(needle) }
        }.map { it.relativePath }
        assertTrue(
            buildString {
                appendLine("这些手搓空态件已经随 14 个 T1 调用点收编删除，不许重新写回来：")
                appendLine("  应删形态：${REVIVED_PRIVATE_FUNS.joinToString(" / ")}")
                appendLine("  复活位置：")
                revived.forEach { appendLine("    $it") }
            },
            revived.isEmpty(),
        )
    }

    /**
     * 断言 3：判墨只有一条实现。
     *
     * 「压在壁纸上的空态要翻白/翻近黑」这套判据只能活一个地方：`pages/shell/EmptyStateInkSpec.kt`
     * （纯函数 + 6 例 JVM 单测 `EmptyStateInkSpecTest.kt`）。组件侧不许再抄一份调用——
     * 一旦有两处判墨实现，壁纸换了之后两页墨色会不一致，而且谁都不知道该信哪份。
     */
    @Test
    fun `断言 3 判墨单一来源`() {
        val component = stripComments(File(repoRoot(), COMPONENT_PATH).readText())
        val leaked = INK_FUNCTIONS.filter { component.contains("$it(") }
        assertTrue(
            "组件源码里出现了判墨函数调用 ${leaked.joinToString(" / ")} —— 判墨只许在 " +
                "$INK_SPEC_PATH 里实现，组件只做 `Color(...)` 包装（否则壁纸换了两处墨色会打架）。",
            leaked.isEmpty(),
        )

        val spec = stripComments(File(repoRoot(), INK_SPEC_PATH).readText())
        val wrong = INK_FUNCTIONS.map { name -> name to Regex("""\b${Regex.escape(name)}\s*\(""").findAll(spec).count() }
            .filter { (_, count) -> count != 1 }
        assertTrue(
            buildString {
                appendLine("判墨规格件的调用次数不对（每个必须恰好 1 次：一处是声明点之后的真实调用，不许零处也不许抄两份）：")
                wrong.forEach { (name, count) -> appendLine("    $name → $count 次") }
            },
            wrong.isEmpty(),
        )
    }

    /**
     * 断言 4：组件不带文案、不带裸色。
     *
     * 文案一律由调用方传 ARB 句柄（`*Strings.xxx.text`），组件源码零中文字面量——否则六语就断在组件里；
     * 裸 `Color(0x…)` 同样不许出现，墨色只能来自判墨规格件或主题槽位。
     *
     * **豁免范围（2026-11-10 收窄，Chief 三条卡死口径）**：只放行 `@Preview(...)` 的参数与被它标注的
     * 函数体——那两段是 **IDE 里的预览标签与假数据**，永远不上屏，与「屏上文案走 ARB」不冲突；
     * 除此之外的代码仍要求零中文字面量。豁免外的中文字面量照旧判红（探针见文件头）。
     */
    @Test
    fun `断言 4 组件不带文案与裸色`() {
        val code = stripComments(File(repoRoot(), COMPONENT_PATH).readText())
        val onScreenCode = blankPreviewSpans(code)
        val cjkLiterals = STRING_LITERAL.findAll(onScreenCode)
            .map { it.groupValues[1] }
            .filter { literal -> literal.any { it in '一'..'鿿' } }
            .toList()
        assertTrue(
            "组件源码里出现了中文字面量 ${cjkLiterals.joinToString(" / ") { "『$it』" }} ——" +
                "空态文案必须由调用方传 ARB 句柄，组件自己不持有任何一句话" +
                "（只有 `@Preview(...)` 参数与预览函数体内的假数据豁免）。",
            cjkLiterals.isEmpty(),
        )

        val rawColors = Regex("""\b0x[0-9A-Fa-f]{6,8}\b""").findAll(code).map { it.value }.toList()
        assertTrue(
            "组件源码里出现了裸色 ${rawColors.joinToString(" / ")} —— 墨色只许来自判墨规格件" +
                "（`EmptyStateInkSpec.kt`）或主题槽位，不许在 UI 层写死 ARGB。",
            rawColors.isEmpty(),
        )
    }

    /**
     * T3 特例登记（方案 §7.3）：11 项**刻意不套**页面级空态，理由写在这里，谁想统一先读理由。
     *
     * 只断言「登记的文件还在」——不拦它们自写提示，也不拦新页面自写空态（本轮不做全量棘轮）。
     * 文件被改名/删除时这条会红，逼着回来把理由一起搬走，避免白名单悄悄烂成过期清单。
     */
    @Test
    fun `T3 特例白名单登记`() {
        val missing = T3_EXCEPTIONS.filter { File(repoRoot(), it.path).isFile.not() }
        assertTrue(
            buildString {
                appendLine("T3 特例登记里有文件不存在了（改名/删除后请把理由一起搬走，别留着过期白名单）：")
                missing.forEach { appendLine("  - ${it.item} ${it.path} —— ${it.reason}") }
            },
            missing.isEmpty(),
        )
    }

    // ------------------------------------------------------------------
    // 判据实现
    // ------------------------------------------------------------------

    private data class SourceFile(val relativePath: String, val file: File)

    private data class CallSite(val item: String, val path: String, val minCalls: Int)

    private data class Exception3(val item: String, val path: String, val reason: String)

    /** 仓库根：从 user.dir 往上找含 `android/app/src` 的目录（与既有守卫同一套写法）。 */
    private fun repoRoot(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "android/app/src").isDirectory) return dir
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（android/app/src）—— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "user.dir=${System.getProperty("user.dir")}",
        )
    }

    private fun sourceFiles(): List<SourceFile> {
        val root = repoRoot()
        val bases = listOf(
            "android/app/src/main/kotlin",
            "android/app/src/composeP1/kotlin",
        )
        return bases.flatMap { base ->
            val dir = File(root, base)
            if (!dir.isDirectory) {
                emptyList()
            } else {
                dir.walkTopDown()
                    .filter { it.isFile && it.extension == "kt" }
                    .map { SourceFile(it.relativeTo(root).invariantSeparatorsPath, it) }
                    .toList()
            }
        }
    }

    private fun importsComponent(text: String): Boolean = text.contains(COMPONENT_IMPORT)

    /** 取 `object X { … }` 的对象体（花括号配对；调用方已把注释与字符串抹空）。 */
    private fun objectBody(code: String, header: String): String? {
        val start = code.indexOf(header)
        if (start < 0) return null
        val open = code.indexOf('{', start)
        if (open < 0) return null
        var depth = 0
        var i = open
        while (i < code.length) {
            when (code[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return code.substring(open + 1, i)
                }
            }
            i++
        }
        return null
    }

    /**
     * 把注释抹成空格（换行保留），**字符串内容保留**——
     * 断言 4 要数中文字面量，所以这里不像加载态守卫那样连字符串一起抹。
     */
    private fun stripComments(text: String): String {
        val out = StringBuilder(text.length)
        var i = 0
        fun blank(from: Int, count: Int) {
            repeat(count) { offset ->
                out.append(if (text[from + offset] == '\n') '\n' else ' ')
            }
        }
        while (i < text.length) {
            when {
                text.startsWith("//", i) -> {
                    val end = text.indexOf('\n', i).let { if (it < 0) text.length else it }
                    blank(i, end - i)
                    i = end
                }
                text.startsWith("/*", i) -> {
                    val end = text.indexOf("*/", i + 2).let { if (it < 0) text.length else it + 2 }
                    blank(i, end - i)
                    i = end
                }
                else -> {
                    out.append(text[i])
                    i++
                }
            }
        }
        return out.toString()
    }

    /**
     * 断言 4 的豁免面：只把 `@Preview(...)` 的参数、以及被它标注的那个函数体抹成空格（换行保留）。
     *
     * 定位方式：注解之后第一个 `fun` 即预览函数，再按花括号配对取函数体（与 [objectBody] 同一套配对写法，
     * 但保持两处独立，不动别的判据）。本文件的预览函数无参数、体内有 lambda 花括号，配对仍成立。
     *
     * 除这两段以外的源码原样返回——豁免**不外溢**：预览之外任何中文字面量照旧被抓（探针 2）。
     */
    private fun blankPreviewSpans(code: String): String {
        val chars = code.toCharArray()
        fun blank(from: Int, toExclusive: Int) {
            for (i in from until toExclusive.coerceAtMost(chars.size)) {
                if (chars[i] != '\n') chars[i] = ' '
            }
        }
        var from = 0
        while (true) {
            val at = code.indexOf("@Preview", from)
            if (at < 0) break
            val open = code.indexOf('(', at)
            val close = if (open >= 0) matchingDelimiter(code, open, '(', ')') else -1
            if (close > 0) blank(at, close + 1)
            val funAt = code.indexOf("fun ", if (close > 0) close else at)
            if (funAt >= 0) {
                val bodyOpen = code.indexOf('{', funAt)
                val bodyClose = if (bodyOpen >= 0) matchingDelimiter(code, bodyOpen, '{', '}') else -1
                if (bodyClose > 0) blank(bodyOpen, bodyClose + 1)
            }
            from = if (close > 0) close + 1 else at + 1
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

    private companion object {
        const val COMPONENT_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuEmptyState.kt"

        const val INK_SPEC_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/shell/EmptyStateInkSpec.kt"

        const val COMPONENT_IMPORT = "import com.mutx163.qingyu.components.QingyuEmptyState"

        /** 空跑哨兵：2026-11-10 实测 830+ 个 .kt，留足余量。 */
        const val MIN_EXPECTED_FILES = 700

        /** 2026-11-10 实测 13 个文件 import 了空态套件，留余量。 */
        const val MIN_EXPECTED_IMPORTERS = 10

        /** 14 个 T1 项实际落到 15 处调用（日志页 2 处、云备份 2 支）。 */
        const val EXPECTED_T1_CALLS = 15

        /** 判墨函数：只许在 `EmptyStateInkSpec.kt` 里各出现 1 次。 */
        val INK_FUNCTIONS = listOf("inkOverWallpaperArgb", "mutedInkOverWallpaperArgb")

        /** 六个几何常量（发布版 `hyperos_empty_state.dart:27-49`）。 */
        val EXPECTED_GEOMETRY = linkedMapOf(
            "IconSize" to 48,
            "IconTitleGap" to 16,
            "TitleDescriptionGap" to 8,
            "DescriptionActionGap" to 20,
            "ContentPaddingHorizontal" to 32,
            "ContentPaddingVertical" to 48,
        )

        /** 手搓空态的五个入口，收编后不许复活。 */
        val REVIVED_PRIVATE_FUNS = listOf(
            "fun TaskEmptyState(",
            "fun ExamEmptyState(",
            "fun CourseOverviewEmptyState(",
            "fun StatisticsEmptyState(",
            "fun DiagnosticsCenteredState(",
        )

        /** 14 个 T1 调用点（方案 §5A.1；行号在报告里，守卫只钉路径与次数）。 */
        val T1_CALL_SITES = listOf(
            CallSite("C01 待办列表", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/TaskListPage.kt", 1),
            CallSite("C02 考试列表", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/ExamListPage.kt", 1),
            CallSite("C03 日程列表", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleListPage.kt", 1),
            CallSite("C04 日期规则", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleDateRulePage.kt", 1),
            CallSite("C05 课程总览", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/CourseOverviewPage.kt", 1),
            CallSite("C07 统计分析", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsAnalysisPage.kt", 1),
            CallSite("C08 统计会话", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsSessionPage.kt", 1),
            CallSite("C09 课程统计", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/CourseStatisticsPage.kt", 1),
            CallSite("C15+C16 日志空/无匹配", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveDiagnosticsLogPage.kt", 2),
            CallSite("C17 云备份", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudBackupListPage.kt", 2),
            CallSite("C18 教务课程导入", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCourseImportPage.kt", 1),
            CallSite("C20 教务调试记录", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCustomDebugPage.kt", 1),
            CallSite("C37 展示册", "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/showcase/MiuixShowcasePage.kt", 1),
        )

        /** T3 特例（方案 §4.1 定稿 11 项；C21/C22 同文件，按项登记保留两条理由）。 */
        val T3_EXCEPTIONS = listOf(
            Exception3(
                "C06 冲突页",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/conflict/CourseConflictPage.kt",
                "发布版就是 Center(Text(...)) 一行正文，无图标无动作；套页面级空态会改变观感",
            ),
            Exception3(
                "C10 图表卡",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/charts/BasicChartCards.kt",
                "图表卡内一行灰字，尺寸随图表内核缩放；只保证灰阶同源",
            ),
            Exception3(
                "C19 学校适配器",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseSchoolAdaptersPage.kt",
                "这一屏「空」＝读不到（失败）+ 重试，是错误态不是空态",
            ),
            Exception3(
                "C21 教务网页登录说明卡",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt",
                "配置缺失的说明卡，不是「没数据」；卡片本身承载返回上下文",
            ),
            Exception3(
                "C22 教务登录「没带目标进来」",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt",
                "同上：错误说明 + 返回，不是空数据",
            ),
            Exception3(
                "C23 日视图空态",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewEmptyState.kt",
                "发布版本页就无图标、17 Medium；11-09 用户实报后刚修好判墨，形态别动（判墨走共享规格件）",
            ),
            Exception3(
                "C24 月视图概览卡",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthPanelOverview.kt",
                "卡内几何被发布版 MonthOverviewMetrics:143-150 钉住，不是页面级留白",
            ),
            Exception3(
                "C25 月视图日程卡",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthDayAgenda.kt",
                "卡内容不是空态页；加课胶囊入口是这块的主角",
            ),
            Exception3(
                "C26 作息管理空行",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeManagementPage.kt",
                "发布版是禁用导航行（HyperosNavTile(enabled:false)），换空态会改信息层级",
            ),
            Exception3(
                "C27 地点时间匹配",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/LocationTimeMatchPage.kt",
                "空态本身就是入口（发布版 ActionTile），再加图标空态是重复",
            ),
            Exception3(
                "C29 壁纸取景页",
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/WallpaperPositionPickerPage.kt",
                "沉浸取景页压照片；发布版这里是 broken_image 图标，本版刻意改文字区分「没选」与「文件没了」",
            ),
        )

        /** Kotlin 字符串字面量（不跨行）；断言 4 用它挑中文字面量。 */
        val STRING_LITERAL = Regex("\"((?:[^\"\\\\\n]|\\\\.)*)\"")
    }
}

