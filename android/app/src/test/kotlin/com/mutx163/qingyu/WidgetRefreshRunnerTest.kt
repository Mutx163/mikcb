package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [WidgetRefreshRunner] 的 JVM 单测（不需要 Android）。
 *
 * 钉的是一个**已经发生过的真 bug 形态**：`updateAll` 抛异常后 `rescheduleRefresh` 不执行，
 * 精确闹钟不再重排，桌面卡片静默停更到进程重启。本文件把「异常路径也必须重排 + 必须 finish」
 * 写成可执行断言，任何人把 `finally` 改成顺序调用都会红。
 *
 * 咬合探针记录：把 `run()` 里的 `safely(STAGE_RESCHEDULE) { reschedule() }` 删掉 →
 * `updateAll 抛两次异常` 与 `reschedule 抛异常` 两例立即失败；还原后全绿。
 */
class WidgetRefreshRunnerTest {

    private class Recorder {
        var updateCalls = 0
        var rescheduleCalls = 0
        var finishCalls = 0
        val order = mutableListOf<String>()
        val failures = mutableListOf<String>()
    }

    /** 探针辅助：`updateAll` 放最后，尾部 lambda 才绑得到它。 */
    private fun runner(
        recorder: Recorder,
        reschedule: () -> Unit = { recorder.rescheduleCalls++; recorder.order += "reschedule" },
        finish: () -> Unit = { recorder.finishCalls++; recorder.order += "finish" },
        updateAll: () -> Unit,
    ): WidgetRefreshRunner = WidgetRefreshRunner(
        updateAll = updateAll,
        reschedule = reschedule,
        finish = finish,
        onError = { stage, _ -> recorder.failures += stage },
    )

    @Test
    fun `updateAll 连续抛两次异常时 reschedule 与 finish 仍各执行一次`() {
        val recorder = Recorder()
        val runner = runner(recorder) {
            recorder.updateCalls++
            recorder.order += "update"
            throw IllegalStateException("模拟整份档案 JSON 解析失败")
        }

        runner.run()

        assertEquals("失败后应只重试一次", 2, recorder.updateCalls)
        assertEquals("异常路径必须重排闹钟", 1, recorder.rescheduleCalls)
        assertEquals("异常路径必须 finish 广播", 1, recorder.finishCalls)
        assertEquals(listOf("update", "update", "reschedule", "finish"), recorder.order)
        assertEquals(listOf("update", "retry"), recorder.failures)
    }

    @Test
    fun `updateAll 首次失败、重试成功时不再记失败`() {
        val recorder = Recorder()
        val runner = runner(recorder) {
            recorder.updateCalls++
            if (recorder.updateCalls == 1) throw IllegalStateException("第一次失败")
        }

        runner.run()

        assertEquals(2, recorder.updateCalls)
        assertEquals(1, recorder.rescheduleCalls)
        assertEquals(1, recorder.finishCalls)
        assertEquals(listOf("update"), recorder.failures)
    }

    @Test
    fun `updateAll 成功时只跑一次且照常重排`() {
        val recorder = Recorder()
        val runner = runner(recorder) { recorder.updateCalls++ }

        runner.run()

        assertEquals(1, recorder.updateCalls)
        assertEquals(1, recorder.rescheduleCalls)
        assertEquals(1, recorder.finishCalls)
        assertTrue(recorder.failures.isEmpty())
    }

    @Test
    fun `reschedule 自己抛异常时 finish 仍执行且不外抛`() {
        val recorder = Recorder()
        val runner = runner(
            recorder = recorder,
            updateAll = { recorder.updateCalls++ },
            reschedule = {
                recorder.rescheduleCalls++
                throw SecurityException("模拟精确闹钟权限被收回")
            },
        )

        runner.run()

        assertEquals(1, recorder.rescheduleCalls)
        assertEquals("reschedule 失败也不能吞掉 finish", 1, recorder.finishCalls)
        assertEquals(listOf(WidgetRefreshRunner.STAGE_RESCHEDULE), recorder.failures)
    }

    @Test
    fun `finish 自己抛异常不外抛`() {
        val recorder = Recorder()
        val runner = runner(
            recorder = recorder,
            updateAll = { recorder.updateCalls++ },
            finish = { recorder.finishCalls++; throw IllegalStateException("模拟 PendingResult 已回收") },
        )

        runner.run()

        assertEquals(1, recorder.finishCalls)
        assertEquals(1, recorder.rescheduleCalls)
        assertEquals(listOf(WidgetRefreshRunner.STAGE_FINISH), recorder.failures)
    }
}
