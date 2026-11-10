package com.mutx163.qingyu.pages.about

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「折叠行为必须有顶栏可折」守卫（2026-11-10）。
 *
 * ## 它防的是哪一类事故
 *
 * 用户真机报「版本更新页：展开更新说明后整页无法下滑」。根因不是布局，而是这一页
 * 2026-11-08 起改成了**自绘两颗胶囊、不再画 `TopAppBar`**，却仍给列表挂着
 * `rememberQingyuScrollBehavior()`（miuix `MiuixScrollBehavior`）：
 *
 * - 该行为的折叠目标是 `TopAppBarState`，`heightOffsetLimit` 只由 `TopAppBar` 写入；
 *   没有顶栏时它停在 `rememberTopAppBarState` 的默认值 `-Float.MAX_VALUE`
 *   （miuix-ui 0.9.4 `TopAppBar.kt:279`、`:314-319`）；
 * - `onPreScroll` 里只要 `heightOffset` 变了就 `return available.copy(x = 0f)`
 *   （`TopAppBar.kt:483-495`）——limit 无限大 ⇒ 每一段向上滚动都被整段吃掉；
 * - 于是内容不满一屏时看不出问题，一展开更新说明、内容超过一屏，就表现为「滑不动」。
 *
 * ## 判据
 *
 * `android/app/src/composeP1` 下任何 Kotlin 源码（**先剥注释**）出现
 * `rememberQingyuScrollBehavior(` 时，同一文件必须同时出现顶栏任一写法：
 * `TopAppBar(` / `SmallTopAppBar(` / `QingyuPageScaffold(`（后者内部渲染官方面板）。
 *
 * 唯一豁免：`components/QingyuPageList.kt` —— 它就是那个行为的工厂出口（定义处），
 * 由调用方负责「有栏才用」。注释里提到组件名不触发判据（与 `RowDividerGuardTest` 同一纪律）。
 *
 * 放在 `pages/about` 下而不是 `pages/` 根：L0（`test-kotlin-module.ps1 -Module pages/about`）
 * 只收模块目录，这份守卫要能被 L0 跑到；判据本身扫全 `composeP1`。
 */
class FoldBehaviorNeedsTopBarGuardTest {

    private fun repoRoot(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "i18n/app_zh.arb").isFile && File(dir, "android/app/build.gradle").isFile) return dir
            dir = dir.parentFile
        }
        error("找不到仓库根（user.dir=${System.getProperty("user.dir")}）")
    }

    /** 剥掉 Kotlin 行注释与块注释（含 KDoc）；注释里讲历史/引用组件名不算违规。 */
    private fun stripKotlinComments(source: String): String {
        val withoutBlock = Regex("/\\*.*?\\*/", RegexOption.DOT_MATCHES_ALL).replace(source, "")
        return withoutBlock.lineSequence().map { it.substringBefore("//") }.joinToString("\n")
    }

    private val behaviorToken = "rememberQingyuScrollBehavior("
    private val topBarTokens = listOf("TopAppBar(", "SmallTopAppBar(", "QingyuPageScaffold(")

    /** 组件自身：行为工厂的定义处，不对它要求顶栏（调用方负责「有栏才用」）。 */
    private val exempt = setOf(
        "com/mutx163/qingyu/components/QingyuPageList.kt",
    )

    @Test
    fun `挂折叠行为的文件必须同文件有顶栏`() {
        // 扫的是 composeP1 的**源码根**（`kotlin/`），这样相对路径就是包路径，判据里写死路径不会随目录搬家漂移。
        val root = File(repoRoot(), "android/app/src/composeP1/kotlin")
        assertTrue("扫描根不存在：${root.absolutePath}", root.isDirectory)

        val files = root.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList()
        assertTrue("只扫到 ${files.size} 个 composeP1 源文件，判据疑似失效（空跑假绿）", files.size >= 200)

        val relative = { file: File ->
            file.invariantSeparatorsPath.substringAfter(root.invariantSeparatorsPath + "/")
        }
        val behaviorFiles = files.filter { behaviorToken in stripKotlinComments(it.readText()) }
        assertTrue(
            "一处 `$behaviorToken` 都没扫到——判据已失效（组件里的定义应当命中）",
            behaviorFiles.isNotEmpty(),
        )
        assertTrue(
            "组件里的 `fun rememberQingyuScrollBehavior(` 没被扫到，判据可能写坏了",
            behaviorFiles.any { relative(it) == "com/mutx163/qingyu/components/QingyuPageList.kt" },
        )

        val offenders = behaviorFiles
            .filter { relative(it) !in exempt }
            .filter { file ->
                val code = stripKotlinComments(file.readText())
                topBarTokens.none { it in code }
            }
            .map { relative(it) }

        assertTrue(
            "以下页面挂了「折叠顶栏」的滚动行为，却没有 TopAppBar / QingyuPageScaffold 可折。" +
                "miuix 的 ExitUntilCollapsedScrollBehavior 在 heightOffsetLimit 无人写入时" +
                "（默认 -Float.MAX_VALUE）会把每一段向上滚动整段吃掉 —— 表现就是「内容超过一屏后整页滑不动」" +
                "（2026-11-10 版本更新页事故）。没有栏可折就别建这个行为：列表不传 scrollBehavior。" +
                "违规位置：\n" + offenders.joinToString("\n") { "    $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `版本更新页不挂折叠行为（事故棘轮）`() {
        val page = File(
            repoRoot(),
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdatePage.kt",
        )
        assertTrue("版本更新页源码不见了：${page.path}", page.isFile)
        val code = stripKotlinComments(page.readText())
        assertFalse(
            "版本更新页又建了折叠行为：本页没有顶栏，这会让「展开更新说明后整页滑不动」复发" +
                "（2026-11-10 用户真机事故）。列表保持不传 scrollBehavior。",
            behaviorToken in code,
        )
        assertFalse(
            "版本更新页又把 scrollBehavior 传给列表了：没有顶栏可折，传了就会吞掉向上滚动。",
            Regex("""QingyuPageList\([\s\S]{0,400}?scrollBehavior\s*=""").containsMatchIn(code),
        )
    }
}
