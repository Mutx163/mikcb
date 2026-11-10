package com.mutx163.qingyu.pages.transfer

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **J10：发送槽必须在页面层清、不许在导航层清**的源码守卫（2026-11-10）。
 *
 * 背景：`TransferShellBridge` 改进程级 object 后，`outbound` 槽里的最后一次发送包
 *（压缩上限 16 MiB / 原始 64 MiB）若不清，会一直活到进程结束。清除点只能放在
 * `QrTransferSendHost`（页面层：back / stop / 组合销毁），不能放在 `ShellPageIndex`
 *（导航层）——页面层是唯一知道「这次发送真的结束了」的地方，导航层顺手清会在
 * `remember(payload)` 还活着时把包抽走。行为契约由 `ShellBridgeSignalsTest` 钉；
 * 本守卫钉生产接线。
 */
class QrTransferSendOutboundClearGuardTest {

    private val qrHosts: String by lazy {
        stripLineComments(readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/QrTransferHosts.kt",
        ))
    }

    private val shellIndex: String by lazy {
        stripLineComments(readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
        ))
    }

    @Test
    fun `发送页宿主必须清发送槽且覆盖 back-stop-销毁三条路径`() {
        assertTrue(
            "QrTransferSendHost 没有调 TransferShellBridge.clearOutbound()——" +
                "进程级发送槽会把最后一次 16MB/64MB 的包留到进程结束",
            qrHosts.contains("TransferShellBridge.clearOutbound()"),
        )
        assertTrue(
            "QrTransferSendHost 缺少 DisposableEffect/onDispose 兜底——系统返回等不走 back 回调的路径清不到",
            qrHosts.contains("DisposableEffect(Unit)") && qrHosts.contains("onDispose"),
        )
        // back / stop 两个回调各一次 + onDispose 一次 = 至少 3 处。
        val clearCalls = Regex("""TransferShellBridge\.clearOutbound\(\)""").findAll(qrHosts).count()
        assertTrue(
            "clearOutbound() 只出现 $clearCalls 次：back、stop、onDispose 三条路径必须都有（幂等）",
            clearCalls >= 3,
        )
    }

    @Test
    fun `导航层不许顺手清发送槽`() {
        assertFalse(
            "ShellPageIndex.kt 里出现了 clearOutbound——导航层清会把 remember(payload) 还要用的包抽走；" +
                "清除点只能是 QrTransferSendHost 页面层",
            shellIndex.contains("clearOutbound"),
        )
    }

    // ------------------------------------------------------------------ 定位

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }
}
