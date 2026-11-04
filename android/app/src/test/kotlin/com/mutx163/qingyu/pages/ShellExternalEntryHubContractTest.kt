package com.mutx163.qingyu.pages

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * R09 消费链（C）守卫：NotificationLaunchTarget.postLaunchPage → ShellExternalEntryHub → 壳消费钩子。
 *
 * ## 为什么是源码级而不是运行时
 * `ShellExternalEntryHub` 带 `androidx.compose.runtime` 状态（`by mutableStateOf`），
 * 进不了 JVM 单测（同 `ExternalBackupTransferWiringGuardTest` / `DayViewWiringGuardTest`
 * 的既有说明）。所以按本仓库同一套做法做源码级契约，钉住这条链四段字面量不丢：
 *   1) `postLaunchPage` 把 pageId 投进 `ShellExternalEntryHub.post(pageId, payload = null)`；
 *   2) `hub.post` 把 pageId 写进 `pendingPageId`；
 *   3) `hub.consumePageId` 读出 pendingPageId 并清空（消费即清空，防重复推页）；
 *   4) 壳 `ShellExternalEntryEffect` 用 `consumePageId()` 的值调 `onOpenPage(...)`。
 * 任一段被删/改名，通知即使落进 hub 也不会推到页面——本条即红。
 */
class ShellExternalEntryHubContractTest {

    @Test
    fun `postLaunchPage 必须把解析出的落点投进 hub`() {
        val target = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/NotificationLaunchTarget.kt",
        )
        assertTrue(
            "postLaunchPage 没有把 pageId 投进 ShellExternalEntryHub.post(pageId, payload = null)—" +
                "解析完落点却没人接收，通知点击仍不落页。",
            "ShellExternalEntryHub.post(pageId, payload = null)" in target,
        )
    }

    @Test
    fun `hub 的 post 写入 pendingPageId、consumeId 读取并清空`() {
        val runtime = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellExternalEntryRuntime.kt",
        )
        assertTrue(
            "hub.post 不见了（消费链没有入口）",
            "fun post(pageId: String?, payload: ShellExternalEntry.ImportPayload?)" in runtime,
        )
        assertTrue(
            "hub.post 没有把 pageId 写进 pendingPageId—待推落点丢失",
            "pendingPageId = pageId" in runtime,
        )
        assertTrue(
            "hub.consumePageId 不见了（壳没有取落点的方法）",
            "fun consumePageId(): String?" in runtime,
        )
        assertTrue(
            "consumePageId 读出后没有清空 pendingPageId—会重复推同一页",
            "pendingPageId = null" in runtime,
        )
    }

    @Test
    fun `壳消费钩子必须把 hub 的 id 交给 onOpenPage`() {
        val runtime = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellExternalEntryRuntime.kt",
        )
        assertTrue(
            "ShellExternalEntryEffect 没有调用 ShellExternalEntryHub.consumePageId()",
            "ShellExternalEntryHub.consumePageId()" in runtime,
        )
        assertTrue(
            "ShellExternalEntryEffect 拿到的 pageId 没有交给 onOpenPage(pageId)—页面不会被推出来",
            "onOpenPage(pageId)" in runtime,
        )
    }

    /** 从工作目录向上最多 8 层找仓库根下的相对路径源文件；找不到直接判失败。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) {
                val text = candidate.readText(Charsets.UTF_8)
                check(text.length > 200) { "$relative 读出来太短（${text.length}），定位可能坏了" }
                return text
            }
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
