package com.mutx163.qingyu.pages.time_scheme

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **「进页转圈久 / 点确定卡住」不许复发**的源码守卫（2026-11-10 A2/A3）。
 *
 * ## 它钉住三件在这次修复里被拆掉的东西
 *
 * 1. 列表页不能再有加载门（`isLoading = model == null`）——首帧就该有轻模型；
 * 2. 不能再绕一圈 `withContext(Dispatchers.IO) { repository.snapshot }`——那个 getter 是纯内存的；
 * 3. 编辑页不能又在**组合期同步**跑 `TimeSchemeUsageIndexFactory.build(...)`（会把主线程按住，
 *    表现就是「新建 → 确定」后页面迟迟不出来）——首帧用 `TimeSchemeUsageIndex.EMPTY`，后台补。
 *
 * ## 为什么用文本守卫
 *
 * 这三条都是「性能回归」，不影响功能对错、单测也全绿；只有看宿主源码结构才看得出来。
 * 同仓先例：`TimeSchemeWiringGuardTest`、`DataTransferQrImportWiringGuardTest`。
 */
class TimeSchemeLoadingDoorGuardTest {

    private val hostSource: String by lazy { stripLineComments(readSource(HOST_PATH)) }

    @Test
    fun `列表页不许再有加载门`() {
        assertFalse(
            "TimeSchemeHost.kt 又出现了 `isLoading = model == null`——" +
                "首帧就该用内存快照装配轻模型，不要再让用户对着转圈等",
            hostSource.contains("isLoading = model == null"),
        )
        assertTrue(
            "列表页必须直接以内存快照起步（`mutableStateOf(repository.snapshot)`）",
            hostSource.contains("mutableStateOf(repository.snapshot)"),
        )
    }

    @Test
    fun `不许再为内存快照绕 IO 线程`() {
        assertFalse(
            "TimeSchemeHost.kt 里还有 `withContext(Dispatchers.IO) { repository.snapshot }`——" +
                "snapshot 是纯内存 getter，绕 IO 只多一次主线程挂起",
            hostSource.replace(" ", "").contains("withContext(Dispatchers.IO){repository.snapshot}"),
        )
    }

    @Test
    fun `编辑页首帧不许同步建引用索引`() {
        assertTrue(
            "编辑页首帧必须以 `TimeSchemeUsageIndex.EMPTY` 起步（后台再补索引）",
            hostSource.contains("usage = TimeSchemeUsageIndex.EMPTY"),
        )
        // 唯一允许在组合期建索引的地方是列表页的轻模型装配；这里断言全文件里
        // `remember(snapshot) {` + Factory.build 这种组合不再出现。
        assertFalse(
            "又出现 `remember(snapshot) { TimeSchemeUsageIndexFactory.build(...) }` 了——" +
                "那会在主线程上做全量档案扫描",
            Regex(
                """remember\(snapshot\)\s*\{\s*TimeSchemeUsageIndexFactory\.build""",
            ).containsMatchIn(hostSource),
        )
    }

    private fun stripLineComments(source: String): String =
        source.lineSequence().filterNot { it.trimStart().startsWith("//") }.joinToString("\n")

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        const val HOST_PATH = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TimeSchemeHost.kt"
    }
}
