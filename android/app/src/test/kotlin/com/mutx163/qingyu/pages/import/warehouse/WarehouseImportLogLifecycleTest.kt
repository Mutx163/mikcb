package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `WarehouseImportLogLifecycle` 的语义用例（纯 JVM，不碰 Compose）。
 *
 * 钉的正是 2026-11-14 复核出来的那条缺陷：`beginRun` / `markEnd` / `markFailure` / `reset`
 * 生产零调用 ⇒ 表头空、verdict 恒 running、失败也算 running、几次尝试挤进同一个 auto run。
 * 现在宿主只经这一层改 run 状态，所以这里把「会话 / 开轮 / 收尾 / 迟到事件」四件事钉死。
 */
class WarehouseImportLogLifecycleTest {

    @Test
    fun `开轮即写表头 school 与 adapter`() {
        WarehouseImportLogLifecycle.resetForTest("t/header")
        val runId = WarehouseImportLogLifecycle.beginAttempt("杭州大学", "adapter-9")
        val run = WarehouseImportLog.snapshot().currentRun!!

        assertEquals(runId, run.runId)
        assertTrue("runId 必须带显式前缀，不能再落进 auto-", runId.startsWith("run-"))
        assertEquals("杭州大学", run.school)
        assertEquals("adapter-9", run.adapterId)
        assertFalse(run.finished)
        assertTrue(WarehouseImportLogLifecycle.isOpen())
    }

    @Test
    fun `每次执行各算一轮 同会话重试保留上一轮失败现场`() {
        WarehouseImportLogLifecycle.resetForTest("t/retry")
        WarehouseImportLogLifecycle.beginAttempt("A", "a")
        WarehouseImportLogLifecycle.recordFailure("boom", "detail" to "connect")
        WarehouseImportLogLifecycle.failIfOpen("boom")
        // 同一会话再点一次执行：上一次失败不能消失。
        WarehouseImportLogLifecycle.beginAttempt("A", "a")

        val runs = WarehouseImportLog.snapshot().runs
        assertEquals(2, runs.size)
        assertEquals("run-1", runs[0].runId)
        assertTrue("失败那一轮必须标 failed", runs[0].failed)
        assertEquals("boom", runs[0].endReason)
        assertEquals(1, runs[0].entries.size)
        assertEquals(WarehouseLogCategory.FAILURE, runs[0].entries[0].category)
        assertFalse(runs[1].finished)
    }

    @Test
    fun `换导入目标才清空 同目标重进页面不清`() {
        WarehouseImportLogLifecycle.resetForTest("school-1/adapter-1")
        WarehouseImportLogLifecycle.beginAttempt("一校", "adapter-1")
        WarehouseImportLogLifecycle.endIfOpen("complete")

        // 同键重进：旧证据还在。
        WarehouseImportLogLifecycle.beginSession("school-1/adapter-1")
        assertEquals(1, WarehouseImportLog.snapshot().runs.size)

        // 换学校：新会话，空 buffer。
        WarehouseImportLogLifecycle.beginSession("school-2/adapter-2")
        assertTrue(WarehouseImportLog.snapshot().runs.isEmpty())
    }

    @Test
    fun `迟到的 complete 不改写已定局的结论`() {
        WarehouseImportLogLifecycle.resetForTest("t/late")
        WarehouseImportLogLifecycle.beginAttempt("A", "a")
        assertTrue(WarehouseImportLogLifecycle.endIfOpen("complete"))

        assertFalse("已定局后 complete 再收尾必须 no-op", WarehouseImportLogLifecycle.endIfOpen("complete-late"))
        assertFalse("已定局后不许再翻成失败", WarehouseImportLogLifecycle.failIfOpen("late-error"))

        val run = WarehouseImportLog.snapshot().currentRun!!
        assertTrue(run.finished)
        assertFalse(run.failed)
        assertEquals("complete", run.endReason)
    }

    @Test
    fun `定局后的失败记录被丢弃 不新开 auto 轮`() {
        WarehouseImportLogLifecycle.resetForTest("t/drop")
        WarehouseImportLogLifecycle.beginAttempt("A", "a")
        WarehouseImportLogLifecycle.endIfOpen("complete")
        val before = WarehouseImportLog.snapshot().runs.size

        assertFalse(WarehouseImportLogLifecycle.recordFailure("late"))
        assertEquals(before, WarehouseImportLog.snapshot().runs.size)
    }

    @Test
    fun `失败收尾后导出结论是 failure 正常收尾是 success`() {
        WarehouseImportLogLifecycle.resetForTest("t/verdict-fail")
        WarehouseImportLogLifecycle.beginAttempt("A", "a")
        WarehouseImportLogLifecycle.recordFailure("boom")
        WarehouseImportLogLifecycle.failIfOpen("boom")
        val failed = WarehouseImportLogExport.buildText(
            WarehouseImportLog.snapshot(),
            WarehouseDeviceInfo.UNKNOWN,
            nowMs = 0L,
        )
        assertTrue("失败 run 的 verdict 必须是 failure（以前恒 running）", "verdict=failure" in failed)
        assertTrue("endReason 必须写进表头", "endReason=boom" in failed)

        WarehouseImportLogLifecycle.resetForTest("t/verdict-ok")
        WarehouseImportLogLifecycle.beginAttempt("A", "a")
        WarehouseImportLogLifecycle.endIfOpen("complete")
        val ok = WarehouseImportLogExport.buildText(
            WarehouseImportLog.snapshot(),
            WarehouseDeviceInfo.UNKNOWN,
            nowMs = 0L,
        )
        assertTrue("正常收尾的 verdict 必须是 success", "verdict=success" in ok)
        assertTrue("正常收尾的 endReason 必须是 complete", "endReason=complete" in ok)
    }

    @Test
    fun `runId 单调递增且不重复`() {
        WarehouseImportLogLifecycle.resetForTest("t/ids")
        val first = WarehouseImportLogLifecycle.beginAttempt("A", "a")
        val second = WarehouseImportLogLifecycle.beginAttempt("A", "a")
        assertNotEquals(first, second)
        assertEquals("run-1", first)
        assertEquals("run-2", second)
    }
}
