package com.mutx163.qingyu.pages.crossguard

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

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
 * ## 为什么用**宽 pattern + 显式白名单**（而不是只认 canary）
 *
 * 两个失败方向不一样：
 * - 窄 pattern（只认 canary）：0 命中、永远绿，**静默吸收**所有新来的 `XxxProbe.kt`，没人知道漏了什么；
 * - 宽 pattern（`canary|zzcanary|probe`）+ 逐条白名单：新增一个 `XxxProbe.kt` **立刻红**，
 *   逼人做一次性显式决定——要么改名、要么在评审里说明后加白。
 *
 * 本次白名单是**存量迁移表**：只许缩不许增；某条对应文件被删/改名后不清掉同样会红（stale 断言）。
 *
 * ## 判据的三句话
 *
 * 1. **扫描根 = `android/app/src`**（不按仓库根：`.agents/` 下有 `_c2m_probe.sh`、`arb-live-probe.txt`
 *    等 scratch 文件，它们不参与构建，扫进来只会放大误伤）；
 * 2. **判据 = 文件名**匹配 `(?i)canary|zzcanary|probe`（**不读文件内容**：
 *    `i18n/LocaleFormatGuardTest.kt:91`、`pages/ComposePageStyleGuardTest.kt:264` 的注释里
 *    就在讲这套手法，按内容扫会「讲这件事的注释被判成这件事」）；
 * 3. 命中且不在白名单 ⇒ 红；失败信息写清「探针不属于仓库，会污染 Gradle 编译面」。
 */
class CanaryFileGuardTest {

    @Test
    fun `src 下出现探针文件即红，白名单外的 Probe 一律要求显式处理`() {
        val root = File(repoRoot(), "android/app/src")
        assertTrue("找不到 Android 源码根：${root.absolutePath}", root.isDirectory)

        val scanned = mutableListOf<File>()
        val offenders = mutableListOf<String>()
        val whitelistSeen = mutableSetOf<String>()

        root.walkTopDown().forEach { f ->
            if (!f.isFile) return@forEach
            scanned += f
            val rel = f.absolutePath.removePrefix(root.absolutePath + File.separator)
                .replace('\\', '/')
            if (rel == SELF_REL_PATH) return@forEach // 守卫自身名字含 Canary
            if (!PROBE_NAME.containsMatchIn(f.name)) return@forEach
            if (rel in WHITELIST) {
                whitelistSeen += rel
            } else {
                offenders += rel
            }
        }

        assertTrue(
            "扫描规模异常（只扫到 ${scanned.size} 个文件）：判据疑似失效，空跑会假绿",
            scanned.size >= 1500,
        )
        assertTrue(
            buildString {
                appendLine("android/app/src 下出现探针 / canary 文件（不属于仓库，会污染 Gradle 编译面）：")
                offenders.forEach { appendLine("  - $it") }
                appendLine("处理顺序：① 先把它移出工作区；② 确认没有同类文件；")
                appendLine("③ 如果是长期需要的调试工具，改名去掉 probe/canary 字样并在评审里说明——")
                appendLine("   本白名单是存量迁移表，只许缩不许增。")
            },
            offenders.isEmpty(),
        )

        val stale = WHITELIST.filterNot { it in whitelistSeen }.sorted()
        assertTrue(
            buildString {
                appendLine("白名单里这些条目已不再命中（文件删了 / 改名了 / 不再匹配判据），请删掉对应行：")
                stale.forEach { appendLine("  - $it") }
            },
            stale.isEmpty(),
        )
    }

    @Test
    fun `判据真的能抓到 canary，且白名单里的 7 个合法文件都在`() {
        // 反向自证：真探针名字必须命中（防止 pattern 被改成永不命中）。
        assertTrue(PROBE_NAME.containsMatchIn("ZzCanary.kt"))
        assertTrue(PROBE_NAME.containsMatchIn("zzcanary/Leak.kt"))
        assertTrue(PROBE_NAME.containsMatchIn("SomeProbe.kt"))

        // 白名单必须逐条指向真实存在的文件（不存在 → stale 断言会红，这里再给一次明确提示）。
        val root = File(repoRoot(), "android/app/src")
        val missing = WHITELIST.filterNot { File(root, it).isFile }.sorted()
        assertTrue("白名单条目指向的文件不存在（路径基准是 android/app/src）：$missing", missing.isEmpty())
    }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "i18n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（未定位到 i18n/app_zh.arb），工作目录 ${File("").absolutePath}")
    }

    private companion object {
        /** 宽判据（文件名，大小写不敏感）：canary / zzcanary / probe。 */
        val PROBE_NAME = Regex("(?i)canary|zzcanary|probe")

        /** 守卫自身，扫描时跳过。 */
        const val SELF_REL_PATH = "test/kotlin/com/mutx163/qingyu/pages/crossguard/CanaryFileGuardTest.kt"

        /**
         * 存量白名单（7 条，逐条列全，不要通配）。路径基准 = `android/app/src`。
         * 这些是仓库里**长期存在的合法 Probe**（性能探针 / 凭据探测 / 预览滚动探针）。
         * 新增 Probe 不要往这里加行——先问「它为什么必须叫 probe」。
         */
        val WHITELIST = setOf(
            "composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthScrollProbe.kt",
            "main/kotlin/com/mutx163/qingyu/pages/diagnostics/PerfProbeCore.kt",
            "main/kotlin/com/mutx163/qingyu/platform/LegacyCredentialProbe.kt",
            "main/kotlin/com/mutx163/qingyu/platform/PerfProbe.kt",
            "main/kotlin/com/mutx163/qingyu/platform/guide/GuidePermissionProbe.kt",
            "test/kotlin/com/mutx163/qingyu/pages/diagnostics/PerfProbeCoreTest.kt",
            "test/kotlin/com/mutx163/qingyu/weather/WallpaperFileNameBiteProbeTest.kt",
        )
    }
}
