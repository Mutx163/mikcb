package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 外部打开 `.mikcb` / `.json` 备份 → 数据传输页的接线守卫（2026-11-02）。
 *
 * ## 它防的是哪一类事故
 *
 * 外部入口链路有三段：跳板 `ShellExternalEntryActivity` 读文件备 payload 进
 * [ShellExternalEntryHub] → 壳按 `importTargetPage` 推到 `g3.dataTransfer` →
 * **传输页宿主把备份文本接进导入预览**。第三段曾经空着：页面被推到了，
 * payload 却留在 hub 里没人消费——用户从文件管理器点开备份，看到的是
 * 干干净净的传输页，什么也没发生。
 *
 * ## 为什么读源码文本
 *
 * 「宿主有没有消费 hub 的 payload」发生在 Compose 函数体里，反射与编译产物
 * 都不保留；hub 本身带 `androidx.compose.runtime` 状态，进不了 JVM 单测。
 * 与同目录 `DayViewWiringGuardTest` / `DiagnosticsWiringGuardTest` 同一套做法。
 */
class ExternalBackupTransferWiringGuardTest {

    @Test
    fun `传输页宿主必须消费 hub 里的备份 payload`() {
        val host = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferHost.kt",
        )
        assertTrue(
            "`DataTransferHost` 没有调用 `ShellExternalEntryHub.consumeImport(\"backup\")`——" +
                "外部打开 .mikcb 备份只会被推到传输页，payload 永远留在 hub 里没人消费。",
            "ShellExternalEntryHub.consumeImport(\"backup\")" in host,
        )
        assertTrue(
            "`DataTransferHost` 取到备份 payload 后没有接进导入预览链路" +
                "（找不到 `openImportPreview(payload.text, TransferChannel.FILE)`）——" +
                "外部打开备份不会弹出导入预览。",
            "openImportPreview(payload.text, TransferChannel.FILE)" in host,
        )
    }

    @Test
    fun `hub 的 kind 判定必须保住各页面互不抢`() {
        val runtime = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellExternalEntryRuntime.kt",
        )
        // 传输页只按 "backup" 消费：ics / spreadsheet / 超限各有落点页，
        // kind 不符时不许被顺手消费掉（`consumeImport` 的契约）。
        assertTrue(
            "`ShellExternalEntryHub` 的 payloadKind 映射丢了 `Backup -> \"backup\"`——" +
                "传输页按 kind 消费的判据失效，各导入页会互抢 payload。",
            "is ShellExternalEntry.ImportPayload.Backup -> \"backup\"" in runtime,
        )
        assertTrue(
            "`ShellExternalEntryHub.consumeImport` 不见了——kind 不符不消费的契约没有承载点。",
            "fun consumeImport(kind: String)" in runtime,
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：文件定位坏了会让上面几条全部变绿——那比没有守卫更糟。
        val host = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferHost.kt",
        )
        assertTrue(
            "DataTransferHost.kt 读出来太短（${host.length} 字符），定位可能坏了",
            host.length > 200,
        )
        assertTrue("源文件里应当有 DataTransferHost( 定义", "fun DataTransferHost(" in host)
    }

    /** 与同目录守卫同一口径：从工作目录向上找仓库根，找不到仍判失败。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
