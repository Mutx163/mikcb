package com.mutx163.qingyu.app

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `main/.../app/` 目录的**层间不变量守卫**（2026-10-28 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * `main/.../app/` 在 `scripts/test-kotlin-module.ps1` 的 `sharedModelDirs` 里，
 * **被每一次 L0 无条件收录**（不管你在跑哪个模块）。由此推出两条硬不变量：
 *
 * 1. **不许 import 任何 `com.mutx163.qingyu.pages.<域>`。**
 *    `pages/<域>` 只在 `-Module <那个域>` 时才被收进 L0 源集，所以一旦 `app/` 引用了它，
 *    **除那个域以外的所有模块的 L0 都会红**，而报错文件是 `app/` 里的那个——
 *    别人看到的是「我的模块编译不过」，根本查不到是谁弄的。
 *    **同一天发生过两次**：`pages.settings`（`SettingsPageBridge` 放错目录）、
 *    `pages.task`（`AddTaskFormReducer` 放错目录），第二次红了**约 2 小时 40 分钟**，
 *    代价由所有泳道一起付。
 * 2. **必须是纯 Kotlin**：不许 `android.*` / `androidx.compose.*` / `top.yukonga.miuix.*`。
 *    理由：L0 直接调 `kotlinc` + `JUnitCore` 跑真 JVM，没有 Android 框架类。
 *    脚本侧还有一道「整目录含 Android 导入就跳过」的兜底，但那是**静默跳过**
 *    （表现为「测试里 app 的符号全都 Unresolved」），比这里报错更难查。
 *    Android 胶水一律放 `platform/`。
 *
 * ## 为什么这两条以前只写在文档里、现在要变成测试
 *
 * 原来只写在派活文档里，措辞是「`app/` 不许 import `pages.settings.*`」——
 * 那是**当时那个例子**，不是不变量。下一个人只记住了例子，于是换成 `pages.task` 又踩一次。
 * **规则要写不变量，不要写当时那个例子**；而写在文档里的不变量仍会被漏读，
 * 所以这里把它变成「提交时就红」的机器约束。
 *
 * ## 为什么读文件文本
 *
 * 「有没有 import 某个包」在编译产物里被擦除了（import 不是运行期实体），
 * 反射拿不到；所以读源码文本。与 `ShellPageDispatchCoverageTest` 同一套做法。
 *
 * **代价**：文本匹配对写法敏感（例如完全限定名直接写在表达式里而不写 import 就抓不到）。
 * 这是**有意接受的边界**——它拦的是实践中出现的形态（写 import），不是理论上的所有形态。
 */
class AppLayerPurityTest {

    @Test
    fun `扫描器必须真的扫到 app 目录的源文件`() {
        // 没有这条，路径写错时下面两条会因为「零个文件」而永远绿 —— 守卫变成摆设。
        val files = appSources()
        assertTrue(
            "app/ 目录下只扫到 ${files.size} 个 .kt，明显不对；" +
                "路径若已移动，请同步本测试的 APP_DIR_RELATIVE 常量",
            files.size >= 5,
        )
    }

    @Test
    fun `app 目录不许 import 任何 pages 子包`() {
        val offenders = mutableListOf<String>()
        for (file in appSources()) {
            file.readLines().forEachIndexed { index, line ->
                if (PAGES_IMPORT.containsMatchIn(line)) {
                    offenders += "${relative(file)}:${index + 1}: ${line.trim()}"
                }
            }
        }
        assertTrue(
            buildString {
                appendLine("main/.../app/ 里出现了对 pages/ 子包的 import（${offenders.size} 处）：")
                offenders.forEach { appendLine("  - $it") }
                appendLine()
                appendLine("为什么不行：app/ 被**每一次 L0 无条件收录**，而 pages/<域> 只在")
                appendLine("-Module <那个域> 时才收 ⇒ 除那个域以外的所有模块的 L0 都会红，")
                appendLine("且报错文件是 app/ 里的这个，别人查不到源头。")
                appendLine()
                appendLine("怎么修：把该文件搬进它依赖的那个 pages/<域>/ 目录（L0 源集按目录收集，")
                appendLine("搬进去后只有那个模块会编它）。包名可以保持不变，避免打断别人的 import。")
            },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `app 目录必须是纯 Kotlin`() {
        val offenders = mutableListOf<String>()
        for (file in appSources()) {
            file.readLines().forEachIndexed { index, line ->
                if (ANDROID_IMPORT.containsMatchIn(line)) {
                    offenders += "${relative(file)}:${index + 1}: ${line.trim()}"
                }
            }
        }
        assertTrue(
            buildString {
                appendLine("main/.../app/ 里出现了 Android / Compose / miuix 导入（${offenders.size} 处）：")
                offenders.forEach { appendLine("  - $it") }
                appendLine()
                appendLine("为什么不行：L0 直接调 kotlinc + JUnitCore 跑真 JVM，没有 Android 框架类。")
                appendLine("脚本侧还有一道「整目录含 Android 导入就跳过」的兜底，但那是**静默跳过**，")
                appendLine("表现为「测试里 app 的符号全都 Unresolved」，比这里报错更难查。")
                appendLine()
                appendLine("怎么修：Android 胶水放 platform/，纯逻辑留 app/。")
            },
            offenders.isEmpty(),
        )
    }

    // ---------- 基础设施 ----------

    /**
     * 从工作目录向上找仓库根，再收集 `app/` 下所有 `.kt`。
     *
     * 与 `ShellPageDispatchCoverageTest.dispatchSource()` 同一套做法：
     * L0 脚本与 Gradle 的工作目录不同，所以按「向上找标志路径」而不是写死相对路径。
     */
    private fun appSources(): List<File> {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, APP_DIR_RELATIVE)
            if (candidate.isDirectory) {
                return candidate.walkTopDown()
                    .filter { it.isFile && it.extension == "kt" }
                    .toList()
                    .sortedBy { it.path }
            }
            dir = dir?.parentFile
        }
        error(
            "找不到 $APP_DIR_RELATIVE（工作目录 ${File("").absolutePath}）；" +
                "路径若已移动，请同步本测试的 APP_DIR_RELATIVE 常量",
        )
    }

    private fun relative(file: File): String =
        file.path.replace('\\', '/').substringAfterLast("com/mutx163/qingyu/")

    private companion object {
        const val APP_DIR_RELATIVE = "android/app/src/main/kotlin/com/mutx163/qingyu/app"

        /** `import com.mutx163.qingyu.pages.<任何东西>`。 */
        val PAGES_IMPORT = Regex("""^\s*import\s+com\.mutx163\.qingyu\.pages\.""")

        /** 非纯 Kotlin 的导入（Android 框架 / Compose / miuix）。 */
        val ANDROID_IMPORT = Regex("""^\s*import\s+(android[.:]|androidx\.compose|top\.yukonga\.miuix)""")
    }
}
