package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导出文本的形状（纯 JVM）。
 *
 * 三条最贵的判据：
 * - **表头 10 字段齐全且顺序固定，`truncated` 恒在第 10 行**：用户报障时贴的就是这一段，
 *   少一行 / 换顺序都会让「按行读」的人对不上；缺值留空行，不省略。
 *   `truncated` 是唯一用 `: ` 分隔的一行（`truncated: true|false`），其余 9 行是 `key=value`。
 * - **失败 run 的首条必须保留**（`失败run首条必须保留_不是takeLast`）：这是保留语义的
 *   唯一可执行证据。实现若退回「取最近 500 条」，600 条那轮的首条会先被挤掉 ⇒ 红。
 * - **截断标记是 ASCII**：`[TRUNCATED]` + `truncated: true` 两处都必给——中文注记在非中文
 *   语言版本下既不可比也不可读。
 */
class WarehouseImportLogExportTest {

    @Test
    fun `表头10字段齐全且顺序固定 truncated在最后一行`() {
        val log = WarehouseImportLogBuffer()
        log.beginRun("run-1", SCHOOL, ADAPTER)
        log.record(WarehouseLogCategory.MACRO_STEP, linkedMapOf("step" to "1/2", "status" to "ok"))
        log.record(WarehouseLogCategory.FAILURE, linkedMapOf("code" to "macro_step_failed"))
        log.markFailure("macro_step_failed")

        val text = WarehouseImportLogExport.buildText(log.snapshot(), DEVICE, nowMs = FIXED_MS)
        val head = text.lineSequence().take(WarehouseImportLogExport.HEADER_KEYS.size).toList()
        assertEquals("表头必须是 10 行", 10, WarehouseImportLogExport.HEADER_KEYS.size)
        assertEquals(
            "表头行数不足：10 个字段必须各占一行",
            WarehouseImportLogExport.HEADER_KEYS.size,
            head.size,
        )
        // 前 9 行是 key=value。
        for (index in 0 until 9) {
            val key = WarehouseImportLogExport.HEADER_KEYS[index]
            assertTrue(
                "表头第 ${index + 1} 行应是 <$key>=…，实际=<${head[index]}>",
                head[index].startsWith("$key="),
            )
        }
        // 第 10 行（下标 9）是 truncated: true|false——位置写死在这里，别处不许漂。
        assertEquals(
            "第 10 行必须是 truncated 行（顺序固定，它是表头最后一行）",
            WarehouseImportLogExport.TRUNCATED_FIELD,
            WarehouseImportLogExport.HEADER_KEYS[9],
        )
        assertEquals(
            "第 10 行应逐字是 <truncated: false>（本用例没截断），实际=<${head[9]}>",
            "truncated: false",
            head[9],
        )
        // 值也要真的落进去（不是只有键）。
        assertTrue("version 没写进表头", head.any { it == "version=${DEVICE.appVersion}" })
        assertTrue("model 没写进表头", head.any { it == "model=${DEVICE.model}" })
        assertTrue("android 没写进表头", head.any { it == "android=${DEVICE.androidVersion}" })
        assertTrue("school 没写进表头", head.any { it == "school=$SCHOOL" })
        assertTrue("adapter 没写进表头", head.any { it == "adapter=$ADAPTER" })
        assertTrue("macroSteps 应统计 MACRO_STEP 条数", head.any { it == "macroSteps=1" })
        assertTrue("有失败 run 时 verdict 必须是 failure", head.any { it == "verdict=failure" })
        assertTrue("endReason 应取失败原因", head.any { it == "endReason=macro_step_failed" })
        assertTrue("time 行不能是空值", head[0].length > "time=".length)
    }

    /** 没超 256 KiB：`truncated: false`，且文末**没有**截断标记。 */
    @Test
    fun `未截断时 truncated为false且无截断标记`() {
        val log = WarehouseImportLogBuffer()
        log.beginRun("run-1", SCHOOL, ADAPTER)
        log.record(WarehouseLogCategory.MACRO_STEP, linkedMapOf("step" to "1/1"))

        val text = WarehouseImportLogExport.buildText(log.snapshot(), DEVICE, nowMs = FIXED_MS)
        assertTrue("小日志被误判成截断：$text", text.contains("truncated: false"))
        assertTrue(
            "没截断却出现 [TRUNCATED] 标记，用户会以为这份日志缺内容",
            !text.contains(WarehouseImportLogExport.TRUNCATED_NOTE),
        )
    }

    /** 超 256 KiB：表头 `truncated: true` + 文末 ASCII 标记，两处都给。 */
    @Test
    fun `截断时 truncated为true且文末带ASCII标记`() {
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
        val bytes = text.toByteArray(Charsets.UTF_8).size
        assertTrue("截断后仍有 $bytes 字节，超过 256 KiB", bytes <= WarehouseImportLogExport.MAX_TEXT_BYTES)
        assertTrue("表头没有报 truncated: true", text.contains("truncated: true"))
        assertTrue(
            "文末缺 ASCII 标记 ${WarehouseImportLogExport.TRUNCATED_NOTE}",
            text.contains(WarehouseImportLogExport.TRUNCATED_NOTE),
        )
        assertTrue(
            "截断标记必须在文末（用户从下往上看就要看到它）",
            text.trimEnd().endsWith(WarehouseImportLogExport.TRUNCATED_NOTE),
        )
    }

    /** 造 600 条 + 一次失败 ⇒ 导出仍含失败 run 的**首条**（这就是「不是 takeLast」的证据）。 */
    @Test
    fun `失败run首条必须保留_不是takeLast`() {
        val log = WarehouseImportLogBuffer()
        log.beginRun("run-fail", SCHOOL, ADAPTER)
        log.record(
            WarehouseLogCategory.MACRO_STEP,
            linkedMapOf("step" to "1/600", "marker" to "first-row"),
        )
        for (index in 1 until 600) {
            log.record(
                WarehouseLogCategory.MACRO_STEP,
                linkedMapOf("step" to "${index + 1}/600", "marker" to "row-$index"),
            )
        }
        log.record(WarehouseLogCategory.FAILURE, linkedMapOf("code" to "macro_step_failed"))
        log.markFailure("macro_step_failed")

        val snapshot = log.snapshot()
        assertEquals("失败 run 的条目被截断了（容量 500 的环形窗口不该作用在失败 run 上）", 601, snapshot.entryCount)

        val text = WarehouseImportLogExport.buildText(snapshot, DEVICE, nowMs = FIXED_MS)
        assertTrue("导出文本是空的", text.isNotBlank())
        assertTrue(
            "失败 run 的第一条被挤掉了 —— 这说明实现是 takeLast(500)，不是按 run 保留",
            text.contains("marker=first-row"),
        )
        assertTrue("最后一条也必须在（否则不是「保留」而是「换了另一段」）", text.contains("marker=row-599"))
        assertTrue("失败那条服务消息也要在文本里", text.contains("macro_step_failed"))
    }

    /** 正常收尾的 run：verdict=success；仍在跑的 run：verdict=running。 */
    @Test
    fun `verdict随收尾状态变化`() {
        val running = WarehouseImportLogBuffer()
        running.beginRun("run-1", SCHOOL, ADAPTER)
        running.record(WarehouseLogCategory.MACRO_STEP, linkedMapOf("step" to "1/1"))
        val runningText = WarehouseImportLogExport.buildText(running.snapshot(), DEVICE, nowMs = FIXED_MS)
        assertTrue(
            "run 还没收尾时 verdict 应为 running：$runningText",
            runningText.lineSequence().any { it == "verdict=running" },
        )

        running.markEnd("complete")
        val successText = WarehouseImportLogExport.buildText(running.snapshot(), DEVICE, nowMs = FIXED_MS)
        assertTrue(
            "run 正常收尾后 verdict 应为 success：$successText",
            successText.lineSequence().any { it == "verdict=success" },
        )
        assertTrue(
            "endReason 应取收尾原因：$successText",
            successText.lineSequence().any { it == "endReason=complete" },
        )
    }

    private companion object {
        const val SCHOOL = "示例大学"
        const val ADAPTER = "cas-1"
        const val FIXED_MS = 1_763_000_000_000L
        val DEVICE = WarehouseDeviceInfo(model = "Pixel 7", androidVersion = "14", appVersion = "1.2.3-debug")
    }
}
