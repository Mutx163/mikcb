package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 连接弹层接线守卫（2026-11-02，防主线程网络闪退回归）。
 *
 * ## 它防的是哪一类事故
 *
 * `f.cloudSync` 分支曾经：`testing` / `connecting` 写死 `false`（进行中没有禁用与转圈）、
 * `onTestConnection` / `onConfirm` **直接在主线程**调 `controller.testConnection / connect`
 * （同步阻塞 WebDAV 请求）⇒ 真机上 `NetworkOnMainThreadException` 必现闪退；
 * `onConfirm` 无条件 `showConnect = false` ⇒ 连接失败也关弹层，用户以为连上了。
 *
 * ## 为什么读源码文本
 *
 * 「回调里怎么调控制器」写在 Compose lambda 里，编译产物与反射都不保留；
 * 与 `pages/shell/DayViewWiringGuardTest` 同一套做法，判据是「出现/不出现某些字样」。
 */
class WebdavConnectSheetWiringGuardTest {

    @Test
    fun `连接弹层的网络动作必须离开主线程`() {
        val branch = branchBody("f.cloudSync")
        assertTrue(
            "测试连接没有走 `withContext(Dispatchers.IO)`：真机主线程发同步网络请求会 " +
                "NetworkOnMainThreadException 闪退（2026-11-02 修复的事故）。",
            "withContext(Dispatchers.IO) { controller.testConnection(u, p) }" in branch,
        )
        assertTrue(
            "确认连接没有走 `withContext(Dispatchers.IO)`：同上，主线程网络闪退。",
            "withContext(Dispatchers.IO) { controller.connect(u, p) }" in branch,
        )
        assertTrue(
            "连接弹层回调没有用 `scope.launch`：必须沿用仓库既有的协程模式，不许自造线程池。",
            "scope.launch" in branch,
        )
    }

    @Test
    fun `连接弹层必须接进行中状态`() {
        val branch = branchBody("f.cloudSync")
        assertTrue(
            "`testing` 没接状态变量（写死 false）：进行中按钮不禁用、不转圈，用户会连点。",
            "testing = sheetTesting" in branch,
        )
        assertTrue(
            "`connecting` 没接状态变量（写死 false）：同上。",
            "connecting = sheetConnecting" in branch,
        )
    }

    @Test
    fun `只有连接成功才关弹层`() {
        val branch = branchBody("f.cloudSync")
        val onConfirm = branch
            .substringAfter("onConfirm = { u, p ->")
            .substringBefore("onCancel =")
        assertTrue("onConfirm 里没有调用 `controller.connect(u, p)`", "controller.connect(u, p)" in onConfirm)
        val successIndex = onConfirm.indexOf("if (result.success)")
        val closeIndex = onConfirm.indexOf("showConnect = false")
        assertTrue(
            "onConfirm 没有按 `result.success` 判断：失败也会走到关弹层。",
            successIndex >= 0,
        )
        assertTrue(
            "onConfirm 在判断 success 之前就关了弹层（无条件关闭的老写法）：连接失败弹层被关，" +
                "用户以为连上了，实际什么都没发生。",
            closeIndex > successIndex,
        )
        // 测试连接只报告结果，绝不该动弹层开关。
        val onTest = branch
            .substringAfter("onTestConnection = { u, p ->")
            .substringBefore("onConfirm =")
        assertTrue(
            "onTestConnection 里出现了 `showConnect = false`：测试失败/进行中会把弹层关掉。",
            "showConnect = false" !in onTest,
        )
    }

    // ── 辅助：从仓库根定位 ShellPageIndex.kt 并截取指定分支体（同 DayViewWiringGuardTest） ──

    private fun branchBody(id: String): String {
        val source = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
        )
        val matches = BRANCH.findAll(source).toList()
        val index = matches.indexOfFirst { it.groupValues[1] == id }
        assertTrue("ShellPageIndex.kt 里找不到分支 `$id`", index >= 0)
        val start = matches[index].range.last + 1
        val end = matches.getOrNull(index + 1)?.range?.first ?: source.length
        return source.substring(start, end)
    }

    /** 从工作目录向上找仓库根再定位文件；找不到仍判失败，守卫不许静默跳过。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private val BRANCH = Regex("""^[ \t]*"([A-Za-z0-9._-]+)"[ \t]*->""", RegexOption.MULTILINE)
}
