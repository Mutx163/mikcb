package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.infra.AppLogStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * C 的**双脱敏读回**用例（L0 可跑）。
 *
 * ## 这一步相比 A 的唯一新增风险
 *
 * A 只证明「面板/`last.txt` 干净」；C 多开了一条出口（应用日志），多一个出口就多一次
 * 「上游把没脱敏的文本递进来」的机会。所以这里不只测「跑一遍结果干净」，还测
 * **递进去的文本本身没脱敏时，应用日志仍然干净**（[appendWarehouseImportLogToAppLog]
 * 内部那道闸），以及两端读回**同时**干净。
 *
 * ## 口径
 *
 * - 四个明文样本：`13800138000 + 86`（键 `phone`）、`Abc123456`（键 `account`）、
 *   `JSESSIONID=abcd`（键 `Cookie`）、`?token=xyz`（URL 查询串）。
 * - `last.txt` 与 `app_runtime.log` **都**读回、都逐个 `assertFalse`；
 * - 两端都还要有正向内容（不是靠「什么都没写」过关）。
 * - 8 KiB 截断：构造 9 KB 的 message，末尾放 `TAIL_MARKER`；应用日志里应当有
 *   `[TRUNCATED]`、没有 `TAIL_MARKER`。
 */
class WarehouseImportLogAppLogTest {

    // ---------------------------------------------------------------
    // 1. 双落点：两端都干净
    // ---------------------------------------------------------------

    @Test
    fun `both last_txt and the app log are free of plaintext secrets`() {
        val dir = Files.createTempDirectory("warehouse-c-both").toFile()
        AppLogStore.initialize(dir)
        val snapshot = snapshotWithSecrets()
        val deviceInfo = DEVICE
        val exportText = WarehouseImportLogExport.buildText(snapshot, deviceInfo, FIXED_NOW)
        // 宿主侧同一条路径：导出文本 → 过一遍脱敏 → 再交给 C 的落点。
        val redactedByHost = WarehouseLogRedaction.redactText(exportText)

        val fileWriter = WarehouseImportLogFileWriter(
            baseDir = dir,
            log = WarehouseImportLogBuffer(nowMs = { FIXED_NOW }),
        )
        assertTrue("last.txt must be written", fileWriter.write(exportText))
        assertTrue(
            "app log append must succeed",
            appendWarehouseImportLogToAppLog(
                snapshot = snapshot,
                text = redactedByHost,
                log = WarehouseImportLogBuffer(nowMs = { FIXED_NOW }),
            ),
        )

        val appLog = AppLogStore.readText()
        val lastTxt = File(dir, "warehouse_import_log/last.txt").readText()
        assertTrue("app log is blank", appLog.isNotBlank())
        assertTrue("last.txt is blank", lastTxt.isNotBlank())

        for (secret in SECRETS) {
            assertFalse("app log leaked <$secret>", appLog.contains(secret))
            assertFalse("last.txt leaked <$secret>", lastTxt.contains(secret))
        }

        // 正向一侧：两端都有真内容，不是靠「什么都没记」过关。
        assertTrue("app log lost the category", appLog.contains("category=warehouse.import"))
        assertTrue("app log lost the end reason", appLog.contains("endReason=timeout"))
        assertTrue("app log lost the entry count", appLog.contains("entries=1"))
        assertTrue("app log dropped the host-only url", appLog.contains("https://jw.example.edu"))
        assertTrue("last.txt lost the verdict", lastTxt.contains("verdict=failure"))
    }

    // ---------------------------------------------------------------
    // 2. 第二道闸：调用方递进来没脱敏的文本，应用日志仍要干净
    // ---------------------------------------------------------------

    @Test
    fun `app log path re-redacts text handed in without redaction`() {
        val dir = Files.createTempDirectory("warehouse-c-gate").toFile()
        AppLogStore.initialize(dir)
        val raw = "request https://jw.example.edu/xskb/list?token=xyz with JSESSIONID=abcd"

        assertTrue(
            appendWarehouseImportLogToAppLog(
                snapshot = snapshotWithSecrets(entries = emptyList()),
                text = raw,
                log = WarehouseImportLogBuffer(nowMs = { FIXED_NOW }),
            ),
        )

        val appLog = AppLogStore.readText()
        listOf("xyz", "abcd", "/xskb/", "token=xyz").forEach { leaked ->
            assertFalse("second redaction gate missed <$leaked>", appLog.contains(leaked))
        }
        assertTrue("host-only url must survive", appLog.contains("https://jw.example.edu"))
    }

    // ---------------------------------------------------------------
    // 3. 8 KiB 上限：截断标记出现、尾部标记消失
    // ---------------------------------------------------------------

    @Test
    fun `oversized message is truncated with the marker`() {
        val dir = Files.createTempDirectory("warehouse-c-cap").toFile()
        AppLogStore.initialize(dir)
        val bigMessage = "C".repeat(9_000) + TAIL_MARKER
        val bigEntry = WarehouseImportLogEntry(
            tsMs = FIXED_NOW,
            category = WarehouseLogCategory.SCRIPT,
            fields = linkedMapOf("message" to bigMessage),
        )
        val snapshot = snapshotWithSecrets(entries = listOf(bigEntry))
        val text = WarehouseImportLogExport.buildText(snapshot, DEVICE, FIXED_NOW)
        assertTrue(
            "fixture must exceed the 8 KiB cap: ${text.toByteArray(Charsets.UTF_8).size}",
            text.toByteArray(Charsets.UTF_8).size > WAREHOUSE_IMPORT_APP_LOG_MAX_BYTES,
        )

        assertTrue(
            appendWarehouseImportLogToAppLog(
                snapshot = snapshot,
                text = text,
                log = WarehouseImportLogBuffer(nowMs = { FIXED_NOW }),
            ),
        )

        val appLog = AppLogStore.readText()
        assertTrue("truncation marker missing", appLog.contains(WAREHOUSE_IMPORT_APP_LOG_TRUNCATED_NOTE))
        assertFalse("tail beyond the cap must be dropped", appLog.contains(TAIL_MARKER))
        val body = appLog.substringAfter("message=")
        assertTrue(
            "truncated body is still too long: ${body.length}",
            body.length <= WAREHOUSE_IMPORT_APP_LOG_MAX_BYTES + 128,
        )
    }

    // ---------------------------------------------------------------
    // 4. 写失败：不抛、只记 INTERNAL（与 last.txt 同一口径）
    // ---------------------------------------------------------------

    @Test
    fun `append failure is recorded as internal and never thrown`() {
        val dir = Files.createTempDirectory("warehouse-c-fail").toFile()
        // 把 filesDir 指到一个**普通文件**上：目录建不出来，AppLogStore.append 必失败。
        val blocker = File(dir, "blocked")
        blocker.writeText("not a directory")
        assertTrue(blocker.isFile)
        AppLogStore.initialize(blocker)

        val buffer = WarehouseImportLogBuffer(nowMs = { FIXED_NOW })
        val ok = appendWarehouseImportLogToAppLog(
            snapshot = snapshotWithSecrets(),
            text = "anything",
            log = buffer,
        )

        assertFalse("append must report failure, not throw", ok)
        val internal = buffer.snapshot().runs
            .flatMap { it.entries }
            .filter { it.category == WarehouseLogCategory.INTERNAL }
        assertEquals(1, internal.size)
        assertEquals("appendWarehouseImportLogToAppLog", internal.single().fields["where"])
    }

    // ---------------------------------------------------------------
    // 构造器
    // ---------------------------------------------------------------

    /** 模拟「上游绕过 buffer 直接塞了明文」的一轮收尾（失败 run，endReason=timeout）。 */
    private fun snapshotWithSecrets(
        entries: List<WarehouseImportLogEntry> = listOf(secretEntry()),
    ) = WarehouseImportLogSnapshot(
        runs = listOf(
            WarehouseImportLogRun(
                runId = "run-1",
                school = "",
                adapterId = "cas-1",
                entries = entries,
                endReason = "timeout",
                failed = true,
                finished = true,
            ),
        ),
        lastFailureReason = "timeout",
    )

    private fun secretEntry() = WarehouseImportLogEntry(
        tsMs = FIXED_NOW,
        category = WarehouseLogCategory.FAILURE,
        fields = linkedMapOf(
            "phone" to "13800138000 + 86",
            "account" to "Abc123456",
            "Cookie" to "JSESSIONID=abcd",
            "url" to "https://jw.example.edu/xskb/list?token=xyz",
        ),
    )

    private companion object {
        const val FIXED_NOW = 1_700_000_000_000L
        const val TAIL_MARKER = "TAIL_MARKER_AFTER_CAP"

        /** 这四个串在原样文本里各出现一次，两个落点都不许读回它们。 */
        val SECRETS = listOf("13800138000", "Abc123456", "JSESSIONID=abcd", "token=xyz")

        val DEVICE = WarehouseDeviceInfo(
            model = "Pixel 7",
            androidVersion = "14",
            appVersion = "1.2.3-debug",
        )
    }
}
