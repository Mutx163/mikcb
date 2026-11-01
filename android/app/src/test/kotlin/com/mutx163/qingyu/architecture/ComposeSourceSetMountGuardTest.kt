package com.mutx163.qingyu.architecture

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 源集挂载守卫（2026-11-01）：`android/app/build.gradle` 必须把 `composeP1` 源树完整挂进
 * `main` 源集。
 *
 * ## 为什么需要它
 *
 * Gradle 只编译**被挂载**的目录。此前 `sourceSets.main.kotlin.srcDirs` 是逐目录登记的
 * （components / app / pages 下 21 个域），漏写一个目录不会报错：那个目录下的页面**不进
 * `:app:compile*Kotlin`、不进 APK**，直到有人运行到那一页才崩，排查成本极高。
 * 活例：包根的 `ComposeP1Activity.kt` 一直没被挂上（2026-11-01 清理时发现并删除）。
 *
 * 现在 `build.gradle` 改为整树挂载 `src/composeP1/kotlin`，本守卫把这条不变量锁住：
 * 只要树里出现一个没被任何 `kotlin.srcDirs` 覆盖的 `.kt` 文件就失败——无论日后是
 * 有人把整树挂载改回逐目录列表，还是新增了别的前缀。
 *
 * ## 判据
 *
 * - 从 `android/app/build.gradle` 源码文本里解析所有 `kotlin.srcDirs += 'src/composeP1/...'`；
 * - `src/composeP1/kotlin` 下的每个 `.kt` 文件，路径（相对 `android/app`）必须等于某个挂载项
 *   或以 `<挂载项>/` 开头（`srcDirs` 是递归的，父目录覆盖所有子目录）；
 * - 顺带做一次「守卫不能空跑」自检：挂载项非空、源树里至少有 40 个 `.kt` 文件。
 */
class ComposeSourceSetMountGuardTest {

    private val mountRegex =
        Regex("""kotlin\.srcDirs\s*\+=\s*['"](src/composeP1/kotlin[^'"]*)['"]""")

    @Test
    fun `composeP1 源树里的每个 Kotlin 文件都必须被 build_gradle 挂载`() {
        val repoRoot = repoRoot()
        val moduleRoot = File(repoRoot, "android/app")
        val buildGradle = File(moduleRoot, "build.gradle")
        assertTrue("找不到 ${buildGradle.absolutePath}", buildGradle.isFile)

        val mounts = mountRegex.findAll(buildGradle.readText())
            .map { it.groupValues[1].trimEnd('/') }
            .toList()
        assertTrue(
            "build.gradle 没有挂载 src/composeP1/kotlin 下的任何目录；" +
                "Compose 页面将整体被排除在编译之外",
            mounts.isNotEmpty(),
        )

        val tree = File(moduleRoot, "src/composeP1/kotlin")
        assertTrue("找不到 composeP1 源码目录：${tree.absolutePath}", tree.isDirectory)
        val kotlinFiles = tree.walkTopDown()
            .filter { it.isFile && it.name.endsWith(".kt") }
            .toList()
        assertTrue(
            "composeP1 源码目录下只找到 ${kotlinFiles.size} 个 .kt 文件，守卫疑似空跑",
            kotlinFiles.size >= 40,
        )

        val missing = kotlinFiles
            .map { it.relativeTo(moduleRoot).invariantSeparatorsPath }
            .filter { rel -> mounts.none { mount -> rel == mount || rel.startsWith("$mount/") } }

        assertTrue(
            buildString {
                appendLine("以下 composeP1 源文件没有被 build.gradle 的 kotlin.srcDirs 挂载，")
                appendLine("它们会被静默排除在编译之外（不报错、不进 APK、运行到那一页才崩）：")
                missing.forEach { appendLine("  - android/app/$it") }
                appendLine("修法：在 android/app/build.gradle 的 sourceSets.main 里挂上所在目录，")
                appendLine("或直接整树挂载：kotlin.srcDirs += 'src/composeP1/kotlin'。")
            },
            missing.isEmpty(),
        )
    }

    /** 与 `CjkLiteralGateTest` 一致的仓库根定位：往上找到含 `lib/l10n/app_zh.arb` 的目录。 */
    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "lib/l10n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（未定位到 lib/l10n/app_zh.arb）")
    }
}
