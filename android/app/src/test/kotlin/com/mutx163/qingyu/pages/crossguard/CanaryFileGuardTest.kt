package com.mutx163.qingyu.pages.crossguard

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * 探针 / canary 文件守卫（2026-11-12，`ZzCanary.kt` 事故后补）。
 *
 * ## 防的是什么
 *
 * 探针被误放进 `android/app/src`：
 * - 落在 `main`/`composeP1` 就是**编译面里的真源码**，一串 `Unresolved reference` 直接炸 Gradle
 *   （活例：`:app:compilePerfBenchKotlin` 报 `ZzCanary.kt` 一堆 Compose 未解析）；
 * - 它**不进 git**（未跟踪），一旦有人手清，`git status` 与历史都看不出痕迹——
 *   只存在于某个人的工作区、某个时间窗，属于最难查的一类污染。
 *
 * ## 判据的三句话
 *
 * 1. **扫描根 = `android/app/src`**（不按仓库根：`.agents/` 下有 `_c2m_probe.sh`、`arb-live-probe.txt`
 *    等 scratch 文件，它们不参与构建，扫进来只会放大误伤）；
 * 2. **判据 = 文件名**匹配 `(?i)canary|zzcanary|probe`（**不读文件内容**：
 *    `i18n/LocaleFormatGuardTest.kt:91`、`pages/ComposePageStyleGuardTest.kt:264` 的注释里
 *    就在讲这套手法，按内容扫会「讲这件事的注释被判成这件事」）；
 * 3. 命中且不在白名单 ⇒ 红；白名单是**存量迁移表，只许缩不许增**。
 *
 * ## 「能抓」为什么用临时目录验，而不是往仓库塞探针（2026-11-12 两次教训）
 *
 * 为证明守卫会红，直接往 `android/app/src` 放两分钟 `ZzCanary.kt` —— **测试期间仓库里真的躺着
 * 一个能炸编译的探针**。所以扫描抽成纯函数 [scanProbeFiles]，用 `Files.createTempDirectory`
 * 造假 src 树验证「命中 / 白名单放行 / 不误伤」三个方向，**一个字节都不碰仓库**。
 * 今后同类验证一律照此办理。
 */
class CanaryFileGuardTest {

    @Test
    fun `真实仓库 src 下没有探针文件，且白名单没有过期条目`() {
        val root = File(repoRoot(), "android/app/src")
        assertTrue("找不到 Android 源码根：${root.absolutePath}", root.isDirectory)

        val result = scanProbeFiles(root)

        assertTrue(
            "扫描规模异常（只扫到 ${result.scanned} 个文件）：判据疑似失效，空跑会假绿",
            result.scanned >= 1500,
        )
        assertTrue(
            buildString {
                appendLine("android/app/src 下出现探针 / canary 文件（不属于仓库，会污染 Gradle 编译面）：")
                result.offenders.forEach { appendLine("  - $it") }
                appendLine("处理顺序：① 先把它移出工作区；② 确认没有同类文件；")
                appendLine("③ 若属长期调试工具，改名去掉 probe/canary 字样并在评审里说明——")
                appendLine("   本白名单是存量迁移表，只许缩不许增。")
            },
            result.offenders.isEmpty(),
        )

        val stale = PROBE_WHITELIST.filterNot { it in result.whitelistSeen }.sorted()
        assertTrue(
            buildString {
                appendLine("白名单里这些条目已不再命中（文件删了 / 改名了 / 不再匹配判据），请删掉对应行：")
                stale.forEach { appendLine("  - $it") }
            },
            stale.isEmpty(),
        )
    }

    @Test
    fun `纯函数在临时目录上同时验证「能抓」与「不误伤」`() {
        val tmp = Files.createTempDirectory("canary-guard").toFile()
        try {
            write(tmp, "main/kotlin/com/mutx163/qingyu/ZzCanary.kt")
            write(tmp, "main/kotlin/com/mutx163/qingyu/demo/FooProbe.kt")
            write(tmp, "main/kotlin/com/mutx163/qingyu/demo/OrdinaryFile.kt")
            write(tmp, "main/kotlin/com/mutx163/qingyu/platform/PerfProbe.kt") // 白名单内 → 必须放行

            val result = scanProbeFiles(tmp)

            assertEquals(
                "只有未登记的 canary/probe 该被点名（白名单那条放行、普通文件不能被误抓）",
                listOf(
                    "main/kotlin/com/mutx163/qingyu/ZzCanary.kt",
                    "main/kotlin/com/mutx163/qingyu/demo/FooProbe.kt",
                ).sorted(),
                result.offenders.sorted(),
            )
            assertTrue(
                "白名单命中没被记录（stale 断言会因此失效）",
                "main/kotlin/com/mutx163/qingyu/platform/PerfProbe.kt" in result.whitelistSeen,
            )
            assertEquals("临时树里共 4 个文件，扫描数应等于它", 4, result.scanned)
        } finally {
            tmp.deleteRecursively()
        }
    }

    @Test
    fun `判据本身认 canary 与 probe，不认普通文件名`() {
        assertTrue(PROBE_NAME.containsMatchIn("ZzCanary.kt"))
        assertTrue(PROBE_NAME.containsMatchIn("FooProbe.kt"))
        assertTrue(PROBE_NAME.containsMatchIn("zzcanary/Leak.kt"))
        assertTrue(!PROBE_NAME.containsMatchIn("OrdinaryFile.kt"))
    }

    private fun write(root: File, rel: String) {
        val f = File(root, rel)
        f.parentFile.mkdirs()
        f.writeText("// fixture\nobject Fixture\n")
    }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "i18n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（未定位到 i18n/app_zh.arb），工作目录 ${File("").absolutePath}")
    }
}

/** 宽判据（文件名，大小写不敏感）。 */
internal val PROBE_NAME = Regex("(?i)canary|zzcanary|probe")

/** 守卫自身（文件名含 Canary），扫描时跳过。 */
internal const val CANARY_GUARD_SELF_REL =
    "test/kotlin/com/mutx163/qingyu/pages/crossguard/CanaryFileGuardTest.kt"

/**
 * 存量白名单（7 条，逐条列全，不要通配）。路径基准 = `android/app/src`。
 * 新增 Probe 不要往这里加行——先问「它为什么必须叫 probe」。
 */
internal val PROBE_WHITELIST: Set<String> = setOf(
    "composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthScrollProbe.kt",
    "main/kotlin/com/mutx163/qingyu/pages/diagnostics/PerfProbeCore.kt",
    "main/kotlin/com/mutx163/qingyu/platform/LegacyCredentialProbe.kt",
    "main/kotlin/com/mutx163/qingyu/platform/PerfProbe.kt",
    "main/kotlin/com/mutx163/qingyu/platform/guide/GuidePermissionProbe.kt",
    "test/kotlin/com/mutx163/qingyu/pages/diagnostics/PerfProbeCoreTest.kt",
    "test/kotlin/com/mutx163/qingyu/weather/WallpaperFileNameBiteProbeTest.kt",
)

/** 一次扫描的结果：白名单外的探针 + 白名单命中（用于 stale 断言）+ 扫描规模。 */
internal data class ProbeScanResult(
    val scanned: Int,
    val offenders: List<String>,
    val whitelistSeen: Set<String>,
)

/**
 * 纯函数：扫 [root] 下文件名匹配 [PROBE_NAME] 的文件。
 *
 * 刻意不读文件内容；白名单与自跳过路径是顶层常量，所以测试能拿临时目录直接调它。
 */
internal fun scanProbeFiles(root: File): ProbeScanResult {
    var scanned = 0
    val offenders = mutableListOf<String>()
    val seen = mutableSetOf<String>()
    root.walkTopDown().forEach { f ->
        if (!f.isFile) return@forEach
        scanned++
        val rel = f.absolutePath.removePrefix(root.absolutePath + File.separator).replace('\\', '/')
        if (rel == CANARY_GUARD_SELF_REL) return@forEach
        if (!PROBE_NAME.containsMatchIn(f.name)) return@forEach
        if (rel in PROBE_WHITELIST) seen += rel else offenders += rel
    }
    return ProbeScanResult(scanned, offenders, seen)
}
