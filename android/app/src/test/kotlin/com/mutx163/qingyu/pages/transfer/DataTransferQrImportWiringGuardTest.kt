package com.mutx163.qingyu.pages.transfer

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **扫码收齐→导入不能被自己的 key 取消**的源码守卫（2026-11-10）。
 *
 * ## 原缺陷
 *
 * `DataTransferHost.kt` 里原来是：
 *
 * ```kotlin
 * LaunchedEffect(bridge.inboundBytes) {
 *     val bytes = bridge.inboundBytes ?: return@LaunchedEffect
 *     bridge.inboundBytes = null        // ← key 变了
 *     val text = withContext(Dispatchers.IO) { decode(bytes) }
 *     openImportPreview(text, …)
 * }
 * ```
 *
 * 函数内部把 key 置 null，重组时 Compose 会取消**正在解码的协程**；解码只要超过一帧
 * （大备份概率高），后面的预览就永远弹不出来，页面还卡在 `isImporting = true`。
 * 修法是用 `LaunchedEffect(Unit) + snapshotFlow`，让协程只随页面销毁而停。
 *
 * 这条守卫钉住修法本身（Compose 行为在 L0 里跑不起来，源码级是唯一能自动化的探针）。
 */
class DataTransferQrImportWiringGuardTest {

    private val source: String by lazy { stripLineComments(readHostSource()) }

    @Test
    fun `扫码字节消费必须用 snapshotFlow 而不是以 inboundBytes 为 key`() {
        assertTrue(
            "DataTransferHost.kt 没有 snapshotFlow { bridge.inboundBytes }——" +
                "扫码收齐后清空字段会取消正在解码的协程，预览可能永远不弹",
            source.contains("snapshotFlow { bridge.inboundBytes }"),
        )
        assertFalse(
            "DataTransferHost.kt 仍有 LaunchedEffect(bridge.inboundBytes)——" +
                "key 会在函数内被清空，协程自取消；改用 LaunchedEffect(Unit) + snapshotFlow",
            source.contains("LaunchedEffect(bridge.inboundBytes)"),
        )
    }

    @Test
    fun `扫码字节仍走与文件导入同一条预览链路`() {
        assertTrue(
            "扫码字节必须交给 openImportPreview(…, TransferChannel.QR)，不能丢",
            source.contains("openImportPreview(text, TransferChannel.QR)"),
        )
    }

    // ------------------------------------------------------------------ 定位

    private fun readHostSource(): String {
        val relative = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferHost.kt"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 DataTransferHost.kt（工作目录 ${File("").absolutePath}），试过：$relative")
    }

    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }
}
