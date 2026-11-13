package com.mutx163.qingyu.pages.import.warehouse

import java.io.File
import java.util.UUID
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 落盘（真文件往返 + 截断 + 写失败）。
 *
 * 为什么**必须写真实文件再读回**：只断言 buffer 的话，「buffer 已脱敏」与「文件里也是
 * 脱敏后的内容」就是同一个断言——导出层将来被人改成直写 `entry.fields`（跳过第二道脱敏）
 * 也照样绿。这里两端各断言一次：buffer 一侧（端点 1）与**磁盘上那份文本**（端点 2）。
 */
class WarehouseImportLogFileWriterTest {

    private val phone = "13800138000"
    private val account = "Abc123456"
    private val cookie = "JSESSIONID=abcd"
    private val rawUrl = "https://jw.example.edu/xskb/list?token=xyz"

    /** 生产里绝不能出现在日志里的四类明文（逐条搜）。 */
    private val secrets = listOf(phone, account, cookie, "abcd", "token=xyz", "xyz")

    /** 端点 1（buffer 已脱敏）+ 端点 2（写盘文件里也没有明文）——两端对照。 */
    @Test
    fun `真实文件往返后四串逐个搜不到 且buffer本身也已脱敏`() {
        val dir = newTempDir("roundtrip")
        val log = WarehouseImportLogBuffer()
        seedRun(log)

        // 端点 1：buffer 里的字段值（还没编成文本）就不允许有明文。
        val bufferText = log.snapshot().runs
            .flatMap { run -> run.entries.flatMap { entry -> entry.fields.values } }
            .joinToString(" ")
        assertTrue("buffer 里没有任何字段值，下面的否定断言会在空串上恒真", bufferText.isNotBlank())
        for (raw in secrets) {
            assertFalse("buffer 里仍有明文 <$raw>：$bufferText", bufferText.contains(raw))
        }

        // 端点 2：真的写到盘上，再把文件读回来。
        val writer = WarehouseImportLogFileWriter(baseDir = dir, log = log)
        val target = writer.targetFile()
        val text = WarehouseImportLogExport.buildText(log.snapshot(), DEVICE, nowMs = FIXED_MS)
        assertTrue("写入真实文件失败：${target.absolutePath}", writer.write(text))
        assertTrue("文件没落在 warehouse_import_log/last.txt：${target.absolutePath}", target.isFile)
        val readBack = target.readText(Charsets.UTF_8)
        assertTrue("读回来的文件是空的", readBack.isNotBlank())
        for (raw in secrets) {
            assertFalse("落盘文件里仍有明文 <$raw>：${target.absolutePath}", readBack.contains(raw))
        }
        assertTrue("脱敏把内容整段吃掉了（应有 9 行表头）", readBack.contains("verdict=failure"))

        // 报告里要贴的现场：真实路径 + 读回内容前 8 行（从 L0 输出里直接抄）。
        println("[warehouse-log] file=${target.absolutePath}")
        readBack.lineSequence().take(8).forEach { println("[warehouse-log] $it") }
    }

    /** 单份上限 256 KiB（真实文件往返）：超了截断、表头 `truncated: true`、文末 ASCII 标记。 */
    @Test
    fun `超过256KiB的日志截断后写盘 表头与文末两处标记都在`() {
        val dir = newTempDir("truncated")
        val log = WarehouseImportLogBuffer()
        log.beginRun("run-big", SCHOOL, ADAPTER)
        repeat(6000) { index ->
            log.record(
                WarehouseLogCategory.MACRO_STEP,
                linkedMapOf(
                    "step" to "$index/6000",
                    "type" to "click",
                    "selector" to "#row-$index",
                    "status" to "ok",
                    "ms" to "1",
                ),
            )
        }
        val text = WarehouseImportLogExport.buildText(log.snapshot(), DEVICE, nowMs = FIXED_MS)
        val writer = WarehouseImportLogFileWriter(baseDir = dir, log = log)
        val target = writer.targetFile()
        assertTrue("写入真实文件失败：${target.absolutePath}", writer.write(text))

        val readBack = target.readText(Charsets.UTF_8)
        val bytes = readBack.toByteArray(Charsets.UTF_8).size
        assertTrue("落盘后仍有 $bytes 字节，超过 256 KiB", bytes <= WarehouseImportLogExport.MAX_TEXT_BYTES)
        assertTrue(
            "表头没有报 truncated: true（机器读的那一处缺失）",
            readBack.contains("truncated: true"),
        )
        assertTrue(
            "文末缺少 ASCII 标记 ${WarehouseImportLogExport.TRUNCATED_NOTE}（人看的那一处缺失）",
            readBack.trimEnd().endsWith(WarehouseImportLogExport.TRUNCATED_NOTE),
        )
        println("[warehouse-log-truncated] file=${target.absolutePath} bytes=$bytes")
    }

    /** 写失败：**不抛**、返回 false，并记一条 INTERNAL（第 2 步 UI 必须能显示它）。 */
    @Test
    fun `写失败只记INTERNAL且不抛异常`() {
        val dir = newTempDir("writefail")
        // 拿一个**文件**当目录用：`mkdirs()` 必然失败，写进去必然抛 IOException。
        val blocker = File(dir, "blocker-file")
        assertTrue("准备不可写路径失败", blocker.createNewFile())
        val log = WarehouseImportLogBuffer()
        log.beginRun("run-1", SCHOOL, ADAPTER)

        val writer = WarehouseImportLogFileWriter(baseDir = dir, log = log)
        val doomed = File(File(blocker, "nested"), WarehouseImportLogFileWriter.FILE_NAME)
        val written = writer.write(doomed, "time=x\n")
        assertFalse("写到不可写路径居然报告成功", written)

        val internals = log.snapshot().runs
            .flatMap { run -> run.entries }
            .filter { it.category == WarehouseLogCategory.INTERNAL }
        assertTrue(
            "写失败没有记 INTERNAL：用户分不清「没生成」和「生成失败」（第 2 步 UI 要显示它）",
            internals.isNotEmpty(),
        )
        assertTrue(
            "INTERNAL 条目里应当带错误原因：${internals.map { it.fields }}",
            internals.any { it.fields["error"].orEmpty().isNotBlank() },
        )
    }

    // ---------------------------------------------------------------------
    // 工具
    // ---------------------------------------------------------------------

    private fun seedRun(log: WarehouseImportLogBuffer) {
        log.beginRun("run-1", SCHOOL, ADAPTER)
        log.record(
            WarehouseLogCategory.MACRO_STEP,
            linkedMapOf(
                "step" to "1/3",
                "type" to "fillField",
                "selector" to "#username",
                "status" to "ok",
                "ms" to "12",
                "account" to account,
            ),
        )
        log.record(
            WarehouseLogCategory.MACRO_STEP,
            linkedMapOf("step" to "2/3", "type" to "fillField", "selector" to "#phone", "phone" to phone),
        )
        log.record(
            WarehouseLogCategory.GATE,
            linkedMapOf("decision" to "ready", "reason" to "none", "stage" to "LOADED"),
        )
        log.record(
            WarehouseLogCategory.SCRIPT,
            linkedMapOf("url" to rawUrl, "Cookie" to cookie),
        )
        log.record(WarehouseLogCategory.FAILURE, linkedMapOf("code" to "macro_poll_timeout|timeoutSeconds=15"))
        log.markFailure("timeout")
    }

    /**
     * 测试用临时目录。
     *
     * 默认落在系统 temp；跑证据留档时把 `MIKCB_LOG_EVIDENCE_DIR` 指到一个能留住的目录，
     * 文件就不会随调用方的临时目录一起被清掉（报告要贴真实路径与内容）。
     */
    private fun newTempDir(label: String): File {
        val override = System.getenv("MIKCB_LOG_EVIDENCE_DIR")
        val base = if (!override.isNullOrBlank()) File(override) else File(System.getProperty("java.io.tmpdir"))
        val dir = File(base, "mikcb-warehouse-log-$label-" + UUID.randomUUID().toString().take(8))
        assertTrue("建临时目录失败：${dir.absolutePath}", dir.mkdirs())
        return dir
    }

    private companion object {
        const val SCHOOL = "示例大学"
        const val ADAPTER = "cas-1"
        const val FIXED_MS = 1_763_000_000_000L
        val DEVICE = WarehouseDeviceInfo(model = "Pixel 7", androidVersion = "14", appVersion = "1.2.3-debug")
    }
}
