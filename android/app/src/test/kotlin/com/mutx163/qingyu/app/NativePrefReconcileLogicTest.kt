package com.mutx163.qingyu.app

import com.mutx163.qingyu.app.PrefReconcileAction.CANCEL_SCHEDULE
import com.mutx163.qingyu.app.PrefReconcileAction.ENABLE_SCHEDULE
import com.mutx163.qingyu.app.PrefReconcileAction.NO_CHANGE
import com.mutx163.qingyu.app.PrefReconcileAction.WRITE_PREF
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 启动对账（settings → native pref 单向）的**决策 + 幂等性**单测。
 *
 * 覆盖四条硬口径（Lead 指定）：
 * 1. settings 有键且与 pref 不一致 ⇒ 执行对应动作一次；
 * 2. settings 有键且一致 ⇒ 不产生副作用（避免每次启动重复排闹钟）；
 * 3. settings **缺键** ⇒ 不覆盖 pref（旧版只写 pref 的用户不能被静默关掉）；
 * 4. settings=false 且 pref=true ⇒ 取消排程；
 * 外加：同一份快照连续对账两次，第二次动作集为空（幂等）。
 *
 * 假实现模拟真实语义：`scheduleNext` 会写 `enabled=true`，
 * `cancel` 会写 `enabled=false`，pref 写入会改值——所以「第二次无动作」不是因为
 * 假实现不记事，而是决策真读到已更新的现状。
 */
class NativePrefReconcileLogicTest {

    private class FakeScheduler(initial: Boolean) {
        var enabled: Boolean = initial
            private set
        var scheduleCalls: Int = 0
            private set
        var cancelCalls: Int = 0
            private set

        fun schedule() {
            scheduleCalls += 1
            enabled = true
        }

        fun cancel() {
            cancelCalls += 1
            enabled = false
        }
    }

    private class FakePrefStore(initial: Boolean) {
        var value: Boolean = initial
            private set
        var writes: Int = 0
            private set

        fun write(newValue: Boolean) {
            writes += 1
            value = newValue
        }
    }

    private class FakePort(
        private val scheduler: FakeScheduler,
        private val prefStore: FakePrefStore,
    ) : PrefReconcilePort {
        override fun weeklyReportEnabled(): Boolean = scheduler.enabled

        override fun scheduleWeeklyReport() = scheduler.schedule()

        override fun cancelWeeklyReport() = scheduler.cancel()

        override fun liveHideFromRecents(): Boolean = prefStore.value

        override fun writeLiveHideFromRecents(value: Boolean) = prefStore.write(value)
    }

    @Test
    fun `周报决策真值表`() {
        assertEquals(NO_CHANGE, NativePrefReconcileLogic.decideWeeklyReport(null, false))
        assertEquals(NO_CHANGE, NativePrefReconcileLogic.decideWeeklyReport(null, true))
        assertEquals(ENABLE_SCHEDULE, NativePrefReconcileLogic.decideWeeklyReport(true, false))
        assertEquals(NO_CHANGE, NativePrefReconcileLogic.decideWeeklyReport(true, true))
        assertEquals(CANCEL_SCHEDULE, NativePrefReconcileLogic.decideWeeklyReport(false, true))
        assertEquals(NO_CHANGE, NativePrefReconcileLogic.decideWeeklyReport(false, false))
    }

    @Test
    fun `隐藏任务决策真值表`() {
        assertEquals(NO_CHANGE, NativePrefReconcileLogic.decideLiveHideFromRecents(null, false))
        assertEquals(NO_CHANGE, NativePrefReconcileLogic.decideLiveHideFromRecents(null, true))
        assertEquals(
            WRITE_PREF,
            NativePrefReconcileLogic.decideLiveHideFromRecents(true, false),
        )
        assertEquals(
            WRITE_PREF,
            NativePrefReconcileLogic.decideLiveHideFromRecents(false, true),
        )
        assertEquals(NO_CHANGE, NativePrefReconcileLogic.decideLiveHideFromRecents(true, true))
        assertEquals(NO_CHANGE, NativePrefReconcileLogic.decideLiveHideFromRecents(false, false))
    }

    @Test
    fun `settings 有键且与 pref 不一致 → 排程执行一次`() {
        val scheduler = FakeScheduler(initial = false)
        val prefStore = FakePrefStore(initial = false)
        val applied = NativePrefReconcileLogic.reconcile(
            settings = mapOf(NativePrefReconcileLogic.KEY_WEEKLY_REPORT_ENABLED to true),
            port = FakePort(scheduler, prefStore),
        )

        assertEquals(listOf(ENABLE_SCHEDULE), applied)
        assertEquals(1, scheduler.scheduleCalls)
        assertEquals(0, scheduler.cancelCalls)
        assertTrue("排程后开关应变为开", scheduler.enabled)
    }

    @Test
    fun `settings 有键且与 pref 一致 → 不产生副作用`() {
        val scheduler = FakeScheduler(initial = true)
        val prefStore = FakePrefStore(initial = true)
        val applied = NativePrefReconcileLogic.reconcile(
            settings = mapOf(
                NativePrefReconcileLogic.KEY_WEEKLY_REPORT_ENABLED to true,
                NativePrefReconcileLogic.KEY_LIVE_HIDE_FROM_RECENTS to true,
            ),
            port = FakePort(scheduler, prefStore),
        )

        assertTrue("一致时不该有任何动作，实际：$applied", applied.isEmpty())
        assertEquals(0, scheduler.scheduleCalls)
        assertEquals(0, scheduler.cancelCalls)
        assertEquals("一致时不该重写 pref", 0, prefStore.writes)
    }

    @Test
    fun `settings 缺键 → 不覆盖 pref`() {
        val scheduler = FakeScheduler(initial = false)
        val prefStore = FakePrefStore(initial = true)
        // 旧版用户：只有 pref 是开着的，settings 里根本没有这两个键。
        val applied = NativePrefReconcileLogic.reconcile(
            settings = emptyMap(),
            port = FakePort(scheduler, prefStore),
        )

        assertTrue("缺键时不该有任何动作，实际：$applied", applied.isEmpty())
        assertEquals(0, scheduler.scheduleCalls)
        assertEquals(0, scheduler.cancelCalls)
        assertEquals(0, prefStore.writes)
        assertTrue("缺键时 pref 必须保持原值", prefStore.value)
    }

    @Test
    fun `settings 为 false 且 pref 为 true → 取消排程`() {
        val scheduler = FakeScheduler(initial = true)
        val prefStore = FakePrefStore(initial = false)
        val applied = NativePrefReconcileLogic.reconcile(
            settings = mapOf(NativePrefReconcileLogic.KEY_WEEKLY_REPORT_ENABLED to false),
            port = FakePort(scheduler, prefStore),
        )

        assertEquals(listOf(CANCEL_SCHEDULE), applied)
        assertEquals(1, scheduler.cancelCalls)
        assertEquals(0, scheduler.scheduleCalls)
        assertTrue("取消后开关应变为关", !scheduler.enabled)
    }

    @Test
    fun `settings 与 pref 都关 → 不重复取消`() {
        val scheduler = FakeScheduler(initial = false)
        val applied = NativePrefReconcileLogic.reconcile(
            settings = mapOf(NativePrefReconcileLogic.KEY_WEEKLY_REPORT_ENABLED to false),
            port = FakePort(scheduler, FakePrefStore(initial = false)),
        )

        assertTrue("本来就关着时不该再取消，实际：$applied", applied.isEmpty())
        assertEquals(0, scheduler.cancelCalls)
    }

    @Test
    fun `隐藏任务不一致才写 pref`() {
        val prefStore = FakePrefStore(initial = false)
        NativePrefReconcileLogic.reconcile(
            settings = mapOf(NativePrefReconcileLogic.KEY_LIVE_HIDE_FROM_RECENTS to true),
            port = FakePort(FakeScheduler(initial = false), prefStore),
        )

        assertEquals(1, prefStore.writes)
        assertTrue(prefStore.value)
    }

    @Test
    fun `连续对账两次 → 第二次副作用为零`() {
        val scheduler = FakeScheduler(initial = false)
        val prefStore = FakePrefStore(initial = false)
        val port = FakePort(scheduler, prefStore)
        val settings = mapOf(
            NativePrefReconcileLogic.KEY_WEEKLY_REPORT_ENABLED to true,
            NativePrefReconcileLogic.KEY_LIVE_HIDE_FROM_RECENTS to true,
        )

        val first = NativePrefReconcileLogic.reconcile(settings, port)
        assertEquals(
            listOf(ENABLE_SCHEDULE, WRITE_PREF),
            first,
        )
        assertEquals(1, scheduler.scheduleCalls)
        assertEquals(1, prefStore.writes)

        val second = NativePrefReconcileLogic.reconcile(settings, port)
        assertTrue("第二次对账不该再产生任何动作，实际：$second", second.isEmpty())
        assertEquals("第二次不该重排闹钟", 1, scheduler.scheduleCalls)
        assertEquals(0, scheduler.cancelCalls)
        assertEquals("第二次不该重写 pref", 1, prefStore.writes)
    }
}
